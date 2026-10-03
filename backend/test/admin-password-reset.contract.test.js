import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync(new URL('../src/server.js', import.meta.url), 'utf8');
assert.match(source, /app\.post\('\/api\/admin\/reset-password',auth,requirePermission\('users\.edit'\)/);
assert.match(source, /bcrypt\.hash\(temporaryPassword,12\)/);
assert.match(source, /temporaryPasswordLength:8/);
assert.match(source, /tokenVersion.*\+1/);
assert.doesNotMatch(source, /metadata:JSON\.stringify\(\{[^}]*temporaryPassword/);
console.log('admin password reset contract: OK');
