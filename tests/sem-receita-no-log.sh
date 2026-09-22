#!/usr/bin/env bash
# sem-receita-no-log.sh — nenhuma etapa termina em "faça você mesmo".
#
# POR QUE ESTE ARQUIVO NASCEU EM 22/09/2026
#   Ele não reclamou de dezoito coisas. Reclamou de UMA, dezoito vezes:
#
#     O app descobre o problema, sabe o conserto, e manda a pessoa consertar.
#
#   A sprint P2 mediu seis provas no log da própria máquina dele — `areas.sh`
#   mandando alfinetar pelo COSMIC, o `spotify/manifesto.sh` com um `git clone`
#   dentro de um `meow_info`, o `prompt.sh` com um `curl | sh`, o
#   `qbittorrent/manifesto.sh` delegando a um script de outro projeto, o
#   `fastfetch_logo.sh` com a conta pronta e o conserto por fazer. Todas com a
#   mesma forma: diagnóstico certo, conserto conhecido, nenhum botão.
#
#   "Um engenheiro lê isso como cortesia; um designer leigo lê como «o programa
#   desistiu»."
#
# A REGRA QUE ESTE TESTE COBRA
#   Uma etapa que sabe o conserto ou FAZ, ou oferece um botão que faz
#   (`meow_pendencia_acionavel`, lib/comum.sh). Quando nem o botão é possível —
#   porque o que falta é decisão humana genuína —, a mensagem diz A DECISÃO, e
#   não a receita.
#
#   Na prática, o que o teste procura é a receita: uma linha de `meow_info` ou
#   `meow_aviso` que carregue `curl | sh`, `git clone` ou `apt install`. Esses
#   três são o formato de uma instalação copiável — o sinal mais barato e mais
#   confiável de que a frase virou tutorial.
#
# POR QUE SÓ ESSES TRÊS, E NÃO UMA GRAMÁTICA DE RECEITA
#   Porque um detector esperto de "isto parece um comando" acusaria toda frase
#   que cita o nome de um arquivo, e um teste que grita demais é desligado na
#   segunda semana. Três padrões literais, zero falso positivo fora da lista de
#   isenção, e o resto fica com a revisão humana — que é onde ele já estava.
#
# AS ISENÇÕES CASAM PELO CONTEÚDO DA LINHA, NUNCA PELO NÚMERO
#   Mesma disciplina do `tests/portabilidade.sh`, e pelo mesmo motivo escrito
#   lá: isenção presa a número apodrece no primeiro rebase, e o teste fica verde
#   sobre o defeito que veio pegar. Cada isenção abaixo carrega o motivo na
#   mesma entrada.
#
# ESTE ARQUIVO NÃO SE VARRE, e nem o `lib/comum.sh`: o primeiro carrega, por
# definição, todos os padrões que caça; o segundo DEFINE `meow_info` e
# `meow_aviso`, e as linhas onde eles nascem não são mensagens.
#
#   0 = nenhuma receita solta no log · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2

EU="tests/sem-receita-no-log.sh"
achados=0
isentos=0
ok()    { printf 'ok: %s\n' "$1"; }
acusa() {
  printf 'FALHOU: %s:%s — %s\n' "$1" "$2" "$4" >&2
  printf '        %s\n' "$3" >&2
  achados=$((achados+1))
}

# ---------------------------------------------------------------------------
# AS ISENÇÕES, uma a uma, com o motivo ao lado
# ---------------------------------------------------------------------------
# Cada entrada é um trecho LITERAL da linha isenta (comparação por substring,
# sem regex). Tudo o que não estiver aqui é achado.
#
# AS CINCO ISENÇÕES DE HOJE SÃO A MESMA, CINCO VEZES: `sudo apt install`.
#   Instalar pacote do sistema precisa de root, e a ponte root deste projeto não
#   é um curinga — são OITO verbos fechados (docs/FRONTEIRA.md, "A ponte root, e
#   por que ela não é NOPASSWD: ALL"), e instalar pacote arbitrário não é
#   nenhum deles. Não há botão que este projeto possa oferecer sem abrir a ponte
#   — e abrir a ponte para caber um botão é trocar um incômodo por um buraco.
#
#   Então elas ficam como estão, e a regra da sprint continua respeitada: a
#   mensagem diz A DECISÃO ("falta este pacote, instalá-lo é sua escolha"), e o
#   comando é o endereço da decisão, não um tutorial disfarçado de cortesia.
#   O dia em que a ponte ganhar um verbo de pacote, estas cinco viram botão e a
#   isenção para de casar sozinha.
ISENTAS=(
  'meow_info "  instale com: sudo apt install imagemagick"'
  'meow_info "      sudo apt install ${faltam_apt% }"'
  'meow_info "instale com: sudo apt install papirus-icon-theme"'
  'meow_info "  sudo apt install papirus-icon-theme"'
  'meow_info "se quiser: sudo apt install qt5ct qt6ct"'
)

isenta() {
  local linha="$1" i
  for i in "${ISENTAS[@]}"; do
    case "$linha" in *"$i"*) return 0 ;; esac
  done
  return 1
}

# ---------------------------------------------------------------------------
# a varredura
# ---------------------------------------------------------------------------
# `-print0`/`read -d ''` porque nome de arquivo pode ter espaço, e um `for` sobre
# `$(find)` partiria o caminho no meio — a armadilha que o resto da suíte já
# evita do mesmo jeito.
while IFS= read -r -d '' arq; do
  case "$arq" in
    "./$EU"|./lib/comum.sh) continue ;;
  esac
  num=0
  while IFS= read -r linha || [ -n "$linha" ]; do
    num=$((num+1))
    # Só linha que CHAMA um dos dois verbos. Uma linha de comentário que os
    # mencione não é mensagem na tela de ninguém.
    case "$linha" in
      *meow_info*|*meow_aviso*) : ;;
      *) continue ;;
    esac
    # Comentário puro (a linha inteira começa com `#`, com ou sem recuo) fica de
    # fora: ele documenta, não fala.
    aparada="${linha#"${linha%%[![:space:]]*}"}"
    case "$aparada" in '#'*) continue ;; esac

    motivo=""
    case "$linha" in
      *'curl'*'| sh'*|*'curl'*'|sh'*)  motivo="receita de \`curl | sh\` dentro de uma mensagem" ;;
      *'git clone'*)                   motivo="receita de \`git clone\` dentro de uma mensagem" ;;
      *'apt install'*)                 motivo="receita de \`apt install\` dentro de uma mensagem" ;;
    esac
    [ -n "$motivo" ] || continue

    if isenta "$linha"; then
      isentos=$((isentos+1))
      continue
    fi
    acusa "${arq#./}" "$num" "$aparada" "$motivo"
  done < "$arq"
done < <(find ./scripts ./lib ./assets/temas-de-apps \
              -type f \( -name '*.sh' -o -name '*.bash' \) -print0 2>/dev/null)

printf '\n'
if [ "$achados" -eq 0 ]; then
  ok "sem receita no log: nenhuma etapa manda a pessoa rodar o que o projeto sabe fazer ($isentos isenções)"
  exit 0
fi
printf 'FALHOU: %d receita(s) solta(s) em mensagem (%d isenções)\n' "$achados" "$isentos" >&2
printf 'O conserto é o `meow_pendencia_acionavel` do lib/comum.sh — ver a sprint P2.\n' >&2
exit 1
