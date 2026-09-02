#!/usr/bin/env bash
# terminal.sh — a paleta ANSI do `cosmic-term`, que era a única peça da tela
# dela que continuava de fábrica.
#
# ELA TEM CATPPUCCIN EM TUDO, MENOS ONDE DIGITA
#   VS Code, Obsidian, btop, bat, qBittorrent e Spotify já estão vestidos. O
#   terminal — a janela onde ela passa o dia — não. Medido em 25/08/2026:
#   `~/.config/cosmic/com.system76.CosmicTerm/v1/` tinha OITO arquivos
#   (`focus_follow_mouse`, `font_name`, `font_size`,
#   `font_size_zoom_step_mul_100`, `opacity`, `shortcuts_custom`,
#   `tab_new_inherit_working_directory`, `use_bright_bold`) e NENHUM deles é
#   cor. Sem `color_schemes_dark`, sem `color_schemes_light`: o vermelho do
#   `ls` era o `#F16161` embutido no binário, não o `#f38ba8` da paleta.
#
# ===========================================================================
# A ARMADILHA QUE DECIDE O DESENHO: O ARQUIVO DE IMPORTAÇÃO NÃO É O ARQUIVO
# DE CONFIGURAÇÃO. SÃO DOIS FORMATOS DIFERENTES.
# ===========================================================================
#   O README do port oficial (`catppuccin/cosmic-desktop`, pasta
#   `assets/temas/cosmic-term/`) manda importar pela GUI — View → Color schemes… →
#   Import — e os quatro `.ron` de lá são UM `ColorScheme` solto:
#
#       (
#           name: "Catppuccin Mocha",
#           foreground: "#cdd6f4",
#           ...
#       )
#
#   Copiar esse arquivo por cima de `color_schemes_dark` NÃO funciona, e o
#   modo de falha é silencioso. O `Config` do cosmic-term 1.6.0 declara
#   (`src/config.rs`, commit `032a107`, o mesmo que gerou o binário desta
#   máquina — conferido no `apt-get source --print-uris`):
#
#       pub color_schemes_dark:  BTreeMap<ColorSchemeId, ColorScheme>,
#       pub color_schemes_light: BTreeMap<ColorSchemeId, ColorScheme>,
#
#   com `#[serde(transparent)] pub struct ColorSchemeId(pub u64)`. Ou seja: o
#   arquivo no disco é um MAPA de inteiro para struct —
#
#       {
#           0: (
#               name: "Catppuccin Mocha",
#               ...
#           ),
#       }
#
#   — e o `.ron` do port é só o MIOLO de uma entrada desse mapa. O que a GUI
#   faz no Import é exatamente isto: `ron::de::from_reader::<ColorScheme>` do
#   arquivo escolhido e `insert(id, color_scheme)` no mapa
#   (`src/main.rs`, `Message::ColorSchemeImportResult`).
#
#   Por isso este script NÃO baixa o port: ele reproduz o port a partir de
#   `assets/paleta/catppuccin.json`, que é a fonte de cor deste projeto, e faz o
#   `insert` que a GUI faria.
#
# O PORT OFICIAL SAI INTEIRO DA NOSSA PALETA — E ISSO FOI CONFERIDO, NÃO SUPOSTO
#   Os quatro arquivos de `assets/temas/cosmic-term/` foram baixados em 25/08/2026 e
#   comparados campo a campo com o que a regra abaixo deriva de
#   `assets/paleta/catppuccin.json`. Os QUATRO bateram: mocha, latte, frappé e
#   macchiato, todos os 29 hex de cada um. A regra é:
#
#       foreground = text          cursor            = rosewater
#       bright_foreground = text   dim_foreground    = overlay0
#       normal  = surface1, red, green, yellow, blue, PINK, TEAL, subtext1
#       bright  = surface2, (as mesmas seis), subtext0
#       dim     = idêntico a normal
#
#   Duas trocas nessa linha merecem a maiúscula, porque são o oposto do que se
#   chutaria: o MAGENTA do ANSI é o `pink` do Catppuccin (não o `mauve`), e o
#   CYAN é o `teal` (não o `sky`).
#
#   E no LATTE o par claro/escuro se inverte, como manda um tema claro:
#   `normal.black` é `subtext1` (não `surface1`), `normal.white` é `surface2`,
#   `bright.black` é `subtext0` e `bright.white` é `surface1`.
#
# O CAMPO `background` ESTÁ AUSENTE DE PROPÓSITO, E ISSO PROTEGE O `opacity: 96`
#   Nenhum dos quatro arquivos do port oficial tem `background:` — `grep -c
#   background` devolveu 0 nos quatro. Não é esquecimento. O `ColorScheme` tem
#   o campo como `Option<HexColor>` com `skip_serializing_if`, e o
#   `terminal_theme.rs` do upstream comenta a linha equivalente no tema
#   embutido com todas as letras:
#
#       // Background comes from theme settings:
#       // colors[NamedColor::Background] = colors[NamedColor::Black];
#
#   e o `terminal.rs` trata o `None` como "Allow using an unset background".
#   Traduzindo: sem `background`, o fundo continua vindo do tema COSMIC dela e
#   o `opacity: 96` continua valendo. Gravar `background: "#1e1e2e"` chumbaria
#   um fundo opaco por cima da transparência que ela escolheu. Este script
#   nunca escreve esse campo.
#
# ===========================================================================
# UM ESQUEMA INSTALADO E NÃO SELECIONADO NÃO MUDA UM PIXEL
# ===========================================================================
#   Este é o modo de falha mais provável da sprint, e o nome da chave não é
#   `color_scheme_*` coisa nenhuma. É:
#
#       syntax_theme_dark    (String)   padrão de fábrica: "COSMIC Dark"
#       syntax_theme_light   (String)   padrão de fábrica: "COSMIC Light"
#
#   Achados no binário (`strings /usr/bin/cosmic-term | grep syntax_theme`) e
#   confirmados na lista de campos do `Config`. A seleção é por NOME, casada
#   contra o `name` de dentro do `ColorScheme` — e o `main.rs` tem um
#   `.or_else()` que cai calado no tema embutido quando o nome não existe:
#
#       self.themes.get(&self.config.syntax_theme(kind, profile))
#           .or_else(|| self.themes.get(&(COSMIC_THEME_DARK.to_string(), Dark)))
#
#   Ou seja: nome errado por um acento = tela idêntica à de antes, sem erro,
#   sem log, sem nada. Por isso o nome do esquema e o valor de `syntax_theme_*`
#   saem da MESMA função aqui dentro (`_nome_esquema`), e não de duas listas.
#
#   E A SELEÇÃO TEM DONO COMPARTILHADO — ver `_slot_por`. Esta chave é o que o
#   seletor de Ajustes → Cores do cosmic-term escreve, então ela só é escrita
#   quando está vazia, de fábrica ou já nossa. A lição é de 17/08/2026, quando
#   o `vidro.sh` perdeu a chave `opacity` por reimpor todo dia a escolha da
#   GUI dela.
#
#   O acento importa: o flavor `frappe` da paleta vira `"Catppuccin Frappé"` no
#   nome, com É, porque é assim que o port oficial escreve.
#
# POR QUE OS DOIS SLOTS, E NÃO SÓ O ESCURO
#   O `app_theme` do cosmic-term nasce `System`, e o `color_scheme_kind()`
#   escolhe o mapa `dark` ou `light` conforme o tema do sistema. Com
#   `MODO="auto"` no meow.conf — ou no dia em que ela clicar em claro — só o
#   slot escuro vestido devolveria o terminal ao "COSMIC Light" de fábrica no
#   meio do dia. Escrever os dois custa quatro arquivos e fecha o buraco.
#
#   O flavor claro NÃO é escolha: `assets/paleta/catppuccin.json` grava
#   `"claros": ["latte"]` — o Catppuccin tem exatamente UM flavor claro. O
#   slot claro é sempre o Latte, e o slot escuro é o `FLAVOR` do meow.conf
#   (ou mocha, se `FLAVOR` for latte).
#
# ===========================================================================
# O ACCENT: A ÚNICA COISA AQUI QUE É GOSTO, E ONDE ELA DESLIGA
# ===========================================================================
#   O port oficial não usa `mauve` em lugar nenhum — o `#CBA6F7` dela não
#   aparece em nenhum dos 29 hex do `catppuccin-mocha.ron`. O magenta do ANSI
#   é `pink` e o cursor é `rosewater`.
#
#   Como `ACCENT` é chave do meow.conf e o mauve é a assinatura dela na
#   máquina inteira, o accent entra no CURSOR — o único campo que o port
#   escolhe por conta própria e o único ponto "aceso" permanente da janela.
#   Com `ACCENT="mauve"` e `FLAVOR="mocha"`, o cursor vira `#CBA6F7`.
#
#   Isto é desvio do upstream, e portanto tem botão:
#
#       TERMINAL_CURSOR="port"   -> cursor = rosewater, idêntico ao oficial
#       TERMINAL_CURSOR="accent" -> cursor = ACCENT     (padrão)
#
# ===========================================================================
# TRÊS MEDIÇÕES QUE ECONOMIZAM UM DIA CADA
# ===========================================================================
#   1. VALE NA HORA, SEM REINICIAR NADA. Lendo
#      `/proc/<pid do cosmic-term>/fdinfo/*` em 25/08/2026, ele mantém
#      EXATAMENTE UM watch de inotify, e o inode resolve para
#      `~/.config/cosmic/com.system76.CosmicTerm/v1`. O `Message::Config` do
#      `main.rs` chama `update_config()` -> `update_color_schemes()` -> aplica
#      em todas as abas abertas. Não é preciso fechar janela, nem reiniciar
#      app, nem tocar no `cosmic-panel` (que aliás é da Aurora).
#
#   2. O `\n` FINAL É UMA ARMADILHA DE IDEMPOTÊNCIA, E ELA FOI PROVADA.
#      O `ron::ser::to_string_pretty` fecha o mapa com `}\n` — o
#      `shortcuts_custom` dela termina em `7d 0a`, conferido no `xxd`. Só que
#      o `meow_escrever` compara com `[ "$conteudo" = "$(cat "$destino")" ]`,
#      e `$( )` COME o `\n` final. Medido:
#
#          conteúdo COM \n final  -> rc=1, rc=1, rc=1 ... para sempre
#          conteúdo SEM \n final  -> rc=0 (e não reescreve, nem contra um
#                                    arquivo que TEM o \n)
#
#      Um módulo que devolve 1 toda vez faz o `meow-doctor.timer` das 5h
#      pendurar "o auto-reparo corrigiu" na TV dela todo dia sem ter
#      corrigido nada. Por isso tudo aqui é gerado SEM `\n` final. O RON
#      ignora espaço no fim, e o cosmic-term repõe o dele quando reescrever.
#
#   2b. O HEX É MAIÚSCULO, E ISSO NÃO É ESTILO — É A SEGUNDA ARMADILHA DE
#      IDEMPOTÊNCIA, E A MAIS DIFÍCIL DE ADIVINHAR.
#      Para provar que este arquivo é aceito eu compilei um validador de 80
#      linhas com os structs COPIADOS de `src/config.rs` e as mesmas versões
#      de `ron` (0.12.2) e `hex_color` (3.0.0) do `Cargo.lock` do commit. Ele
#      desserializa o nosso arquivo e reserializa. O resultado:
#
#          PARSE OK: 1 esquema(s)
#          id 0 = "Catppuccin Mocha"  cursor=#CBA6F7  background=None
#
#      e a reserialização voltou com TODOS os hex em MAIÚSCULA — o `Serialize`
#      do `hex_color` imprime `#CDD6F4`, nunca `#cdd6f4`. O port oficial do
#      Catppuccin está em minúscula, e o `HexColor` aceita as duas na leitura,
#      então nada quebra.
#
#      O que quebraria é pior que quebrar: a GUI reescreve o mapa INTEIRO
#      (`save_color_schemes` -> `config_handler.set("color_schemes_dark", ...)`)
#      a cada importação, renomeação ou exclusão de qualquer esquema. Bastava
#      ela mexer numa dessas para o NOSSO trecho voltar em maiúscula, e a
#      passagem seguinte deste script o reescreveria em minúscula: dois
#      programas empurrando o mesmo arquivo em direções opostas, para sempre,
#      com o doctor gritando "consertado" toda madrugada. Escrevendo em
#      maiúscula, o que a GUI grava é BYTE A BYTE o que gravamos, e ninguém
#      empurra nada.
#
#      A paleta já guarda os hex em maiúscula; quem os abaixava era o python
#      daqui. Agora ele os sobe.
#
#   3. O FORMATO EXATO SAIU DE UM ARQUIVO QUE O PRÓPRIO APP ESCREVEU.
#      O `cosmic-config` grava com `ron::ser::to_string_pretty(&value,
#      PrettyConfig::new())` (`cosmic-config/src/lib.rs:459`), e o
#      `shortcuts_custom` dela é a amostra: indentação de 4 espaços por nível,
#      `\n` (nunca `\r\n`), vírgula depois do ÚLTIMO membro, e `(` sem nome de
#      struct na frente. É esse layout que `_entrada_ron` reproduz.
#
# ===========================================================================
# O QUE ESTE SCRIPT NÃO TOCA, NUNCA
# ===========================================================================
#   `font_name`, `font_size`, `font_size_zoom_step_mul_100`, `opacity`,
#   `use_bright_bold`, `focus_follow_mouse`, `shortcuts_custom` e
#   `tab_new_inherit_working_directory` são DELA. O `opacity: 96` está no
#   ponto e a fonte é a JetBrainsMono Nerd Font Mono que o
#   `instalar_fontes.sh` instalou. Este módulo escreve QUATRO arquivos e mais
#   nenhum:
#
#       color_schemes_dark   color_schemes_light
#       syntax_theme_dark    syntax_theme_light
#
#   E dentro dos dois mapas ele mexe em UMA entrada — a que tem o nome dele.
#   Qualquer outro esquema que ela tenha importado pela GUI atravessa este
#   script byte a byte, verbatim, inclusive a formatação. Se o mapa não puder
#   ser lido, o script RECUSA escrever e sai 2: melhor um erro alto que um
#   arquivo dela reescrito por um parser que não entendeu o que leu.
#
# DESLIGAR TEM DE DESLIGAR
#   `remover` (ou `TERMINAL_ESQUEMA="nao"` no meow.conf) tira a nossa entrada
#   dos dois mapas e devolve a seleção ao padrão de fábrica. Se o mapa ficar
#   vazio, o ARQUIVO é apagado — que é o mesmo que o `BTreeMap::new()` do
#   `Default`, e é o estado em que a máquina dela estava antes desta sprint.
#   O `syntax_theme_*` só é apagado se ainda estiver apontando para um nome
#   NOSSO; se ela trocou o esquema pela GUI depois, a escolha dela fica.
#
# USO
#   scripts/terminal.sh aplicar     instala o esquema e o seleciona (idempotente)
#   scripts/terminal.sh conferir    não escreve nada; 0 igual, 1 divergente,
#                                   3 sem cosmic-term / desligado no conf
#   scripts/terminal.sh remover     tira o nosso e volta ao de fábrica
#
#   Aliases `--aplicar`, `--conferir` e `--remover` existem para o `bin/meow`
#   chamar com a mesma cara dos módulos vizinhos.
#
#   FLAVOR="mocha"            slot escuro (mocha | frappe | macchiato; latte -> mocha)
#   ACCENT="mauve"            cor do cursor, quando TERMINAL_CURSOR="accent"
#   TERMINAL_ESQUEMA="sim"    "nao" desinstala
#   TERMINAL_CURSOR="accent"  "port" devolve o rosewater do port oficial
#   TERMINAL_DIR=...          override do diretório de config (existe para teste)
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

