<#
.SYNOPSIS
    Runs registered queries from this repository against the Content Query Builder API.

.DESCRIPTION
    Resolves SQL from CheckIDs (wildcards allowed), a file or a literal string, substitutes
    {{PLACEHOLDER}} parameters, authenticates against the Content Query Builder and posts
    each statement to /api/relation-manager/execute-sql.

    One CheckID prints to the screen or to -OutFile. Several CheckIDs switch to batch mode:
    one file per check under -OutDir plus a _summary.csv, and a failing check no longer stops
    the run. Files are named after the CheckID, for example BMX-DQ-003.csv. Rows written to a
    file carry check_id and check_name as their first two columns.

    -Format xlsx collects a whole batch into a single workbook instead, one tab per check
    named after its "-- Name -" header and a _summary tab first. There the identity sits on
    row 1 rather than on every data row: A1 the CheckID, B1 the name, C1 the exact SQL that
    was sent, with the result table starting on row 3. Upload that file to Google Drive and
    open it as Sheets to get every check as its own tab.

    Credentials are never stored in this file. They are read from the environment:
        EP_QB_EMAIL     login email
        EP_QB_PASSWORD  login password
        EP_QB_COOKIE    optional, a ready session cookie such as
                        "XSRF-TOKEN=...; content-query-builder-session=..."
        EP_QB_URL       optional, base URL override
    TOOLS\secrets.local.ps1 is dot-sourced when present and may set any of them,
    which keeps them off the command line. It is excluded from git by .gitignore.
    When email or password is missing the script prompts for them interactively.
    The session cookie is cached in %LOCALAPPDATA%\entpulse-qb\session.xml and reused
    until the server rejects it.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-003 -SportId 58

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-* -SportId 58
    Runs the whole BMX catalogue into output\run_<timestamp>, one CSV per check.

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-001,BMX-DQ-002,BMX-DQ-003 -SportId 58 -OutDir .\out

.EXAMPLE
    .\TOOLS\Run-Query.ps1 BMX-DQ-* -SportId 58 -MaxChecks 5

.EXAMPLE
    .\TOOLS\Run-Query.ps1 GLOBAL-DISCOVERY-015 -Params SPORT_ID=58 -Format csv -OutFile .\out.csv

.EXAMPLE
    .\TOOLS\Run-Query.ps1 -Sql "SELECT COUNT(*) AS c FROM sport;" -Format json
#>
[CmdletBinding()]
param(
    # One or more CheckIDs. Wildcards are allowed: BMX-DQ-*, GLOBAL-*, *
    [Parameter(Position = 0)]
    [string[]]$CheckId,

    [string]$File,

    [string]$Sql,

    # Shorthand for the {{SPORT_ID}} placeholder, which nearly every check uses.
    [int]$SportId,

    # Remaining placeholders, either NAME=VALUE strings or a hashtable.
    [object]$Params,

    [ValidateSet('table', 'json', 'csv', 'xlsx')]
    [string]$Format = 'table',

    # Single check, or any number of checks when -Format is xlsx. Otherwise use -OutDir.
    [string]$OutFile,

    # Batch runs write one file per check here. Defaults to output\run_<timestamp>.
    [string]$OutDir,

    # Cap how many of the matched checks actually run. 0 means no cap.
    [int]$MaxChecks,

    [int]$Preview = 50,

    [switch]$DryRun,

    [switch]$ListChecks,

    # Prints the full command set. The cqb wrapper maps a bare "info" onto this.
    [switch]$Info,

    [switch]$Relogin
)

$ErrorActionPreference = 'Stop'

# Local, git-ignored credential file. Loaded before anything reads EP_QB_*, so it
# can supply the login, a session cookie or a different base URL.
$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path $SecretsPath) { . $SecretsPath }

$BaseUrl = $env:EP_QB_URL
if ([string]::IsNullOrWhiteSpace($BaseUrl)) { $BaseUrl = 'http://spcdev.enetpulse.com:19080' }
$BaseUrl = $BaseUrl.TrimEnd('/')

$ExecuteUrl = "$BaseUrl/api/relation-manager/execute-sql"
$LoginUrl = "$BaseUrl/login"
$LoginPageUrl = "$BaseUrl/app/pool"

$RepoRoot = Split-Path -Parent $PSScriptRoot
$StateDir = Join-Path $env:LOCALAPPDATA 'entpulse-qb'
$StatePath = Join-Path $StateDir 'session.xml'

# Small pause between statements in a batch, so a long catalogue does not hammer the API.
$BatchDelayMs = 250

# Hoisted out of the cell writer, which runs once per cell across thousands of rows.
$XlsxNumericTypes = @([int], [long], [double], [decimal], [single], [int16], [uint16], [uint32], [uint64], [byte], [sbyte])
$XlsxInvariant = [Globalization.CultureInfo]::InvariantCulture
$XlsxCellLimit = 32767

# --------------------------------------------------------------------------------------
# Query resolution
# --------------------------------------------------------------------------------------

function Get-QuerySourceFiles {
    $dirs = @(
        (Join-Path $RepoRoot 'GLOBAL_QUERIES'),
        (Join-Path $RepoRoot 'POWERBI_QUERIES')
    )
    $files = @()
    foreach ($d in $dirs) {
        if (Test-Path $d) {
            $files += Get-ChildItem -Path $d -Filter *.sql -File
        }
    }
    return $files
}

