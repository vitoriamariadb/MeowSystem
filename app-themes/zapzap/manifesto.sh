#!/usr/bin/env bash
# app-themes/zapzap/manifesto.sh — o ZapZap vira "WhatsApp", com ícone Catppuccin.
#
# O QUE ELE FAZ, E POR QUE
#   O ZapZap é um cliente de WhatsApp para Linux. No lançador ele aparece com o
#   nome do projeto ("ZapZap") e o ícone próprio, em degradê verde-limão que não
#   combina com nada do resto. A Vitória pediu o mesmo que o Dracula_OS-Theme faz:
#   chamar de "WhatsApp" e trocar a logo.
#
# A PRIMEIRA TENTATIVA DUPLICOU O APP NO LANÇADOR — e é por isso que este
# módulo faz o que faz.
#   A ideia óbvia era pôr um `.desktop` de mesmo nome em
#   `~/.local/share/applications/`, contando com a precedência do XDG_DATA_HOME
#   sobre o XDG_DATA_DIRS. Pela especificação, deveria vencer.
#   MEDIDO: o lançador do COSMIC **não deduplica por ID**. Ele lista os dois
#   arquivos, e a Vitória viu "ZapZap" E "WhatsApp" lado a lado no lançador.
#
# O QUE FUNCIONA: trocar o SYMLINK do próprio diretório de exports.
#   `~/.local/share/flatpak/exports/share/applications/com.rtosta.zapzap.desktop`
#   é um symlink para dentro da árvore do app, que é somente-leitura. Mas o LINK
#   mora no home dela e pode ser substituído por um arquivo real. Assim existe um
#   `.desktop` só, e não há duplicata possível.
#
# O CUSTO, E COMO ELE É PAGO
#   Um `flatpak update` do ZapZap recria o symlink e a mudança some. Não é
#   silencioso por acaso: o `conferir` detecta, o `meow doctor --consertar` e o
#   timer diário reaplicam. O alvo original fica guardado ao lado, em
#   `.meow-original`, para o `flatpak repair` não achar link quebrado.
#
# O ÍCONE
#   O Papirus tem `whatsapp-desktop`, mas SÓ na variante clara (`Papirus/`, não
#   `Papirus-Dark/`) — verificado. Como o nosso tema herda do `Papirus-Dark`, ele
#   não seria encontrado. Copiamos para o nosso tema com o nome que o `.desktop`
#   passa a pedir, e trocamos o verde do WhatsApp (`#47AD5D`) pelo verde do
#   Catppuccin, lido da paleta — nada de hex digitado à mão.
#
# POR QUE NÃO MEXER NO `Exec=`
#   A linha de execução do flatpak tem `@@u %u @@` (file-forwarding) e o
#   `--branch`/`--arch` exatos. Copiar é seguro; reescrever seria uma chance
#   gratuita de quebrar o app.

_ZZ_APP="com.rtosta.zapzap"
_ZZ_NOME_NOVO="WhatsApp"
_ZZ_ICONE="meow-whatsapp"
_ZZ_ORIGEM="$HOME/.local/share/flatpak/exports/share/applications/$_ZZ_APP.desktop"
_ZZ_DESTINO="$_ZZ_ORIGEM"   # sim, o próprio: substituímos o symlink
# O ORIGINAL PRECISA SER GUARDADO ANTES DA PRIMEIRA ESCRITA. Depois que o symlink
# vira arquivo real, ler "a origem" devolveria o nosso próprio conteúdo — e o
# `conferir` passaria sempre, comparando o arquivo com ele mesmo. Este é o tipo
# de bug que não dá erro: só faz o módulo parar de verificar qualquer coisa.
_ZZ_GUARDADO="$HOME/.local/share/flatpak/exports/share/applications/.$_ZZ_APP.desktop.meow-original"
_ZZ_PAPIRUS="/usr/share/icons/Papirus/48x48/apps/whatsapp-desktop.svg"

_zz_tema_dir() {
  printf '%s' "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}"
}

# O verde do flavor ativo, lido da paleta canônica.
_zz_verde() {
  local flavor="${FLAVOR:-mocha}"
  local paleta="$MEOW_RAIZ/palette/catppuccin.json"
  [ -f "$paleta" ] || { printf '%s' "#A6E3A1"; return; }
  python3 -c "
import json, sys
try:
    p = json.load(open('$paleta'))
    print(p['flavors']['$flavor']['green'])
except Exception:
    print('#A6E3A1')
" 2>/dev/null || printf '%s' "#A6E3A1"
}