DIR="${TERMINAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicTerm/v1}"
PALETA="$RAIZ/assets/paleta/catppuccin.json"

ESQUEMA="${TERMINAL_ESQUEMA:-sim}"
_FLAVOR="${FLAVOR:-mocha}"
_ACCENT="${ACCENT:-mauve}"
_CURSOR="${TERMINAL_CURSOR:-accent}"

ACAO="aplicar"
case "${1:-}" in
  ''|aplicar|--aplicar)   ACAO="aplicar" ;;
  conferir|--conferir)    ACAO="conferir" ;;
  remover|--remover)      ACAO="remover" ;;
  -h|--help)
    printf 'uso: %s [aplicar|conferir|remover]\n\n' "$(basename "$0")"
    printf '  aplicar   instala o esquema Catppuccin no cosmic-term e o seleciona\n'
    printf '  conferir  não escreve nada (0 igual · 1 divergente · 3 sem dependência)\n'
    printf '  remover   tira o nosso esquema e volta ao de fábrica\n\n'
    printf 'conf: FLAVOR, ACCENT, TERMINAL_ESQUEMA, TERMINAL_CURSOR\n'
    exit 0 ;;
  *) meow_erro "opção desconhecida: '$1' — use aplicar, conferir ou remover"
     exit "$MEOW_ERRO" ;;
