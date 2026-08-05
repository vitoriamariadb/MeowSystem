#!/usr/bin/env bash
# auditar_icones.sh — responde, a qualquer momento, a pergunta dela:
# "a lista de ícones está toda baixada e pareada?"
#
#   ./scripts/auditar_icones.sh            tabela colorida + o que falta
#   ./scripts/auditar_icones.sh --lista    acrescenta app por app
#   ./scripts/auditar_icones.sh --ocultos  inclui os .desktop que ela não vê
#   ./scripts/auditar_icones.sh --tema X   simula OUTRO tema sem selecioná-lo
#   ./scripts/auditar_icones.sh --json     saída para máquina
#
#   0 = todo mundo pareado · 1 = algum app sem ícone · 2 = erro · 3 = falta dependência
#
# ESTE SCRIPT NÃO MEXE EM CONFIGURAÇÃO NENHUMA
#   É auditoria, não reparo: nada em `~/.config`, nada em `~/.local/share/icons`,
#   nada em `/usr`. A única escrita do processo inteiro é UMA linha no
#   `~/.local/state/meowsystem/meow.log` (via `meow_registrar`, igual aos outros
#   módulos), para o histórico dizer quando a máquina esteve pareada — e nem essa,
#   no `--json`: modo de máquina costuma rodar em laço, e engordar o log dela a cada
#   volta seria o único estrago que este script saberia fazer.
#
#   Por isso ele também NÃO pega o lock do MeowSystem (`meow_travar`): ela precisa
#   poder rodar isto no meio de um `install.sh`, para ver o efeito, sem que um dos
#   dois recuse a rodar. Consequência boa: a idempotência é de graça — rodar duas
#   vezes dá saída byte a byte idêntica, porque não existe segunda escrita.
#
# ------------------------------------------------------------------------------
# A FONTE DA VERDADE É O CÓDIGO QUE A MÁQUINA DELA RODA, NÃO A ESPECIFICAÇÃO
#
#   Auditoria que "quase" imita o buscador de ícone é pior que nenhuma: ela diz
#   "tudo pareado" e o app aparece com ícone genérico. Por isso a resolução aqui é
#   copiada do buscador REAL — a crate `cosmic-freedesktop-icons`, fixada pelo
#   Cargo.lock do `cosmic-comp` 091583a no commit
#   `ab4c57b8e416c6af9297cb04d101889896fd9a92` de github.com/pop-os/freedesktop-icons
#   (o binário `/usr/bin/cosmic-comp` confirma a versão: a mensagem "unable to read
#   icon theme directory" está em `src/theme/mod.rs` linha 175 nos dois).
#
#   Há DUAS buscas acontecendo aqui, e elas NÃO seguem a mesma regra:
#
#   1) achar o .desktop  -> vence o diretório de MAIOR precedência XDG, e o do
#      usuário vem PRIMEIRO ($XDG_DATA_HOME, depois $XDG_DATA_DIRS na ordem).
#      É por isso que o `google-chrome.desktop` de `~/.local/share/applications`
#      (existem 8 nomes duplicados nesta máquina) é o que vale, e o de
#      `/usr/share/applications` nem é lido.
#
#   2) achar o ÍCONE    -> o laço EXTERNO é o NOME DO TEMA, e o diretório-base é o
#      laço interno (`lib.rs`: `THEMES` é um mapa nome -> lista de bases, e a busca
#      é `icon_themes.iter().find_map(search_theme)`). A lista de bases sai de
#      `paths.rs::icon_theme_base_paths`, nesta ordem:
#        $XDG_DATA_DIRS/{icons,pixmaps} · $XDG_DATA_HOME/{icons,pixmaps} · $HOME/.icons
#      Ou seja: `/usr/share/icons` vem ANTES de `~/.local/share/icons`, e o
#      `~/.icons` é o ÚLTIMO, não o primeiro. **O comentário de doc da própria
#      função mente** ("Look in $HOME/.icons ... in that order") — o código faz o
#      contrário. Seguir o comentário custaria a ordem inteira.
#
#   Uma sessão anterior misturou as duas e concluiu que "/usr/share vence o
#   usuário" — errado; o que perdia era o `hicolor`, que é o FIM da fila de
#   herança. Este script implementa as duas ordens separadamente, de propósito.
#
# ------------------------------------------------------------------------------
# A CADEIA TEM DOIS NÍVEIS, NÃO INFINITOS — E ISSO JÁ MENTIU AQUI
#
#   A tentação é descer a herança recursivamente (avô, bisavô...), que é o que a
#   especificação freedesktop manda. A crate NÃO faz isso: `search_theme_inherits`
#   lê o `Inherits=` do tema selecionado e chama `search_inherited_theme` para cada
#   pai — e essa função só varre os diretórios DAQUELE pai, sem tocar no `Inherits=`
#   dele. Depois vêm quatro temas implícitos, sempre, nesta ordem (lib.rs 344-350):
#
#       Cosmic  ->  hicolor  ->  gnome  ->  Yaru
#
#   MEDIDO, e a diferença não é acadêmica: `MeowSystem-Icons` herda de `Cosmic`, que
#   herda de `Pop`. Uma versão anterior deste script descia até o `Pop` e dava
#   `repoman` como PAREADO — o COSMIC nunca chega lá, e o ícone que ela veria é o
#   genérico. Na direção contrária, o `gnome` (instalado em /usr/share/icons/gnome)
#   ficava de fora, e um ícone que só existe lá seria acusado de "falta baixar".
#
#   O `hicolor` citado no meio de um `Inherits=` é DESCARTADO ali (parse.rs 86,
#   "Filtering out 'hicolor' since we are going to fallback there anyway") e só entra
#   na posição fixa acima. Como os ícones de Flatpak vivem em
#   `~/.local/share/flatpak/exports/share/icons/hicolor`, quase todo app Flatpak
#   resolve nesse degrau — é normal, não é defeito.
#
# ------------------------------------------------------------------------------
# ARMADILHAS QUE ESTE SCRIPT SABE VER (e que um `ls` não veria)
#
#   - A lista branca de subdiretórios do tema NÃO é a chave `Directories=`.
#     `parse.rs::get_all_directories` percorre as SEÇÕES `[...]` do index.theme e
#     aceita cada uma que declare `Size=`, parando na primeira que não declare — a
#     chave `Directories=` nunca é lida. As duas leituras divergem em 3 dos 22
#     index.theme instalados aqui (04/08/2026): o `Pop` tem `[scalable/web]` fora
#     do `Directories=`, e o `ubuntu-mono-*`, `[animations/22]`. Um SVG numa seção
#     que não existe é invisível para o COSMIC, e o sintoma é "baixei e não apareceu": o
#     `~/.local/share/icons/hicolor` desta máquina não tem seção `[scalable/apps]`,
#     e tem arquivo largado em `scalable/apps`. Quando um app cai em "sem ícone", o
#     diagnóstico procura exatamente por isso e diz o nome do pecado.
#
#   - Depois de TODOS os temas ainda há o último recurso: `<base>/<nome>.<ext>`,
#     arquivo solto na raiz de cada base (lib.rs 352-380). É assim que
#     `/usr/share/pixmaps/xterm.xpm` funciona — mas as bases são todas, e nesta
#     máquina isso inclui `~/.local/share/pixmaps` e a raiz de `/usr/share/icons`
#     (que tem dois .png soltos). Tratar só o `/usr/share/pixmaps` deixaria de fora
#     ícone que o COSMIC acha.
#
#   - Dentro de um tema, a EXTENSÃO é o laço externo (`try_fold_icon_path`: o
#     `find_map` de fora é o das extensões): todo `.svg` (de qualquer tamanho) é
#     tentado antes de qualquer `.png`. A ordem `svg,png,xpm` é a de `force_svg`, e
#     é a medida com strace nesta máquina (docs/COSMIC-THEMING.md §2) — sem
#     `force_svg` a crate prefere `.png`. Isso não muda o veredito (existe ou não
#     existe), só qual arquivo aparece na coluna de caminho.
#
#   - `Size=`, `MinSize=`, `MaxSize=` e `Type=` só ORDENAM os subdiretórios
#     (`closest_match_size`), nunca excluem nenhum. Não perca tempo afinando-os.
#
#   - `NoDisplay=true`, `Hidden=true` e `OnlyShowIn=`/`NotShowIn=` decidem o que
#     ela VÊ no menu. São 121 dos 187 `.desktop` desta máquina: auditar os 187
#     encheria a tela de trabalho que não existe (handlers de MIME, applets, o
#     `.desktop` do próprio Flatpak). O padrão é auditar só os visíveis; `--ocultos`
#     traz o resto para quem quiser conferir.
set -uo pipefail

