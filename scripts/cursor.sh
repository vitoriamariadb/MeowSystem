#!/usr/bin/env bash
# cursor.sh — o ponteiro, que é o único elemento que atravessa a tela inteira o
# tempo todo e era o de fábrica.
#
# LEIA ISTO ANTES DE ACREDITAR QUE `gsettings cursor-theme` RESOLVE
#   Não resolve sozinho, e a razão é que NESTA MÁQUINA EXISTEM DOIS CURSORES
#   DESENHADOS POR DOIS PROGRAMAS DIFERENTES, com dois mecanismos de escolha que
#   não se falam. Medido em 25/08/2026:
#
#   1. O CURSOR DO COMPOSITOR — o que ela vê sobre a área de trabalho, sobre o
#      painel, sobre a dock e sobre qualquer superfície que não seja GTK. Quem
#      desenha é o `cosmic-comp`, e ele NÃO LÊ GSETTINGS PARA ISSO:
#        strings /usr/bin/cosmic-comp | grep -c 'cursor-theme'   ->  0
#      A ÚNICA chave `org.gnome.desktop.interface` que o binário carrega é
#      `color-scheme` (o literal no binário é
#      "/usr/bin/gsettings" "get" "org.gnome.desktop.interface" "color-scheme").
#      O que ele usa é a crate `xcursor` (`vendor/xcursor/src/lib.rs` aparece no
#      binário) com a variável `XCURSOR_THEME` — e ela está VAZIA no ambiente do
#      processo vivo (`tr '\0' '\n' < /proc/$(pgrep -x cosmic-comp)/environ`
#      não devolve uma linha de XCURSOR). Sem a variável, o nome do tema cai no
#      literal `default`, que é resolvido pelo caminho de busca do XCursor.
#
#   2. O CURSOR DOS APLICATIVOS GTK — o que ela vê DENTRO de uma janela GTK.
#      Esse sim sai do gsettings, e quem o lê é a libgtk, não um binário do
#      COSMIC:
#        strings libgtk-3.so.0 | grep -c cursor-theme   ->  2
#        strings libgtk-4.so.1 | grep -c cursor-theme   ->  3
#      (a chave vira `gtk-cursor-theme-name` no GtkSettings). Por isso a varredura
#      `grep -rl cursor-theme /usr/bin/` devolve ZERO arquivos: nenhum executável
#      do sistema lê essa chave — quem lê é biblioteca, dentro de cada app.
#
#   Conclusão prática, e é o desenho inteiro deste script: **escrever só o
#   gsettings troca o cursor DENTRO das janelas GTK e deixa o cursor do desktop
#   como estava.** Um script que fizesse só isso "funcionaria" no teste e
#   deixaria metade da tela com o cursor de fábrica.
#
# O 'Pop' QUE O gsettings DEVOLVE É DEFAULT DE ESQUEMA, NÃO ESCOLHA GRAVADA
#   Esta distinção importa para o `remover`, e foi medida:
#     gsettings get org.gnome.desktop.interface cursor-theme  ->  'Pop'
#     dconf read /org/gnome/desktop/interface/cursor-theme    ->  (VAZIO)
#   O valor vem de dois overrides de pacote:
#     /usr/share/glib-2.0/schemas/50_pop-desktop.gschema.override:33
#     /usr/share/glib-2.0/schemas/10_cosmic-session.gschema.override:5
#   O segundo é `[org.gnome.desktop.interface:COSMIC]`, ou seja, um default POR
#   AMBIENTE. Nunca houve valor escrito no dconf dela. É por isso que o `remover`
#   faz `gsettings reset` e NÃO `gsettings set ... 'Pop'`: repor 'Pop' à mão
#   deixaria um valor gravado onde antes não havia nenhum — o `reset` devolve o
#   estado exatamente como estava, e o valor efetivo volta a ser 'Pop' de graça,
#   pelo override. Desligar tem de DESLIGAR, e isso inclui não deixar sujeira.
#
# ONDE A CHAVE **NÃO** MORA, para ninguém refazer a procura
#   `~/.config/cosmic/com.system76.CosmicTk/v1/` tem apply_theme_global,
#   header_size, icon_theme, interface_density, interface_font e monospace_font.
#   NÃO existe `cursor_theme`. `com.system76.CosmicComp/v1/` também não tem —
#   as 14 chaves de lá são de entrada, autotile, workspaces e xkb. Ou seja: o
#   COSMIC não tem, hoje, controle de tema de cursor em lugar nenhum da GUI.
#
# A FRONTEIRA COM O RITUAL DA AURORA — PERGUNTADA ANTES DE ESCREVER, E MEDIDA
#   A `docs/FRONTEIRA.md:53` dá `gsettings`/`dconf` à Aurora, mas nomeando
#   `button-layout`. A pergunta "e `cursor-theme`?" foi feita medindo, e a
#   resposta é QUE A CHAVE É NOSSA. As quatro medições que sustentam isso:
#
#     a) TODO `gsettings set` vivo da Aurora mira OUTRO esquema. O grep
#        `grep -rn 'gsettings set' ~/.config/zsh/scripts/` devolve só
#        `aurora-button-layout.service:19` e `ritual-aurora-self-heal.sh:1833`,
#        e os dois escrevem `org.gnome.desktop.wm.preferences button-layout` —
#        `wm.preferences`, não `desktop.interface`. Nenhum toca `desktop.interface`.
#
#     b) A ÚNICA ocorrência de `cursor-theme` no repositório dela é
#        `functions/restaurar.zsh:587`, e ela é de um comando MANUAL de
#        recuperação de desastre (`sistema_restaurar <manifesto.json>`, alias
#        `restaurar`). Não há timer, unidade nem self-heal que a chame: o grep
#        por chamadores só acha o alias em `aliases.zsh:361` e a linha de ajuda
#        do `install.sh:1680`.
#
#     c) Mesmo se ela rodasse à mão, a linha não dispara NESTA máquina. O
#        `__restaurar_capturar_tema()` (restaurar.zsh:151-158) tem saída
#        antecipada para COSMIC — `if [[ "$de" == *"COSMIC"* ]]; then echo
#        "|||24|"; return 0; fi` — que grava cursor VAZIO no manifesto, e o lado
#        que escreve é guardado por `[[ -n "$cursor" ]]`. Guarda falsa, escrita
#        nenhuma.
#
#     d) E não há manifesto: `~/.config/andromeda/manifesto/` NÃO EXISTE no
#        disco, então não há nem o `dconf-backup.ini` que a restaurar.zsh:594
#        carregaria com `dconf load /`.
#
#   Registrado porque a assimetria é o ponto: a Aurora manda em `wm.preferences`
#   (o `button-layout`, que ela reaplica de 5 em 5 minutos por timer), e o Meow
#   manda em `desktop.interface` (onde já moram `icon-theme` = MeowSystem-Icons e
#   `gtk-theme`, que são nossos por esta mesma tabela). Não há um único ponto em
#   que os dois escrevam a mesma chave.
#
#   O ÚNICO risco residual está registrado para não ser esquecido: o `dconf load /`
#   da restaurar.zsh:594 é um restaurador EM MASSA — se um dia existir um
#   `dconf-backup.ini`, ele repõe o dump inteiro, `cursor-theme` junto. Isso não
#   é disputa de chave, é um comando de desastre que sobrescreve tudo por
#   definição, e ele é manual. Não muda o dono; muda o que dizer se um dia o
#   cursor voltar sozinho DEPOIS de ela ter rodado `restaurar` à mão.
#
# AS DUAS ALAVANCAS QUE ESTE SCRIPT PUXA, E POR QUE SÃO DUAS
#   A. `gsettings org.gnome.desktop.interface cursor-theme` — pega os apps GTK,
#      VALE NA HORA (a libgtk assina a mudança do GSettings; nada a reiniciar).
#   B. `~/.icons/default/index.theme` com `Inherits=<tema>` — pega o
#      `cosmic-comp`, e só VALE NO PRÓXIMO LOGIN, porque o compositor carrega o
#      tema de cursor uma vez, na subida.
#
#      Essa é a forma canônica e por-usuário de trocar o cursor do X/Wayland, e
#      ela funciona porque o caminho de busca da crate `xcursor` põe o HOME na
#      frente do sistema. Os literais estão no binário do `cosmic-settings`, nesta
#      ordem: `.icons`, `.local/share/icons`, `/usr/local/share/icons`,
#      `/usr/share/pixmaps`, `/usr/share/cursors/xorg-x11`, mais `XCURSOR_PATH`,
#      `XDG_DATA_HOME` e `XDG_DATA_DIRS`. Como `~/.icons/default` vem ANTES de
#      `/usr/share/icons/default`, o nosso `Inherits` vence sem que ninguém
#      encoste em `/usr/share` — que a TRAVA 1 proíbe de qualquer jeito.
#
#      O que existe hoje em `/usr/share/icons/default/index.theme` é
#      `Inherits=Adwaita`. Ou seja: **antes deste script, o cursor do desktop
#      dela era o Adwaita, não o 'Pop' que o gsettings anuncia** — e o Adwaita
#      tem corpo PRETO (medido: a cor opaca dominante do `default` dele é
#      #000000, contra #ffffff do Pop). Sobre papel de parede escuro, preto some.
#      Não dá para provar isso por captura de tela: o `cosmic-screenshot` não
#      grava o ponteiro, e a partição é `noatime`, então o atime dos arquivos de
#      cursor também não denuncia quem foi lido. A checagem de um segundo é
#      humana: se o ponteiro dela tem miolo PRETO, é Adwaita; se tem miolo
#      BRANCO, é Pop.
#
#   NÃO se mexe em `XCURSOR_THEME` por variável de ambiente. Fazer isso exigiria
#   escrever em `~/.config/environment.d/` ou `~/.config/autostart/` — e
#   `~/.config/autostart/` é da Aurora nesta mesma tabela (FRONTEIRA.md:52).
#   O `index.theme` do home chega no mesmo lugar sem cruzar fronteira nenhuma.
#
# O TAMANHO É DELA, E POR ISSO ESTE SCRIPT NÃO O ESCREVE
#   `cursor-size` = 24, e também é default de esquema (o `dconf read` é vazio).
#   24 é igualmente o default da crate `xcursor` quando `XCURSOR_SIZE` não existe
#   — que é o caso. Os dois lados já concordam em 24 sem ninguém gravar nada, e
#   gravar seria trocar um acordo silencioso por uma imposição nossa. O script
#   informa o tamanho em vigor e não o toca.
#
# A ARMADILHA DO NOME DO FLAVOR — E ELA DERRUBA O MOTIVO DA ESCOLHA
#   Está medido, com contagem de pixel opaco, no `default` de cada tema:
#
#     tema                       corpo (cor dominante)   contorno    luminância
#     catppuccin-latte-mauve     #8839ef  790 px         #eff1f5      86,9/255
#     catppuccin-mocha-mauve     #cba6f7  790 px         #1e1e2e     179,7/255
#     catppuccin-frappe-mauve    #ca9ee6  790 px         #303446     172,6/255
#
#   Nos flavors com nome de ACCENT (`-mauve`), o corpo é pintado com a cor do
#   ACCENT e o CONTORNO com a cor Base do flavor. Isso é o INVERSO do que se
#   supõe: o Latte-mauve é o de corpo mais ESCURO dos três (86,9), e o
#   Mocha-mauve é o mais CLARO (179,7). A regra "só o Latte tem corpo claro" vale
#   para os flavors `-light`/`-dark` do mesmo release, não para os de accent.
#   Quem decide é ela, e a folha visual existe para ela ver isto com os próprios
#   olhos antes de o valor entrar no meow.conf.
#
# LICENÇA (regra do projeto: acervo de terceiro tem licença registrada)
#   O tema é o Volantes Cursors (varlesh), **GPL-2.0**, recolorido com a paleta
#   Catppuccin e empacotado por catppuccin/cursors. Registro auditável no
#   repositório: `assets/cursores/CREDITOS.md`. Este script escreve uma cópia do
#   `LICENSE` e do `AUTHORS` que vêm dentro do próprio pacote ao lado do tema
#   instalado, para que a auditoria também funcione na máquina dela.
#
# USO
#   cursor.sh aplicar    baixa, instala em ~/.local/share/icons e aponta as duas
#                        alavancas (idempotente; sem rede, falha inteira e diz o
#                        comando manual — nunca instala pela metade)
#   cursor.sh conferir   0 = igual · 1 = divergente · 3 = falta dependência
#   cursor.sh estado     diz qual cursor cada metade da tela está usando hoje
#   cursor.sh remover    devolve o cursor de fábrica e apaga o que instalamos
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Vazio = NÃO TOCA, exatamente como VIDRO_OPACIDADE_PAINEL/DOCK fazem desde
# 17/08/2026. É o que permite ela desistir do tema sem desinstalar nada.
CURSOR="${CURSOR:-}"
CURSOR_VERSAO="${CURSOR_VERSAO:-v2.0.0}"

