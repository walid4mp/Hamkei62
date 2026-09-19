import 'dotenv/config';
import express from 'express'; import cors from 'cors'; import morgan from 'morgan'; import bcrypt from 'bcryptjs'; import jwt from 'jsonwebtoken'; import {PrismaClient} from '@prisma/client'; import {createServer} from 'http'; import {Server} from 'socket.io'; import {z} from 'zod'; import crypto from 'crypto';
import multer from 'multer';
import path from 'path';
import fs from 'fs';
import {promisify} from 'util';
import {execFile} from 'child_process';
import https from 'https';
const execFileAsync=promisify(execFile);
const prisma=new PrismaClient(); const app=express(); const http=createServer(app);

app.use(cors({origin:process.env.CORS_ORIGIN||'*'})); app.use(express.json({limit:'5mb'})); app.use(morgan('tiny'));
const io=new Server(http,{cors:{origin:'*'}}); const JWT_SECRET=process.env.JWT_SECRET||'change-me';
const safe=u=>{if(!u)return null; const {passwordHash,...x}=u; return x}; const sign=u=>jwt.sign({id:u.id,username:u.username,email:u.email,role:u.role||'USER'},JWT_SECRET,{expiresIn:'30d'});
function auth(req,res,next){try{const h=req.headers.authorization||''; if(!h.startsWith('Bearer ')) throw 0; req.user=jwt.verify(h.slice(7),JWT_SECRET); next()}catch{res.status(401).json({error:'UNAUTHORIZED'})}}
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
app.get('/',(req,res)=>res.json({service:'SocialNova API',status:'ok',version:'3.0.0',health:'/api/health'}));
app.get('/api/health',(req,res)=>res.json({ok:true,service:'SocialNova API',version:'3.0.0',time:new Date().toISOString()}));
app.post('/api/auth/register',async(req,res)=>{try{const d=z.object({username:z.string().min(3).max(30).regex(/^[a-zA-Z0-9_.]+$/),email:z.string().email(),password:z.string().min(6),displayName:z.string().min(2).max(60)}).parse(req.body);const exists=await prisma.user.findFirst({where:{OR:[{email:d.email},{username:d.username}]}});if(exists)return res.status(409).json({error:'EMAIL_OR_USERNAME_EXISTS'});const{password:pw,...rest}=d;const u=await prisma.user.create({data:{...rest,passwordHash:await bcrypt.hash(pw,12)}});res.status(201).json({user:safe(u),token:sign(u)})}catch(e){res.status(400).json({error:e.message})}});
app.post('/api/auth/login',async(req,res)=>{const d=req.body||{};const u=await prisma.user.findFirst({where:{OR:[{email:d.login},{username:d.login}]}});if(!u||u.isBanned||!(await bcrypt.compare(d.password||'',u.passwordHash)))return res.status(401).json({error:'INVALID_CREDENTIALS'});res.json({user:safe(u),token:sign(u)})});
app.get('/api/me',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.user.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}})]);res.json({user:{...safe(u),followers,following,posts}})});
app.patch('/api/me',auth,async(req,res)=>{try{const d=z.object({displayName:z.string().min(2).max(60).optional(),bio:z.string().max(500).optional(),website:z.string().max(500).optional(),location:z.string().max(200).optional(),gender:z.string().max(20).optional(),birthDate:z.string().datetime().nullable().optional(),avatarUrl:z.string().max(2000000).optional(),coverUrl:z.string().max(2000000).optional(),digitalCardTheme:z.string().max(30).optional(),digitalCardShape:z.string().max(30).optional(),digitalCardVisibility:z.enum(['PUBLIC','FRIENDS','PRIVATE']).optional(),digitalCardShowFollowers:z.boolean().optional(),digitalCardShowPosts:z.boolean().optional(),digitalCardShowStories:z.boolean().optional(),digitalCardShowActivity:z.boolean().optional(),digitalCardShowGender:z.boolean().optional(),digitalCardShowBirthDate:z.boolean().optional(),digitalCardGroupId:z.string().max(100).nullable().optional()}).parse(req.body);const data={...d};if(data.birthDate!==undefined)data.birthDate=data.birthDate?new Date(data.birthDate):null;if(data.digitalCardGroupId){const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:data.digitalCardGroupId,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'})}res.json({user:safe(await prisma.user.update({where:{id:req.user.id},data}))})}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/feed',auth,async(req,res)=>{const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});const ids=fl.map(f=>f.followingId);const visibleReposters=[req.user.id,...ids];const posts=await prisma.post.findMany({where:{OR:[{visibility:'PUBLIC',author:{isBanned:false}},{authorId:req.user.id},{visibility:'FOLLOWERS',authorId:{in:ids}},{reposts:{some:{userId:{in:visibleReposters}}}}],AND:[{OR:[{authorId:req.user.id},{author:{isPrivate:false}},{authorId:{in:ids}},{reposts:{some:{userId:{in:visibleReposters}}}}]}]},orderBy:{createdAt:'desc'},take:50,include:{author:true,likes:true,bookmarks:true,reposts:{include:{user:true}},shares:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:3}}});res.json(posts.map(p=>({...p,author:safe(p.author),likedByMe:p.likes.some(x=>x.userId===req.user.id),bookmarkedByMe:p.bookmarks.some(x=>x.userId===req.user.id),repostedByMe:p.reposts.some(x=>x.userId===req.user.id),reposters:p.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:p.likes.length,commentCount:p.comments.length,repostCount:p.reposts.length,shareCount:p.shares.length,comments:p.comments.map(c=>({...c,author:safe(c.author)}))}))) });
app.post('/api/posts',auth,async(req,res)=>{try{const d=z.object({caption:z.string().max(5000).default(''),mediaUrl:z.string().max(5000).default(''),type:z.enum(['TEXT','IMAGE','VIDEO','MUSIC']).default('TEXT'),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),visibility:z.enum(['PUBLIC','FOLLOWERS','PRIVATE']).default('PUBLIC')}).parse(req.body);res.status(201).json(await prisma.post.create({data:{...d,authorId:req.user.id},include:{author:true}}))}catch(e){res.status(400).json({error:e.message})}});
app.patch('/api/posts/:id',auth,async(req,res)=>{try{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});if(p.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),mediaUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.post.update({where:{id:p.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/posts/:id/like',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const old=await prisma.like.findUnique({where:{postId_userId:key}});if(old)await prisma.like.delete({where:{postId_userId:key}});else{const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});await prisma.like.create({data:key});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'LIKE',text:'أعجب شخص بمنشورك'}})}res.json({liked:!old})});
app.patch('/api/posts/comments/:id',auth,async(req,res)=>{const c=await prisma.comment.findUnique({where:{id:req.params.id}});if(!c||c.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});if(c.editCount>=1||Date.now()-c.createdAt.getTime()>5*60*1000)return res.status(400).json({error:'COMMENT_EDIT_WINDOW_EXPIRED'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const out=await prisma.comment.update({where:{id:c.id},data:{body:body.slice(0,1000),editedAt:new Date(),editCount:{increment:1}}});res.json(out)});
app.delete('/api/posts/comments/:id',auth,async(req,res)=>{const c=await prisma.comment.findUnique({where:{id:req.params.id},include:{post:true}});if(!c)return res.status(404).json({error:'NOT_FOUND'});if(c.authorId!==req.user.id&&c.post.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.comment.delete({where:{id:c.id}});res.json({ok:true})});
app.post('/api/posts/:id/comments',auth,async(req,res)=>{const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const c=await prisma.comment.create({data:{postId:p.id,authorId:req.user.id,body},include:{author:true}});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'COMMENT',text:'تم التعليق على منشورك'}});res.status(201).json({...c,author:safe(c.author)})});
app.post('/api/posts/:id/bookmark',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.bookmark.findUnique({where:{postId_userId:key}});if(old)await prisma.bookmark.delete({where:{postId_userId:key}});else await prisma.bookmark.create({data:key});res.json({bookmarked:!old})});
app.post('/api/posts/:id/repost',auth,async(req,res)=>{const key={postId:req.params.id,userId:req.user.id};const p=await prisma.post.findUnique({where:{id:key.postId}});if(!p)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.repost.findUnique({where:{postId_userId:key}});if(old)await prisma.repost.delete({where:{postId_userId:key}});else{await prisma.repost.create({data:key});if(p.authorId!==req.user.id)await prisma.notification.create({data:{userId:p.authorId,type:'LIKE',text:'تمت إعادة نشر منشورك'}})}res.json({reposted:!old,repostCount:await prisma.repost.count({where:{postId:p.id}})});});
app.post('/api/posts/:id/share',auth,async(req,res)=>{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});await prisma.postShare.create({data:{postId:p.id,userId:req.user.id}});res.json({shareCount:await prisma.postShare.count({where:{postId:p.id}})})});
app.get('/api/music',auth,async(req,res)=>{try{const q=String(req.query.search||'').trim();const category=String(req.query.category||'').trim();const where={licensed:true,...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{artist:{contains:q,mode:'insensitive'}},{album:{contains:q,mode:'insensitive'}}]}:{}),...(category?{category:{equals:category,mode:'insensitive'}}:{})};const rows=await prisma.musicTrack.findMany({where,orderBy:{createdAt:'desc'},take:100});res.json(rows)}catch(e){res.status(500).json({error:'SERVER_ERROR'})}});
app.post('/api/music',auth,admin,async(req,res)=>{try{const d=z.object({title:z.string().min(1).max(200),artist:z.string().min(1).max(120),album:z.string().max(200).default(''),coverUrl:z.string().max(5000).default(''),audioUrl:z.string().url(),category:z.string().max(80).default(''),durationSec:z.number().int().min(0).max(3600).default(0),licensed:z.boolean().default(false)}).parse(req.body);const row=await prisma.musicTrack.create({data:d});res.status(201).json(row)}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/reels',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{OR:[{authorId:req.user.id},{author:{isPrivate:false,isBanned:false}}]},orderBy:{createdAt:'desc'},take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}}}});
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=new Set(followed.map(f=>f.followingId));
  res.json(rows.map(r=>({...r,author:{...safe(r.author),followedByMe:ids.has(r.authorId)},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/following',auth,async(req,res)=>{
  const followed=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const ids=followed.map(f=>f.followingId);
  const rows=await prisma.reel.findMany({where:{authorId:{in:ids}},orderBy:{createdAt:'desc'},take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}}}});
  res.json(rows.map(r=>({...r,author:{...safe(r.author),followedByMe:true},likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.get('/api/reels/reposted',auth,async(req,res)=>{
  const rows=await prisma.reel.findMany({where:{reposts:{some:{userId:req.user.id}}},orderBy:{createdAt:'desc'},take:80,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:50},shares:true,reposts:{include:{user:true}}}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:true,reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,comments:r.comments.map(c=>({...c,author:safe(c.author)}))})));
});
app.post('/api/reels',auth,async(req,res)=>{const d=z.object({videoUrl:z.string().url().or(z.string().min(1)),caption:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default(''),title:z.string().max(200).default(''),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default('')}).parse(req.body);const r=await prisma.reel.create({data:{...d,authorId:req.user.id},include:{author:true}});res.status(201).json({...r,author:safe(r.author)})});
app.patch('/api/reels/:id',auth,async(req,res)=>{try{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});if(r.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional(),title:z.string().max(200).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional()}).parse(req.body);res.json(await prisma.reel.update({where:{id:r.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/reels/:id/like',auth,async(req,res)=>{const key={reelId:req.params.id,userId:req.user.id};const r=await prisma.reel.findUnique({where:{id:key.reelId}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelLike.findUnique({where:{reelId_userId:key}});if(old)await prisma.reelLike.delete({where:{reelId_userId:key}});else{await prisma.reelLike.create({data:key});if(r.authorId!==req.user.id)await prisma.notification.create({data:{userId:r.authorId,type:'LIKE',text:'أعجب شخص بالريلز الخاص بك'}})}res.json({liked:!old,likeCount:await prisma.reelLike.count({where:{reelId:r.id}})});});
app.get('/api/reels/:id/comments',auth,async(req,res)=>{const cs=await prisma.reelComment.findMany({where:{reelId:req.params.id},include:{author:true},orderBy:{createdAt:'desc'},take:100});res.json(cs.map(c=>({...c,author:safe(c.author)})));});
app.patch('/api/reels/comments/:id',auth,async(req,res)=>{const c=await prisma.reelComment.findUnique({where:{id:req.params.id}});if(!c||c.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});if(c.editCount>=1||Date.now()-c.createdAt.getTime()>5*60*1000)return res.status(400).json({error:'COMMENT_EDIT_WINDOW_EXPIRED'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});res.json(await prisma.reelComment.update({where:{id:c.id},data:{body:body.slice(0,1000),editedAt:new Date(),editCount:{increment:1}}}))});
app.delete('/api/reels/comments/:id',auth,async(req,res)=>{const c=await prisma.reelComment.findUnique({where:{id:req.params.id},include:{reel:true}});if(!c)return res.status(404).json({error:'NOT_FOUND'});if(c.authorId!==req.user.id&&c.reel.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.reelComment.delete({where:{id:c.id}});res.json({ok:true})});
app.post('/api/reels/:id/comments',auth,async(req,res)=>{const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const c=await prisma.reelComment.create({data:{reelId:r.id,authorId:req.user.id,body:body.slice(0,1000)},include:{author:true}});if(r.authorId!==req.user.id)await prisma.notification.create({data:{userId:r.authorId,type:'COMMENT',text:'تم التعليق على الريلز الخاص بك'}});res.status(201).json({...c,author:safe(c.author)});});
app.post('/api/reels/:id/share',auth,async(req,res)=>{const r=await prisma.reel.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});await prisma.reelShare.create({data:{reelId:r.id,userId:req.user.id}});res.json({shareCount:await prisma.reelShare.count({where:{reelId:r.id}})});});
app.post('/api/reels/:id/repost',auth,async(req,res)=>{const key={reelId:req.params.id,userId:req.user.id};const r=await prisma.reel.findUnique({where:{id:key.reelId}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.reelRepost.findUnique({where:{reelId_userId:key}});if(old)await prisma.reelRepost.delete({where:{reelId_userId:key}});else await prisma.reelRepost.create({data:key});res.json({reposted:!old,repostCount:await prisma.reelRepost.count({where:{reelId:r.id}})});});
app.post('/api/reels/:id/view',auth,async(req,res)=>{const r=await prisma.reel.update({where:{id:req.params.id},data:{views:{increment:1}}});res.json({views:r.views})});
app.get('/api/stories',auth,async(req,res)=>{
  const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});
  const visible=[req.user.id,...fl.map(f=>f.followingId)];
  const rows=await prisma.story.findMany({where:{authorId:{in:visible},expiresAt:{gt:new Date()}},orderBy:{createdAt:'desc'},take:100,include:{author:true,reactions:true,replies:{include:{author:true},orderBy:{createdAt:'asc'},take:100}}});
  res.json(rows.map(s=>({...s,author:safe(s.author),likedByMe:s.reactions.some(x=>x.userId===req.user.id),reactionCount:s.reactions.length,replies:s.replies.map(r=>({...r,author:safe(r.author)}))})));
});
app.post('/api/stories',auth,async(req,res)=>{const d=z.object({mediaUrl:z.string().min(1),type:z.enum(['IMAGE','VIDEO']).default('IMAGE'),caption:z.string().max(500).default(''),durationHours:z.number().min(1).max(48).default(24),rotationDegrees:z.number().int().min(0).max(359).default(0),overlayText:z.string().max(500).default(''),overlayEmoji:z.string().max(20).default(''),overlayImageUrl:z.string().max(5000).default(''),musicUrl:z.string().max(5000).default(''),musicTitle:z.string().max(200).default('')}).parse(req.body);const s=await prisma.story.create({data:{mediaUrl:d.mediaUrl,type:d.type,caption:d.caption,rotationDegrees:d.rotationDegrees,overlayText:d.overlayText,overlayEmoji:d.overlayEmoji,overlayImageUrl:d.overlayImageUrl,musicUrl:d.musicUrl,musicTitle:d.musicTitle,authorId:req.user.id,expiresAt:new Date(Date.now()+d.durationHours*3600000)},include:{author:true}});res.status(201).json({...s,author:safe(s.author)})});
app.post('/api/stories/:id/react',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const old=await prisma.storyReaction.findUnique({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});if(old)await prisma.storyReaction.delete({where:{storyId_userId:{storyId:story.id,userId:req.user.id}}});else{await prisma.storyReaction.create({data:{storyId:story.id,userId:req.user.id,emoji:'❤️'}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'LIKE',text:'أعجب بقصتك ❤️'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:'[story_reaction]❤️',storyId:story.id}})}}res.json({liked:!old})}catch(e){res.status(400).json({error:'STORY_REACTION_FAILED'})}});
app.post('/api/stories/:id/replies',auth,async(req,res)=>{try{const story=await prisma.story.findUnique({where:{id:req.params.id}});if(!story)return res.status(404).json({error:'NOT_FOUND'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_REPLY'});const r=await prisma.storyReply.create({data:{storyId:story.id,authorId:req.user.id,body:body.slice(0,1000)},include:{author:true}});if(story.authorId!==req.user.id){await prisma.notification.create({data:{userId:story.authorId,type:'COMMENT',text:'ردّ على قصتك'}});await prisma.message.create({data:{senderId:req.user.id,receiverId:story.authorId,body:`[story_reply]${body.slice(0,1000)}`,storyId:story.id}})}res.status(201).json({...r,author:safe(r.author)})}catch(e){res.status(400).json({error:'STORY_REPLY_FAILED'})}});
app.get('/api/stories/:id/replies',auth,async(req,res)=>{const rows=await prisma.storyReply.findMany({where:{storyId:req.params.id},orderBy:{createdAt:'asc'},take:100,include:{author:true}});res.json(rows.map(r=>({...r,author:safe(r.author)})))});
app.patch('/api/stories/:id',auth,async(req,res)=>{try{const s=await prisma.story.findUnique({where:{id:req.params.id}});if(!s)return res.status(404).json({error:'NOT_FOUND'});if(s.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const d=z.object({caption:z.string().max(500).optional(),rotationDegrees:z.number().int().min(0).max(359).optional(),overlayText:z.string().max(500).optional(),overlayEmoji:z.string().max(20).optional(),overlayImageUrl:z.string().max(5000).optional(),musicUrl:z.string().max(5000).optional(),musicTitle:z.string().max(200).optional()}).parse(req.body);res.json(await prisma.story.update({where:{id:s.id},data:d,include:{author:true}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/users/search',auth,async(req,res)=>{const q=String(req.query.q||'').trim();if(q.length<2)return res.json([]);const users=await prisma.user.findMany({where:{isBanned:false,hideFromSearch:false,OR:[{username:{contains:q,mode:'insensitive'}},{displayName:{contains:q,mode:'insensitive'}}]},take:20});res.json(users.map(safe))});
app.post('/api/users/:id/follow',auth,async(req,res)=>{if(req.params.id===req.user.id)return res.status(400).json({error:'SELF'});const target=await prisma.user.findUnique({where:{id:req.params.id}});if(!target)return res.status(404).json({error:'NOT_FOUND'});const key={followerId:req.user.id,followingId:target.id};const old=await prisma.follow.findUnique({where:{followerId_followingId:key}});if(old)await prisma.follow.delete({where:{followerId_followingId:key}});else{await prisma.follow.create({data:key});await prisma.notification.create({data:{userId:target.id,type:'FOLLOW',text:'بدأ شخص بمتابعتك'}})}res.json({following:!old})});
app.get('/api/groups',auth,async(req,res)=>res.json((await prisma.group.findMany({orderBy:{createdAt:'desc'},take:50,include:{owner:true,_count:{select:{members:true}}}})).map(g=>({...g,owner:safe(g.owner)}))));
app.post('/api/groups',auth,async(req,res)=>{const d=z.object({name:z.string().min(2).max(80),description:z.string().max(1000).default(''),avatarUrl:z.string().max(2000).default(''),coverUrl:z.string().max(2000).default(''),privacy:z.enum(['PUBLIC','PRIVATE']).default('PUBLIC'),rules:z.string().max(3000).default('')}).parse(req.body);const g=await prisma.group.create({data:{...d,ownerId:req.user.id,members:{create:{userId:req.user.id,role:'owner'}}},include:{owner:true,_count:{select:{members:true}}}});res.status(201).json({...g,owner:safe(g.owner)})});
app.patch('/api/groups/:id',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id}});if(!g)return res.status(404).json({error:'NOT_FOUND'});if(g.ownerId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});try{const d=z.object({name:z.string().min(2).max(80).optional(),description:z.string().max(1000).optional(),avatarUrl:z.string().max(2000).optional(),coverUrl:z.string().max(2000).optional(),privacy:z.enum(['PUBLIC','PRIVATE']).optional(),rules:z.string().max(3000).optional()}).parse(req.body);res.json(await prisma.group.update({where:{id:g.id},data:d,include:{owner:true,_count:{select:{members:true}}}}))}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/groups/:id',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id},include:{owner:true,_count:{select:{members:true}}}});if(!g)return res.status(404).json({error:'NOT_FOUND'});const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:g.id,userId:req.user.id}}});res.json({...g,owner:safe(g.owner),joined:!!member})});
app.get('/api/groups/:id/messages',auth,async(req,res)=>{const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:req.params.id,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'});const rows=await prisma.groupMessage.findMany({where:{groupId:req.params.id},orderBy:{createdAt:'asc'},take:200,include:{sender:true}});res.json(rows.map(x=>({...x,sender:safe(x.sender)})))});
app.post('/api/groups/:id/messages',auth,async(req,res)=>{const member=await prisma.groupMember.findUnique({where:{groupId_userId:{groupId:req.params.id,userId:req.user.id}}});if(!member)return res.status(403).json({error:'FORBIDDEN'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const m=await prisma.groupMessage.create({data:{groupId:req.params.id,senderId:req.user.id,body:body.slice(0,4000)},include:{sender:true}});res.status(201).json({...m,sender:safe(m.sender)})});
app.post('/api/groups/:id/join',auth,async(req,res)=>{const g=await prisma.group.findUnique({where:{id:req.params.id}});if(!g)return res.status(404).json({error:'NOT_FOUND'});const key={groupId:g.id,userId:req.user.id};const old=await prisma.groupMember.findUnique({where:{groupId_userId:key}});if(old){if(old.role==='owner')return res.status(400).json({error:'OWNER'});await prisma.groupMember.delete({where:{groupId_userId:key}})}else await prisma.groupMember.create({data:key});res.json({joined:!old})});
app.get('/api/notifications',auth,async(req,res)=>res.json(await prisma.notification.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50})));
app.post('/api/notifications/read',auth,async(req,res)=>{await prisma.notification.updateMany({where:{userId:req.user.id},data:{read:true}});res.json({ok:true})});
app.get('/api/messages/:userId',auth,async(req,res)=>{
  const now=new Date();
  await prisma.message.deleteMany({where:{expiresAt:{not:null,lt:now}}});
  const rows=await prisma.message.findMany({where:{AND:[{OR:[{senderId:req.user.id,receiverId:req.params.userId,deletedForSender:false},{senderId:req.params.userId,receiverId:req.user.id,deletedForReceiver:false}]},{OR:[{expiresAt:null},{expiresAt:{gt:now}}]}]},orderBy:{createdAt:'asc'},take:200});
  // Self-destruct messages are removed after the recipient receives this fetch.
  const selfDestructIds=rows.filter(m=>m.selfDestruct && m.receiverId===req.user.id).map(m=>m.id);
  res.json(rows);
  if(selfDestructIds.length) await prisma.message.deleteMany({where:{id:{in:selfDestructIds}}});
});
app.get('/api/conversations',auth,async(req,res)=>{const rows=await prisma.message.findMany({where:{OR:[{senderId:req.user.id},{receiverId:req.user.id}]},orderBy:{createdAt:'desc'},take:500});const ids=[...new Set(rows.map(m=>m.senderId===req.user.id?m.receiverId:m.senderId))];const users=await prisma.user.findMany({where:{id:{in:ids}}});res.json(users.map(safe))});
app.post('/api/messages/:userId',auth,async(req,res)=>{const target=await prisma.user.findUnique({where:{id:req.params.userId}});if(!target)return res.status(404).json({error:'USER_NOT_FOUND'});const body=String(req.body.body||'').trim();if(!body)return res.status(400).json({error:'EMPTY_COMMENT'});const secret=Boolean(req.body.secret);const selfDestruct=Boolean(req.body.selfDestruct);const ttl=Math.max(1,Math.min(1440,Number(req.body.ttlMinutes||60)));const viewLimit=Math.max(0,Math.min(2,Number(req.body.viewLimit||0)));const m=await prisma.message.create({data:{senderId:req.user.id,receiverId:target.id,body:body.slice(0,4000),secret,selfDestruct,viewLimit,expiresAt:secret?new Date(Date.now()+ttl*60000):null}});io.to(`user:${target.id}`).emit('message',m);res.status(201).json(m)});
app.post('/api/live',auth,async(req,res)=>{const d=z.object({title:z.string().min(2).max(120)}).parse(req.body);const roomName='sn_'+crypto.randomBytes(8).toString('hex');const room=await prisma.liveRoom.create({data:{title:d.title,roomName,hostId:req.user.id},include:{host:true}});res.status(201).json({...room,host:safe(room.host)})});
app.get('/api/live',auth,async(req,res)=>{
  const rows=await prisma.liveRoom.findMany({where:{status:'LIVE'},orderBy:{createdAt:'desc'},take:50,include:{host:true}});
  const now=Date.now();
  res.json(rows.map(r=>{
    const demo=String(r.host?.username||'').startsWith('nova')||String(r.host?.username||'').startsWith('walidpro');
    if(!demo) return {...r,host:safe(r.host)};
    const seed=(now%900000);
    const wave=Math.floor(Math.sin(now/17000 + r.id.length)*18000);
    const simulated=Math.max(1200,Math.min(380000,Math.floor(210000 + seed*0.18 + wave)));
    return {...r,viewerCount:simulated,demoViewers:true,host:safe(r.host)};
  }));
});
app.post('/api/live/token',auth,async(req,res)=>{try{const roomName=String(req.body.roomName||'');if(!roomName)return res.status(400).json({error:'VALIDATION_ERROR'});const key=process.env.LIVEKIT_API_KEY,secret=process.env.LIVEKIT_API_SECRET,url=process.env.LIVEKIT_URL;if(!key||!secret||!url)return res.status(503).json({error:'LIVEKIT_NOT_CONFIGURED'});const token=jwt.sign({sub:req.user.id,name:req.user.username,video:{roomJoin:true,room:roomName,canPublish:true,canSubscribe:true,canPublishData:true}},secret,{issuer:key,expiresIn:'2h'});res.json({token,url})}catch(e){res.status(500).json({error:'SERVER_ERROR'})}});
app.post('/api/live/:id/end',auth,async(req,res)=>{const r=await prisma.liveRoom.findUnique({where:{id:req.params.id}});if(!r||r.hostId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});res.json(await prisma.liveRoom.update({where:{id:r.id},data:{status:'ENDED',endedAt:new Date()}}))});
// ============ SocialNova NovaCoins economy: wallet, gifts, purchases, withdrawals ============
const NOVA_COIN_NAME = 'NovaCoin';
const NOVA_COIN_SYMBOL = 'NVC';
const CREATOR_SHARE = 0.70;
const WITHDRAWAL_FEE_RATE = 0.10;
const CASH_CENTS_PER_100_COINS = 100; // 100 withdrawable NVC = $1.00 before withdrawal fee.
const MIN_WITHDRAW_COINS = 1000;
const COIN_PACKAGES = [
  {productId:'novacoin_100', coins:100, amountCents:99, label:'100 NovaCoins'},
  {productId:'novacoin_550', coins:550, amountCents:499, label:'550 NovaCoins'},
  {productId:'novacoin_1200', coins:1200, amountCents:999, label:'1,200 NovaCoins'},
  {productId:'novacoin_6500', coins:6500, amountCents:4999, label:'6,500 NovaCoins'},
  {productId:'novacoin_14000', coins:14000, amountCents:9999, label:'14,000 NovaCoins'},
];
const DEFAULT_GIFTS = [
  {slug:'rose', name:'وردة', emoji:'🌹', priceCoins:10},
  {slug:'heart', name:'قلب', emoji:'❤️', priceCoins:25},
  {slug:'star', name:'نجمة', emoji:'⭐', priceCoins:100},
  {slug:'crown', name:'تاج', emoji:'👑', priceCoins:500},
  {slug:'rocket', name:'صاروخ', emoji:'🚀', priceCoins:1000},
  {slug:'galaxy', name:'مجرة', emoji:'🌌', priceCoins:5000},
  {slug:'coffee', name:'قهوة', emoji:'☕', priceCoins:40},
  {slug:'flower', name:'باقة زهور', emoji:'💐', priceCoins:150},
  {slug:'diamond', name:'ألماسة', emoji:'💎', priceCoins:750},
  {slug:'fire', name:'نار', emoji:'🔥', priceCoins:300},
  {slug:'trophy', name:'كأس', emoji:'🏆', priceCoins:1200},
  {slug:'car', name:'سيارة', emoji:'🚗', priceCoins:2500},
  {slug:'plane', name:'طائرة', emoji:'✈️', priceCoins:3500},
  {slug:'castle', name:'قلعة', emoji:'🏰', priceCoins:8000},
  {slug:'unicorn', name:'يونيكورن', emoji:'🦄', priceCoins:10000},
  {slug:'sun', name:'شمس', emoji:'☀️', priceCoins:600},
  {slug:'moon', name:'قمر', emoji:'🌙', priceCoins:900},
  {slug:'bear', name:'دب لطيف', emoji:'🧸', priceCoins:450},
  {slug:'balloon', name:'بالونات', emoji:'🎈', priceCoins:180},
  {slug:'medal', name:'ميدالية', emoji:'🏅', priceCoins:650},
  {slug:'music', name:'موسيقى', emoji:'🎵', priceCoins:220},
  {slug:'party', name:'حفلة', emoji:'🎉', priceCoins:1100},
  {slug:'fireworks', name:'ألعاب نارية', emoji:'🎆', priceCoins:4000},
  {slug:'king', name:'ملك', emoji:'🤴', priceCoins:15000},
  {slug:'queen', name:'ملكة', emoji:'👸', priceCoins:15000},
];
const WELCOME_BONUS_COINS = 1000000;
async function ensureWallet(userId, tx=prisma){
  let w=await tx.wallet.upsert({where:{userId},update:{},create:{userId}});
  if(!w.welcomeBonusGranted){
    w=await tx.wallet.update({where:{id:w.id},data:{coinBalance:{increment:WELCOME_BONUS_COINS},bonusCoins:{increment:WELCOME_BONUS_COINS},welcomeBonusGranted:true}});
    await walletLedger(tx,w,userId,'WELCOME_BONUS',WELCOME_BONUS_COINS,w.withdrawableCoins,'مكافأة ترحيبية مجانية: 1,000,000 NovaCoin',{withdrawable:false,bonus:true});
  }
  return w;
}
async function walletLedger(tx, wallet, userId, type, coins, withdrawableCoins, description, metadata={}){
  return tx.walletTransaction.create({data:{walletId:wallet.id,userId,type,coins,balanceAfter:wallet.coinBalance,withdrawableAfter:wallet.withdrawableCoins,reference:'NVT-'+crypto.randomBytes(8).toString('hex').toUpperCase(),description,metadata}});
}

async function ensureGiftCatalog(){
  for(const g of DEFAULT_GIFTS){
    await prisma.gift.upsert({where:{slug:g.slug},update:{name:g.name,emoji:g.emoji,priceCoins:g.priceCoins,enabled:true},create:g});
  }
}

app.get('/api/wallet',auth,async(req,res)=>{
  const w=await ensureWallet(req.user.id);
  const transactions=await prisma.walletTransaction.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:50});
  const withdrawals=await prisma.withdrawalRequest.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:20});
  res.json({currency:{name:NOVA_COIN_NAME,symbol:NOVA_COIN_SYMBOL,creatorShare:CREATOR_SHARE,withdrawalFeeRate:WITHDRAWAL_FEE_RATE,cashCentsPer100Coins:CASH_CENTS_PER_100_COINS,minWithdrawCoins:MIN_WITHDRAW_COINS,welcomeBonusCoins:WELCOME_BONUS_COINS,bonusWithdrawable:false},wallet:w,transactions,withdrawals,packages:COIN_PACKAGES});
});
app.get('/api/wallet/gifts',auth,async(req,res)=>{
  const gifts=await prisma.gift.findMany({where:{enabled:true},orderBy:{priceCoins:'asc'}});
  res.json(gifts);
});
app.post('/api/wallet/purchase/intent',auth,async(req,res)=>{
  const d=z.object({productId:z.string().min(1),platform:z.enum(['android','ios','demo']).default('android'),transactionId:z.string().min(3).max(300)}).parse(req.body);
  const pkg=COIN_PACKAGES.find(x=>x.productId===d.productId); if(!pkg)return res.status(404).json({error:'PACKAGE_NOT_FOUND'});
  const existing=await prisma.purchaseOrder.findUnique({where:{transactionId:d.transactionId}}); if(existing)return res.json({order:existing,already:true});
  const order=await prisma.purchaseOrder.create({data:{userId:req.user.id,productId:pkg.productId,coins:pkg.coins,amountCents:pkg.amountCents,platform:d.platform,transactionId:d.transactionId}});
  res.status(201).json({order,package:pkg,requiresStoreVerification:true});
});
app.post('/api/wallet/purchase/verify',auth,async(req,res)=>{
  const d=z.object({transactionId:z.string().min(3),productId:z.string().min(1),platform:z.enum(['android','ios','demo']),purchaseToken:z.string().optional().default('')}).parse(req.body);
  const order=await prisma.purchaseOrder.findUnique({where:{transactionId:d.transactionId}}); if(!order||order.userId!==req.user.id)return res.status(404).json({error:'PURCHASE_NOT_FOUND'});
  if(order.productId!==d.productId)return res.status(400).json({error:'PRODUCT_MISMATCH'});
  if(order.status==='VERIFIED')return res.json({ok:true,already:true,wallet:await ensureWallet(req.user.id)});
  // Production safety: never credit coins from a client-only claim. Set IAP_VERIFICATION_MODE=DEMO only for local/test builds.
  if(process.env.IAP_VERIFICATION_MODE!=='DEMO')return res.status(503).json({error:'IAP_VERIFICATION_NOT_CONFIGURED'});
  const wallet=await prisma.$transaction(async tx=>{
    const base=await ensureWallet(req.user.id,tx);
    const w=await tx.wallet.update({where:{id:base.id},data:{coinBalance:{increment:order.coins},purchasedCoins:{increment:order.coins},lifetimePurchased:{increment:order.coins}}});
    await tx.purchaseOrder.update({where:{id:order.id},data:{status:'VERIFIED',verifiedAt:new Date()}});
    await walletLedger(tx,w,req.user.id,'PURCHASE',order.coins,w.withdrawableCoins,'شراء NovaCoins',{productId:order.productId,platform:d.platform});
    return w;
  });
  res.json({ok:true,wallet});
});
app.post('/api/wallet/gifts/send',auth,async(req,res)=>{
  try{
    const d=z.object({receiverId:z.string().min(1),giftId:z.string().min(1),context:z.enum(['LIVE','POST','REEL','COMMENT']).default('LIVE'),contextId:z.string().max(200).default(''),message:z.string().max(200).default('')}).parse(req.body);
    if(d.receiverId===req.user.id)return res.status(400).json({error:'SELF_GIFT'});
    const gift=await prisma.gift.findUnique({where:{id:d.giftId}}); if(!gift||!gift.enabled)return res.status(404).json({error:'GIFT_NOT_FOUND'});
    const result=await prisma.$transaction(async tx=>{
      const sender=await ensureWallet(req.user.id,tx);
      const receiver=await ensureWallet(d.receiverId,tx);
      if(sender.coinBalance<gift.priceCoins)throw new Error('INSUFFICIENT_COINS');
      const usePurchased=Math.min(sender.purchasedCoins,gift.priceCoins);
      const useBonus=gift.priceCoins-usePurchased;
      const fundingType=useBonus>0 ? (usePurchased>0?'MIXED':'BONUS') : 'PURCHASED';
      const creatorCoins=fundingType==='PURCHASED' ? Math.max(1,Math.floor(gift.priceCoins*CREATOR_SHARE)) : 0;
      const senderAfter=await tx.wallet.update({where:{id:sender.id},data:{coinBalance:{decrement:gift.priceCoins},purchasedCoins:{decrement:usePurchased},bonusCoins:{decrement:useBonus},lifetimeSpent:{increment:gift.priceCoins}}});
      const receiverAfter=creatorCoins>0
        ? await tx.wallet.update({where:{id:receiver.id},data:{withdrawableCoins:{increment:creatorCoins},lifetimeReceived:{increment:creatorCoins}}})
        : receiver;
      const reference='GFT-'+crypto.randomBytes(8).toString('hex').toUpperCase();
      const giftTx=await tx.giftTransaction.create({data:{senderId:req.user.id,receiverId:d.receiverId,giftId:gift.id,coins:gift.priceCoins,context:d.context,contextId:d.contextId,message:d.message,fundingType,reference}});
      await walletLedger(tx,senderAfter,req.user.id,'GIFT_SENT',-gift.priceCoins,senderAfter.withdrawableCoins,`إرسال ${gift.name}`,{giftId:gift.id,receiverId:d.receiverId,context:d.context,contextId:d.contextId,fundingType});
      if(creatorCoins>0) await walletLedger(tx,receiverAfter,d.receiverId,'GIFT_RECEIVED',0,receiverAfter.withdrawableCoins,`استلام ${gift.name}`,{giftId:gift.id,senderId:req.user.id,context:d.context,contextId:d.contextId,fundingType});
      return {giftTx,sender:senderAfter,receiver:receiverAfter,creatorCoins,fundingType};
    },{isolationLevel:'Serializable'});
    await prisma.notification.create({data:{userId:d.receiverId,type:'GIFT',text:`استلمت ${gift.emoji} ${gift.name} بقيمة ${gift.priceCoins} NovaCoins`}}).catch(()=>{});
    io.to(`user:${d.receiverId}`).emit('gift:received',result.giftTx);
    if(d.context==='LIVE'&&d.contextId)io.to(`live:${d.contextId}`).emit('live:gift',result.giftTx);
    res.status(201).json({ok:true,gift:gift,transaction:result.giftTx,wallet:result.sender,receiverWallet:{withdrawableCoins:result.receiver.withdrawableCoins},fundingType:result.fundingType});
  }catch(e){
    if(e?.message==='INSUFFICIENT_COINS')return res.status(400).json({error:'INSUFFICIENT_COINS'});
    if(e?.message==='SELF_GIFT')return res.status(400).json({error:'SELF_GIFT'});
    if(e?.code==='P2034')return res.status(409).json({error:'TRY_AGAIN'});
    res.status(400).json({error:e?.message==='SELF_GIFT'?'SELF_GIFT':'VALIDATION_ERROR'});
  }
});
app.post('/api/wallet/withdraw',auth,async(req,res)=>{
  try{
    const owner=await prisma.user.findUnique({where:{id:req.user.id},select:{birthDate:true,isBanned:true}});
    if(owner?.isBanned)return res.status(403).json({error:'FORBIDDEN'});
    if(!owner?.birthDate)return res.status(403).json({error:'AGE_VERIFICATION_REQUIRED'});
    const now=new Date(); const dob=new Date(owner.birthDate);
    let age=now.getUTCFullYear()-dob.getUTCFullYear();
    const birthdayPassed=(now.getUTCMonth()>dob.getUTCMonth())||(now.getUTCMonth()===dob.getUTCMonth()&&now.getUTCDate()>=dob.getUTCDate());
    if(!birthdayPassed)age--;
    if(age<18)return res.status(403).json({error:'WITHDRAWAL_18_PLUS'});
    const d=z.object({coins:z.number().int().min(MIN_WITHDRAW_COINS),method:z.enum(['BANK','PAYPAL','OTHER']),destination:z.string().min(4).max(300)}).parse(req.body);
    const result=await prisma.$transaction(async tx=>{
      const w=await tx.wallet.upsert({where:{userId:req.user.id},update:{},create:{userId:req.user.id}});
      if(w.withdrawableCoins<d.coins)throw new Error('INSUFFICIENT_WITHDRAWABLE');
      const feeCoins=Math.floor(d.coins*WITHDRAWAL_FEE_RATE);
      const netCoins=d.coins-feeCoins;
      const cashCents=Math.floor(netCoins*CASH_CENTS_PER_100_COINS/100);
      if(cashCents<=0)throw new Error('WITHDRAW_TOO_SMALL');
      const after=await tx.wallet.update({where:{id:w.id},data:{withdrawableCoins:{decrement:d.coins}}});
      const reference='WDR-'+crypto.randomBytes(8).toString('hex').toUpperCase();
      const reqw=await tx.withdrawalRequest.create({data:{userId:req.user.id,coins:d.coins,feeCoins,cashCents,method:d.method,destination:d.destination,reference}});
      await walletLedger(tx,after,req.user.id,'WITHDRAWAL_PENDING',0,after.withdrawableCoins,'طلب سحب من المحفظة',{coins:d.coins,feeCoins,cashCents,method:d.method,reference});
      return {after,reqw};
    },{isolationLevel:'Serializable'});
    res.status(201).json({ok:true,request:result.reqw,wallet:result.after,netCashCents:result.reqw.cashCents,feeCoins:result.reqw.feeCoins});
  }catch(e){
    const map={INSUFFICIENT_WITHDRAWABLE:'INSUFFICIENT_WITHDRAWABLE',WITHDRAW_TOO_SMALL:'WITHDRAW_TOO_SMALL'};
    if(map[e?.message])return res.status(400).json({error:map[e.message]});
    if(e?.code==='P2034')return res.status(409).json({error:'TRY_AGAIN'});
    res.status(400).json({error:'VALIDATION_ERROR'});
  }
});
app.get('/api/wallet/received-gifts',auth,async(req,res)=>res.json(await prisma.giftTransaction.findMany({where:{receiverId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{gift:true,sender:true}})));
app.get('/api/wallet/sent-gifts',auth,async(req,res)=>res.json(await prisma.giftTransaction.findMany({where:{senderId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{gift:true,receiver:true}})));


app.get('/api/me/groups',auth,async(req,res)=>{const rows=await prisma.groupMember.findMany({where:{userId:req.user.id},orderBy:{joinedAt:'desc'},include:{group:true}});res.json(rows.map(x=>({...x.group,memberRole:x.role,joinedAt:x.joinedAt}))) });
app.get('/api/me/digital-card',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.user.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts,stories,activeStories,sales,salesViews,selectedGroup]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}}),prisma.story.count({where:{authorId:u.id}}),prisma.story.count({where:{authorId:u.id,expiresAt:{gt:new Date()}}}),prisma.storeOrder.count({where:{listing:{sellerId:u.id},status:{not:'CANCELLED'}}}),prisma.storeListing.aggregate({where:{sellerId:u.id},_sum:{views:true}}),u.digitalCardGroupId?prisma.groupMember.findUnique({where:{groupId_userId:{groupId:u.digitalCardGroupId,userId:u.id}},include:{group:true}}):null]);res.json({...safe(u),followers,following,posts,stories,activeStories,sales,productViews:salesViews._sum.views??0,digitalCardGroup:selectedGroup?.group?{id:selectedGroup.group.id,name:selectedGroup.group.name,avatarUrl:selectedGroup.group.avatarUrl}:null,verification:{verified:u.isVerified,tier:u.verificationTier}})});
app.get('/api/users/:id/profile',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.params.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}})]);const followerCount=u.demoFollowersCount ?? followers;const followingCount=u.demoFollowingCount ?? following;const isMe=u.id===req.user.id;const followingMe=!!await prisma.follow.findUnique({where:{followerId_followingId:{followerId:req.user.id,followingId:u.id}}});const followedByMe=followingMe;const gate=u.isPrivate&&!isMe&&!followedByMe;res.json({...safe(u),followers:u.hideFollowersCount&&!isMe?null:followerCount,following:u.hideFollowingCount&&!isMe?null:followingCount,posts:gate?null:posts,followingMe,followedByMe,isMe,isLocked:gate,rawFollowers:followerCount,rawFollowing:followingCount,rawPosts:posts})});

