#!/usr/bin/env python3
"""Migrate the legacy in-app translation map to real ARB files (V93).

The app used to translate strings through a hand-written Dart map. This tool
reads that map and emits:

  flutter-app/lib/l10n/app_<lang>.arb      one ARB file per language
  flutter-app/lib/l10n/source_index.dart   Arabic source -> ARB key map
  flutter-app/lib/l10n/key_lookup.dart     key -> generated getter dispatch

`flutter gen-l10n` then produces AppLocalizations from the ARB files, so the
ARB files are the single source of truth and the old helper becomes a thin
adapter instead of a second system.
"""
from __future__ import annotations

import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LEGACY = os.path.join(ROOT, 'tools', 'legacy_strings.json')
SRC = os.path.join(ROOT, 'flutter-app', 'lib', 'core', 'localization.dart')
OUT = os.path.join(ROOT, 'flutter-app', 'lib', 'l10n')

LANGS = ['ar', 'en', 'fr', 'es', 'tr', 'de', 'ru', 'pt']

# Portuguese is a target language in the V93 spec but was never translated in
# the legacy map. Only the reviewed core UI strings are provided here; anything
# missing falls back to English on purpose and is reported as partial coverage.
PT_CORE = {
    'الإعدادات': 'Configurações',
    'اللغة': 'Idioma',
    'حفظ': 'Guardar',
    'إلغاء': 'Cancelar',
    'تأكيد': 'Confirmar',
    'إعادة المحاولة': 'Tentar novamente',
    'الكل': 'Tudo',
    'الرئيسية': 'Início',
    'استكشاف': 'Explorar',
    'إنشاء': 'Criar',
    'حسابي': 'Meu perfil',
    'الرسائل': 'Mensagens',
    'الإشعارات': 'Notificações',
    'المجموعات': 'Grupos',
    'المتابعون': 'Seguidores',
    'متابعة': 'Seguir',
    'يتابع': 'A seguir',
    'منشورات': 'Publicações',
    'منشور': 'Publicação',
    'المنشور': 'Publicação',
    'الريلز': 'Reels',
    'الستوري': 'Story',
    'التعليقات': 'Comentários',
    'رد': 'Responder',
    'إعادة نشر': 'Repostar',
    'الخصوصية': 'Privacidade',
    'عام': 'Público',
    'الخاصة': 'Privado',
    'المتابعون فقط': 'Apenas seguidores',
    'حذف': 'Eliminar',
    'تعديل': 'Editar',
    'الموسيقى': 'Música',
    'المشاهدات': 'Visualizações',
    'الإعجابات': 'Gostos',
    'المشاركات': 'Partilhas',
    'السماح بالتعليقات': 'Permitir comentários',
    'السماح بالردود': 'Permitir respostas',
    'طلبات المراسلة': 'Pedidos de mensagem',
    'إعدادات المحادثة': 'Definições da conversa',
    'لا توجد محادثات بعد': 'Ainda não há conversas',
    'إرسال': 'Enviar',
    'بحث': 'Pesquisar',
    'إنشاء حساب': 'Criar conta',
    'تسجيل الدخول': 'Iniciar sessão',
    'الاسم الكامل': 'Nome completo',
    'اسم المستخدم': 'Nome de utilizador',
    'كلمة المرور': 'Palavra-passe',
    'تاريخ الميلاد': 'Data de nascimento',
    'الجنس': 'Género',
    'ذكر': 'Masculino',
    'أنثى': 'Feminino',
    'الموقع': 'Localização',
    'الوصف': 'Descrição',
    'عنوان': 'Título',
    'هدية': 'Presente',
    'إرسال هدية': 'Enviar presente',
    'الآن': 'Agora mesmo',
    'أرشفة': 'Arquivar',
    'كتم الصوت': 'Sem som',
    'مكبر الصوت': 'Altifalante',
    'مشاركة': 'Partilhar',
    'خلفية المحادثة': 'Fundo da conversa',
    'الجمهور': 'Público-alvo',
    'تحديد الجمهور': 'Escolher público',
}

ENTRY = re.compile(r"'((?:[^'\\]|\\.)*)'\s*:\s*\{([^}]*)\}", re.S)
KV = re.compile(r"'([a-z]{2})'\s*:\s*(?:\"((?:[^\"\\]|\\.)*)\"|'((?:[^'\\]|\\.)*)')")


