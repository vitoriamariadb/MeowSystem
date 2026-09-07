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
#   cursor.sh listar     um valor por linha: os ponteiros que a chave CURSOR aceita
#   cursor.sh adicionar <url-ou-zip-ou-pasta>   instala um ponteiro de terceiro
#   cursor.sh remover [valor]   devolve o cursor de fábrica e apaga o que instalamos
#                        (sem argumento: o tema do $CURSOR; com argumento: aquele)
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

# AS TRÊS RAÍZES DE BUSCA, EM UMA LISTA SÓ — 06/09/2026
#   Elas já estavam aqui, escritas à mão dentro do `_cursor_instalado`. Passaram
#   a ser uma lista porque o `listar` precisa percorrer EXATAMENTE o mesmo
#   conjunto que o `aplicar` sabe resolver: uma lista que ofereça menos do que o
#   `aplicar` aceita esconde um ponteiro instalado, e uma que ofereça mais
#   devolve um botão que falha na rede (foi esse o defeito que o
#   `_temas_de_cursor` do painel consertou em 01/09). Com uma lista só não há
#   como as duas divergirem no dia em que uma quarta raiz aparecer.
#
#   A primeira é onde ESTE script instala; as outras duas são só de leitura — a
#   TRAVA 1 do lib/comum.sh proíbe escrever em `/usr/share`.
CURSOR_RAIZES=("$CURSOR_ICONES" "$HOME/.icons" "/usr/share/icons")

# O que o `adicionar` acabou de pôr no disco — lido pelo `_cursor_dizer_como_usar`.
CURSOR_ADICIONADO=""

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
  local nome raiz; nome="$(_cursor_nome_tema "$1")"
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz/$nome/cursors" ] && return 0
  done
  return 1
}

