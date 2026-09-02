#!/usr/bin/env bash
# assets/temas-de-apps/btop-bat/manifesto.sh — Catppuccin Mocha no btop e no bat.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`.
#
# DOIS APPS NUM MÓDULO SÓ, E POR QUÊ
#   Os dois são utilitários de terminal, os dois vêm do mesmo upstream
#   (catppuccin/<app>), e nenhum dos dois está instalado hoje. Separá-los daria
#   dois módulos que só sabem dizer "3". Juntos, o módulo tem uma regra clara:
#   cada app é conferido/aplicado de forma independente, e o veredito do módulo
#   é o pior veredito entre os apps PRESENTES. App ausente nunca é erro.
#
# ─────────────────────────────────────────────────────────────────────────────
# A ARMADILHA QUE MATA ESTE MÓDULO CALADO: NO UBUNTU, `bat` CHAMA-SE `batcat`
# ─────────────────────────────────────────────────────────────────────────────
#   MEDIDO, não suposto — `dpkg-deb -c bat_0.24.0-1build1_amd64.deb` nesta
#   máquina lista UM binário e ele é `./usr/bin/batcat`. O nome `bat` já é do
#   `bacula-console-qt`, e o Debian renomeou o nosso para não colidir.
#
#   Consequência: `command -v bat` continua FALHANDO depois de
#   `sudo apt install bat`. Um módulo que detectasse só por `bat` devolveria 3
#   para sempre, sem nunca dar erro — o pior tipo de bug, o que se parece com
#   "ainda não instalado". Por isso `_bb_bat_bin()` procura os dois nomes, nesta
#   ordem: `bat` primeiro (se ela um dia instalar pelo cargo/binário oficial,
#   esse é o de verdade), `batcat` depois.
#
#   O que o rename NÃO muda: o NOME do diretório de config continua "bat" mesmo
#   com o binário chamado `batcat`. O que muda — e o que a versão anterior deste
#   módulo errava — é ONDE esse diretório fica. MEDIDO com o bat 0.24.0 do apt:
#       bat --config-dir   = BAT_CONFIG_DIR > $XDG_CONFIG_HOME/bat > ~/.config/bat
#       bat --cache-dir    = BAT_CACHE_PATH > $XDG_CACHE_HOME/bat  > ~/.cache/bat
#       bat --config-file  = BAT_CONFIG_PATH > <config-dir>/config
#   Cravar `~/.config/bat` seria instalar o tema num diretório em que o bat nem
#   olha no dia em que ela exportar `XDG_CONFIG_HOME` — e o módulo juraria
#   "aplicado" com a tela dizendo o contrário. Por isso os três caminhos são
#   PERGUNTADOS AO BINÁRIO (`_bb_bat_cfg_dir` e companhia), com a cadeia acima
#   só como reserva para um bat velho demais para as flags.
#
#   NÃO criamos `alias bat=batcat`: o lugar disso seria o `~/.config/zsh`, que é
#   o repo Andromeda com auto-commit de 10 em 10 minutos — território proibido
#   (TRAVA 1 do comum.sh). Fica o aviso na tela, a decisão é dela.
#
# ─────────────────────────────────────────────────────────────────────────────
# COMO CADA APP DESCOBRE O TEMA (lido no código-fonte, não no README)
# ─────────────────────────────────────────────────────────────────────────────
# btop — `src/btop_theme.cpp` v1.3.0, que é a versão do apt aqui:
#     updateThemes()  varre `~/.config/btop/themes` e `/usr/share/btop/themes`
#                     e guarda os CAMINHOS COMPLETOS.
#     setTheme()      aceita três formas de casar:
#                        p == theme            (caminho absoluto)
#                        p.stem() == theme     ("catppuccin_mocha")
#                        p.filename() == theme ("catppuccin_mocha.theme")
#     Gravamos o STEM. Caminho absoluto também funcionaria, mas engessa o
#     `$HOME` dentro do arquivo de config — e o dia em que a home mudar de disco
#     (aqui os discos têm nome de deus grego e já trocaram de letra) o btop
#     voltaria calado para o tema Default.
#
#     O btop CRIA `~/.config/btop/themes` sozinho no arranque (btop.cpp, ~l.863).
#     Não dependemos disso: `mkdir -p` antes de escrever.
#
# bat — o nome que vai em `--theme` NÃO é o nome do arquivo: é o `<key>name</key>`
#     de dentro do plist. Conferido com `plistlib` no arquivo vendorizado:
#     "Catppuccin Mocha" (com espaço). O arquivo em si chama-se
#     "Catppuccin Mocha.tmTheme" — também com espaço, o que exige aspas em cada
#     expansão daqui para baixo. Mantivemos os nomes do upstream em vez de
#     higienizá-los porque a procedência (SHA256SUMS) vale mais que a comodidade.
#
#     E o tema só existe DEPOIS de `bat cache --build`, que compila
#     `<config-dir>/themes/*` em `<cache-dir>/themes.bin`. Sem esse passo o bat
#     ignora o `--theme` e cai no default, sem reclamar.
#
# ─────────────────────────────────────────────────────────────────────────────
# QUEM VENCE QUEM — as duas medições que mudaram este módulo
# ─────────────────────────────────────────────────────────────────────────────
#   1) A ÚLTIMA linha vence, nos DOIS apps. Medido:
#        bat  — config com `--theme="Catppuccin Mocha"` seguido de
#               `--theme="Dracula"` renderiza keyword em #ff79c6 (Dracula);
#               na ordem inversa, em #cba6f7 (Catppuccin).
#        btop — `btop.conf` com `color_theme` duas vezes (mocha, depois latte):
#               o btop carregou o LATTE e regravou o arquivo (244 linhas) com ele.
#      Consequência: procurar a chave com `grep` em QUALQUER linha e reescrever a
#      PRIMEIRA é o jeito de mentir. Se ela acrescentar `--theme="Dracula"` no fim
#      do config para experimentar, o módulo diria "já aplicado" para sempre e a
#      tela dela mostraria Dracula. Aqui só a ÚLTIMA ocorrência conta — é ela que
#      o conferir julga e é ela que o merge reescreve.
#
#   2) `BAT_THEME` no ambiente VENCE o arquivo de config. Medido igual: config
#      com `--theme="Catppuccin Mocha"` + `BAT_THEME=Dracula` no ambiente saiu
#      #ff79c6. (Este módulo afirmava o contrário antes de alguém medir.)
#      O conserto não é nosso — a variável nasce no shell dela, que mora em
#      `~/.config/zsh`, o repo com auto-commit: território proibido. Então o bat
#      devolve 3 nesse caso, com a linha exata que resolve. Não 0 (seria mentira)
#      e não 1 (o self-heal tentaria consertar de hora em hora sem nunca
#      conseguir — a armadilha de idempotência nº 1 da casa).
#
# ─────────────────────────────────────────────────────────────────────────────
# MERGE, NUNCA REESCRITA — OS DOIS ARQUIVOS DE CONFIG SÃO DELA
# ─────────────────────────────────────────────────────────────────────────────
#   O `config` do bat é uma lista de argumentos de linha de comando, um por
#   linha (`--style=...`, `--italic-text=always`, ...). O `btop.conf` é
#   `chave = "valor"` com comentários `#*`. Nos dois casos mexemos em UMA linha —
#   a ÚLTIMA que casa com a chave, que é a que vale (ver a medição acima) — e
#   copiamos o resto byte a byte. `_bb_merge_linha()` faz isso com awk.
#
#   ARMADILHA DO BTOP: ele REESCREVE o `btop.conf` inteiro ao sair, com todas as
#   chaves e comentários dele. Isso não nos atrapalha (ele reescreve o valor que
#   carregou, inclusive o nosso) — MAS se o btop estiver ABERTO enquanto
#   aplicamos, o `btop.conf` dele em memória é o antigo, e ao fechar ele apaga o
#   que acabamos de gravar. Por isso `meow_app_aplicar` avisa quando acha um btop
#   vivo. Não matamos o processo dela: avisar é o certo, matar é presunção.
#
#   O `pgrep` aqui é `-x btop`: `-f btop` sem âncora casaria qualquer comando que
#   só CITE "btop" — inclusive o shell que roda este módulo. Essa lição já custou
#   caro neste sistema (um `pkill -f` de teste matou o próprio shell). E o nome
#   "btop" tem 4 caracteres, bem abaixo do corte de 15 do `/proc/PID/comm`, então
#   `-x` é seguro aqui — ao contrário do que aconteceu com
#   `cosmic-applet-notifications`.
#
# ─────────────────────────────────────────────────────────────────────────────
# O ACENTO DO UPSTREAM É AZUL, O DA CASA É MAUVE
# ─────────────────────────────────────────────────────────────────────────────
#   Mesmo achado do módulo qbittorrent. No `catppuccin_mocha.theme` upstream:
#       theme[hi_fg]="#89b4fa"        # blue — atalhos de teclado
#       theme[selected_fg]="#89b4fa"  # blue — linha selecionada
#   É Mocha legítimo, mas acentuado em blue. O MeowSystem-Theme é Mocha + accent
#   mauve #CBA6F7. Por padrão instalamos o upstream BYTE A BYTE (é o que o
#   SHA256SUMS promete, e é o que a spec deste módulo pediu). Quem quiser o
#   acento da casa liga `MEOW_BTOP_ACENTO=mauve`: aí um tema DERIVADO
#   (`meowsystem_mocha.theme`) é gerado na hora a partir do vendorizado, trocando
#   só essas duas chaves. De propósito: o derivado é GERADO, não vendorizado —
#   não existe uma segunda cópia para desincronizar do upstream. (O
#   `catppuccin_mocha.theme` só fica instalado do lado se uma passagem anterior,
#   sem a variável, já o tiver instalado; com `mauve` desde o começo, o módulo
#   instala apenas o derivado.)
#
#   No bat NÃO existe esse ajuste, e é de propósito: ali as cores são semânticas
#   (keyword, string, comentário), não "acento" — e o mauve #CBA6F7 já é a cor de
#   keyword, com 19 ocorrências no arquivo. Mexer seria estragar realce de
#   sintaxe achando que se está trocando um acento.
#
# BACKUP
#   Todo arquivo dela que este módulo estaria prestes a SOBRESCREVER é copiado
#   antes para `~/.local/state/meowsystem/backups/<ISO>/`, preservando o caminho
#   relativo à home. Arquivo que não existia não gera backup (não há o que
#   perder), e nada é copiado em MEOW_DRY_RUN.

