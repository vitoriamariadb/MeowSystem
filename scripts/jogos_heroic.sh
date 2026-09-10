#!/usr/bin/env bash
# jogos_heroic.sh — um .desktop por jogo INSTALADO no Heroic, no lançador dela.
#
#   ./jogos_heroic.sh              escreve, limpa e converge
#   ./jogos_heroic.sh --conferir   não escreve nem apaga; 1 se algo divergir
#
# POR QUE ISTO EXISTE
#   Queixa dela, 10/09/2026: "os jogos instalados pelo heroic launcher não
#   aparecem nos .desktop da interface". Medido no mesmo dia, e a causa é a
#   mesma da Steam com outro nome: o Heroic SÓ escreve `.desktop` de jogo quando
#   alguém liga a chave, e ela está desligada —
#       addDesktopShortcuts=false · addStartMenuShortcuts=false
#   em `config.json` (a lista de `heroic/config.json` desta máquina). Nenhum
#   `.desktop` do Heroic existia em `~/.local/share/applications` nem no
#   `~/.var/app/.../data/applications`: `grep -ril heroic` nos dois devolveu
#   vazio. Ou seja: não é atalho que se perdeu, é atalho que nunca foi escrito.
#
#   Ligar as duas chaves DELE seria o contorno óbvio e é o errado: o Heroic só
#   escreve o atalho no momento da instalação (`addShortcuts` é chamado no fim do
#   download), então os jogos JÁ instalados continuariam de fora, e o arquivo
#   ficaria sem dono conhecido — sem a nossa marca, sem escada de ícone e sem
#   limpeza quando o jogo sair. Aqui a fonte é a biblioteca do próprio Heroic,
#   relida a cada passagem, como o `jogos_steam.sh` faz com o `appmanifest`.
#
# A FONTE DE VERDADE SÃO DOIS ARQUIVOS, E ELES SE CONFIRMAM
#   1. `store_cache/<runner>_library.json` — a biblioteca que o Heroic guarda
#      para desenhar a própria tela. É um formato SÓ para os quatro runners
#      (`app_name`, `title`, `runner`, `is_installed`, `install.is_dlc`,
#      `art_square`), e é o mesmo objeto que o Heroic passa para a rotina que
#      escreve os atalhos dele (`addShortcuts(gameInfo)`, lido no `app.asar`
#      2.22.1). Daqui saem título e arte.
#   2. `<runner>Config/.../installed.json` — o que o backend (legendary, gogdl,
#      nile) escreve ao instalar e apaga ao desinstalar. Daqui sai o "está no
#      disco".
#   Um jogo entra no lançador quando os DOIS concordam. O cache sozinho não
#   basta: ele é reescrito pelo frontend e pode dizer `is_installed` de um jogo
#   que saiu. O `installed.json` sozinho também não: ele não tem a arte, e no
#   gog/nile nem o título. Quando o `installed.json` do runner não existe ou não
#   é legível, vale o cache — é o caso dos jogos `sideload`, que não têm backend.
#
# O DLC NÃO É JOGO — E O HEROIC PENSA IGUAL
#   `install.is_dlc` sai do próprio `app.asar`: `addShortcuts` começa com
#   `if (gameInfo.install.is_dlc) return`. Nesta máquina são dois registros
#   `is_installed` para um jogo só — Marvel's Guardians of the Galaxy e a roupa
#   Social-Lord, 327 KiB, que não abre nada. Sem esta linha o lançador ganharia
#   um cartão que não é um jogo.
#
# O `Exec` É O DO PRÓPRIO HEROIC, COM AS ASPAS QUE FALTAM NELE
#   O modelo do upstream (mesma função do `app.asar`) é
#       Exec=xdg-open heroic://launch?appName=<app>&runner=<runner>
#   e o handler `x-scheme-handler/heroic` está registrado nesta máquina —
#   `xdg-mime query default x-scheme-handler/heroic` devolve
#   `com.heroicgameslauncher.hgl.desktop`, medido em 10/09/2026. As aspas são
#   nossas: `&`, `?` e `$` são caracteres RESERVADOS no campo `Exec` da
#   especificação, e sem aspas o `desktop-file-validate` reclama.
#
#   Nada de `flatpak run …` cravado: o Heroic também existe como deb e AppImage,
#   e o URI resolve nos três. É a mesma escolha do `jogos_steam.sh` ao recusar o
#   wrapper do Ritual da Aurora — só que aqui o caminho estável é o protocolo, e
#   não o binário.
#
# UM CARTÃO POR JOGO, E O RIVAL AQUI É O PRÓPRIO HEROIC
#   Se ela ligar "criar atalho" na interface dele, o arquivo nasce com o NOME DO
#   JOGO (`shortcutFiles()` no `app.asar`: `${sanitize(title)}.desktop`) — nome
#   livre, com espaço e acento, que nenhum glob descreve. É o `Future Knight` de
#   09/09/2026 outra vez. Por isso a limpeza pergunta pelo CONTEÚDO: para qual
#   `appName` este cartão aponta, e ele tem a nossa assinatura?
#
# O ÍCONE É A CAPA, E ELA JÁ ESTÁ NO DISCO
#   Nada de tematizar (a mesma decisão dos jogos da Steam: capa repintada vira
#   um monte de ícone igual). E nada de baixar: um script que o `meow doctor`
#   chama às 5h não vai à rede. As três fontes locais, medidas em 10/09/2026:
#     1. `icons/<app_name>.jpg|.png` — a arte alta que o próprio Heroic baixa
#        (1200x1600 no jogo desta máquina);
#     2. o `.ico`/`support/icon.png` de dentro da pasta do jogo, no GOG — é o
#        que o `getIcon` do Heroic prefere para esse runner;
#     3. `images-cache/<sha256 da URL da arte>` — o cache do frontend. A conta é
#        `sha256(art_square + "?h=400&resize=1&w=300")`, lida no `app.asar`
#        (`getImageFromCache`) e conferida contra o disco: 31 dos 33 arquivos do
#        cache desta máquina foram identificados por ela. São 300x400, de sobra
#        para a escada, que aqui termina em 96.
#   Sem nenhuma das três, o cartão usa o ícone do Heroic — que é honesto ("é um
#   jogo do Heroic") e nunca um borrão.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"
# O encurtamento do rótulo: as chaves do `assets/icones/apps-nomes.map` para os
# jogos daqui são `heroic-<runner>-<app_name>`, o mesmo id do arquivo sem o
# prefixo `meow-`. (Na Steam a chave é `steam-<appid>` e o arquivo é
# `meow-steam-<appid>` — divergência histórica que lá é documentada e que não se
# repete aqui.)
. "$RAIZ/scripts/nomes_apps.sh"

