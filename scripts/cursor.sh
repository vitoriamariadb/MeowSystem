#!/usr/bin/env bash
# cursor.sh — o ponteiro, que é o único elemento que atravessa a tela inteira o
# tempo todo e era o de fábrica.
#
# ONDE A CHAVE **NÃO** MORA, para ninguém refazer a procura
# `~/.config/cosmic/com.system76.CosmicTk/v1/` tem apply_theme_global,
# header_size, icon_theme, interface_density, interface_font e monospace_font.
#
#   A. `gsettings org.gnome.desktop.interface cursor-theme` — pega os apps GTK,
#      VALE NA HORA (a libgtk assina a mudança do GSettings; nada a reiniciar).
#   B. `~/.icons/default/index.theme` com `Inherits=<tema>` — pega o
#      `cosmic-comp`, e só VALE NO PRÓXIMO LOGIN, porque o compositor carrega o
#      tema de cursor uma vez, na subida.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Vazio = NÃO TOCA, exatamente como VIDRO_OPACIDADE_PAINEL/DOCK fazem. É o
# que permite ela desistir do tema sem desinstalar nada.
CURSOR="${CURSOR:-}"
CURSOR_VERSAO="${CURSOR_VERSAO:-v2.0.0}"

CURSOR_ICONES="$HOME/.local/share/icons"
CURSOR_DEFAULT_DIR="$HOME/.icons/default"
CURSOR_DEFAULT="$CURSOR_DEFAULT_DIR/index.theme"
CURSOR_CHAVE="org.gnome.desktop.interface"

# Elas já estavam aqui, escritas à mão dentro do `_cursor_instalado`. Com uma
# lista só não há como as duas divergirem no dia em que uma quarta raiz
# aparecer.
#
# A primeira é onde ESTE script instala; as outras duas são só de leitura — a
# TRAVA 1 do lib/comum.sh proíbe escrever em `/usr/share`.
CURSOR_RAIZES=("$CURSOR_ICONES" "$HOME/.icons" "/usr/share/icons")

# O que o `adicionar` acabou de pôr no disco — lido pelo `_cursor_dizer_como_usar`.
CURSOR_ADICIONADO=""

# A regra agora tem duas linhas, nesta ordem: se existir uma pasta com o nome
# EXATO em alguma das raízes, ela é o tema; senão, vale a convenção de antes.
_cursor_dir_exato() {
  local raiz
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz/$1" ] && { printf '%s/%s' "$raiz" "$1"; return 0; }
  done
  return 1
}
_cursor_dir_tema() {
  local exato; exato="$(_cursor_dir_exato "$1")" && { printf '%s' "$exato"; return; }
  printf '%s/%s-cursors' "$CURSOR_ICONES" "$1"
}
_cursor_nome_tema() {
  _cursor_dir_exato "$1" >/dev/null && { printf '%s' "$1"; return; }
  printf '%s-cursors' "$1"
}
_cursor_url() {
  printf 'https://github.com/catppuccin/cursors/releases/download/%s/%s-cursors.zip' \
         "$CURSOR_VERSAO" "$1"
}

# Agora um pack pode trazer o dele em `cursores/<nome>/cursors/`
# (`origens.cursores.proprio`), e é aqui que ele entra, ANTES da rede.
#
# O pack oferece; `CURSOR` vazio continua não tocando em nada, e um CURSOR que
# nomeia outro tema continua valendo — "o meow.conf vence o pack"
# (docs/PACKS.md).
CURSOR_PACK_LIDO=0
CURSOR_PACK_ID=""
CURSOR_PACK_DIR=""
CURSOR_PACK_VALOR=""
# O PONTEIRO QUE O PACK MANDA BAIXAR Vazios quando o pack traz o tema dentro
# dele (o `CURSOR_PACK_DIR` acima) ou não traz nada.
CURSOR_PACK_URL=""
CURSOR_PACK_SHA=""
CURSOR_PACK_PASTA=""

_cursor_ler_pack() {
  [ "$CURSOR_PACK_LIDO" = "1" ] && return 0
  CURSOR_PACK_LIDO=1
  meow_tem python3 || return 0
  local saida
  # `"$(meow_pack_dir)"` vazio é o pack padrão: o verbo trata o vazio como "o
  # pack ativo", a mesma porta do `meow_app_tema_do_pack`.
  #
  # Calado, o que sobrava na tela era a linha seguinte do `aplicar`: "não deu
  # para baixar (sem rede, ou release mudou)", o motivo errado para um pack
  # quebrado.
  saida="$(python3 "$MEOW_RAIZ/scripts/pack.py" ponteiro "$(meow_pack_dir)")" || return 0
  CURSOR_PACK_ID="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  CURSOR_PACK_DIR="$(printf '%s\n' "$saida" | sed -n 's/^dir=//p')"
  CURSOR_PACK_VALOR="$(printf '%s\n' "$saida" | sed -n 's/^valor=//p')"
  CURSOR_PACK_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  CURSOR_PACK_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  CURSOR_PACK_PASTA="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"
}

