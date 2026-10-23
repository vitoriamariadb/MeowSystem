#!/usr/bin/env bash
# jogos_heroic.sh — um .desktop por jogo INSTALADO no Heroic, no lançador dela.
#
#   ./jogos_heroic.sh              escreve, limpa e converge
#   ./jogos_heroic.sh --conferir   não escreve nem apaga; 1 se algo divergir
#   ./jogos_heroic.sh --listar     os jogos instalados, um por linha: id, título,
#                                  arte e se está no lançador (sim|nao); só lê
#
# Ligar as duas chaves DELE seria o contorno óbvio e é o errado: o Heroic só
# escreve o atalho no momento da instalação (`addShortcuts` é chamado no fim do
# download), então os jogos JÁ instalados continuariam de fora, e o arquivo
# ficaria sem dono conhecido — sem a nossa marca, sem escada de ícone e sem
# limpeza quando o jogo sair.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"
# O encurtamento do rótulo: as chaves do `assets/icones/apps-nomes.map` para os
# jogos daqui são `heroic-<runner>-<app_name>`, o mesmo id do arquivo sem o
# prefixo `meow-`.
. "$RAIZ/scripts/nomes_apps.sh"

APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"
ICONE_PADRAO="com.heroicgameslauncher.hgl"

# --- o mesmo verbo dos outros módulos, e a mesma armadilha do seco ------------
# `MEOW_SECO` é congelado no `source` do comum.sh: o `--conferir` o liga aqui, direto,
# ou apagaria arquivo dizendo que era conferência.
LISTAR=0
case "${1:-}" in
  --conferir) MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  --listar) LISTAR=1; MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--listar]"; exit "$MEOW_ERRO" ;;
esac

# Os jogos que ela tirou do lançador pelo interruptor do painel: um id por linha.
HEROIC_FORA="${MEOW_HEROIC_FORA:-$HOME/.config/meow/jogos-heroic-fora.list}"
heroic_fora() { [ -f "$HEROIC_FORA" ] && grep -qxF -- "$1" "$HEROIC_FORA"; }

# O interruptor do painel: tira ou devolve um id na lista, antes da passada.
_heroic_lista_trocar() {
  local tirar="${MEOW_HEROIC_TIRAR:-}" por="${MEOW_HEROIC_POR:-}" atual novo
  [ -n "$tirar$por" ] || return 0
  atual="$(cat "$HEROIC_FORA" 2>/dev/null)"
  novo="$(printf '%s\n' "$atual" | grep -vxF -e "${por:-\x00}" -e "${tirar:-\x00}" | sed '/^$/d')"
  [ -n "$tirar" ] && novo="$(printf '%s\n%s' "$novo" "$tirar" | sed '/^$/d')"
  meow_escrever "$HEROIC_FORA" "$novo" 644
  [ $? -le 1 ] || { meow_erro "não consegui gravar $HEROIC_FORA"; exit "$MEOW_ERRO"; }
}

meow_tem python3 || {
  meow_pula "sem python3 — não dá para ler a biblioteca do Heroic (é JSON)"
  exit "$MEOW_SEM_DEPENDENCIA"
}