esac
# O `--conferir` do projeto é o seco visto de fora. Atribuir aqui funciona
# porque o `source` do comum.sh já passou (ver o cabeçalho de MEOW_SECO lá).
# shellcheck disable=SC2034  # quem lê MEOW_SECO é o meow_seco() do comum.sh
[ "$ACAO" = "conferir" ] && MEOW_SECO=1
# `MEOW_DRY_RUN=1 terminal.sh` (a forma que os `chk_` vizinhos usam) também
# tem de virar conferência, e nunca uma remoção de verdade.
meow_seco && [ "$ACAO" = "aplicar" ] && ACAO="conferir"

# --- os nomes, e por que eles são a chave de tudo ---------------------------
# O nome é a IDENTIDADE da nossa entrada dentro do mapa (é por ele que o
# `remover` acha o que apagar) E é o valor que vai para `syntax_theme_*`. Uma
# função só para os dois usos: duas listas discordariam no dia em que alguém
# corrigisse o acento de "Frappé" em uma delas.
_nome_esquema() {
  case "$1" in
    mocha)     printf 'Catppuccin Mocha' ;;
    latte)     printf 'Catppuccin Latte' ;;
    frappe)    printf 'Catppuccin Frappé' ;;
    macchiato) printf 'Catppuccin Macchiato' ;;
    *)         return 1 ;;
  esac
}

