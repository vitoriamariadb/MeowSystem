#!/usr/bin/env bash
# app/run.sh — sobe o painel de configuração e abre o navegador nele.
#
# É O QUE O `.desktop` CHAMA, e é o que se roda na mão. Uma coisa só, sem flag,
# como o resto deste projeto:
#
#     ./app/run.sh              sobe, abre o navegador, e fica de pé
#     ./app/run.sh --sem-abrir  sobe e só imprime a URL (para eu testar sem
#                               nascer janela na tela dela)
#     ./app/run.sh --porta-só   imprime a URL e sai (não serve para nada além
#                               de conferir que o backend sobe)
#
# ─────────────────────────────────────────────────────────────────────────────
# O CICLO DE VIDA É A PARTE QUE IMPORTA, E ELE TEM UM MODO DE FALHA CONHECIDO
# ─────────────────────────────────────────────────────────────────────────────
# Um servidor local que sobrevive à janela que o abriu é a receita de uma porta
# aberta esquecida — e esta porta roda `./install.sh`. Então:
#
#   - no modo normal quem encerra é a PRÓPRIA PÁGINA: o servidor sobe com
#     `MEOW_APP_VIGIA=1` e sai quando a janela do navegador fecha (o bloco "O
#     PAINEL MORRE COM A JANELA QUE O ABRIU", em `servidor.py`, conta o porquê);
#   - o `trap` cobre EXIT, INT, TERM e HUP, e vale enquanto este script está de
#     pé. O HUP não é zelo: fechar o terminal que lançou isto manda SIGHUP, e
#     sem ele o Python ficaria órfão;
#   - o Python morre com o grupo, e ele mesmo mata os trabalhos vivos ao sair
#     (o `finally` do `main()` em `servidor.py`);
#   - a espera é `wait` sobre o PID do Python, e não um `sleep` em laço: com
#     `wait` o script acorda no instante em que o servidor cai, em vez de
#     descobrir isso até um segundo depois.
#
# ─────────────────────────────────────────────────────────────────────────────
# POR QUE O NAVEGADOR É `xdg-open`, E NÃO UM NOME DE PROGRAMA
# ─────────────────────────────────────────────────────────────────────────────
# Cravar `firefox` ou `google-chrome` aqui seria escolher por ela num assunto que
# é dela, e quebraria no dia em que ela trocasse de navegador. `$BROWSER` vence
# quando existe (é a convenção do freedesktop e o que ela pode definir no
# `env.zsh`), e `xdg-open` é o resto. Sem nenhum dos dois, o script imprime a URL
# e diz para colar — que é uma resposta, e não um erro.
#
# O QUE MUDOU EM 02/09/2026: A JANELA PRÓPRIA
#   O padrão do sistema aqui é o Chrome (`xdg-settings get default-web-browser`
#   -> `google-chrome.desktop`), e abrir o painel numa ABA dele o perdia entre as
#   outras. Quando o navegador padrão é da família Chromium, o painel passa a
#   abrir com `--app=`: janela própria, sem barra de endereço, com `--class` do
#   nosso `.desktop` para o dock lhe dar o ícone certo.
#
#   Nada disso é obrigatório: a escolha continua sendo a do sistema. Firefox,
#   ou navegador que não conheçamos, cai no `xdg-open` de sempre e o painel
#   funciona igual — só numa aba.
#
# ─────────────────────────────────────────────────────────────────────────────
# A URL CARREGA O TOKEN, E É POR ISSO QUE ELA NÃO VAI PARA LUGAR NENHUM
# ─────────────────────────────────────────────────────────────────────────────
# O `servidor.py` imprime UMA linha em stdout — a URL inteira com o token — e é
# só isso que este script lê. Ela não é registrada em log, não vai para o
# `meow_registrar` e não fica em arquivo: o token vale enquanto o processo viver,
# e o `app.js` o tira da barra de endereço no primeiro instante. Um token gravado
# em disco sobreviveria à sessão que o criou, que é justamente o que não pode.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

ABRIR=1
SO_URL=0
PID_ARQ="$MEOW_ESTADO/app.pid"

