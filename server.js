const http = require("node:http");
const fs = require("node:fs");
const path = require("node:path");
const { URL } = require("node:url");

const ROOT = __dirname;
const DATA_DIR = path.join(ROOT, "data");
const SUBMISSIONS_FILE = path.join(DATA_DIR, "contact-submissions.jsonl");

loadEnv(path.join(ROOT, ".env"));

const PORT = Number(process.env.PORT || 4321);
const CONTACT_TO_EMAIL = process.env.CONTACT_TO_EMAIL || "lethalinjection2004@gmail.com";
const CONTACT_FROM_EMAIL = process.env.CONTACT_FROM_EMAIL || "Nightmare Clinical Analytics <onboarding@resend.dev>";
const RESEND_API_KEY = process.env.RESEND_API_KEY || "";

const mimeTypes = new Map([
  [".html", "text/html; charset=utf-8"],
  [".css", "text/css; charset=utf-8"],
  [".js", "text/javascript; charset=utf-8"],
  [".json", "application/json; charset=utf-8"],
  [".csv", "text/csv; charset=utf-8"],
  [".pdf", "application/pdf"],
  [".png", "image/png"],
  [".svg", "image/svg+xml"],
  [".ico", "image/x-icon"]
]);

const server = http.createServer(async (req, res) => {
  try {
    const url = new URL(req.url, `http://${req.headers.host || "localhost"}`);
    if (req.method === "GET" && url.pathname === "/api/health") {
      sendJson(res, 200, {
        ok: true,
        app: "Nightmare Clinical Analytics",
        emailConfigured: Boolean(RESEND_API_KEY)
      });
      return;
    }
    if (req.method === "POST" && url.pathname === "/api/contact") {
      await handleContact(req, res);
      return;
    }
    if (req.method !== "GET" && req.method !== "HEAD") {
      sendJson(res, 405, { ok: false, error: "Method not allowed" });
      return;
    }
    serveStatic(url.pathname, req, res);
  } catch (error) {
    console.error(error);
    sendJson(res, 500, { ok: false, error: "Unexpected server error" });
  }
});

server.listen(PORT, "0.0.0.0", () => {
  console.log(`Nightmare Clinical Analytics running at http://0.0.0.0:${PORT}`);
  if (!RESEND_API_KEY) {
    console.log("Contact form will save locally. Add RESEND_API_KEY in .env to enable email delivery.");
  }
});

function loadEnv(filePath) {
  if (!fs.existsSync(filePath)) return;
  const lines = fs.readFileSync(filePath, "utf8").split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq).trim();
    const value = trimmed.slice(eq + 1).trim().replace(/^["']|["']$/g, "");
    if (!process.env[key]) process.env[key] = value;
  }
}

function serveStatic(pathname, req, res) {
  const cleanPath = decodeURIComponent(pathname.split("?")[0]);
  const requested = cleanPath === "/" ? "/index.html" : cleanPath;
  const filePath = path.normalize(path.join(ROOT, requested));
  if (!filePath.startsWith(ROOT)) {
    sendText(res, 403, "Forbidden");
    return;
  }
  if (isPrivatePath(filePath)) {
    sendText(res, 403, "Forbidden");
    return;
  }
  fs.stat(filePath, (err, stat) => {
    if (err || !stat.isFile()) {
      sendText(res, 404, "Not found");
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, {
      "Content-Type": mimeTypes.get(ext) || "application/octet-stream",
      "Content-Length": stat.size,
      "Cache-Control": ext === ".html" ? "no-store" : "public, max-age=3600"
    });
    if (req.method === "HEAD") {
      res.end();
      return;
    }
    fs.createReadStream(filePath).pipe(res);
  });
}

function isPrivatePath(filePath) {
  const relative = path.relative(ROOT, filePath).replaceAll("\\", "/");
  const base = path.basename(filePath);
  if (base.startsWith(".")) return true;
  if (relative === "server.js") return true;
  if (relative.endsWith(".ps1")) return true;
  if (relative === "data/contact-submissions.jsonl") return true;
  return false;
}

