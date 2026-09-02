#!/usr/bin/env bash
# icones_absolutos.sh — troca o `Icon=` de CAMINHO ABSOLUTO por um NOME, para que
#                       o tema de ícones passe a ser consultado.
#
#   ./icones_absolutos.sh              aplica (o mesmo que --aplicar)
#   ./icones_absolutos.sh --conferir   não escreve; devolve 1 se algo divergir
#   ./icones_absolutos.sh --sem-sudo   aplica só o que não precisa de root
#
# O DEFEITO, MEDIDO EM 08/08/2026
#   Dos 50 `.desktop` visíveis no lançador dela, UM aponta o ícone por caminho:
#
#     /usr/share/applications/input-remapper-gtk.desktop
#       Icon=/usr/share/input-remapper/input-remapper.svg
#
#   A especificação freedesktop permite as duas formas, e é aí que está a pegadinha:
#   com um caminho absoluto o programa abre o arquivo e pronto — **o tema de ícones
#   não é nem consultado**. Não há nome a resolver. Nenhuma linha de nenhum mapa
#   deste projeto alcança esse ícone; o `auditar_icones.sh` o classifica, com razão,
#   como "caminho absoluto", e é a única entrada dessa categoria na máquina dela.
#
#   Consequências, e nenhuma delas é estética: o ícone não acompanha o flavor, não
#   acompanha claro/escuro, e o dia em que o pacote mudar de caminho ele desaparece
#   sem nada acusar — porque não há tema onde procurar um substituto.
#
# O CONSERTO É REESCREVER NO ARQUIVO QUE JÁ EXISTE, E ISSO FOI UMA CORREÇÃO DE ROTA
#   O desenho que veio da auditoria era outro: um `.desktop` NOVO no home com
#   `Icon=<nome>`, mais `NoDisplay=true` no arquivo do sistema — apoiado no fato
#   (verdadeiro) de que o `cosmic-app-library` NÃO deduplica por ID. Esse desenho
#   FOI RECUSADO, e o motivo é o próprio `ocultar_apps.sh`:
#
#     O arquivo de `/usr/share` é território do apt. Um `apt upgrade` do pacote
#     devolve o original — sem o `NoDisplay`. A partir daí o lançador mostra DOIS
#     "Input Remapper": o nosso do home e o do sistema, desambiguados com
#     "(Local)" e "(Sistema)". Ou seja: o conserto fabricaria exatamente a
#     duplicata que o `ocultar_apps.sh` existe para limpar, e fabricaria numa data
#     que ninguém escolhe.
#
#   Reescrevendo no arquivo que já existe, o mesmo `apt upgrade` devolve o ícone
#   antigo e nada mais: UMA entrada no lançador, o `--conferir` acusa, e o
#   `meow ativar` refaz. É a mesma escolha que o `nomes_apps.sh` já fez, pelo mesmo
#   motivo, e o comentário dele diz a frase inteira: "o nome curto tem de entrar no
#   arquivo que já existe, onde quer que ele esteja".
#
# SÓ MEXE EM CAMINHO ABSOLUTO — ESSA É A TRAVA
#   Se o `Icon=` já for um nome, o script não toca. Não há "melhorar" um nome aqui:
#   trocar um nome que resolve por outro é decisão de mapa, não de script, e é o
#   que o `assets/icones/apps.map` e o `assets/icones/apps-arcticons.map` fazem. A única coisa que
#   este arquivo conserta é a forma que impede o tema de ser consultado.
#
# E SÓ NA SEÇÃO `[Desktop Entry]`
#   Um `[Desktop Action]` pode ter o próprio `Icon=`, e trocá-lo mudaria o ícone de
#   um item do menu de contexto. É a mesma armadilha que o `ocultar_apps.sh`
#   descreve para o `NoDisplay` e o `nomes_apps.sh` para o `Name=`: chave certa,
#   seção errada, efeito outro.
#
# O NOME NOVO TEM DE EXISTIR NO TEMA, E QUEM O CRIA É OUTRO SCRIPT
#   `input-remapper` passou a existir por uma linha no `assets/icones/apps-arcticons.map`
#   (`input-remapper:keymapper:sky`, com a medição de cor lá dentro), posta em
#   `48x48/apps` pelo `icones_apps_arcticons.sh`. Este script NÃO instala ícone:
#   se o nome não resolver, ele avisa e não escreve — trocar um caminho que
#   funciona por um nome que não resolve daria ícone genérico, que é pior que o
#   ícone velho do upstream.
#
# A LISTA É CURTA E EXPLÍCITA, de propósito — como no `ocultar_apps.sh`
#   Nada de heurística do tipo "todo Icon= que começa com / vira o basename". O
#   basename daria `input-remapper`, sim, mas daria também nomes que não existem em
#   tema nenhum, e o script escreveria com confiança um `Icon=` que resolve para
#   nada. Cada linha aqui é uma decisão, com o nome escolhido e medido.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia (e foi consertado, fora do seco) · 2 erro ·
#   3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA="${ICONES_TEMA:-${NOME_TEMA_ICONES:-MeowSystem-Icons}}"

