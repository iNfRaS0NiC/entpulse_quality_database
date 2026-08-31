<#
.SYNOPSIS
    One-time Google authorisation for the live per-sport Sheet.

.DESCRIPTION
    Run this once per machine. It opens a browser, waits for the account to approve, and
    writes the resulting refresh token into TOOLS/secrets.local.ps1, which .gitignore
    excludes. Every later run exchanges that token for an access token on its own, with no
    browser and no interaction.

    Nothing else in the package is interactive, which is why this is a script of its own
    rather than a switch on Run-Query.ps1: it opens a window, waits for a person, and is
    meant to be run once and forgotten.

    This file stays pure ASCII, as the other TOOLS scripts do: Windows PowerShell 5.1 reads a
    .ps1 without a BOM as ANSI, so a literal em dash would arrive mojibaked and fail to parse.

.PARAMETER Force
    Replace a refresh token that is already recorded. Without it an existing token is left
    alone, because re-authorising costs nothing but overwriting a working one silently is how
    a scheduled run starts failing for no visible reason.

.EXAMPLE
    .\TOOLS\Connect-Sheets.ps1
#>
[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Google requires TLS 1.2 and Windows PowerShell 5.1 still negotiates 1.0 by default on some
# machines, where the failure is an unhelpful "connection was closed" rather than a protocol
# error. Set before the first request rather than after the first mystery.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Shared with the runner: the same dead-IPv6 workaround, and the same scope, in one place.
. (Join-Path $PSScriptRoot 'Sheets.ps1')

$SecretsPath = Join-Path $PSScriptRoot 'secrets.local.ps1'
if (Test-Path -LiteralPath $SecretsPath) { . $SecretsPath }

$ClientId = $env:EP_SHEETS_CLIENT_ID
$ClientSecret = $env:EP_SHEETS_CLIENT_SECRET
$Scope = $SheetsScope
Set-SheetsAddressFamily -Uri 'https://oauth2.googleapis.com/token'

if ([string]::IsNullOrWhiteSpace($ClientId) -or [string]::IsNullOrWhiteSpace($ClientSecret)) {
    throw ("EP_SHEETS_CLIENT_ID and EP_SHEETS_CLIENT_SECRET must be set in $SecretsPath. " +
        'Both come from the Desktop OAuth client in Google Cloud Console, under ' +
        'APIs and Services -> Credentials.')
}

if (-not $Force -and -not [string]::IsNullOrWhiteSpace($env:EP_SHEETS_REFRESH_TOKEN)) {
    Write-Host 'A refresh token is already recorded. Nothing to do.' -ForegroundColor DarkGray
    Write-Host 'Use -Force to replace it - if it has stopped working, or to widen its scope.' -ForegroundColor DarkGray
    # The one reason a working token needs replacing. A refresh grant does not carry a scope,
    # so a token minted before a scope was added to $SheetsScope keeps the narrower grant for
    # ever and nothing fails until something tries to use the new one. The board never will.
    Write-Host ('  Scopes this package now asks for: ' + $Scope) -ForegroundColor DarkGray
    return
}

# A TcpListener rather than an HttpListener. HttpListener needs a URL reservation, so a
# non-elevated shell fails with an access denied that has nothing to do with Google, and
# telling somebody to run netsh as administrator to log in to a spreadsheet is not a setup
# step worth having. One GET is all this has to understand.
#
# Port 0 asks the OS for a free one, which is then read back. A Desktop OAuth client accepts
# any loopback port without registering it, so nothing here has to match the console.
$listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, 0)
$listener.Start()
$port = ([Net.IPEndPoint]$listener.LocalEndpoint).Port
$redirect = "http://127.0.0.1:$port"

# Guards against a stray request on the loopback port being read as the answer.
$state = [Guid]::NewGuid().ToString('N')

$authUrl = 'https://accounts.google.com/o/oauth2/v2/auth' +
    '?client_id=' + [uri]::EscapeDataString($ClientId) +
    '&redirect_uri=' + [uri]::EscapeDataString($redirect) +
    '&response_type=code' +
    '&scope=' + [uri]::EscapeDataString($Scope) +
    '&state=' + $state +
    # Both are required to be given a refresh token at all. Without access_type=offline
    # Google returns only an access token, and without prompt=consent it returns no refresh
    # token on any authorisation after the first for this client and account - so a second
    # run of this script would appear to succeed and record nothing.
    '&access_type=offline' +
    '&prompt=consent'

Write-Host ''
Write-Host 'Opening a browser to authorise the Google account.' -ForegroundColor Cyan
Write-Host 'Sign in with the account that can edit the sport documents.' -ForegroundColor Cyan
Write-Host ''
Write-Host 'If no window opens, paste this into a browser yourself:' -ForegroundColor DarkGray
Write-Host $authUrl -ForegroundColor DarkGray
Write-Host ''

