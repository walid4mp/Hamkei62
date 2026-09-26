import 'dotenv/config';
import bcrypt from 'bcryptjs';
import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

// Idempotent demo accounts: re-running never duplicates a user.
const SCALE_TEST = [
  { username:'nova300k', displayName:'Nova Creator 300K', email:'nova300k@demo.socialnova.app', followers:300000, following:1200 },
  { username:'nova500k', displayName:'Nova Creator 500K', email:'nova500k@demo.socialnova.app', followers:500000, following:2500 },
  { username:'nova1m', displayName:'Nova Creator 1M', email:'nova1m@demo.socialnova.app', followers:1000000, following:5000 },
  { username:'nova2m', displayName:'Nova Creator 2M', email:'nova2m@demo.socialnova.app', followers:2000000, following:8000 },
  { username:'nova5m', displayName:'Nova Creator 5M', email:'nova5m@demo.socialnova.app', followers:5000000, following:15000 },
];

const EXTRA_GMAIL = [
  { username:'walidpro1', displayName:'Walid Pro 1', email:'walidpro1@gmail.com' },
  { username:'walidpro2', displayName:'Walid Pro 2', email:'walidpro2@gmail.com' },
  { username:'walidpro3', displayName:'Walid Pro 3', email:'walidpro3@gmail.com' },
  { username:'walidpro4', displayName:'Walid Pro 4', email:'walidpro4@gmail.com' },
  { username:'walidpro5', displayName:'Walid Pro 5', email:'walidpro5@gmail.com' },
];

const DEMO = [
  { username: 'Walkd', displayName: 'Walidnnn', email: 'ww6083ss5u2@gmail.com', tier: 'PRO', bio: 'حساب تجريبي للاختبار', location: 'SocialNova', gender: '' },
  { username: 'devnova', displayName: 'SocialNova Developer', email: 'devnova@socialnova.app', tier: 'PRO', bio: 'حساب مطور رسمي • إدارة المنصة', location: 'SocialNova HQ', gender: '' },
  { username: 'devdesign', displayName: 'SocialNova Design', email: 'devdesign@socialnova.app', tier: 'PRO', bio: 'تصميم وتجربة المستخدم', location: 'SocialNova HQ', gender: '' },
  { username: 'devmedia', displayName: 'SocialNova Media', email: 'devmedia@socialnova.app', tier: 'PRO', bio: 'الإعلام والمحتوى', location: 'SocialNova HQ', gender: '' },
  { username: 'devsupport', displayName: 'SocialNova Support', email: 'devsupport@socialnova.app', tier: 'PRO', bio: 'الدعم وإدارة المجتمع', location: 'SocialNova HQ', gender: '' },
  { username: 'devlive', displayName: 'SocialNova Live', email: 'devlive@socialnova.app', tier: 'PRO', bio: 'البث المباشر والاتصالات', location: 'SocialNova HQ', gender: '' },
  { username: 'lina',     displayName: 'لينا خالد',  email: 'lina@socialnova.app',     tier: 'PRO',    bio: 'مصممة واجهات • مشاركة يومية ✨', location: 'الرياض', website: 'https://lina.design', gender: 'أنثى' },
  { username: 'omar',     displayName: 'عمر يوسف',   email: 'omar@socialnova.app',     tier: 'NORMAL', bio: 'مبرمج تطبيقات موبايل.', location: 'دبي', gender: 'ذكر' },
  { username: 'sara',     displayName: 'سارة أحمد',  email: 'sara@socialnova.app',     tier: 'NONE',   bio: 'أحب التصوير والسفر 📷', location: 'القاهرة', gender: 'أنثى' },
  { username: 'youssef',  displayName: 'يوسف الغامدي', email: 'youssef@socialnova.app', tier: 'NONE',  bio: 'رياضة وتغذية.', location: 'جدة', gender: 'ذكر' },
  { username: 'nour',     displayName: 'نور حسن',    email: 'nour@socialnova.app',     tier: 'NORMAL', bio: 'محتوى تعليمي وبرمجة.', location: 'عمّان', gender: 'أنثى' },
  { username: 'adam',     displayName: 'آدم التميمي', email: 'adam@socialnova.app',    tier: 'NONE',   bio: 'موسيقى وهندسة صوت.', location: 'بيروت', gender: 'ذكر' },
];