case "${1:-}" in
  --sem-abrir) ABRIR=0 ;;
  --porta-so|--porta-só) ABRIR=0; SO_URL=1 ;;
  --parar)
    # O painel solto precisa de uma porta para ser fechado — senão a única saída
    # seria `pkill`, que é a ferramenta errada para um processo que a gente
    # mesmo largou de propósito.
    if [ -f "$PID_ARQ" ] && kill -0 "$(cat "$PID_ARQ")" 2>/dev/null; then
      kill -TERM "$(cat "$PID_ARQ")" 2>/dev/null
      rm -f "$PID_ARQ"
      meow_ok "painel encerrado"
    else
      rm -f "$PID_ARQ"
      meow_pula "não há painel de pé"
    fi
    exit 0 ;;
  --estado)
    if [ -f "$PID_ARQ" ] && kill -0 "$(cat "$PID_ARQ")" 2>/dev/null; then
      meow_ok "painel de pé (pid $(cat "$PID_ARQ"))"
    else
      meow_pula "painel parado"
    fi
    exit 0 ;;
  ''|--abrir) ;;
  -h|--help)
    cat <<'FIM'

app/run.sh — o painel de configuração visual do MeowSystem

  ./app/run.sh              sobe o backend, abre o navegador e DEVOLVE o terminal
  ./app/run.sh --parar      encerra o painel que ficou de pé
  ./app/run.sh --estado     diz se há painel de pé
  ./app/run.sh --sem-abrir  sobe e imprime a URL, preso ao terminal (para testes)
  ./app/run.sh --porta-so   sobe, imprime a URL e sai (só para conferir)

O backend escuta em 127.0.0.1, numa porta que o kernel escolhe, com um token de
sessão sorteado a cada execução. Nunca é exposto à rede.

No uso normal ele fica SOLTO: o terminal volta para você, e o painel segue de pé
enquanto a janela do navegador estiver aberta — fechou a janela, o servidor sai
sozinho. Com `--sem-abrir` ele fica preso ao terminal e morre com ele: é assim
que os testes o sobem e derrubam.

FIM
    exit 0 ;;
  *) meow_erro "opção desconhecida: $1"; meow_info "veja: ./app/run.sh --help"; exit 2 ;;
esac

# ROOT NÃO — a mesma guarda do install.sh e do bin/meow, e pelo mesmo motivo.
# Este painel grava no `~/.config/meow/meow.conf` e chama o `./install.sh`; sob
# sudo o `$HOME` vira `/root` (ou pior, o dela enche de arquivo com dono root, e
# a GUI de tema passa a falhar em silêncio).
if [ "$(id -u)" = "0" ]; then
  meow_erro "não me rode com sudo."
  meow_info "  rode como o seu usuário normal:  ./app/run.sh"
  exit 2
fi

meow_tem python3 || {
  meow_erro "o painel precisa do python3, e ele não está aqui"
  meow_info "  sudo apt install python3"
  exit "$MEOW_SEM_DEPENDENCIA"
}

SERVIDOR="$RAIZ/app/servidor.py"
[ -f "$SERVIDOR" ] || { meow_erro "não achei $SERVIDOR"; exit "$MEOW_ERRO"; }

# --- SEM TERMINAL, A SAÍDA PRECISA DE UM LUGAR ------------------------------
# O `.desktop` deixou de ser `Terminal=true` em 02/09/2026 (o cabeçalho de
# `scripts/atalho.sh` conta o que aquilo virou nesta máquina). O ganho é grande e
# a conta é uma só: sem janela de terminal, um traceback do Python não tem onde
# aparecer, e "cliquei e não abriu" volta a ser mudo.
#
# Então quando este script roda sem terminal — e SÓ então — tudo o que ele e o
# servidor escrevem vai para um arquivo. Rodado na mão, nada muda: a saída
# continua na tela, que é onde ela deve estar.
#
# O `-t 1` é o teste certo, e não uma variável do lançador: ele responde
# exatamente à pergunta que importa ("existe tela para isto?"). O `--porta-so`
# dos testes escreve a URL num cano, que também não é tty — por isso o desvio só
# vale no modo que abre navegador.
PAINEL_LOG="$MEOW_ESTADO/painel.log"
if [ "$ABRIR" = "1" ] && [ ! -t 1 ]; then
  # Um log que só cresce é um log que ninguém abre. 1 MB guarda semanas de
  # aberturas do painel; passou disso, fica a metade final.
  if [ -f "$PAINEL_LOG" ] && [ "$(stat -c%s "$PAINEL_LOG" 2>/dev/null || echo 0)" -gt 1048576 ]; then
    tail -c 524288 "$PAINEL_LOG" > "$PAINEL_LOG.tmp" 2>/dev/null &&
      mv -f "$PAINEL_LOG.tmp" "$PAINEL_LOG"
  fi
  exec >>"$PAINEL_LOG" 2>&1
  printf '\n===== %s — painel aberto sem terminal =====\n' "$(date -Is)"