# --- ONDE O HEROIC GUARDA A CONFIGURAÇÃO -------------------------------------
# Flatpak primeiro porque é o desta máquina (`flatpak list` -> Heroic v2.22.1,
# instalação `user`).
heroic_conf() {
  local c
  for c in "${HEROIC_CONF:-}" \
           "$HOME/.var/app/com.heroicgameslauncher.hgl/config/heroic" \
           "${XDG_CONFIG_HOME:-$HOME/.config}/heroic"; do
    [ -n "$c" ] && [ -d "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

CONF="$(heroic_conf)" || {
  meow_pula "Heroic não instalado (ou nunca aberto) — nada a fazer"
  exit "$MEOW_OK"
}

# --- O MOTOR: a biblioteca do Heroic, em linhas ------------------------------
# Devolve uma linha por jogo instalado, com TAB entre os campos:
#
#     <runner> <app_name> <título> <caminho da arte, ou vazio>
#
# É Python porque a entrada é JSON aninhado — e a mesma razão do `_areas_motor`
# do `areas.sh`: montar isto com `grep` e `sed` é escrever um leitor de JSON
# errado.
_heroic_motor() {
  python3 -I - "$CONF" <<'PY'
import hashlib
import json
import os
import sys

conf = sys.argv[1]


def carrega(*partes):
    caminho = os.path.join(conf, *partes)
    try:
        with open(caminho, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return None


# A LISTA DE JOGOS DENTRO DO CACHE MUDA DE NOME CONFORME O RUNNER
#   `legendary_library.json` guarda em `library`, `gog_library.json` em `games`,
#   e o `nile_library.json` desta máquina é um `{}` seco. Cravar a chave certa
#   para cada um é combinar com uma versão do Heroic; procurar a primeira lista
#   de objetos que tenha `app_name` responde a mesma pergunta e sobrevive à
#   próxima renomeação.
def lista_de_jogos(dado):
    if isinstance(dado, list):
        candidatos = [dado]
    elif isinstance(dado, dict):
        candidatos = [v for v in dado.values() if isinstance(v, list)]
    else:
        return []
    for c in candidatos:
        if any(isinstance(g, dict) and g.get("app_name") for g in c):
            return [g for g in c if isinstance(g, dict)]
    return []


# O QUE O BACKEND DIZ QUE ESTÁ NO DISCO
#   Três formatos, um por runner, todos medidos em 10/09/2026:
#     legendary -> {"<app_name>": {...}}          (dicionário)
#     gog       -> {"installed": [{"appName": ...}]}
#     nile      -> [{"id": ...}]
#   `None` (e não conjunto vazio) quando o arquivo não existe ou não abre: é o
#   que faz o cache valer sozinho, em vez de esvaziar o lançador por causa de um
#   arquivo que mudou de forma.
def ids_instalados(dado):
    if dado is None:
        return None
    if isinstance(dado, dict):
        if "installed" in dado and isinstance(dado["installed"], list):
            itens = dado["installed"]
        else:
            return {str(k) for k in dado}
    elif isinstance(dado, list):
        itens = dado
    else:
        return None
    ids = set()
    for it in itens:
        if not isinstance(it, dict):
            continue
        for chave in ("appName", "app_name", "id", "install_path"):
            if it.get(chave):
                ids.add(str(it[chave]))
                break
    return ids


RUNNERS = (
    ("legendary", "legendary_library.json", ("legendaryConfig", "legendary", "installed.json")),
    ("gog", "gog_library.json", ("gog_store", "installed.json")),
    ("nile", "nile_library.json", ("nile_config", "nile", "installed.json")),
)

jogos = []
achou_biblioteca = False

for runner, cache, instalado in RUNNERS:
    dado = carrega("store_cache", cache)
    if dado is None:
        continue
    achou_biblioteca = True
    vivos = ids_instalados(carrega(*instalado))
    for g in lista_de_jogos(dado):
        if not g.get("is_installed"):
            continue
        if (g.get("install") or {}).get("is_dlc"):
            continue
        if vivos is not None and str(g["app_name"]) not in vivos:
            continue
        jogos.append((g.get("runner") or runner, g))

# Os `sideload`: jogo que ela mesma apontou para o Heroic. Não têm backend nem
# `installed.json` — a biblioteca é a única fonte, e é ela que manda.
lado = carrega("sideload_apps", "library.json")
if lado is not None:
    achou_biblioteca = True
    for g in lista_de_jogos(lado):
        if (g.get("install") or {}).get("is_dlc"):
            continue
        jogos.append((g.get("runner") or "sideload", g))

if not achou_biblioteca:
    # Nenhuma biblioteca legível. Não é "zero jogos": é "não sei".
    sys.exit(2)

# --- a arte, só do que já está no disco --------------------------------------
SUFIXOS = ("?h=400&resize=1&w=300", "", "?h=800&resize=1&w=600")


def arte(runner, g):
    app = str(g["app_name"])
    for ext in (".jpg", ".png", ".ico"):
        p = os.path.join(conf, "icons", app + ext)
        if os.path.isfile(p):
            return p
    if runner == "gog":
        caminho = (g.get("install") or {}).get("install_path") or ""
        for p in (
            os.path.join(caminho, "goggame-%s.ico" % app),
            os.path.join(caminho, "support", "icon.png"),
        ):
            if caminho and os.path.isfile(p):
                return p
    cache = os.path.join(conf, "images-cache")
    for chave in ("art_square", "art_cover"):
        url = g.get(chave)
        if not url:
            continue
        for suf in SUFIXOS:
            digest = hashlib.sha256((url + suf).encode("utf-8")).hexdigest()
            p = os.path.join(cache, digest)
            if os.path.isfile(p):
                return p
    return ""


vistos = set()
for runner, g in jogos:
    app = str(g["app_name"])
    if (runner, app) in vistos:
        continue
    vistos.add((runner, app))
    titulo = (g.get("title") or app).strip()
    # TAB e quebra de linha viram espaço: a saída é lida campo a campo por TAB.
    limpo = " ".join(titulo.split())
    sys.stdout.write("\t".join((runner, app, limpo, arte(runner, g))) + "\n")
PY
}

# --- o id do arquivo ---------------------------------------------------------
# O `app_name` do Epic é um hash, o do GOG um número e o do sideload um uuid —
# mas o do sideload é escolhido pelo Heroic a partir do nome que ELA digitou,
# então pode trazer qualquer coisa.
id_do_jogo() {
  local runner="$1" app="$2"
  printf 'meow-heroic-%s-%s' "$(printf '%s' "$runner" | tr -c 'A-Za-z0-9._-' '_')" \
                             "$(printf '%s' "$app"    | tr -c 'A-Za-z0-9._-' '_')"
}

loja_do_runner() {
  case "$1" in
    legendary) printf 'Epic Games' ;;
    gog)       printf 'GOG' ;;
    nile)      printf 'Amazon' ;;
    sideload)  printf 'adicionado à mão' ;;
    *)         printf '%s' "$1" ;;
  esac
}