# --- procedência (ver PROCEDENCIA.md) ---------------------------------------
MEOW_BB_REPO_BAT="https://github.com/catppuccin/bat"
MEOW_BB_COMMIT_BAT="6810349b28055dce54076712fc05fc68da4b8ec0"
MEOW_BB_REPO_BTOP="https://github.com/catppuccin/btop"
MEOW_BB_COMMIT_BTOP="f437574b600f1c6d932627050b15ff5153b58fa3"

# Raiz do módulo. BASH_SOURCE porque somos `source`: $0 é o runner, não este
# arquivo. `readlink -f` para o caso de o assets/temas-de-apps/ ser alcançado por symlink.
MEOW_BB_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"

# ═══════════════════════════════════════════════════════════════════════════
# auxiliares privados (prefixo _bb_ para não colidir com o runner)
# ═══════════════════════════════════════════════════════════════════════════

# Flavor da casa. Aceita MEOW_FLAVOR e, por compatibilidade com
# scripts/construir_icones.sh, o FLAVOR pelado.
# É FUNÇÃO, não variável fixada no `source`: o `install.sh` só lê o `meow.conf`
# lá dentro do `main()`, ou seja, DEPOIS de a fila de módulos poder ter sido
# carregada. Uma variável congelada aqui em cima leria "mocha" e ignoraria em
# silêncio o flavor que ela escolheu — e silêncio é o pior modo de errar.
_bb_flavor() { printf '%s' "${MEOW_FLAVOR:-${FLAVOR:-mocha}}"; }

