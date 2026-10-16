#!/usr/bin/env bash
# assets/temas-de-apps/vscode/manifesto.sh — o tema do pack no Visual Studio Code.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`: quem chama é
# o runner, e um `exit` aqui derrubaria a sessão inteira dele no meio da fila.
#
# O QUE ELE FAZ, EM UMA FRASE
#   Garante instaladas as extensões que o pack no ar declara (a do tema e, se
#   ele trouxer, a dos ícones) e as chaves delas no `settings.json` dela
#   (`workbench.colorTheme` e `workbench.iconTheme`) — sem tocar em mais nada.
#
# ATÉ 24/09/2026 A FRASE ACIMA NOMEAVA AS DUAS EXTENSÕES DO CATPPUCCIN
#   E ela era a verdade do arquivo: `Catppuccin.catppuccin-vsc`, os ícones,
#   "Catppuccin Mocha" e "catppuccin-mocha" cravados, com qualquer pack no ar —
#   com o Dracula, o VS Code recebia o Catppuccin. Desde a P55 os quatro saem do
#   pack no ar (`apps.vscode` e `apps.vscode-icones`), e só do pack no ar: o tema
#   herdado de outro pack é recusado, com o motivo «sem tema neste pack».
#
#   O TEMA DE FORA ENTRA PINADO. O do Catppuccin desce da Marketplace pelo id,
#   como sempre desceu (ver a PROCEDÊNCIA, abaixo). O do Dracula o pack pina: a
#   URL do `.vsix` e o sha256 dele, a forma da base de ícones da P41. O módulo
#   baixa para um temporário, confere, instala pelo CLI (`--install-extension
#   <arquivo>`) e apaga o arquivo; só baixa quando a extensão falta — ou,
#   desde a revisão de 25/09/2026, quando a versão que está no editor não traz
#   o tema (ver o `_meow_vscode_sem_o_tema`).
#
#   PACK SEM TEMA DE ÍCONES (o Dracula) não mexe no `workbench.iconTheme` —
#   menos quando o que está lá é o tema de ícones que OUTRO pack declara, que o
#   MeowSystem pôs: esse volta ao de fábrica, em vez de ficar aceso ao lado do
#   tema do pack no ar.
#
# ─────────────────────────────────────────────────────────────────────────────
# POR QUE O MERGE É TEXTUAL E NÃO `json.load` + `json.dump`
#   O `settings.json` dela tem 20+ chaves e — o que importa mais — tem
#   COMENTÁRIOS: oito blocos `//` explicando por que o auto-update de extensão
#   está desligado, por que os rulers estão em 100, por que o black formata ao
#   salvar. `settings.json` do VS Code é JSONC, e `json.dump` devolveria um
#   arquivo válido e sem alma: comentários apagados, ordem embaralhada, recuo
#   trocado. Então o helper Python aqui de dentro VARRE o texto, acha o span de
#   bytes do valor de cada chave de PRIMEIRO NÍVEL e troca só aqueles bytes.
#   Todo o resto do arquivo sai byte a byte idêntico ao que entrou.
#
#   O varredor entende as três coisas que quebram um regex ingênuo: comentários
#   de linha e de bloco, aspas escapadas dentro de string, e chaves aninhadas
#   (o `"[python]": { "editor.defaultFormatter": ... }` dela tem uma chave em
#   profundidade 2 que NÃO pode ser confundida com uma de primeiro nível).
#
# A ARMADILHA DO `meow_escrever` COM NEWLINE FINAL  (medida, não suposta)
#   `meow_escrever` compara o conteúdo novo com `"$(cat "$destino")"`, e
#   `$(...)` COME as quebras de linha finais. Um conteúdo terminado em "\n"
#   nunca é considerado igual ao arquivo em disco — a função gravaria de novo a
#   cada passagem e devolveria 1 ("consertei") para sempre. Como o arquivo dela
#   termina em "\n" (ela usa `files.insertFinalNewline`) e tirá-lo seria mexer
#   no que é dela, a comparação de idempotência é feita AQUI, byte a byte, com
#   um sentinela `X` no fim da saída para preservar o "\n". O `meow_escrever`
#   continua sendo quem grava — é ele que tem a trava de território e o `mv`
#   atômico dentro do diretório de destino.
#
# E QUEM EMITE O SENTINELA É O PYTHON, NUNCA UM `printf X` NO SHELL
#   Esta linha aqui APAGOU o settings.json dela num teste — 170 bytes viraram 0:
#
#       novo="$(_meow_vscode_json fundir …; printf X)"; rc_json=$?
#
#   Em bash, `$?` depois de uma substituição de comando é o status do ÚLTIMO
#   comando da lista de dentro. Esse último comando era o `printf X`, que nunca
#   falha: `rc_json` valia 0 SEMPRE. Quando o `fundir` recusava o serviço
#   (JSON inválido, `python3` sumido, arquivo ilegível) ele saía 2 com a saída
#   vazia — e o módulo, achando que tinha dado certo, gravava essa string VAZIA
#   por cima da config dela e ainda anunciava "ok, VS Code em Catppuccin Mocha".
#   O backup salvava os dados, mas o arquivo vivo ficava zerado e as 20+
#   escolhas dela sumiam do editor até alguém restaurar na mão.
#
#   Agora o `X` sai do próprio `sys.stdout.write` do helper: o `$?` volta a ser
#   o código de saída do python, e a AUSÊNCIA do `X` no fim vira uma segunda
#   trava — saída truncada ou vazia também é recusada, mesmo que o rc minta.
#
# O QUE O RITUAL DA AURORA FAZ COM ISSO A CADA HORA  (o ponto mais importante)
#   `~/.config/zsh/scripts/configurar-vscode.sh` roda de hora em hora e:
#     1. RECONCILIA A LISTA DE EXTENSÕES — o array `EXTENSOES` inclui
#        `dracula-theme.theme-dracula`, `josemurilloc.aura-spirit-dracula` e
#        `pkief.material-icon-theme`. Ele só INSTALA as ausentes; nunca remove.
#        Consequência prática: desinstalar as Dracula é trabalho perdido, elas
#        voltam em até 1h. Por isso este módulo NÃO desinstala nada — ele
#        apenas troca a chave do tema. As duas convivem no disco, e quem está
#        ativo é decidido pelo `settings.json`.
#     2. CRIA o `settings.json` SÓ SE AUSENTE (`if [ ! -f "$SETTINGS" ]`).
#        Ou seja: a chave do tema que gravamos aqui NÃO é revertida pelo
#        self-heal. É esse detalhe que faz este módulo ser durável.
#     3. APAGA a pasta de qualquer extensão cujo `engines.vscode` peça um minor
#        MAIOR que o do `code` instalado (a faxina que consertou o pt-BR pela
#        metade em 2026-07-21). Se a Catppuccin instalada exigir um VS Code mais
#        novo que o daqui, a Aurora deleta a pasta dentro de uma hora e o VS
#        Code cai calado no tema padrão. Por isso `meow_app_aplicar` confere o
#        engine logo depois de instalar e AVISA — melhor gritar agora do que
#        deixar o tema sumir sozinho de madrugada.
#   NADA disso é editado por aqui: `~/.config/zsh` é o repo Andromeda, com
#   auto-commit a cada 10 minutos. O `meow_destino_permitido` do `comum.sh`
#   inclusive recusaria a escrita.
#
# PROCEDÊNCIA DAS EXTENSÕES (confirmada por fetch em 2026-08-04)
#   - https://github.com/catppuccin/vscode        -> Catppuccin.catppuccin-vsc
#     temas: "Catppuccin Latte/Frappé/Macchiato/Mocha"
#   - https://github.com/catppuccin/vscode-icons  -> Catppuccin.catppuccin-vsc-icons
#     ícones: latte/frappe/macchiato/mocha
#   Não fixamos commit porque a instalação é pela Marketplace, e o CLI do VS
#   Code resolve sozinho a última versão COMPATÍVEL com o `code` instalado —
#   que é exatamente o que a faxina da Aurora (item 3) exige. Fixar versão aqui
#   brigaria com ela. O que verificamos, depois de instalar, é o contrato: que
#   o tema "Catppuccin Mocha" e o ícone "catppuccin-mocha" existem mesmo nos
#   `contributes` da versão que caiu no disco.
#   [P55, 24/09/2026: isto é do pack Catppuccin, que declara as duas extensões
#   pelo id da Marketplace. O Dracula, o pack pina — a origem, a versão e o
#   sha256 estão no packs/dracula/PROCEDENCIA.md.]
# ─────────────────────────────────────────────────────────────────────────────

MEOW_VSCODE_BIN="${MEOW_VSCODE_BIN:-code}"
MEOW_VSCODE_SETTINGS="${MEOW_VSCODE_SETTINGS:-$HOME/.config/Code/User/settings.json}"
MEOW_VSCODE_EXTDIR="${MEOW_VSCODE_EXTDIR:-$HOME/.vscode/extensions}"

