// Vercel serverless function: POST /api/login
// Checks credentials against the Neon users table (same logic as server.ps1)
const crypto = require("crypto");

async function sql(query, params) {
  const dbUrl = process.env.DATABASE_URL;
  const host = new URL(dbUrl.replace(/^postgres(ql)?:\/\//, "https://")).host;
  const endpoint = "https://" + host.replace(/^[^.]+\./, "api.") + "/sql";
  const res = await fetch(endpoint, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Neon-Connection-String": dbUrl,
      "Neon-Raw-Text-Output": "true"
    },
    body: JSON.stringify({ query, params })
  });
  if (!res.ok) throw new Error("Neon query failed: " + res.status + " " + (await res.text()));
  return (await res.json()).rows;
}

// Stored format: "iterations:salt:hash" (base64), PBKDF2-SHA256, 32-byte hash
function verifyPassword(password, stored) {
  const parts = String(stored).split(":");
  if (parts.length !== 3) return false;
  const salt = Buffer.from(parts[1], "base64");
  const expected = Buffer.from(parts[2], "base64");
  const actual = crypto.pbkdf2Sync(password, salt, parseInt(parts[0], 10), expected.length, "sha256");
  return crypto.timingSafeEqual(expected, actual);
}

module.exports = async (req, res) => {
  if (req.method !== "POST") {
    return res.status(405).json({ ok: false, error: "Method not allowed" });
  }
  try {
    const body = typeof req.body === "string" ? JSON.parse(req.body) : (req.body || {});
    const rows = await sql(
      "SELECT username, password_hash, role FROM users WHERE username = $1",
      [String(body.username || "")]
    );
    if (rows.length && verifyPassword(String(body.password || ""), rows[0].password_hash)) {
      return res.status(200).json({ ok: true, username: rows[0].username, role: rows[0].role });
    }
    return res.status(401).json({ ok: false, error: "Invalid username or password" });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ ok: false, error: "Server error" });
  }
};