// Admin wallet operations: payout review and audit trail.
app.get('/api/admin/wallet/withdrawals',auth,admin,async(req,res)=>res.json(await prisma.withdrawalRequest.findMany({orderBy:{createdAt:'desc'},take:300,include:{user:true}})));
app.patch('/api/admin/wallet/withdrawals/:id',auth,admin,async(req,res)=>{
  const status=String(req.body.status||'').toUpperCase();
  if(!['PAID','REJECTED'].includes(status))return res.status(400).json({error:'VALIDATION_ERROR'});
  const out=await prisma.$transaction(async tx=>{
    const wreq=await tx.withdrawalRequest.findUnique({where:{id:req.params.id}}); if(!wreq)return null;
    if(wreq.status!=='PENDING')return wreq;
    const updated=await tx.withdrawalRequest.update({where:{id:wreq.id},data:{status,reviewedAt:new Date()}});
    if(status==='REJECTED'){
      const wallet=await tx.wallet.upsert({where:{userId:wreq.userId},update:{withdrawableCoins:{increment:wreq.coins}},create:{userId:wreq.userId,withdrawableCoins:wreq.coins}});
      await walletLedger(tx,wallet,wreq.userId,'WITHDRAWAL_REFUNDED',0,wallet.withdrawableCoins,'إرجاع طلب سحب مرفوض',{reference:wreq.reference});
    }
    return updated;
  },{isolationLevel:'Serializable'});
  if(!out)return res.status(404).json({error:'NOT_FOUND'});
  await prisma.notification.create({data:{userId:out.userId,type:'WALLET',text:status==='PAID'?'تمت معالجة طلب السحب.':'تم رفض طلب السحب وإعادة الرصيد إلى محفظتك.'}}).catch(()=>{});
  res.json(out);
});

