"""Animated SVG illustrations for README.md / README.pl.md.

GitHub shows SVG files as images and plays their CSS animations (no JavaScript, no video
hosting). The texts follow the real app (tool/i18n/translations.py), shortened to fit.

    python tool/readme/make_art.py      # writes docs/assets/readme/*-{en,pl}.svg
"""
from __future__ import annotations

import os
from html import escape

OUT = os.path.join(os.path.dirname(__file__), '..', '..', 'docs', 'assets', 'readme')

SANS = "-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif"
MONO = "ui-monospace,SFMono-Regular,Consolas,'Liberation Mono',Menlo,monospace"

# Colours of the app (android_app/lib/ui/app_theme.dart: indigo light, navy dark).
NAVY_BG = '#0B1426'
NAVY = '#1E3A8A'
NAVY_CARD = '#122039'
NAVY_LINE = '#4A5E85'
ACCENT = '#9DB4FF'
ON_NAVY = '#DCE3FF'
PRIMARY = '#4355B9'
SURFACE = '#FBF8FF'
OUTLINE = '#E3E1EC'
TEXT = '#1B1B21'
MUTED = '#5D5E72'
GREEN = '#16A34A'
AMBER = '#D97706'
BLUE = '#2563EB'


class Anim:
    """Collects CSS keyframes for one looping timeline of T seconds."""

    def __init__(self, period: float):
        self.T = period
        self.css: list[str] = []
        self.n = 0

    def _pct(self, t: float) -> str:
        return f'{max(0.0, min(100.0, t / self.T * 100)):.2f}%'

    def frames(self, steps: list[tuple[float, str]]) -> str:
        """Returns a class name animating through (time, css) steps."""
        self.n += 1
        name = f'a{self.n}'
        body = ' '.join(f'{self._pct(t)}{{{css}}}' for t, css in steps)
        self.css.append(f'@keyframes {name}{{{body}}}'
                        f'.{name}{{animation:{name} {self.T}s linear infinite}}')
        return name

    def show(self, start: float, end: float, fade: float = 0.3) -> str:
        """Visible between start and end (seconds), hidden otherwise."""
        steps = [(0, 'opacity:0')] if start > 0 else [(0, 'opacity:1')]
        if start > 0:
            steps += [(start, 'opacity:0'), (start + fade, 'opacity:1')]
        if end < self.T:
            steps += [(end, 'opacity:1'), (min(self.T, end + fade), 'opacity:0'), (self.T, 'opacity:0')]
        else:
            steps += [(self.T, 'opacity:1')]
        return self.frames(steps)

    def style(self) -> str:
        return ('<style>' + ''.join(self.css) +
                '*{transform-box:fill-box}'
                '@media (prefers-reduced-motion:reduce){*{animation-duration:0s!important}}</style>')


def text(x, y, s, size=14, fill=TEXT, weight=400, anchor='start', family=SANS, cls='', extra=''):
    c = f' class="{cls}"' if cls else ''
    return (f'<text x="{x}" y="{y}" font-family="{family}" font-size="{size}" fill="{fill}" '
            f'font-weight="{weight}" text-anchor="{anchor}"{c}{extra}>{escape(s)}</text>')


def svg(w, h, body, anim: Anim | None, title: str) -> str:
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" '
            f'role="img" aria-label="{escape(title)}"><title>{escape(title)}</title>'
            + (anim.style() if anim else '') + body + '</svg>\n')


# --------------------------------------------------------------------------- hero

