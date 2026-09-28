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
