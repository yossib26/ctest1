# Simple web server for this folder: http://localhost:8080/
# Serves static files and POST /api/login (checked against the Neon users table)
. (Join-Path $PSScriptRoot "db.ps1")

$port = 8080
$root = $PSScriptRoot
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$port/")
$listener.Start()
Write-Host "Serving $root at http://localhost:$port/ (Ctrl+C to stop)"

$types = @{ ".html" = "text/html; charset=utf-8"; ".css" = "text/css"; ".js" = "application/javascript" }
# Files that must never be served to the browser
$blocked = @(".env", "db.ps1", "server.ps1", "setup-db.ps1")

function Send-Json($res, [int]$status, $obj) {
  $bytes = [Text.Encoding]::UTF8.GetBytes(($obj | ConvertTo-Json -Compress))
  $res.StatusCode = $status
  $res.ContentType = "application/json; charset=utf-8"
  $res.OutputStream.Write($bytes, 0, $bytes.Length)
}

function Invoke-Login($req, $res) {
  try {
    $reader = New-Object IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
    $data = $reader.ReadToEnd() | ConvertFrom-Json
    $rows = Invoke-Sql "SELECT username, password_hash FROM users WHERE username = `$1" @([string]$data.username)
    if ($rows -and (Test-PasswordHash ([string]$data.password) $rows[0].password_hash)) {
      Send-Json $res 200 @{ ok = $true; username = $rows[0].username }
    } else {
      Send-Json $res 401 @{ ok = $false; error = "Invalid username or password" }
    }
  } catch {
    Write-Host "Login error: $_"
    Send-Json $res 500 @{ ok = $false; error = "Server error" }
  }
}

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $path = $req.Url.AbsolutePath.TrimStart("/")

    if ($path -eq "api/login" -and $req.HttpMethod -eq "POST") {
      Invoke-Login $req $res
    } else {
      if ($path -eq "") { $path = "login.html" }
      $file = Join-Path $root $path
      if ((Test-Path $file -PathType Leaf) -and ((Resolve-Path $file).Path.StartsWith($root)) -and
          ($blocked -notcontains [IO.Path]::GetFileName($file))) {
        $bytes = [System.IO.File]::ReadAllBytes($file)
        $ext = [System.IO.Path]::GetExtension($file)
        if ($types.ContainsKey($ext)) { $res.ContentType = $types[$ext] }
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
      } else {
        $res.StatusCode = 404
      }
    }
    $res.Close()
  }
} finally {
  $listener.Stop()
}