async function main() {
  const passwordHash = await bcrypt.hash('demo1234', 10);
  for (const u of DEMO) {
    await prisma.user.upsert({
      where: { username: u.username },
      update: { verificationTier: u.tier, isVerified: u.tier !== 'NONE', role: u.username.startsWith('dev') ? 'DEVELOPER' : 'USER' },
      create: {
        username: u.username,
        email: u.email,
        displayName: u.displayName,
        passwordHash,
        bio: u.bio,
        location: u.location,
        website: u.website,
        gender: u.gender,
        verificationTier: u.tier,
        isVerified: u.tier !== 'NONE',
        role: u.username.startsWith('dev') ? 'DEVELOPER' : 'USER',
      },
    });
  }
  for (const u of EXTRA_GMAIL) {
    const account = await prisma.user.upsert({
      where: { username: u.username },
      update: { email: u.email, displayName: u.displayName, verificationTier:'PRO', isVerified:true, role:'USER' },
      create: { username:u.username, email:u.email, displayName:u.displayName, passwordHash, bio:'حساب تجريبي SocialNova بكامل الميزات', location:'SocialNova', verificationTier:'PRO', isVerified:true, role:'USER', demoFollowersCount:100000, demoFollowingCount:500 },
    });
    await prisma.wallet.upsert({
      where:{userId:account.id},
      update:{coinBalance:999999999, withdrawableCoins:0, lifetimePurchased:999999999, lifetimeReceived:999999999},
      create:{userId:account.id, coinBalance:999999999, lifetimePurchased:999999999, lifetimeReceived:999999999},
    });
  }

  const walid = await prisma.user.findUnique({ where: { username: 'Walkd' } });
  if (walid) {
    await prisma.wallet.upsert({
      where: { userId: walid.id },
      update: { coinBalance: 999999999, withdrawableCoins: 0, lifetimePurchased: 999999999, lifetimeReceived: 999999999 },
      create: { userId: walid.id, coinBalance: 999999999, lifetimePurchased: 999999999, lifetimeReceived: 999999999 },
    });
  }

  for (const u of SCALE_TEST) {
    const account = await prisma.user.upsert({
      where: { username: u.username },
      update: { displayName:u.displayName, demoFollowersCount:u.followers, demoFollowingCount:u.following, isVerified:true, verificationTier:'PRO', role:'DEVELOPER' },
      create: { username:u.username, email:u.email, displayName:u.displayName, passwordHash, bio:'حساب تجريبي SocialNova لاختبار المقاييس والميزات • DEMO', verificationTier:'PRO', isVerified:true, role:'DEVELOPER', demoFollowersCount:u.followers, demoFollowingCount:u.following },
    });
    await prisma.wallet.upsert({
      where:{userId:account.id},
      update:{coinBalance:999999999, withdrawableCoins:0, lifetimePurchased:999999999, lifetimeReceived:999999999},
      create:{userId:account.id, coinBalance:999999999, lifetimePurchased:999999999, lifetimeReceived:999999999},
    });
    const postCount = await prisma.post.count({where:{authorId:account.id}});
    if (postCount === 0) {
      await prisma.post.create({data:{authorId:account.id, caption:'منشور تجريبي لاختبار SocialNova 🚀 #SocialNova #Demo', type:'TEXT', visibility:'PUBLIC'}});
    }
  }

  // Developer accounts are real seed accounts. Their followers are explicitly
  // marked as demo accounts so the UI never represents them as real people.
  const devs = DEMO.filter(x => x.username.startsWith('dev'));
  for (const d of devs) {
    const target = await prisma.user.findUnique({ where: { username: d.username } });
    if (!target) continue;
    for (let i = 1; i <= 25; i++) {
      const username = `f_${d.username}_${i}`.slice(0, 30);
      const follower = await prisma.user.upsert({
        where: { username },
        update: {},
        create: { username, email: `${username}@demo.socialnova.app`, displayName: `متابع تجريبي ${i}`, passwordHash },
      });
      await prisma.follow.upsert({ where: { followerId_followingId: { followerId: follower.id, followingId: target.id } }, update: {}, create: { followerId: follower.id, followingId: target.id } });
    }
  }
  // Two persistent demo live rooms so the Live tab is never empty during testing.
  for (const [i, username] of ['nova1m','nova5m'].entries()) {
    const host = await prisma.user.findUnique({where:{username}});
    if (!host) continue;
    const roomName = `demo_${username}`;
    await prisma.liveRoom.upsert({
      where:{roomName},
      update:{status:'LIVE', title:i===0?'Nova Live • 1M Demo':'Nova Live • 5M Demo'},
      create:{hostId:host.id, roomName, title:i===0?'Nova Live • 1M Demo':'Nova Live • 5M Demo', status:'LIVE', viewerCount:0}
    });
  }

  const count = await prisma.user.count();
  console.log(`[seed] developer/demo accounts ready — total users: ${count}`);
}

main()
  .catch((e) => console.error('[seed] skipped:', e.message))
  .finally(() => prisma.$disconnect());
