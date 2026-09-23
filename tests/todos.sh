#!/usr/bin/env bash
# todos.sh — A PERGUNTA "A SUÍTE PASSA?" PASSA A TER UMA RESPOSTA.
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Até hoje a única forma de saber que um teste estava vermelho era lembrar de
#   chamá-lo pelo nome. E a medição diz o que isso custou: o `tests/numeros.sh`
#   passou três dias em `rc=1` apontando 14 números errados, o `README.md` foi
#   editado no dia seguinte ao teste ficar vermelho, e os números não foram
#   corrigidos — porque ninguém rodou. No mesmo período o `docs/SPRINTS.md`
#   afirmava "123/123 passando" duas linhas abaixo da frase, dele mesmo, "a
#   suíte verde não fecha sprint".
#
#   Um teste que ninguém roda não é rede de segurança: é decoração.
#
# OS DOIS SUBCONJUNTOS, E POR QUE ELES EXISTEM
#   Metade desta suíte roda em qualquer lugar — HOME de brinquedo, `env -i`,
#   `MEOW_IGNORA_DESKTOP=1`, nada além de bash e python3. A outra metade só
#   responde a verdade NA MÁQUINA DELA: precisa do Papirus instalado, do
#   `rsvg-convert`, do Playwright com Chromium, ou de subir o painel e escrever
#   uma isca dentro do `~/.local/share/icons` de verdade.
#
#   Misturar os dois faz o CI ficar vermelho por AUSÊNCIA e não por defeito — e
#   vermelho que não significa nada é a coisa que este arquivo veio matar, não
#   criar. Por isso:
#
#     ./tests/todos.sh              tudo, que é o que se roda na bancada dela
#     ./tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)
#     ./tests/todos.sh --maquina    só o que exige a máquina dela
#
#   E a tela SEMPRE diz qual subconjunto rodou. Um placar sem essa frase mente
#   por omissão: "12 de 12" não quer dizer nada se os quatro caros ficaram fora.
#
# A LISTA É ESCRITA, MAS NÃO PODE FICAR INCOMPLETA
#   A armadilha nº 3 do projeto (toda lista fixa é uma lista que alguém vai
#   esquecer) não deixa cravar a lista de testes: um teste novo ficaria de fora
#   e a suíte diria verde sem ele. Aqui a CLASSIFICAÇÃO precisa ser escrita, que
#   é a parte que nenhuma medição adivinha — então os arquivos são DESCOBERTOS
#   em `tests/` e quem aparecer sem classificação faz este runner sair com 2. O
#   custo de acrescentar um teste é uma linha aqui, e é de propósito.
#
# PULADO NÃO É OK, E APARECE SEPARADO
#   Vários testes saem 0 dizendo "pulado: falta numpy". Somar isso ao verde é
#   fingir cobertura, que é o defeito que o `tests/midia.sh` descreve no
#   cabeçalho dele. O placar conta os três estados, e o resumo final diz quantos
#   foram pulados.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = todos passaram · 1 = algum falhou · 2 = erro deste runner.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
TESTES="$RAIZ/tests"

# ---------------------------------------------------------------------------
# A CLASSIFICAÇÃO, com o motivo de cada linha
# ---------------------------------------------------------------------------
# PORTÁTIL: só bash, python3 e o que está versionado aqui. Roda num CI sem
# sessão gráfica, sem COSMIC, sem Papirus e sem rede.
PORTATIL=(
  numeros.sh             # lê o repositório e conta; nada mais
  orfaos.sh              # idem
  portabilidade.sh       # grep no que está versionado; nada além de git e bash
  arvore.sh              # pergunta ao `git ls-files` quem é dono de qual arquivo
  pack.sh                # pack de terceiro num MEOW_PACKS temporário; não instala nada
  fonte-unica.sh         # mapas do repositório + packs e HOME de brinquedo; só bash e python3
  sem-receita-no-log.sh  # grep nos .sh versionados; nada além de bash
  temas-de-apps.sh       # grep nos manifestos + pack.py; estado de brinquedo
  git-limpo.sh           # acervo, HOME e estado de brinquedo; só git e bash
  app.sh                 # compara o esquema do painel com o do wizard; python3
  estilo.sh              # régua da caneta contra o acervo Arcticons DAQUI (pede numpy)
  reversao.sh            # grep no desinstalador + install.sh com MEOW_IGNORA_DESKTOP=1
  seco.sh                # o cabeçalho dele exige rodar "inclusive num CI sem sessão gráfica"
  convergencia.sh        # instalador em HOME de brinquedo, cinco passagens (~70s)
  instalacao.sh          # o laço das passagens, com etapas falsas; não toca em nada
  midia.sh               # HOME de brinquedo com binário falso; nunca compila
  jogos-heroic.sh        # HOME de brinquedo com biblioteca falsa do Heroic
  um-cartao-por-jogo.sh  # HOME de brinquedo com manifesto falso da Steam
)