# O `--json` tem de silenciar a cor ANTES de o comum.sh decidir se colore: ele
# olha $NO_COLOR uma vez, no `source`. Espremer isto para depois exigiria zerar as
# variáveis na mão, e alguma escaparia.
# shellcheck disable=SC2034  # quem lê $NO_COLOR é o lib/comum.sh, no `source` abaixo
case " $* " in *" --json "*) NO_COLOR=1 ;; esac

# `dirname` é comando EXTERNO, e usá-lo aqui fazia o script morrer com código 1 —
# "divergente, consertei" — quando o problema era não conseguir nem se carregar.
# `cd` e `pwd` são builtins: assim o bootstrap não depende de PATH nenhum, e a única
# falha possível vira um 3 honesto.
_meow_dir="${BASH_SOURCE[0]}"
case "$_meow_dir" in */*) _meow_dir="${_meow_dir%/*}" ;; *) _meow_dir="." ;; esac
RAIZ="$(cd "$_meow_dir/.." && pwd)"
# shellcheck source=../lib/comum.sh
if ! . "$RAIZ/lib/comum.sh" 2>/dev/null; then
  printf '  erro nao encontrei lib/comum.sh a partir de %s\n' "$RAIZ" >&2
  exit 3
fi
unset _meow_dir

JSON=0; LISTA=0; OCULTOS=0; TEMA_FORCADO=""

_ajuda() {
  cat <<FIM
auditar_icones.sh — a lista de ícones está toda baixada e pareada?

  --lista        mostra app por app, com o tema que entregou o ícone
  --ocultos      inclui os .desktop com NoDisplay/Hidden/OnlyShowIn
  --tema NOME    audita contra outro tema de ícones, sem selecioná-lo
  --json         saída legível por máquina
  -h, --ajuda    isto aqui

saída: 0 = todos pareados · 1 = algum sem ícone · 2 = erro · 3 = falta dependência
FIM
}

while [ $# -gt 0 ]; do
  case "$1" in
    --json)    JSON=1 ;;
    --lista)   LISTA=1 ;;
    --ocultos) OCULTOS=1 ;;
    --tema)    TEMA_FORCADO="${2:-}"
               # Recusar valor com `-` na frente não é preciosismo: `--tema --json`
               # engolia o `--json` como NOME DE TEMA e auditava um tema chamado
               # "--json", em modo humano, sem reclamar de nada.
               case "$TEMA_FORCADO" in
                 ""|-*) meow_erro "--tema exige um nome de tema"; exit "$MEOW_ERRO" ;;
               esac
               shift ;;
    --tema=*)  TEMA_FORCADO="${1#--tema=}" ;;
    -h|--ajuda|--help) _ajuda; exit 0 ;;
    *) meow_erro "argumento desconhecido: $1"; _ajuda >&2; exit "$MEOW_ERRO" ;;
  esac
  shift
done

for dep in find awk; do
  meow_tem "$dep" || { meow_erro "falta '$dep' no PATH"; exit "$MEOW_SEM_DEPENDENCIA"; }
done

TMP="$(mktemp -d -t meow-auditoria.XXXXXX)" || { meow_erro "sem /tmp?"; exit "$MEOW_ERRO"; }
trap 'rm -rf "$TMP"' EXIT

DADOS_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
DADOS_DIRS="${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
AMBIENTE="${XDG_CURRENT_DESKTOP:-COSMIC}"

# ==============================================================================
# 1. QUAL É O TEMA SELECIONADO
# ==============================================================================
# O valor é RON: uma string entre aspas, sem newline no fim. `tr -d` em vez de
# `sed` porque o arquivo pode legitimamente não ter quebra de linha nenhuma.
TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1/icon_theme"
if [ -n "$TEMA_FORCADO" ]; then
  TEMA="$TEMA_FORCADO"; FONTE_TEMA="--tema (simulação)"
elif [ -r "$TK" ]; then
  TEMA="$(tr -d '"\n' < "$TK")"; FONTE_TEMA="$TK"
else
  # Sem a chave, o COSMIC usa o tema dele. Não é erro nem falta de dependência:
  # é uma máquina que nunca teve o tema trocado. Auditar contra "Cosmic" é a
  # resposta honesta para o que ela veria na tela agora.
  TEMA="Cosmic"; FONTE_TEMA="(chave ausente — padrão do COSMIC)"
fi
[ -n "$TEMA" ] || { meow_erro "o tema de ícones selecionado está vazio em $TK"; exit "$MEOW_ERRO"; }

# ==============================================================================
# 2. AS BASES DE ÍCONE, NA ORDEM DO paths.rs::icon_theme_base_paths
# ==============================================================================
# cada $XDG_DATA_DIRS/{icons,pixmaps} -> $XDG_DATA_HOME/{icons,pixmaps} -> $HOME/.icons
#
# Os diretórios `pixmaps` entram na MESMA lista que os `icons`, e não como um
# apêndice: para a crate eles são base de tema como qualquer outra (nenhum tem
# index.theme, então não rendem tema nenhum — mas rendem o último recurso do
# arquivo solto, lá na seção 6). E o `$HOME/.icons` é o ÚLTIMO da lista, ao
# contrário do que a especificação freedesktop e o comentário da própria função
# dizem.
BASES=()
IFS=':' read -r -a _dd <<<"$DADOS_DIRS"
for d in "${_dd[@]}"; do [ -n "$d" ] && BASES+=("$d/icons" "$d/pixmaps"); done
BASES+=("$DADOS_HOME/icons" "$DADOS_HOME/pixmaps" "$HOME/.icons")

# Rótulo CURTO de um diretório. A tabela alinha por largura de coluna: um caminho
# absoluto inteiro no rótulo (acontece com $XDG_DATA_DIRS fora do comum) esticaria
# a coluna e quebraria o desenho. Caminho desconhecido vira "…/penúltimo/último".
_curto_caminho() {
  local p="${1/#$HOME/\~}" pai
  if [ "${#p}" -gt 20 ]; then pai="${p%/*}"; printf '…/%s/%s' "${pai##*/}" "${p##*/}"
  else printf '%s' "$p"; fi
}

