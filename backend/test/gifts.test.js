import test from 'node:test';
import assert from 'node:assert/strict';

import { buildGiftCatalog, GIFT_CATEGORIES } from '../src/modules/gifts.js';
import { PERMISSIONS, ROLES, ROLE_PERMISSIONS, effectivePermissions, hasPermission, liveStaffCan } from '../src/modules/permissions.js';

test('gift engine produces 200+ gifts with unique identity', () => {
  const catalog = buildGiftCatalog();
  assert.ok(catalog.length >= 200, `expected >=200 gifts, got ${catalog.length}`);
  assert.equal(new Set(catalog.map((g) => g.emoji)).size, catalog.length, 'emoji must be unique');
  assert.equal(new Set(catalog.map((g) => g.name)).size, catalog.length, 'name must be unique');
  assert.equal(new Set(catalog.map((g) => g.slug)).size, catalog.length, 'slug must be unique');
});

test('gift prices ascend and every gift is complete', () => {
  const catalog = buildGiftCatalog();
  for (let i = 1; i < catalog.length; i++) {
    assert.ok(catalog[i].priceCoins >= catalog[i - 1].priceCoins, 'prices must ascend');
  }
  const rarities = new Set(['COMMON', 'RARE', 'EPIC', 'LEGENDARY', 'MYTHIC']);
  for (const g of catalog) {
    assert.ok(g.slug && /^[a-z0-9_]+$/.test(g.slug), `bad slug ${g.slug}`);
    assert.ok(g.name && g.emoji && g.effectKey && g.soundKey, `incomplete gift ${g.slug}`);
    assert.ok(g.effectMs >= 1000, `bad duration ${g.slug}`);
    assert.ok(rarities.has(g.rarity), `bad rarity ${g.rarity}`);
    assert.ok(GIFT_CATEGORIES.some((c) => c.key === g.category), `bad category ${g.category}`);
  }
});

test('catalog is deterministic', () => {
  assert.deepEqual(buildGiftCatalog(), buildGiftCatalog());
});

test('permissions: only SUPER_ADMIN carries the wildcard', () => {
  for (const role of ROLES) {
    const perms = effectivePermissions({ role, adminPermissions: [] });
    if (role === 'SUPER_ADMIN') assert.ok(perms.includes('*'));
    else assert.ok(!perms.includes('*'), `${role} must not wildcard`);
  }
});

test('permissions: grants add on top of role defaults, legacy names expand', () => {
  const moderator = effectivePermissions({ role: 'MODERATOR', adminPermissions: [] });
  assert.ok(moderator.includes('posts.delete'));
  const custom = effectivePermissions({ role: 'SECURITY_ACCOUNT', adminPermissions: ['POST_MODERATION'] });
  assert.ok(custom.includes('posts.moderate'));
  assert.ok(hasPermission({ role: 'SECURITY_ACCOUNT', adminPermissions: ['POST_MODERATION'] }, 'posts.delete'));
});

test('live staff roles are distinct and enforced', () => {
  assert.ok(liveStaffCan({ role: 'MODERATOR' }, 'comments.pin'));
  assert.ok(liveStaffCan({ role: 'MODERATOR' }, 'live.mute'));
  assert.ok(liveStaffCan({ role: 'ASSISTANT' }, 'comments.delete'));
  assert.ok(!liveStaffCan({ role: 'ASSISTANT' }, 'comments.pin'), 'assistant cannot pin');
  assert.ok(!liveStaffCan({ role: 'ASSISTANT' }, 'live.mute'), 'assistant cannot mute');
  assert.ok(!liveStaffCan(null, 'comments.delete'));
});

test('permission catalog is complete and deduplicated', () => {
  assert.equal(new Set(PERMISSIONS).size, PERMISSIONS.length);
  for (const p of ['users.ban', 'posts.delete', 'live.moderate', 'gifts.manage', 'withdrawals.approve', 'audit.view']) {
    assert.ok(PERMISSIONS.includes(p), `missing ${p}`);
  }
  assert.ok(Object.keys(ROLE_PERMISSIONS).length >= 7);
});

// ── V93: the gift library contract the Flutter store now depends on ─────────
test('every gift exposes the full V93 library contract', () => {
  const catalog = buildGiftCatalog();
  for (const g of catalog) {
    for (const field of ['slug', 'name', 'nameEn', 'emoji', 'priceCoins', 'rarity', 'category',
      'effectKey', 'effectMs', 'soundKey', 'assetKey', 'imageUrl', 'previewUrl',
      'animationUrl', 'premium', 'sortOrder', 'metadata']) {
      assert.ok(Object.prototype.hasOwnProperty.call(g, field), `${g.slug} is missing ${field}`);
    }
    assert.equal(typeof g.premium, 'boolean', `${g.slug} premium must be a boolean`);
    assert.equal(typeof g.sortOrder, 'number', `${g.slug} sortOrder must be a number`);
    assert.ok(g.assetKey.startsWith('gifts/'), `${g.slug} assetKey`);
    // Artwork is uploaded later; until then the client falls back to the emoji.
    assert.equal(typeof g.imageUrl, 'string');
  }
});

test('premium gifts are the top two rarity bands only', () => {
  const catalog = buildGiftCatalog();
  for (const g of catalog) {
    const expected = g.rarity === 'MYTHIC' || g.rarity === 'LEGENDARY';
    assert.equal(g.premium, expected, `${g.slug} (${g.rarity}) premium mismatch`);
  }
  assert.ok(catalog.some((g) => g.premium), 'at least one premium gift');
  assert.ok(catalog.some((g) => !g.premium), 'at least one free-tier gift');
});

test('nameEn is derived and never empty', () => {
  for (const g of buildGiftCatalog()) {
    assert.ok(g.nameEn.length > 0, `${g.slug} has no English name`);
    assert.match(g.nameEn, /^[A-Za-z0-9 ]+$/, `${g.slug} nameEn: ${g.nameEn}`);
  }
});
