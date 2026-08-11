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
`mocha/mauve`: `#CBA6F7` no `palette/catppuccin.json` e `cba6f7` no color.ini —
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
  estado  <color.ini> --flavor mocha --acento mauve
      Imprime `desejado=`, `text=`, `button_active=` e `ok=sim|nao`. Não escreve.
  aplicar <color.ini> --flavor mocha --acento mauve
      Reescreve as duas chaves. Preserva o arquivo byte a byte fora delas
      (não uso configparser de propósito: ele normaliza espaçamento, comentário
      e caixa, e o diff contra o upstream viraria ilegível).
"""
import argparse
import re
import sys

# `[mocha]` até a próxima `[secao]` ou o fim. re.M para `^` valer por linha.
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
    # O `\g<2>`/`\g<3>` preserva o alinhamento em colunas do arquivo upstream.
    novo, n = re.subn(r'^(' + re.escape(chave) + r')(\s*)=(\s*)(\S+)[ \t]*$',
                      lambda m: f'{m.group(1)}{m.group(2)}={m.group(3)}{valor}',
                      bloco, count=1, flags=re.M)
    return novo, n


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('verbo', choices=('estado', 'aplicar'))
    p.add_argument('color_ini')
    p.add_argument('--flavor', required=True)
    p.add_argument('--acento', required=True)
    a = p.parse_args()

    try:
        texto = open(a.color_ini, encoding='utf-8').read()
    except OSError as e:
        print(f'nao consegui ler o color.ini: {e}', file=sys.stderr)
        return 2

    faixa = _fatia_secao(texto, a.flavor)
    if not faixa:
        print(f'o color.ini nao tem a secao [{a.flavor}]', file=sys.stderr)
        return 2
    inicio, fim = faixa
    bloco = texto[inicio:fim]

    # `none` é o valor que o próprio tema usa para "sem acento": nesse caso o
    # desejado é o `text` de fábrica, que nós não sabemos mais qual era depois de
    # já ter escrito por cima. Por isso `none` é recusado aqui, com o conserto
    # dito na frase — não é caso de adivinhar.
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
        ok = (atual_text or '').lower() == hex_acento.lower() and \
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

    if novo == bloco:
        print('nada a fazer')
        return 0

    # Temporário no MESMO diretório e `mv`: é a trava 2 do projeto. Um color.ini
    # pela metade faria o `spicetify apply` seguinte escrever cor lixo no app.
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
