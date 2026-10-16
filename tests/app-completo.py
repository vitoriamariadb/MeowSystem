#!/usr/bin/env python3
"""app-completo.py — o painel inteiro, aba por aba e botão por botão.

    tests/app-completo.py               todas as abas; é o que o gate roda
    tests/app-completo.py --aba Ícones  uma aba só (e o cabeçalho), para depurar
    tests/app-completo.py --fotos DIR   guarda a captura de cada aba em DIR

ESCRITO POR CAUSA DESTE PEDIDO (24/09/2026, sprint P46)
  "abrir cada aba como user. E vai aba a aba. Botão a botão, usa todos os
   menus, todas as configs, tudo certinho [...] e valida cada feature. Se tiver
   um teste completo pra isso e colocar como gate já ajudaria muito. Importante
   ser via navegador tudo."

  O `tests/app-navegador.py` (145 conferências) e o `tests/app-acessibilidade.py`
  percorrem caminhos escolhidos a dedo. Nenhum dos dois garante que TODO
  controle da tela foi exercitado: um botão novo entrava no painel sem teste
  nenhum, e a suíte continuava verde. Este arquivo fecha essa porta.

O QUE ELE FAZ
  1. Sobe o painel numa CASA DE BRINQUEDO (ver `montar_casa`) e abre a página
     no Chromium do Playwright, sem janela na tela.
  2. Abre cada aba como uma pessoa abriria — clique no menu lateral, e não URL.
  3. ENUMERA os controles da aba no DOM (`CENSO_JS`) e dá a cada um um nome
     estável: `data-chave` do cartão, `id`, `aria-label`; o rótulo visível só
     quando não há outro.
  4. Confere o censo contra o INVENTÁRIO escrito aqui. Controle na tela que não
     está no inventário REPROVA ("o controle X da aba Y não tem teste"), e
     controle do inventário que sumiu da tela também. Botão novo sem teste não
     passa.
  5. ACIONA cada um, pelo papel que ele tem (`Percurso.acionador`), e cobra um
     efeito que se vê: o DOM mudou, a API respondeu 2xx, a casa de brinquedo
     mudou — ou, no «Ver o que faria», NÃO mudou. O que o gesto REVELA (a caixa
     de pergunta, a gaveta, o «Copiar», o painel de um aplicativo) também está
     no inventário (`REVELADOS`), e também é acionado.
  6. Em toda a aba: nenhum erro no console, nenhuma resposta 4xx/5xx que o
     passo não esperava, nenhum `undefined`, `NaN`, `[object`, `${` ou `null`
     solto na tela. E uma captura por aba, em /tmp/meow-app-completo/, para
     quem revisar.

OS MOLDES
  Controle que nasce de DADO — um cartão por pack, uma ficha por papel de
  parede, um botão por aplicativo, uma opção por valor aceito — entra no
  inventário pelo MOLDE, e não um a um: o que se cobra é que o molde tenha ao
  menos um exemplar na tela e que o exemplar funcione. A casa de brinquedo
  planta o dado que cada molde precisa para existir (ver `montar_casa`).

AS EXCEÇÕES TÊM NOME E MOTIVO
  O que não se aciona de verdade nem na casa de brinquedo está em `EXCECOES`,
  com a frase do porquê. O teste confere que cada uma existe na tela e está
  PROTEGIDA: pede confirmação, mostra o comando e, quando há o «Ver o que
  faria», roda o ensaio e confere que a casa não mudou. E a lista não pode
  ficar velha: ela é conferida contra o que o próprio servidor declara de cada
  ação (`sudo`, `rede`) — uma ação nova que peça senha e não esteja nela
  reprova, e uma exceção que deixou de pedir também.

  O que o percurso acha QUEBRADO fora do território dele (um script, a CLI)
  fica em `DEFEITOS_CONHECIDOS`, pela frase exata e com o endereço do conserto
  — impresso em toda corrida, e reprovando no dia em que parar de acontecer.

DEPENDÊNCIA, E POR QUE AQUI ELA É VERMELHA
  Os outros dois testes de navegador saem "pulado" sem Playwright. Este não:
  ele é o gate de merge (ver `docs/SPRINTS.md`), e gate que se pula sozinho
  não é gate. Sem Playwright, ou sem o Chromium dele, sai 1 com a receita:

      python3 -m venv ~/.local/share/meowsystem/venv-testes
      ~/.local/share/meowsystem/venv-testes/bin/pip install playwright
      ~/.local/share/meowsystem/venv-testes/bin/playwright install chromium

  0 = passou · 1 = falhou · 2 = erro deste teste
"""
import hashlib
import json
import os
import re
import shutil
import struct
import subprocess
import sys
import tempfile
import time
import zlib
from urllib.parse import quote

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _arg(nome):
    """O valor de `--nome VALOR` na linha de comando, ou None."""
    if nome in sys.argv:
        i = sys.argv.index(nome)
        if i + 1 < len(sys.argv):
            return sys.argv[i + 1]
    return None


SO_ABA = _arg("--aba")
FOTOS = _arg("--fotos")

try:
    from playwright.sync_api import sync_playwright
except ImportError:
    print("FALHOU: o Playwright não está instalado neste interpretador:")
    print("  " + sys.executable)
    print("  este teste é o gate de merge e não sai pulado; a receita está no")
    print("  cabeçalho de tests/app-completo.py.")
    sys.exit(1)


# ===========================================================================
# A CASA DE BRINQUEDO
# ===========================================================================
# O PAINEL REAL APLICA NA MÁQUINA — é a regra do projeto, e é por ela que quem
# vai para a sandbox é o TESTE, e nunca o painel. Este arquivo aperta cada
# botão, inclusive os que escrevem, então a casa de brinquedo dos dois testes
# de navegador de hoje (P33) não basta: aqui ela ganha três peças a mais, cada
# uma por uma porta que um clique abriria.
#
#   1. O REPOSITÓRIO TAMBÉM É DE BRINQUEDO. O painel escreve dentro da RAIZ
#      dele, e não só na casa: o «Usar este ícone» grava o
#      `assets/icones/apps-arcticons.map`, o «Adicionar logo» grava em
#      `assets/gatos/`, o «Importar um pack» monta `packs/<id>/`, o «Salvar no
#      pack» dos desenhos autorais reescreve o pack, e o «Tirar da lista» de um
#      jogo mexe no `assets/icones/jogos-fora.map`. O
#      `tests/app-navegador.py` guarda e devolve os dois mapas que ELE toca;
#      aqui a lista de quem escreve não se sabe de antemão (é o teste que a
#      descobre), então o painel sobe de uma CÓPIA da árvore de trabalho — os
#      arquivos versionados e os novos ainda não versionados, que é o que está
#      sendo testado — e o repositório de verdade não é tocado por construção.
#   2. OS SINAIS NÃO SAEM DA CASA. `pkill` e `killall` escolhem processo por
#      NOME na máquina inteira, e foi assim que um `doctor` de brinquedo
#      derrubou o painel da sessão de verdade (P44, `tests/doctor-so-le.sh`).
#      Aqui eles registram e recusam. O `kill` — o binário e o builtin do
#      bash — só entrega sinal a processo cujo ambiente diz `HOME=<casa>`: o
#      script que mata o próprio filho continua funcionando, e o que miraria o
#      painel dela não chega lá.
#   3. A REDE E O BARRAMENTO RECUSAM. `curl`, `wget`, `cargo`,
#      `notify-send`, `xdg-open`, `systemd-run` e `pkexec` registram e saem 1;
#      o `git` recusa só os verbos que vão à rede; `systemctl`, `gsettings`,
#      `dconf` e `busctl` respondem às perguntas e recusam o resto (o molde é o
#      do `tests/doctor-so-le.sh`). Um ensaio que tentar escrever, ou uma ação
#      que baixe sem declarar `rede`, aparece no registro — e isso reprova.
#
# E A CASA NÃO FICA VAZIA, porque vazia ela desenharia menos controles e o
# inventário mediria menos — o jeito errado de ficar verde. O que se planta é o
# dado de que cada MOLDE precisa para ter um exemplar, e cada lugar sai do
# `meow.conf` do brinquedo, nunca de um nome escrito aqui: o ponteiro de
# fábrica, o tema de ícones, a galeria, uma pendência por conserto que o
# servidor conhece, um jogo da Steam, duas áreas alfinetadas e um ajuste
# mudado de fábrica.
BRINQUEDO = tempfile.mkdtemp(prefix="meow-completo-")
CASA = os.path.join(BRINQUEDO, "casa")
RAIZ_B = os.path.join(BRINQUEDO, "raiz")
FALSO = os.path.join(BRINQUEDO, "falso")
REGISTRO = os.path.join(BRINQUEDO, "registro")
CONF = os.path.join(CASA, ".config", "meow", "meow.conf")
ESTADO = os.path.join(CASA, ".local", "state", "meowsystem")
PAREDES = 6
APPID = "1715980"
# O PROGRAMA DE BRINQUEDO QUE O LANÇADOR ESCONDE (P54, achado 41): um id da
# lista de fábrica do `LANCADOR_OCULTAR`, com um `.desktop` da casa que lhe dá
# outro nome — a ficha tem de dizer o nome, e não o id.
PROGRAMA = ("org.gnome.Evince", "Leitor de Brinquedo")
# O NOME QUE SÓ O CACHE DA STEAM SABE (P54, achado 44): o da decisão sem
# manifesto, que a linha das «Decisões já executadas» tem de mostrar.
NOME_NA_STEAM = "Demo de Brinquedo"
# A tag que a história de um pack traz e que tem de sair como TEXTO (P53).
HOSTIL = '<img src=x onerror="window.__meow_xss=1">'


def valor_de(chave, conf=CONF):
    with open(conf, encoding="utf-8") as fh:
        for linha in fh:
            if linha.startswith(chave + "="):
                return linha.split("=", 1)[1].split("#")[0].strip().strip('"')
    return None


def png_liso(caminho, rgb, larg=64, alt=40):
    """Um PNG de uma cor só, escrito à mão (o mesmo dos outros dois testes)."""
    def pedaco(tipo, corpo):
        return (struct.pack(">I", len(corpo)) + tipo + corpo
                + struct.pack(">I", zlib.crc32(tipo + corpo) & 0xFFFFFFFF))
    linhas = (bytes([0]) + bytes(rgb) * larg) * alt
    with open(caminho, "wb") as fh:
        fh.write(bytes([0x89]) + "PNG\r\n".encode() + bytes([0x1A, 0x0A])
                 + pedaco("IHDR".encode(), struct.pack(">IIBBBBB", larg, alt, 8, 2, 0, 0, 0))
                 + pedaco("IDAT".encode(), zlib.compress(linhas))
                 + pedaco("IEND".encode(), bytes()))


def xcursor_liso(caminho, lado=24, argb=0xFFCDD6F4):
    """Um XCursor de uma imagem só, no formato que o servidor decodifica."""
    pixels = bytes().join(struct.pack("<I", argb if x <= y else 0)
                          for y in range(lado) for x in range(lado))
    with open(caminho, "wb") as fh:
        fh.write("Xcur".encode() + struct.pack("<III", 16, 0x10000, 1)
                 + struct.pack("<III", 0xFFFD0002, lado, 28)
                 + struct.pack("<9I", 36, 0xFFFD0002, lado, 1, lado, lado, 0, 0, 0)
                 + pixels)


def appinfo_vdf(caminho, nomes):
    """Um `appinfo.vdf` da Steam, versão 29, com `appinfo › common › name` de
    cada appid de `nomes` — o molde que o `_nome_no_appinfo` do servidor lê
    (P54). Só o que ele precisa: a tabela de nomes de chave no fim, e o resto
    de cada entrada zerado."""
    chaves = ["appinfo", "common", "name"]
    entradas = b""
    for appid, nome in nomes.items():
        kv = (bytes([0]) + struct.pack("<I", 0) + bytes([0]) + struct.pack("<I", 1)
              + bytes([1]) + struct.pack("<I", 2) + nome.encode("utf-8") + bytes([0])
              + bytes([8, 8, 8]))
        resto = struct.pack("<IIQ", 2, 0, 0) + bytes(20) + struct.pack("<I", 0) + bytes(20) + kv
        entradas += struct.pack("<II", int(appid), len(resto)) + resto
    entradas += struct.pack("<I", 0)
    tabela = struct.pack("<I", len(chaves)) + b"".join(c.encode() + bytes([0]) for c in chaves)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "wb") as fh:
        fh.write(struct.pack("<IIq", 0x07564429, 1, 16 + len(entradas)) + entradas + tabela)


def copiar_raiz():
    """A árvore de trabalho, versionada e nova, numa pasta de brinquedo."""
    lista = subprocess.run(
        ["git", "-C", RAIZ, "ls-files", "-z", "--cached", "--others",
         "--exclude-standard"], capture_output=True, check=True).stdout
    for rel in sorted(set(filter(None, lista.decode().split("\0")))):
        origem, destino = os.path.join(RAIZ, rel), os.path.join(RAIZ_B, rel)
        if not os.path.lexists(origem):
            continue           # apagado na árvore e ainda no índice
        os.makedirs(os.path.dirname(destino), exist_ok=True)
        if os.path.islink(origem):
            os.symlink(os.readlink(origem), destino)
        else:
            shutil.copy2(origem, destino)
    # O `git init` não é enfeite: o item «Créditos» do menu sai do `git remote`
    # (`_repositorio_no_ar`). Sem ele a cópia desenharia um menu com um item a
    # menos, e o link externo do menu ficaria sem teste.
    subprocess.run(["git", "init", "-q", RAIZ_B], check=True)
    remoto = subprocess.run(["git", "-C", RAIZ, "remote", "get-url", "origin"],
                            capture_output=True, text=True).stdout.strip()
    if remoto:
        subprocess.run(["git", "-C", RAIZ_B, "remote", "add", "origin", remoto],
                       check=True)


# O falso que registra e recusa. O `$0` sai pelo `basename`, então o mesmo
# corpo serve para todos.
RECUSA_SH = """#!/bin/sh
echo "$(basename "$0") $*" >> "$MEOW_COMPLETO_REGISTRO"
exit 1
"""

# O que responde pergunta e recusa o resto. O de verdade se acha PULANDO este
# diretório no PATH, e não cortando o começo dele — o laço infinito que o
# `tests/doctor-so-le.sh` mediu em 24/09/2026 foi o corte.
RESPONDE_SH = """#!/bin/bash
real=""
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  [ "$_d" = "%(falso)s" ] && continue
  [ -x "$_d/%(nome)s" ] && { real="$_d/%(nome)s"; break; }
done
case " $* " in
  %(leitura)s) [ -n "$real" ] && exec "$real" "$@"; exit 1 ;;
esac
echo "%(nome)s $*" >> "$MEOW_COMPLETO_REGISTRO"
exit 1
"""
# O `git` fica — o servidor lê o `remote` dele para o «Créditos» —, menos os
# verbos que vão à rede.
GIT_SH = """#!/bin/bash
case " $* " in
  *" clone "*|*" fetch "*|*" pull "*|*" push "*|*" ls-remote "*|*" submodule "*)
    echo "git $*" >> "$MEOW_COMPLETO_REGISTRO"; exit 1 ;;
esac
IFS=: read -ra _dirs <<< "$PATH"
for _d in "${_dirs[@]}"; do
  [ "$_d" = "%(falso)s" ] && continue
  [ -x "$_d/git" ] && exec "$_d/git" "$@"
done
exit 127
"""
LEITURAS = {
    "systemctl": '*" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*'
                 '|*" status "*|*" cat "*|*" list-units "*|*" list-unit-files "*'
                 '|*" show-environment "*|*" --version "*',
    "gsettings": '" get "*|*" get "*|" list-"*|" range "*|" describe "*|" writable "*',
    "dconf": '" read "*|" list "*|" dump "*',
    "busctl": '*" get-property "*|*" introspect "*|*" FindUserByName "*',
}

# O SINAL SÓ ENTRA NA CASA. O alvo é conferido pelo `HOME` do ambiente dele,
# que todo processo que o painel sobe herda do brinquedo. `-0` e `-l` são
# pergunta, e seguem. Job do próprio shell (`%1`) é filho de quem chama.
#   SEM CANO, E ISSO É MEDIDO: a primeira versão lia o ambiente com
# `tr | grep -q`, e o `app/run.sh` roda com `set -o pipefail`. O `grep -q` fecha
# o cano no primeiro acerto, o `tr` morre de SIGPIPE, e o `pipefail` transforma
# o acerto em erro — o `kill` do `limpar()` do run.sh recusava o próprio
# servidor como "fora da casa", e cada corrida deixava um painel órfão de pé
# (dezesseis, contados em 24/09/2026). É a armadilha que o `tests/todos.sh`
# descreve; o `grep -z` lê o arquivo sozinho.
#   As funções vão para o bash de duas formas, e as duas são necessárias: o
# `kill` BINÁRIO é um script que as carrega (é o que um `subprocess` acha no
# PATH), e o BUILTIN do bash só é vencido por uma função exportada no ambiente
# (`BASH_FUNC_<nome>%%`) — é o mesmo gesto do `tests/doctor-so-le.sh`.
FUNCOES_BASH = {
    "_meow_na_casa": r"""() {
  case "$1" in %*) return 0 ;; esac
  grep -qxzF "HOME=$MEOW_COMPLETO_CASA" "/proc/$1/environ" 2>/dev/null
}""",
    "_meow_kill": r"""() {
  local a p rc=0 sinal=() alvos=()
  for a in "$@"; do
    case "$a" in -0|-l|-L) builtin kill "$@"; return ;;
                 -*) sinal+=("$a") ;; *) alvos+=("$a") ;; esac
  done
  for p in "${alvos[@]}"; do
    if _meow_na_casa "$p"; then builtin kill "${sinal[@]}" "$p" || rc=1
    else echo "kill(fora da casa) ${sinal[*]} $p" >> "$MEOW_COMPLETO_REGISTRO"; rc=1; fi
  done
  return "$rc"
}""",
    "kill": '() {  _meow_kill "$@"\n}',
    "pkill": '() {  echo "pkill(função) $*" >> "$MEOW_COMPLETO_REGISTRO"; return 1\n}',
    "killall": '() {  echo "killall(função) $*" >> "$MEOW_COMPLETO_REGISTRO"; return 1\n}',
}


def escrever_exec(caminho, corpo):
    with open(caminho, "w", encoding="utf-8") as fh:
        fh.write(corpo)
    os.chmod(caminho, 0o755)


def montar_casa():
    """Semeia a casa e a raiz de brinquedo; devolve o ambiente do servidor."""
    copiar_raiz()
    os.makedirs(os.path.dirname(CONF))
    os.makedirs(ESTADO)
    shutil.copyfile(os.path.join(RAIZ, "meow.conf.exemplo"), CONF)

    icones = os.path.join(CASA, ".local", "share", "icons")
    ponteiro = os.path.join(icones, valor_de("CURSOR"), "cursors")
    os.makedirs(ponteiro)
    xcursor_liso(os.path.join(ponteiro, "left_ptr"))
    tema = os.path.join(icones, valor_de("NOME_TEMA_ICONES"), "scalable", "apps")
    os.makedirs(tema)
    glifos = os.path.join(RAIZ, "assets", "icones", "arcticons-apps")
    for nome in sorted(os.listdir(glifos)):
        if nome.endswith(".svg"):
            shutil.copyfile(os.path.join(glifos, nome), os.path.join(tema, nome))
    # METADE ESCURA, METADE CLARA. O carrossel separa dia e noite pela luz de
    # cada imagem, e só monta o grupo da HORA (`e_noite`) se ele tiver duas ou
    # mais — senão tudo fica em `ativos/` e as abas Dia e Noite da galeria
    # nascem vazias. Com as seis escuras da primeira versão, o percurso passava
    # de noite e reprovava de dia: medido às 07:21 de 24/09/2026, "o grupo de
    # dia ficou com 1 imagem(ns)". Três de cada lado valem a qualquer hora.
    ativos = os.path.join(valor_de("WALLPAPER_BASE").replace("$HOME", CASA), "ativos")
    os.makedirs(ativos)
    for i in range(PAREDES):
        png_liso(os.path.join(ativos, f"brinquedo-{i:02d}.png"),
                 (0x1E + 8 * i, 0x1E, 0x2E) if i % 2 else (0xEE, 0xEE - 8 * i, 0xE0))

    # UMA PENDÊNCIA POR CONSERTO QUE O SERVIDOR CONHECE — o molde do
    # `tests/app-acessibilidade.py`, lido do `ACAO_DA_PENDENCIA` da fonte.
    import ast
    with open(os.path.join(RAIZ, "app", "servidor.py"), encoding="utf-8") as fh:
        arvore = ast.parse(fh.read())
    pendencias = []
    for no in arvore.body:
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "ACAO_DA_PENDENCIA" for a in no.targets)):
            pendencias = sorted(ast.literal_eval(no.value))
    # E UMA DE TEMA DE TERCEIRO, a que ganha dois botões e não um (P53, achados
    # 3 e 4): o servidor as reconhece pelo SUFIXO do id, e não por linha no
    # `ACAO_DA_PENDENCIA`. O sufixo sai da fonte, e o app é o primeiro módulo
    # que chama a leitura no caminho que escreve (`pergunte`) — é esse o
    # módulo que registra a linha, e ele muda sem ninguém vir aqui.
    for no in arvore.body:
        if (isinstance(no, ast.Assign)
                and any(getattr(a, "id", "") == "SUFIXO_TEMA_DE_TERCEIRO" for a in no.targets)):
            modulos = os.path.join(RAIZ, "assets", "temas-de-apps")
            for app in sorted(os.listdir(modulos)):
                try:
                    with open(os.path.join(modulos, app, "manifesto.sh"), encoding="utf-8") as fh:
                        if re.search(r"meow_app_tema_no_ar .* pergunte\b", fh.read()):
                            pendencias.append(app + ast.literal_eval(no.value))
                            break
                except OSError:
                    continue
    with open(os.path.join(ESTADO, "pendencias.tsv"), "w", encoding="utf-8") as fh:
        for ident in pendencias:
            fh.write(f"{ident}\tteste\tPendência plantada pelo teste ({ident})"
                     f"\t./scripts/teste.sh {ident}\t2026-09-24T00:00:00-03:00\n")

    # UMA HISTÓRIA DE PACK COM MARKDOWN HOSTIL — P53, achado 6. A página passou
    # a montar títulos, listas, negrito, código e link a partir do `LEIA-ME.md`
    # de quem publicou o pack, numa página com token de sessão. O `tests/pack.sh`
    # confere o CÓDIGO (nada de `innerHTML`); aqui se confere o EFEITO, no
    # navegador: a tag sai como texto, o `javascript:` não vira link, e o
    # negrito vira negrito (ver `conferir_historia`). O arquivo é o que o
    # pack padrão declara em `vitrine.descricao`, na CÓPIA da raiz.
    padrao = subprocess.run([sys.executable, os.path.join(RAIZ_B, "scripts", "pack.py"), "padrao"],
                            capture_output=True, text=True).stdout.strip()
    with open(os.path.join(padrao, "pack.json"), encoding="utf-8") as fh:
        historia = (json.load(fh).get("vitrine") or {}).get("descricao")
    if historia:
        with open(os.path.join(padrao, historia), "a", encoding="utf-8") as fh:
            fh.write("\n## Teste da casa de brinquedo\n\n"
                     "Um " + HOSTIL + " no texto, um [link mau](javascript:window.__meow_xss=2)"
                     " e **negrito de brinquedo**.\n")

    # UM JOGO DA STEAM, no molde do `tests/um-cartao-por-jogo.sh`: o manifesto
    # diz que está instalado, e o `.desktop` da própria Steam o anuncia. A capa
    # vertical é o que põe o jogo na grade (`_capa_do_jogo`), e a pasta em
    # `common/` é o que acende o «Apagar os arquivos» — que o teste aperta, e
    # que apaga ESTA pasta, de brinquedo.
    steamapps = os.path.join(CASA, ".steam", "steam", "steamapps")
    os.makedirs(os.path.join(steamapps, "common", "JogoDeBrinquedo"))
    with open(os.path.join(steamapps, "common", "JogoDeBrinquedo", "jogo.bin"), "w") as fh:
        fh.write("brinquedo\n")
    with open(os.path.join(steamapps, f"appmanifest_{APPID}.acf"), "w",
              encoding="utf-8") as fh:
        fh.write('"AppState"\n{\n\t"appid"\t\t"%s"\n\t"name"\t\t"Jogo de Brinquedo"\n'
                 '\t"installdir"\t\t"JogoDeBrinquedo"\n}\n' % APPID)
    capa = os.path.join(CASA, ".steam", "steam", "appcache", "librarycache", APPID)
    os.makedirs(capa)
    png_liso(os.path.join(capa, "library_600x900.jpg"), (0x88, 0x44, 0xCC), 60, 90)
    hicolor = os.path.join(icones, "hicolor", "256x256", "apps")
    os.makedirs(hicolor)
    png_liso(os.path.join(hicolor, f"steam_icon_{APPID}.png"), (0x44, 0x88, 0xCC))
    aplicativos = os.path.join(CASA, ".local", "share", "applications")
    os.makedirs(aplicativos)
    with open(os.path.join(aplicativos, f"steam_app_{APPID}.desktop"), "w",
              encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nName=Jogo de Brinquedo\n"
                 f"Exec=steam steam://rungameid/{APPID}\nIcon=steam_icon_{APPID}\n"
                 "Terminal=false\nType=Application\nCategories=Game;\n")
    # E A LOJA, QUE NÃO É JOGO (P77, achado 19): a Steam se declara `Game` e
    # registra o esquema `steam://`. Ela vai para a aba Ícones como programa,
    # e o `h_jogo` cobra que não apareça entre os jogos.
    with open(os.path.join(aplicativos, "steam.desktop"), "w", encoding="utf-8") as fh:
        fh.write("[Desktop Entry]\nName=Steam\nExec=steam %U\nIcon=steam\n"
                 "Terminal=false\nType=Application\nCategories=Network;FileTransfer;Game;\n"
                 "MimeType=x-scheme-handler/steam;x-scheme-handler/steamlink;\n")
    # A DECISÃO SEM MANIFESTO GANHA NOME NO CACHE DA STEAM (P54, achado 44). As
    # linhas do mapa da raiz de brinquedo cujo jogo não está aqui são as
    # «Decisões já executadas»; o nome da primeira mora só no `appinfo.vdf`.
    with open(os.path.join(RAIZ_B, "assets", "icones", "jogos-fora.map"),
              encoding="utf-8") as fh:
        orfas = [l.split(":")[0].strip() for l in fh
                 if l.strip() and not l.lstrip().startswith("#")
                 and l.split(":")[0].strip().isdigit() and l.split(":")[0].strip() != APPID]
    if orfas:
        appinfo_vdf(os.path.join(CASA, ".steam", "steam", "appcache", "appinfo.vdf"),
                    {orfas[0]: NOME_NA_STEAM})
    # E O PROGRAMA QUE O LANÇADOR ESCONDE (P54, achado 41), com nome e ícone
    # próprios: o `.desktop` da casa vence o do sistema, como no lançador.
    png_liso(os.path.join(hicolor, "leitor-de-brinquedo.png"), (0xCC, 0x88, 0x44))
    with open(os.path.join(aplicativos, PROGRAMA[0] + ".desktop"), "w",
              encoding="utf-8") as fh:
        fh.write(f"[Desktop Entry]\nName={PROGRAMA[1]}\nExec=true\n"
                 "Icon=leitor-de-brinquedo\nTerminal=false\nType=Application\n")
    # O PROGRAMA DE QUE UM AJUSTE DEPENDE (P77, achado 12): a marca
    # `[so-com-app …]` esconde o cartão numa máquina sem aquele programa. A
    # casa planta o primeiro id de cada marca — lido do `meow.conf` dela, e
    # não escrito aqui —, para o cartão continuar existindo e sendo testado.
    with open(CONF, encoding="utf-8") as fh:
        so_com = re.findall(r"\[so-com-app ([^\]\s]+)", fh.read())
    for ident in so_com:
        with open(os.path.join(aplicativos, ident + ".desktop"), "w", encoding="utf-8") as fh:
            fh.write("[Desktop Entry]\nName=Programa de Brinquedo\nExec=true\n"
                     "Terminal=false\nType=Application\n")

    # DUAS ÁREAS ALFINETADAS, no formato que o `areas.sh` escreve: sem área o
    # «Tirar uma área» não tem o que oferecer, e com uma só ele recusa — com
    # razão, medido na segunda corrida: "é a última área alfinetada".
    areas = os.path.join(CASA, ".config", "cosmic", "com.system76.CosmicComp", "v1")
    os.makedirs(areas)
    with open(os.path.join(areas, "pinned_workspaces"), "w", encoding="utf-8") as fh:
        fh.write("[\n" + "".join(
            '    (\n        output: (\n            name: "DP-1",\n'
            '            edid: None,\n        ),\n        tiling_enabled: false,\n'
            '        id: Some("%s"),\n        name: Some("%s"),\n    ),\n' % area
            for area in (("c0ffee", "Brinquedo"), ("decafe", "Quintal"))) + "]\n")

    # UM AJUSTE MUDADO DE FÁBRICA: a Início lista o que ela mudou, uma ficha por
    # chave, e numa casa nova a lista é vazia. Um texto livre, que não mexe em
    # mais nada da casa.
    with open(CONF, encoding="utf-8") as fh:
        texto = fh.read()
    with open(CONF, "w", encoding="utf-8") as fh:
        fh.write(re.sub(r'^FASTFETCH_TITULO="[^"]*"', 'FASTFETCH_TITULO="Casa de brinquedo"',
                        texto, count=1, flags=re.M))

    os.makedirs(FALSO)
    open(REGISTRO, "w").close()
    # O `cargo` entra com a rede: um applet compilado de verdade custa dezenas
    # de minutos e baixa crates — medido na primeira corrida, o instalador
    # chamou o `cargo build` dos dois applets.
    for nome in ("sudo", "pkexec", "pkill", "killall", "notify-send",
                 "systemd-run", "xdg-open", "curl", "wget", "cargo"):
        escrever_exec(os.path.join(FALSO, nome), RECUSA_SH)
    escrever_exec(os.path.join(FALSO, "git"), GIT_SH % {"falso": FALSO})
    for nome, leitura in LEITURAS.items():
        escrever_exec(os.path.join(FALSO, nome),
                      RESPONDE_SH % {"falso": FALSO, "nome": nome, "leitura": leitura})
    escrever_exec(os.path.join(FALSO, "kill"),
                  "#!/bin/bash\n"
                  + "".join(f"{n} {FUNCOES_BASH[n]}\n" for n in ("_meow_na_casa", "_meow_kill"))
                  + '_meow_kill "$@"\n')

    ambiente = {
        "PATH": FALSO + os.pathsep + os.environ.get("PATH", ""),
        "HOME": CASA, "USER": os.environ.get("USER", "meow"),
        "LANG": os.environ.get("LANG", "C.UTF-8"),
        "MEOW_CONF": CONF, "MEOW_ESTADO": ESTADO,
        "MEOW_PONTE": os.path.join(BRINQUEDO, "sem-ponte"),
        "MEOW_COMPLETO_REGISTRO": REGISTRO, "MEOW_COMPLETO_CASA": CASA,
    }
    for nome, corpo in FUNCOES_BASH.items():
        ambiente[f"BASH_FUNC_{nome}%%"] = corpo
    return ambiente


