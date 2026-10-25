#!/usr/bin/env bash
# scripts/temas-de-apps/zapzap/manifesto.sh — o ZapZap vira "WhatsApp", com o ícone nas cores do pack no ar e o WhatsApp Web no tema do pack (CSS, P106).
#
# ATÉ 24/09/2026 A PRIMEIRA LINHA DIZIA "com ícone Catppuccin", e a tela do
# `conferir` também — com qualquer pack no ar. O ÍCONE nunca foi do Catppuccin:
# este módulo só grava `Icon=meow-whatsapp`, e quem o desenha é o tema de ícones,
# com o `sky` da paleta do pack no ar (medido nesta máquina com o Dracula no ar:
# `#8BE9FD` no `48x48/apps/meow-whatsapp.svg`, o ciano do Dracula). Quem
# mentia era a frase. Desde a P55 ela diz o nome do pack no ar.
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
# O ÍCONE — ESTE MÓDULO SÓ DÁ O NOME; QUEM DESENHA É O `apps-arcticons.map`
#   Até 11/08/2026 era aqui: o Papirus tem `whatsapp-desktop` só na variante
#   clara (`Papirus/`, não `Papirus-Dark/`), então copiávamos o arquivo para o
#   nosso tema em `scalable/apps/meow-whatsapp.svg`, trocando o verde do WhatsApp
#   (`#47AD5D`) pelo verde da paleta. Era um BALÃO VERDE CHEIO.
#
#   E `meow-whatsapp` também está no `packs/meowsystem/icones/apps-arcticons.map`, desde a
#   unificação de 10/08/2026, com o glifo `whatsapp` em traço `sky` — que o
#   `icones_apps_arcticons.sh` instala em `48x48/apps`. Dois donos para o mesmo
#   nome, exatamente a doença dos oito `com.system76.Cosmic*` da Sprint J, e com
#   o mesmo desfecho: o resolvedor pede `scalable` primeiro (`strace` de
#   08/08/2026, docs/SPRINTS.md), o balão cheio vencia, e o traço que ela
#   aprovou ficava no disco sem nunca aparecer.
#
#   O critério dela é o mesmo dos oito, e é textual: "no sentido de criarmos
#   icons igual o nosso tema atual" (11/08/2026) — o nosso tema é o TRAÇO. Então
#   este módulo parou de instalar o balão e REMOVE o que já instalou. O que ele
#   continua fazendo é o que só ele pode fazer: gravar `Icon=meow-whatsapp` no
#   `.desktop`, que é o nome que faz a linha do mapa Arcticons alcançar o app.
#
#   Isto NÃO mexe na bandeja: ela nunca passou por este arquivo. O ícone da
#   bandeja é `IconPixmap` cru pelo D-Bus, e foi vestido na FONTE do app (o
#   `tray_icon.py` do flatpak, ver `packs/meowsystem/icones/bandeja.map`) mais a chave
#   `tray_theme=symbolic_light`, que continua sendo escrita aqui embaixo.
#
#   Para desfazer: devolver `_zz_icone_desejado` (está no git, commit anterior a
#   este) e tirar a linha `meow-whatsapp:whatsapp:sky` do `apps-arcticons.map` —
#   nunca só uma das duas, que é como o defeito nasceu.
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

_zz_tema_dir() {
  printf '%s' "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}"
}