_rotulo_base() {
  # shellcheck disable=SC2088  # o "~/.icons" é RÓTULO de tabela, não caminho a expandir
  case "$1" in
    "$DADOS_HOME/icons")     printf 'usuário' ;;
    "$DADOS_HOME/pixmaps")   printf 'pixmaps do usuário' ;;
    "$HOME/.icons")          printf '~/.icons' ;;
    "$DADOS_HOME"/flatpak/*) printf 'flatpak' ;;
    /var/lib/flatpak/*)      printf 'flatpak sistema' ;;
    /usr/share/icons)        printf 'sistema' ;;
    /usr/share/pixmaps)      printf 'pixmaps' ;;
    *)                       _curto_caminho "$1" ;;
  esac
}

# ==============================================================================
# 3. A CADEIA DE HERANÇA — DOIS NÍVEIS E QUATRO IMPLÍCITOS, NADA MAIS
# ==============================================================================
# tema selecionado -> `Inherits=` DIRETO dele (sem hicolor) -> Cosmic -> hicolor
# -> gnome -> Yaru. Sem recursão: os avós NÃO são consultados pelo COSMIC (veja o
# bloco no cabeçalho — foi por descer até o avô `Pop` que uma versão anterior deu
# `repoman` como pareado, mentindo).
_indice_de() {   # primeiro index.theme do tema, em qualquer base
  local tema="$1" b
  for b in "${BASES[@]}"; do
    [ -f "$b/$tema/index.theme" ] && { printf '%s' "$b/$tema/index.theme"; return 0; }
  done
  return 1
}

_herda() {       # Inherits= do index.theme, um por linha
  local idx="$1"
  awk -F= '
    /^\[Icon Theme\]/ { g=1; next }
    /^\[/            { if (g) exit }
    g && /^Inherits=/ {
      n = split(substr($0, 10), p, ",")
      for (i = 1; i <= n; i++) { gsub(/^[ \t]+|[ \t\r]+$/, "", p[i]); if (p[i] != "") print p[i] }
      exit
    }' "$idx"
}

declare -A JA_NA_CADEIA=()
CADEIA=()
_por_na_cadeia() {   # acrescenta um tema, se ele existir em alguma base
  local tema="$1"
  [ -n "${JA_NA_CADEIA[$tema]:-}" ] && return 0
  _indice_de "$tema" >/dev/null || return 0   # citado mas não instalado: ignora
  JA_NA_CADEIA[$tema]=1
  CADEIA+=("$tema")
}

# `THEMES.get(tema).or_else(hicolor)`: tema selecionado que não existe em disco não
# é erro — o COSMIC troca a raiz da busca pelo hicolor e segue com os implícitos.
RAIZ_TEMA="$TEMA"
_indice_de "$TEMA" >/dev/null || RAIZ_TEMA="hicolor"
_por_na_cadeia "$RAIZ_TEMA"

# O `Inherits=` é lido de TODAS as bases que tenham esse tema, não só da primeira:
# a crate percorre a lista inteira de cópias do tema procurando quem responda.
for b in "${BASES[@]}"; do
  [ -f "$b/$RAIZ_TEMA/index.theme" ] || continue
  while IFS= read -r pai; do
    [ "$pai" = "hicolor" ] && continue   # descartado no parse; entra na posição fixa
    _por_na_cadeia "$pai"
  done < <(_herda "$b/$RAIZ_TEMA/index.theme")
done

for t in Cosmic hicolor gnome Yaru; do _por_na_cadeia "$t"; done

# Sem isto a auditoria diria "sem ícone" para meio mundo sem explicar a causa comum
# a todos — que é um `icon_theme` com nome errado. Vai para o STDERR inteiro: o
# `meow_info` escreve no stdout, e uma linha dessas no meio do `--json` produzia um
# documento que nenhum parser aceita (medido: `json.load` estourava no caractere 2).
if [ "$RAIZ_TEMA" != "$TEMA" ]; then
  meow_aviso "o tema '$TEMA' não está instalado em nenhuma base de ícones"
  meow_info "a busca cai direto no hicolor — é por isso que os ícones somem" >&2
fi

# ==============================================================================
# 4. OS PARES (tema, base) NA ORDEM REAL DE CONSULTA
# ==============================================================================
# Nome do tema é o laço externo; a base é o interno. Um par só existe se tiver
# index.theme ALI: um diretório de tema sem index.theme não é tema, e um mesmo
# nome em duas bases tem seções de tamanho diferentes (o `hicolor` do usuário e o do
# sistema divergem nesta máquina — é a armadilha do cabeçalho).
PARES=()   # "tema\tbase\trotulo\tindex.theme"
for tema in "${CADEIA[@]}"; do
  for b in "${BASES[@]}"; do
    [ -f "$b/$tema/index.theme" ] || continue
    rb="$(_rotulo_base "$b")"
    PARES+=("$tema"$'\t'"$b"$'\t'"$tema ($rb)"$'\t'"$b/$tema/index.theme")
  done
done
[ ${#PARES[@]} -gt 0 ] || { meow_erro "nenhum tema de ícones instalado (nem '$TEMA' nem hicolor)"; exit "$MEOW_SEM_DEPENDENCIA"; }

# Subdiretórios que o COSMIC realmente enxerga, um por linha.
#
# NÃO é a chave `Directories=` — essa a crate nunca lê. O que vale é a SEÇÃO:
# `parse.rs::get_all_directories` percorre os `[...]` do index.theme e aceita cada
# um que declare `Size=`. E ele PARA no primeiro que não declare (o `size.take()?`
# encerra o iterador inteiro, não pula a seção) — por isso o `exit` aqui, e não um
# `next`. Divergem em 3 dos 22 index.theme instalados aqui; ler a chave errada dá
# tanto falso "existe" quanto falso "não existe".
_secoes_com_size() {
  awk '
    /^[ \t]*\[/ {
      if (sec != "" && sec != "Icon Theme") { if (!tem) exit; print sec }
      linha = $0
      sub(/^[ \t]*\[/, "", linha); sub(/\][ \t\r]*$/, "", linha)
      sec = linha; tem = 0
      next
    }
    /^[ \t]*Size[ \t]*=/ { tem = 1 }
    END { if (sec != "" && sec != "Icon Theme" && tem) print sec }' "$1"
}

# ==============================================================================
# 5. QUAIS .desktop CONTAM
# ==============================================================================
# Precedência XDG de verdade: $XDG_DATA_HOME primeiro, $XDG_DATA_DIRS depois, na
# ordem. Mesmo nome de arquivo = mesmo app; o primeiro a aparecer ganha e os
# outros nem são lidos (8 nomes duplicados nesta máquina).
ORIGENS=("$DADOS_HOME/applications")
for d in "${_dd[@]}"; do [ -n "$d" ] && ORIGENS+=("$d/applications"); done

_rotulo_origem() {
  case "$1" in
    "$DADOS_HOME/applications")    printf 'usuário' ;;
    "$DADOS_HOME"/flatpak/*)       printf 'flatpak' ;;
    /var/lib/flatpak/*)            printf 'flatpak sistema' ;;
    /usr/share/applications)       printf 'sistema' ;;
    /usr/local/share/applications) printf 'local' ;;
    *)                             _curto_caminho "$1" ;;
  esac
}

# Lê só o grupo [Desktop Entry]. Ler o arquivo inteiro pegaria o `Icon=` das
# [Desktop Action ...] (o Chrome tem três) e auditaria um ícone que não é o do app.
# `Name[pt_BR]` na frente do `Name` porque a tabela é para ela ler.
_ler_desktop() {
  awk -v amb="$AMBIENTE" '
    BEGIN { FS = "\n" }
    /^\[/ { if (g) exit; if ($0 ~ /^\[Desktop Entry\]/) g = 1; next }
    !g { next }
    { sub(/\r$/, "") }
    /^Type=/        && tipo  == "" { tipo  = substr($0, 6) }
    /^Icon=/        && icone == "" { icone = substr($0, 6) }
    /^Name=/        && nome  == "" { nome  = substr($0, 6) }
    /^Name\[pt_BR\]=/ && nomebr == "" { nomebr = substr($0, 13) }   # "Name[pt_BR]=" tem 12 caracteres
    /^NoDisplay=/   && nod   == "" { nod   = substr($0, 11) }
    /^Hidden=/      && hid   == "" { hid   = substr($0, 8) }
    /^OnlyShowIn=/  && so    == "" { so    = substr($0, 12) }
    /^NotShowIn=/   && ns    == "" { ns    = substr($0, 11) }
    END {
      oculto = 0
      if (tolower(nod) == "true" || tolower(hid) == "true") oculto = 1
      if (so != "" && index(";" so ";", ";" amb ";") == 0) oculto = 1
      if (ns != "" && index(";" ns ";", ";" amb ";") >  0) oculto = 1
      if (tipo != "" && tipo != "Application") oculto = 1
      printf "%s\t%s\t%s\n", oculto, (nomebr != "" ? nomebr : nome), icone
    }' "$1"
}

declare -A JA_VISTO=()
TOTAL=0; VISIVEIS=0
: > "$TMP/apps"          # id \t rotulo-origem \t nome \t icone
for dir in "${ORIGENS[@]}"; do
  [ -d "$dir" ] || continue
  rot="$(_rotulo_origem "$dir")"
  while IFS= read -r arq; do
    id="${arq##*/}"; id="${id%.desktop}"
    [ -n "${JA_VISTO[$id]:-}" ] && continue
    JA_VISTO[$id]=1
    TOTAL=$((TOTAL+1))
    IFS=$'\t' read -r oculto nome icone < <(_ler_desktop "$arq")
    [ "$oculto" = "1" ] && [ "$OCULTOS" = "0" ] && continue
    VISIVEIS=$((VISIVEIS+1))
    printf '%s\t%s\t%s\t%s\n' "$id" "$rot" "${nome:-$id}" "${icone:-}" >> "$TMP/apps"
  done < <(find "$dir" -maxdepth 1 -name '*.desktop' 2>/dev/null | sort)
