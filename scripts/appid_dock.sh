#!/usr/bin/env bash
# appid_dock.sh — as janelas que a DOCK não desenha, porque o app_id não casa
# com nenhum `.desktop`.
#
# ============================================================================
# A DOR, MEDIDA NA TELA DELA (27/08/2026)
# ============================================================================
#   Ela abriu o Boxy SVG e a janela não apareceu na dock, embora o ícone exista
#   e o cartão apareça no lançador. "são vários programas assim, flatpak tmb."
#
#   Com CINCO janelas abertas (`com.system76.CosmicTerm`, `__main__.py`,
#   `google-chrome`, `com.system76.CosmicFiles`, `boxy-svg-boxy-svg-linux`) a
#   dock desenhou TRÊS itens. Comparando duas capturas, as posições x dos ícones
#   não se moveram um pixel ao abrir o Boxy: o item ausente ocupa ZERO espaço.
#   Os dois que faltam são exatamente os dois que reprovam no `find_app_by_id`.
#
#   `filter_top_levels = None` nos dois arquivos de configuração do applist, ou
#   seja não é filtro de workspace — a explicação rival foi derrubada por
#   experimento, não por argumento: com uma ponte de teste plantada à mão, o
#   Boxy APARECEU na dock, com ponto de "rodando" e já com o ícone traçado do
#   `MeowSystem-Icons`, sem reiniciar o painel. O arquivo de teste foi removido.
#
# ============================================================================
# POR QUE UMA PONTE `StartupWMClass` RESOLVE, E É A ÚNICA ALAVANCA HONESTA
# ============================================================================
#   O `cosmic-app-list` não tem heurística própria: delega tudo a
#   `fde::find_app_by_id` da crate `freedesktop-desktop-entry` 0.8.1 (a versão
#   que o `Cargo.lock` do commit `40248fb` trava, e `40248fb` é o sufixo do
#   `/usr/bin/cosmic-applets` instalado). `StartupWMClass` é a PRIMEIRA das seis
#   etapas, e cada etapa varre o parque INTEIRO antes de a seguinte começar.
#
#   Consequência que decide o desenho deste arquivo: **a etapa vence a
#   precedência XDG**. Medido num parque sintético — um `.desktop` em
#   `$XDG_DATA_HOME` que casava só por NOME DE ARQUIVO PERDEU para um de
#   `/usr/share` que casava por `StartupWMClass`. Ou seja, o truque de "sombra de
#   mesmo basename em `~/.local/share/applications`", que é o coração do
#   `midia.sh` e funciona para o painel achar applet, NÃO VALE AQUI — e não
#   precisa valer. Um arquivo com nome NOSSO ganha a etapa 1 sem encostar no
#   arquivo do flatpak.
#
#   `NoDisplay=true` NÃO atrapalha o casamento (medido: casa igual), então a
#   ponte existe sem virar cartão a mais no lançador.
#
# POR QUE NOME NOSSO, E NÃO UM OVERRIDE DE MESMO BASENAME
#   As duas contas que o arquivo separado não paga:
#   1. SEQUESTRO DE MIME. Medido: com um `com.boxy_svg.BoxySVG.desktop` no home,
#      o `Gio.DesktopAppInfo.new()` devolve O NOSSO — e com ele todo consumidor
#      GIO da máquina. Sem `MimeType=` e sem `--file-forwarding @@ %f @@`, abrir
#      um `.svg` passaria a abrir o Boxy VAZIO, calado.
#   2. DUPLICATA NO LANÇADOR. O `cosmic-app-library` não deduplica por
#      desktop-id: mostra as duas cópias, com "(Local)" e "(Flatpak)" — foi o que
#      ela viu em 04/08 e em 13/08.
#
# ============================================================================
# O NOME DESTE ARQUIVO NÃO É `janelas.sh`, E ISSO É A REGRA 1
# ============================================================================
#   `scripts/janelas.sh` JÁ EXISTE e é o lado a lado (tiling) do cosmic-comp,
#   escrito em 25/08/2026. Dois scripts com o mesmo nome de etapa, ou um só
#   script com duas responsabilidades, é exatamente o dono duplo que já custou a
#   este projeto um laço eterno de seis rodadas. O nome desta etapa é o que ela
#   conserta: o `app_id` na dock.
#
# ============================================================================
# A GUARDA QUE IMPEDE O SEQUESTRO — o pior risco desta etapa
# ============================================================================
#   Uma ponte com `StartupWMClass=google-chrome` venceria
#   `/usr/local/share/applications/google-chrome.desktop`, que é o wrapper
#   ACELERADO do Ritual da Aurora (FRONTEIRA.md, 13/08/2026), e o clique no dock
#   voltaria a subir o Chrome sem `LIBVA_DRIVER_NAME` — o sintoma exato que
#   aquela travessia consertou.
#
#   A guarda NÃO é uma lista de nomes proibidos cravada aqui: seria um segundo
#   dono da decisão, e envelheceria. É dinâmica — antes de escrever, o script
#   pergunta ao casador se aquele app_id JÁ CASA hoje, IGNORANDO as próprias
#   pontes (`--sem-ponte`). Se casa, ele PULA e diz com quem. Medido agora:
#   `google-chrome` casa por `StartupWMClass` em `/usr/local/share` e
#   `com.system76.CosmicTerm` casa por id — nenhum dos dois pode entrar no mapa.
#
#   E ela FALHA FECHADA: se o casador não puder rodar (sem `python3`, parque
#   ilegível), a etapa inteira sai com 3 sem escrever nada. Uma guarda que falha
#   aberta é pior que guarda nenhuma, porque dá confiança.
#
# ============================================================================
# DONO ÚNICO — os três vizinhos, e todos são de dentro de casa
# ============================================================================
#   `jogos_steam.sh` escreve NO MESMO DIRETÓRIO e com a MESMA CHAVE
#   (`meow-steam-<appid>.desktop`, `StartupWMClass=steam_app_<appid>`). A
#   convivência é por três regras: prefixos disjuntos (`meow-steam-` /
#   `meow-janela-`), marcas de autoria disjuntas (`X-MeowSystem=jogo-steam` /
#   `X-MeowSystem=janela-dock`) e o mapa RECUSANDO todo app_id `steam_app_*`.
#   A limpeza daqui nunca apaga por prefixo de nome — só com a marca dentro do
#   arquivo, que é a regra literal do cabeçalho dele: um `.desktop` que ela
#   escreveu à mão não é órfão de ninguém.
#
#   `nomes_apps.sh` EDITA `.desktop` alheio para encurtar o `Name=` — e PULA
#   arquivo oculto (`nomes_apps.sh:212`: `grep -qE '^NoDisplay=true' && continue`).
#   Nossa ponte escapa dele por causa do `NoDisplay=true`. ISSO É DEPENDÊNCIA
#   ACIDENTAL: quem um dia tirar essa linha cria dois donos do mesmo arquivo em
#   silêncio. Por isso `_conferir` ESTOURA se achar uma ponte sem `NoDisplay`.
#   No sentido inverso, se ele encurtar o `Name=` do alvo, a ponte fica velha —
#   e é por isso que `Name=`/`Icon=`/`Exec=` são DERIVADOS a cada passagem.
#   Ordem no `install.sh`: esta etapa vem DEPOIS de `nomes_apps` e de
#   `jogos_steam`, para ler o parque já estabilizado.
#
#   `midia.sh` usa o mesmo mecanismo por um caminho diferente (sombra de mesmo
#   basename, porque o `cosmic-panel` casa applet por basename). Basename fixo,
#   sem interseção com `meow-janela-*`.
#
# ============================================================================
# `Exec=` DERIVADO, NUNCA COPIADO INTEIRO
# ============================================================================
#   A spec §2.1 usa o arquivo vencedor INTEIRO — não há herança nem drop-in. O
#   `Exec` exportado do Boxy congela CINCO coisas que um update pode mudar:
#     Exec=/usr/bin/flatpak run --branch=stable --arch=x86_64 --command=boxy-svg \
#          --file-forwarding com.boxy_svg.BoxySVG @@ %f @@
#   Quando o alvo declara `X-Flatpak=<id>` (todo export declara), a ponte escreve
#   a forma canônica `flatpak run <id>`: o `metadata` do app instalado diz
#   `command=boxy-svg`, que é o mesmo default, e o flatpak resolve ramo,
#   arquitetura e comando lendo o metadata NOVO a cada execução. A ponte fica
#   MAIS à prova de update que o arquivo exportado, não menos.
#   Fora do flatpak, o `Exec` do alvo é copiado SEM os códigos de campo
#   (`%f %F %u %U %i %c %k`): a ponte não recebe arquivo, ela só abre o app.
#
# ============================================================================
# O QUE ESTA ETAPA NÃO FAZ — e cada recusa tem motivo
# ============================================================================
#   · NÃO descobre sozinha. app_id fora do mapa é AVISO com a linha pronta para
#     colar. Escrever por dedução já falharia no primeiro caso desta casa: o
#     briefing previa `boxy-svg` e o medido é `boxy-svg-boxy-svg-linux`.
#   · NÃO edita nem o `.desktop` do flatpak, nem o dela, nem nada em `/usr`.
#     A ponte é ADITIVA: desfazer é `rm`, sem `sudo`, sem restaurar nada.
#   · NÃO escreve `MimeType=` nem `Categories=`. Quem abre `.svg` continua sendo
#     o arquivo do flatpak, intacto.
#   · NÃO reinicia o `cosmic-panel`. O aplicar já vale a quente sozinho: o
#     applist RE-VARRE o disco quando o casamento FALHA (`app.rs:804`), e é
#     justamente a falha que estamos consertando. O desfazer é assimétrico — só
#     aparece no próximo login, e tudo bem: derrubar o painel esgota o supervisor
#     (backoff 2^N × sorteio(0..9), sem teto e que nunca zera).
#   · NÃO grava estado em `$MEOW_ESTADO` além do manifesto que a `meow_escrever`
#     já preenche. Um coletor residente seria um segundo dono do mapa.
#   · NÃO fixa nada na dock. Quem escolhe favorito é ela.
#
# POR QUE app_id NÃO MAPEADO NÃO DEVOLVE 1
#   Porque 1 significa "divergia e EU CONSERTEI", e aqui nada foi consertado —
#   falta uma decisão dela. Devolver 1 faria o `tests/convergencia.sh` nunca
#   convergir: o instalador diria "mudou" para sempre, sem nada a mudar. O aviso
#   vai para a tela (`meow_aviso` escreve mesmo em `LOG_NIVEL=silencioso`) e o
#   código continua honesto.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