APPS="$HOME/.local/share/applications"
HICOLOR="$HOME/.local/share/icons/hicolor"
ICONE_PADRAO="com.heroicgameslauncher.hgl"

# --- o mesmo verbo dos outros módulos, e a mesma armadilha do seco ------------
# `MEOW_SECO` é congelado no `source` do `lib/comum.sh` (comum.sh:25), então
# definir `MEOW_DRY_RUN` aqui embaixo chegaria tarde e o `--conferir` APAGARIA
# arquivo dizendo que era conferência. Foi medido no irmão da Steam, em
# 02/09/2026, apagando o cartão do Stray de verdade.
case "${1:-}" in
  --conferir) MEOW_SECO=1; MEOW_DRY_RUN=1; export MEOW_DRY_RUN ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac

meow_tem python3 || {
  meow_pula "sem python3 — não dá para ler a biblioteca do Heroic (é JSON)"
  exit "$MEOW_SEM_DEPENDENCIA"
}

# --- ONDE O HEROIC GUARDA A CONFIGURAÇÃO -------------------------------------
# Flatpak primeiro porque é o desta máquina (`flatpak list` -> Heroic v2.22.1,
# instalação `user`). O caminho nativo cobre o deb e o AppImage, que usam o
# `~/.config/heroic` de sempre. `HEROIC_CONF` no ambiente vence os dois — é o
# que o teste usa.
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
# errado. Sai 0 com zero linha quando não há jogo instalado, e 2 quando não
# CONSEGUIU ler — a diferença importa, porque o segundo caso ADIA a limpeza (não
# saber quais jogos existem não é o mesmo que saber que não existe nenhum).
_heroic_motor() {
  python3 - "$CONF" <<'PY'
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
# `meow-heroic-<runner>-<app_name>`. O `app_name` do Epic é um hash, o do GOG um
# número e o do sideload um uuid — mas o do sideload é escolhido pelo Heroic a
# partir do nome que ELA digitou, então pode trazer qualquer coisa. Tudo que não
# for `[A-Za-z0-9._-]` vira `_`, e o runner entra no nome porque dois runners
# podem repetir um mesmo `app_name` sem se conhecerem.
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
# É o `plantar_icone` do `jogos_steam.sh`, com o mesmo `-strip` +
# `exclude-chunk=tIME` que torna a saída byte-idêntica entre duas rodadas (sem
# ele o carimbo de tempo dentro do PNG faz o doctor acusar divergência eterna) e
# a mesma proporção de 96% da caixa em TODO degrau da escada.
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
    mv -f "$tmp" "$destino" || { rm -f "$tmp"; return 1; }
    mudou_algum=1
  done <<EOF_ESCADA
$(meow_icones_escada)
EOF_ESCADA

  [ "$mudou_algum" = 1 ] && return 2
  return 0
}

