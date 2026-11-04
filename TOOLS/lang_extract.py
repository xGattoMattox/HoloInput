#!/usr/bin/env python3
"""
lang_extract.py - estrae dal codice Delphi tutte le scritte localizzabili di HoloInput.

Cerca le chiamate Tr('chiave', <testo predefinito>) e TrBuiltin(...) (testi non modificabili
dalla cartella LANG: valgono solo quelli incorporati nell'exe) in tutti i file .pas del progetto,
piu' i nomi delle tipologie (KindCaption -> kind.*) e dei layout (LayoutCaption ->
layout.*) di Holo.Config, e scrive un file di lingua con i testi predefiniti
(italiano), nel formato letto da Holo.Lang:

    [Lingua]
    Nome=Italiano
    [Testi]
    chiave=testo        (a capo = \\n, barra rovescia = \\\\, spazi agli estremi tra virgolette)

Uso (dalla cartella del progetto):
    python TOOLS/lang_extract.py                      scrive LANG/italiano.ini
    python TOOLS/lang_extract.py -o nuovo.ini         scrive un altro file
    python TOOLS/lang_extract.py --check LANG/english.ini
                                                      elenca le chiavi mancanti o in piu'
                                                      in una traduzione

Il testo predefinito puo' contenere solo stringhe tra apici, caratteri #$XXXX / #NNN,
sLineBreak e costanti stringa dichiarate nel progetto (NOME = 'testo';), uniti con '+'.
"""
import argparse, glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def pas_files():
    out = []
    for p in glob.glob(os.path.join(ROOT, '**', '*.pas'), recursive=True):
        if '__history' in p or '__recovery' in p:
            continue
        out.append(p)
    return sorted(out)


