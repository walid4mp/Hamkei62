#!/usr/bin/env python3
"""Generate the real SocialNova gift artwork (V93).

The gift engine used to render an emoji inside a rarity frame. This tool
produces an actual PNG asset per gift — a dark glassmorphism card with a
category emblem, a per-gift rune ring, a rarity aura/frame and a 4-frame
preview strip for the animation family — plus a manifest the backend seeds
into Gift.imageUrl / Gift.previewUrl.

It is deterministic: the same catalog always produces byte-identical art, so
re-running it never churns the repository.

Usage:
    node -e "..." > catalog.json      # or use --catalog <file>
    python3 tools/generate_gift_assets.py --catalog catalog.json --out backend/src/admin-assets/gifts

Admins can still replace any single file from the Asset Manager; the generator
never overwrites a file that carries a `.keep` sibling marker.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
from PIL import Image, ImageDraw, ImageFilter

SIZE = 384
PREVIEW_FRAME = 192

RARITY = {
    'COMMON':    {'aura': (154, 164, 184), 'glow': 70,  'ring': (176, 186, 206), 'spikes': 0},
    'RARE':      {'aura': (56, 189, 248),  'glow': 95,  'ring': (125, 211, 252), 'spikes': 0},
    'EPIC':      {'aura': (168, 85, 247),  'glow': 115, 'ring': (216, 180, 254), 'spikes': 12},
    'LEGENDARY': {'aura': (255, 176, 32),  'glow': 140, 'ring': (253, 224, 71),  'spikes': 20},
    'MYTHIC':    {'aura': (255, 61, 113),  'glow': 165, 'ring': (255, 214, 102), 'spikes': 28},
}

CATEGORY_TINT = {
    'love':    ((255, 79, 163), (255, 173, 214)),
    'luxury':  ((255, 196, 87), (255, 236, 179)),
    'tech':    ((0, 217, 255), (168, 85, 247)),
    'nature':  ((52, 211, 153), (250, 204, 21)),
    'food':    ((251, 146, 60), (253, 224, 71)),
    'music':   ((139, 92, 246), (34, 211, 238)),
    'sport':   ((248, 113, 113), (56, 189, 248)),
}


def seed_of(slug: str) -> int:
    return int(hashlib.sha256(slug.encode()).hexdigest()[:12], 16)


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def radial(size, center, radius, color, strength=1.0):
    """A soft radial glow layer."""
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    steps = 26
    for i in range(steps, 0, -1):
        r = radius * i / steps
        alpha = int(255 * strength * (1 - i / steps) ** 1.6)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r],
                  fill=color + (max(0, min(255, alpha)),))
    return layer.filter(ImageFilter.GaussianBlur(14))


def background(size, aura, seed):
    img = Image.new('RGBA', (size, size), (5, 7, 15, 255))
    d = ImageDraw.Draw(img)
    top, bottom = (10, 14, 32), (3, 5, 12)
    for y in range(size):
        d.line([(0, y), (size, y)], fill=lerp(top, bottom, y / size) + (255,))
    # soft glass highlight (blurred, never a hard-edged wedge)
    sheen = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    ds = ImageDraw.Draw(sheen)
    ds.polygon([(int(-size * .1), int(size * .04)), (int(size * .92), int(-size * .06)),
                (int(size * 1.12), int(size * .34)), (int(-size * .1), int(size * .46))],
               fill=(255, 255, 255, 26))
    img = Image.alpha_composite(img, sheen.filter(ImageFilter.GaussianBlur(size * .09)))
    # rarity aura, centred and subtle
    img = Image.alpha_composite(img, radial(size, (int(size * .5), int(size * .5)),
                                            int(size * .54), aura, .34))
    return img


def emblem(draw, category, cx, cy, r, c1, c2):
    """A category-defining mark, drawn from primitives (no emoji font)."""
    if category == 'love':
        draw.ellipse([cx - r, cy - r * .95, cx, cy + r * .05], fill=c1)
        draw.ellipse([cx, cy - r * .95, cx + r, cy + r * .05], fill=c1)
        draw.polygon([(cx - r * .97, cy - r * .10), (cx + r * .97, cy - r * .10),
                      (cx, cy + r)], fill=c2)
    elif category == 'luxury':
        base = cy + r * .55
        draw.polygon([(cx - r, base), (cx - r * .55, cy - r * .75), (cx - r * .18, base - r * .28),
                      (cx, cy - r * .95), (cx + r * .18, base - r * .28),
                      (cx + r * .55, cy - r * .75), (cx + r, base)], fill=c1)
        draw.rectangle([cx - r, base, cx + r, base + r * .22], fill=c2)
        for dx in (-.55, 0, .55):
            draw.ellipse([cx + r * dx - r * .12, cy - r * .55, cx + r * dx + r * .12, cy - r * .31], fill=c2)
    elif category == 'tech':
        draw.polygon([(cx - r, cy + r * .18), (cx - r * .62, cy - r * .30),
                      (cx + r * .58, cy - r * .30), (cx + r, cy + r * .18)], fill=c1)
        draw.polygon([(cx - r * .58, cy - r * .26), (cx - r * .36, cy - r * .72),
                      (cx + r * .42, cy - r * .72), (cx + r * .58, cy - r * .26)], fill=c2)
        for dx in (-.55, .55):
            draw.ellipse([cx + r * dx - r * .22, cy + r * .02, cx + r * dx + r * .22, cy + r * .46], fill=c2)
    elif category == 'nature':
        draw.polygon([(cx, cy - r), (cx + r * .82, cy - r * .12), (cx, cy + r),
                      (cx - r * .82, cy - r * .12)], fill=c1)
        draw.line([(cx, cy - r * .8), (cx, cy + r * .92)], fill=c2, width=max(2, int(r * .10)))
    elif category == 'food':
        draw.polygon([(cx - r * .72, cy - r * .18), (cx + r * .72, cy - r * .18),
                      (cx, cy + r * .82)], fill=c1)
        draw.ellipse([cx - r * .88, cy - r * .78, cx + r * .88, cy - r * .02], fill=c2)
    elif category == 'music':
        draw.ellipse([cx - r * .78, cy + r * .18, cx - r * .10, cy + r * .86], fill=c1)
        draw.ellipse([cx + r * .12, cy + r * .02, cx + r * .80, cy + r * .70], fill=c1)
        draw.rectangle([cx - r * .18, cy - r * .95, cx - r * .02, cy + r * .52], fill=c2)
        draw.rectangle([cx + r * .62, cy - r * 1.05, cx + r * .78, cy + r * .36], fill=c2)
        draw.polygon([(cx - r * .18, cy - r * .95), (cx + r * .78, cy - r * 1.05),
                      (cx + r * .78, cy - r * .70), (cx - r * .18, cy - r * .60)], fill=c2)
    else:  # sport
        draw.polygon([(cx - r * .82, cy - r * .70), (cx + r * .82, cy - r * .70),
                      (cx + r * .40, cy + r * .12), (cx - r * .40, cy + r * .12)], fill=c1)
        draw.rectangle([cx - r * .14, cy + r * .10, cx + r * .14, cy + r * .62], fill=c2)
        draw.rectangle([cx - r * .52, cy + r * .60, cx + r * .52, cy + r * .82], fill=c2)
        draw.ellipse([cx - r * .58, cy - r * .92, cx + r * .58, cy - r * .52], fill=c2)


def pattern_layer(seed, spec, c1):
    """A per-gift background pattern (6 variants) so gifts never look cloned."""
    size = SIZE
    layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    variant = seed % 6
    tint = spec['ring'] + (26,)
    if variant == 0:
        for i in range(9):
            r = size * (0.12 + i * 0.05)
            d.ellipse([size / 2 - r, size / 2 - r, size / 2 + r, size / 2 + r], outline=tint, width=1)
    elif variant == 1:
        for i in range(-size, size * 2, max(14, int(size * 0.055))):
            d.line([(i, 0), (i + size, size)], fill=tint, width=1)
    elif variant == 2:
        for i in range(0, size + 1, max(10, int(size * 0.045))):
            d.line([(0, i), (size, i)], fill=tint, width=1)
    elif variant == 3:
        step = max(12, int(size * 0.05))
        for y in range(0, size, step):
            for x in range(0, size, step):
                if ((x // step) + (y // step)) % 2 == 0:
                    d.point((x, y), fill=spec['aura'] + (70,))
                d.ellipse([x - 1, y - 1, x + 1, y + 1], fill=tint)
    elif variant == 4:
        for i in range(7):
            a = i / 7 * math.tau
            d.line([(size / 2, size / 2),
                    (size / 2 + math.cos(a) * size, size / 2 + math.sin(a) * size)],
                   fill=spec['aura'] + (18,), width=max(4, int(size * 0.03)))
    else:
        d.polygon([(0, size * 0.72), (size * 0.5, size * 0.42), (size, size * 0.74),
                   (size, size), (0, size)], fill=c1 + (16,))
    return layer.filter(ImageFilter.GaussianBlur(1.1))


def rune_ring(draw, seed, cx, cy, r, color):
    """Per-gift uniqueness: a deterministic sigil ring around the emblem."""
    segments = 14 + (seed % 9)
    for i in range(segments):
        a = (i / segments) * math.tau + (seed % 360) * math.pi / 180
        inner = r * (1.02 + ((seed >> (i % 24)) & 7) * 0.02)
        outer = inner + r * (0.06 + ((seed >> ((i * 3) % 24)) & 7) * 0.022)
        w = 1 + ((seed >> ((i * 5) % 24)) & 3)
        draw.line([(cx + math.cos(a) * inner, cy + math.sin(a) * inner),
                   (cx + math.cos(a) * outer, cy + math.sin(a) * outer)],
                  fill=color, width=w)


def rarity_frame(img, rarity, seed):
    spec = RARITY[rarity]
    size = img.size[0]
    ring = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(ring)
    pad = int(size * .055)
    d.ellipse([pad, pad, size - pad, size - pad], outline=spec['ring'] + (235,),
              width=max(3, int(size * .011)))
    d.ellipse([pad + 9, pad + 9, size - pad - 9, size - pad - 9],
              outline=spec['aura'] + (120,), width=2)
    spikes = spec['spikes']
    if spikes:
        cx = cy = size / 2
        r = size / 2 - pad + 14
        for i in range(spikes):
            a = (i / spikes) * math.tau + seed % 17
            tip = r + size * .035
            base = r - size * .012
            half = (math.tau / spikes) * .22
            d.polygon([(cx + math.cos(a - half) * base, cy + math.sin(a - half) * base),
                       (cx + math.cos(a) * tip, cy + math.sin(a) * tip),
                       (cx + math.cos(a + half) * base, cy + math.sin(a + half) * base)],
                      fill=spec['ring'] + (215,))
    return Image.alpha_composite(img, ring.filter(ImageFilter.GaussianBlur(0.6)))


def render_gift(gift):
    slug = gift['slug']
    category = gift.get('category') or 'nature'
    rarity = (gift.get('rarity') or 'COMMON').upper()
    seed = seed_of(slug)
    c1, c2 = CATEGORY_TINT.get(category, ((214, 214, 214), (255, 255, 255)))
    spec = RARITY[rarity]

    img = background(SIZE, spec['aura'], seed)

    img = Image.alpha_composite(img, pattern_layer(seed, spec, c1))

    embl = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    d = ImageDraw.Draw(embl)
    cx = cy = SIZE / 2
    rune_ring(d, seed, cx, cy, SIZE * .335, spec['ring'] + (150,))
    # per-gift pose: rotation + scale from the seed so no two gifts look alike
    embl = embl.rotate(((seed % 29) - 14) * 0.7, resample=Image.BICUBIC, center=(cx, cy))
    d = ImageDraw.Draw(embl)
    emblem(d, category, cx, cy, SIZE * .20 * (0.90 + ((seed >> 7) % 26) / 100.0),
           c1 + (255,), c2 + (255,))
    img = Image.alpha_composite(img, embl.filter(ImageFilter.GaussianBlur(0.4)))
    img = Image.alpha_composite(img, radial(SIZE, (int(cx), int(cy)),
                                            int(SIZE * .40), spec['aura'], .35))
    img = rarity_frame(img, rarity, seed)
    # premium metallic sweep
    if rarity in ('LEGENDARY', 'MYTHIC'):
        sweep = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
        ds = ImageDraw.Draw(sweep)
        ds.polygon([(0, int(SIZE * .78)), (SIZE, int(SIZE * .52)),
                    (SIZE, int(SIZE * .62)), (0, int(SIZE * .88))],
                   fill=(255, 236, 179, 46))
        img = Image.alpha_composite(img, sweep.filter(ImageFilter.GaussianBlur(10)))
    return img.convert('RGB')


def render_preview(gift):
    """A 4-frame strip showing the gift's animation family pose progression."""
    family = (gift.get('effectKey') or 'bloom')
    strip = Image.new('RGB', (PREVIEW_FRAME * 4, PREVIEW_FRAME), (5, 7, 15))
    for i in range(4):
        t = i / 3
        base = render_gift(gift).resize((PREVIEW_FRAME, PREVIEW_FRAME), Image.LANCZOS)
        f = Image.new('RGB', (PREVIEW_FRAME, PREVIEW_FRAME), (5, 7, 15))
        if family in ('rise', 'fly'):
            dy = int(PREVIEW_FRAME * (0.34 - 0.26 * t))
            dx = int(PREVIEW_FRAME * 0.18 * t) if family == 'fly' else 0
            scale = 0.72 + 0.10 * t
        elif family == 'drive':
            dy = int(PREVIEW_FRAME * (0.06 - 0.10 * t)); dx = int(PREVIEW_FRAME * (0.30 - 0.58 * t)); scale = 0.86
        elif family == 'shake':
            dy = 0; dx = int((PREVIEW_FRAME * 0.05) * (-1 if i % 2 else 1)); scale = 0.98
        elif family == 'bloom':
            dy = 0; dx = 0; scale = 0.42 + 0.18 * t
        else:  # drop
            dy = int(PREVIEW_FRAME * (-0.30 + 0.30 * t)); dx = 0; scale = 0.78 + 0.10 * t
        s = max(24, int(PREVIEW_FRAME * scale))
        small = base.resize((s, s), Image.LANCZOS)
        px = int(PREVIEW_FRAME / 2 - s / 2 + dx)
        py = int(PREVIEW_FRAME / 2 - s / 2 + dy)
        f.paste(small, (max(0, min(PREVIEW_FRAME - s, px)), max(0, min(PREVIEW_FRAME - s, py))))
        d = ImageDraw.Draw(f, 'RGBA')
        d.rectangle([0, 0, 3, PREVIEW_FRAME], fill=(255, 255, 255, 30 + i * 40))
        strip.paste(f, (i * PREVIEW_FRAME, 0))
    return strip


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--catalog', required=True, help='JSON array of gifts (slug/category/rarity/effectKey)')
    ap.add_argument('--out', required=True, help='output root, e.g. backend/src/admin-assets/gifts')
    ap.add_argument('--previews', action='store_true', default=True)
    args = ap.parse_args()

    with open(args.catalog, encoding='utf-8') as fh:
        gifts = json.load(fh)
    if isinstance(gifts, dict):
        gifts = gifts.get('gifts', [])

    written = 0
    manifest = []
    for gift in gifts:
        category = gift.get('category') or 'nature'
        folder = os.path.join(args.out, category)
        os.makedirs(folder, exist_ok=True)
        img_path = os.path.join(folder, f"{gift['slug']}.webp")
        if not os.path.exists(img_path + '.keep'):
            render_gift(gift).save(img_path, 'WEBP', quality=82, method=5)
            written += 1
        entry = {
            'slug': gift['slug'],
            'category': category,
            'rarity': gift.get('rarity'),
            'imageUrl': f"/admin-assets/gifts/{category}/{gift['slug']}.webp",
        }
        if args.previews:
            preview_dir = os.path.join(args.out, 'preview')
            os.makedirs(preview_dir, exist_ok=True)
            prev_path = os.path.join(preview_dir, f"{gift['slug']}.webp")
            if not os.path.exists(prev_path + '.keep'):
                render_preview(gift).save(prev_path, 'WEBP', quality=80, method=5)
            entry['previewUrl'] = f"/admin-assets/gifts/preview/{gift['slug']}.webp"
        manifest.append(entry)

    with open(os.path.join(args.out, 'manifest.json'), 'w', encoding='utf-8') as fh:
        json.dump({'count': len(manifest), 'gifts': manifest}, fh, ensure_ascii=False, indent=1)
    print(f"rendered {written} gift images + {len(manifest)} manifest entries into {args.out}")


if __name__ == '__main__':
    main()
