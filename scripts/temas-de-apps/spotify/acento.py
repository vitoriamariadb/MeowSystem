#!/usr/bin/env python3
"""acento.py — põe o ACCENT do meow.conf dentro do color.ini do tema Catppuccin.

POR QUE ESTE ARQUIVO EXISTE (medido em 10/08/2026)
──────────────────────────────────────────────────
O README do catppuccin/spicetify diz, sobre o acento: "head over to Spotify's
settings page and select the accent colour". Não há comando de CLI. Lido o
`catppuccin/theme.js` do tema (commit 1ec645c4), o mecanismo é este e nada mais:

    const initialValue = localStorage.getItem("catppuccin-accentColor") ?? "none";
    ...
    "--spice-text":          `var(--spice-${selectedValue})`,
    "--spice-button-active": `var(--spice-${selectedValue})`,

Ou seja: o "acento" do tema é a sobrescrita de DUAS variáveis — `--spice-text` e
`--spice-button-active` — pela cor de mesmo nome. Não é nada além disso.

E essas duas variáveis nascem do `color.ini`, que é um arquivo, na pasta dela,
lido pelo `spicetify apply`. Então o acento NÃO precisa ser um clique guardado
num LevelDB fora do alcance do `meow.conf`: basta escrever, na seção do flavor,
`text` e `button-active` com o hex que aquela mesma seção já dá para o acento.

    [mocha]
    text          = cba6f7   <- era cdd6f4; agora é o `mauve` de três linhas abaixo
    button-active = cba6f7   <- era 9399B2
    ...
    mauve         = cba6f7

É idempotente por construção e não inventa cor nenhuma: a fonte do hex é a
própria seção do color.ini, nunca a paleta do Meow. (As duas coincidem — conferi
`mocha/mauve`: `#CBA6F7` no `assets/paleta/catppuccin.json` e `cba6f7` no color.ini —
mas fazer o valor vir do arquivo que o spicetify vai ler é o que garante que
`aplicar` e `conferir` estejam falando do MESMO número.)

O QUE ISTO CUSTA, DITO EM VOZ ALTA
  O dropdown "Catppuccin → Choose an accent color" dentro do Spotify continua
  funcionando e continua GANHANDO de nós enquanto estiver aberto: ele escreve
  `style` inline no `<html>`, que vence qualquer folha de estilo. O que ele
  perde é o significado de "none": com `none` o theme.js apenas remove a
  sobrescrita inline, e o que aparece por baixo passa a ser o nosso acento em
  vez do cinza-texto do tema. É a troca certa — o acento dela vira uma linha do
  meow.conf, conferível pelo doctor, em vez de um clique que ninguém audita.

VERBOS
  estado  <color.ini> --flavor mocha --acento mauve [--paleta paleta.json]
      Imprime `desejado=`, `text=`, `button_active=` e `ok=sim|nao`. Não escreve.
  aplicar <color.ini> --flavor mocha --acento mauve [--paleta paleta.json]
      Reescreve as duas chaves. Preserva o arquivo byte a byte fora delas
      (não uso configparser de propósito: ele normaliza espaçamento, comentário
      e caixa, e o diff contra o upstream viraria ilegível).

  Com --paleta, o flavor que o color.ini não tem (o de um pack pessoal, que
  herda o tema) ganha a seção dele: a seção de fundo mais perto, trocada slot a
  slot pelas cores do flavor na paleta. Sem seção de onde derivar, sai 3.
"""
import argparse
import re
import sys

def _fatia_secao(texto: str, secao: str):
    ini = re.search(r'^\[' + re.escape(secao) + r'\]\s*$', texto, re.M)
    if not ini:
        return None
    inicio = ini.end()
    prox = re.search(r'^\[[^\]]+\]\s*$', texto[inicio:], re.M)
    fim = inicio + prox.start() if prox else len(texto)
    return inicio, fim


def _ler_chave(bloco: str, chave: str):
    m = re.search(r'^(' + re.escape(chave) + r')(\s*)=(\s*)(\S+)\s*$', bloco, re.M)
    return m.group(4) if m else None


def _escrever_chave(bloco: str, chave: str, valor: str):
    novo, n = re.subn(r'^(' + re.escape(chave) + r')(\s*)=(\s*)(\S+)[ \t]*$',
                      lambda m: f'{m.group(1)}{m.group(2)}={m.group(3)}{valor}',
                      bloco, count=1, flags=re.M)
    return novo, n


def _hex(valor: str):
    v = (valor or '').strip().lstrip('#').lower()
    return v if re.fullmatch(r'[0-9a-f]{6}', v) else None


