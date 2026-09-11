import { DatabaseSync } from 'node:sqlite';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { OPERATORS } from '../services/operatorData.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Render's free web-service disk is ephemeral (wiped on redeploy/restart) —
// fine for a demo, matching how Phase 1's mock also resets on reload. Point
// DB_PATH at a Render persistent disk mount (or a managed Postgres instead)
// if you need bookings to survive redeploys. See README "Deployment".
const DB_PATH = process.env.DB_PATH || path.join(__dirname, '..', '..', 'data', 'bus_booking.sqlite');

fs.mkdirSync(path.dirname(DB_PATH), { recursive: true });

export const db = new DatabaseSync(DB_PATH);

const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
db.exec(schema);

function seedOperators() {
  const { count } = db.prepare('SELECT COUNT(*) AS count FROM operators').get();
  if (count > 0) return;

  const insert = db.prepare('INSERT INTO operators (name, bus_type, rating) VALUES (?, ?, ?)');
  for (const op of OPERATORS) {
    insert.run(op.name, op.busType, op.rating);
  }
}

seedOperators();

export function runInTransaction(fn) {
  db.exec('BEGIN');
  try {
    const result = fn();
    db.exec('COMMIT');
    return result;
  } catch (err) {
    db.exec('ROLLBACK');
    throw err;
  }
}
