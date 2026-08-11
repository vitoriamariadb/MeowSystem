#!/usr/bin/env bash
# app-themes/vscode/manifesto.sh — Catppuccin Mocha no Visual Studio Code.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`: quem chama é
# o runner, e um `exit` aqui derrubaria a sessão inteira dele no meio da fila.
#
# O QUE ELE FAZ, EM UMA FRASE
#   Garante duas extensões instaladas (`Catppuccin.catppuccin-vsc` e
#   `Catppuccin.catppuccin-vsc-icons`) e duas chaves no `settings.json` dela
#   (`workbench.colorTheme` e `workbench.iconTheme`) — sem tocar em mais nada.
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
# ─────────────────────────────────────────────────────────────────────────────

MEOW_VSCODE_BIN="${MEOW_VSCODE_BIN:-code}"
MEOW_VSCODE_SETTINGS="${MEOW_VSCODE_SETTINGS:-$HOME/.config/Code/User/settings.json}"
MEOW_VSCODE_EXTDIR="${MEOW_VSCODE_EXTDIR:-$HOME/.vscode/extensions}"
MEOW_VSCODE_TEMA="${MEOW_VSCODE_TEMA:-Catppuccin Mocha}"
MEOW_VSCODE_ICONES="${MEOW_VSCODE_ICONES:-catppuccin-mocha}"