# Os diretórios que o lançador varre, na ordem dele. Todos entram: o mesmo id pode
# existir em mais de um, e cada cópia visível é um item na tela. Mesma lista do
# `nomes_apps.sh`, pelo mesmo motivo.
DIRS=(
  "$HOME/.local/share/applications"
  "$HOME/.local/share/flatpak/exports/share/applications"
  "/var/lib/flatpak/exports/share/applications"
  "/usr/share/applications"
  "/usr/local/share/applications"
)

# `id-do-desktop : nome-de-icone`, com o porquê ao lado.
#
#   input-remapper-gtk  Icon=/usr/share/input-remapper/input-remapper.svg, o
#                       único caminho absoluto dos 50 visíveis. O nome novo é
#                       `input-remapper`, que o `assets/icones/apps-arcticons.map` faz
#                       existir com o glifo `keymapper` na cor `sky` — gamepad com
#                       D-pad na frente de um teclado, que é a composição do
#                       próprio ícone do upstream.
TROCAR=(
  "input-remapper-gtk:input-remapper"
)

# --- o nome novo resolve no tema? -------------------------------------------
# Sem `gi` não há como perguntar ao resolvedor real, e aí a resposta honesta é
# "não sei": o script então CONFIA na lista e segue, em vez de recusar por não
# conseguir medir. O `python3` do PATH é o venv dela e não tem `gi`; o do sistema
# tem. Se nenhum dos dois servir, a conferência é pulada, não inventada.
#
# `has_icon`, E NÃO `lookup_icon` — A ARMADILHA FOI REPRODUZIDA EM 08/08/2026
#   `Gtk.IconTheme.lookup_icon` NUNCA devolve vazio: para um nome que não existe
#   ele devolve um `IconPaintable` do `image-missing` embutido, e o `get_file()`
#   dele é um `GResourceFile` — objeto verdadeiro, não `None`. Um teste escrito
#   como `if p.get_file()` aprova TODO nome, inclusive os inexistentes, e foi
#   exatamente o que a primeira versão deste script fez: ela mandou trocar o
#   caminho absoluto por um nome que ainda não existia no tema.
#   Quem delata é o `get_icon_name()`, que sai `image-missing`, ou o `get_path()`,
#   que sai `None` porque recurso embutido não tem caminho em disco. O predicado
#   certo, e o único curto, é o `has_icon`.
PY_SISTEMA=""
for c in /usr/bin/python3.12 /usr/bin/python3; do
  if [ -x "$c" ] && "$c" -c 'import gi' 2>/dev/null; then PY_SISTEMA="$c"; break; fi
done

_resolve() {
  local nome="$1"
  [ -n "$PY_SISTEMA" ] || return 0     # não sei medir: não reprovo
  "$PY_SISTEMA" - "$nome" "$TEMA" <<'PY' 2>/dev/null
import sys, gi
gi.require_version("Gtk", "4.0")
from gi.repository import Gtk, Gdk
Gtk.init()
disp = Gdk.Display.get_default()
t = Gtk.IconTheme.get_for_display(disp) if disp else Gtk.IconTheme.new()
if disp is None:
    t.set_theme_name(sys.argv[2])
sys.exit(0 if t.has_icon(sys.argv[1]) else 1)
PY
}

# --- o Icon= da seção [Desktop Entry], como ele está hoje --------------------
_icone_atual() {
  awk '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && /^Icon=/ { sub(/^Icon=/, ""); print; exit }
  ' "$1"
}