def hero(L) -> str:
    a = Anim(6)
    b = [
        '<defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{NAVY_BG}"/><stop offset="1" stop-color="{NAVY}"/></linearGradient></defs>',
        '<rect width="960" height="300" rx="18" fill="url(#g)"/>',
        f'<circle cx="900" cy="20" r="120" fill="{ACCENT}" opacity="0.06"/>',
        f'<circle cx="560" cy="300" r="90" fill="{ACCENT}" opacity="0.05"/>',
        text(48, 100, 'RemoteAppTester', 44, '#FFFFFF', 700),
        text(48, 146, L['tag1'], 21, ON_NAVY, 500),
        text(48, 175, L['tag2'], 21, ON_NAVY, 500),
        text(48, 214, L['sub'], 15, ACCENT),
    ]
    x = 48
    for chip in L['chips']:
        w = len(chip) * 7.4 + 26
        b.append(f'<rect x="{x}" y="238" width="{w:.0f}" height="28" rx="14" fill="{NAVY_CARD}" stroke="{NAVY_LINE}"/>')
        b.append(text(x + w / 2, 257, chip, 13, ON_NAVY, 500, 'middle'))
        x += w + 8

    # Computer with the AI agent writing code.
    b.append(f'<rect x="596" y="70" width="176" height="116" rx="10" fill="{NAVY_CARD}" stroke="{NAVY_LINE}" stroke-width="2"/>')
    b.append(f'<rect x="664" y="186" width="40" height="16" fill="{NAVY_LINE}"/><rect x="640" y="202" width="88" height="6" rx="3" fill="{NAVY_LINE}"/>')
    for i, (w, c) in enumerate([(70, ACCENT), (110, '#7DD3FC'), (90, '#C4B5FD'), (124, ACCENT), (60, '#86EFAC')]):
        cls = a.show(0.3 + i * 0.35, 5.6)
        b.append(f'<rect class="{cls}" x="{612 + (12 if i in (1, 2) else 0)}" y="{86 + i * 18}" width="{w}" height="8" rx="4" fill="{c}" opacity="0.9"/>')
    b.append(text(684, 232, L['pc'], 12, ACCENT, 500, 'middle'))

    # Tailscale link with a moving packet.
    b.append(f'<line x1="776" y1="128" x2="850" y2="128" stroke="{NAVY_LINE}" stroke-width="3" stroke-dasharray="6 6"/>')
    b.append(text(813, 116, 'Tailscale', 11, ACCENT, 600, 'middle'))
    mv = a.frames([(0, 'transform:translateX(0);opacity:0'), (2.2, 'transform:translateX(0);opacity:0'),
                   (2.3, 'transform:translateX(0);opacity:1'), (3.3, 'transform:translateX(66px);opacity:1'),
                   (3.4, 'transform:translateX(66px);opacity:0'), (6, 'transform:translateX(66px);opacity:0')])
    b.append(f'<rect class="{mv}" x="778" y="121" width="14" height="14" rx="3" fill="#86EFAC"/>')

    # Phone that receives the app.
    b.append(f'<rect x="856" y="62" width="76" height="140" rx="14" fill="#0F172A" stroke="{NAVY_LINE}" stroke-width="2"/>')
    b.append(f'<rect x="862" y="72" width="64" height="120" rx="9" fill="{SURFACE}"/>')
    prog = a.frames([(0, 'transform:scaleX(0)'), (3.3, 'transform:scaleX(0)'), (4.2, 'transform:scaleX(1)'), (6, 'transform:scaleX(1)')])
    pb = a.show(3.3, 4.3, 0.1)
    b.append(f'<g class="{pb}"><rect x="870" y="128" width="48" height="6" rx="3" fill="{OUTLINE}"/>'
             f'<rect class="{prog}" x="870" y="128" width="48" height="6" rx="3" fill="{PRIMARY}" style="transform-origin:left"/></g>')
    ok = a.show(4.3, 5.8)
    b.append(f'<g class="{ok}"><circle cx="894" cy="124" r="17" fill="{GREEN}"/>'
             '<path d="M886 124 l6 6 l11 -12" fill="none" stroke="#fff" stroke-width="3.5" stroke-linecap="round" stroke-linejoin="round"/></g>')
    b.append(text(894, 232, L['phone'], 12, ACCENT, 500, 'middle'))
    return svg(960, 300, ''.join(b), a, L['hero_title'])


# --------------------------------------------------------------------------- workflow

