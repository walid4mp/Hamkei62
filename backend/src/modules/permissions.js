// SocialNova central permission catalog.
//
// Single source of truth for roles and permissions. Every admin endpoint must
// check a specific permission here; no role silently bypasses the checks.
// SUPER_ADMIN carries the wildcard `*` only.

export const PERMISSIONS = Object.freeze([
  // users
  'users.view', 'users.edit', 'users.delete', 'users.ban', 'users.unban', 'users.verify',
  // profiles
  'profiles.view', 'profiles.edit', 'profiles.moderate',
  // posts
  'posts.view', 'posts.delete', 'posts.moderate',
  // stories
  'stories.view', 'stories.delete', 'stories.moderate',
  // reels
  'reels.view', 'reels.delete', 'reels.moderate',
  // live
  'live.view', 'live.moderate', 'live.end', 'live.manage',
  // comments
  'comments.view', 'comments.delete', 'comments.pin', 'comments.moderate',
  // messages & calls
  'messages.view', 'messages.moderate', 'messages.delete',
  'calls.view', 'calls.moderate',
  // gifts
  'gifts.manage', 'gifts.create', 'gifts.edit', 'gifts.delete',
  // wallet & money
  'wallet.view', 'wallet.manage',
  'transactions.view', 'transactions.manage',
  'withdrawals.view', 'withdrawals.approve', 'withdrawals.reject',
  // content library
  'movies.view', 'movies.create', 'movies.edit', 'movies.delete',
  'series.view', 'series.create', 'series.edit', 'series.delete',
  'episodes.create', 'episodes.edit', 'episodes.delete',
  'creators.manage', 'rewards.manage',
  // appearance
  'themes.manage', 'backgrounds.manage', 'effects.manage', 'assets.manage',
  // trust & safety
  'reports.view', 'reports.resolve',
  // administration
  'admins.view', 'admins.create', 'admins.edit', 'admins.delete',
  'permissions.view', 'permissions.grant', 'permissions.revoke',
  'settings.view', 'settings.edit',
  'audit.view',
]);

export const ROLES = Object.freeze([
  'USER',
  'ASSISTANT_MODERATOR',
  'MODERATOR',
  'ADMIN',
  'SECURITY_ACCOUNT',
  'DEVELOPER',
  'SUPER_ADMIN',
]);

// Legacy role ids kept so existing production rows and the current admin panel
// keep working. They resolve to the same permission sets as their modern names.
export const LEGACY_ROLE_ALIASES = Object.freeze({
  CUSTOM_MODERATOR: 'ASSISTANT_MODERATOR',
  FULL_MODERATOR: 'MODERATOR',
});

