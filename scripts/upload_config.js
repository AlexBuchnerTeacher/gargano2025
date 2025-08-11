/**
 * Upload beliebiger JSON-Dateien in ein Firestore-Dokument.
 *
 * Beispiel:
 *   node scripts/upload_config.js --doc config/infos_default --file firestore_seed/config_infos_default.json --key C:\keys\my-service-account.json
 *
 * Alternativ zum --key-Parameter kannst du die Umgebungsvariable setzen:
 *   $env:GOOGLE_APPLICATION_CREDENTIALS="C:\keys\my-service-account.json"
 */

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

// ---- CLI-Args ----
const args = require("node:process").argv.slice(2);
function getArg(name, def = undefined) {
  const i = args.findIndex(a => a === `--${name}`);
  if (i >= 0 && args[i + 1]) return args[i + 1];
  return def;
}

const docPath = getArg("doc");   // z.B. "config/infos_default"
const filePath = getArg("file"); // z.B. "firestore_seed/config_infos_default.json"
const keyPath  = getArg("key");  // optional, sonst GOOGLE_APPLICATION_CREDENTIALS
const project  = getArg("project"); // optional; meist nicht nötig

if (!docPath || !filePath) {
  console.error("Usage: node scripts/upload_config.js --doc <collection/doc> --file <path-to-json> [--key <service-account.json>] [--project <projectId>]");
  process.exit(1);
}

// ---- Firebase Admin init ----
let credential;
if (keyPath) {
  const absKey = path.resolve(keyPath);
  credential = admin.credential.cert(require(absKey));
} else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  credential = admin.credential.applicationDefault();
} else {
  console.error("Fehler: Service-Account fehlt. Übergib --key <pfad> oder setze $env:GOOGLE_APPLICATION_CREDENTIALS.");
  process.exit(1);
}

admin.initializeApp({
  credential,
  projectId: project, // optional
});

const db = admin.firestore();

// ---- Hilfsfunktion: "serverTimestamp" Strings durch FieldValue ersetzen ----
function replacePlaceholders(obj) {
  if (obj === null || obj === undefined) return obj;
  if (typeof obj === "string") {
    if (obj === "serverTimestamp") return admin.firestore.FieldValue.serverTimestamp();
    return obj;
  }
  if (Array.isArray(obj)) return obj.map(replacePlaceholders);
  if (typeof obj === "object") {
    const out = {};
    for (const [k, v] of Object.entries(obj)) {
      out[k] = replacePlaceholders(v);
    }
    return out;
  }
  return obj;
}

// ---- JSON laden ----
const absFile = path.resolve(filePath);
if (!fs.existsSync(absFile)) {
  console.error(`Datei nicht gefunden: ${absFile}`);
  process.exit(1);
}

let data;
try {
  let raw = fs.readFileSync(absFile, "utf8");
  // BOM am Anfang entfernen (verursacht "Unexpected token" bei JSON.parse)
  if (raw.charCodeAt(0) === 0xFEFF) {
    raw = raw.slice(1);
  }
  data = JSON.parse(raw);
} catch (e) {
  console.error("JSON konnte nicht gelesen/geparst werden:", e.message);
  process.exit(1);
}


data = replacePlaceholders(data);

// ---- Doc schreiben ----
(async () => {
  try {
    await db.doc(docPath).set(data, { merge: false });
    console.log(`OK: ${absFile} → ${docPath} geschrieben.`);
    process.exit(0);
  } catch (e) {
    console.error("Fehler beim Schreiben:", e.message);
    process.exit(1);
  }
})();