# O nome de tela do pack no ar, que é de quem são as cores do ícone (ver o topo),
# pela regra única do `adocao` — a mesma do `meow_pack_dir`. Sem resposta, a
# frase diz de quem é sem dizer o nome.
_zz_pack_nome() {
  local nome
  nome="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao "${PACK:-}" "${FLAVOR:-}" 2>/dev/null | sed -n 's/^nome=//p')"
  printf '%s' "${nome:-do pack no ar}"
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

# O balão verde cheio que este módulo instalava até 11/08/2026. Ver o cabeçalho:
# quem veste `meow-whatsapp` agora é o `packs/meowsystem/icones/apps-arcticons.map`, em traço, num
# diretório de dono único. O que sobra aqui é ARRANCAR o arquivo antigo — sem
# isso ele continuaria vencendo em `scalable/apps`, e a decisão dela ficaria no
# disco sem chegar à tela.
_zz_icone_velho() {
  printf '%s' "$(_zz_tema_dir)/scalable/apps/$_ZZ_ICONE.svg"
}

# O pack no ar veste `meow-whatsapp` com um desenho dele (o `icones/apps.map`):
# aí o arquivo de `scalable/apps` é a arte do pack, e não o balão de antes.
_zz_do_pack() {
  MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$MEOW_RAIZ/scripts/pack.py" fontes 2>/dev/null \
    | awk -F'\t' -v n="$_ZZ_ICONE" '$1 == n { achou = 1 } END { exit !achou }'
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
  python3 -I - "$_ZZ_CONF" "$desejado" <<'PY'
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

# --- O TEMA DO WHATSAPP: CSS PELA PALETA DO PACK (P106, 24/10/2026) ----------
# Pedido dela (24/10): «o ZapZap permite alterar o CSS», como o Telegram e o
# Discord. O ZapZap 7.5.1 injeta no WhatsApp Web todo `.css` da pasta
# `customizations/global/css/` (o `customizations_manager.py` do flatpak), e só
# quando a chave `custom/global/css/enabled` do ZapZap.conf é true — de
# fábrica ela é false. O CSS sai do modelo do motor
# (`zapzap.modelo.css`) com a paleta do pack no ar, pelo `modelo.py`, que só põe
# cor que é `#hex`; o resto do arquivo é texto do modelo. O nosso arquivo é UM,
# com a marca `meowsystem-tema:`; outro `.css` na pasta é de quem usa, e a
# regra é a do tema de terceiro (lib/comum.sh): perguntar, nunca escrever por
# cima. O ZapZap lê o CSS ao carregar a página: com ele aberto, vale ao reabrir.
_ZZ_CSS_DIR="$HOME/.var/app/$_ZZ_APP/data/ZapZap/customizations/global/css"
_ZZ_CSS="$_ZZ_CSS_DIR/MeowSystem.css"
_ZZ_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

_zz_css_marca() {
  sed -n 's|^ \* meowsystem-tema: \([^ ]*\).*$|\1|p' "$1" 2>/dev/null | head -n 1
}

# Os `.css` da pasta que não são o nosso (o ZapZap aceita a extensão em
# qualquer caixa). Um arquivo com o nosso nome e sem a marca é de terceiro.
_zz_css_de_terceiro() {
  local f
  for f in "$_ZZ_CSS_DIR"/*; do
    [ -f "$f" ] || continue
    case "${f,,}" in *.css) ;; *) continue ;; esac
    [ "$f" = "$_ZZ_CSS" ] && [ -n "$(_zz_css_marca "$f")" ] && continue
    printf '%s\n' "$f"
  done
}

# 0 = o CSS global está ligado no ZapZap.conf (`[custom]`, `global\css\enabled`).
_zz_css_ligado() {
  [ -f "$_ZZ_CONF" ] || return 1
  awk -F= '/^\[/{s=$0} s=="[custom]" && $1=="global\\css\\enabled"{v=$2} END{exit !(v=="true")}' "$_ZZ_CONF"
}

# ligar | tirar — a chave do CSS global; o conf inteiro sai no stdout, o resto
# do arquivo como estava.
_zz_conf_css() {
  [ -f "$_ZZ_CONF" ] || return 1
  python3 -I - "$_ZZ_CONF" "$1" <<'PY'
import sys
caminho, modo = sys.argv[1], sys.argv[2]
CHAVE = 'global\\css\\enabled'
linhas = open(caminho, encoding='utf-8').read().split('\n')
ini = next((i for i, l in enumerate(linhas) if l.strip() == '[custom]'), None)
if ini is None:
    if modo == 'ligar':
        while linhas and linhas[-1] == '':
            linhas.pop()
        linhas += ['', '[custom]', CHAVE + '=true', '']
else:
    fim = next((i for i in range(ini + 1, len(linhas)) if linhas[i].startswith('[')), len(linhas))
    achadas = [i for i in range(ini + 1, fim) if linhas[i].split('=', 1)[0] == CHAVE]
    if modo == 'ligar':
        if achadas:
            linhas[achadas[0]] = CHAVE + '=true'
        else:
            linhas.insert(ini + 1, CHAVE + '=true')
    else:
        for i in reversed(achadas):
            del linhas[i]
        fim -= len(achadas)
        if all(not l.strip() for l in linhas[ini + 1:fim]):
            del linhas[ini:fim]
sys.stdout.write('\n'.join(linhas))
PY
}

# O CSS que o pack no ar pede. 0 = montou · 1 = o pack não traz tema para o
# WhatsApp · 2 = não montou (motivo em `_ZZ_CSS_ERRO`).
_zz_css_do_pack() {
  _ZZ_CSS_DESEJADO=""; _ZZ_CSS_QUERO=""; _ZZ_CSS_ERRO=""
  meow_app_tema_do_pack zapzap.arquivo
  _ZZ_CSS_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || return 1
  _ZZ_CSS_QUERO="$_ZZ_CSS_DE/${FLAVOR:-}"
  # Pack é dado: fora a cor, o único texto do pack que entra no CSS é a marca,
  # e ela só leva nome.
  [[ "$_ZZ_CSS_QUERO" =~ ^[A-Za-z0-9_-]+/[A-Za-z0-9_-]+$ ]] \
    || { _ZZ_CSS_ERRO="pack ou flavor com nome fora do padrão ('$_ZZ_CSS_QUERO')"; return 2; }
  _ZZ_CSS_DESEJADO="$(python3 "$_ZZ_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_ZZ_CSS_DE" 2>&1)" \
    || { _ZZ_CSS_ERRO="$_ZZ_CSS_DESEJADO"; _ZZ_CSS_DESEJADO=""; return 2; }
  return 0
}

# 0 = em dia · 1 = divergente · 3 = há CSS de terceiro, ou o modelo não montou.
_zz_css_conferir() {
  local marca rc
  marca="$(_zz_css_marca "$_ZZ_CSS")"
  _zz_css_do_pack; rc=$?
  if [ "$rc" = 1 ]; then
    [ -z "$marca" ] && return "$MEOW_OK"
    meow_muda "ZapZap: o pack no ar não traz tema para o WhatsApp, e o do MeowSystem ('$marca') continua lá"
    return "$MEOW_DIVERGENTE"
  fi
  [ "$rc" = 2 ] && { meow_aviso "ZapZap: o modelo do tema não montou — $_ZZ_CSS_ERRO"; return "$MEOW_SEM_DEPENDENCIA"; }
  # Nunca aberto, sem conf: a mesma regra da bandeja, logo acima.
  [ -f "$_ZZ_CONF" ] || return "$MEOW_OK"
  if [ -z "$marca" ]; then
    if [ -n "$(_zz_css_de_terceiro)" ]; then
      meow_pula "ZapZap: há CSS que não veio daqui em $_ZZ_CSS_DIR — não é tocado"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
    meow_muda "ZapZap: o tema do pack ainda não está no WhatsApp"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$(cat "$_ZZ_CSS")" != "$_ZZ_CSS_DESEJADO" ]; then
    meow_muda "ZapZap: o WhatsApp está em '$marca', e o de agora é '$_ZZ_CSS_QUERO' (ou o modelo mudou)"
    return "$MEOW_DIVERGENTE"
  fi
  _zz_css_ligado || { meow_muda "ZapZap: o tema está na pasta, e o CSS está desligado no ZapZap"; return "$MEOW_DIVERGENTE"; }
  meow_ok "ZapZap: o WhatsApp está no tema do pack (do pack $_ZZ_CSS_DE) — $_ZZ_CSS_QUERO"
  return "$MEOW_OK"
}

# Tira o NOSSO arquivo (é a marca que diz de quem ele é) e, se a pasta fica sem
# CSS nenhum, devolve a chave ao de fábrica. Com CSS de outra pessoa lá, a chave
# continua ligada: é ela que faz aquele valer. Escrita direta, e não por
# `meow_escrever`, pelo motivo do «DESFAZER» lá embaixo.
# 0 = nada nosso no disco · 1 = tirou (ou tiraria, no seco) · 2 = erro.
_zz_css_tirar() {
  [ -n "$(_zz_css_marca "$_ZZ_CSS")" ] || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "ZapZap: tiraria $_ZZ_CSS"
    return "$MEOW_DIVERGENTE"
  fi
  rm -f -- "$_ZZ_CSS" || { meow_erro "ZapZap: não consegui tirar $_ZZ_CSS"; return "$MEOW_ERRO"; }
  meow_ok "ZapZap: o tema do pack saiu do WhatsApp (vale quando o ZapZap reabrir)"
  if _zz_css_ligado && [ -z "$(_zz_css_de_terceiro)" ]; then
    local novo
    if ! novo="$(_zz_conf_css tirar)" || ! printf '%s' "$novo" > "$_ZZ_CONF" 2>/dev/null; then
      meow_aviso "ZapZap: não consegui desligar o CSS no ZapZap.conf"
    fi
  fi
  return "$MEOW_DIVERGENTE"
}

# 0 = nada a fazer · 1 = escreveu (ou escreveria) · 2 = erro · 3 = pendente.
_zz_css_aplicar() {
  local marca rc no_ar mudou=0 novo
  _zz_css_do_pack; rc=$?
  # Pack sem tema para o WhatsApp: o nosso, de outro pack, sai.
  [ "$rc" = 1 ] && { _zz_css_tirar; return; }
  [ "$rc" = 2 ] && { meow_aviso "ZapZap: o modelo do tema não montou — $_ZZ_CSS_ERRO"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ -f "$_ZZ_CONF" ] || { meow_info "ZapZap: o tema do WhatsApp entra depois que o ZapZap abrir uma vez"; return "$MEOW_OK"; }

  marca="$(_zz_css_marca "$_ZZ_CSS")"
  if [ -n "$marca" ]; then
    [ "$marca" = "$_ZZ_CSS_QUERO" ] \
      || meow_muda "ZapZap: o WhatsApp estava em '$marca' — passa a '$_ZZ_CSS_QUERO'"
  else
    no_ar="$(_zz_css_de_terceiro | head -n 1)"
    meow_app_tema_no_ar zapzap "$no_ar" "$_ZZ_CSS_QUERO" "$_ZZ_CSS_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_escrever "$_ZZ_CSS" "$_ZZ_CSS_DESEJADO" 644
  case $? in
    1) mudou=1 ;;
    2) meow_erro "ZapZap: falhou ao escrever $_ZZ_CSS"; return "$MEOW_ERRO" ;;
  esac
  if ! _zz_css_ligado; then
    novo="$(_zz_conf_css ligar)" || { meow_erro "ZapZap: não consegui ler o ZapZap.conf"; return "$MEOW_ERRO"; }
    meow_escrever "$_ZZ_CONF" "$novo" 644
    case $? in
      1) mudou=1 ;;
      2) meow_erro "ZapZap: não consegui ligar o CSS no ZapZap.conf"; return "$MEOW_ERRO" ;;
    esac
  fi
  [ "$mudou" = 1 ] || return "$MEOW_OK"
  meow_seco || meow_ok "ZapZap: o WhatsApp veste o tema do pack (do pack $_ZZ_CSS_DE) — $_ZZ_CSS_QUERO (vale quando o ZapZap reabrir)"
  return "$MEOW_DIVERGENTE"
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { meow_flatpak_tem "$_ZZ_APP"; }

# CADA SAÍDA-3 DAQUI DECLARA A CAUSA [21/09/2026]
#   As quatro linhas abaixo devolviam o mesmo 3 sem uma palavra, e o `aplicar`
#   traduzia todas elas por "ZapZap não instalado (ou falta python3)" — que
#   acerta em duas e erra em duas. Agora a causa viaja com o número, pelo
#   `meow_app_sem` do lib/comum.sh.
meow_app_detectar() {
  # Motivo velho mente com cara de medida: zerar antes de medir é do contrato.
  MEOW_APP_MOTIVO=""
  meow_tem flatpak || { meow_app_sem "ZapZap: o flatpak não está instalado"; return; }
  # por diretório, não por `flatpak info`: aquele cria o repositório ostree no
  # home só por ser perguntado, e detecção não pode escrever (ver lib/comum.sh).
  meow_app_instalado || { meow_app_sem "ZapZap: $_ZZ_APP não está instalado"; return; }
  [ -f "$_ZZ_ORIGEM" ] || { meow_app_sem "ZapZap: não achei o .desktop do flatpak em $_ZZ_ORIGEM"; return; }
  # O python3 continua sendo dependência por causa do `ZapZap.conf` (a chave da
  # bandeja). O `whatsapp-desktop` do Papirus saiu da lista em 11/08/2026: ele
  # era a fonte do balão verde, e o balão não é mais instalado — cobrar um
  # arquivo que ninguém lê faria o módulo se declarar sem dependência à toa.
  meow_tem python3 || { meow_app_sem "ZapZap: falta python3, que escreve a chave da bandeja no ZapZap.conf"; return; }
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  [ -f "$_ZZ_DESTINO" ] || return "$MEOW_DIVERGENTE"
  [ "$(_zz_desktop_desejado)" = "$(cat "$_ZZ_DESTINO")" ] || return "$MEOW_DIVERGENTE"
  # A pós-condição do ícone virou de sinal em 11/08/2026: o certo agora é o
  # arquivo NÃO existir em `scalable/apps`, para o glifo de traço de
  # `48x48/apps` poder vencer. Ver o cabeçalho.
  [ ! -f "$(_zz_icone_velho)" ] || _zz_do_pack || return "$MEOW_DIVERGENTE"

  # O ícone da bandeja só é conferido se o conf existir: num ZapZap recém
  # instalado, que nunca abriu, não há arquivo — e cobrar uma chave de um arquivo
  # que o app ainda não criou seria divergência eterna até ela abrir o programa.
  if [ -f "$_ZZ_CONF" ] && [ "$(_zz_tray_atual)" != "$_ZZ_TRAY_DESEJADO" ]; then
    return "$MEOW_DIVERGENTE"
  fi

  # O tema do WhatsApp (P106).
  _zz_css_conferir || return $?

  meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' com o ícone $(_zz_pack_nome)"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  # A frase que estava aqui listava DUAS causas possíveis e imprimia as duas
  # sempre, inclusive quando a verdadeira era uma terceira (o `.desktop` do
  # flatpak sumido). Quem mede é o `detectar`; quem fala é ele, por aqui.
  meow_app_detectar || { meow_app_pendente zapzap; return; }
  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "ZapZap já aparece como '$_ZZ_NOME_NOVO' — nada a fazer"
    return "$MEOW_OK"
  }

  local icone; icone="$(_zz_icone_velho)"
  local mudou=0

  # ANTES de escrever por cima: guardar o original é a regra 4 do contrato, e
  # aqui é o único ponto que pode fazê-lo (o `conferir` não escreve mais).
  # Tem de vir antes do `meow_escrever` do `.desktop`, senão o que se guarda já
  # é a nossa própria saída.
  _zz_guardar_original

  # O balão verde cheio de antes de 11/08/2026. Enquanto ele estiver aqui, o
  # glifo de traço que ela aprovou não chega à tela — o resolvedor pede
  # `scalable` antes de `48x48`.
  if [ -f "$icone" ] && ! _zz_do_pack; then
    if meow_seco; then
      meow_muda "removeria $icone (o glifo de traço do Arcticons é o que vale)"
      mudou=1
    elif meow_destino_permitido "$icone" && rm -f "$icone"; then
      mudou=1
      meow_info "balão verde retirado de scalable/apps — quem veste é o apps-arcticons.map"
    else
      meow_aviso "não consegui remover $icone — o balão cheio continua vencendo"
    fi
  fi

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

  # O tema do WhatsApp (P106). À parte do `mudou`: CSS novo não pede o
  # lançador relido.
  local tema=0
  _zz_css_aplicar
  case $? in
    1) tema=1 ;;
    2) return "$MEOW_ERRO" ;;
    3) tema=3 ;;
  esac

  if [ "$mudou" = "0" ]; then
    [ "$tema" = 1 ] && return "$MEOW_DIVERGENTE"
    [ "$tema" = 3 ] && return "$MEOW_SEM_DEPENDENCIA"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"

  # O lançador lê o cache de .desktop; sem isto o nome novo só apareceria no
  # próximo login. Falhar aqui não é erro: o arquivo já está no lugar certo.
  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  # E O `update-desktop-database` NÃO BASTA — 02/09/2026
  #   Ele reconstrói o índice de MIME. Quem desenha o item do lançador é o
  #   `cosmic-app-library`, que resolve `Icon=` no arranque e guarda. Depois do
  #   `flatpak update` daquela data o arquivo voltou a ser nosso em segundos e o
  #   balão verde de fábrica continuou na tela dela — a queixa foi "o icon do wpp
  #   voltou ao default dele", e metade dela era este cache.
  meow_lancador_reler

  meow_ok "ZapZap agora aparece como '$_ZZ_NOME_NOVO' (o ícone vem do apps-arcticons.map)"
  return "$MEOW_DIVERGENTE"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter zapzap` e, desde 11/08/2026, o passo 2/6 do
# `install.sh --uninstall`. Nada automático chama: o doctor das 05:00 só aplica.
#
# AQUI NÃO SE ESCREVE COM `meow_escrever`, E O MOTIVO É O MANIFESTO
#   Aquela função REGISTRA o que grava. Devolver o `.desktop` de fábrica por ela
#   poria o arquivo restaurado na lista do desinstalador, que o apagaria no passo
#   seguinte: o ZapZap ficaria SEM `.desktop` — sumiria do lançador — em vez de
#   voltar ao que era. Por isso escrita direta. E o registro velho no manifesto
#   não incomoda: o sha de lá é o do NOSSO conteúdo, o arquivo agora tem outro, e
#   a guarda "mudou depois que escrevemos, fica" pula sozinha.
#
# O QUE ELE NÃO DEVOLVE, E POR QUÊ
#   O balão verde de `scalable/apps` não volta. Ele deixou de ser instalado em
#   11/08/2026 (ver o cabeçalho): recriá-lo aqui seria repor uma decisão que ela
#   revogou. O ícone do lançador volta a ser o do flatpak assim que o `Icon=`
#   original está de volta, que é o que importa.
meow_app_reverter() {
  # Mesma lista de causas possíveis do `aplicar`, mesmo conserto.
  meow_app_detectar || { meow_app_pendente zapzap; return; }

  # 0. o tema do WhatsApp (P106): só o nosso arquivo sai.
  local css_mudou=0
  _zz_css_tirar
  case $? in 1) css_mudou=1 ;; 2) return "$MEOW_ERRO" ;; esac

  # Sem o original guardado não há o que devolver — e INVENTAR um `.desktop` de
  # flatpak à mão é a receita para um app que não abre. O caminho de volta existe
  # e é do flatpak; dizemos qual é.
  if [ ! -L "$_ZZ_ORIGEM" ] && [ ! -f "$_ZZ_GUARDADO" ]; then
    meow_aviso "não achei o original em $(basename "$_ZZ_GUARDADO") — não invento um .desktop de flatpak"
    meow_info "  o flatpak recria o dele: flatpak update com.rtosta.zapzap  (ou flatpak repair --user)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local mudou="$css_mudou"
  local tray_atual; tray_atual="$(_zz_tray_atual)"

  if meow_seco; then
    [ -f "$_ZZ_GUARDADO" ] && meow_muda "devolveria o .desktop de fábrica (nome 'ZapZap' de volta)"
    [ "$tray_atual" != "default" ] && meow_muda "devolveria tray_theme=default no ZapZap.conf"
    return "$MEOW_DIVERGENTE"
  fi

  # 1. o `.desktop`. Fica um arquivo REAL onde o flatpak tinha um symlink — o
  #    conteúdo é o mesmo, e o próximo `flatpak update` repõe o link.
  if [ -f "$_ZZ_GUARDADO" ]; then
    if cp -f "$_ZZ_GUARDADO" "$_ZZ_DESTINO" 2>/dev/null; then
      rm -f "$_ZZ_GUARDADO"
      mudou=1
      meow_ok "o .desktop voltou ao de fábrica — o app chama-se 'ZapZap' de novo"
    else
      meow_erro "não consegui devolver $_ZZ_DESTINO"
      return "$MEOW_ERRO"
    fi
  fi

  # 2. o ícone da bandeja, pela mesma porta por onde entrou. `default` é o valor
  #    de fábrica do ZapZap (core/config/settings/appearance.py:24).
  if [ -f "$_ZZ_CONF" ] && [ "$tray_atual" != "default" ]; then
    local novo
    if novo="$(_zz_conf_com_tray default)" && [ -n "$novo" ]; then
      if printf '%s' "$novo" > "$_ZZ_CONF" 2>/dev/null; then
        mudou=1
        meow_ok "ícone da bandeja: default (vale quando o ZapZap reabrir)"
      else
        meow_aviso "não consegui escrever o ZapZap.conf — a bandeja fica símbolica"
      fi
    fi
  fi

  [ "$mudou" = "0" ] && { meow_ok "ZapZap já estava como de fábrica"; return "$MEOW_OK"; }

  meow_tem update-desktop-database && \
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true

  meow_info "o ícone da bandeja segue vestido na FONTE do app (tray_icon.py do flatpak)"
  meow_info "  para devolver aquele: flatpak update com.rtosta.zapzap — ver packs/meowsystem/icones/bandeja.map"
  meow_info "tire 'zapzap' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