MAPA="$RAIZ/assets/icones/appid.map"
SONDA="$RAIZ/scripts/appid_sonda.py"
APPS="$HOME/.local/share/applications"
MARCA="X-MeowSystem=janela-dock"
PREFIXO="meow-janela-"

declare -A MAPA_LIDO=()     # app_id -> desktop-id do alvo
declare -A ALIAS_OK=()      # desktop-id -> 1, quando a repetição é deliberada
declare -A ALVO_CAMINHO=()  # desktop-id -> caminho do .desktop que VENCE
declare -A ALVO_NOME=()     # desktop-id -> Name=
declare -A ALVO_ICONE=()    # desktop-id -> Icon=
declare -A ALVO_EXEC=()     # desktop-id -> Exec= já derivado
declare -A JA_CASA=()       # app_id -> "etapa<TAB>caminho", ignorando nossas pontes
MAPA_ORDEM=()               # a ordem do arquivo, para a saída sair legível

# --- o arquivo da ponte, sanitizado ------------------------------------------
# Tudo fora de [A-Za-z0-9._-] vira `-`. O prefixo `meow-janela-` é a convenção
# que o `jogos_steam.sh` estabeleceu, e mantém a ponte fora da 2ª etapa do
# casamento (que compara o último componente pontuado do app_id com o file_stem).
_arquivo_de() {
  local id="$1"
  printf '%s%s.desktop' "$PREFIXO" "$(printf '%s' "$id" | tr -c 'A-Za-z0-9._-' '-')"
}