CURSOR_ICONES="$HOME/.local/share/icons"
CURSOR_DEFAULT_DIR="$HOME/.icons/default"
CURSOR_DEFAULT="$CURSOR_DEFAULT_DIR/index.theme"
CURSOR_CHAVE="org.gnome.desktop.interface"

# O diretório do tema é sempre `<valor>-cursors`: é o nome que o próprio pacote
# usa por dentro, e o `index.theme` do tema não pode ser renomeado sem quebrar a
# correspondência com o `Inherits` que escrevemos.
_cursor_dir_tema() { printf '%s/%s-cursors' "$CURSOR_ICONES" "$1"; }
_cursor_nome_tema() { printf '%s-cursors' "$1"; }
_cursor_url() {
  printf 'https://github.com/catppuccin/cursors/releases/download/%s/%s-cursors.zip' \
         "$CURSOR_VERSAO" "$1"
}

# O `index.theme` que faz o compositor obedecer. O `Comment=` não é enfeite: é a
# assinatura que o `remover` usa para saber se este arquivo é nosso. Sem ela,
# apagar um `~/.icons/default/index.theme` que ela mesma tenha escrito um dia
# seria destruir configuração alheia em nome de "reverter".
_cursor_default_texto() {
  printf '[Icon Theme]\nName=Default\nComment=escrito pelo MeowSystem (scripts/cursor.sh)\nInherits=%s\n' \
         "$(_cursor_nome_tema "$1")"
}

