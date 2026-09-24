#!/usr/bin/env bash
# portabilidade.sh — o repositório ainda roda na máquina de um estranho?
#
# POR QUE ESTE ARQUIVO NASCEU EM 21/09/2026
#   Uma varredura perguntou o que impede alguém de fora de instalar o projeto, e
#   a resposta estava na LINHA 39 DO README: o `git clone` trazia `[REDACTED]`
#   no lugar da conta do GitHub. O sanitizador de identidade do Spellbook apagou
#   o nome — e faz bem, este é repositório de duas pessoas —, só que ninguém
#   repôs. O passo 1 do projeto ficou sem rodar, calado, por semanas.
#
#   Nenhum teste da suíte fazia essa pergunta. O `numeros.sh` confere contagem,
#   o `estilo.sh` confere desenho, o `reversao.sh` confere o desfazer; a
#   PORTABILIDADE não tinha dono. Este arquivo passa a ser o dono dela.
#
# AS QUATRO REGRAS, E O DEFEITO QUE CADA UMA PEGA
#   1. HOME DE PESSOA EM TEXTO        `/home/fulano/` em qualquer arquivo versionado
#                                     (e `/home/fulano` sem a barra, desde a P43)
#   2. DISCO QUE NÃO É PADRÃO         `/mnt/Apate` numa receita copiável
#   3. IDENTIDADE REDIGIDA            `[REDACTED]` numa instrução de instalação
#   4. ZDOTDIR SEM ESCAPE             `$HOME/.config/zsh` sem variável de troca
#
#   As três primeiras são a mesma família: uma receita que só roda na bancada de
#   quem a escreveu. A quarta é a vizinha: `~/.config/zsh` é o repositório
#   privado da Aurora nesta casa, mas é também a convenção ZDOTDIR mais comum do
#   mundo zsh — cravar o caminho faz o projeto recusar, na máquina de um
#   estranho, um diretório que é dele.
#
# A REGRA 1 PASSOU A LER TUDO — 23/09/2026, sprint P38
#   Até aqui ela olhava só o que RODA: linha de código que não é comentário, e
#   o miolo das cercas de um .md. Ficavam de fora o comentário, a prosa, as
#   pesquisas, as folhas e os arquivos de registro — e foi por essa porta que
#   os homes das duas máquinas onde o projeto cresceu se espalharam: 171 linhas
#   em 31 arquivos, medido em 23/09. Tirando a guarda da captura `original`
#   (isenção própria, lá embaixo), nenhuma estava em código que roda, e todas
#   estavam no que a pessoa LÊ. Um produto que qualquer um instala não carrega
#   o nome de ninguém, nem na documentação.
#
#   Agora a regra 1 lê TODO arquivo de texto versionado, linha a linha, sem
#   perguntar se é comentário ou registro. As outras três continuam onde
#   estavam: `/mnt/Apate` numa história e `[REDACTED]` num relato são o assunto
#   do texto, e não uma receita que alguém vai copiar.
#
# A REGRA 1 PASSOU A PEGAR O HOME SEM A BARRA FINAL — 24/09/2026, sprint P43
#   O padrão era `/home/<nome>/`, e a barra era a porta: `/home/fulano` no fim
#   de uma linha, antes de uma aspa ou de um espaço, passava. O `tests/pack.sh`
#   escreveu um dado assim de propósito, e o comentário dele conta por quê — o
#   nome entrava "SEM a barra final" para a regra não o ver. Agora a regra casa
#   o nome seguido de qualquer coisa que não seja letra, dígito, `_` ou `-`, ou
#   do fim da linha; `/home/<usuário>` continua passando, porque o `<` não é
#   nome de ninguém.
#   RODADA CONTRA O REPOSITÓRIO INTEIRO ANTES DE FIXAR (24/09): dois achados
#   novos, os dois em teste, e nenhum é a casa de alguém — cada um virou uma
#   isenção nomeada, lá embaixo, com o motivo ao lado.
#
#   UM HOME CABE NO TEXTO DE DUAS FORMAS, e nenhuma das duas casa a regra:
#     - `~/…` (ou `$HOME/…` num comando) quando é RECEITA ou exemplo — diz "a
#       casa de quem estiver lendo", que é o que a receita quer dizer;
#     - `/home/<usuário>/…` quando é MEDIDA citada — o valor que um arquivo
#       tinha naquela máquina era absoluto, e o `<` diz que o nome saiu dali.
#
# AS ISENÇÕES CASAM PELO CONTEÚDO DA LINHA, NUNCA PELO NÚMERO
#   Isenção presa a número de linha apodrece no primeiro rebase: o arquivo anda
#   três linhas, a isenção passa a cobrir a linha errada e o teste fica verde
#   sobre o defeito que veio pegar. Aqui cada isenção é um TRECHO da linha, e o
#   dia em que a linha mudar a isenção para de casar — que é exatamente a hora
#   de alguém reler o motivo.
#
# ESTE ARQUIVO NÃO SE VARRE, E ISSO NÃO É BRECHA
#   Um caçador carrega, por definição, todos os padrões que caça: as isenções
#   abaixo são linhas literais de outros arquivos. Varrer a si mesmo faria o
#   teste acusar cada isenção como se fosse o defeito.
#
#   0 = o repositório está portátil · 1 = achados · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
command -v git >/dev/null 2>&1 || { printf 'pulado: o git não está disponível\n'; exit 0; }

