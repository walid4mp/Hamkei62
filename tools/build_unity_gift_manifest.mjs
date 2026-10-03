import fs from 'fs';
import { buildGiftCatalog } from '../backend/src/modules/gifts.js';
const gifts=buildGiftCatalog().map((g,i)=>({
  id:g.slug,name:g.name,nameEn:g.nameEn,priceCoins:g.priceCoins,rarity:g.rarity,category:g.category,
  effectKey:g.effectKey,effectMs:g.effectMs,soundKey:g.soundKey,
  assetKey:g.assetKey,modelPath:`models/${g.slug}.glb`,
  animationKey:`${g.effectKey}_${String(i+1).padStart(3,'0')}`
}));
fs.mkdirSync('./unity-gifts/Assets/Resources', {recursive:true});
fs.writeFileSync('./unity-gifts/Assets/Resources/gift_manifest.json', JSON.stringify({version:1,gifts},null,2));
console.log(`wrote ${gifts.length} gifts`);
