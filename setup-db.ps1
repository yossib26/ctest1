# One-time setup: creates the users table in Neon and adds the admin user
. (Join-Path $PSScriptRoot "db.ps1")

Invoke-Sql @"
CREATE TABLE IF NOT EXISTS users (
  id            SERIAL PRIMARY KEY,
  username      TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
)
"@ | Out-Null

Invoke-Sql "INSERT INTO users (username, password_hash) VALUES (`$1, `$2) ON CONFLICT (username) DO NOTHING" `
  @("admin", (New-PasswordHash "1234")) | Out-Null

Invoke-Sql "SELECT id, username, created_at FROM users ORDER BY id" | Format-Table