done
OCULTADOS=$((TOTAL - VISIVEIS))

if [ "$VISIVEIS" -eq 0 ]; then
  meow_aviso "nenhum .desktop visível encontrado — nada a auditar"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# ==============================================================================
# 6. RESOLVER OS ÍCONES — UMA PASSADA SÓ
# ==============================================================================
# A tentação é testar `[ -f ]` para cada (nome × tema × base × subdiretório ×
# extensão). Nesta máquina isso dá ~700 mil testes só para o `hicolor`, que
# declara 649 subdiretórios. Em vez disso varremos os diretórios UMA vez, em
# ordem de prioridade, e deixamos o awk casar com o conjunto de nomes desejados.
# Custo: ~26 mil linhas, uma fração de segundo.
#
# `rank` = posição do par × 10 + peso da extensão (svg 0, png 1, xpm 2). Como a
# extensão é o laço externo DENTRO do tema, o `.svg` de 22x22 vence o `.png` de
# 512x512 do mesmo tema — e é isso que o rank codifica.
awk -F'\t' '{ i = $4
              if (i == "" || substr(i,1,1) == "/" || index(i,"/") > 0) next
              sub(/\.(png|svg|xpm)$/, "", i)
              print i }' "$TMP/apps" | sort -u > "$TMP/desejados"

