#!/usr/bin/env bash
# lib/comum.sh — a base de todo módulo do MeowSystem: cores, log, códigos de
# saída e as duas travas que impedem o instalador de estragar a máquina dela.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO.
#
# AS CORES SAEM DA PALETA, COMO TUDO AQUI
#   São os mesmos hex de `assets/paleta/catppuccin.json`, convertidos para o truecolor
#   do terminal. Se um dia a paleta mudar, muda aqui também — mas continua sem
#   inventar cor nova no meio do caminho.
#
# CÓDIGOS DE SAÍDA HONESTOS (regra 7 do contrato)
#   0 = certo · 1 = divergente · 2 = erro de execução · 3 = falta dependência.
#   A diferença entre 1 e 3 é o que permite ao auto-reparo ficar quieto quando o
#   app simplesmente não está instalado, e gritar quando algo de fato quebrou.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# A VARIÁVEL QUE VALE É `MEOW_DRY_RUN`, E ESTA LINHA É O MOTIVO
#   Esta atribuição roda no `source`, então `MEOW_SECO=1 ./algum_script.sh` é
#   SOBRESCRITO aqui e não liga seco nenhum — o script roda de verdade achando
#   que está só prevendo. Aconteceu comigo em 24/08/2026: dois `semear` que eu
#   dei por "em seco" foram execuções reais. Dentro do script, depois deste
#   source, atribuir `MEOW_SECO=1` funciona (é o que o `--conferir` faz).
MEOW_SECO="${MEOW_DRY_RUN:-0}"

MEOW_OK=0; MEOW_DIVERGENTE=1; MEOW_ERRO=2; MEOW_SEM_DEPENDENCIA=3

if [ -t 1 ] && [ "${NO_COLOR:-}" = "" ]; then
  C_MAUVE=$'\033[38;2;203;166;247m'; C_ROSA=$'\033[38;2;245;194;231m'
  C_VERDE=$'\033[38;2;166;227;161m'; C_AMARELO=$'\033[38;2;249;226;175m'
  C_VERM=$'\033[38;2;243;139;168m';  C_AZUL=$'\033[38;2;137;180;250m'
  C_DIM=$'\033[38;2;127;132;156m';   C_FORTE=$'\033[1m'; C_ZERO=$'\033[0m'
else
  C_MAUVE=""; C_ROSA=""; C_VERDE=""; C_AMARELO=""; C_VERM=""; C_AZUL=""
  C_DIM=""; C_FORTE=""; C_ZERO=""
fi

