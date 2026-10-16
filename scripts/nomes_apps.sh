#!/usr/bin/env bash
#   ./nomes_apps.sh              aplica (o mesmo que --aplicar)
#   ./nomes_apps.sh --conferir   não escreve; devolve 1 se algo divergir
#   ./nomes_apps.sh --sem-sudo   aplica só o que não precisa de root
#   ./nomes_apps.sh --so-flatpak aplica só nos exports de flatpak do home, e o
#                                644 em ~/.local/share/applications
#   ./nomes_apps.sh --so-sistema aplica só em /usr/share e /var/lib (é o gatilho do apt;
#                                não toca a permissão do home)
set -uo pipefail

MEOW_NOMES_RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$MEOW_NOMES_RAIZ/lib/comum.sh"

MEOW_NOMES_MAPA="${MEOW_NOMES_MAPA:-$MEOW_NOMES_RAIZ/assets/icones/apps-nomes.map}"

# Os diretórios que o lançador varre, na ordem dele. Todos entram: o mesmo id
# pode existir em mais de um, e cada cópia visível é um item na tela.
MEOW_NOMES_DIRS=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "/usr/share/applications"
  "/usr/local/share/applications"
)

# --- o mapa ------------------------------------------------------------------
# Lido a cada consulta em vez de num array global porque este arquivo também é
# `source` pelo `jogos_steam.sh`, e um estado global carregado no source é
# exatamente o tipo de coisa que fica velha sem avisar.
meow_nome_do_mapa() {
  local id="$1"
  [ -f "$MEOW_NOMES_MAPA" ] || return 1
  awk -F: -v id="$id" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    $1 == id { sub(/^[^:]*:/, ""); print; achou=1; exit }
    END { exit !achou }
  ' "$MEOW_NOMES_MAPA"
}

# --- a reescrita ---------------------------------------------------------------
# Devolve o CONTEÚDO do arquivo com o nome curto no lugar. Sem argumento de nome,
# consulta o mapa; sem entrada no mapa, devolve o arquivo intacto — o que faz
# desta função segura de aplicar sobre qualquer .desktop.
#
# Esta é a função que o `jogos_steam.sh` chama: lá o arquivo de origem está na
# área de trabalho com o nome do jogo, e o id de destino é `steam-<appid>`, então
# os dois vêm separados.
#
#   meow_nome_curto <id> <arquivo>
meow_nome_curto() {
  local id="$1" arq="$2" novo
  [ -f "$arq" ] || return 1
  novo="$(meow_nome_do_mapa "$id")" || { cat "$arq"; return 0; }
  [ -n "$novo" ] || { cat "$arq"; return 0; }

  # `sec` acompanha a seção corrente para que só a `[Desktop Entry]` seja tocada.
  # O `match` guarda a CHAVE (`Name=`, `Name[pt_BR]=`, `Name[pt]=`) e troca só o
  # valor — assim a variante de idioma continua sendo variante de idioma.
  awk -v novo="$novo" '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && match($0, /^Name(\[pt(_BR)?\])?=/) {
      print substr($0, RSTART, RLENGTH) novo; next
    }
    { print }
  ' "$arq"
}

# Só as funções, para quem der `source` (o `jogos_steam.sh`).
# shellcheck disable=SC2317
if [ "${BASH_SOURCE[0]}" != "${0}" ]; then
  return 0
fi

# =============================================================================
# Daqui para baixo é o script rodando por conta própria.
# =============================================================================

CONFERIR=0
SEM_SUDO=0
# Restringe o trabalho a UMA classe de caminho (ver `_classe`, logo abaixo).
# Vazio = todas, que é o modo do `install.sh` e do doctor.
SO_CLASSE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --conferir)   CONFERIR=1 ;;
    --sem-sudo)   SEM_SUDO=1 ;;
    --so-flatpak) SO_CLASSE=flatpak ;;
    --so-sistema) SO_CLASSE=sistema ;;
    ''|--aplicar) ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--sem-sudo|--so-flatpak|--so-sistema]"
       exit "$MEOW_ERRO" ;;
  esac
  shift
done
meow_seco && CONFERIR=1

if [ ! -f "$MEOW_NOMES_MAPA" ]; then
  meow_erro "não achei o mapa de nomes ($MEOW_NOMES_MAPA)"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# --- de que classe é este caminho -------------------------------------------
