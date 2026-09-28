import 'dotenv/config';
import express from 'express'; import cors from 'cors'; import morgan from 'morgan'; import bcrypt from 'bcryptjs'; import jwt from 'jsonwebtoken'; import {PrismaClient} from '@prisma/client'; import {createServer} from 'http'; import {Server} from 'socket.io'; import {z} from 'zod'; import crypto from 'crypto';
import multer from 'multer';
import path from 'path';
import {fileURLToPath} from 'url';
import fs from 'fs';
import {promisify} from 'util';
import {execFile} from 'child_process';
import https from 'https';
import { AccessToken } from 'livekit-server-sdk';
import { buildGiftCatalog, GIFT_CATEGORIES } from './modules/gifts.js';
import { liveStaffCan } from './modules/permissions.js';
import { PERMISSIONS, ROLES, ROLE_PERMISSIONS, effectivePermissions, hasPermission, normalizeRole, expandLegacy, toArray, SUPER_ADMIN_ONLY_PERMISSIONS } from './modules/permissions.js';
const __filename=fileURLToPath(import.meta.url);
const __dirname=path.dirname(__filename);
const execFileAsync=promisify(execFile);
const prisma=new PrismaClient(); const app=express(); const http=createServer(app);

// CORS: an explicit allow-list when configured; otherwise reflect the request
// origin (native apps send none). Never credentials-with-wildcard.
const CORS_ORIGINS=(process.env.CORS_ORIGIN||'').split(',').map(x=>x.trim()).filter(Boolean);
app.use(cors({origin:CORS_ORIGINS.length?CORS_ORIGINS:true,credentials:false}));
// Baseline security headers (dependency-free).
app.use((req,res,next)=>{res.setHeader('X-Content-Type-Options','nosniff');res.setHeader('X-Frame-Options','DENY');res.setHeader('Referrer-Policy','no-referrer');res.setHeader('X-XSS-Protection','0');res.setHeader('Strict-Transport-Security','max-age=15552000; includeSubDomains');res.setHeader('Permissions-Policy','geolocation=(), microphone=(self), camera=(self)');next();});
app.use(express.json({limit:'5mb'})); app.use(morgan('tiny'));

// ---- Idempotency for money/content mutations -------------------------------
// A client sends `Idempotency-Key` on every mutation (it reuses the same key
// across its own retries). Replayed keys return the stored response instead of
// executing the operation a second time. Keys are scoped to the caller so one
// user can never read another user's cached response.
const IDEMPOTENT_PATTERNS=[
  /^\/api\/wallet\//, /^\/api\/posts$/, /^\/api\/reels$/, /^\/api\/stories$/,
  /^\/api\/rewards\//, /^\/api\/creators\/subscri/, /^\/api\/friends\/.*transfer/,
];
// JWT-only pre-auth: identifies the caller for idempotency without hitting the
// DB. Route-level `auth` still performs the full validation.
app.use((req,res,next)=>{ try{ const h=req.headers.authorization||''; if(h.startsWith('Bearer ')) req.user=jwt.verify(h.slice(7),JWT_SECRET); }catch{} next(); });
app.use(async(req,res,next)=>{
  if(req.method!=='POST') return next();
  const key=String(req.headers['idempotency-key']||'').trim();
  if(!key || key.length<8 || key.length>200) return next();
  if(!IDEMPOTENT_PATTERNS.some(re=>re.test(req.path))) return next();
  const uid=req.user?.id||'';
  if(!uid) return next();
  try{
    const rows=await prisma.$queryRawUnsafe('SELECT "statusCode","response" FROM "IdempotencyRecord" WHERE "key"=$1 AND "userId"=$2 LIMIT 1',key,uid);
    if(rows?.[0]?.response){ res.status(rows[0].statusCode||200).type('application/json').send(rows[0].response); return; }
  }catch{}
  let stored=false;
  const remember=(body)=>{
    if(stored||!body) return; stored=true;
    try{ prisma.$executeRawUnsafe('INSERT INTO "IdempotencyRecord" ("key","userId","path","method","statusCode","response") VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT ("key") DO NOTHING',key,uid,req.path,'POST',res.statusCode||200,String(body)).catch(()=>{}); }catch{}
  };
  const origJson=res.json.bind(res);
  const origSend=res.send.bind(res);
  res.json=(body)=>{ if((res.statusCode||200)<500){ try{remember(JSON.stringify(body));}catch{} } return origJson(body); };
  res.send=(body)=>{ if((res.statusCode||200)<500){ try{remember(typeof body==='string'?body:JSON.stringify(body));}catch{} } return origSend(body); };
  next();
});
app.use('/admin-assets',express.static(path.join(__dirname,'admin-assets')));
const io=new Server(http,{cors:{origin:'*'}});
// A known JWT secret is a critical vulnerability. Require JWT_SECRET in
// production; otherwise fall back to a random per-boot secret (sessions are
// intentionally invalidated on restart) and warn loudly.
let JWT_SECRET=process.env.JWT_SECRET||'';
if(!JWT_SECRET||JWT_SECRET==='change-me'){
  JWT_SECRET=crypto.randomBytes(48).toString('hex');
  console.warn('[security] JWT_SECRET is not set (or is the default) — using a random ephemeral secret. Set JWT_SECRET in production.');
}
const safe=u=>{if(!u)return null; const {passwordHash,...x}=u; return x}; const sign=u=>jwt.sign({id:u.id,username:u.username,email:u.email,role:u.role||'USER',tv:Number(u.tokenVersion||0)},JWT_SECRET,{expiresIn:'30d'});
const RELATIONSHIP_TYPES=new Set(['SINGLE','IN_RELATIONSHIP','ENGAGED','MARRIED','CIVIL_UNION','DOMESTIC_PARTNERSHIP','OPEN_RELATIONSHIP','COMPLICATED','SEPARATED','DIVORCED','WIDOWED']);
async function relationshipFor(userId, viewerId){
  const user=await prisma.user.findUnique({where:{id:userId},select:{relationshipStatus:true,relationshipSince:true}});
  const row=await prisma.relationship.findFirst({where:{status:{in:['ACTIVE','PENDING']},OR:[{requesterId:userId},{partnerId:userId}]},orderBy:{createdAt:'desc'},include:{requester:true,partner:true}});
  if(!row)return {type:user?.relationshipStatus||'SINGLE',status:'NONE',since:user?.relationshipSince||null,partner:null};
  const partner=row.requesterId===userId?row.partner:row.requester;
  return {id:row.id,type:row.type,status:row.status,since:row.since||user?.relationshipSince||null,createdAt:row.createdAt,partner:safe(partner),isRequester:row.requesterId===viewerId,isIncoming:row.partnerId===viewerId&&row.status==='PENDING'};
}

function profileUser(u,extra={}){return {...safe(u),...extra};}

async function statusRingsForUserIds(userIds, viewerId){
  const ids=[...new Set(userIds.map(String).filter(Boolean))];
  if(!ids.length)return new Map();
  const now=new Date();
  const recent=new Date(Date.now()-24*60*60*1000);
  const [lives,stories,posts,reels]=await Promise.all([
    prisma.liveRoom.findMany({where:{hostId:{in:ids},status:'LIVE'},select:{hostId:true,createdAt:true}}),
    prisma.story.findMany({where:{authorId:{in:ids},expiresAt:{gt:now}},select:{authorId:true,id:true,createdAt:true},orderBy:{createdAt:'desc'}}),
    prisma.post.findMany({where:{authorId:{in:ids},createdAt:{gte:recent}},select:{authorId:true,id:true,createdAt:true},orderBy:{createdAt:'desc'}}),
    prisma.reel.findMany({where:{authorId:{in:ids},createdAt:{gte:recent}},select:{authorId:true,id:true,createdAt:true},orderBy:{createdAt:'desc'}})
  ]);
  const out=new Map();
  for(const id of ids)out.set(id,{live:false,story:false,post:false,reel:false,segments:[]});
  for(const x of lives){const v=out.get(x.hostId);if(v)v.live=true;}
  for(const x of stories){const v=out.get(x.authorId);if(v)v.story=true;}
  for(const x of posts){const v=out.get(x.authorId);if(v)v.post=true;}
  for(const x of reels){const v=out.get(x.authorId);if(v)v.reel=true;}
  for(const [id,v] of out){
    // Stable order is intentional: LIVE -> STORY -> POST -> REEL.
    v.segments=[...(v.live?['LIVE']:[]),...(v.story?['STORY']:[]),...(v.post?['POST']:[]),...(v.reel?['REEL']:[])];
    v.hasNewContent=v.story||v.post||v.reel;
  }
  return out;
}
function withStatus(user,statusMap){
  if(!user)return null;
  const x=safe(user); const s=statusMap?.get(user.id);
  return s?{...x,statusRings:s}:x;
}

async function notifyMentions(body, text){
  const names=[...String(body||'').matchAll(/@([A-Za-z0-9_.-]{2,40})/g)].map(m=>m[1].toLowerCase());
  if(!names.length)return;
  const users=await prisma.user.findMany({where:{username:{in:names},isBanned:false},select:{id:true,username:true}});
  for(const u of users){await prisma.notification.create({data:{userId:u.id,type:'MENTION',text:text||`تمت الإشارة إليك @${u.username}`}});}
}
function auth(req,res,next){(async()=>{try{const h=req.headers.authorization||''; if(!h.startsWith('Bearer ')) throw 0; req.user=jwt.verify(h.slice(7),JWT_SECRET); const did=rawDeviceId(req); if(did && await isDeviceBanned(did)) return res.status(403).json({error:'DEVICE_BANNED'}); // Account-close check is best-effort: if the additive column is missing on an older database we must not lock existing users out.
    try{const row=await prisma.user.findUnique({where:{id:req.user.id},select:{isDeactivated:true,tokenVersion:true}}); if(row?.isDeactivated===true) return res.status(403).json({error:'ACCOUNT_CLOSED'}); if(row && Number(req.user.tv??0)!==Number(row.tokenVersion??0)) return res.status(401).json({error:'SESSION_REVOKED'});}catch{} next()}catch{res.status(401).json({error:'UNAUTHORIZED'})}})()}
// Account status + moderation flags for the client, without leaking the hash.
function publicUser(u){ if(!u) return null; return {...safe(u), permissions: effectiveFor(u)}; }
function rawDeviceId(req, body={}){ return String(req.headers['x-device-id'] || body.deviceId || '').trim().slice(0,256); }
function deviceHash(deviceId){ if(!deviceId) return ''; return crypto.createHash('sha256').update(`${process.env.DEVICE_BAN_SALT||JWT_SECRET}:device:${deviceId}`).digest('hex'); }
async function ensureDeviceBanTable(){
  await prisma.$executeRawUnsafe(`CREATE TABLE IF NOT EXISTS "DeviceBan" ("id" text PRIMARY KEY, "deviceHash" text UNIQUE NOT NULL, "reason" text NOT NULL DEFAULT '', "actorId" text, "bannedAt" timestamptz NOT NULL DEFAULT now(), "expiresAt" timestamptz, "revokedAt" timestamptz)`);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "DeviceBan_deviceHash_idx" ON "DeviceBan"("deviceHash")`);
  await prisma.$executeRawUnsafe(`CREATE TABLE IF NOT EXISTS "DeviceSeen" ("id" text PRIMARY KEY, "userId" text NOT NULL, "deviceHash" text NOT NULL, "firstSeenAt" timestamptz NOT NULL DEFAULT now(), "lastSeenAt" timestamptz NOT NULL DEFAULT now(), UNIQUE("userId","deviceHash"))`);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "DeviceSeen_userId_idx" ON "DeviceSeen"("userId")`);
  await prisma.$executeRawUnsafe(`CREATE INDEX IF NOT EXISTS "DeviceSeen_deviceHash_idx" ON "DeviceSeen"("deviceHash")`);
}
async function rememberDevice(userId,deviceId){
  const h=deviceHash(deviceId); if(!userId||!h)return;
  await prisma.$executeRawUnsafe(`INSERT INTO "DeviceSeen" ("id","userId","deviceHash") VALUES ($1,$2,$3) ON CONFLICT ("userId","deviceHash") DO UPDATE SET "lastSeenAt"=now()`,crypto.randomUUID(),userId,h).catch(()=>{});
}
async function isDeviceBanned(deviceId){
  const h=deviceHash(deviceId); if(!h) return false;
  const rows=await prisma.$queryRawUnsafe(`SELECT "id","expiresAt","revokedAt" FROM "DeviceBan" WHERE "deviceHash"=$1 LIMIT 1`,h);
  const row=rows[0]; if(!row || row.revokedAt) return false;
  if(row.expiresAt && new Date(row.expiresAt).getTime() <= Date.now()) return false;
  return true;
}
async function requireAllowedDevice(req,res,next){
  try{ const id=rawDeviceId(req); if(id && await isDeviceBanned(id)) return res.status(403).json({error:'DEVICE_BANNED'}); next(); }
  catch(e){ next(e); }
}


const MODERATION_PERMISSIONS=[
  'POST_MODERATION','REEL_MODERATION','STORY_MODERATION','COMMENT_MODERATION',
  'LIVE_MODERATION','GROUP_MODERATION','USER_MODERATION','REPORTS','CONVERSATION_REVIEW'
];
const STAFF_PERMISSION_CATALOG=[
  ...MODERATION_PERMISSIONS,
  'VIEW_ANALYTICS','VIEW_AD_REVENUE','MANAGE_GIFTS','MANAGE_MUSIC','MANAGE_MOVIES',
  'MANAGE_SERIES','MANAGE_EPISODES','MANAGE_PROMOTIONS','MANAGE_CREATOR_PAYOUTS',
  'MANAGE_SUBSCRIPTIONS','MANAGE_PAYMENTS','MANAGE_XP','MANAGE_COMMUNITIES',
  'MANAGE_AI','MANAGE_SETTINGS','MANAGE_ADMIN_ROLES','VIEW_AUDIT_LOGS',
  'MANAGE_ASSIGNED_PROFILES','ASSIGNED_PROFILE_BAN','ASSIGNED_PROFILE_VERIFY','ASSIGNED_PROFILE_FEATURE','ASSIGNED_PROFILE_COINS','ASSIGNED_PROFILE_EFFECTS','ASSIGNED_PROFILE_SPECIALS','ASSIGNED_PROFILE_SUBSCRIPTIONS'
];
function permissionArray(value){return toArray(value);}
async function currentAdmin(req){
  if(!req.user?.id)return null;
  return prisma.user.findUnique({where:{id:req.user.id},select:{id:true,email:true,role:true,adminPermissions:true,specialFeatures:true,isBanned:true}});
}
// All permission checks go through the central catalog (modules/permissions.js).
// `hasPermission` accepts either a dotted permission or a legacy constant.
async function superAdmin(req,res,next){
  const u=await currentAdmin(req);
  if(isSuperAdmin(u))return next();
  return res.status(403).json({error:'SUPER_ADMIN_ONLY'});
}
async function staffPermission(permission){
  return async (req,res,next)=>{
    const u=await currentAdmin(req);
    if(hasPermission(u,permission))return next();
    return res.status(403).json({error:'PERMISSION_DENIED',permission});
  };
}
function adminEmailList(){return (process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);}
function isAdminEmail(email){const e=String(email||'').toLowerCase();return e?adminEmailList().includes(e):false;}
// Route permission guard. Every admin endpoint names the permission it needs;
// SUPER_ADMIN is the only role that carries the wildcard. ADMIN_EMAILS is a
// bootstrap-only list (see ensureSuperAdmin) and does NOT bypass runtime checks.
function requirePermission(permission){ return async function(req,res,next){ try{ const u=await currentAdmin(req); if(hasPermission(u,permission))return next(); return res.status(403).json({error:'PERMISSION_DENIED',permission}); }catch(e){ return res.status(500).json({error:'PERMISSION_CHECK_FAILED'}); } }; }
async function requireAnyPermission(list){ return async function(req,res,next){ try{ const u=await currentAdmin(req); if(list.some(p=>hasPermission(u,p)))return next(); return res.status(403).json({error:'PERMISSION_DENIED',permission:list.join('|')}); }catch(e){ return res.status(500).json({error:'PERMISSION_CHECK_FAILED'}); } }; }

// ---- Audit log -----------------------------------------------------------
// Rich audit helper: every sensitive action records who did what to whom, the
// permission used, before/after, request IP/device and the result.
async function auditAction(req, action, { permission='', targetUserId=null, targetType='', targetId='', before=null, after=null, result='OK' }={}){
  try{
    const actor=await currentAdmin(req);
    await prisma.auditLog.create({data:{
      actorId:req.user?.id||'system',
      action:String(action).slice(0,120),
      targetUserId:targetUserId||null,
      metadata:JSON.stringify({
        actorRole:actor?.role||'', permission, targetType, targetId,
        before, after, ip:req.ip||'', device:req.headers?.['x-device-id']||'', result,
      }),
    }});
  }catch(e){ console.warn('[audit]',e?.message||e); }
}

// Delivers a moderation report to every staff account with the matching
// permission. Uses raw SQL so it works regardless of client enum generation.
async function notifyStaffReport(permission, text){
  try{
    const staff=await prisma.user.findMany({where:{OR:[{role:{in:['ADMIN','DEVELOPER','SUPER_ADMIN','MODERATOR']}}]},select:{id:true},take:200});
    for(const s of staff){
      if(permission && !hasPermission(s,permission)) { if(!['ADMIN','DEVELOPER','SUPER_ADMIN','MODERATOR'].includes(String(s.role||'').toUpperCase())) continue; }
      await prisma.$executeRawUnsafe('INSERT INTO "Notification" ("id","userId","type","text","read","createdAt") VALUES (gen_random_uuid()::text,$1,\'REPORT\'::"NotificationType",$2,false,CURRENT_TIMESTAMP)',s.id,String(text||'').slice(0,500)).catch(()=>{});
    }
  }catch(e){ console.warn('[report]',e?.message||e); }
}

function isSuperAdmin(user){ return !!user && normalizeRole(user.role)==='SUPER_ADMIN'; }
function effectiveFor(user){ return effectivePermissions(user); }
// Bootstrap: guarantee at least one SUPER_ADMIN. ADMIN_EMAILS accounts are
// promoted once; otherwise the oldest DEVELOPER is promoted. This is the only
// place ADMIN_EMAILS has any effect at runtime — it never bypasses a
// permission check inside a request.
async function ensureSuperAdmin(){
  try{
    const existing=await prisma.user.count({where:{role:'SUPER_ADMIN'}});
    if(existing>0)return;
    const emails=adminEmailList();
    let promoted=0;
    if(emails.length){
      promoted=await prisma.user.updateMany({where:{email:{in:emails}},data:{role:'SUPER_ADMIN',adminPermissions:['*']}}).then(r=>r.count).catch(()=>0);
    }
    if(!promoted){
      const dev=await prisma.user.findFirst({where:{role:'DEVELOPER'},orderBy:{createdAt:'asc'}});
      if(dev){ await prisma.user.update({where:{id:dev.id},data:{role:'SUPER_ADMIN',adminPermissions:['*']}}); promoted=1; }
    }
    if(promoted)console.log('[admin] bootstrapped SUPER_ADMIN account(s):',promoted);
  }catch(e){ console.warn('[admin] ensureSuperAdmin skipped:',e?.message||e); }
}

