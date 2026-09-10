#!/usr/bin/env python3
"""Quem, no lançador, NÃO resolve dentro do NOSSO tema — medido, nunca contado à mão.

A PERGUNTA CERTA NÃO É "QUEM VEM DO PAPIRUS"
    O inventário de 08/08/2026 nasceu com **12** órfãos e a conta de 10/08/2026
    devolve **13** — e a diferença não é o parque de programas ter mudado: é a
    pergunta ter sido cega. Um flatpak recém-instalado cujo ícone o Papirus não
    tem cai no `hicolor` que o **próprio flatpak exporta**, diretório que está em
    `XDG_DATA_DIRS` e nunca entrou naquela varredura. Ele some da conta parecendo
    resolvido. Perguntando ao contrário — "quem NÃO resolve dentro de
    `~/.local/share/icons/<nosso tema>`" — não há por onde escapar.

DUAS ARMADILHAS DE IMPLEMENTAÇÃO, AS DUAS SILENCIOSAS
    1. NÃO ANDAR NO DISCO. Quem decide qual arquivo vence é o resolvedor, e ele
       lê o `index.theme` (`Directories=`, `Inherits=`) — varrer pasta com `glob`
       reproduz o algoritmo errado e mente com convicção. Aqui a resolução é
       pedida ao próprio GTK.
    2. OS DIRETÓRIOS DE TAMANHO DO `Papirus-Dark` SÃO SYMLINK
       (`48x48 -> ../Papirus/48x48`). `os.walk` e `find` não descem em diretório
       simbólico sem `followlinks=True` / `-L`, e uma varredura ingênua conclui
       que o tema inteiro não tem ícone de 48 px. Este script não anda no disco
       justamente por isto — a armadilha fica registrada para quem for reauditar.

    `/var/lib/flatpak/exports/share/applications` não existe nesta máquina,
    apesar de o `XDG_DATA_DIRS` citá-lo: ausência não é defeito, e não vira aviso.

SÓ LEITURA, E ISSO É O QUE O MANTÉM SEGURO
    Não escreve ícone nenhum e não tem modo de escrita. Escolher ícone é decisão
    dela — o auto-reparo das 5h pode chamar isto à vontade que não há o que
    consertar sozinho. O que ele produz é uma CONTA, para nunca mais existir um
    número escrito à mão envelhecendo dentro de um documento.

CÓDIGOS DE SAÍDA (o contrato do projeto)
    0 tudo no tema · 1 há órfãos (não é erro: é inventário) · 2 erro · 3 falta
    dependência.
"""
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

# Os diretórios de `.desktop` na ordem de precedência do XDG: o primeiro que
# tiver o arquivo é o que vale, e os de baixo ficam sombreados.
APPDIRS = [
    os.path.join(HOME, '.local/share/applications'),
    os.path.join(HOME, '.local/share/flatpak/exports/share/applications'),
    '/var/lib/flatpak/exports/share/applications',
    '/usr/local/share/applications',
    '/usr/share/applications',
]


def visiveis():
    """Os `.desktop` que o lançador de fato mostra, sem duplicata."""
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
            # As quatro chaves que escondem uma entrada. Ignorá-las infla a conta
            # com `.desktop` de serviço, que ninguém vê no lançador.
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
    """Os que ficam como estão por pedido expresso dela.

    Os jogos são a maioria e mudam sozinhos — o `jogos_steam.sh` e o
    `jogos_heroic.sh` geram um `.desktop` por jogo instalado, cada um com a sua
    marca (`X-MeowSystem=jogo-steam`, `X-MeowSystem=jogo-heroic`). Ler
    essa marca é mais honesto que adivinhar pelo nome: a arte deles vem da Steam,
    não do tema, e contá-los como "fora do tema" enterra os órfãos de verdade
    num ruído que cresce a cada jogo instalado. A lista de nomes é a mesma do
    `scripts/icones_apps.sh` (`INTOCAVEIS`), e por isso está repetida e não
    derivada: um script em bash não exporta array para um em python.
    """
    if marca in ('jogo-steam', 'jogo-heroic'):
        return True
    if icone.startswith('steam_icon_') or icone.startswith('meow-steam-'):
        return True
    # Os do Heroic entram pela mesma porta e pelo mesmo motivo: a capa é do jogo,
    # não do tema. O prefixo fica ao lado da marca porque o `Icon=` de um jogo
    # sem capa no disco cai no `com.heroicgameslauncher.hgl` — e esse é o ícone
    # do PROGRAMA Heroic, que o tema veste e deve continuar sendo cobrado.
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
        # `Icon=` pode ser caminho absoluto. Aí não há resolução nenhuma: o
        # arquivo é aquele, e ele nunca está dentro do nosso tema.
        if icone.startswith('/'):
            atual = icone if os.path.exists(icone) else None
        else:
            # 48 px é a dock, o menor lugar onde ícone de aplicativo aparece
            # nesta máquina (medido — ver o cabeçalho do icones_apps_arcticons).
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
              f'Steam e os dois dela)')
        for o in orfaos:
            print(f"     {o['icone'] or '(sem Icon=)':40s} -> {o['atual']}")
        if orfaos:
            print('  >> ficar fora não é defeito: um ícone errado é pior que um '
                  'genérico (assets/icones/apps.map)')

    return MEOW_DIVERGENTE if orfaos else MEOW_OK


if __name__ == '__main__':
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(MEOW_ERRO)
