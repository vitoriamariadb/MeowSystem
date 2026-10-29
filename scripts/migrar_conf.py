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
    - Não remove nada, com UMA exceção nomeada: a linha ATIVA de uma chave
      APOSENTADA (`APOSENTADAS`, mais abaixo, desde a P75). Chave que ela
      inventou, comentário que ela escreveu e chave que só saiu do exemplo
      ficam onde estão.
    - Não reordena e não reformata o arquivo dela.

A ÚNICA LINHA QUE JÁ EXISTIA E MUDA — 24/09/2026, P52
    Uma chave que trocou de nome no projeto (`RENOMEADAS`, mais abaixo) tem o
    NOME reescrito na própria linha, com o valor e o comentário intactos — sem
    isso a linha velha e a nova, vazia, disputariam a mesma chave. Fora esse
    caso, este script só acrescenta.

E O VALOR QUE É RESTO DE OUTRO PACK — 10/10/2026, P79
    `VESTIGIOS`, mais abaixo: o `ICONES_FLAVOR` e o `ICONES_PASTAS` que nomeiam
    um flavor que o pack no ar não tem voltam à forma de fábrica, que acompanha
    o pack; e, na troca de pack (`--pack-de-antes`), o `CURSOR` que era o
    ponteiro do pack de antes vira o do novo. O comentário da linha fica.

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

CHAVE = re.compile(r"^\s*(?:export\s+)?([A-Za-z_][A-Za-z0-9_]*)=")


def chaves_de(texto: str) -> set[str]:
    return {m.group(1) for l in texto.splitlines() if (m := CHAVE.match(l))}


RENOMEADAS = {"WALLPAPER_FONTES_DELA": "WALLPAPER_FONTES_PERMITIDAS"}


APOSENTADAS = {
    "ICONES_BASE": "a base de ícones vem do pack, pinada, por decisão de 24/09/2026",
}

BLOCOS_APOSENTADOS = {
    "ICONES_BASE": """# @ Tema de onde herdar
# > De qual tema instalado o nosso puxa o que ele mesmo não desenha.
# De qual tema instalado o nosso HERDA o que ele não desenha. Vira o `Inherits=`
# do index.theme, e todo ícone que falta no MeowSystem sai daí — apontar para um
# tema claro clareia justamente o que ficou de fora, e nada mais.
#
# ESTA CHAVE E A DE BAIXO NÃO TINHAM COMENTÁRIO PRÓPRIO — corrigido em 02/09/2026
#   Estavam coladas na `NOME_TEMA_ICONES`, sem linha em branco entre elas, e
#   quem lê uma chave sem comentário lê o comentário da chave de cima: os TRÊS
#   cartões apareciam em fila com o mesmo título ("O nome do tema de ícones que
#   este projeto constrói e instala em ~/.local/share/icons/") e o mesmo "Por
#   quê", que explicava uma chave que não era a delas. O `meow configurar` fazia
#   igual. O conserto é o branco e o parágrafo: cada uma diz o que faz.
#
# O PACK PODE TRAZER A BASE — 24/09/2026
#   Um pack que declara a base dele (o Dracula declara) a baixa, confere e
#   herda dela, e aí este valor de fábrica — `Papirus-Dark`, ou vazio — cede ao
#   pack. Qualquer OUTRO tema escrito aqui vence o pack, como toda chave deste
#   arquivo. O preço: com um pack assim no ar, o `Papirus-Dark` não se escolhe
#   por aqui, porque escrevê-lo é o mesmo que deixar a chave de fábrica. A regra
#   inteira está em docs/PACKS.md, "A base de ícones".""",
}


VESTIGIOS = ("ICONES_FLAVOR", "ICONES_PASTAS")
_VALOR = r'("(?:[^"\\]|\\.)*"|\'[^\']*\'|[^\s#]*)'
RE_NOME = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9._-]*$")


def _valor_cru(texto: str, chave: str) -> str | None:
    achado = None
    for m in re.finditer(r"(?m)^\s*(?:export\s+)?" + re.escape(chave) + "=" + _VALOR, texto):
        achado = m.group(1)
    if achado is None:
        return None
    if len(achado) >= 2 and achado[0] == achado[-1] and achado[0] in "\"'":
        return achado[1:-1]
    return achado


def _trocar_valor(texto: str, chave: str, valor: str) -> str:
    linhas = list(re.finditer(r"(?m)^(\s*(?:export\s+)?" + re.escape(chave) + "=)" + _VALOR, texto))
    m = linhas[-1]
    return texto[:m.start(2)] + '"%s"' % valor + texto[m.end(2):]


def _expandir(valor: str, nomes: dict) -> str:
    return re.sub(r"\$\{?([A-Z_]+)\}?", lambda m: nomes.get(m.group(1), m.group(0)), valor)