let fcmAccessToken=null;
let fcmAccessTokenExpiresAt=0;
const b64url=v=>Buffer.from(v).toString('base64').replace(/=/g,'').replace(/\+/g,'-').replace(/\//g,'_');
async function getFcmAccessToken(){
  const projectId=String(process.env.FIREBASE_PROJECT_ID||'').trim();
  const clientEmail=String(process.env.FIREBASE_CLIENT_EMAIL||'').trim();
  const privateKey=String(process.env.FIREBASE_PRIVATE_KEY||'').replace(/\\n/g,'\n');
  if(!projectId||!clientEmail||!privateKey)return null;
  if(fcmAccessToken && Date.now()<fcmAccessTokenExpiresAt-60000)return fcmAccessToken;
  const now=Math.floor(Date.now()/1000);
  const header=b64url(JSON.stringify({alg:'RS256',typ:'JWT'}));
  const claim=b64url(JSON.stringify({iss:clientEmail,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}));
  const signer=crypto.createSign('RSA-SHA256'); signer.update(`${header}.${claim}`); signer.end();
  const assertion=`${header}.${claim}.${b64url(signer.sign(privateKey))}`;
  const body=`grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${encodeURIComponent(assertion)}`;
  const token=await new Promise((resolve,reject)=>{const r=https.request({hostname:'oauth2.googleapis.com',path:'/token',method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(body)}},res=>{let x='';res.on('data',d=>x+=d);res.on('end',()=>{try{const j=JSON.parse(x);if(!j.access_token)return reject(new Error('FCM_AUTH_FAILED'));resolve(j)}catch(e){reject(e)}})});r.on('error',reject);r.write(body);r.end()});
  fcmAccessToken=token.access_token; fcmAccessTokenExpiresAt=Date.now()+Number(token.expires_in||3600)*1000; return fcmAccessToken;
}
let googlePlayAccessToken=null;
let googlePlayAccessTokenExpiresAt=0;
async function getGooglePlayAccessToken(){
  const email=String(process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL||'').trim();
  const privateKey=String(process.env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY||'').replace(/\\n/g,'\n');
  if(!email||!privateKey)return null;
  if(googlePlayAccessToken && Date.now()<googlePlayAccessTokenExpiresAt-60000)return googlePlayAccessToken;
  const now=Math.floor(Date.now()/1000); const header=b64url(JSON.stringify({alg:'RS256',typ:'JWT'}));
  const claim=b64url(JSON.stringify({iss:email,scope:'https://www.googleapis.com/auth/androidpublisher',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}));
  const signer=crypto.createSign('RSA-SHA256'); signer.update(`${header}.${claim}`); signer.end();
  const assertion=`${header}.${claim}.${b64url(signer.sign(privateKey))}`;
  const body=`grant_type=${encodeURIComponent('urn:ietf:params:oauth:grant-type:jwt-bearer')}&assertion=${encodeURIComponent(assertion)}`;
  const token=await new Promise((resolve,reject)=>{const r=https.request({hostname:'oauth2.googleapis.com',path:'/token',method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded','Content-Length':Buffer.byteLength(body)}},res=>{let x='';res.on('data',d=>x+=d);res.on('end',()=>{try{const j=JSON.parse(x);if(!j.access_token)return reject(new Error('GOOGLE_PLAY_AUTH_FAILED'));resolve(j)}catch(e){reject(e)}})});r.on('error',reject);r.write(body);r.end()});
  googlePlayAccessToken=token.access_token; googlePlayAccessTokenExpiresAt=Date.now()+Number(token.expires_in||3600)*1000; return googlePlayAccessToken;
}
function googlePlayConfigured(){return Boolean(process.env.GOOGLE_PLAY_PACKAGE_NAME&&process.env.GOOGLE_SERVICE_ACCOUNT_EMAIL&&process.env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY);}
async function googlePlayGet(pathname){const access=await getGooglePlayAccessToken();if(!access)throw new Error('GOOGLE_PLAY_NOT_CONFIGURED');return await new Promise((resolve,reject)=>{const r=https.request({hostname:'androidpublisher.googleapis.com',path:pathname,method:'GET',headers:{Authorization:`Bearer ${access}`}},res=>{let x='';res.on('data',d=>x+=d);res.on('end',()=>{let j={};try{j=JSON.parse(x)}catch{};if(res.statusCode>=200&&res.statusCode<300)return resolve(j);const e=new Error(`GOOGLE_PLAY_${res.statusCode}`);e.status=res.statusCode;e.body=j;reject(e)})});r.on('error',reject);r.end()});}
async function verifyGoogleOneTime(productId,purchaseToken){
  if(!googlePlayConfigured())return {configured:false,verified:false};
  const pkg=encodeURIComponent(String(process.env.GOOGLE_PLAY_PACKAGE_NAME).trim());
  const product=encodeURIComponent(productId); const token=encodeURIComponent(purchaseToken);
  const data=await googlePlayGet(`/androidpublisher/v3/applications/${pkg}/purchases/products/${product}/tokens/${token}`);
  return {configured:true,verified:Number(data.purchaseState)===0,data};
}
async function verifyGoogleSubscription(productId,purchaseToken){
  if(!googlePlayConfigured())return {configured:false,verified:false};
  const pkg=encodeURIComponent(String(process.env.GOOGLE_PLAY_PACKAGE_NAME).trim()); const token=encodeURIComponent(purchaseToken);
  const data=await googlePlayGet(`/androidpublisher/v3/applications/${pkg}/purchases/subscriptionsv2/tokens/${token}`);
  const line=(data.lineItems||[]).find(x=>x.productId===productId) || data.lineItems?.[0];
  const state=String(data.subscriptionState||''); const active=['SUBSCRIPTION_STATE_ACTIVE','SUBSCRIPTION_STATE_IN_GRACE_PERIOD'].includes(state);
  return {configured:true,verified:active,data,line};
}

async function sendFcmToUser(userId,data,notification){
  if(process.env.FCM_DISABLED==='true')return;
  const u=await prisma.user.findUnique({where:{id:userId},select:{fcmToken:true,pushNotifications:true}});
  if(!u?.pushNotifications||!u.fcmToken)return;
  const access=await getFcmAccessToken(); if(!access)return;
  const projectId=String(process.env.FIREBASE_PROJECT_ID||'').trim(); if(!projectId)return;
  const message={message:{token:u.fcmToken,data:Object.fromEntries(Object.entries(data||{}).map(([k,v])=>[k,String(v??'')])),...(notification?{notification}:{}),android:{priority:'high'}}};
  const body=JSON.stringify(message);
  await new Promise((resolve,reject)=>{const r=https.request({hostname:'fcm.googleapis.com',path:`/v1/projects/${encodeURIComponent(projectId)}/messages:send`,method:'POST',headers:{Authorization:`Bearer ${access}`,'Content-Type':'application/json','Content-Length':Buffer.byteLength(body)}},res=>{let x='';res.on('data',d=>x+=d);res.on('end',()=>{if(res.statusCode>=200&&res.statusCode<300)return resolve();if(res.statusCode===404||res.statusCode===400){prisma.user.update({where:{id:userId},data:{fcmToken:''}}).catch(()=>{});}reject(new Error(`FCM_SEND_FAILED:${res.statusCode}`));})});r.on('error',reject);r.write(body);r.end()}).catch(e=>console.warn('[fcm]',e.message));
}

async function ensureAdminLogin(){
  const email=String(process.env.ADMIN_LOGIN_EMAIL||'').trim().toLowerCase();
  const password=String(process.env.ADMIN_LOGIN_PASSWORD||'');
  if(!email || !password){console.warn('[admin] ADMIN_LOGIN_EMAIL/ADMIN_LOGIN_PASSWORD not configured; use an existing DEVELOPER account or ADMIN_EMAILS.');return;}
  if(password.length<8){console.warn('[admin] ADMIN_LOGIN_PASSWORD must be at least 8 characters; dedicated admin login was not created.');return;}
  const username=String(process.env.ADMIN_LOGIN_USERNAME||'admin').trim().replace(/[^a-zA-Z0-9_.]/g,'').slice(0,30)||'admin';
  const passwordHash=await bcrypt.hash(password,12);
  const existing=await prisma.user.findUnique({where:{email}});
  if(existing){
    await prisma.user.update({where:{id:existing.id},data:{username:existing.username,displayName:existing.displayName||'SocialNova Admin',passwordHash,role:'DEVELOPER',isVerified:true,isBanned:false,adminPermissions:['*'],specialFeatures:['admin_panel']}});
    console.log(`[admin] dedicated admin login ready for ${email}`);
    return;
  }
  let finalUsername=username;
  const same=await prisma.user.findUnique({where:{username:finalUsername}});
  if(same) finalUsername=`${username}_${crypto.randomBytes(3).toString('hex')}`.slice(0,30);
  await prisma.user.create({data:{username:finalUsername,email,displayName:process.env.ADMIN_LOGIN_NAME||'SocialNova Admin',passwordHash,role:'DEVELOPER',isVerified:true,adminPermissions:['*'],specialFeatures:['admin_panel']}});
  console.log(`[admin] dedicated admin account created for ${email}`);
}
const uploadDir=path.join(process.cwd(),'uploads'); fs.mkdirSync(uploadDir,{recursive:true});
app.use('/uploads',express.static(uploadDir));
const imageExts=new Set(['.jpg','.jpeg','.png','.webp','.gif','.heic','.heif','.bmp','.avif']);
const videoExts=new Set(['.mp4','.mov','.m4v','.webm','.avi','.mkv','.3gp','.3gpp','.ts']);
const audioExts=new Set(['.mp3','.m4a','.aac','.wav','.ogg','.oga','.flac']);
const mediaKind=(file)=>{const hint=String(file?.fieldname==='file'?'':(file?.mediaKind||'')).toUpperCase(); const mime=String(file?.mimetype||'').toLowerCase(); const ext=path.extname(String(file?.originalname||'')).toLowerCase(); if(hint==='IMAGE'||hint==='VIDEO'||hint==='AUDIO')return hint; if(mime.startsWith('image/')||imageExts.has(ext))return 'IMAGE'; if(mime.startsWith('video/')||videoExts.has(ext))return 'VIDEO'; if(mime.startsWith('audio/')||audioExts.has(ext))return 'AUDIO'; return null};
const upload=multer({storage:multer.diskStorage({destination:uploadDir,filename:(req,file,cb)=>{const ext=path.extname(file.originalname||'').toLowerCase();cb(null,`${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`)}}),limits:{fileSize:200*1024*1024},fileFilter:(req,file,cb)=>{const hinted=String(req.body?.mediaKind||'').toUpperCase(); const kind=['IMAGE','VIDEO','AUDIO'].includes(hinted)?hinted:mediaKind(file); cb(kind?null:new Error('UNSUPPORTED_MEDIA'),!!kind)}});
async function normalizeUploadedMedia(file,kind){
  if(!file || !['VIDEO','AUDIO'].includes(kind)) return file;
  const source=file.path;
  const base=path.join(uploadDir,`${Date.now()}-${crypto.randomBytes(6).toString('hex')}`);
  const out=kind==='VIDEO'?`${base}.mp4`:`${base}.m4a`;
  try{
    if(kind==='VIDEO'){
      await execFileAsync('ffmpeg',['-y','-i',source,'-map','0:v:0','-map','0:a?','-c:v','libx264','-preset','veryfast','-crf','23','-pix_fmt','yuv420p','-c:a','aac','-b:a','128k','-movflags','+faststart',out],{timeout:240000,maxBuffer:1024*1024*4});
    }else{
      await execFileAsync('ffmpeg',['-y','-i',source,'-vn','-c:a','aac','-b:a','192k','-movflags','+faststart',out],{timeout:120000,maxBuffer:1024*1024*4});
    }
    await fs.promises.unlink(source).catch(()=>{});
    const stat=await fs.promises.stat(out);
    return {...file,path:out,filename:path.basename(out),originalname:path.basename(out),mimetype:kind==='VIDEO'?'video/mp4':'audio/mp4',size:stat.size};
  }catch(err){
    await fs.promises.unlink(out).catch(()=>{});
    // Never silently keep an incompatible media file. The app plays a stable
    // MP4/H.264/AAC video or M4A/AAC audio, so report a real normalization error.
    throw new Error(`MEDIA_NORMALIZATION_FAILED:${kind}`);
  }
}
function cloudinaryConfigured(){
  return Boolean(process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET);
}

function cloudinaryUpload(file, kind){
  return new Promise((resolve,reject)=>{
    const cloud=String(process.env.CLOUDINARY_CLOUD_NAME||'').trim();
    const key=String(process.env.CLOUDINARY_API_KEY||'').trim();
    const secret=String(process.env.CLOUDINARY_API_SECRET||'').trim();
    if(!cloud||!key||!secret) return reject(new Error('STORAGE_NOT_CONFIGURED'));
    const timestamp=Math.floor(Date.now()/1000);
    const folder='socialnova/media';
    const signature=crypto.createHash('sha1').update(`folder=${folder}&timestamp=${timestamp}${secret}`).digest('hex');
    const boundary=`----SocialNova${crypto.randomBytes(12).toString('hex')}`;
    const fields={timestamp:String(timestamp),api_key:key,signature,folder};
    const resourceType=kind==='IMAGE'?'image':'video';
    const endpoint=`/v1_1/${encodeURIComponent(cloud)}/${resourceType}/upload`;
    const options={hostname:'api.cloudinary.com',path:endpoint,method:'POST',headers:{'Content-Type':`multipart/form-data; boundary=${boundary}`}};
    const req=https.request(options,(response)=>{
      let body='';
      response.setEncoding('utf8');
      response.on('data',chunk=>body+=chunk);
      response.on('end',()=>{
        let data=null; try{data=JSON.parse(body)}catch{}
        if(response.statusCode>=200&&response.statusCode<300&&data?.secure_url){
          resolve({url:data.secure_url,publicId:data.public_id||'',resourceType:data.resource_type||resourceType,bytes:data.bytes||file.size,format:data.format||''});
        }else{
          reject(new Error(`CLOUDINARY_UPLOAD_FAILED:${data?.error?.message||response.statusCode||'UNKNOWN'}`));
        }
      });
    });
    req.setTimeout(600000,()=>req.destroy(new Error('CLOUDINARY_UPLOAD_TIMEOUT')));
    req.on('error',reject);
    const line=(name,value)=>Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name=\"${name}\"\r\n\r\n${value}\r\n`);
    for(const [name,value] of Object.entries(fields)) req.write(line(name,value));
    req.write(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"${path.basename(file.path)}\"\r\nContent-Type: ${file.mimetype||'application/octet-stream'}\r\n\r\n`));
    const stream=fs.createReadStream(file.path);
    stream.on('error',err=>req.destroy(err));
    stream.on('end',()=>{req.end(Buffer.from(`\r\n--${boundary}--\r\n`));});
    stream.pipe(req,{end:false});
  });
}

async function downloadRemoteMedia(url, out){
  const u=new URL(String(url||''));
  if(!['http:','https:'].includes(u.protocol)) throw new Error('BAD_MEDIA_URL');
  await new Promise((resolve,reject)=>{
    const request=https.get(u,{headers:{'User-Agent':'SocialNova-Media/1.0'}},response=>{
      if(response.statusCode>=300&&response.statusCode<400&&response.headers.location){
        response.resume();
        return downloadRemoteMedia(new URL(response.headers.location,u).toString(),out).then(resolve,reject);
      }
      if(response.statusCode!==200){response.resume();return reject(new Error(`REMOTE_MEDIA_HTTP_${response.statusCode}`));}
      const stream=fs.createWriteStream(out);
      response.pipe(stream);
      stream.on('finish',()=>stream.close(resolve));
      stream.on('error',reject);
    });
    request.setTimeout(120000,()=>request.destroy(new Error('REMOTE_MEDIA_TIMEOUT')));
    request.on('error',reject);
  });
}

app.post('/api/media/mix',auth,async(req,res)=>{
  let videoPath='',musicPath='',outPath='';
  try{
    const d=z.object({videoUrl:z.string().url(),musicUrl:z.string().url(),durationSec:z.number().int().min(1).max(300).optional()}).parse(req.body);
    const base=path.join(uploadDir,`mix-${Date.now()}-${crypto.randomBytes(6).toString('hex')}`);
    videoPath=`${base}-video`; musicPath=`${base}-music`; outPath=`${base}.mp4`;
    await downloadRemoteMedia(d.videoUrl,videoPath);
    await downloadRemoteMedia(d.musicUrl,musicPath);
    const args=['-y','-i',videoPath,'-stream_loop','-1','-i',musicPath];
    if(d.durationSec) args.push('-t',String(d.durationSec));
    let videoHasAudio=true;
    try{
      const probe=await execFileAsync('ffprobe',['-v','error','-select_streams','a:0','-show_entries','stream=index','-of','csv=p=0',videoPath],{timeout:30000,maxBuffer:1024*1024});
      videoHasAudio=String(probe.stdout||'').trim().length>0;
    }catch{ videoHasAudio=false; }
    args.push('-map','0:v:0');
    if(videoHasAudio){
      args.push('-filter_complex','[0:a]aresample=async=1:first_pts=0[a0];[1:a]aresample=async=1:first_pts=0[a1];[a0][a1]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[aout]','-map','[aout]');
    }else{
      args.push('-map','1:a:0');
    }
    args.push('-c:v','copy','-c:a','aac','-b:a','192k','-movflags','+faststart','-shortest',outPath);
    await execFileAsync('ffmpeg',args,{timeout:240000,maxBuffer:1024*1024*8});
    const fake={path:outPath,mimetype:'video/mp4',size:(await fs.promises.stat(outPath)).size,filename:path.basename(outPath)};
    const stored=await cloudinaryUpload(fake,'VIDEO');
    res.status(201).json({url:stored.url,type:'VIDEO',storage:'cloudinary',publicId:stored.publicId});
  }catch(e){
    res.status(422).json({error:'MEDIA_MIX_FAILED',detail:String(e?.message||e).slice(0,180)});
  }finally{
    for(const f of [videoPath,musicPath,outPath]) if(f) await fs.promises.unlink(f).catch(()=>{});
  }
});

app.get('/api/storage/status',(req,res)=>{
  const configured=cloudinaryConfigured();
  res.json({configured,provider:configured?'cloudinary':'none',durable:configured});
});

app.post('/api/upload',auth,upload.single('file'),async(req,res)=>{
  try{
    if(!req.file)return res.status(400).json({error:'NO_FILE'});
    const kind=mediaKind(req.file)||String(req.body?.mediaKind||'').toUpperCase()||'IMAGE';
    const normalized=await normalizeUploadedMedia(req.file,kind);
    // Render's local filesystem is ephemeral. Production uploads therefore MUST go to durable object/media storage.
    // Cloudinary is used here because it supports images, videos and audio and returns HTTPS URLs suitable for Flutter.
    if(process.env.NODE_ENV==='production' && !cloudinaryConfigured()) throw new Error('STORAGE_NOT_CONFIGURED');
    if(cloudinaryConfigured()){
      const stored=await cloudinaryUpload(normalized,kind);
      await fs.promises.unlink(normalized.path).catch(()=>{});
      return res.status(201).json({url:stored.url,type:kind,size:stored.bytes,mime:kind==='IMAGE'?(normalized.mimetype||'image/jpeg'):(kind==='VIDEO'?'video/mp4':'audio/mp4'),storage:'cloudinary',publicId:stored.publicId});
    }
    const origin=`${req.protocol}://${req.get('host')}`;
    return res.status(201).json({url:`${origin}/uploads/${normalized.filename}`,type:kind,size:normalized.size,mime:normalized.mimetype||'',storage:'local'});
  }catch(e){
    if(req.file?.path) await fs.promises.unlink(req.file.path).catch(()=>{});
    const msg=String(e?.message||'');
    const code=msg.startsWith('MEDIA_NORMALIZATION_FAILED')?'MEDIA_NORMALIZATION_FAILED':msg==='STORAGE_NOT_CONFIGURED'?'STORAGE_NOT_CONFIGURED':msg.startsWith('CLOUDINARY_UPLOAD')?'UPLOAD_FAILED':'UPLOAD_FAILED';
    res.status(code==='MEDIA_NORMALIZATION_FAILED'?422:code==='STORAGE_NOT_CONFIGURED'?503:500).json({error:code});
  }
});function jsonObject(value){return value&&typeof value==='object'&&!Array.isArray(value)?value:{};}
async function assignedPermissions(actorId,targetUserId){const row=await prisma.$queryRawUnsafe('SELECT "permissions" FROM "AdminProfileAssignment" WHERE "actorId"=$1 AND "targetUserId"=$2 LIMIT 1',actorId,targetUserId);if(!row?.[0])return [];try{return JSON.parse(String(row[0].permissions||'[]'))||[];}catch{return [];}}
async function canManageAssigned(req,targetUserId,permission){const actor=await currentAdmin(req);if(actor?.role==='DEVELOPER')return true;const adminEmails=(process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);if(actor?.email&&adminEmails.includes(String(actor.email).toLowerCase()))return true;if(!hasPermission(actor,'MANAGE_ASSIGNED_PROFILES'))return false;const perms=await assignedPermissions(actor.id,targetUserId);return perms.includes('*')||perms.includes(permission);}
function admin(req,res,next){const list=(process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);if(req.user&&req.user.role==='DEVELOPER')return next();if(!list.includes(String(req.user&&req.user.email).toLowerCase()))return res.status(403).json({error:'ADMIN_ONLY'});next()}
async function ensureSchemaCompatibility(){
  // The production database may be one or more versions behind the Prisma schema.
  // Only additive, non-destructive changes are performed here. In particular, we
  // never drop columns/tables and never use --accept-data-loss at startup.
  const statements=[
    // Additive compatibility for production databases created by older SocialNova builds.
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "relationshipStatus" TEXT NOT NULL DEFAULT 'SINGLE'`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "relationshipSince" TIMESTAMP(3)`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "fcmToken" TEXT`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "isDeactivated" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "deactivatedAt" TIMESTAMP(3)`,
    // Bumped by "logout all devices"; JWTs carrying an older version are rejected.
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "tokenVersion" INTEGER NOT NULL DEFAULT 0`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "actorRole" TEXT NOT NULL DEFAULT ''`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "permission" TEXT NOT NULL DEFAULT ''`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "targetType" TEXT NOT NULL DEFAULT ''`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "targetId" TEXT NOT NULL DEFAULT ''`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "result" TEXT NOT NULL DEFAULT 'OK'`,
    `ALTER TABLE "AuditLog" ADD COLUMN IF NOT EXISTS "ipAddress" TEXT NOT NULL DEFAULT ''`,
    // Creator levels (admin-editable thresholds).
    `CREATE TABLE IF NOT EXISTS "CreatorLevel" ("key" TEXT PRIMARY KEY,"label" TEXT NOT NULL,"minFollowers" INTEGER NOT NULL,"tier" INTEGER NOT NULL DEFAULT 0,"color" TEXT NOT NULL DEFAULT '#9CA3AF","enabled" BOOLEAN NOT NULL DEFAULT true)`,
    // Message effects (celebration/hearts/fire/stars/snow/fireworks).
    `ALTER TABLE "Message" ADD COLUMN IF NOT EXISTS "effect" TEXT NOT NULL DEFAULT ''`,
    // Trust & safety: report notifications to staff accounts.
    `ALTER TYPE "NotificationType" ADD VALUE IF NOT EXISTS 'REPORT'`,
    // Live moderation: muted viewers per room.
    `CREATE TABLE IF NOT EXISTS "LiveMute" ("roomName" TEXT NOT NULL,"userId" TEXT NOT NULL,"reason" TEXT NOT NULL DEFAULT '',"actorId" TEXT NOT NULL DEFAULT '',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY ("roomName","userId"))`,
    // Gift Engine columns.
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "rarity" TEXT NOT NULL DEFAULT 'COMMON'`,
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "category" TEXT NOT NULL DEFAULT 'love'`,
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "metadata" TEXT NOT NULL DEFAULT '{}'`,
    // Persistent live counters so taps/gifts survive leaving and re-entering.
    `ALTER TABLE "LiveRoom" ADD COLUMN IF NOT EXISTS "tapCount" INTEGER NOT NULL DEFAULT 0`,
    `ALTER TABLE "LiveRoom" ADD COLUMN IF NOT EXISTS "giftCount" INTEGER NOT NULL DEFAULT 0`,
    `ALTER TABLE "LiveRoom" ADD COLUMN IF NOT EXISTS "giftScore" INTEGER NOT NULL DEFAULT 0`,
    `CREATE TABLE IF NOT EXISTS "LiveTapCount" ("roomName" TEXT NOT NULL,"userId" TEXT NOT NULL,"taps" INTEGER NOT NULL DEFAULT 0,"updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY ("roomName","userId"))`,
    `CREATE INDEX IF NOT EXISTS "LiveTapCount_room_taps_idx" ON "LiveTapCount"("roomName","taps")`,
    // Idempotency for money/content mutations (Idempotency-Key header).
    `CREATE TABLE IF NOT EXISTS "IdempotencyRecord" ("key" TEXT PRIMARY KEY,"userId" TEXT NOT NULL,"path" TEXT NOT NULL,"method" TEXT NOT NULL,"statusCode" INTEGER NOT NULL DEFAULT 0,"response" TEXT,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
    `CREATE INDEX IF NOT EXISTS "IdempotencyRecord_user_created_idx" ON "IdempotencyRecord"("userId","createdAt")`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "showBirthDateInProfile" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "showLocationInProfile" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "showRelationshipInProfile" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "showGenderInProfile" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardTheme" TEXT NOT NULL DEFAULT 'midnight'`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShape" TEXT NOT NULL DEFAULT 'rounded'`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardVisibility" TEXT NOT NULL DEFAULT 'PUBLIC'`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowFollowers" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowPosts" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowStories" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowActivity" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowGender" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardShowBirthDate" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "User" ADD COLUMN IF NOT EXISTS "digitalCardGroupId" TEXT`,
    `ALTER TABLE "Post" ADD COLUMN IF NOT EXISTS "archived" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Post" ADD COLUMN IF NOT EXISTS "commentsEnabled" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "Post" ADD COLUMN IF NOT EXISTS "pinned" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Post" ADD COLUMN IF NOT EXISTS "repostEnabled" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "Reel" ADD COLUMN IF NOT EXISTS "archived" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Reel" ADD COLUMN IF NOT EXISTS "commentsEnabled" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "Reel" ADD COLUMN IF NOT EXISTS "repostEnabled" BOOLEAN NOT NULL DEFAULT true`,
    `ALTER TABLE "Reel" ADD COLUMN IF NOT EXISTS "speed" DOUBLE PRECISION NOT NULL DEFAULT 1.0`,
    `ALTER TABLE "Story" ADD COLUMN IF NOT EXISTS "archived" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Story" ADD COLUMN IF NOT EXISTS "autoHideAfterInteraction" BOOLEAN NOT NULL DEFAULT false`,
    `ALTER TABLE "Story" ADD COLUMN IF NOT EXISTS "autoHideViews" INTEGER NOT NULL DEFAULT 0`,
    `ALTER TABLE "Story" ADD COLUMN IF NOT EXISTS "replyEnabled" BOOLEAN NOT NULL DEFAULT true`,
    // Relationship was added after some production databases were initialized.
    // Create it explicitly and safely so Prisma relationship queries cannot crash
    // older production databases.
    `CREATE TABLE IF NOT EXISTS "Relationship" (
      "id" TEXT PRIMARY KEY,
      "requesterId" TEXT NOT NULL,
      "partnerId" TEXT NOT NULL,
      "type" TEXT NOT NULL DEFAULT 'IN_RELATIONSHIP',
      "status" TEXT NOT NULL DEFAULT 'PENDING',
      "since" TIMESTAMP(3),
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "Relationship_requesterId_fkey" FOREIGN KEY ("requesterId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT "Relationship_partnerId_fkey" FOREIGN KEY ("partnerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
    )`,
    `CREATE INDEX IF NOT EXISTS "Relationship_requesterId_status_idx" ON "Relationship"("requesterId","status")`,
    `CREATE INDEX IF NOT EXISTS "Relationship_partnerId_status_idx" ON "Relationship"("partnerId","status")`,
    `CREATE INDEX IF NOT EXISTS "Relationship_status_createdAt_idx" ON "Relationship"("status","createdAt")`,
    // Chat themes and audit logs were added after some production databases were initialized.
    // Create them additively so Messenger customization and the admin audit panel never 404/500.
    `CREATE TABLE IF NOT EXISTS "ChatTheme" (
      "id" TEXT PRIMARY KEY,
      "ownerId" TEXT NOT NULL,
      "peerId" TEXT NOT NULL,
      "background" TEXT NOT NULL DEFAULT 'gradient:midnight',
      "bubbleStyle" TEXT NOT NULL DEFAULT 'glass',
      "accent" TEXT NOT NULL DEFAULT 'violet',
      "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "ChatTheme_ownerId_fkey" FOREIGN KEY ("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT "ChatTheme_peerId_fkey" FOREIGN KEY ("peerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
    )`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "ChatTheme_ownerId_peerId_key" ON "ChatTheme"("ownerId","peerId")`,
    `CREATE INDEX IF NOT EXISTS "ChatTheme_peerId_idx" ON "ChatTheme"("peerId")`,
    `CREATE TABLE IF NOT EXISTS "AuditLog" (
      "id" TEXT PRIMARY KEY,
      "actorId" TEXT NOT NULL,
      "action" TEXT NOT NULL,
      "targetUserId" TEXT,
      "peerUserId" TEXT,
      "metadata" TEXT,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
    )`,
    `CREATE INDEX IF NOT EXISTS "AuditLog_actorId_createdAt_idx" ON "AuditLog"("actorId","createdAt")`,
    `CREATE INDEX IF NOT EXISTS "AuditLog_targetUserId_createdAt_idx" ON "AuditLog"("targetUserId","createdAt")`,
    `CREATE INDEX IF NOT EXISTS "AuditLog_peerUserId_createdAt_idx" ON "AuditLog"("peerUserId","createdAt")`,
    `CREATE TABLE IF NOT EXISTS "LiveModerator" ("id" TEXT PRIMARY KEY,"roomId" TEXT NOT NULL,"userId" TEXT NOT NULL,"role" TEXT NOT NULL DEFAULT 'MODERATOR',"permissions" JSONB,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "LiveModerator_roomId_fkey" FOREIGN KEY("roomId") REFERENCES "LiveRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "LiveModerator_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "LiveModerator_roomId_userId_key" ON "LiveModerator"("roomId","userId")`,
    `CREATE INDEX IF NOT EXISTS "LiveModerator_userId_createdAt_idx" ON "LiveModerator"("userId","createdAt")`,
    `CREATE TABLE IF NOT EXISTS "LiveComment" ("id" TEXT PRIMARY KEY,"roomId" TEXT NOT NULL,"authorId" TEXT NOT NULL,"body" TEXT NOT NULL,"replyToId" TEXT,"replyToName" TEXT NOT NULL DEFAULT '',"pinned" BOOLEAN NOT NULL DEFAULT false,"deleted" BOOLEAN NOT NULL DEFAULT false,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "LiveComment_roomId_fkey" FOREIGN KEY("roomId") REFERENCES "LiveRoom"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "LiveComment_authorId_fkey" FOREIGN KEY("authorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS "LiveComment_roomId_createdAt_idx" ON "LiveComment"("roomId","createdAt")`,
    `CREATE INDEX IF NOT EXISTS "LiveComment_roomId_pinned_idx" ON "LiveComment"("roomId","pinned")`,
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "effectKey" TEXT NOT NULL DEFAULT 'pulse'`,
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "effectMs" INTEGER NOT NULL DEFAULT 1800`,
    `ALTER TABLE "Gift" ADD COLUMN IF NOT EXISTS "soundKey" TEXT NOT NULL DEFAULT ''`,
    // PostView was added after some production databases were initialized. Create it
    // explicitly and safely; this avoids prisma db push --accept-data-loss.
    `CREATE TABLE IF NOT EXISTS "PostView" (
      "id" TEXT PRIMARY KEY,
      "postId" TEXT NOT NULL,
      "userId" TEXT NOT NULL,
      "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
      CONSTRAINT "PostView_postId_fkey" FOREIGN KEY ("postId") REFERENCES "Post"("id") ON DELETE CASCADE ON UPDATE CASCADE,
      CONSTRAINT "PostView_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE
    )`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "PostView_postId_userId_key" ON "PostView"("postId","userId")`,
    `CREATE INDEX IF NOT EXISTS "PostView_userId_createdAt_idx" ON "PostView"("userId","createdAt")`,
    `CREATE TABLE IF NOT EXISTS "Series" ("id" TEXT PRIMARY KEY,"creatorId" TEXT NOT NULL,"title" TEXT NOT NULL,"description" TEXT NOT NULL DEFAULT '',"posterUrl" TEXT NOT NULL DEFAULT '',"trailerUrl" TEXT NOT NULL DEFAULT '',"visibility" TEXT NOT NULL DEFAULT 'PUBLIC',"status" TEXT NOT NULL DEFAULT 'PUBLISHED',"featured" BOOLEAN NOT NULL DEFAULT false,"featuredPriority" INTEGER NOT NULL DEFAULT 0,"subscriberOnly" BOOLEAN NOT NULL DEFAULT false,"seasonPassPriceCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "Series_creatorId_fkey" FOREIGN KEY("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE INDEX IF NOT EXISTS "Series_creatorId_createdAt_idx" ON "Series"("creatorId","createdAt")`,
    `CREATE TABLE IF NOT EXISTS "Season" ("id" TEXT PRIMARY KEY,"seriesId" TEXT NOT NULL,"number" INTEGER NOT NULL,"title" TEXT NOT NULL DEFAULT '',"description" TEXT NOT NULL DEFAULT '',"passPriceCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "Season_seriesId_fkey" FOREIGN KEY("seriesId") REFERENCES "Series"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "Season_seriesId_number_key" ON "Season"("seriesId","number")`,
    `CREATE TABLE IF NOT EXISTS "Episode" ("id" TEXT PRIMARY KEY,"seasonId" TEXT NOT NULL,"creatorId" TEXT NOT NULL,"number" INTEGER NOT NULL,"title" TEXT NOT NULL,"description" TEXT NOT NULL DEFAULT '',"videoUrl" TEXT NOT NULL,"thumbnailUrl" TEXT NOT NULL DEFAULT '',"durationSec" INTEGER NOT NULL DEFAULT 0,"accessMode" TEXT NOT NULL DEFAULT 'FREE',"priceCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"adSupported" BOOLEAN NOT NULL DEFAULT false,"published" BOOLEAN NOT NULL DEFAULT true,"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,"views" INTEGER NOT NULL DEFAULT 0,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "Episode_seasonId_fkey" FOREIGN KEY("seasonId") REFERENCES "Season"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "Episode_creatorId_fkey" FOREIGN KEY("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "Episode_seasonId_number_key" ON "Episode"("seasonId","number")`,
    `CREATE TABLE IF NOT EXISTS "Movie" ("id" TEXT PRIMARY KEY,"creatorId" TEXT NOT NULL,"title" TEXT NOT NULL,"description" TEXT NOT NULL DEFAULT '',"posterUrl" TEXT NOT NULL DEFAULT '',"trailerUrl" TEXT NOT NULL DEFAULT '',"videoUrl" TEXT NOT NULL,"durationSec" INTEGER NOT NULL DEFAULT 0,"accessMode" TEXT NOT NULL DEFAULT 'FREE',"priceCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"adSupported" BOOLEAN NOT NULL DEFAULT false,"published" BOOLEAN NOT NULL DEFAULT true,"featured" BOOLEAN NOT NULL DEFAULT false,"featuredPriority" INTEGER NOT NULL DEFAULT 0,"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,"views" INTEGER NOT NULL DEFAULT 0,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "Movie_creatorId_fkey" FOREIGN KEY("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "ContentPurchase" ("id" TEXT PRIMARY KEY,"buyerId" TEXT NOT NULL,"movieId" TEXT,"episodeId" TEXT,"provider" TEXT NOT NULL DEFAULT 'GOOGLE_PLAY',"productId" TEXT NOT NULL,"purchaseToken" TEXT UNIQUE NOT NULL,"status" TEXT NOT NULL DEFAULT 'PENDING_VERIFICATION',"amountCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"verifiedAt" TIMESTAMP(3),CONSTRAINT "ContentPurchase_buyerId_fkey" FOREIGN KEY("buyerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "ContentPurchase_movieId_fkey" FOREIGN KEY("movieId") REFERENCES "Movie"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "ContentPurchase_episodeId_fkey" FOREIGN KEY("episodeId") REFERENCES "Episode"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "CreatorSubscription" ("id" TEXT PRIMARY KEY,"creatorId" TEXT NOT NULL,"subscriberId" TEXT NOT NULL,"provider" TEXT NOT NULL DEFAULT 'GOOGLE_PLAY',"productId" TEXT NOT NULL,"purchaseToken" TEXT UNIQUE NOT NULL,"status" TEXT NOT NULL DEFAULT 'PENDING_VERIFICATION',"startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"expiresAt" TIMESTAMP(3),"creatorSharePct" DOUBLE PRECISION NOT NULL DEFAULT 70,"platformSharePct" DOUBLE PRECISION NOT NULL DEFAULT 30,CONSTRAINT "CreatorSubscription_creatorId_fkey" FOREIGN KEY("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "CreatorSubscription_subscriberId_fkey" FOREIGN KEY("subscriberId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "SeasonPass" ("id" TEXT PRIMARY KEY,"seasonId" TEXT NOT NULL,"buyerId" TEXT NOT NULL,"provider" TEXT NOT NULL DEFAULT 'GOOGLE_PLAY',"productId" TEXT NOT NULL,"purchaseToken" TEXT UNIQUE NOT NULL,"status" TEXT NOT NULL DEFAULT 'PENDING_VERIFICATION',"amountCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "SeasonPass_seasonId_fkey" FOREIGN KEY("seasonId") REFERENCES "Season"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "SeasonPass_buyerId_fkey" FOREIGN KEY("buyerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "SeasonPass_seasonId_buyerId_key" ON "SeasonPass"("seasonId","buyerId")`,
    `CREATE TABLE IF NOT EXISTS "AdImpression" ("id" TEXT PRIMARY KEY,"viewerId" TEXT NOT NULL,"creatorId" TEXT NOT NULL,"movieId" TEXT,"episodeId" TEXT,"placement" TEXT NOT NULL DEFAULT 'CONTENT',"qualified" BOOLEAN NOT NULL DEFAULT false,"eCPM" DOUBLE PRECISION NOT NULL DEFAULT 0,"revenueCents" INTEGER NOT NULL DEFAULT 0,"currency" TEXT NOT NULL DEFAULT 'USD',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "AdImpression_viewerId_fkey" FOREIGN KEY("viewerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "CreatorTeam" ("id" TEXT PRIMARY KEY,"ownerId" TEXT NOT NULL,"name" TEXT NOT NULL,"description" TEXT NOT NULL DEFAULT '',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "CreatorTeam_ownerId_fkey" FOREIGN KEY("ownerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "CreatorTeamMember" ("teamId" TEXT NOT NULL,"userId" TEXT NOT NULL,"role" TEXT NOT NULL DEFAULT 'MEMBER',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY("teamId","userId"),CONSTRAINT "CreatorTeamMember_teamId_fkey" FOREIGN KEY("teamId") REFERENCES "CreatorTeam"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "CreatorTeamMember_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "AudioRoom" ("id" TEXT PRIMARY KEY,"hostId" TEXT NOT NULL,"title" TEXT NOT NULL,"roomName" TEXT UNIQUE NOT NULL,"status" TEXT NOT NULL DEFAULT 'LIVE',"topic" TEXT NOT NULL DEFAULT '',"maxSpeakers" INTEGER NOT NULL DEFAULT 12,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"endedAt" TIMESTAMP(3),CONSTRAINT "AudioRoom_hostId_fkey" FOREIGN KEY("hostId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "Battle" ("id" TEXT PRIMARY KEY,"roomName" TEXT NOT NULL,"status" TEXT NOT NULL DEFAULT 'LIVE',"title" TEXT NOT NULL DEFAULT 'Creator Battle',"endsAt" TIMESTAMP(3),"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP)`,
    `CREATE TABLE IF NOT EXISTS "BattleParticipant" ("battleId" TEXT NOT NULL,"userId" TEXT NOT NULL,"teamId" TEXT,"score" INTEGER NOT NULL DEFAULT 0,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,PRIMARY KEY("battleId","userId"),CONSTRAINT "BattleParticipant_battleId_fkey" FOREIGN KEY("battleId") REFERENCES "Battle"("id") ON DELETE CASCADE ON UPDATE CASCADE,CONSTRAINT "BattleParticipant_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "AcademyCourse" ("id" TEXT PRIMARY KEY,"creatorId" TEXT NOT NULL,"title" TEXT NOT NULL,"description" TEXT NOT NULL DEFAULT '',"coverUrl" TEXT NOT NULL DEFAULT '',"published" BOOLEAN NOT NULL DEFAULT false,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "AcademyCourse_creatorId_fkey" FOREIGN KEY("creatorId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "AcademyLesson" ("id" TEXT PRIMARY KEY,"courseId" TEXT NOT NULL,"number" INTEGER NOT NULL,"title" TEXT NOT NULL,"videoUrl" TEXT NOT NULL DEFAULT '',"body" TEXT NOT NULL DEFAULT '',CONSTRAINT "AcademyLesson_courseId_fkey" FOREIGN KEY("courseId") REFERENCES "AcademyCourse"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE UNIQUE INDEX IF NOT EXISTS "AcademyLesson_courseId_number_key" ON "AcademyLesson"("courseId","number")`,
    `CREATE TABLE IF NOT EXISTS "HallOfFameEntry" ("id" TEXT PRIMARY KEY,"userId" TEXT NOT NULL,"category" TEXT NOT NULL,"title" TEXT NOT NULL,"period" TEXT NOT NULL DEFAULT '',"metric" DOUBLE PRECISION NOT NULL DEFAULT 0,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "HallOfFameEntry_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "AiCoachSession" ("id" TEXT PRIMARY KEY,"userId" TEXT NOT NULL,"goal" TEXT NOT NULL,"prompt" TEXT NOT NULL,"response" TEXT NOT NULL,"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "AiCoachSession_userId_fkey" FOREIGN KEY("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE)`,
    `CREATE TABLE IF NOT EXISTS "AdminProfileAssignment" ("id" TEXT PRIMARY KEY,"actorId" TEXT NOT NULL,"targetUserId" TEXT NOT NULL,"permissions" TEXT NOT NULL DEFAULT '[]',"createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,"updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,CONSTRAINT "AdminProfileAssignment_actorId_fkey" FOREIGN KEY("actorId") REFERENCES "User"("id") ON DELETE CASCADE,CONSTRAINT "AdminProfileAssignment_targetUserId_fkey" FOREIGN KEY("targetUserId") REFERENCES "User"("id") ON DELETE CASCADE,CONSTRAINT "AdminProfileAssignment_actor_target_key" UNIQUE("actorId","targetUserId"))`,
    `CREATE INDEX IF NOT EXISTS "AdminProfileAssignment_targetUserId_idx" ON "AdminProfileAssignment"("targetUserId")`,
    `CREATE INDEX IF NOT EXISTS "AdminProfileAssignment_actorId_idx" ON "AdminProfileAssignment"("actorId")`
  ];
  for(const sql of statements){
    try{ await prisma.$executeRawUnsafe(sql); }
    catch(e){ console.error('[schema-compat]',e.message); throw e; }
  }
}

function conversationModerator(req,res,next){const email=String(req.user&&req.user.email||'').toLowerCase();const list=(process.env.CONVERSATION_MODERATOR_EMAILS||process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);if(req.user&&req.user.role==='DEVELOPER')return next();if(!list.includes(email))return res.status(403).json({error:'CONVERSATION_MODERATOR_ONLY'});next()}
app.get('/',(req,res)=>res.sendFile(path.join(__dirname,'admin-panel.index.html')));
app.get('/api/admin/conversations/search',auth,conversationModerator,async(req,res)=>{const q=String(req.query.q||'').trim();if(q.length<2)return res.json([]);const rows=await prisma.user.findMany({where:{OR:[{username:{contains:q,mode:'insensitive'}},{email:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}}]},select:{id:true,username:true,displayName:true,email:true,avatarUrl:true,isBanned:true},take:30});res.json(rows);});

// Return every private conversation partner for one selected user. This is the
// admin review flow: choose ONE person first, then choose which conversation to open.
app.get('/api/admin/conversations/user/:userId',auth,conversationModerator,async(req,res)=>{
  try{
    const user=await prisma.user.findUnique({where:{id:req.params.userId},select:{id:true,username:true,displayName:true,email:true,avatarUrl:true,isBanned:true}});
    if(!user)return res.status(404).json({error:'USER_NOT_FOUND'});
    const rows=await prisma.message.findMany({
      where:{OR:[{senderId:user.id},{receiverId:user.id}]},
      orderBy:{createdAt:'desc'},
      take:2000
    });
    const peerIds=[]; const seen=new Set(); const latest=new Map();
    for(const m of rows){
      const peerId=m.senderId===user.id?m.receiverId:m.senderId;
      if(!seen.has(peerId)){seen.add(peerId);peerIds.push(peerId);latest.set(peerId,m);}
    }
    if(!peerIds.length)return res.json({user,conversations:[]});
    const peers=await prisma.user.findMany({where:{id:{in:peerIds}},select:{id:true,username:true,displayName:true,email:true,avatarUrl:true,isBanned:true}});
    const byId=new Map(peers.map(x=>[x.id,x]));
    const conversations=peerIds.filter(id=>byId.has(id)).map(peerId=>{
      const last=latest.get(peerId);
      const unread=rows.filter(m=>m.senderId===peerId&&m.receiverId===user.id&&!m.read&&!m.deletedForReceiver).length;
      return {peer:byId.get(peerId),lastMessage:last?{id:last.id,body:last.body,createdAt:last.createdAt,senderId:last.senderId,read:last.read}:null,messageCount:rows.filter(m=>(m.senderId===user.id&&m.receiverId===peerId)||(m.senderId===peerId&&m.receiverId===user.id)).length,unreadCount:unread};
    });
    res.json({user,conversations});
  }catch(e){console.error('[admin conversation list]',e);res.status(500).json({error:'SERVER_ERROR'});}
});

app.get('/api/admin/conversations/:userId/:peerId',auth,conversationModerator,async(req,res)=>{
  try{
    const a=await prisma.user.findUnique({where:{id:req.params.userId},select:{id:true,username:true,displayName:true,email:true,avatarUrl:true,isBanned:true}});
    const b=await prisma.user.findUnique({where:{id:req.params.peerId},select:{id:true,username:true,displayName:true,email:true,avatarUrl:true,isBanned:true}});
    if(!a||!b)return res.status(404).json({error:'USER_NOT_FOUND'});
    const limit=Math.min(500,Math.max(1,Number(req.query.limit||200)));
    const rows=await prisma.message.findMany({where:{OR:[{senderId:a.id,receiverId:b.id},{senderId:b.id,receiverId:a.id}]},orderBy:{createdAt:'asc'},take:limit});
    // Auditing must never turn a valid conversation into HTTP 500 if an older
    // production database temporarily lacks the audit table.
    try{await prisma.auditLog.create({data:{actorId:req.user.id,action:'CONVERSATION_VIEW',targetUserId:a.id,peerUserId:b.id,metadata:JSON.stringify({limit,returned:rows.length})}});}catch(auditError){console.error('[admin conversation audit]',auditError.message);}
    res.json({users:[a,b],messages:rows.map(m=>({...m,moderationView:true})),count:rows.length});
  }catch(e){console.error('[admin conversation]',e);res.status(500).json({error:'SERVER_ERROR'});}
});

app.get('/api/admin/audit-logs',auth,requirePermission('audit.view'),async(req,res)=>{
  const limit=Math.min(200,Math.max(1,Number(req.query.limit||50)));
  const rows=await prisma.auditLog.findMany({orderBy:{createdAt:'desc'},take:limit});
  res.json(rows);
});

// Staff / developer permission management. Only a DEVELOPER (super admin)
// may grant or revoke administrative permissions or create privileged staff.
app.get('/api/admin/permission-catalog',auth,requirePermission('permissions.view'),async(req,res)=>{
  res.json({
    roles:ROLES.map(id=>({id,label:id,permissions:ROLE_PERMISSIONS[id]||[]})),
    permissions:PERMISSIONS,
    legacy:STAFF_PERMISSION_CATALOG,
  });
});

app.get('/api/admin/users/:id/privileges',auth,superAdmin,async(req,res)=>{
  const u=await prisma.user.findUnique({where:{id:req.params.id},select:{id:true,username:true,email:true,displayName:true,role:true,adminPermissions:true,specialFeatures:true}});
  if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});
  res.json(u);
});

app.patch('/api/admin/users/:id/privileges',auth,requirePermission('permissions.grant'),async(req,res)=>{
  try{
    const d=z.object({
      role:z.enum(['USER','ASSISTANT_MODERATOR','MODERATOR','ADMIN','SECURITY_ACCOUNT','DEVELOPER','SUPER_ADMIN']).optional(),
      permissions:z.array(z.string().max(80)).max(200).optional(),
      specialFeatures:z.array(z.string().max(80)).max(100).optional(),
      confirm:z.boolean().optional(),
    }).parse(req.body||{});
    const existing=await prisma.user.findUnique({where:{id:req.params.id},select:{id:true,role:true,adminPermissions:true,specialFeatures:true}});
    if(!existing)return res.status(404).json({error:'USER_NOT_FOUND'});
    const actor=await currentAdmin(req);
    const role=normalizeRole(d.role||existing.role);

    // Guardrail: the last SUPER_ADMIN cannot be demoted or stripped.
    if(normalizeRole(existing.role)==='SUPER_ADMIN' && role!=='SUPER_ADMIN'){
      const count=await prisma.user.count({where:{role:'SUPER_ADMIN'}});
      if(count<=1)return res.status(409).json({error:'LAST_SUPER_ADMIN'});
      if(d.confirm!==true)return res.status(428).json({error:'CONFIRMATION_REQUIRED'});
    }
    // Only a SUPER_ADMIN may create another SUPER_ADMIN.
    if(role==='SUPER_ADMIN' && !isSuperAdmin(actor))return res.status(403).json({error:'SUPER_ADMIN_ONLY'});

    let permissions=d.permissions!==undefined?expandLegacy(d.permissions):expandLegacy(permissionArray(existing.adminPermissions));
    // Role defaults are what make the role meaningful; explicit grants are added
    // on top. SUPER_ADMIN is the single wildcard role.
    if(role==='SUPER_ADMIN')permissions=['*'];
    else if(role==='USER')permissions=[];
    else permissions=[...new Set([...(ROLE_PERMISSIONS[role]||[]),...permissions])];
    // Only SUPER_ADMIN may hold the guarded permission-management set.
    if(!isSuperAdmin(actor))permissions=permissions.filter(p=>!SUPER_ADMIN_ONLY_PERMISSIONS.includes(p));
    if(permissionArray(existing.adminPermissions).includes('*') && role!=='SUPER_ADMIN' && d.confirm!==true){
      return res.status(428).json({error:'CONFIRMATION_REQUIRED'});
    }

    const updated=await prisma.user.update({where:{id:existing.id},data:{role,adminPermissions:permissions,specialFeatures:d.specialFeatures!==undefined?d.specialFeatures:existing.specialFeatures}});
    await auditAction(req,'STAFF_PERMISSIONS_UPDATE',{permission:'permissions.grant',targetUserId:existing.id,targetType:'USER',targetId:existing.id,before:{role:existing.role,permissions:permissionArray(existing.adminPermissions)},after:{role,permissions}});
    res.json({ok:true,user:{...safe(updated),permissions:effectiveFor(updated)}});
  }catch(e){res.status(400).json({error:'VALIDATION_ERROR',details:String(e?.message||'')});}
});

app.get('/api/admin/profile-permission-catalog',auth,superAdmin,async(req,res)=>res.json({permissions:['ASSIGNED_PROFILE_BAN','ASSIGNED_PROFILE_VERIFY','ASSIGNED_PROFILE_FEATURE','ASSIGNED_PROFILE_COINS','ASSIGNED_PROFILE_EFFECTS','ASSIGNED_PROFILE_SPECIALS','ASSIGNED_PROFILE_SUBSCRIPTIONS','*']}));
app.get('/api/admin/profile-assignments',auth,superAdmin,async(req,res)=>{const rows=await prisma.$queryRawUnsafe('SELECT a.*, au.username AS "actorUsername", tu.username AS "targetUsername" FROM "AdminProfileAssignment" a JOIN "User" au ON au.id=a."actorId" JOIN "User" tu ON tu.id=a."targetUserId" ORDER BY a."createdAt" DESC LIMIT 500');res.json(rows.map(r=>({...r,permissions:(()=>{try{return JSON.parse(String(r.permissions||'[]'))}catch{return []}})()})))});
app.put('/api/admin/profile-assignments',auth,superAdmin,async(req,res)=>{try{const d=z.object({actorId:z.string().min(1),targetUserId:z.string().min(1),permissions:z.array(z.string()).min(1).max(30)}).parse(req.body||{});const [actor,target]=await Promise.all([prisma.user.findUnique({where:{id:d.actorId}}),prisma.user.findUnique({where:{id:d.targetUserId}})]);if(!actor||!target)return res.status(404).json({error:'USER_NOT_FOUND'});const allowed=new Set(['ASSIGNED_PROFILE_BAN','ASSIGNED_PROFILE_VERIFY','ASSIGNED_PROFILE_FEATURE','ASSIGNED_PROFILE_COINS','ASSIGNED_PROFILE_EFFECTS','ASSIGNED_PROFILE_SPECIALS','ASSIGNED_PROFILE_SUBSCRIPTIONS','*']);const permissions=[...new Set(d.permissions.filter(x=>allowed.has(x)))];if(!permissions.length)return res.status(400).json({error:'NO_VALID_PERMISSIONS'});const rows=await prisma.$queryRawUnsafe('SELECT "id" FROM "AdminProfileAssignment" WHERE "actorId"=$1 AND "targetUserId"=$2 LIMIT 1',d.actorId,d.targetUserId);if(rows?.[0])await prisma.$executeRawUnsafe('UPDATE "AdminProfileAssignment" SET "permissions"=$1,"updatedAt"=CURRENT_TIMESTAMP WHERE "id"=$2',JSON.stringify(permissions),rows[0].id);else await prisma.$executeRawUnsafe('INSERT INTO "AdminProfileAssignment" ("id","actorId","targetUserId","permissions") VALUES ($1,$2,$3,$4)',crypto.randomUUID(),d.actorId,d.targetUserId,JSON.stringify(permissions));await prisma.auditLog.create({data:{actorId:req.user.id,action:'PROFILE_ASSIGNMENT_UPDATE',targetUserId:d.targetUserId,metadata:JSON.stringify({actorId:d.actorId,permissions})}}).catch(()=>{});res.json({ok:true,actorId:d.actorId,targetUserId:d.targetUserId,permissions});}catch(e){res.status(400).json({error:'VALIDATION_ERROR',details:String(e?.message||'')});}});
app.delete('/api/admin/profile-assignments/:actorId/:targetUserId',auth,superAdmin,async(req,res)=>{await prisma.$executeRawUnsafe('DELETE FROM "AdminProfileAssignment" WHERE "actorId"=$1 AND "targetUserId"=$2',req.params.actorId,req.params.targetUserId);res.json({ok:true})});
app.get('/api/admin/users/:id/profile-effects',auth,admin,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.params.id},select:{id:true,specialFeatures:true}});if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});const f=jsonObject(u.specialFeatures);res.json({profileOpenEffect:f.profileOpenEffect||'',profileOpenVideoUrl:f.profileOpenVideoUrl||'',profileOpenEnabled:f.profileOpenEnabled===true,profileOpenDurationMs:Number(f.profileOpenDurationMs||4500)})});
app.patch('/api/admin/users/:id/profile-effects',auth,async(req,res)=>{const id=req.params.id;if(!(await canManageAssigned(req,id,'ASSIGNED_PROFILE_EFFECTS')))return res.status(403).json({error:'ASSIGNED_PROFILE_PERMISSION_DENIED',permission:'ASSIGNED_PROFILE_EFFECTS'});const u=await prisma.user.findUnique({where:{id},select:{id:true,specialFeatures:true}});if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});const d=z.object({profileOpenEffect:z.enum(['NONE','GOLDEN_AURA','NEON_PORTAL','HEART_BURST','SPARKLES','FIRE','GALAXY','CROWN','DIAMOND','STARS','LIGHTNING','SAKURA']).optional(),profileOpenVideoUrl:z.string().max(5000).optional(),profileOpenEnabled:z.boolean().optional(),profileOpenDurationMs:z.number().int().min(1000).max(15000).optional()}).parse(req.body||{});const f=jsonObject(u.specialFeatures);const next={...f,...d};if(next.profileOpenEffect==='NONE')next.profileOpenEffect='';const out=await prisma.user.update({where:{id},data:{specialFeatures:next}});await prisma.auditLog.create({data:{actorId:req.user.id,action:'PROFILE_OPEN_EFFECT_UPDATE',targetUserId:id,metadata:JSON.stringify(d)}}).catch(()=>{});res.json({user:safe(out),effects:{profileOpenEffect:next.profileOpenEffect||'',profileOpenVideoUrl:next.profileOpenVideoUrl||'',profileOpenEnabled:next.profileOpenEnabled===true,profileOpenDurationMs:Number(next.profileOpenDurationMs||4500)}})});
app.post('/api/admin/managed-users/:id/action',auth,async(req,res)=>{const id=req.params.id;const action=String(req.body?.action||'').toUpperCase();const map={BAN:'ASSIGNED_PROFILE_BAN',VERIFY:'ASSIGNED_PROFILE_VERIFY',FEATURE:'ASSIGNED_PROFILE_FEATURE',COINS:'ASSIGNED_PROFILE_COINS',SPECIALS:'ASSIGNED_PROFILE_SPECIALS',SUBSCRIPTION:'ASSIGNED_PROFILE_SUBSCRIPTIONS'};if(!map[action])return res.status(400).json({error:'INVALID_ACTION'});if(!(await canManageAssigned(req,id,map[action])))return res.status(403).json({error:'ASSIGNED_PROFILE_PERMISSION_DENIED',permission:map[action]});const u=await prisma.user.findUnique({where:{id},include:{wallet:true}});if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});let out=u;if(action==='BAN')out=await prisma.user.update({where:{id},data:{isBanned:Boolean(req.body?.value)}});if(action==='VERIFY')out=await prisma.user.update({where:{id},data:{isVerified:Boolean(req.body?.value),verificationTier:String(req.body?.tier||'NORMAL')}});if(action==='FEATURE')out=await prisma.user.update({where:{id},data:{featuredAccount:Boolean(req.body?.value),featuredPriority:Math.max(0,Math.min(10000,Number(req.body?.priority||100)))}});if(action==='COINS'){const coins=Number(req.body?.coins||0);if(!Number.isInteger(coins)||coins===0)return res.status(400).json({error:'INVALID_COINS'});const wallet=u.wallet||await prisma.wallet.create({data:{userId:id}});const next=Math.max(0,wallet.coinBalance+coins);await prisma.wallet.update({where:{id:wallet.id},data:{coinBalance:next}});await prisma.walletTransaction.create({data:{userId:id,walletId:wallet.id,type:coins>0?'ADMIN_GRANT':'ADMIN_DEBIT',coins,balanceAfter:next,withdrawableAfter:wallet.withdrawableCoins,reference:`ASSIGNED-${crypto.randomUUID()}`,description:'تعديل من مسؤول مفوض'}});out=await prisma.user.findUnique({where:{id}});}if(action==='SUBSCRIPTION'){const creatorId=String(req.body?.creatorId||id);const days=Math.max(1,Math.min(3650,Number(req.body?.days||30)));const creator=await prisma.user.findUnique({where:{id:creatorId}});if(!creator)return res.status(404).json({error:'CREATOR_NOT_FOUND'});const existing=await prisma.creatorSubscription.findFirst({where:{creatorId,subscriberId:id,status:'VERIFIED'}});const expires=new Date(Date.now()+days*86400000);if(existing)out=await prisma.user.update({where:{id},data:{specialFeatures:{...jsonObject(u.specialFeatures),subscriptionGrantedByAdmin:true,subscriptionExpiresAt:expires.toISOString()}}});else{await prisma.creatorSubscription.create({data:{creatorId,subscriberId:id,provider:'ADMIN',productId:`ADMIN-SUB-${crypto.randomUUID()}`,purchaseToken:`ADMIN-${crypto.randomUUID()}`,status:'VERIFIED',expiresAt:expires}});out=await prisma.user.findUnique({where:{id}});}}
  if(action==='SPECIALS'){const current=jsonObject(u.specialFeatures);const patch=req.body?.features;if(!patch||typeof patch!=='object'||Array.isArray(patch))return res.status(400).json({error:'INVALID_FEATURES'});out=await prisma.user.update({where:{id},data:{specialFeatures:{...current,...patch}}});}await prisma.auditLog.create({data:{actorId:req.user.id,action:`ASSIGNED_${action}`,targetUserId:id,metadata:JSON.stringify(req.body||{})}}).catch(()=>{});res.json({ok:true,user:safe(out)})});
