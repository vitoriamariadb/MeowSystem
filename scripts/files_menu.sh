#!/usr/bin/env bash
# files_menu.sh — "Próximo papel de parede" e "Papel de parede anterior" no menu
# de contexto da área de trabalho, e o que faz isso sobreviver a um apt upgrade.
#
#   ./files_menu.sh aplicar     põe o binário patchado no lugar (ou avisa que falta build)
#   ./files_menu.sh build       baixa o fonte da versão INSTALADA, patcha e compila
#   ./files_menu.sh --conferir  0 = no ar · 1 = divergente · 3 = falta dependência
#   ./files_menu.sh estado      diagnóstico
#   ./files_menu.sh remover     tira o nosso e devolve o do pacote
#
# ============================================================================
# 1. QUEM DESENHA A ÁREA DE TRABALHO NÃO É O `cosmic-files`
# ============================================================================
# É o `cosmic-files-applet`, e descobrir isso custou um build inteiro. Medido em
# 01/09/2026: o `src/main.rs` do `cosmic-files` chama `cosmic_files::main()`
# (modo App), e quem chama `cosmic_files::desktop()` — o que fixa
# `app::Mode::Desktop`, o único modo em que o bloco de papel de parede do menu
# aparece — é `cosmic-files-applet/src/main.rs`. Os dois vêm do MESMO pacote e
# da MESMA lib, então o patch é um só; o que muda é que são DOIS binários a
# instalar. Instalar só o primeiro compila, instala, não dá erro nenhum e não
# muda um item no menu dela.
#
# ============================================================================
# 2. POR QUE `~/.local/bin/` E NÃO `/usr/bin/`
# ============================================================================
# A TRAVA 1 do `lib/comum.sh` recusa `/usr/bin` — e está certa: é território do
# gerenciador de pacotes, e um `apt upgrade` sobrescreve. O `cosmic-files` subiu
# de versão DUAS vezes na semana de 25/08 a 01/09/2026; escrever ali seria
# refazer o trabalho a cada atualização, com janela de binário sobrescrito no
# meio.
#
# `~/.local/bin` VEM ANTES DE `/usr/bin` NO PATH DA SESSÃO DELA — medido no
# `environ` dos processos vivos em 01/09/2026:
#     PATH=~/.cargo/bin:~/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:…
# e os dois são lançados por NOME, não por caminho absoluto: o `.desktop` do
# pacote diz `Exec=cosmic-files %U`, e o applet nasce como filho do
# `cosmic-panel` com a cmdline `cosmic-files-applet`. Então um arquivo nosso em
# `~/.local/bin` vence o do pacote no próximo lançamento, sem sudo, sem tocar em
# território de ninguém, e sem que um `apt upgrade` tenha o que desfazer.
#
# ============================================================================
# 3. A REGRA QUE IMPEDE O BINÁRIO VELHO DE FICAR NO AR: FALHAR PARA O UPSTREAM
# ============================================================================
# O artefato é guardado POR VERSÃO DO PACOTE. Quando o `apt` sobe a versão e não
# há artefato para a nova, este script REMOVE os nossos e deixa o do pacote
# valer — perde-se os dois itens do menu até o próximo build, e ganha-se a
# certeza de que ela nunca fica com um gerenciador de arquivos de uma semana
# atrás vencendo o que o apt acabou de instalar.
#
# É O CONTRÁRIO DO QUE O `aurora-cosmic-comp-ws.sh` FAZ, e de propósito: lá o
# binário patchado é o compositor, e ficar sem ele é ficar sem sessão, então
# vale segurar o velho até o build novo. Aqui o custo de falhar para o upstream
# é dois itens de menu a menos por alguns minutos.
#
# ============================================================================
# 4. O BUILD, E POR QUE ELE NÃO RODA DENTRO DE UM TIQUE
# ============================================================================
# São 161 MB de fonte e ~4 min de compilação (medido: 28,9 s para o
# `cosmic-files` e 1 min 23 s para o applet, incrementais, sobre uma árvore já
# construída; a primeira vez é bem mais). Um `--conferir` que compilasse
# seguraria o `meow doctor` por minutos. Então:
#   `aplicar`/`--conferir`  nunca compilam;
#   `build`                 compila, e é o que ela (ou o auto-build) chama;
#   auto-build              `systemd-run` numa unit transitória de nome fixo,
#                           Nice=19 e IO idle, no máximo 3 tentativas por versão.
# As guardas são as mesmas do irmão do cosmic-comp, pelas mesmas razões
# medidas lá: unit de nome fixo não empilha, carimbo por versão limita as
# tentativas, e jogo aberto adia.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FILES_MENU="${FILES_MENU:-sim}"
FILES_MENU_AUTOBUILD="${FILES_MENU_AUTOBUILD:-sim}"