def icon(kind: str, cx: float, cy: float, color: str) -> str:
    if kind == 'chat':
        return (f'<rect x="{cx-18}" y="{cy-14}" width="36" height="24" rx="7" fill="none" stroke="{color}" stroke-width="2.5"/>'
                f'<path d="M{cx-8} {cy+10} l-4 8 l10 -8" fill="{color}"/>'
                f'<circle cx="{cx-8}" cy="{cy-2}" r="2.2" fill="{color}"/><circle cx="{cx}" cy="{cy-2}" r="2.2" fill="{color}"/><circle cx="{cx+8}" cy="{cy-2}" r="2.2" fill="{color}"/>')
    if kind == 'code':
        return (f'<path d="M{cx-8} {cy-11} l-11 11 l11 11 M{cx+8} {cy-11} l11 11 l-11 11 M{cx+4} {cy-14} l-8 28" '
                f'fill="none" stroke="{color}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>')
    if kind == 'build':
        return (f'<path d="M{cx} {cy-17} l16 8 v18 l-16 8 l-16 -8 v-18 z M{cx-16} {cy-9} l16 8 l16 -8 M{cx} {cy-1} v18" '
                f'fill="none" stroke="{color}" stroke-width="2.4" stroke-linejoin="round"/>')
    return (f'<rect x="{cx-11}" y="{cy-19}" width="22" height="38" rx="5" fill="none" stroke="{color}" stroke-width="2.5"/>'
            f'<path d="M{cx-5} {cy} l4 4 l7 -8" fill="none" stroke="{GREEN}" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>')


def workflow(L) -> str:
    a = Anim(10)
    b = [f'<rect width="960" height="250" rx="18" fill="{SURFACE}" stroke="{OUTLINE}"/>']
    xs = [24, 258, 492, 726]
    kinds = ['chat', 'code', 'build', 'phone']
    for i, (x, kind, (title, l1, l2)) in enumerate(zip(xs, kinds, L['steps'])):
        on = a.frames([(0, 'opacity:0'), (i * 2.5, 'opacity:0'), (i * 2.5 + 0.3, 'opacity:1'),
                       (i * 2.5 + 2.4, 'opacity:1'), (i * 2.5 + 2.7, 'opacity:0'), (10, 'opacity:0')])
        b.append(f'<rect x="{x}" y="24" width="210" height="196" rx="16" fill="#FFFFFF" stroke="{OUTLINE}" stroke-width="1.5"/>')
        b.append(f'<rect class="{on}" x="{x}" y="24" width="210" height="196" rx="16" fill="#EEF0FF" stroke="{PRIMARY}" stroke-width="2.5"/>')
        b.append(f'<circle cx="{x+30}" cy="54" r="15" fill="{PRIMARY}"/>' + text(x + 30, 59, str(i + 1), 15, '#fff', 700, 'middle'))
        b.append(icon(kind, x + 105, 92, PRIMARY))
        b.append(text(x + 105, 150, title, 15, TEXT, 700, 'middle'))
        b.append(text(x + 105, 174, l1, 12.5, MUTED, 400, 'middle', MONO if l1.startswith('rt ') else SANS))
        b.append(text(x + 105, 194, l2, 12.5, MUTED, 400, 'middle', MONO if l2.startswith('rt ') else SANS))
        if i < 3:
            b.append(f'<path d="M{x+214} 122 h16 m-6 -6 l6 6 l-6 6" fill="none" stroke="{PRIMARY}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>')
    b.append(text(480, 240, L['loop'], 12, MUTED, 500, 'middle'))
    return svg(960, 250, ''.join(b), a, L['flow_title'])


# --------------------------------------------------------------------------- phones