app.post('/api/admin/developer-accounts',auth,requirePermission('admins.create'),async(req,res)=>{
  try{
    const d=z.object({username:z.string().min(3).max(30).regex(/^[a-zA-Z0-9_.]+$/),email:z.string().email(),password:z.string().min(8),displayName:z.string().min(2).max(60),role:z.enum(['ASSISTANT_MODERATOR','MODERATOR','ADMIN','SECURITY_ACCOUNT','DEVELOPER']).default('SECURITY_ACCOUNT'),permissions:z.array(z.string()).max(200).default([])}).parse(req.body||{});
    const exists=await prisma.user.findFirst({where:{OR:[{email:d.email},{username:d.username}]}});
    if(exists)return res.status(409).json({error:'EMAIL_OR_USERNAME_EXISTS'});
    const role=normalizeRole(d.role);
    let permissions=[...new Set([...(ROLE_PERMISSIONS[role]||[]),...expandLegacy(d.permissions)])];
    const actor=await currentAdmin(req);
    if(!isSuperAdmin(actor))permissions=permissions.filter(p=>!SUPER_ADMIN_ONLY_PERMISSIONS.includes(p));
    const u=await prisma.user.create({data:{username:d.username,email:d.email.toLowerCase(),displayName:d.displayName,passwordHash:await bcrypt.hash(d.password,12),role,adminPermissions:permissions,specialFeatures:['admin_panel'],isVerified:true}});
    await auditAction(req,'STAFF_ACCOUNT_CREATED',{permission:'admins.create',targetUserId:u.id,targetType:'USER',targetId:u.id,after:{role,permissions}});
    res.status(201).json({user:{...safe(u),permissions:effectiveFor(u)}});
  }catch(e){res.status(400).json({error:'VALIDATION_ERROR',details:String(e?.message||'')});}
});


// Complete Admin Control Center API. These routes are intentionally additive and
// use only models already present in the production schema.
app.get('/api/admin/status',auth,admin,async(req,res)=>res.json({ok:true,version:'3.2.0',admin:true,serverTime:new Date().toISOString(),routes:['overview','users','posts','reels','stories','comments','groups','live','verification','wallet','analytics','storage','audit','conversations']}));
app.get('/api/admin/overview',auth,admin,async(req,res)=>{
  try{
    const [users,activeUsers,banned,posts,reels,stories,groups,live,messages,tracks,pendingWithdrawals,pendingVerification,listings]=await Promise.all([
      prisma.user.count(),prisma.user.count({where:{lastSeen:{gte:new Date(Date.now()-15*60*1000)},isBanned:false}}),prisma.user.count({where:{isBanned:true}}),
      prisma.post.count(),prisma.reel.count(),prisma.story.count({where:{expiresAt:{gt:new Date()}}}),prisma.group.count(),prisma.liveRoom.count({where:{status:'LIVE'}}),prisma.message.count(),prisma.musicTrack.count(),
      prisma.withdrawalRequest.count({where:{status:'PENDING'}}),prisma.verificationRequest.count({where:{status:'PENDING'}}),prisma.storeListing.count()
    ]);
    res.json({users,activeUsers,banned,posts,reels,stories,groups,live,messages,tracks,pendingWithdrawals,pendingVerification,listings,storage:{cloudinary:cloudinaryConfigured()},livekit:Boolean(process.env.LIVEKIT_URL&&process.env.LIVEKIT_API_KEY&&process.env.LIVEKIT_API_SECRET)});
  }catch(e){console.error('[admin overview]',e);res.status(500).json({error:'SERVER_ERROR'});}
});

app.get('/api/admin/users',auth,admin,async(req,res)=>{
  const q=String(req.query.q||'').trim();
  const where=q?{OR:[{username:{contains:q,mode:'insensitive'}},{email:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}}]}:{};
  const rows=await prisma.user.findMany({where,orderBy:{createdAt:'desc'},take:200,include:{wallet:true}});
  res.json(rows.map(u=>({...safe(u),coinBalance:u.wallet?.coinBalance||0,withdrawableCoins:u.wallet?.withdrawableCoins||0})));
});
app.patch('/api/admin/users/:id',auth,requirePermission('USER_MODERATION'),async(req,res)=>{
  try{
    const d=req.body||{}; const data={};
    if(typeof d.banned==='boolean')data.isBanned=d.banned;
    if(typeof d.verified==='boolean')data.isVerified=d.verified;
    if(['NONE','NORMAL','PRO'].includes(String(d.verificationTier||'')))data.verificationTier=String(d.verificationTier);
    if(d.verificationExpiresAt!==undefined)data.verificationExpiresAt=d.verificationExpiresAt?new Date(d.verificationExpiresAt):null;
    if(typeof d.featuredAccount==='boolean'){
      data.featuredAccount=d.featuredAccount;
      // الحساب المُبرز إداريًا يجب أن يكون قابلاً للاكتشاف العام. هذا لا يصنع مشاهدات وهمية؛ بل يزيد ظهوره في الاكتشاف والخلاصات.
      if(d.featuredAccount){ data.isPrivate=false; data.hideFromSearch=false; data.hideFromSuggestions=false; }
    }
    if(Number.isInteger(d.featuredPriority))data.featuredPriority=Math.max(0,Math.min(10000,d.featuredPriority));
    if(!Object.keys(data).length)return res.status(400).json({error:'NO_CHANGES'});
    const u=await prisma.user.update({where:{id:req.params.id},data});
    await prisma.auditLog.create({data:{actorId:req.user.id,action:d.featuredAccount===true?'ACCOUNT_FEATURED':d.featuredAccount===false?'ACCOUNT_UNFEATURED':'USER_ADMIN_UPDATE',targetUserId:u.id,metadata:JSON.stringify(data)}}).catch(()=>{});
    res.json({user:safe(u)});
  }catch(e){console.error('[admin user update]',e);res.status(400).json({error:'UPDATE_FAILED'});}
});