function Get-CheckCatalogue {
    # Every registered check, with the SQL body attached. Statements are separated by the
    # "-- ====..." banner lines used across the repo.
    $catalogue = @()

    foreach ($f in Get-QuerySourceFiles) {
        $raw = Get-Content -LiteralPath $f.FullName -Raw

        # CheckID -> line number, so -ListChecks can point straight at the source.
        $lineOf = @{}
        $n = 0
        foreach ($line in ($raw -split "\r?\n")) {
            $n++
            $m = [regex]::Match($line, '^\s*--\s*CheckID\s*[-:]\s*(\S+)\s*$')
            if ($m.Success -and -not $lineOf.ContainsKey($m.Groups[1].Value)) {
                $lineOf[$m.Groups[1].Value] = $n
            }
        }

        foreach ($block in [regex]::Split($raw, '(?m)^--\s*={10,}\s*\r?$')) {
            $idMatch = [regex]::Match($block, '(?m)^\s*--\s*CheckID\s*[-:]\s*(\S+)\s*$')
            if (-not $idMatch.Success) { continue }

            $id = $idMatch.Groups[1].Value
            $nameMatch = [regex]::Match($block, '(?m)^\s*--\s*Name\s*[-:]\s*(.+?)\s*$')

            $catalogue += [pscustomobject]@{
                CheckId = $id
                Name    = $(if ($nameMatch.Success) { $nameMatch.Groups[1].Value } else { '' })
                File    = $f.Name
                Line    = $(if ($lineOf.ContainsKey($id)) { $lineOf[$id] } else { 0 })
                Path    = $f.FullName
                Sql     = $block.Trim()
            }
        }
    }

    return $catalogue
}

function Select-Checks {
    param([string[]]$Patterns)

    $catalogue = Get-CheckCatalogue
    $selected = @()

    foreach ($pattern in $Patterns) {
        $hits = @($catalogue | Where-Object { $_.CheckId -like $pattern } | Sort-Object CheckId)
        if ($hits.Count -eq 0) {
            throw "No CheckID matches '$pattern'. Use -ListChecks to see available IDs."
        }
        $selected += $hits
    }

    # A CheckID living in two files is a repository error, not something to guess about.
    $duplicate = $selected | Group-Object CheckId | Where-Object { $_.Count -gt 1 } | Select-Object -First 1
    if ($duplicate) {
        $where = ($duplicate.Group | ForEach-Object { $_.File } | Select-Object -Unique) -join ', '
        if (($duplicate.Group | ForEach-Object { $_.File } | Select-Object -Unique).Count -gt 1) {
            throw "CheckID '$($duplicate.Name)' is ambiguous, found in: $where"
        }
    }

    # Overlapping patterns must not run the same check twice.
    $seen = @{}
    $unique = @()
    foreach ($check in $selected) {
        if (-not $seen.ContainsKey($check.CheckId)) {
            $seen[$check.CheckId] = $true
            $unique += $check
        }
    }

    # No comma wrapper here: the caller re-wraps with @(), and the two together nest.
    return $unique
}

function ConvertTo-ParamTable {
    # Accepts @{ SPORT_ID = 58 } as well as the friendlier SPORT_ID=58,FROM_ID=100 form.
    param($Value)

    $table = @{}
    if ($null -eq $Value) { return $table }

    if ($Value -is [hashtable]) {
        foreach ($key in $Value.Keys) { $table[[string]$key] = $Value[$key] }
        return $table
    }

    foreach ($item in @($Value)) {
        $text = [string]$item
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        $split = $text.IndexOf('=')
        if ($split -lt 1) {
            throw "Cannot read parameter '$text'. Use NAME=VALUE, for example -Params SPORT_ID=58"
        }
        $table[$text.Substring(0, $split).Trim()] = $text.Substring($split + 1).Trim()
    }

    return $table
}

function Expand-Placeholders {
    param([string]$Text, [hashtable]$Values)

    $result = [regex]::Replace($Text, '\{\{\s*(\w+)\s*\}\}', {
            param($m)
            $key = $m.Groups[1].Value
            if ($Values.ContainsKey($key)) { return [string]$Values[$key] }
            return $m.Value
        })

    $missing = @([regex]::Matches($result, '\{\{\s*(\w+)\s*\}\}') |
        ForEach-Object { $_.Groups[1].Value } |
        Select-Object -Unique)

    if ($missing.Count -gt 0) {
        $hint = if ($missing -contains 'SPORT_ID') { '-SportId 58' } else { "-Params $($missing[0])=<value>" }
        throw "Missing parameter value(s): $($missing -join ', '). Pass them like: $hint"
    }
    return $result
}

# --------------------------------------------------------------------------------------
# Session handling
# --------------------------------------------------------------------------------------

function New-EmptySession {
    return New-Object Microsoft.PowerShell.Commands.WebRequestSession
}

function Add-CookieToSession {
    param($Session, [string]$Name, [string]$Value)

    $uri = [uri]$BaseUrl
    $cookie = New-Object System.Net.Cookie($Name, $Value, '/', $uri.Host)
    $Session.Cookies.Add($cookie)
}

function Save-SessionState {
    param($Session)

    if (-not (Test-Path $StateDir)) { New-Item -ItemType Directory -Path $StateDir | Out-Null }
    $uri = [uri]$BaseUrl

    # Keep the newest cookie per name, otherwise a stale duplicate can win on restore.
    $latest = [ordered]@{}
    foreach ($c in $Session.Cookies.GetCookies($uri)) { $latest[$c.Name] = $c.Value }

    $bag = @()
    foreach ($name in $latest.Keys) { $bag += @{ Name = $name; Value = $latest[$name] } }
    $bag | Export-Clixml -Path $StatePath
}