def encerrar_a_casa():
    """Todo processo que ainda carregue o ambiente da casa recebe TERM, e o
    que resistir, KILL. O `app/run.sh` já derruba o servidor que subiu; este é
    o cinto para o que um trabalho da gaveta tenha deixado em segundo plano —
    um teste que sai deixando processo de pé na máquina de quem roda é o
    contrário do que a casa de brinquedo promete."""
    import signal
    marca = ("MEOW_COMPLETO_CASA=" + CASA).encode()
    for tentativa in (signal.SIGTERM, signal.SIGKILL):
        vivos = []
        for pid in filter(str.isdigit, os.listdir("/proc")):
            if int(pid) == os.getpid():
                continue
            try:
                with open(f"/proc/{pid}/environ", "rb") as fh:
                    if marca in fh.read().split(bytes(1)):
                        os.kill(int(pid), tentativa)
                        vivos.append(pid)
            except OSError:
                continue
        if not vivos:
            return
        time.sleep(1)


def registro():
    with open(REGISTRO, encoding="utf-8") as fh:
        return [l.rstrip("\n") for l in fh if l.strip()]


def sobe_servidor(ambiente):
    """Sobe o painel da raiz de brinquedo; devolve (processo, url)."""
    proc = subprocess.Popen(
        [os.path.join(RAIZ_B, "app", "run.sh"), "--sem-abrir"],
        cwd=RAIZ_B, env=ambiente,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    url = None
    inicio = time.time()
    while time.time() - inicio < 40:
        linha = proc.stdout.readline()
        if not linha:
            break
        m = re.search(r"http://127\.0\.0\.1:\d+/\?t=[A-Za-z0-9_-]+", linha)
        if m:
            url = m.group(0)
            break
    return proc, url


# ===========================================================================
# O CENSO: todo controle da tela, com um nome estável
# ===========================================================================
# O nome é `contexto · papel`.
#   CONTEXTO é onde o controle mora: o cartão de um ajuste (pelo `data-chave`),
#   o cartão de uma ação (pelo título — a ação não tem outro identificador no
#   DOM), um MOLDE (o recipiente de um controle que nasce de dado), ou a aba
#   solta. Menu, topo, gaveta e caixa de pergunta são contextos da página, e
#   não de uma aba.
#   PAPEL é o que o controle faz ali: pelo `id`, pelo `data-*` que o declara
#   (`data-valor`, `data-acao-rapida`), pelo tipo (deslizante, seletor, campo),
#   e só no fim pelo nome acessível ou pelo texto — sem a contagem que alguns
#   rótulos trazem colada ("No carrossel 24").
#
# O censo MARCA cada elemento com `data-inventario="<nome>"`: é por essa marca
# que o acionador o acha logo depois, sem uma segunda regra de localização que
# pudesse discordar desta. Toda repintura da página apaga as marcas, e o
# acionador refaz o censo antes de cada gesto.
#
# O QUE CONTA COMO CONTROLE: todo elemento que recebe clique, foco ou texto e
# tem caixa na tela. O `<input type=file>` escondido não conta — ele não é
# alcançável, e quem o abre é o botão dele, que conta. O que está dentro de um
# `<details>` fechado ou de um balão escondido também não: aparece quando é
# aberto, e aí o censo o pega como controle REVELADO.
CENSO_JS = r"""
() => {
  const SEL = 'button, a[href], input, select, textarea, summary, [role=button],'
            + ' [role=switch], [role=checkbox], [role=tab], [role=menuitem],'
            + ' [contenteditable=""], [contenteditable=true],'
            + ' [tabindex]:not([tabindex="-1"])';
  /* O `checkVisibility` e não só a caixa: o conteúdo de um `<details>`
     fechado continua com caixa no Chromium e não recebe clique — o link do
     «Mais sobre este pack» era contado na tela estando fechado. */
  const visivel = (el) => {
    if (el.type === 'file') return false;
    const r = el.getBoundingClientRect();
    if (r.width === 0 && r.height === 0) return false;
    if (el.checkVisibility && !el.checkVisibility({ visibilityProperty: true }))
      return false;
    const cs = getComputedStyle(el);
    return cs.display !== 'none' && cs.visibility !== 'hidden';
  };
  const limpo = (t) => (t || '').replace(/\s+/g, ' ').trim();
  const semConta = (t) => limpo(t).replace(/\s*\d+$/, '').slice(0, 60);
  const titulo = (el, sel) => limpo((el.querySelector(sel) || {}).textContent);
  /* OS LUGARES: recipiente que não nasce de dado e dá nome ao que tem dentro.
     Aninham — um deslizante da oficina é «ícone do aplicativo › oficina». */
  const LUGARES = [
    ['article.cartao[data-chave]', (e) => 'ajuste ' + e.dataset.chave],
    ['article.acao', (e) => 'ação «' + titulo(e, 'h3') + '»'],
    ['.escolha-icone', () => 'ícone do aplicativo'],
    ['details.oficina', () => 'oficina'],
    ['details.oficina-edicao', () => 'edição do SVG'],
    ['.oficina-autoral', () => 'desenhos autorais'],
    ['.escolha-jogo', () => 'decisão do jogo'],
    ['#lista-pendentes', () => 'lista de escolhas'],
  ];
  /* OS MOLDES: recipiente de controle que nasce de DADO — um por pack, por
     papel de parede, por aplicativo, por cor da paleta. O de dentro ganha, e o
     papel do controle ali é o que ele FAZ, não o dado que ele carrega. */
  const MOLDES = [
    ['.ficha', 'ficha da lista', (el) => el.tagName === 'BUTTON' ? 'tirar' : null],
    ['.comandos .comando', 'linha de comando', () => 'Copiar'],
    ['.linha-pendente', 'escolha pendente', () => 'ir ao cartão'],
    ['.galeria figure', 'papel de parede', null],
    ['.grade-apps .app', 'aplicativo', () => 'abrir'],
    ['.grade-jogos .jogo', 'jogo da Steam', () => 'abrir'],
    ['.home-fichas .home-ficha', 'ajuste mudado', () => 'ir ao cartão'],
    ['.linha-orfa', 'jogo órfão', null],
    ['article.pack', 'cartão de pack', null],
    ['.pendencia', 'pendência', null],
    /* [P73: o desenho que não vale no app fica na pasta, apagado, com o porquê
       na dica — é outro papel, e o gesto dele é não fazer nada.] */
    ['.tira-glifos button.travado', 'desenho travado', () => 'dica'],
    ['.tira-glifos button', 'desenho do acervo', () => 'escolher'],
    ['.cores-grade button[data-cor]', 'cor', () => 'escolher'],
    ['.oficina-folha button', 'variação', () => 'escolher'],
    ['.oficina-autoral [role=group][aria-label="Desenho"] button', 'desenho autoral',
     () => 'escolher'],
    ['.oficina-autoral [role=group][aria-label="Papéis"] select', 'papel do desenho',
     () => 'seletor'],
  ];
  const zona = (el) => el.closest('#trilho') ? 'menu'
    : el.closest('header.topo') ? 'topo'
    : el.closest('#gaveta') ? 'gaveta'
    : el.closest('dialog') ? 'caixa'
    : el.closest('#torradas') ? 'torrada'
    : el.closest('#aviso-aplicar') ? 'aviso'
    : el.closest('#principal') ? 'aba' : 'página';
  const contexto = (el) => {
    const partes = [];
    for (const [sel, nome] of LUGARES) {
      const r = el.closest(sel);
      if (r) partes.push([r, nome(r)]);
    }
    /* De fora para dentro: quem contém vem antes. */
    partes.sort((a, b) => (a[0].contains(b[0]) ? -1 : b[0].contains(a[0]) ? 1 : 0));
    const nomes = partes.map((p) => p[1]);
    let papelDoMolde = null;
    for (const [sel, nome, papelDele] of MOLDES) {
      if (el.closest(sel)) { nomes.push(nome); papelDoMolde = papelDele; break; }
    }
    const z = zona(el);
    if (z !== 'aba') nomes.unshift(z);
    return { ctx: nomes.length ? nomes.join(' › ') : 'aba', papelDoMolde };
  };
  const papel = (el, ctx) => {
    const tag = el.tagName.toLowerCase();
    const rotulo = semConta(el.getAttribute('aria-label') || '');
    const noCartao = ctx.startsWith('ajuste ');
    if (el.id) return '#' + el.id;
    if (tag === 'input') {
      const t = (el.type || 'text').toLowerCase();
      if (t === 'range') return noCartao ? 'deslizante' : 'deslizante «' + rotulo + '»';
      if (t === 'time') return 'hora';
      if (t === 'search') return 'filtro «' + rotulo + '»';
      if (t === 'checkbox' || t === 'radio') return 'marca «' + rotulo + '»';
      if (el.classList.contains('nova')) return 'nova ficha';
      return noCartao ? 'campo' : 'campo «' + rotulo + '»';
    }
    if (tag === 'textarea') return 'texto «' + rotulo + '»';
    if (tag === 'select') return noCartao || ctx.startsWith('ação ') ? 'seletor'
                                                                   : 'seletor «' + rotulo + '»';
    /* O texto do `<summary>` sem o botão que mora nele (a oficina põe o «Usar»
       ali dentro): o nome é o do que abre, e não a soma dos dois. */
    if (tag === 'summary') return 'abre «' + semConta([...el.childNodes]
      .filter((n) => !(n.nodeType === 1 && n.matches('button, a, input, select')))
      .map((n) => n.textContent).join(' ')) + '»';
    if (el.closest('#trilho') && el.dataset.grupo) return el.dataset.grupo;
    if (tag === 'a') {
      const href = el.getAttribute('href') || '';
      if (href.startsWith('#')) return 'âncora «' + semConta(el.textContent) + '»';
      if (el.hasAttribute('download')) return 'baixa «' + semConta(el.textContent) + '»';
      return 'link externo';
    }
    if (el.classList.contains('porque')) return '?';
    if (el.classList.contains('lado-previa')) return 'Como está (desfaz o bloco)';
    if (el.classList.contains('desfazer-forma')) return 'Desfazer as escolhas da forma';
    /* O editor de SVG é o que a máquina tem («Abrir no gThumb» aqui, «Abrir
       no Boxy SVG» noutra): o papel é abrir no editor, qualquer que seja. */
    if (/^Abrir no /.test(limpo(el.textContent)) && ctx.includes('edição do SVG'))
      return 'Abrir no editor';
    if (el.dataset.acaoRapida) return 'ação rápida ' + el.dataset.acaoRapida;
    if ('valor' in el.dataset) return el.dataset.valor === '' ? 'deixar vazio' : 'opção';
    return rotulo || semConta(el.textContent) || tag;
  };
  const achados = {};
  for (const el of document.querySelectorAll(SEL)) {
    el.removeAttribute('data-inventario');
    if (!visivel(el)) continue;
    const { ctx, papelDoMolde } = contexto(el);
    const p = (papelDoMolde && papelDoMolde(el)) || papel(el, ctx);
    const nome = ctx + ' · ' + p;
    el.setAttribute('data-inventario', nome);
    const a = achados[nome] || (achados[nome] = { nome, zona: zona(el), n: 0,
      amostra: limpo(el.getAttribute('aria-label') || el.textContent).slice(0, 50) });
    a.n++;
  }
  return { aba: typeof ABA === 'undefined' ? '' : ABA,
           busca: (document.getElementById('busca') || {}).value || '',
           itens: Object.values(achados) };
}
"""


# ===========================================================================
# O QUE SE OBSERVA
# ===========================================================================
# A casa ANTES e DEPOIS de um gesto: caminho, tamanho e data de cada arquivo
# da casa e da raiz de brinquedo. Não é hash de conteúdo — são milhares de
# arquivos e o retrato é tirado dezenas de vezes; tamanho e data em
# nanossegundos pegam toda escrita que um script faça.
#
# O QUE NÃO ENTRA NO RETRATO, e cada linha é uma medição:
#   · o `.git` da raiz, que o `git init` criou e é do teste;
#   · o `meow.log` e o `ultimo-status`/`ultimo-*` do estado: o registro de
#     que um verbo rodou é a trilha de auditoria do projeto, e não escrita
#     na máquina;
#   · o `~/.cache`, onde o fontconfig e o próprio Chromium do sistema guardam
#     o que acharam — cache é, por definição, o que se pode apagar sem perda;
#   · o `lock` do estado, que é a trava de um instalador por vez: o ensaio a
#     toma como a execução de verdade (dois ensaios juntos também se atrapalham),
#     e ela não guarda dado nenhum. Medido na primeira corrida, 24/09/2026: era a
#     única "escrita" de cinco ensaios;
#   · o `__pycache__`, o bytecode que o Python grava ao importar o servidor.
FORA_DO_RETRATO = re.compile(
    r"^(raiz/\.git/|casa/\.cache/|casa/\.local/state/meowsystem/(meow\.log|ultimo-|lock$))"
    r"|.*/__pycache__/")


def retrato():
    """{caminho relativo ao brinquedo: (tamanho, data)} da casa e da raiz."""
    fotos = {}
    for base in (CASA, RAIZ_B):
        for pasta, _, arquivos in os.walk(base):
            for nome in arquivos:
                cam = os.path.join(pasta, nome)
                rel = os.path.relpath(cam, BRINQUEDO)
                if FORA_DO_RETRATO.match(rel):
                    continue
                try:
                    st = os.lstat(cam)
                except OSError:
                    continue
                fotos[rel] = (st.st_size, st.st_mtime_ns)
    return fotos


def diferenca(antes, depois):
    mudou = [c for c in depois if antes.get(c) != depois[c]]
    sumiu = [c for c in antes if c not in depois]
    return sorted(mudou + sumiu)


# O FIM DA GAVETA SAI DA NATUREZA DA AÇÃO — 24/09/2026, sprint P50 (achado 17)
#   A pastilha do fim era escolhida só pelo código de saída, e o percurso a
#   anotava na tabela sem cobrar nada: «Recarregar o painel» dizia «já estava
#   certo» depois de reciclar, e passava. Agora cada ação declara a natureza
#   dela no servidor, e a frase do fim tem de ser uma das que a tabela
#   `NATUREZAS` dá para ESSA natureza (a do `ensaio`, no «Ver o que faria») —
#   ou o «pulado» e o «saiu N» que valem para todas. A tabela é lida do
#   servidor da raiz de brinquedo, e não copiada aqui: uma cópia seria a
#   segunda lista que o teste passaria a conferir contra si mesma.
_NATUREZAS = {}


def frases_do_fim(natureza):
    if not _NATUREZAS:
        codigo = ("import json, sys; sys.path.insert(0, sys.argv[1]); import servidor; "
                  "print(json.dumps({n: sorted({f for _c, f in t.values()}) "
                  "for n, t in servidor.NATUREZAS.items()}))")
        ambiente = dict(os.environ, MEOW_RAIZ=RAIZ_B, HOME=CASA, MEOW_CONF=CONF)
        r = subprocess.run([sys.executable, "-c", codigo, os.path.join(RAIZ_B, "app")],
                           capture_output=True, text=True, env=ambiente)
        _NATUREZAS.update(json.loads(r.stdout or "{}"))
    return set(_NATUREZAS.get(natureza, [])) | {"pulado"}


# O REGISTRO DOS FALSOS, LIDO COMO VEREDITO
#   Um sinal fora da casa é defeito em QUALQUER gesto: é o painel da sessão
#   de verdade. Numa execução de verdade o resto é informação (o `systemctl
#   --user enable` do instalador bate no falso e é recusado — é o que ele
#   faria numa casa sem sessão); num ENSAIO, qualquer linha que não seja
#   pergunta (`sudo -n`, que só confere se há senha guardada) é o ensaio
#   tentando escrever — e o ensaio promete não escrever nada.
#   E baixar da internet sem a ação declarar `rede` é o servidor mentindo na
#   pastilha do cartão, que é a única coisa que ela lê antes de apertar.
SINAL_FORA = re.compile(r"^(pkill|killall|kill\(fora da casa\))")
PERGUNTA = re.compile(r"^sudo -n ")
REDE = re.compile(r"^(curl|wget) |^git (clone|fetch|pull|ls-remote|submodule)"
                  r"|^cargo (build|install|fetch) ")

# O QUE NA TELA É DEFEITO, E NÃO DADO. `null` e `undefined` sozinhos num nó de
# texto são a forma exata de um `append(null)` — o cartão que perdeu o
# controle e ganhou a palavra no lugar dele.
TEXTO_RUIM_JS = r"""
() => {
  const achados = [];
  const raizes = ['header.topo', '#trilho', '#conteudo', 'dialog[open]', '#torradas',
                  '#gaveta .gaveta-topo', '#aviso-aplicar'];
  for (const sel of raizes) {
    for (const raiz of document.querySelectorAll(sel)) {
      const andar = document.createTreeWalker(raiz, NodeFilter.SHOW_TEXT);
      let n;
      while ((n = andar.nextNode())) {
        const t = n.textContent;
        const pai = n.parentElement;
        if (!pai || pai.closest('script, style, template, .dica, code')) continue;
        if (pai.offsetParent === null && getComputedStyle(pai).position !== 'fixed') continue;
        const so = t.trim();
        if (so === 'null' || /\bundefined\b|\bNaN\b|\[object |\$\{/.test(t))
          achados.push(so.slice(0, 80) + '  (em ' + pai.tagName.toLowerCase()
                       + (pai.className ? '.' + String(pai.className).split(' ')[0] : '') + ')');
      }
    }
  }
  return achados;
}
"""

# A CASA E O CLONE NÃO APARECEM NA TELA — 24/09/2026, P52 (achados 10 e 13).
#   A varredura das 14 abas achou o caminho absoluto na caixa de confirmar, no
#   «ver comando», no topo da gaveta e em três balões de ícone. Aqui a régua é
#   a página inteira, e não só o que está visível agora: o balão `?` e o «ver
#   comando» estão no DOM fechados, e abrem com um clique. Os atributos que
#   viram texto (o balão, o nome acessível, o que o «Copiar» copia) contam
#   junto. Na saída da gaveta vale só a casa: um clone fora dela (`/opt`) não
#   diz o nome de ninguém, e é assim que o `servidor.py` a trata.
CAMINHO_JS = r"""
([casa, raiz]) => {
  const achados = [];
  const olhar = (texto, onde, soCasa) => {
    if (!texto) return;
    if (texto.includes(casa) || (!soCasa && texto.includes(raiz)))
      achados.push(texto.trim().slice(0, 80) + '  (em ' + onde + ')');
  };
  const andar = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
  let n;
  while ((n = andar.nextNode())) {
    const pai = n.parentElement;
    if (!pai || pai.closest('script, style, template')) continue;
    olhar(n.textContent, pai.tagName.toLowerCase() + (pai.id ? '#' + pai.id : ''),
          !!pai.closest('#saida'));
  }
  const nomes = ['title', 'aria-label', 'data-comando', 'placeholder'];
  for (const el of document.querySelectorAll('[title], [aria-label], [data-comando], [placeholder]'))
    for (const a of nomes) olhar(el.getAttribute(a), el.tagName.toLowerCase() + '[' + a + ']', false);
  return achados;
}
"""

# AS TORRADAS QUE NASCEM A PARTIR DE AGORA, com a classe e o texto — ver o
# `h_acervo`, que é quem precisa delas: a torrada some antes de a página parar.
TORRADAS_VISTAS_JS = r"""
() => {
  window.__torradasVistas = [];
  if (window.__torradasVigia) window.__torradasVigia.disconnect();
  window.__torradasVigia = new MutationObserver((ms) => {
    for (const m of ms) for (const n of m.addedNodes) {
      if (!n.classList || !n.classList.contains('torrada')) continue;
      const classe = ['ok', 'igual', 'erro'].find((c) => n.classList.contains(c)) || '';
      window.__torradasVistas.push({ classe, texto: n.textContent || '' });
    }
  });
  window.__torradasVigia.observe(document.getElementById('torradas'), { childList: true });
}
"""

# A PÁGINA PARADA: nenhuma mutação por `quieto` ms (a marca do censo não
# conta), com um teto — a gaveta de um trabalho vivo muda a cada 400 ms e
# nunca para sozinha.
ASSENTAR_JS = r"""
([quieto, teto]) => new Promise((pronto) => {
  let t = null;
  const fim = () => { obs.disconnect(); clearTimeout(t); clearTimeout(limite); pronto(); };
  const obs = new MutationObserver((ms) => {
    if (ms.every((m) => m.type === 'attributes' && m.attributeName === 'data-inventario')) return;
    clearTimeout(t); t = setTimeout(fim, quieto);
  });
  obs.observe(document.body, { subtree: true, childList: true, attributes: true, characterData: true });
  t = setTimeout(fim, quieto);
  const limite = setTimeout(fim, teto);
})
"""


# O que a página tentou buscar fora de 127.0.0.1 — a rota do contexto recusa
# e anota. É por aqui que o link externo prova para onde iria.
PEDIDOS_DE_FORA = []


def css_attr(valor):
    return valor.replace("\\", "\\\\").replace('"', '\\"')


class Percurso:
    """A visita. Guarda o que foi conferido, o que falhou e o que foi acionado."""

    def __init__(self, pag):
        self.pag = pag
        self.aba = "(abrindo)"
        self.gesto = ""
        self.falhas = []
        self.conferidas = 0
        self.acionados = set()
        self.esperadas = []          # [(status, trecho de url)] que o gesto pediu
        self.pedidos_vivos = 0
        self.nascidos = 0            # todo pedido que nasceu (o `assentar` compara)
        self.posts = []              # (url, corpo) de todo POST de ação
        self.acoes_vistas = {}       # id de ação -> como o percurso a exerceu
        self.tempos = {}             # aba -> segundos
        self.resultados = []         # (aba, ação, como, estado da gaveta, cauda)
        self.vistos = {}             # aba -> {nome: censo} de tudo o que apareceu
        self.url = ""
        self.base = {}               # aba -> censo da aba ao abrir
        self.rodadas = set()         # (ação, ensaio?) que já rodaram inteiras
        self.duracoes = {}           # nome -> segundos do gesto
        self.app_aberto = ""         # o aplicativo cujo painel o percurso abriu
        self.conhecidos_vistos = set()
        # [P77] As escolhas que revelaram o controle sendo acionado: o
        # `desfazer` de dentro de um revelado não as tira da bandeja, senão o
        # controle some no meio do próprio gesto (ver `acionar_revelados`).
        self.preservar = None
        pag.on("request", self._pedido)
        pag.on("requestfinished", self._fim_pedido)
        pag.on("requestfailed", self._pedido_falhou)
        pag.on("response", self._resposta)
        pag.on("console", self._console)
        pag.on("pageerror", lambda e: self.falha(f"erro de JavaScript: {e}"))

    # --- o placar ----------------------------------------------------------
    def falha(self, frase):
        onde = self.aba + (f" › {self.gesto}" if self.gesto else "")
        for padrao in DEFEITOS_CONHECIDOS:
            if re.search(padrao, frase):
                self.conhecidos_vistos.add(padrao)
                print(f"  ~~ [{onde}] conhecido, fora desta sprint: {frase}")
                return
        self.falhas.append((onde, frase))
        print(f"  XX [{onde}] {frase}")

    def checa(self, cond, frase):
        self.conferidas += 1
        if not cond:
            self.falha(frase)
        return bool(cond)

    # --- a rede ------------------------------------------------------------
    @staticmethod
    def _conta(req):
        return "/api/pulso" not in req.url and req.url.startswith("http://127.0.0.1")

    def _pedido(self, req):
        if not self._conta(req):
            return
        self.pedidos_vivos += 1
        self.nascidos += 1
        if req.method == "POST" and re.search(r"/api/(rodar|salvar|acervo|pack-importar|"
                                              r"importar|pendencia-recusar|jogo-fora|"
                                              r"app-icone|app-desenho|autorais|definir)",
                                              req.url):
            try:
                corpo = json.loads(req.post_data or "{}")
            except ValueError:
                corpo = {}
            self.posts.append((req.url.split("?")[0].rsplit("/", 1)[-1], corpo))

    def _fim_pedido(self, req):
        if self._conta(req):
            self.pedidos_vivos = max(0, self.pedidos_vivos - 1)

    def _pedido_falhou(self, req):
        if self._conta(req):
            self.pedidos_vivos = max(0, self.pedidos_vivos - 1)
            # Um `<img>` que a repintura descartou é abortado pelo próprio
            # navegador; isso é a página trocando de ideia, e não defeito.
            if "ERR_ABORTED" not in (req.failure or ""):
                self.falha(f"pedido falhou na rede: {req.url[:90]} ({req.failure})")

    def esperar_status(self, status, trecho):
        """O gesto seguinte vai provocar este 4xx de propósito."""
        self.esperadas.append((status, trecho))

    def _resposta(self, resp):
        if resp.status < 400 or not resp.url.startswith("http://127.0.0.1"):
            return
        for i, (st, trecho) in enumerate(self.esperadas):
            if st == resp.status and trecho in resp.url:
                del self.esperadas[i]
                return
        self.falha(f"resposta {resp.status} que ninguém pediu: {resp.url.split('?')[0][-60:]}"
                   + (f"?{resp.url.split('?', 1)[1][:70]}" if "?" in resp.url else ""))

    def _console(self, msg):
        if msg.type != "error":
            return
        # O `Failed to load resource` é o eco, no console, de uma resposta 4xx/5xx:
        # quem a julga é o `_resposta`, que sabe se ela foi pedida pelo gesto.
        if "Failed to load resource" in msg.text:
            return
        self.falha(f"erro no console: {msg.text[:160]}")

    # --- a página ----------------------------------------------------------
    def assentar(self, quieto=250, teto=8000):
        """Espera a rede (menos o pulso) e o DOM pararem.

        O PEDIDO QUE NASCE DEPOIS DO GESTO — 15/10/2026, P82 (item 37). A cura
        da integração da P80 (`e34845c`) valeu só para o `/api/pack-importar`:
        todo gesto cujo pedido nasce num salto assíncrono (o `close` de uma
        caixa) tinha a mesma janela. O pedido nascia enquanto o DOM assentava,
        e a espera de depois era de 3 s cravados; um servidor mais lento que
        isso deixava o gate conferir a tela antes da resposta. Agora o
        `assentar` conta os pedidos que NASCEM enquanto o DOM assenta (a
        janela é o próprio `quieto`), espera cada um deles pelo mesmo `teto`
        do gesto, e assenta o DOM de novo, porque a resposta repinta a tela.
        A volta tem limite: uma página que pergunta em laço não prende o gate.
        """
        fim = time.time() + teto / 1000
        while self.pedidos_vivos and time.time() < fim:
            self.pag.wait_for_timeout(40)
        for _volta in range(4):
            antes = self.nascidos
            self.pag.evaluate(ASSENTAR_JS, [quieto, max(300, int((fim - time.time()) * 1000))])
            if self.nascidos == antes and not self.pedidos_vivos:
                break
            fim = max(fim, time.time() + teto / 1000)
            while self.pedidos_vivos and time.time() < fim:
                self.pag.wait_for_timeout(40)

    def censo(self):
        """O censo de agora. Tudo o que ele vê fica anotado: o que aparece no
        meio de um gesto (a caixa, o «Copiar», o painel de um aplicativo) é
        conferido contra o inventário no fim, junto com o que estava na tela."""
        c = self.pag.evaluate(CENSO_JS)
        achados = {a["nome"]: a for a in c["itens"]}
        # O que é da aba conta na aba que a PÁGINA mostra (um gesto pode ter
        # levado a outra); com a busca preenchida, a tela mistura as abas.
        lugar = "(busca)" if c["busca"] else c["aba"]
        for nome, a in achados.items():
            chave = lugar if a["zona"] == "aba" else "topo"
            self.vistos.setdefault(chave, {}).setdefault(nome, a)
        return achados

    def achar(self, nome, i=0):
        """O i-ésimo elemento com este nome, com o censo refeito agora."""
        self.censo()
        loc = self.pag.locator(f'[data-inventario="{css_attr(nome)}"]')
        return loc.nth(i) if loc.count() > i else None

    def clicar_nome(self, nome, i=0):
        """Clica no i-ésimo elemento com este nome. Uma repintura entre o censo
        e o clique apaga a marca (é o que a página faz quando uma lista chega
        pela rede), e aí o censo é refeito e o clique tentado de novo — é o
        que uma pessoa faria com o botão que piscou."""
        for tentativa in range(4):
            el = self.esperar_nome(nome, teto=4.0) if i == 0 else self.achar(nome, i)
            if el is None:
                break
            try:
                el.click(timeout=2500)
                return
            except Exception:
                self.pag.wait_for_timeout(200)
        raise RuntimeError(f"não consegui clicar em «{nome}»")

    def esperar_nome(self, nome, teto=8.0):
        """O elemento, esperando a lista que o traz chegar da rede — depois de
        um trabalho a página relê a grade, e no meio dela mostra "lendo…"."""
        fim = time.time() + teto
        while True:
            el = self.achar(nome)
            if el is not None or time.time() > fim:
                return el
            self.pag.wait_for_timeout(150)

    def quantos(self, nome):
        self.censo()
        return self.pag.locator(f'[data-inventario="{css_attr(nome)}"]').count()

    def js(self, codigo, arg=None):
        return self.pag.evaluate(codigo, arg)

    def abrir_aba(self, grupo):
        """Pelo menu lateral, como uma pessoa abriria."""
        self.pag.locator(f'#trilho button[data-grupo="{css_attr(grupo)}"]').click()
        self.assentar(quieto=350)

    def aba_atual(self):
        return self.js("() => ABA")

    def voltar(self):
        """Deixa a página como a aba começou: sem caixa aberta, sem trabalho
        correndo, sem escolha pendente, sem busca, na aba certa."""
        if self.js("() => !!document.querySelector('dialog[open]')"):
            self.pag.keyboard.press("Escape")
            self.assentar()
        self.esperar_trabalho()
        if self.js("() => MUDANCAS.size") > 0:
            self.descartar()
        if self.pag.locator("#busca").input_value():
            self.pag.fill("#busca", "")
            self.assentar()
        if self.js("() => !!document.getElementById('lista-pendentes')"):
            self.pag.keyboard.press("Escape")
        if self.aba not in ("topo",) and self.aba_atual() != self.aba:
            self.abrir_aba(self.aba)

    def descartar(self):
        """O Descartar do banner, e a pergunta que ele faz com 2+ escolhas."""
        self.censo()
        self.acionados.add("topo · #botao-descartar")
        self.pag.locator("#botao-descartar").click()
        self.assentar()
        if self.pag.locator("#confirmar[open]").count():
            self.pag.locator("#confirmar-ok").click()
            self.assentar()

    def esperar_trabalho(self, teto=240):
        """Espera o trabalho da gaveta acabar e devolve (estado, saída)."""
        if self.js("() => TRABALHO !== null"):
            try:
                self.pag.wait_for_function("() => TRABALHO === null", timeout=teto * 1000)
            except Exception:
                self.falha(f"o trabalho não acabou em {teto} s")
                return None
            self.assentar()
        return (self.pag.locator("#gaveta-estado").inner_text(),
                self.pag.locator("#saida").inner_text())

    def texto_ruim(self):
        for achado in self.js(TEXTO_RUIM_JS):
            self.falha(f"texto de defeito na tela: {achado!r}")
        for achado in self.js(CAMINHO_JS, [CASA, RAIZ_B]):
            self.falha(f"a casa ou o caminho do clone na tela: {achado!r}")

    # ======================================================================
    # AS AÇÕES: o protocolo das três respostas
    # ======================================================================
    # Todo controle que roda uma ação do servidor passa por aqui, e o controle
    # não precisa dizer QUAL ação roda: o protocolo descobre pelo que o clique
    # faz — a caixa que abre (o título dela é o rótulo da ação) ou o POST que
    # sai. É o mesmo gesto para o «Executar» de um cartão, a ação rápida da
    # Início, o «Resolver» de uma pendência e o «Usar» de um papel de parede.
    #
    # Com caixa, as TRÊS respostas são dadas, uma por clique:
    #   1. Cancelar — e nada pode ter ido ao servidor, nem a casa mudado;
    #   2. Ver o que faria, quando a caixa o oferece — o ensaio roda, a faixa
    #      amarela aparece, e a casa NÃO muda: nem arquivo, nem falso chamado;
    #   3. Rodar — de verdade, na casa de brinquedo; menos nas EXCEÇÕES, que
    #      ficam provadas protegidas pelas duas primeiras.
    ACOES_JS = r"""
    () => (ESQUEMA.acoes || []).map((a) => ({
      id: a.id, rotulo: a.rotulo, escreve: !!a.escreve, sudo: !!a.sudo,
      confirma: !!a.confirma, destrutivo: !!a.destrutivo, rede: !!a.rede,
      natureza: a.natureza || "" }))
    """

    # O selo da rede à vista na porta da ação: o botão rápido da Início (selo
    # logo depois dele) ou o cartão da ação (selo no rodapé). Decisão 7, P78.
    SELO_DA_REDE_JS = r"""
    (a) => {
      const visivel = (e) => !!e && e.offsetParent !== null;
      const rapido = document.querySelector(`[data-acao-rapida="${a.id}"]`);
      if (visivel(rapido) && rapido.nextElementSibling
          && rapido.nextElementSibling.matches(".p-rede")) return true;
      return [...document.querySelectorAll("article.acao")]
        .some((c) => visivel(c) && c.textContent.includes(a.rotulo) && visivel(c.querySelector(".p-rede")));
    }
    """

    def acoes(self):
        return {a["id"]: a for a in self.js(self.ACOES_JS)}

    def acao_por_rotulo(self, rotulo):
        return next((a for a in self.acoes().values() if a["rotulo"] == rotulo), None)

    def caixa_aberta(self, teto=4.0):
        fim = time.time() + teto
        while time.time() < fim:
            if self.pag.locator("#confirmar[open]").count():
                self.censo()
                return True
            self.pag.wait_for_timeout(50)
        return False

    def esperar_post(self, n0, teto=4.0):
        fim = time.time() + teto
        while time.time() < fim:
            if len(self.posts) > n0:
                return self.posts[n0]
            if self.pag.locator("#confirmar[open]").count():
                return None
            self.pag.wait_for_timeout(50)
        return None

    def gesto_de_acao(self, clicar, rotulo=""):
        """Clica, descobre a ação e dá as respostas que ela aceita."""
        antes, reg0, n0 = retrato(), len(registro()), len(self.posts)
        clicar()
        post = self.esperar_post(n0)
        if self.caixa_aberta(0.3 if post else 4.0):
            return self._com_caixa(clicar, antes, reg0, n0)
        if not post:
            self.falha(f"o clique em «{rotulo}» não abriu caixa nem pediu nada ao servidor")
            return
        destino, corpo = post
        ident = corpo.get("acao") or ("instalar" if destino == "salvar" else "")
        acao = self.acoes().get(ident)
        if not self.checa(acao, f"o POST /api/{destino} pediu a ação {ident!r}, que o "
                                "servidor não declara"):
            return
        self.acoes_vistas.setdefault(ident, set()).add("sem caixa")
        # Pedir senha ou baixar da internet SEM PERGUNTAR é o que as exceções
        # existem para impedir: se isso roda direto, a exceção não protege nada.
        # [Decisão 7 da leva G, P78: o REPARO que baixa roda sem pergunta, e o
        #  que se cobra dele é o selo «baixa da internet» à vista na porta.]
        if reparo_que_baixa(acao):
            self.checa(self.js(self.SELO_DA_REDE_JS, acao),
                       f"«{acao['rotulo']}» baixa da internet sem pergunta (é reparo), "
                       f"e a porta dele mostra o selo «baixa da internet»")
        else:
            self.checa(not (acao["sudo"] or acao["rede"]),
                       f"«{acao['rotulo']}» rodou sem caixa de pergunta, e declara "
                       f"{'pedir senha' if acao['sudo'] else 'baixar da internet'}")
        self.conferir_trabalho(acao, bool(corpo.get("seco")), antes, reg0)
        # O CONSERTO QUE NASCE NA GAVETA — QA da P77, 10/10/2026. O conferir
        # que sai 1 deixa o botão da ação que conserta ao lado do «Fechar»
        # (`conserta_com`, servidor); ele é um gesto de ação como outro qualquer.
        botao = self.pag.locator("#gaveta-consertar")
        if botao.count() and botao.is_visible():
            self.censo()             # o botão entra no que apareceu, antes de sumir no clique
            self.acionados.add("gaveta · #gaveta-consertar")
            # [Integração da onda 2: a porta da gaveta também mostra o selo da
            #  rede quando a ação que conserta baixa (decisão 7, P78). Conferido
            #  ANTES do clique, porque o botão e o selo somem nele.]
            conserto = self.acao_por_rotulo(botao.inner_text().strip())
            if conserto and reparo_que_baixa(conserto):
                self.checa(self.js("""() => {
                    const b = document.querySelector('#gaveta-consertar');
                    const s = b && b.nextElementSibling;
                    return !!s && s.matches('.p-rede') && s.offsetParent !== null; }"""),
                           f"«{conserto['rotulo']}» na gaveta mostra o selo «baixa da "
                           f"internet» logo depois do botão")
            self.gesto_de_acao(lambda: botao.click(), botao.inner_text().strip())

    def _com_caixa(self, clicar, antes, reg0, n0):
        titulo = self.pag.locator("#confirmar-titulo").inner_text().strip()
        acao = self.acao_por_rotulo(titulo)
        if acao is None:
            # Caixa de pergunta que não é de ação do servidor (o «Não
            # perguntar de novo?» da pendência): quem a chamou cuida dela.
            return titulo
        ident = acao["id"]
        oferece = self.pag.locator("#confirmar-ensaio").is_visible()
        self.checa(self.pag.locator("#confirmar-comando").inner_text().strip(),
                   f"a caixa de «{titulo}» mostra o comando que vai rodar")
        # O COMANDO DA CAIXA COLA EM QUALQUER MÁQUINA — P52, achado 10. Sem a
        # casa e sem o caminho do clone: `meow …`, `./script.sh …` ou `~/…`.
        cmd = self.pag.locator("#confirmar-comando").inner_text()
        self.checa(CASA not in cmd and RAIZ_B not in cmd,
                   f"a caixa de «{titulo}» mostra o comando sem a casa nem o "
                   f"caminho do clone ({cmd.strip()[:60]!r})")
        self.checa(oferece == (acao["sudo"] or acao["destrutivo"]),
                   f"a caixa de «{titulo}» oferece o «Ver o que faria» "
                   "exatamente quando a ação pede senha ou desfaz algo")
        vistas = self.acoes_vistas.setdefault(ident, set())
        # A CAIXA DO SUDO É UMA LINHA, E O PORQUÊ É O «?» — P79, decisão 11.
        if acao["sudo"]:
            sudo = self.pag.locator("#confirmar-sudo")
            self.checa(sudo.is_visible() and "\n" not in sudo.locator("strong").inner_text().strip(),
                       f"a caixa de «{titulo}» diz o sudo em uma linha")
            if self.achar("caixa · ?") is not None:
                self.h_porque("caixa · ?")
                self.acionados.add("caixa · ?")

        # 1. Cancelar
        self.pag.locator("#confirmar button[value=nao]").click()
        self.acionados.add("caixa · Cancelar")
        self.assentar(quieto=150)
        self.checa(len(self.posts) == n0,
                   f"Cancelar em «{titulo}» não pede nada ao servidor"
                   + (f" — pediu {self.posts[n0:]}" if len(self.posts) > n0 else ""))
        self.esperar_trabalho()
        mudou = diferenca(antes, retrato())
        self.checa(not mudou, f"Cancelar em «{titulo}» não muda a casa — mudou {mudou[:4]}")
        vistas.add("cancelar")

        # 2. Ver o que faria
        rodou = False
        if oferece:
            n1, reg1, antes1 = len(self.posts), len(registro()), retrato()
            clicar()
            if not self.checa(self.caixa_aberta(), f"«{titulo}» pergunta de novo no segundo clique"):
                return titulo
            self.pag.locator("#confirmar-ensaio").click()
            self.acionados.add("caixa · #confirmar-ensaio")
            post = self.esperar_post(n1)
            self.checa(post and post[1].get("seco") is True,
                       f"«Ver o que faria» em «{titulo}» pede o ensaio ao servidor")
            self.conferir_trabalho(acao, True, antes1, reg1)
            vistas.add("ensaio")
            if ident not in EXCECOES and self.pag.locator("#ensaio-rodar").count():
                n2, reg2, antes2 = len(self.posts), len(registro()), retrato()
                self.pag.locator("#ensaio-rodar").click()
                self.acionados.add("gaveta · #ensaio-rodar")
                post = self.esperar_post(n2)
                self.checa(post and post[1].get("seco") is False,
                           f"«Rodar de verdade» depois do ensaio de «{titulo}» roda sem ensaio")
                self.conferir_trabalho(acao, False, antes2, reg2)
                vistas.add("rodar")
                rodou = True

        # 3. Rodar
        if ident in EXCECOES:
            vistas.add("protegida")
            return titulo
        if not rodou:
            n3, reg3, antes3 = len(self.posts), len(registro()), retrato()
            clicar()
            if not self.checa(self.caixa_aberta(), f"«{titulo}» pergunta de novo no último clique"):
                return titulo
            self.pag.locator("#confirmar-ok").click()
            self.acionados.add("caixa · #confirmar-ok")
            post = self.esperar_post(n3)
            self.checa(post and not post[1].get("seco"),
                       f"«Rodar» em «{titulo}» pede ao servidor a execução de verdade")
            self.conferir_trabalho(acao, False, antes3, reg3)
            vistas.add("rodar")
        return titulo

    # O QUE NA SAÍDA É QUEBRA, E NÃO RESPOSTA. A casa de brinquedo não tem
    # sessão, rede nem senha, e muita ação honesta responde "não achei" ou sai
    # 2 lá dentro — isso é a ação dizendo a verdade sobre a casa. Traceback,
    # variável sem valor e comando inexistente não são resposta de ninguém:
    # são o programa quebrado.
    QUEBRA = re.compile(r"Traceback \(most recent call last\)|unbound variable|"
                        r"command not found|comando não encontrado|syntax error|"
                        r"erro de sintaxe|: line \d+: |: linha \d+: ")

    def conferir_trabalho(self, acao, seco, antes, reg0):
        rot = acao["rotulo"]
        # A resposta do POST é quem abre a gaveta: primeiro ela chega.
        self.assentar(quieto=100)
        if not self.checa(self.js("() => !document.getElementById('gaveta').hidden"),
                          f"«{rot}» abriu a gaveta"):
            return
        # A MESMA AÇÃO POR OUTRA PORTA — o «Conferir a máquina» da Início e o
        # da aba Instalação são dois botões para o mesmo `doctor`. A porta já
        # provou o que tinha de provar (pediu a ação certa, abriu a gaveta);
        # esperar o trabalho inteiro de novo mediria a ação duas vezes. Aqui o
        # «Parar» ganha a vez, que é também onde ele é conferido.
        #   SÓ PARA QUEM NÃO ESCREVE, OU PARA O ENSAIO: uma ação que escreve,
        # repetida, costuma vir com outro argumento (outra imagem, outro lado),
        # e o gesto que a chamou confere o efeito dela depois — interrompida,
        # ela não o teria. Medido numa corrida da suíte: o «Medir» da aba Noite
        # parado antes de gravar o `lado.tsv`.
        chave = (acao["id"], seco)
        if (chave in self.rodadas and (seco or not acao["escreve"])
                and self.js("() => TRABALHO !== null")):
            parar = self.pag.locator("#parar")
            try:
                # O trabalho pode acabar entre a pergunta e o clique — aí o
                # «Parar» se apaga, e esperar por ele seria esperar por nada.
                if parar.is_enabled():
                    parar.click(timeout=1500)
                    self.acionados.add("gaveta · #parar")
            except Exception:
                pass
            # Um trabalho de décimos de segundo acaba antes do clique chegar:
            # aí não há o que interromper, e o «Parar» é conferido de verdade
            # no ensaio do instalador (ver `h_salvar`).
            fim = self.esperar_trabalho(teto=60)
            if fim:
                self.resultados.append((self.aba, rot, "por outra porta", fim[0], ""))
            return
        self.rodadas.add(chave)
        fim = self.esperar_trabalho(teto=300)
        if fim is None:
            return
        estado, saida = fim
        self.acionados.add("gaveta · #gaveta-estado")
        self.checa(saida.strip(), f"«{rot}» mostrou a saída na gaveta")
        # A GAVETA NÃO TRAZ A CASA DE NINGUÉM — P52. O comando do topo sai como
        # a pessoa o digitaria, e as linhas trocam a casa por `~`.
        topo = self.pag.locator("#gaveta-comando").inner_text()
        self.checa(CASA not in topo and RAIZ_B not in topo,
                   f"a gaveta de «{rot}» mostra o comando sem a casa nem o caminho "
                   f"do clone ({topo.strip()[:60]!r})")
        self.checa(CASA not in saida,
                   f"a saída de «{rot}» na gaveta troca a casa por ~")
        for linha in saida.splitlines():
            if self.QUEBRA.search(linha):
                self.falha(f"«{rot}» quebrou: {linha.strip()[:140]}")
                break
        if seco:
            self.checa(self.pag.locator("#faixa-ensaio").count(),
                       f"o ensaio de «{rot}» ganha a faixa «ENSAIO · nada foi escrito»")
        novas = registro()[reg0:]
        for linha in novas:
            if SINAL_FORA.match(linha):
                self.falha(f"«{rot}» mandou sinal para fora da casa: {linha[:120]}")
            elif REDE.match(linha) and not acao["rede"]:
                self.falha(f"«{rot}» tentou baixar sem declarar rede: {linha[:120]}")
            elif seco and not PERGUNTA.match(linha):
                self.falha(f"o ensaio de «{rot}» tentou escrever: {linha[:120]}")
        if seco or not acao["escreve"]:
            mudou = diferenca(antes, retrato())
            self.checa(not mudou, f"«{rot}» {'em ensaio ' if seco else ''}não muda a casa"
                                  f" — mudou {len(mudou)}: {mudou[:4]}")
        # O ESTADO DA GAVETA É INFORMAÇÃO, E NÃO VEREDITO: na casa de
        # brinquedo não há sessão, rede nem senha, e uma ação honesta sai 2
        # dizendo isso ("não consegui armar o timer"). Ele vai para a tabela do
        # fim, e quem reprova é a QUEBRA, logo acima.
        frase = estado.split(" · ")[0].strip().lower()
        natureza = "ensaio" if seco else acao.get("natureza", "")
        self.checa(frase in frases_do_fim(natureza) or re.match(r"saiu -?\d+$", frase),
                   f"o fim de «{rot}» ({estado.strip()}) é uma frase da natureza "
                   f"«{natureza}», e não só do código de saída")
        cauda = ""
        if re.match(r"saiu ", frase):
            cauda = " / ".join(l.strip() for l in saida.splitlines() if l.strip())[-160:]
        self.resultados.append((self.aba, rot, "ensaio" if seco else "de verdade", estado, cauda))

    # ======================================================================
    # OS AJUSTES: cada forma de controle de um cartão
    # ======================================================================
    # O efeito cobrado é o que a pessoa vê e o que o Salvar leva: a marca no
    # botão e a escolha na bandeja (`MUDANCAS`, que é o que o «1 escolha» do
    # banner conta). E cada gesto termina desfeito — pelo Descartar, que é o
    # gesto dela — para o cartão seguinte começar do disco.
    CARTAO_JS = r"""
    (k) => {
      const c = document.querySelector(`#conteudo article.cartao[data-chave="${k}"]`);
      if (!c) return null;
      const x = c.cloneNode(true);
      x.querySelectorAll('[data-inventario]').forEach((e) => e.removeAttribute('data-inventario'));
      const item = ESQUEMA.chaves.find((i) => i.chave === k) || {};
      return { html: x.outerHTML, pendente: MUDANCAS.has(k),
               escolha: MUDANCAS.has(k) ? MUDANCAS.get(k) : null,
               disco: item.valor ?? '' };
    }
    """

    def cartao(self, chave):
        return self.js(self.CARTAO_JS, chave) or {"html": "", "pendente": False,
                                                  "escolha": None, "disco": ""}

    @staticmethod
    def chave_de(nome):
        return re.match(r"ajuste (\S+)", nome).group(1)

    # OS DESFAZERES DO BLOCO — «Como está» (o lado de antes da prévia, quando
    # há escolha pendente no bloco) e «Desfazer N escolhas» (a forma do painel
    # e da dock) — são revelados pela escolha pendente, e é o `desfazer` que os
    # aperta, antes do Descartar do banner: assim cada cartão com prévia os
    # exercita, e a prova é a bandeja esvaziar.
    DESFAZERES = (("#conteudo button.desfazer-forma", "aba · Desfazer as escolhas da forma"),
                  ("#conteudo button.lado-previa", "aba · Como está (desfaz o bloco)"))

    def desfazer(self):
        if self.preservar:
            # Dentro de um revelado: desfaz só o que o gesto de dentro escolheu.
            self.js("(manter) => { for (const k of [...MUDANCAS.keys()])"
                    " if (!manter.includes(k)) MUDANCAS.delete(k);"
                    " atualizarBarraSalvar(); render(); }", sorted(self.preservar))
            self.assentar(quieto=80, teto=3000)
            return
        for sel, nome in self.DESFAZERES:
            n = self.js("() => MUDANCAS.size")
            botao = self.pag.locator(sel)
            if n and botao.count() and botao.first.is_visible():
                self.censo()
                botao.first.click()
                self.assentar(quieto=80, teto=3000)
                self.checa(self.js("() => MUDANCAS.size") < n,
                           f"«{nome.split(' · ')[-1]}» tira da bandeja as escolhas do bloco")
                self.acionados.add(nome)
        if self.js("() => MUDANCAS.size") > 0:
            self.descartar()

    def h_porque(self, nome):
        el = self.achar(nome)
        dica = el.get_attribute("aria-controls")
        el.click()
        self.checa(el.get_attribute("aria-expanded") == "true"
                   and self.pag.locator(f"#{dica}").is_visible(),
                   "o «?» abre o balão da explicação")
        el.click()
        self.checa(el.get_attribute("aria-expanded") == "false"
                   and not self.js(f"() => !document.getElementById('{dica}').hidden"),
                   "e o segundo clique o fecha")

    def h_opcoes(self, nome):
        chave = self.chave_de(nome)
        # [P77, 10/10/2026: uma escolha pode REVELAR controles — o «Restaurar
        # ao padrão» que só existe com escolha feita, o cartão que o modo do
        # gato mostra. O que a escolha revelou é acionado logo, com a escolha
        # ainda na bandeja.]
        antes = set(self.censo())
        for i in range(self.quantos(nome)):
            el = self.achar(nome, i)
            if el is None:
                self.falha(f"a opção {i + 1} sumiu depois do clique na anterior")
                break
            if el.is_disabled():
                continue
            valor = el.get_attribute("data-valor")
            self.clicar_nome(nome, i)
            self.assentar(quieto=80, teto=3000)
            c = self.cartao(chave)
            # PELO VALOR, E NÃO PELA POSIÇÃO — 10/10/2026, P77. No controle por
            # área (Sim/Não por área, `controlePorArea`) o botão «Não» de uma
            # área grava vazio numa hora e uma lista na outra, e a fileira de
            # «opções» muda de tamanho entre um clique e o seguinte: a opção de
            # índice i depois do clique já não era a clicada. Com as áreas de
            # verdade na tela (duas, lidas do COSMIC), isso reprovava um clique
            # certo. O que se cobra é o que a frase diz: o valor clicado fica
            # marcado.
            seguro = (valor or "").replace("\\", "\\\\").replace('"', '\\"')
            marcado = self.pag.locator(
                f'#conteudo article.cartao[data-chave="{chave}"] '
                f'button[data-valor="{seguro}"][aria-pressed="true"]').count() > 0
            self.checa(marcado, f"{chave}: clicar em {valor!r} marca {valor!r}")
            self.checa(c["pendente"] == (valor != c["disco"]),
                       f"{chave}: {valor!r} {'entra' if valor != c['disco'] else 'não entra'}"
                       " na bandeja do Salvar")
            self.acionar_revelados(antes)
        self.desfazer()

    def mexer_no_cartao(self, chave):
        """Um gesto qualquer que mude o cartão — para provar que um botão de
        voltar (Restaurar, Automático, vazio) desfaz alguma coisa."""
        base = f'#conteudo article.cartao[data-chave="{chave}"]'
        faixa = self.pag.locator(f"{base} input[type=range]")
        if faixa.count():
            faixa.first.focus()
            no_fim = faixa.first.input_value() == faixa.first.get_attribute("max")
            self.pag.keyboard.press("Home" if no_fim else "End")
            return True
        opc = self.pag.locator(f'{base} button[data-valor]:not([data-valor=""])'
                               ':not([aria-pressed=true])')
        if opc.count():
            opc.first.click()
            return True
        campo = self.pag.locator(f"{base} input[type=time]")
        if campo.count():
            campo.first.fill("21:47")
            return True
        return False

    def h_botao_do_cartao(self, nome):
        """«Restaurar ao padrão», «Automático», o vazio: mudam o cartão."""
        chave = self.chave_de(nome)
        el = self.achar(nome)
        h0 = self.cartao(chave)["html"]
        el.click()
        self.assentar(quieto=80, teto=3000)
        h1 = self.cartao(chave)["html"]
        if h1 == h0:
            # Já estava no valor que o botão devolve: move antes, e o botão
            # tem de desfazer o movimento.
            self.checa(self.mexer_no_cartao(chave), f"{chave}: há um controle para mover")
            self.assentar(quieto=80, teto=3000)
            h2 = self.cartao(chave)["html"]
            el = self.achar(nome)
            if self.checa(el is not None, f"{chave}: «{nome.split(' · ')[-1]}» continua lá"):
                el.click()
                self.assentar(quieto=80, teto=3000)
                self.checa(self.cartao(chave)["html"] != h2,
                           f"{chave}: «{nome.split(' · ')[-1]}» muda o cartão")
        self.desfazer()

    def h_deslizante(self, nome):
        chave = self.chave_de(nome)
        antes = set(self.censo())
        el = self.achar(nome)
        if not self.checa(not el.is_disabled(), f"{chave}: o deslizante nasce livre"):
            return
        v0 = el.input_value()
        el.focus()
        self.pag.keyboard.press("Home" if v0 == el.get_attribute("max") else "End")
        self.assentar(quieto=80, teto=3000)
        c = self.cartao(chave)
        el = self.achar(nome)
        self.checa(el is not None and el.input_value() != v0 and c["pendente"],
                   f"{chave}: a tecla move o deslizante e a escolha entra na bandeja")
        self.acionar_revelados(antes)
        self.desfazer()

    def acionar_revelados(self, antes):
        """Aciona o que a escolha pendente revelou em OUTRO cartão — o nome de
        uma área em «Nomes das áreas» acende o Sim/Não da «Folga invisível».

        [P77, 10/10/2026: e o cartão que um MODO revela (Logo do sistema). A
        escolha que revelou fica na bandeja enquanto os de dentro são
        acionados: o `desfazer` deles só tira o que eles mesmos escolheram.]"""
        anterior = self.preservar
        self.preservar = set(self.js("() => [...MUDANCAS.keys()]") or []) | (anterior or set())
        try:
            for n in sorted(set(self.censo()) - antes):
                if (n.startswith("ajuste ") and not n.endswith(" · Aplicar")
                        and n not in self.acionados and self.acionador(n)):
                    self.acionar(n, limpar=False, esperar=False)
        finally:
            self.preservar = anterior

    def h_campo(self, nome):
        chave = self.chave_de(nome)
        antes = set(self.censo())
        el = self.achar(nome)
        v0 = el.input_value()
        h0 = self.cartao(chave)["html"]
        n_torradas = self.pag.locator("#torradas .torrada").count()
        el.fill((v0 + "1") if v0 else "1")
        el.press("Enter")
        self.assentar(quieto=120, teto=3000)
        c = self.cartao(chave)
        recusou = self.pag.locator("#torradas .torrada.erro").count() > 0 or \
            self.pag.locator("#torradas .torrada").count() > n_torradas
        self.checa(c["pendente"] or recusou or c["html"] != h0,
                   f"{chave}: escrever no campo e dar Enter entra na bandeja, ou a "
                   "página diz por que não")
        if c["pendente"]:
            self.acionar_revelados(antes)
            c = self.cartao(chave)
        if not c["pendente"]:
            el = self.achar(nome)
            if el is not None:
                el.fill(v0)
                el.press("Enter")
        self.desfazer()

    def h_hora(self, nome):
        chave = self.chave_de(nome)
        antes = set(self.censo())
        el = self.achar(nome)
        v0 = el.input_value()
        # O `fill` de um campo de hora já dispara o `change`, e o `change`
        # repinta a aba: o elemento de antes deixa de existir.
        el.fill("21:47" if v0 != "21:47" else "06:13")
        self.assentar(quieto=80, teto=3000)
        self.checa(self.cartao(chave)["pendente"], f"{chave}: a hora nova entra na bandeja")
        self.acionar_revelados(antes)
        self.desfazer()

    def h_nova_ficha(self, nome):
        chave = self.chave_de(nome)
        novo = "zzz-completo"
        base = f'#conteudo article.cartao[data-chave="{chave}"]'
        el = self.achar(nome)
        el.fill(novo)
        el.press("Enter")
        self.assentar(quieto=100, teto=3000)
        fichas = self.pag.locator(f"{base} .fichas")
        self.checa(novo in (fichas.inner_text() if fichas.count() else "")
                   and self.cartao(chave)["pendente"],
                   f"{chave}: o Enter desenha a ficha nova e a põe na bandeja")
        tirar = self.pag.locator(f'{base} .ficha button[aria-label="Tirar {novo}"]')
        if self.checa(tirar.count(), f"{chave}: a ficha nova tem o × dela"):
            tirar.first.click()
            self.assentar(quieto=100, teto=3000)
            self.checa(novo not in self.pag.locator(f"{base} .fichas").inner_text()
                       and not self.cartao(chave)["pendente"],
                       f"{chave}: o × tira a ficha, e a lista volta a ser a do disco")
            self.acionados.add(f"ajuste {chave} › ficha da lista · tirar")
        self.desfazer()

    # A FICHA DE PROGRAMA DIZ O PROGRAMA (P54, achado 41): o nome e o ícone do
    # `.desktop`, e o id no balão. Lido da tela, contra o que a casa plantou.
    FICHA_PROGRAMA_JS = r"""
    ([k, id]) => {
      const c = document.querySelector(`#conteudo article.cartao[data-chave="${k}"]`);
      if (!c) return null;
      const fichas = [...c.querySelectorAll('.ficha')];
      const f = fichas.find((x) => x.getAttribute('data-balao') === id);
      return { rotulos: fichas.map((x) => (x.querySelector(':scope > span') || {}).textContent),
               achou: !!f, texto: f ? f.querySelector(':scope > span').textContent : '',
               icone: !!(f && f.querySelector('img')) };
    }
    """

    def h_tirar_ficha(self, nome):
        chave = self.chave_de(nome)
        if chave == "LANCADOR_OCULTAR":
            f = self.js(self.FICHA_PROGRAMA_JS, [chave, PROGRAMA[0]]) or {}
            self.checa(f.get("achou") and f.get("texto") == PROGRAMA[1] and f.get("icone"),
                       f"{chave}: a ficha de {PROGRAMA[0]} mostra «{PROGRAMA[1]}» e o "
                       f"ícone do .desktop, com o id no balão ({f})")
            self.checa(PROGRAMA[0] not in (f.get("rotulos") or []),
                       f"{chave}: o id cru {PROGRAMA[0]} não aparece como rótulo de ficha")
        n0 = self.quantos(nome)
        self.achar(nome).click()
        self.assentar(quieto=100, teto=3000)
        self.checa(self.quantos(nome) == n0 - 1 and self.cartao(chave)["pendente"],
                   f"{chave}: o × tira uma ficha ({n0} → {self.quantos(nome)}) e a "
                   "lista nova entra na bandeja")
        self.desfazer()

    def h_seletor_ajuste(self, nome):
        chave = self.chave_de(nome)
        for i in range(self.quantos(nome)):
            el = self.achar(nome, i)
            atual = el.input_value()
            outros = [o for o in el.locator("option").evaluate_all(
                "(os) => os.map((o) => o.value)") if o != atual]
            if not outros:
                # Uma opção só nesta casa (a variante de pastas do único tema de
                # pastas instalado): nada a trocar, e ela está escolhida.
                self.checa(atual, f"{chave}: o seletor {i + 1} mostra a única opção")
                continue
            h0 = self.cartao(chave)["html"]
            el.select_option(outros[0])
            self.assentar(quieto=100, teto=3000)
            c = self.cartao(chave)
            self.checa(c["pendente"] or c["html"] != h0,
                       f"{chave}: trocar o seletor {i + 1} muda o cartão")
            self.desfazer()

    # ======================================================================
    # AS AÇÕES DA ABA
    # ======================================================================
    def h_executar(self, nome):
        rotulo = re.match(r"ação «(.*)» ·", nome).group(1)
        el = self.achar(nome)
        if el is not None and el.is_disabled():
            self.conferir_apagado(el, rotulo)
            return
        self.gesto_de_acao(lambda: self.clicar_nome(nome), rotulo)

    def h_par(self, nome):
        """O segundo botão do par «ver / aplicar» (P82, item 22): é o aplicar,
        e o gesto é o de qualquer ação — a caixa, se houver, e o trabalho."""
        rotulo = nome.split(" · ", 1)[1]
        self.gesto_de_acao(lambda: self.clicar_nome(nome), rotulo)

    # O «EXECUTAR» APAGADO DIZ POR QUÊ, COM OS NOMES DA TELA — 24/09/2026, P50
    #   Achados 32 e 33: «Pôr um gato no dock» com o gato por horário e «Gravar
    #   as áreas» sem área fixada rodavam e não faziam nada. Agora o botão se
    #   apaga — na casa de brinquedo, o `LOGO_MODO` de fábrica é `hora`, e os
    #   dois botões do gato nascem apagados. O que se cobra: o cartão diz o
    #   motivo, o motivo cita o ajuste pelo título do cartão dele e o valor
    #   pelo rótulo do botão (achado 47 — o nome sai de onde a tela o define),
    #   ou a ação que vem antes pelo rótulo dela; e o servidor recusa rodar a
    #   ação apagada mesmo com um POST direto.
    MOTIVO_JS = r"""
    (id) => {
      const a = (ESQUEMA.acoes || []).find((x) => x.id === id);
      if (!a || !a.indisponivel) return null;
      const m = a.indisponivel;
      /* `feito` (QA da P80): a ação já feita aponta a seguinte pelo rótulo dela. */
      const ref = m.antes || m.feito;
      const antes = ref ? (ESQUEMA.acoes.find((x) => x.id === ref) || {}).rotulo : null;
      return { antes, chave: m.chave ? nomeVisivel(m.chave) : null,
               vale: m.vale ? rotuloDeValor(m.vale) : null,
               pede: m.pede ? rotuloDeValor(m.pede) : null };
    }
    """

    def conferir_apagado(self, el, rotulo):
        acao = self.acao_por_rotulo(rotulo)
        if not self.checa(acao, f"o «Executar» apagado é de uma ação que o servidor declara ({rotulo})"):
            return
        cartao = el.locator("xpath=ancestor::article[1]")
        frase = cartao.locator("p.frase").all_inner_texts()
        motivo = self.js(self.MOTIVO_JS, acao["id"])
        if motivo is None:
            # O apagado de antes (P46): lista vazia. Continua dizendo por quê.
            self.checa(any(f.strip() for f in frase),
                       f"«{rotulo}» apagado diz por quê no cartão")
            return
        texto = " ".join(frase)
        nomes = [n for n in (motivo["antes"], motivo["chave"], motivo["vale"], motivo["pede"]) if n]
        self.checa(nomes and all(f"«{n}»" in texto for n in nomes),
                   f"«{rotulo}» apagado diz por quê com os nomes da tela {nomes}: {texto[:160]!r}")
        self.esperar_status(409, "/api/rodar")
        sel = cartao.locator("select")
        arg = sel.input_value() if sel.count() else ""
        resposta = self.js("(c) => api('/api/rodar', {method: 'POST', body: JSON.stringify(c)})",
                           {"acao": acao["id"], "argumento": arg, "confirmado": True})
        self.checa(resposta and resposta.get("erro") and self.js("() => TRABALHO === null"),
                   f"o servidor recusa rodar «{rotulo}» apagado ({(resposta or {}).get('erro')!r})")
        self.acoes_vistas.setdefault(acao["id"], set()).add("apagada")

    def h_clique_de_acao(self, nome):
        """Ação rápida, «Usar este», «Conferir»: um botão que roda uma ação."""
        self.gesto_de_acao(lambda: self.clicar_nome(nome), nome.split(" · ")[-1])

    def h_resolver(self, nome):
        """Uma pendência por vez, pelo balão (que é o rótulo da ação dela)."""
        baloes = [self.achar(nome, i).get_attribute("data-balao")
                  for i in range(self.quantos(nome))]
        for balao in baloes:
            def clicar(b=balao):
                self.censo()
                self.pag.locator(f'[data-inventario="{css_attr(nome)}"]'
                                 f'[data-balao="{css_attr(b)}"]').first.click()
            self.gesto_de_acao(clicar, f"Resolver: {balao}")
            self.voltar()

    def h_seletor_acao(self, nome):
        el = self.achar(nome)
        atual = el.input_value()
        linha = el.locator("xpath=ancestor::article[1]").locator("code.cmd")
        c0 = linha.inner_text()
        opcoes = el.locator("option").evaluate_all("(os) => os.map((o) => o.value)")
        if nome.startswith("ação «Trocar de tema» "):
            self.conferir_temas_prontos(opcoes, atual)
        outros = [o for o in opcoes if o != atual]
        if not outros:
            # Uma opção só: não há o que trocar, e o que se confere é o
            # comando dizer essa opção. (Era o caso de «Trocar de tema», com
            # a `original` sozinha, até a P48 — ver `conferir_temas_prontos`.)
            self.checa(atual in c0, f"o comando na tela leva a única opção ({c0!r})")
            return
        el.select_option(outros[0])
        self.checa(linha.inner_text() != c0,
                   f"trocar o seletor reescreve o comando na tela ({c0!r} → "
                   f"{linha.inner_text()!r})")
        el.select_option(atual)

    # OS TEMAS PRONTOS SÃO OS DOS PACKS, E A `original` NÃO É UM DELES
    # — 24/09/2026, sprint P48 (achado 30)
    #   A validação no painel de verdade achou «Trocar de tema» com UMA opção,
    #   `original`, pré-selecionada: o servidor listava `assets/temas/capturados/`
    #   e as capturas tinham descido para dentro dos packs (P27). E um clique em
    #   «Executar» aplicaria o tema de fábrica de OUTRA máquina. Este percurso
    #   não via nada disso: o seletor de uma opção só caía no ramo "não há o que
    #   trocar" do `h_seletor_acao`, e passava.
    #   A régua é a do `meow tema` — o `pack.py capturas` da raiz de brinquedo,
    #   com o pack padrão, que é o que o `PACK=""` do conf de brinquedo pede —
    #   menos a `original`. E a régua não pode estar vazia nem ser só a
    #   `original`: aí as duas listas concordariam no defeito.
    def conferir_temas_prontos(self, opcoes, atual):
        ambiente = {k: v for k, v in os.environ.items() if not k.startswith("MEOW_")}
        ambiente["HOME"] = CASA
        r = subprocess.run([sys.executable, os.path.join(RAIZ_B, "scripts", "pack.py"),
                            "capturas"], env=ambiente, capture_output=True, text=True)
        regua = [n for n in r.stdout.split() if n != "original"]
        par = f"{valor_de('FLAVOR')}-{valor_de('ACCENT')}"
        if not self.checa(r.returncode == 0 and par in regua,
                          f"a régua dos temas prontos (pack.py capturas) traz {par}: "
                          f"rc={r.returncode} {r.stdout.split()}"):
            return
        self.checa(opcoes == regua,
                   f"«Trocar de tema» oferece os temas prontos dos packs ({regua}), "
                   f"e oferece {opcoes}")
        self.checa("original" not in opcoes and atual != "original",
                   f"«Trocar de tema» não oferece a `original`, o tema de fábrica de "
                   f"outra máquina (oferece {opcoes}, escolhida {atual!r})")

    def h_ver_comando(self, nome):
        el = self.achar(nome)
        el.focus()
        el.click()
        lista = el.locator("xpath=ancestor::*[.//div[contains(@class,'comandos')]][1]") \
                  .locator(".comandos").first
        self.checa(el.get_attribute("aria-expanded") == "true" and lista.is_visible(),
                   "«ver comando» abre a lista de comandos")
        copiar = lista.locator("button")
        if self.checa(copiar.count(), "a lista traz um «Copiar»"):
            codigo = lista.locator("code").first.inner_text()
            copiar.first.focus()
            copiar.first.click()
            self.assentar(quieto=100, teto=2000)
            copiado = self.js("() => navigator.clipboard.readText()")
            self.checa(copiado and codigo.strip() and
                       (copiado.strip() == codigo.strip() or copiado.strip().endswith(
                           codigo.strip().split(" ", 1)[-1])),
                       f"«Copiar» põe o comando na área de transferência ({copiado[:50]!r})")
            self.checa(self.pag.locator("#torradas .torrada", has_text="copiado").count(),
                       "e diz que copiou")
            self.acionados.add(nome.rsplit(" · ", 1)[0] + " › linha de comando · Copiar")
        el = self.achar(nome)
        if el is not None and el.get_attribute("aria-expanded") == "true":
            el.click()
            self.checa(el.get_attribute("aria-expanded") == "false", "e o segundo clique fecha")

    # ======================================================================
    # O RESTO DA ABA
    # ======================================================================
    def h_fundo(self, nome):
        """As pílulas de fundo das prévias: a marca vai para quem foi clicado."""
        original = self.pag.locator(".fundos button[aria-pressed=true]").inner_text().strip()
        el = self.achar(nome)
        el.click()
        self.assentar(quieto=100, teto=3000)
        el = self.achar(nome)
        self.checa(el is not None and el.get_attribute("aria-pressed") == "true",
                   "a pílula de fundo clicada fica marcada")
        self.pag.locator(".fundos button", has_text=original).first.click()
        self.assentar(quieto=100, teto=3000)

    def h_aba_galeria(self, nome):
        el = self.achar(nome)
        el.click()
        self.assentar(quieto=200)
        el = self.achar(nome)
        self.checa(el is not None and el.get_attribute("aria-pressed") == "true"
                   and self.pag.locator("#conteudo .galeria figure, #conteudo .sem-previa")
                   .count(), "a aba da galeria fica marcada e mostra o que tem")
        self.pag.locator("#conteudo .abas button").first.click()
        self.assentar(quieto=200)

    def contagem_galeria(self):
        """{"No carrossel": 6, "Noite": 0, ...}, lido dos botões das abas."""
        conta = {}
        for t in self.pag.locator("#conteudo .abas button").all_inner_texts():
            m = re.match(r"\s*(.*?)\s*(\d*)\s*$", t)
            conta[m.group(1)] = int(m.group(2) or 0)
        return conta

    def clicar_na_ficha(self, nome, i=0):
        """Os botões da ficha de imagem só recebem o ponteiro com a ficha sob o
        rato ou com o foco dentro dela (`:focus-within`, no estilo.css). O foco
        é o caminho que não depende de onde o rato está: o botão o recebe, a
        legenda acorda, e o clique chega a ele."""
        el = self.achar(nome, i)
        el.focus()
        el.click()

    def h_galeria(self, nome):
        """O primeiro papel de parede: Usar, Dia, Noite, Tirar — e o Medir e o
        Devolver que eles revelam."""
        papel = nome.split(" · ")[-1]
        c0 = self.contagem_galeria()
        imagem = self.achar(nome).locator("xpath=ancestor::figure[1]").locator(".nome") \
                     .inner_text().strip()
        antes = retrato()
        # A GALERIA NÃO SOME NA RELEITURA — 25/09/2026, sprint P68 (item 3)
        #   O gate inteiro reprovou 9 vezes nesta aba com «a lista que o traz
        #   não voltou em 8 s», e a aba sozinha passou 2 de 2: o fim de um
        #   trabalho esquecia as listas da galeria (P46) e toda pintura seguinte
        #   mostrava «lendo o acervo…» até a releitura chegar — com a máquina
        #   carregada, mais que os 8 s do `esperar_nome` do gesto seguinte. A
        #   demora só aparece sob carga; a galeria vazia no meio aparece em toda
        #   corrida, e é ela que o vigia cobra: do clique até a releitura
        #   assentar, nenhuma pintura do #conteudo sem ficha ou com o «lendo».
        #   O molde é o passo 24 do tests/app-navegador.py (a grade da P57).
        self.js("""() => {
          window.__galeriaSumiu = [];
          window.__vigiaGaleria = new MutationObserver(() => {
            const fichas = document.querySelectorAll('#conteudo .galeria figure').length;
            const lendo = [...document.querySelectorAll('#conteudo .sem-previa')]
              .some((e) => e.textContent.includes('lendo o acervo'));
            if (!fichas || lendo) window.__galeriaSumiu.push({ fichas, lendo });
          });
          window.__vigiaGaleria.observe(document.getElementById('conteudo'),
                                        { childList: true, subtree: true });
        }""")
        self.gesto_de_acao(lambda: self.clicar_na_ficha(nome), f"papel de parede: {papel}")
        self.assentar(quieto=300)
        sumiu = self.js("() => { window.__vigiaGaleria.disconnect(); return window.__galeriaSumiu; }")
        self.checa(not sumiu, f"a galeria não some na releitura depois de «{papel}»: "
                              f"{len(sumiu)} pintura(s) sem ficha ou com «lendo o acervo…»")
        c1 = self.contagem_galeria()
        if papel in ("Dia", "Noite"):
            # A contagem pode não mudar (a imagem escura já contava na Noite
            # pela medição): quem prova é o lado gravado e o «Medir» aceso.
            self.checa(any(c.endswith("lado.tsv") for c in diferenca(antes, retrato())),
                       f"«{papel}» grava o lado de {imagem}")
            self.pag.locator("#conteudo .abas button", has_text=papel).first.click()
            self.assentar(quieto=300)
            medir = "papel de parede · Medir"
            if self.checa(self.esperar_nome(medir) is not None,
                          f"na aba {papel}, {imagem} ganha o «Medir»"):
                antes = retrato()
                self.gesto_de_acao(lambda: self.clicar_na_ficha(medir), "Medir")
                self.assentar(quieto=300)
                self.checa(any(c.endswith("lado.tsv") for c in diferenca(antes, retrato())),
                           "«Medir» devolve a escolha ao brilho medido")
                self.acionados.add(medir)
        elif papel == "Tirar":
            self.checa(c1.get("Recusadas", 0) == c0.get("Recusadas", 0) + 1
                       and c1.get("No carrossel", 0) == c0.get("No carrossel", 0) - 1,
                       f"«Tirar» manda {imagem} para as Recusadas ({c0} → {c1})")
            self.pag.locator("#conteudo .abas button", has_text="Recusadas").first.click()
            self.assentar(quieto=300)
            devolver = "papel de parede · Devolver"
            if self.checa(self.esperar_nome(devolver) is not None,
                          "nas Recusadas a imagem tem «Devolver»"):
                self.gesto_de_acao(lambda: self.clicar_na_ficha(devolver), "Devolver")
                self.assentar(quieto=300)
                c2 = self.contagem_galeria()
                self.checa(c2.get("No carrossel") == c0.get("No carrossel")
                           and c2.get("Recusadas") == c0.get("Recusadas"),
                           f"«Devolver» põe a imagem de volta no carrossel ({c2})")
                self.acionados.add(devolver)
        elif papel == "Usar":
            self.checa(diferenca(antes, retrato()), f"«Usar» muda a imagem da casa ({imagem})")
        self.pag.locator("#conteudo .abas button").first.click()
        self.assentar(quieto=200)

    def h_favoritar(self, nome):
        """A estrela da primeira imagem (P79): guarda nas favoritas, a aba
        «Favoritos» conta uma a mais, e a estrela acesa a tira de volta."""
        c0 = self.contagem_galeria()
        self.gesto_de_acao(lambda: self.clicar_na_ficha(nome), "Guardar nas favoritas")
        self.assentar(quieto=300)
        c1 = self.contagem_galeria()
        self.checa(c1.get("Favoritos", 0) == c0.get("Favoritos", 0) + 1
                   and c1.get("No carrossel") == c0.get("No carrossel"),
                   f"a estrela guarda a imagem nas favoritas e ela segue girando ({c0} → {c1})")
        tirar = "papel de parede · Tirar das favoritas"
        if self.checa(self.esperar_nome(tirar) is not None, "a favorita tem a estrela acesa"):
            self.gesto_de_acao(lambda: self.clicar_na_ficha(tirar), "Tirar das favoritas")
            self.assentar(quieto=300)
            c2 = self.contagem_galeria()
            self.checa(c2.get("Favoritos", 0) == c0.get("Favoritos", 0),
                       f"a estrela acesa tira a imagem das favoritas ({c2})")
            self.acionados.add(tirar)
        self.pag.locator("#conteudo .abas button").first.click()
        self.assentar(quieto=200)

    def h_filtro(self, nome):
        """O filtro de uma grade: pelo nome do primeiro item, e depois limpo.

        A grade é a DO FILTRO — o «Filtrar jogo» filtra os jogos da Steam, e o
        «Filtrar aplicativo», a grade de aplicativos; quem diz qual é o
        `data-foco` dele."""
        el = self.achar(nome)
        foco = el.get_attribute("data-foco")
        sel = {"jogos": "#conteudo .grade-jogos .jogo"}.get(foco, "#conteudo .grade-apps .app")
        grade = self.pag.locator(sel)
        n0 = grade.count()
        if not self.checa(n0, f"o filtro tem o que filtrar ({sel})"):
            return
        palavra = re.split(r"\s+", grade.first.locator(".app-nome").inner_text().strip())[0][:5]
        try:
            el.fill(palavra)
            self.assentar(quieto=150)
            n1 = grade.count()
            self.checa(1 <= n1 <= n0, f"filtrar por {palavra!r} deixa {n1} de {n0}")
            self.achar(nome).fill("zzzz-nada-casa")
            self.assentar(quieto=150)
            self.checa(grade.count() == 0, "um filtro sem resultado esvazia a grade")
        finally:
            el = self.achar(nome)
            if el is not None:
                el.fill("")
                self.assentar(quieto=150)
        self.checa(grade.count() == n0, "e limpar o filtro devolve a grade inteira")

    def h_pular(self, nome):
        el = self.achar(nome)
        alvo = (el.get_attribute("href") or "")[1:]
        if not self.checa(alvo and self.js(f"() => !!document.getElementById({json.dumps(alvo)})"),
                          f"o salto aponta para um lugar que existe (#{alvo})"):
            return
        el.focus()
        self.pag.keyboard.press("Enter")
        self.assentar(quieto=100, teto=2000)
        self.checa(self.js(f"""() => {{
            const a = document.getElementById({json.dumps(alvo)});
            const r = a.getBoundingClientRect();
            return document.activeElement === a || (r.top >= 0 && r.top < innerHeight);
        }}"""), f"o Enter no salto leva o foco ou a tela até #{alvo}")

    def h_details(self, nome):
        """Abre, aciona o que ele revela (o link do pack, os dois «baixar» do
        Exportar), e fecha.

        NUM MOLDE, O EXEMPLAR QUE REVELA: o «Mais sobre este pack» do pack que
        veio de um CSV não tem site, e o pack importado no gesto anterior
        passa a ser o primeiro da fila — medido na quarta corrida. Os
        exemplares são abertos em ordem até um revelar alguma coisa."""
        if nome.startswith("cartão de pack"):
            # TODOS os cartões, e antes do laço: ele para no primeiro exemplar
            # que revela alguma coisa, e o da história plantada pode não ser
            # esse. O `open` é posto e tirado direto — o clique é o do laço.
            self.historia_conferida = False
            for i in range(self.quantos(nome)):
                d = self.achar(nome, i).locator("xpath=..")
                d.evaluate("(d) => { d.open = true; }")
                self.conferir_historia(d)
                d.evaluate("(d) => { d.open = false; }")
            self.checa(self.historia_conferida,
                       "a história com Markdown hostil, plantada no pack padrão, foi "
                       "conferida no cartão dele")
            # O CARTÃO INTEIRO ABRE (P77, achado 8): um clique na capa abre o
            # detalhe e o cartão toma a linha da grade; o segundo fecha.
            d = self.achar(nome, 0).locator("xpath=..")
            capa = d.locator("xpath=..").locator(".pack-capa")
            capa.click()
            # O `toggle` do `<details>` chega numa tarefa depois do clique.
            self.pag.wait_for_timeout(200)
            aberto = d.evaluate("(d) => d.open && d.parentElement.classList.contains('aberto')")
            capa.click()
            self.pag.wait_for_timeout(200)
            self.checa(aberto and not d.evaluate("(d) => d.open"),
                       "um clique na capa do pack abre o detalhe na linha inteira, e outro fecha")
        for i in range(min(3, self.quantos(nome))):
            # [P73: as pastas da ficha de ícone podem nascer ABERTAS (a do pack
            # no ar, a dos sugeridos). Aberta, ela é fechada antes, para o
            # clique conferido ser o que abre; e volta aberta no fim, para os
            # desenhos de dentro continuarem ao alcance do percurso.]
            estava = False
            if nome.startswith("ícone do aplicativo · abre"):
                el = self.achar(nome, i)
                estava = bool(el.locator("xpath=..").evaluate("(d) => d.open"))
                if estava:
                    el.click()
            # [P77: a página tem de estar PARADA antes do censo. Em «Lançadores
            # e jogos» o «⋯» das ações é aberto logo depois do «Conferir» dos
            # jogos, cujo fim relê a lista e repinta a aba — a repintura apaga
            # as marcas do censo, e o primeiro controle revelado (o `?` do
            # «Baixar o tema do Spotify») ficava sem quem o achasse: o clique
            # esperava 8 s e quebrava, nas duas corridas.]
            self.assentar(quieto=300)
            antes = set(self.censo())
            el = self.achar(nome, i)
            el.click()
            self.checa(el.locator("xpath=..").evaluate("(d) => d.open"),
                       f"«{nome.split('«')[-1][:-1]}» abre")
            novos = sorted(set(self.censo()) - antes)
            # A oficina e a edição do SVG têm percurso próprio, com ordem (ver
            # `h_aplicativo`); os `<details>` simples acionam aqui o que revelam.
            if not nome.startswith("ícone do aplicativo"):
                for n in novos:
                    if self.acionador(n) and n not in self.acionados:
                        alvo = self.achar(nome, i)
                        if alvo is not None and not alvo.locator("xpath=..").evaluate(
                                "(d) => d.open"):
                            alvo.click()
                        self.acionar(n, limpar=False, esperar=False)
            el = self.achar(nome, i)
            if el is not None and el.locator("xpath=..").evaluate("(d) => d.open"):
                el.click()
            el = self.achar(nome, i)
            self.checa(el is not None and not el.locator("xpath=..").evaluate("(d) => d.open"),
                       "e fecha no segundo clique")
            if estava and el is not None:
                el.click()
            # [P77: o «⋯» dos ajustes técnicos é um por bloco, e uma página
            # pode ter dois com o mesmo nome (Logo do sistema: o do dock e o do
            # terminal). Cada um revela os SEUS controles, então todos abrem.]
            if novos and "⋯" not in nome:
                break

    # A HISTÓRIA DO PACK É MONTADA, E NADA DELA VIRA HTML — P53, achado 6. O
    # `montar_casa` pôs no LEIA-ME do pack padrão uma tag, um `javascript:` e
    # um negrito. Em QUALQUER exemplar: nenhum elemento fora do subconjunto,
    # nenhum `href` que não seja https, e a página não rodou nada. No
    # exemplar que tem o trecho plantado: a tag está lá, como texto, e o
    # negrito virou `<strong>`.
    HISTORIA_JS = r"""
    (d) => {
      const h = d.querySelector('.pack-historia');
      if (!h) return null;
      const PERMITIDOS = new Set(['H4', 'H5', 'P', 'UL', 'OL', 'LI', 'STRONG', 'CODE', 'A']);
      return {
        estranhos: [...h.querySelectorAll('*')].map((e) => e.tagName)
                     .filter((t) => !PERMITIDOS.has(t)),
        hrefs: [...h.querySelectorAll('a')].map((a) => a.getAttribute('href') || '')
                 .filter((u) => !u.startsWith('https://')),
        rodou: window.__meow_xss !== undefined,
        plantado: h.textContent.includes('Teste da casa de brinquedo'),
        tag_como_texto: h.textContent.includes(HOSTIL),
        negrito: [...h.querySelectorAll('strong')].some((b) => b.textContent === 'negrito de brinquedo'),
      };
    }
    """

    def conferir_historia(self, details):
        r = details.evaluate(self.HISTORIA_JS.replace("HOSTIL", json.dumps(HOSTIL)))
        if r is None:
            return
        self.checa(not r["estranhos"] and not r["hrefs"] and not r["rodou"],
                   f"a história do pack não vira HTML (elementos {r['estranhos'][:3]}, "
                   f"hrefs {r['hrefs'][:2]}, rodou={r['rodou']})")
        if r["plantado"]:
            self.historia_conferida = True
            self.checa(r["tag_como_texto"] and r["negrito"],
                       "a tag da história sai como texto, e o **negrito** vira negrito")

    def h_link_externo(self, nome):
        """Não sai para a internet: o pedido de fora é recusado pela rota do
        contexto, e o que se confere é que o clique abre uma aba NOVA no
        endereço certo, sem levar esta página junto."""
        # A REPINTURA ENTRE O CENSO E O CLIQUE — 10/10/2026, P79 (achado da
        #   conferência da P77: o «Créditos» estourava o tempo uma vez no gate
        #   completo e passava na corrida seguinte). A marca `data-inventario`
        #   mora no elemento, e uma repintura do menu no meio do gesto (a página
        #   relê o que chega pela rede) a apaga: o `click` ficava esperando um
        #   elemento que não existe mais até o teto. Reproduzido repintando o
        #   menu no primeiro `pointerover` do link: «Locator.click: Timeout
        #   30000ms exceeded». É o mesmo caso do `clicar_nome`, e a cura é a
        #   dele: o censo de novo e outra tentativa, com um teto curto por clique.
        nova = None
        n0 = len(PEDIDOS_DE_FORA)
        for _tentativa in range(4):
            el = self.esperar_nome(nome, teto=4.0)
            if el is None:
                break
            try:
                href = el.get_attribute("href", timeout=2500) or ""
                rel = el.get_attribute("rel", timeout=2500) or ""
                with self.pag.context.expect_page(timeout=5000) as aberta:
                    el.click(timeout=2500)
                nova = aberta
                break
            except Exception:
                self.pag.wait_for_timeout(200)
        if nova is None:
            self.falha(f"não consegui clicar em «{nome}»")
            return
        self.checa(href.startswith("https://"), f"o link externo vai para https ({href[:50]})")
        self.checa("noopener" in rel, "e abre sem dar a esta página à outra (rel=noopener)")
        nova.value.wait_for_timeout(300)
        pedidos = PEDIDOS_DE_FORA[n0:]
        self.checa(any(u.rstrip("/") == href.rstrip("/") for u in pedidos),
                   f"o clique abre {href[:50]} numa aba nova (pediu {pedidos[:2]})")
        nova.value.close()

    def h_porta(self, nome):
        rotulo = nome.split(" · ")[-1]
        antes = self.aba_atual()
        self.achar(nome).click()
        self.assentar(quieto=200)
        agora = self.aba_atual()
        esperado = rotulo[len("Abrir "):] if rotulo.startswith("Abrir ") else None
        self.checa(agora != antes and (esperado is None or agora == esperado),
                   f"«{rotulo}» leva a {esperado or 'outra aba'} (foi a {agora})")
        self.abrir_aba(self.aba)

    # ======================================================================
    # O QUE ENTRA POR ARQUIVO
    # ======================================================================
    def arquivo_de_teste(self, tipo):
        """Um arquivo VÁLIDO de cada acervo: a porta é conferida aceitando, e
        não só recusando. Tudo nasce aqui, sem depender de nada da máquina —
        menos a fonte, que ninguém escreve à mão: ela vem do `fc-match`."""
        import zipfile
        pasta = os.path.join(BRINQUEDO, "envios")
        os.makedirs(pasta, exist_ok=True)
        svg = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
               '<circle cx="24" cy="24" r="18" fill="none" stroke="#cba6f7" '
               'stroke-width="3"/></svg>')
        if tipo in ("Adicionar logo", "Adicionar ícone"):
            nome = os.path.join(pasta, "brinquedo-desenho.svg")
            with open(nome, "w", encoding="utf-8") as fh:
                fh.write(svg)
            return nome
        if tipo == "Adicionar imagem":
            nome = os.path.join(pasta, "brinquedo-nova.png")
            png_liso(nome, (0xF5, 0xC2, 0xE7))
            return nome
        if tipo == "Adicionar tema":
            nome = os.path.join(pasta, "brinquedo-ponteiro.zip")
            cur = os.path.join(pasta, "left_ptr")
            xcursor_liso(cur)
            with zipfile.ZipFile(nome, "w") as z:
                z.write(cur, "Brinquedo-Ponteiro/cursors/left_ptr")
                z.writestr("Brinquedo-Ponteiro/index.theme",
                           "[Icon Theme]\nName=Brinquedo-Ponteiro\n")
            return nome
        if tipo == "Adicionar tema de ícones":
            nome = os.path.join(pasta, "brinquedo-icones.zip")
            with zipfile.ZipFile(nome, "w") as z:
                z.writestr("Brinquedo-Icones/index.theme",
                           "[Icon Theme]\nName=Brinquedo-Icones\nDirectories=scalable/apps\n\n"
                           "[scalable/apps]\nSize=48\nType=Scalable\n")
                z.writestr("Brinquedo-Icones/scalable/apps/brinquedo.svg", svg)
            return nome
        if tipo == "Adicionar fonte":
            achada = subprocess.run(["fc-match", "-f", "%{file}", "sans:fontformat=TrueType"],
                                    capture_output=True, text=True).stdout.strip()
            if not achada.endswith(".ttf"):
                return None
            nome = os.path.join(pasta, "brinquedo-fonte.ttf")
            shutil.copyfile(achada, nome)
            return nome
        return None

    def h_acervo(self, nome):
        rotulo = nome.split(" · ")[-1]
        arquivo = self.arquivo_de_teste(rotulo)
        if not self.checa(arquivo, f"há um arquivo de teste para «{rotulo}»"):
            return
        antes, n0 = retrato(), len(self.posts)
        # A TORRADA É CONTADA QUANDO NASCE, E NÃO SÓ NO FIM — 24/09/2026, P52
        #   Ela vive 2,6 s (`torrada()`, no app.js), e depois de um «Adicionar» a
        #   página repinta por uns 2,5 s. O `assentar` espera 300 ms de silêncio,
        #   e a própria torrada saindo é uma mutação que empurra a espera para
        #   depois dela. Medido na árvore de `dev` (92e7c09), só a aba «Logo do
        #   sistema»: a torrada `ok` nasceu em 101 ms, a conta foi feita em 3,0 s,
        #   e a reprovação saiu sem defeito nenhum na página. Na corrida inteira
        #   as quatro «Adicionar» reprovaram assim, e em outra da mesma árvore só
        #   uma: a conta dependia de quanto a máquina estava ocupada. A conta do
        #   fim continua valendo: uma frase repetida não nasce de novo (a que
        #   existe só ganha sobrevida), e aí quem a vê é a conta do fim.
        self.js(TORRADAS_VISTAS_JS)
        with self.pag.expect_file_chooser(timeout=5000) as escolha:
            self.achar(nome).click()
        escolha.value.set_files(arquivo)
        fim = time.time() + 120
        while len(self.posts) == n0 and time.time() < fim:
            self.pag.wait_for_timeout(100)
        self.assentar(quieto=300, teto=120000)
        self.esperar_trabalho()
        vistas = self.js("() => window.__torradasVistas || []")
        ok = (self.pag.locator("#torradas .torrada.ok, #torradas .torrada.igual").count()
              or any(v["classe"] in ("ok", "igual") for v in vistas))
        erro = self.pag.locator("#torradas .torrada.erro")
        disse = ([erro.first.inner_text()] if erro.count() else []) + \
            [v["texto"] for v in vistas if v["classe"] == "erro"]
        self.checa(ok and not disse,
                   f"«{rotulo}» aceita {os.path.basename(arquivo)} e diz que entrou"
                   + (f" — disse {disse[0][:120]!r}" if disse else ""))
        self.checa(diferenca(antes, retrato()), f"«{rotulo}» escreveu na casa de brinquedo")

    def h_exportar_pack(self, nome):
        with self.pag.expect_download(timeout=30000) as baixa:
            self.achar(nome).click()
        caminho = baixa.value.path()
        # O `.meowpack` é um tar comprimido com zstd (`scripts/pack.py`): a
        # assinatura dos quatro primeiros bytes é o que se confere.
        with open(caminho, "rb") as fh:
            cabeca = fh.read(4)
        self.checa(baixa.value.suggested_filename.endswith(".meowpack")
                   and os.path.getsize(caminho) > 1000
                   and cabeca == bytes([0x28, 0xB5, 0x2F, 0xFD]),
                   f"«Exportar o meu» baixa um .meowpack de verdade "
                   f"({baixa.value.suggested_filename}, {os.path.getsize(caminho)} bytes)")

    def h_importar_pack(self, nome):
        """Um CSV das 26 cores, pela porta da P16: vira um pack novo."""
        import csv as _csv
        pasta = os.path.join(BRINQUEDO, "envios")
        os.makedirs(pasta, exist_ok=True)
        arquivo = os.path.join(pasta, "brinquedo.csv")
        # A paleta do flavor escuro que está no ar, com outro nome: cores
        # inventadas reprovam no contraste que o pack exige (medido: "text sobre
        # base tem contraste 2.00:1"), e a recusa não é o que se quer provar.
        paleta = self.js("() => { const f = ESQUEMA.paleta.flavors || {};"
                         " const n = Object.keys(f).find((k) => k !== 'latte') ||"
                         " Object.keys(f)[0]; return f[n] || {}; }")
        with open(arquivo, "w", encoding="utf-8", newline="") as fh:
            w = _csv.writer(fh)
            w.writerow(["slot", "flavor", "hex"])
            for slot in self.js("() => ESQUEMA.paleta.ordem || []"):
                w.writerow([slot, "noite", paleta.get(slot, "#000000")])
        packs0 = self.pag.locator("#conteudo article.pack").count()
        with self.pag.expect_file_chooser(timeout=5000) as escolha:
            self.achar(nome).click()
        escolha.value.set_files(arquivo)
        if not self.checa(self.caixa_aberta(20), "importar mostra a caixa com o que o pack traz"):
            return
        self.checa(self.pag.locator("#confirmar-corpo").is_visible(),
                   "e a caixa desenha o pack antes de perguntar")
        self.pag.locator("#confirmar button[value=nao]").click()
        self.assentar()
        self.checa(self.pag.locator("#conteudo article.pack").count() == packs0,
                   "Cancelar não instala o pack")
        with self.pag.expect_file_chooser(timeout=5000) as escolha:
            self.achar(nome).click()
        escolha.value.set_files(arquivo)
        if self.caixa_aberta(20):
            # A RESPOSTA DO SERVIDOR É ESPERADA PELO NOME — 10/10/2026, P80
            #   (integração). O pedido da instalação só nasce depois do `close`
            #   da caixa, num salto assíncrono, e o evento dele chega ao Python
            #   depois de o `assentar` olhar o `pedidos_vivos`: o contador
            #   ainda dizia 0, o DOM ficava parado 400 ms com o `meow pack
            #   importar` rodando, e o gate contava os cartões antes de o
            #   servidor responder. Na segunda rodada seguida da suíte, com a
            #   máquina carregada, a instalação passou da janela de 3 s do fim
            #   do `assentar` e o gate saiu vermelho com o pack instalado (um
            #   `sleep 4` na rota reproduz sem depender da carga). O teto é o do servidor, que
            #   dá 120 s ao `importar`.
            with self.pag.expect_response(
                    lambda r: "/api/pack-importar" in r.url and r.request.method == "POST",
                    timeout=130000):
                self.pag.locator("#confirmar-ok").click()
            self.acionados.add("caixa · #confirmar-ok")
            self.assentar(quieto=400, teto=30000)
            if self.checa(self.pag.locator("#conteudo article.pack").count() == packs0 + 1,
                          "confirmar instala o pack, e ele ganha cartão na Início"):
                # O AVESSO, NO MESMO GESTO — P53, achado 8. O pack que acabou
                # de entrar é o único da casa de brinquedo que mora na casa da
                # pessoa, e é o único cartão que ganha o «Remover».
                self.acionar("cartão de pack · Remover", limpar=False)

    def h_remover_pack(self, nome):
        """O «Remover» do pack importado: a caixa, o ensaio que não apaga e o
        de verdade, pelo protocolo das três respostas — e no fim o cartão sai
        da Início e a pasta sai da casa, inteira, sem o oculto da troca."""
        packs0 = self.pag.locator("#conteudo article.pack").count()
        da_pessoa = os.path.join(CASA, ".local", "share", "meowsystem", "packs")
        antes = sorted(os.listdir(da_pessoa)) if os.path.isdir(da_pessoa) else []
        self.checa(self.quantos(nome) == 1,
                   f"só o pack importado ganha o «Remover» ({self.quantos(nome)} na tela)")
        self.gesto_de_acao(lambda: self.clicar_nome(nome), "Remover")
        self.assentar(quieto=400, teto=30000)
        depois = sorted(os.listdir(da_pessoa)) if os.path.isdir(da_pessoa) else []
        self.checa(self.pag.locator("#conteudo article.pack").count() == packs0 - 1,
                   "«Remover» tira o cartão do pack da Início")
        self.checa(len(depois) == len(antes) - 1,
                   f"e tira a pasta dele da casa, sem deixar resto ({antes} → {depois})")

    # ======================================================================
    # PENDÊNCIAS, JOGOS, DESENHOS
    # ======================================================================
    def h_recusar(self, nome):
        n_pend = self.pag.locator("#conteudo .pendencia").count()
        antes, n0 = retrato(), len(self.posts)
        self.achar(nome).click()
        if not self.checa(self.caixa_aberta(), "«Não, obrigado» pergunta antes"):
            return
        self.pag.locator("#confirmar button[value=nao]").click()
        self.assentar()
        self.checa(len(self.posts) == n0 and not diferenca(antes, retrato()),
                   "Cancelar não grava a recusa")
        self.achar(nome).click()
        if self.caixa_aberta():
            self.pag.locator("#confirmar-ok").click()
            self.assentar(quieto=300)
            self.checa(self.pag.locator("#conteudo .pendencia").count() == n_pend - 1,
                       "confirmar a recusa tira a pendência da tela")
            self.checa(diferenca(antes, retrato()), "e grava a recusa no estado")

    def decisao_de_jogo(self, clicar, frase):
        """A rota `jogo-fora` grava a decisão e, em seguida, a página roda o
        `jogos_aplicar` (o `definirJogo` do app.js)."""
        antes, n0 = retrato(), len(self.posts)
        clicar()
        post = self.esperar_post(n0, teto=10)
        self.checa(post and post[0] == "jogo-fora", f"{frase} grava a decisão")
        self.assentar(quieto=300)
        self.esperar_trabalho()
        self.checa(any(c.endswith("jogos-fora.map") for c in diferenca(antes, retrato())),
                   f"{frase} muda o mapa de jogos (de brinquedo)")

    def decisao_com_caixa(self, clicar, frase, reabrir=lambda: None):
        """A decisão de jogo que arruma o lançador pergunta antes (P54, a decisão
        dos jogos de 24/09): a caixa diz o que sai e o que entra, e dá as três
        respostas. A conferência que enche a caixa é o `jogo-fora` com
        `previa`, que não grava; o «Ver o que faria» é o mesmo pedido com
        `seco`, e roda a passagem em ensaio na gaveta; só o «sim» grava."""
        acao = self.acoes().get("jogos_aplicar")
        antes, n0 = retrato(), len(self.posts)
        clicar()
        if not self.checa(self.caixa_aberta(), f"{frase} pergunta antes de arrumar o lançador"):
            return
        # A caixa fala a língua do botão clicado (revisão da P54): o «Voltar ao
        # normal» numa caixa «Tirar da lista» leria como tirar o jogo do lançador.
        ok = (self.pag.locator("#confirmar-ok").text_content() or "").strip()
        self.checa(ok == frase.strip("«»"), f"a caixa de {frase} confirma com o mesmo nome ({ok!r})")
        efeito = self.pag.locator("#confirmar .efeito-jogos [data-efeito]")
        fim = time.time() + 60
        while not efeito.count() and time.time() < fim:
            self.pag.wait_for_timeout(100)
        self.checa(efeito.count(), f"a caixa de {frase} diz o que sai e o que entra no lançador")
        self.checa(all(d != "jogo-fora" or c.get("previa") for d, c in self.posts[n0:]),
                   f"a conferência da caixa de {frase} não grava nada")
        self.pag.locator("#confirmar button[value=nao]").click()
        self.acionados.add("caixa · Cancelar")
        self.assentar(quieto=150)
        mudou = diferenca(antes, retrato())
        self.checa(not mudou, f"Cancelar em {frase} não muda a casa — mudou {mudou[:4]}")

        reabrir()
        n1, reg1, antes1 = len(self.posts), len(registro()), retrato()
        clicar()
        if self.checa(self.caixa_aberta(), f"{frase} pergunta de novo, e oferece o «Ver o que faria»"):
            self.pag.locator("#confirmar-ensaio").click()
            self.acionados.add("caixa · #confirmar-ensaio")
            fim = time.time() + 10
            while (not any(c.get("seco") for _, c in self.posts[n1:])
                   and time.time() < fim):
                self.pag.wait_for_timeout(50)
            self.checa(any(d == "jogo-fora" and c.get("seco") is True for d, c in self.posts[n1:]),
                       f"«Ver o que faria» em {frase} pede o ensaio ao servidor")
            if acao:
                self.conferir_trabalho(acao, True, antes1, reg1)

        reabrir()
        clicar()
        if not self.checa(self.caixa_aberta(), f"{frase} pergunta de novo no último clique"):
            return
        n3 = len(self.posts)
        antes3 = retrato()
        self.pag.locator("#confirmar-ok").click()
        self.acionados.add("caixa · #confirmar-ok")
        fim = time.time() + 10
        while (not any(d == "jogo-fora" and not c.get("previa") and not c.get("seco")
                       for d, c in self.posts[n3:]) and time.time() < fim):
            self.pag.wait_for_timeout(50)
        self.checa(any(d == "jogo-fora" and not c.get("previa") and not c.get("seco")
                       for d, c in self.posts[n3:]), f"o «sim» de {frase} grava a decisão")
        self.assentar(quieto=300)
        self.esperar_trabalho()
        self.checa(any(c.endswith("jogos-fora.map") for c in diferenca(antes3, retrato())),
                   f"{frase} muda o mapa de jogos (de brinquedo)")

    def h_orfa(self, nome):
        n0 = self.quantos(nome)
        # A DECISÃO SEM MANIFESTO DIZ O NOME DO JOGO (P54, achado 44): o da
        # casa só existe no `appinfo.vdf` de brinquedo, e não o número.
        linhas = self.pag.locator("#conteudo .linha-orfa .orfa-nome").all_inner_texts()
        self.checa(NOME_NA_STEAM in linhas,
                   f"a decisão sem manifesto mostra o nome do cache da Steam ({linhas})")
        self.decisao_com_caixa(lambda: self.achar(nome).click(), "«Tirar da lista»")
        self.assentar(quieto=300)
        self.checa(self.quantos(nome) == n0 - 1, "e o órfão sai da lista")

    def h_escolher(self, nome):
        """Um exemplar do molde: a marca vai para ele."""
        el = self.achar(nome)
        el.click()
        self.assentar(quieto=150, teto=4000)
        el = self.achar(nome)
        self.checa(el is not None and el.get_attribute("aria-pressed") == "true",
                   f"«{nome.split(' › ')[-1]}»: o escolhido fica marcado")

    def h_seletor_solto(self, nome):
        el = self.achar(nome)
        atual = el.input_value()
        outros = [o for o in el.locator("option").evaluate_all(
            "(os) => os.map((o) => o.value)") if o != atual]
        if not self.checa(outros, "o seletor tem mais de uma opção"):
            return
        antes = self.js("() => document.getElementById('conteudo').innerHTML.length")
        el.select_option(outros[0])
        self.assentar(quieto=200, teto=4000)
        self.checa(self.js("() => document.getElementById('conteudo').innerHTML.length") != antes
                   or self.achar(nome).input_value() == outros[0],
                   "trocar o seletor fica valendo")

    # ======================================================================
    # O TOPO DA PÁGINA, QUE VALE PARA TODA ABA
    # ======================================================================
    def escolher_por_busca(self, chave, valor):
        """Uma escolha pendente, pelo caminho mais curto que ela usaria."""
        self.pag.fill("#busca", chave)
        self.assentar(quieto=200)
        self.pag.locator(f'#conteudo article.cartao[data-chave="{chave}"] '
                         f'button[data-valor="{css_attr(valor)}"]').first.click()
        self.assentar(quieto=150)
        self.pag.fill("#busca", "")
        self.assentar(quieto=200)

    def h_busca(self, nome):
        el = self.achar(nome)
        el.fill("gato")
        self.assentar(quieto=250)
        self.checa(self.pag.locator("#conteudo .cartao, #conteudo .acao").count() > 1,
                   "buscar «gato» traz cartões de mais de uma aba")
        el.fill("zzzz-nada-casa")
        self.assentar(quieto=250)
        self.checa(self.pag.locator("#conteudo .vazio-msg").is_visible(),
                   "uma busca sem resultado diz que nada casa")
        el.fill("")
        self.assentar(quieto=250)
        self.checa(not self.pag.locator("#conteudo .vazio-msg").count(),
                   "e limpar a busca devolve a aba")

    def h_baixa(self, nome):
        marca = {"#baixar-conf": "FLAVOR=", "#baixar-pagina": "<html"}[nome.split(" · ")[-1]]
        menu = self.pag.locator("#menu-exportar")
        if not menu.evaluate("(d) => d.open"):
            menu.locator("summary").click()
        with self.pag.expect_download(timeout=30000) as baixa:
            self.clicar_nome(nome)
        with open(baixa.value.path(), encoding="utf-8", errors="replace") as fh:
            corpo = fh.read()
        self.checa(marca in corpo,
                   f"«{nome.split(' · ')[-1]}» baixa {baixa.value.suggested_filename} com "
                   f"{marca!r} dentro ({len(corpo)} caracteres)")
        # O QUE SE EXPORTA NÃO LEVA A CASA NEM O CLONE — P52, achados 21 e 22.
        #   Do `.conf` só o CABEÇALHO: o corpo é o arquivo da pessoa, byte a
        #   byte, e um caminho que ela mesma escreveu nele é dela para levar. A
        #   página vai inteira, e também na forma de URL (`%2F…`), que é como a
        #   casa aparecia nas prévias embutidas.
        rotulo = nome.split(" · ")[-1]
        olhado = corpo.split("\n\n", 1)[0] if rotulo == "#baixar-conf" else corpo
        vazou = [c for c in (CASA, RAIZ_B, quote(CASA, safe=""), quote(RAIZ_B, safe=""))
                 if c in olhado]
        self.checa(not vazou, f"«{rotulo}» não leva a casa nem o caminho do clone"
                   + (f" — achei {len(vazou)} forma(s)" if vazou else ""))

    def h_importar_conf(self, nome):
        arquivo = os.path.join(BRINQUEDO, "envios", "meus-ajustes.conf")
        os.makedirs(os.path.dirname(arquivo), exist_ok=True)
        novo = "debug" if valor_de("LOG_NIVEL") != "debug" else "info"
        with open(arquivo, "w", encoding="utf-8") as fh:
            fh.write(f'LOG_NIVEL="{novo}"\n')
        with self.pag.expect_file_chooser(timeout=5000) as escolha:
            self.achar(nome).click()
        escolha.value.set_files(arquivo)
        self.assentar(quieto=300)
        self.checa(self.js("() => MUDANCAS.get('LOG_NIVEL')") == novo,
                   "importar um .conf põe as escolhas dele na bandeja do Salvar")
        self.checa(valor_de("LOG_NIVEL") != novo, "e não grava nada antes do Salvar")
        self.desfazer()

    def h_ensaiar_salvar(self, nome):
        """«Ver o que faria» do banner: o instalador inteiro em ensaio."""
        atual = valor_de("LOG_NIVEL")
        self.escolher_por_busca("LOG_NIVEL", "debug" if atual != "debug" else "info")
        antes, reg0, n0 = retrato(), len(registro()), len(self.posts)
        self.achar(nome).click()
        post = self.esperar_post(n0, teto=10)
        self.checa(post and post[0] == "salvar" and post[1].get("seco") is True,
                   "«Ver o que faria» pede ao servidor o ensaio das escolhas")
        self.conferir_trabalho(self.acoes()["instalar"], True, antes, reg0)
        self.checa(valor_de("LOG_NIVEL") == atual, "o ensaio não grava a escolha no meow.conf")
        self.checa(self.pag.locator("#ensaio-rodar").count(),
                   "e oferece «Rodar de verdade» — que aqui é o instalador, e fica sem clique")
        self.censo()
        self.acoes_vistas.setdefault("instalar", set()).add("ensaio do banner")
        self.h_mais_abaixo()
        self.h_saida()
        self.h_fechar_gaveta()
        self.desfazer()

    def h_mais_abaixo(self):
        """Rolar a saída para cima acende o «mais N linhas abaixo»."""
        self.js("() => { const s = document.getElementById('saida'); s.scrollTop = 0;"
                " s.dispatchEvent(new Event('scroll')); }")
        self.assentar(quieto=100, teto=2000)
        nome = "gaveta · #mais-abaixo"
        el = self.achar(nome)
        if not self.checa(el is not None, "rolar a saída para cima acende o «mais linhas abaixo»"):
            return
        el.click()
        self.assentar(quieto=100, teto=2000)
        self.checa(self.js("() => { const s = document.getElementById('saida');"
                           " return s.scrollTop + s.clientHeight >= s.scrollHeight - 30; }"),
                   "e clicar nele desce até o fim da saída")
        self.acionados.add(nome)

    def h_saida(self):
        nome = "gaveta · #saida"
        el = self.achar(nome)
        if self.checa(el is not None, "a saída da gaveta está na tela"):
            el.focus()
            self.checa(self.js("() => document.activeElement.id === 'saida'"),
                       "a saída recebe o foco do teclado, para ler rolando")
            self.acionados.add(nome)

    def h_fechar_gaveta(self):
        nome = "gaveta · #fechar-gaveta"
        el = self.achar(nome)
        if self.checa(el is not None, "a gaveta tem o Fechar"):
            el.click()
            self.checa(self.js("() => document.getElementById('gaveta').hidden"),
                       "Fechar esconde a gaveta")
            self.acionados.add(nome)

    def h_salvar(self, nome):
        """O Salvar DE VERDADE, sem rodar o instalador.

        Clicar em «Salvar e aplicar» grava e começa o instalador, que é
        exceção (ver `EXCECOES`). Mas o servidor grava ANTES de começar, e
        recusa o instalador quando outro trabalho corre — é o caminho de quem
        salva com o painel aberto em duas janelas. O teste o percorre assim:
        as escolhas ficam prontas, uma segunda aba começa o ensaio do
        instalador, e esta salva — o «Aplicar» de um cartão (uma chave só) e o
        «Salvar e aplicar» (o resto). O disco muda de verdade, o instalador não
        roda, e a página diz as duas coisas. No fim, o «Parar» da outra aba
        encerra o ensaio."""
        chave = "WALLPAPER_ORDEM"
        self.escolher_por_busca("LOG_NIVEL", "debug" if valor_de("LOG_NIVEL") != "debug"
                                else "info")
        self.pag.fill("#busca", chave)
        self.assentar(quieto=200)
        cartao = f'#conteudo article.cartao[data-chave="{chave}"]'
        self.pag.locator(f"{cartao} button[data-valor]:not([aria-pressed=true])"
                         ':not([data-valor=""])').first.click()
        self.assentar(quieto=150)
        esperado = dict(self.js("() => [...MUDANCAS.entries()]"))
        aplicar = f"ajuste {chave} · Aplicar"
        if not self.checa(self.achar(aplicar) is not None,
                          "a escolha pendente acende o «Aplicar» do cartão"):
            return

        # O TRABALHO DA OUTRA ABA É O MAIS LONGO QUE SÓ LÊ: o «O que está no ar
        # agora» (o `meow status`), uns dez segundos na casa de brinquedo. O
        # ensaio do instalador, que foi a primeira escolha, acabava em 7 s e o
        # «Parar» chegava tarde — medido na segunda corrida.
        outra = self.pag.context.new_page()
        outra.goto(self.url, wait_until="domcontentloaded")
        outra.wait_for_selector("#trilho button")
        outra.locator('#trilho button[data-grupo="Instalação"]').click()
        # [P77 grupo 4: o «O que está no ar agora» só mostra (natureza
        # `mostrar`) e mora no «⋯» das ações técnicas da Instalação.]
        # O `has` é procurado DENTRO do `<details>`: sem o `#conteudo` na frente.
        acao = outra.locator("article.acao", has_text="O que está no ar agora")
        outra.locator("#conteudo details.ajustes-tecnicos", has=acao).locator("summary").click()
        acao.get_by_role("button", name="Executar", exact=True).click()
        outra.wait_for_function("() => TRABALHO !== null && TRABALHO.timer !== null",
                                timeout=15000)

        self.esperar_status(409, "/api/salvar")
        self.achar(aplicar).click()
        self.assentar(quieto=200)
        self.acionados.add("ajuste * · Aplicar")
        self.checa(valor_de(chave) == esperado[chave],
                   f"o «Aplicar» do cartão grava a chave dele ({chave}={esperado[chave]})")
        self.checa(valor_de("LOG_NIVEL") != esperado["LOG_NIVEL"],
                   "e só ela: a outra escolha continua esperando")

        self.esperar_status(409, "/api/salvar")
        self.achar(nome).click()
        self.assentar(quieto=200)
        self.checa(valor_de("LOG_NIVEL") == esperado["LOG_NIVEL"],
                   f"«Salvar e aplicar» grava a escolha no meow.conf "
                   f"(LOG_NIVEL={esperado['LOG_NIVEL']})")
        aviso = self.achar("aviso · #aviso-aplicar-botao")
        if self.checa(aviso is not None,
                      "com o instalador ocupado, o aviso diz que ficou gravado e falta aplicar"):
            # O «Aplicar» do aviso roda o instalador, que é exceção: ele é
            # conferido na tela e pelo que diz, e fica sem clique.
            self.checa("Aplicar" in aviso.inner_text(), "e oferece o «Aplicar»")
            self.acionados.add("aviso · #aviso-aplicar-botao")
        self.acoes_vistas.setdefault("instalar", set()).add("aviso sem clique")

        parar = outra.locator("#parar")
        if self.checa(parar.is_enabled(),
                      "a outra aba tem o «Parar» aceso enquanto o trabalho corre"):
            parar.click()
            try:
                outra.wait_for_function("() => TRABALHO === null", timeout=30000)
                estado = outra.locator("#gaveta-estado").inner_text()
                self.checa(re.search(r"saiu -|interromp|parad", estado, re.I),
                           f"«Parar» encerra o trabalho, e a gaveta diz ({estado})")
            except Exception:
                self.falha("«Parar» não encerrou o trabalho em 30 s")
            self.acionados.add("gaveta · #parar")
        outra.close()
        self.pag.fill("#busca", "")
        self.assentar()

    def h_salvar_conta(self, nome):
        """O contador abre a lista, e a linha leva ao cartão."""
        self.escolher_por_busca("LOG_NIVEL", "debug" if valor_de("LOG_NIVEL") != "debug"
                                else "info")
        self.escolher_por_busca("WALLPAPER_ORDEM", self.js(
            "() => { const i = ESQUEMA.chaves.find((k) => k.chave === 'WALLPAPER_ORDEM');"
            " return i.opcoes.find((o) => o !== (i.valor ?? '')); }"))
        el = self.achar(nome)
        if not self.checa(el is not None, "com escolha pendente, o contador está na tela "
                          "como controle (alcançável pelo teclado)"):
            return
        # PELO TECLADO PRIMEIRO: o contador era um `<strong>` com clique, fora
        # da fila do Tab — ver o conserto no app.js.
        el.focus()
        self.pag.keyboard.press("Enter")
        self.assentar(quieto=150)
        self.checa(self.pag.locator("#lista-pendentes").count(),
                   "o Enter no contador abre a lista das escolhas")
        if not self.pag.locator("#lista-pendentes").count():
            self.achar(nome).click()
            self.assentar(quieto=150)
        linha = "topo › lista de escolhas › escolha pendente · ir ao cartão"
        n = self.quantos(linha)
        self.checa(n == 2, f"o contador abre a lista das {n} escolhas")
        if n:
            self.achar(linha).click()
            self.assentar(quieto=300)
            self.checa(self.aba_atual() in ("Manutenção", "Papel de parede"),
                       f"a linha leva à aba do cartão ({self.aba_atual()})")
            self.acionados.add(linha)
        # Descartar com duas escolhas pergunta antes.
        self.pag.locator("#botao-descartar").click()
        self.checa(self.caixa_aberta(), "Descartar duas escolhas pergunta antes")
        self.pag.locator("#confirmar button[value=nao]").click()
        self.checa(self.js("() => MUDANCAS.size") == 2, "Cancelar mantém as duas")
        self.descartar()
        self.checa(self.js("() => MUDANCAS.size") == 0, "e confirmar descarta as duas")
        self.acionados.add("topo · #botao-descartar")

    # ======================================================================
    # O ÍCONE DE UM APLICATIVO: o painel que o clique na grade abre
    # ======================================================================
    def h_aplicativo(self, nome):
        """Abre o primeiro aplicativo e aciona o painel inteiro dele.

        A ORDEM IMPORTA, e é a de quem usa: primeiro o que só mexe no desenho
        (escolher, colorir, a oficina, a busca), depois o que grava. «Usar este
        ícone» e «Desfazer a escolha no traço» fecham o painel quando terminam,
        e por isso vêm por último, cada um com o painel reaberto."""
        antes = set(self.censo())
        # O PAINEL É DO MESMO APLICATIVO, pelo nome: gravar um ícone reordena a
        # grade, e "o primeiro da grade" deixa de ser o mesmo — medido na
        # segunda corrida, o «Voltar» procurado no aplicativo errado.
        self.app_aberto = self.achar(nome).locator(".app-nome").inner_text().strip()
        self.abrir_painel(nome)
        novos = sorted(n for n in self.censo() if n not in antes)
        if not self.checa(novos, "clicar no aplicativo abre o painel do ícone dele"):
            return
        # A oficina fechada esconde a régua, a cor e o SVG; aberta, eles contam.
        oficina = next((n for n in novos if " › oficina · abre «" in n
                        or n.startswith("ícone do aplicativo › oficina · abre")), None)
        if oficina:
            # O acionador do `<details>` abre e fecha; depois ele é aberto de
            # novo, pelo mesmo clique, para o que mora dentro contar.
            self.acionar(oficina, limpar=False)
            self.achar(oficina).click()
            self.assentar(quieto=400, teto=15000)
            edicao = next((n for n in self.censo() if "edição do SVG · abre" in n), None)
            if edicao:
                self.acionar(edicao, limpar=False)
                self.achar(edicao).click()
                self.assentar(quieto=200)
            novos = sorted(n for n in self.censo() if n not in antes)
        # A oficina por ÚLTIMO: um desenho gravado por ela põe trava no
        # aplicativo (o glifo do Arcticons não vale onde há desenho convertido),
        # e o painel deixa de oferecer o «Usar este ícone» — medido na terceira
        # corrida.
        gravam = ("ícone do aplicativo · Adicionar ícone",
                  "ícone do aplicativo · Desfazer a escolha no traço",
                  "ícone do aplicativo · Usar este ícone",
                  "ícone do aplicativo › oficina · Usar")
        for n in novos:
            if n in self.acionados or n in gravam or not self.acionador(n):
                continue
            self.abrir_painel(nome)
            if "› oficina" in n:
                self.garantir_aberto("oficina")
            if "edição do SVG" in n and "· abre «" not in n:
                self.garantir_aberto("edição do SVG")
            self.acionar(n, limpar=False)
        # [P73: o desenho que se escolhe mora numa PASTA, e a que abre sozinha
        # (a primeira do pack no ar) pode ser toda de desenho travado neste
        # aplicativo. Uma pasta com desenho que vale é aberta, e o «escolher»
        # é acionado nela — o gesto de quem procura no acervo.]
        escolher = "ícone do aplicativo › desenho do acervo · escolher"
        if escolher not in self.acionados:
            self.abrir_painel(nome)
            pasta = self.pag.locator("#conteudo details.pasta-acervo:has(button:not(.travado))")
            if pasta.count() and not pasta.first.evaluate("(d) => d.open"):
                pasta.first.locator(":scope > summary").click()
                self.assentar(quieto=300, teto=8000)
            if self.achar(escolher) is not None:
                self.acionar(escolher, limpar=False)
        for n in gravam[:3]:
            self.abrir_painel(nome)
            if n == gravam[2]:
                pasta = self.pag.locator("#conteudo details.pasta-acervo:has(button:not(.travado))")
                if pasta.count() and not pasta.first.evaluate("(d) => d.open"):
                    pasta.first.locator(":scope > summary").click()
                    self.assentar(quieto=300, teto=8000)
            if self.achar(n) is not None:
                self.acionar(n, limpar=False)
        # O «Desfazer» só existe quando o aplicativo tem desenho gravado — o que o
        # «Usar este ícone» acabou de fazer. Reaberto, ele tem de aparecer, e é
        # ele que devolve a raiz de brinquedo ao que era. (Aplicativo com trava
        # não oferece o «Usar»: aí não há o que conferir.)
        # [P73: o «Desfazer» é o do traço ou o da escolha de desenho, conforme o
        # desenho que o «Usar» conseguiu escolher; os dois tiram a linha do
        # estado da casa.]
        if gravam[2] in novos:
            self.abrir_painel(nome)
            desfazer = next((n for n in ("ícone do aplicativo · Desfazer a escolha no traço",
                                         "ícone do aplicativo · Desfazer a minha escolha")
                             if self.achar(n) is not None), None)
            if self.checa(desfazer is not None,
                          "depois do «Usar este ícone», o painel oferece o «Desfazer» dela"):
                self.acionar(desfazer, limpar=False)
        self.abrir_painel(nome)
        self.garantir_aberto("oficina")
        if self.achar(gravam[3]) is not None:
            self.acionar(gravam[3], limpar=False)
        self.fechar_painel_do_aplicativo(nome)

    def garantir_aberto(self, qual):
        """Reabre, pelo clique no `<summary>`, a oficina ou a edição do SVG que
        uma repintura fechou."""
        sel = {"oficina": "#conteudo details.oficina",
               "edição do SVG": "#conteudo details.oficina-edicao"}[qual]
        if qual == "edição do SVG":
            self.garantir_aberto("oficina")
        det = self.pag.locator(sel)
        if det.count() and not det.first.evaluate("(d) => d.open"):
            det.first.locator(":scope > summary > span, :scope > summary").first.click()
            self.assentar(quieto=300, teto=15000)

    def cartao_do_aplicativo(self, nome):
        """O cartão do aplicativo aberto, pronto para o clique.

        A GRADE SOME ENQUANTO O ESQUEMA SE RELÊ — 24/09/2026, depois da leva B.
        Um trabalho que escreve esquece a lista de aplicativos (P46) e a relê
        depois do esquema, que leva de 2 a 4 s; com a máquina carregada, a grade
        voltava depois dos 8 s do clique, e o gate reprovava «aplicativo ·
        abrir» sem defeito novo na página (medido: nenhum botão da grade no DOM
        no instante da reprovação). E o cartão que já estava na tela podia
        estar debaixo do desenho preso no topo da aba (`.previa-bloco.presa`),
        que tomava o clique. A grade é esperada como uma pessoa esperaria, e o
        cartão vai para o meio da tela antes do clique. A demora em si é da P57."""
        cartao = self.pag.locator(f'[data-inventario="{css_attr(nome)}"]',
                                  has_text=self.app_aberto).first
        cartao.wait_for(state="attached", timeout=30000)
        cartao.evaluate("e => e.scrollIntoView({block: 'center'})")
        return cartao

    def abrir_painel(self, nome):
        if not self.pag.locator("#conteudo .escolha-icone").count():
            self.censo()
            self.cartao_do_aplicativo(nome).click()
            self.assentar(quieto=400, teto=15000)

    def fechar_painel_do_aplicativo(self, nome):
        if self.pag.locator("#conteudo .escolha-icone").count():
            self.censo()
            self.cartao_do_aplicativo(nome).click()
            self.assentar(quieto=200)

    # ======================================================================
    # UM JOGO DA STEAM: o painel da decisão
    # ======================================================================
    def h_jogo(self, nome):
        """Tirar do lançador, voltar ao normal, apagar os arquivos — as três
        decisões, cada uma com o jogo reaberto, na pasta de brinquedo."""
        def abrir():
            if not self.pag.locator("#conteudo .escolha-jogo").count():
                self.esperar_nome(nome).click()
                self.assentar(quieto=300)
        abrir()
        if not self.checa(self.pag.locator("#conteudo .escolha-jogo").count(),
                          "clicar no jogo abre a decisão dele"):
            return
        # TODA CONTAGEM DA ABA CONCORDA COM O NÚMERO (P54, achado 43, e a
        # revisão, que achou a segunda: «1 jogos têm atalho», na grade de
        # ícones). A contagem de atalhos é da MÁQUINA — o `.desktop` da Steam
        # do sistema entra nela —, então o 1 é posto na página, e não esperado
        # da casa: medido nesta bancada, com a Steam instalada, a conferência
        # passava vazia contra o código de antes.
        self.js("() => { JOGOS.total_apps = 1; render(); }")
        # [P77: as contas viraram selos, e a frase de cada um mora no balão e
        # no `aria-label` dele — o texto conferido é o da tela mais o desses
        # nomes.]
        texto = self.pag.locator("#conteudo").inner_text() + "\n" + self.js(
            "() => [...document.querySelectorAll('#conteudo [aria-label]')]"
            ".map((e) => e.getAttribute('aria-label')).join('\\n')")
        self.js("() => carregarJogos()")
        self.assentar(quieto=300)
        loja = self.js("() => (JOGOS.apps || []).some((a) => a.id === 'steam')")
        self.checa(not loja, "a loja (a Steam, que se declara Game) não conta como jogo")
        solto = re.findall(r"\b1 jogos\b[^.]*", texto)
        self.checa(not solto and "1 jogo tem atalho" in texto,
                   f"a aba não diz «1 jogos», e diz «1 jogo tem atalho» ({solto})")
        motivo = self.achar("decisão do jogo · campo «Por que este jogo sai do lançador»")
        if self.checa(motivo is not None, "a decisão tem o campo do motivo"):
            motivo.fill("teste do percurso")
            self.acionados.add("decisão do jogo · campo «Por que este jogo sai do lançador»")
        for rotulo in ("Tirar do lançador", "Voltar ao normal"):
            abrir()
            botao = f"decisão do jogo · {rotulo}"
            if self.checa(self.achar(botao) is not None, f"a decisão oferece «{rotulo}»"):
                # Os dois perguntam antes desde a P54: a decisão de 24/09 nomeia
                # a CLASSE («as ações de jogos que aplicam todas as marcas
                # pendentes»), e o «Voltar ao normal» também grava a linha e
                # roda a passagem inteira — ele ficou de fora na primeira
                # versão, e a revisão o pegou.
                self.decisao_com_caixa(lambda b=botao: self.achar(b).click(),
                                       f"«{rotulo}»", abrir)
                self.acionados.add(botao)
        abrir()
        apagar = "decisão do jogo · Apagar os arquivos"
        if self.checa(self.achar(apagar) is not None, "a decisão oferece «Apagar os arquivos»"):
            n0 = len(self.posts)
            self.achar(apagar).click()
            if self.checa(self.caixa_aberta(), "«Apagar os arquivos» pergunta antes"):
                self.pag.locator("#confirmar button[value=nao]").click()
                self.assentar()
                self.checa(len(self.posts) == n0, "Cancelar não marca nada")
            abrir()
            pasta = os.path.join(CASA, ".steam", "steam", "steamapps", "common", "JogoDeBrinquedo")

            def confirmar_apagar():
                self.achar(apagar).click()
                if self.caixa_aberta():
                    self.pag.locator("#confirmar-ok").click()
            self.decisao_de_jogo(confirmar_apagar, "«Apagar os arquivos»")
            self.checa(not os.path.exists(pasta),
                       "e a pasta do jogo (de brinquedo) sai do disco")
            self.acionados.add(apagar)
            # O jogo apagado leva o manifesto junto: ele sai da grade e passa às
            # «Decisões já executadas», com a data — é onde ela o vê depois.
            self.assentar(quieto=300)
            orfa = self.pag.locator("#conteudo .linha-orfa", has_text="Jogo de Brinquedo")
            self.checa(orfa.count() and "apagados" in orfa.first.inner_text(),
                       "e o jogo passa às «Decisões já executadas», com os arquivos apagados")

    # O CARTÃO A QUE A FICHA LEVOU: existe, está na janela e está aceso.
    CHEGADA_JS = r"""
    (k) => {
      const c = document.querySelector(`#conteudo article.cartao[data-chave="${k}"]`);
      if (!c) return null;
      const r = c.getBoundingClientRect();
      return { visivel: r.top >= 0 && r.bottom <= innerHeight + 1,
               aceso: c.classList.contains('chegou') };
    }
    """

    def h_ficha_mudada(self, nome):
        """A ficha de ajuste mudado da Início leva ao CARTÃO, e não só à aba: a
        aba troca, a página rola até ele, e ele fica aceso (P54, achado 18).
        O aceso dura segundos, então ele é conferido assim que o cartão nasce,
        antes do `assentar` — que numa aba de prévias pode passar do prazo."""
        el = self.achar(nome)
        chave = el.get_attribute("data-leva")
        el.click()
        onde, fim = None, time.time() + 2.2
        while time.time() < fim:
            onde = self.js(self.CHEGADA_JS, chave)
            if onde and onde["visivel"] and onde["aceso"]:
                break
            self.pag.wait_for_timeout(50)
        self.checa(self.aba_atual() != "Início", f"a ficha leva à aba do ajuste ({self.aba_atual()})")
        self.checa(onde and onde["visivel"],
                   f"a ficha rola até o cartão {chave}, e ele fica inteiro na janela")
        self.checa(onde and onde["aceso"], f"e o cartão {chave} chega aceso")
        self.assentar(quieto=200)
        self.abrir_aba(self.aba)

    def h_usar_icone(self, nome):
        """«Usar este ícone»: grava a escolha no estado da casa, e não na raiz.

        [P73, 09/10/2026 (I3): até aqui a prova era «o mapa de ícones do
        projeto muda» — e era a regressão. Usar o programa não pode sujar o
        repositório: a escolha vai para `~/.config/meow/icones-*.map`.]"""
        # Sem desenho escolhido a página só diz "escolha um desenho primeiro":
        # o gesto dela é escolher e depois usar — um que valha (sem trava), e
        # visível (numa pasta aberta). O traço primeiro, como sempre foi.
        if not self.pag.locator("#conteudo .tira-glifos button[aria-pressed=true]").count():
            vale = self.pag.locator("#conteudo .tira-glifos button:not(.travado):not(.do-pack):visible")
            if not vale.count():
                vale = self.pag.locator("#conteudo .tira-glifos button:not(.travado):visible")
            vale.first.click()
        antes, n0 = retrato(), len(self.posts)
        self.achar(nome).click()
        post = self.esperar_post(n0, teto=10)
        self.checa(post and post[0] == "app-icone" and (post[1].get("glifo") or post[1].get("arquivo")),
                   "«Usar este ícone» grava o desenho escolhido")
        self.assentar(quieto=300, teto=20000)
        self.esperar_trabalho()
        mudou = diferenca(antes, retrato())
        self.checa(any(c.startswith("casa/.config/meow/icones-") for c in mudou),
                   "e a escolha vai para o estado da casa (~/.config/meow/icones-*.map)")
        self.checa(not any(c.startswith(("raiz/assets/icones/", "raiz/packs/")) for c in mudou),
                   "e a raiz (de brinquedo) não muda: " + ", ".join(
                       c for c in mudou if c.startswith("raiz/"))[:200])

    def h_travado(self, nome):
        """O desenho travado não responde ao clique, e diz que não vale (P73)."""
        el = self.achar(nome)
        n0 = len(self.posts)
        # O Playwright não clica no que tem `aria-disabled` (é o que o diz
        # inativo); o clique vai pelo evento, como o de uma pessoa insistindo.
        el.dispatch_event("click")
        self.assentar(quieto=150, teto=4000)
        el = self.achar(nome)
        self.checa(el is not None and el.get_attribute("aria-disabled") == "true"
                   and el.get_attribute("aria-pressed") != "true" and len(self.posts) == n0,
                   "o desenho travado não fica marcado, nem grava nada, e diz que não vale")

    def h_voltar_icone(self, nome):
        antes, n0 = retrato(), len(self.posts)
        self.achar(nome).click()
        post = self.esperar_post(n0, teto=10)
        self.checa(post and post[1].get("remover") is True,
                   f"«{nome.split(' · ')[-1]}» pede para tirar o desenho")
        self.assentar(quieto=300, teto=20000)
        self.esperar_trabalho()
        self.checa(diferenca(antes, retrato()), "e o mapa volta ao que era")

    def h_oficina_regua(self, nome):
        """A régua move, e a oficina pede ao servidor o desenho com o valor novo.

        A PROVA É O PEDIDO, E NÃO A LUPA: numa arte simples o conversor devolve
        o MESMO desenho com a suavidade em 2 e em 9 (medido na P33, e de novo
        aqui no «Arquivos»), e cobrar a lupa mudada reprovaria a régua por uma
        coisa que é da arte."""
        rotulo = nome.split("«")[-1][:-1]
        el = self.achar(nome)
        campo = el.get_attribute("name")
        v0 = el.input_value()
        n0 = len(self.posts)
        el.focus()
        self.pag.keyboard.press("Home" if v0 == el.get_attribute("max") else "End")
        self.assentar(quieto=400, teto=20000)
        el = self.achar(nome)
        novo = el.input_value() if el is not None else v0
        self.checa(novo != v0, f"«{rotulo}» se move com o teclado ({v0} → {novo})")
        pedidos = [c for d, c in self.posts[n0:] if d == "app-desenho"]
        self.checa(pedidos and str(pedidos[-1].get(campo)) == novo,
                   f"e a oficina pede o desenho com {campo}={novo}")

    def h_editor_svg(self, nome):
        """«Abrir no <editor>»: grava o rascunho no estado (de brinquedo). Com o
        painel sem janela (`--sem-abrir`), o servidor NÃO abre programa nenhum
        e diz isso — é o caminho que ele tem para teste, e o que se confere é
        que ele o tomou."""
        antes, n0 = retrato(), len(self.posts)
        self.achar(nome).click()
        post = self.esperar_post(n0, teto=10)
        self.assentar(quieto=200)
        self.checa(post and post[1].get("acao") == "editor",
                   "«Abrir no editor» manda o desenho ao servidor")
        self.checa(any("/meowsystem/oficina/" in c for c in diferenca(antes, retrato())),
                   "e o rascunho nasce no estado da casa")
        self.checa(not any(l.startswith("xdg-open") for l in registro()),
                   "e nenhum programa é aberto na sessão")

    def h_reler_svg(self, nome):
        n0 = len(self.posts)
        self.achar(nome).click()
        post = self.esperar_post(n0, teto=10)
        self.assentar(quieto=200)
        self.checa(post and post[1].get("acao") == "editor-ler",
                   "«Reler» pergunta ao servidor pelo rascunho")

    def h_usar_oficina(self, nome):
        """O «Usar» da oficina grava o desenho no mapa e o põe na tela."""
        el = self.achar(nome)
        if el.is_disabled():
            variacao = self.pag.locator("#conteudo .oficina-folha button")
            if variacao.count():
                variacao.first.click()
                self.assentar(quieto=400, teto=15000)
            el = self.achar(nome)
        if not self.checa(el is not None and el.is_enabled(),
                          "escolher uma variação acende o «Usar» da oficina"):
            return
        antes, n0 = retrato(), len(self.posts)
        el.click()
        post = self.esperar_post(n0, teto=10)
        self.assentar(quieto=300, teto=20000)
        self.esperar_trabalho()
        self.checa(post and post[0] == "app-desenho", "«Usar» grava o desenho da oficina")
        # [P82, item 5 (decisão 15): o desenho da oficina mora no estado de quem
        #   usa — o `icones-convertidos.map` ao lado do meow.conf —, e o
        #   repositório não muda.]
        mudou = diferenca(antes, retrato())
        self.checa(any(c.endswith(".config/meow/icones-convertidos.map") for c in mudou),
                   "e o mapa de convertidos de quem usa (de brinquedo) muda")
        self.checa(not any(c.startswith("raiz/assets/icones/") for c in mudou),
                   "e o repositório (de brinquedo) não muda")

    def h_texto_svg(self, nome):
        el = self.achar(nome)
        v0 = el.input_value()
        el.fill(v0.replace("</svg>", '<circle cx="4" cy="4" r="2"/></svg>') if v0 else
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
                '<circle cx="24" cy="24" r="9"/></svg>')
        self.assentar(quieto=200)
        desf = self.pag.locator("details.oficina button", has_text="Desfazer")
        self.checa(desf.count() and desf.first.is_enabled(),
                   "editar o SVG à mão acende o Desfazer")

    def h_desfazer_oficina(self, nome):
        """O Desfazer nasce apagado; a edição do SVG à mão é o que o acende."""
        el = self.achar(nome)
        if el.is_disabled():
            self.garantir_aberto("edição do SVG")
            area = self.pag.locator("#conteudo details.oficina textarea")
            area.fill(area.input_value().replace("</svg>", '<circle cx="4" cy="4" r="2"/></svg>'))
            self.assentar(quieto=200)
            el = self.achar(nome)
        if not self.checa(el is not None and el.is_enabled(),
                          "editar o SVG acende o Desfazer"):
            return
        area = self.pag.locator("#conteudo details.oficina textarea")
        v0 = area.input_value() if area.count() else ""
        el.click()
        self.assentar(quieto=300, teto=15000)
        self.checa(area.count() and area.input_value() != v0,
                   "Desfazer devolve o desenho anterior")

    # ======================================================================
    # QUEM ACIONA O QUÊ
    # ======================================================================
    # Pelo PAPEL do controle, e não pelo nome dele: um cartão novo com um
    # deslizante já nasce com acionador. Um papel sem linha aqui reprova como
    # "sem acionador", que é o "não tem teste" dito pelo lado do código.
    def acionador(self, nome):
        tabela = [
            (r" · \?$", self.h_porque),
            (r"^ajuste \S+ · opção$", self.h_opcoes),
            # [P79, decisão 10: o restaurar das chaves de fábrica preenchida diz
            #   o de fábrica no parêntese; o «Não tocar» é o vazio delas.]
            (r"^ajuste \S+ · (deixar vazio|Restaurar ao padrão( \(.*\))?|Automático)$",
             self.h_botao_do_cartao),
            (r"^ajuste \S+ · deslizante$", self.h_deslizante),
            (r"^ajuste \S+ · campo$", self.h_campo),
            (r"^ajuste \S+ · hora$", self.h_hora),
            (r"^ajuste \S+ · nova ficha$", self.h_nova_ficha),
            (r"^ajuste \S+ › ficha da lista · tirar$", self.h_tirar_ficha),
            (r"^ajuste \S+ · seletor$", self.h_seletor_ajuste),
            (r" · ver comando$", self.h_ver_comando),
            (r"^ação «.*» · Executar$", self.h_executar),
            # [P82, item 22: o par «ver / aplicar» — o «Conferir» é o Executar
            #   do ver, e o segundo botão é o aplicar, pelo rótulo dele.]
            (r"^ação «.*» · Conferir$", self.h_executar),
            (r"^ação «(Ver o que mudaria nos jogos do Heroic|O que a atualização mudaria)» · ", self.h_par),
            (r"^ação «.*» · seletor$", self.h_seletor_acao),
            (r" · Adicionar (tema|logo|imagem|fonte|tema de ícones|ícone)$", self.h_acervo),
            (r"^aba · (Escuro|Vidro escuro|Vidro claro|Claro)$", self.h_fundo),
            (r"^aba · (No carrossel|Noite|Dia|Favoritos|Recusadas)$", self.h_aba_galeria),
            (r"^papel de parede · (Usar|Dia|Noite|Tirar)$", self.h_galeria),
            (r"^papel de parede · Guardar nas favoritas$", self.h_favoritar),
            (r"^aba · filtro «", self.h_filtro),
            (r"âncora «Pular", self.h_pular),
            (r"^aplicativo · abrir$", self.h_aplicativo),
            (r"^jogo da Steam · abrir$", self.h_jogo),
            (r"^ajuste mudado · ir ao cartão$", self.h_ficha_mudada),
            (r" · abre «", self.h_details),
            (r" · link externo$", self.h_link_externo),
            (r"^cartão de pack · Usar este$", self.h_clique_de_acao),
            (r"^aba · ação rápida ", self.h_clique_de_acao),
            (r"^pendência · Resolver$", self.h_resolver),
            (r"^pendência · Não, obrigado$", self.h_recusar),
            (r"^pendência · (Trocar pelo tema do pack|Manter o meu)$", self.h_clique_de_acao),
            (r"^cartão de pack · Remover$", self.h_remover_pack),
            (r"^aba · (Tópicos|Sistema|Abrir .+)$", self.h_porta),
            (r"^aba · Exportar o meu$", self.h_exportar_pack),
            (r"^aba · Importar um pack$", self.h_importar_pack),
            (r"^aba · (Conferir|Arrumar os jogos no lançador)$", self.h_clique_de_acao),
            (r"^jogo órfão · Tirar da lista$", self.h_orfa),
            (r" › (desenho do acervo|cor|variação|desenho autoral) · escolher$", self.h_escolher),
            (r" › papel do desenho · seletor$", self.h_seletor_solto),
            (r"^ícone do aplicativo · filtro «", self.h_filtro_glifos),
            (r"^ícone do aplicativo · Usar este ícone$", self.h_usar_icone),
            (r"^ícone do aplicativo · Desfazer a (escolha no traço|minha escolha)$",
             self.h_voltar_icone),
            (r"› desenho travado · dica$", self.h_travado),
            (r"oficina · deslizante «", self.h_oficina_regua),
            (r"edição do SVG · texto «", self.h_texto_svg),
            (r"edição do SVG · Abrir no editor$", self.h_editor_svg),
            (r"edição do SVG · Reler$", self.h_reler_svg),
            (r"› oficina · Usar$", self.h_usar_oficina),
            (r"oficina · Desfazer$", self.h_desfazer_oficina),
            (r"^desenhos autorais · Salvar no pack$", self.h_salvar_autoral),
            (r"^topo · #busca$", self.h_busca),
            (r"^topo · #baixar-\w+$", self.h_baixa),
            (r"^topo · #rotulo-importar$", self.h_importar_conf),
            (r"^topo · #botao-ensaiar$", self.h_ensaiar_salvar),
            (r"^topo · #botao-salvar$", self.h_salvar),
            (r"^topo · #salvar-conta$", self.h_salvar_conta),
        ]
        for padrao, funcao in tabela:
            if re.search(padrao, nome):
                return funcao
        return None

    def acionar(self, nome, limpar=True, esperar=True):
        funcao = self.acionador(nome)
        t0 = time.time()
        gesto_antes = self.gesto
        self.gesto = nome
        if funcao is None:
            self.falha("o controle não tem acionador neste teste — um papel novo "
                       "precisa de uma linha em `Percurso.acionador`")
        elif esperar and self.esperar_nome(nome) is None:
            self.falha("o controle sumiu da aba antes do gesto (a lista que o traz "
                       "não voltou em 8 s)")
        else:
            try:
                funcao(nome)
            except Exception as e:
                self.falha(f"o gesto quebrou: {type(e).__name__}: {str(e).splitlines()[0][:160]}")
                self.foto(f"quebra-{len(self.falhas)}")
        self.acionados.add(nome)
        self.duracoes[nome] = self.duracoes.get(nome, 0) + (time.time() - t0)
        if limpar:
            try:
                self.voltar()
            except Exception as e:
                self.falha(f"não consegui voltar ao começo da aba: {type(e).__name__}: "
                           f"{str(e).splitlines()[0][:120]}")
        self.gesto = gesto_antes

    def foto(self, nome):
        pasta = FOTOS or os.path.join(tempfile.gettempdir(), "meow-app-completo")
        os.makedirs(pasta, exist_ok=True)
        caminho = os.path.join(pasta, re.sub(r"[^\w.-]+", "-", nome) + ".png")
        try:
            self.pag.screenshot(path=caminho, full_page=True)
        except Exception:
            return None
        return caminho

    def h_filtro_glifos(self, nome):
        # [P73: a busca casa também o nome do app no mapa e o significado no
        # catálogo, então um achado pode não ter o termo no NOME do arquivo. O
        # que se cobra é que ela filtra (menos que antes) e acha o desenho de
        # cujo nome o termo saiu.]
        tira = self.pag.locator("#conteudo .tira-glifos button")
        n0 = tira.count()
        primeiro = (tira.first.get_attribute("data-glifo") or "") if n0 else ""
        termo = primeiro[:4]
        if not self.checa(termo, "a tira tem desenhos para buscar"):
            return
        self.achar(nome).fill(termo)
        self.assentar(quieto=400, teto=10000)
        achados = tira.evaluate_all("(bs) => bs.map((b) => b.dataset.glifo)")
        self.checa(achados and len(achados) < n0 and primeiro in achados
                   and sum(termo in g.lower() for g in achados) * 2 >= len(achados),
                   f"buscar {termo!r} filtra a tira e acha {primeiro!r} "
                   f"({len(achados)} de {n0})")
        el = self.achar(nome)
        if el is not None:
            el.fill("")
            self.assentar(quieto=400, teto=10000)

    def h_salvar_autoral(self, nome):
        """Escolher um desenho, trocar uma cor, e só então o Salvar acende."""
        escolher = "desenhos autorais › desenho autoral · escolher"
        el = self.achar(escolher)
        if not self.checa(el is not None, "há um desenho autoral para escolher"):
            return
        el.click()
        self.assentar(quieto=300, teto=10000)
        seletor = "desenhos autorais › papel do desenho · seletor"
        sel = self.achar(seletor)
        if not self.checa(sel is not None, "escolher o desenho mostra os papéis de cor"):
            return
        atual = sel.input_value()
        outro = next(o for o in sel.locator("option").evaluate_all(
            "(os) => os.map((o) => o.value)") if o != atual)
        sel.select_option(outro)
        self.assentar(quieto=300, teto=10000)
        self.acionados.add(seletor)
        botao = self.achar(nome)
        if not self.checa(botao is not None and botao.is_enabled(),
                          "trocar uma cor acende o «Salvar no pack»"):
            return
        antes, n0 = retrato(), len(self.posts)
        botao.click()
        post = self.esperar_post(n0, teto=10)
        self.assentar(quieto=300, teto=20000)
        self.checa(post and post[0] == "autorais", "«Salvar no pack» grava o desenho")
        self.checa(any(c.startswith("raiz/packs/") for c in diferenca(antes, retrato())),
                   "e o pack (de brinquedo) muda no disco")

    # ======================================================================
    # A ABA
    # ======================================================================
    def percorrer_aba(self, grupo):
        self.aba, self.gesto = grupo, ""
        t0 = time.time()
        self.abrir_aba(grupo)
        self.acionados.add(f"menu · {grupo}")
        self.checa(self.aba_atual() == grupo, f"o menu abre «{grupo}»")
        print(f"\n== {grupo}")
        foto = self.foto(f"aba-{grupo}")
        self.texto_ruim()
        base = {n: a for n, a in self.censo().items() if a["zona"] == "aba"}
        self.base[grupo] = base
        self.conferir_inventario(grupo, base)
        print(f"   {sum(a['n'] for a in base.values())} controles, {len(base)} nomes"
              + (f" · captura em {foto}" if foto else ""))
        for nome in sorted(base):
            if nome in self.acionados and (nome.startswith("papel de parede")
                                           or nome.startswith("aplicativo")):
                continue
            self.acionar(nome)
        self.texto_ruim()
        self.tempos[grupo] = time.time() - t0
        print(f"   {self.tempos[grupo]:.0f} s")

    def percorrer_topo(self):
        """Menu, banner e o salto de teclado: a moldura de toda aba."""
        self.aba, self.gesto = "topo", ""
        t0 = time.time()
        self.abrir_aba("Início")
        self.aba = "topo"
        print("\n== topo (menu, banner, gaveta e caixa)")
        base = {n: a for n, a in self.censo().items() if a["zona"] != "aba"}
        self.base["topo"] = base
        self.conferir_inventario("topo", base)
        for nome in sorted(base):
            if nome.startswith("menu · ") and nome != "menu · link externo":
                # Cada aba é aberta pelo menu no percurso dela; com `--aba
                # topo` o menu é clicado aqui, para o topo prestar contas só.
                if SO_ABA == "topo":
                    self.abrir_aba(nome.split(" · ", 1)[1])
                    self.acionados.add(nome)
                    self.abrir_aba("Início")
                continue
            self.acionar(nome)
            if self.aba_atual() != "Início":
                self.abrir_aba("Início")
        # O CONTADOR DE ESCOLHAS SÓ EXISTE COM ESCOLHA PENDENTE: o gesto que o
        # revela (duas escolhas) mora no acionador dele, que o chama pelo nome.
        self.acionar("topo · #salvar-conta", esperar=False)
        self.tempos["topo"] = time.time() - t0

    # ======================================================================
    # O INVENTÁRIO É O GATE
    # ======================================================================
    def conferir_inventario(self, grupo, base):
        conhecidos = INVENTARIO.get(grupo)
        if conhecidos is None:
            self.falha(f"a aba «{grupo}» não tem inventário — aba nova precisa de uma "
                       "entrada em INVENTARIO")
            conhecidos = set()
        for nome in sorted(set(base) - conhecidos):
            self.falha(f"o controle «{nome}» da aba «{grupo}» não tem teste: ele não está "
                       "no inventário")
        for nome in sorted(conhecidos - set(base)):
            self.falha(f"o controle «{nome}» do inventário sumiu da aba «{grupo}»")

    def fechar_contas(self):
        """O que apareceu no meio de um gesto e o que ficou sem clique."""
        self.gesto = ""
        todo_inventario = set().union(*INVENTARIO.values()) if INVENTARIO else set()
        for grupo, vistos in self.vistos.items():
            self.aba = grupo
            permitidos = INVENTARIO.get(grupo, set()) | INVENTARIO.get("topo", set())
            if grupo == "(busca)":
                # A busca junta cartões de todas as abas: vale o que alguma
                # aba conhece.
                permitidos = todo_inventario
            for nome in sorted(vistos):
                if nome in permitidos or casa_revelado(nome, grupo) or \
                   (grupo == "(busca)" and any(casa_revelado(nome, g) for g in REVELADOS)):
                    continue
                self.falha(f"o controle «{nome}» apareceu em «{grupo}» e não tem teste: "
                           "ele não está em REVELADOS")
        self.aba = "(fim)"
        # Com `--aba`, só a aba pedida presta contas: o topo e o que se revela
        # em toda aba dependem do percurso inteiro, que é o que o gate roda.
        def conta(grupo):
            return not SO_ABA or grupo == SO_ABA
        todos_vistos = {n for v in self.vistos.values() for n in v}
        for grupo, padroes in REVELADOS.items():
            for padrao in sorted(padroes) if conta(grupo) else ():
                if not any(casa(padrao, n) for n in todos_vistos):
                    self.falha(f"o controle revelado «{padrao}» ({grupo}) nunca apareceu")
                elif not any(casa(padrao, a) or casa(a, padrao) for a in self.acionados):
                    self.falha(f"o controle revelado «{padrao}» ({grupo}) apareceu e "
                               "não foi acionado")
        for grupo, nomes in INVENTARIO.items():
            for nome in sorted(nomes) if conta(grupo) else ():
                if not any(casa(nome, a) or casa(a, nome) for a in self.acionados):
                    self.falha(f"o controle «{nome}» ({grupo}) não foi acionado")