# --- o arquivo com o Icon= trocado ------------------------------------------
_reescrito() {
  local arq="$1" novo="$2"
  awk -v novo="$novo" '
    /^\[/ { sec = $0 }
    sec == "[Desktop Entry]" && /^Icon=/ { print "Icon=" novo; next }
    { print }
  ' "$arq"
}

_classe() {
  case "$1" in
    "$HOME"/.local/share/flatpak/exports/share/applications) printf 'flatpak' ;;
    "$HOME"/*)                                               printf 'home' ;;
    *)                                                       printf 'sistema' ;;
  esac
}

CONFERIR=0
SEM_SUDO=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --sem-sudo) SEM_SUDO=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--sem-sudo]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

mudou=0
pendente_sudo=0
ausentes=0
falhou=0
sem_icone=0
declare -A DIRS_TOCADOS=()

for linha in "${TROCAR[@]}"; do
  id="${linha%%:*}"
  nome="${linha#*:}"
  [ -n "$id" ] && [ -n "$nome" ] || continue

  achou=0
  for dir in "${DIRS[@]}"; do
    arq="$dir/$id.desktop"
    [ -e "$arq" ] || continue
    achou=1

    atual="$(_icone_atual "$arq")"

    # Já é um nome? Então não é caso nosso — nem quando o nome é outro. Isto é a
    # trava, e ela também é o que faz o script idempotente: depois de aplicar, o
    # `Icon=` deixa de começar com `/` e a linha para de casar para sempre.
    case "$atual" in
      /*) ;;
      *)  continue ;;
    esac

    # O nome novo tem de resolver ANTES de a gente jogar fora o caminho que
    # funciona. Um `Icon=` que não resolve dá ícone genérico — pior que o velho.
    if ! _resolve "$nome"; then
      meow_aviso "'$nome' ainda não resolve no tema $TEMA — '$id' fica com o caminho absoluto"
      meow_info "  rode o icones_apps_arcticons.sh primeiro (a linha está em assets/icones/apps-arcticons.map)"
      sem_icone=$((sem_icone + 1))
      continue
    fi

    desejado="$(_reescrito "$arq" "$nome")"

    if [ "$CONFERIR" = 1 ]; then
      meow_muda "trocaria o Icon= de $id: '$atual' -> '$nome'"
      mudou=1
      continue
    fi

    case "$(_classe "$dir")" in
      home|flatpak)
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
        if [ ! -w "$arq" ] && ! sudo -n true 2>/dev/null; then
          pendente_sudo=$((pendente_sudo + 1))
          continue
        fi
        # A CÓPIA VEM ANTES DA ESCRITA, SEMPRE. O arquivo é do apt, e trocar o
        # `Icon=` sem guardar o original era uma via de mão única — `meow
        # desfazer --lancador` é a contrapartida de mexer em /usr/share.
        if ! meow_backup_sistema "$arq"; then
          meow_aviso "não consegui guardar cópia de $arq — não vou reescrevê-lo"
          falhou=1; continue
        fi
        tmp="$(mktemp)" || { falhou=1; continue; }
        printf '%s\n' "$desejado" > "$tmp"
        if sudo install -m 644 "$tmp" "$arq" 2>/dev/null; then
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

if [ "$falhou" = 1 ]; then
  meow_erro "algum Icon= não pôde ser reescrito"
  exit "$MEOW_ERRO"
fi

if [ "$pendente_sudo" -gt 0 ]; then
  if [ "$SEM_SUDO" = 1 ]; then
    meow_pula "$pendente_sudo Icon= em /usr/share espera root — rode: meow ativar"
  else
    meow_aviso "$pendente_sudo Icon= precisa(m) de sudo para trocar"
    meow_info "rode o install.sh de novo com sudo disponível"
  fi
fi

if [ "$mudou" = 0 ] && [ "$pendente_sudo" = 0 ]; then
  meow_ok "nenhum Icon= de caminho absoluto (${#TROCAR[@]} na lista, $ausentes não instalados, $sem_icone sem ícone no tema)"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  exit "$MEOW_DIVERGENTE"
fi

if [ "$mudou" = 1 ]; then
  # O lançador lê um cache de MIME, não a lista de aplicativos: falhar aqui não é
  # erro, o arquivo já está no lugar certo.
  if meow_tem update-desktop-database; then
    for dir in "${!DIRS_TOCADOS[@]}"; do
      if [ -w "$dir" ]; then
        update-desktop-database "$dir" 2>/dev/null || true
      else
        sudo -n update-desktop-database "$dir" 2>/dev/null || true
      fi
    done
  fi
  meow_ok "Icon= de caminho absoluto trocado por nome"
  meow_info "vale no próximo início do lançador"
fi

exit "$MEOW_DIVERGENTE"