# Os três caminhos do bat vêm do PRÓPRIO binário (ver o cabeçalho: a cadeia
# BAT_CONFIG_DIR > XDG_CONFIG_HOME > ~/.config foi medida, não suposta).
# Reimplementá-la aqui seria mais um jeito de errar calado; perguntar custa um
# `fork` e nunca desatualiza. O padrão só entra se a flag não existir (bat velho).
_bb_bat_caminho() {
  local bin="$1" flag="$2" reserva="$3" v
  if v="$("$bin" "$flag" 2>/dev/null)" && [ -n "$v" ]; then printf '%s' "$v"; return 0; fi
  printf '%s' "$reserva"
  return 0
}
_bb_bat_cfg_dir()   { _bb_bat_caminho "$1" --config-dir  "${BAT_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/bat}"; }
_bb_bat_cache_dir() { _bb_bat_caminho "$1" --cache-dir   "${BAT_CACHE_PATH:-${XDG_CACHE_HOME:-$HOME/.cache}/bat}"; }
_bb_bat_cfg_file()  { _bb_bat_caminho "$1" --config-file "$(_bb_bat_cfg_dir "$1")/config"; }

# O btop não tem flag equivalente; segue a convenção XDG.
_bb_btop_cfg_dir() { printf '%s/btop' "${XDG_CONFIG_HOME:-$HOME/.config}"; }

# O binário do bat, sob qualquer um dos dois nomes. Imprime o nome; 1 se ausente.
_bb_bat_bin() {
  if command -v bat >/dev/null 2>&1; then printf 'bat'; return 0; fi
  if command -v batcat >/dev/null 2>&1; then printf 'batcat'; return 0; fi
  return 1
}

_bb_btop_bin() { command -v btop >/dev/null 2>&1; }

# Nome do tema bat = o <key>name</key> do plist. Capitaliza o flavor porque é
# assim que o upstream escreve ("Catppuccin Mocha", "Catppuccin Macchiato").
_bb_bat_tema_nome() {
  local f; f="$(_bb_flavor)"
  printf 'Catppuccin %s' "$(printf '%s' "${f:0:1}" | tr '[:lower:]' '[:upper:]')${f:1}"
}
_bb_bat_tema_arquivo() { printf '%s/upstream/bat/%s.tmTheme' "$MEOW_BB_DIR" "$(_bb_bat_tema_nome)"; }

# Stem do tema btop — é isto que vai na chave color_theme.
_bb_btop_tema_stem() {
  if [ "${MEOW_BTOP_ACENTO:-}" = "mauve" ]; then
    printf 'meowsystem_%s' "$(_bb_flavor)"
  else
    printf 'catppuccin_%s' "$(_bb_flavor)"
  fi
}
_bb_btop_upstream() { printf '%s/upstream/btop/catppuccin_%s.theme' "$MEOW_BB_DIR" "$(_bb_flavor)"; }

# Conteúdo do tema btop a instalar: upstream cru, ou derivado com acento mauve.
# O sed é ancorado na chave inteira para não pegar o mesmo #89b4fa de proc_box
# (borda de caixa, não acento) nem os dos gradientes.
_bb_btop_conteudo() {
  local orig; orig="$(_bb_btop_upstream)"
  [ -f "$orig" ] || return 1
  if [ "${MEOW_BTOP_ACENTO:-}" = "mauve" ]; then
    sed -E 's/^(theme\[(hi_fg|selected_fg)\]=")#[0-9A-Fa-f]{6}(")/\1#cba6f7\3/' "$orig"
  else
    cat "$orig"
  fi
}

# Backup antes de sobrescrever. Só é chamado quando já sabemos que o destino
# EXISTE e vai mudar. O carimbo é calculado uma vez por execução para que tudo
# que uma aplicação sobrescreveu caia na MESMA pasta.
#
# O FORMATO NÃO É ESCOLHA NOSSA: a pasta `backups/` é COMPARTILHADA pelos cinco
# módulos, e os outros quatro gravam `%Y-%m-%dT%H-%M-%S` (visto no disco:
# `backups/2026-08-04T20-14-44`, do módulo Qt). Um formato próprio aqui
# (`20260804T202836Z`) rachava uma mesma passagem do catálogo em duas pastas com
# cara diferente — e ela procuraria o backup do bat na pasta errada. O
# `MEOW_CARIMBO` do runner, se existir, vence tudo: é o que o módulo do VS Code
# já respeita.
_bb_carimbo() {
  if [ -z "${MEOW_BB_CARIMBO:-}" ]; then
    MEOW_BB_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  fi
  printf '%s' "$MEOW_BB_CARIMBO"
}