# Decide COMO escrever. O `/var/lib/flatpak` é export de instalação de sistema:
# mora fora do home e precisa de root como qualquer arquivo do apt.
_classe() {
  case "$1" in
    "$HOME"/.local/share/flatpak/exports/share/applications) printf 'flatpak' ;;
    "$HOME"/*)                                               printf 'home' ;;
    *)                                                       printf 'sistema' ;;
  esac
}

# O original de um export de flatpak, guardado antes da PRIMEIRA escrita.
# Enquanto o link estiver intacto (nunca aplicamos, ou o flatpak o recriou), a
# fonte é ele; a partir da primeira aplicação, é a cópia guardada.
_guardado_de() {
  local arq="$1"
  printf '%s/.%s.meow-original' "$(dirname "$arq")" "$(basename "$arq")"
}

_fonte_de() {
  local arq="$1" guardado; guardado="$(_guardado_de "$arq")"
  if [ -L "$arq" ]; then printf '%s' "$arq"; return; fi
  if [ -f "$guardado" ]; then printf '%s' "$guardado"; else printf '%s' "$arq"; fi
}

mudou=0
pendente_sudo=0
ausentes=0
falhou=0
declare -A DIRS_TOCADOS=()

# --- A PERMISSÃO DOS `.desktop` DO HOME -------------
#
# Em todos, menos `--so-sistema`: aquele é o gatilho do apt, que roda como ROOT,
# e root não tem nada a fazer no home dela (é a armadilha 3 do wrapper, contada
# no bloco dos filtros acima).
#
# O contador é separado do `mudou` dos nomes, e é por isso: o `mudou` chama o
# `meow_lancador_reler`, que derruba o `cosmic-app-library` para ele reler — e
# um chmod não muda nada que o lançador desenhe.
PERM_DIR="$HOME/.local/share/applications"
perm_n=0
perm_falhou=0
if [ "$SO_CLASSE" != "sistema" ] && [ -d "$PERM_DIR" ]; then
  while IFS= read -r -d '' arq; do
    modo="$(stat -c %a -- "$arq" 2>/dev/null)"
    if [ "$CONFERIR" = 1 ]; then
      meow_muda "$(basename "$arq") está com permissão $modo — o certo é 644"
      perm_n=$((perm_n + 1))
      continue
    fi
    if chmod 644 -- "$arq" 2>/dev/null; then
      meow_info "$(basename "$arq"): permissão $modo -> 644"
      perm_n=$((perm_n + 1))
    else
      meow_erro "não consegui dar 644 a $arq (permissão $modo)"
      perm_falhou=1
    fi
  done < <(find "$PERM_DIR" -maxdepth 1 -type f -name '*.desktop' ! -perm 644 -print0 2>/dev/null)
fi

# O mapa vai para um array ANTES do laço, e não para o `stdin` dele.
LINHAS=()
while IFS= read -r linha; do LINHAS+=("$linha"); done < "$MEOW_NOMES_MAPA"

for linha in "${LINHAS[@]}"; do
  case "$linha" in ''|\#*) continue ;; esac
  id="${linha%%:*}"
  curto="${linha#*:}"
  if [ -z "$id" ] || [ -z "$curto" ]; then continue; fi

  achou=0
  for dir in "${MEOW_NOMES_DIRS[@]}"; do
    arq="$dir/$id.desktop"
    [ -e "$arq" ] || continue
    achou=1

    # Oculto não tem rótulo na tela: nada a encurtar, e nenhum sudo a gastar.
    grep -qE '^NoDisplay=true' "$arq" 2>/dev/null && continue

    classe="$(_classe "$dir")"
    # O filtro fica DEPOIS do `achou=1`: um app que existe só em /usr/share
    # continua sendo "instalado" mesmo quando esta passada não vai tocá-lo, e
    # contá-lo como ausente faria o resumo mentir para quem lê o log.
    [ -n "$SO_CLASSE" ] && [ "$classe" != "$SO_CLASSE" ] && continue
    fonte="$arq"
    [ "$classe" = "flatpak" ] && fonte="$(_fonte_de "$arq")"

    desejado="$(meow_nome_curto "$id" "$fonte")" || { falhou=1; continue; }

    # Regra 5: comparar por CONTEÚDO. E comparar do mesmo jeito que se escreve —
    # `meow_escrever` grava com `printf '%s'`, que come o \n final, então `cmp`
    # byte a byte acusaria divergência eterna num arquivo perfeito.
    if [ -f "$arq" ] && [ ! -L "$arq" ] && [ "$desejado" = "$(cat "$arq" 2>/dev/null)" ]; then
      continue
    fi

    if [ "$CONFERIR" = 1 ]; then
      meow_muda "encurtaria $id -> '$curto'"
      mudou=1
      continue
    fi

    case "$classe" in
      home|flatpak)
        # O original do flatpak tem de ser guardado ANTES da primeira escrita:
        # depois que o symlink vira arquivo real, o alvo some para sempre.
        if [ "$classe" = "flatpak" ] && [ -L "$arq" ]; then
          guardado="$(_guardado_de "$arq")"
          [ -f "$guardado" ] || cp -L "$arq" "$guardado" 2>/dev/null || true
        fi
        meow_escrever "$arq" "$desejado" 644
        case $? in
          1) mudou=1; DIRS_TOCADOS["$dir"]=1 ;;
          2) meow_erro "não consegui escrever $arq"; falhou=1 ;;
        esac
        ;;
      sistema)
        if [ "$SEM_SUDO" = 1 ]; then
          pendente_sudo=$((pendente_sudo + 1))
          continue
        fi
        if ! meow_desktop_pode "$arq"; then
          pendente_sudo=$((pendente_sudo + 1))
          continue
        fi
        # A CÓPIA VEM ANTES DA ESCRITA, SEMPRE. O arquivo é do apt, e reescrevê-lo
        # sem guardar o original era uma via de mão única — `meow desfazer
        # --lancador` é a contrapartida de mexer em /usr/share.
        if ! meow_backup_sistema "$arq"; then
          meow_aviso "não consegui guardar cópia de $arq — não vou reescrevê-lo"
          falhou=1; continue
        fi
        tmp="$(mktemp)" || { falhou=1; continue; }
        printf '%s\n' "$desejado" > "$tmp"
        if meow_desktop_escrever "$arq" "$tmp"; then
          mudou=1; DIRS_TOCADOS["$dir"]=1
        else
          pendente_sudo=$((pendente_sudo + 1))
        fi
        rm -f "$tmp"
        ;;
    esac
  done
  [ "$achou" = 0 ] && ausentes=$((ausentes + 1))
done

# O `grep -c` JÁ IMPRIME O ZERO
#   Ele conta, imprime `0` e SAI 1 quando nada casa; o `|| printf 0` que estava
#   aqui somava um segundo zero, e com o mapa vazio (ou só de comentário) a tela
#   dizia "(0\n0 no mapa", quebrando a linha no meio. O padrão só vale para o
#   caso em que o grep não imprime nada: o mapa que ele não consegue ler (o que
#   não existe já parou lá em cima, com "não achei o mapa de nomes").
total="$(grep -cvE '^[[:space:]]*(#|$)' "$MEOW_NOMES_MAPA" 2>/dev/null)"
total="${total:-0}"

if [ "$falhou" = 1 ]; then
  meow_erro "algum nome não pôde ser reescrito"
  exit "$MEOW_ERRO"
fi

if [ "$pendente_sudo" -gt 0 ]; then
  if [ "$SEM_SUDO" = 1 ]; then
    meow_pula "$pendente_sudo nome(s) em /usr/share esperam root — rode: meow ativar"
  else
    meow_aviso "$pendente_sudo nome(s) precisam de sudo para encurtar"
  fi
fi

if [ "$mudou" = 0 ] && [ "$pendente_sudo" = 0 ] && [ "$perm_n" = 0 ] && [ "$perm_falhou" = 0 ]; then
  meow_ok "nomes do lançador já curtos ($total no mapa, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  exit "$MEOW_DIVERGENTE"
fi

[ "$perm_n" -gt 0 ] && meow_ok "$perm_n .desktop do home voltaram a 644"

if [ "$mudou" = 1 ]; then
  # O lançador lê o cache de .desktop. Falhar aqui não é erro: o arquivo já está
  # no lugar certo, e a base é um índice de MIME, não a lista de aplicativos.
  if meow_tem update-desktop-database; then
    for dir in "${!DIRS_TOCADOS[@]}"; do
      if [ -w "$dir" ]; then
        update-desktop-database "$dir" 2>/dev/null || true
      else
        meow_desktop_banco "$dir"
      fi
    done
  fi
  meow_ok "nomes do lançador encurtados"
  # O `update-desktop-database` acima reconstrói um índice de MIME; ele não faz
  # o `cosmic-app-library` reler nada. Aqueles dois processos resolvem nome e
  # ícone NO ARRANQUE e guardam.
  meow_lancador_reler
fi

if [ "$perm_falhou" = 1 ]; then
  meow_erro "algum .desktop do home não pôde voltar a 644"
  exit "$MEOW_ERRO"
fi

exit "$MEOW_DIVERGENTE"
