/**
 * The DQ menu on a sport's live board.
 *
 * It appends one row to the `Run requests` tab and stops. It holds no SQL, no database
 * credentials, no mail credentials and no execution logic, and it has no code path that
 * builds a command: what it writes is a CheckID the board already contains, or the single
 * reserved token *SPORT*. Everything that runs runs on the owner's machine, from
 * TOOLS/Watch-SheetRequests.ps1, which validates every field again before acting on it.
 *
 * Deploy it to execute as the owner. That is what lets the tab be a protected range - the
 * button still appends for everybody allowed to click it, while nobody can type into the
 * queue by hand. Without that, ALLOWED below guards against a mistake and not against
 * intent, because `Requested by` would be a cell anybody could write.
 *
 * The source of truth for this file is TOOLS/sheets-apps-script/RunRequests.gs in the
 * entpulse_quality_database repository. Edit it there, then paste it in.
 */

var QUEUE_SHEET = 'Run requests';
var WHOLE_SPORT = '*SPORT*';

/**
 * Who may ask. Kept in step with `requesters.allowed` in TOOLS/sheet-registry.json, which is
 * what the worker enforces; this copy only decides whether the menu item does anything, and
 * a request that slips past it is refused on the machine rather than run.
 */
var ALLOWED = [
  'zgeorgieva@enetpulse.com',
  'vanin.neykov@enetpulse.com',
  'mtumpalov@enetpulse.com',
  'venelin@enetpulse.com'
];

var HEADERS = [
  'Request ID', 'CheckID', 'Requested by', 'Requested at', 'Status',
  'Started at', 'Finished at', 'Run ID', 'Findings', 'Eligible', 'Verdict', 'Error'
];

function onOpen() {
  SpreadsheetApp.getUi()
    .createMenu('DQ')
    .addItem('Run this check', 'requestThisCheck')
    .addItem('Run the whole sport (owner only)', 'requestWholeSport')
    .addSeparator()
    .addItem('Open run queue', 'openRunQueue')
    .addItem('Cancel selected request', 'cancelSelectedRequest')
    .addToUi();
}

/** The person clicking. Empty when the script cannot see them, which is refused rather than guessed. */
function currentUser_() {
  var user = '';
  try { user = Session.getActiveUser().getEmail() || ''; } catch (e) { user = ''; }
  return user.toLowerCase();
}

/** The account the script runs as, which is the document's owner when it is deployed that way. */
function ownerUser_() {
  var user = '';
  try { user = Session.getEffectiveUser().getEmail() || ''; } catch (e) { user = ''; }
  return user.toLowerCase();
}

function mayRequest_(user) {
  if (!user) { return false; }
  if (user === ownerUser_()) { return true; }
  for (var i = 0; i < ALLOWED.length; i++) {
    if (ALLOWED[i].toLowerCase() === user) { return true; }
  }
  return false;
}

function queueSheet_() {
  var book = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = book.getSheetByName(QUEUE_SHEET);
  if (!sheet) {
    throw new Error(
      'This document has no "' + QUEUE_SHEET + '" tab yet. It is created by ' +
      'TOOLS/Add-RunRequestsTab.ps1, which also protects it.');
  }
  return sheet;
}

/**
 * The CheckID under the cursor. On a check tab it is in A2, where the run writes the
 * identity block; on Overview it is column B of the selected row.
 *
 * Always the full ID. `DQ-023` is not enough - Cycling-DQ-023 and Triathlon-DQ-023 are
 * different checks, and a board carries only one sport's.
 */
function selectedCheckId_() {
  var book = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = book.getActiveSheet();
  var name = sheet.getName();

  if (name === QUEUE_SHEET) {
    return String(sheet.getRange(sheet.getActiveCell().getRow(), 2).getValue() || '').trim();
  }
  if (name === 'Overview') {
    var row = sheet.getActiveCell().getRow();
    if (row < 2) { return ''; }
    return String(sheet.getRange(row, 2).getValue() || '').trim();
  }
  return String(sheet.getRange('A2').getValue() || '').trim();
}

/**
 * One CheckID and nothing else. No list, no wildcard, no path, no whitespace splitting into
 * two - the queue row has a single CheckID cell and this writes one value into it. The
 * shape is checked here for a clear message and again on the machine, where it is enforced.
 */
function looksLikeOneCheckId_(value) {
  return /^[A-Za-z][A-Za-z0-9.\-]*-DQ-\d{1,4}$/.test(value);
}

function newRequestId_() {
  return 'REQ-' + Utilities.formatDate(new Date(), 'UTC', 'yyyyMMdd-HHmmss') + '-' +
    Utilities.getUuid().substring(0, 4).toUpperCase();
}