# --- o mapa, lido uma vez ----------------------------------------------------
# Dois campos e um opcional, separados por ':'. Nem app_id nem desktop-id usam
# ':' — o primeiro é uma string de protocolo, o segundo é nome de arquivo.
_ler_mapa() {
  local linha id alvo marca
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    IFS=':' read -r id alvo marca <<<"$linha"
    [ -n "$id" ] && [ -n "$alvo" ] || continue
    MAPA_LIDO["$id"]="$alvo"
    MAPA_ORDEM+=("$id")
    if [ "${marca:-}" = "alias" ]; then ALIAS_OK["$alvo"]=1; fi
  done < "$MAPA"
  # `return 0` não é decoração: `while` devolve o status do último comando do
  # corpo, e a última linha do mapa não é um alias — com `set -e` o script
  # morreria aqui, calado e com código 1. (A mesma cicatriz do `icones_sistema.sh`.)
  return 0
}

# --- as asserções que ESTOURAM em vez de deixar passar ------------------------
_conferir_mapa() {
  local id alvo arq erro=0
  declare -A visto_alvo=() visto_arq=()
  for id in "${!MAPA_LIDO[@]}"; do
    alvo="${MAPA_LIDO[$id]}"

    # A chave do `jogos_steam.sh`. Dois donos numa chave é a regra 1.
    case "$id" in
      steam_app_*)
        meow_erro "'$id' é chave do jogos_steam.sh — tire esta linha do mapa"
        erro=1 ;;
    esac

    # Duas pontes para o mesmo alvo quase sempre são um app_id velho esquecido
    # aqui depois de uma atualização.
    if [ -n "${visto_alvo[$alvo]:-}" ] && [ -z "${ALIAS_OK[$alvo]:-}" ]; then
      meow_erro "dois app_id apontam para o mesmo alvo '$alvo': '$id' e '${visto_alvo[$alvo]}'"
      meow_erro "  decida: tire o app_id velho, ou marque a repetição com ':alias'"
      erro=1
    fi
    visto_alvo["$alvo"]="$id"

    # Dois app_id que sanitizam para o MESMO arquivo se sobrescreveriam em
    # silêncio, e a segunda ponte simplesmente não existiria.
    arq="$(_arquivo_de "$id")"
    if [ -n "${visto_arq[$arq]:-}" ]; then
      meow_erro "'$id' e '${visto_arq[$arq]}' geram o mesmo arquivo '$arq'"
      erro=1
    fi
    visto_arq["$arq"]="$id"
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