_cursor_default_e_nosso() {
  [ -f "$CURSOR_DEFAULT" ] && grep -q 'MeowSystem' "$CURSOR_DEFAULT" 2>/dev/null
}

# LER NÃO PODE ESCREVER — E O `gsettings get` ESCREVE QUANDO NÃO HÁ BARRAMENTO
#   Medido em 25/08/2026: com a sessão de pé, `gsettings get` fala com o serviço
#   do dconf e não toca em disco nenhum. SEM `DBUS_SESSION_BUS_ADDRESS`, o
#   cliente do dconf não tem com quem falar e CRIA `~/.cache/dconf/user` sozinho
#   — abrindo com O_RDWR|O_CREAT. Uma LEITURA que escreve.
#
#   Isso deixou o `tests/seco.sh` vermelho: ele roda o `install.sh --dry-run` com
#   `env -i` num HOME vazio, justamente para provar que o seco não escreve nada,
#   e a fase de DETECÇÃO do cursor sujava o HOME. É a mesma classe do defeito que
#   aquele teste já pegou em 10/08 (o `code --list-extensions` e o
#   `flatpak info` deixando oito arquivos): detecção com efeito colateral.
#
#   `DCONF_PROFILE=/dev/null` cala a criação do cache. Mas ele NÃO pode valer
#   sempre que falta barramento, e essa foi a minha primeira tentativa, errada:
#   sem perfil o `gsettings get` devolve o default do ESQUEMA e não o que está
#   no banco da usuária, então logo depois de um `gsettings set` a leitura ainda
#   diz `Adwaita` — a etapa se acha divergente e reescreve A CADA PASSAGEM. Isso
#   deixou o `tests/convergencia.sh` vermelho ("ainda mexia na passagem 3"): eu
#   tinha trocado um teste quebrado por outro.
#
#   A guarda certa é o SECO, não o barramento. No seco não há `set` nenhum para
#   ler de volta — só se descreve o que MUDARIA —, então o default do esquema
#   serve de base e nada precisa ser exato. Fora do seco o caminho é o normal, e
#   aí criar o cache do dconf não viola promessa alguma: execução que escreve,
#   escreve.
#
#   Vale só para LEITURA. O `gsettings set` lá embaixo nunca passa por aqui.
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
  local nome; nome="$(_cursor_nome_tema "$1")"
  [ -d "$CURSOR_ICONES/$nome/cursors" ] && return 0
  [ -d "$HOME/.icons/$nome/cursors" ] && return 0
  [ -d "/usr/share/icons/$nome/cursors" ] && return 0
  return 1
}