def _distancia(a: str, b: str) -> int:
    return sum(abs(int(a[i:i + 2], 16) - int(b[i:i + 2], 16)) for i in (0, 2, 4))


def _secoes(texto: str):
    return re.findall(r'^\[([^\]]+)\]\s*$', texto, re.M)


def derivar_secao(texto: str, flavor: str, cores: dict):
    novas = {k: _hex(v) for k, v in (cores or {}).items() if _hex(v)}
    if 'base' not in novas:
        return None
    candidatas = []
    for nome in _secoes(texto):
        ini, fim = _fatia_secao(texto, nome)
        bloco = texto[ini:fim]
        slots = {k: _hex(_ler_chave(bloco, k) or '') for k in novas}
        slots = {k: v for k, v in slots.items() if v}
        if 'base' in slots and len(slots) * 2 >= len(novas):
            candidatas.append((_distancia(slots['base'], novas['base']), nome, bloco, slots))
    if not candidatas:
        return None
    _d, _nome, bloco, slots = min(candidatas)

    def trocar(m):
        chave, valor = m.group(1), _hex(m.group(4))
        if valor is None:
            return m.group(0)
        if chave in novas:
            return f'{m.group(1)}{m.group(2)}={m.group(3)}{novas[chave]}'
        perto = min(((_distancia(valor, v), k) for k, v in slots.items()), default=None)
        if perto is None or perto[0] > 12:
            return m.group(0)
        return f'{m.group(1)}{m.group(2)}={m.group(3)}{novas[perto[1]]}'

    corpo = re.sub(r'^([A-Za-z0-9_-]+)(\s*)=(\s*)(\S+)[ \t]*$', trocar, bloco.strip('\n'), flags=re.M)
    return texto.rstrip('\n') + f'\n\n[{flavor}]\n{corpo}\n'


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('verbo', choices=('estado', 'aplicar'))
    p.add_argument('color_ini')
    p.add_argument('--flavor', required=True)
    p.add_argument('--acento', required=True)
    p.add_argument('--paleta')
    a = p.parse_args()

    try:
        texto = open(a.color_ini, encoding='utf-8').read()
    except OSError as e:
        print(f'nao consegui ler o color.ini: {e}', file=sys.stderr)
        return 2

    derivada = False
    faixa = _fatia_secao(texto, a.flavor)
    if not faixa and a.paleta:
        try:
            import json
            cores = json.load(open(a.paleta, encoding='utf-8'))['flavors'][a.flavor]
        except (OSError, ValueError, KeyError, TypeError):
            cores = None
        derivado = derivar_secao(texto, a.flavor, cores) if cores else None
        if derivado is None:
            print(f'o color.ini nao tem a secao [{a.flavor}], nem uma de onde deriva-la', file=sys.stderr)
            return 3
        texto, derivada = derivado, True
        faixa = _fatia_secao(texto, a.flavor)
    if not faixa:
        print(f'o color.ini nao tem a secao [{a.flavor}]', file=sys.stderr)
        return 2
    inicio, fim = faixa
    bloco = texto[inicio:fim]

    if a.acento == 'none':
        print("acento 'none' nao e suportado por este caminho: reinstale o tema "
              "para voltar ao color.ini de fabrica", file=sys.stderr)
        return 2

    hex_acento = _ler_chave(bloco, a.acento)
    if not hex_acento:
        print(f'a secao [{a.flavor}] nao define a cor "{a.acento}"', file=sys.stderr)
        return 2

    atual_text = _ler_chave(bloco, 'text')
    atual_btn = _ler_chave(bloco, 'button-active')

    if a.verbo == 'estado':
        ok = not derivada and (atual_text or '').lower() == hex_acento.lower() and \
             (atual_btn or '').lower() == hex_acento.lower()
        print(f'desejado={hex_acento}')
        print(f'text={atual_text or ""}')
        print(f'button_active={atual_btn or ""}')
        print(f'ok={"sim" if ok else "nao"}')
        return 0

    novo = bloco
    for chave in ('text', 'button-active'):
        novo, n = _escrever_chave(novo, chave, hex_acento)
        if n != 1:
            print(f'nao achei a chave "{chave}" na secao [{a.flavor}]', file=sys.stderr)
            return 2

    if novo == bloco and not derivada:
        print('nada a fazer')
        return 0

    import os
    destino = a.color_ini
    tmp = destino + '.meow-parcial'
    with open(tmp, 'w', encoding='utf-8') as fh:
        fh.write(texto[:inicio] + novo + texto[fim:])
    os.replace(tmp, destino)
    print(f'acento {a.acento}={hex_acento} gravado em [{a.flavor}]')
    return 0


if __name__ == '__main__':
    sys.exit(main())
