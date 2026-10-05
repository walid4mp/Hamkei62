// SocialNova Gift Engine.
//
// A single, deterministic generator for the whole gift catalog (200+ gifts).
// Every gift carries: id (slug), name, icon (emoji), rarity, value, duration,
// animation key, sound key, enabled flag and metadata (category + tier).
//
// The catalog is generated from curated themed lists so it is stable across
// restarts (upsert by slug) and every entry is unique.

export const GIFT_CATEGORIES = [
  { key: 'love', label: 'حب ومشاعر' },
  { key: 'luxury', label: 'فخامة' },
  { key: 'tech', label: 'تقنية وسيارات' },
  { key: 'nature', label: 'طبيعة' },
  { key: 'food', label: 'مأكولات' },
  { key: 'music', label: 'موسيقى وترفيه' },
  { key: 'sport', label: 'رياضة وقوة' },
];

// [emoji, Arabic name]. Emojis are unique across the whole catalog.
const LOVE = [
  ['🌹', 'وردة حمراء'], ['❤️', 'قلب'], ['💘', 'قلب بسهم'], ['💝', 'قلب بفيونكة'],
  ['💖', 'قلب لامع'], ['💗', 'قلب متنامي'], ['💓', 'قلب نابض'], ['💞', 'قلبان يدوران'],
  ['💕', 'قلبان صغيران'], ['😍', 'نظرة حب'], ['😘', 'قبلة طائرة'], ['🥰', 'وجه محب'],
  ['💋', 'قبلة حمراء'], ['🌷', 'توليب'], ['🌺', 'كركديه'], ['🌸', 'زهرة كرز'],
  ['💐', 'باقة ورد'], ['🎁', 'هدية'], ['💌', 'رسالة حب'], ['🧸', 'دبدوب'],
  ['🍫', 'شوكولاتة'], ['🍬', 'حلوى'], ['🎂', 'كيكة عيد'], ['🥂', 'نخب'],
  ['💍', 'خاتم'], ['👰', 'عروس'], ['🤵', 'عريس'], ['💒', 'زفاف'],
  ['🕯️', 'شمعة رومانسية'], ['🫶', 'قلب باليدين'],
];

const LUXURY = [
  ['👑', 'تاج'], ['💎', 'ماسة'], ['💠', 'جوهرة'], ['🔮', 'كريستال'],
  ['🏆', 'كأس ذهبي'], ['🥇', 'ميدالية ذهبية'], ['🥈', 'ميدالية فضية'], ['🥉', 'ميدالية برونزية'],
  ['🎖️', 'وسام شرف'], ['🏅', 'شارة'], ['💰', 'كيس نقود'], ['💵', 'دولار'],
  ['💶', 'يورو'], ['💷', 'جنيه'], ['💴', 'ين'], ['🪙', 'عملة ذهبية'],
  ['💳', 'بطاقة ذهبية'], ['⚜️', 'زنبق ملكي'], ['🦢', 'بجعة'], ['🦚', 'طاووس'],
  ['🐎', 'حصان أصيل'], ['🐕', 'كلب وفي'], ['🐈', 'قط مدلل'], ['🦅', 'صقر'],
  ['🦉', 'بومة حكيمة'], ['🐅', 'نمر'], ['🐆', 'فهد'], ['🐘', 'فيل'],
  ['🦏', 'وحيد القرن'], ['🪭', 'مروحة فاخرة'],
];

const TECH = [
  ['🚀', 'صاروخ'], ['🛸', 'سفينة فضاء'], ['✈️', 'طائرة'], ['🛩️', 'طائرة خاصة'],
  ['🚁', 'هليكوبتر'], ['🏎️', 'سيارة سباق'], ['🚗', 'سيارة'], ['🚙', 'دفع رباعي'],
  ['🏍️', 'دراجة نارية'], ['🚲', 'دراجة'], ['🛥️', 'يخت'], ['⛵', 'قارب شراعي'],
  ['🚤', 'زورق سريع'], ['🚂', 'قطار'], ['📱', 'هاتف'], ['💻', 'حاسوب'],
  ['⌚', 'ساعة ذكية'], ['📷', 'كاميرا'], ['🎮', 'يد تحكم'], ['🕹️', 'عصا ألعاب'],
  ['🎧', 'سماعات'], ['🖥️', 'شاشة'], ['🛰️', 'قمر صناعي'], ['🤖', 'روبوت'],
  ['⚡', 'برق'], ['🔋', 'بطارية'], ['💡', 'مصباح'], ['🔦', 'كشاف'],
  ['📡', 'هوائي'], ['🧲', 'مغناطيس'],
];