app.get('/api/admin/posts',auth,admin,async(req,res)=>{const rows=await prisma.post.findMany({orderBy:{createdAt:'desc'},take:200,include:{author:true,likes:true,comments:true,reposts:true}});res.json(rows.map(p=>({...p,author:safe(p.author),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length})));});
app.get('/api/admin/reels',auth,admin,async(req,res)=>{const rows=await prisma.reel.findMany({orderBy:{createdAt:'desc'},take:200,include:{author:true,likes:true,comments:true,reposts:true}});res.json(rows.map(r=>({...r,author:safe(r.author),likeCount:r.likes.length,commentCount:r.comments.length,repostCount:r.reposts.length})));});
app.patch('/api/admin/reels/:id/feature',auth,admin,async(req,res)=>{const featured=Boolean(req.body?.featured);const priority=Number(req.body?.priority||0);res.json(await prisma.reel.update({where:{id:req.params.id},data:{featured,featuredPriority:priority}}));});
app.get('/api/admin/stories',auth,admin,async(req,res)=>{const rows=await prisma.story.findMany({where:{expiresAt:{gt:new Date()}},orderBy:{createdAt:'desc'},take:200,include:{author:true}});res.json(rows.map(s=>({...s,author:safe(s.author)})));});
app.get('/api/admin/groups',auth,admin,async(req,res)=>{const rows=await prisma.group.findMany({orderBy:{createdAt:'desc'},take:200,include:{owner:true,_count:{select:{members:true}}}});res.json(rows.map(g=>({...g,owner:safe(g.owner),memberCount:g._count.members})));});
app.get('/api/admin/live',auth,admin,async(req,res)=>{const rows=await prisma.liveRoom.findMany({where:{status:'LIVE'},orderBy:[{host:{featuredAccount:'desc'}},{host:{featuredPriority:'desc'}},{createdAt:'desc'}],take:100,include:{host:true}});res.json(rows.map(r=>({...r,host:safe(r.host)})));});
app.patch('/api/admin/live/:id/stop',auth,requirePermission('LIVE_MODERATION'),async(req,res)=>{const r=await prisma.liveRoom.update({where:{id:req.params.id},data:{status:'ENDED',endedAt:new Date()}});res.json({ok:true,room:r});});
app.get('/api/admin/verification',auth,admin,async(req,res)=>{const rows=await prisma.verificationRequest.findMany({orderBy:{createdAt:'desc'},take:200,include:{user:true}});res.json(rows.map(v=>({...v,user:safe(v.user)})));});
app.get('/api/admin/wallet/withdrawals',auth,admin,async(req,res)=>{const rows=await prisma.withdrawalRequest.findMany({orderBy:{createdAt:'desc'},take:200,include:{user:true}});res.json(rows.map(w=>({...w,user:safe(w.user)})));});
app.patch('/api/admin/wallet/withdrawals/:id',auth,admin,async(req,res)=>{const status=String(req.body?.status||'');if(!['PAID','REJECTED'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});const w=await prisma.withdrawalRequest.update({where:{id:req.params.id},data:{status,reviewedAt:new Date()}});res.json(w);});
app.get('/api/admin/storage',auth,admin,async(req,res)=>res.json({cloudinaryConfigured:cloudinaryConfigured(),storageUploadConfigured:Boolean(process.env.STORAGE_UPLOAD_URL),storagePublicConfigured:Boolean(process.env.STORAGE_PUBLIC_URL),livekitConfigured:Boolean(process.env.LIVEKIT_URL&&process.env.LIVEKIT_API_KEY&&process.env.LIVEKIT_API_SECRET),cloudName:process.env.CLOUDINARY_CLOUD_NAME||''}));

app.patch('/api/verification/requests/:id',auth,admin,async(req,res)=>{
  const status=String(req.body?.status||'');
  if(!['APPROVED','REJECTED'].includes(status))return res.status(400).json({error:'INVALID_STATUS'});
  const row=await prisma.verificationRequest.findUnique({where:{id:req.params.id}});
  if(!row)return res.status(404).json({error:'NOT_FOUND'});
  const updated=await prisma.verificationRequest.update({where:{id:row.id},data:{status,reviewedAt:new Date()}});
  if(status==='APPROVED')await prisma.user.update({where:{id:row.userId},data:{isVerified:true,verificationTier:row.tier}}).catch(()=>{});
  res.json(updated);
});
app.patch('/api/admin/users/:id/deactivate',auth,requirePermission('USER_MODERATION'),async(req,res)=>{
  try{
    const deactivated=req.body?.deactivated===true;
    const u=await prisma.user.update({where:{id:req.params.id},data:{isDeactivated:deactivated,deactivatedAt:deactivated?new Date():null}});
    await prisma.auditLog.create({data:{actorId:req.user.id,action:deactivated?'ACCOUNT_DEACTIVATED':'ACCOUNT_REACTIVATED',targetUserId:u.id,metadata:JSON.stringify({deactivated})}}).catch(()=>{});
    res.json({ok:true,user:safe(u)});
  }catch(e){res.status(400).json({error:'DEACTIVATE_FAILED'});}
});
app.post('/api/admin/users/:id/coins',auth,admin,async(req,res)=>{
  const coins=Number(req.body?.coins||0); if(!Number.isInteger(coins)||coins===0)return res.status(400).json({error:'INVALID_COINS'});
  const u=await prisma.user.findUnique({where:{id:req.params.id},include:{wallet:true}}); if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});
  const wallet=u.wallet||await prisma.wallet.create({data:{userId:u.id}});
  const next=Math.max(0,wallet.coinBalance+coins);
  const updated=await prisma.wallet.update({where:{id:wallet.id},data:{coinBalance:next}});
  await prisma.walletTransaction.create({data:{userId:u.id,walletId:wallet.id,type:coins>0?'ADMIN_GRANT':'ADMIN_DEBIT',coins,balanceAfter:next,withdrawableAfter:wallet.withdrawableCoins,reference:`ADMIN-${crypto.randomUUID()}`,description:String(req.body?.description||'تعديل إداري')}});
  await prisma.auditLog.create({data:{actorId:req.user.id,action:'ADMIN_COINS_UPDATE',targetUserId:u.id,metadata:JSON.stringify({coins,description:req.body?.description||''})}}).catch(()=>{});
  res.json({ok:true,coinBalance:updated.coinBalance});
});
app.post('/api/admin/users/:id/demo-followers',auth,admin,async(req,res)=>{
  const count=Math.max(0,Math.min(500,Number(req.body?.count||0))); if(!Number.isInteger(count)||count<1)return res.status(400).json({error:'INVALID_COUNT'});
  const u=await prisma.user.findUnique({where:{id:req.params.id}}); if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});
  const current=Number(u.demoFollowersCount||0); const updated=await prisma.user.update({where:{id:u.id},data:{demoFollowersCount:current+count}});
  await prisma.auditLog.create({data:{actorId:req.user.id,action:'DEMO_FOLLOWERS_GRANT',targetUserId:u.id,metadata:JSON.stringify({added:count,total:updated.demoFollowersCount,clearlyLabeled:true})}}).catch(()=>{});
  res.json({ok:true,added:count,total:updated.demoFollowersCount});
});

app.delete('/api/admin/posts/:id',auth,requirePermission('POST_MODERATION'),async(req,res)=>{await prisma.post.delete({where:{id:req.params.id}});res.json({ok:true});});
app.delete('/api/admin/reels/:id',auth,requirePermission('REEL_MODERATION'),async(req,res)=>{await prisma.reel.delete({where:{id:req.params.id}});res.json({ok:true});});
app.delete('/api/admin/stories/:id',auth,requirePermission('STORY_MODERATION'),async(req,res)=>{await prisma.story.delete({where:{id:req.params.id}});res.json({ok:true});});
app.delete('/api/admin/groups/:id',auth,requirePermission('GROUP_MODERATION'),async(req,res)=>{await prisma.group.delete({where:{id:req.params.id}});res.json({ok:true});});
app.get('/api/admin/comments',auth,admin,async(req,res)=>{const rows=await prisma.comment.findMany({orderBy:{createdAt:'desc'},take:300,include:{author:true,post:true}});res.json(rows.map(c=>({...c,author:safe(c.author)})));});
app.delete('/api/admin/comments/:id',auth,requirePermission('COMMENT_MODERATION'),async(req,res)=>{await prisma.comment.delete({where:{id:req.params.id}});res.json({ok:true});});
app.get('/api/admin/audit-logs-full',auth,requirePermission('audit.view'),async(req,res)=>res.json(await prisma.auditLog.findMany({orderBy:{createdAt:'desc'},take:300}))); 
app.get('/api/admin/analytics',auth,admin,async(req,res)=>{const [users,posts,reels,groups,live,withdrawals]=await Promise.all([prisma.user.count(),prisma.post.count(),prisma.reel.count(),prisma.group.count(),prisma.liveRoom.count({where:{status:'LIVE'}}),prisma.withdrawalRequest.aggregate({where:{status:'PAID'},_sum:{cashCents:true,coins:true}})]);res.json({users,posts,reels,groups,live,paidWithdrawals:withdrawals});});