fi

# --- sobe o backend ---------------------------------------------------------
# O stdout do Python é um cano (a URL vem por ele); o stderr fica na tela, que é
# onde um traceback tem de aparecer.
TUBO="$(mktemp -u -t meow-app-XXXXXX)"
mkfifo -m 600 "$TUBO" || { meow_erro "não consegui criar o cano em $TUBO"; exit "$MEOW_ERRO"; }

# `MEOW_APP_VIGIA=1` só no modo normal: é ele que faz o servidor sair quando a
# janela do navegador fecha. Com `--sem-abrir` não há janela nenhuma para vigiar,
# e quem derruba o servidor é o terminal — que é como `tests/app-navegador.py` o
# sobe e o desce sem deixar processo órfão.
MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$MEOW_ESTADO" MEOW_APP_VIGIA="$ABRIR" python3 "$SERVIDOR" > "$TUBO" &
PID=$!

limpar() {
  local rc=$?
  trap - EXIT INT TERM HUP
  if [ -n "${PID:-}" ] && kill -0 "$PID" 2>/dev/null; then
    kill -TERM "$PID" 2>/dev/null
    # Meio segundo para o `finally` do servidor parar os trabalhos vivos. Se ele
    # não sair, o KILL resolve — mas dar a chance é o que evita deixar um
    # `./install.sh` correndo sem ninguém olhando.
    for _ in 1 2 3 4 5; do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.1
    done
    kill -KILL "$PID" 2>/dev/null
  fi
  rm -f "$TUBO"
  exit "$rc"
}
trap limpar EXIT INT TERM HUP

# Lê a única linha que o servidor imprime. O `timeout` é o que impede este script
# de pendurar para sempre quando o Python morre antes de falar (erro de sintaxe,
# porta indisponível, o que for) — sem ele, o `read` num FIFO espera eternamente.
URL=""
if ! read -r -t 15 URL < "$TUBO"; then
  meow_erro "o backend não respondeu em 15 s"
  meow_info "  rode à mão para ver o erro:  python3 $SERVIDOR"
  exit "$MEOW_ERRO"
fi
[ -n "$URL" ] || { meow_erro "o backend subiu sem dizer a URL"; exit "$MEOW_ERRO"; }

meow_titulo "MeowSystem — painel de configuração"
meow_ok "no ar em ${URL%%\?*}"
meow_info "a URL completa carrega o token da sessão; ela vale só enquanto isto estiver de pé"

if [ "$SO_URL" = "1" ]; then
  printf '%s\n' "$URL"
  exit 0
fi

# `--sem-abrir` QUER DIZER "eu abro", ENTÃO ELE TEM DE DAR O ENDEREÇO INTEIRO
#   A primeira versão calava a URL nos dois modos, e a linha "no ar em
#   http://127.0.0.1:45167/" acima é INÚTIL sozinha: sem o `?t=<token>` o
#   servidor responde 403, que é o certo. Descobri usando — pedi `--sem-abrir`
#   para testar sem nascer janela na tela dela, e fiquei com uma base de URL que
#   não abre. Quem escolheu abrir por conta própria precisa do que colar.
#
#   No modo normal a URL continua não sendo impressa, e isso é de propósito: lá
#   o navegador já recebeu o endereço, e um token na rolagem do terminal é um
#   token que fica no histórico da janela.
if [ "$ABRIR" = "0" ]; then
  printf '\n    %s\n\n' "$URL"
fi

# --- abre o navegador -------------------------------------------------------
# O ID DA JANELA É O DO NOSSO `.desktop`, e isso é o que dá ícone a ela: o
# COSMIC casa a janela com o cartão do lançador pelo `app_id`, e o
# `StartupWMClass` do outro lado fecha o par.
APP_ID="com.meowsystem.Painel"