const NATURE = [
  ['🌌', 'مجرة'], ['🌠', 'شهاب'], ['⭐', 'نجمة'], ['🌟', 'نجمة متلألئة'],
  ['✨', 'بريق'], ['🌈', 'قوس قزح'], ['☀️', 'شمس'], ['🌤️', 'شمس وغيوم'],
  ['☁️', 'سحابة'], ['🌧️', 'مطر'], ['⛈️', 'عاصفة'], ['🌩️', 'صاعقة'],
  ['❄️', 'ندفة ثلج'], ['⛄', 'رجل ثلج'], ['🔥', 'لهب'], ['🎆', 'ألعاب نارية'],
  ['🎇', 'مفرقعات'], ['🌋', 'بركان'], ['🌊', 'موجة'], ['🌪️', 'إعصار'],
  ['🍀', 'زهرة الحظ'], ['🌴', 'نخلة'], ['🌵', 'صبار'], ['🌳', 'شجرة'],
  ['🍁', 'ورقة خريف'], ['🍂', 'أوراق متساقطة'], ['🌾', 'سنابل'], ['🍄', 'فطر'],
  ['🐚', 'صدفة'], ['🪨', 'صخرة'],
];

const FOOD = [
  ['☕', 'قهوة'], ['🍵', 'شاي'], ['🧋', 'شاي بوبا'], ['🥤', 'مشروب غازي'],
  ['🍹', 'كوكتيل'], ['🍸', 'كأس'], ['🍷', 'نبيذ'], ['🍺', 'بيرة'],
  ['🍕', 'بيتزا'], ['🍔', 'برجر'], ['🌭', 'هوت دوغ'], ['🍟', 'بطاطس'],
  ['🍗', 'دجاج مشوي'], ['🥩', 'ستيك'], ['🍣', 'سوشي'], ['🍜', 'نودلز'],
  ['🍝', 'باستا'], ['🥗', 'سلطة'], ['🍎', 'تفاحة'], ['🍓', 'فراولة'],
  ['🍉', 'بطيخ'], ['🍇', 'عنب'], ['🍊', 'برتقال'], ['🍋', 'ليمون'],
  ['🥑', 'أفوكادو'], ['🍩', 'دونات'], ['🍪', 'كوكيز'], ['🍭', 'مصاصة'],
  ['🍦', 'آيس كريم'], ['🥧', 'فطيرة'],
];

const MUSIC = [
  ['🎤', 'ميكروفون'], ['🎙️', 'ميكروفون استوديو'], ['🎸', 'جيتار'], ['🎹', 'بيانو'],
  ['🎺', 'بوق'], ['🎻', 'كمان'], ['🥁', 'طبول'], ['🪘', 'طبل'],
  ['🎷', 'ساكسفون'], ['🪗', 'أكورديون'], ['🎼', 'نوتة موسيقية'], ['🎵', 'نوتة مفردة'],
  ['🎶', 'أنغام'], ['📻', 'راديو'], ['📺', 'تلفاز'], ['🎬', 'كلاكيت'],
  ['🎭', 'أقنعة مسرح'], ['🎪', 'سيرك'], ['🎨', 'لوحة ألوان'], ['🖌️', 'فرشاة رسم'],
  ['🎯', 'هدف'], ['🎳', 'بولينج'], ['🎲', 'نرد'], ['♟️', 'شطرنج'],
  ['🧩', 'أحجية'], ['🃏', 'ورقة لعب'], ['🎰', 'ماكينة حظ'], ['🪄', 'عصا سحرية'],
  ['🔔', 'جرس'], ['📯', 'بوق إعلان'],
];