app.get('/api/admin/device-bans',auth,admin,async(req,res)=>{
  const rows=await prisma.$queryRawUnsafe(`SELECT "id","deviceHash","reason","actorId","bannedAt","expiresAt","revokedAt" FROM "DeviceBan" ORDER BY "bannedAt" DESC LIMIT 300`);
  res.json(rows.map(x=>({...x,deviceId:`…${String(x.deviceHash).slice(-10)}`})));
});
app.get('/api/admin/users/:id/devices',auth,admin,async(req,res)=>{
  const rows=await prisma.$queryRawUnsafe(`SELECT "id","deviceHash","firstSeenAt","lastSeenAt" FROM "DeviceSeen" WHERE "userId"=$1 ORDER BY "lastSeenAt" DESC`,req.params.id);
  const bans=await prisma.$queryRawUnsafe(`SELECT "deviceHash","reason","bannedAt","expiresAt","revokedAt" FROM "DeviceBan" WHERE "deviceHash" IN (SELECT "deviceHash" FROM "DeviceSeen" WHERE "userId"=$1)`,req.params.id);
  const map=new Map(bans.map(x=>[x.deviceHash,x]));
  res.json(rows.map(x=>({...x,deviceId:`…${String(x.deviceHash).slice(-10)}`,ban:map.get(x.deviceHash)||null})));
});
app.post('/api/admin/users/:id/device-ban',auth,requirePermission('USER_MODERATION'),async(req,res)=>{
  const d=z.object({reason:z.string().max(500).default('حظر جميع أجهزة المستخدم')}).parse(req.body||{});
  const rows=await prisma.$queryRawUnsafe(`SELECT "deviceHash" FROM "DeviceSeen" WHERE "userId"=$1`,req.params.id);
  if(!rows.length)return res.status(404).json({error:'NO_DEVICE_HISTORY'});
  for(const row of rows){await prisma.$executeRawUnsafe(`INSERT INTO "DeviceBan" ("id","deviceHash","reason","actorId") VALUES ($1,$2,$3,$4) ON CONFLICT ("deviceHash") DO UPDATE SET "reason"=EXCLUDED."reason","actorId"=EXCLUDED."actorId","bannedAt"=now(),"revokedAt"=NULL`,crypto.randomUUID(),row.deviceHash,d.reason,req.user.id);}
  await prisma.auditLog.create({data:{actorId:req.user.id,action:'USER_DEVICE_BAN_ALL',targetUserId:req.params.id,metadata:JSON.stringify({count:rows.length,reason:d.reason})}}).catch(()=>{});
  res.json({ok:true,count:rows.length});
});
app.post('/api/admin/device-bans',auth,requirePermission('USER_MODERATION'),async(req,res)=>{
  const d=z.object({deviceId:z.string().min(4).max(256),reason:z.string().max(500).default('حظر جهاز إداري'),expiresAt:z.string().datetime().nullable().optional()}).parse(req.body||{});
  const h=deviceHash(d.deviceId); if(!h)return res.status(400).json({error:'INVALID_DEVICE'});
  await prisma.$executeRawUnsafe(`INSERT INTO "DeviceBan" ("id","deviceHash","reason","actorId","expiresAt") VALUES ($1,$2,$3,$4,$5) ON CONFLICT ("deviceHash") DO UPDATE SET "reason"=EXCLUDED."reason","actorId"=EXCLUDED."actorId","bannedAt"=now(),"expiresAt"=EXCLUDED."expiresAt","revokedAt"=NULL`,crypto.randomUUID(),h,d.reason,req.user.id,d.expiresAt?new Date(d.expiresAt):null);
  await prisma.auditLog.create({data:{actorId:req.user.id,action:'DEVICE_BAN',metadata:JSON.stringify({deviceHashSuffix:h.slice(-10),reason:d.reason,expiresAt:d.expiresAt||null})}}).catch(()=>{});
  res.json({ok:true,deviceId:`…${h.slice(-10)}`});
});
app.post('/api/admin/device-bans/:id/revoke',auth,admin,async(req,res)=>{
  await prisma.$executeRawUnsafe(`UPDATE "DeviceBan" SET "revokedAt"=now() WHERE "id"=$1`,req.params.id);
  await prisma.auditLog.create({data:{actorId:req.user.id,action:'DEVICE_UNBAN',metadata:JSON.stringify({deviceBanId:req.params.id})}}).catch(()=>{});
  res.json({ok:true});
});
app.get('/api/health',(req,res)=>res.json({ok:true,service:'SocialNova API',version:'3.0.0',time:new Date().toISOString()}));
app.post('/api/auth/register',requireAllowedDevice,async(req,res)=>{try{const d=z.object({username:z.string().min(3).max(30).regex(/^[a-zA-Z0-9_.]+$/),email:z.string().email(),password:z.string().min(6),displayName:z.string().min(2).max(60),deviceId:z.string().max(256).optional()}).parse(req.body);const deviceId=rawDeviceId(req,d);if(deviceId && await isDeviceBanned(deviceId))return res.status(403).json({error:'DEVICE_BANNED'});const exists=await prisma.user.findFirst({where:{OR:[{email:d.email},{username:d.username}]}});if(exists)return res.status(409).json({error:'EMAIL_OR_USERNAME_EXISTS'});const{password:pw,deviceId:_device,...rest}=d;const u=await prisma.user.create({data:{...rest,passwordHash:await bcrypt.hash(pw,12)}});await rememberDevice(u.id,deviceId);res.status(201).json({user:publicUser(u),token:sign(u)})}catch(e){res.status(400).json({error:e.message})}});
app.post('/api/auth/login',requireAllowedDevice,async(req,res)=>{const d=req.body||{};if(rawDeviceId(req,d) && await isDeviceBanned(rawDeviceId(req,d)))return res.status(403).json({error:'DEVICE_BANNED'});const u=await prisma.user.findFirst({where:{OR:[{email:d.login},{username:d.login}]}});if(!u||u.isBanned||!(await bcrypt.compare(d.password||'',u.passwordHash)))return res.status(401).json({error:'INVALID_CREDENTIALS'});if(u.isDeactivated===true)return res.status(403).json({error:'ACCOUNT_CLOSED'});const isAdmin=effectiveFor(u).length>0;await rememberDevice(u.id,rawDeviceId(req,d));res.json({user:publicUser(u),isAdmin,token:sign(u)})});
app.get('/api/me',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.user.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts,relationship]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}}),relationshipFor(u.id,u.id)]);res.json({user:{...publicUser(u),followers,following,posts,relationshipType:relationship.type,relationship}})});
app.post('/api/account/close',auth,async(req,res)=>{try{await prisma.user.update({where:{id:req.user.id},data:{isDeactivated:true,deactivatedAt:new Date()}});res.json({ok:true})}catch(e){res.status(500).json({error:'ACCOUNT_CLOSE_FAILED'})}});
app.post('/api/account/reactivate',auth,async(req,res)=>{try{await prisma.user.update({where:{id:req.user.id},data:{isDeactivated:false,deactivatedAt:null}});res.json({ok:true})}catch(e){res.status(500).json({error:'ACCOUNT_REACTIVATE_FAILED'})}});
// Invalidate every existing session of this account (all devices).
app.post('/api/auth/logout-all',auth,async(req,res)=>{try{await prisma.user.update({where:{id:req.user.id},data:{tokenVersion:{increment:1}}});await auditAction(req,'LOGOUT_ALL_DEVICES',{targetUserId:req.user.id});res.json({ok:true})}catch(e){res.status(500).json({error:'LOGOUT_ALL_FAILED'})}});
app.patch('/api/me',auth,async(req,res)=>{try{const d=z.object({displayName:z.string().min(2).max(60).optional(),bio:z.string().max(500).optional(),website:z.string().max(500).optional(),location:z.string().max(200).optional(),gender:z.string().max(20).optional(),birthDate:z.string().datetime().nullable().optional(),avatarUrl:z.string().max(2000000).optional(),coverUrl:z.string().max(2000000).optional(),digitalCardTheme:z.string().max(30).optional(),digitalCardShape:z.string().max(30).optional(),digitalCardVisibility:z.enum(['PUBLIC','FRIENDS','PRIVATE']).optional(),digitalCardShowFollowers:z.boolean().optional(),digitalCardShowPosts:z.boolean().optional(),digitalCardShowStories:z.boolean().optional(),digitalCardShowActivity:z.boolean().optional(),digitalCardShowGender:z.boolean().optional(),digitalCardShowBirthDate:z.boolean().optional(),digitalCardGroupId:z.string().max(100).nullable().optional(),specialFeatures:z.record(z.any()).optional()}).parse(req.body);const data={...d};
    if(data.specialFeatures){const current=await prisma.user.findUnique({where:{id:req.user.id},select:{specialFeatures:true,role:true}});const base=jsonObject(current?.specialFeatures);const incoming=jsonObject(data.specialFeatures);if(current?.role!=='DEVELOPER'){for(const k of ['profileOpenEffect','profileOpenVideoUrl','profileOpenEnabled','profileOpenDurationMs'])delete incoming[k];}data.specialFeatures={...base,...incoming};}if(data.birthDate!==undefined)data.birthDate=data.birthDate?new Date(data.birthDate):null;if(data.digitalCardGroupId){const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:data.digitalCardGroupId,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'})}res.json({user:safe(await prisma.user.update({where:{id:req.user.id},data}))})}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/feed',auth,async(req,res)=>{const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});const ids=fl.map(f=>f.followingId);const visibleReposters=[req.user.id,...ids];const posts=await prisma.post.findMany({where:{AND:[{OR:[{visibility:'PUBLIC',author:{isBanned:false}},{authorId:req.user.id},{visibility:'FOLLOWERS',authorId:{in:ids}},{reposts:{some:{userId:{in:visibleReposters}}}}]},{OR:[{authorId:req.user.id},{postViews:{none:{userId:req.user.id}}}]}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{createdAt:'desc'}],take:50,include:{author:true,likes:true,bookmarks:true,reposts:{include:{user:true}},shares:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:3}}});const statusMap=await statusRingsForUserIds(posts.map(p=>p.authorId),req.user.id);res.json(posts.map(p=>({...p,author:withStatus(p.author,statusMap),likedByMe:p.likes.some(x=>x.userId===req.user.id),bookmarkedByMe:p.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:p.reposts.some(x=>x.userId===req.user.id),reposters:p.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length,shareCount:p.shares.length,comments:p.comments.map(c=>({...c,author:safe(c.author)}))}))) });
app.post('/api/posts',auth,async(req,res)=>{try{const d=z.object({caption:z.string().max(5000).default(''),mediaUrl:z.string().max(5000).default(''),type:z.enum(['TEXT','IMAGE','VIDEO','MUSIC']).default('TEXT'),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),visibility:z.enum(['PUBLIC','FOLLOWERS','PRIVATE']).default('PUBLIC')}).parse(req.body);res.status(201).json(await prisma.post.create({data:{...d,authorId:req.user.id},include:{author:true}}))}catch(e){res.status(400).json({error:e.message})}});
app.patch('/api/posts/:id',auth,async(req,res)=>{try{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});if(p.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),mediaUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.post.update({where:{id:p.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.delete('/api/posts/:id',auth,async(req,res)=>{try{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const u=await currentAdmin(req);const canMod=!!u&&(u.role==='DEVELOPER'||isAdminEmail(u.email)||hasPermission(u,'POST_MODERATION'));if(p.authorId!==req.user.id&&!canMod)return res.status(403).json({error:'FORBIDDEN'});await prisma.post.delete({where:{id:p.id}});res.json({ok:true});}catch(e){res.status(404).json({error:'NOT_FOUND'});}});
app.post('/api/posts/:id/like',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const old=await prisma.like.findUnique({where:{postId_userId:key}});if(old)await prisma.like.delete({where:{postId_userId:key}});else{const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});await prisma.like.create({data:key});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'LIKE',text:'أعجب شخص بمنشورك'}})}res.json({liked:!old})});
app.patch('/api/posts/comments/:id',auth,async(req,res)=>{const c=await prisma.comment.findUnique({where:{id:req.params.id}});if(!c||c.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});if(c.editCount>=1||Date.now()-c.createdAt.getTime()>5*60*1000)return res.status(400).json({error:'COMMENT_EDIT_WINDOW_EXPIRED'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const out=await prisma.comment.update({where:{id:c.id},data:{body:body.slice(0,1000),editedAt:new Date(),editCount:{increment:1}}});res.json(out)});
app.delete('/api/posts/comments/:id',auth,async(req,res)=>{const c=await prisma.comment.findUnique({where:{id:req.params.id},include:{post:true}});if(!c)return res.status(404).json({error:'NOT_FOUND'});if(c.authorId!==req.user.id&&c.post.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.comment.delete({where:{id:c.id}});res.json({ok:true})});
app.post('/api/posts/:id/view',auth,async(req,res)=>{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});if(p.authorId!==req.user.id){await prisma.postView.upsert({where:{postId_userId:{postId:p.id,userId:req.user.id}},create:{postId:p.id,userId:req.user.id},update:{}});}res.json({ok:true});});
app.post('/api/posts/:id/comments',auth,async(req,res)=>{const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const c=await prisma.comment.create({data:{postId:p.id,authorId:req.user.id,body},include:{author:true}});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'COMMENT',text:'تم التعليق على منشورك'}});await notifyMentions(body,'تمت الإشارة إليك في تعليق على منشور');res.status(201).json({...c,author:safe(c.author)})});
app.get('/api/posts/:id/comments',auth,async(req,res)=>{const rows=await prisma.comment.findMany({where:{postId:req.params.id},orderBy:{createdAt:'asc'},take:200,include:{author:true}});res.json(rows.map(c=>({...c,author:safe(c.author)})));});
app.post('/api/posts/:id/bookmark',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.bookmark.findUnique({where:{postId_userId:key}});if(old)await prisma.bookmark.delete({where:{postId_userId:key}});else await prisma.bookmark.create({data:key});res.json({bookmarked:!old})});
app.post('/api/posts/:id/repost',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.repost.findUnique({where:{postId_userId:key}});if(old)await prisma.repost.delete({where:{postId_userId:key}});else{await prisma.repost.create({data:key});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'LIKE',text:'تمت إعادة نشر منشورك'}})}res.json({reposted:!old,repostCount:await prisma.repost.count({where:{postId:p.id}})});});
app.post('/api/posts/:id/share',auth,async(req,res)=>{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});await prisma.postShare.create({data:{postId:p.id,userId:req.user.id}});res.json({shareCount:await prisma.postShare.count({where:{postId:p.id}})})});
app.get('/api/music',auth,async(req,res)=>{try{const q=String(req.query.search||'').trim();const category=String(req.query.category||'').trim();const where={licensed:true,...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{artist:{contains:q,mode:'insensitive'}},{album:{contains:q,mode:'insensitive'}}]}:{}),...(category?{category:{equals:category,mode:'insensitive'}}:{})};const rows=await prisma.musicTrack.findMany({where,orderBy:{createdAt:'desc'},take:100});res.json(rows)}catch(e){res.status(500).json({error:'SERVER_ERROR'})}});
app.post('/api/music',auth,admin,async(req,res)=>{try{const d=z.object({title:z.string().min(1).max(200),artist:z.string().min(1).max(120),album:z.string().max(200).default(''),coverUrl:z.string().max(5000).default(''),audioUrl:z.string().url(),category:z.string().max(80).default(''),durationSec:z.number().int().min(0).max(3600).default(0),licensed:z.boolean().default(false)}).parse(req.body);const row=await prisma.musicTrack.create({data:d});res.status(201).json(row)}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/reels',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{AND:[{OR:[{authorId:req.user.id},{author:{isPrivate:false,isBanned:false}}]},{feedbacks:{none:{userId:req.user.id,kind:'NOT_INTERESTED'}}}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=new Set(followed.map(f=>f.followingId));
  const statusMap=await statusRingsForUserIds(rows.map(r=>r.authorId),req.user.id);
  res.json(rows.map(r=>({...r,author:{...withStatus(r.author,statusMap),followedByMe:ids.has(r.authorId)},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/following',auth,async(req,res)=>{
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=followed.map(f=>f.followingId);
  const rows=await prisma.reel.findMany({where:{AND:[{authorId:{in:ids}},{feedbacks:{none:{userId:req.user.id,kind:'NOT_INTERESTED'}}}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  const statusMap=await statusRingsForUserIds(rows.map(r=>r.authorId),req.user.id);
  res.json(rows.map(r=>({...r,author:{...withStatus(r.author,statusMap),followedByMe:true},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/reposted',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{reposts:{some:{userId:req.user.id}}},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:true,savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.post('/api/reels',auth,async(req,res)=>{const d=z.object({videoUrl:z.string().url().or(z.string().min(1)),caption:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default('')}).parse(req.body);const r=await prisma.reel.create({data:{...d,authorId:req.user.id},include:{author:true}});res.status(201).json({...r,author:safe(r.author)})});
app.patch('/api/reels/:id',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});if(r.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.reel.update({where:{id:r.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.delete('/api/reels/:id',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const u=await currentAdmin(req);const canMod=!!u&&(u.role==='DEVELOPER'||isAdminEmail(u.email)||hasPermission(u,'REEL_MODERATION'));if(r.authorId!==req.user.id&&!canMod)return res.status(403).json({error:'FORBIDDEN'});await prisma.reel.delete({where:{id:r.id}});res.json({ok:true});}catch(e){res.status(404).json({error:'NOT_FOUND'});}});
app.post('/api/reels/:id/like',auth,async(req,res)=>{const key={reelId:req.params.id,userId:req.user.id};const r=await prisma.reel.findUnique({where:{id:key.reelId}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelLike.findUnique({where:{reelId_userId:key}});if(old)await prisma.reelLike.delete({where:{reelId_userId:key}});else{await prisma.reelLike.create({data:key});if(r.authorId!==req.user.id)await prisma.notification.create({data:{userId:r.authorId,type:'LIKE',text:'أعجب شخص بالريلز الخاص بك'}})}res.json({liked:!old,likeCount:await prisma.reelLike.count({where:{reelId:r.id}})});});
app.get('/api/reels/:id/comments',auth,async(req,res)=>{const cs=await prisma.reelComment.findMany({where:{reelId:req.params.id},include:{author:true},orderBy:{createdAt:'desc'},take:100});res.json(cs.map(c=>({...c,author:safe(c.author)})));});
app.patch('/api/reels/comments/:id',auth,async(req,res)=>{const c=await prisma.reelComment.findUnique({where:{id:req.params.id}});if(!c||c.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});if(c.editCount>=1||Date.now()-c.createdAt.getTime()>5*60*1000)return res.status(400).json({error:'COMMENT_EDIT_WINDOW_EXPIRED'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});res.json(await prisma.reelComment.update({where:{id:c.id},data:{body:body.slice(0,1000),editedAt:new Date(),editCount:{increment:1}}}))});
app.delete('/api/reels/comments/:id',auth,async(req,res)=>{const c=await prisma.reelComment.findUnique({where:{id:req.params.id},include:{reel:true}});if(!c)return res.status(404).json({error:'NOT_FOUND'});if(c.authorId!==req.user.id&&c.reel.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.reelComment.delete({where:{id:c.id}});res.json({ok:true})});
app.post('/api/reels/:id/comments',auth,async(req,res)=>{const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const c=await prisma.reelComment.create({data:{reelId:r.id,authorId:req.user.id,body:body.slice(0,1000)},include:{author:true}});if(r.authorId!==req.user.id)await prisma.notification.create({data:{userId:r.authorId,type:'COMMENT',text:'تم التعليق على الريلز الخاص بك'}});await notifyMentions(body,'تمت الإشارة إليك في تعليق على ريلز');res.status(201).json({...c,author:safe(c.author)});});
app.post('/api/reels/:id/share',auth,async(req,res)=>{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});await prisma.reelShare.create({data:{reelId:r.id,userId:req.user.id}});res.json({shareCount:await prisma.reelShare.count({where:{reelId:r.id}})});});
app.post('/api/reels/:id/repost',auth,async(req,res)=>{const key={reelId:req.params.id,userId:req.user.id};const r=await prisma.reel.findUnique({where:{id:key.reelId}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelRepost.findUnique({where:{reelId_userId:key}});if(old)await prisma.reelRepost.delete({where:{reelId_userId:key}});else await prisma.reelRepost.create({data:key});res.json({reposted:!old,repostCount:await prisma.reelRepost.count({where:{reelId:r.id}})});});
app.post('/api/reels/:id/bookmark',auth,async(req,res)=>{const key={reelId:req.params.id,userId:req.user.id};const r=await prisma.reel.findUnique({where:{id:key.reelId}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelBookmark.findUnique({where:{reelId_userId:key}});if(old)await prisma.reelBookmark.delete({where:{reelId_userId:key}});else await prisma.reelBookmark.create({data:key});res.json({bookmarked:!old,bookmarkCount:await prisma.reelBookmark.count({where:{reelId:r.id}})});});
app.post('/api/reels/:id/feedback',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const kind=z.enum(['INTERESTED','NOT_INTERESTED']).parse(String(req.body.kind||''));const reason=String(req.body.reason||'').slice(0,300);await prisma.reelFeedback.deleteMany({where:{reelId:r.id,userId:req.user.id,kind:{not:kind}}});await prisma.reelFeedback.upsert({where:{reelId_userId_kind:{reelId:r.id,userId:req.user.id,kind}},create:{reelId:r.id,userId:req.user.id,kind,reason},update:{reason}});res.json({ok:true,kind});}catch(e){res.status(400).json({error:'FEEDBACK_FAILED'})}});
app.post('/api/reels/:id/report',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const reason=String(req.body.reason||'').trim().slice(0,300);if(!reason)return res.status(400).json({error:'REPORT_REASON_REQUIRED'});await prisma.reelReport.upsert({where:{reelId_userId:{reelId:r.id,userId:req.user.id}},create:{reelId:r.id,userId:req.user.id,reason},update:{reason}});res.json({ok:true});}catch(e){res.status(400).json({error:'REPORT_FAILED'})}});
// Report a post. There is no dedicated report table for posts, so each report is
// delivered as a moderation notification to every staff account.
app.post('/api/posts/:id/report',auth,async(req,res)=>{try{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const reason=String(req.body?.reason||'').trim().slice(0,300);if(!reason)return res.status(400).json({error:'REPORT_REASON_REQUIRED'});await notifyStaffReport('reports.view',`بلاغ على منشور ${p.id} من @${req.user.username||req.user.id}: ${reason}`);res.json({ok:true});}catch(e){res.status(400).json({error:'REPORT_FAILED'})}});
app.post('/api/reels/:id/add-to-story',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const s=await prisma.story.create({data:{authorId:req.user.id,mediaUrl:r.videoUrl,type:'VIDEO',caption:r.caption,rotationDegrees:r.rotationDegrees,overlayText:r.overlayText,overlayEmoji:r.overlayEmoji,overlayImageUrl:r.overlayImageUrl,musicUrl:r.musicUrl,musicTitle:r.musicTitle,expiresAt:new Date(Date.now()+24*3600000)},include:{author:true}});res.status(201).json({...s,author:safe(s.author)});}catch(e){res.status(400).json({error:'ADD_TO_STORY_FAILED'})}});
app.post('/api/reels/:id/view',auth,async(req,res)=>{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelView.findUnique({where:{reelId_userId:{reelId:r.id,userId:req.user.id}}});if(!old){await prisma.reelView.create({data:{reelId:r.id,userId:req.user.id}});const out=await prisma.reel.update({where:{id:r.id},data:{views:{increment:1}}});return res.json({views:out.views,newView:true});}res.json({views:r.views,newView:false});});
app.get('/api/activity',auth,async(req,res)=>{const [views,comments,postComments,posts,likes,reelLikes]=await Promise.all([prisma.reelView.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{reel:{include:{author:true}}}}),prisma.reelComment.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{reel:{include:{author:true}}}}),prisma.comment.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{post:{include:{author:true}}}}),prisma.post.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{author:true}}),prisma.like.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{post:true}}),prisma.reelLike.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{reel:true}})]);res.json({views:views.map(v=>({...v,reel:{...v.reel,author:safe(v.reel.author)}})),comments,postComments,posts:posts.map(p=>({...p,author:safe(p.author)})),likedPosts:likes.map(x=>({...x,post:{...x.post,author:safe(x.post.author)}})),likedReels:reelLikes.map(x=>({...x,reel:{...x.reel}}))});});
app.get('/api/stories',auth,async(req,res)=>{
  const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const visible=[req.user.id,...fl.map(f=>f.followingId)];
  const rows=await prisma.story.findMany({where:{OR:[{authorId:{in:visible}},{author:{featuredAccount:true,isBanned:false}}],expiresAt:{gt:new Date()},NOT:{hiddenUserIds:{contains:req.user.id}}},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{createdAt:'desc'}],take:100,include:{author:true,reactions:true,replies:{include:{author:true},orderBy:{createdAt:'asc'},take:100}}});
  const statusMap=await statusRingsForUserIds(rows.map(s=>s.authorId),req.user.id);
  res.json(rows.map(s=>({...s,author:withStatus(s.author,statusMap),likedByMe:s.reactions.some(x=>x.userId===req.user.id),reactionCount:s.reactions.length,replies:s.replies.map(r=>({...r,author:safe(r.author)}))})));
});
app.post('/api/stories',auth,async(req,res)=>{const d=z.object({mediaUrl:z.string().min(1),type:z.enum(['IMAGE','VIDEO']).default('IMAGE'),caption:z.string().max(500).default(''),durationHours:z.number().min(1).max(48).default(24),audienceMode:z.enum(['EVERYONE','CLOSE_FRIENDS','HIDDEN']).default('EVERYONE'),hiddenUserIds:z.array(z.string()).max(200).default([]),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default('')}).parse(req.body);const author=await prisma.user.findUnique({where:{id:req.user.id},select:{isVerified:true,verificationTier:true,verificationExpiresAt:true}});if(!author)return res.status(401).json({error:'UNAUTHORIZED'});const verified=author.isVerified&&author.verificationTier!=='NONE'&&(!author.verificationExpiresAt||author.verificationExpiresAt>new Date());const duration=[6,12,24,48].includes(d.durationHours)?d.durationHours:24;if(duration!==24&&!verified)return res.status(403).json({error:'VERIFIED_ONLY_DURATION'});const s=await prisma.story.create({data:{mediaUrl:d.mediaUrl,type:d.type,caption:d.caption,audienceMode:d.audienceMode,hiddenUserIds:d.hiddenUserIds.join(','),rotationDegrees:d.rotationDegrees,overlayText:d.overlayText,overlayEmoji:d.overlayEmoji,overlayImageUrl:d.overlayImageUrl,musicUrl:d.musicUrl,musicTitle:d.musicTitle,authorId:req.user.id,expiresAt:new Date(Date.now()+duration*3600000)},include:{author:true}});res.status(201).json({...s,author:safe(s.author)})});
app.post('/api/stories/:id/react',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.storyReaction.findUnique({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});if(old)await prisma.storyReaction.delete({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});else{await prisma.storyReaction.create({data:{storyId:story.id,userId:req.user.id,emoji:'❤️'}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'LIKE',text:'أعجب بقصتك ❤️'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:'[story_reaction]❤️',storyId:story.id}})}}res.json({liked:!old})}catch(e){res.status(400).json({error:'STORY_REACTION_FAILED'})}});
app.post('/api/stories/:id/replies',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_REPLY'});const r=await prisma.storyReply.create({data:{storyId:story.id,authorId:req.user.id,body:body.slice(0,1000)},include:{author:true}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'COMMENT',text:'ردّ على قصتك'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:`[story_reply]${body.slice(0,1000)}`,storyId:story.id}})}res.status(201).json({...r,author:safe(r.author)})}catch(e){res.status(400).json({error:'STORY_REPLY_FAILED'})}});
app.get('/api/stories/:id/replies',auth,async(req,res)=>{const rows=await prisma.storyReply.findMany({where:{storyId:req.params.id},orderBy:{createdAt:'asc'},take:100,include:{author:true}});res.json(rows.map(r=>({...r,author:safe(r.author)})))});
app.patch('/api/stories/:id',auth,async(req,res)=>{try{const s=await prisma.story.findUnique({where:{id:req.params.id}});if(!s)return res.status(404).json({error:'NOT_FOUND'});if(s.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(500).optional(),durationHours:z.number().min(1).max(48).optional(),audienceMode:z.enum(['EVERYONE','CLOSE_FRIENDS','HIDDEN']).optional(),hiddenUserIds:z.array(z.string()).max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional()}).parse(req.body);const author=await prisma.user.findUnique({where:{id:req.user.id},select:{isVerified:true,verificationTier:true,verificationExpiresAt:true}});const verified=!!author?.isVerified&&author.verificationTier!=='NONE'&&(!author.verificationExpiresAt||author.verificationExpiresAt>new Date());if(d.durationHours!==undefined){const h=[6,12,24,48].includes(d.durationHours)?d.durationHours:24;if(h!==24&&!verified)return res.status(403).json({error:'VERIFIED_ONLY_DURATION'});d.durationHours=h;}const data={...d};if(d.hiddenUserIds)data.hiddenUserIds=d.hiddenUserIds.join(',');if(d.durationHours)data.expiresAt=new Date(s.createdAt.getTime()+d.durationHours*3600000);delete data.durationHours;res.json(await prisma.story.update({where:{id:s.id},data,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.delete('/api/stories/:id',auth,async(req,res)=>{const s=await prisma.story.findUnique({where:{id:req.params.id}});if(!s)return res.status(404).json({error:'NOT_FOUND'});if(s.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.story.delete({where:{id:s.id}});res.json({ok:true})});
app.get('/api/users/:id/profile',auth,async(req,res)=>{
  const u=await prisma.user.findUnique({where:{id:req.params.id}});
  if(!u)return res.status(404).json({error:'NOT_FOUND'});
  const [followers,following,posts,followingMe,followedByMe,followRequested,hasActiveStory,relationship,statusMap]=await Promise.all([
    prisma.follow.count({where:{followingId:u.id}}),
    prisma.follow.count({where:{followerId:u.id}}),
    prisma.post.count({where:{authorId:u.id}}),
    prisma.follow.findUnique({where:{followerId_followingId:{followerId:u.id,followingId:req.user.id}}}),
    prisma.follow.findUnique({where:{followerId_followingId:{followerId:req.user.id,followingId:u.id}}}),
    prisma.followRequest.findUnique({where:{senderId_targetId:{senderId:req.user.id,targetId:u.id}}}),
    prisma.story.findFirst({where:{authorId:u.id,expiresAt:{gt:new Date()}},select:{id:true}}),
    relationshipFor(u.id,req.user.id),
    statusRingsForUserIds([u.id],req.user.id)
  ]);
  const isMe=u.id===req.user.id;
  const sf=jsonObject(u.specialFeatures);
  const profileOpenEffect={enabled:sf.profileOpenEnabled===true,effect:String(sf.profileOpenEffect||''),videoUrl:String(sf.profileOpenVideoUrl||''),durationMs:Number(sf.profileOpenDurationMs||4500)};
  let managementPermissions=[]; try{const a=await assignedPermissions(req.user.id,u.id); managementPermissions=a;}catch(_){}
  const out={...safe(u),followers,following,posts,followingMe:!!followingMe,followedByMe:!!followedByMe,followRequested:followRequested?.status==='PENDING',hasActiveStory:!!hasActiveStory,isMe,relationshipType:relationship.type,relationship,profileOpenEffect,managementPermissions,profileVisibility:{birthDate:u.showBirthDateInProfile,location:u.showLocationInProfile,relationship:u.showRelationshipInProfile,gender:u.showGenderInProfile},statusRings:statusMap.get(u.id)||{live:false,story:!!hasActiveStory,post:false,reel:false,segments:[],hasNewContent:!!hasActiveStory}};
  if(!isMe){
    if(!u.showBirthDateInProfile)out.birthDate=null;
    if(!u.showLocationInProfile)out.location='';
    if(!u.showGenderInProfile)out.gender='';
    if(!u.showRelationshipInProfile){out.relationship=null;out.relationshipType='';}
  }
  res.json(profileUser(out));
});
app.get('/api/users/:id/followers',auth,async(req,res)=>{const rows=await prisma.follow.findMany({where:{followingId:req.params.id},orderBy:{createdAt:'desc'},take:500,include:{follower:true}});res.json(rows.map(x=>safe(x.follower)));});
app.get('/api/users/:id/following',auth,async(req,res)=>{const rows=await prisma.follow.findMany({where:{followerId:req.params.id},orderBy:{createdAt:'desc'},take:500,include:{following:true}});res.json(rows.map(x=>safe(x.following)));});
app.get('/api/users/:id/posts',auth,async(req,res)=>{const rows=await prisma.post.findMany({where:{authorId:req.params.id},orderBy:{createdAt:'desc'},take:50,include:{author:true,likes:true,bookmarks:true,reposts:true,shares:true}});res.json(rows.map(p=>({...p,author:safe(p.author),likedByMe:p.likes.some(x=>x.userId===req.user.id),bookmarkedByMe:p.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:p.reposts.some(x=>x.userId===req.user.id),likeCount:p.likes.length,commentCount:0,repostCount:p.reposts.length,shareCount:p.shares.length})));});

app.get('/api/users/suggested',auth,async(req,res)=>{
  const users=await prisma.user.findMany({
    where:{
      id:{not:req.user.id},
      isBanned:false,
      hideFromSearch:false,
      hideFromSuggestions:false
    },
    orderBy:[{featuredAccount:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],
    take:30
  });
  res.json(users.map(safe));
});

app.get('/api/users/search',auth,async(req,res)=>{const q=String(req.query.q||'').trim();if(q.length<2)return res.json([]);const users=await prisma.user.findMany({where:{isBanned:false,hideFromSearch:false,OR:[{username:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}}]},take:20});res.json(users.map(safe))});
app.get('/api/search',auth,async(req,res)=>{
  try{
    const q=String(req.query.q||'').trim();
    if(q.length<2)return res.json({users:[],reels:[],posts:[],groups:[],live:[],stories:[]});
    const now=new Date();
    const [users,reels,posts,groups,live,stories]=await Promise.all([
      prisma.user.findMany({where:{isBanned:false,hideFromSearch:false,OR:[{username:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}},{bio:{contains:q,mode:'insensitive'}}]},orderBy:[{featuredAccount:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:20}),
      prisma.reel.findMany({where:{archived:false,author:{isBanned:false,isPrivate:false},OR:[{caption:{contains:q,mode:'insensitive'}},{title:{contains:q,mode:'insensitive'}},{musicTitle:{contains:q,mode:'insensitive'}}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{views:'desc'},{createdAt:'desc'}],take:20,include:{author:true}}),
      prisma.post.findMany({where:{archived:false,visibility:'PUBLIC',author:{isBanned:false,isPrivate:false},OR:[{caption:{contains:q,mode:'insensitive'}},{title:{contains:q,mode:'insensitive'}},{overlayText:{contains:q,mode:'insensitive'}}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{createdAt:'desc'}],take:20,include:{author:true}}),
      prisma.group.findMany({where:{privacy:'PUBLIC',OR:[{name:{contains:q,mode:'insensitive'}},{description:{contains:q,mode:'insensitive'}},{rules:{contains:q,mode:'insensitive'}}]},orderBy:{createdAt:'desc'},take:20,include:{owner:true,_count:{select:{members:true}}}}),
      prisma.liveRoom.findMany({where:{status:'LIVE',OR:[{title:{contains:q,mode:'insensitive'}},{host:{username:{contains:q,mode:'insensitive'}}},{host:{displayName:{contains:q,mode:'insensitive'}}}],host:{isBanned:false,isPrivate:false}},orderBy:[{host:{featuredAccount:'desc'}},{host:{featuredPriority:'desc'}},{viewerCount:'desc'},{createdAt:'desc'}],take:20,include:{host:true}}),
      prisma.story.findMany({where:{archived:false,expiresAt:{gt:now},audienceMode:'EVERYONE',author:{isBanned:false,isPrivate:false},OR:[{caption:{contains:q,mode:'insensitive'}},{overlayText:{contains:q,mode:'insensitive'}},{musicTitle:{contains:q,mode:'insensitive'}},{author:{username:{contains:q,mode:'insensitive'}}},{author:{displayName:{contains:q,mode:'insensitive'}}}]},orderBy:[{author:{featuredAccount:'desc'}},{author:{featuredPriority:'desc'}},{createdAt:'desc'}],take:20,include:{author:true}})
    ]);
    res.json({
      users:users.map(safe),
      reels:reels.map(r=>({...r,author:safe(r.author)})),
      posts:posts.map(p=>({...p,author:safe(p.author)})),
      groups:groups.map(g=>({...g,owner:safe(g.owner)})),
      live:live.map(r=>({...r,host:safe(r.host),livekitConfigured:livekitConfigured()})),
      stories:stories.map(s=>({...s,author:safe(s.author)}))
    });
  }catch(e){console.error('[search] failed',e);res.status(500).json({error:'SEARCH_FAILED'});}
});

app.post('/api/users/:id/follow',auth,async(req,res)=>{if(req.params.id===req.user.id)return res.status(400).json({error:'SELF'});const target=await prisma.user.findUnique({where:{id:req.params.id}});if(!target)return res.status(404).json({error:'NOT_FOUND'});const key={followerId:req.user.id,followingId:target.id};const old=await prisma.follow.findUnique({where:{followerId_followingId:key}});if(old){await prisma.follow.delete({where:{followerId_followingId:key}});await prisma.followRequest.deleteMany({where:{senderId:req.user.id,targetId:target.id,status:'PENDING'}});return res.json({following:false,requested:false});}if(target.isPrivate){const reqq=await prisma.followRequest.upsert({where:{senderId_targetId:{senderId:req.user.id,targetId:target.id}},update:{status:'PENDING'},create:{senderId:req.user.id,targetId:target.id}});await prisma.notification.create({data:{userId:target.id,type:'FOLLOW',text:'لديك طلب متابعة جديد'}}).catch(()=>{});return res.json({following:false,requested:reqq.status==='PENDING'});}await prisma.follow.create({data:key});await prisma.notification.create({data:{userId:target.id,type:'FOLLOW',text:'بدأ شخص بمتابعتك'}});res.json({following:true,requested:false})});
app.get('/api/follow-requests',auth,async(req,res)=>{const rows=await prisma.followRequest.findMany({where:{targetId:req.user.id,status:'PENDING'},orderBy:{createdAt:'desc'},include:{sender:true}});res.json(rows.map(x=>({...x,sender:safe(x.sender)})));});
app.post('/api/follow-requests/:id/accept',auth,async(req,res)=>{const q=await prisma.followRequest.findUnique({where:{id:req.params.id}});if(!q||q.targetId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});await prisma.$transaction([prisma.follow.create({data:{followerId:q.senderId,followingId:q.targetId}}),prisma.followRequest.update({where:{id:q.id},data:{status:'ACCEPTED'}})]);res.json({ok:true});});
app.post('/api/follow-requests/:id/reject',auth,async(req,res)=>{const q=await prisma.followRequest.findUnique({where:{id:req.params.id}});if(!q||q.targetId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});await prisma.followRequest.update({where:{id:q.id},data:{status:'REJECTED'}});res.json({ok:true});});
app.patch('/api/relationships/status',auth,async(req,res)=>{try{const d=z.object({type:z.string().min(1).max(40),since:z.string().datetime().nullable().optional()}).parse(req.body);if(!RELATIONSHIP_TYPES.has(d.type))return res.status(400).json({error:'INVALID_RELATIONSHIP_TYPE'});const active=await prisma.relationship.findFirst({where:{status:{in:['ACTIVE','PENDING']},OR:[{requesterId:req.user.id},{partnerId:req.user.id}]}});if(active)return res.status(409).json({error:'END_RELATIONSHIP_FIRST'});const u=await prisma.user.update({where:{id:req.user.id},data:{relationshipStatus:d.type,relationshipSince:d.since?new Date(d.since):null}});res.json({type:u.relationshipStatus,status:'NONE',since:u.relationshipSince,partner:null});}catch(e){res.status(400).json({error:'RELATIONSHIP_STATUS_FAILED'})}});
app.get('/api/relationships/current',auth,async(req,res)=>res.json(await relationshipFor(req.user.id,req.user.id)));
app.get('/api/relationships/requests',auth,async(req,res)=>{const rows=await prisma.relationship.findMany({where:{partnerId:req.user.id,status:'PENDING'},orderBy:{createdAt:'desc'},include:{requester:true}});res.json(rows.map(r=>({...r,requester:safe(r.requester)})));});
app.post('/api/relationships',auth,async(req,res)=>{try{const d=z.object({type:z.string().min(1).max(40),partnerId:z.string().min(1),since:z.string().datetime().nullable().optional()}).parse(req.body);if(!RELATIONSHIP_TYPES.has(d.type)||d.type==='SINGLE')return res.status(400).json({error:'INVALID_RELATIONSHIP_TYPE'});if(d.partnerId===req.user.id)return res.status(400).json({error:'SELF_RELATIONSHIP'});const target=await prisma.user.findUnique({where:{id:d.partnerId}});if(!target||target.isBanned)return res.status(404).json({error:'USER_NOT_FOUND'});const follows=await prisma.follow.findUnique({where:{followerId_followingId:{followerId:d.partnerId,followingId:req.user.id}}});if(!follows)return res.status(403).json({error:'PARTNER_MUST_FOLLOW_YOU'});const active=await prisma.relationship.findFirst({where:{status:'ACTIVE',OR:[{requesterId:req.user.id},{partnerId:req.user.id},{requesterId:d.partnerId},{partnerId:d.partnerId}]}});if(active)return res.status(409).json({error:'ALREADY_IN_RELATIONSHIP'});const pending=await prisma.relationship.findFirst({where:{status:'PENDING',OR:[{requesterId:req.user.id,partnerId:d.partnerId},{requesterId:d.partnerId,partnerId:req.user.id}]}});if(pending)return res.status(409).json({error:'RELATIONSHIP_REQUEST_EXISTS'});const row=await prisma.relationship.create({data:{requesterId:req.user.id,partnerId:d.partnerId,type:d.type,since:d.since?new Date(d.since):null},include:{requester:true,partner:true}});await prisma.notification.create({data:{userId:d.partnerId,type:'FOLLOW',text:`طلب منك ${req.user.username||'مستخدم'} تأكيد العلاقة: ${d.type}`}}).catch(()=>{});res.status(201).json({...row,requester:safe(row.requester),partner:safe(row.partner)});}catch(e){res.status(400).json({error:e?.message||'RELATIONSHIP_CREATE_FAILED'})}});
app.post('/api/relationships/:id/accept',auth,async(req,res)=>{const row=await prisma.relationship.findUnique({where:{id:req.params.id},include:{requester:true,partner:true}});if(!row||row.partnerId!==req.user.id||row.status!=='PENDING')return res.status(404).json({error:'NOT_FOUND'});const active=await prisma.relationship.findFirst({where:{status:'ACTIVE',OR:[{requesterId:req.user.id},{partnerId:req.user.id},{requesterId:row.requesterId},{partnerId:row.requesterId}]}});if(active)return res.status(409).json({error:'ALREADY_IN_RELATIONSHIP'});const activeSince=row.since||new Date(); const updated=await prisma.relationship.update({where:{id:row.id},data:{status:'ACTIVE',since:activeSince},include:{requester:true,partner:true}}); await prisma.$transaction([prisma.user.update({where:{id:row.requesterId},data:{relationshipStatus:row.type,relationshipSince:activeSince}}),prisma.user.update({where:{id:row.partnerId},data:{relationshipStatus:row.type,relationshipSince:activeSince}})]);await prisma.notification.create({data:{userId:row.requesterId,type:'FOLLOW',text:'تم قبول طلب العلاقة ❤️'}}).catch(()=>{});res.json({...updated,requester:safe(updated.requester),partner:safe(updated.partner)});});
app.post('/api/relationships/:id/reject',auth,async(req,res)=>{const row=await prisma.relationship.findUnique({where:{id:req.params.id}});if(!row||row.partnerId!==req.user.id||row.status!=='PENDING')return res.status(404).json({error:'NOT_FOUND'});await prisma.relationship.update({where:{id:row.id},data:{status:'REJECTED'}});res.json({ok:true});});
app.delete('/api/relationships/current',auth,async(req,res)=>{const row=await prisma.relationship.findFirst({where:{status:{in:['ACTIVE','PENDING']},OR:[{requesterId:req.user.id},{partnerId:req.user.id}]}});if(!row)return res.json({ok:true});if(row.status==='PENDING'&&row.requesterId!==req.user.id)return res.status(403).json({error:'PENDING_INCOMING'});await prisma.$transaction([prisma.relationship.delete({where:{id:row.id}}),prisma.user.update({where:{id:row.requesterId},data:{relationshipStatus:'SINGLE',relationshipSince:null}}),prisma.user.update({where:{id:row.partnerId},data:{relationshipStatus:'SINGLE',relationshipSince:null}})]);res.json({ok:true});});

app.get('/api/groups',auth,async(req,res)=>res.json((await prisma.group.findMany({orderBy:{createdAt:'desc'},take:50,include:{owner:true,_count:{select:{members:true}}}})).map(g=>({...g,owner:safe(g.owner)}))));
app.post('/api/groups',auth,async(req,res)=>{const d=z.object({name:z.string().min(2).max(80),description:z.string().max(1000).default(''),avatarUrl:z.string().max(2000).default(''),coverUrl:z.string().max(2000).default(''),privacy:z.enum(['PUBLIC','PRIVATE']).default('PUBLIC'),rules:z.string().max(3000).default('')}).parse(req.body);const g=await prisma.group.create({data:{...d,ownerId:req.user.id,members:{create:{userId:req.user.id,role:'owner'}}},include:{owner:true,_count:{select:{members:true}}}});res.status(201).json({...g,owner:safe(g.owner)})});
app.patch('/api/groups/:id',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id}});if(!g)return res.status(404).json({error:'NOT_FOUND'});if(g.ownerId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});try{const d=z.object({name:z.string().min(2).max(80).optional(),description:z.string().max(1000).optional(),avatarUrl:z.string().max(2000).optional(),coverUrl:z.string().max(2000).optional(),privacy:z.enum(['PUBLIC','PRIVATE']).optional(),rules:z.string().max(3000).optional()}).parse(req.body);res.json(await prisma.group.update({where:{id:g.id},data:d,include:{owner:true,_count:{select:{members:true}}}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/groups/:id',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id},include:{owner:true,_count:{select:{members:true}}}});if(!g)return res.status(404).json({error:'NOT_FOUND'});const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:g.id,userId:req.user.id}}});res.json({...g,owner:safe(g.owner),joined:!!member})});
app.get('/api/groups/:id/messages',auth,async(req,res)=>{const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:req.params.id,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'});const rows=await prisma.groupMessage.findMany({where:{groupId:req.params.id},orderBy:{createdAt:'asc'},take:200,include:{sender:true}});res.json(rows.map(x=>({...x,sender:safe(x.sender)})))});
app.post('/api/groups/:id/messages',auth,async(req,res)=>{const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:req.params.id,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const m=await prisma.groupMessage.create({data:{groupId:req.params.id,senderId:req.user.id,body:body.slice(0,4000)},include:{sender:true}});res.status(201).json({...m,sender:safe(m.sender)})});
app.post('/api/groups/:id/join',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id}});if(!g)return res.status(404).json({error:'NOT_FOUND'});const key={groupId:g.id,userId:req.user.id};const old=await prisma.groupMember.findUnique({where:{groupId_userId:key}});if(old){if(old.role==='owner')return res.status(400).json({error:'OWNER'});await prisma.groupMember.delete({where:{groupId_userId:key}})}else await prisma.groupMember.create({data:key});res.json({joined:!old})});
app.get('/api/notifications',auth,async(req,res)=>res.json(await prisma.notification.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50})));
app.post('/api/notifications/read',auth,async(req,res)=>{await prisma.notification.updateMany({where:{userId:req.user.id},data:{read:true}});res.json({ok:true})});
app.post('/api/push/token',auth,async(req,res)=>{const token=String(req.body?.token||'').trim();if(!token||token.length>4096)return res.status(400).json({error:'INVALID_TOKEN'});await prisma.user.update({where:{id:req.user.id},data:{fcmToken:token}});res.json({ok:true})});

// ---- Compatibility + production feature routes used by the Flutter client ----
function livekitConfigured(){return Boolean(process.env.LIVEKIT_URL&&process.env.LIVEKIT_API_KEY&&process.env.LIVEKIT_API_SECRET);}
async function livekitToken(identity,roomName,canPublish){
  if(!livekitConfigured()) throw new Error('LIVEKIT_NOT_CONFIGURED');
  const at=new AccessToken(process.env.LIVEKIT_API_KEY,process.env.LIVEKIT_API_SECRET,{identity,ttl:'2h'});
  at.addGrant({roomJoin:true,room:roomName,canPublish,canSubscribe:true,canPublishData:true});
  return at.toJwt();
}

app.get('/api/users/:id/liked',auth,async(req,res)=>{
  const rows=await prisma.post.findMany({where:{likes:{some:{userId:req.params.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(p=>({...p,author:safe(p.author),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length,bookmarkCount:p.bookmarks.length,shareCount:p.shares.length,likedByMe:p.likes.some(x=>x.userId===req.user.id),savedByMe:p.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:p.reposts.some(x=>x.userId===req.user.id)})));
});
app.get('/api/users/:id/saved',auth,async(req,res)=>{
  if(req.params.id!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});
  const rows=await prisma.post.findMany({where:{bookmarks:{some:{userId:req.params.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(p=>({...p,author:safe(p.author),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length,bookmarkCount:p.bookmarks.length,shareCount:p.shares.length,likedByMe:p.likes.some(x=>x.userId===req.user.id),savedByMe:true,repostedByMe:p.reposts.some(x=>x.userId===req.user.id)})));
});
app.get('/api/users/:id/reels',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{authorId:req.params.id},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likeCount:r.likes.length,commentCount:r.comments.length,bookmarkCount:r.bookmarks.length,shareCount:r.shares.length,repostCount:r.reposts.length,likedByMe:r.likes.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id)})));
});
app.get('/api/users/:id/reels-liked',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{likes:{some:{userId:req.params.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likeCount:r.likes.length,commentCount:r.comments.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,shareCount:r.shares.length,likedByMe:r.likes.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id)})));
});
app.get('/api/users/:id/reels-saved',auth,async(req,res)=>{
  if(req.params.id!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});
  const rows=await prisma.reel.findMany({where:{bookmarks:{some:{userId:req.params.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likeCount:r.likes.length,commentCount:r.comments.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,shareCount:r.shares.length,likedByMe:r.likes.some(x=>x.userId===req.user.id),savedByMe:true,repostedByMe:r.reposts.some(x=>x.userId===req.user.id)})));
});
app.get('/api/users/:id/reposted-reels',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{reposts:{some:{userId:req.params.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,comments:true,reposts:true,bookmarks:true,shares:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likeCount:r.likes.length,commentCount:r.comments.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,shareCount:r.shares.length,likedByMe:r.likes.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:true})));
});
app.get('/api/users/:id/stories',auth,async(req,res)=>{
  const rows=await prisma.story.findMany({where:{authorId:req.params.id,expiresAt:{gt:new Date()},archived:false},orderBy:{createdAt:'desc'},take:100,include:{author:true}});
  res.json(rows.map(x=>({...x,author:safe(x.author)})));
});

app.get('/api/me/digital-card',auth,async(req,res)=>{
  const u=await prisma.user.findUnique({where:{id:req.user.id},include:{wallet:true}});
  if(!u)return res.status(404).json({error:'NOT_FOUND'});
  const [followers,following,posts]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}})]);
  res.json({...safe(u),followers,following,posts,card:{theme:u.digitalCardTheme||'midnight',shape:u.digitalCardShape||'rounded',visibility:u.digitalCardVisibility||'PUBLIC',showFollowers:u.digitalCardShowFollowers,showPosts:u.digitalCardShowPosts,showStories:u.digitalCardShowStories,showActivity:u.digitalCardShowActivity,showGender:u.digitalCardShowGender,showBirthDate:u.digitalCardShowBirthDate,groupId:u.digitalCardGroupId||null}});
});
app.get('/api/me/groups',auth,async(req,res)=>{
  const rows=await prisma.group.findMany({where:{members:{some:{userId:req.user.id}}},orderBy:{createdAt:'desc'},include:{owner:true,_count:{select:{members:true}}}});
  res.json(rows.map(g=>({...g,owner:safe(g.owner),memberCount:g._count.members})));
});
app.patch('/api/settings',auth,async(req,res)=>{
  try{
    const allowed=z.object({isPrivate:z.boolean().optional(),hideFollowersCount:z.boolean().optional(),hideFollowingCount:z.boolean().optional(),hideFromSearch:z.boolean().optional(),hideFromSuggestions:z.boolean().optional(),preventProfileScreenshots:z.boolean().optional(),showOnlineStatus:z.boolean().optional(),allowMessageRequests:z.boolean().optional(),pushNotifications:z.boolean().optional(),showBirthDateInProfile:z.boolean().optional(),showLocationInProfile:z.boolean().optional(),showRelationshipInProfile:z.boolean().optional(),showGenderInProfile:z.boolean().optional()}).parse(req.body||{});
    const user=await prisma.user.update({where:{id:req.user.id},data:allowed});
    res.json({user:safe(user)});
  }catch(e){res.status(400).json({error:'VALIDATION_ERROR'});}
});