_stream() {
  local i=0 par tema base rotulo idx sub b j nb
  for par in "${PARES[@]}"; do
    IFS=$'\t' read -r tema base rotulo idx <<<"$par"
    local -a alvos=()
    while IFS= read -r sub; do
      [ -d "$base/$tema/$sub" ] && alvos+=("$base/$tema/$sub")
    done < <(_secoes_com_size "$idx")
    if [ ${#alvos[@]} -gt 0 ]; then
      # `-H` NÃO É ENFEITE. MEDIDO nesta máquina, e caro de descobrir:
      # o Papirus-Dark quase não tem diretório de verdade — `128x128` é link para
      # `../Papirus/128x128`, e `128x128/apps` é link também. O `find` padrão (-P)
      # não segue nem o CAMINHO INICIAL quando ele próprio é um link: começar em
      # `Papirus-Dark/128x128/apps` devolve ZERO arquivo, calado. Com `-H` só o
      # ponto de partida é seguido — que é exatamente o que queremos, sem sair
      # descendo por links de dentro do tema.
      find -H "${alvos[@]}" -maxdepth 1 \( -type f -o -type l \) -printf '%f\t%p\n' 2>/dev/null \
        | awk -F'\t' -v br="$((i * 10))" -v rot="$rotulo" 'BEGIN { OFS = "\t" }
            {
              n = $1
              if      (n ~ /\.svg$/) { r = 0 }
              else if (n ~ /\.png$/) { r = 1 }
              else if (n ~ /\.xpm$/) { r = 2 }
              else next
              print br + r, substr(n, 1, length(n) - 4), rot, $2
            }'
    fi
    i=$((i + 1))
  done
  # O ÚLTIMO RECURSO: `<base>/<nome>.<ext>` solto na raiz da base, depois de TODO
  # tema (lib.rs 352-380). São todas as bases, não só o `/usr/share/pixmaps`: nesta
  # máquina há `~/.local/share/pixmaps/hefesto-dualsense4unix.png` e dois .png na
  # raiz de `/usr/share/icons`, e o COSMIC acha os três.
  #
  # Aqui a EXTENSÃO é o laço EXTERNO e a base o interno — o inverso da busca por
  # tema. Por isso o rank multiplica a extensão pelo número de bases: assim um
  # `.svg` na última base vence um `.png` na primeira, que é o que o código faz.
  j=0; nb=${#BASES[@]}
  for b in "${BASES[@]}"; do
    if [ -d "$b" ]; then
      find -H "$b" -maxdepth 1 \( -type f -o -type l \) -printf '%f\t%p\n' 2>/dev/null \
        | awk -F'\t' -v br="$(( ${#PARES[@]} * 10 ))" -v nb="$nb" -v j="$j" \
              -v rot="solto em $(_rotulo_base "$b")" 'BEGIN { OFS = "\t" }
            {
              n = $1
              if      (n ~ /\.svg$/) { r = 0 }
              else if (n ~ /\.png$/) { r = 1 }
              else if (n ~ /\.xpm$/) { r = 2 }
              else next
              print br + r * nb + j, substr(n, 1, length(n) - 4), rot, $2
            }'
    fi
    j=$((j + 1))
  done
}

_stream | awk -F'\t' -v quero="$TMP/desejados" 'BEGIN {
    OFS = "\t"
    while ((getline linha < quero) > 0) if (linha != "") q[linha] = 1
  }
  ($2 in q) && (!($2 in melhor) || $1 + 0 < melhor[$2]) { melhor[$2] = $1 + 0; tema[$2] = $3; cam[$2] = $4 }
  END { for (n in melhor) print n, tema[n], cam[n] }' > "$TMP/resolvidos"

declare -A DE_TEMA=() DE_CAMINHO=()
while IFS=$'\t' read -r n t c; do DE_TEMA[$n]="$t"; DE_CAMINHO[$n]="$c"; done < "$TMP/resolvidos"

# ==============================================================================
# 7. VEREDITO POR APP
# ==============================================================================
declare -A CONTA=()
ORDEM_TEMAS=()
COM=0; SEM=0
: > "$TMP/faltantes"     # id \t nome \t icone \t origem
: > "$TMP/pareados"      # id \t nome \t icone \t origem \t tema \t caminho
while IFS=$'\t' read -r id origem nome icone; do
  tema=""; caminho=""
  if [ -z "$icone" ]; then
    tema=""                                    # .desktop sem Icon= — nada a parear
  elif [ "${icone:0:1}" = "/" ] || [ "${icone#*/}" != "$icone" ]; then
    # Caminho e não nome. O COSMIC carrega o arquivo direto, sem passar por tema.
    if [ -f "$icone" ]; then tema="caminho absoluto"; caminho="$icone"; fi
  else
    chave="${icone%.png}"; chave="${chave%.svg}"; chave="${chave%.xpm}"
    tema="${DE_TEMA[$chave]:-}"; caminho="${DE_CAMINHO[$chave]:-}"
  fi

  if [ -n "$tema" ]; then
    COM=$((COM+1))
    [ -z "${CONTA[$tema]:-}" ] && ORDEM_TEMAS+=("$tema")
    CONTA[$tema]=$(( ${CONTA[$tema]:-0} + 1 ))
    printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$nome" "$icone" "$origem" "$tema" "$caminho" >> "$TMP/pareados"
  else
    SEM=$((SEM+1))
    printf '%s\t%s\t%s\t%s\n' "$id" "$nome" "${icone:-(sem Icon=)}" "$origem" >> "$TMP/faltantes"
  fi
done < "$TMP/apps"

# ==============================================================================
# 8. POR QUE FALTOU — o diagnóstico que transforma a lista em ação
# ==============================================================================
# Só roda se algo faltou, porque varre TODAS as bases de ícone (~150 mil arquivos
# em /usr/share/icons). Três respostas possíveis, e cada uma pede uma ação
# diferente — é justamente isso que uma lista de nomes secos não dá:
#   a) o arquivo existe num tema DA CADEIA, mas num subdiretório sem seção
#      `[sub]` com `Size=`  -> o COSMIC ignora; corrigir o index.theme.
#   b) existe num tema FORA da cadeia -> acrescentar o tema ao `Inherits=`.
#   c) não existe em lugar nenhum     -> falta baixar mesmo.
declare -A MOTIVO=()
if [ "$SEM" -gt 0 ]; then
  cut -f3 "$TMP/faltantes" \
    | awk '{ i = $0; if (i == "(sem Icon=)" || index(i, "/") > 0) next
             sub(/\.(png|svg|xpm)$/, "", i); print i }' | sort -u > "$TMP/faltam_nomes"

  RAIZES=()
  for b in "${BASES[@]}"; do [ -d "$b" ] && RAIZES+=("$b"); done
  if [ -s "$TMP/faltam_nomes" ] && [ ${#RAIZES[@]} -gt 0 ]; then
    # `-L` aqui, e não `-H`: esta varredura ANDA pela árvore inteira, e a árvore
    # dos temas Papirus é feita de links (os 81 mil arquivos do Papirus aparecem
    # no Papirus-Dark por link de diretório). Sem `-L` o diagnóstico diria "não
    # existe em nenhum tema" para ícone que existe — o pior conselho possível.
    # Custo medido: ~1,5 milhão de caminhos, ~0,9 s. Só roda quando algo faltou.
    find -L "${RAIZES[@]}" -mindepth 3 \( -type f -o -type l \) \
         \( -name '*.svg' -o -name '*.png' -o -name '*.xpm' \) -printf '%p\n' 2>/dev/null \
      | awk -v quero="$TMP/faltam_nomes" '
          BEGIN { while ((getline l < quero) > 0) if (l != "") q[l] = 1 }
          { n = $0; sub(/.*\//, "", n); sub(/\.[^.]+$/, "", n)
            if ((n in q) && !(n in visto)) { visto[n] = 1; print n "\t" $0 } }' > "$TMP/faltam_onde"
  else
    : > "$TMP/faltam_onde"
  fi

  while IFS=$'\t' read -r nome caminho; do
    # tema = componente logo depois da base; resto = subdiretório declarado ou não
    achou_base=""
    for b in "${BASES[@]}"; do
      case "$caminho" in "$b"/*) achou_base="$b"; break ;; esac
    done
    resto="${caminho#$achou_base/}"; tema_ach="${resto%%/*}"
    sub="${resto#*/}"; sub="${sub%/*}"
    if [ -n "${JA_NA_CADEIA[$tema_ach]:-}" ]; then
      MOTIVO[$nome]="existe em $tema_ach/$sub, mas o index.theme daquele tema não tem uma seção [$sub] com Size= — o COSMIC ignora"
    else
      MOTIVO[$nome]="existe no tema '$tema_ach', que não está na cadeia de herança — acrescente-o ao Inherits="
    fi
  done < "$TMP/faltam_onde"
fi

_motivo_de() {
  local icone="$1" chave
  case "$icone" in
    "(sem Icon=)") printf 'o .desktop não declara Icon= — não há o que parear'; return ;;
    */*)           printf 'o Icon= é um caminho, e o arquivo não existe: %s' "$icone"; return ;;
  esac
  chave="${icone%.png}"; chave="${chave%.svg}"; chave="${chave%.xpm}"
  printf '%s' "${MOTIVO[$chave]:-não existe em nenhum tema instalado — falta baixar}"
}

# ==============================================================================
# 9. SAÍDA
# ==============================================================================
_esc() { local s="${1//\\/\\\\}"; printf '%s' "${s//\"/\\\"}"; }

if [ "$JSON" = "1" ]; then
  printf '{\n'
  # Chave de MÁQUINA, sem acento de propósito: quem lê isto é `jq`/`json.load`, e
  # nome de campo com acento vira dor de cabeça em todo consumidor. O validador de
  # acentuação do repo reclamaria, daí o noqa.
  printf '  "versao": 1,\n'   # noqa: acentuacao
  printf '  "data": "%s",\n' "$(date -Iseconds)"
  printf '  "tema_selecionado": "%s",\n' "$(_esc "$TEMA")"
  printf '  "fonte_do_tema": "%s",\n' "$(_esc "$FONTE_TEMA")"
  printf '  "cadeia": ['
  sep=""
  for t in "${CADEIA[@]}"; do printf '%s"%s"' "$sep" "$(_esc "$t")"; sep=", "; done
  printf '],\n'
  printf '  "desktop_total": %s,\n  "auditados": %s,\n  "ignorados_por_visibilidade": %s,\n' \
         "$TOTAL" "$VISIVEIS" "$OCULTADOS"
  printf '  "com_icone": %s,\n  "sem_icone": %s,\n' "$COM" "$SEM"
  printf '  "por_tema": {'
  sep=""
  for t in "${ORDEM_TEMAS[@]}"; do printf '%s"%s": %s' "$sep" "$(_esc "$t")" "${CONTA[$t]}"; sep=", "; done
  printf '},\n'
  printf '  "faltantes": ['
  sep=""
  while IFS=$'\t' read -r id nome icone origem; do
    printf '%s\n    {"id": "%s", "nome": "%s", "icone": "%s", "origem": "%s", "motivo": "%s"}' \
      "$sep" "$(_esc "$id")" "$(_esc "$nome")" "$(_esc "$icone")" "$(_esc "$origem")" \
      "$(_esc "$(_motivo_de "$icone")")"
    sep=","
  done < "$TMP/faltantes"
  [ -n "$sep" ] && printf '\n  '
  printf '],\n'
  printf '  "aplicativos": ['
  sep=""
  while IFS=$'\t' read -r id nome icone origem tema caminho; do
    printf '%s\n    {"id": "%s", "nome": "%s", "icone": "%s", "origem": "%s", "tema": "%s", "caminho": "%s"}' \
      "$sep" "$(_esc "$id")" "$(_esc "$nome")" "$(_esc "$icone")" "$(_esc "$origem")" \
      "$(_esc "$tema")" "$(_esc "$caminho")"
    sep=","
  done < "$TMP/pareados"
  [ -n "$sep" ] && printf '\n  '
  printf ']\n}\n'
  [ "$SEM" -gt 0 ] && exit "$MEOW_DIVERGENTE"
  exit "$MEOW_OK"
fi

# A régua tem exatamente a mesma largura da que o `meow_passo` desenha (52), para
# o bloco fechar alinhado com o título. A barra é dimensionada para caber nesse
# mesmo bloco — barra que estoura a régua faz a tabela parecer quebrada.
LARGURA_BLOCO=52
# Repetição em bash puro, sem `seq`. Não é purismo: o `seq` era a única dependência
# do script que NÃO estava na verificação lá de cima, e sem ele a tabela saía com a
# régua de um traço só — errada, mas com código de saída 0, que é o pior jeito de
# falhar. `${s// /$c}` troca cada espaço pelo caractere; `${#t}` e o `%*s` contam em
# CARACTERES no bash, então isto continua certo com o `─` e o `█`, que são multibyte.
_repetir() {
  local n="$1" c="$2" s
  [ "$n" -le 0 ] && return 0
  printf -v s '%*s' "$n" ''
  printf '%s' "${s// /$c}"
}
_regua() { printf '  %s%s%s\n' "$C_DIM" "$(_repetir "$LARGURA_BLOCO" '─')" "$C_ZERO"; }

# O printf do BASH conta BYTES em `%-20s` e `%.20s` — não caracteres. MEDIDO aqui:
# "hicolor (usuário)" tem 17 caracteres e 18 bytes, e sai da coluna com um espaço a
# menos que "hicolor (sistema)", que tem os mesmos 17 caracteres. (O printf do zsh
# acerta, o que torna a armadilha pior: testar o trecho no terminal dela "funciona"
# e o script continua torto.) Por isso NENHUMA coluna aqui usa largura de printf:
# `_encurtar` corta por caractere e o preenchimento vai como `%*s` de espaços, com
# a conta feita em `${#texto}`, que o bash calcula em caracteres.
_encurtar() {
  local t="$1" m="$2"
  if [ "${#t}" -le "$m" ]; then printf '%s' "$t"; else printf '%s…' "${t:0:$((m - 1))}"; fi
}
_sobra() { local n=$(( $1 - ${#2} )); [ "$n" -lt 0 ] && n=0; printf '%s' "$n"; }

meow_titulo "Auditoria de ícones — MeowSystem"

printf '  %stema selecionado%s  %s%s%s\n' "$C_DIM" "$C_ZERO" "$C_MAUVE$C_FORTE" "$TEMA" "$C_ZERO"
printf '  %scadeia de busca%s   ' "$C_DIM" "$C_ZERO"
sep=""
for t in "${CADEIA[@]}"; do
  if [ "$t" = "$TEMA" ]; then printf '%s%s%s%s' "$sep" "$C_MAUVE" "$t" "$C_ZERO"
  else printf '%s%s%s%s' "$sep" "$C_DIM" "$t" "$C_ZERO"; fi
  sep="$C_DIM > $C_ZERO"
done
printf '\n'
if [ "$OCULTOS" = "1" ]; then
  printf '  %saplicativos%s       %s auditados   %s(--ocultos: inclui NoDisplay/Hidden/OnlyShowIn)%s\n' \
         "$C_DIM" "$C_ZERO" "$VISIVEIS" "$C_DIM" "$C_ZERO"
else
  printf '  %saplicativos%s       %s visíveis   %s(de %s .desktop; %s ficaram fora por NoDisplay/OnlyShowIn)%s\n' \
         "$C_DIM" "$C_ZERO" "$VISIVEIS" "$C_DIM" "$TOTAL" "$OCULTADOS" "$C_ZERO"
fi

# --- de onde veio cada ícone ---------------------------------------------------
# Ordenado pela contagem, com barra proporcional: a leitura que ela quer é "o
# tema do MeowSystem está entregando quanto?", e isso é uma comparação visual.
meow_passo "De onde veio cada ícone"
MAIOR=1
for t in "${ORDEM_TEMAS[@]}"; do [ "${CONTA[$t]}" -gt "$MAIOR" ] && MAIOR="${CONTA[$t]}"; done
LARG=8
for t in "${ORDEM_TEMAS[@]}"; do [ "${#t}" -gt "$LARG" ] && LARG="${#t}"; done
[ "$LARG" -gt 30 ] && LARG=30
BARRA_MAX=$(( LARGURA_BLOCO - LARG - 8 )); [ "$BARRA_MAX" -lt 6 ] && BARRA_MAX=6
while IFS=$'\t' read -r n t; do
  barra=$(( n * BARRA_MAX / MAIOR )); [ "$barra" -lt 1 ] && barra=1
  case "$t" in
    "$TEMA"*)              cor="$C_MAUVE" ;;   # o nosso tema, em destaque
    hicolor*|solto*)       cor="$C_AMARELO" ;; # fim da fila: funciona, mas não é tema
    *)                     cor="$C_AZUL" ;;
  esac
  rot="$(_encurtar "$t" "$LARG")"
  printf '  %s%s%s%*s  %s%4s%s  %s%s%s\n' "$cor" "$rot" "$C_ZERO" "$(_sobra "$LARG" "$rot")" '' \
         "$C_FORTE" "$n" "$C_ZERO" "$cor" "$(_repetir "$barra" '█')" "$C_ZERO"
done < <(for t in "${ORDEM_TEMAS[@]}"; do printf '%s\t%s\n' "${CONTA[$t]}" "$t"; done | sort -rn -k1,1)

_regua
PCT=$(( COM * 100 / VISIVEIS ))
if [ "$SEM" -eq 0 ]; then COR_TOTAL="$C_VERDE$C_FORTE"; else COR_TOTAL="$C_AMARELO$C_FORTE"; fi
printf '  %s%s%s%*s  %s%4s%s  %sde %s   (%s%%)%s\n' \
  "$COR_TOTAL" "pareados" "$C_ZERO" "$(_sobra "$LARG" pareados)" '' \
  "$COR_TOTAL" "$COM" "$C_ZERO" "$C_DIM" "$VISIVEIS" "$PCT" "$C_ZERO"

# --- app por app (opcional) ----------------------------------------------------
if [ "$LISTA" = "1" ]; then
  meow_passo "Aplicativo por aplicativo"
  while IFS=$'\t' read -r id nome icone origem tema caminho; do
    case "$tema" in
      "$TEMA"*)          cor="$C_MAUVE" ;;
      hicolor*|solto*)   cor="$C_AMARELO" ;;
      *)                 cor="$C_AZUL" ;;
    esac
    cn="$(_encurtar "$nome" 28)"; ci="$(_encurtar "$icone" 24)"; co="$(_encurtar "$origem" 15)"
    printf '  %s%*s %s%s%s%*s %s%s%s%*s %s%s%s\n' \
      "$cn" "$(_sobra 28 "$cn")" '' \
      "$C_DIM" "$ci" "$C_ZERO" "$(_sobra 24 "$ci")" '' \
      "$C_DIM" "$co" "$C_ZERO" "$(_sobra 15 "$co")" '' \
      "$cor" "$tema" "$C_ZERO"
  done < <(sort -t$'\t' -k5,5 -k2,2 "$TMP/pareados")