def casa(padrao, nome):
    """`*` no inventário é "qualquer coisa": `ajuste * · Aplicar`."""
    if "*" not in padrao:
        return padrao == nome
    return re.fullmatch(".*".join(re.escape(p) for p in padrao.split("*")), nome) is not None


def casa_revelado(nome, grupo):
    return any(casa(p, nome) for p in REVELADOS.get(grupo, set()) | REVELADOS["(toda aba)"])


# ===========================================================================
# AS EXCEÇÕES: o que nem a casa de brinquedo roda de verdade
# ===========================================================================
# Pela AÇÃO do servidor, e não pelo botão: a mesma ação tem mais de uma porta
# na página (o «Instalar tudo», o «Salvar e aplicar», o «Aplicar» do aviso), e
# a razão de não rodar é dela, não da porta. Cada uma é provada PROTEGIDA pelo
# protocolo das três respostas: a caixa abre, mostra o comando, o Cancelar não
# pede nada, e o «Ver o que faria» roda o ensaio sem mudar a casa.
#
# A LISTA NÃO FICA VELHA SOZINHA: ela tem de ser exatamente o conjunto das
# ações que o servidor declara pedir senha ou baixar da internet (`sudo`,
# `rede`). Uma ação nova com essas marcas reprova até ganhar a linha dela, e
# uma exceção que perdeu a marca reprova até sair daqui.
# O REPARO QUE BAIXA — decisão 7 da leva G, 09/10/2026 (P78)
#   «O doctor não tem que avisar nada. Tem que corrigir.» A regra da P46 (ação
#   que baixa não roda sem caixa de pergunta) passa a valer só para a ação que
#   baixa E é OPCIONAL — instalar o starship, baixar a coleção. O reparo que
#   quem usa pede (natureza `consertar`, sem senha) é isento: roda direto, e o
#   gate cobra dele o selo «baixa da internet» à vista, no lugar da pergunta.
def reparo_que_baixa(acao):
    return bool(acao["rede"]) and not acao["sudo"] and acao.get("natureza") == "consertar"