EU="tests/portabilidade.sh"
achados=0
isentos=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; achados=$((achados+1)); }

# ---------------------------------------------------------------------------
# AS ISENÇÕES, uma a uma, com o motivo ao lado
# ---------------------------------------------------------------------------
# Cada entrada é um trecho LITERAL da linha isenta (comparação por substring,
# sem regex). Tudo o que não estiver aqui é achado.
ISENTAS=(
  # --- regra 4: leitura da árvore da vizinha, por contrato documentado -------
  # O `install.sh` semeia o `vizinhos.conf` a partir do DISCO REAL, e para isso
  # precisa perguntar se há um repositório git em `~/.config/zsh`. É justamente
  # o padrão que tirou a lista de vizinhos de dentro do código
  # (`lib/comum.sh:236-249`); cobrar escape aqui seria cobrar o oposto do
  # conserto.
  '[ -d "$HOME/.config/zsh/.git" ]'
  # A mesma função, três linhas abaixo: isto é DADO, não caminho. O `\$HOME` sai
  # escapado de propósito para que o `vizinhos.conf` guarde a variável, e não o
  # valor expandido de quem rodou o instalador.
  '\$HOME/.config/zsh'
  # Um `case` que só existe para decidir se o AVISO sai. O destino real vem de
  # `MEOW_COMPLETIONS_DIR`, que é o escape — e o comentário logo acima dele diz
  # que foi assim que a linha foi testada.
  '"$HOME/.config/zsh"/*)'

  # --- regra 4: ISENÇÃO COM DÍVIDA ANOTADA ----------------------------------
  # ERAM DUAS. UMA FOI PAGA EM 22/09/2026 (sprint P29), E A OUTRA CONTINUA AQUI.
  #
  # A QUE SAIU:
  #     'MEOW_QBT_AURORA_FONTE="$HOME/.config/zsh/scripts/aurora-qbittorrent-config.sh"'
  #   A P29 foi buscar o arquivo no Spellbook para trazê-lo, e mediu que ele
  #   NÃO EXISTE lá — `find ~/.config/zsh -name '*qbittorrent*'` devolve zero
  #   linha. Não era "está no outro projeto": era dependência de um arquivo que
  #   não existe em lugar nenhum. A linha do manifesto virou
  #   `${MEOW_QBT_AURORA_FONTE:-}` — padrão vazio —, e a isenção saiu junto.
  #
  #   E ESTE É O MOTIVO DE A ISENÇÃO TER DE SAIR NO MESMO COMMIT que o conserto:
  #   enquanto ela estivesse aqui, este teste passaria VERDE sobre o defeito que
  #   veio pegar, e passaria verde igual depois de consertado — o que faz dele
  #   um teste que não mede nada. Uma isenção que sobrevive ao seu motivo é pior
  #   que nenhuma isenção.
  #
  # A QUE FICA, e agora é a única: o `scripts/areas.sh` crava a árvore da
  # vizinha sem variável de troca. Continua sendo dívida, não falso positivo. O
  # remédio é uma linha — `${MEOW_AREAS_VIZINHO_FONTE:-$HOME/.config/zsh/...}`,
  # ou o padrão vazio que o qbittorrent acabou de adotar — e o `areas.sh` NÃO
  # está entre os arquivos que a P29 autoriza tocar ("Arquivos, e só estes").
  # Apagar o achado calado seria pior que registrá-lo. No dia em que a linha
  # mudar, esta isenção para de casar sozinha, que é a hora de reler isto.
  'AREAS_VIZINHO_FONTE="$HOME/.config/zsh/scripts/aurora-cosmic-workspaces.py"'

  # --- regra 1: home DE NINGUÉM, dentro de teste de unidade -----------------
  # As quatro linhas do `0001-meow-capa-cor-controles.patch` que casam a regra 1
  # são fixtures de `#[test]` em Rust: `/home/user/` é o home-placeholder
  # canônico, e o que está sendo testado é o PARSER de `file://`, não um
  # caminho que alguém vai abrir. Trocar para `~/` faria o teste deixar de
  # exercitar a forma absoluta, que é a única que aquele parser aceita.
  'file:///home/user/'
  'PathBuf::from("/home/user/Album Art.png")'

  # --- regra 1: home DE NINGUÉM, em exemplo que precisa ser absoluto --------
  # Estas duas só apareceram quando a regra 1 passou a ler comentário e
  # pesquisa, em 23/09/2026 (P38), e nenhuma é casa de alguém: `voce` é quem
  # lê, `x` é valor de teste. As duas pedem a forma ABSOLUTA, então `~` não
  # serve de troca.
  #   O `meow.conf.exemplo` mostra o comando que o `scripts/wallpaper.sh`
  # imprime ao consertar uma saída: o caminho vai entre aspas, onde `~` não
  # expande, e a chave `WALLPAPER_FONTES_DELA` guarda caminho absoluto. A forma
  # da casa desde a P38 seria `/home/<usuário>/`; o arquivo não era desta
  # sprint, e a isenção para de casar sozinha no dia em que a linha mudar.
  'meow wallpaper permitir "/home/voce/Imagens/aquela-pasta"'
  #   A pesquisa de 01/09 conferiu que o validador do painel NÃO recusa um
  # `LOGO` legítimo: o que se media era justamente um caminho absoluto aceito.
  '`LOGO=/home/x/meu-gato.svg`'

  # --- regra 4: a MENSAGEM da leitura que já está isenta acima --------------
  # Esta linha é o aviso que reporta o resultado do `[ -d "$HOME/.config/zsh/.git" ]`
  # logo acima dela, no `bin/meow`. É o mesmo contrato e o mesmo diretório: se a
  # leitura é legítima, dizer em voz alta o que ela achou também é. Ela só
  # apareceu quando o `bin/meow` entrou nesta varredura, em 21/09/2026, pela
  # porta do shebang.
  'meow_aviso "$HOME/.config/zsh é um repositório git e não está protegido"'

  # --- regra 1 SEM A BARRA: as duas que a P43 achou ao fechar a porta -------
  # A casa de mentira do `tests/pack.sh`: é o DADO que a régua do `validar`
  # (a da P30, `RE_CASA_DE_ALGUEM`) tem de recusar, e a prova só vale com a
  # forma absoluta — `~` é justamente o que a régua deixa passar. `fulano` é o
  # nome de ninguém. O `tests/pack.sh` não é desta sprint; se a linha mudar, a
  # isenção para de casar sozinha.
  'CASA_ALHEIA="/home/fulano"'
  # O HOME de brinquedo do `tests/fonte-unica.sh` é `$T/home`, e `tema` é uma
  # pasta DENTRO dele — o `/home/tema` que a regra lê é o fim de `$T/home/` e o
  # nome de uma pasta de teste, não a casa de alguém.
  'tema="$T/home/tema"'
)