const SPORT = [
  ['⚽', 'كرة قدم'], ['🏀', 'كرة سلة'], ['🏈', 'كرة أمريكية'], ['🎾', 'تنس'],
  ['🏐', 'كرة طائرة'], ['🏓', 'بينغ بونغ'], ['🏸', 'ريشة'], ['🥊', 'قفاز ملاكمة'],
  ['🥋', 'زي قتالي'], ['🏋️', 'دمبل'], ['🤸', 'جمباز'], ['🏃', 'عدّاء'],
  ['🚴', 'دراجة سباق'], ['🏊', 'سباحة'], ['🏄', 'تزلج مائي'], ['⛷️', 'تزلج ثلجي'],
  ['🏂', 'لوح ثلجي'], ['⛸️', 'تزحلق جليد'], ['🏹', 'قوس وسهم'], ['🎣', 'صنارة صيد'],
  ['🧗', 'تسلق'], ['🤺', 'مبارزة'], ['🏇', 'فروسية'], ['🥅', 'مرمى'],
  ['🏒', 'هوكي'], ['🏉', 'رجبي'], ['🥏', 'قرص طائر'], ['🛹', 'لوح تزلج'],
  ['🛼', 'حذاء تزلج'], ['🥌', 'كيرلينغ'],
];

const CATEGORY_LISTS = {
  love: LOVE, luxury: LUXURY, tech: TECH, nature: NATURE,
  food: FOOD, music: MUSIC, sport: SPORT,
};

// Reserve emojis used only if a themed list leaves us short of 200 unique icons.
const RESERVE = [
  ['🦄', 'وحيد القرن السحري'], ['🐉', 'تنين'], ['🐲', 'رأس تنين'], ['🦖', 'ديناصور'],
  ['🦕', 'ديناصور طويل'], ['🐺', 'ذئب'], ['🦊', 'ثعلب'], ['🐻', 'دب'],
  ['🐼', 'باندا'], ['🐨', 'كوالا'], ['🦋', 'فراشة'], ['🐝', 'نحلة'],
  ['🐞', 'دعسوقة'], ['🦜', 'ببغاء'], ['🦩', 'فلامنغو'], ['🐬', 'دولفين'],
  ['🐳', 'حوت'], ['🦈', 'قرش'], ['🐢', 'سلحفاة'], ['🦂', 'عقرب'],
  ['🕊️', 'حمامة سلام'], ['🦔', 'قنفذ'], ['🐿️', 'سنجاب'], ['🦥', 'كسلان'],
];

const ANIMATIONS = [
  'crown', 'lion', 'rocket', 'car', 'plane', 'diamond', 'fire', 'fireworks',
  'rose', 'heart', 'dragon', 'galaxy', 'lightning', 'stars', 'snow', 'sakura',
  'yacht', 'castle', 'crystal', 'trophy', 'coins', 'music', 'food', 'sport',
  'balloon', 'pulse',
];

const SOUND_BY_RARITY = {
  COMMON: 'common', RARE: 'luck', EPIC: 'luxury', LEGENDARY: 'exclusive', MYTHIC: 'exclusive',
};

/** Value (in coins) for a gift at index i, ascending within the catalog. */
function valueFor(i) {
  // 1..49, 99..499, 999..2999, 4999..9999, then mythic 10000+
  if (i < 60) return 1 + i * ((49 - 1) / 60) | 0;
  if (i < 120) return 99 + ((i - 60) * 4);
  if (i < 170) return 999 + ((i - 120) * 40);
  if (i < 195) return 4999 + ((i - 170) * 200);
  return 10000 + ((i - 195) * 500);
}

function rarityFor(value) {
  if (value >= 10000) return 'MYTHIC';
  if (value >= 4999) return 'LEGENDARY';
  if (value >= 999) return 'EPIC';
  if (value >= 99) return 'RARE';
  return 'COMMON';
}

function durationFor(rarity) {
  switch (rarity) {
    case 'MYTHIC': return 5200;
    case 'LEGENDARY': return 4200;
    case 'EPIC': return 3200;
    case 'RARE': return 2400;
    default: return 1600;
  }
}