def phone_frame(x: int, title: str, body: str, dark=False) -> str:
    bg = NAVY_BG if dark else SURFACE
    fg = ON_NAVY if dark else TEXT
    # The screen clips its content, so sliding panels never spill outside the phone.
    return (f'<defs><clipPath id="screen{x}"><rect x="{x+10}" y="30" width="230" height="450" rx="26"/></clipPath></defs>'
            f'<g><rect x="{x}" y="20" width="250" height="470" rx="34" fill="#0F172A"/>'
            f'<rect x="{x+10}" y="30" width="230" height="450" rx="26" fill="{bg}"/>'
            f'<g clip-path="url(#screen{x})">'
            + (text(x + 28, 86, title, 18, fg, 600) if title else '') + body + '</g>'
            f'<rect x="{x+100}" y="38" width="50" height="8" rx="4" fill="#0F172A"/></g>')


def bar(x, y, color, line1, line2, extra='') -> str:
    tint = {'blue': ('#E0EAFF', BLUE), 'amber': ('#FEF3C7', AMBER), 'green': ('#DCFCE7', GREEN)}[color]
    return (f'<rect x="{x}" y="{y}" width="230" height="58" fill="{tint[0]}"/>'
            f'<circle cx="{x+20}" cy="{y+22}" r="8" fill="{tint[1]}"/>'
            + text(x + 36, y + 22, line1, 12, TEXT, 600) + text(x + 36, y + 40, line2, 11.5, MUTED) + extra)


def btn(x, y, w, label, filled=True, cls='') -> str:
    c = f' class="{cls}"' if cls else ''
    if filled:
        return (f'<g{c}><rect x="{x}" y="{y}" width="{w}" height="26" rx="13" fill="{PRIMARY}"/>'
                + text(x + w / 2, y + 17, label, 11.5, '#fff', 600, 'middle') + '</g>')
    return f'<g{c}>' + text(x + w / 2, y + 17, label, 11.5, PRIMARY, 600, 'middle') + '</g>'


def card(x, y, name, sub, chip='', chip_color=PRIMARY) -> str:
    out = (f'<rect x="{x}" y="{y}" width="206" height="58" rx="12" fill="#FFFFFF" stroke="{OUTLINE}"/>'
           f'<rect x="{x+12}" y="{y+13}" width="32" height="32" rx="8" fill="#E8EAFF"/>'
           + text(x + 54, y + 26, name, 13, TEXT, 600) + text(x + 54, y + 44, sub, 11, MUTED))
    if chip:
        # A dot on the right edge ("new changes"); the label is in the title for screen readers.
        out += (f'<circle cx="{x+190}" cy="{y+29}" r="6" fill="{chip_color}"><title>{escape(chip)}</title></circle>')
    return out


def fingerprint(cx, cy, color) -> str:
    arcs = ''.join(
        f'<path d="M{cx-r} {cy+r*0.5} A{r} {r*1.15} 0 1 1 {cx+r} {cy+r*0.5}" fill="none" stroke="{color}" '
        f'stroke-width="3" stroke-linecap="round"/>' for r in (8, 15, 22, 29))
    return arcs + f'<path d="M{cx} {cy-2} v18" stroke="{color}" stroke-width="3" stroke-linecap="round"/>'