# 0 = este valor é o ponteiro que o pack traz, e é o pack que o resolve.
_cursor_do_pack() {
  _cursor_ler_pack
  [ -n "$CURSOR_PACK_VALOR" ] && [ -n "$CURSOR_PACK_DIR" ] && [ -d "$CURSOR_PACK_DIR/cursors" ] || return 1
  [ "$1" = "$CURSOR_PACK_VALOR" ] || return 1
  [ "$(_cursor_nome_tema "$1")" = "$1-cursors" ]
}

# O Dracula achou a origem do ponteiro dele: o `Dracula-cursors.tar.xz` do
# release v4.0.0 do `dracula/gtk`, com os mesmos 113 ponteiros que o
# `Dracula-Cursor` desta máquina, um a um.
#
# A MESMA TERCEIRA LINHA DA REGRA, e com a mesma condição: o valor é o do
# pack, e nenhum diretório de nome exato o sequestra.
#
# As duas oferecem "o que a chave aceita sem baixar nada", e este baixa.
_cursor_baixavel_do_pack() {
  _cursor_ler_pack
  [ -n "$CURSOR_PACK_URL" ] && [ "$1" = "$CURSOR_PACK_VALOR" ] || return 1
  [ "$(_cursor_nome_tema "$1")" = "$1-cursors" ]
}

# TUDO OU NADA, como o `_cursor_baixar_instalar`: desce para um temporário,
# confere o sha256 que o pack pinou, abre, confere que a pasta declarada é um
# tema de ponteiro sem link para fora, e só então entra pelo
# `_cursor_instalar_pasta`, com o nome que a chave usa.
_cursor_baixar_do_pack() {
  local valor="$1" tmp alvo real fora obtido f
  for f in curl tar sha256sum realpath; do
    meow_tem "$f" || { meow_erro "falta $f"; return "$MEOW_SEM_DEPENDENCIA"; }
  done
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor-pack.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "baixando o ponteiro '$valor' do pack $CURSOR_PACK_ID…"
  # O ponto na frente dos dois nomes de trabalho é o que os separa do diretório
  # renomeado lá embaixo: o valor da chave nunca começa por ponto.
  if ! _cursor_curl "$CURSOR_PACK_URL" "$tmp/.pacote"; then
    rm -rf "$tmp"
    meow_erro "não deu para baixar o ponteiro do pack $CURSOR_PACK_ID (sem rede?)"
    meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$CURSOR_PACK_SHA  $tmp/.pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$tmp/.pacote" | cut -d' ' -f1)"
    rm -rf "$tmp"
    meow_erro "sha256 do ponteiro não bate com o que o pack $CURSOR_PACK_ID pinou"
    meow_info "  esperado $CURSOR_PACK_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  mkdir "$tmp/.aberto" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  if ! tar -xf "$tmp/.pacote" -C "$tmp/.aberto" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o pacote do ponteiro veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi
  alvo="$tmp/.aberto/$CURSOR_PACK_PASTA"
  if [ ! -d "$alvo/cursors" ]; then
    rm -rf "$tmp"
    meow_erro "o pacote não tem '$CURSOR_PACK_PASTA/cursors' — o pack $CURSOR_PACK_ID declara a pasta errada?"
    return "$MEOW_ERRO"
  fi
  # O link que sai do tema iria junto no `cp -a` do `_cursor_instalar_pasta`, e
  # é a regra que o `pack.py` aplica ao ponteiro de dentro do pack.
  real="$(realpath -m -- "$alvo")"
  fora="$(find "$real" -type l -print0 | xargs -0 -r realpath -m -- 2>/dev/null \
            | grep -v -e "^$real/" -e "^$real\$" || true)"
  if [ -n "$fora" ]; then
    rm -rf "$tmp"
    meow_erro "o ponteiro do pack $CURSOR_PACK_ID tem link apontando para fora do tema — nada instalado"
    return "$MEOW_ERRO"
  fi
  # O diretório passa a chamar-se como a CHAVE, e o `_cursor_instalar_pasta`
  # põe o `-cursors` — o pacote do Dracula chama a pasta de `Dracula-cursors`,
  # que a chave escreveria como `Dracula`, e o valor do pack é `Dracula-Cursor`.
  mv -- "$alvo" "$tmp/$valor" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  _cursor_instalar_pasta "$tmp/$valor"; local rc=$?
  rm -rf "$tmp"
  return "$rc"
}