EXCECOES = {
    "instalar": "roda o instalador inteiro: pede senha, baixa fontes e compila os "
                "applets. Na casa de brinquedo leva um minuto e sai 2 por falta de "
                "rede e de sessão — o ensaio prova o que ele faria, e o Salvar é "
                "provado gravando com o instalador ocupado",
    "desinstalar": "desfaz a instalação e pede senha; na casa de brinquedo não há o que "
                   "desfazer além do que o próprio teste pôs, e o ensaio mostra o plano",
    "pack_usar": "troca o pack e roda o instalador inteiro (senha e rede)",
    "sistema_atualizar": "atualiza o Pop!_OS inteiro com senha e rede",
    "sistema_limpar": "apaga pacote do sistema com senha",
    "wallpaper_semear": "baixa a coleção curada da internet",
    "prompt_instalar_starship": "baixa e instala o starship da internet",
    "files_menu_build": "baixa e compila o cosmic-files (dezenas de minutos)",
    "spotify_baixar_tema": "baixa o tema do spicetify da internet",
    # [P79, decisão 9: o gesto explícito na extensão que um pack importado pede.]
    "vscode_instalar_extensao": "baixa e instala no VS Code a extensão que o pack importado pede",
}


# ===========================================================================
# OS DEFEITOS CONHECIDOS: achados pelo percurso, e fora do território dele
# ===========================================================================
# O percurso conserta o que acha dentro de `app/`. O que ele acha FORA — num
# script, na CLI — fica aqui, pela frase exata da reprovação e com o endereço
# do conserto: a linha aparece em toda corrida como `~~ conhecido`, e o gate
# não fica vermelho por uma coisa que esta sprint não pode tocar. E a lista não
# esconde nada por muito tempo: um defeito daqui que parou de aparecer reprova
# ("saia da lista"), para ela nunca guardar um conserto que já aconteceu —
# menos o que depende do estado da sessão, que é dito na linha dele.
#   Cada entrada: padrão da reprovação -> (endereço do conserto, se ele aparece
# em TODA corrida).
DEFEITOS_CONHECIDOS = {
    # Vazio desde 24/09/2026: os dois que a P46 achou (o `usar` que o
    # `cmd_wallpaper` não repassava e o `meow_lancador_reler` que mirava o
    # lançador da máquina inteira) foram consertados na origem, e o percurso
    # passou a cobrar que o «Usar» da galeria termine bem.
    #
    # P77, 10/10/2026: com as ações técnicas no «⋯», «O carrossel agora» passou
    # a ser o PRIMEIRO script de papel de parede da aba (o «⋯» abre antes dos
    # outros gestos, pela ordem dos nomes), e numa casa nova ele semeia o
    # estado: o `meow_estado_com_padrao` (lib/comum.sh) copia o `BANIDOS.txt` e
    # o `lado.tsv` da receita na primeira LEITURA, inclusive num verbo que só
    # mostra. Antes, um gesto que escreve chegava primeiro e escondia isso.
    # Aparece só quando nada semeou antes, por isso não em toda corrida.
    r"«O carrossel agora» não muda a casa — mudou \d+: \['casa/\.local/state/meowsystem/"
    r"papeis-de-parede/": (
        "lib/comum.sh `meow_estado_com_padrao`: semear o estado só em verbo que "
        "escreve (o `meow wallpaper` sem argumento só lê)", False),
}