def phones(L) -> str:
    a = Anim(12)
    b = [f'<rect width="960" height="560" rx="18" fill="#F1F2FA"/>']

    # 1. Fingerprint lock.
    x = 40
    pulse = a.frames([(0, 'transform:scale(1);opacity:.35'), (1.2, 'transform:scale(1.35);opacity:0'),
                      (1.21, 'transform:scale(1);opacity:.35'), (2.4, 'transform:scale(1.35);opacity:0'),
                      (2.41, 'transform:scale(1);opacity:.35'), (3.6, 'transform:scale(1.35);opacity:0'), (12, 'opacity:0')])
    locked = a.show(0, 4.0)
    unlocked = a.show(4.0, 11.5)
    body = (f'<g class="{locked}">'
            f'<circle class="{pulse}" cx="{x+125}" cy="250" r="46" fill="{ACCENT}" style="transform-origin:center"/>'
            f'<circle cx="{x+125}" cy="250" r="46" fill="{NAVY_CARD}" stroke="{NAVY_LINE}"/>'
            + fingerprint(x + 125, 246, ACCENT)
            + text(x + 125, 150, 'RemoteAppTester', 18, '#fff', 700, 'middle')
            + text(x + 125, 174, L['locked'], 13, ACCENT, 400, 'middle')
            + f'<rect x="{x+40}" y="330" width="170" height="40" rx="20" fill="{ACCENT}"/>'
            + text(x + 125, 355, L['unlock'], 12.5, '#0B1A4A', 700, 'middle')
            + text(x + 125, 400, L['pin'], 12, ACCENT, 500, 'middle') + '</g>'
            + f'<g class="{unlocked}"><circle cx="{x+125}" cy="250" r="46" fill="{GREEN}"/>'
            f'<path d="M{x+104} 250 l14 14 l26 -28" fill="none" stroke="#fff" stroke-width="6" stroke-linecap="round" stroke-linejoin="round"/>'
            + text(x + 125, 340, L['unlocked'], 15, '#fff', 600, 'middle') + '</g>')
    b.append(phone_frame(x, '', body, dark=True))
    b.append(text(x + 125, 524, L['cap1'], 15, TEXT, 700, 'middle'))
    b.append(text(x + 125, 544, L['cap1b'], 12.5, MUTED, 400, 'middle'))

    # 2. Delivery of a new version.
    x = 355
    s_dl, s_ask, s_inst, s_done = a.show(0.3, 4), a.show(4, 7.4), a.show(7.4, 8.8), a.show(8.8, 11.6)
    grow = a.frames([(0, 'transform:scaleX(.05)'), (0.3, 'transform:scaleX(.05)'), (3.9, 'transform:scaleX(1)'), (12, 'transform:scaleX(1)')])
    tap = a.frames([(0, 'transform:scale(1)'), (6.4, 'transform:scale(1)'), (6.6, 'transform:scale(.88)'), (6.9, 'transform:scale(1)'), (12, 'transform:scale(1)')])
    y = 100
    body = (f'<g class="{s_dl}">' + bar(x + 10, y, 'blue', L['dl1'], L['dl2'],
                                        f'<rect x="{x+46}" y="{y+49}" width="180" height="4" rx="2" fill="#C7D2FE"/>'
                                        f'<rect class="{grow}" x="{x+46}" y="{y+49}" width="180" height="4" rx="2" fill="{BLUE}" style="transform-origin:left"/>') + '</g>'
            + f'<g class="{s_ask}">' + bar(x + 10, y, 'amber', L['ask1'], '') +
            btn(x + 120, y + 28, 50, L['skip'], False) + btn(x + 172, y + 28, 62, L['install'], True, tap) + '</g>'
            + f'<g class="{s_inst}">' + bar(x + 10, y, 'blue', L['inst1'], L['inst2']) + '</g>'
            + f'<g class="{s_done}">' + bar(x + 10, y, 'green', L['done1'], '') + btn(x + 162, y + 28, 70, L['launch'], False) + '</g>'
            + card(x + 22, 176, L['p1'], 'Flutter · Android', L['newchg'], AMBER)
            + card(x + 22, 244, L['p2'], 'Vite · web')
            + card(x + 22, 312, L['p3'], 'Flutter · Android')
            + f'<circle cx="{x+204}" cy="440" r="24" fill="{PRIMARY}"/>'
            + f'<path d="M{x+204} 430 v20 M{x+194} 440 h20" stroke="#fff" stroke-width="3" stroke-linecap="round"/>')
    b.append(phone_frame(x, L['projects'], body))
    b.append(text(x + 125, 524, L['cap2'], 15, TEXT, 700, 'middle'))
    b.append(text(x + 125, 544, L['cap2b'], 12.5, MUTED, 400, 'middle'))

    # 3. Website preview with "Report a problem".
    x = 670
    sheet = a.frames([(0, 'transform:translateY(220px)'), (3, 'transform:translateY(220px)'), (3.5, 'transform:translateY(0)'),
                      (7.5, 'transform:translateY(0)'), (8, 'transform:translateY(220px)'), (12, 'transform:translateY(220px)')])
    typed = a.frames([(0, 'transform:scaleX(0)'), (4, 'transform:scaleX(0)'), (6, 'transform:scaleX(1)'), (12, 'transform:scaleX(1)')])
    press = a.frames([(0, 'transform:scale(1)'), (2.5, 'transform:scale(1)'), (2.7, 'transform:scale(.9)'), (2.9, 'transform:scale(1)'), (12, 'transform:scale(1)')])
    toast = a.show(8.1, 10.6)
    body = (f'<rect x="{x+22}" y="100" width="206" height="250" rx="10" fill="#FFFFFF" stroke="{OUTLINE}"/>'
            f'<rect x="{x+22}" y="100" width="206" height="36" rx="10" fill="#0EA5E9"/><rect x="{x+22}" y="120" width="206" height="16" fill="#0EA5E9"/>'
            + text(x + 36, 123, L['site'], 13, '#fff', 700)
            + f'<rect x="{x+36}" y="150" width="150" height="12" rx="6" fill="#CBD5E1"/>'
            f'<rect x="{x+36}" y="170" width="110" height="12" rx="6" fill="#E2E8F0"/>'
            f'<rect x="{x+36}" y="196" width="178" height="80" rx="10" fill="#E0F2FE"/>'
            f'<rect x="{x+36}" y="290" width="84" height="30" rx="15" fill="#0EA5E9"/>'
            f'<rect x="{x+128}" y="290" width="86" height="30" rx="15" fill="#F97316" opacity="0.85"/>'
            + f'<g class="{press}" style="transform-origin:center"><rect x="{x+40}" y="370" width="170" height="36" rx="18" fill="#FEE2E2" stroke="#EF4444"/>'
            + text(x + 125, 393, '⚑ ' + L['report'], 12.5, '#B91C1C', 700, 'middle') + '</g>'
            + f'<g class="{sheet}"><rect x="{x+10}" y="300" width="230" height="180" rx="22" fill="#FFFFFF" stroke="{OUTLINE}"/>'
            f'<rect x="{x+105}" y="310" width="40" height="5" rx="2.5" fill="{OUTLINE}"/>'
            + text(x + 28, 340, L['report'], 14, TEXT, 700)
            + f'<rect x="{x+28}" y="352" width="194" height="54" rx="8" fill="{SURFACE}" stroke="{OUTLINE}"/>'
            + f'<g class="{typed}" style="transform-origin:left">' + text(x + 38, 374, L['note1'], 12, TEXT) + text(x + 38, 392, L['note2'], 12, TEXT) + '</g>'
            + text(x + 28, 426, L['console'], 11, MUTED)
            + btn(x + 150, 438, 72, L['send']) + '</g>'
            + f'<g class="{toast}"><rect x="{x+26}" y="420" width="198" height="40" rx="10" fill="#1F2937"/>'
            + text(x + 125, 445, L['saved'], 12, '#fff', 500, 'middle') + '</g>')
    b.append(phone_frame(x, L['preview'], body))
    b.append(text(x + 125, 524, L['cap3'], 15, TEXT, 700, 'middle'))
    b.append(text(x + 125, 544, L['cap3b'], 12.5, MUTED, 400, 'middle'))
    return svg(960, 560, ''.join(b), a, L['phones_title'])


