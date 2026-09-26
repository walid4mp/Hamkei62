import 'dotenv/config';
import express from 'express'; import cors from 'cors'; import morgan from 'morgan'; import bcrypt from 'bcryptjs'; import jwt from 'jsonwebtoken'; import {PrismaClient} from '@prisma/client'; import {createServer} from 'http'; import {Server} from 'socket.io'; import {z} from 'zod'; import crypto from 'crypto';
import multer from 'multer';
import path from 'path';
import {fileURLToPath} from 'url';
import fs from 'fs';
import {promisify} from 'util';
import {execFile} from 'child_process';
import https from 'https';
const __filename=fileURLToPath(import.meta.url);
const __dirname=path.dirname(__filename);
const execFileAsync=promisify(execFile);
const prisma=new PrismaClient(); const app=express(); const http=createServer(app);

app.use(cors({origin:process.env.CORS_ORIGIN||'*'})); app.use(express.json({limit:'5mb'})); app.use(morgan('tiny'));
const io=new Server(http,{cors:{origin:'*'}}); const JWT_SECRET=process.env.JWT_SECRET||'change-me';
const safe=u=>{if(!u)return null; const {passwordHash,...x}=u; return x}; const sign=u=>jwt.sign({id:u.id,username:u.username,email:u.email,role:u.role||'USER'},JWT_SECRET,{expiresIn:'30d'});

