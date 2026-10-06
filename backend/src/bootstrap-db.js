import 'dotenv/config';
import { PrismaClient } from '@prisma/client';
import { execFile } from 'child_process';
import { promisify } from 'util';
import path from 'path';

const prisma = new PrismaClient();
const execFileAsync = promisify(execFile);

try {
  const rows = await prisma.$queryRawUnsafe(`SELECT to_regclass('"User"')::text AS name`);
  const exists = Boolean(rows?.[0]?.name);
  if (!exists) {
    const npx = process.platform === 'win32' ? 'npx.cmd' : 'npx';
    console.log('[database] Empty database detected; creating the complete Prisma schema...');
    await execFileAsync(npx, ['prisma', 'db', 'push', '--skip-generate', '--accept-data-loss'], {
      cwd: path.resolve(process.cwd()), timeout: 180000, maxBuffer: 8 * 1024 * 1024,
    });
    console.log('[database] Complete Prisma schema created.');
  } else {
    console.log('[database] Existing database detected; preserving existing data and using additive compatibility migrations.');
  }
} finally {
  await prisma.$disconnect();
}