async function handleContact(req, res) {
  let body;
  try {
    body = await readJson(req, 32 * 1024);
  } catch {
    sendJson(res, 400, { ok: false, error: "Invalid request body" });
    return;
  }

  const submission = normalizeSubmission(body);
  const validationError = validateSubmission(submission);
  if (validationError) {
    sendJson(res, 400, { ok: false, error: validationError });
    return;
  }

  if (body.website) {
    sendJson(res, 200, { ok: true, saved: false, emailed: false });
    return;
  }

  fs.mkdirSync(DATA_DIR, { recursive: true });
  fs.appendFileSync(SUBMISSIONS_FILE, JSON.stringify(submission) + "\n", "utf8");

  const emailResult = await sendContactEmail(submission);
  sendJson(res, 200, {
    ok: true,
    saved: true,
    emailed: emailResult.ok,
    emailConfigured: Boolean(RESEND_API_KEY),
    message: emailResult.ok
      ? "Your message was sent."
      : "Your message was saved locally. Email delivery needs RESEND_API_KEY."
  });
}

function readJson(req, maxBytes) {
  return new Promise((resolve, reject) => {
    let data = "";
    req.setEncoding("utf8");
    req.on("data", chunk => {
      data += chunk;
      if (Buffer.byteLength(data, "utf8") > maxBytes) {
        reject(new Error("Request too large"));
        req.destroy();
      }
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(data || "{}"));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function normalizeSubmission(body) {
  const now = new Date().toISOString();
  return {
    receivedAt: now,
    name: clean(body.name, 120),
    email: clean(body.email, 160),
    organization: clean(body.organization, 160),
    role: clean(body.role, 120),
    interest: clean(body.interest, 160),
    message: clean(body.message, 4000),
    source: "Nightmare Clinical Analytics contact form"
  };
}

function clean(value, maxLength) {
  return String(value || "")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, maxLength);
}

function validateSubmission(submission) {
  if (submission.name.length < 2) return "Please enter your name.";
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(submission.email)) return "Please enter a valid email.";
  if (submission.message.length < 10) return "Please include a short message.";
  return "";
}

async function sendContactEmail(submission) {
  if (!RESEND_API_KEY) return { ok: false, skipped: true };
  const subject = `Nightmare Clinical Analytics inquiry from ${submission.name}`;
  const html = `
    <div style="font-family:Arial,sans-serif;line-height:1.5;color:#111">
      <h2>New contact form submission</h2>
      <p><strong>Name:</strong> ${escapeHtml(submission.name)}</p>
      <p><strong>Email:</strong> ${escapeHtml(submission.email)}</p>
      <p><strong>Organization:</strong> ${escapeHtml(submission.organization || "Not provided")}</p>
      <p><strong>Role:</strong> ${escapeHtml(submission.role || "Not provided")}</p>
      <p><strong>Interest:</strong> ${escapeHtml(submission.interest || "Not provided")}</p>
      <p><strong>Message:</strong><br>${escapeHtml(submission.message)}</p>
      <p><strong>Received:</strong> ${escapeHtml(submission.receivedAt)}</p>
    </div>
  `;

  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json"
      },
      body: JSON.stringify({
        from: CONTACT_FROM_EMAIL,
        to: CONTACT_TO_EMAIL,
        reply_to: submission.email,
        subject,
        html
      })
    });
    if (!response.ok) {
      const text = await response.text();
      console.error(`Email send failed: ${response.status} ${text}`);
      return { ok: false, status: response.status };
    }
    return { ok: true };
  } catch (error) {
    console.error("Email send failed:", error);
    return { ok: false };
  }
}

function escapeHtml(value) {
  return String(value || "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function sendJson(res, status, payload) {
  const body = JSON.stringify(payload);
  res.writeHead(status, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body)
  });
  res.end(body);
}

function sendText(res, status, body) {
  res.writeHead(status, {
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": Buffer.byteLength(body)
  });
  res.end(body);
}