# O TEMA, OS ÍCONES E AS DUAS EXTENSÕES SAEM DO PACK NO AR — P55 (ver o topo).
# Nascem vazios, e quem os preenche é o `detectar` (`_meow_vscode_do_pack`). Os
# dois dos ícones podem ficar vazios: é o pack que não traz tema de ícones.
MEOW_VSCODE_TEMA=""
MEOW_VSCODE_ICONES=""
MEOW_VSCODE_EXT_TEMA=""
MEOW_VSCODE_EXT_ICONES=""
# O pacote pinado da extensão do tema, quando o pack traz um.
_MEOW_VSCODE_VSIX=""
_MEOW_VSCODE_VSIX_SHA=""
_MEOW_VSCODE_PACK=""
_MEOW_VSCODE_PACK_NOME=""

# Cache da consulta ao CLI: `code --list-extensions` custa ~0,22 s por chamada
# (medido). Sem cache, um `conferir` gastaria isso três vezes à toa.
_MEOW_VSCODE_LISTA=""

# =============================================================================
# helper 1 — o varredor de JSONC (ler / conferir / fundir)
# =============================================================================
# Recebe o modo e os argumentos por "$@" e o script pelo stdin. Modos:
#   ler      <arquivo> <chave>...           -> {"chave": valor|null} em stdout
#   conferir <arquivo> <chave> <valor>...   -> 0 tudo igual · 1 divergente · 2 erro
#   fundir   <arquivo> <chave> <valor>...   -> texto novo em stdout (não grava)
_meow_vscode_json() {
  python3 -I - "$@" <<'PYFIM'
# -*- coding: utf-8 -*-
import json, os, re, sys

MODO = sys.argv[1] if len(sys.argv) > 1 else ""
CAMINHO = sys.argv[2] if len(sys.argv) > 2 else ""
RESTO = sys.argv[3:]

def pular(t, i):
    """Avança sobre espaço em branco e comentários // e /* */."""
    n = len(t)
    while i < n:
        c = t[i]
        if c in " \t\r\n":
            i += 1
        elif c == "/" and i + 1 < n and t[i + 1] == "/":
            j = t.find("\n", i)
            i = n if j < 0 else j
        elif c == "/" and i + 1 < n and t[i + 1] == "*":
            j = t.find("*/", i + 2)
            i = n if j < 0 else j + 2
        else:
            break
    return i

def fim_string(t, i):
    """i aponta para a aspa de ABERTURA; devolve o índice APÓS a de fechamento."""
    n = len(t)
    j = i + 1
    while j < n:
        if t[j] == "\\":
            j += 2
            continue
        if t[j] == '"':
            return j + 1
        j += 1
    return n

def fim_valor(t, i):
    """Fim do valor JSON que começa em i (string, objeto, lista ou escalar)."""
    n = len(t)
    if i >= n:
        return i
    c = t[i]
    if c == '"':
        return fim_string(t, i)
    if c in "{[":
        prof = 0
        j = i
        while j < n:
            d = t[j]
            if d == '"':
                j = fim_string(t, j)
                continue
            if d == "/" and j + 1 < n and t[j + 1] in "/*":
                j = pular(t, j)
                continue
            if d in "{[":
                prof += 1
            elif d in "}]":
                prof -= 1
                if prof == 0:
                    return j + 1
            j += 1
        return n
    j = i
    while j < n and t[j] not in ",}]\n":
        j += 1
    while j > i and t[j - 1] in " \t\r":
        j -= 1
    return j

def varrer(t):
    """{chave: (ini, fim) do VALOR} das chaves de PRIMEIRO NÍVEL, + pos após '{'.

    Pular o valor inteiro depois de casar uma chave é o que mantém o contador
    de profundidade honesto: o "[python]": { ... } dela tem chaves em
    profundidade 2 que não podem entrar no resultado.
    """
    n = len(t)
    i = 0
    prof = 0
    raiz = None
    achados = {}
    while i < n:
        c = t[i]
        if c in " \t\r\n":
            i += 1
            continue
        if c == "/" and i + 1 < n and t[i + 1] in "/*":
            i = pular(t, i)
            continue
        if c == '"':
            fim = fim_string(t, i)
            if prof == 1:
                k = pular(t, fim)
                if k < n and t[k] == ":":
                    try:
                        chave = json.loads(t[i:fim])
                    except ValueError:
                        chave = None
                    ini = pular(t, k + 1)
                    f = fim_valor(t, ini)
                    if chave is not None:
                        achados[chave] = (ini, f)
                    i = f
                    continue
            i = fim
            continue
        if c in "{[":
            prof += 1
            if c == "{" and prof == 1 and raiz is None:
                raiz = i + 1
            i += 1
            continue
        if c in "}]":
            prof -= 1
            i += 1
            continue
        i += 1
    return achados, raiz

def validar(t):
    """Confere que o texto resultante ainda é um JSONC que o VS Code aceita.

    Rede de segurança: é melhor recusar a gravação do que entregar a ela um
    settings.json quebrado (o VS Code ignora o arquivo inteiro e ela perde as
    20+ escolhas de uma vez). Comentários viram espaço para não mexer nos
    índices; vírgula sobrando é tolerada pelo VS Code, então também aqui.
    """
    saida = []
    i, n = 0, len(t)
    while i < n:
        c = t[i]
        if c == '"':
            j = fim_string(t, i)
            saida.append(t[i:j])
            i = j
            continue
        if c == "/" and i + 1 < n and t[i + 1] in "/*":
            j = pular(t, i)
            saida.append(re.sub(r"[^\n]", " ", t[i:j]))
            i = j
            continue
        saida.append(c)
        i += 1
    limpo = re.sub(r",(\s*[}\]])", r"\1", "".join(saida))
    json.loads(limpo)

if not CAMINHO:
    sys.stderr.write("uso: <modo> <arquivo> ...\n")
    sys.exit(2)

existe = os.path.isfile(CAMINHO)
if existe:
    try:
        texto = open(CAMINHO, encoding="utf-8").read()
    except OSError as e:
        sys.stderr.write("não consegui ler %s: %s\n" % (CAMINHO, e))
        sys.exit(2)
    # ARQUIVO EXISTENTE MAS EM BRANCO — o próprio VS Code trata assim.
    # Sem isto o `varrer` devolvia raiz=None, o `fundir` recusava o serviço e o
    # módulo ficava em divergência ETERNA: `conferir` dizia 1 (a chave não está
    # lá) e `aplicar` dizia 0 ("nada a fazer"), de hora em hora, para sempre.
    # Um `settings.json` de 0 byte aparece sozinho — basta o VS Code criá-lo e
    # ela nunca ter mexido, ou um `touch`. Não há nada dela para preservar.
    if not texto.strip():
        texto = "{\n}\n"
else:
    texto = "{\n}\n"

try:
    achados, raiz = varrer(texto)
except Exception as e:
    sys.stderr.write("não entendi %s: %s\n" % (CAMINHO, e))
    sys.exit(2)

def valor_de(chave):
    if chave not in achados:
        return None
    ini, fim = achados[chave]
    try:
        return json.loads(texto[ini:fim])
    except ValueError:
        return None

if MODO == "ler":
    print(json.dumps({c: valor_de(c) for c in RESTO}, ensure_ascii=False))
    sys.exit(0)

pares = list(zip(RESTO[0::2], RESTO[1::2]))

if MODO == "conferir":
    if not existe:
        print("ausente %s" % CAMINHO)
        sys.exit(1)
    divergiu = 0
    for chave, desejado in pares:
        atual = valor_de(chave)
        if atual != desejado:
            print("divergente %s: atual=%r desejado=%r" % (chave, atual, desejado))
            divergiu = 1
    sys.exit(divergiu)

if MODO == "fundir":
    recuo = "    "
    for linha in texto.splitlines():
        s = linha.lstrip()
        if s.startswith('"'):
            recuo = linha[: len(linha) - len(s)] or "    "
            break
    trocas, inserir = [], []
    for chave, valor in pares:
        if chave in achados:
            ini, fim = achados[chave]
            trocas.append((ini, fim, json.dumps(valor, ensure_ascii=False)))
        else:
            inserir.append((chave, valor))
    # De trás para frente: cada troca desloca os índices que vêm depois.
    novo = texto
    for ini, fim, txt in sorted(trocas, reverse=True):
        novo = novo[:ini] + txt + novo[fim:]
    if inserir:
        if raiz is None:
            sys.stderr.write(
                "não achei o objeto raiz em %s (tem conteúdo mas não abre com "
                "'{') — não vou adivinhar onde enfiar a chave\n" % CAMINHO)
            sys.exit(2)
        # `raiz` continua válido: toda troca acontece DEPOIS do '{' da raiz.
        itens = [
            "%s%s: %s" % (recuo, json.dumps(c, ensure_ascii=False),
                          json.dumps(v, ensure_ascii=False))
            for c, v in inserir
        ]
        # Vírgula só quando já existe alguma chave depois do bloco inserido.
        bloco = "\n" + ",\n".join(itens) + ("," if achados else "")
        # Num "{}" cru o resto começa direto no "}": sem este "\n" a última
        # chave e a chave de fechamento sairiam grudadas na mesma linha.
        if not achados and not novo[raiz:].startswith("\n"):
            bloco += "\n"
        novo = novo[:raiz] + bloco + novo[raiz:]
    try:
        validar(novo)
    except Exception as e:
        sys.stderr.write("o resultado não seria um JSON válido (%s) — nada foi gravado\n" % e)
        sys.exit(2)
    sys.stdout.write(novo)
    # SENTINELA `X`, EMITIDO AQUI E NÃO NO SHELL — ver o cabeçalho do módulo.
    # Ele preserva o "\n" final (que o `$(...)` comeria) E serve de prova de que
    # o helper chegou até o fim: se o chamador não achar o `X`, a saída está
    # truncada e ele recusa a gravação, mesmo que o código de saída minta.
    sys.stdout.write("X")
    sys.exit(0)

sys.stderr.write("modo desconhecido: %s\n" % MODO)
sys.exit(2)
PYFIM
}

