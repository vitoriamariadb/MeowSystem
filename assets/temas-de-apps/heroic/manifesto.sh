#!/usr/bin/env bash
# assets/temas-de-apps/heroic/manifesto.sh — Catppuccin dentro do Heroic Games Launcher.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`.
#
# POR QUE ELE EXISTE
#   Pedido dela em 08/09/2026: *"temos alguma seção eu imagino que instale temas
#   dentro dos apps como spotify, qbtorrent e afins pro heroic games, adiciona
#   isso aqui também: https://github.com/catppuccin/heroic"*. O lugar na tela é
#   "Lançadores e jogos", que é onde o Heroic já aparece.
#
# ─────────────────────────────────────────────────────────────────────────────
# O QUE O HEROIC CHAMA DE TEMA, LIDO NO CÓDIGO-FONTE
# ─────────────────────────────────────────────────────────────────────────────
#   Um tema do Heroic é um ARQUIVO CSS solto numa pasta, e nada mais. Duas
#   chaves o ligam, e elas moram em arquivos DIFERENTES:
#
#     customThemesPath   a pasta onde procurar. Vive em `AppSettings`
#                        (`src/common/types.ts`), e o backend a grava em
#                        `<config>/heroic/config.json`, dentro de
#                        `defaultSettings`.
#     theme              o tema escolhido. Vive no `configStore` do FRONT
#                        (`src/frontend/state/GlobalState.tsx`:
#                        `configStore.get('theme', 'midnightMirage')`), que o
#                        `electronStores.ts` aponta para `cwd: 'store'` — ou
#                        seja, `<config>/heroic/store/config.json`, na RAIZ do
#                        objeto, e não dentro de `settings`.
#
#   O VALOR DE `theme` LEVA O `.css` — 09/09/2026, LIDO NO app.asar DO 2.22.1
#     Até 08/09 este cabeçalho afirmava o contrário: *"o valor de `theme` é o
#     nome do arquivo sem o `.css`"*. A afirmação vinha do SELETOR do CSS
#     (`body.catppuccin-mocha-mauve`), não do código que abre o arquivo — e foi
#     ela que fez o defeito parecer medido. Com os 56 CSS na pasta certa e a
#     chave gravada, a tela dela ficou de fábrica, sem erro nenhum. O backend:
#
#       addHandler("getThemeCSS", async (event, theme) => {
#         const cssPath = path.join(customThemesPath, theme);  // não junta ".css"
#         if (!existsSync(cssPath)) return "";                 // e some calado
#         return readFileSync(cssPath, "utf-8");
#       });
#
#     e o front, que só DEPOIS de pedir o arquivo tira a extensão para virar
#     classe:
#
#       const css = await window.api.getThemeCSS(e);
#       e = e.replace(".css", "").replace(/[\s.]/, "_");
#       document.body.className = e;
#
#     O `.replace(".css","")` é a prova: a substituição só existe porque há o
#     que substituir. Gravando `catppuccin-mocha-mauve` sem extensão, o backend
#     procura um arquivo com esse nome exato, não acha, devolve string vazia; o
#     front injeta um `<style>` VAZIO e põe no `body` uma classe que nenhum CSS
#     define — a página cai nos valores de `:root`, que são os de fábrica.
#     Nenhum erro, nenhum aviso, e o `meow apps` dizendo "aplicado".
#
#     Por isso `_heroic_tema` devolve o nome COM a extensão (é o valor da chave
#     E o nome do arquivo, que aqui coincidem) e `_heroic_classe` devolve o nome
#     SEM ela — é a classe do `body`, e só ela escreve o seletor do nosso bloco.
#     São duas funções porque um dia divergiram e ninguém percebeu.
#
#     O `meow doctor` relê esse handler a cada passagem (verificador
#     `heroictema`): se um Heroic futuro passar a juntar o ".css" sozinho, ele
#     AVISA. Não dá para adivinhar a forma nova, mas um defeito com nome é
#     melhor que um defeito mudo.
#
#   `midnightMirage` continua SEM extensão no `reverter`, e não é descuido: é
#   tema embutido, e o front pula o `getThemeCSS` para os embutidos
#   (`e !== "midnightMirage" && !Object.keys(temasEmbutidos).includes(e)`).
#
# ─────────────────────────────────────────────────────────────────────────────
# O REMENDO DAS VARIÁVEIS — O ACERVO ESTÁ UM ANO ATRÁS DO HEROIC
# ─────────────────────────────────────────────────────────────────────────────
#   MEDIDO em 09/09/2026 no `app.asar` da versão instalada: o Heroic 2.22.1 lê
#   **256** variáveis por `var(--…)`; o CSS do acervo (parado em maio de 2025)
#   define **56**. Sobram 201 que ele usa e o acervo não dá.
#
#   A maioria não é cor — FontAwesome (`--fa-*`, 50), espaçamento, escala de
#   texto, família de fonte. Das que são cor, o que decide a entrada aqui é o
#   ESCOPO em que o Heroic as define, lido bloco a bloco no CSS do bundle:
#
#     1. definida só dentro de `body.<tema-embutido>`  → MORRE com a nossa
#        classe no `body`. Uma variável sem valor dentro de `var()` invalida a
#        propriedade inteira: é botão sem fundo de hover, fundo de modal que
#        some, título de conquista sem cor. Estas entram.
#     2. definida em `:root`/`body` com um hex LITERAL → sobrevive, mas com a
#        cor de fábrica (o ciano `#8bffff`, o roxo `#b098e2`). Não quebra nada;
#        fica fora da paleta no meio do nosso tema. Estas entram.
#     3. o Heroic não a define em lugar NENHUM (`--border-color`, `--stop-button`,
#        `--text-muted`, `--warning`, `--background-hover`…). São 91, e são
#        defeito DELE: quebram igual em todo tema, inclusive no de fábrica.
#        Ficam de fora — dar valor a elas faria o nosso tema divergir de todos
#        os outros por uma escolha que ninguém viu na tela.
#     4. definida em escopo de COMPONENTE (`.Sidebar`, `.Dialog`, `.loginPage`)
#        → sobrevive à troca de classe do `body`. Não precisa de remendo. Foi a
#        armadilha do primeiro corte: as `--sidebar-*` parecem mortas num grep
#        por `:root` e não estão.
#     5. definida só dentro de regras de OUTRO tema (`body.nord-light .algo`) →
#        inalcançável com a nossa classe. `--background-light` é o caso: o plano
#        a listava, e ela nunca é lida fora do nord-light.
#
#   Quando o tema de fábrica só define a variável por INDIREÇÃO para algo que o
#   acervo já dá (`--icon-disabled: var(--disabled-button)`), a linha é repetida
#   como está: a indireção passa a apontar para a nossa paleta sozinha, e não se
#   escolhe cor nenhuma. Só as de valor literal recebem cor — e a cor sai de
#   `assets/paleta/catppuccin.json`, lida por `python3`, nunca escrita à mão
#   aqui (é a regra da paleta: "nenhum hex pode ser hardcoded em script").
#
#   Estado de hover segue a convenção que o PRÓPRIO acervo já usa: ele mapeia
#   `--brand-primary-hover`, `--success-hover` e `--danger-hover` para `overlay0`
#   nos quatro flavors. Onde o hover é de uma cor de status, vai o vizinho de
#   paleta (red→maroon, green→teal, yellow→peach), que preserva o significado.
#
#   O bloco entra NO FIM do arquivo instalado, com o mesmo seletor do arquivo do
#   upstream. O `SHA256SUMS` continua conferindo a cópia do upstream NO
#   REPOSITÓRIO — o que é instalado é upstream + bloco, e quem confere isso é o
#   `meow_app_conferir`, pela régua do `meow_escrever` (ver a nota lá).
#
# ─────────────────────────────────────────────────────────────────────────────
# ONDE A PASTA DE TEMAS PODE FICAR — E POR QUE NÃO EM ~/.local/share
# ─────────────────────────────────────────────────────────────────────────────
#   MEDIDO, com `flatpak info --show-permissions com.heroicgameslauncher.hgl`:
#   a lista de `filesystems` traz `~/.steam`, `~/Games/Heroic:create`, `/mnt`,
#   `~/.local/share/applications`, `~/.local/share/lutris` — e NÃO traz
#   `~/.local/share/meowsystem`. Instalar os temas no nosso diretório de dados
#   daria uma pasta que existe, com os 56 arquivos certos dentro, e que o Heroic
#   não enxerga: a lista de temas dele abriria vazia, sem erro nenhum.
#
#   Então a pasta é a DELE: `<config>/heroic/themes`. E o caminho absoluto é o
#   mesmo dos dois lados da caixa — medido rodando dentro do sandbox:
#       $ flatpak run --command=sh com.heroicgameslauncher.hgl -c 'echo $XDG_CONFIG_HOME'
#       /home/vitoriamaria/.var/app/com.heroicgameslauncher.hgl/config
#   É por isso que gravar o caminho do HOST na chave funciona.
#
# ─────────────────────────────────────────────────────────────────────────────
# A ARMADILHA: O HEROIC REESCREVE OS DOIS ARQUIVOS AO SAIR
# ─────────────────────────────────────────────────────────────────────────────
#   Os dois são estado vivo de um Electron aberto. Escrever com o app rodando é
#   escrever num arquivo que vai ser sobrescrito pela memória dele no fechamento
#   — e o módulo diria "aplicado" com a tela mostrando o tema antigo. Por isso
#   `_heroic_rodando` recusa antes de tocar em qualquer coisa, com o código de
#   dependência ausente: não é erro, é "agora não".
#
#   Pela mesma razão nada aqui é escrito por regex no texto cru do JSON. Quem lê
#   e escreve é o `python3`, com `json`, preservando a indentação de cada
#   arquivo — o `store/config.json` usa TAB e o `config.json` usa dois espaços,
#   conferido com `cat -A`. Um `sed` numa chave que não existe ainda não
#   acrescenta nada, e num arquivo de 60 chaves a diferença não aparece.
#
# O ACERVO
#   56 CSS (4 flavors x 14 accents) de https://github.com/catppuccin/heroic,
#   MIT, pinados no commit do arquivo `upstream/COMMIT` e conferidos pelo
#   `SHA256SUMS`. São 240 KB de texto: vão para o git, ao contrário dos cursores
#   e dos papéis de parede, porque texto pequeno versionado é o que permite
#   instalar sem rede.