// ---- Messaging requests and message state ----
app.get('/api/message-requests',auth,async(req,res)=>{
  const rows=await prisma.messageRequest.findMany({where:{targetId:req.user.id,status:'PENDING'},orderBy:{createdAt:'desc'},include:{sender:true}});
  res.json(rows.map(x=>({...x,sender:safe(x.sender)})));
});
app.post('/api/message-requests/:id/accept',auth,async(req,res)=>{
  const row=await prisma.messageRequest.findUnique({where:{id:req.params.id}});
  if(!row||row.targetId!==req.user.id||row.status!=='PENDING')return res.status(404).json({error:'NOT_FOUND'});
  const updated=await prisma.messageRequest.update({where:{id:row.id},data:{status:'ACCEPTED'}});
  res.json({ok:true,request:updated});
});
app.post('/api/message-requests/:id/reject',auth,async(req,res)=>{
  const row=await prisma.messageRequest.findUnique({where:{id:req.params.id}});
  if(!row||row.targetId!==req.user.id||row.status!=='PENDING')return res.status(404).json({error:'NOT_FOUND'});
  await prisma.messageRequest.update({where:{id:row.id},data:{status:'REJECTED'}});
  res.json({ok:true});
});
app.post('/api/messages/:id/delivered',auth,async(req,res)=>{
  const m=await prisma.message.findUnique({where:{id:req.params.id}});
  if(!m||m.receiverId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});
  const updated=await prisma.message.update({where:{id:m.id},data:{deliveredAt:m.deliveredAt||new Date()}});
  io.to(`user:${m.senderId}`).emit('message:delivered',{messageId:m.id,deliveredAt:updated.deliveredAt});
  res.json({ok:true,message:updated});
});
app.post('/api/messages/:id/read',auth,async(req,res)=>{
  const m=await prisma.message.findUnique({where:{id:req.params.id}});
  if(!m||m.receiverId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});
  const now=new Date();
  const updated=await prisma.message.update({where:{id:m.id},data:{read:true,readAt:now,deliveredAt:m.deliveredAt||now}});
  io.to(`user:${m.senderId}`).emit('message:read',{messageId:m.id,readAt:now});
  res.json({ok:true,message:updated});
});
app.post('/api/messages/:id/view',auth,async(req,res)=>{
  const m=await prisma.message.findUnique({where:{id:req.params.id}});
  if(!m||m.senderId!==req.user.id&&m.receiverId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});
  if(m.viewLimit>0 && m.viewCount>=m.viewLimit)return res.status(410).json({error:'MESSAGE_VIEW_LIMIT_REACHED'});
  const updated=await prisma.message.update({where:{id:m.id},data:{viewCount:{increment:1}}});
  if(updated.viewLimit>0 && updated.viewCount>=updated.viewLimit && updated.selfDestruct) await prisma.message.delete({where:{id:m.id}}).catch(()=>{});
  res.json({ok:true,viewCount:updated.viewCount});
});
app.delete('/api/messages/:id',auth,async(req,res)=>{
  const m=await prisma.message.findUnique({where:{id:req.params.id}});
  if(!m)return res.status(404).json({error:'NOT_FOUND'});
  if(m.senderId===req.user.id) await prisma.message.update({where:{id:m.id},data:{deletedForSender:true}});
  else if(m.receiverId===req.user.id) await prisma.message.update({where:{id:m.id},data:{deletedForReceiver:true}});
  else return res.status(403).json({error:'FORBIDDEN'});
  res.json({ok:true});
});

// ---- LiveKit live rooms ----
app.get('/api/live',auth,async(req,res)=>{
  const rows=await prisma.liveRoom.findMany({where:{status:'LIVE'},orderBy:[{host:{featuredAccount:'desc'}},{host:{featuredPriority:'desc'}},{createdAt:'desc'}],take:100,include:{host:true}});
  res.json(rows.map(r=>({...r,host:safe(r.host),livekitConfigured:livekitConfigured()})));
});
app.post('/api/live',auth,async(req,res)=>{
  if(!livekitConfigured())return res.status(503).json({error:'LIVEKIT_NOT_CONFIGURED'});
  const title=String(req.body?.title||'بث مباشر').trim().slice(0,160)||'بث مباشر';
  const roomName=`socialnova-${req.user.id}-${crypto.randomUUID().slice(0,8)}`;
  const room=await prisma.liveRoom.create({data:{hostId:req.user.id,title,roomName,status:'LIVE'},include:{host:true}});
  let token; try{token=await livekitToken(req.user.id,roomName,true);}catch(e){await prisma.liveRoom.delete({where:{id:room.id}});return res.status(503).json({error:'LIVEKIT_NOT_CONFIGURED'});}
  res.status(201).json({...room,host:safe(room.host),url:process.env.LIVEKIT_URL,token});
});
app.post('/api/calls/token',auth,async(req,res)=>{
  if(!livekitConfigured())return res.status(503).json({error:'LIVEKIT_NOT_CONFIGURED'});
  const roomName=String(req.body?.roomName||'').trim();
  if(!/^call_[A-Za-z0-9_-]{3,180}$/.test(roomName))return res.status(400).json({error:'VALIDATION_ERROR'});
  const token=await livekitToken(req.user.id,roomName,true);
  res.json({url:process.env.LIVEKIT_URL,token,roomName,canPublish:true});
});

app.post('/api/live/token',auth,async(req,res)=>{
  if(!livekitConfigured())return res.status(503).json({error:'LIVEKIT_NOT_CONFIGURED'});
  const roomName=String(req.body?.roomName||'').trim();
  const room=await prisma.liveRoom.findUnique({where:{roomName}});
  if(!room||!['LIVE','PAUSED'].includes(room.status))return res.status(404).json({error:'LIVE_NOT_FOUND'});
  if(room.status==='PAUSED' && room.hostId!==req.user.id)return res.status(404).json({error:'LIVE_NOT_FOUND'});
  const canPublish=room.hostId===req.user.id;
  const token=await livekitToken(req.user.id,roomName,canPublish);
  res.json({url:process.env.LIVEKIT_URL,token,roomName,canPublish});
});
app.post('/api/live/:id/pause',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.id}});
  if(!room)return res.status(404).json({error:'LIVE_NOT_FOUND'});
  if(room.hostId!==req.user.id && req.user.role!=='DEVELOPER')return res.status(403).json({error:'FORBIDDEN'});
  const updated=await prisma.liveRoom.update({where:{id:room.id},data:{status:'PAUSED'}});
  io.to(`live:${room.roomName}`).emit('live:paused',{roomId:room.id});
  res.json({ok:true,room:updated});
});
app.post('/api/live/:id/resume',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.id}});
  if(!room)return res.status(404).json({error:'LIVE_NOT_FOUND'});
  if(room.hostId!==req.user.id && req.user.role!=='DEVELOPER')return res.status(403).json({error:'FORBIDDEN'});
  const updated=await prisma.liveRoom.update({where:{id:room.id},data:{status:'LIVE'}});
  io.to(`live:${room.roomName}`).emit('live:resumed',{roomId:room.id});
  res.json({ok:true,room:updated});
});
app.post('/api/live/:id/end',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.id}});
  if(!room)return res.status(404).json({error:'LIVE_NOT_FOUND'});
  if(room.hostId!==req.user.id && req.user.role!=='DEVELOPER')return res.status(403).json({error:'FORBIDDEN'});
  const updated=await prisma.liveRoom.update({where:{id:room.id},data:{status:'ENDED',endedAt:new Date()}});
  io.to(`live:${room.roomName}`).emit('live:ended',{roomId:room.id});
  res.json({ok:true,room:updated});
});
// Persistent live counters + leaderboards. Totals are stored on the room so
// they do not reset when a viewer leaves and comes back.
app.get('/api/live/stats/:roomName',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{roomName:String(req.params.roomName)}});
  if(!room)return res.status(404).json({error:'NOT_FOUND'});
  res.json({tapCount:room.tapCount||0,giftCount:room.giftCount||0,giftScore:room.giftScore||0,viewerCount:room.viewerCount||0});
});
app.get('/api/live/top/:roomName',auth,async(req,res)=>{
  const roomName=String(req.params.roomName);
  let topGifters=[],topTappers=[];
  try{
    topGifters=await prisma.$queryRawUnsafe(`SELECT gt."senderId" AS id, u."username", u."displayName", u."avatarUrl", SUM(gt."coins")::int AS coins, COUNT(*)::int AS gifts FROM "GiftTransaction" gt JOIN "User" u ON u.id=gt."senderId" WHERE gt."context"='LIVE' AND gt."contextId"=$1 GROUP BY gt."senderId", u."username", u."displayName", u."avatarUrl" ORDER BY coins DESC LIMIT 10`,roomName);
  }catch{}
  try{
    topTappers=await prisma.$queryRawUnsafe(`SELECT t."userId" AS id, u."username", u."displayName", u."avatarUrl", t."taps"::int AS taps FROM "LiveTapCount" t JOIN "User" u ON u.id=t."userId" WHERE t."roomName"=$1 ORDER BY t."taps" DESC LIMIT 10`,roomName);
  }catch{}
  res.json({topGifters,topTappers});
});
app.post('/api/live/comments/:id/report',auth,async(req,res)=>{try{const c=await prisma.liveComment.findUnique({where:{id:req.params.id}});if(!c)return res.status(404).json({error:'NOT_FOUND'});const reason=String(req.body?.reason||'').trim().slice(0,300)||'بلاغ';await notifyStaffReport('reports.view',`بلاغ على تعليق بث ${c.id} من @${req.user.username||req.user.id}: ${reason}`);res.json({ok:true});}catch(e){res.status(400).json({error:'REPORT_FAILED'})}});
app.get('/api/live/challenges',auth,async(req,res)=>res.json(await prisma.liveChallenge.findMany({where:{roomName:String(req.query.roomName||''),status:'LIVE'},orderBy:{createdAt:'desc'}})));
app.post('/api/live/challenges',auth,async(req,res)=>{
  const roomName=String(req.body?.roomName||'').trim(), opponentId=String(req.body?.opponentId||'').trim();
  const room=await prisma.liveRoom.findUnique({where:{roomName}});
  if(!room||room.hostId!==req.user.id||room.status!=='LIVE')return res.status(403).json({error:'LIVE_HOST_ONLY'});
  const opponent=await prisma.user.findUnique({where:{id:opponentId}}); if(!opponent)return res.status(404).json({error:'USER_NOT_FOUND'});
  const row=await prisma.liveChallenge.create({data:{roomName,challengerId:req.user.id,opponentId,title:String(req.body?.title||'جولة تحدي').slice(0,100)}});
  res.status(201).json(row);
});
app.patch('/api/live/challenges/:id',auth,async(req,res)=>{
  const row=await prisma.liveChallenge.findUnique({where:{id:req.params.id}}); if(!row)return res.status(404).json({error:'NOT_FOUND'});
  if(row.challengerId!==req.user.id&&row.opponentId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});
  const scoreA=Math.max(0,Math.min(999999,Number(req.body?.scoreA??row.scoreA))),scoreB=Math.max(0,Math.min(999999,Number(req.body?.scoreB??row.scoreB)));
  res.json(await prisma.liveChallenge.update({where:{id:row.id},data:{scoreA,scoreB}}));
});
app.post('/api/live/challenges/:id/finish',auth,async(req,res)=>{
  const row=await prisma.liveChallenge.findUnique({where:{id:req.params.id}}); if(!row)return res.status(404).json({error:'NOT_FOUND'});
  if(row.challengerId!==req.user.id&&row.opponentId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});
  const winnerId=String(req.body?.winnerId||''); if(winnerId!==row.challengerId&&winnerId!==row.opponentId)return res.status(400).json({error:'INVALID_WINNER'});
  res.json(await prisma.liveChallenge.update({where:{id:row.id},data:{status:'FINISHED',winnerId,finishedAt:new Date()}}));
});

// ---- Verification ----
app.get('/api/verification/me',auth,async(req,res)=>{
  const u=await prisma.user.findUnique({where:{id:req.user.id},select:{verificationTier:true,verificationExpiresAt:true,isVerified:true}});
  const requests=await prisma.verificationRequest.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:10});
  res.json({...u,requests});
});
app.post('/api/verification/request',auth,async(req,res)=>{
  const tier=String(req.body?.tier||'NORMAL'); if(!['NORMAL','PRO'].includes(tier))return res.status(400).json({error:'INVALID_TIER'});
  const existing=await prisma.verificationRequest.findFirst({where:{userId:req.user.id,status:'PENDING'}}); if(existing)return res.status(409).json({error:'REQUEST_PENDING'});
  const row=await prisma.verificationRequest.create({data:{userId:req.user.id,tier,reference:`VER-${crypto.randomUUID()}`,amount:tier==='PRO'?999:499,currency:'USD'}});
  res.status(201).json(row);
});
app.post('/api/verification/:id/confirm',auth,async(req,res)=>{
  const row=await prisma.verificationRequest.findUnique({where:{id:req.params.id}}); if(!row||row.userId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});
  if(row.status!=='APPROVED')return res.status(409).json({error:'VERIFICATION_NOT_APPROVED'});
  res.json({ok:true,verificationTier:row.tier});
});
app.get('/api/verification/requests',auth,async(req,res)=>res.json(await prisma.verificationRequest.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50})));

// ---- Wallet / gifts ----
async function ensureWallet(userId){return prisma.wallet.upsert({where:{userId},create:{userId},update:{}});}
app.get('/api/wallet',auth,async(req,res)=>{
  const wallet=await ensureWallet(req.user.id); const gifts=await prisma.gift.findMany({where:{enabled:true},orderBy:{priceCoins:'asc'}});
  const tx=await prisma.walletTransaction.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50});
  const packages=[{productId:'nvc_100',label:'100 NovaCoins',coins:100,amountCents:99},{productId:'nvc_500',label:'500 NovaCoins',coins:500,amountCents:499},{productId:'nvc_1200',label:'1,200 NovaCoins',coins:1200,amountCents:999},{productId:'nvc_2500',label:'2,500 NovaCoins',coins:2500,amountCents:1999},{productId:'nvc_6000',label:'6,000 NovaCoins',coins:6000,amountCents:4999}];res.json({wallet,gifts,transactions:tx,packages,currency:{code:'USD',coinsPerDollar:100,minWithdrawCoins:Number(process.env.NOVA_COIN_MIN_WITHDRAW||1000),withdrawalFeeRate:Number(process.env.NOVA_COIN_WITHDRAWAL_FEE||0.10),creatorShare:Number(process.env.NOVA_COIN_CREATOR_SHARE||0.70)}});
});
app.get('/api/wallet/gifts',auth,async(req,res)=>{
  try{
    const rows=await prisma.$queryRawUnsafe('SELECT "id","slug","name","emoji","priceCoins","enabled","effectKey","effectMs","soundKey","rarity","category","metadata" FROM "Gift" WHERE "enabled"=true ORDER BY "priceCoins" ASC');
    res.json(rows.map(r=>({...r,metadata:(()=>{try{return JSON.parse(String(r.metadata||'{}'))}catch{return {}}})()})));
  }catch(e){res.status(500).json({error:'GIFTS_FAILED'});}
});
app.get('/api/gifts/categories',auth,async(req,res)=>res.json(GIFT_CATEGORIES));

// ---- Creator levels -------------------------------------------------------
const DEFAULT_CREATOR_LEVELS=[
  ['beginner','مبتدئ',100,0,'#9CA3AF'],
  ['rising','صاعد',500,1,'#4FC3F7'],
  ['creator','مبدع',1000,2,'#66BB6A'],
  ['creator_plus','مبدع+',5000,3,'#26C6DA'],
  ['popular','مبدع مشهور',10000,4,'#AB47BC'],
  ['elite','نخبة',50000,5,'#FFA726'],
  ['legend','أسطورة',100000,6,'#FF7043'],
  ['mega','عملاق',1000000,7,'#FFD54F'],
];
async function ensureCreatorLevels(){
  for(const [key,label,minFollowers,tier,color] of DEFAULT_CREATOR_LEVELS){
    await prisma.$executeRawUnsafe('INSERT INTO "CreatorLevel" ("key","label","minFollowers","tier","color","enabled") VALUES ($1,$2,$3,$4,$5,true) ON CONFLICT ("key") DO NOTHING',key,label,minFollowers,tier,color).catch(()=>{});
  }
}
app.get('/api/creator/levels',auth,async(req,res)=>{
  const rows=await prisma.$queryRawUnsafe('SELECT "key","label","minFollowers","tier","color","enabled" FROM "CreatorLevel" WHERE "enabled"=true ORDER BY "minFollowers" ASC').catch(()=>[]);
  res.json(rows);
});
app.put('/api/admin/creator-levels',auth,requirePermission('creators.manage'),async(req,res)=>{
  try{
    const list=z.array(z.object({key:z.string().min(1).max(40),label:z.string().min(1).max(60),minFollowers:z.number().int().min(0).max(100000000),tier:z.number().int().min(0).max(50).default(0),color:z.string().max(20).default('#9CA3AF'),enabled:z.boolean().default(true)})).max(50).parse(req.body?.levels||[]);
    for(const l of list){
      await prisma.$executeRawUnsafe('INSERT INTO "CreatorLevel" ("key","label","minFollowers","tier","color","enabled") VALUES ($1,$2,$3,$4,$5,$6) ON CONFLICT ("key") DO UPDATE SET "label"=EXCLUDED."label","minFollowers"=EXCLUDED."minFollowers","tier"=EXCLUDED."tier","color"=EXCLUDED."color","enabled"=EXCLUDED."enabled"',l.key,l.label,l.minFollowers,l.tier,l.color,l.enabled);
    }
    await auditAction(req,'CREATOR_LEVELS_UPDATE',{permission:'creators.manage',after:list});
    res.json({ok:true,count:list.length});
  }catch(e){res.status(400).json({error:'VALIDATION_ERROR'});}
});
app.get('/api/wallet/received-gifts',auth,async(req,res)=>res.json(await prisma.giftTransaction.findMany({where:{receiverId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{sender:true,gift:true}}).then(xs=>xs.map(x=>({...x,sender:safe(x.sender)})))));
app.get('/api/wallet/sent-gifts',auth,async(req,res)=>res.json(await prisma.giftTransaction.findMany({where:{senderId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{receiver:true,gift:true}}).then(xs=>xs.map(x=>({...x,receiver:safe(x.receiver)})))));
app.post('/api/wallet/gifts/send',auth,async(req,res)=>{
  const receiverId=String(req.body?.receiverId||''),giftId=String(req.body?.giftId||''),context=String(req.body?.context||'GENERAL'),contextId=String(req.body?.contextId||''),message=String(req.body?.message||'').slice(0,300);
  if(receiverId===req.user.id)return res.status(400).json({error:'SELF_GIFT'});
  const receiver=await prisma.user.findUnique({where:{id:receiverId}}); const gift=await prisma.gift.findUnique({where:{id:giftId}}); if(!receiver||!gift||!gift.enabled)return res.status(404).json({error:'GIFT_NOT_FOUND'});
  const share=Number(process.env.NOVA_COIN_CREATOR_SHARE||0.70);
  const result=await prisma.$transaction(async tx=>{
    const w=await tx.wallet.upsert({where:{userId:req.user.id},create:{userId:req.user.id},update:{}});
    if(w.coinBalance<gift.priceCoins)throw new Error('INSUFFICIENT_COINS');
    const rw=await tx.wallet.upsert({where:{userId:receiverId},create:{userId:receiverId},update:{}});
    const senderNext=w.coinBalance-gift.priceCoins, receiverGain=Math.floor(gift.priceCoins*share), receiverNext=rw.coinBalance+receiverGain, withdrawNext=rw.withdrawableCoins+receiverGain;
    await tx.wallet.update({where:{id:w.id},data:{coinBalance:senderNext,lifetimeSpent:{increment:gift.priceCoins}}});
    await tx.wallet.update({where:{id:rw.id},data:{coinBalance:receiverNext,withdrawableCoins:withdrawNext,lifetimeReceived:{increment:receiverGain}}});
    const ref=`GIFT-${crypto.randomUUID()}`;
    await tx.walletTransaction.create({data:{userId:req.user.id,walletId:w.id,type:'GIFT_SENT',coins:-gift.priceCoins,balanceAfter:senderNext,withdrawableAfter:w.withdrawableCoins,reference:ref,description:`إرسال ${gift.name}`}});
    await tx.walletTransaction.create({data:{userId:receiverId,walletId:rw.id,type:'GIFT_RECEIVED',coins:receiverGain,balanceAfter:receiverNext,withdrawableAfter:withdrawNext,reference:`${ref}-R`,description:`استلام ${gift.name}`}});
    const created=await tx.giftTransaction.create({data:{senderId:req.user.id,receiverId,giftId,coins:gift.priceCoins,context,contextId,message,reference:ref,fundingType:'PURCHASED'},include:{gift:true}});
    if(context==='LIVE'&&contextId){io.to(`live:${contextId}`).emit('live:gift',{gift:created.gift,coins:created.coins,userId:req.user.id,username:req.user.username||''});
      prisma.$executeRawUnsafe('UPDATE "LiveRoom" SET "giftCount"="giftCount"+1,"giftScore"="giftScore"+$2 WHERE "roomName"=$1',contextId,created.coins).catch(()=>{});}
    return created;
  }).catch(e=>{if(e.message==='INSUFFICIENT_COINS')return null;throw e;});
  if(!result)return res.status(400).json({error:'INSUFFICIENT_COINS'});
  await prisma.notification.create({data:{userId:receiverId,type:'GIFT',text:`أرسل لك ${req.user.username||'مستخدم'} هدية ${gift.name}`}}).catch(()=>{});
  res.status(201).json(result);
});
app.post('/api/wallet/withdraw',auth,async(req,res)=>{
  const coins=Math.floor(Number(req.body?.coins||0)),method=String(req.body?.method||''),destination=String(req.body?.destination||'').trim();
  const u=await prisma.user.findUnique({where:{id:req.user.id}}); if(!u)return res.status(404).json({error:'NOT_FOUND'});
  const ageOk=u.birthDate && (Date.now()-new Date(u.birthDate).getTime())/(365.2425*86400000)>=18; if(!ageOk)return res.status(403).json({error:'AGE_VERIFICATION_REQUIRED'});
  const min=Number(process.env.NOVA_COIN_MIN_WITHDRAW||1000),feePct=Number(process.env.NOVA_COIN_WITHDRAWAL_FEE||0.10); if(coins<min||destination.length<4)return res.status(400).json({error:'INVALID_WITHDRAWAL'});
  const fee=Math.ceil(coins*feePct),net=coins-fee,cashCents=net; const row=await prisma.$transaction(async tx=>{const w=await tx.wallet.findUnique({where:{userId:req.user.id}});if(!w||w.withdrawableCoins<coins)throw new Error('INSUFFICIENT_WITHDRAWABLE');const nw=w.withdrawableCoins-coins;await tx.wallet.update({where:{id:w.id},data:{withdrawableCoins:nw}});return tx.withdrawalRequest.create({data:{userId:req.user.id,coins,feeCoins:fee,cashCents,currency:'USD',method,destination,status:'PENDING',reference:`WD-${crypto.randomUUID()}`}});}).catch(e=>null);
  if(!row)return res.status(400).json({error:'INSUFFICIENT_WITHDRAWABLE'}); res.status(201).json({...row,netCashCents:cashCents});
});
app.post('/api/wallet/purchase/intent',auth,async(req,res)=>{
  const productId=String(req.body?.productId||''),platform=String(req.body?.platform||''),transactionId=String(req.body?.transactionId||''); if(!productId||!platform||!transactionId)return res.status(400).json({error:'INVALID_PURCHASE'});
  const existing=await prisma.purchaseOrder.findUnique({where:{transactionId}}); if(existing)return res.json(existing);
  const priceMap={nvc_100:100,nvc_500:500,nvc_1200:1200,nvc_2500:2500,nvc_6000:6000}; const coins=Number(priceMap[productId]||0); if(!coins)return res.status(400).json({error:'UNKNOWN_PRODUCT'});
  const row=await prisma.purchaseOrder.create({data:{userId:req.user.id,productId,coins,amountCents:0,currency:'USD',platform,transactionId,status:'PENDING'}}); res.status(201).json(row);
});
app.post('/api/wallet/purchase/verify',auth,async(req,res)=>{
  try{
    const transactionId=String(req.body?.transactionId||req.body?.purchaseToken||'');
    if(!transactionId)return res.status(400).json({error:'PURCHASE_NOT_FOUND'});
    const order=await prisma.purchaseOrder.findUnique({where:{transactionId}}); if(!order||order.userId!==req.user.id)return res.status(404).json({error:'PURCHASE_NOT_FOUND'});
    if(order.status==='VERIFIED')return res.json(order);
    const v=await verifyGoogleOneTime(order.productId,transactionId); if(!v.configured)return res.status(503).json({error:'IAP_VERIFICATION_NOT_CONFIGURED'}); if(!v.verified)return res.status(400).json({error:'PURCHASE_NOT_VERIFIED'});
    const result=await prisma.$transaction(async tx=>{const w=await tx.wallet.upsert({where:{userId:req.user.id},create:{userId:req.user.id},update:{}});const next=w.coinBalance+order.coins;const nw=await tx.wallet.update({where:{id:w.id},data:{coinBalance:next,lifetimePurchased:{increment:order.coins}}});await tx.walletTransaction.create({data:{userId:req.user.id,walletId:w.id,type:'PURCHASE',coins:order.coins,balanceAfter:next,withdrawableAfter:w.withdrawableCoins,reference:order.transactionId,description:`Google Play ${order.productId}`}});await tx.purchaseOrder.update({where:{id:order.id},data:{status:'VERIFIED',verifiedAt:new Date()}});return {order:await tx.purchaseOrder.findUnique({where:{id:order.id}}),wallet:nw};});
    res.json(result);
  }catch(e){console.error('[wallet purchase verify]',e.message);res.status(400).json({error:String(e.message||'PURCHASE_VERIFY_FAILED')});}
});

// ---- Marketplace ----
app.get('/api/store/listings',auth,async(req,res)=>{
  const q=String(req.query.q||'').trim(),category=String(req.query.category||''),location=String(req.query.location||''),sort=String(req.query.sort||'latest');
  const where={active:true,...(category?{category}:{}),...(location?{location:{contains:location,mode:'insensitive'}}:{}),...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{description:{contains:q,mode:'insensitive'}}]}:{})};
  const orderBy=sort==='price_asc'?{priceCents:'asc'}:sort==='price_desc'?{priceCents:'desc'}:sort==='popular'?{purchases:'desc'}:{createdAt:'desc'};
  const rows=await prisma.storeListing.findMany({where,orderBy,take:100,include:{seller:true}}); res.json(rows.map(x=>({...x,seller:safe(x.seller)})));
});
app.post('/api/store/listings',auth,async(req,res)=>{try{const d=z.object({title:z.string().min(2).max(160),description:z.string().max(5000).default(''),category:z.string().max(80),priceCents:z.number().int().nonnegative(),currency:z.string().max(8).default('USD'),location:z.string().max(160).default(''),imageUrl:z.string().max(5000).default(''),stock:z.number().int().positive().default(1),couponCode:z.string().max(80).default(''),discountPct:z.number().int().min(0).max(100).default(0)}).parse(req.body);const row=await prisma.storeListing.create({data:{...d,sellerId:req.user.id},include:{seller:true}});res.status(201).json({...row,seller:safe(row.seller)});}catch(e){res.status(400).json({error:'VALIDATION_ERROR'});}});
app.post('/api/store/listings/:id/view',auth,async(req,res)=>{const row=await prisma.storeListing.update({where:{id:req.params.id},data:{views:{increment:1}}});res.json({views:row.views});});
app.post('/api/store/listings/:id/order',auth,async(req,res)=>{const qty=Math.max(1,Math.min(99,Number(req.body?.quantity||1)));const l=await prisma.storeListing.findUnique({where:{id:req.params.id}});if(!l||!l.active)return res.status(404).json({error:'LISTING_NOT_FOUND'});if(l.sellerId===req.user.id)return res.status(400).json({error:'SELF_ORDER'});if(l.stock<qty)return res.status(400).json({error:'OUT_OF_STOCK'});const discount=Math.max(0,Math.min(100,l.discountPct));const unit=Math.floor(l.priceCents*(100-discount)/100);const amount=unit*qty;const saleRate=Number((await prisma.commissionSetting.findFirst())?.saleRatePct||5);const commission=Math.floor(amount*saleRate/100);const row=await prisma.$transaction(async tx=>{const updated=await tx.storeListing.update({where:{id:l.id},data:{stock:{decrement:qty},purchases:{increment:1}}});const order=await tx.storeOrder.create({data:{listingId:l.id,buyerId:req.user.id,quantity:qty,amountCents:amount,currency:l.currency,status:'REQUESTED',commissionCents:commission}});await tx.commissionLedger.create({data:{orderId:order.id,recipientId:l.sellerId,source:'STORE_SALE',grossCents:amount,commissionCents:commission,netCents:amount-commission,currency:l.currency,status:'PENDING'}});return order;});res.status(201).json(row);});
app.post('/api/store/listings/:id/reviews',auth,async(req,res)=>{const rating=Math.max(1,Math.min(5,Number(req.body?.rating||0))),comment=String(req.body?.comment||'').slice(0,1000);const l=await prisma.storeListing.findUnique({where:{id:req.params.id}});if(!l)return res.status(404).json({error:'LISTING_NOT_FOUND'});const order=await prisma.storeOrder.findFirst({where:{listingId:l.id,buyerId:req.user.id,status:{in:['REQUESTED','COMPLETED']} }});if(!order)return res.status(403).json({error:'PURCHASE_REQUIRED'});const row=await prisma.storeReview.upsert({where:{listingId_authorId:{listingId:l.id,authorId:req.user.id}},create:{listingId:l.id,sellerId:l.sellerId,authorId:req.user.id,rating,comment},update:{rating,comment}});res.status(201).json(row);});
app.get('/api/store/commission/settings',auth,async(req,res)=>res.json(await prisma.commissionSetting.findFirst()||await prisma.commissionSetting.create({data:{}})));
app.get('/api/store/commission/dashboard',auth,async(req,res)=>{const settings=await prisma.commissionSetting.findFirst()||await prisma.commissionSetting.create({data:{}});const rows=await prisma.commissionLedger.findMany({where:{recipientId:req.user.id},orderBy:{createdAt:'desc'},take:200});const summary=rows.reduce((a,x)=>({grossCents:a.grossCents+x.grossCents,commissionCents:a.commissionCents+x.commissionCents,netCents:a.netCents+x.netCents,affiliateCents:a.affiliateCents+(x.source==='AFFILIATE'?x.commissionCents:0)}),{grossCents:0,commissionCents:0,netCents:0,affiliateCents:0});res.json({settings,summary,rows});});
app.get('/api/store/affiliate/:listingId',auth,async(req,res)=>{const l=await prisma.storeListing.findUnique({where:{id:req.params.listingId}});if(!l)return res.status(404).json({error:'LISTING_NOT_FOUND'});const row=await prisma.affiliateReferral.findFirst({where:{listingId:l.id,referrerId:req.user.id}});res.json(row||{listingId:l.id,referrerId:req.user.id,clicks:0,commissionCents:0,status:'PENDING'});});
app.post('/api/store/affiliate/click',auth,async(req,res)=>{const listingId=String(req.body?.listingId||''),referrerId=String(req.body?.referrerId||'');const l=await prisma.storeListing.findUnique({where:{id:listingId}});const ref=await prisma.user.findUnique({where:{id:referrerId}});if(!l||!ref)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.affiliateReferral.findFirst({where:{listingId,referrerId,buyerId:req.user.id}});const row=old?await prisma.affiliateReferral.update({where:{id:old.id},data:{clicks:{increment:1}}}):await prisma.affiliateReferral.create({data:{listingId,referrerId,buyerId:req.user.id,clicks:1}});res.json(row);});