# Nota de estilo daqui para baixo: `condição && ação` NÃO é usado como comando
# solto. Se o runner que nos deu `source` estiver com `set -e`, uma lista `&&`
# cujo primeiro termo falha devolve 1 e MATA o runner — mesmo sendo um "não
# precisa fazer nada" perfeitamente normal. Dentro de `if` o `set -e` fica
# suspenso, então tudo aqui é `if`.
_bb_backup() {
  local alvo="$1" rel dest
  [ -f "$alvo" ] || return 0
  if meow_seco; then return 0; fi
  case "$alvo" in "$HOME"/*) rel="${alvo#"$HOME"/}" ;; *) rel="fora-da-home/${alvo#/}" ;; esac
  dest="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(_bb_carimbo)/$rel"
  mkdir -p "$(dirname "$dest")" || return 1
  cp -p -- "$alvo" "$dest" || return 1
  meow_info "backup: $dest"
  return 0
}

# Instala um arquivo OPACO (artefato do upstream) preservando byte a byte.
# Não usa meow_escrever de propósito: `$(cat ...)` come a newline final e passa o
# conteúdo por uma variável de shell. Para config que NÓS geramos isso é
# inofensivo; para um artefato com sha256 publicado, não — o arquivo instalado
# tem de bater com o SHA256SUMS.
# stdin = conteúdo.  Devolve: 0 já igual · 1 mudou · 2 erro.
_bb_instalar_stdin() {
  local destino="$1" dir tmp
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"

  # Diretório inexistente: o arquivo obviamente diverge, e em dry-run nem o
  # `mkdir -p` pode acontecer — um "seco" que deixa diretórios para trás não é
  # seco. O `cat >/dev/null` NÃO é enfeite: sem ele quem escreve do outro lado do
  # cano leva SIGPIPE e sai 141, e o `pipefail` herdado do comum.sh promove esse
  # 141 a resultado do pipeline — o chamador leria "erro" onde houve "mudaria".
  if [ ! -d "$dir" ]; then
    if meow_seco; then
      cat >/dev/null
      meow_muda "mudaria $destino (criaria $dir)"
      return "$MEOW_DIVERGENTE"
    fi
    mkdir -p "$dir" || return "$MEOW_ERRO"
  fi

  # Onde nasce o temporário: no diretório de DESTINO quando vamos mesmo gravar
  # (é o que torna o `mv` um rename(2) atômico — o repo está em /mnt/Apate e o
  # destino em /home, e um `mv` entre discos seria copy+unlink). No SECO, porém,
  # o `mv` nunca acontece, e um `.meow.XXXXXX` piscando dentro do `~/.config`
  # dela é exatamente a escrita que o dry-run promete não fazer — se o processo
  # morresse no meio, sobraria lixo num diretório que juramos não ter tocado.
  # Então no seco o temporário vai para o $TMPDIR.
  if meow_seco; then
    tmp="$(mktemp "${TMPDIR:-/tmp}/meow-seco.XXXXXX")" || return "$MEOW_ERRO"
  else
    tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  fi
  cat > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }

  if [ -f "$destino" ] && cmp -s "$tmp" "$destino"; then
    rm -f "$tmp"; return "$MEOW_OK"
  fi
  if meow_seco; then
    rm -f "$tmp"; meow_muda "mudaria $destino"; return "$MEOW_DIVERGENTE"
  fi
  _bb_backup "$destino" || { rm -f "$tmp"; meow_erro "backup de $destino falhou"; return "$MEOW_ERRO"; }
  chmod 644 "$tmp"
  # O tmp nasceu dentro de $dir: este mv é rename(2) no mesmo sistema de
  # arquivos, atômico. O repo está em /mnt/Apate e o destino em /home — um mv
  # daqui para lá seria copy+unlink, e um corte no meio deixaria o tema pela metade.
  mv -f "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# Compara stdin com um arquivo, sem escrever nada. 0 igual · 1 difere.
# O `cat >/dev/null` do caminho "destino não existe" é o mesmo cuidado do
# `_bb_instalar_stdin`: sair sem esvaziar o cano dá SIGPIPE em quem escreve do
# outro lado, e o `pipefail` do comum.sh promoveria esse 141 a resultado do
# pipeline inteiro. Hoje todo chamador trata "não-zero" como divergente e não
# veria diferença — mas o primeiro que olhar o código exato veria "erro" onde há
# só "arquivo ainda não instalado".
_bb_igual_stdin() {
  local destino="$1"
  if [ ! -f "$destino" ]; then cat >/dev/null; return 1; fi
  cmp -s - "$destino"
}

# ── MERGE de uma linha em arquivo de config dela ────────────────────────────
# Reescreve a ÚLTIMA linha que casa com $2 por $3; se nenhuma casar, anexa $3
# no fim. Todo o resto sai byte a byte. Imprime o resultado em stdout.
#
# ÚLTIMA, e não primeira: nos dois apps a última ocorrência da chave é a que
# vale (medição no cabeçalho). Reescrever a primeira e deixar uma segunda mais
# embaixo seria gravar uma linha decorativa — o app continuaria com o tema dela
# e o `conferir` diria "aplicado" para sempre.
#
# O awk recebe padrão e substituto por -v para que nenhum `#`, `"` ou `/` do
# valor seja interpretado como sintaxe — foi a razão de não usar sed aqui.
_bb_merge_linha() {
  local arquivo="$1" padrao="$2" nova="$3"
  if [ ! -f "$arquivo" ]; then printf '%s\n' "$nova"; return 0; fi
  awk -v pad="$padrao" -v nova="$nova" '
    { linha[NR] = $0; if ($0 ~ pad) alvo = NR }
    END {
      for (i = 1; i <= NR; i++) print (i == alvo ? nova : linha[i])
      if (!alvo) print nova
    }
  ' "$arquivo"
}

# A ÚLTIMA linha do arquivo $1 que casa com a ERE $2 — a que o app obedece.
# Sempre devolve 0: um `grep` sem casamento dentro de uma atribuição mataria um
# runner com `set -e`, e "chave ausente" é resposta normal, não falha.
_bb_ultima_linha() {
  if [ ! -f "$1" ]; then return 0; fi
  grep -E -- "$2" "$1" 2>/dev/null | tail -n 1 || true
}

# ═══════════════════════════════════════════════════════════════════════════
# bat
# ═══════════════════════════════════════════════════════════════════════════

# O cache está válido para o nosso tema?
#   Critério primário (não depende de formato de saída): themes.bin existe e não
#   é mais ANTIGO que o .tmTheme instalado. Se o tema mudou depois do build, o
#   cache é velho e o bat usaria o tema antigo calado.
#   Critério secundário: se `--list-themes` rodar, o nome tem de aparecer. Se o
#   comando falhar por qualquer motivo, ignoramos — é confirmação, não juiz.
_bb_bat_cache_ok() {
  local bin="$1" tema_dest="$2" nome="$3" bin_cache saida
  bin_cache="$(_bb_bat_cache_dir "$bin")/themes.bin"
  [ -f "$bin_cache" ] || return 1
  [ -f "$tema_dest" ] || return 1
  # "cache não é mais velho que o tema". Escrito pela negativa de propósito:
  # `-nt` é falso quando as mtimes empatam, então `cache -nt tema` sozinho
  # rejeitaria um cache legítimo construído no mesmo segundo do tema.
  [ ! "$tema_dest" -nt "$bin_cache" ] || return 1
  if saida="$("$bin" --no-config --paging=never --color=never --list-themes 2>/dev/null)"; then
    case "$saida" in *"$nome"*) : ;; *) return 1 ;; esac
  fi
  return 0
}

# ERE que acha QUALQUER linha `--theme` (para saber qual é a última que vale) e
# ERE que reconhece uma `--theme` JÁ correta, em qualquer das três grafias
# aceitas pelo bat. Usadas iguais no conferir e no aplicar — se as expressões
# divergissem, o módulo entraria em ping-pong: conferir reprova, aplicar grava,
# conferir reprova de novo, para sempre.
_bb_bat_padrao_chave() { printf '^[[:space:]]*--theme([=[:space:]]|$)'; }
_bb_bat_padrao_ok() {
  printf '^[[:space:]]*--theme[[:space:]]*=?[[:space:]]*"?%s"?[[:space:]]*$' "$1"
}

# A linha `--theme` que o bat de fato obedece já está certa? (a ÚLTIMA do arquivo)
_bb_bat_linha_ok() {
  local cfg="$1" nome="$2" linha
  linha="$(_bb_ultima_linha "$cfg" "$(_bb_bat_padrao_chave)")"
  if [ -z "$linha" ]; then return 1; fi
  printf '%s' "$linha" | grep -Eq "$(_bb_bat_padrao_ok "$nome")"
}

# BAT_THEME no ambiente VENCE o arquivo de config — medido, ver o cabeçalho.
# 0 = tem uma variável dessas mandando em outro tema.
_bb_bat_ambiente_manda() {
  [ -n "${BAT_THEME:-}" ] && [ "${BAT_THEME}" != "$1" ]
}
_bb_bat_avisar_ambiente() {
  meow_aviso "bat: BAT_THEME='${BAT_THEME:-}' no ambiente VENCE o arquivo de config (medido) — o que ela vê NÃO é o '$1'. O conserto é tirar a variável do shell dela, e isso mora no ~/.config/zsh, que não é território deste módulo."
}

# 0 tudo certo · 1 divergente · 2 erro · 3 não dá para garantir daqui.
# (Ausência do binário também é 3, e é tratada pelo chamador.)
_bb_bat_conferir() {
  local bin nome origem destino cfg
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"; origem="$(_bb_bat_tema_arquivo)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  [ -f "$origem" ] || { meow_erro "falta o tema vendorizado: $origem"; return "$MEOW_ERRO"; }
  cmp -s "$origem" "$destino" || { meow_info "bat: tema '$nome' ausente ou divergente"; return "$MEOW_DIVERGENTE"; }
  _bb_bat_cache_ok "$bin" "$destino" "$nome" || { meow_info "bat: cache não contém '$nome' (falta 'bat cache --build')"; return "$MEOW_DIVERGENTE"; }

  # A chave --theme no config dela. Aceita --theme=X e --theme X, com ou sem
  # aspas: as três formas são válidas para o bat, e reprovar uma que ela mesma
  # escreveu à mão só geraria reescrita cosmética eterna.
  if ! _bb_bat_linha_ok "$cfg" "$nome"; then
    meow_info "bat: o --theme que vale (o último de $cfg) não aponta para '$nome'"
    return "$MEOW_DIVERGENTE"
  fi

  # O arquivo está certo, mas quem manda na tela é o ambiente. Nem 0 (mentira)
  # nem 1 (o self-heal tentaria de hora em hora e nunca conseguiria): 3.
  if _bb_bat_ambiente_manda "$nome"; then
    _bb_bat_avisar_ambiente "$nome"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# 0 nada a fazer · 1 aplicou · 2 erro · 3 não dá para garantir daqui.
_bb_bat_aplicar() {
  local bin nome origem destino cfg mudou=0 rc texto
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"; origem="$(_bb_bat_tema_arquivo)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  [ -f "$origem" ] || { meow_erro "falta o tema vendorizado: $origem"; return "$MEOW_ERRO"; }

  _bb_instalar_stdin "$destino" < "$origem"; rc=$?
  case $rc in
    1) mudou=1; meow_muda "bat: tema '$nome' instalado em $destino" ;;
    2) meow_erro "bat: falhou ao instalar $destino"; return "$MEOW_ERRO" ;;
  esac

  # --theme no config, por MERGE: o arquivo pode ter 20 escolhas dela
  # (--style, --italic-text, --map-syntax...) e nenhuma delas é da nossa conta.
  # O `_bb_instalar_stdin` já faz backup, compara por conteúdo e respeita o
  # dry-run, então não há um segundo caminho aqui.
  if ! _bb_bat_linha_ok "$cfg" "$nome"; then
    texto="$(_bb_merge_linha "$cfg" "$(_bb_bat_padrao_chave)" "--theme=\"$nome\"")"
    printf '%s\n' "$texto" | _bb_instalar_stdin "$cfg"
    case $? in
      1) mudou=1; meow_muda "bat: --theme=\"$nome\" gravado em $cfg" ;;
      2) meow_erro "bat: falhou ao gravar $cfg"; return "$MEOW_ERRO" ;;
    esac
  fi

  # O cache é o passo que faz o tema EXISTIR para o bat. Roda depois de tudo.
  if ! _bb_bat_cache_ok "$bin" "$destino" "$nome"; then
    if meow_seco; then
      meow_muda "rodaria '$bin cache --build'"
      mudou=1
    else
      meow_info "bat: compilando o cache de temas ($bin cache --build)"
      if "$bin" cache --build >/dev/null 2>&1; then
        mudou=1
      else
        meow_erro "bat: '$bin cache --build' falhou"
        return "$MEOW_ERRO"
      fi
    fi
  fi

  # Os dois avisos só saem quando ALGO mudou. O self-heal roda de hora em hora:
  # um aviso fixo numa passagem que não fez nada vira ruído que ela aprende a
  # ignorar — e no dia em que o aviso importasse, ninguém leria.
  if [ "$mudou" = "1" ] && [ "$bin" = "batcat" ]; then
    meow_aviso "bat: o binário aqui chama-se 'batcat' (colisão com bacula-console-qt no Debian) — o alias é decisão dela, e não pode morar no ~/.config/zsh"
  fi
  if _bb_bat_ambiente_manda "$nome"; then
    _bb_bat_avisar_ambiente "$nome"
    # Mudamos os arquivos e isso é verdade (1); o que não dá é dizer "aplicado"
    # quando nada mudou e a tela continua obedecendo ao ambiente — aí é 3.
    if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
  return "$MEOW_OK"
}

# ═══════════════════════════════════════════════════════════════════════════
# btop
# ═══════════════════════════════════════════════════════════════════════════

# O btop aceita stem, nome de arquivo OU caminho absoluto (btop_theme.cpp,
# setTheme). Este ERE cobre as três, e é o mesmo no conferir e no aplicar: se ela
# tiver escolhido o tema pelo menu do btop — que grava o caminho absoluto — o
# módulo reconhece como certo em vez de reescrever a linha toda vez.
_bb_btop_padrao_chave() { printf '^[[:space:]]*color_theme[[:space:]]*='; }
_bb_btop_padrao_ok() {
  printf '^[[:space:]]*color_theme[[:space:]]*=[[:space:]]*"(.*/)?%s(\.theme)?"[[:space:]]*$' "$1"
}