# Guarda o original na primeira vez, e devolve o caminho de onde LER a receita.
# Enquanto o link estiver intacto (nunca aplicamos, ou o flatpak atualizou e o
# recriou), a fonte é ele; a partir da primeira aplicação, é a cópia guardada.
_zz_fonte() {
  if [ -L "$_ZZ_ORIGEM" ]; then
    if [ ! -f "$_ZZ_GUARDADO" ] && ! meow_seco; then
      cp -L "$_ZZ_ORIGEM" "$_ZZ_GUARDADO" 2>/dev/null || true
    fi
    printf '%s' "$_ZZ_ORIGEM"
    return
  fi
  if [ -f "$_ZZ_GUARDADO" ]; then printf '%s' "$_ZZ_GUARDADO"; else printf '%s' "$_ZZ_ORIGEM"; fi
}

_zz_desktop_desejado() {
  # Troca só Name= e Icon=. As traduções de Name (Name[xx]=) também vão, senão o
  # lançador mostraria "ZapZap" para quem usa outro idioma — e o sistema dela é
  # pt_BR, então isso não é hipotético.
  sed -E \
    -e "s|^Name=.*|Name=$_ZZ_NOME_NOVO|" \
    -e "s|^Name\[[^]]+\]=.*|Name[pt_BR]=$_ZZ_NOME_NOVO|" \
    -e "s|^Icon=.*|Icon=$_ZZ_ICONE|" \
    "$(_zz_fonte)"
}

_zz_icone_desejado() {
  local verde; verde="$(_zz_verde)"
  # O ícone do Papirus usa #47ad5d (verde do WhatsApp) e #ffffff. O branco vira a
  # base do flavor, para o balão ter o mesmo fundo das outras superfícies.
  local base="#1E1E2E"
  case "${FLAVOR:-mocha}" in
    latte) base="#EFF1F5" ;;
    frappe) base="#303446" ;;
    macchiato) base="#24273A" ;;
  esac
  sed -E -e "s|#47ad5d|$verde|gI" -e "s|#ffffff|$base|gI" "$_ZZ_PAPIRUS"
}

meow_app_detectar() {
  meow_tem flatpak || return "$MEOW_SEM_DEPENDENCIA"
  flatpak info "$_ZZ_APP" >/dev/null 2>&1 || return "$MEOW_SEM_DEPENDENCIA"
  [ -f "$_ZZ_ORIGEM" ] || return "$MEOW_SEM_DEPENDENCIA"
  meow_tem python3 || return "$MEOW_SEM_DEPENDENCIA"
  [ -f "$_ZZ_PAPIRUS" ] || return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  local tema; tema="$(_zz_tema_dir)"
  local icone="$tema/scalable/apps/$_ZZ_ICONE.svg"

  [ -f "$_ZZ_DESTINO" ] || return "$MEOW_DIVERGENTE"
  [ -f "$icone" ] || return "$MEOW_DIVERGENTE"
  [ "$(_zz_desktop_desejado)" = "$(cat "$_ZZ_DESTINO")" ] || return "$MEOW_DIVERGENTE"
  [ "$(_zz_icone_desejado)" = "$(cat "$icone")" ] || return "$MEOW_DIVERGENTE"

  meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' com o ícone Catppuccin"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || {
    meow_pula "ZapZap não instalado (ou falta o whatsapp-desktop do Papirus)"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' — nada a fazer"
    return "$MEOW_OK"
  }

  local tema; tema="$(_zz_tema_dir)"
  local icone="$tema/scalable/apps/$_ZZ_ICONE.svg"
  local mudou=0

  meow_escrever "$icone" "$(_zz_icone_desejado)" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar o ícone"; return "$MEOW_ERRO" ;; esac

  meow_escrever "$_ZZ_DESTINO" "$(_zz_desktop_desejado)" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever o .desktop"; return "$MEOW_ERRO" ;; esac

  [ "$mudou" = "0" ] && return "$MEOW_OK"
  meow_seco && return "$MEOW_DIVERGENTE"

  # O lançador lê o cache de .desktop; sem isto o nome novo só apareceria no
  # próximo login. Falhar aqui não é erro: o arquivo já está no lugar certo.
  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  meow_ok "ZapZap agora aparece como '$_ZZ_NOME_NOVO', com ícone Catppuccin"
  return "$MEOW_DIVERGENTE"
}