async function notifyMentions(body, text){
  const names=[...String(body||'').matchAll(/@([A-Za-z0-9_.-]{2,40})/g)].map(m=>m[1].toLowerCase());
  if(!names.length)return;
  const users=await prisma.user.findMany({where:{username:{in:names},isBanned:false},select:{id:true,username:true}});
  for(const u of users){await prisma.notification.create({data:{userId:u.id,type:'MENTION',text:text||`تمت الإشارة إليك @${u.username}`}});}
}
function auth(req,res,next){try{const h=req.headers.authorization||''; if(!h.startsWith('Bearer ')) throw 0; req.user=jwt.verify(h.slice(7),JWT_SECRET); next()}catch{res.status(401).json({error:'UNAUTHORIZED'})}}

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
});function admin(req,res,next){const list=(process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);if(req.user&&req.user.role==='DEVELOPER')return next();if(!list.includes(String(req.user&&req.user.email).toLowerCase()))return res.status(403).json({error:'ADMIN_ONLY'});next()}
app.get('/',(req,res)=>res.sendFile(path.join(__dirname,'admin-panel.index.html')));
app.get('/api/health',(req,res)=>res.json({ok:true,service:'SocialNova API',version:'3.0.0',time:new Date().toISOString()}));
app.post('/api/auth/register',async(req,res)=>{try{const d=z.object({username:z.string().min(3).max(30).regex(/^[a-zA-Z0-9_.]+$/),email:z.string().email(),password:z.string().min(6),displayName:z.string().min(2).max(60)}).parse(req.body);const exists=await prisma.user.findFirst({where:{OR:[{email:d.email},{username:d.username}]}});if(exists)return res.status(409).json({error:'EMAIL_OR_USERNAME_EXISTS'});const{password:pw,...rest}=d;const u=await prisma.user.create({data:{...rest,passwordHash:await bcrypt.hash(pw,12)}});res.status(201).json({user:safe(u),token:sign(u)})}catch(e){res.status(400).json({error:e.message})}});
app.post('/api/auth/login',async(req,res)=>{const d=req.body||{};const u=await prisma.user.findFirst({where:{OR:[{email:d.login},{username:d.login}]}});if(!u||u.isBanned||!(await bcrypt.compare(d.password||'',u.passwordHash)))return res.status(401).json({error:'INVALID_CREDENTIALS'});const adminEmails=(process.env.ADMIN_EMAILS||'').split(',').map(x=>x.trim().toLowerCase()).filter(Boolean);const isAdmin=u.role==='DEVELOPER'||adminEmails.includes(String(u.email).toLowerCase());res.json({user:safe(u),isAdmin,token:sign(u)})});
app.get('/api/me',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.user.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}})]);res.json({user:{...safe(u),followers,following,posts}})});
app.patch('/api/me',auth,async(req,res)=>{try{const d=z.object({displayName:z.string().min(2).max(60).optional(),bio:z.string().max(500).optional(),website:z.string().max(500).optional(),location:z.string().max(200).optional(),gender:z.string().max(20).optional(),birthDate:z.string().datetime().nullable().optional(),avatarUrl:z.string().max(2000000).optional(),coverUrl:z.string().max(2000000).optional(),digitalCardTheme:z.string().max(30).optional(),digitalCardShape:z.string().max(30).optional(),digitalCardVisibility:z.enum(['PUBLIC','FRIENDS','PRIVATE']).optional(),digitalCardShowFollowers:z.boolean().optional(),digitalCardShowPosts:z.boolean().optional(),digitalCardShowStories:z.boolean().optional(),digitalCardShowActivity:z.boolean().optional(),digitalCardShowGender:z.boolean().optional(),digitalCardShowBirthDate:z.boolean().optional(),digitalCardGroupId:z.string().max(100).nullable().optional()}).parse(req.body);const data={...d};if(data.birthDate!==undefined)data.birthDate=data.birthDate?new Date(data.birthDate):null;if(data.digitalCardGroupId){const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:data.digitalCardGroupId,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'})}res.json({user:safe(await prisma.user.update({where:{id:req.user.id},data}))})}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/feed',auth,async(req,res)=>{const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});const ids=fl.map(f=>f.followingId);const visibleReposters=[req.user.id,...ids];const posts=await prisma.post.findMany({where:{OR:[{visibility:'PUBLIC',author:{isBanned:false}},{authorId:req.user.id},{visibility:'FOLLOWERS',authorId:{in:ids}},{reposts:{some:{userId:{in:visibleReposters}}}}],AND:[{OR:[{authorId:req.user.id},{author:{isPrivate:false}},{authorId:{in:ids}},{reposts:{some:{userId:{in:visibleReposters}}}},{postViews:{none:{userId:req.user.id}}}]}]},orderBy:{createdAt:'desc'},take:50,include:{author:true,likes:true,bookmarks:true,reposts:{include:{user:true}},shares:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:3}}});res.json(posts.map(p=>({...p,author:safe(p.author),likedByMe:p.likes.some(x=>x.userId===req.user.id),bookmarkedByMe:p.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:p.reposts.some(x=>x.userId===req.user.id),reposters:p.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length,shareCount:p.shares.length,comments:p.comments.map(c=>({...c,author:safe(c.author)}))}))) });
app.post('/api/posts',auth,async(req,res)=>{try{const d=z.object({caption:z.string().max(5000).default(''),mediaUrl:z.string().max(5000).default(''),type:z.enum(['TEXT','IMAGE','VIDEO','MUSIC']).default('TEXT'),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),visibility:z.enum(['PUBLIC','FOLLOWERS','PRIVATE']).default('PUBLIC')}).parse(req.body);res.status(201).json(await prisma.post.create({data:{...d,authorId:req.user.id},include:{author:true}}))}catch(e){res.status(400).json({error:e.message})}});
app.patch('/api/posts/:id',auth,async(req,res)=>{try{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});if(p.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),mediaUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.post.update({where:{id:p.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
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
  const rows=await prisma.reel.findMany({where:{AND:[{OR:[{authorId:req.user.id},{author:{isPrivate:false,isBanned:false}}]},{OR:[{authorId:req.user.id},{viewsLog:{none:{userId:req.user.id}}}]},{feedbacks:{none:{userId:req.user.id,kind:'NOT_INTERESTED'}}}]},orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=new Set(followed.map(f=>f.followingId));
  res.json(rows.map(r=>({...r,author:{...safe(r.author),followedByMe:ids.has(r.authorId)},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/following',auth,async(req,res)=>{
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=followed.map(f=>f.followingId);
  const rows=await prisma.reel.findMany({where:{AND:[{authorId:{in:ids}},{viewsLog:{none:{userId:req.user.id}}},{feedbacks:{none:{userId:req.user.id,kind:'NOT_INTERESTED'}}}]},orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  res.json(rows.map(r=>({...r,author:{...safe(r.author),followedByMe:true},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/reposted',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{reposts:{some:{userId:req.user.id}}},orderBy:[{featured:'desc'},{featuredPriority:'desc'},{createdAt:'desc'}],take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}},bookmarks:true}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:true,savedByMe:r.bookmarks.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,bookmarkCount:r.bookmarks.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.post('/api/reels',auth,async(req,res)=>{const d=z.object({videoUrl:z.string().url().or(z.string().min(1)),caption:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default('')}).parse(req.body);const r=await prisma.reel.create({data:{...d,authorId:req.user.id},include:{author:true}});res.status(201).json({...r,author:safe(r.author)})});
app.patch('/api/reels/:id',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});if(r.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.reel.update({where:{id:r.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
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
app.post('/api/reels/:id/add-to-story',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const s=await prisma.story.create({data:{authorId:req.user.id,mediaUrl:r.videoUrl,type:'VIDEO',caption:r.caption,rotationDegrees:r.rotationDegrees,overlayText:r.overlayText,overlayEmoji:r.overlayEmoji,overlayImageUrl:r.overlayImageUrl,musicUrl:r.musicUrl,musicTitle:r.musicTitle,expiresAt:new Date(Date.now()+24*3600000)},include:{author:true}});res.status(201).json({...s,author:safe(s.author)});}catch(e){res.status(400).json({error:'ADD_TO_STORY_FAILED'})}});
app.post('/api/reels/:id/view',auth,async(req,res)=>{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelView.findUnique({where:{reelId_userId:{reelId:r.id,userId:req.user.id}}});if(!old){await prisma.reelView.create({data:{reelId:r.id,userId:req.user.id}});const out=await prisma.reel.update({where:{id:r.id},data:{views:{increment:1}}});return res.json({views:out.views,newView:true});}res.json({views:r.views,newView:false});});
app.get('/api/activity',auth,async(req,res)=>{const [views,comments,postComments,posts,likes,reelLikes]=await Promise.all([prisma.reelView.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{reel:{include:{author:true}}}}),prisma.reelComment.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{reel:{include:{author:true}}}}),prisma.comment.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{post:{include:{author:true}}}}),prisma.post.findMany({where:{authorId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{author:true}}),prisma.like.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{post:true}}),prisma.reelLike.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50,include:{reel:true}})]);res.json({views:views.map(v=>({...v,reel:{...v.reel,author:safe(v.reel.author)}})),comments,postComments,posts:posts.map(p=>({...p,author:safe(p.author)})),likedPosts:likes.map(x=>({...x,post:{...x.post,author:safe(x.post.author)}})),likedReels:reelLikes.map(x=>({...x,reel:{...x.reel}}))});});
app.get('/api/stories',auth,async(req,res)=>{
  const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const visible=[req.user.id,...fl.map(f=>f.followingId)];
  const rows=await prisma.story.findMany({where:{authorId:{in:visible},expiresAt:{gt:new Date()},NOT:{hiddenUserIds:{contains:req.user.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,reactions:true,replies:{include:{author:true},orderBy:{createdAt:'asc'},take:100}}});
  res.json(rows.map(s=>({...s,author:safe(s.author),likedByMe:s.reactions.some(x=>x.userId===req.user.id),reactionCount:s.reactions.length,replies:s.replies.map(r=>({...r,author:safe(r.author)}))})));
});
app.post('/api/stories',auth,async(req,res)=>{const d=z.object({mediaUrl:z.string().min(1),type:z.enum(['IMAGE','VIDEO']).default('IMAGE'),caption:z.string().max(500).default(''),durationHours:z.number().min(1).max(48).default(24),audienceMode:z.enum(['EVERYONE','CLOSE_FRIENDS','HIDDEN']).default('EVERYONE'),hiddenUserIds:z.array(z.string()).max(200).default([]),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default('')}).parse(req.body);const author=await prisma.user.findUnique({where:{id:req.user.id},select:{isVerified:true,verificationTier:true,verificationExpiresAt:true}});if(!author)return res.status(401).json({error:'UNAUTHORIZED'});const verified=author.isVerified&&author.verificationTier!=='NONE'&&(!author.verificationExpiresAt||author.verificationExpiresAt>new Date());const duration=[6,12,24,48].includes(d.durationHours)?d.durationHours:24;if(duration!==24&&!verified)return res.status(403).json({error:'VERIFIED_ONLY_DURATION'});const s=await prisma.story.create({data:{mediaUrl:d.mediaUrl,type:d.type,caption:d.caption,audienceMode:d.audienceMode,hiddenUserIds:d.hiddenUserIds.join(','),rotationDegrees:d.rotationDegrees,overlayText:d.overlayText,overlayEmoji:d.overlayEmoji,overlayImageUrl:d.overlayImageUrl,musicUrl:d.musicUrl,musicTitle:d.musicTitle,authorId:req.user.id,expiresAt:new Date(Date.now()+duration*3600000)},include:{author:true}});res.status(201).json({...s,author:safe(s.author)})});
app.post('/api/stories/:id/react',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.storyReaction.findUnique({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});if(old)await prisma.storyReaction.delete({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});else{await prisma.storyReaction.create({data:{storyId:story.id,userId:req.user.id,emoji:'❤️'}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'LIKE',text:'أعجب بقصتك ❤️'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:'[story_reaction]❤️',storyId:story.id}})}}res.json({liked:!old})}catch(e){res.status(400).json({error:'STORY_REACTION_FAILED'})}});
app.post('/api/stories/:id/replies',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_REPLY'});const r=await prisma.storyReply.create({data:{storyId:story.id,authorId:req.user.id,body:body.slice(0,1000)},include:{author:true}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'COMMENT',text:'ردّ على قصتك'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:`[story_reply]${body.slice(0,1000)}`,storyId:story.id}})}res.status(201).json({...r,author:safe(r.author)})}catch(e){res.status(400).json({error:'STORY_REPLY_FAILED'})}});
app.get('/api/stories/:id/replies',auth,async(req,res)=>{const rows=await prisma.storyReply.findMany({where:{storyId:req.params.id},orderBy:{createdAt:'asc'},take:100,include:{author:true}});res.json(rows.map(r=>({...r,author:safe(r.author)})))});
app.patch('/api/stories/:id',auth,async(req,res)=>{try{const s=await prisma.story.findUnique({where:{id:req.params.id}});if(!s)return res.status(404).json({error:'NOT_FOUND'});if(s.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(500).optional(),durationHours:z.number().min(1).max(48).optional(),audienceMode:z.enum(['EVERYONE','CLOSE_FRIENDS','HIDDEN']).optional(),hiddenUserIds:z.array(z.string()).max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional()}).parse(req.body);const author=await prisma.user.findUnique({where:{id:req.user.id},select:{isVerified:true,verificationTier:true,verificationExpiresAt:true}});const verified=!!author?.isVerified&&author.verificationTier!=='NONE'&&(!author.verificationExpiresAt||author.verificationExpiresAt>new Date());if(d.durationHours!==undefined){const h=[6,12,24,48].includes(d.durationHours)?d.durationHours:24;if(h!==24&&!verified)return res.status(403).json({error:'VERIFIED_ONLY_DURATION'});d.durationHours=h;}const data={...d};if(d.hiddenUserIds)data.hiddenUserIds=d.hiddenUserIds.join(',');if(d.durationHours)data.expiresAt=new Date(s.createdAt.getTime()+d.durationHours*3600000);delete data.durationHours;res.json(await prisma.story.update({where:{id:s.id},data,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.delete('/api/stories/:id',auth,async(req,res)=>{const s=await prisma.story.findUnique({where:{id:req.params.id}});if(!s)return res.status(404).json({error:'NOT_FOUND'});if(s.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.story.delete({where:{id:s.id}});res.json({ok:true})});
app.get('/api/users/search',auth,async(req,res)=>{const q=String(req.query.q||'').trim();if(q.length<2)return res.json([]);const users=await prisma.user.findMany({where:{isBanned:false,hideFromSearch:false,OR:[{username:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}}]},take:20});res.json(users.map(safe))});
app.post('/api/users/:id/follow',auth,async(req,res)=>{if(req.params.id===req.user.id)return res.status(400).json({error:'SELF'});const target=await prisma.user.findUnique({where:{id:req.params.id}});if(!target)return res.status(404).json({error:'NOT_FOUND'});const key={followerId:req.user.id,followingId:target.id};const old=await prisma.follow.findUnique({where:{followerId_followingId:key}});if(old){await prisma.follow.delete({where:{followerId_followingId:key}});await prisma.followRequest.deleteMany({where:{senderId:req.user.id,targetId:target.id,status:'PENDING'}});return res.json({following:false,requested:false});}if(target.isPrivate){const reqq=await prisma.followRequest.upsert({where:{senderId_targetId:{senderId:req.user.id,targetId:target.id}},update:{status:'PENDING'},create:{senderId:req.user.id,targetId:target.id}});await prisma.notification.create({data:{userId:target.id,type:'FOLLOW',text:'لديك طلب متابعة جديد'}}).catch(()=>{});return res.json({following:false,requested:reqq.status==='PENDING'});}await prisma.follow.create({data:key});await prisma.notification.create({data:{userId:target.id,type:'FOLLOW',text:'بدأ شخص بمتابعتك'}});res.json({following:true,requested:false})});
app.get('/api/follow-requests',auth,async(req,res)=>{const rows=await prisma.followRequest.findMany({where:{targetId:req.user.id,status:'PENDING'},orderBy:{createdAt:'desc'},include:{sender:true}});res.json(rows.map(x=>({...x,sender:safe(x.sender)})));});
app.post('/api/follow-requests/:id/accept',auth,async(req,res)=>{const q=await prisma.followRequest.findUnique({where:{id:req.params.id}});if(!q||q.targetId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});await prisma.$transaction([prisma.follow.create({data:{followerId:q.senderId,followingId:q.targetId}}),prisma.followRequest.update({where:{id:q.id},data:{status:'ACCEPTED'}})]);res.json({ok:true});});
app.post('/api/follow-requests/:id/reject',auth,async(req,res)=>{const q=await prisma.followRequest.findUnique({where:{id:req.params.id}});if(!q||q.targetId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});await prisma.followRequest.update({where:{id:q.id},data:{status:'REJECTED'}});res.json({ok:true});});
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
app.post('/api/messages/:userId',auth,async(req,res)=>{const target=await prisma.user.findUnique({where:{id:req.params.userId}});if(!target)return res.status(404).json({error:'USER_NOT_FOUND'});if(target.id===req.user.id)return res.status(400).json({error:'SELF_MESSAGE'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_MESSAGE'});const secret=Boolean(req.body.secret);const selfDestruct=Boolean(req.body.selfDestruct);const ttl=Math.max(1,Math.min(1440,Number(req.body.ttlMinutes||60)));const viewLimit=Math.max(0,Math.min(2,Number(req.body.viewLimit||0)));const online=io.sockets.adapter.rooms.has(`user:${target.id}`);const m=await prisma.message.create({data:{senderId:req.user.id,receiverId:target.id,body:body.slice(0,4000),secret,selfDestruct,viewLimit,expiresAt:secret?new Date(Date.now()+ttl*60000):null,deliveredAt:online?new Date():null}});io.to(`user:${target.id}`).emit('message',m);if(online){await prisma.message.update({where:{id:m.id},data:{deliveredAt:new Date()}}).catch(()=>{});}else{await sendFcmToUser(target.id,{type:'message',messageId:m.id,fromId:req.user.id,body:m.body},{title:'SocialNova',body:body.startsWith('[')?'لديك رسالة جديدة':body.slice(0,120)});}res.status(201).json(m)});