# A linha `color_theme` que o btop de fato obedece já está certa? MEDIDO com o
# btop 1.3.0: um btop.conf com `color_theme` duas vezes (mocha, depois latte)
# fez o btop carregar o LATTE — a última vence, como no bat. Por isso é a última
# que se julga, e não "existe alguma linha certa em algum lugar do arquivo".
_bb_btop_linha_ok() {
  local conf="$1" stem="$2" linha
  linha="$(_bb_ultima_linha "$conf" "$(_bb_btop_padrao_chave)")"
  if [ -z "$linha" ]; then return 1; fi
  printf '%s' "$linha" | grep -Eq "$(_bb_btop_padrao_ok "$stem")"
}

_bb_btop_conferir() {
  local stem destino conf
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  [ -f "$(_bb_btop_upstream)" ] || { meow_erro "falta o tema vendorizado: $(_bb_btop_upstream)"; return "$MEOW_ERRO"; }
  _bb_btop_conteudo | _bb_igual_stdin "$destino" || { meow_info "btop: tema '$stem' ausente ou divergente"; return "$MEOW_DIVERGENTE"; }

  if _bb_btop_linha_ok "$conf" "$stem"; then
    return "$MEOW_OK"
  fi
  meow_info "btop: o color_theme que vale (o último de $conf) não aponta para '$stem'"
  return "$MEOW_DIVERGENTE"
}

