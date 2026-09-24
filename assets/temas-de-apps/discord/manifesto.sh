#!/usr/bin/env bash
# assets/temas-de-apps/discord/manifesto.sh — o tema do pack no Discord.
#
# POR QUE ESTE MÓDULO NASCEU — 24/09/2026, sprint P42
#   A P37 mediu o que o tema Dracula de antes aplicava e o MeowSystem nunca
#   migrou, e o Discord estava na lista. A decisão de 23/09 foi "migrar para o
#   pack": o CSS do tema Dracula do CtorW virou um MODELO em `packs/<pack>/apps/`
#   (a chave `apps.discord.arquivo`), com os 40 hex trocados por papel da
#   paleta, e quem põe a cor é o `assets/temas-de-apps/modelo.py`. O slug
#   `discord` já estava no `APPS_ATIVOS` de fábrica e caía no "não temos módulo
#   para esse app ainda" do `aplicar_apps.sh`; agora tem.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`.
#
# O CLIENTE OFICIAL NÃO CARREGA TEMA, E ISSO É A PRIMEIRA PENDÊNCIA
#   Tema de Discord é CSS que um cliente MODIFICADO injeta: BetterDiscord,
#   Vencord ou Vesktop, cada um com a sua pasta `themes/`. O Discord oficial,
#   sozinho, não lê pasta nenhuma. Medido nesta máquina em 24/09/2026: o Discord
#   é o flatpak oficial (`com.discordapp.Discord`, cliente 1.0.155) e nenhuma das
#   pastas abaixo existe — então aqui o módulo sai pendente, com o motivo. O tema
#   de antes fazia a mesma coisa e dizia "copie manualmente".
#
#   Ele só escreve em pasta que JÁ EXISTE: criar `BetterDiscord/themes/` numa
#   máquina sem BetterDiscord seria pôr no disco um arquivo que nada lê e chamar
#   isso de aplicado.
#
# ATIVAR É DELA
#   Os três clientes pedem que o tema seja ligado nas configurações deles, e
#   guardam isso cada um no seu formato. O módulo põe o arquivo e diz o nome que
#   ela vai achar na lista; mexer no JSON de configuração de um cliente de
#   terceiro para ligá-lo seria o segundo dono no mesmo arquivo.

_DC_ARQ_NOME="MeowSystem.theme.css"
_DC_MODELO_PY="$MEOW_RAIZ/assets/temas-de-apps/modelo.py"
_DC_CONF="${XDG_CONFIG_HOME:-$HOME/.config}"

# As pastas `themes/` dos três clientes, nativos e flatpak. Só as que existem.
_dc_pastas() {
  local d
  for d in \
    "$_DC_CONF/BetterDiscord/themes" \
    "$_DC_CONF/Vencord/themes" \
    "$_DC_CONF/vesktop/themes" \
    "$HOME/.var/app/com.discordapp.Discord/config/BetterDiscord/themes" \
    "$HOME/.var/app/com.discordapp.Discord/config/Vencord/themes" \
    "$HOME/.var/app/dev.vencord.Vesktop/config/vesktop/themes"; do
    [ -d "$d" ] && printf '%s\n' "$d"
  done
}

_dc_instalado() {
  meow_flatpak_tem com.discordapp.Discord || meow_flatpak_tem dev.vencord.Vesktop \
    || meow_tem discord || meow_tem Discord || meow_tem vesktop
}