# Os valores que a chave `CURSOR` aceita, um por linha, sem repetir.
#
# O QUE SE IMPRIME É O VALOR, E NÃO O NOME DA PASTA — E A DIFERENÇA JÁ CUSTOU
# QUATRO BOTÕES QUEBRADOS NA TELA DELA
#   A pasta chama `catppuccin-mocha-light-cursors`; o valor que o `aplicar`
#   resolve é `catppuccin-mocha-light`, porque o `_cursor_nome_tema` acrescenta o
#   sufixo SEMPRE. Imprimir a pasta faria a página gravar
#   `CURSOR=catppuccin-mocha-light-cursors`, o `aplicar` procuraria
#   `…-cursors-cursors`, não acharia, e sairia BAIXANDO um zip que não existe.
#   Esse é literalmente o defeito medido em 01/09/2026 e registrado no
#   `_temas_de_cursor` do `app/servidor.py`. A lista existe para dizer o que
#   FUNCIONA, não o que está no disco.
#
#   Pelo mesmo motivo, pasta que não termine em `-cursors` fica de fora mesmo
#   tendo ponteiros dentro: o `aplicar` não sabe montar o nome dela. MEDIDO
#   nesta máquina em 06/09/2026 — há TRÊS diretórios com um `cursors/` dentro
#   (`/usr/share/icons/Adwaita`, `/usr/share/icons/Pop` e
#   `~/.local/share/icons/catppuccin-mocha-light-cursors`) e só o último tem
#   nome que a chave sabe escolher. É por isso que a página mostra UM: não é a
#   página que está errada, é a máquina que tem um só.
_cursor_temas_instalados() {
  local raiz d nome
  for raiz in "${CURSOR_RAIZES[@]}"; do
    [ -d "$raiz" ] || continue
    for d in "$raiz"/*-cursors; do
      [ -d "$d/cursors" ] || continue
      nome="$(basename -- "$d")"
      printf '%s\n' "${nome%-cursors}"
    done
  done | sort -u
}

# --- instalação ------------------------------------------------------------
# A ROTA DE DESCARGA, EM UMA FUNÇÃO SÓ — 06/09/2026
#   O `aplicar` baixa do release pinado do catppuccin/cursors; o `adicionar`
#   baixa de um endereço que ela escolheu. Os dois querem exatamente o mesmo
#   cuidado (falhar inteiro, com tempo-limite, sem seguir para o disco), e uma
#   segunda invocação de `curl` escrita ao lado desta seria a segunda verdade
#   sobre "como este projeto baixa arquivo" — a que ninguém corrige no dia em que
#   a primeira ganhar um cabeçalho ou um limite novo.
#
#   `--fail` para que uma página de erro do GitHub (HTTP 404 com corpo HTML) não
#   vire um "zip corrompido" três linhas abaixo; `--max-time` porque um
#   temporizador é a única coisa que separa "sem rede" de "pendurado para
#   sempre" num script que o instalador chama desatendido.
_cursor_curl() {
  curl -sSL --fail --connect-timeout 15 --max-time 300 -o "$2" "$1" 2>/dev/null
}

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
# POR QUE ESTE SUBCOMANDO EXISTE, E QUAL QUEIXA ELE RESPONDE
#   "Temas do Ponteiro só aparece um." A medição de 06/09/2026 diz que a página
#   está CERTA: existe um só diretório `*-cursors` na máquina inteira (a conta
#   está no `_cursor_temas_instalados`). O que faltava não era a lista, era a
#   porta de entrada — sem ela, ganhar um ponteiro novo exigia abrir um
#   terminal, e o painel não tinha o que chamar.
#
# O NOME DA PASTA GANHA O SUFIXO `-cursors` QUANDO NÃO O TEM, E ISSO NÃO É
# CAPRICHO
#   O `_cursor_nome_tema` acrescenta `-cursors` SEMPRE, então um tema instalado
#   como `Bibata-Modern-Ice` é um tema que a chave `CURSOR` não sabe escolher: o
#   `aplicar` procuraria `Bibata-Modern-Ice-cursors`, não acharia, e sairia
#   BAIXANDO um zip do release do catppuccin que não existe. Instalar com o nome
#   cru seria pôr no disco algo que a interface mostra e o clique não resolve —
#   o mesmo defeito que o painel consertou em 01/09 tirando três botões da lista.
#   Renomear o DIRETÓRIO é seguro porque, para o XCursor, o nome do tema É o nome
#   do diretório: o `index.theme` de dentro traz `Name=`, que nenhuma das duas
#   alavancas deste script consulta.
#
# O ARGUMENTO É TEXTO DE FORA, E É TRATADO COMO TAL
#   Nada de `eval`, nada de `shell=True`: o caminho e a URL entram citados em
#   todo comando, o nome que sai de dentro do pacote é peneirado para
#   `[A-Za-z0-9._-]` antes de virar diretório, e a extração acontece num
#   temporário — nunca direto no destino. Um zip com `../` no caminho não tem por
#   onde escapar: o `unzip` já recusa subir, e o que entra no destino é o
#   `basename` peneirado, nunca o caminho que veio no pacote.
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
# A IDEMPOTÊNCIA É POR CONTEÚDO, COMO A REGRA 5 DO PROJETO MANDA
#   "Já existe um diretório com esse nome" responderia 0 para um tema instalado
#   pela metade — que é exatamente o estado que o `_cursor_baixar_instalar`
#   inteiro existe para evitar. O `diff -rq` responde a pergunta certa: é o mesmo
#   tema, arquivo a arquivo? Sem o `diff` no PATH a pergunta não tem resposta
#   honesta, e aí a presença do diretório é o melhor que se pode dizer — dito em
#   voz alta, não escondido.
_cursor_instalar_pasta() {
  local origem="$1" nome destino
  nome="$(_cursor_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  case "$nome" in *-cursors) : ;; *) nome="$nome-cursors" ;; esac
  destino="$CURSOR_ICONES/$nome"

  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq -- "$origem" "$destino" >/dev/null 2>&1; then
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
  # escreve "só num temporário". Baixar é pior: é gastar a rede dela para
  # ensaiar. Então o seco responde pelo NOME, que é palpite, e diz que é.
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

# A LISTA É DADO, NÃO RELATÓRIO — por isso ela sai limpa no stdout
#   Quem chama é a página, que quer um valor por linha e nada mais. Toda linha
#   decorada deste script (`meow_ok`, `meow_info`) já vai para o stdout com
#   marcador e cor; misturar as duas coisas obrigaria o outro lado a filtrar por
#   aparência, que é o acoplamento mais frágil que existe entre dois programas.
#   Aqui não se imprime mais nada: lista vazia é uma resposta legítima, e o
#   código de saída continua 0 porque LER não muda nada.
cmd_listar() {
  _cursor_temas_instalados
  return "$MEOW_OK"
}

# `remover` sem argumento é o de sempre: desliga as duas alavancas e apaga o tema
# do `$CURSOR`. Com um argumento, apaga SÓ o tema nomeado — é o desfazer do
# `adicionar`, e sem ele o subcomando novo seria a única coisa deste script que
# entra no disco e não sabe sair.
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
# SÓ APAGA O QUE ESTÁ EM `$CURSOR_ICONES`, E ISSO É PROPOSITAL
#   Tema que veio de `/usr/share/icons` é do gerenciador de pacotes (a TRAVA 1
#   recusaria o caminho de qualquer jeito) e tema em `~/.icons` não foi este
#   script que pôs lá. Apagar o que não instalamos é destruir configuração alheia
#   em nome de "reverter" — a mesma regra que o `_cursor_default_e_nosso` aplica
#   ao `index.theme` do compositor.
#
#   E se o tema apagado for o que a chave `CURSOR` aponta, a tela dela cai no
#   ponteiro de fábrica no próximo login sem ninguém avisar. Então avisa-se.
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
