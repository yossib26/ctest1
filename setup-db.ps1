# Setup: creates the users table in Neon and adds the default users.
# Safe to re-run: existing users are left unchanged.
# New users get a random password, printed once below - save it, it is not stored anywhere in plain text.
. (Join-Path $PSScriptRoot "db.ps1")

Invoke-Sql @"
CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
)
"@ | Out-Null

Invoke-Sql "ALTER TABLE users ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin'))" | Out-Null

# The original admin keeps its password (1234)
Invoke-Sql "INSERT INTO users (username, password_hash, role) VALUES (`$1, `$2, 'admin') ON CONFLICT (username) DO NOTHING" `
  @("admin", (New-PasswordHash "1234")) | Out-Null
Invoke-Sql "UPDATE users SET role = 'admin' WHERE username = 'admin'" | Out-Null

function New-RandomPassword {
  $chars = "abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
  $bytes = New-Object byte[] 10
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

$defaultUsers = @(
  @{ username = "user1";  role = "user" },
  @{ username = "user2";  role = "user" },
  @{ username = "user3";  role = "user" },
  @{ username = "user4";  role = "user" },
  @{ username = "user5";  role = "user" },
  @{ username = "admin1"; role = "admin" },
  @{ username = "admin2"; role = "admin" }
)

$created = @()
foreach ($u in $defaultUsers) {
  $password = New-RandomPassword
  $rows = Invoke-Sql "INSERT INTO users (username, password_hash, role) VALUES (`$1, `$2, `$3) ON CONFLICT (username) DO NOTHING RETURNING username" `
    @($u.username, (New-PasswordHash $password), $u.role)
  if ($rows) { $created += [pscustomobject]@{ username = $u.username; role = $u.role; password = $password } }
}

if ($created) {
  Write-Host "`nNew users created (save these passwords now):"
  $created | Format-Table
}

Write-Host "All users:"
Invoke-Sql "SELECT id, username, role, created_at FROM users ORDER BY id" | Format-Table
