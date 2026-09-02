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

/**
 * Where a column is, by its header text.
 *
 * Read off row 1 rather than counted, because the two files that write this tab have to agree
 * about its shape and only one of them can be redeployed by editing a file. Two columns were
 * inserted into the middle of the layout on 2026-09-01; every positional index in this script
 * would have moved silently, and the failure would have been a status written into the wrong
 * cell rather than an error.
 *
 * Returns a zero-based index, or -1.
 */
function columnIndex_(sheet, name) {
  var width = sheet.getLastColumn();
  if (width < 1) { return -1; }
  var header = sheet.getRange(1, 1, 1, width).getValues()[0];
  for (var i = 0; i < header.length; i++) {
    if (String(header[i] || '').trim() === name) { return i; }
  }
  return -1;
}

/** One-based, and it throws rather than writing into a column it guessed at. */
function columnNumber_(sheet, name) {
  var index = columnIndex_(sheet, name);
  if (index < 0) {
    throw new Error(
      'The "' + QUEUE_SHEET + '" tab has no "' + name + '" column. It is created by ' +
      'TOOLS/Add-RunRequestsTab.ps1, which also adds columns to a tab written before they existed.');
  }
  return index + 1;
}

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
    return String(sheet.getRange(sheet.getActiveCell().getRow(),
      columnNumber_(sheet, 'CheckID')).getValue() || '').trim();
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

/**
 * The moment, written the way the worker writes its own timestamps.
 *
 * A string and not a Date. appendRow replaces the cell's number format with a bare DATE_TIME
 * whose pattern is empty, so a Date arrives rendered in the spreadsheet's default order while
 * Started at and Finished at - written as text by the worker - read dd.MM.yyyy beside it.
 * Measured on the Soccer board 2026-09-01: 9/1/2026 next to 01.09.2026 in the same row, which
 * is exactly the pair that gets read as the ninth of January.
 *
 * The document's zone and not the script's. getScriptTimeZone() returns what appsscript.json
 * declares, which is a second place for the answer to live and drifted from the first one
 * immediately: the manifest said Europe/Sofia while the document and the machine were both
 * Europe/Paris, so every request was stamped an hour ahead and the board showed runs starting
 * before they were asked for - Requested at 21:36:02 beside Started at 20:36:30 on the Soccer
 * board, 2026-09-01. The spreadsheet's own zone is the frame everything else on the board is
 * already in, and it cannot disagree with itself.
 */
function stamp_() {
  var zone = SpreadsheetApp.getActiveSpreadsheet().getSpreadsheetTimeZone();
  return Utilities.formatDate(new Date(), zone, 'dd.MM.yyyy HH:mm:ss');
}

function newRequestId_() {
  return 'REQ-' + Utilities.formatDate(new Date(), 'UTC', 'yyyyMMdd-HHmmss') + '-' +
    Utilities.getUuid().substring(0, 4).toUpperCase();
}

/**
 * What a CheckID asserts, taken off the board it is on.
 *
 * Overview already carries every check's name against its ID, so this needs no registry and no
 * second tab to maintain: the name written into the queue is the same string the reviewer is
 * looking at one tab away. A check tab is read too, for a click made from one whose row has not
 * reached Overview.
 *
 * Empty when it cannot be found, which is not an error. The worker fills the cell from
 * POWERBI_REGISTRY.md when it picks the request up, so a blank here is at worst brief.
 */
function checkNameFor_(checkId) {
  if (!checkId || checkId === WHOLE_SPORT) { return ''; }
  var book = SpreadsheetApp.getActiveSpreadsheet();

  var overview = book.getSheetByName('Overview');
  if (overview) {
    try {
      var idColumn = 0, nameColumn = 0;
      var width = overview.getLastColumn();
      var header = overview.getRange(1, 1, 1, width).getValues()[0];
      for (var c = 0; c < header.length; c++) {
        var title = String(header[c] || '').trim();
        if (title === 'CheckID') { idColumn = c; }
        if (title === 'Check Name') { nameColumn = c; }
      }
      if (nameColumn > 0) {
        var rows = overview.getRange(2, 1, Math.max(overview.getLastRow() - 1, 1), width).getValues();
        for (var r = 0; r < rows.length; r++) {
          if (String(rows[r][idColumn] || '').trim() === checkId) {
            return String(rows[r][nameColumn] || '').trim();
          }
        }
      }
    } catch (e) { }
  }

  // A check tab carries its own identity in row 1 and row 2.
  try {
    var tab = book.getActiveSheet();
    if (String(tab.getRange('A2').getValue() || '').trim() === checkId) {
      return String(tab.getRange('B2').getValue() || '').trim();
    }
  } catch (e) { }

  return '';
}