# ===========================================================================
# O INVENTÁRIO
# ===========================================================================
# Um nome por linha, no formato que o censo escreve (`contexto · papel`). A
# medição que o gerou está no cabeçalho deste arquivo; para acrescentar um
# controle, a reprovação já traz a linha pronta.
def _linhas(texto):
    return {l.strip() for l in texto.strip().splitlines() if l.strip()}


# O QUE ESTÁ NA TELA AO ABRIR CADA ABA — medido em 24/09/2026 na casa de
# brinquedo (`montar_casa`): 14 abas e o topo, 754 controles, 459 nomes.
# P77, 09/10/2026: cada aba ganhou o `?` do cabeçalho e o do desenho («aba · ?»),
# e cada cartão de ação o `?` da ajuda («ação «X» · ?»). Os nomes entraram aqui
# com o mesmo acionador de todo `?` (`h_porque`).
INVENTARIO = {
    "topo": _linhas("""
        menu · Atualização
        menu · Cor e tela
        menu · Dia e noite
        menu · Instalação
        menu · Início
        menu · Lançadores e jogos
        menu · Logo do sistema
        menu · Manutenção
        menu · Modo de leitura
        menu · Painel e dock
        menu · Papel de parede
        menu · Terminal
        menu · link externo
        menu · Áreas de trabalho
        menu · Ícones
        página · âncora «Pular para o conteúdo»
        topo · #botao-ensaiar
        topo · #botao-salvar
        topo · #busca
        topo · #rotulo-importar
        topo · abre «Exportar»
    """),
    "Início": _linhas("""
        aba · ?
        aba · Abrir Dia e noite
        aba · Abrir Modo de leitura
        aba · Exportar o meu
        aba · Importar um pack
        aba · Sistema
        aba · Tópicos
        aba · ação rápida doctor
        aba · ação rápida doctor_consertar
        aba · ação rápida painel_reciclar
        aba · ação rápida wallpaper_proximo
        ajuste mudado · ir ao cartão
        cartão de pack · Usar este
        cartão de pack · abre «Detalhes do pack»
        pendência · ?
        pendência · Manter o meu
        pendência · Não, obrigado
        pendência · Resolver
        pendência · Trocar pelo tema do pack
    """),
    "Cor e tela": _linhas("""
        aba · ?
        aba · abre «⋯ Ajustes técnicos»
        aba · Claro
        aba · Escuro
        aba · Vidro claro
        aba · Vidro escuro
        ajuste ACCENT · ?
        ajuste ACCENT · opção
        ajuste CURSOR · ?
        ajuste CURSOR · Adicionar tema
        ajuste CURSOR · deixar vazio
        ajuste CURSOR · opção
        ajuste ESCALA_TELA · ?
        ajuste ESCALA_TELA · deixar vazio
        ajuste ESCALA_TELA · opção
        ajuste FLAVOR · ?
        ajuste FLAVOR · opção
        ajuste JANELAS_TILING · ?
        ajuste JANELAS_TILING · deixar vazio
        ajuste JANELAS_TILING · opção
        ajuste JANELAS_TILING_ESCOPO · ?
        ajuste JANELAS_TILING_ESCOPO · opção
        ajuste MODO · ?
        ajuste MODO · opção
        ajuste PACK · ?
        ajuste PACK · opção
        ação «Passar para claro ou escuro» · ?
        ação «Passar para claro ou escuro» · Executar
        ação «Passar para claro ou escuro» · seletor
        ação «Passar para claro ou escuro» · ver comando
        ação «Temas prontos nesta máquina» · ?
        ação «Temas prontos nesta máquina» · Executar
        ação «Temas prontos nesta máquina» · ver comando
        ação «Trocar de tema» · ?
        ação «Trocar de tema» · Executar
        ação «Trocar de tema» · seletor
        ação «Trocar de tema» · ver comando
    """),
    "Áreas de trabalho": _linhas("""
        aba · ?
        aba · abre «⋯ Ações técnicas»
        ajuste AREAS_ENCAIXE · ?
        ajuste AREAS_ENCAIXE · nova ficha
        ajuste AREAS_FOLGA · ?
        ajuste AREAS_FOLGA · campo
        ajuste AREAS_NOMES · ?
        ajuste AREAS_NOMES · campo
        ação «Criar a primeira área» · ?
        ação «Criar a primeira área» · Executar
        ação «Criar a primeira área» · ver comando
        ação «Gravar as áreas» · ?
        ação «Gravar as áreas» · Executar
        ação «Gravar as áreas» · ver comando
        ação «Tirar uma área» · ?
        ação «Tirar uma área» · Executar
        ação «Tirar uma área» · seletor
        ação «Tirar uma área» · ver comando
        ação «Voltar as áreas de antes» · ?
        ação «Voltar as áreas de antes» · Executar
        ação «Voltar as áreas de antes» · ver comando
    """),
    "Logo do sistema": _linhas("""
        aba · ?
        aba · Adicionar logo
        aba · abre «⋯ Ajustes técnicos»
        aba · abre «⋯ Ações técnicas»
        ajuste FASTFETCH_LOGO · ?
        ajuste FASTFETCH_LOGO · opção
        ajuste FASTFETCH_LOGO_ALINHAR · ?
        ajuste FASTFETCH_LOGO_ALINHAR · opção
        ajuste FASTFETCH_LOGO_COLUNAS · ?
        ajuste FASTFETCH_LOGO_COLUNAS · deslizante
        ajuste FASTFETCH_LOGO_LINHAS · ?
        ajuste FASTFETCH_LOGO_LINHAS · deslizante
        ajuste FASTFETCH_LOGO_MODO · ?
        ajuste FASTFETCH_LOGO_MODO · opção
        ajuste FASTFETCH_LOGO_QUEBRAS · ?
        ajuste FASTFETCH_LOGO_QUEBRAS · deslizante
        ajuste FASTFETCH_LOGO_RECUO · ?
        ajuste FASTFETCH_LOGO_RECUO · deslizante
        ajuste FASTFETCH_TITULO · ?
        ajuste FASTFETCH_TITULO · campo
        ajuste FASTFETCH_TITULO · Restaurar ao padrão ({full-user-name} @ {host-name-colored})
        ajuste LOGO_DIA · ?
        ajuste LOGO_DIA · opção
        ajuste LOGO_MODO · ?
        ajuste LOGO_MODO · opção
        ajuste LOGO_NOITE · ?
        ajuste LOGO_NOITE · opção
        ação «Passar ao próximo gato» · ?
        ação «Passar ao próximo gato» · Executar
        ação «Passar ao próximo gato» · ver comando
        ação «Pôr um gato no dock» · ?
        ação «Pôr um gato no dock» · Executar
        ação «Pôr um gato no dock» · seletor
        ação «Pôr um gato no dock» · ver comando
    """),
    # [Integração da leva G, 09/10/2026: o `ajuste ICONES_BASE` saiu daqui. A
    #   P75 aposentou a chave (a base vem do pack, pinada — `migrar_conf.py`,
    #   `APOSENTADAS`) e o cartão sumiu da aba junto com ela do exemplo.]
    "Ícones": _linhas("""
        aba · ?
        aba · abre «⋯ Ajustes técnicos»
        aba · Adicionar tema de ícones
        aba · filtro «Filtrar aplicativo»
        aba · âncora «Pular a lista de aplicativos»
        ajuste ICONES_COR_MARCA · ?
        ajuste ICONES_COR_MARCA · opção
        ajuste ICONES_DRACULA · ?
        ajuste ICONES_DRACULA · opção
        ajuste ICONES_FLAVOR · ?
        ajuste ICONES_FLAVOR · opção
        ajuste ICONES_PASTAS · ?
        ajuste ICONES_PASTAS · seletor
        ajuste ICONES_PASTAS · ver comando
        ajuste ICONES_RESGATADOS · ?
        ajuste ICONES_RESGATADOS · opção
        ajuste NOME_TEMA_ICONES · ?
        ajuste NOME_TEMA_ICONES · campo
        ajuste PASTAS_XDG · ?
        ajuste PASTAS_XDG · opção
        aplicativo · abrir
        ação «Pôr os desenhos em traço na tela» · ?
        ação «Pôr os desenhos em traço na tela» · Executar
        ação «Pôr os desenhos em traço na tela» · ver comando
        ação «Reconstruir o tema de ícones» · ?
        ação «Reconstruir o tema de ícones» · Executar
        ação «Reconstruir o tema de ícones» · ver comando
        ação «Tema de ícones instalado» · ?
        ação «Tema de ícones instalado» · Executar
        ação «Tema de ícones instalado» · ver comando
    """),
    # [P82, 15/10/2026: os «desenhos autorais» saíram do inventário — os dois
    #   packs deixaram de declarar desenho (o Hefesto e o FogStripper,
    #   decisão 16), e sem desenho a oficina não aparece. O gesto continua
    #   coberto pelo `tests/oficina.sh`, num pack de brinquedo que declara.]
    "Painel e dock": _linhas("""
        aba · ?
        aba · abre «⋯ Ações técnicas»
        ajuste FORMA_ALA_FINAL_DOCK · ?
        ajuste FORMA_ALA_FINAL_DOCK · deixar vazio
        ajuste FORMA_ALA_FINAL_DOCK · opção
        ajuste FORMA_ALA_FINAL_PAINEL · ?
        ajuste FORMA_ALA_FINAL_PAINEL · deixar vazio
        ajuste FORMA_ALA_FINAL_PAINEL · opção
        ajuste FORMA_ALA_INICIAL_DOCK · ?
        ajuste FORMA_ALA_INICIAL_DOCK · deixar vazio
        ajuste FORMA_ALA_INICIAL_DOCK · opção
        ajuste FORMA_ALA_INICIAL_PAINEL · ?
        ajuste FORMA_ALA_INICIAL_PAINEL · deixar vazio
        ajuste FORMA_ALA_INICIAL_PAINEL · opção
        ajuste FORMA_CENTRO_DOCK · ?
        ajuste FORMA_CENTRO_DOCK · deixar vazio
        ajuste FORMA_CENTRO_DOCK · opção
        ajuste FORMA_CENTRO_PAINEL · ?
        ajuste FORMA_CENTRO_PAINEL · deixar vazio
        ajuste FORMA_CENTRO_PAINEL · opção
        ajuste FORMA_DOCK_ILHA · ?
        ajuste FORMA_DOCK_ILHA · opção
        ajuste FORMA_DOCK_SOLTO · ?
        ajuste FORMA_DOCK_SOLTO · opção
        ajuste FORMA_ESPACO_DOCK · ?
        ajuste FORMA_ESPACO_DOCK · deslizante
        ajuste FORMA_ESPACO_PAINEL · ?
        ajuste FORMA_ESPACO_PAINEL · deslizante
        ajuste FORMA_MARGEM_DOCK · ?
        ajuste FORMA_MARGEM_DOCK · deslizante
        ajuste FORMA_MARGEM_PAINEL · ?
        ajuste FORMA_MARGEM_PAINEL · deslizante
        ajuste FORMA_PAINEL_ILHA · ?
        ajuste FORMA_PAINEL_ILHA · opção
        ajuste FORMA_PAINEL_SOLTO · ?
        ajuste FORMA_PAINEL_SOLTO · opção
        ajuste FORMA_RAIO_DOCK · ?
        ajuste FORMA_RAIO_DOCK · deslizante
        ajuste FORMA_RAIO_PAINEL · ?
        ajuste FORMA_RAIO_PAINEL · deslizante
        ajuste FORMA_RECHEIO_DOCK · ?
        ajuste FORMA_RECHEIO_DOCK · deslizante
        ajuste FORMA_RECHEIO_PAINEL · ?
        ajuste FORMA_RECHEIO_PAINEL · deslizante
        ajuste MIDIA · ?
        ajuste MIDIA · opção
        ajuste MIDIA_CAPA · ?
        ajuste MIDIA_CAPA · opção
        ajuste MIDIA_CONTROLES · ?
        ajuste MIDIA_CONTROLES · opção
        ajuste MIDIA_COR_ALBUM · ?
        ajuste MIDIA_COR_ALBUM · opção
        ajuste MIDIA_COR_ARTISTA · ?
        ajuste MIDIA_COR_ARTISTA · opção
        ajuste MIDIA_COR_TITULO · ?
        ajuste MIDIA_COR_TITULO · opção
        ajuste MIDIA_FONTE · ?
        ajuste MIDIA_FONTE · deslizante
        ajuste MIDIA_LARGURA · ?
        ajuste MIDIA_LARGURA · campo
        ajuste RELOGIO_SEGUNDOS · ?
        ajuste RELOGIO_SEGUNDOS · deixar vazio
        ajuste RELOGIO_SEGUNDOS · opção
        ajuste VIDRO_AO_MAXIMIZAR · ?
        ajuste VIDRO_AO_MAXIMIZAR · opção
        ajuste VIDRO_OPACIDADE_DOCK · ?
        ajuste VIDRO_OPACIDADE_DOCK · deslizante
        ajuste VIDRO_OPACIDADE_PAINEL · ?
        ajuste VIDRO_OPACIDADE_PAINEL · deslizante
    """),
    "Papel de parede": _linhas("""
        aba · ?
        aba · Adicionar imagem
        aba · Dia
        aba · Favoritos
        aba · No carrossel
        aba · Noite
        aba · Recusadas
        aba · abre «⋯ Ajustes técnicos»
        aba · abre «⋯ Ações técnicas»
        aba · âncora «Pular a galeria»
        ajuste FILES_MENU · ?
        ajuste FILES_MENU · opção
        ajuste WALLPAPER_AJUSTE · ?
        ajuste WALLPAPER_AJUSTE · opção
        ajuste WALLPAPER_FIXO_TTL · ?
        ajuste WALLPAPER_FIXO_TTL · campo
        ajuste WALLPAPER_FONTES_PERMITIDAS · ?
        ajuste WALLPAPER_FONTES_PERMITIDAS · nova ficha
        ajuste WALLPAPER_INTERVALO · ?
        ajuste WALLPAPER_INTERVALO · opção
        ajuste WALLPAPER_NOTIFICAR · ?
        ajuste WALLPAPER_NOTIFICAR · opção
        ajuste WALLPAPER_ORDEM · ?
        ajuste WALLPAPER_ORDEM · opção
        ação «Imagem anterior» · ?
        ação «Imagem anterior» · Executar
        ação «Imagem anterior» · ver comando
        ação «Próxima imagem» · ?
        ação «Próxima imagem» · Executar
        ação «Próxima imagem» · ver comando
        ação «Voltar a girar» · ?
        ação «Voltar a girar» · Executar
        ação «Voltar a girar» · ver comando
        papel de parede · Dia
        papel de parede · Guardar nas favoritas
        papel de parede · Noite
        papel de parede · Tirar
        papel de parede · Usar
        papel de parede · ver comando
    """),
    "Dia e noite": _linhas("""
        aba · ?
        ajuste MODO_AUTO_CLARO_ATE · ?
        ajuste MODO_AUTO_CLARO_ATE · hora
        ajuste MODO_AUTO_CLARO_DE · ?
        ajuste MODO_AUTO_CLARO_DE · hora
        ajuste NOITE_FIM · ?
        ajuste NOITE_FIM · hora
        ajuste NOITE_INICIO · ?
        ajuste NOITE_INICIO · hora
        ajuste WALLPAPER_LIMIAR_LUZ · ?
        ajuste WALLPAPER_LIMIAR_LUZ · deslizante
        ajuste WALLPAPER_NOITE · ?
        ajuste WALLPAPER_NOITE · opção
        ajuste WALLPAPER_NOITE_FIM · ?
        ajuste WALLPAPER_NOITE_FIM · hora
        ajuste WALLPAPER_NOITE_INICIO · ?
        ajuste WALLPAPER_NOITE_INICIO · hora
    """),
    "Modo de leitura": _linhas("""
        aba · ?
        aba · abre «⋯ Ações técnicas»
        ajuste LEITURA_AGENDA · ?
        ajuste LEITURA_AGENDA · deixar vazio
        ajuste LEITURA_AGENDA · opção
        ajuste LEITURA_APPLET · ?
        ajuste LEITURA_APPLET · opção
        ajuste LEITURA_HORARIO_FIM · ?
        ajuste LEITURA_HORARIO_FIM · hora
        ajuste LEITURA_HORARIO_INICIO · ?
        ajuste LEITURA_HORARIO_INICIO · hora
        ajuste LEITURA_RAMPA_MIN · ?
        ajuste LEITURA_RAMPA_MIN · deslizante
        ajuste LEITURA_TEMPERATURA · ?
        ajuste LEITURA_TEMPERATURA · deslizante
        ajuste LEITURA_TEXTURA · ?
        ajuste LEITURA_TEXTURA · deslizante
        ação «Desligar o modo de leitura» · ?
        ação «Desligar o modo de leitura» · Executar
        ação «Desligar o modo de leitura» · ver comando
    """),
    "Terminal": _linhas("""
        aba · ?
        aba · Adicionar fonte
        ajuste PROMPT_STARSHIP · ?
        ajuste PROMPT_STARSHIP · opção
        ajuste TERMINAL_CURSOR · ?
        ajuste TERMINAL_CURSOR · opção
        ajuste TERMINAL_ESQUEMA · ?
        ajuste TERMINAL_ESQUEMA · opção
        ação «Instalar o starship» · ?
        ação «Instalar o starship» · Executar
        ação «Instalar o starship» · ver comando
    """),
    "Lançadores e jogos": _linhas("""
        aba · ?
        aba · Arrumar os jogos no lançador
        aba · Conferir
        aba · abre «⋯ Ações técnicas»
        aba · filtro «Filtrar jogo»
        aba · âncora «Pular a lista»
        aba · âncora «Pular os jogos»
        ajuste APPS_ATIVOS · ?
        ajuste APPS_ATIVOS · nova ficha
        ajuste APPS_ATIVOS › ficha da lista · tirar
        ajuste AUTOSTART_BLOQUEADOS · ?
        ajuste AUTOSTART_BLOQUEADOS · nova ficha
        ajuste LANCADOR_OCULTAR · ?
        ajuste LANCADOR_OCULTAR · nova ficha
        ajuste LANCADOR_OCULTAR › ficha da lista · tirar
        ajuste LANCADOR_SISTEMA · ?
        ajuste LANCADOR_SISTEMA · opção
        ajuste SPOTIFY_MARKETPLACE · ?
        ajuste SPOTIFY_MARKETPLACE · opção
        aplicativo · abrir
        ação «Quais programas estão vestidos» · ?
        ação «Quais programas estão vestidos» · Executar
        ação «Quais programas estão vestidos» · ver comando
        ação «Ver o que mudaria nos jogos do Heroic» · ?
        ação «Ver o que mudaria nos jogos do Heroic» · Conferir
        ação «Ver o que mudaria nos jogos do Heroic» · Pôr os jogos do Heroic no lançador
        ação «Ver o que mudaria nos jogos do Heroic» · ver comando
        jogo da Steam · abrir
        jogo órfão · Tirar da lista
    """),
    "Manutenção": _linhas("""
        aba · ?
        aba · abre «⋯ Ajustes técnicos»
        aba · abre «⋯ Ações técnicas»
        ajuste ASSETS_VIGIA · ?
        ajuste ASSETS_VIGIA · opção
        ajuste ASSETS_VIGIA_NOTIFICAR · ?
        ajuste ASSETS_VIGIA_NOTIFICAR · opção
        ajuste AUTO_REPARO · ?
        ajuste AUTO_REPARO · opção
        ajuste AUTO_REPARO_NOTIFICAR · ?
        ajuste AUTO_REPARO_NOTIFICAR · opção
        ajuste BACKUPS_MANTIDOS · ?
        ajuste BACKUPS_MANTIDOS · campo
        ajuste FLATPAK_VIGIA · ?
        ajuste FLATPAK_VIGIA · opção
        ajuste FLATPAK_VIGIA_NOTIFICAR · ?
        ajuste FLATPAK_VIGIA_NOTIFICAR · opção
        ajuste HEROIC_VIGIA · ?
        ajuste HEROIC_VIGIA · opção
        ajuste LOG_NIVEL · ?
        ajuste LOG_NIVEL · opção
        ajuste PONTE_ROOT · ?
        ajuste PONTE_ROOT · opção
        ajuste SOM · ?
        ajuste SOM · opção
        ajuste STEAM_VIGIA · ?
        ajuste STEAM_VIGIA · opção
        ação «Ouvir o som» · ?
        ação «Ouvir o som» · Executar
        ação «Ouvir o som» · ver comando
    """),
    "Instalação": _linhas("""
        aba · ?
        aba · abre «⋯ Ações técnicas»
        ação «Conferir a máquina» · ?
        ação «Conferir a máquina» · Executar
        ação «Conferir a máquina» · ver comando
        ação «Consertar o que estiver fora» · ?
        ação «Consertar o que estiver fora» · Executar
        ação «Consertar o que estiver fora» · ver comando
        ação «Desinstalar o MeowSystem» · ?
        ação «Desinstalar o MeowSystem» · Executar
        ação «Desinstalar o MeowSystem» · ver comando
        ação «Instalar tudo» · ?
        ação «Instalar tudo» · Executar
        ação «Instalar tudo» · ver comando
        ação «Voltar ao tema de antes» · ?
        ação «Voltar ao tema de antes» · Executar
        ação «Voltar ao tema de antes» · ver comando
    """),
    "Atualização": _linhas("""
        aba · ?
        ação «Limpar o que sobrou» · ?
        ação «Limpar o que sobrou» · Executar
        ação «Limpar o que sobrou» · ver comando
        ação «O que a atualização mudaria» · ?
        ação «O que a atualização mudaria» · Conferir
        ação «O que a atualização mudaria» · Atualizar a máquina inteira
        ação «O que a atualização mudaria» · ver comando
    """),
}

