# Helpers for talking to Neon over its HTTP SQL endpoint (no drivers needed)
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Get-DatabaseUrl {
  $envFile = Join-Path $PSScriptRoot ".env"
  foreach ($line in Get-Content $envFile) {
    if ($line -match '^\s*DATABASE_URL\s*=\s*(.+)$') { return $Matches[1].Trim() }
  }
  throw "DATABASE_URL not found in .env"
}

$script:DbUrl = Get-DatabaseUrl
$script:DbHost = ([Uri]($script:DbUrl -replace '^postgres(ql)?://', 'https://')).Host
$script:SqlEndpoint = "https://" + ($script:DbHost -replace '^[^.]+\.', 'api.') + "/sql"

function Invoke-Sql([string]$Query, [object[]]$Params = @()) {
  $body = @{ query = $Query; params = $Params } | ConvertTo-Json -Compress -Depth 5
  $headers = @{ "Neon-Connection-String" = $script:DbUrl; "Neon-Raw-Text-Output" = "true" }
  $res = Invoke-RestMethod -Method Post -Uri $script:SqlEndpoint -Headers $headers `
    -ContentType "application/json" -Body ([Text.Encoding]::UTF8.GetBytes($body))
  return $res.rows
}

# PBKDF2-SHA256 password hashing, stored as "iterations:salt:hash" (base64)
function New-PasswordHash([string]$Password) {
  $salt = New-Object byte[] 16
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($salt)
  $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, 100000, [Security.Cryptography.HashAlgorithmName]::SHA256)
  return "100000:" + [Convert]::ToBase64String($salt) + ":" + [Convert]::ToBase64String($kdf.GetBytes(32))
}

function Test-PasswordHash([string]$Password, [string]$Stored) {
  $parts = $Stored -split ':'
  if ($parts.Count -ne 3) { return $false }
  $salt = [Convert]::FromBase64String($parts[1])
  $expected = [Convert]::FromBase64String($parts[2])
  $kdf = New-Object Security.Cryptography.Rfc2898DeriveBytes($Password, $salt, [int]$parts[0], [Security.Cryptography.HashAlgorithmName]::SHA256)
  $actual = $kdf.GetBytes(32)
  $diff = 0
  for ($i = 0; $i -lt $expected.Length; $i++) { $diff = $diff -bor ($expected[$i] -bxor $actual[$i]) }
  return $diff -eq 0
}