# Tudo o que este módulo pode ter escrito algum dia, em qualquer flavor. É o
# que o `remover` procura: se ela trocou o FLAVOR entre um `aplicar` e o
# `remover`, apagar só o flavor de agora deixaria o antigo para trás.
NOSSOS_NOMES='Catppuccin Mocha,Catppuccin Latte,Catppuccin Frappé,Catppuccin Macchiato'

# O slot escuro segue o FLAVOR; o claro é sempre o Latte, porque o Catppuccin
# tem um flavor claro só (`"claros": ["latte"]` na paleta).
case "$_FLAVOR" in
  latte) FLAVOR_ESCURO="mocha" ;;
  *)     FLAVOR_ESCURO="$_FLAVOR" ;;
esac
FLAVOR_CLARO="latte"

# --- o ajudante em python ---------------------------------------------------
# Bash não lê RON, e um `sed` sobre um mapa aninhado com strings dentro é o
# jeito mais rápido de picotar um arquivo dela. O python entra em três modos:
#
#   gerar <flavor> <nome> <cursor_hex|-->   imprime a entrada pronta
#   por   <arquivo> <nome>                  põe/substitui a nossa (ENTRADA=...)
#   tirar <arquivo>                         tira as nossas (NOSSOS=...)
#
# `por` e `tirar` imprimem o CONTEÚDO desejado do arquivo inteiro, ou a
# palavra `__VAZIO__` quando o mapa fica sem nenhuma entrada — e aí o
# chamador apaga o arquivo, que é o padrão de fábrica (`BTreeMap::new()`).
#
# O parser guarda o texto CRU de cada entrada que não é nossa e o devolve sem
# tocar: ele precisa saber onde uma entrada começa e termina, não o que tem
# dentro. Qualquer coisa que ele não entenda vira erro e ninguém escreve nada.
_py() {
  PALETA="$PALETA" python3 - "$@" <<'PY'
import json, os, re, sys

modo = sys.argv[1]


def esc(s):
    # RON aceita as mesmas fugas de string do JSON; ensure_ascii=False mantém
    # o "é" de Frappé como UTF-8, que é como o port oficial o escreve.
    return json.dumps(s, ensure_ascii=False)


# ---------------------------------------------------------------- gerar
def gerar(flavor, nome, cursor_hex):
    pal = json.load(open(os.environ["PALETA"]))
    claros = set(pal.get("claros", ["latte"]))
    try:
        # MAIÚSCULA, E ISSO NÃO É ESTILO — ver o bloco "O HEX É MAIÚSCULO"
        # no cabeçalho deste arquivo.
        p = {k: v.upper() for k, v in pal["flavors"][flavor].items()}
    except KeyError:
        sys.stderr.write("flavor desconhecido na paleta: %s\n" % flavor)
        sys.exit(2)

    if flavor in claros:
        n_black, n_white = p["subtext1"], p["surface2"]
        b_black, b_white = p["subtext0"], p["surface1"]
    else:
        n_black, n_white = p["surface1"], p["subtext1"]
        b_black, b_white = p["surface2"], p["subtext0"]

    cursor = cursor_hex if cursor_hex != "--" else p["rosewater"]

    # magenta = pink e cyan = teal. Não é engano: é o que o port oficial faz,
    # e foi conferido contra os quatro arquivos dele.
    meio = [p["red"], p["green"], p["yellow"], p["blue"], p["pink"], p["teal"]]
    normal = [n_black] + meio + [n_white]
    bright = [b_black] + meio + [b_white]
    nomes = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]

    def ansi(campo, cores, ind):
        L = ["%s%s: (" % (" " * ind, campo)]
        for k, v in zip(nomes, cores):
            L.append('%s%s: "%s",' % (" " * (ind + 4), k, v))
        L.append("%s)," % (" " * ind))
        return L

    # A ORDEM DOS CAMPOS É A DA DECLARAÇÃO DO STRUCT em src/config.rs, e
    # `background` não entra — ver o cabeçalho deste arquivo.
    L = ["("]
    L.append("        name: %s," % esc(nome))
    L.append('        foreground: "%s",' % p["text"])
    L.append('        cursor: "%s",' % cursor)
    L.append('        bright_foreground: "%s",' % p["text"])
    L.append('        dim_foreground: "%s",' % p["overlay0"])
    L += ansi("normal", normal, 8)
    L += ansi("bright", bright, 8)
    L += ansi("dim", normal, 8)          # o port repete o normal no dim
    L.append("    )")
    sys.stdout.write("\n".join(L))