def _pack():
    import importlib.util
    alvo = Path(__file__).resolve().parent / "pack.py"
    spec = importlib.util.spec_from_file_location("meow_pack_migrar", alvo)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def vestigios(texto: str, exemplo: str, antes: tuple[str, str] | None = None) -> tuple[str, list[str]]:
    pack_cru, flavor_cru = _valor_cru(texto, "PACK") or "", _valor_cru(texto, "FLAVOR") or ""
    accent = _valor_cru(texto, "ACCENT") or ""
    if "$" in pack_cru + flavor_cru + accent:
        return texto, []
    try:
        pack = _pack()
        ident, _dir, _rec = pack.adocao(pack_cru, flavor_cru)
        _p, dados, _d = pack.validar(ident, silencioso=True)
        flavors = set(dados["flavors"])
    except Exception:
        return texto, []
    nomes = {"FLAVOR": flavor_cru, "ACCENT": accent}
    feitas = []
    for chave in VESTIGIOS:
        atual, fabrica = _valor_cru(texto, chave), _valor_cru(exemplo, chave)
        if not atual or fabrica is None or atual == fabrica:
            continue
        if chave == "ICONES_FLAVOR":
            vestigio = "$" not in atual and atual not in flavors
        else:
            m = re.match(r"^cat-([a-z0-9]+)-", _expandir(atual, nomes))
            vestigio = bool(m and m.group(1) not in flavors)
        if vestigio:
            texto = _trocar_valor(texto, chave, fabrica)
            feitas.append(f"{chave} ({atual} -> {fabrica})")
    cursor = _valor_cru(texto, "CURSOR")
    if antes is not None and cursor:
        try:
            de_antes = pack.adocao(*antes)[0]
            fabrica = _valor_cru(exemplo, "CURSOR") or ""
            decide = lambda ref: ((pack.ponteiro(ref) or {}).get("valor") or fabrica)
            era, vai = decide(de_antes), decide(ident)
        except Exception:
            era = vai = ""
        if de_antes != ident and era and vai and cursor == era and era != vai and RE_NOME.match(vai):
            texto = _trocar_valor(texto, "CURSOR", vai)
            feitas.append(f"CURSOR ({cursor} -> {vai})")
    if antes is not None:
        texto, feitas = _mascote_junto(pack, texto, antes, ident, feitas)
    return texto, feitas


def par_do_pack(texto: str) -> tuple[str, str]:
    pack_cru, flavor_cru = _valor_cru(texto, "PACK"), _valor_cru(texto, "FLAVOR")
    if not pack_cru or not flavor_cru:
        return texto, ""
    try:
        novo = _pack().par_do_conf(pack_cru, flavor_cru)
    except Exception:
        return texto, ""
    if not novo:
        return texto, ""
    ident, flavor, porque = novo
    if ident != pack_cru:
        texto = _trocar_valor(texto, "PACK", ident)
    if flavor != flavor_cru:
        texto = _trocar_valor(texto, "FLAVOR", flavor)
    return texto, f'PACK="{ident}" e FLAVOR="{flavor}" ({porque})'


MASCOTE = (("LOGO", ("dia", "noite")), ("LOGO_DIA", ("dia",)), ("LOGO_NOITE", ("noite",)),
           ("FASTFETCH_LOGO_GATO", ("dia", "noite")))


def _mascote_junto(pack, texto, antes, ident, feitas):
    try:
        de_antes = pack.adocao(*antes)[0]
        if de_antes == ident:
            return texto, feitas
        padroes = {f: (pack.mascote_padrao(f, de_antes), pack.mascote_padrao(f, ident))
                   for f in ("dia", "noite")}
    except Exception:
        return texto, feitas
    for chave, fases in MASCOTE:
        atual = _valor_cru(texto, chave)
        for fase in fases:
            era, vai = padroes[fase]
            if atual and era and vai and atual == era and era != vai and RE_NOME.match(vai):
                texto = _trocar_valor(texto, chave, vai)
                feitas.append(f"{chave} ({atual} -> {vai})")
                break
    return texto, feitas


def aposentar(texto: str) -> tuple[str, list[str]]:
    tiradas = []
    linhas = texto.splitlines(keepends=True)
    fica = []
    for linha in linhas:
        m = CHAVE.match(linha)
        if m and m.group(1) in APOSENTADAS:
            if m.group(1) not in tiradas:
                tiradas.append(m.group(1))
            continue
        fica.append(linha)
    return "".join(fica), tiradas


def tirar_blocos_orfaos(texto: str) -> tuple[str, list[str]]:
    linhas = texto.split("\n")
    tirados = []
    for chave, bloco in BLOCOS_APOSENTADOS.items():
        modelo = bloco.split("\n")
        i = 0
        while i < len(linhas):
            if linhas[i] != modelo[0]:
                i += 1
                continue
            n = 0
            while n < len(modelo) and i + n < len(linhas) and linhas[i + n] == modelo[n]:
                n += 1
            if n < 2:
                i += 1
                continue
            fim = i + n
            if i > 0 and linhas[i - 1] == "" and fim < len(linhas) and linhas[fim] == "":
                fim += 1
            del linhas[i:fim]
            if chave not in tirados:
                tirados.append(chave)
    return "\n".join(linhas), tirados