# O QUE SÓ APARECE DEPOIS DE UM GESTO: a caixa de pergunta, a gaveta, o
# «Copiar» do «ver comando», o «Aplicar» do cartão com escolha pendente, o
# conteúdo de um `<details>`, o painel de um aplicativo. O `*` é "qualquer
# coisa" — um «Aplicar» por cartão é um molde, e não 123 linhas. Cada linha
# daqui tem de APARECER na corrida e ser ACIONADA; a que some reprova.
# O painel que o clique num aplicativo abre é o mesmo nas duas grades (Ícones
# e o ícone de cada jogo, em Lançadores).
# [P73, 09/10/2026: a ficha ganhou as pastas por acervo (`abre «…»`, uma por
# pasta), o desenho travado (apagado, com a dica) e os dois «Desfazer» — o do
# traço e o da escolha de desenho, ambos no estado de quem usa. O molde
# `Desfazer a *` cobre os dois: qual aparece depende do desenho que o percurso
# conseguiu escolher no aplicativo da máquina.]
PAINEL_DO_APLICATIVO = _linhas("""
    ícone do aplicativo · Adicionar ícone
    ícone do aplicativo · Usar este ícone
    ícone do aplicativo · Desfazer a *
    ícone do aplicativo · abre «*»
    ícone do aplicativo › desenho travado · dica
    ícone do aplicativo · filtro «Buscar desenho»
    ícone do aplicativo › cor · escolher
    ícone do aplicativo › desenho do acervo · escolher
    ícone do aplicativo › oficina · Desfazer
    ícone do aplicativo › oficina · Usar
    ícone do aplicativo › oficina · abre «Gerar ícone — MeowSystem»
    ícone do aplicativo › oficina · deslizante «Detalhe»
    ícone do aplicativo › oficina · deslizante «Linhas fracas»
    ícone do aplicativo › oficina · deslizante «Suavidade»
    ícone do aplicativo › oficina · deslizante «Traço mínimo»
    ícone do aplicativo › oficina › cor · escolher
    ícone do aplicativo › oficina › edição do SVG · Abrir no editor
    ícone do aplicativo › oficina › edição do SVG · Reler
    ícone do aplicativo › oficina › edição do SVG · abre «Editar o SVG»
    ícone do aplicativo › oficina › edição do SVG · texto «O SVG do desenho»
    ícone do aplicativo › oficina › variação · escolher
""")