# 0 = já está certo · 1 = não deu (sem convert, sem arte) · 2 = mudou / mudaria.
plantar_icone() {
  local id="$1" fonte="$2" destino dir tmp px lado mudou_algum=0
  meow_tem convert || return 1
  [ -n "$fonte" ] && [ -f "$fonte" ] || return 1

  while read -r px; do
    [ -n "$px" ] || continue
    destino="$HICOLOR/${px}x${px}/apps/$id.png"
    meow_destino_permitido "$destino" || return 1
    dir="$(dirname "$destino")"
    mkdir -p "$dir" || return 1
    lado=$(( px * 96 / 100 ))
    [ "$lado" -lt 1 ] && lado=1
    # O temporário nasce DENTRO do destino: `mv` entre sistemas de arquivos
    # diferentes não é atômico (trava 2 do lib/comum.sh).
    tmp="$(mktemp -p "$dir" ".meow.XXXXXX.png")" || return 1
    # `[0]` porque a fonte pode ser um `.ico` com várias resoluções dentro: sem
    # o índice, o `convert` escreveria um PNG por quadro e o `mv` seguinte não
    # acharia o arquivo que pediu.
    if ! convert "${fonte}[0]" -resize "${lado}x${lado}" -background none -gravity center \
          -extent "${px}x${px}" \
          -strip -define png:exclude-chunk=tIME,tEXt,zTXt "$tmp" 2>/dev/null; then
      rm -f "$tmp"; return 1
    fi
    if [ -f "$destino" ] && cmp -s "$tmp" "$destino"; then
      rm -f "$tmp"; continue
    fi
    if meow_seco; then rm -f "$tmp"; mudou_algum=1; continue; fi
    chmod 644 "$tmp"
    meow_guardar_antes "$destino"
    mv -f "$tmp" "$destino" || { rm -f "$tmp"; return 1; }
    mudou_algum=1
  done <<EOF_ESCADA
$(meow_icones_escada)
EOF_ESCADA

  [ "$mudou_algum" = 1 ] && return 2
  return 0
}

# --- 1. os jogos, da biblioteca do Heroic para o lançador --------------------

[ "$LISTAR" = "1" ] || _heroic_lista_trocar

biblioteca="$(_heroic_motor)"; rc_motor=$?
if [ "$rc_motor" = "2" ]; then
  # Não conseguimos LER a biblioteca.
  meow_aviso "não consegui ler a biblioteca do Heroic em $CONF — nada escrito, limpeza adiada"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

mudou=0; jogos=0; escritos=0; sem_arte=0; vivos=""

if [ "$LISTAR" = "1" ]; then
  while IFS=$'\t' read -r runner app titulo arte; do
    [ -n "$runner" ] && [ -n "$app" ] || continue
    id="$(id_do_jogo "$runner" "$app")"
    heroic_fora "$id" && no=nao || no=sim
    printf '%s\t%s\t%s\t%s\n' "$id" "$titulo" "$arte" "$no"
  done <<EOF_LISTA
$biblioteca
EOF_LISTA
  exit "$MEOW_OK"
fi