// Default permissions per role. Only SUPER_ADMIN gets `*`; every other role is
// an explicit list, so a DEVELOPER account is still permission-checked.
export const ROLE_PERMISSIONS = Object.freeze({
  USER: [],
  ASSISTANT_MODERATOR: [
    'users.view', 'profiles.view', 'posts.view', 'posts.delete', 'stories.view',
    'stories.delete', 'reels.view', 'reels.delete', 'comments.view', 'comments.delete',
    'live.view', 'reports.view', 'messages.view',
  ],
  MODERATOR: [
    'users.view', 'users.ban', 'users.unban', 'profiles.view', 'profiles.moderate',
    'posts.view', 'posts.delete', 'posts.moderate', 'stories.view', 'stories.delete',
    'stories.moderate', 'reels.view', 'reels.delete', 'reels.moderate', 'live.view',
    'live.moderate', 'live.end', 'comments.view', 'comments.delete', 'comments.pin',
    'comments.moderate', 'messages.view', 'messages.moderate', 'calls.view',
    'reports.view', 'reports.resolve', 'audit.view',
  ],
  ADMIN: [
    'users.view', 'users.edit', 'users.ban', 'users.unban', 'users.verify',
    'profiles.view', 'profiles.edit', 'profiles.moderate',
    'posts.view', 'posts.delete', 'posts.moderate',
    'stories.view', 'stories.delete', 'stories.moderate',
    'reels.view', 'reels.delete', 'reels.moderate',
    'live.view', 'live.moderate', 'live.end', 'live.manage',
    'comments.view', 'comments.delete', 'comments.pin', 'comments.moderate',
    'messages.view', 'messages.moderate', 'messages.delete',
    'calls.view', 'calls.moderate',
    'gifts.manage', 'gifts.create', 'gifts.edit',
    'wallet.view', 'transactions.view', 'withdrawals.view', 'withdrawals.approve',
    'withdrawals.reject', 'movies.view', 'series.view', 'creators.manage',
    'rewards.manage', 'themes.manage', 'backgrounds.manage', 'effects.manage', 'assets.manage',
    'reports.view', 'reports.resolve', 'admins.view', 'settings.view', 'audit.view',
  ],
  // Security accounts start with no permissions at all; a Super Admin grants
  // exactly what each security operator needs.
  SECURITY_ACCOUNT: [],
  // Developers get the operational catalog but NOT permission management, so
  // they cannot escalate themselves.
  DEVELOPER: [
    'users.view', 'users.edit', 'users.ban', 'users.unban', 'users.verify',
    'profiles.view', 'profiles.edit', 'profiles.moderate',
    'posts.view', 'posts.delete', 'posts.moderate',
    'stories.view', 'stories.delete', 'stories.moderate',
    'reels.view', 'reels.delete', 'reels.moderate',
    'live.view', 'live.moderate', 'live.end', 'live.manage',
    'comments.view', 'comments.delete', 'comments.pin', 'comments.moderate',
    'messages.view', 'messages.moderate', 'messages.delete',
    'calls.view', 'calls.moderate',
    'gifts.manage', 'gifts.create', 'gifts.edit', 'gifts.delete',
    'wallet.view', 'wallet.manage', 'transactions.view', 'transactions.manage',
    'withdrawals.view', 'withdrawals.approve', 'withdrawals.reject',
    'movies.view', 'movies.create', 'movies.edit', 'movies.delete',
    'series.view', 'series.create', 'series.edit', 'series.delete',
    'episodes.create', 'episodes.edit', 'episodes.delete',
    'creators.manage', 'rewards.manage', 'themes.manage', 'backgrounds.manage',
    'effects.manage', 'assets.manage', 'reports.view', 'reports.resolve',
    'admins.view', 'settings.view', 'settings.edit', 'audit.view',
  ],
  SUPER_ADMIN: ['*'],
});

// Legacy uppercase constants used by earlier releases. They keep working and
// map onto the dotted catalog so old grants and the current admin panel are
// not broken by the migration.
export const LEGACY_PERMISSION_MAP = Object.freeze({
  POST_MODERATION: ['posts.moderate', 'posts.delete'],
  REEL_MODERATION: ['reels.moderate', 'reels.delete'],
  STORY_MODERATION: ['stories.moderate', 'stories.delete'],
  COMMENT_MODERATION: ['comments.moderate', 'comments.delete'],
  LIVE_MODERATION: ['live.moderate', 'live.end'],
  GROUP_MODERATION: ['posts.moderate'],
  USER_MODERATION: ['users.ban', 'users.unban', 'users.verify', 'users.edit'],
  REPORTS: ['reports.view', 'reports.resolve'],
  CONVERSATION_REVIEW: ['messages.view'],
  VIEW_ANALYTICS: ['audit.view'],
  VIEW_AD_REVENUE: ['transactions.view'],
  MANAGE_GIFTS: ['gifts.manage'],
  MANAGE_MUSIC: ['effects.manage'],
  MANAGE_MOVIES: ['movies.manage', 'movies.edit'],
  MANAGE_SERIES: ['series.edit'],
  MANAGE_EPISODES: ['episodes.edit'],
  MANAGE_PROMOTIONS: ['rewards.manage'],
  MANAGE_CREATOR_PAYOUTS: ['withdrawals.approve'],
  MANAGE_SUBSCRIPTIONS: ['creators.manage'],
  MANAGE_PAYMENTS: ['wallet.manage'],
  MANAGE_XP: ['rewards.manage'],
  MANAGE_COMMUNITIES: ['posts.moderate'],
  MANAGE_AI: ['settings.edit'],
  MANAGE_SETTINGS: ['settings.edit'],
  MANAGE_ADMIN_ROLES: ['permissions.grant'],
  VIEW_AUDIT_LOGS: ['audit.view'],
  MANAGE_ASSIGNED_PROFILES: ['profiles.edit'],
  ASSIGNED_PROFILE_BAN: ['users.ban'],
  ASSIGNED_PROFILE_VERIFY: ['users.verify'],
  ASSIGNED_PROFILE_FEATURE: ['profiles.edit'],
  ASSIGNED_PROFILE_COINS: ['wallet.manage'],
  ASSIGNED_PROFILE_EFFECTS: ['effects.manage'],
  ASSIGNED_PROFILE_SPECIALS: ['profiles.edit'],
  ASSIGNED_PROFILE_SUBSCRIPTIONS: ['creators.manage'],
});

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