function alreadyOpen_(sheet, checkId) {
  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    var id = String(values[i][1] || '').trim();
    var status = String(values[i][4] || '').trim().toUpperCase();
    if (status !== 'QUEUED' && status !== 'WAITING' && status !== 'RUNNING') { continue; }
    if (id === checkId) { return true; }
    // A whole-sport run repaints every check, so anything queued behind it is already asked
    // for, and a second *SPORT* would repaint what the first one just did.
    if (id === WHOLE_SPORT || checkId === WHOLE_SPORT) { return true; }
  }
  return false;
}

function append_(checkId, user) {
  var sheet = queueSheet_();
  if (alreadyOpen_(sheet, checkId)) {
    SpreadsheetApp.getUi().alert(
      checkId === WHOLE_SPORT
        ? 'A run is already queued for this sport. Wait for it to finish.'
        : checkId + ' is already queued or running. Wait for it to finish.');
    return;
  }

  var requestId = newRequestId_();
  sheet.appendRow([
    requestId, checkId, user, new Date(), 'QUEUED', '', '', '', '', '', '', ''
  ]);

  var ahead = 0;
  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    var status = String(values[i][4] || '').trim().toUpperCase();
    if (status === 'QUEUED' || status === 'WAITING' || status === 'RUNNING') { ahead++; }
  }

  // What is ahead, not only the position. A board refresh takes about thirteen minutes for a
  // mid-sized sport, and a bare "Position 2" does not explain the wait to the person waiting.
  var note = ahead <= 1
    ? 'It will start within a minute unless the machine is busy.'
    : 'Position ' + ahead + '. Something is running ahead of it; a whole-sport refresh takes ' +
      'around fifteen minutes.';
  SpreadsheetApp.getUi().alert('Queued ' + checkId + '.\n\n' + note + '\n\nRequest ' + requestId);
}

function requestThisCheck() {
  var user = currentUser_();
  if (!mayRequest_(user)) {
    SpreadsheetApp.getUi().alert(
      'Runs can be asked for by a few named accounts. Ask the owner to add ' +
      (user || 'your account') + ' to the list.');
    return;
  }

  var checkId = selectedCheckId_();
  if (!checkId) {
    SpreadsheetApp.getUi().alert(
      'No check here. Open a check tab, or select a row on Overview, and try again.');
    return;
  }
  if (!looksLikeOneCheckId_(checkId)) {
    SpreadsheetApp.getUi().alert(
      'That does not read as one CheckID: "' + checkId + '".\n\n' +
      'One check at a time, by its full ID - Soccer-DQ-023, not DQ-023 and not a list.');
    return;
  }
  append_(checkId, user);
}

/**
 * The whole sport, which is the owner's alone. It writes the reserved token rather than a
 * list, so the cell stays one value and the machine maps that one value to -RunAll itself.
 * It is also the long job on the queue and holds the lock for its whole length.
 */
function requestWholeSport() {
  var user = currentUser_();
  var owner = ownerUser_();
  if (!user || !owner || user !== owner) {
    SpreadsheetApp.getUi().alert(
      'A whole-sport run is the owner\'s to ask for. Use "Run this check" for one check.');
    return;
  }

  var response = SpreadsheetApp.getUi().alert(
    'Refresh the whole board?',
    'This runs every approved check for this sport and repaints the board. It takes minutes, ' +
    'and everything else on the queue waits behind it.',
    SpreadsheetApp.getUi().ButtonSet.OK_CANCEL);
  if (response !== SpreadsheetApp.getUi().Button.OK) { return; }

  append_(WHOLE_SPORT, user);
}

function openRunQueue() {
  var sheet = queueSheet_();
  SpreadsheetApp.getActiveSpreadsheet().setActiveSheet(sheet);
}

/**
 * Cancelling is only ever a QUEUED or WAITING request. A RUNNING one is a statement already
 * on the database, and a row that says CANCELLED while the run continues is worse than no
 * button at all.
 */
function cancelSelectedRequest() {
  var user = currentUser_();
  if (!mayRequest_(user)) {
    SpreadsheetApp.getUi().alert('Only the accounts that may ask for a run may cancel one.');
    return;
  }

  var sheet = queueSheet_();
  if (SpreadsheetApp.getActiveSheet().getName() !== QUEUE_SHEET) {
    SpreadsheetApp.getUi().alert('Open "' + QUEUE_SHEET + '" and select the request to cancel.');
    return;
  }

  var row = sheet.getActiveCell().getRow();
  if (row < 2) {
    SpreadsheetApp.getUi().alert('Select a request row.');
    return;
  }

  var status = String(sheet.getRange(row, 5).getValue() || '').trim().toUpperCase();
  if (status !== 'QUEUED' && status !== 'WAITING') {
    SpreadsheetApp.getUi().alert(
      'Only a QUEUED or WAITING request can be cancelled. This one is ' + (status || 'blank') + '.');
    return;
  }

  sheet.getRange(row, 5).setValue('CANCELLED');
  sheet.getRange(row, 7).setValue(new Date());
  sheet.getRange(row, 12).setValue('Cancelled by ' + user);
}