# id da extensão -> o que ela precisa contribuir para o tema funcionar.
MEOW_VSCODE_EXT_TEMA="Catppuccin.catppuccin-vsc"
MEOW_VSCODE_EXT_ICONES="Catppuccin.catppuccin-vsc-icons"

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
  python3 - "$@" <<'PYFIM'
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
_meow_vscode_pkg() {
  local id_min achado
  id_min="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
  [ -d "$MEOW_VSCODE_EXTDIR" ] || return 1
  achado="$(find "$MEOW_VSCODE_EXTDIR" -mindepth 2 -maxdepth 2 -name package.json \
              -path "$MEOW_VSCODE_EXTDIR/$id_min-[0-9]*/package.json" \
              -print -quit 2>/dev/null)"
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

# Confere se a versão instalada realmente contribui o tema/ícone que pedimos, e
# se o engine dela sobrevive à faxina da Aurora. Só avisa — nunca falha o passo.
_meow_vscode_auditar_ext() {
  local pkg menor
  # `code --version` cria o perfil igual ao `--list-extensions`. Sem perfil não
  # há extensão para auditar, então a auditoria não tem o que fazer aqui — e
  # perguntar seria escrever num modo que prometeu não escrever.
  if [ ! -d "$MEOW_VSCODE_EXTDIR" ]; then return 0; fi
  menor="$("$MEOW_VSCODE_BIN" --version 2>/dev/null | head -1 | cut -d. -f2)"
  for pkg in "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_TEMA" 2>/dev/null || true)" \
             "$(_meow_vscode_pkg "$MEOW_VSCODE_EXT_ICONES" 2>/dev/null || true)"; do
    if [ -z "$pkg" ] || [ ! -f "$pkg" ]; then continue; fi
    python3 - "$pkg" "${menor:-0}" "$MEOW_VSCODE_TEMA" "$MEOW_VSCODE_ICONES" <<'PYFIM'
import json, sys
pkg, minor, tema, icone = sys.argv[1], int(sys.argv[2] or 0), sys.argv[3], sys.argv[4]
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
temas = [t.get("label") or t.get("id") for t in (d.get("contributes") or {}).get("themes", [])]
icones = [t.get("id") for t in (d.get("contributes") or {}).get("iconThemes", [])]
if temas and tema not in temas:
    print("aviso: %s não contribui o tema %r (tem: %s)" % (nome, tema, ", ".join(map(str, temas))))
if icones and icone not in icones:
    print("aviso: %s não contribui o ícone %r (tem: %s)" % (nome, icone, ", ".join(map(str, icones))))
PYFIM
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
# CONTRATO — as três funções que o runner chama
# =============================================================================

# 0 = dá para trabalhar · 3 = falta dependência. Nunca falha.
#
# O `python3` ENTRA AQUI, e não é preciosismo: TODA leitura e TODA escrita deste
# módulo passam pelo varredor de JSONC. Sem ele o módulo entrava em divergência
# ETERNA — medido: `conferir` devolvia 1 (não conseguia ler a chave) e `aplicar`
# devolvia 0 ("nada a fazer"), de hora em hora, para sempre. 3 é o código que faz
# o auto-reparo ficar quieto quando não há nada a consertar do nosso lado.
meow_app_detectar() {
  meow_tem "$MEOW_VSCODE_BIN" || return "$MEOW_SEM_DEPENDENCIA"
  meow_tem python3 || return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

# 0 = já aplicado · 1 = divergente · 3 = app ausente.
meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  local divergente=0 ext saida rc linha
  for ext in "$MEOW_VSCODE_EXT_TEMA" "$MEOW_VSCODE_EXT_ICONES"; do
    if ! _meow_vscode_tem_ext "$ext"; then
      meow_info "extensão ausente: $ext"
      divergente=1
    fi
  done

  saida="$(_meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" \
             workbench.colorTheme "$MEOW_VSCODE_TEMA" \
             workbench.iconTheme  "$MEOW_VSCODE_ICONES" 2>&1)"; rc=$?
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
    meow_ok "VS Code: $MEOW_VSCODE_TEMA + $MEOW_VSCODE_ICONES já no lugar"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# 0 = nada a fazer · 1 = aplicou · 2 = erro · 3 = app ausente.
meow_app_aplicar() {
  meow_app_detectar || {
    if meow_tem "$MEOW_VSCODE_BIN"; then
      meow_pula "falta python3 (o varredor de JSONC é ele) — pulando (não é erro)"
    else
      meow_pula "VS Code não instalado — pulando (não é erro)"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }

  # NOMES DE RETORNO SEPARADOS, E ISSO CUSTOU UM TESTE
  #   A primeira versão reaproveitava um único `rc` para a divergência do
  #   settings.json e para o resultado de cada `--install-extension`. Rodando de
  #   verdade, as duas extensões instalaram, o `rc` do laço voltou 0 e o bloco
  #   do settings.json foi PULADO inteiro: o tema continuou Dracula e o módulo
  #   ainda assim disse "ok". Cada coisa tem sua variável agora.
  local ext faltando=() mudou=0 saida novo antigo aud linha erro_json
  local rc_set rc_ext rc_json rc_esc

  for ext in "$MEOW_VSCODE_EXT_TEMA" "$MEOW_VSCODE_EXT_ICONES"; do
    if ! _meow_vscode_tem_ext "$ext"; then faltando+=("$ext"); fi
  done

  _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" \
      workbench.colorTheme "$MEOW_VSCODE_TEMA" \
      workbench.iconTheme  "$MEOW_VSCODE_ICONES" >/dev/null 2>&1; rc_set=$?

  if [ "${#faltando[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code: $MEOW_VSCODE_TEMA + $MEOW_VSCODE_ICONES já no lugar"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    for ext in ${faltando[@]+"${faltando[@]}"}; do
      meow_muda "instalaria a extensão $ext"
    done
    if [ "$rc_set" != "0" ]; then
      meow_muda "mudaria $MEOW_VSCODE_SETTINGS: colorTheme=$MEOW_VSCODE_TEMA, iconTheme=$MEOW_VSCODE_ICONES"
    fi
    return "$MEOW_DIVERGENTE"
  fi

  # --- 1. extensões ---------------------------------------------------------
  # Sem `--force`: o CLI já é idempotente e resolve sozinho a última versão
  # COMPATÍVEL com o `code` instalado — que é o que a faxina da Aurora exige.
  # `timeout` porque sem rede o CLI fica pendurado esperando a Marketplace.
  for ext in ${faltando[@]+"${faltando[@]}"}; do
    meow_info "instalando extensão $ext…"
    if meow_tem timeout; then
      saida="$(timeout 300 "$MEOW_VSCODE_BIN" --install-extension "$ext" 2>&1)"; rc_ext=$?
    else
      saida="$("$MEOW_VSCODE_BIN" --install-extension "$ext" 2>&1)"; rc_ext=$?
    fi
    if [ "$rc_ext" != "0" ]; then
      meow_erro "falhou ao instalar $ext (rc=$rc_ext): $(printf '%s' "$saida" | tail -3)"
      return "$MEOW_ERRO"
    fi
    _MEOW_VSCODE_LISTA=""   # o cache do CLI acabou de ficar velho
    if ! _meow_vscode_tem_ext "$ext"; then
      meow_erro "o CLI disse que instalou $ext, mas não achei a pasta em $MEOW_VSCODE_EXTDIR"
      return "$MEOW_ERRO"
    fi
    meow_muda "extensão $ext instalada"
    mudou=1
  done

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
    novo="$(_meow_vscode_json fundir "$MEOW_VSCODE_SETTINGS" \
              workbench.colorTheme "$MEOW_VSCODE_TEMA" \
              workbench.iconTheme  "$MEOW_VSCODE_ICONES" 2>"$erro_json")"; rc_json=$?
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
      meow_muda "settings.json: colorTheme=$MEOW_VSCODE_TEMA, iconTheme=$MEOW_VSCODE_ICONES"
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
  meow_registrar "vscode: $MEOW_VSCODE_TEMA + $MEOW_VSCODE_ICONES"
  meow_ok "VS Code em $MEOW_VSCODE_TEMA (ícones $MEOW_VSCODE_ICONES)"
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
_MEOW_VSCODE_TEMA_FABRICA="${MEOW_VSCODE_TEMA_FABRICA:-Default Dark Modern}"
_MEOW_VSCODE_ICONES_FABRICA="${MEOW_VSCODE_ICONES_FABRICA:-vs-seti}"

meow_app_reverter() {
  meow_app_detectar || {
    meow_pula "VS Code não instalado (ou falta python3)"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local ext instaladas=() mudou=0 rc_set novo
  for ext in "$MEOW_VSCODE_EXT_TEMA" "$MEOW_VSCODE_EXT_ICONES"; do
    if _meow_vscode_tem_ext "$ext"; then instaladas+=("$ext"); fi
  done

  _meow_vscode_json conferir "$MEOW_VSCODE_SETTINGS" \
      workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
      workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" >/dev/null 2>&1; rc_set=$?

  if [ "${#instaladas[@]}" = "0" ] && [ "$rc_set" = "0" ]; then
    meow_ok "VS Code já estava sem o Catppuccin"
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
    if novo="$(_meow_vscode_json aplicar "$MEOW_VSCODE_SETTINGS" \
                 workbench.colorTheme "$_MEOW_VSCODE_TEMA_FABRICA" \
                 workbench.iconTheme  "$_MEOW_VSCODE_ICONES_FABRICA" 2>/dev/null)" \
       && [ -n "$novo" ]; then
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

  [ "$mudou" = "0" ] && { meow_ok "VS Code já estava sem o Catppuccin"; return "$MEOW_OK"; }
  meow_ok "VS Code de volta ao tema de fábrica — reescolha o seu em File > Preferences > Theme"
  meow_info "tire 'vscode' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