def unescape(v: str) -> str:
    return v.replace("\\'", "'").replace('\\"', '"').replace('\\\\', '\\')


def read_legacy() -> dict:
    # The strings originally lived in core/localization.dart; that file is now
    # a thin adapter over the ARB files, so the extracted data is kept here and
    # this tool stays re-runnable without editing source code.
    if os.path.exists(LEGACY):
        return json.load(open(LEGACY, encoding='utf-8'))
    text = open(SRC, encoding='utf-8').read()
    entries: dict[str, dict[str, str]] = {}
    for m in ENTRY.finditer(text):
        source = unescape(m.group(1))
        body = m.group(2)
        row = {}
        for kv in KV.finditer(body):
            lang = kv.group(1)
            value = kv.group(2) if kv.group(2) is not None else kv.group(3)
            row[lang] = unescape(value)
        if row and ('ar' in row or any(l in row for l in ('en', 'fr'))):
            # merge duplicates, later wins
            entries.setdefault(source, {}).update(row)
    return entries


def main():
    os.makedirs(OUT, exist_ok=True)
    entries = read_legacy()

    # Arabic sources get a stable ascii key; keys that are already ascii
    # (the settings/language block) keep their own name so existing call sites
    # such as L10n.text('chooseLanguage') keep working unchanged.
    sources = sorted(entries.keys())
    ascii_re = re.compile(r'^[a-zA-Z][a-zA-Z0-9_]*$')
    counter = 0
    key_of = {}
    for src in sources:
        if ascii_re.match(src):
            key_of[src] = src
        else:
            counter += 1
            key_of[src] = f"s{counter:04d}"

    arb: dict[str, dict[str, str]] = {lang: {} for lang in LANGS}
    for src, row in entries.items():
        key = key_of[src]
        arb['ar'][key] = row.get('ar', src)
        for lang in LANGS:
            if lang == 'ar':
                continue
            value = row.get(lang)
            if lang == 'pt':
                value = PT_CORE.get(src) or value
            if value:
                arb[lang][key] = value
            else:
                arb[lang][key] = arb['en'].get(key) or row.get('en') or src

    # Portuguese core added for sources the legacy map never translated
    for src, pt in PT_CORE.items():
        if src in key_of:
            arb['pt'][key_of[src]] = pt

    for lang in LANGS:
        payload = {'@@locale': lang}
        payload.update({k: arb[lang][k] for k in sorted(arb[lang])})
        with open(os.path.join(OUT, f'app_{lang}.arb'), 'w', encoding='utf-8') as fh:
            json.dump(payload, fh, ensure_ascii=False, indent=2)
            fh.write('\n')

    with open(os.path.join(OUT, 'source_index.dart'), 'w', encoding='utf-8') as fh:
        fh.write('// GENERATED by tools/generate_l10n.py — do not edit by hand.\n')
        fh.write('/// Maps a source string (usually Arabic) to its ARB key.\n')
        fh.write('const Map<String, String> kSourceIndex = {\n')
        for src in sources:
            escaped = src.replace('\\', '\\\\').replace("'", "\\'").replace('$', r'\$')
            fh.write(f"  '{escaped}': '{key_of[src]}',\n")
        fh.write('};\n')

    with open(os.path.join(OUT, 'key_lookup.dart'), 'w', encoding='utf-8') as fh:
        fh.write('// GENERATED by tools/generate_l10n.py — do not edit by hand.\n')
        fh.write("import 'package:flutter_gen/gen_l10n/app_localizations.dart';\n\n")
        fh.write('/// Resolves an ARB key against a generated [AppLocalizations].\n')
        fh.write('String lookupLocalizedKey(AppLocalizations l, String key) {\n')
        fh.write('  switch (key) {\n')
        for src in sources:
            key = key_of[src]
            fh.write(f"    case '{key}':\n      return l.{key};\n")
        fh.write('    default:\n      return key;\n')
        fh.write('  }\n}\n')

    missing_pt = sum(1 for k in arb['pt'] if k not in PT_CORE.values() and not entries.get(
        next((s for s, kk in key_of.items() if kk == k), ''), {}).get('pt'))
    print(f"languages: {', '.join(LANGS)}")
    print(f"strings: {len(sources)}")
    print(f"portuguese reviewed strings: {len(PT_CORE)} (the rest fall back to English)")


if __name__ == '__main__':
    main()
