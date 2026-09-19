#!/usr/bin/env python3
"""vidro_janela.py — o vidro fosco continua quando a JANELA é maximizada.

ESTE ARQUIVO É A OUTRA METADE DO `vidro.sh`
    O `vidro.sh` cuida do painel e do dock: a chave `keep_style_on_maximize`
    impede que a barra largue o translúcido quando uma janela maximiza. Só que
    a JANELA tem o problema equivalente, por outro mecanismo, e nenhuma chave
    do COSMIC o cobre. Quem liga `VIDRO_AO_MAXIMIZAR="sim"` espera vidro fosco
    ao maximizar — inteiro, não a metade de cima. As duas metades saem da mesma
    chave de propósito: um produto não pede que a pessoa ligue a mesma coisa
    duas vezes.

O PROBLEMA, E POR QUE NÃO É BUG
    O COSMIC pinta a janela com DUAS paletas: flutuante usa
    `transparent_background` (alpha < FF, e o compositor desfoca o que está
    atrás); maximizada troca para `background`, que vem de fábrica com alpha FF
    — opaco. O blur continua sendo feito (o cliente segue pedindo
    `ext_background_effect_v1.set_blur_region` na tela inteira e declarando
    `set_opaque_region(nil)`), só que não sobra transparência por onde ele
    apareça.

    É intencional upstream: cosmic-epoch#3714 foi fechada como duplicata de
    cosmic-panel#457 ("Give option to keep the panel transparency when window
    is maximized"), com PR #601. Quando a opção nativa chegar, ela vira chave de
    tema nova — e `avisar_se_nativo()` grita para que a correção daqui seja
    aposentada em vez de brigar com a de fábrica.

A CORREÇÃO, E O QUE ELA NÃO FAZ
    Copiar o alpha de `transparent_X.base` para `X.base`, em cada par (X,
    transparent_X) que o tema tiver. **Nenhum valor fixo**: o alpha sai do que a
    própria pessoa escolheu nos controles "Espessura do efeito fosco" e
    "Opacidade do vidro" em Aparência. Mexer nos controles continua funcionando;
    este script apenas volta a sincronizar as duas paletas.

POR QUE ISTO É SEGURO NUMA MÁQUINA QUALQUER
    - Os temas e os pares são DESCOBERTOS em disco, nunca listados à mão: tema
      novo ou `transparent_*` novo entra sozinho, e uma máquina sem nenhum deles
      simplesmente não tem o que fazer e sai 0.
    - Comparação SEMÂNTICA: lê o alpha gravado e só escreve quando difere do
      alvo. Nada de marcador dentro do arquivo — o cosmic-settings reserializa
      esses RON e descartaria qualquer comentário nosso. (É a armadilha que
      cegou um applier de atalhos por 562 execuções, registrada em
      `docs/COSMIC-THEMING.md`.)
    - Reescrita CIRÚRGICA: troca só os 2 dígitos do alpha do `base:` de
      profundidade 1, byte a byte. Campos que o COSMIC vier a acrescentar ficam
      intactos.
    - Escrita ATÔMICA: `.tmp` + `os.replace`. O cosmic-settings pode estar lendo
      o tema neste instante, e meio arquivo seria um tema quebrado até o próximo
      login.
    - Respeita o desligamento de fábrica: com "Janelas" desmarcado em Aparência
      (`frosted_windows = false`), o alvo passa a ser FF — que é o de fábrica.

CONTRATO (o mesmo do resto do projeto)
    vidro_janela.py              aplica
    vidro_janela.py --conferir   não escreve; 0 = no ar · 1 = divergente
    vidro_janela.py --restaurar  devolve o alpha de fábrica (FF)

    Quem decide SE deve rodar é o `vidro.sh`, que lê `VIDRO_AO_MAXIMIZAR` do
    meow.conf. Este arquivo não conhece o conf, e isso é de propósito: uma porta
    de decisão só.
"""

from __future__ import annotations

import argparse
import glob
import os
import re
import sys

COSMIC_DIR = os.path.join(os.path.expanduser("~"), ".config", "cosmic")

# Alpha de fábrica: opaco. É para onde `--restaurar` volta.
ALPHA_OPACO = "FF"

MEOW_OK = 0
MEOW_DIVERGENTE = 1

# `base: "#RRGGBBAA"` — o AA é opcional porque versões antigas do COSMIC
# gravaram "#RRGGBB"; nesse caso tratamos como FF e completamos ao escrever.
RE_BASE = re.compile(r'base\s*:\s*"#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?"')


def achar_base_raiz(texto: str):
    """O `base:` do nível 1 do RON — o fundo da janela.

    Percorre contando parênteses FORA de string, porque `component`, `hover` e
    companhia também têm um `base:`. Pegar a primeira ocorrência por expressão
    regular daria certo hoje e erraria calado no dia em que o COSMIC reordenasse
    os campos.
    """
    profundidade = 0
    em_string = False
    escapado = False
    i = 0
    n = len(texto)
    while i < n:
        c = texto[i]
        if em_string:
            if escapado:
                escapado = False
            elif c == "\\":
                escapado = True
            elif c == '"':
                em_string = False
            i += 1
            continue
        if c == '"':
            em_string = True
            i += 1
            continue
        if c == "(":
            profundidade += 1
            i += 1
            continue
        if c == ")":
            profundidade -= 1
            i += 1
            continue
        if profundidade == 1 and texto.startswith("base", i):
            # Tem de ser o início do identificador, não o fim de outro
            # (`selected_base`, por exemplo).
            anterior = texto[i - 1] if i > 0 else " "
            if not (anterior.isalnum() or anterior == "_"):
                m = RE_BASE.match(texto, i)
                if m:
                    return m
        i += 1
    return None