PATCH="$MEOW_RAIZ/patches/cosmic-files-wallpaper-menu.patch"
MARCA="MEOW-FILES-WALLPAPER-PATCH-1"
BINS=(cosmic-files cosmic-files-applet)
DESTINO="$HOME/.local/bin"
GUARDA="$MEOW_ESTADO/cosmic-files"
MAX_TENTATIVAS=3

versao_do_pacote() { dpkg-query -W -f='${Version}' cosmic-files 2>/dev/null; }
# `/` não aparece em versão de deb, mas `:` (epoch) e `~` aparecem; nenhum deles
# atrapalha num nome de diretório. Fica o nome cru, para o `estado` poder ser
# lido contra o `dpkg -l` sem tradução no meio.
artefato_de() { printf '%s/%s' "$GUARDA" "$1"; }
tentativa_de() { printf '%s/%s.tentado' "$GUARDA" "$1"; }

# O binário QUE VAI SER LANÇADO, resolvido pelo PATH como o COSMIC o resolve.
# Perguntar por `/usr/bin/cosmic-files` responderia sobre o pacote, não sobre o
# que ela vai executar — e é a segunda pergunta que importa.
qual_no_path() { command -v "$1" 2>/dev/null; }
patchado() { grep -a -q -- "$MARCA" "$1" 2>/dev/null; }

# 0 = os dois binários no PATH são os nossos.
tudo_no_ar() {
  local b p
  for b in "${BINS[@]}"; do
    p="$(qual_no_path "$b")" || return 1
    [ -n "$p" ] && patchado "$p" || return 1
  done
  return 0
}

remover_nossos() {
  local b n=0
  for b in "${BINS[@]}"; do
    [ -f "$DESTINO/$b" ] || continue
    if meow_seco; then meow_muda "removeria $DESTINO/$b"; n=1; continue; fi
    rm -f "$DESTINO/$b" && n=1
  done
  return "$n"
}