while IFS=$'\t' read -r runner app titulo arte; do
  [ -n "$runner" ] && [ -n "$app" ] || continue
  id="$(id_do_jogo "$runner" "$app")"
  # Fora do lançador a pedido: não entra em `vivos`, e a limpeza tira o cartão.
  heroic_fora "$id" && continue
  jogos=$((jogos + 1))
  vivos="$vivos$id"$'\n'

  nome="$titulo"
  curto="$(meow_nome_do_mapa "${id#meow-}" 2>/dev/null)" || curto=""
  [ -n "$curto" ] && nome="$curto"

  plantar_icone "$id" "$arte"
  case $? in
    0) icone="$id" ;;
    2) icone="$id"; mudou=1 ;;
    *) icone="$ICONE_PADRAO"; sem_arte=$((sem_arte + 1)) ;;
  esac

  corpo="$(printf '%s\n' \
    '[Desktop Entry]' \
    '# Gerado por MeowSystem/scripts/jogos_heroic.sh a partir da biblioteca do Heroic.' \
    '# Edições feitas aqui são desfeitas na próxima rodada — mude o script.' \
    'Type=Application' \
    'Version=1.0' \
    "Name=$nome" \
    "Comment=Jogo do Heroic ($(loja_do_runner "$runner"))" \
    "Exec=xdg-open \"heroic://launch?appName=$app&runner=$runner\"" \
    "Icon=$icone" \
    'Terminal=false' \
    'Categories=Game;' \
    'Keywords=heroic;jogo;game;epic;gog;' \
    'StartupNotify=false' \
    'X-MeowSystem=jogo-heroic' \
    "X-HeroicRunner=$runner" \
    "X-HeroicAppName=$app")"

  meow_escrever "$APPS/$id.desktop" "$corpo" 644
  case $? in
    1) mudou=1; escritos=$((escritos + 1)) ;;
    2) meow_erro "não consegui instalar o atalho de $titulo"; exit "$MEOW_ERRO" ;;
  esac
done <<EOF_BIBLIOTECA
$biblioteca
EOF_BIBLIOTECA

# --- 2. limpeza: o que existe no destino e não deveria mais existir -----------
# Só apaga com PROVA DE AUTORIA: a marca `X-MeowSystem=jogo-heroic` no corpo, ou
# — para o cartão que não é nosso — o `appName` do `Exec` casando com um jogo
# para o qual ACABAMOS de escrever o substituto.

removidos=0; duplicatas=0; degraus_removidos=0

for f in "$APPS"/meow-heroic-*.desktop; do
  [ -e "$f" ] || continue
  grep -q '^X-MeowSystem=jogo-heroic$' "$f" || continue
  orfao="$(basename "$f" .desktop)"
  printf '%s' "$vivos" | grep -qxF "$orfao" && continue
  if meow_seco; then
    meow_muda "removeria o atalho de um jogo que saiu do Heroic ($orfao)"
  else
    # Remove de TODO degrau — inclusive dos que saíram da escada quando a escala
    # da tela mudou; por isso o glob, e não a lista.
    for g in "$f" "$HICOLOR"/*/apps/"$orfao".png; do [ -e "$g" ] && meow_guardar_antes "$g"; done
    rm -f "$f" "$HICOLOR"/*/apps/"$orfao".png
  fi
  mudou=1; removidos=$((removidos + 1))
done