def ler(caminho: str):
    try:
        with open(caminho, "r", encoding="utf-8") as fh:
            return fh.read()
    except OSError:
        return None


def alpha_de(caminho: str):
    """Alpha (2 dígitos hex maiúsculos) do `base:` raiz, ou None."""
    texto = ler(caminho)
    if texto is None:
        return None
    m = achar_base_raiz(texto)
    if not m:
        return None
    return (m.group(2) or ALPHA_OPACO).upper()


def escrever_alpha(caminho: str, alvo: str) -> bool:
    """Reescreve só o alpha do `base:` raiz. True se tocou no arquivo."""
    texto = ler(caminho)
    if texto is None:
        return False
    m = achar_base_raiz(texto)
    if not m:
        return False
    atual = (m.group(2) or ALPHA_OPACO).upper()
    if atual == alvo:
        return False
    novo = texto[: m.start()] + 'base: "#%s%s"' % (m.group(1), alvo) + texto[m.end() :]
    tmp = caminho + ".meow-tmp"
    with open(tmp, "w", encoding="utf-8") as fh:
        fh.write(novo)
    try:
        st = os.stat(caminho)
        os.chmod(tmp, st.st_mode & 0o7777)
    except OSError:
        pass
    os.replace(tmp, caminho)
    return True


def temas():
    """Diretórios de tema APLICADO, descobertos em disco.

    Os `.Builder` guardam a receita e não o tema derivado — não têm
    `background`, então seriam pulados de qualquer jeito; ficam de fora por
    clareza. `v*` porque o COSMIC já migrou de v1 para v2 e vai migrar de novo.
    """
    achados = []
    padrao = os.path.join(COSMIC_DIR, "com.system76.CosmicTheme.*", "v*")
    for caminho in sorted(glob.glob(padrao)):
        if ".Builder" in caminho or not os.path.isdir(caminho):
            continue
        if glob.glob(os.path.join(caminho, "transparent_*")):
            achados.append(caminho)
    return achados


def nome_curto(dir_tema: str) -> str:
    return os.path.basename(os.path.dirname(dir_tema)).replace("com.system76.CosmicTheme.", "")


def avisar_se_nativo(dirs) -> None:
    """Grita quando o COSMIC ganhar a opção de fábrica.

    No dia em que a System76 entregar cosmic-panel#457 para janelas, vai nascer
    uma chave de tema com "maxim" no nome. Nesse dia esta correção deixa de ser
    necessária e passa a BRIGAR com a nativa — melhor descobrir por aviso do que
    por comportamento estranho meses depois.
    """
    for dir_tema in dirs:
        for caminho in sorted(glob.glob(os.path.join(dir_tema, "*maxim*"))):
            print("  !!   o COSMIC criou %s" % os.path.basename(caminho))
            print("       a opção nativa (cosmic-panel#457) parece ter chegado —")
            print("       esta correção pode ser aposentada em favor da de fábrica")
            return


def frosted_windows_ligado(dir_tema: str) -> bool:
    """"Janelas" marcado em Aparência. Ausente = ligado (é o default do COSMIC)."""
    texto = ler(os.path.join(dir_tema, "frosted_windows"))
    if texto is None:
        return True
    return texto.strip() == "true"


def pares(dir_tema: str):
    """(arquivo transparente, arquivo opaco) de cada par que existe no tema."""
    for origem in sorted(glob.glob(os.path.join(dir_tema, "transparent_*"))):
        destino = os.path.join(dir_tema, os.path.basename(origem)[len("transparent_") :])
        if os.path.isfile(destino):
            yield origem, destino


def alvo_de(origem: str, forcar_opaco: bool):
    return ALPHA_OPACO if forcar_opaco else alpha_de(origem)


def planejar(dirs, restaurar: bool):
    """Lista de (destino, atual, alvo) do que está fora do lugar."""
    fora = []
    for dir_tema in dirs:
        forcar = restaurar or not frosted_windows_ligado(dir_tema)
        for origem, destino in pares(dir_tema):
            alvo = alvo_de(origem, forcar)
            atual = alpha_de(destino)
            if alvo is None or atual is None:
                continue
            if alvo != atual:
                fora.append((dir_tema, destino, atual, alvo))
    return fora


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Vidro fosco também na janela maximizada (COSMIC)")
    ap.add_argument("--conferir", action="store_true",
                    help="não escreve; sai 1 se houver divergência")
    ap.add_argument("--restaurar", action="store_true",
                    help="devolve o alpha de fábrica (FF)")
    args = ap.parse_args()

    dirs = temas()
    if not dirs:
        # Máquina sem tema COSMIC em disco. Não é erro: é uma máquina em que
        # não há o que fazer, e um produto não reclama disso.
        print("  --   nenhum tema COSMIC em disco — nada a fazer")
        return MEOW_OK

    avisar_se_nativo(dirs)
    fora = planejar(dirs, args.restaurar)

    if args.conferir:
        if not fora:
            print("  ok   vidro da janela maximizada: consistente")
            return MEOW_OK
        for dir_tema, destino, atual, alvo in fora:
            print("  !=   %s/%s: alpha %s, deveria ser %s"
                  % (nome_curto(dir_tema), os.path.basename(destino), atual, alvo))
        return MEOW_DIVERGENTE

    if not fora:
        print("  --   vidro da janela maximizada: nada a fazer")
        return MEOW_OK

    for dir_tema, destino, atual, alvo in fora:
        if escrever_alpha(destino, alvo):
            print("  ok   %s/%s: alpha %s -> %s"
                  % (nome_curto(dir_tema), os.path.basename(destino), atual, alvo))
    return MEOW_OK


if __name__ == "__main__":
    sys.exit(main())