# `{MEOW_FD}>&-` fecha o descritor da trava no filho. O cabeçalho do
# `meow_travar` conta o acidente que isto evita: em 10/08/2026 um app de vida
# longa lançado por um módulo levou o cadeado junto, e a partir dali TODO comando
# do projeto recusava rodar dizendo "outro meow está rodando" — com o culpado
# sendo um tocador de música. Um navegador é exatamente esse tipo de processo:
# ele vive horas depois de este script morrer.
_soltar() {
  if [ -n "${MEOW_FD:-}" ]; then
    eval '"$@" >/dev/null 2>&1 {MEOW_FD}>&- &'
  else
    "$@" >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true
}

# A linha `Exec=` de um `.desktop`, procurada nos lugares do XDG na ordem em que
# o próprio XDG os lê (o home vence o sistema). Os `%f`, `%u` e companhia saem:
# eles falam de abrir ARQUIVO, e o que queremos daqui é só o nome do programa.
_exec_do_desktop() {
  local id="$1" d
  for d in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" \
           /usr/local/share/applications /usr/share/applications \
           "$HOME/.local/share/flatpak/exports/share/applications" \
           /var/lib/flatpak/exports/share/applications; do
    [ -f "$d/$id" ] || continue
    grep -m1 '^Exec=' "$d/$id" | cut -d= -f2- | sed 's/ *%[a-zA-Z]//g'
    return 0
  done
  return 1
}

# O navegador padrão DELA, resolvido pelo caminho oficial. Não é escolha nossa:
# `xdg-settings` responde o mesmo que o `xdg-open` obedeceria.
_exec_padrao() {
  local id
  meow_tem xdg-settings || return 1
  id="$(xdg-settings get default-web-browser 2>/dev/null || true)"
  [ -n "$id" ] || return 1
  _exec_do_desktop "$id"
}

# O `Exec=` INTEIRO É O COMANDO, E NÃO O PRIMEIRO CAMPO DELE — 02/09/2026
#   O `.desktop` do Chrome no home dela não começa pelo programa:
#
#     Exec=env LIBVA_DRIVER_NAME=nvidia NVD_BACKEND=direct \
#          /usr/bin/google-chrome-stable --ignore-gpu-blocklist \
#          --enable-features=VaapiVideoDecoder,… --ozone-platform-hint=auto
#
#   A primeira versão desta parte lia só o primeiro campo, recebia `env` e
#   abria `env http://127.0.0.1:…`: o servidor subia e NENHUMA janela nascia,
#   sem erro em lugar nenhum (medido aqui, na primeira tentativa). E descartar o
#   resto da linha seria pior ainda — jogaria fora a aceleração de vídeo e o
#   `--ozone-platform-hint`, que são a razão de aquele arquivo existir no home
#   dela.
#
#   Então a linha inteira vira o comando e o painel só acrescenta as suas duas
#   flags. O binário é procurado DENTRO dela, pulando o `env` e as atribuições
#   de variável, e serve a uma única pergunta: esta família aceita `--app=`?
_binario_da_linha() {
  local p
  for p in $1; do
    case "$p" in
      env|/usr/bin/env|/bin/env) continue ;;
      *=*) continue ;;
      -*) break ;;
      *) printf '%s\n' "$p"; return 0 ;;
    esac
  done
  return 1
}

# Família Chromium = janela própria com `--app=`. A lista casa por pedaço do
# nome de propósito: `google-chrome-stable`, `chromium-browser` e
# `brave-browser-beta` são todos o mesmo motor com o mesmo punhado de flags.
_e_chromium() {
  case "${1##*/}" in
    *chrome*|*chromium*|*brave*|*edge*|*vivaldi*|*thorium*) return 0 ;;
  esac
  return 1
}