# MÁQUINA: a resposta depende do que está INSTALADO nela. Fora do CI não por
# preguiça — por honestidade: lá eles sairiam "pulado" e engordariam o placar.
MAQUINA=(
  conversor.sh           # traça a partir de /usr/share/icons/Papirus; muda com a versão do pacote
  afinador.sh            # precisa de rsvg-convert e do `compare` do ImageMagick
  previa-cerca.sh        # sobe o painel e planta uma isca no ~/.local/share/icons de verdade
  app-navegador.py       # Playwright com Chromium, a página usada como ela usaria
  app-acessibilidade.py  # Playwright com Chromium; sobe o painel
  oficina.sh             # lê os .desktop da máquina: o desenho de pack que veste um deles tem cartão
)

# ---------------------------------------------------------------------------
# Modo
# ---------------------------------------------------------------------------
MODO="tudo"
case "${1:-}" in
  ''|--tudo)   MODO="tudo" ;;
  --portatil)  MODO="portatil" ;;
  --maquina)   MODO="maquina" ;;
  -h|--ajuda|--help)
    # Escrito à mão, e não recortado do cabeçalho com `sed -n 'N,Mp'`: número
    # de linha dentro do próprio arquivo é a primeira coisa que envelhece.
    printf './tests/todos.sh              tudo, que é o que se roda na bancada dela\n'
    printf './tests/todos.sh --portatil   só o que roda em máquina sem COSMIC (o CI)\n'
    printf './tests/todos.sh --maquina    só o que exige a máquina dela\n'
    exit 0 ;;
  *) printf 'uso: %s [--tudo|--portatil|--maquina]\n' "$(basename "$0")" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------------------
# A guarda da lista: todo arquivo de teste tem de estar classificado
# ---------------------------------------------------------------------------
conhecido() {
  local alvo="$1" i
  for i in "${PORTATIL[@]}" "${MAQUINA[@]}"; do
    [ "$i" = "$alvo" ] && return 0
  done
  return 1
}

# E A DESCOBERTA NÃO PODE SER POR EXTENSÃO — corrigido em 21/09/2026
#   A primeira versão varria `tests/*.sh` e `tests/*.py`, e com isso a guarda
#   tinha o buraco que ela diz fechar: um teste novo em `.bats`, `.expect` ou
#   sem extensão nenhuma não era DESCOBERTO, não caía no `exit 2`, e o placar
#   dizia verde sem ele — a armadilha nº 3 de novo, um nível abaixo. Agora entra
#   todo arquivo de `tests/` que seja EXECUTÁVEL (que é o que um teste é aqui)
#   ou que tenha as duas extensões de sempre. As duas extensões continuam na
#   conta de propósito: um `.sh` a que alguém esqueceu de dar `chmod +x` tem de
#   aparecer, e ele aparece — vermelho, no laço da corrida, por não ser
#   executável. `-maxdepth 1` porque material de apoio mora em subdiretório.
mapfile -t ENCONTRADOS < <(
  find "$TESTES" -maxdepth 1 -type f \
       \( -perm -u+x -o -name '*.sh' -o -name '*.py' \) -printf '%f\n' | sort
)
DESCONHECIDOS=()
for nome in "${ENCONTRADOS[@]:-}"; do
  [ -n "$nome" ] || continue
  [ "$nome" = "todos.sh" ] && continue
  conhecido "$nome" || DESCONHECIDOS+=("$nome")
done
if [ "${#DESCONHECIDOS[@]}" -gt 0 ]; then
  printf 'FALHOU: teste sem classificação em tests/todos.sh: %s\n' "${DESCONHECIDOS[*]}" >&2
  printf 'Diga se ele roda em qualquer máquina (PORTATIL) ou só na dela (MAQUINA).\n' >&2
  printf 'Sem isso este runner diria verde sem ter rodado o arquivo novo.\n' >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# A corrida
# ---------------------------------------------------------------------------
case "$MODO" in
  tudo)     ALVOS=("${PORTATIL[@]}" "${MAQUINA[@]}"); QUAL="todos os $(( ${#PORTATIL[@]} + ${#MAQUINA[@]} ))" ;;
  portatil) ALVOS=("${PORTATIL[@]}");                 QUAL="os ${#PORTATIL[@]} portáteis (sem COSMIC, sem Papirus, sem navegador)" ;;
  maquina)  ALVOS=("${MAQUINA[@]}");                  QUAL="os ${#MAQUINA[@]} que exigem a máquina dela" ;;
esac

printf '== suíte MeowSystem: %s ==\n\n' "$QUAL"