REVELADOS = {
    "(toda aba)": _linhas("""
        caixa · Cancelar
        caixa · #confirmar-ok
        caixa · #confirmar-ensaio
        caixa · ?
        gaveta · #parar
        gaveta · #fechar-gaveta
        gaveta · #saida
        gaveta · #mais-abaixo
        gaveta · #ensaio-rodar
        gaveta · #gaveta-consertar
        topo · #botao-descartar
        topo · #salvar-conta
        topo › lista de escolhas › escolha pendente · ir ao cartão
        aviso · #aviso-aplicar-botao
        ajuste * · Aplicar
        *linha de comando · Copiar
        aba · Como está (desfaz o bloco)
        ajuste * · Restaurar ao padrão
        ajuste * · Restaurar ao padrão (*)
        ajuste * · Automático
        ajuste * · deixar vazio
    """),
    "topo": _linhas("""
        topo · #baixar-conf
        topo · #baixar-pagina
    """),
    "Início": _linhas("""
        cartão de pack · link externo
        cartão de pack · Remover
    """),
    # [P77: os ajustes `[avancado]` moram no «⋯ Ajustes técnicos» do fim do
    # bloco; o `h_details` abre o «⋯» e aciona o que ele revela.]
    "Cor e tela": _linhas("""
        ajuste CURSOR_VERSAO · ?
        ajuste CURSOR_VERSAO · campo
        ajuste WALLPAPER_DRACULA_COMMIT · ?
        ajuste WALLPAPER_DRACULA_COMMIT · campo
        ajuste WALLPAPER_DRACULA_REPO · ?
        ajuste WALLPAPER_DRACULA_REPO · campo
    """),
    "Áreas de trabalho": _linhas("""
        ajuste AREAS_FOLGA · deixar vazio
        ajuste AREAS_FOLGA · opção
        ação «As áreas de agora» · ?
        ação «As áreas de agora» · Executar
        ação «As áreas de agora» · ver comando
    """),
    "Ícones": PAINEL_DO_APLICATIVO | _linhas("""
        ajuste ICONES_LOGO_HEFESTO · ?
        ajuste ICONES_LOGO_HEFESTO · campo
    """),
    "Papel de parede": _linhas("""
        ajuste FILES_MENU_AUTOBUILD · ?
        ajuste FILES_MENU_AUTOBUILD · opção
        ajuste WALLPAPER_BASE · ?
        ajuste WALLPAPER_BASE · campo
        ação «Baixar a coleção curada» · ?
        ação «Baixar a coleção curada» · Executar
        ação «Baixar a coleção curada» · ver comando
        ação «Construir o menu da área de trabalho» · ?
        ação «Construir o menu da área de trabalho» · Executar
        ação «Construir o menu da área de trabalho» · ver comando
        ação «Menu da área de trabalho» · ?
        ação «Menu da área de trabalho» · Executar
        ação «Menu da área de trabalho» · ver comando
        ação «O carrossel agora» · ?
        ação «O carrossel agora» · Executar
        ação «O carrossel agora» · ver comando
        ação «Reaplicar as regras do carrossel» · ?
        ação «Reaplicar as regras do carrossel» · Executar
        ação «Reaplicar as regras do carrossel» · ver comando
        papel de parede · Devolver
        papel de parede · Medir
        papel de parede · Tirar das favoritas
    """),
    "Lançadores e jogos": PAINEL_DO_APLICATIVO | _linhas("""
        ação «Baixar o tema do Spotify» · ?
        ação «Baixar o tema do Spotify» · Executar
        ação «Baixar o tema do Spotify» · ver comando
        ação «Vestir os programas agora» · ?
        ação «Vestir os programas agora» · Executar
        ação «Vestir os programas agora» · ver comando
        decisão do jogo · Apagar os arquivos
        decisão do jogo · Tirar do lançador
        decisão do jogo · Voltar ao normal
        decisão do jogo · campo «Por que este jogo sai do lançador»
    """),
    "Painel e dock": _linhas("""
        ação «Até quanto o canto pode arredondar» · ?
        ação «Até quanto o canto pode arredondar» · Executar
        ação «Até quanto o canto pode arredondar» · ver comando
        ação «Como estão o painel e a dock» · ?
        ação «Como estão o painel e a dock» · Executar
        ação «Como estão o painel e a dock» · ver comando
        ação «Recarregar o painel» · ?
        ação «Recarregar o painel» · Executar
        ação «Recarregar o painel» · ver comando
    """),
    "Logo do sistema": _linhas("""
        ajuste FASTFETCH_LOGO_BLOCOS · ?
        ajuste FASTFETCH_LOGO_BLOCOS · opção
        ajuste FASTFETCH_LOGO_CELULA · ?
        ajuste FASTFETCH_LOGO_CELULA · campo
        ajuste FASTFETCH_LOGO_CONF · ?
        ajuste FASTFETCH_LOGO_CONF · opção
        ajuste FASTFETCH_LOGO_DIA · ?
        ajuste FASTFETCH_LOGO_DIA · opção
        ajuste FASTFETCH_LOGO_GATO · ?
        ajuste FASTFETCH_LOGO_GATO · opção
        ajuste FASTFETCH_LOGO_NOITE · ?
        ajuste FASTFETCH_LOGO_NOITE · opção
        ajuste LOGO · ?
        ajuste LOGO · opção
        ajuste LOGO_INTERVALO · ?
        ajuste LOGO_INTERVALO · opção
        ajuste LOGO_RECICLAR · ?
        ajuste LOGO_RECICLAR · opção
        ajuste LOGO_ROTACAO · ?
        ajuste LOGO_ROTACAO · opção
        ação «Qual gato está no ar, e por quê» · ?
        ação «Qual gato está no ar, e por quê» · Executar
        ação «Qual gato está no ar, e por quê» · ver comando
    """),
    # [P77 grupo 4: as duas ações que só mostram (natureza `mostrar`) moram
    # no «⋯» das ações técnicas da Instalação.]
    "Instalação": _linhas("""
        ação «As últimas 50 linhas do registro» · ?
        ação «As últimas 50 linhas do registro» · Executar
        ação «As últimas 50 linhas do registro» · ver comando
        ação «O que está no ar agora» · ?
        ação «O que está no ar agora» · Executar
        ação «O que está no ar agora» · ver comando
    """),
    # [P77 grupo 4: o timbre do sino (`[avancado]`) e o «Regravar o som»
    # (natureza `aplicar`) moram nos dois «⋯» do fim da página.]
    "Manutenção": _linhas("""
        ajuste SOM_DECAIMENTO · ?
        ajuste SOM_DECAIMENTO · deslizante
        ajuste SOM_FUNDAMENTAL · ?
        ajuste SOM_FUNDAMENTAL · deslizante
        ajuste SOM_HARMONICO · ?
        ajuste SOM_HARMONICO · deslizante
        ajuste SOM_PESO_FUNDAMENTAL · ?
        ajuste SOM_PESO_FUNDAMENTAL · campo
        ajuste SOM_PESO_HARMONICO · ?
        ajuste SOM_PESO_HARMONICO · campo
        ação «Regravar o som» · ?
        ação «Regravar o som» · Executar
        ação «Regravar o som» · ver comando
    """),
    "Modo de leitura": _linhas("""
        ação «Aplicar o degrau desta hora» · ?
        ação «Aplicar o degrau desta hora» · Executar
        ação «Aplicar o degrau desta hora» · ver comando
        ação «Modo de leitura agora» · ?
        ação «Modo de leitura agora» · Executar
        ação «Modo de leitura agora» · ver comando
    """),
}


