// V93 — call lifecycle rules.
import test from 'node:test';
import assert from 'node:assert/strict';

import {
  CALL_STATUS, TERMINAL_STATUSES, isTerminal, normalizeKind, makeCallRoomName,
  isValidRoomName, computeDurationSec, resolveEndStatus, resolveTimeoutStatus,
  canTransition, callNotificationText, RING_TIMEOUT_MS,
} from '../src/modules/calls.js';

test('terminal statuses are recognised and non-terminal ones are not', () => {
  for (const s of TERMINAL_STATUSES) assert.equal(isTerminal(s), true, s);
  assert.equal(isTerminal(CALL_STATUS.RINGING), false);
  assert.equal(isTerminal(CALL_STATUS.ACCEPTED), false);
  assert.equal(isTerminal(undefined), false);
});

test('kind is normalised and defaults to AUDIO', () => {
  assert.equal(normalizeKind('VIDEO'), 'VIDEO');
  assert.equal(normalizeKind('video'), 'VIDEO');
  assert.equal(normalizeKind('AUDIO'), 'AUDIO');
  assert.equal(normalizeKind(''), 'AUDIO');
  assert.equal(normalizeKind(null), 'AUDIO');
});

test('room names are valid, stable and sanitised', () => {
  const room = makeCallRoomName('abc-123_XYZ');
  assert.ok(isValidRoomName(room), room);
  assert.equal(room, 'call_abc-123_XYZ');
  assert.ok(isValidRoomName(makeCallRoomName('a'.repeat(80))));
  assert.ok(!isValidRoomName('live:room'));
  assert.ok(!isValidRoomName('call_'));
  // characters that could escape a room name are stripped
  assert.equal(makeCallRoomName('a/b:c', ''), 'call_abc');
});

test('duration is derived from timestamps, never from the client', () => {
  const start = new Date('2026-09-28T10:00:00Z');
  const end = new Date('2026-09-28T10:03:12Z');
  assert.equal(computeDurationSec(start, end), 192);
  assert.equal(computeDurationSec(null, end), 0);
  assert.equal(computeDurationSec(start, null), 0);
  // clock skew / reversed range never produces a negative duration
  assert.equal(computeDurationSec(end, start), 0);
});

test('end status: answered calls END, unanswered calls are MISSED', () => {
  assert.equal(resolveEndStatus(CALL_STATUS.ACCEPTED, new Date()), CALL_STATUS.ENDED);
  assert.equal(resolveEndStatus(CALL_STATUS.RINGING, null), CALL_STATUS.MISSED);
  // a terminal call keeps its status
  assert.equal(resolveEndStatus(CALL_STATUS.REJECTED, new Date()), CALL_STATUS.REJECTED);
});

test('ring timeout turns RINGING into MISSED only after the window', () => {
  const started = new Date('2026-09-28T10:00:00Z');
  const before = new Date(started.getTime() + RING_TIMEOUT_MS - 1000);
  const after = new Date(started.getTime() + RING_TIMEOUT_MS + 1000);
  assert.equal(resolveTimeoutStatus(CALL_STATUS.RINGING, started, before), CALL_STATUS.RINGING);
  assert.equal(resolveTimeoutStatus(CALL_STATUS.RINGING, started, after), CALL_STATUS.MISSED);
  // an accepted call is never downgraded by the sweeper
  assert.equal(resolveTimeoutStatus(CALL_STATUS.ACCEPTED, started, after), CALL_STATUS.ACCEPTED);
});

test('only the two parties may act, and only the receiver may answer', () => {
  const base = { callerId: 'caller', receiverId: 'receiver', currentStatus: CALL_STATUS.RINGING };
  assert.equal(canTransition({ ...base, actorId: 'receiver', next: CALL_STATUS.ACCEPTED }), true);
  assert.equal(canTransition({ ...base, actorId: 'caller', next: CALL_STATUS.ACCEPTED }), false, 'caller cannot answer');
  assert.equal(canTransition({ ...base, actorId: 'stranger', next: CALL_STATUS.ACCEPTED }), false);
  assert.equal(canTransition({ ...base, actorId: 'stranger', next: CALL_STATUS.ENDED }), false);
  assert.equal(canTransition({ ...base, actorId: 'caller', next: CALL_STATUS.ENDED }), true);
  assert.equal(canTransition({ ...base, actorId: 'receiver', next: CALL_STATUS.REJECTED }), true);
  // terminal calls accept no further transitions
  assert.equal(canTransition({ ...base, currentStatus: CALL_STATUS.ENDED, actorId: 'caller', next: CALL_STATUS.ENDED }), false);
  assert.equal(canTransition({ ...base, currentStatus: CALL_STATUS.MISSED, actorId: 'receiver', next: CALL_STATUS.ACCEPTED }), false);
});

test('notifications carry the right text per outcome', () => {
  assert.match(callNotificationText({ status: CALL_STATUS.MISSED, name: 'خالد' }), /فائتة/);
  assert.match(callNotificationText({ status: CALL_STATUS.ENDED, name: 'خالد', video: true }), /فيديو/);
  assert.match(callNotificationText({ status: CALL_STATUS.REJECTED, name: 'سارة' }), /رفض/);
});