_dc_marca() {
  sed -n 's|^ \* meowsystem-tema: \([^ ]*\).*$|\1|p' "$1" 2>/dev/null | head -n 1
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { _dc_instalado; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "Discord: não está instalado"; return; }
  _DC_PASTAS="$(_dc_pastas)"
  [ -n "$_DC_PASTAS" ] || { meow_app_sem "Discord: o cliente oficial não carrega tema — falta um cliente modificado (BetterDiscord, Vencord ou Vesktop)"; return; }
  meow_tem python3 || { meow_app_sem "Discord: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack discord.arquivo
  _DC_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "Discord: o pack no ar não declara tema para o Discord"; return; }
  _DC_QUERO="$_DC_DE/${FLAVOR:-}"
  _DC_DESEJADO="$(python3 "$_DC_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_DC_DE" 2>&1)" \
    || { meow_app_sem "Discord: o modelo do pack $_DC_DE não montou — $_DC_DESEJADO"; return; }
  _DC_NOME="$(python3 "$_DC_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null) (MeowSystem)"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  local pasta arq marca rc="$MEOW_OK"
  while IFS= read -r pasta; do
    arq="$pasta/$_DC_ARQ_NOME"
    marca="$(_dc_marca "$arq")"
    if [ ! -f "$arq" ]; then
      meow_muda "Discord: o tema do pack não está em $pasta"
      rc="$MEOW_DIVERGENTE"
    elif [ -z "$marca" ]; then
      meow_pula "Discord: $arq não veio daqui — não é tocado"
      [ "$rc" = "$MEOW_OK" ] && rc="$MEOW_SEM_DEPENDENCIA"
    elif [ "$(cat "$arq")" != "$_DC_DESEJADO" ]; then
      meow_muda "Discord: em $pasta está '$marca', e o de agora é '$_DC_QUERO' (ou o modelo mudou)"
      rc="$MEOW_DIVERGENTE"
    fi
  done <<< "$_DC_PASTAS"
  [ "$rc" = "$MEOW_OK" ] && meow_ok "Discord: o tema do pack (do pack $_DC_DE) está na pasta de cada cliente — $_DC_QUERO"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente discord; return; }
  local pasta arq marca mudou=0 pulou=0
  while IFS= read -r pasta; do
    arq="$pasta/$_DC_ARQ_NOME"
    marca="$(_dc_marca "$arq")"
    if [ -n "$marca" ]; then
      if [ "$marca" = "$_DC_QUERO" ]; then
        meow_app_tema_no_ar discord "$marca" "$_DC_QUERO" "$_DC_DE" >/dev/null
      else
        meow_muda "Discord: em $pasta o tema do MeowSystem estava em '$marca' — passa a '$_DC_QUERO'"
      fi
    else
      # Sem arquivo é "sem tema"; um arquivo com o NOSSO nome e sem a marca é de
      # terceiro, e a regra é a de sempre: pergunta, ou deixa pendência.
      local no_ar=""
      [ -f "$arq" ] && no_ar="$arq"
      meow_app_tema_no_ar discord "$no_ar" "$_DC_QUERO" "$_DC_DE" pergunte
      [ $? = "$MEOW_DIVERGENTE" ] || { pulou=1; continue; }
    fi
    meow_escrever "$arq" "$_DC_DESEJADO" 644
    case $? in
      1) mudou=1; meow_seco || meow_ok "Discord: tema do pack em $pasta" ;;
      2) meow_erro "Discord: falhou ao escrever $arq"; return "$MEOW_ERRO" ;;
    esac
  done <<< "$_DC_PASTAS"

  if [ "$mudou" = 1 ]; then
    meow_seco && return "$MEOW_DIVERGENTE"
    meow_info "ligue '$_DC_NOME' em Configurações > Temas do cliente (vale ao reabrir o Discord)"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$pulou" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
  meow_ok "Discord: já está no tema do pack (do pack $_DC_DE) — $_DC_QUERO"
  return "$MEOW_OK"
}

# Tira o nosso arquivo de toda pasta `themes/` onde ele estiver com a marca. Não
# depende do pack nem do cliente instalado: é a marca que diz de quem ele é.
meow_app_reverter() {
  local pasta arq mudou=0
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    arq="$pasta/$_DC_ARQ_NOME"
    [ -n "$(_dc_marca "$arq")" ] || continue
    if meow_seco; then
      meow_muda "Discord: tiraria $arq"
    else
      rm -f -- "$arq" || { meow_erro "Discord: não consegui tirar $arq"; return "$MEOW_ERRO"; }
      meow_ok "Discord: o tema do pack saiu de $pasta"
    fi
    mudou=1
  done <<< "$(_dc_pastas)"
  if [ "$mudou" = 0 ]; then
    meow_ok "Discord: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_seco || meow_info "tire 'discord' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