/** Expand legacy grant strings into dotted permissions. Unknown strings kept. */
export function expandLegacy(grants) {
  const out = [];
  for (const raw of grants || []) {
    const g = String(raw || '').trim();
    if (!g) continue;
    if (g === '*') { out.push('*'); continue; }
    if (LEGACY_PERMISSION_MAP[g]) out.push(...LEGACY_PERMISSION_MAP[g]);
    else out.push(g);
  }
  return unique(out);
}

export function normalizeRole(role) {
  const r = String(role || 'USER').toUpperCase();
  return LEGACY_ROLE_ALIASES[r] || r;
}

/**
 * Effective permissions of a user: role defaults + explicit grants, expanded
 * from legacy names. `*` only ever comes from SUPER_ADMIN or an explicit grant.
 */
export function effectivePermissions(user) {
  if (!user) return [];
  const role = normalizeRole(user.role);
  const defaults = ROLE_PERMISSIONS[role] || [];
  if (defaults.includes('*')) return ['*'];
  return unique([...defaults, ...expandLegacy(toArray(user.adminPermissions))]);
}

export function toArray(value) {
  if (Array.isArray(value)) return value.map((v) => String(v));
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed.map((v) => String(v));
    } catch { /* not JSON */ }
    return value.split(',').map((v) => v.trim());
  }
  return [];
}

/** True when the user holds `permission` (dotted or legacy name). */
export function hasPermission(user, permission) {
  if (!user || user.isBanned) return false;
  const perms = effectivePermissions(user);
  if (perms.includes('*')) return true;
  const wanted = expandLegacy([String(permission)]);
  return wanted.some((p) => perms.includes(p));
}

// Live-room staff roles. A room host may appoint Moderators and Assistant
// Moderators; each role has a distinct, enforced capability set.
export const LIVE_ROLE_PERMISSIONS = Object.freeze({
  MODERATOR: ['comments.delete', 'comments.pin', 'live.mute', 'live.remove', 'live.end'],
  ASSISTANT_MODERATOR: ['comments.delete', 'live.report'],
});

/**
 * True when a LiveModerator row grants `permission`. An explicit `permissions`
 * JSON list on the row is honoured on top of the role defaults.
 */
export function liveStaffCan(staffRow, permission) {
  if (!staffRow) return false;
  let role = String(staffRow.role || 'ASSISTANT_MODERATOR').toUpperCase();
  if (role === 'ASSISTANT') role = 'ASSISTANT_MODERATOR';
  if (role === 'FULL_MODERATOR') role = 'MODERATOR';
  const defaults = LIVE_ROLE_PERMISSIONS[role] || [];
  let extra = [];
  try {
    const p = staffRow.permissions;
    if (Array.isArray(p)) extra = p.map(String);
    else if (typeof p === 'string') extra = JSON.parse(p);
  } catch { /* ignore malformed */ }
  return defaults.includes(permission) || extra.includes(permission) || extra.includes('*');
}

/** Permissions that may only be held by a SUPER_ADMIN (guarded grants). */
export const SUPER_ADMIN_ONLY_PERMISSIONS = Object.freeze([
  'permissions.grant', 'permissions.revoke', 'admins.create', 'admins.delete',
  'settings.edit',
]);