_bb_btop_aplicar() {
  local stem destino conf mudou=0 texto
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  [ -f "$(_bb_btop_upstream)" ] || { meow_erro "falta o tema vendorizado: $(_bb_btop_upstream)"; return "$MEOW_ERRO"; }

  _bb_btop_conteudo | _bb_instalar_stdin "$destino"
  case $? in
    1) mudou=1; meow_muda "btop: tema '$stem' instalado em $destino" ;;
    2) meow_erro "btop: falhou ao instalar $destino"; return "$MEOW_ERRO" ;;
  esac

  if ! _bb_btop_linha_ok "$conf" "$stem"; then
    texto="$(_bb_merge_linha "$conf" "$(_bb_btop_padrao_chave)" "color_theme = \"$stem\"")"
    printf '%s\n' "$texto" | _bb_instalar_stdin "$conf"
    case $? in
      1) mudou=1; meow_muda "btop: color_theme = \"$stem\" gravado em $conf" ;;
      2) meow_erro "btop: falhou ao gravar $conf"; return "$MEOW_ERRO" ;;
    esac
  fi

  # Ver o cabeçalho: um btop aberto reescreve o btop.conf inteiro ao sair, com o
  # valor que ele carregou na abertura — apagando o que acabamos de gravar.
  # `-x` e não `-f`: `-f btop` casaria o próprio shell que roda este módulo.
  if [ "$mudou" = "1" ] && ! meow_seco && pgrep -x btop >/dev/null 2>&1; then
    meow_aviso "btop: há um btop ABERTO — ele regrava o btop.conf ao sair e desfaz isto. Feche e reabra."
  fi

  if [ "$mudou" = "1" ]; then return "$MEOW_DIVERGENTE"; fi
  return "$MEOW_OK"
}

