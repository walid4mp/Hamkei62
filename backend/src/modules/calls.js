// SocialNova V93 — call lifecycle rules (pure, testable).
// The socket/HTTP layers persist these transitions; keeping them here means the
// same rules are used by the REST routes, the socket handlers and the tests.

export const CALL_STATUS = {
  RINGING: 'RINGING',
  ACCEPTED: 'ACCEPTED',
  REJECTED: 'REJECTED',
  MISSED: 'MISSED',
  ENDED: 'ENDED',
  FAILED: 'FAILED',
};

export const TERMINAL_STATUSES = [
  CALL_STATUS.REJECTED,
  CALL_STATUS.MISSED,
  CALL_STATUS.ENDED,
  CALL_STATUS.FAILED,
];

/** How long an unanswered call may ring before it becomes a missed call. */
export const RING_TIMEOUT_MS = Number(process.env.CALL_RING_TIMEOUT_MS || 45000);

export function isTerminal(status) {
  return TERMINAL_STATUSES.includes(String(status || '').toUpperCase());
}

export function normalizeKind(kind) {
  const k = String(kind || '').toUpperCase();
  return k === 'VIDEO' ? 'VIDEO' : 'AUDIO';
}

/** `call_` + a random token, so LiveKit and the app agree on the room name. */
export function makeCallRoomName(seed) {
  const token = String(seed || '').replace(/[^A-Za-z0-9_-]/g, '').slice(0, 24);
  return `call_${token || 'socialnova'}`;
}

export function isValidRoomName(roomName) {
  return /^call_[A-Za-z0-9_-]{3,180}$/.test(String(roomName || ''));
}

/** Duration is always derived from answeredAt → endedAt, never trusted from the client. */
export function computeDurationSec(answeredAt, endedAt) {
  if (!answeredAt || !endedAt) return 0;
  const a = new Date(answeredAt).getTime();
  const b = new Date(endedAt).getTime();
  if (!Number.isFinite(a) || !Number.isFinite(b) || b <= a) return 0;
  return Math.max(0, Math.round((b - a) / 1000));
}

/** What the call becomes when the caller/callee hangs up. */
export function resolveEndStatus(currentStatus, answeredAt) {
  const s = String(currentStatus || '').toUpperCase();
  if (isTerminal(s)) return s;
  if (!answeredAt) return CALL_STATUS.MISSED; // rang, never answered
  return CALL_STATUS.ENDED;
}

/** What a RINGING call becomes once the ring timeout has passed. */
export function resolveTimeoutStatus(currentStatus, startedAt, now = new Date()) {
  const s = String(currentStatus || '').toUpperCase();
  if (s !== CALL_STATUS.RINGING) return s;
  const start = new Date(startedAt).getTime();
  if (!Number.isFinite(start)) return s;
  return now.getTime() - start >= RING_TIMEOUT_MS ? CALL_STATUS.MISSED : s;
}

/**
 * Who is allowed to move a call into `next`. Only the two parties may act, and
 * only the receiver may accept/reject.
 */
export function canTransition({ actorId, callerId, receiverId, currentStatus, next }) {
  const current = String(currentStatus || '').toUpperCase();
  const target = String(next || '').toUpperCase();
  if (!actorId || actorId !== callerId && actorId !== receiverId) return false;
  if (isTerminal(current)) return false;
  if (target === CALL_STATUS.ACCEPTED || target === CALL_STATUS.REJECTED) {
    return actorId === receiverId && current === CALL_STATUS.RINGING;
  }
  if (target === CALL_STATUS.ENDED || target === CALL_STATUS.MISSED) {
    return true; // either party may hang up
  }
  return false;
}

/** Human label used in notifications. */
export function callNotificationText({ status, name, video }) {
  const who = name || 'مستخدم';
  const kind = video ? 'مكالمة فيديو' : 'مكالمة صوتية';
  switch (String(status || '').toUpperCase()) {
    case CALL_STATUS.MISSED: return `مكالمة ${kind} فائتة من ${who}`;
    case CALL_STATUS.ENDED: return `انتهت ${kind} مع ${who}`;
    case CALL_STATUS.REJECTED: return `تم رفض ${kind} من ${who}`;
    default: return `${kind} من ${who}`;
  }
}