app.get('/api/admin/stats',auth,admin,async(req,res)=>res.json({users:await prisma.user.count(),posts:await prisma.post.count(),reels:await prisma.reel.count(),groups:await prisma.group.count(),live:await prisma.liveRoom.count(),messages:await prisma.message.count()}));
app.get('/api/admin/users',auth,admin,async(req,res)=>res.json((await prisma.user.findMany({orderBy:{createdAt:'desc'},take:200})).map(safe)));app.post('/api/admin/users/:id/demo-followers',auth,admin,async(req,res)=>{const target=await prisma.user.findUnique({where:{id:req.params.id}});if(!target)return res.status(404).json({error:'NOT_FOUND'});const count=Math.min(Math.max(Number(req.body.count||25),1),500);const passwordHash=await bcrypt.hash('demo1234',10);let added=0;for(let i=0;i<count;i++){const username=`demo_${target.username}_${Date.now()}_${i}`.slice(0,30);try{const follower=await prisma.user.create({data:{username,email:`${username}@demo.socialnova.app`,displayName:`متابع تجريبي ${i+1}`,passwordHash}});await prisma.follow.create({data:{followerId:follower.id,followingId:target.id}});added++}catch{}}const followers=await prisma.follow.count({where:{followingId:target.id}});res.json({added,followers,notice:'هؤلاء حسابات تجريبية وليست مستخدمين حقيقيين'});});

