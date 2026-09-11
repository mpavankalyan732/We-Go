import { db } from '../db/index.js';

const REF_CHARS = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no ambiguous 0/O/1/I

function randomReferenceId() {
  let suffix = '';
  for (let i = 0; i < 6; i++) suffix += REF_CHARS[Math.floor(Math.random() * REF_CHARS.length)];
  return `BK-${suffix}`;
}

function randomPnr() {
  let pnr = '';
  for (let i = 0; i < 10; i++) pnr += Math.floor(Math.random() * 10);
  return pnr;
}

// Astronomically unlikely to collide, but this is a real database now — check.
export function generateUniqueReferenceId() {
  const exists = db.prepare('SELECT 1 FROM bookings WHERE booking_reference_id = ?');
  for (let attempt = 0; attempt < 10; attempt++) {
    const id = randomReferenceId();
    if (!exists.get(id)) return id;
  }
  throw new Error('Could not generate a unique booking reference id');
}

export function generateUniquePnr() {
  const exists = db.prepare('SELECT 1 FROM bookings WHERE pnr = ?');
  for (let attempt = 0; attempt < 10; attempt++) {
    const pnr = randomPnr();
    if (!exists.get(pnr)) return pnr;
  }
  throw new Error('Could not generate a unique PNR');
}
