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
meow_conf_definir() {
  local chave="$1" valor="$2" texto
  if [ -f "$MEOW_CONF_ARQUIVO" ]; then
    texto="$(cat "$MEOW_CONF_ARQUIVO")"
  else
    texto="$(cat "$MEOW_CONF_PADRAO" 2>/dev/null)" || return "$MEOW_ERRO"
  fi
  meow_escrever "$MEOW_CONF_ARQUIVO" "$(meow_conf_texto_definir "$texto" "$chave" "$valor")" 644
}

# --- lock: o timer pode disparar enquanto ela roda na mão (regra 10) --------
MEOW_ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}"

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

# Notificação: ela precisa saber quando algo mudou sozinho.
meow_notificar() {
  meow_seco && return 0
  meow_tem notify-send || return 0
  notify-send -a MeowSystem -i preferences-desktop-theme "$1" "${2:-}" 2>/dev/null || true
}