VERDES=0; PULADOS=0; VERMELHOS=()
for nome in "${ALVOS[@]}"; do
  arq="$TESTES/$nome"
  if [ ! -x "$arq" ]; then
    printf 'FALHOU  %-22s não é executável\n' "$nome"
    VERMELHOS+=("$nome")
    continue
  fi
  inicio="$(date +%s)"
  saida="$("$arq" 2>&1)"; rc=$?
  seg=$(( $(date +%s) - inicio ))

  # `pulado` no começo de uma linha é o idioma da casa para "não dava para
  # conferir aqui". O rc=3 é o mesmo em número (regra 7 do contrato).
  #
  # O `rc` MANDA, E A PALAVRA SÓ DESEMPATA — medido em 21/09/2026
  #   A primeira versão deste laço olhava a palavra antes do código e marcou o
  #   `conversor.sh` como *pulado* com `rc=1`: ele imprime "pulado: ... não
  #   existe nesta máquina" para UM caso e falha em outro, linhas adiante. Um
  #   runner que esconde vermelho atrás de um pulado é o defeito que este
  #   arquivo veio matar, com o crachá de quem veio consertá-lo.
  #
  # E O MESMO DEFEITO VOLTOU PELA PORTA DO NÚMERO — corrigido em 21/09/2026
  #   A segunda versão aceitava `rc=3` sozinho como pulado, e cinco testes desta
  #   suíte terminam em `exit "$falhas"`: `estilo.sh`, `app.sh`, `conversor.sh`,
  #   `afinador.sh` e `previa-cerca.sh`. Com EXATAMENTE três falhas eles saem 3,
  #   e o runner os carimbava *pulado* — fora do placar vermelho, sem imprimir a
  #   saída vermelha, e a suíte inteira saindo 0. Dois deles (`estilo.sh` e
  #   `app.sh`) estão no subconjunto do CI, e em `estilo.sh` chegar a três é
  #   trivial: uma TRAVA mais os dois PISO que o cabeçalho dele já diz estarem
  #   fora. Reproduzido com dois esboços em 21/09: o que imprime três `FALHOU:`
  #   e sai 3 agora aparece vermelho, com as três linhas na tela.
  #
  #   Então o pulado passou a exigir as TRÊS coisas ao mesmo tempo: código 0 ou
  #   3, a palavra `pulado` abrindo alguma linha, e NENHUM `FALHOU` na saída. A
  #   palavra vermelha manda sobre as outras duas — um teste que falou em falha
  #   nunca é pulado, seja qual for o número com que ele saiu.
  #
  # E A BUSCA É CASAMENTO DE PADRÃO, NÃO UM CANO PARA `grep -q`
  #   Com `set -o pipefail`, o `-q` fecha o cano na primeira linha, o lado de
  #   cá morre de SIGPIPE e a condição inverte sozinha.
  disse_pulado=0
  [[ $saida == pulado* || $saida == *$'\n'pulado* ]] && disse_pulado=1
  disse_falhou=0
  [[ $saida == *FALHOU* ]] && disse_falhou=1

  if [ "$disse_pulado" -eq 1 ] && [ "$disse_falhou" -eq 0 ] \
     && { [ "$rc" -eq 0 ] || [ "$rc" -eq 3 ]; }; then
    estado="pulado"; PULADOS=$((PULADOS + 1))
  elif [ "$rc" -eq 0 ]; then
    estado="ok"; VERDES=$((VERDES + 1))
  else
    estado="FALHOU"; VERMELHOS+=("$nome")
  fi
  printf '%-7s %-22s rc=%-3s %3ss\n' "$estado" "$nome" "$rc" "$seg"

  # Quem falhou mostra o que disse. Quem passou não polui a tela: o placar
  # responde, e o detalhe de um teste verde ninguém lê.
  #
  # E DE QUEM FALHOU SÓ SAI A PARTE VERMELHA. O `conversor.sh` imprime 48
  # linhas de `ok:` em volta de UMA de `FALHOU:` — despejar as 48 esconde a
  # única que interessa no meio do verde, que é a forma mais boba de um log
  # ilegível. Se o teste falhou sem usar a palavra, aí sim vai tudo: melhor
  # ruído que silêncio.
  if [ "$estado" = "FALHOU" ]; then
    vermelho="$(printf '%s\n' "$saida" | grep -E 'FALHOU|^Erro|Traceback')"
    [ -n "$vermelho" ] || vermelho="$saida"
    printf '%s\n' "$vermelho" | sed 's/^/        | /'
  fi
done

# ---------------------------------------------------------------------------
printf '\n== %s · %s verde(s), %s pulado(s), %s vermelho(s) ==\n' \
       "$QUAL" "$VERDES" "$PULADOS" "${#VERMELHOS[@]}"
if [ "${#VERMELHOS[@]}" -gt 0 ]; then
  printf 'vermelhos: %s\n' "${VERMELHOS[*]}" >&2
  exit 1
fi
[ "$PULADOS" -gt 0 ] && printf 'atenção: %s teste(s) pulado(s) não são verde — falta dependência nesta máquina.\n' "$PULADOS"
exit 0