_HEROIC_APPID="com.heroicgameslauncher.hgl"
_HEROIC_FLAVOR="${FLAVOR:-mocha}"
_HEROIC_ACENTO="${ACCENT:-mauve}"
_HEROIC_ORIGEM="$RAIZ/assets/temas-de-apps/heroic/upstream/themes"

_HEROIC_PALETA="$RAIZ/assets/paleta/catppuccin.json"

# A CLASSE do `body` — o nome do arquivo sem a extensão. É ela que abre o CSS do
# upstream (`body.catppuccin-mocha-mauve { … }`) e é ela que abre o nosso bloco.
# Se a combinação de flavor e accent dela não existir no acervo (accent novo do
# Catppuccin, por exemplo), o módulo cai no par de fábrica do projeto em vez de
# apontar para um arquivo que não existe.
_heroic_classe() {
  local nome="catppuccin-${_HEROIC_FLAVOR}-${_HEROIC_ACENTO}"
  [ -f "$_HEROIC_ORIGEM/$nome.css" ] || nome="catppuccin-mocha-mauve"
  printf '%s' "$nome"
}

# O VALOR DA CHAVE `theme`, que é o nome do ARQUIVO — com o `.css`. Ver a seção
# do cabeçalho: o `getThemeCSS` do 2.22.1 faz `join(customThemesPath, theme)` e
# não acrescenta extensão nenhuma. Sem o `.css` aqui a tela fica de fábrica sem
# nenhum aviso, que foi o defeito de 08/09/2026.
_heroic_tema() {
  printf '%s.css' "$(_heroic_classe)"
}

