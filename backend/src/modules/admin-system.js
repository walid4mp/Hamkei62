// SocialNova Admin System contract. Mount these checks from server.js when the
// corresponding production admin routes are implemented.
const ADMIN_ROLES = Object.freeze({
  SUPER_ADMIN: ['*'],
  ADMIN: ['users','creators','content','reports','settings'],
  MODERATOR: ['reports','content_moderation','live_moderation','communities'],
  FINANCE: ['payments','subscriptions','ad_revenue','creator_payouts'],
  CONTENT_MANAGER: ['movies','series','episodes','posts','featured_content'],
  SUPPORT: ['users','tickets','reports_read'],
  ANALYTICS: ['analytics']
});

function hasPermission(role, permission) {
  const permissions = ADMIN_ROLES[role] || [];
  return permissions.includes('*') || permissions.includes(permission);
}

module.exports = { ADMIN_ROLES, hasPermission };