try { Start-Process $authUrl | Out-Null } catch { }

Write-Host "Waiting on $redirect ..." -ForegroundColor DarkGray

# Not $error: that is an automatic variable holding PowerShell's own error history, and
# assigning to it here would clobber the record of anything that had already gone wrong.
$code = $null
$failure = $null
try {
    $client = $listener.AcceptTcpClient()
    try {
        $stream = $client.GetStream()
        $reader = New-Object IO.StreamReader($stream)

        # Only the request line matters: GET /?code=...&state=... HTTP/1.1
        $requestLine = $reader.ReadLine()
        $target = ''
        if ($requestLine -match '^GET\s+(\S+)\s+HTTP') { $target = $matches[1] }

        $query = @{}
        if ($target -match '\?(.*)$') {
            foreach ($pair in ($matches[1] -split '&')) {
                $bits = $pair -split '=', 2
                if ($bits.Count -eq 2) { $query[$bits[0]] = [uri]::UnescapeDataString($bits[1]) }
            }
        }

        if ($query['state'] -ne $state) {
            $failure = 'The reply did not carry the state this request sent, so it was not the answer to it.'
        }
        elseif ($query.ContainsKey('error')) {
            $failure = "Google returned: $($query['error'])"
        }
        elseif (-not $query.ContainsKey('code')) {
            $failure = 'Google returned no authorisation code.'
        }
        else {
            $code = $query['code']
        }

        # Deliberately not "Authorised". At this point only the code has arrived; the exchange
        # for a refresh token has not been attempted, and the token has not been written. An
        # earlier version said Authorised here, and the browser then announced success for a
        # run whose real outcome was still a second away and could have been a failure.
        $message = $(if ($code) { 'Code received. The terminal has the result.' }
            else { "Not authorised. $failure" })
        $html = "<!doctype html><meta charset=utf-8><title>Enetpulse</title>" +
            "<body style='font:16px system-ui;padding:3rem'><p>$message</p></body>"
        $bytes = [Text.Encoding]::UTF8.GetBytes($html)
        $header = "HTTP/1.1 200 OK`r`nContent-Type: text/html; charset=utf-8`r`n" +
            "Content-Length: $($bytes.Length)`r`nConnection: close`r`n`r`n"
        $headerBytes = [Text.Encoding]::ASCII.GetBytes($header)
        $stream.Write($headerBytes, 0, $headerBytes.Length)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
    }
    finally { $client.Close() }
}
finally { $listener.Stop() }

if (-not $code) { throw $failure }

Write-Host 'Authorised. Exchanging the code for a refresh token.' -ForegroundColor DarkGray

$response = Invoke-RestMethod -Method Post -Uri 'https://oauth2.googleapis.com/token' -Body @{
    code          = $code
    client_id     = $ClientId
    client_secret = $ClientSecret
    redirect_uri  = $redirect
    grant_type    = 'authorization_code'
}

if ([string]::IsNullOrWhiteSpace($response.refresh_token)) {
    throw ('Google returned an access token but no refresh token. That happens when the ' +
        'authorisation was not asked for offline access; re-run this script, which requests ' +
        'it explicitly.')
}

# Written into the file the runner already reads, rather than printed for copying: the token
# is long enough that a truncated paste is a real outcome, and the failure it produces is an
# invalid_grant three days later rather than an error at the time.
$line = "`$env:EP_SHEETS_REFRESH_TOKEN = '$($response.refresh_token)'"
$existing = $(if (Test-Path -LiteralPath $SecretsPath) {
        Get-Content -LiteralPath $SecretsPath -Raw -Encoding UTF8
    }
    else { '' })

if ($existing -match '(?m)^\s*\$env:EP_SHEETS_REFRESH_TOKEN\s*=.*$') {
    $existing = [regex]::Replace($existing, '(?m)^\s*\$env:EP_SHEETS_REFRESH_TOKEN\s*=.*$', $line)
}
else {
    if ($existing.Length -gt 0 -and $existing[-1] -ne "`n") { $existing += "`r`n" }
    $existing += "$line`r`n"
}

[IO.File]::WriteAllText($SecretsPath, $existing, (New-Object Text.UTF8Encoding $false))

Write-Host ''
Write-Host "Recorded in $SecretsPath" -ForegroundColor Green
Write-Host 'No browser is needed again: every run exchanges this token for an access token.' -ForegroundColor DarkGray
Write-Host ''
Write-Host 'If a later run starts failing with invalid_grant, the token was revoked - by a' -ForegroundColor DarkGray
Write-Host 'password change, by removing the app from the account, or because the OAuth' -ForegroundColor DarkGray
Write-Host 'consent screen is External and still in Testing, where Google expires it after 7' -ForegroundColor DarkGray
Write-Host 'days. Internal has no such expiry. Re-run this script with -Force to replace it.' -ForegroundColor DarkGray
