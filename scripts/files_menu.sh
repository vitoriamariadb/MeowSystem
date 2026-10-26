#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

FILES_MENU="${FILES_MENU:-sim}"
FILES_MENU_AUTOBUILD="${FILES_MENU_AUTOBUILD:-sim}"

PATCHES=(
  "$MEOW_RAIZ/patches/cosmic-files-wallpaper-menu.patch"
  "$MEOW_RAIZ/patches/cosmic-files-wallpaper-menu-1.9.patch"
)
MARCA="MEOW-FILES-WALLPAPER-PATCH-1"
BINS=(cosmic-files cosmic-files-applet)
DESTINO="$HOME/.local/bin"
GUARDA="$MEOW_ESTADO/cosmic-files"
MAX_TENTATIVAS=3

versao_do_pacote() { dpkg-query -W -f='${Version}' cosmic-files 2>/dev/null; }
artefato_de() { printf '%s/%s' "$GUARDA" "$1"; }
tentativa_de() { printf '%s/%s.tentado' "$GUARDA" "$1"; }

qual_no_path() { command -v "$1" 2>/dev/null; }
patchado() { grep -a -q -- "$MARCA" "$1" 2>/dev/null; }

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

cmd_aplicar() {
  local ver dir b mudou=0
  [ "$FILES_MENU" = "sim" ] || {
    remover_nossos
    if [ "$?" = "1" ]; then
      meow_muda "FILES_MENU=\"$FILES_MENU\" — itens de papel de parede removidos do menu"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "FILES_MENU=\"$FILES_MENU\" — o menu de contexto fica de fábrica"
    return "$MEOW_OK"; }

  ver="$(versao_do_pacote)"
  [ -n "$ver" ] || { meow_pula "o cosmic-files não está instalado por pacote — nada a vestir"; return "$MEOW_SEM_DEPENDENCIA"; }
  dir="$(artefato_de "$ver")"

  if [ ! -d "$dir" ]; then
    remover_nossos; [ "$?" = "1" ] && mudou=1
    meow_aviso "não há build patchado para o cosmic-files $ver — o do pacote está valendo"
    if [ "$mudou" = "1" ]; then
      meow_info "  (removi o nosso, que era de outra versão)"
    fi
    disparar_autobuild "$ver" || {
      if meow_seco; then
        meow_muda "construiria o menu de contexto do cosmic-files $ver, em segundo plano"
      else
        meow_pendencia_acionavel files-menu-build \
          "Não há build patchado para o cosmic-files $ver, e a construção sozinha não rodou" \
          "meow files-menu build"
      fi
    }
    [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
    return 4
  fi

  meow_pendencia_resolvida files-menu-build

  mkdir -p "$DESTINO" 2>/dev/null || { meow_erro "não consegui criar $DESTINO"; return "$MEOW_ERRO"; }
  for b in "${BINS[@]}"; do
    [ -f "$dir/$b" ] || { meow_erro "artefato incompleto: falta $dir/$b"; return "$MEOW_ERRO"; }
    if [ -f "$DESTINO/$b" ] && cmp -s "$dir/$b" "$DESTINO/$b"; then continue; fi
    if meow_seco; then meow_muda "instalaria $DESTINO/$b (patchado, $ver)"; mudou=1; continue; fi
    local tmp; tmp="$(mktemp -p "$DESTINO" ".meow-cf.XXXXXX")" || return "$MEOW_ERRO"
    cp -f "$dir/$b" "$tmp" && chmod 755 "$tmp" && mv -f "$tmp" "$DESTINO/$b" \
      || { rm -f "$tmp"; meow_erro "não consegui instalar $b"; return "$MEOW_ERRO"; }
    meow_manifesto_registrar "$DESTINO/$b"
    mudou=1
  done

  if meow_seco && [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
  if [ "$mudou" = "1" ]; then
    meow_ok "menu de contexto vestido: avançar e voltar papel de parede ($ver)"
    meow_info "  vale nas janelas novas; a área de trabalho no próximo login"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "menu de contexto já tem avançar/voltar papel de parede ($ver)"
  return "$MEOW_OK"
}

cmd_build() {
  local ver dir tmpdir fonte
  ver="$(versao_do_pacote)"
  [ -n "$ver" ] || { meow_erro "o cosmic-files não está instalado por pacote"; return "$MEOW_SEM_DEPENDENCIA"; }
  dir="$(artefato_de "$ver")"
  [ -f "${PATCHES[0]}" ] || { meow_erro "falta ${PATCHES[0]}"; return "$MEOW_ERRO"; }
  meow_tem cargo   || { meow_erro "falta o cargo (rustup ou o pacote cargo)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem apt-get || { meow_erro "falta apt-get";                            return "$MEOW_SEM_DEPENDENCIA"; }

  if [ -d "$dir" ] && [ -f "$dir/cosmic-files-applet" ]; then
    meow_ok "já existe build patchado para $ver — nada a compilar"
    return "$MEOW_OK"
  fi
  meow_seco && { meow_muda "compilaria o cosmic-files $ver patchado (~161 MB de fonte, minutos)"; return "$MEOW_DIVERGENTE"; }

  tmpdir="$(mktemp -d -p "${TMPDIR:-/tmp}" meow-cf.XXXXXX)" || return "$MEOW_ERRO"
  trap 'rm -rf "$tmpdir"' RETURN

  meow_info "baixando o fonte do cosmic-files $ver…"
  ( cd "$tmpdir" && apt-get source "cosmic-files=$ver" ) >/dev/null 2>&1 \
    || { meow_erro "apt-get source falhou — o deb-src está habilitado?"; return "$MEOW_ERRO"; }
  fonte="$(find "$tmpdir" -maxdepth 1 -type d -name 'cosmic-files-*' | head -1)"
  [ -n "$fonte" ] || { meow_erro "não achei a árvore de fonte baixada"; return "$MEOW_ERRO"; }

  if ! grep -rq -- "$MARCA" "$fonte/src/app.rs" 2>/dev/null; then
    local p
    for p in "${PATCHES[@]}"; do
      [ -f "$p" ] || continue
      ( cd "$fonte" && patch -p1 -F0 --forward --dry-run < "$p" ) >/dev/null 2>&1 || continue
      ( cd "$fonte" && patch -p1 -F0 --forward --no-backup-if-mismatch < "$p" ) >/dev/null 2>&1
      break
    done
    grep -q -- "$MARCA" "$fonte/src/app.rs" \
      || { meow_erro "nenhum patch do menu entra nesta versão — o upstream mexeu no menu"; return "$MEOW_ERRO"; }
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

jogo_aberto() { pgrep -f "SteamLaunch[ ]AppId=[0-9]" >/dev/null 2>&1; }
disparar_autobuild() {
  local ver="$1" n f
  [ "$FILES_MENU_AUTOBUILD" = "sim" ] || return 1
  meow_seco && return 1
  meow_tem systemd-run || return 1
  jogo_aberto && { meow_info "  auto-build adiado: jogo aberto"; return 0; }

  f="$(tentativa_de "$ver")"; n=0; [ -f "$f" ] && n="$(wc -l < "$f")"
  if [ "$n" -ge "$MAX_TENTATIVAS" ]; then
    meow_pendencia_acionavel files-menu-build \
      "O menu de contexto de papel de parede não compilou em $n tentativas e parei de tentar sozinha" \
      "meow files-menu build"
    return 0
  fi
  mkdir -p "$GUARDA"; printf '%s tentativa %s/%s\n' "$(date -Is)" "$((n+1))" "$MAX_TENTATIVAS" >> "$f"

  meow_pendencia_acionavel files-menu-build \
    "Construindo o menu de contexto de papel de parede em segundo plano (tentativa $((n+1)) de $MAX_TENTATIVAS) — leva alguns minutos e não precisa de você" \
    ""

  if systemd-run --user --unit=meow-files-menu-build --collect \
       --description="build do cosmic-files patchado ($ver)" \
       --property=SuccessExitStatus="1 3" \
       --property=Nice=19 --property=CPUWeight=10 \
       --property=IOWeight=10 --property=IOSchedulingClass=idle \
       --setenv=MEOW_RAIZ="$MEOW_RAIZ" \
       "$MEOW_RAIZ/scripts/garantir_builds.sh" >/dev/null 2>&1; then
    meow_info "  auto-build DISPARADO em background (tentativa $((n+1))/$MAX_TENTATIVAS)"
  else
    meow_info "  auto-build já em andamento"
  fi
  return 0
}

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
  build)               cmd_build; rc_build=$?
                       case "$rc_build" in
                         0|1) meow_pendencia_resolvida files-menu-build ;;
                         3)   meow_pendencia_acionavel files-menu-build \
                                "Não dá para construir o menu de contexto de papel de parede nesta máquina: falta uma ferramenta de compilação que eu não instalo sozinha" \
                                "" ;;
                         *)   meow_pendencia_acionavel files-menu-build \
                                "A construção do menu de contexto de papel de parede falhou — posso tentar de novo" \
                                "meow files-menu build" ;;
                       esac
                       exit "$rc_build" ;;
  estado)              cmd_estado ;;
  remover)             remover_nossos
                       if [ "$?" = "1" ]; then
                         meow_ok "removidos; o cosmic-files do pacote volta a valer"
                         exit "$MEOW_DIVERGENTE"
                       fi
                       meow_ok "não havia nada nosso instalado"; exit "$MEOW_OK" ;;
  *) echo "uso: files_menu.sh [aplicar|build|--conferir|estado|remover]" >&2; exit 2 ;;
esac