# ═══════════════════════════════════════════════════════════════════════════
# a interface do contrato: as três funções
# ═══════════════════════════════════════════════════════════════════════════

# 0 = pelo menos um dos dois está instalado · 3 = nenhum. Nunca falha.
meow_app_detectar() {
  local achou=0 bat_bin
  if bat_bin="$(_bb_bat_bin)"; then
    meow_info "bat encontrado como '$bat_bin'"
    achou=1
  fi
  if _bb_btop_bin; then
    meow_info "btop encontrado"
    achou=1
  fi
  if [ "$achou" = "1" ]; then return "$MEOW_OK"; fi
  meow_pula "btop e bat não estão instalados (sudo apt install btop bat)"
  return "$MEOW_SEM_DEPENDENCIA"
}

# Quantos dos dois estão presentes. 0 = nenhum.
_bb_presentes() {
  local n=0
  if _bb_bat_bin >/dev/null; then n=$((n+1)); fi
  if _bb_btop_bin; then n=$((n+1)); fi
  printf '%s' "$n"
}

# Rótulo da mensagem final: nomeia só os apps que tiveram veredito. Dizer
# "btop/bat: nada a fazer" com o bat entregue ao BAT_THEME (3) seria assinar
# embaixo do que o aviso de duas linhas acima acabou de desmentir.
_bb_rotulo() {
  local l=""
  if [ "$1" != "3" ]; then l="bat"; fi
  if [ "$2" != "3" ]; then l="${l:+$l/}btop"; fi
  printf '%s' "${l:-btop/bat}"
}

# Acumula o veredito: 2 vence 1, que vence 0; 3 (app ausente) não conta.
_bb_pior() {
  local atual="$1" novo="$2"
  if [ "$novo" = "3" ]; then printf '%s' "$atual"; return 0; fi
  if [ "$novo" -gt "$atual" ]; then printf '%s' "$novo"; else printf '%s' "$atual"; fi
}

# 0 aplicado · 1 divergente · 2 erro · 3 nada que este módulo possa garantir.
# O erro de um app não some: 2 vence 1, que vence 0. Um app que devolve 3 é
# ignorado no veredito — mas se os DOIS devolverem 3 o resultado é 3, não 0:
# um "0" ali significaria "conferi e está tudo certo" sem ter conferido nada.
meow_app_conferir() {
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi

  _bb_bat_conferir;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_conferir; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi

  if [ "$pior" = "0" ]; then
    meow_ok "$(_bb_rotulo "$bat_rc" "$btop_rc"): Catppuccin $(_bb_flavor) já aplicado"
  fi
  return "$pior"
}