# --- dependências ------------------------------------------------------------
# A SONDA NÃO É DEPENDÊNCIA DO APLICAR, e isso é decisão de desenho: quem manda
# é o MAPA, que é um arquivo do repositório. O instalador tem de aplicar as
# pontes num terminal sem sessão gráfica, e o `tests/convergencia.sh` tem de dar
# o mesmo resultado nas duas rodadas independentemente de quais janelas estavam
# abertas. A sonda alimenta só o AVISO.
#
# O CASADOR, esse é dependência dura — é ele que impede o sequestro.
_pronto() {
  if [ ! -f "$MAPA" ]; then
    meow_pula "sem assets/icones/appid.map — nenhuma ponte de janela a construir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3 || [ ! -f "$SONDA" ]; then
    meow_pula "sem python3 ou sem scripts/appid_sonda.py — sem o casador não se escreve ponte"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- o parque, lido uma vez, pelo mesmo código que o dock usa -----------------
# Só o PRIMEIRO de cada desktop-id entra: é a precedência XDG, e a sonda já
# entrega o parque na ordem de `fde::default_paths()`.
_ler_parque() {
  local id caminho nome icone exec flat n=0
  while IFS=$'\t' read -r id caminho nome icone exec flat; do
    [ -n "$id" ] || continue
    [ -z "${ALVO_CAMINHO[$id]:-}" ] || continue
    ALVO_CAMINHO["$id"]="$caminho"
    ALVO_NOME["$id"]="$nome"
    ALVO_ICONE["$id"]="$icone"
    if [ -n "$flat" ]; then
      # A forma canônica mínima — ver o cabeçalho.
      ALVO_EXEC["$id"]="/usr/bin/flatpak run $flat"
    else
      # Sem os códigos de campo: a ponte não recebe arquivo, ela abre o app.
      ALVO_EXEC["$id"]="$(printf '%s' "$exec" \
        | sed -E 's/ --file-forwarding//g; s/ @@u?( |$)/\1/g; s/ %[a-zA-Z]//g; s/[[:space:]]+$//')"
    fi
    n=$((n + 1))
  done < <(python3 "$SONDA" --parque)
  [ "$n" -gt 0 ] || { meow_erro "o casador não leu nenhum .desktop — parque ilegível"; return "$MEOW_ERRO"; }
  return "$MEOW_OK"
}

# --- "este app_id já casava ANTES de nós?" ------------------------------------
# `--sem-ponte` descarta os `.desktop` que carregam a marca de autoria. Sem isso
# a resposta na segunda rodada seria "casa" — a nossa própria ponte — e o script
# apagaria o que acabou de escrever, num laço eterno. É esta linha que faz a
# etapa convergir.
_ler_casamentos() {
  local id etapa caminho
  [ "${#MAPA_ORDEM[@]}" -gt 0 ] || return 0
  while IFS=$'\t' read -r id etapa caminho; do
    [ "$etapa" = "-" ] && continue
    JA_CASA["$id"]="$etapa"$'\t'"$caminho"
  done < <(printf '%s\n' "${MAPA_ORDEM[@]}" | python3 "$SONDA" --casar --sem-ponte)
  return 0
}

# --- o corpo da ponte, derivado do alvo a cada passagem -----------------------
_corpo() {
  local id="$1" alvo="$2"
  printf '%s\n' \
    '[Desktop Entry]' \
    '# Gerado por MeowSystem/scripts/appid_dock.sh a partir de assets/icones/appid.map.' \
    '# Ponte de app_id: existe só para o cosmic-app-list achar esta janela.' \
    '# Não é o .desktop do aplicativo — o de verdade continua intacto, e é ele' \
    '# que abre os arquivos. Edições aqui são desfeitas: mude o mapa.' \
    'Type=Application' \
    "Name=${ALVO_NOME[$alvo]}" \
    "Icon=${ALVO_ICONE[$alvo]}" \
    "Exec=${ALVO_EXEC[$alvo]}" \
    'Terminal=false' \
    'NoDisplay=true' \
    "StartupWMClass=$id" \
    "$MARCA" \
    "X-MeowSystem-AppId=$id" \
    "X-MeowSystem-Alvo=$alvo.desktop"
}

# --- o que deveria estar no disco --------------------------------------------
# "app_id<TAB>alvo". Sai daqui quem PULA, e cada pulo diz o motivo em voz alta —
# um pulo silencioso é o que faz uma etapa parecer conforme sem estar.
_desejado() {
  local id alvo
  for id in ${MAPA_ORDEM[@]+"${MAPA_ORDEM[@]}"}; do
    alvo="${MAPA_LIDO[$id]}"
    if [ -z "${ALVO_CAMINHO[$alvo]:-}" ]; then
      meow_pula "'$id': o alvo '$alvo.desktop' não está instalado — fica como está" >&2
      continue
    fi
    if [ -n "${JA_CASA[$id]:-}" ]; then
      meow_pula "'$id' JÁ casa por ${JA_CASA[$id]%%$'\t'*} em ${JA_CASA[$id]#*$'\t'} — não sequestro" >&2
      continue
    fi
    if [ -z "${ALVO_NOME[$alvo]:-}" ]; then
      meow_pula "'$id': o alvo '$alvo.desktop' não tem Name= — nada a desenhar na dock" >&2
      continue
    fi
    [ -n "${ALVO_ICONE[$alvo]:-}" ] || \
      meow_aviso "'$id': o alvo '$alvo.desktop' não tem Icon= — a ponte aparece sem ícone"
    printf '%s\t%s\n' "$id" "$alvo"
  done
}

# --- órfão: só com PROVA DE AUTORIA ------------------------------------------
# Devolve os caminhos a remover. Nunca por prefixo de nome sozinho: um
# `meow-janela-*` que ela tenha escrito à mão, sem a marca, não é órfão de
# ninguém — é dela.
_orfaos() {
  local arq id mantidas="$1"
  [ -d "$APPS" ] || return 0
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || continue
    id="$(sed -n 's/^X-MeowSystem-AppId=//p' "$arq" | head -n1)"
    printf '%s' "$mantidas" | grep -qxF "$(_arquivo_de "$id")" && continue
    printf '%s\t%s\n' "$arq" "${id:-<sem app_id>}"
  done
  return 0
}

# --- o AVISO: app_id vivo, sem casamento e fora do mapa -----------------------
# É assim que a etapa "colhe sozinha" — sem daemon, sem estado, sem escrita. Ela
# olha o que está aberto AGORA, e monta a linha para ela colar no mapa.
_avisar_novos() {
  local id titulo etapa caminho cand novos=0
  declare -A vivos=() titulos=()

  if ! python3 "$SONDA" --janelas >/dev/null 2>&1; then
    meow_pula "sem sessão Wayland utilizável — não dá para colher app_id agora"
    return 0
  fi
  while IFS=$'\t' read -r id titulo; do
    [ -n "$id" ] || continue
    [ -n "${MAPA_LIDO[$id]:-}" ] && continue      # já decidido
    case "$id" in steam_app_*) continue ;; esac   # chave do jogos_steam.sh
    vivos["$id"]=1
    titulos["$id"]="$titulo"
  done < <(python3 "$SONDA" --janelas)

  [ "${#vivos[@]}" -gt 0 ] || return 0

  # Sem `--sem-ponte`: aqui a pergunta é "a dock desenha?", e uma ponte nossa
  # que já resolveu o caso conta como casamento.
  while IFS=$'\t' read -r id etapa caminho; do
    [ "$etapa" = "-" ] || continue
    novos=$((novos + 1))
    if [ "$novos" = 1 ]; then
      meow_aviso "janela(s) aberta(s) cujo app_id não casa com nenhum .desktop:"
    fi
    cand="$(printf '%s\n' "$id" | python3 "$SONDA" --sugerir | cut -f2)"
    meow_aviso "  app_id '$id'   (janela: ${titulos[$id]:-?})"
    if [ -n "$cand" ]; then
      meow_aviso "  se for um destes, cole em assets/icones/appid.map:"
      local c
      for c in ${cand//,/ }; do meow_aviso "      $id:$c"; done
    else
      meow_aviso "  nenhum .desktop parecido — escolha o alvo à mão e cole:"
      meow_aviso "      $id:<desktop-id-sem-.desktop>"
    fi
  done < <(printf '%s\n' "${!vivos[@]}" | python3 "$SONDA" --casar)

  [ "$novos" = 0 ] || meow_aviso "  (nada foi escrito: o mapa é curado à mão, de propósito)"
  return 0
}

# --- a auditoria de dois donos ------------------------------------------------
# Uma ponte sem `NoDisplay=true` cairia no alcance do `nomes_apps.sh`, que
# reescreve `Name=` de arquivo alheio. Dois donos do mesmo arquivo, em silêncio.
_conferir_donos() {
  local arq erro=0
  [ -d "$APPS" ] || return "$MEOW_OK"
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || continue
    if ! grep -qxF 'NoDisplay=true' "$arq"; then
      meow_erro "a ponte '$arq' perdeu o NoDisplay=true"
      meow_erro "  sem ele o nomes_apps.sh passa a editar este arquivo: dois donos"
      erro=1
    fi
  done
  [ "$erro" = 0 ] || return "$MEOW_ERRO"
  return "$MEOW_OK"
}

# --- conferir: NÃO ESCREVE NADA ----------------------------------------------
# O critério tem de ser o do escritor: `meow_escrever` grava com `printf '%s'`,
# que come o `\n` final, então um `cmp` byte a byte acusaria divergência eterna
# num arquivo perfeito.
_conferir() {
  local id alvo arq ausentes=0 divergentes=0 orfaos=0 total=0 mantidas=""
  _conferir_donos || return $?

  while IFS=$'\t' read -r id alvo; do
    total=$((total + 1))
    arq="$APPS/$(_arquivo_de "$id")"
    mantidas="$mantidas$(_arquivo_de "$id")"$'\n'
    if [ ! -f "$arq" ]; then
      ausentes=$((ausentes + 1))
    elif [ "$(_corpo "$id" "$alvo")" != "$(cat "$arq")" ]; then
      divergentes=$((divergentes + 1))
    fi
  done < <(_desejado)

  while IFS=$'\t' read -r arq id; do
    [ -n "$arq" ] || continue
    meow_muda "removeria a ponte de '$id' ($(basename "$arq")) — saiu do mapa ou o alvo sumiu"
    orfaos=$((orfaos + 1))
  done < <(_orfaos "$mantidas")

  _avisar_novos

  if [ "$ausentes" = 0 ] && [ "$divergentes" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total ponte(s) de app_id conformes"
    return "$MEOW_OK"
  fi
  meow_muda "pontes de app_id: $ausentes a criar, $divergentes a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local id alvo arq rc mudou=0 postas=0 removidas=0 mantidas=""
  _conferir_donos || return $?

  while IFS=$'\t' read -r id alvo; do
    arq="$APPS/$(_arquivo_de "$id")"
    mantidas="$mantidas$(_arquivo_de "$id")"$'\n'
    set +e
    meow_escrever "$arq" "$(_corpo "$id" "$alvo")" 644
    rc=$?
    set -e
    case "$rc" in
      "$MEOW_OK") ;;
      "$MEOW_DIVERGENTE") mudou=1; postas=$((postas + 1)) ;;
      *) meow_erro "não consegui escrever $arq"; return "$MEOW_ERRO" ;;
    esac
  done < <(_desejado)

  while IFS=$'\t' read -r arq id; do
    [ -n "$arq" ] || continue
    if meow_seco; then
      meow_muda "removeria a ponte de '$id' ($(basename "$arq"))"
    else
      meow_destino_permitido "$arq" || return "$MEOW_ERRO"
      rm -f "$arq"
      meow_info "ponte de '$id' removida (saiu do mapa ou o alvo sumiu)"
    fi
    mudou=1; removidas=$((removidas + 1))
  done < <(_orfaos "$mantidas")

  _avisar_novos

  if [ "$mudou" = 0 ]; then
    meow_ok "pontes de app_id já conformes"
    return "$MEOW_OK"
  fi
  # No seco, o verbo tem de ser o condicional: um "2 escritas" numa auditoria
  # que não escreveu nada é a mesma mentira que o `meow_notificar` do seco já
  # pendurou na TV dela uma vez.
  if meow_seco; then
    meow_muda "pontes de app_id: $postas a escrever, $removidas a remover"
    return "$MEOW_DIVERGENTE"
  fi
  meow_info "pontes de app_id: $postas escrita(s), $removidas removida(s)"
  meow_info "vale na próxima janela que o app abrir — o applist re-varre o disco quando o casamento falha"
  return "$MEOW_DIVERGENTE"
}