# =============================================================================
# helper 2 — extensões
# =============================================================================
_meow_vscode_lista() {
  if [ -z "$_MEOW_VSCODE_LISTA" ]; then
    # SEM PERFIL NO DISCO, O VS CODE NUNCA RODOU AQUI — e perguntar CRIA o
    # perfil. Medido em HOME virgem (10/08/2026): um único
    # `code --list-extensions` deixa .config/Code/machineid, .config/Code/logs/,
    # .cache/Microsoft/DeveloperTools/deviceid e
    # .vscode/extensions/extensions.json. Num MEOW_DRY_RUN=1 isso é a promessa
    # "nada será escrito" virando mentira na fase que só deveria OLHAR.
    if [ ! -d "$MEOW_VSCODE_EXTDIR" ] && [ ! -d "$HOME/.config/Code/User" ]; then
      meow_debug "VS Code sem perfil em $MEOW_VSCODE_EXTDIR nem ~/.config/Code/User"
      _MEOW_VSCODE_LISTA=$'\n'
      printf '%s\n' "$_MEOW_VSCODE_LISTA"
      return 0
    fi
    _MEOW_VSCODE_LISTA="$("$MEOW_VSCODE_BIN" --list-extensions 2>/dev/null \
                          | tr '[:upper:]' '[:lower:]')"
    # marca "já consultei e deu vazio", para não repetir a chamada de 0,22 s.
    # `if` e não `cond && ação`: se o runner que nos deu `source` estiver com
    # `set -e`, uma lista `&&` cujo teste falha devolve 1 e mata o runner.
    if [ -z "$_MEOW_VSCODE_LISTA" ]; then _MEOW_VSCODE_LISTA=$'\n'; fi
  fi
  printf '%s\n' "$_MEOW_VSCODE_LISTA"
}

# Devolve o package.json da extensão instalada, ou vazio.
#
# DUAS ARMADILHAS AQUI, as duas descobertas testando:
#
#  1. `-[0-9]*` E NÃO `-*`. O VS Code nomeia a pasta `<editor>.<nome>-<versão>`,
#     e o id do tema é PREFIXO do id dos ícones:
#       catppuccin.catppuccin-vsc-1.2.3        <- tema
#       catppuccin.catppuccin-vsc-icons-1.2.3  <- ícones
#     Um glob `catppuccin.catppuccin-vsc-*` casa as DUAS pastas. Isso daria o
#     bug mais chato possível: `conferir` juraria que o tema está instalado
#     quando só os ícones estão, e o VS Code cairia no tema padrão sem
#     ninguém reclamar. Exigir dígito depois do hífen separa os dois, porque
#     versão sempre começa com número e `-icons` não.
#
#  2. `find` E NÃO GLOB. O shell de login dela é o zsh, onde a opção `nomatch`
#     (ligada por padrão) faz um glob sem correspondência ABORTAR a função em
#     vez de sobrar literal como no bash. Este arquivo é bash, mas um `find`
#     custa 3 ms e tira o módulo do assunto.
#
#  3. A VERSÃO MAIS ALTA, QUANDO HÁ MAIS DE UMA — 25/09/2026, revisão da P55.
#     Instalar um .vsix por cima de uma versão mais velha pode deixar as duas
#     pastas no disco (o `code` de mentira do tests/temas-de-apps.sh deixa), e o
#     `-print -quit` devolvia a primeira que o `find` achasse. Desde que a
#     versão que não traz o tema do pack deixou de contar como no lugar (ver o
#     `_meow_vscode_sem_o_tema`), ler a velha seria baixar o pacote pinado de
#     novo a cada hora. A que vale é a mais alta — a que acabou de entrar.
_meow_vscode_pkg() {
  local id_min achado
  id_min="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [ -d "$MEOW_VSCODE_EXTDIR" ] || return 1
  achado="$(find "$MEOW_VSCODE_EXTDIR" -mindepth 2 -maxdepth 2 -name package.json \
              -path "$MEOW_VSCODE_EXTDIR/$id_min-[0-9]*/package.json" \
              -print 2>/dev/null | sort -V | tail -n 1)"
  [ -n "$achado" ] || return 1
  printf '%s\n' "$achado"
}

# A PASTA é a verdade, não o CLI: é a pasta que o VS Code varre ao iniciar e é a
# pasta que a faxina da Aurora apaga. O CLI fica de reserva para o caso de um
# `--extensions-dir` customizado.  `grep -F` porque o id tem pontos.
_meow_vscode_tem_ext() {
  local id_min
  id_min="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  _meow_vscode_pkg "$1" >/dev/null && return 0
  _meow_vscode_lista | grep -qixF -- "$id_min"
}

# O QUE A VERSÃO INSTALADA CONTRIBUI, CONTRA O QUE O PACK PEDE. Imprime uma frase
# por nome que falta — o tema, o ícone — e sai 1; sai 0 quando nada falta, ou
# quando o package.json não diz (ilegível, ou sem lista daquele tipo): o que não
# se sabe não é acusado.
#   ERA UM PEDAÇO DA AUDITORIA, QUE SÓ AVISAVA — 25/09/2026, revisão da P55. O
#   `conferir` e o `aplicar` passaram a perguntar a mesma coisa (ver o
#   `_meow_vscode_sem_o_tema`), e a regra saiu de lá para ser uma só. A frase é
#   a de antes; quem põe o «aviso:» na frente é a auditoria.
#   O NOME CASA O `id` OU O `label` do tema — o settings.json o nomeia por um
#   deles, e aceitar os dois não acusa a falta de um tema que está lá. A lista
#   do «tem:» é a de antes.
_meow_vscode_contribui() {   # <package.json> <tema> <ícone>
  python3 -I - "$@" <<'PYFIM' 2>/dev/null
import json, sys
pkg, tema, icone = sys.argv[1:4]
try:
    d = json.load(open(pkg, encoding="utf-8"))
    nome = "%s@%s" % (d.get("name"), d.get("version"))
    c = d.get("contributes") or {}
    temas = [t for t in c.get("themes") or [] if isinstance(t, dict)]
    icones = [t for t in c.get("iconThemes") or [] if isinstance(t, dict)]
except Exception:
    sys.exit(0)
falta = 0
if tema and temas and tema not in [t.get(k) for t in temas for k in ("id", "label")]:
    print("%s não contribui o tema %r (tem: %s)"
          % (nome, tema, ", ".join(str(t.get("label") or t.get("id")) for t in temas)))
    falta = 1
if icone and icones and icone not in [t.get("id") for t in icones]:
    print("%s não contribui o ícone %r (tem: %s)"
          % (nome, icone, ", ".join(str(t.get("id")) for t in icones)))
    falta = 1
sys.exit(falta)
PYFIM
}

# 0 = a extensão do tema está no disco e a versão dela NÃO traz o tema que o pack
# pede — a frase fica em `_VSC_SEM_O_TEMA`; 1 = traz, não está no disco, ou o
# package.json não diz.
#
# A VERSÃO QUE NÃO TRAZ O TEMA NÃO ESTÁ NO LUGAR — 25/09/2026, revisão da P55
#   A 2.25 do Dracula renomeou o tema de «Dracula» para «Dracula Theme» (ver o
#   packs/dracula/PROCEDENCIA.md), e o módulo só instalava a extensão que FALTA.
#   Medido com uma 2.24.3 de brinquedo e o Dracula no ar: o `aplicar` gravava
#   «Dracula Theme», avisava uma vez, e dali em diante o `conferir` e o `aplicar`
#   diziam «já no lugar», com o editor no tema de fábrica. E o settings.json
#   dela desliga a atualização automática de extensões (lido em 25/09/2026:
#   `"extensions.autoUpdate": false`), então uma 2.24 que já estivesse lá
#   ficaria. Agora é divergência: com pino, o `aplicar` põe o pacote pinado por
#   cima; sem pino, é pendência dita, e nada é escrito — atualizar sem pino
#   seria trazer a versão que a Marketplace quisesse, que é o que aquela chave
#   desliga.
_VSC_SEM_O_TEMA=""
_meow_vscode_sem_o_tema() {
  local pkg
  _VSC_SEM_O_TEMA=""
  pkg="$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_TEMA")" || return 1
  _VSC_SEM_O_TEMA="$(_meow_vscode_contribui "$pkg" "$MEOW_VSCODE_TEMA" "")" && return 1
  [ -n "$_VSC_SEM_O_TEMA" ]
}