# ─────────────────────────────────────────────────────────────────────────────
# A TABELA DO REMENDO — UM LUGAR SÓ, UMA LINHA POR VARIÁVEL
# ─────────────────────────────────────────────────────────────────────────────
#   `nome|receita`. A receita é uma de três coisas:
#     var(--x)   uma indireção do tema de fábrica, repetida como está. `--x` é
#                uma variável que o acervo JÁ define, então a linha não escolhe
#                cor nenhuma — ela reaponta a indireção para a nossa paleta.
#     @cor       um nome de `assets/paleta/catppuccin.json`, resolvido no flavor
#                do arquivo. `@accent` é o accent dela. `@cor+XX` acrescenta os
#                dois dígitos de alfa ao hex.
#     literal    o que estiver escrito, copiado sem tocar.
#
#   Acrescentar ou tirar uma variável é acrescentar ou tirar UMA linha daqui.
#   A régua final não é o grep: é `getComputedStyle` com a janela aberta.
_HEROIC_REMENDO=(
  # 1. Morrem com a nossa classe (o Heroic só as define dentro de `body.<tema>`),
  #    e o tema de fábrica as resolve por indireção para algo que o acervo dá.
  "--button-stroke|var(--accent)"
  "--icon-disabled|var(--disabled-button)"
  "--install-button|var(--secondary-button)"
  "--link-highlight|var(--accent)"
  "--modal-backdrop|var(--background-darker-80)"
  "--text-danger|var(--status-danger)"
  "--text-log|var(--status-warning)"
  "--text-quartenary|var(--neutral-04)"
  "--text-warning|var(--status-warning-hover)"

  # 2. Morrem também, mas o tema de fábrica as resolve num literal fora da
  #    paleta — aqui o papel foi lido no uso, não no nome:
  #    `--text-hover` é o texto que acende no hover (o `--sidebar-hover-text-color`
  #    sai daqui); `--text-title` é o `h1` e o título de conquista;
  #    `--download-button` é o ícone secundário e o item de menu sob o cursor;
  #    `--background-secondary` é o fundo do botão `outline` desabilitado.
  "--text-hover|@accent"
  "--text-title|@text"
  "--download-button|@accent"
  "--background-secondary|@surface0"

  # 3. Sobrevivem em `:root`/`body`, com o hex de fábrica. Não quebram nada —
  #    só são de outra paleta no meio da nossa. `--accent-02` é o fundo da
  #    pastilha de gênero (o `5b` é o alfa que o Heroic usa nela);
  #    `--gamecard-title-color` é o véu atrás do título sobre a capa, e é o
  #    único que o plano errou de papel: chamá-lo de "cor do texto" pintaria a
  #    barra inteira de claro. Vai `crust` com alfa, que funciona no mocha E no
  #    latte — o `#000000cc` de fábrica é véu preto sob texto escuro no latte.
  "--accent-overlay|@accent"
  "--accent-02|@accent+5b"
  "--brand-secondary|@accent"
  "--brand-text-01|@subtext1"
  "--brand-text-02|@subtext0"
  "--brand-text-05|@accent"
  "--primary-hover|@overlay0"
  "--primary-active|@accent"
  "--secondary-hover|@overlay0"
  "--status-default|@subtext0"
  "--status-default-hover|@subtext1"
  "--status-danger-hover|@maroon"
  "--status-success-hover|@teal"
  "--status-warning-hover|@peach"
  "--gamecard-title-color|@crust+cc"
  "--anticheat-denied|@red"
  "--alphabet-filter-bg-hover|@surface1"

  # 4. A ÚNICA da terceira espécie (o Heroic não a define em lugar nenhum), e
  #    ela está aqui com a medição contra si: o plano dizia que sem valor o
  #    `filter: grayscale(var(--installing-effect))` fica inválido e as capas de
  #    jogo não instalado apareceriam coloridas. Não é o que acontece — o valor
  #    vem do JS, INLINE, no próprio cartão: `Be = ge ? `${125-progresso}%` :
  #    "100%"`, gravado em `style={{"--installing-effect": Be}}`. Estilo inline
  #    num ancestral mais próximo vence a nossa linha no `body`, sempre. Ou
  #    seja: esta linha nunca muda um pixel hoje. Fica como guarda — se uma
  #    versão futura deixar de gravar inline, o cinza continua sendo o de
  #    fábrica em vez de a propriedade morrer.
  "--installing-effect|100%"
)