# --- LOG_NIVEL: silencioso | info | debug -----------------------------------
# A chave existia no `meow.conf.exemplo` desde a primeira versão e NENHUM script
# a lia — o `meow configurar` perguntava, dizia "gravado", e a saída continuava
# idêntica. Em 08/08/2026 as chaves inertes foram varridas: as da estrutura do
# tema saíram (não tinham como funcionar), e esta ficou, porque custa três
# linhas e é o único jeito de calar o instalador.
#
# O QUE ELA CALA, E O QUE NUNCA CALA
#   `silencioso` esconde o que é PROGRESSO — título, passo, info e o "já estava
#   certo". Continua mostrando o que MUDOU (`~~`), o que foi pulado, aviso e
#   erro. Um modo silencioso que engula erro não é silêncio, é cegueira: quem
#   liga isto quer parar de ler 25 etapas dizendo "ok", não parar de saber que
#   algo quebrou. `debug` não acrescenta ruído por conta própria; ele existe
#   para os scripts consultarem com `meow_debug`.
MEOW_LOG_NIVEL="${LOG_NIVEL:-info}"
meow_quieto() { [ "$MEOW_LOG_NIVEL" = "silencioso" ]; }
meow_debug()  { [ "$MEOW_LOG_NIVEL" = "debug" ] && printf '  %s..%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; return 0; }

meow_titulo() { meow_quieto && return 0
                printf '\n%s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO"; }
meow_passo()  { meow_quieto && return 0
                printf '\n  %s%s%s\n  %s%s%s\n' "$C_MAUVE$C_FORTE" "$*" "$C_ZERO" \
                       "$C_DIM" "$(printf '%.0s─' {1..52})" "$C_ZERO"; }
meow_info()   { meow_quieto && return 0
                printf '  %s>>%s %s\n' "$C_AZUL" "$C_ZERO" "$*"; }
meow_ok()     { meow_quieto && return 0
                printf '  %sok%s   %s\n' "$C_VERDE" "$C_ZERO" "$*"; }
meow_muda()   { printf '  %s~~%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*"; }
meow_pula()   { printf '  %s--%s   %s\n' "$C_DIM" "$C_ZERO" "$*"; }
meow_aviso()  { printf '  %s!!%s   %s\n' "$C_AMARELO" "$C_ZERO" "$*" >&2; }
meow_erro()   { printf '  %serro%s %s\n' "$C_VERM" "$C_ZERO" "$*" >&2; }
meow_seco()   { [ "$MEOW_SECO" = "1" ]; }

# --- O MOTIVO DA PENDÊNCIA: quem mede é o `detectar`, quem fala é o `aplicar` -
#
# O DEFEITO QUE ISTO MATA, MEDIDO EM 21/09/2026
#   O Spotify dela ESTÁ instalado: `flatpak list --app` devolve
#   `com.spotify.Client 1.2.95.453.g0eeebbed stable user`, com o `Apps/xpui`
#   patchado e o spicetify já pintando o app de Dracula. E o log do install.sh
#   do mesmo dia dizia, com todas as letras:
#
#     --   Spotify não instalado (ou não é o flatpak de usuário)
#
#   A causa verdadeira era outra, e o módulo a conhecia: falta o tema catppuccin
#   em ~/.config/spicetify/Themes. O `meow_app_detectar` mediu isso e devolveu
#   3; o `meow_app_aplicar` recebeu só o NÚMERO e imprimiu a primeira frase de
#   uma lista de causas possíveis. O código de saída sobreviveu à viagem, o
#   motivo não — e frase chutada é pior que silêncio: ela manda a pessoa
#   procurar defeito onde não há. O mesmo desenho estava em quatro módulos.
#
# O CONTRATO, EM DUAS FUNÇÕES
#   `meow_app_sem "<motivo>"`      guarda a causa e devolve 3. É a ÚNICA porta
#                                  por onde um `detectar` sai pendente.
#   `meow_app_pendente <módulo>`   diz a causa guardada e devolve 3. É a ÚNICA
#                                  forma de `aplicar`/`conferir`/`reverter`
#                                  anunciarem a pendência.
#
#   O IDIOMA É `... || { meow_app_sem "..."; return; }`, E O `return` NU É DE
#   PROPÓSITO: sem argumento ele devolve o status do último comando, que é o 3
#   da própria `meow_app_sem`. Motivo e código saem do mesmo lugar, então não há
#   como um ficar para trás quando o outro mudar.
#
#   TODO `detectar` COMEÇA ZERANDO O MOTIVO. Um motivo velho, deixado por uma
#   chamada anterior que falhou por outra razão, mente igual ao chute — e mente
#   com cara de coisa medida, que é pior.
#
# MOTIVO VAZIO É DEFEITO DO MÓDULO, NÃO CASO A COBRIR COM FRASE GENÉRICA
#   Uma frase guarda-chuva ("não deu para agir agora") é exatamente como o
#   defeito acima nasceu: ela cala o buraco em vez de mostrá-lo. Por isso o
#   motivo vazio aparece na tela como erro de programação E quebra o
#   `tests/reversao.sh`. É a única forma de a próxima saída-3 sem motivo não
#   nascer muda.
MEOW_APP_MOTIVO=""

meow_app_sem() { MEOW_APP_MOTIVO="$*"; return "$MEOW_SEM_DEPENDENCIA"; }

meow_app_pendente() {
  local modulo="${1:-sem nome}"
  if [ -n "$MEOW_APP_MOTIVO" ]; then
    meow_pula "$MEOW_APP_MOTIVO"
  else
    meow_erro "sem motivo declarado — defeito no módulo $modulo"
  fi
  return "$MEOW_SEM_DEPENDENCIA"
}

# --- A PORTA ÚNICA DA PALETA -------------------------------------------------
#
# POR QUE ISTO EXISTE [2026-09-17]
#   Onze lugares liam a paleta, e DEZ cravavam o nome do arquivo:
#     scripts/terminal.sh:260        scripts/midia.sh:74
#     scripts/icones_apps_arcticons.sh:111
#     assets/temas-de-apps/heroic/manifesto.sh:161
#     assets/temas-de-apps/spotify/manifesto.sh:168
#     app/servidor.py:158            scripts/gerar_icones_autorais.py:123
#     scripts/folha_conversor.py:94  scripts/folha_marcas.py:166
#     scripts/folha_proposta.py:154
#   O décimo primeiro — scripts/gerar_temas.py:52 — já respeitava `PALETA_ARQUIVO`
#   e `MEOW_PALETA` desde 11/09/2026, e o comentário dele prometia que a paleta
#   era trocável pelo meow.conf.
#
#   A promessa era falsa em duas camadas. A chave `PALETA_ARQUIVO` não existia no
#   meow.conf.exemplo, e o install.sh chamava o gerador sem exportar variável
#   nenhuma. E mesmo que existisse, trocar a paleta teria partido o projeto ao
#   meio: o tema do COSMIC viria de uma paleta e o terminal, os ícones, o painel
#   e os temas de aplicativo continuariam lendo o Catppuccin. Não daria erro —
#   daria DIVERGÊNCIA SILENCIOSA, que é pior.
#
# O CONTRATO, em ordem de precedência
#   1. $MEOW_PALETA       caminho completo. É a porta de teste e a que um pack usa.
#   2. $PALETA_ARQUIVO    só o nome, resolvido dentro de assets/paleta/.
#   3. catppuccin.json    o embutido, que continua sendo o default de sempre.
#   A ordem é EXATAMENTE a de scripts/gerar_temas.py:52-54, que já funcionava —
#   esta função generaliza aquele comportamento, não inventa outro.
#
# POR QUE UMA FUNÇÃO, E NÃO UMA VARIÁVEL EXPORTADA
#   Uma variável precisaria ser exportada em TODO ponto de entrada — as etapas
#   do install.sh e as ações do bin/meow, que são dezenas — e esquecer um ponto
#   daria o mesmo defeito de novo, calado. Uma função resolve na hora da
#   chamada, e quem esquecer de usá-la aparece no grep de tests/estilo.sh.
#
#   O NÚMERO EXATO SAIU DAQUI EM 21/09/2026, E NÃO FOI ATUALIZADO
#     Esta linha dizia "54 etapas, 46 ações". Eram 58 e 50 desde o commit que
#     as mudou, e este arquivo foi editado DEPOIS dele sem que ninguém notasse:
#     o `tests/numeros.sh` cobra README, LEIA-ME e SPRINTS, e não cobra
#     comentário de biblioteca. Um número sem cobrador apodrece — a armadilha
#     nº 3 do projeto num único inteiro. Quem conta de verdade é o
#     `_medidas_do_projeto()` do `app/servidor.py`; aqui o que vale é a ordem
#     de grandeza, e ela não muda.
#
#   E O `grep` DO tests/estilo.sh PASSOU A EXISTIR NO MESMO DIA
#     Até 21/09/2026 a frase acima descrevia uma cobrança que não estava
#     escrita em lugar nenhum: o `tests/estilo.sh` mede a caneta do conversor e
#     não olhava uma linha de código. Agora ele abre com essa varredura, antes
#     das guardas de dependência, e ela morde de verdade.
#
# QUEM NÃO PODE USAR ESTA FUNÇÃO
#   Os cinco consumidores em Python. Eles repetem as três linhas equivalentes,
#   com um comentário apontando para cá — é o idioma que gerar_temas.py já usava,
#   e acrescentar um módulo importável entre `scripts/` e `app/` traria um
#   problema de sys.path que este projeto não tem hoje.
meow_paleta() {
  if [ -n "${MEOW_PALETA:-}" ]; then
    printf '%s' "$MEOW_PALETA"
    return 0
  fi
  # O PACK ATIVO VEM ANTES DO EMBUTIDO [19/09/2026]
  #   Sem esta consulta o formato de pack ficava pela metade: `meow_pack_dir`
  #   resolvia `packs/<id>` corretamente, o `pack validar` conferia os 26 slots
  #   da `paleta.json` dele, e nenhum consumidor a lia. O pack declarava uma
  #   paleta que não vestia nada — e a tela continuava saindo do embutido,
  #   calada, que é a forma mais cara de um formato falhar.
  #
  #   Medido antes de ligar, e é por isso que ligar foi seguro: os 26 slots do
  #   flavor `dracula` são IDÊNTICOS nos dois arquivos hoje. Trocar a fonte não
  #   move um pixel nesta máquina — o que muda é que a partir daqui o pack passa
  #   a mandar de verdade, que é o ponto do formato.
  local _pack_dir
  _pack_dir="$(meow_pack_dir)"
  if [ -n "$_pack_dir" ] && [ -f "$_pack_dir/paleta.json" ]; then
    printf '%s' "$_pack_dir/paleta.json"
    return 0
  fi
  printf '%s' "$MEOW_RAIZ/assets/paleta/${PALETA_ARQUIVO:-catppuccin.json}"
}

# O nome do arquivo, sem o caminho — para MENSAGEM, nunca para abrir.
# Existe porque as mensagens de erro também cravavam "assets/paleta/catppuccin.json"
# (icones_apps_arcticons.sh:394 e :489, midia.sh:195), e uma mensagem que nomeia
# o arquivo errado manda a pessoa procurar defeito onde não há.
# O diretório do pack ativo, ou vazio se for o embutido.
#
# Quem decide qual pack é o ativo: a chave PACK do meow.conf. Sem ela, o pack é
# o embutido (Catppuccin) e esta função devolve vazio — que é o sinal para o
# chamador usar os caminhos de sempre em assets/.
#
# O resolvedor de verdade é scripts/pack.py (ver docs/PACKS.md). Esta função só
# pergunta a ele, e o faz sem sair do lugar quando não há pack: um fork de
# python por script, num instalador de 54 etapas, custaria caro à toa.
meow_pack_dir() {
  local PACK="${PACK:-}"
  # ADOÇÃO POR CONVENÇÃO [2026-09-17]
  #   Sem a chave PACK, um FLAVOR que nomeie um pack existente adota esse pack.
  #   É o que faz um meow.conf escrito ANTES do formato existir continuar
  #   valendo: o desta máquina tem FLAVOR="dracula" e nenhuma linha PACK, e
  #   exigir a chave nova faria o desktop perder os ícones no primeiro `meow
  #   ativar` depois da atualização — calado, que é o pior jeito.
  #   A chave explícita continua vencendo; isto é só o default.
  if [ -z "$PACK" ] && [ -n "${FLAVOR:-}" ]; then
    local base
    for base in "${MEOW_PACKS:-}" "${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/packs" "$MEOW_RAIZ/packs"; do
      [ -n "$base" ] || continue
      [ -f "$base/$FLAVOR/pack.json" ] && { PACK="$FLAVOR"; break; }
    done
  fi
  [ -n "$PACK" ] || return 0
  [ "$PACK" = "catppuccin" ] && return 0
  python3 "$MEOW_RAIZ/scripts/pack.py" caminho "$PACK" id >/dev/null 2>&1 || {
    meow_aviso "pack '$PACK' não resolve — usando o embutido"
    return 0
  }
  local d
  for base in "${MEOW_PACKS:-}" "${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/packs" "$MEOW_RAIZ/packs"; do
    [ -n "$base" ] || continue
    d="$base/$PACK"
    [ -f "$d/pack.json" ] && { printf '%s' "$d"; return 0; }
  done
  return 0
}

# Um caminho de dentro do pack ativo, com queda para o do núcleo.
#   meow_pack_arquivo icones/apps.map  assets/icones/apps-dracula.map
# devolve o primeiro que existir, nessa ordem. É o que permite migrar um acervo
# para dentro de um pack sem quebrar quem ainda não migrou.
meow_pack_arquivo() {
  local no_pack="$1" no_nucleo="${2:-}" dir
  dir="$(meow_pack_dir)"
  if [ -n "$dir" ] && [ -e "$dir/$no_pack" ]; then
    printf '%s' "$dir/$no_pack"
    return 0
  fi
  [ -n "$no_nucleo" ] && [ -e "$MEOW_RAIZ/$no_nucleo" ] && printf '%s' "$MEOW_RAIZ/$no_nucleo"
  return 0
}

meow_paleta_nome() {
  local p; p="$(meow_paleta)"
  printf '%s' "${p#"$MEOW_RAIZ"/}"
}

# --- A RAIZ DO COSMIC: UM LUGAR SÓ PARA DIZER ONDE ELA É --------------------
# Onde mora a configuração do COSMIC desta pessoa.
#
# HAVIA DOIS IDIOMAS, E SÓ UM DELES ERA HONRADO [21/09/2026]
#   Medido no dia: 11 pontos em shell liam `${MEOW_COSMIC_DIR:-$HOME/...}` e 24
#   cravavam o caminho direto — entre eles o `lib/preflight.sh`, que é o
#   GUARDIÃO e roda antes da primeira escrita. Uma costura meio construída é
#   pior que nenhuma: quem lê o código vê a variável e supõe que ela vale,
#   quando ela valia em pouco mais de um terço dos lugares.
#
#   A divergência ainda não mordeu ninguém, e o motivo é um acaso: NADA neste
#   repositório atribui `MEOW_COSMIC_DIR` — conferido em 21/09/2026, zero
#   atribuições. Quem desvia a raiz nos testes desvia o `HOME` inteiro
#   (`tests/convergencia.sh` roda o instalador com `env -i HOME=<temporário>`),
#   e mover o HOME move os dois idiomas de uma vez. O dia em que alguém usar a
#   variável para valer é o dia em que metade do projeto olha para o lugar
#   errado, calada. Fechar a costura agora é mais barato que depurar aquilo.
#
# ISTO NÃO É UMA CAMADA DE DESKTOP, E A RECUSA ESTÁ MEDIDA
#   Também em 21/09/2026: de 89 arquivos executáveis do projeto, 72 citam o
#   COSMIC. Portar para GNOME/KDE foi recusado com esse número na mesa, e o
#   `meow_preflight` já recusa instalar fora do COSMIC. Um verbo com um ramo só
#   fecha uma divergência que existe; um `case` com um ramo só mentiria dizendo
#   que existe alternativa.
#
# O QUE MUDA SOB `set -u` COM HOME INDEFINIDO, E POR QUE PASSA
#   Medido em 21/09/2026: a expansão inline morria na hora (`HOME: variável não
#   associada`, rc 127). O verbo morre no SUBSHELL do `$( )`, então quem o chama
#   sem `set -e` SEGUE com a raiz VAZIA — e os caminhos viram
#   `/com.system76...`. Nenhum caminho do projeto roda assim: os oito `env -i`
#   do repositório são todos de `tests/` e passam `HOME=`, e o único de
#   produção (`scripts/painel.sh:390`) lança o `cosmic-panel`, não um script
#   meow. Fica registrado porque o sintoma, no dia em que houver um, será um
#   caminho absoluto esquisito e não uma mensagem de erro.
#
# Quem esquecer de chamá-lo aparece no grep do `tests/estilo.sh`. Lá a cobrança
# é só para CÓDIGO: comentário continua livre, porque é onde a explicação mora
# e reescrevê-la apagaria o porquê.
meow_cosmic_dir() {
  printf '%s' "${MEOW_COSMIC_DIR:-$HOME/.config/cosmic}"
}

# --- TRAVA 1: territórios proibidos ----------------------------------------
# Uma escrita fora de lugar aqui não dá erro: dá um sintoma bizarro dias depois.
#
# SÃO DUAS LISTAS, E A DIFERENÇA ENTRE ELAS É A DIFERENÇA ENTRE MÁQUINA E PROJETO
#   A primeira vale em qualquer lugar do mundo: /usr é território do gerenciador
#   de pacotes, e um `apt upgrade` sobrescreve.
#
#   O "o self-heal reverte em até 1h" que estava escrito aqui era grande demais
#   para o que é medido: em 10/08/2026, `grep -rn /usr/share/applications
#   ~/.config/zsh` não devolveu UMA linha. O Aurora disputa `/usr/share` em
#   pontos nomeados (o ícone do App Library, self-heal:793 — e lá ele só DESFAZ o
#   que a v3.45 dele plantou), não o diretório inteiro. Quem escreve em
#   `/usr/share/applications` é o MeowSystem, sozinho: `ocultar_apps.sh` e
#   `nomes_apps.sh`, com `sudo install` direto, por fora desta função.
#
#   A trava continua recusando o caminho, e isso está certo: ela existe para que
#   ninguém escreva ali SEM PERCEBER. Quem precisa escrever escolheu escrever, e
#   documentou por quê — no caso do lançador, porque o `cosmic-app-library` não
#   deduplica por ID e uma cópia no home apareceria ao LADO da do sistema, e não
#   no lugar dela. O que NÃO servia era "o pacote do apt é o backup": reinstalar
#   um pacote para desfazer uma linha é caro demais para ser um botão de volta.
#   Agora essas três escritas passam por `meow_backup_sistema` (abaixo), só
#   acontecem com LANCADOR_SISTEMA="sim", e voltam por `meow desfazer --lancador`.
#
#   A segunda lista é dos VIZINHOS desta máquina — aqui, o repo Andromeda em
#   ~/.config/zsh (auto-commit a cada 10min: arquivo largado lá vira commit no
#   repo PRIVADO dela) e os atalhos de teclado, que são do Ritual da Aurora.
#
#   Cravar a segunda no código fazia o instalador recusar, na máquina de um
#   estranho, um diretório que é dele: `~/.config/zsh` é a convenção ZDOTDIR mais
#   comum do mundo zsh, e a recusa vinha explicada por um "repo Andromeda" que
#   ele não tem. Pior: a própria completion mora lá, e a trava já tinha uma
#   exceção reimplementada à mão (install.sh:185) para contorná-la.
MEOW_PROIBIDOS_SISTEMA=(/usr/share /usr/local/share /usr/bin /usr/lib)
MEOW_PROIBIDOS_LOCAIS=()
MEOW_VIZINHOS="${MEOW_VIZINHOS:-$HOME/.config/meow/vizinhos.conf}"
if [ -f "$MEOW_VIZINHOS" ]; then
  while IFS= read -r _l || [ -n "$_l" ]; do
    _l="${_l%%#*}"                      # comentário no fim da linha
    _l="${_l%"${_l##*[![:space:]]}"}"   # apara espaço à direita
    [ -z "$_l" ] && continue
    # SEM `eval`: a única expansão que este arquivo precisa é $HOME, e passar as
    # linhas por eval transformaria um arquivo de configuração em execução de
    # código — `$(rm -rf ~)` numa linha bastaria.
    MEOW_PROIBIDOS_LOCAIS+=("${_l//\$HOME/$HOME}")
  done < "$MEOW_VIZINHOS"
  unset _l
fi

meow_destino_permitido() {
  local alvo="$1" real p
  real="$(readlink -m -- "$alvo")"
  for p in "${MEOW_PROIBIDOS_SISTEMA[@]}"; do
    case "$real" in "$p"/*)
      meow_erro "recusado: '$alvo' é território do sistema e do gerenciador de pacotes"
      return 1 ;;
    esac
  done
  # Casa o caminho exato e tudo abaixo dele. Escreva CAMINHO ABSOLUTO no
  # vizinhos.conf: um nome solto de componente não é casado no meio do caminho,
  # ao contrário do que a regra antiga dos atalhos fazia.
  for p in ${MEOW_PROIBIDOS_LOCAIS[@]+"${MEOW_PROIBIDOS_LOCAIS[@]}"}; do
    case "$real" in "$p"|"$p"/*)
      meow_erro "recusado: '$alvo' pertence a outro projeto nesta máquina ($p)"
      return 1 ;;
    esac
  done
  return 0
}

# --- TRAVA 2: escrita atômica no MESMO sistema de arquivos ------------------
# O repo mora em /mnt/Apate e os destinos em /home: `mv` entre eles NÃO é
# atômico, e um corte no meio deixaria arquivo de config pela metade. O
# temporário nasce sempre dentro do diretório de DESTINO.
meow_escrever() {
  local destino="$1" conteudo="$2" modo="${3:-644}" tmp dir
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  if [ -f "$destino" ] && [ "$conteudo" = "$(cat "$destino" 2>/dev/null)" ]; then
    return "$MEOW_OK"   # regra 5: comparar por conteúdo, não escrever à toa
  fi
  if meow_seco; then
    meow_muda "mudaria $destino"
    return "$MEOW_DIVERGENTE"
  fi
  mkdir -p "$dir" || return "$MEOW_ERRO"
  # O PREFIXO `.atomicwrite` NÃO É COSMÉTICO — 26/08/2026
  #   O `cosmic-config` do libcosmic IGNORA de propósito os temporários cujo nome
  #   começa com `.atomicwrite`, ao traduzir eventos de inotify em mudanças de
  #   chave (`libcosmic/cosmic-config/src/lib.rs:407-408`:
  #       // Skip any .atomicwrite temporary files
  #       if key.starts_with(".atomicwrite") { continue }
  #   ), porque é assim que ele mesmo escreve.
  #
  #   Com o nosso `.meow.` o painel recebia QUATRO eventos por chave gravada — o
  #   Create do temporário, o Modify(Data), o Name(From) e só então o Name(To)
  #   legítimo —, e cada um faz o `cosmic-panel` reler a ENTRADA INTEIRA e
  #   recomitar o raio de canto contra o bbox do frame anterior
  #   (`corner_radius.rs:658` e `:685`). Ou seja: multiplicávamos por quatro os
  #   dados jogados na corrida que apaga topbar e dock, e justamente no instante
  #   em que a barra está mais frágil. O `forma.sh` grava até 12 chaves numa
  #   rajada, e `spacing` está na lista `must_recreate` do painel, que respawna
  #   os applets no meio dela.
  #
  #   A atomicidade não muda: o temporário continua no diretório de destino
  #   (TRAVA 2, logo acima), então o `mv -f` segue sendo rename no mesmo
  #   filesystem. Muda só o nome — e com ele o silêncio.
  tmp="$(mktemp -p "$dir" ".atomicwrite.meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s' "$conteudo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod "$modo" "$tmp"
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$destino"
  return "$MEOW_DIVERGENTE"   # 1 = "estava divergente e eu consertei"
}

# --- O MEOW.CONF: UM CAMINHO SÓ, E UMA FORMA SÓ DE ESCREVER NELE ------------
# Os dois caminhos e as duas funções abaixo VIERAM do `bin/meow` em 11/08/2026,
# e a mudança é de endereço, não de comportamento: o texto delas é o mesmo.
#
# O motivo é a Sprint M. O `wallpaper.sh permitir` precisa gravar uma chave no
# meow.conf, e ele NÃO é a CLI — é um script de `scripts/`, que roda como
# processo filho. Sem mover isto para cá, a saída seria reescrever a mesma
# lógica de "trocar a chave preservando o comentário" num segundo lugar; e
# chave de configuração com duas rotinas de escrita é a receita de as duas
# discordarem no dia em que uma delas for corrigida (foi exatamente o que
# aconteceu com a `conf_definir`, que escrevia só a PRIMEIRA ocorrência
# enquanto o shell obedece a ÚLTIMA — ver o cabeçalho abaixo).
#
# `MEOW_CONF` continua sendo o override de sempre, e agora ele vale para todo
# módulo que sourceia este arquivo, não só para a CLI.
MEOW_CONF_ARQUIVO="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"
MEOW_CONF_PADRAO="${MEOW_CONF_PADRAO:-$MEOW_RAIZ/meow.conf.exemplo}"

# Troca (ou acrescenta) uma chave do meow.conf preservando o comentário da linha.
# É o que faz `meow tema claro`, `meow logo <x>` e `meow wallpaper permitir`
# valerem também para o próximo `meow aplicar` — sem isso a mudança duraria até
# o self-heal seguinte.
#
# É FEITO EM BASH, E NÃO COM UM `sed`, POR CAUSA DO COMENTÁRIO DA LINHA
#   O meow.conf é comentado linha a linha, e o comentário é metade do valor dele
#   como documentação. Um `sed -E 's|^(MODO=)[^#]*(#.*)?$|...|'` parece resolver
#   e não resolve: o `[^#]*` é guloso, engole os espaços que separam o valor do
#   comentário e devolve `MODO="claro"# escuro | claro | auto`, colado. ERE não
#   tem quantificador preguiçoso para consertar isso. Aqui a linha é partida no
#   primeiro `#` e os espaços de antes dele são preservados como estavam.
#
#   Limite conhecido: valor que CONTENHA `#` (um hex de cor, por exemplo) seria
#   lido como comentário. Nenhuma chave deste conf é assim — as cores vêm da
#   paleta, nunca do conf — e o wizard recusa `#` e `"` na resposta dela.
#
# TODAS AS OCORRÊNCIAS, NÃO SÓ A PRIMEIRA — E ISSO É MEDIÇÃO, NÃO ZELO
#   O `meow.conf.exemplo` tinha `LOGO_INTERVALO=` DUAS vezes (30m na seção da
#   logo, 1d na do wallpaper) até 05/08/2026. O arquivo é lido pelo `.` do shell,
#   onde vale a ÚLTIMA atribuição; esta função escrevia só a PRIMEIRA. O
#   resultado numa máquina recém-instalada seria `meow configurar` gravar `2h`,
#   imprimir o diff certo, e o valor em vigor continuar `1d` — sem nada acusar.
#   O exemplo foi corrigido, e aqui a regra passou a ser "a chave inteira": um
#   conf com a mesma chave duas vezes sai deste caminho com as duas concordando.
meow_conf_texto_definir() {
  local texto="$1" chave="$2" valor="$3" novo="" linha resto antes espacos comentario achou=0
  while IFS= read -r linha; do
    if [ "${linha#"$chave"=}" != "$linha" ]; then
      achou=1
      resto="${linha#"$chave"=}"
      if [ "${resto#*#}" != "$resto" ]; then
        antes="${resto%%#*}"
        comentario="#${resto#*#}"
        # O sufixo que sobra depois do último caractere não-branco: exatamente
        # os espaços que alinhavam o comentário.
        espacos="${antes##*[![:space:]]}"
        linha="$chave=\"$valor\"$espacos$comentario"
      else
        linha="$chave=\"$valor\""
      fi
    fi
    novo="$novo$linha"$'\n'
  done <<< "$texto"
  novo="${novo%$'\n'}"
  [ "$achou" = "1" ] || novo="$novo"$'\n'"$chave=\"$valor\""
  printf '%s' "$novo"
}

# Grava a chave no meow.conf dela. Quando o arquivo ainda não existe, a base é o
# `meow.conf.exemplo` — o mesmo caminho que o `install.sh` toma no seco, e o que
# impede a primeira gravação de nascer um arquivo de uma linha só, sem nenhum
# dos comentários que são a documentação deste projeto.
#
# Devolve o que a `meow_escrever` devolve: 0 já estava assim · 1 escreveu (ou
# escreveria, no seco) · 2 falhou.
# "A CHAVE DIZ 'nao', OU ELA SIMPLESMENTE NÃO EXISTE?" — 08/09/2026
#
# São perguntas diferentes, e confundi-las apagou um arquivo de `/etc`. O
# `${LANCADOR_SISTEMA:-nao}` que a etapa do hook de apt usava responde às duas
# com a mesma palavra: chave ausente e chave escrita "nao" viram o mesmo valor.
# Para LER a preferência isso é certo — o padrão é não mexer em `/usr/share`.
# Para DESTRUIR, não: remover um arquivo de `/etc` porque uma chave está
# faltando é agir por omissão, e omissão não é decisão.
#
# Enquanto o `sudo` falhava calado num ambiente sem terminal, o defeito era
# invisível. Com a ponte root, o mesmo caminho passou a funcionar — e o
# `tests/convergencia.sh`, que roda o instalador num HOME de brinquedo onde
# nenhuma chave existe, apagou o `99-meow-lancador` da máquina de verdade.
#
# Esta função lê o ARQUIVO, não a variável: devolve 0 só quando a chave está lá,
# escrita, com o valor pedido. Sem arquivo, ou sem a chave, devolve 1.
meow_conf_diz() {
  local chave="$1" quer="$2" linha
  [ -f "$MEOW_CONF_ARQUIVO" ] || return 1
  linha="$(sed -n "s/^[[:space:]]*$chave=//p" "$MEOW_CONF_ARQUIVO" | tail -1)"
  [ -n "$linha" ] || return 1
  # Tira as aspas e o comentário de fim de linha, que é como o arquivo é escrito.
  linha="${linha%%#*}"
  linha="$(printf '%s' "$linha" | tr -d '"'"'"' \t\r')"
  [ "$linha" = "$quer" ]
}

# A QUEBRA DE LINHA DO FIM SOBREVIVE — 13/09/2026
#   O `$(cat)` come as quebras do fim e o `meow_escrever` grava com `printf '%s'`:
#   TODA gravação tirava o último `\n` do arquivo dela. Medido pelo painel: um
#   Salvar ligou os segundos do relógio, o seguinte desligou, e o md5 não voltou
#   — a única diferença era esse byte. Agora o arquivo é lido inteiro (o `x` do
#   fim segura as quebras dentro do `$(...)`), as quebras são separadas do texto
#   e voltam iguais na gravação.
#
#   A comparação "já estava assim" fica AQUI, e não no `meow_escrever`: lá ela é
#   feita contra outro `$(cat)`, que também come a quebra, e o texto com o `\n`
#   devolvido nunca bateria — cada Salvar regravaria o arquivo e contaria como
#   mudança uma chave que ficou igual.
meow_conf_definir() {
  local chave="$1" valor="$2" texto novo fim="" nl=$'\n'
  if [ -f "$MEOW_CONF_ARQUIVO" ]; then
    texto="$(cat "$MEOW_CONF_ARQUIVO"; printf x)"
    texto="${texto%x}"
    fim="${texto##*[!$nl]}"
    texto="${texto%"$fim"}"
  else
    texto="$(cat "$MEOW_CONF_PADRAO" 2>/dev/null)" || return "$MEOW_ERRO"
    fim="$nl"
  fi
  novo="$(meow_conf_texto_definir "$texto" "$chave" "$valor")"
  if [ -f "$MEOW_CONF_ARQUIVO" ] && [ "$novo" = "$texto" ]; then
    return "$MEOW_OK"
  fi
  meow_escrever "$MEOW_CONF_ARQUIVO" "$novo$fim" 644
}

# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

# --- O ESTADO DO USUÁRIO SAI DO REPOSITÓRIO, E O `.padrao` FICA — 21/09/2026 -
#
# Até hoje a CURADORIA dela era gravada DENTRO do clone: `BANIDOS.txt` e
# `lado.tsv` moravam em `assets/papeis-de-parede/` e eram versionados. Usar o
# painel virava commit pendente. Está medido no `git status` daquele dia: `+47`
# linhas em `BANIDOS.txt` e `-3` em `lado.tsv`, gravadas às 17h09 por ela clicar
# em "Tirar" e em "Dia"/"Noite". Ninguém programou nada.
#
# E SÃO DOIS USUÁRIOS REAIS, com três remotos entre si — `origin`, `fork` e um
# caminho local para a máquina dela. Cada `git pull` entre os dois era conflito
# de merge num arquivo que nenhum dos dois editou de propósito. O `merge=ours`
# do `.gitattributes` prometia resolver isso e não resolvia: o driver só existia
# no `.git/config` DELE, e nada no repositório o registrava — quem clonasse
# recebia a declaração sem o mecanismo, que é a pior das combinações porque
# parece protegido. Quem registra agora é a `etapa_cli` do `install.sh`, e ela é
# cinto de segurança, não a defesa principal: a defesa é este arquivo sair.
#
# O DESENHO É SEMENTE, E NÃO SOBREPOSIÇÃO
#   O `.padrao` versionado é o conteúdo de FÁBRICA, e ele é copiado para
#   `$MEOW_ESTADO` UMA vez. Não é uma camada lida por baixo do estado, e a
#   diferença é exatamente o que faz o desfazer funcionar: o `cmd_desbanir`
#   reescreve o `BANIDOS.txt` SEM um nome e o `gravar_lado` reescreve o
#   `lado.tsv` inteiro — com sobreposição, o que ela acabou de tirar voltaria na
#   leitura seguinte, vindo da camada de baixo. Um desfazer que não desfaz é
#   pior que não ter o botão.
#
# O MARCADOR É O DIRETÓRIO, E NÃO O ARQUIVO
#   O `gravar_lado` APAGA o `lado.tsv` quando ela desfaz a última escolha —
#   "sem escolha" e "sem arquivo" são o mesmo estado, de propósito, para o
#   registro não virar uma segunda verdade que ninguém sabe apagar. Semear pela
#   ausência do ARQUIVO faria as escolhas de fábrica ressuscitarem nesse exato
#   instante, calado. Por isso quem responde "já semeei" é o DIRETÓRIO: ele
#   nasce na semeadura e não some mais.
#
# E POR ISSO A SEMEADURA É DO DIRETÓRIO INTEIRO, E NÃO DE UM ARQUIVO
#   Custou uma passagem do `tests/git-limpo.sh` para aparecer: com o diretório
#   servindo de marca, semear UM arquivo por chamada faz o segundo chamador
#   achar a pasta já de pé e não semear nada. No `wallpaper.sh` isso é literal —
#   o `LADO_TSV` resolve na linha 776 e o `BANIDOS_TXT` na 2331, e o primeiro
#   criava a pasta para o segundo. O `BANIDOS.txt` nascia SÓ com o nome que ela
#   acabara de banir, e as 231 imagens da curadoria de 24/08/2026 voltariam no
#   `semear` seguinte.
#
#   Então quem semeia varre TODO `*.padrao` da pasta de origem. Isso também
#   desarma a armadilha nº 3 do projeto (toda lista fixa é uma lista que alguém
#   vai esquecer): um `.padrao` novo passa a ser semeado sem ninguém precisar
#   lembrar de acrescentá-lo a uma lista aqui.
#
# O SECO NÃO SEMEIA, E A PROMESSA É MAIS FORTE QUE A CONVENIÊNCIA
#   A primeira versão disto semeava mesmo sob `--seco`, com o argumento de que
#   `$MEOW_ESTADO` é a nossa casa e não a máquina dela. O `tests/seco.sh`
#   reprovou na hora, e está certo: o contrato dele é "o seco não escreve NADA
#   fora do próprio lock", e é a única promessa que o README faz sobre
#   auditoria. Promessa com exceção não é promessa — a exceção é o que a próxima
#   pessoa copia.
#
#   O QUE SE PERDE, DITO EM VOZ ALTA: numa máquina onde o instalador nunca
#   rodou de verdade, um `--conferir` lê um estado que ainda não existe e
#   enxerga a lista de banidos vazia. É o único caso, ele some na primeira
#   passagem não-seca, e o `esta_banida` tem a pasta `banidos/` como primeira
#   defesa de qualquer jeito. O caminho devolvido continua sendo o do ESTADO,
#   e não o da semente, porque é ele que as mensagens de prévia nomeiam: um
#   `meow_muda` dizendo "entraria em BANIDOS.txt.padrao" apontaria para um
#   arquivo em que nada nunca vai ser escrito.
#
# O ARQUIVO ANTIGO, DE DENTRO DO CLONE, VENCE O `.padrao` NA SEMEADURA
#   Quem já usava o projeto tem, no clone, um `BANIDOS.txt` mais rico que o de
#   fábrica — no dele eram 47 linhas a mais que o commit, gravadas pelo painel e
#   nunca commitadas. Semear do `.padrao` ignorando esse arquivo apagaria a
#   curadoria dele no dia da migração, e apagaria calado, que é o jeito de
#   apagar do qual não se volta. Enquanto o arquivo velho estiver lá, é ELE a
#   semente; o `.padrao` atende quem clona hoje. A conta se fecha sozinha: o
#   `.gitignore` barra o arquivo velho, ele nunca mais é recriado, e quem apagar
#   o dele à mão passa a cair no `.padrao` como qualquer clone novo.
#
# A ORIGEM É SEMPRE `assets/<pasta>` e o destino `$MEOW_ESTADO/<pasta>`: um
# acervo do repositório tem um espelho de estado com o mesmo nome, e não há
# terceiro caminho a inventar. Dois argumentos em vez de quatro, e nenhuma
# chamada que possa cruzar as pastas por engano.
#
# Uso:  caminho="$(meow_estado_com_padrao papeis-de-parede BANIDOS.txt)"
meow_estado_com_padrao() {
  local pasta="$1" arquivo="$2" origem="$MEOW_RAIZ/assets/$1" dir="$MEOW_ESTADO/$1"
  local padrao semente
  if [ ! -d "$dir" ] && ! meow_seco; then
    # Se o `mkdir` falhar, ecoamos o caminho do estado do mesmo jeito: quem
    # chamou trata "não consegui escrever" como sempre tratou, e devolver vazio
    # aqui faria o chamador operar sobre o caminho "" sem entender por quê.
    if mkdir -p "$dir" 2>/dev/null; then
      for padrao in "$origem"/*.padrao; do
        [ -f "$padrao" ] || continue          # a pasta sem nenhum `.padrao`
        semente="${padrao%.padrao}"           # o arquivo velho, de dentro do clone
        [ -f "$semente" ] || semente="$padrao"
        cp -p -- "$semente" "$dir/$(basename "${padrao%.padrao}")" 2>/dev/null
      done
    fi
  fi
  printf '%s' "$dir/$arquivo"
}

# --- UMA PASSAGEM, UMA PASTA DE BACKUP --------------------------------------
# Quatro arquivos LIAM `MEOW_CARIMBO` (`hicolor.sh` e os módulos do VS Code, do
# btop/bat e dos toolkits), todos com o mesmo `${MEOW_CARIMBO:-$(date ...)}` —
# e NINGUÉM o definia. Cada um calculava o próprio `date`, então uma passagem do
# `install.sh` que cruzasse a virada do segundo rachava os backups em duas
# pastas. Está no disco: `backups/2026-08-04T20-14-44` (Qt) e
# `backups/2026-08-04T20-17-02` (obsidian), mesma execução.
#
# `export` é o ponto: os scripts de `scripts/` e os módulos rodam como PROCESSOS
# FILHOS e sourceiam este arquivo de novo. Sem exportar, cada um recomeçaria a
# contagem e o defeito continuaria de pé. Quem já tiver a variável (o pai)
# vence — é o `:-` fazendo o trabalho.
#
# O `aplicar_tema.sh` fica de fora de propósito: ele nem sourceia este arquivo,
# usa o prefixo `<ISO>-tema-<nome>` e poda só o que casa com esse prefixo.
export MEOW_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
# --- a trava, e o vazamento de descritor que ela sofre ----------------------
# `exec {MEOW_FD}>arquivo` NÃO marca o descritor como close-on-exec — medido no
# bash 5.2.21 desta máquina em 10/08/2026: um filho lançado enquanto a trava
# está de pé aparece com o mesmo `lock` em `/proc/<pid>/fd`. Enquanto esse filho
# viver, o `flock` continua tomado, mesmo com o `meow` que o criou já morto há
# muito tempo.
#
# NÃO É TEÓRICO: naquele dia o `meow apps aplicar spotify` deixou o descritor
# vazar para o próprio Spotify. O app ficou aberto, e a partir daí TODO comando
# do projeto — inclusive o `install.sh` — recusava rodar dizendo "outro meow
# está rodando". A mensagem era falsa e, pior, não dava o que fazer: não havia
# outro meow, havia um tocador de música segurando um cadeado.
#
# Bash puro não tem como marcar FD_CLOEXEC, então a trava não some — o que dá
# para fazer, e é o que se faz aqui, é PARAR DE MENTIR sobre ela. Quando o lock
# está tomado, olha-se quem o segura de verdade e diz-se o nome do processo. Se
# não for um processo do projeto, é descritor vazado: o texto passa a explicar
# isso e a oferecer a saída (fechar aquele app, ou soltar o cadeado à força).
#
# Quem lança app de vida longa a partir de um módulo deve fechar o descritor no
# filho — a forma é acrescentar `{MEOW_FD}>&-` ao comando (conferido: com isso o
# filho não herda).
meow_travar() {
  mkdir -p "$MEOW_ESTADO"
  local lock="$MEOW_ESTADO/lock"
  exec {MEOW_FD}>"$lock" || return "$MEOW_ERRO"
  flock -n "$MEOW_FD" && return 0

  # Quem está de fato com o arquivo aberto. O `fuser` é o único que enxerga
  # descritor herdado; um arquivo de PID não veria nada, porque o dono original
  # já morreu.
  # O `$$` sai da lista: nós mesmos acabamos de abrir o arquivo duas linhas
  # acima, e sem esta exclusão o próprio script apareceria como "bash(...)" —
  # casaria com o caso legítimo logo abaixo e esconderia o verdadeiro culpado.
  local donos="" nomes=""
  if meow_tem fuser; then
    donos="$(fuser "$lock" 2>/dev/null | tr -s ' ')"
    for p in $donos; do
      [ "$p" = "$$" ] && continue
      [ -r "/proc/$p/comm" ] && nomes="$nomes $(cat "/proc/$p/comm" 2>/dev/null)($p)"
    done
  fi

  if [ -z "$nomes" ]; then
    meow_aviso "outro meow está rodando (lock em $lock) — saindo"
    return "$MEOW_ERRO"
  fi

  # Um processo do próprio projeto segurando o lock é o caso legítimo.
  case "$nomes" in
    *meow*|*install.sh*|*bash*|*aplicar_*|*construir_*|*icones_*)
      meow_aviso "outro meow está rodando ($nomes) — saindo"
      return "$MEOW_ERRO" ;;
  esac

  meow_erro "o cadeado está preso em:$nomes"
  meow_aviso "isso não é outro meow — é descritor vazado. Um módulo lançou esse"
  meow_aviso "app enquanto a trava estava de pé, e ele levou o cadeado junto."
  meow_aviso "saídas: feche o app acima, ou solte à força com"
  meow_aviso "  flock -u \"$lock\" true  &&  rm -f \"$lock\""
  return "$MEOW_ERRO"
}

# --- backup do que é do SISTEMA ---------------------------------------------
# A TRAVA 1 recusa /usr/share e está certa. Mas três scripts PRECISAM escrever
# lá: o cosmic-app-library não honra override em ~/.local/share/applications
# (bug upstream pop-os/cosmic-applets#667, medido aqui em 04/08/2026 com
# NoDisplay=true E Hidden=true e o Vim continuando no lançador), então marcar o
# arquivo que veio do apt é hoje a única coisa que esconde um app. Elas passam
# por fora de `meow_escrever` de propósito, e por isso a cópia de segurança tem
# de ser explícita: `dpkg -V nvidia-settings` já acusa `??5??????` nesta máquina,
# e não havia backup nenhum para devolver.
#
# O destino ESPELHA o caminho absoluto — sem isso, `meow desfazer --lancador`
# teria de adivinhar de onde cada arquivo veio.
meow_backup_sistema() {
  local arq="$1"
  local dir="$MEOW_ESTADO/backups/$MEOW_CARIMBO-sistema"
  local dest="$dir${arq}"
  [ -f "$arq" ] || return 0
  [ -f "$dest" ] && return 0          # já guardado nesta rodada
  mkdir -p "$(dirname "$dest")" 2>/dev/null || return "$MEOW_ERRO"
  # tolerar falha em vez de derrubar a etapa: ela é opcional, o backup não pode
  # ser o motivo de o lançador não ser vestido — mas sem ele não escrevemos.
  cp -a "$arq" "$dest" 2>/dev/null || return "$MEOW_ERRO"
  return 0
}

# --- MANIFESTO: o que este projeto pôs no disco -----------------------------
# Sem ele, desinstalar seria uma SEGUNDA lista, escrita à mão, que envelheceria
# em silêncio a cada etapa nova. Quem preenche é a própria `meow_escrever`, no
# único ponto por onde toda escrita de configuração passa.
#
# O sha256 é o que permite ao `--uninstall` PULAR um arquivo que a pessoa passou
# a manter à mão depois — remover o que ela editou seria apagar trabalho dela.
MEOW_MANIFESTO="$MEOW_ESTADO/manifesto.tsv"
meow_manifesto_registrar() {
  local alvo="$1" sha
  meow_seco && return 0
  [ -f "$alvo" ] || return 0
  sha="$(sha256sum -- "$alvo" 2>/dev/null | cut -d' ' -f1)"
  mkdir -p "$MEOW_ESTADO" || return 0
  # Uma linha por caminho: a antiga sai antes de a nova entrar. O filtro é `awk`
  # comparando o CAMPO inteiro, e não `grep "^$alvo"`, porque caminho é texto
  # cheio de `.`, `+` e `[` — num grep isso é expressão regular, e
  # `~/.config/a.conf` casaria com `~/aXconf`.
  if [ -f "$MEOW_MANIFESTO" ]; then
    awk -F'\t' -v a="$alvo" '$1 != a' "$MEOW_MANIFESTO" > "$MEOW_MANIFESTO.tmp" 2>/dev/null \
      && mv -f "$MEOW_MANIFESTO.tmp" "$MEOW_MANIFESTO" 2>/dev/null
    rm -f "$MEOW_MANIFESTO.tmp" 2>/dev/null
  fi
  printf '%s\t%s\t%s\n' "$alvo" "$(date -Iseconds)" "${sha:--}" >> "$MEOW_MANIFESTO"
  return 0
}

# --- log e notificação: as duas OUTRAS escritas, e o seco vale para elas -----
# `MEOW_DRY_RUN=1` promete não escrever nada. A promessa costuma ser lida como
# "não escreve CONFIGURAÇÃO", e é aí que ela vaza — o log é um arquivo, e a
# notificação é uma frase na tela dela.
#
# MEDIDO em 2026-08-04, com md5 antes e depois: `MEOW_DRY_RUN=1 ./install.sh`
# acrescentava `install.sh feitos=12 pulados=0 falhos=0` ao `meow.log`. E o
# `etapa_icones`/`etapa_wallpaper` do install.sh disparam `meow_notificar`
# quando o script chamado devolve 1 — que é EXATAMENTE o que ele devolve no
# seco, sem ter escrito nada. Ou seja: numa máquina com o tema divergente, uma
# auditoria em seco pendurava na TV dela um "Ícones e logo atualizados" falso.
#
# A guarda mora aqui, e não em cada chamador, porque o chamador que esquecer é
# justamente o que ninguém vai reler. Quem quiser registrar apesar do seco
# escreve no arquivo por conta própria — e aí a decisão está à vista.
meow_registrar() {
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO"
  printf '%s %s\n' "$(date -Iseconds)" "$*" >> "$MEOW_ESTADO/meow.log"
}

meow_tem() { command -v "$1" >/dev/null 2>&1; }

# Um flatpak instalado deixa DIRETÓRIO no disco; `flatpak info` deixa um repo
# ostree INTEIRO em ~/.local/share/flatpak/repo só por ter sido perguntado
# (medido em HOME virgem, 10/08/2026). Detecção com efeito colateral é o mesmo
# vazamento que o `meow_registrar` acima já teve de tapar: `MEOW_DRY_RUN=1`
# promete não escrever nada, e perguntar não pode ser escrever.
# Cobre instalação de usuário, de sistema e o dado por app em ~/.var/app.
meow_flatpak_tem() {   # 0 = instalado, 1 = não
  local id="$1"
  [ -d "$HOME/.local/share/flatpak/app/$id" ] && return 0
  [ -d "/var/lib/flatpak/app/$id" ] && return 0
  [ -d "$HOME/.var/app/$id" ] && return 0
  meow_debug "flatpak '$id' não achado por diretório (app/ nem .var/app/)"
  return 1
}

# --- O MENU DE LANÇAMENTO RELÊ OS ÍCONES ------------------------------------
# TRÊS CONSUMIDORES, TRÊS CACHES DIFERENTES, E É ISSO QUE FAZ "instalei e não
# apareceu" parecer defeito de instalação quando não é:
#
#   o dock / painel .... `cosmic-panel`, resolve no arranque -> `painel.sh reciclar`
#   o terminal ......... `fastfetch`, relê o arquivo a cada execução -> nada a fazer
#   o menu de lançamento `cosmic-app-library` + `cosmic-launcher`, resolvem no
#                        arranque e guardam -> é o que esta função destrava
#
# Medido em 11/08/2026: o Flatseal aparecia chapado no lançador (processo das
# 09:34) e em traço na dock (processo das 13:08) — mesmo arquivo no disco, mesmo
# tema ativo, idades de processo diferentes. Conferir por arquivo responde "está
# instalado?"; só reiniciar o consumidor responde "está na tela dela?".
#
# `pkill -x cosmic-app-library` NÃO FUNCIONA, e a razão é boba: o `comm` do
# kernel trunca em 15 caracteres, o nome tem 18, e o `-x` exige casamento
# exato. Vai de `-f`, sobre a linha de comando inteira.
#
# MATAR AQUI É SEGURO, e é a diferença para o applet do painel (que deixa buraco
# no dock quando morre sozinho): estes dois são filhos do `cosmic-session`, que
# os repõe em segundos e resolve o binário pelo PATH. A grade fecha se estiver
# aberta — por isso NUNCA chamar isto sem que algo tenha de fato mudado.
meow_lancador_reler() {
  meow_seco && return 0
  local matou=0
  # `cosmic-launcher` primeiro: é o mais barato de repor e o que ela usa por
  # atalho de teclado, então a janela de indisponibilidade fica no menor.
  for alvo in cosmic-launcher cosmic-app-library; do
    if pgrep -f "$alvo" >/dev/null 2>&1; then
      pkill -f "$alvo" 2>/dev/null && matou=1
    fi
  done
  [ "$matou" = "1" ] && meow_debug "lançador chacoalhado — o cosmic-session repõe em segundos"
  return 0
}

# --- A TELA INTEIRA RELÊ O QUE MUDOU ------------------------------------------
# 13/09/2026. Queixa dela: "as alterações que faço pela interface seja icones,
# configs e afins nada tá aplicando de verdade". Nos ícones a medição deu razão
# a ela: o `icones_apps_arcticons.sh` punha o desenho no tema e terminava com
# "os ícones novos aparecem no próximo login" — o arquivo certo no disco, e a
# dock e o menu mostrando o de antes até ela sair da sessão.
#
# Os dois consumidores que resolvem no arranque, cada um pela porta dele:
#   o dock e o painel -> `scripts/painel.sh reciclar`, a porta única, que recusa
#                        quando ninguém repõe a barra;
#   o menu            -> `meow_lancador_reler`, logo acima.
#
# SÓ DEPOIS DE ALGO TER MUDADO, pela mesma razão da função de cima: o painel
# pisca uns 2 s e a grade de aplicativos fecha se estiver aberta.
#
# E SÓ NA CASA DE VERDADE. Os testes rodam o instalador num HOME de brinquedo,
# e um reciclo dali derrubaria a barra DELA no meio de uma suíte — é a lição da
# ponte root: dar poder a um automatismo acorda os caminhos que só não faziam
# estrago por falharem. O HOME tem de ser o da conta, lido do passwd.
#
# O CÓDIGO DIZ O QUE ACONTECEU, para quem chama poder dizer a verdade na tela:
#   0  releu (ou é ensaio da CLI, que não relê nada de propósito)
#   1  o painel recusou reciclar — o menu releu, a dock fica para o login
#   3  este HOME não é o da sessão: nada foi tocado
meow_tela_reler() {
  meow_seco && return 0
  local lar rc=0
  lar="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  if [ -z "$lar" ] || ! [ "$HOME" -ef "$lar" ]; then
    meow_debug "HOME ($HOME) não é o da conta — a tela não é desta sessão, nada a reler"
    return 3
  fi
  if [ -x "$MEOW_RAIZ/scripts/painel.sh" ] && pgrep -x cosmic-panel >/dev/null 2>&1; then
    if ! "$MEOW_RAIZ/scripts/painel.sh" reciclar; then
      meow_aviso "o painel recusou reciclar agora — na dock, o desenho novo aparece no próximo login"
      rc=1
    fi
  fi
  meow_lancador_reler
  return "$rc"
}

# Notificação: ela precisa saber quando algo mudou sozinho.
meow_notificar() {
  meow_seco && return 0
  meow_tem notify-send || return 0
  notify-send -a MeowSystem -i preferences-desktop-theme "$1" "${2:-}" 2>/dev/null || true
}

# ============================================================================
# A PONTE ROOT — 08/09/2026
# ============================================================================
# Pedido dela: *"não conseguimos de alguma forma usar sudo só na instalar e criar
# um perfil naquele conf.d ... aquele que só preciso uma vez e fica lá registrado
# pra sempre?"*
#
# `/usr/local/lib/meowsystem/ponte_root.sh` é o braço root do projeto, e
# `/etc/sudoers.d/49-meowsystem-ponte` libera os verbos DELE sem senha. Quem
# instala os dois é o `install.sh`, e é ali — uma vez — que a senha é pedida.
# O porquê do desenho está no cabeçalho da própria ponte.
#
# ESTAS DUAS FUNÇÕES SÃO A ÚNICA PORTA. Nenhum script chama a ponte pelo caminho
# cru: assim "a ponte existe?", "ela está liberada?" e "o que fazer quando não
# está" ficam escritos uma vez só, e um script novo não pode esquecer metade.
MEOW_PONTE="${MEOW_PONTE:-/usr/local/lib/meowsystem/ponte_root.sh}"

# "Dá para usar a ponte agora?" — e as DUAS metades importam. O arquivo pode
# existir sem a regra (instalação pela metade, ou `PONTE_ROOT="nao"` a caminho),
# e a regra pode existir sem o arquivo (um `rm` manual). `sudo -n` responde às
# duas de uma vez, e responde pela VERDADE do sudo, não pela nossa suposição
# sobre ele — que é a diferença entre conferir e adivinhar.
# O `$HOME` TEM DE SER O DA MÁQUINA, E ISSO CUSTOU UM ARQUIVO DE /etc
#   Em 08/09/2026, no mesmo dia em que a ponte nasceu, o `tests/convergencia.sh`
#   — que roda o instalador num HOME de brinquedo, com `env -i` — APAGOU o
#   `/etc/apt/apt.conf.d/99-meow-lancador` da máquina de verdade. O caminho é
#   este: naquele HOME não há `meow.conf`, então `LANCADOR_SISTEMA` cai no
#   padrão "nao", e a etapa do hook toma o ramo de REMOVER.
#
#   Antes da ponte isso era inofensivo: sob `env -i` o `sudo rm` falhava calado,
#   e a etapa avisava "sem sudo para remover". A ponte tornou EFETIVO um caminho
#   que só não fazia estrago porque não tinha permissão — e é esse o preço de
#   dar poder a um programa: os caminhos que falhavam por falta de permissão
#   passam a acontecer.
#
#   A cerca é comparar o `$HOME` de quem chama com o `lar` que o instalador
#   gravou como root. A ponte não consegue fazer isso sozinha: com `env_reset`,
#   o sudo troca o `HOME` pelo do usuário-alvo antes de ela nascer. Aqui, do
#   lado de cá, o `$HOME` ainda é o verdadeiro.
#
#   O `perfil` é 0644 de propósito — ele não guarda segredo nenhum, e ser
#   legível é o que permite esta conferência sem elevar nada.
#
#   O hook de apt continua funcionando: o `meow-lancador-apt.sh` roda como root
#   e a primeira coisa que ele faz é `HOME="$LAR"`, que é exatamente o `lar` do
#   perfil.
meow_ponte_viva() {
  [ -x "$MEOW_PONTE" ] || return 1
  local lar
  lar="$(sed -n 's/^lar=//p' "${MEOW_PONTE%/*}/perfil" 2>/dev/null)"
  if [ -n "$lar" ] && [ "$lar" != "${HOME:-}" ]; then
    meow_debug "ponte: \$HOME é '$HOME' e o perfil diz '$lar' — não uso a ponte daqui"
    return 1
  fi
  sudo -n "$MEOW_PONTE" estado >/dev/null 2>&1
}

# Roda um verbo pela ponte. O stdin do chamador atravessa — é por ele que o nome
# do arquivo e o conteúdo viajam, e é por isso que nenhum verbo tem argumento.
#
# Devolve 127 quando a ponte não está no ar, e esse número é escolhido: ele não
# colide com nenhum código de saída do projeto (0, 1, 2, 3), então quem chama
# consegue distinguir "a ponte recusou" de "não há ponte" e cair no caminho
# antigo — o `sudo` que pede senha — em vez de tratar as duas como erro.
meow_ponte() {
  meow_ponte_viva || return 127
  sudo -n "$MEOW_PONTE" "$1"
}

# ============================================================================
# ESCREVER `.desktop` DE SISTEMA — UM CAMINHO, QUATRO CHAMADORES
# ============================================================================
# `ocultar_apps.sh`, `nomes_apps.sh`, `icones_absolutos.sh` e o `bin/meow`
# escreviam a mesma coisa com o mesmo `sudo install`, cada um com a sua guarda.
# Desde 08/09/2026 há a ponte, e ela é a terceira forma de escrever ali — copiar
# a escolha entre as três para quatro arquivos é garantir que o quinto esqueça
# metade.
#
# A ORDEM É DELIBERADA:
#   1. o arquivo é MEU        -> escrevo direto, sem elevar nada
#   2. a ponte está no ar     -> pela ponte, sem senha (o caso normal)
#   3. o sudo está em cache   -> `sudo install`, como sempre foi
#   4. nada disso             -> 127, e quem chamou conta ao usuário
#
# O 3 continua existindo por causa da máquina que ainda não instalou a ponte —
# e do `PONTE_ROOT="nao"`, que é escolha dela. Tirar o caminho antigo faria a
# ponte deixar de ser conforto e virar requisito.

# "Dá para escrever neste `.desktop` de sistema?" — sem escrever nada.
meow_desktop_pode() {
  [ -w "$1" ] && return 0
  meow_ponte_viva && return 0
  sudo -n true 2>/dev/null
}

# meow_desktop_escrever <arquivo-alvo> <arquivo-com-o-conteudo>
meow_desktop_escrever() {
  local alvo="$1" fonte="$2" nome
  nome="${alvo##*/}"
  if [ -w "$alvo" ]; then
    install -m 644 "$fonte" "$alvo" 2>/dev/null && return 0
  fi
  # A ponte recebe o NOME e o CONTEÚDO pelo stdin, nesta ordem, porque nenhum
  # verbo dela aceita argumento — é o que deixa a regra de sudo sem curinga.
  if meow_ponte_viva; then
    { printf '%s\n' "$nome"; cat "$fonte"; } | meow_ponte desktop 2>/dev/null && return 0
  fi
  sudo install -m 644 "$fonte" "$alvo" 2>/dev/null
}

# O banco de dados do lançador, pelo caminho que estiver disponível.
meow_desktop_banco() {
  local dir="${1:-/usr/share/applications}"
  meow_tem update-desktop-database || return 0
  if [ -w "$dir" ]; then
    update-desktop-database "$dir" 2>/dev/null || true
    return 0
  fi
  if [ "$dir" = "/usr/share/applications" ] && meow_ponte_viva; then
    meow_ponte desktop-banco 2>/dev/null && return 0
  fi
  sudo -n update-desktop-database "$dir" 2>/dev/null || true
  return 0
}