# ---------------------------------------------------------------- ler o mapa
class Erro(Exception):
    pass


def ler_mapa(txt):
    n = len(txt)

    def ws(i):
        while i < n and txt[i] in " \t\r\n":
            i += 1
        return i

    def valor(i):
        prof = 0
        while i < n:
            c = txt[i]
            if c == '"':
                i += 1
                while i < n:
                    if txt[i] == "\\":
                        i += 2
                        continue
                    if txt[i] == '"':
                        i += 1
                        break
                    i += 1
                else:
                    raise Erro("string sem fechamento")
                continue
            if c in "([{":
                prof += 1
                i += 1
                continue
            if c in ")]}":
                if prof == 0:
                    return i          # escalar solto: acabou no fecha do mapa
                prof -= 1
                i += 1
                if prof == 0:
                    return i
                continue
            if prof == 0 and c == ",":
                return i              # escalar solto
            i += 1
        raise Erro("valor sem fechamento")

    i = ws(0)
    if i >= n or txt[i] != "{":
        raise Erro("não começa com '{'")
    i += 1
    itens = []
    while True:
        i = ws(i)
        if i >= n:
            raise Erro("faltou o '}' final")
        if txt[i] == "}":
            i += 1
            break
        j = txt.find(":", i)
        if j < 0:
            raise Erro("entrada sem ':'")
        chave = txt[i:j].strip()
        if not chave.isdigit():
            raise Erro("chave não numérica: %r" % chave)
        j = ws(j + 1)
        fim = valor(j)
        itens.append([int(chave), txt[j:fim]])
        i = ws(fim)
        if i < n and txt[i] == ",":
            i += 1
    if ws(i) != n:
        raise Erro("sobrou texto depois do '}'")
    return itens


