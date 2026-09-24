#!/usr/bin/env python3
"""Acrescenta ao `meow.conf` dela as chaves que o `meow.conf.exemplo` ganhou.

O BURACO QUE ISTO TAPA
    O `install.sh` criava o `meow.conf` a partir do exemplo na primeira vez e,
    daí em diante, dizia apenas "meow.conf já existe" e seguia. Chave nova no
    exemplo NUNCA chegava numa máquina que já tinha rodado o projeto.

    Medido em 05/08/2026, com um `meow.conf` da versão anterior: depois de um
    `./install.sh` inteiro, `VIDRO_AO_MAXIMIZAR` continuava ausente do arquivo.
    O recurso funcionava — todo script tem valor padrão —, e é justamente por
    isso que o defeito é traiçoeiro: nada quebra, nada avisa, e o README segue
    prometendo que "tudo que o projeto decide vive em UM arquivo" enquanto uma
    parte das decisões só existe como padrão dentro de um script. O sintoma real
    é ela abrir o `meow.conf` para desligar o vidro ao maximizar e não achar a
    linha.

O QUE NUNCA FAZ
    - Não toca em valor que já existe. O `ACCENT="mauve"` dela continua dela,
      mesmo que o exemplo diga outra coisa. Só entram chaves AUSENTES.
    - Não remove nada. Chave que ela inventou, comentário que ela escreveu e
      chave que saiu do exemplo ficam onde estão. Este script só acrescenta.
    - Não reordena e não reformata o arquivo dela.

O COMENTÁRIO VEM JUNTO, E NÃO É ENFEITE
    Uma chave sozinha (`VIDRO_AO_MAXIMIZAR="sim"`) no fim do arquivo é um enigma:
    não diz o que aceita nem o que faz. O bloco de comentário imediatamente acima
    dela no exemplo é a documentação dela, então viaja junto. É o mesmo princípio
    do resto do projeto — o porquê mora ao lado da decisão.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# `NOME=` no começo da linha. Aceita `export`, que o shell permite e que um
# arquivo editado à mão pode muito bem ter.
CHAVE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=")


def chaves_de(texto: str) -> set[str]:
    return {m.group(1) for l in texto.splitlines() if (m := CHAVE.match(l))}


# AS CHAVES QUE MUDARAM DE NOME — 24/09/2026, P52 (achado 13)
#   `WALLPAPER_FONTES_DELA` era o nome de uma chave que a tela mostra («casa
#   pelo nome no arquivo»), herança de quando o projeto era de uma pessoa só.
#   O produto vai para qualquer pessoa, e o nome passou a dizer o que a lista
#   É: as fontes que o carrossel está PERMITIDO a deixar em paz — a mesma
#   palavra do verbo que a preenche, `meow wallpaper permitir`.
#
#   A REGRA DO NOME ANTIGO, e ela é uma só em todo o projeto: o nome novo vence
#   quando está no arquivo, mesmo vazio; o antigo só vale quando o novo não
#   está. Quem já tem o `meow.conf` com o nome antigo continua funcionando sem
#   passar por aqui — o `scripts/wallpaper.sh`, o painel e o importar leem o
#   antigo como sinônimo —, e este script só arruma o arquivo: troca o NOME na
#   própria linha, com o valor e o comentário dela intactos, antes de conferir
#   as chaves faltando. A ordem importa: acrescentar primeiro poria a chave
#   nova VAZIA no fim do arquivo, e pela regra acima ela venceria o valor que a
#   linha antiga carregava.
#
#   O painel (`app/servidor.py`) lê esta tabela daqui, por caminho — uma
#   segunda tabela lá seria a armadilha nº 3 deste repositório.
RENOMEADAS = {"WALLPAPER_FONTES_DELA": "WALLPAPER_FONTES_PERMITIDAS"}


def renomear(texto: str) -> tuple[str, list[str]]:
    """(texto, ["ANTIGO -> NOVO"]) — o nome antigo trocado pelo novo, na linha.

    Só quando o arquivo ainda NÃO tem o nome novo: com os dois presentes o novo
    já vence (ver `RENOMEADAS`), e renomear o antigo daria duas linhas da mesma
    chave, onde a última atribuição — talvez a velha — passaria a mandar.
    """
    atuais = chaves_de(texto)
    feitas = []
    for antigo, novo in RENOMEADAS.items():
        if antigo not in atuais or novo in atuais:
            continue
        linha = re.compile(r"^(\s*(?:export\s+)?)" + re.escape(antigo) + "=", re.M)
        texto = linha.sub(lambda m, n=novo: m.group(1) + n + "=", texto)
        feitas.append(f"{antigo} -> {novo}")
    return texto, feitas


def blocos_faltando(exemplo: str, atuais: set[str]) -> list[tuple[str, str]]:
    """Devolve [(nome, bloco)] das chaves do exemplo que faltam no arquivo dela.

    O bloco é a chave mais o comentário colado acima dela. "Colado" importa: a
    varredura para atrás só atravessa linhas que começam com `#`, e uma linha em
    branco encerra o bloco. Sem isso, a primeira chave de uma seção arrastaria
    junto o cabeçalho `# --- Aparência ---` da seção inteira.
    """
    linhas = exemplo.splitlines()
    achados: list[tuple[str, str]] = []
    for i, linha in enumerate(linhas):
        m = CHAVE.match(linha)
        if not m or m.group(1) in atuais:
            continue
        inicio = i
        while inicio > 0 and linhas[inicio - 1].lstrip().startswith("#"):
            inicio -= 1
        achados.append((m.group(1), "\n".join(linhas[inicio : i + 1])))
    return achados


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("conf", type=Path, help="o meow.conf dela")
    p.add_argument("exemplo", type=Path, help="o meow.conf.exemplo do repositório")
    p.add_argument("--conferir", action="store_true",
                   help="não escreve; sai 1 se houver chave faltando")
    args = p.parse_args()

    if not args.exemplo.is_file():
        print(f"ERRO: {args.exemplo} não existe", file=sys.stderr)
        return 2
    if not args.conf.is_file():
        # Sem arquivo dela não há o que migrar: quem cria é o install.sh, e
        # criar aqui também seria a mesma decisão em dois lugares.
        return 0

    exemplo = args.exemplo.read_text(encoding="utf-8")
    atual = args.conf.read_text(encoding="utf-8")

    # O nome antigo vira o novo ANTES da conta do que falta — ver `RENOMEADAS`.
    atual, renomeadas = renomear(atual)
    faltando = blocos_faltando(exemplo, chaves_de(atual))
    if not faltando and not renomeadas:
        return 0

    nomes = ", ".join(n for n, _ in faltando)
    if args.conferir:
        if renomeadas:
            print(f"com o nome antigo no meow.conf: {', '.join(renomeadas)}")
        if faltando:
            print(f"faltam no meow.conf: {nomes}")
        return 1

    # Vão para o FIM, numa seção que se identifica. Tentar encaixar cada chave na
    # seção "certa" exigiria casar os cabeçalhos do exemplo com os dela — e o
    # arquivo dela pode ter sido reorganizado à mão. Acrescentar no fim é o único
    # jeito que não depende de adivinhar a estrutura do arquivo de outra pessoa.
    novo = atual
    if faltando:
        corpo = "\n\n".join(bloco for _, bloco in faltando)
        # A frase do cabeçalho não pode mentir quando um nome foi trocado acima.
        intacto = ("# são os padrões; mexa à vontade. Nada acima desta linha foi alterado.\n"
                   if not renomeadas else
                   "# são os padrões; mexa à vontade. Acima desta linha, só o NOME de\n"
                   f"# {', '.join(renomeadas)} mudou; o valor é o de antes.\n")
        novo = atual.rstrip("\n") + (
            "\n\n"
            "# --- Acrescentado pelo install.sh -----------------------------------------\n"
            "# Chaves que o projeto ganhou depois que este arquivo foi criado. Os valores\n"
            f"{intacto}"
            f"{corpo}\n"
        )

    # Temporário no MESMO diretório: `replace` só é atômico dentro de um sistema
    # de arquivos, e uma queda no meio deixaria ela sem configuração nenhuma.
    tmp = args.conf.with_suffix(args.conf.suffix + ".tmp")
    tmp.write_text(novo, encoding="utf-8")
    tmp.replace(args.conf)
    if renomeadas:
        print(f"renomeadas no meow.conf, com o valor de antes: {', '.join(renomeadas)}")
    if faltando:
        print(f"acrescentadas ao meow.conf: {nomes}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
