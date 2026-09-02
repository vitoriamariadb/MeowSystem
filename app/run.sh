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
#   - o `trap` cobre EXIT, INT, TERM e HUP. O HUP não é zelo: fechar o terminal
#     que lançou isto manda SIGHUP, e sem ele o Python ficaria órfão;
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
case "${1:-}" in
  --sem-abrir) ABRIR=0 ;;
  --porta-so|--porta-só) ABRIR=0; SO_URL=1 ;;
  ''|--abrir) ;;
  -h|--help)
    cat <<'FIM'

app/run.sh — o painel de configuração visual do MeowSystem

  ./app/run.sh              sobe o backend, abre o navegador e fica de pé
  ./app/run.sh --sem-abrir  sobe e imprime a URL, sem abrir janela nenhuma
  ./app/run.sh --porta-so   sobe, imprime a URL e sai (só para conferir)

O backend escuta em 127.0.0.1, numa porta que o kernel escolhe, com um token de
sessão sorteado a cada execução. Ele nunca é exposto à rede, e morre junto com
este script.

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

# --- sobe o backend ---------------------------------------------------------
# O stdout do Python é um cano (a URL vem por ele); o stderr fica na tela, que é
# onde um traceback tem de aparecer.
TUBO="$(mktemp -u -t meow-app-XXXXXX)"
mkfifo -m 600 "$TUBO" || { meow_erro "não consegui criar o cano em $TUBO"; exit "$MEOW_ERRO"; }

MEOW_RAIZ="$RAIZ" python3 "$SERVIDOR" > "$TUBO" &
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
if [ "$ABRIR" = "1" ]; then
  if [ -n "${BROWSER:-}" ] && meow_tem "${BROWSER%% *}"; then
    # `{MEOW_FD}>&-` fecha o descritor da trava no filho. O cabeçalho do
    # `meow_travar` conta o acidente que isto evita: em 10/08/2026 um app de vida
    # longa lançado por um módulo levou o cadeado junto, e a partir dali TODO
    # comando do projeto recusava rodar dizendo "outro meow está rodando" — com
    # o culpado sendo um tocador de música. Um navegador é exatamente esse tipo
    # de processo: ele vive horas depois de este script morrer.
    "$BROWSER" "$URL" >/dev/null 2>&1 & disown
  elif meow_tem xdg-open; then
    xdg-open "$URL" >/dev/null 2>&1 & disown
  else
    meow_aviso "não achei \$BROWSER nem xdg-open — abra você mesma:"
    printf '\n    %s\n\n' "$URL"
  fi
fi

meow_info "Ctrl+C encerra o painel (e qualquer trabalho que estiver correndo)."
printf '\n'

# `wait` acorda no instante em que o Python cair — inclusive quando ele cai
# sozinho. Sem isto, fechar a aba deixaria o servidor de pé para sempre.
wait "$PID"