# --- reverter: `rm`, sem sudo, sem rede, sem restaurar nada -------------------
# A ponte é ADITIVA. Nunca editou o .desktop do flatpak, nunca materializou
# symlink, nunca encostou em /usr. Não há `.meow-original` a repor.
_reverter() {
  local arq n=0
  [ -d "$APPS" ] || { meow_ok "nada a reverter"; return "$MEOW_OK"; }
  for arq in "$APPS/$PREFIXO"*.desktop; do
    [ -e "$arq" ] || continue
    grep -qxF "$MARCA" "$arq" || { meow_pula "$(basename "$arq") não tem a nossa marca — é dela, fica"; continue; }
    if meow_seco; then
      meow_muda "removeria $arq"
    else
      meow_destino_permitido "$arq" || return "$MEOW_ERRO"
      rm -f "$arq"
    fi
    n=$((n + 1))
  done
  [ "$n" = 0 ] && { meow_ok "nenhuma ponte de app_id no disco"; return "$MEOW_OK"; }
  meow_info "$n ponte(s) removida(s); o dock volta ao estado antigo no próximo login"
  meow_info "(o applist só re-varre o disco quando o casamento FALHA — e agora ele não falha mais)"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_mapa
  _conferir_mapa || return $?

  case "${1:-}" in
    --reverter) _reverter; return $? ;;
  esac

  _ler_parque || return $?
  _ler_casamentos

  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; return "$MEOW_ERRO" ;;
  esac
}

main "$@"