# DEGRAU ÓRFÃO: o jogo continua, mas o degrau saiu da escada (a escala da tela
# mudou). O critério é a escada VIVA, e ela tem de ser a MESMA função que planta
# — duas listas aqui seriam dois donos com outra roupa.
escada_viva="$(meow_icones_escada)"
for f in "$HICOLOR"/*/apps/meow-heroic-*.png; do
  [ -e "$f" ] || continue
  degrau="$(basename "$(dirname "$(dirname "$f")")")"   # "256x256"
  degrau="${degrau%%x*}"
  case "$degrau" in ''|*[!0-9]*) continue ;; esac
  printf '%s' "$escada_viva" | grep -qx "$degrau" && continue
  if meow_seco; then
    meow_muda "removeria $f (degrau $degrau fora da escada desta tela)"
  else
    meow_destino_permitido "$f" || continue
    meow_guardar_antes "$f"
    rm -f "$f"
  fi
  mudou=1; degraus_removidos=$((degraus_removidos + 1))
done

# --- O CARTÃO QUE O PRÓPRIO HEROIC ESCREVE -----------------------------------
# Ele nasce com o NOME DO JOGO no arquivo (`sanitize(title) + ".desktop"`), sem
# prefixo nem sufixo: `Marvel's Guardians of the Galaxy.desktop`.
bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-duplicatas"
for f in "$APPS"/*.desktop; do
  [ -e "$f" ] || continue
  grep -q '^X-MeowSystem=jogo-heroic$' "$f" && continue
  linha_exec="$(grep -E '^Exec=' "$f" 2>/dev/null | grep -F 'heroic://launch')" || continue
  [ -n "$linha_exec" ] || continue
  apps_rivais="$(printf '%s\n' "$linha_exec" \
    | grep -oE 'appName=[A-Za-z0-9._-]+|heroic://launch/[A-Za-z0-9._-]+' \
    | sed -E 's#^appName=##; s#^heroic://launch/##' | sort -u)"
  [ -n "$apps_rivais" ] || continue
  # Dois jogos no mesmo `Exec=` não é atalho de UM jogo — é um script dela.
  [ "$(printf '%s\n' "$apps_rivais" | wc -l)" = "1" ] || continue
  # O runner do rival pode não estar escrito no URI (forma antiga), então o
  # substituto é procurado por `app_name` em qualquer runner de `vivos`.
  alvo="$(printf '%s' "$vivos" | grep -E -- "-$(printf '%s' "$apps_rivais" | sed 's/[][\.*^$/]/\\&/g')\$" | head -1)"
  [ -n "$alvo" ] || continue
  [ "$f" = "$APPS/$alvo.desktop" ] && continue
  if meow_seco; then
    meow_muda "removeria o cartão duplicado de $apps_rivais: $(basename "$f") (aponta para o jogo e não é nosso)"
  else
    mkdir -p "$bkp" 2>/dev/null && cp -a "$f" "$bkp/" 2>/dev/null || {
      meow_aviso "sem backup para $(basename "$f") — não removo o que não consigo guardar"
      continue
    }
    meow_guardar_antes "$f"
    rm -f -- "$f"
    meow_muda "cartão duplicado removido: $(basename "$f") (cópia em $bkp)"
  fi
  mudou=1; duplicatas=$((duplicatas + 1))
done

# --- 3. o veredito ------------------------------------------------------------

_notas_finais() {
  [ "$sem_arte" -gt 0 ] &&
    meow_info "$sem_arte jogo(s) ficaram com o ícone do Heroic: a capa ainda não está no disco — ela entra na próxima passada depois de o Heroic baixá-la"
  return 0
}
[ "$sem_arte" -gt 0 ] && trap _notas_finais EXIT

if [ "$jogos" -eq 0 ] && [ "$mudou" = "0" ]; then
  meow_pula "Heroic instalado, nenhum jogo instalado — nada a criar"
  exit "$MEOW_OK"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "$jogos jogo(s) do Heroic no lançador, com a capa que ele baixou"
  exit "$MEOW_OK"
fi

if meow_seco; then
  meow_muda "$jogos jogo(s) do Heroic: $escritos atalho(s) a escrever, $removidos a remover, $duplicatas cartão(ões) duplicado(s) a tirar do lançador"
  exit "$MEOW_DIVERGENTE"
fi

# `update-desktop-database` é índice de MIME, não a lista do lançador. Só o
# diretório do USUÁRIO.
meow_tem update-desktop-database && update-desktop-database "$APPS" 2>/dev/null || true

# A capa está no hicolor, e o GTK não a vê enquanto a cache da raiz for mais
# nova que ela (o cabeçalho de `meow_hicolor_reindexar` traz a medição). O
# COSMIC enxerga sem isto; o painel DELA, que resolve ícone por PyGObject, não.
meow_hicolor_reindexar

# O `cosmic-app-library` e o `cosmic-launcher` resolvem os `.desktop` no
# arranque e guardam: sem chacoalhá-los, o arquivo está no disco e o cartão não
# está na tela.
meow_lancador_reler

[ "$escritos" -gt 0 ] && meow_ok "$escritos jogo(s) do Heroic no lançador (capa do jogo, como os da Steam)"
[ "$removidos" -gt 0 ] && meow_ok "$removidos atalho(s) de jogo que saiu do Heroic removidos"
[ "${degraus_removidos:-0}" -gt 0 ] && meow_ok "$degraus_removidos ícone(s) em degrau fora da escada removidos (a escada desta tela é: $(meow_icones_escada_dita))"
[ "$duplicatas" -gt 0 ] && meow_ok "$duplicatas jogo(s) deixaram de aparecer duas vezes no lançador"
exit "$MEOW_DIVERGENTE"
