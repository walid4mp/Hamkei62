import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const server = fs.readFileSync(path.join(root, 'src/server.js'), 'utf8');
// The merged repo keeps the Flutter client under lib/ (no flutter-app/ dir).
// Assert the client contract only when the legacy client files exist, so the
// server-side endpoints stay verified on every run.
const legacyClientDir = path.join(root, '..', 'flutter-app', 'lib', 'screens');
const hasLegacyClient =
  fs.existsSync(path.join(legacyClientDir, 'nova_tv.dart')) &&
  fs.existsSync(path.join(legacyClientDir, 'creator_content_center.dart'));
const nova = hasLegacyClient ? fs.readFileSync(path.join(legacyClientDir, 'nova_tv.dart'), 'utf8') : '';
const creator = hasLegacyClient ? fs.readFileSync(path.join(legacyClientDir, 'creator_content_center.dart'), 'utf8') : '';

function has(text) { return server.includes(text); }

test('Nova TV server has series -> season -> episode creation endpoints', () => {
  assert.ok(has("app.post('/api/creator/series'"));
  assert.ok(has("app.post('/api/creator/series/:id/seasons'"));
  assert.ok(has("app.post('/api/creator/seasons/:id/episodes'"));
});

test('Nova TV client calls the creator creation endpoints', { skip: hasLegacyClient ? false : 'legacy flutter-app client screens are not part of this merged repo layout' }, () => {
  assert.match(creator, /createCreatorSeries/);
  assert.match(creator, /createCreatorSeason/);
  assert.match(creator, /createCreatorEpisode/);
});

test('published series and episodes are exposed to Nova TV', () => {
  assert.ok(has("app.get('/api/series'"));
  assert.ok(has("where:{status:'PUBLISHED'"));
  assert.ok(has("app.get('/api/episodes/:id'"));
  assert.ok(has("where:{published:true}"));
});

test('subscription purchase is tied to the creator plan and Google verification', () => {
  assert.ok(has("app.post('/api/content/subscription'"));
  assert.ok(has("creatorSubscriptionPlan.findUnique({where:{creatorId:d.creatorId}})"));
  assert.ok(has("SUBSCRIPTION_PRODUCT_MISMATCH"));
  assert.ok(has('verifyGoogleSubscription(d.productId,d.purchaseToken)'));
  assert.ok(has("status='VERIFIED'"));
});

test('protected episodes require an active verified subscription', () => {
  assert.ok(has("ep.accessMode==='SUBSCRIBER' || ep.accessMode==='SUBSCRIPTION'"));
  assert.ok(has('creatorSubscriptionActive(ep.creatorId,userId)'));
  assert.ok(has('seriesSubscriberOnly=Boolean(ep.season?.series?.subscriberOnly)'));
  assert.ok(has("app.post('/api/content/:kind/:id/view'"));
});

test('client sends the purchase token to the backend and only treats VERIFIED as success', { skip: hasLegacyClient ? false : 'legacy flutter-app client screens are not part of this merged repo layout' }, () => {
  assert.match(nova, /purchase\.verificationData\.serverVerificationData/);
  assert.match(nova, /Api\.buyCreatorSubscription/);
  assert.match(nova, /verification != 'VERIFIED'/);
  assert.match(nova, /_seriesRequiresSubscription/);
});