# --------------------------------------------------------------------------- terminal

def terminal(L) -> str:
    a = Anim(16)
    bg = '#0D1117'
    b = [f'<rect width="960" height="340" rx="14" fill="{bg}"/>',
         '<rect width="960" height="36" rx="14" fill="#161B22"/><rect y="22" width="960" height="14" fill="#161B22"/>',
         '<circle cx="22" cy="18" r="6" fill="#FF5F56"/><circle cx="42" cy="18" r="6" fill="#FFBD2E"/><circle cx="62" cy="18" r="6" fill="#27C93F"/>',
         text(480, 23, L['term_title'], 12.5, '#8B949E', 500, 'middle', MONO)]
    lines = L['term']
    t = 0.4
    y = 70
    for kind, s in lines:
        color = {'you': '#E6EDF3', 'agent': '#8B949E', 'cmd': '#E6EDF3', 'out': '#C9D1D9', 'ok': '#3FB950', 'say': '#A5D6FF'}[kind]
        prefix = {'you': '❯ ', 'agent': '● ', 'cmd': '$ ', 'out': '  ', 'ok': '  ✔ ', 'say': '● '}[kind]
        show = a.show(t, 15.4, 0.2)
        if kind == 'cmd':
            # Typed command: a cover slides away from the text.
            dur = 0.05 * len(s)
            cover = a.frames([(0, 'transform:translateX(0)'), (t + 0.2, 'transform:translateX(0)'),
                              (t + 0.2 + dur, f'transform:translateX({len(s) * 8.4 + 30:.0f}px)'), (16, f'transform:translateX({len(s) * 8.4 + 30:.0f}px)')])
            b.append(f'<g class="{show}">' + text(28, y, prefix, 14, '#3FB950', 700, family=MONO)
                     + text(46, y, s, 14, color, 600, family=MONO)
                     + f'<rect class="{cover}" x="46" y="{y-16}" width="{len(s) * 8.4 + 30:.0f}" height="22" fill="{bg}"/></g>')
            t += dur + 0.9
        else:
            weight = 600 if kind in ('you', 'ok') else 400
            b.append(f'<g class="{show}">' + text(28, y, prefix + s, 14, color, weight, family=MONO) + '</g>')
            t += {'you': 1.4, 'agent': 0.9, 'out': 1.6, 'ok': 0.9, 'say': 0.6}[kind]
        y += 30
    caret = a.frames([(0, 'opacity:1'), (8, 'opacity:1'), (8.01, 'opacity:0'), (16, 'opacity:0')])
    b.append(f'<rect x="28" y="{y-16}" width="9" height="18" fill="#E6EDF3" opacity=".7" class="{caret}"/>')
    return svg(960, 340, ''.join(b), a, L['term_title'])