function Restore-SessionState {
    if (-not (Test-Path $StatePath)) { return $null }
    try {
        $bag = Import-Clixml -Path $StatePath
    }
    catch {
        return $null
    }
    if (-not $bag) { return $null }

    $session = New-EmptySession
    foreach ($c in $bag) { Add-CookieToSession -Session $session -Name $c.Name -Value $c.Value }
    return $session
}

function Get-LoginCredential {
    $email = $env:EP_QB_EMAIL
    if ([string]::IsNullOrWhiteSpace($email)) {
        $email = Read-Host 'Content Query Builder email'
    }

    $password = $env:EP_QB_PASSWORD
    if ([string]::IsNullOrWhiteSpace($password)) {
        $secure = Read-Host 'Password' -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try { $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
        finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
    }

    return @{ Email = $email; Password = $password }
}

function New-AuthenticatedSession {
    # A pasted session cookie wins over an interactive login.
    if (-not [string]::IsNullOrWhiteSpace($env:EP_QB_COOKIE)) {
        $session = New-EmptySession
        foreach ($part in ($env:EP_QB_COOKIE -split ';')) {
            $kv = $part.Trim()
            if ($kv -match '^([^=]+)=(.*)$') {
                Add-CookieToSession -Session $session -Name $matches[1].Trim() -Value $matches[2].Trim()
            }
        }
        Write-Host 'Using session cookie from EP_QB_COOKIE.' -ForegroundColor DarkGray
        return $session
    }

    Write-Host 'Logging in...' -ForegroundColor DarkGray

    $session = New-EmptySession
    $page = Invoke-WebRequest -Uri $LoginPageUrl -WebSession $session -UseBasicParsing -TimeoutSec 30

    $tokenMatch = [regex]::Match($page.Content, 'name="_token"\s+value="([^"]+)"')
    if (-not $tokenMatch.Success) {
        throw 'Could not read the CSRF _token from the login page. The login form may have changed.'
    }

    $cred = Get-LoginCredential
    $body = @{
        _token   = $tokenMatch.Groups[1].Value
        email    = $cred.Email
        password = $cred.Password
        remember = 'on'
    }

    $response = Invoke-WebRequest -Uri $LoginUrl -Method POST -Body $body -WebSession $session `
        -UseBasicParsing -TimeoutSec 30

    # A successful login redirects away from /login; a failed one re-renders the form.
    $landedOnLogin = $false
    if ($response.BaseResponse -and $response.BaseResponse.ResponseUri) {
        $landedOnLogin = $response.BaseResponse.ResponseUri.AbsolutePath -match '(?i)/login/?$'
    }

    if ($landedOnLogin -or ($response.Content -match 'name="_token"' -and $response.Content -match '(?i)log ?in')) {
        # Laravel puts the reason in the validation block, which is far more useful
        # than guessing which of the two settings is wrong.
        $reasonMatch = [regex]::Match($response.Content,
            '(?is)<(?:div|span|p|strong|li)[^>]*(?:invalid-feedback|alert|error|danger)[^>]*>(.*?)</(?:div|span|p|strong|li)>')
        if ($reasonMatch.Success) {
            $reason = ((($reasonMatch.Groups[1].Value -replace '<[^>]+>', '') -replace '\s+', ' ').Trim())
            if ($reason) {
                throw "Login failed for '$($cred.Email)': $reason  (check TOOLS\secrets.local.ps1)"
            }
        }
        throw 'Login failed. Check EP_QB_EMAIL and EP_QB_PASSWORD.'
    }

    Save-SessionState -Session $session
    return $session
}

function Get-XsrfHeaderValue {
    param($Session)

    $uri = [uri]$BaseUrl
    foreach ($c in $Session.Cookies.GetCookies($uri)) {
        if ($c.Name -eq 'XSRF-TOKEN') {
            return [uri]::UnescapeDataString($c.Value)
        }
    }
    return $null
}

# --------------------------------------------------------------------------------------
# Execution
# --------------------------------------------------------------------------------------

function Invoke-RemoteSql {
    param($Session, [string]$Statement)

    $headers = @{
        'accept'           = 'application/json'
        'X-Requested-With' = 'XMLHttpRequest'
        'Referer'          = $LoginPageUrl
    }
    $xsrf = Get-XsrfHeaderValue -Session $Session
    if ($xsrf) { $headers['X-XSRF-TOKEN'] = $xsrf }

    $body = 'sql=' + [uri]::EscapeDataString($Statement)

    return Invoke-WebRequest -Uri $ExecuteUrl -Method POST -Body $body `
        -ContentType 'application/x-www-form-urlencoded' -Headers $headers `
        -WebSession $Session -UseBasicParsing -TimeoutSec 300
}

function Get-ErrorDetail {
    # A rejected statement comes back as HTTP 500 with the MySQL message in the
    # body, which Invoke-WebRequest hides behind a generic exception.
    param($ErrorRecord)

    $response = $ErrorRecord.Exception.Response
    if ($null -eq $response) { return $null }

    $body = $null
    try {
        $reader = New-Object System.IO.StreamReader($response.GetResponseStream())
        try { $body = $reader.ReadToEnd() } finally { $reader.Dispose() }
    }
    catch { return $null }

    if ([string]::IsNullOrWhiteSpace($body)) { return $null }

    $detail = $body
    try {
        $parsed = $body | ConvertFrom-Json
        foreach ($name in @('response', 'error', 'message', 'exception')) {
            if ($parsed.PSObject.Properties.Name -contains $name -and $parsed.$name -is [string]) {
                $detail = $parsed.$name
                break
            }
        }
    }
    catch { }

    $detail = ($detail -replace '\s+', ' ').Trim()
    if ($detail.Length -gt 800) { $detail = $detail.Substring(0, 800) + '...' }
    return $detail
}

function Invoke-SqlWithRetry {
    # Uses and refreshes $script:Session so a batch survives an expiring cookie.
    param([string]$Statement)

    try {
        return Invoke-RemoteSql -Session $script:Session -Statement $Statement
    }
    catch {
        $status = 0
        if ($_.Exception.Response) { $status = [int]$_.Exception.Response.StatusCode }

        if ($status -eq 401 -or $status -eq 403 -or $status -eq 419) {
            Write-Host "Session rejected (HTTP $status), logging in again..." -ForegroundColor DarkGray
            if (Test-Path $StatePath) { Remove-Item -LiteralPath $StatePath -Force }
            $script:Session = New-AuthenticatedSession
            return Invoke-RemoteSql -Session $script:Session -Statement $Statement
        }

        $detail = Get-ErrorDetail -ErrorRecord $_
        if ($detail) { throw "Query failed (HTTP $status): $detail" }
        throw
    }
}

function Get-ResultRows {
    param([string]$Content)

    try {
        $parsed = $Content | ConvertFrom-Json
    }
    catch {
        throw "Server did not return JSON. First 300 characters:`n" + $Content.Substring(0, [Math]::Min(300, $Content.Length))
    }

    if ($parsed -is [array]) { return , $parsed }

    # The app wraps results as { "sql": "<echo>", "response": [ {col: val}, ... ] }.
    # A string or object under that key is an error message, not a result set.
    foreach ($name in @('response', 'data', 'rows', 'result', 'results', 'records')) {
        if ($parsed.PSObject.Properties.Name -contains $name) {
            $value = $parsed.$name
            if ($null -eq $value) { return , @() }
            if ($value -is [string]) { throw "Query API returned an error: $value" }
            if ($value -is [array]) { return , $value }
            return , @($value)
        }
    }

    foreach ($name in @('error', 'message', 'exception')) {
        if ($parsed.PSObject.Properties.Name -contains $name) {
            throw "Query API returned an error: $($parsed.$name)"
        }
    }

    return , @($parsed)
}

