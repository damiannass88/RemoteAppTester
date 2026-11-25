"""Generuje lib/translations.dart w desktop_app i android_app z tool/i18n/translations.py.

Do każdej aplikacji trafiają tylko klucze, których używa (tr('...') w lib/), plus teksty
podawane do tr() dynamicznie (np. nazwy typów projektów z rdzenia hosta).
Wypisuje klucze bez tłumaczenia — wtedy zostaje tekst polski.
"""
import glob
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from guide import INTRO, LABEL_ADVANCED, LABEL_IMPORTANT, SECTIONS  # noqa: E402
from translations import T  # noqa: E402
from translations_cli import T_CLI  # noqa: E402

TR_CALL = re.compile(r"\btr\('((?:[^'\\]|\\.)*)'")
# Teksty przekazywane do tr() przez zmienną.
DYNAMIC = {
    'desktop_app': ['Inny', 'Android (Gradle)', 'Flutter', 'React Native', 'Capacitor'],
    'android_app': [],
    'host': ['Inny', 'Android (Gradle)', 'Flutter', 'React Native', 'Capacitor'],
}

table = {}
for row in T + T_CLI:
    if row[0] in table and table[row[0]] != row[1:]:
        print('DUPLIKAT:', row[0])
    table[row[0]] = row[1:]


def dart(s):
    return "'" + re.sub(r"(?<!\\)'", r"\\'", s) + "'"


missing_any = False
for app in ['desktop_app', 'android_app', 'host']:
    keys = set(DYNAMIC[app])
    for f in glob.glob(os.path.join(ROOT, app, 'lib', '**', '*.dart'), recursive=True):
        if 'generated' in f or f.endswith('translations.dart'):
            continue
        keys |= set(TR_CALL.findall(open(f, encoding='utf-8').read()))
    missing = sorted(k for k in keys if k not in table)
    for k in missing:
        print(f'{app}: BRAK TŁUMACZENIA: {k}')
        missing_any = True
    lines = ['// Wygenerowane przez tool/i18n/generate.py z tool/i18n/translations.py — nie edytuj ręcznie.',
             '// Klucz = tekst polski (tr() w kodzie).', '']
    for idx, name in enumerate(['En', 'De', 'Cs']):
        lines.append(f'const Map<String, String> translations{name} = {{')
        for k in sorted(keys):
            if k in table:
                lines.append(f'  {dart(k)}: {dart(table[k][idx])},')
        lines.append('};')
        lines.append('')
    open(os.path.join(ROOT, app, 'lib', 'translations.dart'), 'w', encoding='utf-8', newline='\n').write('\n'.join(lines))
    print(f'{app}: {len(keys)} kluczy, brak: {len(missing)}')


def lit(s):
    return "'" + s.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$').replace('\n', '\\n') + "'"


guide = [
    '// Wygenerowane przez tool/i18n/generate.py z tool/i18n/guide.py — nie edytuj ręcznie.',
    '',
    'class GuideItem {',
    '  const GuideItem(this.question, this.answer, {this.important = false, this.advanced = false});',
    '  final String question;',
    '  final String answer;',
    '  final bool important;',
    '  final bool advanced;',
    '}',
    '',
    'class GuideSection {',
    '  const GuideSection(this.id, this.title, this.items);',
    '  final String id;',
    '  final String title;',
    '  final List<GuideItem> items;',
    '}',
    '',
    'class Guide {',
    '  const Guide(this.intro, this.importantLabel, this.advancedLabel, this.sections);',
    '  final String intro;',
    '  final String importantLabel;',
    '  final String advancedLabel;',
    '  final List<GuideSection> sections;',
    '}',
    '',
    'const guides = <String, Guide>{',
]
for idx, code in enumerate(['pl', 'en', 'de', 'cs']):
    guide.append(f'  {lit(code)}: Guide(')
    guide.append(f'    {lit(INTRO[idx])},')
    guide.append(f'    {lit(LABEL_IMPORTANT[idx])},')
    guide.append(f'    {lit(LABEL_ADVANCED[idx])},')
    guide.append('    [')
    for sid, title, items in SECTIONS:
        guide.append(f'      GuideSection({lit(sid)}, {lit(title[idx])}, [')
        for q, a, important, advanced in items:
            flags = ('important: true, ' if important else '') + ('advanced: true, ' if advanced else '')
            guide.append(f'        GuideItem({lit(q[idx])}, {lit(a[idx])}, {flags}),'.replace(', ),', '),'))
        guide.append('      ]),')
    guide.append('    ],')
    guide.append('  ),')
guide.append('};')
guide.append('')
text = '\n'.join(guide)
for target in ['desktop_app/lib/guide_content.dart', 'android_app/lib/guide_content.dart', 'host/lib/cli/guide_content.dart']:
    open(os.path.join(ROOT, target), 'w', encoding='utf-8', newline='\n').write(text)
print('guide:', sum(len(s[2]) for s in SECTIONS), 'pozycji')
sys.exit(1 if missing_any else 0)