# ===========================================================================
def main():
    # Linha a linha: quem roda o gate acompanha a aba em que ele está.
    sys.stdout.reconfigure(line_buffering=True)
    print("casa de brinquedo em", BRINQUEDO)
    ambiente = montar_casa()
    md5_real = hashlib.md5(open(os.path.join(RAIZ, "meow.conf.exemplo"), "rb").read()).hexdigest()
    proc, url = sobe_servidor(ambiente)
    if not url:
        print("FALHOU: o app/run.sh não imprimiu a URL")
        proc.terminate()
        return 2
    inicio = time.time()
    try:
        with sync_playwright() as p:
            try:
                nav = p.chromium.launch()
            except Exception as e:
                print("FALHOU: o Chromium do Playwright não abriu — "
                      f"{str(e).splitlines()[0][:120]}")
                print("  instale com: <python do teste> -m playwright install chromium")
                return 1
            contexto = nav.new_context(viewport={"width": 1500, "height": 1000},
                                       accept_downloads=True)
            origem = re.match(r"http://[^/]+", url).group(0)
            contexto.grant_permissions(["clipboard-read", "clipboard-write"], origin=origem)
            # Nada sai para a internet: o link externo é conferido pela aba
            # que ele abre, e não pela página do outro lado.
            def fora(rota):
                PEDIDOS_DE_FORA.append(rota.request.url)
                rota.abort()
            contexto.route(lambda u: not u.startswith(origem), fora)
            contexto.set_default_timeout(8000)
            pag = contexto.new_page()
            v = Percurso(pag)
            v.url = url
            pag.goto(url, wait_until="domcontentloaded")
            pag.wait_for_selector("#trilho button")
            v.assentar(quieto=400)

            exc = set(EXCECOES)
            # O reparo que baixa não é exceção: roda de verdade na casa de
            # brinquedo, sem pergunta e com o selo (decisão 7, P78).
            declaradas = {i for i, a in v.acoes().items()
                          if a["sudo"] or (a["rede"] and not reparo_que_baixa(a))}
            v.aba = "exceções"
            for i in sorted(declaradas - exc):
                v.falha(f"a ação {i!r} pede senha ou baixa da internet e não está em "
                        "EXCECOES — o teste a rodaria de verdade")
            for i in sorted(exc - declaradas):
                v.falha(f"a exceção {i!r} não pede senha nem baixa mais: ela sai da lista")

            grupos = pag.evaluate(
                "() => [...document.querySelectorAll('#trilho button[data-grupo]')]"
                ".map((b) => b.dataset.grupo)")
            if not SO_ABA or SO_ABA == "topo":
                v.percorrer_topo()
            for g in grupos:
                if SO_ABA and g != SO_ABA:
                    continue
                v.percorrer_aba(g)
            v.fechar_contas()
            v.aba = "(fim)"
            if not SO_ABA:
                for padrao in sorted(set(DEFEITOS_CONHECIDOS) - v.conhecidos_vistos):
                    if DEFEITOS_CONHECIDOS[padrao][1]:
                        v.falha(f"o defeito conhecido {padrao!r} não apareceu nesta "
                                "corrida: se foi consertado, ele sai de DEFEITOS_CONHECIDOS")

            v.aba = "exceções"
            # O GESTO DA EXTENSÃO DO VS CODE SÓ NASCE COM PACK IMPORTADO NO AR
            #   (P79, decisão 9): os botões são um por extensão que o pack
            #   importado pede, e a casa de brinquedo veste o pack do
            #   repositório. O que se prova aqui é a cerca: sem pack importado,
            #   o servidor recusa rodar a ação com qualquer extensão, mesmo
            #   confirmada. O botão é provado pelo tests/temas-de-apps.sh e pelo
            #   tests/restos-do-painel.sh (o mesmo caminho da escolha da P53).
            if not SO_ABA and "vscode_instalar_extensao" in exc:
                v.esperar_status(409, "/api/rodar")
                r = v.js("(c) => api('/api/rodar', {method: 'POST', body: JSON.stringify(c)})",
                         {"acao": "vscode_instalar_extensao",
                          "argumento": "Catppuccin.catppuccin-vsc", "confirmado": True})
                if v.checa(r and "fora da lista" in str(r.get("erro", "")),
                           f"sem pack importado, o servidor recusa o gesto da extensão ({r!r})"):
                    v.acoes_vistas.setdefault("vscode_instalar_extensao", set()).add("recusada")
            if not SO_ABA:
                for i in sorted(exc):
                    vistas = v.acoes_vistas.get(i, set())
                    v.checa(vistas, f"a exceção {i!r} não apareceu em aba nenhuma")
                    v.checa("rodar" not in vistas and "sem caixa" not in vistas,
                            f"a exceção {i!r} rodou de verdade ({sorted(vistas)})")
            nav.close()
    finally:
        proc.terminate()
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            proc.kill()
        encerrar_a_casa()

    total = time.time() - inicio
    print("\n== o que rodou, e como a gaveta terminou")
    for aba, rot, como, estado, cauda in v.resultados:
        print(f"   {aba[:18]:18s} {rot[:44]:44s} {como:15s} {estado}")
        if cauda:
            print(f"   {'':18s} … {cauda}")
    if v.conhecidos_vistos:
        print("\n== defeitos conhecidos que apareceram, e onde se consertam")
        for padrao in sorted(v.conhecidos_vistos):
            print(f"   ~~ {DEFEITOS_CONHECIDOS[padrao][0]}")
    print("\n== os dez gestos mais demorados")
    for nome, t in sorted(v.duracoes.items(), key=lambda x: -x[1])[:10]:
        print(f"   {t:5.1f} s  {nome}")
    print("\n== tempo por aba")
    for g, t in v.tempos.items():
        print(f"   {g:22s} {t:5.0f} s")
    n_controles = sum(sum(a["n"] for a in b.values()) for b in v.base.values())
    n_nomes = sum(len(b) for b in v.base.values())
    n_abas = len([g for g in v.base if g != "topo"])
    n_revelados = sum(len(r) for r in REVELADOS.values())
    print(f"\n{n_abas} abas e o topo: {n_controles} controles na tela ao abrir, "
          f"{n_nomes} nomes no inventário e {n_revelados} revelados por gesto; "
          f"{len(v.acionados)} acionados; {v.conferidas} conferências; {total:.0f} s.")
    if md5_real != hashlib.md5(open(os.path.join(RAIZ, "meow.conf.exemplo"), "rb").read()).hexdigest():
        v.falhas.append(("(fim)", "o meow.conf.exemplo do repositório mudou durante o teste"))
    if v.falhas:
        print(f"\nFALHOU: {len(v.falhas)} reprovações")
        for onde, frase in v.falhas:
            print(f"  - [{onde}] {frase}")
        return 1
    print("ok: todas as abas, todos os controles acionados, console limpo.")
    return 0


if __name__ == "__main__":
    # O brinquedo sai sempre, inclusive quando o teste morre no meio: ele é uma
    # casa inteira e uma cópia do repositório em /tmp, com falsos dentro. O
    # TERM (o `timeout`, o Ctrl+C de quem roda a suíte) vira saída normal, para
    # o `finally` rodar e levar o painel junto.
    #
    # E O HUP TAMBÉM, E A PASTA É CONFERIDA DEPOIS — 15/10/2026, P82 (item 38).
    #   O terminal que fecha manda HUP, e o HUP sem tratador mata o processo sem
    #   o `finally`: a casa inteira ficava em /tmp. E um processo da casa que
    #   ainda escrevia (um trabalho da gaveta no meio de um `mkdir -p`) podia
    #   recriar a pasta depois do `rmtree`; por isso, se ela voltou, a casa é
    #   encerrada de novo e a pasta sai de novo.
    import signal
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    signal.signal(signal.SIGHUP, lambda *_: sys.exit(129))
    try:
        sys.exit(main())
    finally:
        for _vez in range(2):
            if os.path.isdir(CASA):
                encerrar_a_casa()
            shutil.rmtree(BRINQUEDO, ignore_errors=True)
            if not os.path.exists(BRINQUEDO):
                break
            time.sleep(1)