function alreadyOpen_(sheet, checkId) {
  var idColumn = columnIndex_(sheet, 'CheckID');
  var statusColumn = columnIndex_(sheet, 'Status');
  if (idColumn < 0 || statusColumn < 0) { return false; }

  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    var id = String(values[i][idColumn] || '').trim();
    var status = String(values[i][statusColumn] || '').trim().toUpperCase();
    if (status !== 'QUEUED' && status !== 'WAITING' && status !== 'RUNNING') { continue; }
    if (id === checkId) { return true; }
    // A whole-sport run repaints every check, so anything queued behind it is already asked
    // for, and a second *SPORT* would repaint what the first one just did.
    if (id === WHOLE_SPORT || checkId === WHOLE_SPORT) { return true; }
  }
  return false;
}

/** The ID and what it asserts, which is the only form either of them is ever offered in. */
function describe_(checkId, name) {
  if (checkId === WHOLE_SPORT) { return 'every approved check for this sport'; }
  return name ? checkId + ' - ' + name : checkId;
}

function append_(checkId, user) {
  var sheet = queueSheet_();

  var name = checkId === WHOLE_SPORT ? 'every approved check for this sport'
    : checkNameFor_(checkId);

  if (alreadyOpen_(sheet, checkId)) {
    SpreadsheetApp.getUi().alert(
      checkId === WHOLE_SPORT
        ? 'A run is already queued for this sport. Wait for it to finish.'
        : describe_(checkId, name) + ' is already queued or running. Wait for it to finish.');
    return;
  }

  var requestId = newRequestId_();

  // Built by header name and not as a fixed list, so a column added to the tab lands where the
  // header says rather than one place to the left of it.
  var width = Math.max(sheet.getLastColumn(), 1);
  var row = [];
  for (var c = 0; c < width; c++) { row.push(''); }
  row[columnNumber_(sheet, 'Request ID') - 1] = requestId;
  row[columnNumber_(sheet, 'CheckID') - 1] = checkId;
  row[columnNumber_(sheet, 'Requested by') - 1] = user;
  row[columnNumber_(sheet, 'Requested at') - 1] = stamp_();
  row[columnNumber_(sheet, 'Status') - 1] = 'QUEUED';

  var nameColumn = columnIndex_(sheet, 'Check name');
  if (nameColumn >= 0) { row[nameColumn] = name; }

  sheet.appendRow(row);

  var statusColumn = columnIndex_(sheet, 'Status');
  var ahead = 0;
  var values = sheet.getDataRange().getValues();
  for (var i = 1; i < values.length; i++) {
    var status = String(values[i][statusColumn] || '').trim().toUpperCase();
    if (status === 'QUEUED' || status === 'WAITING' || status === 'RUNNING') { ahead++; }
  }

  // Land them on the queue rather than leaving them on the tab they clicked from. This is the
  // whole of what "open it when the script finishes" can be: an installable trigger runs
  // detached from anybody's browser, so nothing can pull a viewer's screen minutes later when
  // the run actually ends. Landing here at the click is better than that anyway - the row
  // updates in place as the worker writes it, so QUEUED to RUNNING to DONE happens under their
  // eyes without anybody navigating anywhere.
  SpreadsheetApp.getActiveSpreadsheet().setActiveSheet(sheet);
  sheet.setActiveRange(sheet.getRange(sheet.getLastRow(), 1));

  // What is ahead, not only the position. A board refresh takes about thirteen minutes for a
  // mid-sized sport, and a bare "Position 2" does not explain the wait to the person waiting.
  var note = ahead <= 1
    ? 'The machine looks for new requests every 90 seconds, so it starts within about that.'
    : 'Position ' + ahead + '. Something is running ahead of it; a whole-sport refresh takes ' +
      'around fifteen minutes.';
  SpreadsheetApp.getUi().alert(
    'Queued ' + describe_(checkId, name) + '.\n\n' + note +
    '\n\nThis tab is now open, and the row updates itself as the run goes.' +
    '\n\nRequest ' + requestId);
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

  var statusCell = columnNumber_(sheet, 'Status');
  var status = String(sheet.getRange(row, statusCell).getValue() || '').trim().toUpperCase();
  if (status !== 'QUEUED' && status !== 'WAITING') {
    SpreadsheetApp.getUi().alert(
      'Only a QUEUED or WAITING request can be cancelled. This one is ' + (status || 'blank') + '.');
    return;
  }

  sheet.getRange(row, statusCell).setValue('CANCELLED');
  sheet.getRange(row, columnNumber_(sheet, 'Finished at')).setValue(stamp_());
  sheet.getRange(row, columnNumber_(sheet, 'Error')).setValue('Cancelled by ' + user);
}