# Confere se a versão instalada realmente contribui o tema/ícone que pedimos, e
# se o engine dela sobrevive à faxina da Aurora. Só avisa — nunca falha o passo.
_meow_vscode_auditar_ext() {
  local pkg menor linha
  # `code --version` cria o perfil igual ao `--list-extensions`. Sem perfil não
  # há extensão para auditar, então a auditoria não tem o que fazer aqui — e
  # perguntar seria escrever num modo que prometeu não escrever.
  if [ ! -d "$MEOW_VSCODE_EXTDIR" ]; then return 0; fi
  menor="$("$MEOW_VSCODE_BIN" --version 2>/dev/null | head -1 | cut -d. -f2)"
  for pkg in "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_TEMA" 2>/dev/null || true)" \
             "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_ICONES" 2>/dev/null || true)"; do
    if [ -z "$pkg" ] || [ ! -f "$pkg" ]; then continue; fi
    python3 -I - "$pkg" "${menor:-0}" <<'PYFIM'
import json, sys
pkg, minor = sys.argv[1], int(sys.argv[2] or 0)
try:
    d = json.load(open(pkg, encoding="utf-8"))
except Exception as e:
    print("aviso: não consegui ler %s (%s)" % (pkg, e))
    sys.exit(0)
nome = "%s@%s" % (d.get("name"), d.get("version"))
eng = (d.get("engines") or {}).get("vscode", "")
v = eng.replace("^", "").replace(">=", "").split(".")
try:
    if minor and int(v[0]) == 1 and int(v[1]) > minor:
        print("aviso: %s exige VS Code %s e o instalado é 1.%d — o "
              "configurar-vscode.sh do Ritual da Aurora APAGA essa pasta na "
              "próxima passagem (até 1h) e o tema cai para o padrão" % (nome, eng, minor))
except (IndexError, ValueError):
    pass
PYFIM
    # O tema e o ícone que faltam na versão instalada: a regra mora no
    # `_meow_vscode_contribui` (25/09/2026).
    while IFS= read -r linha; do
      if [ -n "$linha" ]; then printf 'aviso: %s\n' "$linha"; fi
    done < <(_meow_vscode_contribui "$pkg" "$MEOW_VSCODE_TEMA" "$MEOW_VSCODE_ICONES")
  done
}

# =============================================================================
# helper 3 — backup (regra 4: antes de sobrescrever, sempre)
# =============================================================================
# Guarda o arquivo em ~/.local/state/meowsystem/backups/<ISO>/<caminho relativo
# ao HOME>, com `manifesto.sha256` e `origens.txt` — sem o caminho absoluto
# original um "desfazer" não saberia para onde devolver o arquivo.
#
# O CARIMBO É `%Y-%m-%dT%H-%M-%S`, COM HÍFENS, E ISSO NÃO É ESTÉTICA
#   A pasta `backups/` é COMPARTILHADA por todos os módulos — medido no disco:
#   `2026-08-04T20-14-44` é do módulo Qt (dark.css, kdeglobals, qt5ct.conf) e
#   `2026-08-04T20-17-02` é do Obsidian. Todos usam esse formato. Se este
#   módulo usasse `date -Iseconds` (`2026-08-04T20:18:00-03:00`), os nomes
#   deixariam de ordenar juntos: em ASCII o `-` (0x2D) vem ANTES do `:` (0x3A),
#   então TODA pasta com hífen pareceria mais antiga que qualquer uma com dois
#   pontos, no mesmo minuto. Quem podasse "as 10 mais novas" apagaria as dos
#   outros módulos primeiro, por ordenação e não por idade.
_meow_vscode_backup() {
  local origem="$1" carimbo destino rel
  if [ ! -f "$origem" ]; then return 0; fi
  carimbo="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_ESTADO/backups/$carimbo"
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  mkdir -p "$destino/$(dirname "$rel")" || return 1
  cp -p -- "$origem" "$destino/$rel" || return 1
  ( cd "$destino" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  printf '%s\n' "$origem" >> "$destino/origens.txt" || return 1
  meow_info "backup: $destino/$rel"
  return 0
}

# POR QUE ESTE MÓDULO NÃO PODA OS BACKUPS
#   A regra 4 do repo fala em reter as 10 últimas, mas a pasta é compartilhada
#   (ver acima) e cada módulo cria a sua a cada passagem. Podar "as 10 mais
#   novas" DAQUI apagaria o histórico dos outros módulos — com cinco módulos e
#   o self-heal de hora em hora, 10 pastas são menos de duas rodadas. A
#   retenção é decisão de quem enxerga a fila inteira: o runner / `meow
#   desfazer`. Aqui a gente só deposita.

# =============================================================================
# helper 4 — o pack no ar (P55, 24/09/2026)
# =============================================================================
# O id e o nome de tela do pack no ar, pela regra única do `adocao` — a mesma do
# `meow_pack_dir`. O nome é o que as frases do desfazer dizem.
#
# E, NA MESMA PERGUNTA, O RESTO DO BLOCO — 25/09/2026, revisão da P55
#   Cada `meow_app_tema_do_pack` abre dois python (o `adocao` do `meow_pack_dir`
#   e o verbo `app`), e este módulo fazia seis perguntas por passada, mais esta.
#   Medido numa casa de brinquedo com o Catppuccin no ar, sem nada a fazer, e a
#   mesma carga nas três árvores: o `conferir` ia de 27 ms antes da P55 a 680
#   ms, e com as cinco trilhas aqui vai a 179 ms. O `esquema` continua sendo
#   perguntado direto — é ele que diz de que pack é o bloco, e a herança é
#   recusada por ele —, e as outras cinco trilhas saem daqui, com o pack.py
#   importado: o mesmo `tema_de_app`, com o diretório que o `adocao` deu, que é
#   o que o `meow_pack_dir` imprime e o verbo `app` recebe. Vazio é ausência,
#   como lá. A resposta é uma linha por campo, e por isso um valor com quebra
#   de linha — que o pack de terceiro pode escrever — conta como ausente, e o
#   nome de tela sai numa linha só: nenhum dos dois inventa um campo a mais.
_VSC_EXT=""; _VSC_URL=""; _VSC_SHA=""; _VSC_ICONES=""; _VSC_ICONES_PACK=""; _VSC_EXT_ICONES=""; _VSC_DO_REPO=""
_meow_vscode_pack_no_ar() {
  local saida
  saida="$(PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

ident, dir_pack, _recusado = pack.adocao(os.environ.get("PACK", ""), os.environ.get("FLAVOR", ""))
print("pack=" + ident)
print("nome=" + " ".join(str(pack.campo(ident, "nome") or ident).splitlines()))
icones_pack = ""
for chave, trilha in (("ext", "vscode.origem.extensao"), ("url", "vscode.origem.url"),
                      ("sha", "vscode.origem.sha256"), ("icones", "vscode-icones.esquema"),
                      ("ext_icones", "vscode-icones.origem.extensao")):
    quem, valor = pack.tema_de_app("apps." + trilha, ref=dir_pack or None)
    if quem is None or valor is None or any(c in str(valor) for c in "\r\n"):
        quem = valor = ""
    print("%s=%s" % (chave, valor))
    if chave == "icones":
        icones_pack = quem
print("icones_pack=" + icones_pack)
# DE ONDE O PACK VEIO — decisão 9 (10/10/2026, P79). Só o pack que mora no
# `packs/` deste repositório instala extensão sozinho. A pasta é a que o
# `adocao` escolheu (o padrão, quando nada escolheu), com os links resolvidos:
# um pack importado com o MESMO id do Dracula, numa raiz de cima, é importado.
dir_real = os.path.realpath(dir_pack or pack.achar(ident) or "")
do_repo = os.path.realpath(os.path.join(pack.RAIZ, "packs"))
print("repo=" + ("1" if dir_real.startswith(do_repo + os.sep) else "0"))
PYFIM
)" || return 1
  _MEOW_VSCODE_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  _MEOW_VSCODE_PACK_NOME="$(printf '%s\n' "$saida" | sed -n 's/^nome=//p')"
  _VSC_EXT="$(printf '%s\n' "$saida" | sed -n 's/^ext=//p')"
  _VSC_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  _VSC_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha=//p')"
  _VSC_ICONES="$(printf '%s\n' "$saida" | sed -n 's/^icones=//p')"
  _VSC_ICONES_PACK="$(printf '%s\n' "$saida" | sed -n 's/^icones_pack=//p')"
  _VSC_EXT_ICONES="$(printf '%s\n' "$saida" | sed -n 's/^ext_icones=//p')"
  _VSC_DO_REPO="$(printf '%s\n' "$saida" | sed -n 's/^repo=//p')"
  [ -n "$_MEOW_VSCODE_PACK" ]
}