// ---- SocialNova Hub: Movies / Series / Creator monetization ----
const accessModes = new Set(['FREE','PAID','SUBSCRIBER']);
const contentKinds = new Set(['MOVIE','EPISODE']);
function moneyInt(v){return Math.max(0,Math.min(100000000,Math.trunc(Number(v)||0)));}
function splitPct(v){const n=Number(v); return Number.isFinite(n)?Math.max(0,Math.min(100,n)):70;}
async function creatorSubscriptionActive(creatorId,userId){
  if(!creatorId||!userId)return false;
  if(creatorId===userId)return true;
  const row=await prisma.creatorSubscription.findFirst({where:{creatorId,subscriberId:userId,status:'VERIFIED',OR:[{expiresAt:null},{expiresAt:{gt:new Date()}}]},orderBy:{expiresAt:'desc'}});
  return !!row;
}
async function hasContentAccess(userId,kind,id){
  const now=new Date();
  if(kind==='MOVIE'){
    const movie=await prisma.movie.findUnique({where:{id}}); if(!movie||!movie.published)return {allowed:false,reason:'NOT_FOUND'};
    if(movie.creatorId===userId||movie.accessMode==='FREE')return {allowed:true,content:movie};
    if(movie.accessMode==='SUBSCRIBER' && await creatorSubscriptionActive(movie.creatorId,userId))return {allowed:true,content:movie};
    const purchase=await prisma.contentPurchase.findFirst({where:{movieId:id,buyerId:userId,status:'VERIFIED'}}); if(purchase)return {allowed:true,content:movie};
    return {allowed:false,reason:movie.accessMode,content:movie};
  }
  const ep=await prisma.episode.findUnique({where:{id},include:{season:{include:{series:true}}}}); if(!ep||!ep.published)return {allowed:false,reason:'NOT_FOUND'};
  if(ep.creatorId===userId||ep.accessMode==='FREE')return {allowed:true,content:ep};
  if(ep.accessMode==='SUBSCRIBER' && await creatorSubscriptionActive(ep.creatorId,userId))return {allowed:true,content:ep};
  const purchase=await prisma.contentPurchase.findFirst({where:{episodeId:id,buyerId:userId,status:'VERIFIED'}}); if(purchase)return {allowed:true,content:ep};
  const pass=await prisma.seasonPass.findFirst({where:{seasonId:ep.seasonId,buyerId:userId,status:'VERIFIED'}}); if(pass)return {allowed:true,content:ep};
  return {allowed:false,reason:ep.accessMode,content:ep};
}
function publicMovie(m){return {...m,videoUrl: m.accessMode==='FREE' ? m.videoUrl : ''};}
function publicEpisode(e){return {...e,videoUrl: e.accessMode==='FREE' ? e.videoUrl : ''};}
function publicSeries(s){return {...s,seasons:(s.seasons||[]).map(se=>({...se,episodes:(se.episodes||[]).map(publicEpisode)}))};}

app.get('/api/hub',auth,async(req,res)=>{
  const [movies,series,audio,teams,academy]=await Promise.all([
    prisma.movie.findMany({where:{published:true},orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:30,include:{creator:true}}),
    prisma.series.findMany({where:{status:'PUBLISHED'},orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:30,include:{creator:true,seasons:{orderBy:{number:'asc'},include:{episodes:{orderBy:{number:'asc'}}}}}}),
    prisma.audioRoom.findMany({where:{status:'LIVE'},orderBy:{createdAt:'desc'},take:30,include:{host:true}}),
    prisma.creatorTeam.findMany({orderBy:{createdAt:'desc'},take:30,include:{owner:true,_count:{select:{members:true}}}}),
    prisma.academyCourse.findMany({where:{published:true},orderBy:{createdAt:'desc'},take:30,include:{creator:true,lessons:true}})
  ]);
  res.json({movies:movies.map(publicMovie),series:series.map(publicSeries),audioRooms:audio,creatorTeams:teams,academy});
});

app.get('/api/movies',auth,async(req,res)=>{
  const q=String(req.query.q||'').trim();
  const where={published:true,...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{description:{contains:q,mode:'insensitive'}}]}:{})};
  const rows=await prisma.movie.findMany({where,orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:100,include:{creator:true}});
  res.json(rows.map(publicMovie));
});
app.get('/api/movies/:id',auth,async(req,res)=>{const row=await prisma.movie.findUnique({where:{id:req.params.id},include:{creator:true,purchases:true}});if(!row||!row.published)return res.status(404).json({error:'NOT_FOUND'});res.json(publicMovie(row));});
app.get('/api/series',auth,async(req,res)=>{const q=String(req.query.q||'').trim();const where={status:'PUBLISHED',...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{description:{contains:q,mode:'insensitive'}}]}:{})};const rows=await prisma.series.findMany({where,orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:100,include:{creator:true,seasons:{orderBy:{number:'asc'},include:{episodes:{orderBy:{number:'asc'}}}}}});res.json(rows.map(publicSeries));});
app.get('/api/series/:id',auth,async(req,res)=>{const row=await prisma.series.findUnique({where:{id:req.params.id},include:{creator:true,seasons:{orderBy:{number:'asc'},include:{episodes:{orderBy:{number:'asc'}}}}}});if(!row||row.status!=='PUBLISHED')return res.status(404).json({error:'NOT_FOUND'});res.json(publicSeries(row));});
app.get('/api/episodes/:id',auth,async(req,res)=>{const row=await prisma.episode.findUnique({where:{id:req.params.id},include:{creator:true,season:{include:{series:true}}}});if(!row||!row.published)return res.status(404).json({error:'NOT_FOUND'});res.json(publicEpisode(row));});