# ------------------------------------------------------------------ aplicar --
cmd_aplicar() {
  local ver dir b mudou=0
  [ "$FILES_MENU" = "sim" ] || {
    remover_nossos && meow_muda "FILES_MENU=\"$FILES_MENU\" — itens de papel de parede removidos do menu" \
                   || meow_pula "FILES_MENU=\"$FILES_MENU\" — o menu de contexto fica de fábrica"
    return "$MEOW_OK"; }

  ver="$(versao_do_pacote)"
  [ -n "$ver" ] || { meow_pula "o cosmic-files não está instalado por pacote — nada a vestir"; return "$MEOW_SEM_DEPENDENCIA"; }
  dir="$(artefato_de "$ver")"

  # A REGRA 3 DO CABEÇALHO, e ela vem ANTES de qualquer coisa: sem artefato para
  # a versão de agora, o nosso sai da frente. Um binário de outra versão
  # vencendo o que o apt acabou de instalar é pior que dois itens de menu a
  # menos.
  if [ ! -d "$dir" ]; then
    remover_nossos && mudou=1
    meow_aviso "não há build patchado para o cosmic-files $ver — o do pacote está valendo"
    if [ "$mudou" = "1" ]; then
      meow_info "  (removi o nosso, que era de outra versão)"
    fi
    disparar_autobuild "$ver" || meow_info "  para construir agora: meow files-menu build"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$DESTINO" 2>/dev/null || { meow_erro "não consegui criar $DESTINO"; return "$MEOW_ERRO"; }
  for b in "${BINS[@]}"; do
    [ -f "$dir/$b" ] || { meow_erro "artefato incompleto: falta $dir/$b"; return "$MEOW_ERRO"; }
    if [ -f "$DESTINO/$b" ] && cmp -s "$dir/$b" "$DESTINO/$b"; then continue; fi
    if meow_seco; then meow_muda "instalaria $DESTINO/$b (patchado, $ver)"; mudou=1; continue; fi
    # Temporário no diretório de DESTINO e `mv` (TRAVA 2): um binário pela
    # metade em `~/.local/bin` é um app que não abre, e o `cp` direto sobre um
    # arquivo em execução devolve ETXTBSY.
    local tmp; tmp="$(mktemp -p "$DESTINO" ".meow-cf.XXXXXX")" || return "$MEOW_ERRO"
    cp -f "$dir/$b" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$DESTINO/$b" \
      || { rm -f "$tmp"; meow_erro "não consegui instalar $b"; return "$MEOW_ERRO"; }
    meow_manifesto_registrar "$DESTINO/$b"
    mudou=1
  done

  meow_seco && { [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"; return "$MEOW_OK"; }
  if [ "$mudou" = "1" ]; then
    meow_ok "menu de contexto vestido: avançar e voltar papel de parede ($ver)"
    meow_info "  vale nas janelas NOVAS; a área de trabalho pega no próximo login"
    meow_info "  ou agora, com: meow painel reciclar"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "menu de contexto já tem avançar/voltar papel de parede ($ver)"
  return "$MEOW_OK"
}

# -------------------------------------------------------------------- build --
cmd_build() {
  local ver dir tmpdir fonte
  ver="$(versao_do_pacote)"
  [ -n "$ver" ] || { meow_erro "o cosmic-files não está instalado por pacote"; return "$MEOW_SEM_DEPENDENCIA"; }
  dir="$(artefato_de "$ver")"
  [ -f "$PATCH" ] || { meow_erro "falta $PATCH"; return "$MEOW_ERRO"; }
  meow_tem cargo   || { meow_erro "falta o cargo (rustup ou o pacote cargo)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem apt-get || { meow_erro "falta apt-get";                            return "$MEOW_SEM_DEPENDENCIA"; }

  if [ -d "$dir" ] && [ -f "$dir/cosmic-files-applet" ]; then
    meow_ok "já existe build patchado para $ver — nada a compilar"
    return "$MEOW_OK"
  fi
  meow_seco && { meow_muda "compilaria o cosmic-files $ver patchado (~161 MB de fonte, minutos)"; return "$MEOW_DIVERGENTE"; }

  tmpdir="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-cf.XXXXXX)" || return "$MEOW_ERRO"
  # `trap` e não `rm` no fim: são 161 MB, e um build interrompido no meio não
  # pode deixá-los no /tmp dela.
  trap 'rm -rf "$tmpdir"' RETURN

  meow_info "baixando o fonte do cosmic-files $ver…"
  ( cd "$tmpdir" && apt-get source cosmic-files ) >/dev/null 2>&1 \
    || { meow_erro "apt-get source falhou — o deb-src está habilitado?"; return "$MEOW_ERRO"; }
  fonte="$(find "$tmpdir" -maxdepth 1 -type d -name 'cosmic-files-*' | head -1)"
  [ -n "$fonte" ] || { meow_erro "não achei a árvore de fonte baixada"; return "$MEOW_ERRO"; }

  # IDEMPOTÊNCIA POR MARCADOR, NUNCA PELO CÓDIGO DE SAÍDA DO `patch`:
  # `patch --forward` devolve 1 tanto para "já aplicado" quanto para erro. É a
  # mesma lição que o `patches/LEIA-ME.txt` registra ter custado caro.
  if ! grep -rq -- "$MARCA" "$fonte/src/app.rs" 2>/dev/null; then
    ( cd "$fonte" && patch -p1 --forward < "$PATCH" ) >/dev/null 2>&1
    grep -q -- "$MARCA" "$fonte/src/app.rs" \
      || { meow_erro "o patch não aplicou nesta versão — o upstream mexeu no menu"; return "$MEOW_ERRO"; }
  fi

  meow_info "compilando (Nice=19, pode levar minutos)…"
  ( cd "$fonte" && tar pxf vendor.tar 2>/dev/null
    nice -n 19 cargo build --release --frozen --offline \
      && nice -n 19 cargo build --package cosmic-files-applet --release --frozen --offline ) >/dev/null 2>&1 \
    || { meow_erro "o cargo falhou"; return "$MEOW_ERRO"; }

  local b
  for b in "${BINS[@]}"; do
    patchado "$fonte/target/release/$b" \
      || { meow_erro "o binário $b saiu SEM o marcador $MARCA — build inútil"; return "$MEOW_ERRO"; }
  done
  mkdir -p "$dir" || return "$MEOW_ERRO"
  for b in "${BINS[@]}"; do
    cp -f "$fonte/target/release/$b" "$dir/$b" && chmod 755 "$dir/$b" \
      || { meow_erro "não consegui guardar $b"; return "$MEOW_ERRO"; }
  done
  meow_ok "build patchado do cosmic-files $ver guardado em $dir"
  meow_registrar "files_menu.sh build $ver"
  cmd_aplicar
  return "$MEOW_DIVERGENTE"
}

# --- auto-build: as mesmas quatro guardas do irmão do cosmic-comp ------------
jogo_aberto() { pgrep -f "SteamLaunch[ ]AppId=[0-9]" >/dev/null 2>&1; }
disparar_autobuild() {
  local ver="$1" n f
  [ "$FILES_MENU_AUTOBUILD" = "sim" ] || return 1
  meow_seco && return 1
  meow_tem systemd-run || return 1
  jogo_aberto && { meow_info "  auto-build adiado: jogo aberto"; return 0; }

  f="$(tentativa_de "$ver")"; n=0; [ -f "$f" ] && n="$(wc -l < "$f")"
  if [ "$n" -ge "$MAX_TENTATIVAS" ]; then
    meow_aviso "  auto-build esgotado: $n tentativas para $ver falharam — precisa de olho humano"
    meow_info  "  o log de cada uma: journalctl --user -u meow-files-menu-build"
    return 0
  fi
  mkdir -p "$GUARDA"; printf '%s tentativa %s/%s\n' "$(date -Is)" "$((n+1))" "$MAX_TENTATIVAS" >> "$f"

  # Unit de NOME FIXO: o systemd recusa a segunda enquanto a primeira roda, e é
  # isso que impede dois builds no mesmo diretório quando o doctor e um
  # `install.sh` caem juntos.
  # `SuccessExitStatus=1 3` — E ELE FALTAVA NA PRIMEIRA VERSÃO, medido no
  # primeiro auto-build de verdade (01/09/2026, 16:49): o build funcionou, o
  # binário foi instalado, e o journal registrou
  # `Failed with result 'exit-code'` porque `cmd_build` devolve 1, que neste
  # projeto é "estava divergente e eu consertei". Uma unit que fica `failed`
  # depois de um sucesso ensina a ignorar `failed` — é o mesmo motivo pelo qual
  # o `meow-logo.service` tem esta linha.
  if systemd-run --user --unit=meow-files-menu-build --collect \
       --description="build do cosmic-files patchado ($ver)" \
       --property=SuccessExitStatus="1 3" \
       --property=Nice=19 --property=CPUWeight=10 \
       --property=IOWeight=10 --property=IOSchedulingClass=idle \
       --setenv=MEOW_RAIZ="$MEOW_RAIZ" \
       "$MEOW_RAIZ/scripts/files_menu.sh" build >/dev/null 2>&1; then
    meow_info "  auto-build DISPARADO em background (tentativa $((n+1))/$MAX_TENTATIVAS)"
    meow_info "  acompanhar: journalctl --user -fu meow-files-menu-build"
  else
    meow_info "  auto-build já em andamento"
  fi
  return 0
}

# ------------------------------------------------------------------- estado --
cmd_estado() {
  local ver dir b p
  ver="$(versao_do_pacote)"
  meow_titulo "Menu de contexto — avançar/voltar papel de parede"
  printf '  versão do pacote : %s\n' "${ver:-<não instalado>}"
  printf '  chave            : FILES_MENU="%s"  autobuild="%s"\n' "$FILES_MENU" "$FILES_MENU_AUTOBUILD"
  dir="$(artefato_de "${ver:-x}")"
  printf '  artefato         : %s\n' "$([ -d "$dir" ] && echo "$dir" || echo '<não existe para esta versão>')"
  for b in "${BINS[@]}"; do
    p="$(qual_no_path "$b")"
    printf '  %-20s %s  %s\n' "$b" "${p:-<não achado>}" \
      "$([ -n "$p" ] && { patchado "$p" && echo '[PATCHADO]' || echo '[do pacote]'; })"
  done
  printf '\n  builds guardados : %s\n\n' "$(ls -1 "$GUARDA" 2>/dev/null | grep -v '\.tentado$' | tr '\n' ' ')"
  return "$MEOW_OK"
}

case "${1:-aplicar}" in
  aplicar)             cmd_aplicar ;;
  --conferir|conferir) MEOW_SECO=1; cmd_aplicar ;;
  build)               cmd_build ;;
  estado)              cmd_estado ;;
  remover)             remover_nossos && { meow_ok "removidos; o cosmic-files do pacote volta a valer"; exit "$MEOW_DIVERGENTE"; }
                       meow_ok "não havia nada nosso instalado"; exit "$MEOW_OK" ;;
  *) echo "uso: files_menu.sh [aplicar|build|--conferir|estado|remover]" >&2; exit 2 ;;
esac