app.patch('/api/admin/users/:id/ban',auth,admin,async(req,res)=>res.json(safe(await prisma.user.update({where:{id:req.params.id},data:{isBanned:Boolean(req.body.banned)}}))));

app.post('/api/messages/:id/view',auth,async(req,res)=>{const m=await prisma.message.findUnique({where:{id:req.params.id}});if(!m||m.receiverId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});if(m.viewLimit<=0)return res.json({ok:true});const next=m.viewCount+1;if(next>=m.viewLimit){await prisma.message.delete({where:{id:m.id}});return res.json({ok:true,deleted:true});}await prisma.message.update({where:{id:m.id},data:{viewCount:next}});res.json({ok:true,views:next,remaining:m.viewLimit-next})});
app.patch('/api/messages/:id/delete',auth,async(req,res)=>{const m=await prisma.message.findUnique({where:{id:req.params.id}});if(!m)return res.status(404).json({error:'NOT_FOUND'});if(m.senderId!==req.user.id&&m.receiverId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});const both=req.body?.forEveryone===true;const data=m.senderId===req.user.id?(both?{deletedForSender:true,deletedForReceiver:true}:{deletedForSender:true}):(both?{deletedForSender:true,deletedForReceiver:true}:{deletedForReceiver:true});await prisma.message.update({where:{id:m.id},data});res.json({ok:true})});
const online=new Map(); io.on('connection',socket=>{socket.on('auth',({token})=>{try{const u=jwt.verify(token,JWT_SECRET);socket.userId=u.id;online.set(u.id,socket.id);socket.join(`user:${u.id}`);socket.emit('ready')}catch{socket.disconnect()}});socket.on('call:invite',async({to,roomName,video,name,avatar})=>{if(!socket.userId||!to||!roomName)return;io.to(`user:${String(to)}`).emit('call:invite',{fromId:socket.userId,roomName:String(roomName),video:video===true,name:String(name||''),avatar:String(avatar||'')});});socket.on('call:accept',async({to,roomName})=>{if(!socket.userId||!to||!roomName)return;io.to(`user:${String(to)}`).emit('call:accept',{fromId:socket.userId,roomName:String(roomName)});});socket.on('call:reject',async({to})=>{if(!socket.userId||!to)return;io.to(`user:${String(to)}`).emit('call:reject',{fromId:socket.userId});});socket.on('message',async({to,body})=>{try{if(!socket.userId||!to||!body)return;const target=await prisma.user.findUnique({where:{id:String(to)}});if(!target)return socket.emit('error',{error:'USER_NOT_FOUND'});const m=await prisma.message.create({data:{senderId:socket.userId,receiverId:target.id,body:String(body).slice(0,4000)}});io.to(`user:${target.id}`).emit('message',m);socket.emit('message',m);await prisma.notification.create({data:{userId:target.id,type:'MESSAGE',text:'لديك رسالة جديدة'}})}catch(e){console.error('socket message error',e.message)}});socket.on('live:chat',async({room,body})=>{if(!socket.userId||!room||!body)return;io.to(`live:${room}`).emit('live:chat',{userId:socket.userId,body:String(body).slice(0,500)});});socket.on('live:join',async({room})=>{if(!socket.userId)return;socket.join(`live:${room}`);socket.to(`live:${room}`).emit('live:user-joined',{userId:socket.userId});});socket.on('live:leave',({room})=>socket.leave(`live:${room}`));socket.on('disconnect',()=>{if(socket.userId&&online.get(socket.userId)===socket.id)online.delete(socket.userId)})});