fi

# --- o que exige ação ----------------------------------------------------------
printf '\n'
if [ "$SEM" -eq 0 ]; then
  printf '  %sTudo pareado.%s Nenhum app visível ficou sem ícone — nada a fazer.\n\n' \
         "$C_VERDE$C_FORTE" "$C_ZERO"
  meow_registrar "auditar_icones tema=$TEMA visiveis=$VISIVEIS pareados=$COM sem=0"
  exit "$MEOW_OK"
fi

meow_passo "Sem ícone ($SEM) — só estes exigem ação"
# No modo --ocultos a lista enche de `.desktop` que existem SÓ para esconder um app
# (um `[Desktop Entry]` com `Hidden=true` e mais nada — é assim que o UXTerm, o
# qt5ct e o Vim somem do menu dela). Não declarar Icon= ali é o certo, não um furo.
[ "$OCULTOS" = "1" ] && printf '  %scom --ocultos, "sem Icon=" costuma ser um .desktop que só serve para esconder um app%s\n\n' \
  "$C_DIM" "$C_ZERO"
while IFS=$'\t' read -r id nome icone origem; do
  printf '  %s%s%s  %s%s%s\n' "$C_VERM$C_FORTE" "$nome" "$C_ZERO" "$C_DIM" "($origem)" "$C_ZERO"
  printf '    %sIcon=%s%s\n' "$C_DIM" "$C_ZERO" "$icone"
  printf '    %s%s%s\n' "$C_AMARELO" "$(_motivo_de "$icone")" "$C_ZERO"
done < "$TMP/faltantes"
printf '\n'
meow_registrar "auditar_icones tema=$TEMA visiveis=$VISIVEIS pareados=$COM sem=$SEM"
exit "$MEOW_DIVERGENTE"