def nome_de(cru):
    m = re.search(r'name:\s*"((?:[^"\\]|\\.)*)"', cru)
    if not m:
        return None
    return json.loads('"%s"' % m.group(1))


def carregar(caminho):
    if not os.path.exists(caminho):
        return []
    txt = open(caminho, encoding="utf-8").read()
    if not txt.strip():
        return []
    try:
        return ler_mapa(txt)
    except Erro as e:
        sys.stderr.write("não entendi %s: %s\n" % (caminho, e))
        sys.exit(2)


def emitir(itens):
    if not itens:
        sys.stdout.write("__VAZIO__")
        return
    L = ["{"]
    for chave, cru in sorted(itens, key=lambda x: x[0]):
        L.append("    %d: %s," % (chave, cru))
    L.append("}")
    sys.stdout.write("\n".join(L))


# ---------------------------------------------------------------- por / tirar
if modo == "gerar":
    gerar(sys.argv[2], sys.argv[3], sys.argv[4])
elif modo == "por":
    caminho, nome = sys.argv[2], sys.argv[3]
    entrada = os.environ["ENTRADA"]
    itens = carregar(caminho)
    for it in itens:
        if nome_de(it[1]) == nome:
            it[1] = entrada
            break
    else:
        # O MESMO CRITÉRIO DA GUI: `last_key_value().map(|(id,_)| id+1)`, com
        # `unwrap_or_default()` = 0 no mapa vazio. Assim a nossa entrada nunca
        # cai em cima de uma dela, e a próxima importação pela GUI continua
        # ganhando um id livre.
        prox = max((c for c, _ in itens), default=-1) + 1
        itens.append([prox, entrada])
    emitir(itens)
elif modo == "tirar":
    nossos = set(os.environ.get("NOSSOS", "").split(","))
    itens = [it for it in carregar(sys.argv[2]) if nome_de(it[1]) not in nossos]
    emitir(itens)
else:
    sys.stderr.write("modo inválido: %s\n" % modo)
    sys.exit(2)
PY
}

# --- o hex do accent --------------------------------------------------------
# A tradução nome-da-paleta -> hex mora aqui pelo mesmo motivo do `midia.sh`:
# a paleta é do MeowSystem, e uma segunda cópia dos hex é uma segunda verdade.
_hex_accent() {
  python3 -c '
import json, sys
try:
    p = json.load(open(sys.argv[1]))["flavors"][sys.argv[2]]
except Exception:
    sys.exit(1)
v = p.get(sys.argv[3])
if not isinstance(v, str) or not v.startswith("#"):
    sys.exit(1)
print(v.upper())
' "$PALETA" "$1" "$_ACCENT" 2>/dev/null
}

# --- pré-requisitos ---------------------------------------------------------
_pronto() {
  if ! meow_tem cosmic-term; then
    meow_pula "cosmic-term não está instalado — nada a vestir"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! meow_tem python3; then
    meow_aviso "python3 não encontrado — é ele quem lê o mapa RON sem estragá-lo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$PALETA" ]; then
    meow_erro "paleta ausente: $PALETA"
    return "$MEOW_ERRO"
  fi
  if ! _nome_esquema "$FLAVOR_ESCURO" >/dev/null; then
    meow_aviso "FLAVOR=\"$_FLAVOR\" não é um flavor do Catppuccin — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_CURSOR" != "accent" ] && [ "$_CURSOR" != "port" ]; then
    meow_aviso "TERMINAL_CURSOR=\"$_CURSOR\" não existe (use accent ou port) — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$_CURSOR" = "accent" ] && [ -z "$(_hex_accent "$FLAVOR_ESCURO")" ]; then
    meow_aviso "ACCENT=\"$_ACCENT\" não existe na paleta — confira o meow.conf"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- escrever um arquivo do cosmic-config -----------------------------------