// Semantic animation pick: a gift's motion should match what the gift is.
// Falls back to a deterministic rotation so every gift still has an animation.
const ANIMATION_RULES = [
  [/صاروخ/, 'rocket'],
  [/طائرة|هليكوبتر|طائرة خاصة/, 'plane'],
  [/سيارة|دفع رباعي|دراجة نارية|قطار|زورق/, 'car'],
  [/يخت|قارب/, 'yacht'],
  [/تاج/, 'crown'],
  [/قصر|زنبق|بجعة|طاووس/, 'castle'],
  [/تنين/, 'dragon'],
  [/أسد|نمر|فهد|ذئب|حصان|صقر|بومة|فيل|وحيد القرن|كلب|قط|دب|ثعلب|باندا|كوالا|قنفذ|سنجاب|كسلان|ديناصور/, 'lion'],
  [/ماسة|جوهرة|كريستال/, 'diamond'],
  [/ألعاب نارية|مفرقعات/, 'fireworks'],
  [/نار|لهب|بركان/, 'fire'],
  [/برق|صاعقة/, 'lightning'],
  [/ثلج|شمعة رومانسية|شمعة/, 'snow'],
  [/زهرة كرز/, 'sakura'],
  [/مجرة|شهاب|سفينة فضاء|قمر صناعي|روبوت/, 'galaxy'],
  [/نجمة|بريق/, 'stars'],
  [/كأس|ميدالية|وسام|شارة/, 'trophy'],
  [/نقود|عملة|دولار|يورو|جنيه|ين|بطاقة/, 'coins'],
  [/ميكروفون|جيتار|بيانو|بوق|كمان|طبول|طبل|ساكسفون|أكورديون|نوتة|أنغام|راديو|تلفاز|كلاكيت|أقنعة|سيرك|لوحة ألوان|فرشاة|جرس|عصا سحرية|عصا ألعاب|يد تحكم|سماعات|أحجية|ورقة لعب|ماكينة حظ|نرد|شطرنج|هدف|بولينج/, 'music'],
  [/وردة|توليب|كركديه|باقة/, 'rose'],
  [/قلب|قبلة|عروس|عريس|زفاف|دبدوب|رسالة حب|نظرة حب|وجه محب|قلب/, 'heart'],
  [/بالون/, 'balloon'],
];

function animationFor(name, category, index, value) {
  for (const [re, key] of ANIMATION_RULES) {
    if (re.test(name)) return key;
  }
  if (category === 'food') return 'food';
  if (category === 'sport') return 'sport';
  if (category === 'nature' && value >= 4999) return 'galaxy';
  return ANIMATIONS[index % ANIMATIONS.length];
}

function slugify(category, name, index) {
  const base = name
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '')
    .toLowerCase();
  // Arabic names are not ASCII-safe for a stable slug, so combine category + index.
  return `${category}_${String(index + 1).padStart(3, '0')}${base ? '' : ''}`;
}

/**
 * Builds the full catalog. Deterministic: same output on every call.
 * @returns {Array<object>} gift definitions
 */
export function buildGiftCatalog() {
  const seenEmoji = new Set();
  const out = [];

  for (const category of GIFT_CATEGORIES) {
    const list = CATEGORY_LISTS[category.key] || [];
    for (const [emoji, name] of list) {
      if (seenEmoji.has(emoji)) continue;
      seenEmoji.add(emoji);
      out.push({ emoji, name, category: category.key });
    }
  }
  for (const [emoji, name] of RESERVE) {
    if (out.length >= 205) break;
    if (seenEmoji.has(emoji)) continue;
    seenEmoji.add(emoji);
    out.push({ emoji, name, category: 'nature' });
  }

  // Order the catalog from everyday to premium so prices/rarity ascend with
  // meaning: love/food first, luxury last.
  const weight = { love: 0, food: 1, music: 2, sport: 3, tech: 4, nature: 5, luxury: 6 };
  out.sort((a, b) => (weight[a.category] ?? 3) - (weight[b.category] ?? 3));

  return out.map((g, i) => {
    const value = valueFor(i);
    const rarity = rarityFor(value);
    const slug = slugify(g.category, g.name, i);
    return {
      slug,
      name: g.name,
      // V93: the engine is the source of truth for the whole gift library
      // contract, so the store can render it without a Flutter release.
      nameEn: slug.replace(/_/g, ' ').replace(/\b([a-z])/g, (m) => m.toUpperCase()),
      emoji: g.emoji,
      priceCoins: value,
      rarity,
      category: g.category,
      effectKey: animationFor(g.name, g.category, i, value),
      effectMs: durationFor(rarity),
      soundKey: SOUND_BY_RARITY[rarity] || 'common',
      enabled: true,
      // Real artwork is uploaded to the Asset library later; until an admin
      // replaces it, the client falls back to the emoji + rarity frame.
      imageUrl: `/admin-assets/gifts/${g.category}/${slug}.webp`,
      previewUrl: `/admin-assets/gifts/preview/${slug}.webp`,
      animationUrl: `/admin-assets/gift-models/${slug}.glb`,
      assetKey: `gifts/${g.category}/${slug}`,
      premium: rarity === 'MYTHIC' || rarity === 'LEGENDARY',
      sortOrder: i,
      metadata: { tier: rarity, order: i },
    };
  });
}