EN = dict(
    hero_title='RemoteAppTester: talk to your AI agent, get the app on your phone',
    tag1='Tell your AI agent what to build.', tag2='Get the new version on your phone, automatically.',
    sub='Build anywhere · Test on Android · Work fully remote',
    chips=['Windows', 'Linux / VPS', 'Android', 'Web preview', 'MIT'],
    pc='PC / VPS + AI agent', phone='your phone',
    flow_title='How RemoteAppTester works: four steps in a loop',
    steps=[('You ask', 'write to the agent', 'from your phone'),
           ('AI agent codes', 'changes the project,', 'rt sg --build'),
           ('RemoteAppTester builds', 'with the commands', 'you approved'),
           ('Phone installs', 'over Tailscale,', 'and you test it')],
    loop='…then you write the next request, and the loop repeats.',
    phones_title='RemoteAppTester on the phone: fingerprint lock, new versions, website preview',
    locked='Locked', unlock='Unlock with fingerprint', pin='or use the phone PIN', unlocked='Unlocked',
    cap1='Fingerprint lock', cap1b='on start and after a break',
    projects='Projects', dl1='New version: Shopping list', dl2='downloading 12.4 / 18.2 MB',
    ask1='Shopping list: install?', skip='Skip', install='Install', inst1='Installing: Shopping list', inst2='Android is checking the app',
    done1='Installed: Shopping list', launch='Launch',
    p1='Shopping list', p2='My website', p3='Notes', newchg='new changes',
    cap2='New versions arrive by themselves', cap2b='you just tap Install (or not even that)',
    preview='Site preview', site='My website', report='Report a problem',
    note1='The orange button covers', note2='the menu on small screens', console='+ browser console attached',
    send='Send', saved='Saved for the AI agent ✓',
    cap3='Website preview', cap3b='your notes go straight to the agent',
    term_title='AI agent session · ~/projects/shopping-list',
    term=[('you', 'Add a shopping list screen. Each item can be ticked off.'),
          ('you', 'When you are done, send the app to my phone with rt.'),
          ('agent', 'Creating lib/screens/shopping_list.dart'),
          ('agent', 'Running tests: 12 passed'),
          ('cmd', 'rt sg -m "Shopping list" --build --wait'),
          ('out', 'Build in progress.'),
          ('ok', 'Done — sent to phones: 1'),
          ('say', 'Sent! Open the app on your phone and try the new list.')],
)