# BACKUP ANTES DE TODA SOBRESCRITA. O `meow_backup_sistema` guarda em
# `~/.local/state/meowsystem/backups/<carimbo>-sistema/<caminho absoluto>`, uma
# vez por passagem (o `MEOW_CARIMBO` é exportado pelo comum.sh), e não faz nada
# quando o arquivo ainda não existe. Sem o backup, NÃO escrevemos: um mapa de
# esquemas importados por ela vale mais que esta sprint.
_gravar() {
  local arq="$1" conteudo="$2"
  if [ -f "$arq" ] && ! meow_seco; then
    if ! meow_backup_sistema "$arq"; then
      meow_erro "não consegui guardar cópia de $arq — nada foi escrito"
      return "$MEOW_ERRO"
    fi
  fi
  meow_escrever "$arq" "$conteudo" 644
}

# Apaga uma chave = volta ao `Default` do cosmic-term. O arquivo vai para o
# backup antes, para que `meow desfazer` tenha de onde tirá-lo.
_apagar() {
  local arq="$1"
  [ -f "$arq" ] || return "$MEOW_OK"
  if meow_seco; then
    meow_muda "apagaria $arq"
    return "$MEOW_DIVERGENTE"
  fi
  meow_backup_sistema "$arq" || { meow_erro "não consegui guardar cópia de $arq"; return "$MEOW_ERRO"; }
  rm -f "$arq" || return "$MEOW_ERRO"
  return "$MEOW_DIVERGENTE"
}

# --- um slot (escuro ou claro) ----------------------------------------------
# $1 = dark|light   $2 = flavor
_slot_por() {
  local tipo="$1" flavor="$2"
  local mapa="$DIR/color_schemes_$tipo" sel="$DIR/syntax_theme_$tipo"
  local nome entrada desejado hex rc mudou=0

  nome="$(_nome_esquema "$flavor")" || return "$MEOW_ERRO"

  hex="--"
  if [ "$_CURSOR" = "accent" ]; then
    hex="$(_hex_accent "$flavor")"
    [ -n "$hex" ] || hex="--"
  fi

  entrada="$(_py gerar "$flavor" "$nome" "$hex")" || return "$MEOW_ERRO"
  desejado="$(ENTRADA="$entrada" _py por "$mapa" "$nome")" || {
    meow_erro "não escrevi nada em $mapa — o mapa de esquemas dela está num formato que eu não sei reescrever com segurança"
    return "$MEOW_ERRO"
  }
  [ "$desejado" = "__VAZIO__" ] && { meow_erro "o mapa desejado saiu vazio — isto é bug"; return "$MEOW_ERRO"; }

  _gravar "$mapa" "$desejado"; rc=$?
  case $rc in
    1) mudou=1 ;;
    2) meow_erro "não consegui escrever $mapa"; return "$MEOW_ERRO" ;;
  esac

  # A SELEÇÃO. Sem esta linha o esquema fica instalado e INVISÍVEL — é o modo
  # de falha mais provável desta sprint.
  #
  # MAS A ESCOLHA DELA VENCE, E ISSO É A LIÇÃO DA OPACIDADE DO PAINEL (17/08).
  #   O `syntax_theme_*` é exatamente o que o seletor de Ajustes → Cores do
  #   cosmic-term escreve. Reescrevê-lo em toda passagem faria o
  #   `meow-doctor.timer` desfazer, todo dia às 5h e sem dizer por quê, o
  #   esquema que ela tivesse escolhido na GUI — que foi o defeito que custou
  #   ao `vidro.sh` a chave `opacity` inteira.
  #
  #   Então só escrevemos quando o campo está VAZIO, no padrão de fábrica, ou
  #   já apontando para um nome nosso. Se ela escolheu outra coisa, avisamos
  #   alto (um esquema instalado e não selecionado é invisível, e o silêncio
  #   aqui seria pior que a divergência) e não mexemos.
  local atual=""
  if [ -f "$sel" ]; then
    atual="$(cat "$sel" 2>/dev/null)"
    atual="${atual#\"}"; atual="${atual%\"}"
  fi
  local podemos=0
  case "$atual" in
    ''|'COSMIC Dark'|'COSMIC Light') podemos=1 ;;
  esac
  case ",$NOSSOS_NOMES," in *",$atual,"*) podemos=1 ;; esac

  if [ "$podemos" = 1 ]; then
    _gravar "$sel" "\"$nome\""; rc=$?
    case $rc in
      1) mudou=1 ;;
      2) meow_erro "não consegui escrever $sel"; return "$MEOW_ERRO" ;;
    esac
  else
    meow_aviso "syntax_theme_$tipo está em \"$atual\", escolha sua — o $nome ficou"
    meow_aviso "instalado mas NÃO selecionado. Para usá-lo: cosmic-term, Ajustes → Cores."
  fi

  [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

_slot_tirar() {
  local tipo="$1"
  local mapa="$DIR/color_schemes_$tipo" sel="$DIR/syntax_theme_$tipo"
  local desejado rc mudou=0 atual

  if [ -f "$mapa" ]; then
    desejado="$(NOSSOS="$NOSSOS_NOMES" _py tirar "$mapa")" || {
      meow_erro "não removi nada de $mapa — formato que eu não sei reescrever com segurança"
      return "$MEOW_ERRO"
    }
    if [ "$desejado" = "__VAZIO__" ]; then
      _apagar "$mapa"; rc=$?
    else
      _gravar "$mapa" "$desejado"; rc=$?
    fi
    case $rc in
      1) mudou=1 ;;
      2) return "$MEOW_ERRO" ;;
    esac
  fi

  # A seleção só volta ao de fábrica se ainda estiver apontando para um nome
  # NOSSO. Se ela escolheu outro esquema pela GUI depois, a escolha é dela.
  if [ -f "$sel" ]; then
    atual="$(cat "$sel" 2>/dev/null)"
    atual="${atual#\"}"; atual="${atual%\"}"
    case ",$NOSSOS_NOMES," in
      *",$atual,"*)
        _apagar "$sel"; rc=$?
        case $rc in
          1) mudou=1 ;;
          2) return "$MEOW_ERRO" ;;
        esac ;;
      *)
        [ -n "$atual" ] && meow_pula "syntax_theme_$tipo está em \"$atual\" — escolha dela, fica" ;;
    esac
  fi

  [ "$mudou" = 1 ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}

