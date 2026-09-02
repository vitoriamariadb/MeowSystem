#!/usr/bin/env bash
# nomes_apps.sh — encurta o `Name=` dos aplicativos que estouram a célula do
#                 lançador do COSMIC.
#
#   ./nomes_apps.sh              aplica (o mesmo que --aplicar)
#   ./nomes_apps.sh --conferir   não escreve; devolve 1 se algo divergir
#   ./nomes_apps.sh --sem-sudo   aplica só o que não precisa de root
#
# O QUE ELA VÊ HOJE, E POR QUE
#   "os .desktop super feios" — e, perguntada, o que incomoda são "os nomes
#   compridos que quebram em duas linhas". Não é gosto: no lançador o rótulo mora
#   numa caixa de tamanho fixo, e o que não cabe quebra ou some atrás de "...".
#
# OS DOIS LIMITES, MEDIDOS EM 08/08/2026 (o `assets/icones/apps-nomes.map` traz a conta)
#   reticências : passou de 27 BYTES, o lançador corta nos 24 primeiros
#                 CARACTERES e acrescenta "...". É `max_name_len = 27` em
#                 `cosmic-app-library/src/widgets/application.rs`, e o `str::len()`
#                 do Rust conta byte enquanto o `{:.24}` conta caractere.
#   quebra      : a célula tem 114 px de texto ((1200 - 2*64 - 6*8)/7 - 2*16), e
#                 o rótulo é `text(name).size(14.0)` numa caixa de 40 px — cabem
#                 duas linhas, a terceira é cortada. Em Fira Sans 14 px isso dá
#                 uns 16 caracteres em caixa mista.
#
# A LISTA NÃO MORA AQUI, DE PROPÓSITO
#   Ela está em `assets/icones/apps-nomes.map`, com o motivo de cada corte ao lado. Lista
#   cravada dentro de script envelhece e ninguém acha — é a mesma razão que põe os
#   ícones em `assets/icones/apps.map` e os mimetypes em `assets/icones/mimetypes.map`.
#
# POR QUE ESCREVER NO ARQUIVO EXISTENTE, E NÃO NUMA CÓPIA NO HOME
#   Porque o `cosmic-app-library` NÃO DEDUPLICA POR ID — medido em 04/08/2026 e
#   documentado no `ocultar_apps.sh`. Uma cópia de `org.gimp.GIMP.desktop` em
#   `~/.local/share/applications` com o nome curto NÃO substituiria a do flatpak:
#   o lançador varreria os dois diretórios e mostraria o GIMP DUAS vezes, uma com
#   cada nome. Foi assim que nasceram as duplicatas "(Local)"/"(Sistema)". Então
#   o nome curto tem de entrar no arquivo que já existe, onde quer que ele esteja.
#
# TRÊS LUGARES, TRÊS MANEIRAS DE ESCREVER — e o script decide pelo caminho
#   ~/.local/share/applications        arquivo nosso: `meow_escrever` e pronto.
#   ~/.local/share/flatpak/exports/…   é um SYMLINK para dentro da árvore do
#                                      flatpak, que é somente-leitura. Mas o LINK
#                                      mora no home dela e pode virar arquivo
#                                      real. É a mesma manobra do
#                                      `assets/temas-de-apps/zapzap/manifesto.sh`, com o
#                                      alvo original guardado em `.meow-original`
#                                      para o `flatpak repair` não achar link
#                                      quebrado. Um `flatpak update` do app
#                                      recria o symlink e desfaz — o `--conferir`
#                                      detecta e o `--aplicar` refaz.
#   /usr/share/applications            é do apt: `sudo install -m 644`, como o
#                                      `ocultar_apps.sh`. Um `apt upgrade` do
#                                      pacote devolve o arquivo original e o nome
#                                      comprido volta. Reaparecer é esperado;
#                                      ficar assim, não.
#
# O QUE ELE NÃO FAZ, E ISSO IMPORTA
#   Não cria `.desktop`, não apaga, não mexe em `Exec=`, `Icon=`, `MimeType=` nem
#   em `Categories=`. Uma linha muda, e é a linha do nome.
#
#   E só na seção `[Desktop Entry]`. O `code.desktop` tem um
#   `[Desktop Action new-empty-window]` com o próprio `Name=New Empty Window`;
#   um `sed 's/^Name=.*/.../'` renomearia também o item do menu de contexto do
#   ícone. É a mesma armadilha que o `ocultar_apps.sh` descreve para o
#   `NoDisplay`: chave certa, seção errada, e o efeito é outro.
#
# ARQUIVO OCULTO É PULADO
#   Quem tem `NoDisplay=true` não aparece no lançador, então não há rótulo a
#   encurtar. Pular economiza um `sudo` inútil sobre os arquivos que o
#   `ocultar_apps.sh` já escondeu.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia (e foi consertado, fora do seco) · 2 erro ·
#   3 falta dependência (aqui: o mapa sumiu)
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
# exatamente o tipo de coisa que fica velha sem avisar. São dez linhas; o custo
# de reler é zero perto do de depurar cache.
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
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --sem-sudo) SEM_SUDO=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--sem-sudo]"; exit "$MEOW_ERRO" ;;
esac
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
# fonte é ele; a partir da primeira aplicação, é a cópia guardada. Sem isso, ler
# "a origem" devolveria o nosso próprio conteúdo e o `--conferir` passaria a
# comparar o arquivo com ele mesmo — um verificador que não verifica nada.
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

# O mapa vai para um array ANTES do laço, e não para o `stdin` dele. Com
# `done < "$mapa"`, um `sudo` que resolvesse pedir senha leria a próxima linha do
# mapa como se fosse a senha — engolindo a linha e falhando o sudo, as duas
# coisas em silêncio.
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
        if [ ! -w "$arq" ] && ! sudo -n true 2>/dev/null; then
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

total="$(grep -cvE '^[[:space:]]*(#|$)' "$MEOW_NOMES_MAPA" 2>/dev/null || printf 0)"

if [ "$falhou" = 1 ]; then
  meow_erro "algum nome não pôde ser reescrito"
  exit "$MEOW_ERRO"
fi

if [ "$pendente_sudo" -gt 0 ]; then
  if [ "$SEM_SUDO" = 1 ]; then
    meow_pula "$pendente_sudo nome(s) em /usr/share esperam root — rode: meow ativar"
  else
    meow_aviso "$pendente_sudo nome(s) precisam de sudo para encurtar"
    meow_info "rode o install.sh de novo com sudo disponível"
  fi
fi

if [ "$mudou" = 0 ] && [ "$pendente_sudo" = 0 ]; then
  meow_ok "nomes do lançador já curtos ($total no mapa, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

if [ "$CONFERIR" = 1 ]; then
  exit "$MEOW_DIVERGENTE"
fi

if [ "$mudou" = 1 ]; then
  # O lançador lê o cache de .desktop. Falhar aqui não é erro: o arquivo já está
  # no lugar certo, e a base é um índice de MIME, não a lista de aplicativos.
  if meow_tem update-desktop-database; then
    for dir in "${!DIRS_TOCADOS[@]}"; do
      if [ -w "$dir" ]; then
        update-desktop-database "$dir" 2>/dev/null || true
      else
        sudo -n update-desktop-database "$dir" 2>/dev/null || true
      fi
    done
  fi
  meow_ok "nomes do lançador encurtados"
  meow_info "vale no próximo início do lançador"
fi

exit "$MEOW_DIVERGENTE"