function Add-CheckColumns {
    # Exported rows stay identifiable once they are out of this shell.
    param($Rows, [string]$CheckId, [string]$Name)

    if ([string]::IsNullOrWhiteSpace($CheckId)) { return , @($Rows) }

    $tagged = @()
    foreach ($row in $Rows) {
        $ordered = [ordered]@{ check_id = $CheckId; check_name = $Name }
        foreach ($property in $row.PSObject.Properties) { $ordered[$property.Name] = $property.Value }
        $tagged += [pscustomobject]$ordered
    }
    return , $tagged
}

function Get-SafeFileName {
    param([string]$CheckId)

    $stem = [regex]::Replace($CheckId, '[^A-Za-z0-9._-]+', '_')
    if (-not $stem) { $stem = 'query' }
    if ($stem.Length -gt 120) { $stem = $stem.Substring(0, 120) }
    return $stem
}

# --------------------------------------------------------------------------------------
# Workbook writing
#
# An .xlsx is a zip of XML parts, so it can be produced with nothing but the .NET
# libraries that ship with Windows. That keeps the tool working on a machine with
# neither Excel nor the ImportExcel module installed.
# --------------------------------------------------------------------------------------

function Get-ExcelColumnName {
    param([int]$Index)

    $name = ''
    while ($Index -gt 0) {
        $remainder = ($Index - 1) % 26
        $name = [char](65 + $remainder) + $name
        $Index = [int](($Index - $remainder - 1) / 26)
    }
    return $name
}

function ConvertTo-XmlText {
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return '' }
    # Control characters are not representable in XML 1.0 and would corrupt the part.
    $clean = [regex]::Replace($Text, '[\x00-\x08\x0B\x0C\x0E-\x1F]', '')
    return [Security.SecurityElement]::Escape($clean)
}

function ConvertTo-SheetName {
    # Excel caps sheet names at 31 characters, forbids : \ / ? * [ ] and demands
    # uniqueness. Google Sheets keeps whatever names the file carries.
    param([string]$Preferred, [string]$Fallback, [hashtable]$Used)

    $name = $Preferred
    if ([string]::IsNullOrWhiteSpace($name)) { $name = $Fallback }
    $name = [regex]::Replace($name, '[:\\/?*\[\]]', '_').Trim()
    if ($name.Length -gt 31) { $name = $name.Substring(0, 31) }
    if ([string]::IsNullOrWhiteSpace($name)) { $name = 'sheet' }

    $base = $name
    $counter = 2
    while ($Used.ContainsKey($name.ToLowerInvariant())) {
        $suffix = "~$counter"
        $keep = [Math]::Min($base.Length, 31 - $suffix.Length)
        $name = $base.Substring(0, $keep) + $suffix
        $counter++
    }

    $Used[$name.ToLowerInvariant()] = $true
    return $name
}