# A paleta inteira num vetor, lida UMA vez por passagem. 4 flavors x 26 cores =
# 104 entradas; sem isto seriam 56 chamadas de `python3` por conferência (uma
# por arquivo do acervo), e o `meow doctor` roda esta conferência toda vez.
declare -A _HEROIC_PAL=()
_heroic_paleta_carregar() {
  [ "${#_HEROIC_PAL[@]}" -gt 0 ] && return 0
  [ -f "$_HEROIC_PALETA" ] || return 1
  local nome hex
  while IFS='=' read -r nome hex; do
    [ -n "$nome" ] && _HEROIC_PAL["$nome"]="$hex"
  done < <(python3 - "$_HEROIC_PALETA" <<'PY'
import json, sys, io
with io.open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
for flavor, cores in d.get("flavors", {}).items():
    for nome, hexa in cores.items():
        sys.stdout.write("%s.%s=%s\n" % (flavor, nome, hexa.lower()))
PY
)
  [ "${#_HEROIC_PAL[@]}" -gt 0 ]
}

# Resolve UMA receita da tabela no flavor e no accent do arquivo.
_heroic_cor() {   # <flavor> <accent> <receita>
  local flavor="$1" acento="$2" r="$3" alfa="" hex
  case "$r" in
    @*) ;;
    *)  printf '%s' "$r"; return 0 ;;
  esac
  r="${r#@}"
  case "$r" in *+*) alfa="${r#*+}"; r="${r%%+*}" ;; esac
  [ "$r" = "accent" ] && r="$acento"
  hex="${_HEROIC_PAL[$flavor.$r]:-}"
  [ -n "$hex" ] || return 1
  printf '%s%s' "$hex" "$alfa"
}

