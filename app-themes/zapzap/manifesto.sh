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

# Devolve o caminho de onde LER a receita — E NÃO ESCREVE NADA.
# Enquanto o link estiver intacto (nunca aplicamos, ou o flatpak atualizou e o
# recriou), a fonte é ele; a partir da primeira aplicação, é a cópia guardada.
#
# ELA GUARDAVA O ORIGINAL AQUI DENTRO, E ISSO ERA ESCRITA NO `conferir`
#   Até 08/08/2026 esta função fazia o `cp -L` do original quando o guardado não
#   existia. Como `meow_app_conferir` a chama, `meow apps conferir` — e o `meow
#   apps tabela`, que a CLI roda só para desenhar a tabela — ESCREVIAM em disco.
#   Conferir é leitura, e é o único modo em que se confia para auditar antes de
#   deixar rodar. O `cp` mudou-se para o `aplicar`, que é onde escrita mora.
_zz_fonte() {
  if [ -L "$_ZZ_ORIGEM" ]; then printf '%s' "$_ZZ_ORIGEM"; return; fi
  if [ -f "$_ZZ_GUARDADO" ]; then printf '%s' "$_ZZ_GUARDADO"; else printf '%s' "$_ZZ_ORIGEM"; fi
}

# O par escritor da função acima: guarda o original antes da PRIMEIRA aplicação.
# Só o `aplicar` chama. `-L` porque a origem é o symlink de export do flatpak e
# o que interessa é o conteúdo apontado, não o link.
_zz_guardar_original() {
  [ -L "$_ZZ_ORIGEM" ] || return 0
  [ -f "$_ZZ_GUARDADO" ] && return 0
  meow_seco && return 0
  cp -L "$_ZZ_ORIGEM" "$_ZZ_GUARDADO" 2>/dev/null || true
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

# --- O ÍCONE DA BANDEJA É OUTRO CAMINHO, E O TEMA NÃO ALCANÇA ELE -----------
# Sintoma dela, 05/08/2026: "wpp em baixo e lá em cima é zapzap ainda". No dock o
# ícone é o nosso; na barra de cima continua o logo verde-limão do projeto.
#
# NÃO É BUG NOSSO NEM DO COSMIC — SÃO DOIS CAMINHOS DIFERENTES, MEDIDO:
#   dock/lançador : o `.desktop` diz `Icon=<nome>`, e o nome passa pelo TEMA DE
#                   ÍCONES. É por aí que o nosso ícone entra.
#   bandeja       : o app publica o ícone pelo protocolo StatusNotifierItem, e
#                   pode mandar um NOME (`IconName`, que passaria pelo tema) ou
#                   PIXELS crus (`IconPixmap`). Medido com busctl:
#
#     ZapZap        IconName=""   IconPixmap=a(iiay) 2 22 22 ...
#     qBittorrent   IconName=""   IconPixmap=a(iiay) 2 22 22 ...
#
#   Com `IconName` VAZIO não há nome a resolver: o app entrega pixels prontos, e
#   nenhum tema de ícone do mundo muda aquilo. É um beco sem saída por desenho do
#   protocolo, não por falta de esforço nosso.
#
# O QUE SALVA: O PRÓPRIO ZAPZAP TEM A OPÇÃO, E NINGUÉM TINHA OLHADO
#   `zapzap/assets/icons/tray_icon.py` traz TRÊS variantes embutidas — `default`
#   (o degradê verde-limão), `symbolic_light` e `symbolic_dark` — e a escolha vem
#   de `core/config/settings/appearance.py:24`:
#       _TRAY_THEME = ("system/tray_theme", TrayIcon.Type.Default.value)
#   Ou seja, é uma linha no `ZapZap.conf` dela. O símbolico monocromático é o que
#   combina com uma barra Catppuccin — é o mesmo princípio dos ícones do próprio
#   COSMIC na bandeja.
#
# POR QUE NÃO PATCHAR O FLATPAK
#   A árvore é gravável (instalação de usuário), então daria. Mas todo
#   `flatpak update` desfaz, e reescrever código Python de terceiro para trocar
#   um ícone é o tipo de conserto que quebra calado seis meses depois. A chave de
#   configuração é a porta que o autor deixou aberta; usamos a porta.
_ZZ_CONF="$HOME/.var/app/$_ZZ_APP/config/ZapZap/ZapZap.conf"
_ZZ_TRAY_DESEJADO="${ZAPZAP_TRAY:-symbolic_light}"

# Lê `tray_theme` da seção [system] do .conf (formato QSettings/ini).
_zz_tray_atual() {
  [ -f "$_ZZ_CONF" ] || { printf 'default'; return; }
  local v
  v="$(awk -F= '/^\[/{s=$0} s=="[system]" && /^tray_theme=/{print $2; exit}' "$_ZZ_CONF")"
  printf '%s' "${v:-default}"
}

# Escreve a chave preservando o resto do arquivo. A seção [system] já existe no
# conf dela; se não existisse, seria criada no fim — que é onde o QSettings
# aceita, porque ele reserializa o arquivo inteiro ao salvar.
_zz_conf_com_tray() {
  local desejado="$1"
  [ -f "$_ZZ_CONF" ] || return 1
  python3 - "$_ZZ_CONF" "$desejado" <<'PY'
import sys, re
caminho, valor = sys.argv[1], sys.argv[2]
linhas = open(caminho, encoding='utf-8').read().split('\n')
saida, secao, escrito = [], None, False
for l in linhas:
    if l.startswith('['):
        # ao SAIR da [system] sem ter achado a chave, acrescenta antes de sair
        if secao == '[system]' and not escrito:
            saida.append(f'tray_theme={valor}'); escrito = True
        secao = l.strip()
    if re.match(r'^tray_theme=', l) and secao == '[system]':
        saida.append(f'tray_theme={valor}'); escrito = True; continue
    saida.append(l)
if not escrito:
    if secao != '[system]':
        saida.append('[system]')
    saida.append(f'tray_theme={valor}')
sys.stdout.write('\n'.join(saida))
PY
}

meow_app_detectar() {
  meow_tem flatpak || return "$MEOW_SEM_DEPENDENCIA"
  # por diretório, não por `flatpak info`: aquele cria o repositório ostree no
  # home só por ser perguntado, e detecção não pode escrever (ver lib/comum.sh).
  meow_flatpak_tem "$_ZZ_APP" || return "$MEOW_SEM_DEPENDENCIA"
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

  # O ícone da bandeja só é conferido se o conf existir: num ZapZap recém
  # instalado, que nunca abriu, não há arquivo — e cobrar uma chave de um arquivo
  # que o app ainda não criou seria divergência eterna até ela abrir o programa.
  if [ -f "$_ZZ_CONF" ] && [ "$(_zz_tray_atual)" != "$_ZZ_TRAY_DESEJADO" ]; then
    return "$MEOW_DIVERGENTE"
  fi

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

  # ANTES de escrever por cima: guardar o original é a regra 4 do contrato, e
  # aqui é o único ponto que pode fazê-lo (o `conferir` não escreve mais).
  # Tem de vir antes do `meow_escrever` do `.desktop`, senão o que se guarda já
  # é a nossa própria saída.
  _zz_guardar_original

  meow_escrever "$icone" "$(_zz_icone_desejado)" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar o ícone"; return "$MEOW_ERRO" ;; esac

  meow_escrever "$_ZZ_DESTINO" "$(_zz_desktop_desejado)" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao escrever o .desktop"; return "$MEOW_ERRO" ;; esac

  # O ícone da bandeja, pela porta que o autor do ZapZap deixou aberta.
  if [ -f "$_ZZ_CONF" ] && [ "$(_zz_tray_atual)" != "$_ZZ_TRAY_DESEJADO" ]; then
    local novo
    if novo="$(_zz_conf_com_tray "$_ZZ_TRAY_DESEJADO")" && [ -n "$novo" ]; then
      meow_escrever "$_ZZ_CONF" "$novo" 644
      case $? in
        1) mudou=1
           # O ZapZap lê o conf ao subir e ao salvar pelas Preferências. Com ele
           # aberto agora, a mudança vale no próximo início — dizer isso evita
           # que ela olhe a barra, não veja nada e ache que falhou.
           meow_info "ícone da bandeja: $_ZZ_TRAY_DESEJADO (vale quando o ZapZap reabrir)" ;;
        2) meow_aviso "não consegui escrever o ZapZap.conf — bandeja fica como está" ;;
      esac
    fi
  fi

  [ "$mudou" = "0" ] && return "$MEOW_OK"
  meow_seco && return "$MEOW_DIVERGENTE"

  # O lançador lê o cache de .desktop; sem isto o nome novo só apareceria no
  # próximo login. Falhar aqui não é erro: o arquivo já está no lugar certo.
  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  meow_ok "ZapZap agora aparece como '$_ZZ_NOME_NOVO', com ícone Catppuccin"
  return "$MEOW_DIVERGENTE"
}