def renomear(texto: str) -> tuple[str, list[str]]:
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
    linhas = exemplo.splitlines()
    achados: list[tuple[str, str]] = []
    for i, linha in enumerate(linhas):
        m = CHAVE.match(linha)
        if not m or m.group(1) in atuais or m.group(1) in APOSENTADAS:
            continue
        inicio = i
        while inicio > 0 and linhas[inicio - 1].lstrip().startswith("#"):
            inicio -= 1
        achados.append((m.group(1), "\n".join(linhas[inicio : i + 1])))
    return achados


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("conf", type=Path, help="o seu meow.conf")
    p.add_argument("exemplo", type=Path, help="o meow.conf.exemplo do repositório")
    p.add_argument("--conferir", action="store_true",
                   help="não escreve; sai 1 se houver chave faltando ou chave "
                        "ainda com o nome antigo")
    p.add_argument("--so-vestigios", action="store_true",
                   help="só os vestígios de pack (a troca de pack, P79)")
    p.add_argument("--pack-de-antes", nargs=2, metavar=("PACK", "FLAVOR"),
                   help="o PACK e o FLAVOR de antes da troca: o CURSOR e o mascote "
                        "de fábrica daquele pack viram os do pack no ar")
    args = p.parse_args()

    if not args.exemplo.is_file():
        print(f"ERRO: {args.exemplo} não existe", file=sys.stderr)
        return 2
    if not args.conf.is_file():
        return 0

    exemplo = args.exemplo.read_text(encoding="utf-8")
    atual = args.conf.read_text(encoding="utf-8")

    if args.so_vestigios:
        aposentadas, renomeadas, faltando, orfaos = [], [], [], []
    else:
        atual, aposentadas = aposentar(atual)
        atual, orfaos = tirar_blocos_orfaos(atual)
        atual, renomeadas = renomear(atual)
        faltando = blocos_faltando(exemplo, chaves_de(atual))
    atual, par = par_do_pack(atual)
    atual, vestigiais = vestigios(atual, exemplo,
                                  tuple(args.pack_de_antes) if args.pack_de_antes else None)
    if not faltando and not renomeadas and not aposentadas and not vestigiais and not orfaos and not par:
        return 0

    nomes = ", ".join(n for n, _ in faltando)
    if args.conferir:
        if par:
            print("PACK e FLAVOR não combinam, viraria: " + par)
        if aposentadas:
            print("aposentada(s), ainda no meow.conf: "
                  + "; ".join(f"{n} ({APOSENTADAS[n]})" for n in aposentadas))
        if renomeadas:
            print(f"com o nome antigo no meow.conf: {', '.join(renomeadas)}")
        if faltando:
            print(f"faltam no meow.conf: {nomes}")
        if vestigiais:
            print("de outro pack, voltariam ao pack no ar: " + "; ".join(vestigiais))
        if orfaos:
            print("comentário do exemplo sem a chave aposentada embaixo: " + ", ".join(orfaos))
        return 1

    novo = atual
    if faltando:
        corpo = "\n\n".join(bloco for _, bloco in faltando)
        acima = []
        if renomeadas:
            acima.append(f"só o NOME de {', '.join(renomeadas)} mudou, com o valor de antes")
        if aposentadas:
            acima.append(f"saiu a linha de {', '.join(aposentadas)}, chave aposentada")
        if orfaos:
            acima.append(f"saiu o comentário do exemplo de {', '.join(orfaos)}, chave aposentada")
        intacto = ("# são os padrões; mexa à vontade. Nada acima desta linha foi alterado.\n"
                   if not acima else
                   "# são os padrões; mexa à vontade. Acima desta linha,\n"
                   f"# {'; '.join(acima)}.\n")
        novo = atual.rstrip("\n") + (
            "\n\n"
            "# --- Acrescentado pelo install.sh -----------------------------------------\n"
            "# Chaves que o projeto ganhou depois que este arquivo foi criado. Os valores\n"
            f"{intacto}"
            f"{corpo}\n"
        )

    tmp = args.conf.with_suffix(args.conf.suffix + ".tmp")
    tmp.write_text(novo, encoding="utf-8")
    tmp.replace(args.conf)
    if par:
        print("PACK e FLAVOR não combinavam, agora: " + par)
    if aposentadas:
        print(f"aposentadas, linha tirada do meow.conf: {', '.join(aposentadas)}")
    if renomeadas:
        print(f"renomeadas no meow.conf, com o valor de antes: {', '.join(renomeadas)}")
    if faltando:
        print(f"acrescentadas ao meow.conf: {nomes}")
    if vestigiais:
        print("de outro pack, voltaram ao pack no ar: " + "; ".join(vestigiais))
    if orfaos:
        print(f"comentário do exemplo sem a chave, tirado do meow.conf: {', '.join(orfaos)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