# O bloco que vai no fim do arquivo instalado, com o seletor DAQUELE arquivo.
_heroic_bloco() {   # <flavor> <accent>
  local flavor="$1" acento="$2" item nome receita valor
  _heroic_paleta_carregar || return 1
  printf '%s\n' "/* MeowSystem — as cores que o Heroic 2.22.1 usa e o acervo de maio/2025 não define."
  printf '%s\n' "   Medido no app.asar da versão instalada; a tabela mora no manifesto.sh. */"
  printf 'body.catppuccin-%s-%s {\n' "$flavor" "$acento"
  for item in "${_HEROIC_REMENDO[@]}"; do
    nome="${item%%|*}"; receita="${item#*|}"
    valor="$(_heroic_cor "$flavor" "$acento" "$receita")" || return 1
    printf '  %s: %s;\n' "$nome" "$valor"
  done
  printf '%s' "}"
}

# O TEXTO INTEIRO de um tema instalado: o CSS do upstream mais o nosso bloco.
# É esta função — e não o arquivo do acervo — que o `conferir` compara com o
# disco e que o `aplicar` grava.
_heroic_css() {   # <arquivo do acervo>
  local arq="$1" base flavor acento bloco
  base="$(basename "$arq" .css)"          # catppuccin-<flavor>-<accent>
  flavor="${base#catppuccin-}"; acento="${flavor#*-}"; flavor="${flavor%%-*}"
  bloco="$(_heroic_bloco "$flavor" "$acento")" || return 1
  printf '%s\n\n%s' "$(cat "$arq")" "$bloco"
}

# A raiz de configuração: flatpak primeiro, porque é como ela tem.
_heroic_conf_dir() {
  local f="$HOME/.var/app/$_HEROIC_APPID/config/heroic"
  [ -d "$f" ] && { printf '%s' "$f"; return 0; }
  [ -d "$HOME/.config/heroic" ] && { printf '%s' "$HOME/.config/heroic"; return 0; }
  return 1
}

_heroic_presente() {
  meow_flatpak_tem "$_HEROIC_APPID" && return 0
  meow_tem heroic && return 0
  return 1
}

# `flatpak ps`, E NUNCA `pgrep -f` — 08/09/2026, medido no primeiro teste.
#   `pgrep -f com.heroicgameslauncher.hgl` casou com o PRÓPRIO comando que
#   estava perguntando: a linha de comando do shell que roda o módulo contém o
#   id do app, e o `-f` compara a linha inteira. O módulo se recusou a aplicar
#   dizendo "o Heroic está aberto" numa máquina com o Heroic fechado — e teria
#   feito isso para sempre, calado, porque a recusa é um "pendente" e não um
#   erro. `flatpak ps` responde pelo id exato, uma linha por app rodando.
_heroic_rodando() {
  if meow_tem flatpak; then
    flatpak ps --columns=application 2>/dev/null | grep -qx -- "$_HEROIC_APPID" && return 0
  fi
  pgrep -x heroic >/dev/null 2>&1 && return 0
  return 1
}

