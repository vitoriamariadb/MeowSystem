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
#   1. HOME DE PESSOA EM CÓDIGO       `/home/fulano/` cravado num .sh/.py/.js
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
  # As duas linhas abaixo cravam a árvore da vizinha SEM variável de troca, ao
  # contrário do `compositor_patches.sh`, que oferece `CP_COPIA` e
  # `CP_SERIE_ALT` para as mesmas leituras. Não são falso positivo: são dívida.
  # Ficam isentas porque a sprint P22 não autoriza tocar nestes dois arquivos, e
  # apagar o achado calado seria pior que registrá-lo. Quem for consertar: o
  # remédio é uma linha, `${MEOW_...:-$HOME/.config/zsh/...}`, e aí a isenção
  # para de casar sozinha.
  'MEOW_QBT_AURORA_FONTE="$HOME/.config/zsh/scripts/aurora-qbittorrent-config.sh"'
  'AREAS_VIZINHO_FONTE="$HOME/.config/zsh/scripts/aurora-cosmic-workspaces.py"'

  # --- regra 1: o CONTEÚDO de um arquivo dela, citado como medida -----------
  # Não é receita: é o que a chave do applet do logo tem hoje, naquela máquina,
  # dentro de um bloco que o texto apresenta como leitura. Reescrever a medida
  # para `~/` faria o documento afirmar uma coisa que ninguém mediu.
  'custom_logo_path   = "/home/vitoriamaria/.config/cosmic/logos/gato-pop.svg"'

  # --- regra 1: ISENÇÃO COM DÍVIDA ANOTADA ----------------------------------
  # Esta É receita — um `pw-play` para copiar e colar, com o home de outra
  # pessoa no meio. Quem clonar o projeto recebe "arquivo não encontrado". O
  # remédio é uma linha (`$HOME/.local/share/...`), mas o `docs/COSMIC-THEMING.md`
  # não está entre os arquivos que a sprint P22 autoriza tocar.
  'pw-play --media-role Notification /home/vitoriamaria/.local/share/sounds'
)

# O ARQUIVO DE REGISTRO, que não é receita de ninguém
# ---------------------------------------------------------------------------
# Estes três guardam MEDIÇÃO: uma sprint cita a linha exata que mediu, com o
# `[REDACTED]`, o `/mnt/Apate` e o home da pessoa preservados — é o que faz o
# registro valer alguma coisa. Cobrar portabilidade de um arquivo cujo trabalho
# é transcrever o defeito seria pedir que ele mentisse sobre o que viu.
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
  local linha="$1" t
  for t in "${ISENTAS[@]}"; do
    case "$linha" in *"$t"*) return 0 ;; esac
  done
  return 1
}

# Uma porta só para registrar, e é de propósito: com duas, o placar de isenções
# acabaria divergindo do que foi realmente pulado.
acusa() {
  local arquivo="$1" num="$2" linha="$3" frase="$4"
  if isenta "$linha"; then
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

# Uma linha de COMENTÁRIO não é uma receita. O projeto inteiro é comentado em
# prosa densa, e as 369 menções a `/mnt/Apate` medidas em 21/09/2026 são todas
# história — dizer de onde veio um arquivo é documentação, não instrução.
_so_comentario() {
  case "${1#"${1%%[![:space:]]*}"}" in
    '#'*|'//'*|'*'*|'/*'*) return 0 ;;
  esac
  return 1
}

for arq in "${ARQUIVOS[@]}"; do
  [ "$arq" = "$EU" ] && continue
  _arquivo_de_registro "$arq" && continue
  [ -f "$arq" ] || continue

  case "$arq" in
    *.sh|*.py|*.js) tipo="codigo" ;;
    *.md)           tipo="prosa" ;;
    *)              continue ;;
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

    # --- 1. home de pessoa ---------------------------------------------------
    case "$linha" in
      */home/*)
        if printf '%s' "$linha" | grep -qE '/home/[a-zA-Z0-9_-]+/'; then
          acusa "$arq" "$num" "$linha" "home de pessoa cravado: só roda na máquina de quem escreveu"
        fi ;;
    esac

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