# --- instalação ------------------------------------------------------------
# TUDO OU NADA. O tema são 121 arquivos; um download cortado no meio deixaria um
# diretório com metade dos ponteiros e o cursor sumindo em algumas formas e não
# em outras — o tipo de defeito que ninguém liga ao instalador. Por isso o zip
# desce inteiro para um temporário, é extraído inteiro, conferido, e só então
# entra no lugar com um `mv` único.
_cursor_baixar_instalar() {
  local valor="$1" url tmp zip extraido origem destino
  url="$(_cursor_url "$valor")"
  destino="$(_cursor_dir_tema "$valor")"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  meow_tem curl  || { meow_erro "falta curl";  return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }

  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-cursor.XXXXXX")" || return "$MEOW_ERRO"
  zip="$tmp/tema.zip"

  if ! curl -sSL --fail --connect-timeout 15 --max-time 300 -o "$zip" "$url" 2>/dev/null; then
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
  if _cursor_instalado "$CURSOR"; then
    meow_ok "tema de cursor '$nome' já está instalado"
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
    # CONFERIR DEPOIS DE ESCREVER, PORQUE O `gsettings set` MENTE (25/08/2026)
    #   Medido num HOME de brinquedo sem `DBUS_SESSION_BUS_ADDRESS`:
    #       gsettings set ... cursor-theme 'teste-meow'   -> exit 0, sem uma
    #       gsettings get ... cursor-theme                -> 'Adwaita'   palavra
    #   O escritor do dconf é um serviço de D-Bus (`ca.desrt.dconf`). Sem
    #   barramento não há quem guarde, e mesmo assim o `gsettings` sai ZERO.
    #
    #   O efeito era esta etapa se achar divergente TODA passagem e reescrever
    #   para sempre — `tests/convergencia.sh` acusava "ainda mexia na passagem
    #   3", e o culpado era `cursor`. Confiar no código de saída é o modo de
    #   falha silencioso de sempre: o instalador dizia "já vale" e nada valia.
    #
    #   Não é erro fatal: numa sessão de verdade isto nunca acontece, e num CI
    #   sem sessão não há o que consertar. Então vira PULO, com o conserto dito
    #   em voz alta — e, principalmente, sem contar como mudança, senão a
    #   promessa de convergência do README seria falsa em qualquer máquina sem
    #   barramento.
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

cmd_remover() {
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

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: cursor.sh {aplicar|conferir|estado|remover}"; exit "$MEOW_ERRO" ;;
esac
