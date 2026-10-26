#!/usr/bin/env python3
import configparser
import glob
import json
import os
import sys

MEOW_OK, MEOW_DIVERGENTE, MEOW_ERRO, MEOW_SEM_DEPENDENCIA = 0, 1, 2, 3

try:
    import gi

    gi.require_version('Gtk', '3.0')
    from gi.repository import Gtk
except (ImportError, ValueError) as erro:
    print(f'  -- sem PyGObject/Gtk3 — é ele que resolve o ícone ({erro})')
    sys.exit(MEOW_SEM_DEPENDENCIA)

HOME = os.path.expanduser('~')
TEMA = os.environ.get('ICONES_TEMA') or os.environ.get('NOME_TEMA_ICONES') or 'MeowSystem-Icons'
RAIZ_TEMA = os.path.join(HOME, '.local/share/icons', TEMA)

APPDIRS = [
    os.path.join(HOME, '.local/share/applications'),
    os.path.join(HOME, '.local/share/flatpak/exports/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    '/usr/local/share/applications',
    '/usr/share/applications',
]


def visiveis():
    vistos, ordem = {}, []
    for d in APPDIRS:
        for f in sorted(glob.glob(os.path.join(d, '*.desktop'))):
            b = os.path.basename(f)
            if b in vistos:
                continue
            c = configparser.RawConfigParser(strict=False)
            try:
                c.read(f, encoding='utf-8')
            except (OSError, configparser.Error):
                continue
            if not c.has_section('Desktop Entry'):
                continue
            g = c['Desktop Entry']
            if g.get('Type', 'Application') != 'Application':
                continue
            if g.get('NoDisplay', 'false').lower() == 'true':
                continue
            if g.get('Hidden', 'false').lower() == 'true':
                continue
            o, n = g.get('OnlyShowIn', ''), g.get('NotShowIn', '')
            if o and 'COSMIC' not in o.upper():
                continue
            if n and 'COSMIC' in n.upper():
                continue
            vistos[b] = (f, g.get('Icon', ''), g.get('Name', ''),
                         g.get('X-MeowSystem', ''))
            ordem.append(b)
    return ordem, vistos


def intocavel(icone, marca):
    if marca in ('jogo-steam', 'jogo-heroic'):
        return True
    if icone.startswith('steam_icon_') or icone.startswith('meow-steam-'):
        return True
    if icone.startswith('meow-heroic-'):
        return True
    return icone in ('fogstripper', 'hefesto-dualsense4unix',
                     'com.vitoriamaria.HefestoDualsense4Unix')


def main():
    ordem, vistos = visiveis()
    tema = Gtk.IconTheme.new()
    tema.set_custom_theme(TEMA)

    orfaos, dentro, poupados = [], 0, 0
    for b in ordem:
        _arq, icone, nome, marca = vistos[b]
        if intocavel(icone, marca):
            poupados += 1
            continue
        if not icone:
            orfaos.append({'desktop': b, 'nome': nome, 'icone': '',
                           'atual': None, 'motivo': 'sem chave Icon='})
            continue
        if icone.startswith('/'):
            atual = icone if os.path.exists(icone) else None
        else:
            info = tema.lookup_icon(icone, 48, 0)
            atual = info.get_filename() if info else None
        if atual and atual.startswith(RAIZ_TEMA):
            dentro += 1
        else:
            orfaos.append({'desktop': b, 'nome': nome, 'icone': icone,
                           'atual': atual,
                           'motivo': 'não resolve' if atual is None else 'fora do tema'})

    if '--json' in sys.argv:
        print(json.dumps({'tema': TEMA, 'total': len(ordem), 'dentro': dentro,
                          'poupados': poupados, 'orfaos': orfaos},
                         ensure_ascii=False, indent=1))
    else:
        print(f'  >> {len(ordem)} aplicativos visíveis · {dentro} dentro de '
              f'{TEMA} · {len(orfaos)} fora · {poupados} intocáveis (jogos da '
              f'Steam e os dois autorais)')
        for o in orfaos:
            print(f"     {o['icone'] or '(sem Icon=)':40s} -> {o['atual']}")
        if orfaos:
            print('  >> ficar fora não é defeito: um ícone errado é pior que um '
                  'genérico (packs/meowsystem/icones/apps.map)')

    return MEOW_DIVERGENTE if orfaos else MEOW_OK


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(MEOW_ERRO)