// ============ SocialNova v8: verification tiers, privacy, settings, lists ============
const VERIFY_PLANS={NORMAL:{tier:'NORMAL',price:4.99,days:30,label:'توثيق عادي'},PRO:{tier:'PRO',price:19.99,days:30,label:'توثيق احترافي'}};
app.get('/api/verification/plans',auth,(req,res)=>res.json({plans:Object.values(VERIFY_PLANS).map(p=>({tier:p.tier,label:p.label,price:p.price,currency:'USD',days:p.days,perks:p.tier==='PRO'?['شارة ذهبية متحركة','أولوية الدعم الفني','إحصائيات متقدمة','ظهور مميز في البحث','تحقق من الهوية','تخصيص رابط الملف']:['شارة زرقاء بجانب الاسم','ثقة أعلى لدى المتابعين','إحصائيات أساسية','دعم عبر البريد']}))}));
app.get('/api/verification/me',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.user.id}});const requests=await prisma.verificationRequest.findMany({where:{userId:req.user.id},orderBy:{createdAt:'desc'},take:10});const active=u.verificationTier!=='NONE'&&(!u.verificationExpiresAt||u.verificationExpiresAt>new Date());res.json({tier:active?u.verificationTier:'NONE',expiresAt:u.verificationExpiresAt,active,requests,plans:VERIFY_PLANS})});
app.post('/api/verification/request',auth,async(req,res)=>{try{const d=z.object({tier:z.enum(['NORMAL','PRO'])}).parse(req.body);const plan=VERIFY_PLANS[d.tier];const reference='SNV-'+crypto.randomBytes(6).toString('hex').toUpperCase();const r=await prisma.verificationRequest.create({data:{userId:req.user.id,tier:d.tier,amount:Math.round(plan.price*100),currency:'USD',reference}});res.status(201).json({request:r,checkout:{reference,amount:plan.price,currency:'USD',label:plan.label,days:plan.days}})}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.post('/api/verification/:id/confirm',auth,async(req,res)=>{const r=await prisma.verificationRequest.findUnique({where:{id:req.params.id}});if(!r||r.userId!==req.user.id)return res.status(404).json({error:'NOT_FOUND'});if(r.status==='APPROVED')return res.json({request:r,already:true});const plan=VERIFY_PLANS[r.tier]||{days:30};const updated=await prisma.verificationRequest.update({where:{id:r.id},data:{status:'APPROVED',reviewedAt:new Date()}});const u=await prisma.user.update({where:{id:req.user.id},data:{verificationTier:r.tier,verificationExpiresAt:new Date(Date.now()+plan.days*86400000),isVerified:true}});await prisma.notification.create({data:{userId:req.user.id,type:'VERIFICATION',text:r.tier==='PRO'?'تم تفعيل التوثيق الاحترافي ✅':'تم تفعيل التوثيق العادي ✅'}});res.json({request:updated,user:safe(u)})});
app.get('/api/verification/requests',auth,async(req,res)=>res.json(await prisma.verificationRequest.findMany({orderBy:{createdAt:'desc'},take:200,include:{user:true}})));
app.patch('/api/verification/requests/:id',auth,admin,async(req,res)=>{const r=await prisma.verificationRequest.findUnique({where:{id:req.params.id}});if(!r)return res.status(404).json({error:'NOT_FOUND'});const status=['APPROVED','REJECTED','PENDING'].includes(String(req.body.status))?String(req.body.status):'PENDING';const out=await prisma.verificationRequest.update({where:{id:r.id},data:{status,reviewedAt:new Date()}});if(status==='APPROVED'){const plan=VERIFY_PLANS[r.tier]||{days:30};await prisma.user.update({where:{id:r.userId},data:{verificationTier:r.tier,verificationExpiresAt:new Date(Date.now()+plan.days*86400000),isVerified:true}})}else if(status==='REJECTED'){await prisma.user.update({where:{id:r.userId},data:{verificationTier:'NONE',isVerified:false}})}res.json(out)});
app.get('/api/users/:id/followers',auth,async(req,res)=>{const rows=await prisma.follow.findMany({where:{followingId:req.params.id},orderBy:{createdAt:'desc'},take:300,include:{follower:true}});res.json(rows.map(x=>safe(x.follower)))});
app.get('/api/users/:id/following',auth,async(req,res)=>{const rows=await prisma.follow.findMany({where:{followerId:req.params.id},orderBy:{createdAt:'desc'},take:300,include:{following:true}});res.json(rows.map(x=>safe(x.following)))});
app.get('/api/users/:id/posts',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{id:req.params.id}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const followedByMe=!!await prisma.follow.findUnique({where:{followerId_followingId:{followerId:req.user.id,followingId:u.id}}});if(u.isPrivate&&u.id!==req.user.id&&!followedByMe)return res.json([]);const posts=await prisma.post.findMany({where:{authorId:u.id},orderBy:{createdAt:'desc'},take:60,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:3}}});res.json(posts.map(p=>({...p,author:safe(p.author),likedByMe:p.likes.some(x=>x.userId===req.user.id),likeCount:p.likes.length,commentCount:p.comments.length}))) });
app.get('/api/users/:id/saved',auth,async(req,res)=>{if(req.user.id!==req.params.id)return res.json([]);const rows=await prisma.post.findMany({where:{bookmarks:{some:{userId:req.user.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,bookmarks:true,comments:{include:{author:true},take:3}}});res.json(rows.map(p=>({...p,author:safe(p.author),likedByMe:p.likes.some(x=>x.userId===req.user.id),bookmarkedByMe:true,likeCount:p.likes.length,commentCount:p.comments.length})))});
app.get('/api/users/:id/liked',auth,async(req,res)=>{if(req.user.id!==req.params.id)return res.json([]);const rows=await prisma.post.findMany({where:{likes:{some:{userId:req.user.id}}},orderBy:{createdAt:'desc'},take:100,include:{author:true,likes:true,bookmarks:true,comments:{include:{author:true},take:3}}});res.json(rows.map(p=>({...p,author:safe(p.author),likedByMe:true,bookmarkedByMe:p.bookmarks.some(x=>x.userId===req.user.id),likeCount:p.likes.length,commentCount:p.comments.length})))});
app.get('/api/users/:id/reposted-reels',auth,async(req,res)=>{
  const u=await prisma.user.findUnique({where:{id:req.params.id}});
  if(!u)return res.status(404).json({error:'NOT_FOUND'});
  const followedByMe=!!await prisma.follow.findUnique({where:{followerId_followingId:{followerId:req.user.id,followingId:u.id}}});
  const rows=await prisma.reel.findMany({where:{reposts:{some:{userId:u.id}}},orderBy:{createdAt:'desc'},take:60,include:{author:true,likes:true,comments:{include:{author:true},orderBy:{createdAt:'desc'},take:3},shares:true,reposts:{include:{user:true}}}});
  res.json(rows.map(r=>({...r,author:safe(r.author),likedByMe:r.likes.some(x=>x.userId===req.user.id),repostedByMe:r.reposts.some(x=>x.userId===req.user.id),reposters:r.reposts.slice(0,3).map(x=>safe(x.user)),likeCount:r.likes.length,commentCount:r.comments.length,shareCount:r.shares.length,repostCount:r.reposts.length,comments:r.comments.map(c=>({...c,author:safe(c.author)})),repostedByProfile:true,repostedByUserId:u.id})));
});
app.delete('/api/posts/:id',auth,async(req,res)=>{const p=await prisma.post.findUnique({where:{id:req.params.id}});if(!p)return res.status(404).json({error:'NOT_FOUND'});if(p.authorId!==req.user.id)return res.status(403).json({error:'FORBIDDEN'});await prisma.post.delete({where:{id:p.id}});res.json({ok:true})});
app.patch('/api/settings',auth,async(req,res)=>{try{const d=z.object({isPrivate:z.boolean().optional(),hideFollowersCount:z.boolean().optional(),hideFollowingCount:z.boolean().optional(),showOnlineStatus:z.boolean().optional(),allowMessageRequests:z.boolean().optional(),pushNotifications:z.boolean().optional(),hideFromSearch:z.boolean().optional(),hideFromSuggestions:z.boolean().optional(),preventProfileScreenshots:z.boolean().optional()}).parse(req.body);res.json({user:safe(await prisma.user.update({where:{id:req.user.id},data:d}))})}catch(e){res.status(400).json({error:'VALIDATION_ERROR'})}});
app.get('/api/users/by-username/:username',auth,async(req,res)=>{const u=await prisma.user.findUnique({where:{username:req.params.username}});if(!u)return res.status(404).json({error:'NOT_FOUND'});const [followers,following,posts]=await Promise.all([prisma.follow.count({where:{followingId:u.id}}),prisma.follow.count({where:{followerId:u.id}}),prisma.post.count({where:{authorId:u.id}})]);res.json({...safe(u),followers,following,posts})});
app.post('/api/blocks/:id',auth,async(req,res)=>{await prisma.follow.deleteMany({where:{OR:[{followerId:req.user.id,followingId:req.params.id},{followerId:req.params.id,followingId:req.user.id}]}});res.json({ok:true})});

app.get('/api/users/suggested',auth,async(req,res)=>{const fl=await prisma.follow.findMany({where:{followerId:req.user.id},select:{followingId:true}});const exclude=[req.user.id,...fl.map(f=>f.followingId)];const users=await prisma.user.findMany({where:{id:{notIn:exclude},isBanned:false,hideFromSuggestions:false},orderBy:{createdAt:'desc'},take:30});res.json(users.map(safe))});
// ---------------- Store / Marketplace ----------------
// ---------------- Store commissions / affiliate ----------------
const COMMISSION_DEFAULTS={saleRatePct:5,serviceRatePct:5,subscriptionRatePct:10,affiliateRatePct:2};
async function getCommissionSettings(){
  let row=await prisma.commissionSetting.findFirst();
  if(!row) row=await prisma.commissionSetting.create({data:COMMISSION_DEFAULTS});
  return row;
}
app.get('/api/store/commission/settings',auth,async(req,res)=>{try{const s=await getCommissionSettings();res.json({saleRatePct:s.saleRatePct,serviceRatePct:s.serviceRatePct,subscriptionRatePct:s.subscriptionRatePct,affiliateRatePct:s.affiliateRatePct});}catch{res.status(500).json({error:'COMMISSION_LOAD_FAILED'});}});
app.get('/api/store/commission/dashboard',auth,async(req,res)=>{
  try{
    const [settings,rows,aff]=await Promise.all([getCommissionSettings(),prisma.commissionLedger.findMany({where:{recipientId:req.user.id},orderBy:{createdAt:'desc'},take:100}),prisma.affiliateReferral.findMany({where:{referrerId:req.user.id},orderBy:{createdAt:'desc'},take:100,include:{listing:{select:{title:true}}}})]);
    const gross=rows.reduce((a,x)=>a+x.grossCents,0), fees=rows.reduce((a,x)=>a+x.commissionCents,0), net=rows.reduce((a,x)=>a+x.netCents,0), affiliate=aff.reduce((a,x)=>a+x.commissionCents,0);
    res.json({settings,summary:{grossCents:gross,commissionCents:fees,netCents:net,affiliateCents:affiliate,totalOrders:rows.length},rows,affiliate:aff});
  }catch(e){res.status(500).json({error:'COMMISSION_DASHBOARD_FAILED'});}
});
app.get('/api/store/affiliate/:listingId',auth,async(req,res)=>{try{const l=await prisma.storeListing.findUnique({where:{id:req.params.listingId},select:{id:true,title:true}});if(!l)return res.status(404).json({error:'NOT_FOUND'});const ref=`${req.user.id}`;res.json({listingId:l.id,title:l.title,referrerId:ref,shareCode:Buffer.from(`${ref}:${l.id}`).toString('base64url')});}catch{res.status(404).json({error:'NOT_FOUND'});}});
app.post('/api/store/affiliate/click',auth,async(req,res)=>{try{const d=z.object({listingId:z.string(),referrerId:z.string()}).parse(req.body);if(d.referrerId===req.user.id)return res.json({ok:true,ignored:true});const l=await prisma.storeListing.findUnique({where:{id:d.listingId}});const ref=await prisma.user.findUnique({where:{id:d.referrerId}});if(!l||!ref)return res.status(404).json({error:'NOT_FOUND'});const existing=await prisma.affiliateReferral.findFirst({where:{listingId:l.id,referrerId:ref.id,buyerId:req.user.id,orderId:null}});if(existing){await prisma.affiliateReferral.update({where:{id:existing.id},data:{clicks:{increment:1}}});}else{await prisma.affiliateReferral.create({data:{listingId:l.id,referrerId:ref.id,buyerId:req.user.id,clicks:1}});}res.json({ok:true});}catch{res.status(400).json({error:'AFFILIATE_FAILED'});}});
const storeCategories = ['ملابس','إلكترونيات','هدايا','رياضة'];
app.get('/api/store/listings', auth, async (req,res)=>{
  try{
    const category=String(req.query.category||'').trim();
    const q=String(req.query.q||'').trim();
    const location=String(req.query.location||'').trim();
    const min=Number.isFinite(Number(req.query.minPrice))?Math.max(0,Number(req.query.minPrice)):undefined;
    const max=Number.isFinite(Number(req.query.maxPrice))?Math.max(0,Number(req.query.maxPrice)):undefined;
    const sort=String(req.query.sort||'latest');
    const where={active:true,...(category&&category!=='الكل'?{category}:{}),...(location?{location:{contains:location,mode:'insensitive'}}:{}),...(q?{OR:[{title:{contains:q,mode:'insensitive'}},{description:{contains:q,mode:'insensitive'}}]}:{}),...((min!==undefined||max!==undefined)?{priceCents:{...(min!==undefined?{gte:Math.round(min*100)}:{}),...(max!==undefined?{lte:Math.round(max*100)}:{})}}:{})};
    const orderBy=sort==='popular'?{views:'desc'}:sort==='purchases'?{purchases:'desc'}:{createdAt:'desc'};
    const rows=await prisma.storeListing.findMany({where,orderBy,take:60,include:{seller:true,reviews:{select:{rating:true}}}});
    res.json(rows.map(x=>{const avg=x.reviews.length?x.reviews.reduce((a,r)=>a+r.rating,0)/x.reviews.length:0; const discount=Math.max(0,Math.min(100,x.discountPct||0)); const final=Math.round(x.priceCents*(100-discount)/100); return {...x,seller:safe(x.seller),rating:avg,reviewCount:x.reviews.length,finalPriceCents:final};}));
  }catch(e){res.status(500).json({error:'STORE_LOAD_FAILED'});}
});
app.post('/api/store/listings', auth, async (req,res)=>{
  try{
    const d=z.object({title:z.string().min(2).max(120),description:z.string().max(1500).default(''),category:z.enum(storeCategories),priceCents:z.number().int().min(0).max(100000000),currency:z.string().max(8).default('USD'),location:z.string().max(120).default(''),imageUrl:z.string().max(5000).default(''),stock:z.number().int().min(1).max(10000).default(1),couponCode:z.string().max(40).default(''),discountPct:z.number().int().min(0).max(90).default(0)}).parse(req.body);
    const row=await prisma.storeListing.create({data:{...d,sellerId:req.user.id}}); res.status(201).json(row);
  }catch(e){res.status(400).json({error:'STORE_VALIDATION_FAILED'});}
});
app.post('/api/store/listings/:id/view', auth, async (req,res)=>{try{const row=await prisma.storeListing.update({where:{id:req.params.id},data:{views:{increment:1}}});res.json({views:row.views});}catch{res.status(404).json({error:'NOT_FOUND'});}});
app.post('/api/store/listings/:id/order', auth, async (req,res)=>{
  try{
    const d=z.object({quantity:z.number().int().min(1).max(50).default(1)}).parse(req.body||{});
    const row=await prisma.storeListing.findUnique({where:{id:req.params.id}}); if(!row||!row.active)return res.status(404).json({error:'NOT_FOUND'}); if(row.sellerId===req.user.id)return res.status(400).json({error:'SELF_ORDER'}); if(d.quantity>row.stock)return res.status(400).json({error:'OUT_OF_STOCK'});
    const total=Math.round(row.priceCents*(100-Math.max(0,Math.min(100,row.discountPct)))/100)*d.quantity;
    const settings=await getCommissionSettings();
    const commissionCents=Math.round(total*Math.max(0,Math.min(100,settings.saleRatePct))/100);
    const affiliate=await prisma.affiliateReferral.findFirst({where:{listingId:row.id,buyerId:req.user.id,orderId:null,referrerId:{not:row.sellerId}},orderBy:{createdAt:'desc'}});
    const affiliateCommissionCents=affiliate?Math.round(total*Math.max(0,Math.min(100,settings.affiliateRatePct))/100):0;
    const netCents=total-commissionCents-affiliateCommissionCents;
    const order=await prisma.$transaction(async tx=>{
      const o=await tx.storeOrder.create({data:{listingId:row.id,buyerId:req.user.id,quantity:d.quantity,amountCents:total,currency:row.currency,commissionCents,affiliateCommissionCents,affiliateUserId:affiliate?.referrerId||null}});
      await tx.storeListing.update({where:{id:row.id},data:{purchases:{increment:d.quantity},stock:{decrement:d.quantity},active:row.stock-d.quantity>0}});
      await tx.commissionLedger.create({data:{orderId:o.id,recipientId:row.sellerId,source:'STORE_SALE',grossCents:total,commissionCents,netCents,currency:row.currency,status:'PENDING'}});
      if(affiliate) await tx.affiliateReferral.update({where:{id:affiliate.id},data:{orderId:o.id,commissionCents:affiliateCommissionCents,status:'PENDING'}});
      return o;
    });
    res.status(201).json({...order,commissionRatePct:settings.saleRatePct,commissionCents,affiliateCommissionCents,netSellerCents:netCents});
  }catch(e){res.status(400).json({error:'ORDER_FAILED'});}
});
app.post('/api/store/listings/:id/reviews', auth, async (req,res)=>{
  try{
    const d=z.object({rating:z.number().int().min(1).max(5),comment:z.string().max(800).default('')}).parse(req.body||{});
    const listing=await prisma.storeListing.findUnique({where:{id:req.params.id}}); if(!listing)return res.status(404).json({error:'NOT_FOUND'}); if(listing.sellerId===req.user.id)return res.status(400).json({error:'SELF_REVIEW'});
    const bought=await prisma.storeOrder.findFirst({where:{listingId:listing.id,buyerId:req.user.id}}); if(!bought)return res.status(403).json({error:'BUY_FIRST'});
    const review=await prisma.storeReview.upsert({where:{listingId_authorId:{listingId:listing.id,authorId:req.user.id}},create:{listingId:listing.id,sellerId:listing.sellerId,authorId:req.user.id,...d},update:d,include:{author:true}}); res.status(201).json({...review,author:safe(review.author)});
  }catch(e){res.status(400).json({error:'REVIEW_FAILED'});}
});
app.use((req,res)=>res.status(404).json({error:'NOT_FOUND'}));
app.use((err,req,res,next)=>{console.error(err);if(res.headersSent)return next(err);res.status(err&&err.name==='ZodError'?400:500).json({error:err&&err.name==='ZodError'?'VALIDATION_ERROR':'SERVER_ERROR'})});
const PORT=process.env.PORT||10000; ensureGiftCatalog().catch(e=>console.error('gift catalog init error',e.message)); http.listen(PORT,()=>console.log(`SocialNova API listening on ${PORT}`));