function Get-CellXml {
    param([string]$Reference, $Value)

    if ($null -eq $Value) { return '' }

    if ($XlsxNumericTypes -contains $Value.GetType()) {
        # Invariant formatting, or a bg-BG decimal comma would make Excel read
        # the number as text.
        return '<c r="{0}"><v>{1}</v></c>' -f $Reference, [string]::Format($XlsxInvariant, '{0}', $Value)
    }

    $raw = [string]$Value
    if ($raw -eq '') { return '' }

    # Excel refuses to open a file containing an over-long cell. Trim the text
    # itself, before escaping inflates it.
    if ($raw.Length -gt $XlsxCellLimit) {
        $raw = $raw.Substring(0, $XlsxCellLimit - 20) + ' ...[truncated]'
    }

    return '<c r="{0}" t="inlineStr"><is><t xml:space="preserve">{1}</t></is></c>' -f `
        $Reference, (ConvertTo-XmlText -Text $raw)
}

function Add-ZipTextEntry {
    param($Zip, [string]$Name, [string]$Content)

    $entry = $Zip.CreateEntry($Name)
    $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.UTF8Encoding($false)))
    try { $writer.Write($Content) } finally { $writer.Dispose() }
}

function Save-Workbook {
    # $Sheets is a list of objects carrying a Name and a Rows collection.
    param($Sheets, [string]$Path)

    Add-Type -AssemblyName System.IO.Compression | Out-Null
    Add-Type -AssemblyName System.IO.Compression.FileSystem | Out-Null

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    if (Test-Path $Path) { Remove-Item -LiteralPath $Path -Force }

    $stream = [IO.File]::Create($Path)
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create)

    try {
        $overrides = New-Object Text.StringBuilder
        $sheetTags = New-Object Text.StringBuilder
        $relTags = New-Object Text.StringBuilder

        $index = 0
        foreach ($sheet in $Sheets) {
            $index++
            $rows = @($sheet.Rows)

            # Columns are unioned across rows, because a later row may carry a key
            # the first one lacked.
            $columns = @()
            foreach ($row in $rows) {
                foreach ($property in $row.PSObject.Properties) {
                    if ($columns -notcontains $property.Name) { $columns += $property.Name }
                }
            }

            $xml = New-Object Text.StringBuilder
            [void]$xml.Append('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
            [void]$xml.Append('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>')

            # Identity lives once on row 1 rather than repeated down every data row.
            # Row 2 is deliberately skipped: sheetData tolerates gaps, and the blank
            # line keeps the table below a self-contained block for sorting and
            # filtering. OOXML row numbering must still ascend.
            # @($null) yields a one-element array, so test for the null before wrapping,
            # or a sheet without metadata gains a blank row 1.
            $header = if ($null -eq $sheet.Header) { @() } else { @($sheet.Header) }
            $headerRow = ($header.Count -gt 0)

            if ($headerRow) {
                [void]$xml.Append('<row r="1">')
                for ($c = 0; $c -lt $header.Count; $c++) {
                    [void]$xml.Append((Get-CellXml -Reference ((Get-ExcelColumnName -Index ($c + 1)) + '1') -Value $header[$c]))
                }
                [void]$xml.Append('</row>')
            }

            $rowNumber = if ($headerRow) { 3 } else { 1 }

            [void]$xml.Append(('<row r="{0}">' -f $rowNumber))
            for ($c = 0; $c -lt $columns.Count; $c++) {
                $ref = (Get-ExcelColumnName -Index ($c + 1)) + $rowNumber
                [void]$xml.Append((Get-CellXml -Reference $ref -Value $columns[$c]))
            }
            [void]$xml.Append('</row>')

            foreach ($row in $rows) {
                $rowNumber++
                [void]$xml.Append(('<row r="{0}">' -f $rowNumber))

                for ($c = 0; $c -lt $columns.Count; $c++) {
                    $ref = (Get-ExcelColumnName -Index ($c + 1)) + $rowNumber
                    [void]$xml.Append((Get-CellXml -Reference $ref -Value $row.($columns[$c])))
                }

                [void]$xml.Append('</row>')
            }

            [void]$xml.Append('</sheetData></worksheet>')
            Add-ZipTextEntry -Zip $zip -Name "xl/worksheets/sheet$index.xml" -Content $xml.ToString()

            [void]$overrides.Append(('<Override PartName="/xl/worksheets/sheet{0}.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>' -f $index))
            [void]$sheetTags.Append(('<sheet name="{0}" sheetId="{1}" r:id="rId{1}"/>' -f (ConvertTo-XmlText -Text $sheet.Name), $index))
            [void]$relTags.Append(('<Relationship Id="rId{0}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet{0}.xml"/>' -f $index))
        }

        Add-ZipTextEntry -Zip $zip -Name '[Content_Types].xml' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' +
            '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' +
            '<Default Extension="xml" ContentType="application/xml"/>' +
            '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' +
            $overrides.ToString() + '</Types>')

        Add-ZipTextEntry -Zip $zip -Name '_rels/.rels' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' +
            '</Relationships>')

        Add-ZipTextEntry -Zip $zip -Name 'xl/workbook.xml' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" ' +
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets>' +
            $sheetTags.ToString() + '</sheets></workbook>')

        Add-ZipTextEntry -Zip $zip -Name 'xl/_rels/workbook.xml.rels' -Content (
            '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' +
            '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' +
            $relTags.ToString() + '</Relationships>')
    }
    finally {
        $zip.Dispose()
        $stream.Dispose()
    }
}

function Save-Rows {
    param($Rows, [string]$Path, [string]$Fmt, [string]$SheetName = 'data', $Header)

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }

    if ($Fmt -eq 'xlsx') {
        Save-Workbook -Path $Path -Sheets @([pscustomobject]@{
                Name   = $SheetName
                Rows   = $Rows
                Header = $Header
            })
    }
    elseif ($Fmt -eq 'json') {
        $Rows | ConvertTo-Json -Depth 8 | Out-File -LiteralPath $Path -Encoding utf8
    }
    else {
        $Rows | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding UTF8
    }
}

# --------------------------------------------------------------------------------------
# Main
# --------------------------------------------------------------------------------------

if ($Info) {
    # The wrapper function announces itself through EP_QB_COMMAND so the examples
    # below show what the reader actually types.
    $Entry = if ($env:EP_QB_COMMAND) { $env:EP_QB_COMMAND } else { '.\TOOLS\Run-Query.ps1' }

    $catalogue = Get-CheckCatalogue
    $sources = ($catalogue | Group-Object File | Sort-Object Name |
        ForEach-Object { "$($_.Name) ($($_.Count))" }) -join ', '

    function Write-Section { param([string]$Title) Write-Host "`n$Title" -ForegroundColor Cyan }
    function Write-Line {
        param([string]$Command, [string]$Explains)

        $column = 54
        $text = '  ' + $Command

        # A long example would otherwise run straight into its explanation.
        if ($text.Length -ge $column) {
            Write-Host $text -ForegroundColor White
            Write-Host ((' ' * $column) + $Explains) -ForegroundColor DarkGray
            return
        }

        Write-Host $text.PadRight($column) -ForegroundColor White -NoNewline
        Write-Host $Explains -ForegroundColor DarkGray
    }

    Write-Host "`nContent Query Builder runner" -ForegroundColor Green
    Write-Host "  server    $BaseUrl" -ForegroundColor DarkGray
    Write-Host "  script    $PSCommandPath" -ForegroundColor DarkGray
    Write-Host "  checks    $($catalogue.Count) in $sources" -ForegroundColor DarkGray
    Write-Host "  login     $(if ($env:EP_QB_COOKIE) { 'EP_QB_COOKIE' } elseif ($env:EP_QB_EMAIL) { $env:EP_QB_EMAIL } else { 'not configured' })" -ForegroundColor DarkGray

    Write-Section 'FIND CHECKS'
    # The bare "info" word is the wrapper's doing; the script itself needs the switch.
    Write-Line $(if ($env:EP_QB_COMMAND) { "$Entry info" } else { "$Entry -Info" }) 'this page'
    Write-Line "$Entry -ListChecks" 'every CheckID with its name and source line'
    Write-Line "$Entry -ListChecks BMX-DQ-0*" 'filter the list by wildcard'

    Write-Section 'RUN ONE'
    Write-Line "$Entry BMX-DQ-003 -SportId 58" 'to the screen'
    Write-Line "$Entry BMX-DQ-003 -SportId 58 -Preview 200" 'show more than the default 50 rows'
    Write-Line "$Entry BMX-DQ-003 -SportId 58 -OutFile .\out.csv" 'to a file, tagged with check_id'
    Write-Line "$Entry BMX-DQ-003 -SportId 58 -DryRun" 'print the SQL, send nothing'

    Write-Section 'RUN MANY'
    Write-Line "$Entry BMX-DQ-001,BMX-DQ-005 -SportId 58" 'a chosen few'
    Write-Line "$Entry BMX-DQ-* -SportId 58" 'the whole BMX catalogue'
    Write-Line "$Entry BMX-DQ-* -SportId 58 -MaxChecks 10" 'only the first 10 matches'
    Write-Line "$Entry * -SportId 58" 'everything'
    Write-Line "$Entry BMX-DQ-* -SportId 58 -OutDir .\out" 'choose the target folder'
    Write-Line "$Entry BMX-DQ-* -SportId 58 -Format xlsx" 'one workbook, one tab per check'
    Write-Host '  Batch mode writes one file per check plus _summary.csv, and keeps' -ForegroundColor DarkGray
    Write-Host '  going when a check fails. Default folder: output\run_<timestamp>' -ForegroundColor DarkGray

    Write-Section 'PARAMETERS'
    Write-Line '-SportId 58' 'fills {{SPORT_ID}}, which nearly every check uses'
    Write-Line '-Params FROM_ID=100,TO_ID=200' 'any other {{PLACEHOLDER}}'
    Write-Line '-Params @{ SPORT_ID = 58 }' 'the hashtable form also works'

    Write-Section 'AD-HOC SQL'
    Write-Line "$Entry -Sql `"SELECT COUNT(*) AS c FROM sport;`"" 'run a literal statement'
    Write-Line "$Entry -File .\scratch.sql" 'run a file'
    Write-Host '  The server only accepts statements starting with SELECT or WITH.' -ForegroundColor DarkGray

    Write-Section 'OUTPUT'
    Write-Line '-Format table' 'default, on-screen preview'
    Write-Line '-Format csv' 'CSV, with check_id and check_name columns'
    Write-Line '-Format json' 'JSON, with check_id and check_name fields'
    Write-Line '-Format xlsx' 'one .xlsx, tabs named after each check, _summary first'
    Write-Host '  In a workbook A1/B1/C1 hold the CheckID, the name and the SQL that ran,' -ForegroundColor DarkGray
    Write-Host '  and the result table starts on row 3. CSV and JSON keep check_id and' -ForegroundColor DarkGray
    Write-Host '  check_name as columns, having nowhere else to put them.' -ForegroundColor DarkGray
    Write-Host '  Files are named after the CheckID: BMX-DQ-003.csv' -ForegroundColor DarkGray
    Write-Host '  Upload the .xlsx to Google Drive and open it as Sheets to get the tabs.' -ForegroundColor DarkGray

    Write-Section 'SESSION'
    Write-Line "$Entry ... -Relogin" 'throw away the cached cookie and log in again'
    Write-Host "  Credentials live in TOOLS\secrets.local.ps1 (git-ignored)." -ForegroundColor DarkGray
    Write-Host "  Cached cookie: $StatePath" -ForegroundColor DarkGray
    Write-Host ''
    return
}

if ($ListChecks) {
    $catalogue = Get-CheckCatalogue
    if ($CheckId) {
        $catalogue = @($catalogue | Where-Object {
                $id = $_.CheckId
                @($CheckId | Where-Object { $id -like $_ }).Count -gt 0
            })
    }
    $catalogue | Sort-Object CheckId | Format-Table CheckId, Name, File, Line -AutoSize
    return
}

# ----- what to run ---------------------------------------------------------------------

if ($Sql) {
    $jobs = @([pscustomobject]@{ CheckId = ''; Name = ''; Sql = $Sql })
}
elseif ($File) {
    $jobs = @([pscustomobject]@{
            CheckId = [IO.Path]::GetFileNameWithoutExtension($File)
            Name    = ''
            Sql     = (Get-Content -LiteralPath $File -Raw)
        })
}
elseif ($CheckId) {
    $jobs = @(Select-Checks -Patterns $CheckId)
}
else {
    throw 'Nothing to run. Pass a CheckID, -File or -Sql. Use -ListChecks to list registered CheckIDs.'
}

if ($MaxChecks -gt 0 -and $jobs.Count -gt $MaxChecks) {
    Write-Host "Matched $($jobs.Count) checks, running the first $MaxChecks." -ForegroundColor DarkGray
    $jobs = $jobs[0..($MaxChecks - 1)]
}

# ----- parameters ----------------------------------------------------------------------

$paramTable = ConvertTo-ParamTable -Value $Params
if ($PSBoundParameters.ContainsKey('SportId')) { $paramTable['SPORT_ID'] = $SportId }

foreach ($job in $jobs) {
    $job.Sql = Expand-Placeholders -Text $job.Sql -Values $paramTable
}

$isBatch = $jobs.Count -gt 1

if ($DryRun) {
    if ($isBatch) {
        Write-Host "--- $($jobs.Count) checks that would run ---" -ForegroundColor DarkGray
        $jobs | Format-Table CheckId, Name -AutoSize
    }
    else {
        Write-Host "--- SQL that would be sent ($($jobs[0].CheckId)) ---" -ForegroundColor DarkGray
        Write-Output $jobs[0].Sql
    }
    return
}

$isWorkbook = $Format -eq 'xlsx'

if ($isBatch -and $OutFile -and -not $isWorkbook) {
    throw "-OutFile takes a single check because column layouts differ per check. Use -OutDir, or -Format xlsx to collect every check into one workbook."
}

# ----- session -------------------------------------------------------------------------

if ($Relogin -and (Test-Path $StatePath)) { Remove-Item -LiteralPath $StatePath -Force }

$script:Session = $null
if (-not $Relogin) { $script:Session = Restore-SessionState }
if ($null -eq $script:Session) { $script:Session = New-AuthenticatedSession }

# ----- batch run -----------------------------------------------------------------------

if ($isBatch) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

    if ($isWorkbook) {
        # One workbook for the whole run, so it can be uploaded as a single file.
        $workbookPath = $OutFile
        if (-not $workbookPath) {
            $folder = if ($OutDir) { $OutDir } else { Join-Path $RepoRoot 'output' }
            $workbookPath = Join-Path $folder "checks_$stamp.xlsx"
        }
        Write-Host "Running $($jobs.Count) checks into $workbookPath" -ForegroundColor DarkGray
    }
    else {
        if (-not $OutDir) { $OutDir = Join-Path $RepoRoot "output\run_$stamp" }
        if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }
        $extension = if ($Format -eq 'json') { '.json' } else { '.csv' }
        Write-Host "Running $($jobs.Count) checks into $OutDir" -ForegroundColor DarkGray
    }

    $summary = @()
    $collected = @()
    $index = 0

    foreach ($job in $jobs) {
        $index++
        $started = Get-Date
        $rowCount = 0
        $status = 'OK'

        try {
            $response = Invoke-SqlWithRetry -Statement $job.Sql
            $rows = Get-ResultRows -Content $response.Content
            $rowCount = @($rows).Count

            if ($rowCount -gt 0) {
                if ($isWorkbook) {
                    # A workbook names the check on the tab and on row 1, so the rows
                    # themselves stay clean.
                    $collected += [pscustomobject]@{ Job = $job; Rows = $rows }
                }
                else {
                    # A flat file has nowhere else to record which check a row came from.
                    $tagged = Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name
                    $target = Join-Path $OutDir ((Get-SafeFileName -CheckId $job.CheckId) + $extension)
                    Save-Rows -Rows $tagged -Path $target -Fmt $Format
                }
            }
            else {
                $status = 'clean'
            }
        }
        catch {
            $status = "ERROR: $($_.Exception.Message)"
        }

        $elapsed = ((Get-Date) - $started).TotalSeconds
        $summary += [pscustomobject]@{
            CheckId = $job.CheckId
            Name    = $job.Name
            Rows    = $rowCount
            Seconds = [math]::Round($elapsed, 1)
            Status  = $status
        }

        $colour = if ($status -like 'ERROR*') { 'Red' } else { 'DarkGray' }
        Write-Host ("[{0}/{1}] {2}  rows={3}  {4:n1}s  {5}" -f `
                $index, $jobs.Count, $job.CheckId, $rowCount, $elapsed, $status) -ForegroundColor $colour

        if ($index -lt $jobs.Count) { Start-Sleep -Milliseconds $BatchDelayMs }
    }

    Save-SessionState -Session $script:Session

    if ($isWorkbook) {
        # The summary leads, so a clean or failed check is still visible in the
        # workbook even though it has no tab of its own.
        $used = @{}
        $sheets = @([pscustomobject]@{
                Name   = (ConvertTo-SheetName -Preferred '_summary' -Fallback '_summary' -Used $used)
                Rows   = $summary
                Header = $null
            })

        $shortened = @()
        foreach ($item in $collected) {
            $preferred = if ($item.Job.Name) { $item.Job.Name } else { $item.Job.CheckId }
            $sheetName = ConvertTo-SheetName -Preferred $preferred -Fallback $item.Job.CheckId -Used $used
            if ($sheetName -ne $preferred) {
                $shortened += [pscustomobject]@{ CheckId = $item.Job.CheckId; Wanted = $preferred; Tab = $sheetName }
            }
            $sheets += [pscustomobject]@{
                Name   = $sheetName
                Rows   = $item.Rows
                Header = @($item.Job.CheckId, $item.Job.Name, $item.Job.Sql)
            }
        }

        Save-Workbook -Sheets $sheets -Path $workbookPath
        $destination = $workbookPath
    }
    else {
        $summary | Export-Csv -LiteralPath (Join-Path $OutDir '_summary.csv') -NoTypeInformation -Encoding UTF8
        $destination = $OutDir
    }

    $summary | Format-Table CheckId, Name, Rows, Seconds, Status -AutoSize

    if ($isWorkbook -and $shortened.Count -gt 0) {
        Write-Host "Tab names capped at Excel's 31-character limit:" -ForegroundColor DarkGray
        $shortened | Format-Table CheckId, Wanted, Tab -AutoSize
    }

    $failed = @($summary | Where-Object { $_.Status -like 'ERROR*' }).Count
    $totalRows = ($summary | Measure-Object Rows -Sum).Sum
    Write-Host ("Done: {0} checks, {1} rows, {2} failed -> {3}" -f `
            $jobs.Count, $totalRows, $failed, $destination) -ForegroundColor DarkGray
    return
}

# ----- single run ----------------------------------------------------------------------

$job = $jobs[0]
if ($job.CheckId) {
    Write-Host "Query: $($job.CheckId)  $($job.Name)" -ForegroundColor DarkGray
}

$started = Get-Date
$response = Invoke-SqlWithRetry -Statement $job.Sql
$elapsed = (Get-Date) - $started

Save-SessionState -Session $script:Session

$rows = Get-ResultRows -Content $response.Content
$count = @($rows).Count
Write-Host ("Rows: {0}   Elapsed: {1:n1}s" -f $count, $elapsed.TotalSeconds) -ForegroundColor DarkGray

# A workbook cannot be printed, so it always lands somewhere on disk.
if ($isWorkbook -and -not $OutFile) {
    $folder = if ($OutDir) { $OutDir } else { Join-Path $RepoRoot 'output' }
    $OutFile = Join-Path $folder ((Get-SafeFileName -CheckId $job.CheckId) + '.xlsx')
}

if ($OutFile) {
    $used = @{}
    $preferred = if ($job.Name) { $job.Name } else { $job.CheckId }
    $sheetName = ConvertTo-SheetName -Preferred $preferred -Fallback 'data' -Used $used

    if ($isWorkbook) {
        Save-Rows -Rows $rows -Path $OutFile -Fmt $Format -SheetName $sheetName `
            -Header @($job.CheckId, $job.Name, $job.Sql)
    }
    else {
        $tagged = Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name
        Save-Rows -Rows $tagged -Path $OutFile -Fmt $Format -SheetName $sheetName
    }

    Write-Host "Written: $OutFile" -ForegroundColor DarkGray
    return
}

switch ($Format) {
    'json' { Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name | ConvertTo-Json -Depth 8 }
    'csv' { Add-CheckColumns -Rows $rows -CheckId $job.CheckId -Name $job.Name | ConvertTo-Csv -NoTypeInformation }
    default {
        # The header line above already says which check this is, so the on-screen
        # table stays free of the repeated check_id / check_name columns.
        if ($count -gt $Preview) {
            Write-Host "Showing first $Preview of $count rows. Use -Format json or -OutFile for all." -ForegroundColor DarkGray
        }
        $rows | Select-Object -First $Preview | Format-Table -AutoSize
    }
}