# --- as ações ---------------------------------------------------------------
_aplicar() {
  local rc mudou=0
  _slot_por dark  "$FLAVOR_ESCURO"; rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1
  _slot_por light "$FLAVOR_CLARO";  rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1

  local qual
  qual="cursor $(_hex_accent "$FLAVOR_ESCURO")"
  [ "$_CURSOR" = "port" ] && qual="cursor do port oficial"

  if [ "$mudou" = 0 ]; then
    meow_ok "terminal já estava em $(_nome_esquema "$FLAVOR_ESCURO") / $(_nome_esquema "$FLAVOR_CLARO")"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    return "$MEOW_DIVERGENTE"
  fi
  meow_registrar "terminal esquema=$FLAVOR_ESCURO/$FLAVOR_CLARO cursor=$_CURSOR"
  meow_ok "terminal vestido: $(_nome_esquema "$FLAVOR_ESCURO") no escuro, $(_nome_esquema "$FLAVOR_CLARO") no claro ($qual)"
  meow_info "vale nas janelas já abertas — o cosmic-term vigia este diretório por inotify"
  return "$MEOW_DIVERGENTE"
}

_remover() {
  local rc mudou=0
  _slot_tirar dark;  rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1
  _slot_tirar light; rc=$?; [ "$rc" = 2 ] && return "$MEOW_ERRO"; [ "$rc" = 1 ] && mudou=1

  if [ "$mudou" = 0 ]; then
    meow_pula "não há esquema nosso no cosmic-term para remover"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  meow_registrar "terminal removido"
  meow_ok "terminal de volta à paleta de fábrica do cosmic-term"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?

  # `remover` pedido na mão vem ANTES da chave do conf: quem digitou "remover"
  # não quer ouvir sobre o TERMINAL_ESQUEMA, quer o terminal de volta.
  [ "$ACAO" = "remover" ] && { _remover; return $?; }

  if [ "$ESQUEMA" != "sim" ]; then
    # Desligar tem de DESLIGAR — a mesma lição do `midia.sh`. Deixar de
    # aplicar manteria de pé o que uma passagem anterior escreveu, e o sintoma
    # seria "desliguei e continua", que é o pior porque não há onde olhar.
    if grep -qF 'Catppuccin' "$DIR"/color_schemes_dark "$DIR"/color_schemes_light 2>/dev/null; then
      meow_muda "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf, mas o esquema nosso continua instalado"
      [ "$ACAO" = "conferir" ] && return "$MEOW_DIVERGENTE"
      _remover; return $?
    fi
    meow_pula "TERMINAL_ESQUEMA=\"$ESQUEMA\" no meow.conf — o terminal fica com a paleta de fábrica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  _aplicar   # `conferir` é `aplicar` em seco — o MEOW_SECO faz a diferença
}

main "$@"
exit $?