def strip_comments(src):
    """Toglie i commenti // { } (* *) lasciando intatte le stringhe."""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if c == "'":
            j = i + 1
            while j < n:
                if src[j] == "'":
                    if j + 1 < n and src[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            out.append(src[i:j + 1])
            i = j + 1
        elif src.startswith('//', i):
            j = src.find('\n', i)
            i = n if j < 0 else j
        elif c == '{':
            j = src.find('}', i)
            i = n if j < 0 else j + 1
        elif src.startswith('(*', i):
            j = src.find('*)', i)
            i = n if j < 0 else j + 2
        else:
            out.append(c)
            i += 1
    return ''.join(out)


def read_constants(sources):
    """Costanti stringa semplici: NOME = 'testo' ['+' ...];"""
    consts = {}
    for src in sources:
        for m in re.finditer(r"\b([A-Z_][A-Z0-9_]*)\s*=\s*((?:'(?:[^']|'')*'|#\$?[0-9A-Fa-f]+|\s|\+)+);", src):
            consts.setdefault(m.group(1), m.group(2))
    return consts


TOKEN = re.compile(r"\s*(?:('(?:[^']|'')*')|#\$([0-9A-Fa-f]+)|#([0-9]+)|(sLineBreak)\b|([A-Za-z_]\w*)|(\+))")


def evaluate(expr, consts, depth=0):
    """Valore di un'espressione stringa Delphi semplice; None se non valutabile."""
    pos, out = 0, []
    expr = expr.strip()
    while pos < len(expr):
        m = TOKEN.match(expr, pos)
        if not m:
            return None
        pos = m.end()
        lit, hx, dec, lb, ident, plus = m.groups()
        if lit is not None:
            out.append(lit[1:-1].replace("''", "'"))
        elif hx is not None:
            out.append(chr(int(hx, 16)))
        elif dec is not None:
            out.append(chr(int(dec)))
        elif lb is not None:
            out.append('\n')
        elif ident is not None:
            if ident not in consts or depth > 5:
                return None
            v = evaluate(consts[ident], consts, depth + 1)
            if v is None:
                return None
            out.append(v)
    return ''.join(out)


def split_args(src, start):
    """Da src[start] (subito dopo 'Tr(') restituisce (arg1, arg2, fine) rispettando stringhe e parentesi."""
    depth, i, args, cur = 0, start, [], []
    while i < len(src):
        c = src[i]
        if c == "'":
            j = i + 1
            while j < len(src):
                if src[j] == "'":
                    if j + 1 < len(src) and src[j + 1] == "'":
                        j += 2
                        continue
                    break
                j += 1
            cur.append(src[i:j + 1])
            i = j + 1
            continue
        if c == '(':
            depth += 1
        elif c == ')':
            if depth == 0:
                args.append(''.join(cur))
                return args, i
            depth -= 1
        elif c == ',' and depth == 0:
            args.append(''.join(cur))
            cur = []
            i += 1
            continue
        cur.append(c)
        i += 1
    return None, i


def array_values(src, name):
    m = re.search(name + r"\s*:\s*array\s*\[\w+\]\s*of\s*string\s*=\s*\((.*?)\);", src, re.S)
    return [v[1:-1].replace("''", "'") for v in re.findall(r"'(?:[^']|'')*'", m.group(1))] if m else []


builtin = set()   # chiavi lette con TrBuiltin (solo testi incorporati)


def collect():
    sources = {p: strip_comments(open(p, encoding='utf-8-sig').read()) for p in pas_files()}
    consts = read_constants(sources.values())
    texts, where, problems = {}, {}, []
    builtin.clear()
    for p, src in sources.items():
        for m in re.finditer(r"\b(Tr|TrBuiltin)\(\s*'([^']+)'\s*,", src):
            args, _ = split_args(src, m.start() + len(m.group(1)) + 1)
            if not args or len(args) != 2:
                problems.append('%s: Tr non leggibile vicino a %s' % (os.path.relpath(p, ROOT), m.group(2)))
                continue
            key = m.group(2).lower()
            if m.group(1) == 'TrBuiltin':
                builtin.add(key)
            val = evaluate(args[1], consts)
            if val is None:
                problems.append('%s: testo predefinito non valutabile per %s' % (os.path.relpath(p, ROOT), key))
                continue
            if key in texts and texts[key] != val:
                problems.append('chiave %s con testi diversi (%s, %s)' % (key, where[key], os.path.relpath(p, ROOT)))
            texts.setdefault(key, val)
            where.setdefault(key, os.path.relpath(p, ROOT))
    cfg = sources.get(os.path.join(ROOT, 'Holo.Config.pas'), '')
    for ini, cap, pref in (('KindIniKey', 'KindCaption', 'kind.'), ('LayoutIniText', 'LayoutCaption', 'layout.')):
        for k, v in zip(array_values(cfg, ini), array_values(cfg, cap)):
            texts.setdefault(pref + k.lower(), v)
            where.setdefault(pref + k.lower(), 'Holo.Config.pas')
    return texts, where, problems


def encode(v):
    v = v.replace('\\', '\\\\').replace('\r\n', '\n').replace('\n', '\\n')
    if v != v.strip() or v.startswith('"'):
        v = '"' + v + '"'
    return v


def write_lang(path, texts, where, name='Italiano'):
    groups = {}
    for k in sorted(texts):
        groups.setdefault(k.split('.')[0], []).append(k)
    lines = ['; HoloInput - testi dell\'interfaccia (%s).' % name,
             '; Formato: chiave=testo. "\\n" = a capo, "\\\\" = barra rovescia; un testo che',
             '; inizia o finisce con spazi va tra virgolette. %d / %s sono segnaposto da mantenere.',
             '; Una chiave mancante usa il testo predefinito (italiano) del programma.',
             '', '[Lingua]', 'Nome=' + name, '', '[Testi]']
    for g in groups:
        if any(k in builtin for k in groups[g]):
            lines.append('; --- ' + g + '  (testi incorporati nell\'exe: modificarli qui non ha effetto,')
            lines.append(';      vanno cambiati nel codice e ricompilati)')
        else:
            lines.append('; --- ' + g)
        for k in groups[g]:
            lines.append('%s=%s' % (k, encode(texts[k])))
        lines.append('')
    with open(path, 'w', encoding='utf-8', newline='\r\n') as f:
        f.write('\n'.join(lines))


def read_keys(path):
    keys, sec = set(), ''
    for ln in open(path, encoding='utf-8-sig'):
        ln = ln.strip()
        if ln.startswith('['):
            sec = ln.strip('[]').lower()
        elif sec == 'testi' and '=' in ln and not ln.startswith(';'):
            keys.add(ln.split('=', 1)[0].strip().lower())
    return keys


def main():
    ap = argparse.ArgumentParser(description='Estrae le scritte localizzabili di HoloInput')
    ap.add_argument('-o', '--output', default=os.path.join(ROOT, 'LANG', 'italiano.ini'))
    ap.add_argument('--check', help='file di lingua da confrontare con le chiavi del codice')
    a = ap.parse_args()
    texts, where, problems = collect()
    for p in problems:
        print('ATTENZIONE:', p)
    if a.check:
        have = read_keys(a.check)
        missing = sorted(set(texts) - have)
        extra = sorted(have - set(texts))
        for k in missing:
            print('manca   ', k)
        for k in extra:
            print('in piu\' ', k)
        print('%d chiavi nel codice, %d mancanti, %d in piu\'' % (len(texts), len(missing), len(extra)))
        sys.exit(1 if missing else 0)
    os.makedirs(os.path.dirname(os.path.abspath(a.output)), exist_ok=True)
    write_lang(a.output, texts, where)
    print('Scritto %s (%d chiavi)' % (a.output, len(texts)))


if __name__ == '__main__':
    main()