# O QUE O PACK NO AR DECLARA. Preenche os quatro do topo e, quando a extensão do
# tema desce pinada, o `_MEOW_VSCODE_VSIX` e o `_MEOW_VSCODE_VSIX_SHA`. Sai pelo
# `meow_app_sem`: é um pedaço do `detectar`. Só vale o bloco do PACK NO AR — o
# tema herdado de outro pack é recusado, e os ícones herdados são ignorados.
#   A forma do pino é conferida aqui, e não no `pack.py`: https e 64 hex
#   minúsculos, as regras da P41. [25/09/2026, revisão da P55: o Obsidian
#   passou a chamar o `origem_pinada` do pack.py, que é a regra daquela forma —
#   um .tar com a `pasta` de dentro. Este pino é outra forma, um .vsix que o CLI
#   instala inteiro, e o `origem_pinada` o recusaria; as duas regras daqui
#   continuam sendo desta forma.]
_meow_vscode_do_pack() {
  MEOW_VSCODE_TEMA=""; MEOW_VSCODE_ICONES=""; MEOW_VSCODE_EXT_TEMA=""; MEOW_VSCODE_EXT_ICONES=""
  _MEOW_VSCODE_VSIX=""; _MEOW_VSCODE_VSIX_SHA=""
  _meow_vscode_pack_no_ar || { meow_app_sem "VS Code: o scripts/pack.py não disse qual é o pack no ar"; return; }
  # Direto, sem `$( )`: a resposta vem pelas duas variáveis (lib/comum.sh).
  meow_app_tema_do_pack vscode.esquema
  if [ -z "$MEOW_APP_TEMA" ]; then
    meow_app_sem "VS Code: sem tema neste pack ($_MEOW_VSCODE_PACK_NOME) — o editor fica como está"
    return
  fi
  if [ "$MEOW_APP_TEMA_PACK" != "$_MEOW_VSCODE_PACK" ]; then
    meow_app_sem "VS Code: sem tema neste pack ($_MEOW_VSCODE_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEMA', do pack $MEOW_APP_TEMA_PACK, e o tema de um pack não veste outro"
    return
  fi
  MEOW_VSCODE_TEMA="$MEOW_APP_TEMA"
  # O resto do bloco já veio na pergunta do `_meow_vscode_pack_no_ar` (25/09/2026).
  MEOW_VSCODE_EXT_TEMA="$_VSC_EXT"
  if [ -z "$MEOW_VSCODE_EXT_TEMA" ]; then
    meow_app_sem "VS Code: o pack $_MEOW_VSCODE_PACK_NOME pede o tema '$MEOW_VSCODE_TEMA' e não diz de que extensão ele vem (apps.vscode.origem.extensao)"
    return
  fi
  # O ID VAI PARA A LINHA DE COMANDO DO `code`, e quem o escreve é o pack: fora
  # da forma `<editor>.<nome>` (letras, dígitos e hífen, como a Marketplace os
  # dá), um id que começasse por `-` viraria opção do CLI.
  if ! [[ "$MEOW_VSCODE_EXT_TEMA" =~ ^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
    meow_app_sem "VS Code: a extensão '$MEOW_VSCODE_EXT_TEMA' do pack $_MEOW_VSCODE_PACK_NOME não tem a forma <editor>.<nome> — nada é instalado"
    MEOW_VSCODE_EXT_TEMA=""
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # O PINO SÓ VALE NO PACK DO REPOSITÓRIO — 10/10/2026, P79 (alerta de
  #   segurança da revisão do 8f668d0). O gesto da decisão 9 consente pelo NOME
  #   da extensão, e o que descia era o `.vsix` da URL e do sha256 que o PACK
  #   escolheu: um pack importado podia pôr o nome de uma extensão conhecida e
  #   a URL de um código qualquer. Para o importado, a URL e o sha256 dele são
  #   ignorados, e a extensão entra pelo id, da loja oficial
  #   (`code --install-extension <id>`), que é o id que a pendência mostra.
  if [ "$_VSC_DO_REPO" = "1" ]; then
    _MEOW_VSCODE_VSIX="$_VSC_URL"; _MEOW_VSCODE_VSIX_SHA="$_VSC_SHA"
  fi
  if [ -n "$_MEOW_VSCODE_VSIX$_MEOW_VSCODE_VSIX_SHA" ]; then
    case "$_MEOW_VSCODE_VSIX" in
      https://*) ;;
      *) meow_app_sem "VS Code: o pacote da extensão $MEOW_VSCODE_EXT_TEMA no pack $_MEOW_VSCODE_PACK_NOME não vem de uma URL https ('$_MEOW_VSCODE_VSIX')"; return ;;
    esac
    if ! [[ "$_MEOW_VSCODE_VSIX_SHA" =~ ^[0-9a-f]{64}$ ]]; then
      meow_app_sem "VS Code: o pacote da extensão $MEOW_VSCODE_EXT_TEMA no pack $_MEOW_VSCODE_PACK_NOME não traz um sha256 (64 hex) — sem ele a URL entrega o que quiser"
      return
    fi
  fi
  if [ -n "$_VSC_ICONES" ] && [ "$_VSC_ICONES_PACK" = "$_MEOW_VSCODE_PACK" ]; then
    MEOW_VSCODE_ICONES="$_VSC_ICONES"
    MEOW_VSCODE_EXT_ICONES="$_VSC_EXT_ICONES"
    if [ -z "$MEOW_VSCODE_EXT_ICONES" ]; then
      meow_app_sem "VS Code: o pack $_MEOW_VSCODE_PACK_NOME pede os ícones '$MEOW_VSCODE_ICONES' e não diz de que extensão eles vêm (apps.vscode-icones.origem.extensao)"
      return
    fi
    if ! [[ "$MEOW_VSCODE_EXT_ICONES" =~ ^[A-Za-z0-9][A-Za-z0-9-]*\.[A-Za-z0-9][A-Za-z0-9-]*$ ]]; then
      meow_app_sem "VS Code: a extensão '$MEOW_VSCODE_EXT_ICONES' do pack $_MEOW_VSCODE_PACK_NOME não tem a forma <editor>.<nome> — nada é instalado"
      MEOW_VSCODE_EXT_ICONES=""
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  fi
  return "$MEOW_OK"
}

# OS TEMAS DE ÍCONES QUE OS PACKS DO DISCO DECLARAM, separados por vírgula: a
# régua do "de outro pack" da função logo abaixo, e ela não depende do pack no
# ar. Uma pergunta só ao `scripts/pack.py`, importado.
#
# SÓ O PACK QUE PASSA NO `validar` CONTA — 25/09/2026, P61
#   A lista era toda pasta com um pack.json, sem o `validar`. Medido com uma
#   pasta `torta` que não passa nele (falta o `formato`) e declara o tema de
#   ícones `icones-dela`, o settings.json dela nesse tema e um pack sem ícones no
#   ar: o `aplicar` trocava o `icones-dela` pelo `vs-seti` de fábrica, como se o
#   MeowSystem o tivesse posto. É a régua que a revisão da P55 levou ao snippet
#   do Obsidian, e os ids vêm agora da mesma lista, o `meow_packs_validos` do
#   lib/comum.sh — uma cópia da conta aqui seria a segunda.
_VSC_TODOS_ICONES=""
_meow_vscode_icones_de_todos() {
  _VSC_TODOS_ICONES="$(MEOW_PACKS_VALIDOS="$(meow_packs_validos)" python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack

icones = []
for ident in os.environ.get("MEOW_PACKS_VALIDOS", "").split():
    try:
        _quem, valor = pack.tema_de_app("apps.vscode-icones.esquema", ref=ident)
    except Exception:
        continue
    if isinstance(valor, str) and valor and "," not in valor and valor not in icones:
        icones.append(valor)
print(",".join(icones))
PYFIM
)"
}

# 0 = o `workbench.iconTheme` de agora é um tema de ícones que algum pack declara,
# e não o de fábrica — um que o MeowSystem pôs.
_meow_vscode_icones_de_pack() {
  local atual
  _meow_vscode_icones_de_todos || return 1
  atual="$(_meow_vscode_json ler "$MEOW_VSCODE_SETTINGS" workbench.iconTheme 2>/dev/null \
           | python3 -c 'import json, sys; v = json.load(sys.stdin).get("workbench.iconTheme"); print(v if isinstance(v, str) else "")' 2>/dev/null)"
  [ -n "$atual" ] && [ "$atual" != "$_MEOW_VSCODE_ICONES_FABRICA" ] || return 1
  case ",$_VSC_TODOS_ICONES," in *",$atual,"*) return 0 ;; esac
  return 1
}

# As chaves que o `settings.json` tem de ter, em pares `chave valor`, no array
# `_VSC_PARES`. O tema sempre; os ícones, os do pack no ar — e, sem eles, o de
# fábrica no lugar do tema de ícones de outro pack (ver o topo).
_VSC_PARES=()
_meow_vscode_pares() {
  _VSC_PARES=(workbench.colorTheme "$MEOW_VSCODE_TEMA")
  if [ -n "$MEOW_VSCODE_ICONES" ]; then
    _VSC_PARES+=(workbench.iconTheme "$MEOW_VSCODE_ICONES")
  elif _meow_vscode_icones_de_pack; then
    _VSC_PARES+=(workbench.iconTheme "$_MEOW_VSCODE_ICONES_FABRICA")
  fi
}

