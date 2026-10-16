#!/usr/bin/env bash
# portabilidade.sh — o repositório ainda roda na máquina de um estranho?
#
# Até aqui ela se chamava "ZDOTDIR sem escape" e aceitava a linha que trouxesse
# `:-` — `${ZDOTDIR:-$HOME/.config/zsh}`, `${MEOW_ZSH_ENV:-…}` —, com seis
# linhas isentas para o resto.
#
# Ficavam de fora o comentário, a prosa, as pesquisas, as folhas e os arquivos
# de registro — e foi por essa porta que os homes das duas máquinas onde o
# projeto cresceu se espalharam: 171 linhas em 31 arquivos, medido.
#
# Agora a regra 1 lê TODO arquivo de texto versionado, linha a linha, sem
# perguntar se é comentário ou registro.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
cd "$RAIZ" || exit 2
command -v git >/dev/null 2>&1 || { printf 'pulado: o git não está disponível\n'; exit 0; }

EU="tests/portabilidade.sh"
achados=0
isentos=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; achados=$((achados+1)); }

# AS ISENÇÕES, uma a uma, com o motivo ao lado
#
# Cada entrada é um trecho LITERAL da linha isenta (comparação por substring,
# sem regex).
ISENTAS=(
  # --- regra 4: AS SEIS ISENÇÕES SAÍRAM ------------------

  # --- regra 1: home DE NINGUÉM, dentro de teste de unidade -----------------
  # As quatro linhas do `0001-meow-capa-cor-controles.patch` que casam a regra 1
  # são fixtures de `#[test]` em Rust: `/home/user/` é o home-placeholder
  # canônico, e o que está sendo testado é o PARSER de `file://`, não um caminho
  # que alguém vai abrir.
  'file:///home/user/'
  'PathBuf::from("/home/user/Album Art.png")'

  # --- regra 1: home DE NINGUÉM, em exemplo que precisa ser absoluto --------
  # As duas pedem a forma ABSOLUTA, então `~` não serve de troca.
  'meow wallpaper permitir "/home/voce/Imagens/aquela-pasta"'
  # A pesquisa conferiu que o validador do painel NÃO recusa um `LOGO`
  # legítimo: o que se media era justamente um caminho absoluto aceito.
  '`LOGO=/home/x/meu-gato.svg`'

  # A casa de mentira do `tests/pack.sh`: é o DADO que a régua do `validar`
  # tem de recusar, e a prova só vale com a forma absoluta — `~` é justamente
  # o que a régua deixa passar.
  'CASA_ALHEIA="/home/fulano"'
  # O HOME de brinquedo do `tests/fonte-unica.sh` é `$T/home`, e `tema` é uma
  # pasta DENTRO dele — o `/home/tema` que a regra lê é o fim de `$T/home/` e o
  # nome de uma pasta de teste, não a casa de alguém.
  'tema="$T/home/tema"'
)

# --- regra 1: A ÚNICA ISENÇÃO POR ARQUIVO, e ela é guarda, não descuido -----
# A linha `origem:` da captura `original` guarda o caminho ABSOLUTO de onde o
# tema de fábrica foi tirado, e de propósito.
ORIGEM_DE_FABRICA="assets/temas/capturados/original/captura.txt"

# O ARQUIVO DE REGISTRO, que não é receita de ninguém
#
# Cobrar portabilidade de um arquivo cujo trabalho é transcrever o defeito
# seria pedir que ele mentisse sobre o que viu.
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

# Os arquivos: os VERSIONADOS, e só eles
#
# `git ls-files` em vez de `find`: o que não está no git não chega na máquina de
# ninguém, e varrer o disco traria `venv/`, artefato de build e a captura de
# tema de outra pessoa — ruído que não é o assunto deste teste.
mapfile -t ARQUIVOS < <(git ls-files 2>/dev/null) || exit 2
[ "${#ARQUIVOS[@]}" -gt 0 ] || { printf 'pulado: não há arquivos versionados aqui\n'; exit 0; }

# REGRA 1 — home de pessoa, em TODO arquivo de texto versionado
#
# Um `git grep` só, e não o laço lá de baixo: aquele lê linha a linha em bash,
# um arquivo por vez, e a regra 1 agora lê também os milhares de `.svg` e as
# folhas de imagem em base64.
R1="$(mktemp)" || exit 2
trap 'rm -f "$R1"' EXIT
# O NOME VAI ATÉ O PRIMEIRO CARÁTER QUE NÃO PODE SER NOME, OU ATÉ O FIM DA
# LINHA — com ou sem a barra. A classe do nome continua a de antes.
git grep --no-color --no-column -zInE '/home/[a-zA-Z0-9_-]+([^a-zA-Z0-9_-]|$)' -- . ":(exclude)$EU" > "$R1" 2>/dev/null
case $? in 0|1) ;; *) printf 'FALHOU: o git grep da regra 1 não rodou\n' >&2; exit 2 ;; esac
while IFS= read -r -d '' arq && IFS= read -r -d '' num && IFS= read -r linha; do
  acusa "$arq" "$num" "$linha" "home de pessoa escrito: é o nome de alguém dentro do produto"
done < "$R1"

# Uma linha de COMENTÁRIO não é uma receita.
_so_comentario() {
  local l="${1#"${1%%[![:space:]]*}"}"
  case "$l" in '#'*) return 0 ;; esac
  case "$2" in
    *.js|*.patch) case "$l" in '//'*|'*'*|'/*'*) return 0 ;; esac ;;
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

  # O QUE ENTRA, O QUE FICA DE FORA, E POR QUÊ — a lista foi revista `.patch`
  # entra como código porque o preâmbulo de um patch é receita para copiar e
  # colar, e sem cerca de crases não há como um `.md` separar prosa de comando
  # ali dentro.
  #
  # FICAM DE FORA, e isto é escolha com número, não esquecimento.
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
      _so_comentario "$linha" "$arq" && continue
    else
      # Fora da cerca, prosa é prosa.
      [ "$cerca" = "1" ] || continue
    fi

    # --- 1. home de pessoa: não mora mais aqui --------------------------------
    # Deixá-la também aqui contaria duas vezes cada linha de código.

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

    # --- 4. o vizinho em execução -------------------------------------------
    # Sem `:-` que valha e sem isenção. Só no código que roda; a `acusa`
    # continua sendo a porta, e a lista de isenções não tem nenhuma linha desta
    # regra.
    if [ "$tipo" = "codigo" ]; then
      case "$arq" in
        bin/*|scripts/*|lib/*|app/*|install.sh)
          case "$linha" in
            *'.config/zsh'*)
              acusa "$arq" "$num" "$linha" "o Spellbook (~/.config/zsh) lido em execução: ou migra para cá, ou sai" ;;
            *'aurora-'*)
              acusa "$arq" "$num" "$linha" "um aurora-* do Ritual chamado em execução: ou migra para cá, ou sai" ;;
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