PL = dict(
    hero_title='RemoteAppTester: rozmawiasz z agentem AI, aplikacja trafia na telefon',
    tag1='Piszesz agentowi AI, co ma zbudować.', tag2='Nowa wersja sama trafia na Twój telefon.',
    sub='Buduj gdziekolwiek · Testuj na Androidzie · Pracuj zdalnie',
    chips=['Windows', 'Linux / VPS', 'Android', 'Podgląd www', 'MIT'],
    pc='PC / VPS + agent AI', phone='Twój telefon',
    flow_title='Jak działa RemoteAppTester: cztery kroki w pętli',
    steps=[('Ty piszesz', 'do agenta AI', 'z telefonu'),
           ('Agent programuje', 'zmienia projekt,', 'rt sg --build'),
           ('RemoteAppTester', 'buduje komendami,', 'które zatwierdziłeś'),
           ('Telefon instaluje', 'przez Tailscale,', 'a Ty testujesz')],
    loop='…potem piszesz kolejną prośbę i pętla się powtarza.',
    phones_title='RemoteAppTester na telefonie: blokada odciskiem, nowe wersje, podgląd strony',
    locked='Zablokowana', unlock='Odblokuj odciskiem palca', pin='albo PIN-em telefonu', unlocked='Odblokowano',
    cap1='Blokada odciskiem palca', cap1b='przy starcie i po przerwie',
    projects='Projekty', dl1='Nowa wersja: Lista zakupów', dl2='pobieranie 12,4 / 18,2 MB',
    ask1='Lista zakupów: zainstalować?', skip='Pomiń', install='Zainstaluj', inst1='Instalowanie: Lista zakupów', inst2='Android sprawdza aplikację',
    done1='Zainstalowano: Lista zakupów', launch='Uruchom',
    p1='Lista zakupów', p2='Moja strona', p3='Notatki', newchg='nowe zmiany',
    cap2='Nowe wersje przychodzą same', cap2b='stukasz „Zainstaluj” (albo nawet nie)',
    preview='Podgląd strony', site='Moja strona', report='Zgłoś problem',
    note1='Pomarańczowy przycisk zasłania', note2='menu na małym ekranie', console='+ dołączona konsola przeglądarki',
    send='Wyślij', saved='Zapisano dla agenta AI ✓',
    cap3='Podgląd strony www', cap3b='uwagi trafiają prosto do agenta',
    term_title='sesja agenta AI · ~/projects/lista-zakupow',
    term=[('you', 'Dodaj ekran listy zakupów. Każdą pozycję można odhaczyć.'),
          ('you', 'Gdy skończysz, wyślij aplikację na mój telefon przez rt.'),
          ('agent', 'Tworzę lib/screens/shopping_list.dart'),
          ('agent', 'Uruchamiam testy: 12 zaliczonych'),
          ('cmd', 'rt sg -m "Lista zakupów" --build --wait'),
          ('out', 'Build w toku.'),
          ('ok', 'Gotowe — wysłano na telefony: 1'),
          ('say', 'Wysłane! Otwórz aplikację na telefonie i sprawdź nową listę.')],
)


def main():
    os.makedirs(OUT, exist_ok=True)
    for code, L in (('en', EN), ('pl', PL)):
        for name, fn in (('hero', hero), ('workflow', workflow), ('phones', phones), ('terminal', terminal)):
            path = os.path.join(OUT, f'{name}-{code}.svg')
            with open(path, 'w', encoding='utf-8', newline='\n') as f:
                f.write(fn(L))
            print(os.path.normpath(path))


if __name__ == '__main__':
    main()