# 0 nada a fazer · 1 aplicou · 2 erro · 3 nenhum dos dois instalado.
meow_app_aplicar() {
  local pior=0 bat_rc btop_rc
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "btop e bat não estão instalados — temas prontos em $MEOW_BB_DIR/upstream para o dia da instalação"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # O carimbo do backup é fixado AQUI, no shell de cima. Se ficasse a cargo do
  # `_bb_backup`, cada pipeline `texto | _bb_instalar_stdin` rodaria num
  # subshell próprio, o valor não voltaria, e uma aplicação que cruzasse a virada
  # do segundo espalharia os backups por duas pastas <ISO> diferentes.
  MEOW_BB_CARIMBO="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"

  _bb_bat_aplicar;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_aplicar; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  # Mesma regra do conferir: se nenhum dos dois teve veredito, não há "nada a
  # fazer" para anunciar — há um "não é comigo", e isso é 3.
  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi

  local rotulo; rotulo="$(_bb_rotulo "$bat_rc" "$btop_rc")"
  case "$pior" in
    0) meow_ok "$rotulo: nada a fazer" ;;
    1) if meow_seco; then
         meow_muda "$rotulo: divergente — nada foi gravado (MEOW_DRY_RUN=1)"
       else
         meow_ok "$rotulo: Catppuccin $(_bb_flavor) aplicado"
       fi ;;
  esac
  return "$pior"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter bat|btop` e o passo 2/6 do `--uninstall`.
#
# SÓ SE APAGA O QUE AINDA É NOSSO, BYTE A BYTE
#   O `.tmTheme` e o `.theme` são comparados com o que ESTE módulo instalaria
#   antes de sumirem. Se ela editou o arquivo depois, o que está lá deixou de ser
#   nosso e fica — é a mesma regra do sha256 do manifesto, aplicada a um par de
#   arquivos que não passam por `meow_escrever`.
#
# A CHAVE DO CONFIG VOLTA AO PADRÃO, NÃO SOME
#   Tirar a linha `--theme` do config do bat deixaria o tema anterior dela (se
#   houvesse um) sem quem o nomeasse. Mas repor "o de antes" também é invenção:
#   ninguém guardou. Então o critério é estreito e verificável — a linha só é
#   mexida quando aponta para o NOSSO tema, e vira o padrão do programa.
_bb_bat_reverter() {
  local bin nome destino cfg texto mudou=0
  bin="$(_bb_bat_bin)" || return "$MEOW_SEM_DEPENDENCIA"
  nome="$(_bb_bat_tema_nome)"
  destino="$(_bb_bat_cfg_dir "$bin")/themes/$nome.tmTheme"
  cfg="$(_bb_bat_cfg_file "$bin")"

  if [ -f "$destino" ]; then
    if cmp -s "$(_bb_bat_tema_arquivo)" "$destino"; then
      if meow_seco; then meow_muda "bat: removeria $destino"; mudou=1
      elif rm -f "$destino"; then mudou=1; meow_muda "bat: tema '$nome' removido"
      fi
    else
      meow_pula "bat: $destino mudou depois que escrevemos — fica"
    fi
  fi

  if _bb_bat_linha_ok "$cfg" "$nome"; then
    if meow_seco; then
      meow_muda "bat: tiraria o --theme='$nome' de $cfg"; mudou=1
    else
      # A linha do NOSSO tema sai; o resto do config dela fica intacto.
      texto="$(awk -v pad="$(_bb_bat_padrao_chave)" -v ok="$(_bb_bat_padrao_ok "$nome")" \
                 '$0 ~ pad && $0 ~ ok { next } { print }' "$cfg")"
      if printf '%s\n' "$texto" > "$cfg" 2>/dev/null; then
        mudou=1; meow_muda "bat: --theme='$nome' retirado de $cfg"
      else
        meow_erro "bat: não consegui reescrever $cfg"; return "$MEOW_ERRO"
      fi
    fi
  fi

  # Sem isto o tema continua DENTRO do cache binário, e `bat --list-themes` ainda
  # o oferece — arquivo removido, tema vivo. Falhar aqui não derruba o resto.
  [ "$mudou" = "1" ] && ! meow_seco && "$bin" cache --build >/dev/null 2>&1
  [ "$mudou" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

_bb_btop_reverter() {
  local stem destino conf texto mudou=0
  _bb_btop_bin || return "$MEOW_SEM_DEPENDENCIA"
  stem="$(_bb_btop_tema_stem)"
  destino="$(_bb_btop_cfg_dir)/themes/$stem.theme"
  conf="$(_bb_btop_cfg_dir)/btop.conf"

  if [ -f "$destino" ]; then
    if _bb_btop_conteudo | _bb_igual_stdin "$destino"; then
      if meow_seco; then meow_muda "btop: removeria $destino"; mudou=1
      elif rm -f "$destino"; then mudou=1; meow_muda "btop: tema '$stem' removido"
      fi
    else
      meow_pula "btop: $destino mudou depois que escrevemos — fica"
    fi
  fi

  # "Default" é o valor de fábrica do btop. Apagar a linha não serviria: o btop
  # reserializa o btop.conf inteiro ao sair e a repõe — apontando para um tema
  # que acabou de deixar de existir.
  if [ -f "$conf" ] && _bb_btop_linha_ok "$conf" "$stem"; then
    if meow_seco; then
      meow_muda "btop: color_theme voltaria para \"Default\""; mudou=1
    else
      texto="$(_bb_merge_linha "$conf" "$(_bb_btop_padrao_chave)" 'color_theme = "Default"')"
      if printf '%s\n' "$texto" > "$conf" 2>/dev/null; then
        mudou=1; meow_muda "btop: color_theme = \"Default\""
      else
        meow_erro "btop: não consegui reescrever $conf"; return "$MEOW_ERRO"
      fi
    fi
  fi

  [ "$mudou" = "0" ] && return "$MEOW_OK"
  return "$MEOW_DIVERGENTE"
}

meow_app_reverter() {
  if [ "$(_bb_presentes)" = "0" ]; then
    meow_pula "nem bat nem btop instalados"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  local pior=0 bat_rc btop_rc
  _bb_bat_reverter;  bat_rc=$?;  pior="$(_bb_pior "$pior" "$bat_rc")"
  _bb_btop_reverter; btop_rc=$?; pior="$(_bb_pior "$pior" "$btop_rc")"

  if [ "$bat_rc" = "3" ] && [ "$btop_rc" = "3" ]; then return "$MEOW_SEM_DEPENDENCIA"; fi
  local rotulo; rotulo="$(_bb_rotulo "$bat_rc" "$btop_rc")"
  case "$pior" in
    0) meow_ok "$rotulo: já estavam sem o Catppuccin" ;;
    1) meow_seco || meow_info "tire 'bat'/'btop' de APPS_ATIVOS, ou o doctor das 05:00 reaplica" ;;
  esac
  return "$pior"
}

# ═══════════════════════════════════════════════════════════════════════════
# manutenção — NÃO faz parte do contrato, é para rodar na mão
# ═══════════════════════════════════════════════════════════════════════════
# Rebaixa os temas do upstream nos commits PINADOS lá em cima e regrava o
# SHA256SUMS. Só existe para que atualizar o upstream seja um diff revisável, e
# não um "baixei de novo e confia". Uso:
#   . assets/temas-de-apps/btop-bat/manifesto.sh && _bb_rebaixar_upstream
_bb_rebaixar_upstream() {
  local tmp par nome url commit sub glob
  meow_tem git || { meow_erro "git não encontrado"; return "$MEOW_SEM_DEPENDENCIA"; }
  tmp="$(mktemp -d)" || return "$MEOW_ERRO"
  for par in "bat|$MEOW_BB_REPO_BAT|$MEOW_BB_COMMIT_BAT|themes|*.tmTheme" \
             "btop|$MEOW_BB_REPO_BTOP|$MEOW_BB_COMMIT_BTOP|themes|*.theme"; do
    IFS='|' read -r nome url commit sub glob <<< "$par"
    git clone -q "$url" "$tmp/$nome" || { meow_erro "clone de $url falhou"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    git -C "$tmp/$nome" checkout -q "$commit" || { meow_erro "commit $commit não existe em $url"; rm -rf "$tmp"; return "$MEOW_ERRO"; }
    mkdir -p "$MEOW_BB_DIR/upstream/$nome"
    # shellcheck disable=SC2086
    cp -p "$tmp/$nome/$sub"/$glob "$MEOW_BB_DIR/upstream/$nome/" || { rm -rf "$tmp"; return "$MEOW_ERRO"; }
    meow_ok "$nome rebaixado em ${commit:0:8}"
  done
  rm -rf "$tmp"
  ( cd "$MEOW_BB_DIR" && find upstream -type f -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
  meow_ok "SHA256SUMS regravado"
  return "$MEOW_OK"
}