# As duas frases que dizem o que está no lugar. Com o Catppuccin no ar, as de
# sempre: "Catppuccin Mocha + catppuccin-mocha" e "colorTheme=…, iconTheme=…".
_meow_vscode_rotulo() {
  if [ -n "$MEOW_VSCODE_ICONES" ]; then printf '%s + %s' "$MEOW_VSCODE_TEMA" "$MEOW_VSCODE_ICONES"
  else printf '%s' "$MEOW_VSCODE_TEMA"; fi
}
_meow_vscode_pares_texto() {
  local i texto=""
  for ((i = 0; i < ${#_VSC_PARES[@]}; i += 2)); do
    texto+="${texto:+, }${_VSC_PARES[i]#workbench.}=${_VSC_PARES[i + 1]}"
  done
  printf '%s' "$texto"
}

# A descida do pacote pinado da extensão do tema, para um temporário. Só o
# `aplicar` chama, e só quando a extensão falta.
# 0 = conferido, em `_VSC_VSIX_ARQ` (quem chama apaga a pasta dele) · 2 = o
# sha256 não bate · 3 = sem rede ou sem ferramenta (com o motivo guardado)
_VSC_VSIX_ARQ=""
_meow_vscode_baixar_vsix() {
  local tmp obtido f
  _VSC_VSIX_ARQ=""
  for f in curl sha256sum; do
    meow_tem "$f" || { meow_app_sem "VS Code: falta '$f' para baixar a extensão $MEOW_VSCODE_EXT_TEMA do pack $_MEOW_VSCODE_PACK_NOME"; return; }
  done
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" .meow-vscode-vsix.XXXXXX)" || return "$MEOW_ERRO"
  meow_info "baixando o pacote pinado de $MEOW_VSCODE_EXT_TEMA…"
  # `--proto =https` nos dois sentidos, como no `construir_icones.sh`.
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 300 --retry 3 --retry-delay 2 -o "$tmp/extensao.vsix" "$_MEOW_VSCODE_VSIX" 2>/dev/null; then
    rm -rf "$tmp"
    meow_app_sem "VS Code: não consegui baixar a extensão $MEOW_VSCODE_EXT_TEMA do pack $_MEOW_VSCODE_PACK_NOME (sem rede?) — fica para o próximo ciclo"
    return
  fi
  if ! echo "$_MEOW_VSCODE_VSIX_SHA  $tmp/extensao.vsix" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$tmp/extensao.vsix" | cut -d' ' -f1)"
    rm -rf "$tmp"
    meow_erro "VS Code: o sha256 da extensão $MEOW_VSCODE_EXT_TEMA não bate com o que o pack $_MEOW_VSCODE_PACK_NOME pinou — nada instalado"
    meow_info "  esperado $_MEOW_VSCODE_VSIX_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  _VSC_VSIX_ARQ="$tmp/extensao.vsix"
  return "$MEOW_OK"
}

# A PENDÊNCIA DA EXTENSÃO DE PACK IMPORTADO — decisão 9 (10/10/2026, P79). O id
# é o que o `app/servidor.py` casa com os botões (um por extensão que o pack no
# ar pede, «Instalar <id>»), e o comando é o que um terminal responde.
_VSC_PENDENCIA_GESTO="vscode-extensao-de-terceiro"
_meow_vscode_espera_gesto() {   # <extensão>...
  local lista
  lista="$(printf '%s, ' "$@")"; lista="${lista%, }"
  meow_pendencia_acionavel "$_VSC_PENDENCIA_GESTO" \
    "O pack importado $_MEOW_VSCODE_PACK_NOME pede a extensão $lista do VS Code: extensão é código, e de pack importado ela só entra pelo seu gesto" \
    "MEOW_VSCODE_EXTENSAO=$1 meow apps aplicar vscode"
  meow_app_sem "VS Code: a extensão $lista, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
  meow_app_pendente vscode
}

# =============================================================================
# CONTRATO — as três funções que o runner chama
# =============================================================================

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { meow_tem "$MEOW_VSCODE_BIN"; }

# 0 = dá para trabalhar · 3 = falta dependência. Nunca falha.
#
# O `python3` ENTRA AQUI, e não é preciosismo: TODA leitura e TODA escrita deste
# módulo passam pelo varredor de JSONC. Sem ele o módulo entrava em divergência
# ETERNA — medido: `conferir` devolvia 1 (não conseguia ler a chave) e `aplicar`
# devolvia 0 ("nada a fazer"), de hora em hora, para sempre. 3 é o código que faz
# o auto-reparo ficar quieto quando não há nada a consertar do nosso lado.
#
# E CADA SAÍDA-3 DECLARA A CAUSA [21/09/2026]
#   As duas linhas abaixo devolviam só o número, e quem recebia o número tinha
#   de ADIVINHAR qual das duas foi — o `aplicar` chegou a repetir o `meow_tem`
#   num if/else para chutar menos. Agora a causa viaja junto, pelo
#   `meow_app_sem` do lib/comum.sh, e ninguém mede duas vezes.
meow_app_detectar() {
  # Motivo velho mente com cara de medida: zerar antes de medir é do contrato.
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "VS Code: '$MEOW_VSCODE_BIN' não está no PATH"; return; }
  meow_tem python3 || { meow_app_sem "VS Code: falta python3, que é o varredor de JSONC deste módulo"; return; }
  # O DESFAZER NÃO DEPENDE DO PACK (P55; ver o DESFAZER lá embaixo), e pede só
  # o que vem até aqui. O resto é o que o pack no ar declara.
  [ "${1:-}" = "sem-pack" ] && return "$MEOW_OK"
  _meow_vscode_do_pack || return
  return "$MEOW_OK"
}

# 0 = já aplicado · 1 = divergente · 3 = app ausente.
meow_app_conferir() {
  meow_app_detectar sem-pack || return "$MEOW_SEM_DEPENDENCIA"
  # O motivo do pack é DITO, e o do programa ausente continua mudo como era: o
  # «sem tema neste pack» é o que o `meow apps conferir` tem de mostrar (P55).
  _meow_vscode_do_pack || { meow_app_pendente vscode; return; }

  local divergente=0 ext saida rc linha espera=0
  for ext in "$MEOW_VSCODE_EXT_TEMA" ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if ! _meow_vscode_tem_ext "$ext"; then
      # A EXTENSÃO DE PACK IMPORTADO NÃO É DIVERGÊNCIA — conferência da P79
      #   (decisão 9). Ela só entra pelo gesto de quem usa, e o `aplicar` não a
      #   instala sozinho: chamá-la de divergência fazia o doctor prometer um
      #   conserto que o `--consertar` não faz, todo dia. É pendência, como o
      #   «Manter o meu» do tema de terceiro (`meow_app_tema_no_ar`), e o
      #   settings.json fica como está até lá (ver o `aplicar`).
      if [ "$_VSC_DO_REPO" != "1" ]; then
        meow_pula "a extensão $ext, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
        espera=1
      else
        meow_info "extensão ausente: $ext"
        divergente=1
      fi
    fi
  done
  [ "$espera" = "1" ] && [ "$divergente" = "0" ] && return "$MEOW_SEM_DEPENDENCIA"
  # A extensão do tema no disco, numa versão que não traz o tema, não está no
  # lugar (25/09/2026; ver o `_meow_vscode_sem_o_tema`).
  if _meow_vscode_sem_o_tema; then
    meow_info "extensão sem o tema: $_VSC_SEM_O_TEMA"
    divergente=1
  fi

  _meow_vscode_pares
  saida="$(_meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" 2>&1)"; rc=$?
  case "$rc" in
    0) : ;;
    # linha a linha: um `meow_info` com texto de duas linhas deixaria a segunda
    # sem o prefixo, e o relatório do runner fica torto.
    1) while IFS= read -r linha; do
         if [ -n "$linha" ]; then meow_info "$linha"; fi
       done <<< "$saida"
       divergente=1 ;;
    # erro de leitura entra como divergência (o contrato de `conferir` só tem
    # 0/1/3); quem grita de verdade é o `aplicar`, que devolve 2.
    *) meow_aviso "não consegui ler $MEOW_VSCODE_SETTINGS: $saida"; divergente=1 ;;
  esac

  if [ "$divergente" = "0" ]; then
    meow_ok "VS Code: $(_meow_vscode_rotulo) já no lugar"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# 0 = nada a fazer · 1 = aplicou · 2 = erro · 3 = app ausente.