# O `index.theme` que faz o compositor obedecer. O `Comment=` não é enfeite: é a
# assinatura que o `remover` usa para saber se este arquivo é nosso.
_cursor_default_texto() {
  printf '[Icon Theme]\nName=Default\nComment=escrito pelo MeowSystem (scripts/cursor.sh)\nInherits=%s\n' \
         "$(_cursor_nome_tema "$1")"
}

_cursor_default_e_nosso() {
  [ -f "$CURSOR_DEFAULT" ] && grep -q 'MeowSystem' "$CURSOR_DEFAULT" 2>/dev/null
}

# SEM `DBUS_SESSION_BUS_ADDRESS`, o cliente do dconf não tem com quem falar e
# CRIA `~/.cache/dconf/user` sozinho — abrindo com O_RDWR|O_CREAT. Uma LEITURA
# que escreve.
#
# Isso deixou o `tests/seco.sh` vermelho: ele roda o `install.sh --dry-run` com
# `env -i` num HOME vazio, justamente para provar que o seco não escreve nada, e
# a fase de DETECÇÃO do cursor sujava o HOME.
_cursor_gsettings_ler() {
  if meow_seco && [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    DCONF_PROFILE=/dev/null gsettings "$@"
  else
    gsettings "$@"
  fi
}

# O valor EFETIVO do gsettings (default de esquema incluído), sem aspas.
_cursor_gsettings_valor() {
  meow_tem gsettings || return 1
  _cursor_gsettings_ler get "$CURSOR_CHAVE" cursor-theme 2>/dev/null | tr -d "'"
}

_cursor_tamanho() {
  meow_tem gsettings || { printf '24'; return; }
  _cursor_gsettings_ler get "$CURSOR_CHAVE" cursor-size 2>/dev/null || printf '24'
}

# O tema já está no disco? Aceita também um tema que ela tenha instalado por
# fora (ou que venha do sistema) — o que este script não faz é fingir que
# instalou o que não instalou.
_cursor_instalado() {
  local nome raiz; nome="$(_cursor_nome_tema "$1")"
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz/$nome/cursors" ] && return 0
  done
  return 1
}

# Os valores que a chave `CURSOR` aceita, um por linha, sem repetir.
#
# O QUE SE IMPRIME É O VALOR, E NÃO O NOME DA PASTA — E A DIFERENÇA JÁ CUSTOU
# QUATRO BOTÕES QUEBRADOS NA TELA DELA A pasta chama
# `catppuccin-mocha-light-cursors`; o valor que o `aplicar` resolve é
# `catppuccin-mocha-light`, porque o `_cursor_nome_tema` acrescenta o sufixo
# SEMPRE.
#
#     cursor.sh listar     catppuccin-mocha-light
#     painel               Adwaita Dracula-Cursor Pop catppuccin-mocha-light
_cursor_temas_instalados() (
  local raiz d nome
  shopt -s dotglob
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz" ] || continue
    for d in "$raiz"/*; do
      [ -d "$d/cursors" ] || continue
      nome="$(basename -- "$d")"
      _cursor_instalado "${nome%-cursors}" && printf '%s\n' "${nome%-cursors}"
    done
  done | LC_ALL=C sort -u
)

# --- instalação ------------------------------------------------------------
#
# Os dois querem exatamente o mesmo cuidado (falhar inteiro, com tempo-limite,
# sem seguir para o disco), e uma segunda invocação de `curl` escrita ao lado
# desta seria a segunda verdade sobre "como este projeto baixa arquivo" — a que
# ninguém corrige no dia em que a primeira ganhar um cabeçalho ou um limite
# novo.
_cursor_curl() {
  curl -sSL --fail --connect-timeout 15 --max-time 300 -o "$2" "$1" 2>/dev/null
}

# O tema são 121 arquivos; um download cortado no meio deixaria um diretório com
# metade dos ponteiros e o cursor sumindo em algumas formas e não em outras — o
# tipo de defeito que ninguém liga ao instalador.
_cursor_baixar_instalar() {
  local valor="$1" url tmp zip extraido origem destino
  url="$(_cursor_url "$valor")"
  destino="$(_cursor_dir_tema "$valor")"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  meow_tem curl  || { meow_erro "falta curl";  return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }

  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor.XXXXXX")" || return "$MEOW_ERRO"
  zip="$tmp/tema.zip"

  if ! _cursor_curl "$url" "$zip"; then
    rm -rf "$tmp"
    meow_erro "não deu para baixar o tema de cursor (sem rede, ou release mudou)"
    meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
    meow_aviso "para fazer à mão, quando houver rede:"
    meow_aviso "  curl -sSL -o /tmp/cursor.zip '$url'"
    meow_aviso "  mkdir -p '$CURSOR_ICONES' && unzip -q /tmp/cursor.zip -d '$CURSOR_ICONES'"
    meow_aviso "  $0 aplicar   # para apontar as chaves depois"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  extraido="$tmp/x"
  if ! unzip -q "$zip" -d "$extraido" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip do tema veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi

  origem="$extraido/$(_cursor_nome_tema "$valor")"
  if [ ! -d "$origem/cursors" ]; then
    rm -rf "$tmp"
    meow_erro "o pacote não tem '$(_cursor_nome_tema "$valor")/cursors' — nome de tema errado?"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$CURSOR_ICONES" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
  rm -rf "$destino"
  if ! mv -f "$origem" "$destino"; then
    rm -rf "$tmp"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi
  rm -rf "$tmp"

  # O manifesto é o que permite ao `--uninstall` saber o que é nosso.
  meow_manifesto_registrar "$destino/index.theme"
  return "$MEOW_OK"
}

# --- adicionar: um ponteiro de terceiro entra no disco ----------------------
#
# Nada de `eval`, nada de `shell=True`: o caminho e a URL entram citados em todo
# comando, o nome que sai de dentro do pacote é peneirado para `[A-Za-z0-9._-]`
# antes de virar diretório, e a extração acontece num temporário — nunca direto
# no destino.
_cursor_nome_seguro() {
  local n="$1"
  n="${n//[^A-Za-z0-9._-]/-}"      # só o alfabeto que um diretório de tema usa
  n="${n#"${n%%[!.-]*}"}"          # nada de nome começando por '.' ou '-'
  printf '%s' "${n:0:80}"
}

# O palpite de nome a partir do argumento. Vale SÓ no modo seco, onde não há
# pacote aberto para perguntar — e onde estar aproximadamente certo não custa
# nada, porque nada é escrito. Fora do seco, quem responde é o próprio conteúdo.
_cursor_nome_do_argumento() {
  local base="$1"
  base="${base%%\?*}"; base="${base%%#*}"    # a query string de uma URL não é nome
  base="$(basename -- "$base")"
  case "$base" in *.zip|*.ZIP) base="${base%.*}" ;; esac
  base="$(_cursor_nome_seguro "$base")"
  case "$base" in *-cursors) printf '%s' "${base%-cursors}" ;; *) printf '%s' "$base" ;; esac
}

# Instala UM diretório de tema (o que tem um `cursors/` dentro) em
# $CURSOR_ICONES. 0 = já estava idêntico · 1 = instalado/atualizado · 2 = erro.
#
# "Já existe um diretório com esse nome" responderia 0 para um tema instalado
# pela metade — que é exatamente o estado que o `_cursor_baixar_instalar`
# inteiro existe para evitar.
_cursor_instalar_pasta() {
  local origem="$1" nome destino
  nome="$(_cursor_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  case "$nome" in *-cursors) : ;; *) nome="$nome-cursors" ;; esac
  destino="$CURSOR_ICONES/$nome"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq --no-dereference -- "$origem" "$destino" >/dev/null 2>&1; then
        meow_ok "'$nome' já está instalado e idêntico"
        CURSOR_ADICIONADO="${nome%-cursors}"
        return "$MEOW_OK"
      fi
      meow_info "'$nome' está no disco e difere do pacote — substituindo"
    else
      meow_ok "'$nome' já está instalado (sem 'diff' para comparar o conteúdo)"
      CURSOR_ADICIONADO="${nome%-cursors}"
      return "$MEOW_OK"
    fi
  fi

  if meow_seco; then
    meow_muda "instalaria o ponteiro '$nome' em $CURSOR_ICONES"
    CURSOR_ADICIONADO="${nome%-cursors}"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$CURSOR_ICONES" || { meow_erro "não consegui criar $CURSOR_ICONES"; return "$MEOW_ERRO"; }
  # O temporário nasce DENTRO de $CURSOR_ICONES: o `mv` final é rename no mesmo
  # sistema de arquivos, e um corte no meio nunca deixa meio tema com o nome
  # definitivo (TRAVA 2 do lib/comum.sh — o pacote costuma vir de /tmp, que
  # nesta máquina é outro dispositivo).
  local palco
  palco="$(mktemp -d -p "$CURSOR_ICONES" ".meow-cursor.XXXXXX")" || return "$MEOW_ERRO"
  if ! cp -a -- "$origem/." "$palco/"; then
    rm -rf "$palco"; meow_erro "não consegui copiar o tema '$nome'"; return "$MEOW_ERRO"
  fi
  chmod 755 "$palco"
  rm -rf "$destino"
  if ! mv -f "$palco" "$destino"; then
    rm -rf "$palco"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi

  # O manifesto é o que permite ao `--uninstall` saber o que é nosso — mesma
  # linha que o `_cursor_baixar_instalar` grava. Tema sem `index.theme` existe
  # (pacote enxuto), e aí o marcador é o próprio diretório de ponteiros.
  if [ -f "$destino/index.theme" ]; then
    meow_manifesto_registrar "$destino/index.theme"
  else
    meow_manifesto_registrar "$destino/cursors"
  fi
  meow_muda "ponteiro '$nome' instalado em $destino"
  CURSOR_ADICIONADO="${nome%-cursors}"
  return "$MEOW_DIVERGENTE"
}

# Os diretórios de tema dentro de uma árvore recém-aberta: os que têm `cursors/`.
# `-maxdepth 3` cobre as duas formas que um pacote de ponteiro usa — o tema na
# raiz do zip, e o tema dentro de uma pasta com o nome da release.
_cursor_colher_temas() {
  find "$1" -maxdepth 3 -type d -name cursors -print0 2>/dev/null
}

cmd_adicionar() {
  local alvo="${1:-}"
  if [ -z "$alvo" ]; then
    meow_erro "uso: cursor.sh adicionar <url-ou-zip-ou-pasta>"
    return "$MEOW_ERRO"
  fi

  CURSOR_ADICIONADO=""
  local rc="$MEOW_OK" achou=0

  # ── uma pasta já aberta: nada a baixar nem a extrair ──────────────────────
  if [ -d "$alvo" ]; then
    if [ -d "$alvo/cursors" ]; then
      _cursor_instalar_pasta "$alvo"; rc=$?
      [ "$rc" -le 1 ] && achou=1
    else
      local d
      while IFS= read -r -d '' d; do
        _cursor_instalar_pasta "$(dirname -- "$d")"; local e=$?
        [ "$e" -ge 2 ] && return "$e"
        [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
        achou=1
      done < <(_cursor_colher_temas "$alvo")
    fi
    [ "$achou" = "1" ] || { meow_erro "não achei nenhum 'cursors/' dentro de '$alvo'"; return "$MEOW_ERRO"; }
    meow_registrar "cursor.sh adicionar '$alvo' -> ${CURSOR_ADICIONADO:-?}"
    _cursor_dizer_como_usar
    return "$rc"
  fi

  # ── no seco não se baixa nem se extrai ────────────────────────────────────
  # Extrair é escrever, e `MEOW_SECO=1` promete não escrever NADA — o
  # `tests/seco.sh` roda num HOME de brinquedo justamente para pegar quem
  # escreve "só num temporário".
  if meow_seco; then
    local palpite; palpite="$(_cursor_nome_do_argumento "$alvo")"
    if [ -n "$palpite" ] && _cursor_instalado "$palpite"; then
      meow_ok "'$(_cursor_nome_tema "$palpite")' já está instalado"
      return "$MEOW_OK"
    fi
    meow_muda "instalaria um ponteiro de '$alvo' em $CURSOR_ICONES"
    meow_info "  no seco o nome é palpite pelo arquivo; quem decide é o conteúdo do pacote"
    return "$MEOW_DIVERGENTE"
  fi

  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }

  local tmp zip
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor-add.XXXXXX")" || return "$MEOW_ERRO"
  zip="$tmp/pacote.zip"

  case "$alvo" in
    http://*|https://*)
      meow_tem curl || { rm -rf "$tmp"; meow_erro "falta curl"; return "$MEOW_SEM_DEPENDENCIA"; }
      meow_info "baixando $alvo…"
      if ! _cursor_curl "$alvo" "$zip"; then
        rm -rf "$tmp"
        meow_erro "não deu para baixar '$alvo' (sem rede, endereço errado, ou 404)"
        meow_aviso "nada foi instalado — o cursor continua exatamente como estava."
        return "$MEOW_SEM_DEPENDENCIA"
      fi
      ;;
    *)
      if [ ! -f "$alvo" ]; then
        rm -rf "$tmp"; meow_erro "não achei '$alvo'"; return "$MEOW_ERRO"
      fi
      case "$alvo" in
        *.zip|*.ZIP) : ;;
        *) rm -rf "$tmp"
           meow_erro "só sei abrir .zip aqui (ou uma pasta de tema já aberta)"
           meow_info "  '$alvo' não é nenhum dos dois"
           return "$MEOW_ERRO" ;;
      esac
      cp -- "$alvo" "$zip" || { rm -rf "$tmp"; meow_erro "não consegui ler '$alvo'"; return "$MEOW_ERRO"; }
      ;;
  esac

  local extraido="$tmp/x"
  if ! unzip -q -o "$zip" -d "$extraido" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi

  local d
  while IFS= read -r -d '' d; do
    _cursor_instalar_pasta "$(dirname -- "$d")"; local e=$?
    if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
    [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
    achou=1
  done < <(_cursor_colher_temas "$extraido")
  rm -rf "$tmp"

  if [ "$achou" = "0" ]; then
    meow_erro "o pacote não tem nenhuma pasta 'cursors/' dentro — não é tema de ponteiro"
    return "$MEOW_ERRO"
  fi

  meow_registrar "cursor.sh adicionar '$alvo' -> ${CURSOR_ADICIONADO:-?}"
  _cursor_dizer_como_usar
  return "$rc"
}

# Instalar não é escolher: o tema entra no disco e a chave `CURSOR` continua
# onde estava. Dizer isto é o que impede o "instalei e não mudou nada".
_cursor_dizer_como_usar() {
  [ -n "$CURSOR_ADICIONADO" ] || return 0
  [ "$CURSOR_ADICIONADO" = "$CURSOR" ] && return 0
  meow_info "para usá-lo: CURSOR=\"$CURSOR_ADICIONADO\" no meow.conf, e depois 'meow aplicar'"
}

# --- comandos ---------------------------------------------------------------
cmd_aplicar() {
  if [ -z "$CURSOR" ]; then
    meow_pula "CURSOR vazio — o tema de cursor não é tocado"
    return "$MEOW_OK"
  fi
  meow_tem gsettings || { meow_erro "falta gsettings (libglib2.0-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }

  local nome rc=0 mudou=0
  nome="$(_cursor_nome_tema "$CURSOR")"

  # 1. o tema no disco
  #
  # Não é "instala se faltar": o `_cursor_instalar_pasta` compara por conteúdo
  # (`diff -rq --no-dereference`) e diz "já está instalado e idêntico" quando
  # nada mudou.
  if _cursor_do_pack "$CURSOR"; then
    meow_info "o ponteiro '$CURSOR' vem do pack $CURSOR_PACK_ID — sem rede"
    _cursor_instalar_pasta "$CURSOR_PACK_DIR"; rc=$?
    [ "$rc" -ge 2 ] && return "$rc"
    [ "$rc" = "1" ] && mudou=1
    rc=0
  elif _cursor_instalado "$CURSOR"; then
    meow_ok "tema de cursor '$nome' já está instalado"
  # O PACK MANDA BAIXAR: antes do release do Catppuccin, que não tem este
  # nome e sairia num 404 — o `CURSOR="Dracula-Cursor"` numa máquina sem o
  # diretório ia buscar um `Dracula-Cursor-cursors.zip` que o
  # `catppuccin/cursors` nunca publicou.
  elif _cursor_baixavel_do_pack "$CURSOR"; then
    if meow_seco; then
      meow_muda "baixaria o ponteiro '$CURSOR' do pack $CURSOR_PACK_ID (sha256 pinado) e o instalaria em $CURSOR_ICONES"
      mudou=1
    else
      _cursor_baixar_do_pack "$CURSOR"; rc=$?
      [ "$rc" -le 1 ] || return "$rc"
      [ "$rc" = "1" ] && mudou=1
      rc=0
    fi
  else
    if meow_seco; then
      meow_muda "baixaria e instalaria '$nome' em $CURSOR_ICONES"
      mudou=1
    else
      meow_info "baixando '$nome' ($CURSOR_VERSAO)…"
      _cursor_baixar_instalar "$CURSOR"; rc=$?
      [ "$rc" -eq 0 ] || return "$rc"
      meow_muda "tema de cursor instalado em $(_cursor_dir_tema "$CURSOR")"
      mudou=1
    fi
  fi

  # 2. alavanca A — os apps GTK (vale na hora)
  local atual; atual="$(_cursor_gsettings_valor)"
  if [ "$atual" = "$nome" ]; then
    meow_ok "gsettings cursor-theme já é '$nome'"
  elif meow_seco; then
    meow_muda "gsettings cursor-theme: '$atual' -> '$nome'"; mudou=1
  else
    if ! gsettings set "$CURSOR_CHAVE" cursor-theme "$nome" 2>/dev/null; then
      meow_erro "gsettings recusou escrever cursor-theme"; return "$MEOW_ERRO"
    fi
    if [ "$(_cursor_gsettings_valor)" = "$nome" ]; then
      meow_muda "gsettings cursor-theme: '$atual' -> '$nome' (apps GTK, já vale)"
      mudou=1
    else
      meow_pula "o gsettings aceitou cursor-theme e não guardou (sem barramento de sessão)"
      meow_info "  o cursor do compositor abaixo não depende disto e continua valendo"
    fi
  fi

  # 3. alavanca B — o compositor (vale no próximo login)
  local texto divergente=0; texto="$(_cursor_default_texto "$CURSOR")"
  if [ -f "$CURSOR_DEFAULT" ] && ! _cursor_default_e_nosso; then
    meow_aviso "$CURSOR_DEFAULT existe e NÃO é nosso — não vou sobrescrever."
    meow_aviso "o cursor do desktop continuará o que esse arquivo mandar."
    divergente=1
  else
    meow_escrever "$CURSOR_DEFAULT" "$texto" 644; local e=$?
    case "$e" in
      0) meow_ok "$CURSOR_DEFAULT já apontava para '$nome'" ;;
      1) meow_muda "$CURSOR_DEFAULT -> Inherits=$nome (compositor, no próximo login)"
         mudou=1 ;;
      *) meow_erro "falha ao escrever $CURSOR_DEFAULT"; return "$MEOW_ERRO" ;;
    esac
  fi

  meow_info "tamanho em vigor: $(_cursor_tamanho) (não é imposto por este script)"
  [ "$mudou" = "1" ] && ! meow_seco && \
    meow_info "o cursor do DESKTOP só troca no próximo login; o das janelas GTK já trocou"

  meow_registrar "cursor.sh aplicar tema=$nome mudou=$mudou"
  { [ "$mudou" = "1" ] || [ "$divergente" = "1" ]; } && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

cmd_conferir() {
  [ -z "$CURSOR" ] && { meow_pula "CURSOR vazio — nada a conferir"; return "$MEOW_OK"; }
  meow_tem gsettings || { meow_erro "falta gsettings"; return "$MEOW_SEM_DEPENDENCIA"; }

  local nome rc="$MEOW_OK"
  nome="$(_cursor_nome_tema "$CURSOR")"

  if ! _cursor_instalado "$CURSOR"; then
    meow_muda "tema de cursor '$nome' não está instalado"; rc="$MEOW_DIVERGENTE"
  # A cópia instalada de um ponteiro do pack tem de ser a do pack: é o mesmo
  # `diff -rq --no-dereference` que o `aplicar` usa para decidir se refaz —
  # conferir por uma régua e aplicar por outra faria o doctor e o instalador
  # discordarem.
  elif _cursor_do_pack "$CURSOR" && meow_tem diff \
       && ! diff -rq --no-dereference -- "$CURSOR_PACK_DIR" "$CURSOR_ICONES/$nome" >/dev/null 2>&1; then
    meow_muda "tema '$nome' instalado difere do que o pack $CURSOR_PACK_ID traz"
    rc="$MEOW_DIVERGENTE"
  else
    meow_ok "tema '$nome' instalado"
  fi

  local atual; atual="$(_cursor_gsettings_valor)"
  if [ "$atual" = "$nome" ]; then
    meow_ok "gsettings cursor-theme = '$nome'"
  else
    meow_muda "gsettings cursor-theme = '$atual' (esperado '$nome')"; rc="$MEOW_DIVERGENTE"
  fi

  if [ -f "$CURSOR_DEFAULT" ] && grep -q "Inherits=$nome\$" "$CURSOR_DEFAULT" 2>/dev/null; then
    meow_ok "$CURSOR_DEFAULT aponta para '$nome'"
  else
    meow_muda "$CURSOR_DEFAULT não aponta para '$nome' (cursor do desktop divergente)"
    rc="$MEOW_DIVERGENTE"
  fi

  return "$rc"
}

# Diz, sem escrever nada, qual cursor cada METADE da tela está usando — que é a
# pergunta que o gsettings sozinho responde errado.
cmd_estado() {
  local gtk desktop=""
  gtk="$(_cursor_gsettings_valor)"
  meow_info "janelas GTK  : '$gtk'   (via gsettings $CURSOR_CHAVE cursor-theme)"

  if [ -f "$CURSOR_DEFAULT" ]; then
    desktop="$(sed -n 's/^Inherits=//p' "$CURSOR_DEFAULT" | head -1)"
    meow_info "desktop      : '$desktop'   (via $CURSOR_DEFAULT)"
    _cursor_default_e_nosso && meow_ok "esse index.theme é do MeowSystem" \
                            || meow_aviso "esse index.theme NÃO é nosso"
  elif [ -f /usr/share/icons/default/index.theme ]; then
    desktop="$(sed -n 's/^Inherits=//p' /usr/share/icons/default/index.theme | head -1)"
    meow_info "desktop      : '$desktop'   (via /usr/share/icons/default/index.theme — o de fábrica)"
    meow_aviso "não há ~/.icons/default: o cursor do desktop é o do sistema, e o"
    meow_aviso "'$gtk' do gsettings NÃO o alcança."
  fi

  [ -n "$gtk" ] && [ -n "$desktop" ] && [ "$gtk" != "$desktop" ] && \
    meow_aviso "as duas metades da tela estão com cursores DIFERENTES"

  meow_info "tamanho: $(_cursor_tamanho)"
  meow_info "XCURSOR_THEME='${XCURSOR_THEME:-}' XCURSOR_SIZE='${XCURSOR_SIZE:-}' (vazio = o compositor usa 'default'/24)"
  return "$MEOW_OK"
}

# A LISTA É DADO, NÃO RELATÓRIO — por isso ela sai limpa no stdout Quem chama é
# a página, que quer um valor por linha e nada mais.
cmd_listar() {
  { _cursor_temas_instalados
    _cursor_ler_pack
    _cursor_do_pack "$CURSOR_PACK_VALOR" && printf '%s\n' "$CURSOR_PACK_VALOR"
  } | LC_ALL=C sort -u
  return "$MEOW_OK"
}

# `remover` sem argumento é o de sempre: desliga as duas alavancas e apaga o
# tema do `$CURSOR`.
cmd_remover() {
  if [ -n "${1:-}" ]; then
    _cursor_remover_tema "$1"
    return $?
  fi
  local mudou=0 nome=""
  [ -n "$CURSOR" ] && nome="$(_cursor_nome_tema "$CURSOR")"

  # 1. o gsettings volta ao ESTADO ANTERIOR, que era "nada gravado" — ver o
  #    cabeçalho. O `reset` faz o valor efetivo voltar a 'Pop' pelo override.
  if meow_tem gsettings; then
    local atual; atual="$(_cursor_gsettings_valor)"
    if [ -n "$nome" ] && [ "$atual" != "$nome" ]; then
      meow_pula "gsettings cursor-theme já não é nosso ('$atual')"
    elif meow_seco; then
      meow_muda "faria gsettings reset cursor-theme (voltaria a '$(gsettings get "$CURSOR_CHAVE" cursor-theme 2>/dev/null)')"
      mudou=1
    else
      gsettings reset "$CURSOR_CHAVE" cursor-theme 2>/dev/null
      meow_muda "gsettings cursor-theme devolvido ao padrão ('$(_cursor_gsettings_valor)')"
      mudou=1
    fi
  fi

  # 2. o index.theme do compositor — só se for nosso
  if [ -f "$CURSOR_DEFAULT" ]; then
    if _cursor_default_e_nosso; then
      if meow_seco; then
        meow_muda "removeria $CURSOR_DEFAULT"; mudou=1
      else
        rm -f "$CURSOR_DEFAULT"
        # rmdir só apaga vazio: se ela puser outro tema em ~/.icons, fica.
        rmdir "$CURSOR_DEFAULT_DIR" 2>/dev/null
        meow_muda "$CURSOR_DEFAULT removido (o desktop volta ao de fábrica no próximo login)"
        mudou=1
      fi
    else
      meow_pula "$CURSOR_DEFAULT não é nosso — preservado"
    fi
  fi

  # 3. o tema no disco. Só o que ESTE script instalou (o de ~/.local/share/icons);
  #    tema do sistema não é nosso para apagar.
  if [ -n "$CURSOR" ]; then
    local dir; dir="$(_cursor_dir_tema "$CURSOR")"
    if [ -d "$dir" ]; then
      if meow_seco; then
        meow_muda "removeria $dir"; mudou=1
      else
        meow_destino_permitido "$dir" && { rm -rf "$dir"; meow_muda "tema removido: $dir"; mudou=1; }
      fi
    fi
  fi

  [ "$mudou" = "0" ] && { meow_pula "nada a remover"; return "$MEOW_OK"; }
  meow_registrar "cursor.sh remover"
  return "$MEOW_DIVERGENTE"
}

# Apaga UM tema pelo valor — o desfazer do `adicionar`.
#
# Tema que veio de `/usr/share/icons` é do gerenciador de pacotes (a TRAVA 1
# recusaria o caminho de qualquer jeito) e tema em `~/.icons` não foi este
# script que pôs lá.
_cursor_remover_tema() {
  local valor nome dir
  valor="$(_cursor_nome_seguro "${1%-cursors}")"
  [ -n "$valor" ] || { meow_erro "uso: cursor.sh remover <valor>"; return "$MEOW_ERRO"; }
  nome="$(_cursor_nome_tema "$valor")"
  dir="$CURSOR_ICONES/$nome"

  if [ ! -d "$dir" ]; then
    meow_pula "'$nome' não está em $CURSOR_ICONES — nada a remover"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$dir" || return "$MEOW_ERRO"

  if meow_seco; then
    meow_muda "removeria $dir"
    return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$dir" || { meow_erro "não consegui remover $dir"; return "$MEOW_ERRO"; }
  meow_muda "ponteiro '$nome' removido de $CURSOR_ICONES"
  [ "$valor" = "$CURSOR" ] && \
    meow_aviso "esse era o tema do CURSOR — o desktop volta ao de fábrica no próximo login"
  meow_registrar "cursor.sh remover $nome"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)   cmd_aplicar ;;
  conferir)  cmd_conferir ;;
  estado)    cmd_estado ;;
  listar)    cmd_listar ;;
  adicionar) cmd_adicionar "${2:-}" ;;
  remover)   cmd_remover "${2:-}" ;;
  *) meow_erro "uso: cursor.sh {aplicar|conferir|estado|listar|adicionar <url-ou-zip-ou-pasta>|remover [valor]}"
     exit "$MEOW_ERRO" ;;
esac