# --- regra 1: A ÚNICA ISENÇÃO POR ARQUIVO, e ela é guarda, não descuido -----
# A linha `origem:` da captura `original` guarda o caminho ABSOLUTO de onde o
# tema de fábrica foi tirado, e de propósito (P30, 23/09/2026). O único leitor
# dela é o `cmd_desfazer` do `bin/meow`, que a compara com o `$COSMIC` desta
# máquina para RECUSAR o reset de fábrica de outra pessoa. Com `~` a guarda
# quebra dos dois jeitos: comparado cru, `~/.config/cosmic` não é igual a
# nenhum `$COSMIC` e a própria máquina que capturou passa a ser recusada;
# expandido antes, ele é igual em toda máquina e a de fora passa a ser aceita.
# O motivo inteiro está no `scripts/capturar_tema.sh`, em "a `original` É A
# EXCEÇÃO". E ela não viaja: mora no motor, fora de pack nenhum.
#   É por ARQUIVO + forma da linha, e não por trecho como as de cima, porque o
# trecho seria o próprio nome de usuário — escrevê-lo aqui plantaria no teste
# exatamente o que o teste existe para tirar do repositório.
ORIGEM_DE_FABRICA="assets/temas/capturados/original/captura.txt"

# O ARQUIVO DE REGISTRO, que não é receita de ninguém
# ---------------------------------------------------------------------------
# Estes três guardam MEDIÇÃO: uma sprint cita a linha exata que mediu, com o
# `[REDACTED]` e o `/mnt/Apate` preservados — é o que faz o registro valer
# alguma coisa. Cobrar portabilidade de um arquivo cujo trabalho é transcrever
# o defeito seria pedir que ele mentisse sobre o que viu.
#   O HOME DA PESSOA SAIU DESTA LISTA EM 23/09/2026 (P38): as regras 2, 3 e 4
# continuam poupando o registro, a regra 1 não. Um home medido se transcreve
# como `/home/<usuário>/…`, que diz a mesma verdade — o valor era absoluto —
# sem dizer de quem era a casa.
#
# A exclusão é por CAMINHO, e não por linha, porque aqui o arquivo inteiro tem
# essa natureza — um `docs/sprints/` novo nasce coberto, sem ninguém lembrar.
_arquivo_de_registro() {
  case "$1" in
    docs/sprints/*|docs/historico/*|docs/SPRINTS.md) return 0 ;;
  esac
  return 1
}

isenta() {
  local linha="$1" arquivo="$2" t
  if [ "$arquivo" = "$ORIGEM_DE_FABRICA" ]; then
    case "$linha" in 'origem: /home/'*'/.config/cosmic') return 0 ;; esac
  fi
  for t in "${ISENTAS[@]}"; do
    case "$linha" in *"$t"*) return 0 ;; esac
  done
  return 1
}

# Uma porta só para registrar, e é de propósito: com duas, o placar de isenções
# acabaria divergindo do que foi realmente pulado.
acusa() {
  local arquivo="$1" num="$2" linha="$3" frase="$4"
  if isenta "$linha" "$arquivo"; then
    isentos=$((isentos+1))
    return 0
  fi
  falha "$arquivo:$num $frase"
}

# ---------------------------------------------------------------------------
# Os arquivos: os VERSIONADOS, e só eles
# ---------------------------------------------------------------------------
# `git ls-files` em vez de `find`: o que não está no git não chega na máquina de
# ninguém, e varrer o disco traria `venv/`, artefato de build e a captura de
# tema de outra pessoa — ruído que não é o assunto deste teste.
mapfile -t ARQUIVOS < <(git ls-files 2>/dev/null) || exit 2
[ "${#ARQUIVOS[@]}" -gt 0 ] || { printf 'pulado: não há arquivos versionados aqui\n'; exit 0; }

# ---------------------------------------------------------------------------
# REGRA 1 — home de pessoa, em TODO arquivo de texto versionado (P38, 23/09)
# ---------------------------------------------------------------------------
# Um `git grep` só, e não o laço lá de baixo: aquele lê linha a linha em bash,
# um arquivo por vez, e a regra 1 agora lê também os milhares de `.svg` e as
# folhas de imagem em base64. O git faz a mesma pergunta sobre os mesmos
# arquivos versionados, e o `-I` pula o binário pela regra dele (byte nulo nos
# primeiros 8000 bytes) — que é o que "arquivo de texto" quer dizer aqui.
#   A SAÍDA TEM DE TER SEMPRE A MESMA FORMA, venha a configuração de quem for:
# o `-z` separa arquivo, número e linha por byte nulo, e o `--no-column` e o
# `--no-color` desligam o que um `grep.column` ou um `color.grep` no gitconfig
# de alguém enfiariam no meio — com `grep.column=true` a coluna entra como um
# terceiro campo, e a linha lida aqui passaria a começar por ela.
#   O resultado vai para um arquivo, e não direto para o laço, para que o
# código de saída do git possa ser lido: 1 é "nada casou", e qualquer coisa
# acima disso é o teste sem enxergar — aí a resposta é 2, e não um verde que
# não mediu nada.
R1="$(mktemp)" || exit 2
trap 'rm -f "$R1"' EXIT
# O NOME VAI ATÉ O PRIMEIRO CARÁTER QUE NÃO PODE SER NOME, OU ATÉ O FIM DA
# LINHA — com ou sem a barra (P43). A classe do nome continua a de antes.
git grep --no-color --no-column -zInE '/home/[a-zA-Z0-9_-]+([^a-zA-Z0-9_-]|$)' -- . ":(exclude)$EU" > "$R1" 2>/dev/null
case $? in 0|1) ;; *) printf 'FALHOU: o git grep da regra 1 não rodou\n' >&2; exit 2 ;; esac
while IFS= read -r -d '' arq && IFS= read -r -d '' num && IFS= read -r linha; do
  acusa "$arq" "$num" "$linha" "home de pessoa escrito: é o nome de alguém dentro do produto"
done < "$R1"

# Uma linha de COMENTÁRIO não é uma receita. O projeto inteiro é comentado em
# prosa densa, e as 369 menções a `/mnt/Apate` medidas em 21/09/2026 são todas
# história — dizer de onde veio um arquivo é documentação, não instrução.
_so_comentario() {
  case "${1#"${1%%[![:space:]]*}"}" in
    '#'*|'//'*|'*'*|'/*'*) return 0 ;;
  esac
  return 1
}

# Um `read` e nada mais: sem subprocesso, porque isto roda uma vez por arquivo
# versionado e são milhares (3.566 só de `.svg`). Em arquivo binário o `read`
# devolve lixo que simplesmente não começa com `#!`, e a resposta é "não".
_tem_shebang() {
  local primeira
  IFS= read -r primeira < "$1" 2>/dev/null || return 1
  case "$primeira" in '#!'*) return 0 ;; esac
  return 1
}

for arq in "${ARQUIVOS[@]}"; do
  [ "$arq" = "$EU" ] && continue
  _arquivo_de_registro "$arq" && continue
  [ -f "$arq" ] || continue

  # O QUE ENTRA, O QUE FICA DE FORA, E POR QUÊ — a lista foi revista em 21/09
  #   `.patch` entra como código porque o preâmbulo de um patch é receita para
  #   copiar e colar, e sem cerca de crases não há como um `.md` separar prosa de
  #   comando ali dentro. Foi exatamente onde o defeito sobreviveu à primeira
  #   passada desta sprint: o `assets/prompt/LEIAME.md` foi consertado e o
  #   `assets/prompt/aurora.patch` ao lado, que manda o MESMO comando, não — e
  #   este teste não o viu.
  #
  #   O SHEBANG É A TERCEIRA PORTA, e existe por um arquivo só: `bin/meow`, o
  #   executável principal e o maior arquivo de código do projeto, é o único
  #   script versionado sem extensão. Classificar por nome o deixava fora da
  #   regra 1 justamente por ser o arquivo que mais gente vai ler. Medido em
  #   21/09/2026: é o único versionado sem extensão que começa com `#!`.
  #
  #   FICAM DE FORA, e isto é escolha com número, não esquecimento. Varrendo os
  #   quatro padrões em 21/09/2026: `.json` de `docs/pesquisas/` dá 348 linhas,
  #   `.html` das folhas dá 32, `.txt` dá 6 (cinco são a `captura.txt`, que a
  #   própria sprint registra como guarda de propósito) e `.service` dá 4. São
  #   quase todos artefato gerado ou transcrição de medição — a mesma natureza
  #   do `docs/sprints/` logo acima —, e abri-los pediria uma política de
  #   isenção inteira, que é sprint própria e não linha de rodapé desta.
  #   `.css`, `.rs`, `.ron` e `.toml` deram ZERO: entrariam de graça hoje, e
  #   ficam de fora só porque nenhum deles é receita que alguém copia.
  #   DESDE 23/09/2026 (P38) ESTA LISTA É SÓ DAS REGRAS 2, 3 E 4. A regra 1 lê
  #   todos eles, e o registro também, no `git grep` antes deste laço.
  case "$arq" in
    *.sh|*.py|*.js|*.patch) tipo="codigo" ;;
    *.md)                   tipo="prosa" ;;
    *) _tem_shebang "$arq" && tipo="codigo" || continue ;;
  esac

  # `cerca` marca se estamos DENTRO de um bloco cercado por três crases. Num
  # arquivo .md é ele que separa "o que se copia para o terminal" de "o que se
  # lê" — e a diferença entre as duas coisas é o assunto inteiro deste teste.
  cerca=0
  num=0
  while IFS= read -r linha || [ -n "$linha" ]; do
    num=$((num+1))
    case "$linha" in '```'*) cerca=$((1-cerca)); continue ;; esac

    if [ "$tipo" = "codigo" ]; then
      _so_comentario "$linha" && continue
    else
      # Fora da cerca, prosa é prosa.
      [ "$cerca" = "1" ] || continue
    fi

    # --- 1. home de pessoa: não mora mais aqui --------------------------------
    # Desde a P38 ela lê o repositório inteiro, e por isso roda antes deste
    # laço, num `git grep` só. Deixá-la também aqui contaria duas vezes cada
    # linha de código.

    # --- 2. disco que não é padrão -------------------------------------------
    case "$linha" in
      *"/mnt/Apate"*|*"/mnt/Mnemosyne"*)
        acusa "$arq" "$num" "$linha" "disco que não é padrão: quem clonou não tem esse ponto de montagem" ;;
    esac

    # --- 3. identidade redigida numa instrução -------------------------------
    # A instrução é o único lugar onde `[REDACTED]` é fatal: em comentário ele é
    # a própria história do sanitizador, e faz sentido ali.
    case "$linha" in
      *"[REDACTED]"*)
        acusa "$arq" "$num" "$linha" "identidade redigida numa instrução: o comando não roda" ;;
    esac

    # --- 4. ZDOTDIR sem escape ------------------------------------------------
    # `:-` é a marca do escape neste projeto: `${ZDOTDIR:-$HOME/.config/zsh}`,
    # `${CP_COPIA:-...}`, `${MEOW_ZSH_ENV:-...}`. Quem a tem está oferecendo uma
    # porta a quem não guarda o zsh ali.
    if [ "$tipo" = "codigo" ]; then
      case "$linha" in
        *'$HOME/.config/zsh'*|*'${HOME}/.config/zsh'*)
          case "$linha" in
            *':-'*) : ;;
            *) acusa "$arq" "$num" "$linha" "caminho do zsh cravado sem variável de escape" ;;
          esac ;;
      esac
    fi
  done < "$arq"
done

printf '\n'
if [ "$achados" -eq 0 ]; then
  ok "portabilidade: nenhuma receita presa à máquina de quem a escreveu ($isentos isenções)"
  exit 0
fi
printf 'FALHOU: %d achado(s) de portabilidade (%d isenções)\n' "$achados" "$isentos" >&2
exit 1