# Devolve o JSON inteiro, já com a chave posta. Sem escrever nada: quem escreve
# é a `meow_escrever`, que compara por conteúdo e não toca no arquivo à toa.
_heroic_json_com() {
  local arquivo="$1" caminho="$2" valor="$3" recuo="$4"
  python3 - "$arquivo" "$caminho" "$valor" "$recuo" <<'PY'
import json, sys, io
arquivo, caminho, valor, recuo = sys.argv[1:5]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except FileNotFoundError:
    d = {}
except ValueError:
    sys.exit(2)          # JSON quebrado: quem conserta é ela, não nós
if not isinstance(d, dict):
    sys.exit(2)
partes = caminho.split(".")
alvo = d
for p in partes[:-1]:
    if not isinstance(alvo.get(p), dict):
        alvo[p] = {}
    alvo = alvo[p]
if valor == "":
    alvo.pop(partes[-1], None)
else:
    alvo[partes[-1]] = valor
sys.stdout.write(json.dumps(d, indent=("\t" if recuo == "tab" else 2), ensure_ascii=False))
PY
}

# Regra 4: antes de sobrescrever, sempre. Mesmo carimbo e mesmo formato dos
# outros módulos — a pasta `backups/` é compartilhada, e um carimbo com dois
# pontos ordenaria antes de todos os com hífen (ver o helper 3 do módulo do VS
# Code, que documenta a medição).
_heroic_backup() {
  local origem="$1" carimbo destino rel
  [ -f "$origem" ] || return 0
  carimbo="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_ESTADO/backups/$carimbo"
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  mkdir -p "$destino/$(dirname "$rel")" || return 1
  cp -p -- "$origem" "$destino/$rel" || return 1
  ( cd "$destino" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  printf '%s\n' "$origem" >> "$destino/origens.txt" || return 1
  meow_info "backup: $destino/$rel"
  return 0
}

_heroic_json_le() {
  local arquivo="$1" caminho="$2"
  python3 - "$arquivo" "$caminho" <<'PY'
import json, sys, io
arquivo, caminho = sys.argv[1:3]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(1)
for p in caminho.split("."):
    if not isinstance(d, dict) or p not in d:
        sys.exit(1)
    d = d[p]
sys.stdout.write(d if isinstance(d, str) else json.dumps(d))
PY
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_detectar — 0 presente, 3 ausente.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_detectar() {
  _heroic_presente || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic instalado, mas ainda não abriu uma vez — sem pasta de configuração"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_ok "Heroic presente, configuração em $dir"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_conferir — 0 aplicado, 1 divergente, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_conferir() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir tema pasta divergiu=0 falta=0 f alvo
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  # COMPARA COMO A `meow_escrever` ESCREVE, E NÃO COM `cmp` — 08/09/2026.
  #   `cmp` acusou 56 de 56 diferentes num diretório com os 56 arquivos certos.
  #   A causa é a regra 5 do contrato: `meow_escrever` grava com `printf '%s'`,
  #   sem a quebra de linha final, e compara por conteúdo do mesmo jeito. Os
  #   arquivos do upstream TÊM a quebra final. Byte a byte eles diferem sempre;
  #   pela régua que os escreveu, são iguais — e é essa a régua que vale, senão
  #   o módulo reescreve os 56 a cada passagem e nunca diz "conforme".
  #
  #   O que se compara é o TEXTO COMPOSTO (upstream + o nosso bloco), e não o
  #   arquivo do acervo: desde 09/09/2026 o que vai para o disco dela é a soma
  #   dos dois. O `SHA256SUMS` continua sendo a conferência da cópia do upstream
  #   NO REPOSITÓRIO — são duas perguntas diferentes.
  for f in "$_HEROIC_ORIGEM"/*.css; do
    alvo="$(_heroic_css "$f")" || {
      meow_erro "não consegui ler $_HEROIC_PALETA — sem fonte de cor, não dá para compor o tema"
      return "$MEOW_ERRO"
    }
    [ "$alvo" = "$(cat "$pasta/$(basename "$f")" 2>/dev/null)" ] || falta=$((falta + 1))
  done
  [ "$falta" = "0" ] || { meow_muda "$falta dos 56 temas não estão em $pasta"; divergiu=1; }

  [ "$(_heroic_json_le "$dir/config.json" defaultSettings.customThemesPath)" = "$pasta" ] \
    || { meow_muda "customThemesPath não aponta para $pasta"; divergiu=1; }
  [ "$(_heroic_json_le "$dir/store/config.json" theme)" = "$tema" ] \
    || { meow_muda "o tema escolhido não é $tema"; divergiu=1; }

  if [ "$divergiu" = "0" ]; then
    meow_ok "Heroic com $tema aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_aplicar — 0 nada a fazer, 1 aplicou, 2 erro, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_aplicar() {
  _heroic_presente || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir tema pasta mudou=0 rc f conteudo
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic ainda não abriu uma vez — nada para configurar"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "Heroic já está no nosso tema — nada a fazer"
    return "$MEOW_OK"
  }

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — ele reescreve a configuração ao sair; feche e rode de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  # 1. os 56 CSS, cada um com o remendo de variáveis colado no fim.
  #    `meow_escrever` compara por conteúdo: numa máquina já pronta isto não
  #    escreve um byte, que é a regra 5 do contrato.
  for f in "$_HEROIC_ORIGEM"/*.css; do
    conteudo="$(_heroic_css "$f")" || {
      meow_erro "não consegui ler $_HEROIC_PALETA — sem fonte de cor, não dá para compor o tema"
      return "$MEOW_ERRO"
    }
    meow_escrever "$pasta/$(basename "$f")" "$conteudo"
    rc=$?
    [ "$rc" = "1" ] && mudou=1
    [ "$rc" -ge 2 ] && return "$MEOW_ERRO"
  done

  # 2. a pasta, no arquivo do backend.
  local novo
  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "$pasta" espaco)" \
    || { meow_erro "não consegui ler $dir/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  # 3. o tema escolhido, no arquivo do front.
  novo="$(_heroic_json_com "$dir/store/config.json" theme "$tema" tab)" \
    || { meow_erro "não consegui ler $dir/store/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/store/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  if [ "$mudou" = "1" ]; then
    meow_ok "Heroic vestido de $tema — a janela mostra na próxima vez que abrir"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "Heroic já está no nosso tema"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_reverter — devolve o tema de fábrica e leva os nossos CSS embora.
# ─────────────────────────────────────────────────────────────────────────────
#   `midnightMirage` é o padrão do Heroic, escrito no próprio código
#   (`ContextProvider.tsx`: `theme: 'midnightMirage'`) — não é um chute nosso.
#   O `customThemesPath` volta a não existir, e não a existir vazio: chave vazia
#   é uma decisão escrita, e aqui a decisão é não ter opinião.
meow_app_reverter() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir pasta mudou=0 rc novo f
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  pasta="$dir/themes"

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — feche e rode de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/store/config.json" theme midnightMirage tab)" || return "$MEOW_ERRO"
  meow_escrever "$dir/store/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "" espaco)" || return "$MEOW_ERRO"
  meow_escrever "$dir/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1

  # Só os NOSSOS arquivos saem, e um a um pelo nome do acervo: a pasta pode ter
  # um tema que ela mesma pôs lá, e apagar a pasta inteira levaria o dela junto.
  if ! meow_seco; then
    for f in "$_HEROIC_ORIGEM"/*.css; do
      [ -f "$pasta/$(basename "$f")" ] || continue
      rm -f -- "$pasta/$(basename "$f")" && mudou=1
    done
    rmdir "$pasta" 2>/dev/null || true
  fi

  [ "$mudou" = "1" ] && { meow_ok "Heroic de volta ao midnightMirage"; return "$MEOW_DIVERGENTE"; }
  meow_ok "Heroic já estava de fábrica"
  return "$MEOW_OK"
}