# --- 1. os jogos, da biblioteca do Heroic para o lançador --------------------

biblioteca="$(_heroic_motor)"; rc_motor=$?
if [ "$rc_motor" = "2" ]; then
  # Não conseguimos LER a biblioteca. Escrever nada e apagar nada é o único
  # comportamento honesto: a ausência de um jogo aqui seria falsa, e a limpeza
  # tiraria da tela dela cartões de jogos que continuam instalados. É o mesmo
  # adiamento que o irmão da Steam faz com a biblioteca desmontada.
  meow_aviso "não consegui ler a biblioteca do Heroic em $CONF — nada escrito, limpeza adiada"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

mudou=0; jogos=0; escritos=0; sem_arte=0; vivos=""

while IFS=$'\t' read -r runner app titulo arte; do
  [ -n "$runner" ] && [ -n "$app" ] || continue
  id="$(id_do_jogo "$runner" "$app")"
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
# para o qual ACABAMOS de escrever o substituto. Nunca por prefixo de nome
# sozinho: um `.desktop` que ela escreveu à mão não é órfão de ninguém.

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
    rm -f "$f"
  fi
  mudou=1; degraus_removidos=$((degraus_removidos + 1))
done

# --- O CARTÃO QUE O PRÓPRIO HEROIC ESCREVE -----------------------------------
# Ele nasce com o NOME DO JOGO no arquivo (`sanitize(title) + ".desktop"`), sem
# prefixo nem sufixo: `Marvel's Guardians of the Galaxy.desktop`. Nome livre,
# como o `Future Knight.desktop` da Steam em 09/09/2026 — nenhum glob o
# descreve, então a pergunta é sobre o conteúdo.
#
# AS TRÊS CONDIÇÕES, TODAS JUNTAS
#   a) o `Exec=` carrega `heroic://launch` com um `appName` — e o app sai DALI,
#      nunca do nome do arquivo. As duas formas do URI são aceitas: a de hoje
#      (`?appName=<app>&runner=<runner>`) e a antiga (`/launch/<app>`), porque um
#      atalho escrito por uma versão velha do Heroic continua no disco;
#   b) o arquivo NÃO traz a nossa assinatura;
#   c) esse mesmo jogo está em `vivos`, isto é, acabamos de escrever o cartão
#      dele. É a promessa que não se toca: nunca tirar um cartão sem deixar
#      substituto, senão o jogo SOME da tela dela.
#
# BACKUP ANTES, PORQUE O ARQUIVO NÃO É NOSSO, e a remoção é ANUNCIADA.
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
    rm -f -- "$f"
    meow_muda "cartão duplicado removido: $(basename "$f") (cópia em $bkp)"
  fi
  mudou=1; duplicatas=$((duplicatas + 1))
done

# --- 3. o veredito ------------------------------------------------------------

_notas_finais() {
  [ "$sem_arte" -gt 0 ] &&
    meow_info "$sem_arte jogo(s) ficaram com o ícone do Heroic: a capa ainda não está no disco — abra a biblioteca dele uma vez e rode de novo"
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

# O `cosmic-app-library` e o `cosmic-launcher` resolvem os `.desktop` no arranque
# e guardam: sem chacoalhá-los, o arquivo está no disco e o cartão não está na
# tela. Só aqui, depois do `meow_seco` — a função fecha a grade se ela estiver
# aberta, e este é o único ponto onde já se sabe que algo mudou de verdade.
meow_lancador_reler

[ "$escritos" -gt 0 ] && meow_ok "$escritos jogo(s) do Heroic no lançador (capa do jogo, como os da Steam)"
[ "$removidos" -gt 0 ] && meow_ok "$removidos atalho(s) de jogo que saiu do Heroic removidos"
[ "${degraus_removidos:-0}" -gt 0 ] && meow_ok "$degraus_removidos ícone(s) em degrau fora da escada removidos (a escada desta tela é: $(meow_icones_escada_dita))"
[ "$duplicatas" -gt 0 ] && meow_ok "$duplicatas jogo(s) deixaram de aparecer duas vezes no lançador"
exit "$MEOW_DIVERGENTE"