app.post('/api/creator/series',auth,async(req,res)=>{try{const d=z.object({title:z.string().min(2).max(200),description:z.string().max(10000).default(''),posterUrl:z.string().max(5000).default(''),trailerUrl:z.string().max(5000).default(''),visibility:z.string().max(30).default('PUBLIC'),subscriberOnly:z.boolean().default(false),seasonPassPriceCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD'),creatorSharePct:z.number().min(0).max(100).default(70)}).parse(req.body);const row=await prisma.series.create({data:{...d,creatorId:req.user.id,platformSharePct:100-d.creatorSharePct}});res.status(201).json(row);}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/creator/series/:id/seasons',auth,async(req,res)=>{const series=await prisma.series.findUnique({where:{id:req.params.id}});if(!series)return res.status(404).json({error:'NOT_FOUND'});if(series.creatorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});try{const d=z.object({number:z.number().int().positive(),title:z.string().max(200).default(''),description:z.string().max(10000).default(''),passPriceCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD'),creatorSharePct:z.number().min(0).max(100).default(series.creatorSharePct)}).parse(req.body);const row=await prisma.season.create({data:{...d,seriesId:series.id,platformSharePct:100-d.creatorSharePct}});res.status(201).json(row);}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/creator/seasons/:id/episodes',auth,async(req,res)=>{const season=await prisma.season.findUnique({where:{id:req.params.id},include:{series:true}});if(!season)return res.status(404).json({error:'NOT_FOUND'});if(season.series.creatorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});try{const d=z.object({number:z.number().int().positive(),title:z.string().min(1).max(200),description:z.string().max(10000).default(''),videoUrl:z.string().min(1).max(10000),thumbnailUrl:z.string().max(5000).default(''),durationSec:z.number().int().nonnegative().default(0),accessMode:z.enum(['FREE','PAID','SUBSCRIBER']).default('FREE'),priceCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD'),adSupported:z.boolean().default(false),creatorSharePct:z.number().min(0).max(100).default(season.creatorSharePct)}).parse(req.body);const row=await prisma.episode.create({data:{...d,seasonId:season.id,creatorId:req.user.id,platformSharePct:100-d.creatorSharePct}});res.status(201).json(publicEpisode(row));}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/creator/movies',auth,async(req,res)=>{try{const d=z.object({title:z.string().min(2).max(200),description:z.string().max(10000).default(''),posterUrl:z.string().max(5000).default(''),trailerUrl:z.string().max(5000).default(''),videoUrl:z.string().min(1).max(10000),durationSec:z.number().int().nonnegative().default(0),accessMode:z.enum(['FREE','PAID','SUBSCRIBER']).default('FREE'),priceCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD'),adSupported:z.boolean().default(false),creatorSharePct:z.number().min(0).max(100).default(70)}).parse(req.body);const row=await prisma.movie.create({data:{...d,creatorId:req.user.id,platformSharePct:100-d.creatorSharePct}});res.status(201).json(publicMovie(row));}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});

app.get('/api/content/:kind/:id/access',auth,async(req,res)=>{const kind=String(req.params.kind||'').toUpperCase();if(!contentKinds.has(kind))return res.status(400).json({error:'INVALID_CONTENT_TYPE'});const out=await hasContentAccess(req.user.id,kind,req.params.id);if(!out.content)return res.status(404).json({error:'NOT_FOUND'});res.json({allowed:out.allowed,reason:out.reason||null,content:out.allowed?(kind==='MOVIE'?out.content:out.content):{id:out.content.id,title:out.content.title,accessMode:out.content.accessMode,priceCents:out.content.priceCents,currency:out.content.currency}});});
app.post('/api/content/purchase',auth,async(req,res)=>{try{const d=z.object({kind:z.enum(['MOVIE','EPISODE']),id:z.string().min(1),productId:z.string().min(1).max(200),purchaseToken:z.string().min(10).max(10000),amountCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD')}).parse(req.body);const existing=await prisma.contentPurchase.findUnique({where:{purchaseToken:d.purchaseToken}});if(existing)return res.json(existing);let content;if(d.kind==='MOVIE')content=await prisma.movie.findUnique({where:{id:d.id}});else content=await prisma.episode.findUnique({where:{id:d.id},include:{season:true}});if(!content)return res.status(404).json({error:'NOT_FOUND'});if(content.accessMode==='FREE')return res.status(400).json({error:'CONTENT_IS_FREE'});const creatorSharePct=splitPct(content.creatorSharePct);let status='PENDING_VERIFICATION';let verifiedAt=null;if(googlePlayConfigured()){const v=await verifyGoogleOneTime(d.productId,d.purchaseToken);if(!v.verified)return res.status(400).json({error:'GOOGLE_PURCHASE_NOT_VERIFIED'});status='VERIFIED';verifiedAt=new Date();}const row=await prisma.contentPurchase.create({data:{buyerId:req.user.id,movieId:d.kind==='MOVIE'?d.id:null,episodeId:d.kind==='EPISODE'?d.id:null,productId:d.productId,purchaseToken:d.purchaseToken,status,verifiedAt,amountCents:moneyInt(d.amountCents),currency:d.currency,creatorSharePct,platformSharePct:100-creatorSharePct}});res.status(status==='VERIFIED'?201:202).json({verification:status,purchase:row,message:status==='VERIFIED'?'تم التحقق من Google Play.':'تم التسجيل بانتظار إعداد Google Play للتحقق.'});}catch(e){console.error('[content purchase verify]',e.message);res.status(400).json({error:String(e.message||'GOOGLE_PURCHASE_FAILED')})}});
app.post('/api/content/purchase/verify',auth,async(req,res)=>{try{const token=String(req.body?.purchaseToken||'');if(!token)return res.status(400).json({error:'PURCHASE_TOKEN_REQUIRED'});const row=await prisma.contentPurchase.findUnique({where:{purchaseToken:token}});if(!row||row.buyerId!==req.user.id)return res.status(404).json({error:'PURCHASE_NOT_FOUND'});const v=await verifyGoogleOneTime(row.productId,row.purchaseToken);if(!v.configured)return res.status(503).json({error:'GOOGLE_PLAY_NOT_CONFIGURED'});if(!v.verified)return res.status(400).json({error:'GOOGLE_PURCHASE_NOT_VERIFIED'});const out=await prisma.contentPurchase.update({where:{id:row.id},data:{status:'VERIFIED',verifiedAt:new Date()}});res.json(out);}catch(e){res.status(400).json({error:String(e.message||'GOOGLE_PURCHASE_FAILED')})}});
app.post('/api/content/subscription',auth,async(req,res)=>{try{const d=z.object({creatorId:z.string().min(1),productId:z.string().min(1).max(200),purchaseToken:z.string().min(10).max(10000),expiresAt:z.string().datetime().nullable().optional()}).parse(req.body);const creator=await prisma.user.findUnique({where:{id:d.creatorId}});if(!creator)return res.status(404).json({error:'USER_NOT_FOUND'});let status='PENDING_VERIFICATION',expires=d.expiresAt?new Date(d.expiresAt):null;if(googlePlayConfigured()){const v=await verifyGoogleSubscription(d.productId,d.purchaseToken);if(!v.verified)return res.status(400).json({error:'GOOGLE_SUBSCRIPTION_NOT_VERIFIED'});status='VERIFIED';const expiry=v.line?.expiryTime;if(expiry)expires=new Date(expiry);}const row=await prisma.creatorSubscription.upsert({where:{purchaseToken:d.purchaseToken},create:{creatorId:d.creatorId,subscriberId:req.user.id,productId:d.productId,purchaseToken:d.purchaseToken,status,expiresAt:expires},update:{expiresAt:expires,status}});res.status(status==='VERIFIED'?201:202).json({verification:status,subscription:row});}catch(e){res.status(400).json({error:String(e.message||'GOOGLE_SUBSCRIPTION_FAILED')})}});
app.post('/api/content/subscription/verify',auth,async(req,res)=>{try{const token=String(req.body?.purchaseToken||'');const row=await prisma.creatorSubscription.findUnique({where:{purchaseToken:token}});if(!row||row.subscriberId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});const v=await verifyGoogleSubscription(row.productId,row.purchaseToken);if(!v.configured)return res.status(503).json({error:'GOOGLE_PLAY_NOT_CONFIGURED'});if(!v.verified)return res.status(400).json({error:'GOOGLE_SUBSCRIPTION_NOT_VERIFIED'});const expiry=v.line?.expiryTime?new Date(v.line.expiryTime):null;res.json(await prisma.creatorSubscription.update({where:{id:row.id},data:{status:'VERIFIED',expiresAt:expiry}}));}catch(e){res.status(400).json({error:String(e.message||'GOOGLE_SUBSCRIPTION_FAILED')})}});
app.post('/api/content/season-pass',auth,async(req,res)=>{try{const d=z.object({seasonId:z.string().min(1),productId:z.string().min(1).max(200),purchaseToken:z.string().min(10).max(10000),amountCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD')}).parse(req.body);const season=await prisma.season.findUnique({where:{id:d.seasonId}});if(!season)return res.status(404).json({error:'NOT_FOUND'});const row=await prisma.seasonPass.upsert({where:{purchaseToken:d.purchaseToken},create:{seasonId:d.seasonId,buyerId:req.user.id,productId:d.productId,purchaseToken:d.purchaseToken,status:'PENDING_VERIFICATION',amountCents:d.amountCents,currency:d.currency},update:{status:'PENDING_VERIFICATION'}});res.status(202).json({verification:'PENDING',seasonPass:row,message:'تم تسجيل Season Pass بانتظار التحقق من Google Play.'});}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/content/ad-impression',auth,async(req,res)=>{try{const d=z.object({creatorId:z.string().min(1),movieId:z.string().nullable().optional(),episodeId:z.string().nullable().optional(),placement:z.string().max(80).default('CONTENT'),qualified:z.boolean().default(false),eCPM:z.number().nonnegative().default(0),revenueCents:z.number().int().nonnegative().default(0),currency:z.string().max(8).default('USD')}).parse(req.body);if(!d.qualified)return res.json({accepted:false,reason:'NOT_QUALIFIED'});const row=await prisma.adImpression.create({data:{...d,viewerId:req.user.id}});res.status(201).json(row);}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/admin/content-purchases/:id/verify',auth,admin,async(req,res)=>{const row=await prisma.contentPurchase.findUnique({where:{id:req.params.id}});if(!row)return res.status(404).json({error:'NOT_FOUND'});if(String(req.body?.verifiedBy||'')!=='GOOGLE_PLAY')return res.status(400).json({error:'EXTERNAL_VERIFICATION_REQUIRED'});const out=await prisma.contentPurchase.update({where:{id:row.id},data:{status:'VERIFIED',verifiedAt:new Date()}});res.json(out);});
app.post('/api/admin/subscriptions/:id/verify',auth,admin,async(req,res)=>{const row=await prisma.creatorSubscription.findUnique({where:{id:req.params.id}});if(!row)return res.status(404).json({error:'NOT_FOUND'});if(String(req.body?.verifiedBy||'')!=='GOOGLE_PLAY')return res.status(400).json({error:'EXTERNAL_VERIFICATION_REQUIRED'});res.json(await prisma.creatorSubscription.update({where:{id:row.id},data:{status:'VERIFIED'}}));});
app.post('/api/admin/season-passes/:id/verify',auth,admin,async(req,res)=>{const row=await prisma.seasonPass.findUnique({where:{id:req.params.id}});if(!row)return res.status(404).json({error:'NOT_FOUND'});if(String(req.body?.verifiedBy||'')!=='GOOGLE_PLAY')return res.status(400).json({error:'EXTERNAL_VERIFICATION_REQUIRED'});res.json(await prisma.seasonPass.update({where:{id:row.id},data:{status:'VERIFIED'}}));});
app.post('/api/content/:kind/:id/view',auth,async(req,res)=>{const kind=String(req.params.kind||'').toUpperCase();const out=await hasContentAccess(req.user.id,kind,req.params.id);if(!out.content)return res.status(404).json({error:'NOT_FOUND'});if(!out.allowed)return res.status(402).json({error:'CONTENT_LOCKED',accessMode:out.content.accessMode,priceCents:out.content.priceCents,currency:out.content.currency});if(kind==='MOVIE')await prisma.movie.update({where:{id:req.params.id},data:{views:{increment:1}}});else await prisma.episode.update({where:{id:req.params.id},data:{views:{increment:1}}});res.json({ok:true,allowed:true,videoUrl:out.content.videoUrl});});

app.get('/api/creator/studio',auth,async(req,res)=>{
  const [movies,series,episodes,subs,purchases,ads]=await Promise.all([
    prisma.movie.findMany({where:{creatorId:req.user.id},orderBy:{createdAt:'desc'}}),
    prisma.series.findMany({where:{creatorId:req.user.id},orderBy:{createdAt:'desc'},include:{seasons:{include:{episodes:true}}}}),
    prisma.episode.findMany({where:{creatorId:req.user.id},orderBy:{createdAt:'desc'}}),
    prisma.creatorSubscription.findMany({where:{creatorId:req.user.id,status:'VERIFIED'},orderBy:{startedAt:'desc'}}),
    prisma.contentPurchase.findMany({where:{status:'VERIFIED',OR:[{movie:{creatorId:req.user.id}},{episode:{creatorId:req.user.id}}]},orderBy:{createdAt:'desc'},take:500}),
    prisma.adImpression.findMany({where:{creatorId:req.user.id,qualified:true},orderBy:{createdAt:'desc'},take:1000})
  ]);
  const gross=purchases.reduce((a,x)=>a+x.amountCents,0)+ads.reduce((a,x)=>a+x.revenueCents,0); const creator=purchases.reduce((a,x)=>a+Math.floor(x.amountCents*x.creatorSharePct/100),0)+ads.reduce((a,x)=>a+Math.floor(x.revenueCents*0.7),0);
  res.json({movies,series,episodes,subscriptions:subs.length,purchases: purchases.length,adsQualified:ads.length,revenue:{grossCents:gross,creatorCents:creator,platformCents:gross-creator,currency:'USD'}});
});

// ---- Creator teams / audio rooms / battles / academy / hall of fame / AI coach ----
app.get('/api/creator/teams',auth,async(req,res)=>res.json(await prisma.creatorTeam.findMany({where:{OR:[{ownerId:req.user.id},{members:{some:{userId:req.user.id}}}]},include:{owner:true,members:{include:{user:true}}},orderBy:{createdAt:'desc'}})));
app.post('/api/creator/teams',auth,async(req,res)=>{const name=String(req.body?.name||'').trim();if(name.length<2)return res.status(400).json({error:'VALIDATION_ERROR'});const row=await prisma.creatorTeam.create({data:{ownerId:req.user.id,name:name.slice(0,100),description:String(req.body?.description||'').slice(0,1000),members:{create:{userId:req.user.id,role:'OWNER'}}},include:{members:true}});res.status(201).json(row)});
app.post('/api/creator/teams/:id/members',auth,async(req,res)=>{const team=await prisma.creatorTeam.findUnique({where:{id:req.params.id}});if(!team||team.ownerId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const user=await prisma.user.findUnique({where:{id:String(req.body?.userId||'')}});if(!user)return res.status(404).json({error:'USER_NOT_FOUND'});const row=await prisma.creatorTeamMember.upsert({where:{teamId_userId:{teamId:team.id,userId:user.id}},create:{teamId:team.id,userId:user.id,role:String(req.body?.role||'MEMBER')},update:{role:String(req.body?.role||'MEMBER')}});res.json(row)});
app.get('/api/audio-rooms',auth,async(req,res)=>res.json(await prisma.audioRoom.findMany({where:{status:'LIVE'},include:{host:true},orderBy:{createdAt:'desc'},take:100})));
app.post('/api/audio-rooms',auth,async(req,res)=>{const title=String(req.body?.title||'').trim();if(title.length<2)return res.status(400).json({error:'VALIDATION_ERROR'});const roomName=`audio-${req.user.id}-${crypto.randomUUID()}`;const row=await prisma.audioRoom.create({data:{hostId:req.user.id,title:title.slice(0,160),topic:String(req.body?.topic||'').slice(0,300),roomName,maxSpeakers:Math.max(2,Math.min(100,Number(req.body?.maxSpeakers||12)))},include:{host:true}});res.status(201).json(row)});
app.post('/api/audio-rooms/:id/end',auth,async(req,res)=>{const row=await prisma.audioRoom.findUnique({where:{id:req.params.id}});if(!row||row.hostId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});res.json(await prisma.audioRoom.update({where:{id:row.id},data:{status:'ENDED',endedAt:new Date()}}))});
app.get('/api/battles',auth,async(req,res)=>res.json(await prisma.battle.findMany({where:{status:'LIVE'},include:{participants:{include:{user:true}}},orderBy:{createdAt:'desc'},take:100})));
app.post('/api/battles',auth,async(req,res)=>{const row=await prisma.battle.create({data:{roomName:String(req.body?.roomName||''),title:String(req.body?.title||'Creator Battle').slice(0,160),endsAt:req.body?.endsAt?new Date(req.body.endsAt):null,participants:{create:{userId:req.user.id}}},include:{participants:true}});res.status(201).json(row)});
app.post('/api/battles/:id/score',auth,async(req,res)=>{const delta=Math.max(-1000,Math.min(1000,Number(req.body?.delta||0)));const row=await prisma.battleParticipant.update({where:{battleId_userId:{battleId:req.params.id,userId:req.user.id}},data:{score:{increment:delta}}});res.json(row)});
app.get('/api/academy',auth,async(req,res)=>res.json(await prisma.academyCourse.findMany({where:{published:true},include:{creator:true,lessons:{orderBy:{number:'asc'}}},orderBy:{createdAt:'desc'}})));
app.post('/api/academy/courses',auth,async(req,res)=>{const title=String(req.body?.title||'').trim();if(title.length<2)return res.status(400).json({error:'VALIDATION_ERROR'});res.status(201).json(await prisma.academyCourse.create({data:{creatorId:req.user.id,title:title.slice(0,200),description:String(req.body?.description||'').slice(0,5000),coverUrl:String(req.body?.coverUrl||'').slice(0,5000),published:Boolean(req.body?.published)}}))});
app.get('/api/hall-of-fame',auth,async(req,res)=>res.json(await prisma.hallOfFameEntry.findMany({orderBy:{metric:'desc'},take:100,include:{user:true}})));
app.post('/api/ai/creator-coach',auth,async(req,res)=>{const goal=String(req.body?.goal||'').trim();if(!goal)return res.status(400).json({error:'VALIDATION_ERROR'});const prompt=String(req.body?.prompt||'').slice(0,4000);const response=`خطة Creator Coach أولية للهدف: ${goal}\n\n1) حدد جمهورًا واضحًا.\n2) انشر جدولًا ثابتًا للمحتوى.\n3) راقب الاحتفاظ بالمشاهدين والتفاعل.\n4) اختبر العناوين والصور المصغرة دون شراء مشاهدات أو متابعين.`;const row=await prisma.aiCoachSession.create({data:{userId:req.user.id,goal:goal.slice(0,500),prompt,response}});res.json(row)});

// Admin: content catalog, featured media, revenue and safe moderation controls.
app.get('/api/admin/movies',auth,admin,async(req,res)=>res.json(await prisma.movie.findMany({orderBy:{createdAt:'desc'},take:300,include:{creator:true}})));
app.get('/api/admin/series',auth,admin,async(req,res)=>res.json(await prisma.series.findMany({orderBy:{createdAt:'desc'},take:300,include:{creator:true,seasons:{include:{episodes:true}}}})));
app.patch('/api/admin/movies/:id/feature',auth,admin,async(req,res)=>res.json(await prisma.movie.update({where:{id:req.params.id},data:{featured:Boolean(req.body?.featured),featuredPriority:Math.max(0,Math.min(10000,Number(req.body?.priority||0)))}})));
app.patch('/api/admin/series/:id/feature',auth,admin,async(req,res)=>res.json(await prisma.series.update({where:{id:req.params.id},data:{featured:Boolean(req.body?.featured),featuredPriority:Math.max(0,Math.min(10000,Number(req.body?.priority||0)))}})));
app.get('/api/admin/content-revenue',auth,admin,async(req,res)=>{const [p,a]=await Promise.all([prisma.contentPurchase.findMany({where:{status:'VERIFIED'},orderBy:{createdAt:'desc'},take:1000}),prisma.adImpression.findMany({where:{qualified:true},orderBy:{createdAt:'desc'},take:2000})]);const gross=p.reduce((x,r)=>x+r.amountCents,0)+a.reduce((x,r)=>x+r.revenueCents,0);const creator=p.reduce((x,r)=>x+Math.floor(r.amountCents*r.creatorSharePct/100),0)+a.reduce((x,r)=>x+Math.floor(r.revenueCents*0.7),0);res.json({grossCents:gross,creatorCents:creator,platformCents:gross-creator,purchases:p.length,qualifiedAds:a.length});});

// ---- Content analytics/archive ----
app.get('/api/content/:type/:id/analytics',auth,async(req,res)=>{
  const type=req.params.type,id=req.params.id;
  if(type==='post'){const x=await prisma.post.findUnique({where:{id},include:{likes:true,comments:true,shares:true,reposts:true,postViews:true}});if(!x)return res.status(404).json({error:'NOT_FOUND'});if(x.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});return res.json({type,views:x.postViews.length,likes:x.likes.length,comments:x.comments.length,shares:x.shares.length,reposts:x.reposts.length});}
  if(type==='reel'){const x=await prisma.reel.findUnique({where:{id},include:{likes:true,comments:true,shares:true,reposts:true,viewsLog:true}});if(!x)return res.status(404).json({error:'NOT_FOUND'});if(x.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});return res.json({type,views:x.views,uniqueViewers:x.viewsLog.length,likes:x.likes.length,comments:x.comments.length,shares:x.shares.length,reposts:x.reposts.length});}
  if(type==='story'){const x=await prisma.story.findUnique({where:{id},include:{replies:true,reactions:true}});if(!x)return res.status(404).json({error:'NOT_FOUND'});if(x.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});return res.json({type,replies:x.replies.length,reactions:x.reactions.length});}
  return res.status(400).json({error:'INVALID_CONTENT_TYPE'});
});
app.get('/api/content/:type/archived',auth,async(req,res)=>{const type=req.params.type;if(type==='post')return res.json(await prisma.post.findMany({where:{authorId:req.user.id,archived:true},orderBy:{createdAt:'desc'},take:100}));if(type==='reel')return res.json(await prisma.reel.findMany({where:{authorId:req.user.id,archived:true},orderBy:{createdAt:'desc'},take:100}));if(type==='story')return res.json(await prisma.story.findMany({where:{authorId:req.user.id,archived:true},orderBy:{createdAt:'desc'},take:100}));res.status(400).json({error:'INVALID_CONTENT_TYPE'});});

app.get('/api/chat/:userId/theme',auth,async(req,res)=>{
  const peer=await prisma.user.findUnique({where:{id:req.params.userId}});
  if(!peer)return res.status(404).json({error:'USER_NOT_FOUND'});
  const row=await prisma.chatTheme.findUnique({where:{ownerId_peerId:{ownerId:req.user.id,peerId:peer.id}}});
  const reverse=await prisma.chatTheme.findUnique({where:{ownerId_peerId:{ownerId:peer.id,peerId:req.user.id}}});
  res.json(reverse?{background:reverse.background,bubbleStyle:reverse.bubbleStyle,accent:reverse.accent}:row?{background:row.background,bubbleStyle:row.bubbleStyle,accent:row.accent}:{background:'gradient:midnight',bubbleStyle:'glass',accent:'violet'});
});
app.put('/api/chat/:userId/theme',auth,async(req,res)=>{
  const peer=await prisma.user.findUnique({where:{id:req.params.userId}});
  if(!peer)return res.status(404).json({error:'USER_NOT_FOUND'});
  const background=String(req.body?.background||'gradient:midnight').slice(0,200);
  const bubbleStyle=String(req.body?.bubbleStyle||'glass').slice(0,40);
  const accent=String(req.body?.accent||'violet').slice(0,40);
  const row=await prisma.chatTheme.upsert({where:{ownerId_peerId:{ownerId:req.user.id,peerId:peer.id}},create:{ownerId:req.user.id,peerId:peer.id,background,bubbleStyle,accent},update:{background,bubbleStyle,accent}});
  res.json({background:row.background,bubbleStyle:row.bubbleStyle,accent:row.accent});
});
app.get('/api/chats/:userId/theme',auth,async(req,res)=>{
  const peer=await prisma.user.findUnique({where:{id:req.params.userId},select:{id:true}});
  if(!peer)return res.status(404).json({error:'USER_NOT_FOUND'});
  const row=await prisma.chatTheme.findUnique({where:{ownerId_peerId:{ownerId:req.user.id,peerId:peer.id}}});
  if(row)return res.json({background:row.background,bubbleStyle:row.bubbleStyle,accent:row.accent});
  const reverse=await prisma.chatTheme.findUnique({where:{ownerId_peerId:{ownerId:peer.id,peerId:req.user.id}}});
  res.json(reverse?{background:reverse.background,bubbleStyle:reverse.bubbleStyle,accent:reverse.accent}:{background:'gradient:midnight',bubbleStyle:'glass',accent:'violet'});
});
app.put('/api/chats/:userId/theme',auth,async(req,res)=>{
  const peer=await prisma.user.findUnique({where:{id:req.params.userId},select:{id:true}});
  if(!peer)return res.status(404).json({error:'USER_NOT_FOUND'});
  const background=String(req.body?.background||'gradient:midnight').slice(0,200);
  const bubbleStyle=String(req.body?.bubbleStyle||'glass').slice(0,40);
  const accent=String(req.body?.accent||'violet').slice(0,40);
  const row=await prisma.chatTheme.upsert({where:{ownerId_peerId:{ownerId:req.user.id,peerId:peer.id}},create:{ownerId:req.user.id,peerId:peer.id,background,bubbleStyle,accent},update:{background,bubbleStyle,accent}});
  res.json({background:row.background,bubbleStyle:row.bubbleStyle,accent:row.accent});
});
app.get('/api/messages/:userId',auth,async(req,res)=>{
  const now=new Date();
  await prisma.message.deleteMany({where:{expiresAt:{not:null,lt:now}}});
  const rows=await prisma.message.findMany({where:{AND:[{OR:[{senderId:req.user.id,receiverId:req.params.userId,deletedForSender:false},{senderId:req.params.userId,receiverId:req.user.id,deletedForReceiver:false}]},{OR:[{expiresAt:null},{expiresAt:{gt:now}}]}]},orderBy:{createdAt:'asc'},take:200});
  const incoming=rows.filter(m=>m.receiverId===req.user.id && !m.read);
  if(incoming.length){await prisma.message.updateMany({where:{id:{in:incoming.map(m=>m.id)}},data:{read:true,readAt:now,deliveredAt:now}});for(const m of incoming)io.to(`user:${m.senderId}`).emit('message:read',{messageId:m.id,readAt:now.toISOString()});}
  const selfDestructIds=rows.filter(m=>m.selfDestruct && m.receiverId===req.user.id).map(m=>m.id);
  if(selfDestructIds.length) await prisma.message.deleteMany({where:{id:{in:selfDestructIds}}});
  res.json(rows.filter(m=>!selfDestructIds.includes(m.id)).map(m=>incoming.some(x=>x.id===m.id)?{...m,read:true,readAt:now.toISOString(),deliveredAt:m.deliveredAt||now.toISOString()}:m));
});
app.get('/api/conversations',auth,async(req,res)=>{const rows=await prisma.message.findMany({where:{OR:[{senderId:req.user.id},{receiverId:req.user.id}]},orderBy:{createdAt:'desc'},take:500});const ids=[...new Set(rows.map(m=>m.senderId===req.user.id?m.receiverId:m.senderId))];const users=await prisma.user.findMany({where:{id:{in:ids}}});res.json(users.map(u=>{const rel=rows.find(m=>(m.senderId===req.user.id&&m.receiverId===u.id)||(m.receiverId===req.user.id&&m.senderId===u.id));const unread=rows.filter(m=>m.senderId===u.id&&m.receiverId===req.user.id&&!m.read&&!m.deletedForReceiver).length;return {...safe(u),lastMessage:rel?{id:rel.id,body:rel.body,createdAt:rel.createdAt,read:rel.read,deliveredAt:rel.deliveredAt,readAt:rel.readAt,senderId:rel.senderId}:null,unreadCount:unread};}));});
app.post('/api/messages/:userId',auth,async(req,res)=>{const target=await prisma.user.findUnique({where:{id:req.params.userId}});if(!target)return res.status(404).json({error:'USER_NOT_FOUND'});if(target.id===req.user.id)return res.status(400).json({error:'SELF_MESSAGE'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_MESSAGE'});const secret=Boolean(req.body.secret);const selfDestruct=Boolean(req.body.selfDestruct);const ttl=Math.max(1,Math.min(1440,Number(req.body.ttlMinutes||60)));const viewLimit=Math.max(0,Math.min(2,Number(req.body.viewLimit||0)));const online=io.sockets.adapter.rooms.has(`user:${target.id}`);const effect=String(req.body.effect||'').slice(0,32);const m=await prisma.message.create({data:{senderId:req.user.id,receiverId:target.id,body:body.slice(0,4000),secret,selfDestruct,viewLimit,expiresAt:secret?new Date(Date.now()+ttl*60000):null,deliveredAt:online?new Date():null}});if(effect)await prisma.$executeRawUnsafe('UPDATE "Message" SET "effect"=$1 WHERE "id"=$2',effect,m.id).catch(()=>{});const out=effect?{...m,effect}:m;io.to(`user:${target.id}`).emit('message',out);if(online){await prisma.message.update({where:{id:m.id},data:{deliveredAt:new Date()}}).catch(()=>{});}else{await sendFcmToUser(target.id,{type:'message',messageId:m.id,fromId:req.user.id,body:m.body},{title:'SocialNova',body:body.startsWith('[')?'لديك رسالة جديدة':body.slice(0,120)});}res.status(201).json(out)});


// ---- Live comments / moderation ----
function livePermission(role, permissions, action){
  const p=Array.isArray(permissions)?permissions:[];
  if(role==='HOST') return true;
  if(p.includes('*')) return true;
  return p.includes(action);
}
async function liveStaff(roomId,userId){
  const row=await prisma.liveModerator.findUnique({where:{roomId_userId:{roomId,userId}}});
  return row||null;
}
async function liveCan(req,roomId,action){
  const room=await prisma.liveRoom.findUnique({where:{id:roomId}}); if(!room)return {room:null,ok:false};
  if(room.hostId===req.user.id)return {room,ok:true,role:'HOST'};
  const staff=await liveStaff(roomId,req.user.id); if(!staff)return {room,ok:false};
  let perms=[]; try{perms=Array.isArray(staff.permissions)?staff.permissions:JSON.parse(String(staff.permissions||'[]'));}catch{}
  return {room,ok:livePermission(staff.role,perms,action),role:staff.role,staff};
}
app.get('/api/live/:roomId/comments',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.roomId}}); if(!room)return res.status(404).json({error:'LIVE_NOT_FOUND'});
  const rows=await prisma.liveComment.findMany({where:{roomId:room.id,deleted:false},orderBy:{createdAt:'asc'},take:200,include:{author:true}});
  res.json(rows.map(c=>({...c,author:safe(c.author)})));
});
app.post('/api/live/:roomId/comments',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.roomId}}); if(!room||!['LIVE','PAUSED'].includes(room.status))return res.status(404).json({error:'LIVE_NOT_FOUND'});
  const body=String(req.body?.body||'').trim().slice(0,1000); if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});
  const replyToId=String(req.body?.replyToId||'').trim(); let replyToName='';
  if(replyToId){const parent=await prisma.liveComment.findUnique({where:{id:replyToId},include:{author:true}});if(!parent||parent.roomId!==room.id||parent.deleted)return res.status(400).json({error:'INVALID_REPLY'});replyToName=parent.author.displayName||parent.author.username||'';}
  const c=await prisma.liveComment.create({data:{roomId:room.id,authorId:req.user.id,body,replyToId:replyToId||null,replyToName},include:{author:true}});
  const payload={...c,author:safe(c.author)};io.to(`live:${room.roomName}`).emit('live:comment',payload);res.status(201).json(payload);
});
app.post('/api/live/:roomId/moderators',auth,async(req,res)=>{
  const room=await prisma.liveRoom.findUnique({where:{id:req.params.roomId}}); if(!room||room.hostId!==req.user.id)return res.status(403).json({error:'HOST_ONLY'});
  const userId=String(req.body?.userId||'').trim(); const role=String(req.body?.role||'MODERATOR').toUpperCase()==='ASSISTANT'?'ASSISTANT':'MODERATOR';
  const u=await prisma.user.findUnique({where:{id:userId}}); if(!u)return res.status(404).json({error:'USER_NOT_FOUND'});
  const follows=await prisma.follow.findUnique({where:{followerId_followingId:{followerId:userId,followingId:req.user.id}}}); if(!follows)return res.status(400).json({error:'NOT_FOLLOWER'});
  const permissions=role==='ASSISTANT'?['DELETE_COMMENT','PIN_COMMENT','MUTE_CHAT']:['DELETE_COMMENT','PIN_COMMENT','MUTE_CHAT','MANAGE_MODERATORS'];
  const row=await prisma.liveModerator.upsert({where:{roomId_userId:{roomId:room.id,userId}},create:{roomId:room.id,userId,role,permissions},update:{role,permissions}});
  io.to(`live:${room.roomName}`).emit('live:moderator',{action:'added',userId,role}); res.status(201).json({...row,user:safe(u)});
});
app.delete('/api/live/:roomId/moderators/:userId',auth,async(req,res)=>{const room=await prisma.liveRoom.findUnique({where:{id:req.params.roomId}});if(!room||room.hostId!==req.user.id)return res.status(403).json({error:'HOST_ONLY'});await prisma.liveModerator.deleteMany({where:{roomId:room.id,userId:req.params.userId}});io.to(`live:${room.roomName}`).emit('live:moderator',{action:'removed',userId:req.params.userId});res.json({ok:true});});
app.get('/api/live/:roomId/moderators',auth,async(req,res)=>{const rows=await prisma.liveModerator.findMany({where:{roomId:req.params.roomId},include:{user:true},orderBy:{createdAt:'asc'}});res.json(rows.map(x=>({...x,user:safe(x.user)})));});
app.post('/api/live/:roomId/comments/:commentId/pin',auth,async(req,res)=>{const c=await prisma.liveComment.findUnique({where:{id:req.params.commentId},include:{room:true}});if(!c||c.roomId!==req.params.roomId)return res.status(404).json({error:'COMMENT_NOT_FOUND'});const can=await liveCan(req,c.roomId,'PIN_COMMENT');if(!can.ok)return res.status(403).json({error:'MODERATOR_ONLY'});await prisma.liveComment.updateMany({where:{roomId:c.roomId,pinned:true},data:{pinned:false}});const out=await prisma.liveComment.update({where:{id:c.id},data:{pinned:true},include:{author:true}});io.to(`live:${c.room.roomName}`).emit('live:comment:pin',{commentId:c.id,pinned:true});res.json({...out,author:safe(out.author)});});
app.delete('/api/live/:roomId/comments/:commentId',auth,async(req,res)=>{const c=await prisma.liveComment.findUnique({where:{id:req.params.commentId},include:{room:true}});if(!c||c.roomId!==req.params.roomId)return res.status(404).json({error:'COMMENT_NOT_FOUND'});const can=await liveCan(req,c.roomId,'DELETE_COMMENT');if(!can.ok&&c.authorId!==req.user.id)return res.status(403).json({error:'MODERATOR_ONLY'});await prisma.liveComment.update({where:{id:c.id},data:{deleted:true,body:'تم حذف التعليق'}});io.to(`live:${c.room.roomName}`).emit('live:comment:delete',{commentId:c.id});res.json({ok:true});});
app.get('/api/live/:roomId/followers',auth,async(req,res)=>{const room=await prisma.liveRoom.findUnique({where:{id:req.params.roomId}});if(!room||room.hostId!==req.user.id)return res.status(403).json({error:'HOST_ONLY'});const rows=await prisma.follow.findMany({where:{followingId:req.user.id},orderBy:{createdAt:'desc'},take:500,include:{follower:true}});const mods=await prisma.liveModerator.findMany({where:{roomId:room.id}});const ids=new Set(mods.map(x=>x.userId));res.json(rows.map(x=>({...safe(x.follower),isModerator:ids.has(x.followerId)})));});

// ---- Socket.IO realtime layer ----
io.on('connection',socket=>{
  socket.on('auth',async payload=>{
    try{
      const token=String(payload?.token||''); if(!token) return socket.disconnect(true);
      const u=jwt.verify(token,JWT_SECRET); const user=await prisma.user.findUnique({where:{id:u.id},select:{id:true,username:true,displayName:true,isBanned:true}});
      if(!user||user.isBanned)return socket.disconnect(true);
      socket.data.user=user; socket.join(`user:${user.id}`);
      socket.emit('auth:ok',{userId:user.id});
    }catch{socket.disconnect(true);}
  });
  const me=()=>socket.data.user;
  socket.on('message',async payload=>{try{const u=me();if(!u)return;const to=String(payload?.to||''),body=String(payload?.body||'').trim();if(!to||!body)return;const target=await prisma.user.findUnique({where:{id:to}});if(!target||target.id===u.id)return;const effect=String(payload?.effect||'').slice(0,32);const m=await prisma.message.create({data:{senderId:u.id,receiverId:target.id,body:body.slice(0,4000),deliveredAt:new Date()}});if(effect)await prisma.$executeRawUnsafe('UPDATE "Message" SET "effect"=$1 WHERE "id"=$2',effect,m.id).catch(()=>{});const out=effect?{...m,effect}:m;io.to(`user:${target.id}`).emit('message',out);socket.emit('message:sent',out);}catch(e){console.warn('[socket message]',e.message);}});
  socket.on('typing',payload=>{const u=me();if(!u)return;const to=String(payload?.to||'').trim();if(!to||to===u.id)return;socket.to(`user:${to}`).emit('typing',{from:u.id,fromId:u.id,username:u.username,displayName:u.displayName,typing:payload?.typing!==false});});
  socket.on('live:join',async payload=>{const u=me();if(!u)return;const room=String(payload?.room||'').trim();if(!room)return;const live=await prisma.liveRoom.findUnique({where:{roomName:room}});if(!live||!['LIVE','PAUSED'].includes(live.status))return;if(live.status==='PAUSED'&&live.hostId!==u.id)return;socket.join(`live:${room}`);socket.data.liveRoom=room;io.to(`live:${room}`).emit('live:user-joined',{userId:u.id,username:u.username,displayName:u.displayName});});
  socket.on('live:leave',payload=>{const room=String(payload?.room||socket.data.liveRoom||'').trim();if(room){socket.leave(`live:${room}`);io.to(`live:${room}`).emit('live:user-left',{userId:me()?.id||''});}});
  socket.on('live:tap',payload=>{const u=me();if(!u)return;const room=String(payload?.room||'').trim();if(!room)return;io.to(`live:${room}`).emit('live:tap',{userId:u.id,username:u.username,createdAt:new Date().toISOString()});
    // Persist the tap so totals survive leaving the room (best-effort).
    prisma.$executeRawUnsafe('INSERT INTO "LiveTapCount" ("roomName","userId","taps","updatedAt") VALUES ($1,$2,1,CURRENT_TIMESTAMP) ON CONFLICT ("roomName","userId") DO UPDATE SET "taps"="LiveTapCount"."taps"+1,"updatedAt"=CURRENT_TIMESTAMP',room,u.id).catch(()=>{});
    prisma.$executeRawUnsafe('UPDATE "LiveRoom" SET "tapCount"="tapCount"+1 WHERE "roomName"=$1',room).catch(()=>{});});
  socket.on('live:chat',async payload=>{try{const u=me();if(!u)return;const roomName=String(payload?.room||'').trim(),body=String(payload?.body||'').trim();if(!roomName||!body)return;const room=await prisma.liveRoom.findUnique({where:{roomName:roomName}});if(!room)return;const muted=await prisma.$queryRawUnsafe('SELECT 1 FROM "LiveMute" WHERE "roomName"=$1 AND "userId"=$2 LIMIT 1',roomName,u.id).catch(()=>[]);if(muted&&muted.length){socket.emit('live:muted-notice',{room:roomName});return;}const replyToId=String(payload?.replyToId||'').trim();let replyToName='';if(replyToId){const parent=await prisma.liveComment.findUnique({where:{id:replyToId},include:{author:true}});if(parent&&parent.roomId===room.id&&!parent.deleted)replyToName=parent.author.displayName||parent.author.username||'';}const c=await prisma.liveComment.create({data:{roomId:room.id,authorId:u.id,body:body.slice(0,1000),replyToId:replyToId||null,replyToName},include:{author:true}});io.to(`live:${roomName}`).emit('live:comment',{...c,author:safe(c.author)});}catch(e){console.warn('[live comment]',e.message);}});
  socket.on('live:comment:pin',async payload=>{try{const u=me();if(!u)return;const roomName=String(payload?.room||'').trim(),commentId=String(payload?.commentId||'').trim();const room=await prisma.liveRoom.findUnique({where:{roomName:roomName}});if(!room)return;const staff=await liveStaff(room.id,u.id);const can=room.hostId===u.id||liveStaffCan(staff,'comments.pin');if(!can)return;await prisma.liveComment.updateMany({where:{roomId:room.id,pinned:true},data:{pinned:false}});await prisma.liveComment.update({where:{id:commentId},data:{pinned:true}});io.to(`live:${roomName}`).emit('live:comment:pin',{commentId,pinned:true});}catch{}});
  socket.on('live:comment:delete',async payload=>{try{const u=me();if(!u)return;const roomName=String(payload?.room||'').trim(),commentId=String(payload?.commentId||'').trim();const room=await prisma.liveRoom.findUnique({where:{roomName:roomName}});if(!room)return;const c=await prisma.liveComment.findUnique({where:{id:commentId}});if(!c)return;const staff=await liveStaff(room.id,u.id);const can=room.hostId===u.id||c.authorId===u.id||liveStaffCan(staff,'comments.delete');if(!can)return;await prisma.liveComment.update({where:{id:commentId},data:{deleted:true}});io.to(`live:${roomName}`).emit('live:comment:delete',{commentId});}catch{}});
  socket.on('live:gift',payload=>{const u=me();if(!u)return;const room=String(payload?.room||'').trim();io.to(`live:${room}`).emit('live:gift',{...payload,userId:u.id,username:u.username});});
  socket.on('live:mute',async payload=>{try{const u=me();if(!u)return;const roomName=String(payload?.room||'').trim(),target=String(payload?.userId||'').trim();if(!roomName||!target)return;const room=await prisma.liveRoom.findUnique({where:{roomName}});if(!room)return;const staff=await liveStaff(room.id,u.id);if(room.hostId!==u.id&&!liveStaffCan(staff,'live.mute'))return;const unmute=payload?.value===false;if(unmute){await prisma.$executeRawUnsafe('DELETE FROM "LiveMute" WHERE "roomName"=$1 AND "userId"=$2',roomName,target);}else{await prisma.$executeRawUnsafe('INSERT INTO "LiveMute" ("roomName","userId","reason","actorId") VALUES ($1,$2,$3,$4) ON CONFLICT ("roomName","userId") DO NOTHING',roomName,target,String(payload?.reason||'').slice(0,200),u.id);}io.to(`live:${roomName}`).emit('live:muted',{userId:target,value:!unmute});}catch{}});
  socket.on('live:remove',async payload=>{try{const u=me();if(!u)return;const roomName=String(payload?.room||'').trim(),target=String(payload?.userId||'').trim();if(!roomName||!target)return;const room=await prisma.liveRoom.findUnique({where:{roomName}});if(!room)return;const staff=await liveStaff(room.id,u.id);if(room.hostId!==u.id&&!liveStaffCan(staff,'live.remove'))return;io.to(`live:${roomName}`).emit('live:removed',{userId:target});}catch{}});
  socket.on('call:invite',payload=>{const u=me();if(!u)return;const to=String(payload?.to||'');if(to)io.to(`user:${to}`).emit('call:invite',{...payload,from:u.id,fromName:u.displayName||u.username});});
  socket.on('call:accept',payload=>{const u=me();const to=String(payload?.to||'');if(u&&to)io.to(`user:${to}`).emit('call:accept',{...payload,from:u.id});});
  socket.on('call:reject',payload=>{const u=me();const to=String(payload?.to||'');if(u&&to)io.to(`user:${to}`).emit('call:reject',{...payload,from:u.id});});
  socket.on('call:reel',payload=>{const u=me();const to=String(payload?.to||'');const url=String(payload?.url||'').trim();if(u&&to&&url)io.to(`user:${to}`).emit('call:reel',{url,title:String(payload?.title||''),from:u.id,createdAt:new Date().toISOString()});});
  socket.on('disconnect',()=>{const u=me(),room=socket.data.liveRoom;if(u&&room)io.to(`live:${room}`).emit('live:user-left',{userId:u.id});});
});

async function ensureCatalog(){
  // Gift Engine: a deterministic catalog of 200+ unique gifts generated in
  // modules/gifts.js. Seeding is a raw upsert so the extra columns (rarity,
  // category, metadata) work even before a Prisma client regeneration.
  const catalog=buildGiftCatalog();
  for(const g of catalog){
    await prisma.$executeRawUnsafe(
      `INSERT INTO "Gift" ("id","slug","name","emoji","priceCoins","enabled","effectKey","effectMs","soundKey","rarity","category","metadata","createdAt")
       VALUES (gen_random_uuid()::text,$1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,CURRENT_TIMESTAMP)
       ON CONFLICT ("slug") DO UPDATE SET "name"=EXCLUDED."name","emoji"=EXCLUDED."emoji","priceCoins"=EXCLUDED."priceCoins","enabled"=EXCLUDED."enabled","effectKey"=EXCLUDED."effectKey","effectMs"=EXCLUDED."effectMs","soundKey"=EXCLUDED."soundKey","rarity"=EXCLUDED."rarity","category"=EXCLUDED."category","metadata"=EXCLUDED."metadata"`,
      g.slug,g.name,g.emoji,g.priceCoins,g.enabled,g.effectKey,g.effectMs,g.soundKey,g.rarity,g.category,JSON.stringify(g.metadata||{}),
    );
  }
  await prisma.commissionSetting.upsert({where:{id:'default'},create:{id:'default'},update:{}}).catch(async()=>{if(!(await prisma.commissionSetting.findFirst()))await prisma.commissionSetting.create({data:{}});});
}

const PORT=Number(process.env.PORT||10000);
(async()=>{
  try{
    await ensureSchemaCompatibility();
    await ensureDeviceBanTable();
    await ensureCatalog();
    await ensureSuperAdmin();
    await ensureCreatorLevels();
    await ensureAdminLogin();
    http.listen(PORT,'0.0.0.0',()=>console.log(`[SocialNova] API listening on ${PORT}`));
  }catch(e){
    console.error('[SocialNova] startup schema/device setup failed:',e);
    process.exit(1);
  }
})();