meow_app_aplicar() {
  # O if/else que MEDIA DE NOVO para adivinhar a causa saiu em 21/09/2026: com
  # duas dependências ele acertava, com a terceira teria virado o chute do
  # módulo do Spotify. Quem mediu foi o `detectar`, e é a palavra dele que sai.
  meow_app_detectar || { meow_pendencia_resolvida "$_VSC_PENDENCIA_GESTO"; meow_app_pendente vscode; return; }

  # NOMES DE RETORNO SEPARADOS, E ISSO CUSTOU UM TESTE
  #   A primeira versão reaproveitava um único `rc` para a divergência do
  #   settings.json e para o resultado de cada `--install-extension`. Rodando de
  #   verdade, as duas extensões instalaram, o `rc` do laço voltou 0 e o bloco
  #   do settings.json foi PULADO inteiro: o tema continuou Dracula e o módulo
  #   ainda assim disse "ok". Cada coisa tem sua variável agora.
  local ext faltando=() mudou=0 saida novo antigo aud linha erro_json alvo
  local rc_set rc_ext rc_json rc_esc

  for ext in "$MEOW_VSCODE_EXT_TEMA" ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if ! _meow_vscode_tem_ext "$ext"; then faltando+=("$ext"); fi
  done
  # A extensão do tema no disco numa versão sem o tema do pack (25/09/2026; ver o
  # `_meow_vscode_sem_o_tema`): com pino, o pacote pinado entra por cima dela,
  # pelo caminho da que falta; sem, é pendência, e nada é escrito.
  if _meow_vscode_sem_o_tema; then
    if [ -z "$_MEOW_VSCODE_VSIX" ]; then
      meow_app_sem "VS Code: $_VSC_SEM_O_TEMA — atualize a extensão pelo editor; o pack $_MEOW_VSCODE_PACK_NOME não pina um pacote dela"
      meow_app_pendente vscode; return
    fi
    faltando+=("$MEOW_VSCODE_EXT_TEMA")
  fi

  # A EXTENSÃO DE PACK IMPORTADO ESPERA O GESTO — decisão 9 (10/10/2026, P79)
  #   Extensão é código que roda com a conta de quem usa a cada abertura do
  #   editor, e o sha256 que o pack pina prova integridade, não confiança. Só o
  #   pack do `packs/` deste repositório instala sozinho; o importado instala só
  #   a extensão que o gesto nomeou (`MEOW_VSCODE_EXTENSAO`, que o botão da
  #   pendência manda), e o resto fica dito na pendência, sem settings.json
  #   novo: um tema apontado para uma extensão que não está lá é o editor no
  #   padrão com o nome de outro na configuração.
  local espera=() gesto="" e_min
  if [ "${#faltando[@]}" -gt 0 ] && [ "$_VSC_DO_REPO" != "1" ]; then
    gesto="$(printf '%s' "${MEOW_VSCODE_EXTENSAO:-}" | tr '[:upper:]' '[:lower:]')"
    local vale=()
    for ext in "${faltando[@]}"; do
      e_min="$(printf '%s' "$ext" | tr '[:upper:]' '[:lower:]')"
      if [ -n "$gesto" ] && [ "$e_min" = "$gesto" ]; then vale+=("$ext"); else espera+=("$ext"); fi
    done
    faltando=(${vale[@]+"${vale[@]}"})
  fi
  if [ "${#espera[@]}" = "0" ]; then meow_pendencia_resolvida "$_VSC_PENDENCIA_GESTO"; fi

  _meow_vscode_pares
  _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" >/dev/null 2>&1; rc_set=$?

  if [ "${#faltando[@]}" = "0" ] && [ "${#espera[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code: $(_meow_vscode_rotulo) já no lugar"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    for ext in ${faltando[@]+"${faltando[@]}"}; do
      if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ]; then
        meow_muda "instalaria a extensão $ext, do pacote pinado ($_MEOW_VSCODE_VSIX)"
      else
        meow_muda "instalaria a extensão $ext"
      fi
    done
    for ext in ${espera[@]+"${espera[@]}"}; do
      meow_pula "a extensão $ext, do pack importado $_MEOW_VSCODE_PACK_NOME, espera o seu gesto"
    done
    if [ "$rc_set" != "0" ] && [ "${#espera[@]}" = "0" ]; then
      meow_muda "mudaria $MEOW_VSCODE_SETTINGS: $(_meow_vscode_pares_texto)"
    fi
    return "$MEOW_DIVERGENTE"
  fi

  # --- 1. extensões ---------------------------------------------------------
  # Sem `--force`: o CLI já é idempotente e resolve sozinho a última versão
  # COMPATÍVEL com o `code` instalado — que é o que a faxina da Aurora exige.
  # `timeout` porque sem rede o CLI fica pendurado esperando a Marketplace.
  # A extensão que o pack PINA (P55) desce antes, conferida pelo sha256, e o CLI
  # a instala do arquivo; o temporário sai logo depois, deu certo ou não.
  for ext in ${faltando[@]+"${faltando[@]}"}; do
    meow_info "instalando extensão $ext…"
    alvo="$ext"
    if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ]; then
      _meow_vscode_baixar_vsix
      case $? in
        0) alvo="$_VSC_VSIX_ARQ" ;;
        3) meow_app_pendente vscode; return ;;
        *) return "$MEOW_ERRO" ;;
      esac
    fi
    if meow_tem timeout; then
      saida="$(timeout 300 "$MEOW_VSCODE_BIN" --install-extension "$alvo" 2>&1)"; rc_ext=$?
    else
      saida="$("$MEOW_VSCODE_BIN" --install-extension "$alvo" 2>&1)"; rc_ext=$?
    fi
    if [ -n "$_VSC_VSIX_ARQ" ]; then rm -rf -- "$(dirname -- "$_VSC_VSIX_ARQ")"; _VSC_VSIX_ARQ=""; fi
    if [ "$rc_ext" != "0" ]; then
      meow_erro "falhou ao instalar $ext (rc=$rc_ext): $(printf '%s' "$saida" | tail -3)"
      return "$MEOW_ERRO"
    fi
    _MEOW_VSCODE_LISTA=""   # o cache do CLI acabou de ficar velho
    if ! _meow_vscode_tem_ext "$ext"; then
      meow_erro "o CLI disse que instalou $ext, mas não achei a pasta em $MEOW_VSCODE_EXTDIR"
      return "$MEOW_ERRO"
    fi
    # O pacote pinado entrou e a versão no disco ainda não traz o tema: ou o
    # pino não é do tema que o pack declara, ou o CLI deixou uma mais nova no
    # lugar. Seguir seria baixar de novo a cada hora (25/09/2026).
    if [ "$ext" = "$MEOW_VSCODE_EXT_TEMA" ] && [ -n "$_MEOW_VSCODE_VSIX" ] && _meow_vscode_sem_o_tema; then
      meow_erro "VS Code: o pacote que o pack $_MEOW_VSCODE_PACK_NOME pina para $ext entrou, e $_VSC_SEM_O_TEMA — o settings.json não foi mudado"
      return "$MEOW_ERRO"
    fi
    meow_muda "extensão $ext instalada"
    mudou=1
  done

  # A extensão que espera o gesto deixa o settings.json como está (ver acima).
  if [ "${#espera[@]}" -gt 0 ]; then
    _meow_vscode_espera_gesto "${espera[@]}"
    return
  fi

  # --- 2. settings.json (MERGE, nunca reescrita) ----------------------------
  if [ "$rc_set" != "0" ] || [ ! -f "$MEOW_VSCODE_SETTINGS" ]; then
    # O `X` do fim vem do PYTHON, não de um `printf X` daqui: com o `printf` o
    # `$?` era o dele (sempre 0) e um `fundir` que recusasse o serviço gravava
    # string VAZIA por cima da config dela. Ver o cabeçalho — isso zerou o
    # settings.json num teste. O stderr vai para um temporário só para a
    # mensagem sair com o prefixo do runner em vez de solta na tela.
    erro_json="$(mktemp -t meow-vscode-erro.XXXXXX)" || {
      meow_erro "não consegui criar arquivo temporário — nada foi gravado"
      return "$MEOW_ERRO"
    }
    novo="$(_meow_vscode_json fundir "$MEOW_VSCODE_SETTINGS" "${_VSC_PARES[@]}" 2>"$erro_json")"; rc_json=$?
    saida="$(cat -- "$erro_json" 2>/dev/null)"
    rm -f -- "$erro_json"

    # Duas travas, não uma: o código de saída E o sentinela. Saída truncada
    # (disco cheio, OOM no meio do write) sai com rc 0 e sem o `X`.
    if [ "$rc_json" != "0" ] || [ "${novo: -1}" != "X" ]; then
      meow_erro "não consegui fundir $MEOW_VSCODE_SETTINGS (rc=$rc_json) — nada foi gravado${saida:+: $saida}"
      return "$MEOW_ERRO"
    fi
    novo="${novo%X}"

    antigo=""
    if [ -f "$MEOW_VSCODE_SETTINGS" ]; then
      antigo="$(cat -- "$MEOW_VSCODE_SETTINGS"; printf X)"; antigo="${antigo%X}"
    fi
    if [ "$novo" != "$antigo" ]; then
      # A guarda é a EXISTÊNCIA do arquivo, não `-n "$antigo"`: se o `cat` acima
      # falhasse (permissão, arquivo trocado no meio), `antigo` sairia vazio e o
      # backup do arquivo dela seria PULADO justamente na hora de sobrescrevê-lo.
      if [ -f "$MEOW_VSCODE_SETTINGS" ] && ! _meow_vscode_backup "$MEOW_VSCODE_SETTINGS"; then
        meow_erro "não consegui fazer backup de $MEOW_VSCODE_SETTINGS — não vou gravar"
        return "$MEOW_ERRO"
      fi
      meow_escrever "$MEOW_VSCODE_SETTINGS" "$novo" 644; rc_esc=$?
      if [ "$rc_esc" = "2" ]; then
        meow_erro "falhou ao gravar $MEOW_VSCODE_SETTINGS"
        return "$MEOW_ERRO"
      fi
      meow_muda "settings.json: $(_meow_vscode_pares_texto)"
      mudou=1
    fi
  fi

  # --- 3. auditoria (só avisa) ---------------------------------------------
  aud="$(_meow_vscode_auditar_ext 2>/dev/null || true)"
  if [ -n "$aud" ]; then
    while IFS= read -r linha; do
      if [ -n "$linha" ]; then meow_aviso "$linha"; fi
    done <<< "$aud"
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "VS Code: nada a fazer"
    return "$MEOW_OK"
  fi

  # O VS Code VIGIA o settings.json e repinta ao vivo — não precisa reiniciar.
  # Se ele estiver fechado, pega na próxima abertura. Nos dois casos, nada de
  # matar processo aqui: o editor aberto dela pode ter arquivo não salvo.
  meow_registrar "vscode: $(_meow_vscode_rotulo)"
  if [ -n "$MEOW_VSCODE_ICONES" ]; then
    meow_ok "VS Code em $MEOW_VSCODE_TEMA (ícones $MEOW_VSCODE_ICONES)"
  else
    meow_ok "VS Code em $MEOW_VSCODE_TEMA (o pack $_MEOW_VSCODE_PACK_NOME não traz tema de ícones)"
  fi
  return "$MEOW_DIVERGENTE"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter vscode` e o passo 2/6 do `--uninstall`.
#
# ELE REPÕE O PADRÃO DE FÁBRICA, NÃO "O QUE ELA TINHA" — E ISSO É DELIBERADO
#   Ninguém guardou qual era o tema dela antes (o módulo nunca precisou saber).
#   Havia duas saídas ruins e uma honesta:
#     · RESTAURAR o settings.json inteiro do backup mais antigo — apagaria meses
#       de escolhas dela no editor para desfazer duas linhas. Recusado.
#     · REMOVER as duas chaves — exigiria um removedor de JSONC novo, com o
#       maquinário de vírgulas e comentários todo de novo, para um caminho que
#       roda uma vez na vida. É onde um settings.json quebra calado.
#     · ESCREVER o padrão do VS Code nas duas chaves, pelo MESMO varredor que já
#       aplica. É o que está aqui: reusa código provado e o resultado é
#       verificável na tela — o editor volta ao visual de fábrica.
#   Se ela usava Dracula antes, é ela quem reescolhe. A mensagem diz isso.
#
# AS EXTENSÕES SAEM, PORQUE FOMOS NÓS QUE AS PUSEMOS
#   O `aplicar` roda `--install-extension`; o par exato é `--uninstall-extension`.
#   Deixá-las seria dizer "desfeito" com o Catppuccin ainda na lista dela.
#   [P55, 24/09/2026: saem as que o PACK NO AR declara — as que o `aplicar` põe
#   com ele —, e só elas. Estar instalada não diz de quem é a extensão: o
#   `configurar-vscode.sh` do cabeçalho instala a `dracula-theme.theme-dracula`
#   por conta própria, e um desfazer que levasse a extensão de TODO pack do disco
#   tiraria, com o Catppuccin no ar, uma que ela pôs — e a sprint pediu o
#   Catppuccin igual ao de antes. O preço, dito: quem trocou de pack fica com as
#   extensões do de antes instaladas e desligadas; as duas chaves do
#   settings.json voltam ao de fábrica do mesmo jeito. Pack sem tema de VS Code
#   não tira extensão nenhuma.]
#
# O `fundir`, E NÃO O `aplicar` QUE ESTAVA AQUI — 24/09/2026, P55
#   Esta função chamava o varredor no modo `aplicar`, que ele não tem: saía 2
#   com "modo desconhecido", e o desfazer morria em "não consegui montar o
#   settings.json de volta" toda vez que havia tema a tirar. Medido numa casa de
#   brinquedo com o Catppuccin aplicado: rc=2 nas duas passadas, e o tema
#   ficava. O modo que monta é o `fundir`, com o sentinela `X` que ele mesmo
#   emite (ver o cabeçalho). E o settings.json que não existe continua não
#   existindo: não há tema nele para tirar.
_MEOW_VSCODE_TEMA_FABRICA="${MEOW_VSCODE_TEMA_FABRICA:-Default Dark Modern}"
_MEOW_VSCODE_ICONES_FABRICA="${MEOW_VSCODE_ICONES_FABRICA:-vs-seti}"

meow_app_reverter() {
  # A lista de causas possíveis que estava aqui virou a causa medida.
  meow_app_detectar sem-pack || { meow_app_pendente vscode; return; }
  # O pack no ar dá as extensões que saem (ver acima) e o nome da frase. A saída
  # 3 dele aqui não é pendência: sem tema neste pack, as duas listas ficam
  # vazias e o settings.json volta ao de fábrica assim mesmo.
  _meow_vscode_do_pack || true
  [ -n "$_MEOW_VSCODE_PACK_NOME" ] || _MEOW_VSCODE_PACK_NOME="tema do MeowSystem"

  local ext instaladas=() mudou=0 rc_set=0 novo
  for ext in ${MEOW_VSCODE_EXT_TEMA:+"$MEOW_VSCODE_EXT_TEMA"} ${MEOW_VSCODE_EXT_ICONES:+"$MEOW_VSCODE_EXT_ICONES"}; do
    if _meow_vscode_tem_ext "$ext"; then instaladas+=("$ext"); fi
  done

  if [ -f "$MEOW_VSCODE_SETTINGS" ]; then
    _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" \
        workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
        workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" >/dev/null 2>&1; rc_set=$?
  fi

  if [ "${#instaladas[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code já estava sem o $_MEOW_VSCODE_PACK_NOME"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    for ext in ${instaladas[@]+"${instaladas[@]}"}; do
      meow_muda "desinstalaria a extensão $ext"
    done
    [ "$rc_set" != "0" ] && \
      meow_muda "mudaria $MEOW_VSCODE_SETTINGS: colorTheme=$_MEOW_VSCODE_TEMA_FABRICA, iconTheme=$_MEOW_VSCODE_ICONES_FABRICA"
    return "$MEOW_DIVERGENTE"
  fi

  # --- 1. o settings.json. Escrita DIRETA, não `meow_escrever`: aquela registra
  # no manifesto, e o desinstalador apagaria em seguida o arquivo que acabamos de
  # devolver — ela perderia o settings.json inteiro.
  if [ "$rc_set" != "0" ]; then
    if novo="$(_meow_vscode_json fundir "$MEOW_VSCODE_SETTINGS" \
                 workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
                 workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" 2>/dev/null)" \
       && [ "${novo: -1}" = "X" ]; then
      novo="${novo%X}"
      _meow_vscode_backup "$MEOW_VSCODE_SETTINGS" || {
        meow_erro "vscode: backup do settings.json falhou — não escrevi"
        return "$MEOW_ERRO"
      }
      if printf '%s' "$novo" > "$MEOW_VSCODE_SETTINGS" 2>/dev/null; then
        mudou=1
        meow_muda "vscode: colorTheme=$_MEOW_VSCODE_TEMA_FABRICA, iconTheme=$_MEOW_VSCODE_ICONES_FABRICA"
      else
        meow_erro "vscode: não consegui escrever $MEOW_VSCODE_SETTINGS"
        return "$MEOW_ERRO"
      fi
    else
      meow_erro "vscode: não consegui montar o settings.json de volta"
      return "$MEOW_ERRO"
    fi
  fi

  # --- 2. as extensões. Falha aqui não derruba o resto: o tema já saiu, e uma
  # extensão que ficou é visível na lista dela — nada quebra calado.
  for ext in ${instaladas[@]+"${instaladas[@]}"}; do
    if "$MEOW_VSCODE_BIN" --uninstall-extension "$ext" >/dev/null 2>&1; then
      mudou=1; meow_muda "extensão removida: $ext"
    else
      meow_aviso "não consegui remover $ext — tire pela interface do editor"
    fi
  done
  _MEOW_VSCODE_LISTA=""   # a lista em cache mentiria daqui para a frente

  [ "$mudou" = "0" ] && { meow_ok "VS Code já estava sem o $_MEOW_VSCODE_PACK_NOME"; return "$MEOW_OK"; }
  meow_ok "VS Code de volta ao tema de fábrica — reescolha o seu em File > Preferences > Theme"
  meow_info "tire 'vscode' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