if [ "$ABRIR" = "1" ]; then
  LINHA=""
  if [ -n "${BROWSER:-}" ] && meow_tem "${BROWSER%% *}"; then
    LINHA="$BROWSER"
  else
    LINHA="$(_exec_padrao || true)"
  fi
  BIN=""
  [ -n "$LINHA" ] && BIN="$(_binario_da_linha "$LINHA" || true)"

  if [ -n "$BIN" ] && meow_tem "$BIN"; then
    # `eval` para virar array respeitando as aspas que um `Exec=` pode ter num
    # caminho com espaço. A linha vem de um `.desktop` do sistema — a mesma
    # confiança que o `xdg-open` já deposita nela.
    eval "CMD=($LINHA)"
    if _e_chromium "$BIN"; then
      # Janela sem barra de endereço. É o que ela pediu ao dizer "era pra ele
      # abrir o chrome": uma janela do painel, e não mais uma aba perdida entre
      # as outras.
      #
      # O PERFIL DEDICADO É O QUE DÁ ÍCONE À JANELA — 02/09/2026
      #   Medido na dock dela: uma janela de `--app` nasce com o `app_id`
      #   `chrome-<host>__-<perfil>`, e o `--class` que pedimos é IGNORADO (o
      #   Chromium calcula o seu próprio para janelas de app). Com o perfil dela
      #   isso dava `chrome-127.0.0.1__-Profile_2`, que não casa com `.desktop`
      #   nenhum — e o COSMIC desenhava a engrenagem bege de "aplicativo
      #   desconhecido". Foi essa engrenagem que ela mandou corrigir.
      #
      #   Num diretório de perfil nosso o sufixo é sempre `Default`, então o
      #   `app_id` vira `chrome-127.0.0.1__-Default`: previsível, e é o nome do
      #   cartão-sombra que o `scripts/atalho.sh` planta para lhe dar o ícone.
      #
      #   Vem de brinde o que o painel mais precisa: instância PRÓPRIA. Com o
      #   perfil dela, `--app` conversa com o Chrome já aberto e o processo sai
      #   na hora; aqui a janela é dona do seu processo, e fechá-la derruba o
      #   pulso no mesmo instante.
      #
      #   O que se perde são as extensões e as senhas dela nesta janela — para
      #   uma página local que só fala com `127.0.0.1`, não faz falta nenhuma.
      #   `--class` continua na linha: não custa nada e é o que vale no dia em
      #   que o Chromium passar a respeitá-lo.
      _soltar "${CMD[@]}" \
        --user-data-dir="$MEOW_ESTADO/navegador" \
        --no-first-run --no-default-browser-check \
        --app="$URL" --class="$APP_ID"
    else
      _soltar "${CMD[@]}" "$URL"
    fi
  elif meow_tem xdg-open; then
    _soltar xdg-open "$URL"
  else
    meow_aviso "não achei \$BROWSER nem xdg-open — abra você mesma:"
    printf '\n    %s\n\n' "$URL"
  fi
fi

# ============================================================================
# O TERMINAL DELA VOLTA — 01/09/2026
# ============================================================================
# Pedido dela, olhando o terminal preso depois de abrir o painel: "abre essa
# janela ao inves dela rodar em background".
#
# O script segurava o terminal com `wait "$PID"` e um `trap` que matava o
# servidor na saida. Isso e o certo para `--sem-abrir` (quem chama e um teste, e
# quer o servidor morto no fim), e e errado para o uso NORMAL: ela clica no
# atalho do lancador ou digita `meow abrir`, e o terminal fica ocupado ate ela
# lembrar de dar Ctrl+C.
#
# Entao os dois modos se separam aqui:
#   · uso normal      -> o servidor e SOLTO (`disown`), o trap desarma, e este
#                        script sai. Quem encerra e a JANELA: com
#                        `MEOW_APP_VIGIA=1` o servidor sai quando o pulso da
#                        pagina some (02/09/2026). `meow abrir --parar` continua
#                        valendo para o caso de o navegador ja ter ido embora
#                        sem avisar.
#   · `--sem-abrir`   -> continua preso ao terminal e morre com ele, porque e
#                        assim que `tests/app-navegador.py` sobe e derruba o
#                        painel sem deixar processo orfao.
if [ "$ABRIR" = "0" ]; then
  meow_info "Ctrl+C encerra o painel (e qualquer trabalho que estiver correndo)."
  printf '\n'
  # `wait` acorda no instante em que o Python cair — inclusive quando ele cai
  # sozinho. Sem isto, fechar a aba deixaria o servidor de pé para sempre.
  wait "$PID"
  exit $?
fi

# O `trap` some ANTES do disown: ele é quem mataria o servidor na saída deste
# script, e sair é exatamente o que vamos fazer agora.
trap - EXIT INT TERM HUP
rm -f "$TUBO"
disown "$PID" 2>/dev/null || true
printf '%s\n' "$PID" > "$PID_ARQ" 2>/dev/null || true

meow_ok "o painel ficou de pé sozinho (pid $PID) — o terminal é seu de novo"
meow_info "fechar a janela do navegador encerra o painel; à mão:  meow abrir --parar"
printf '\n'
