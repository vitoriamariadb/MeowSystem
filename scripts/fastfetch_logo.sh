#!/usr/bin/env bash
# fastfetch_logo.sh — a Coquinha em ANSI no lugar do logo do Pop!_OS, e a
# fronteira que impede este script de terminar o serviço sozinho.
#
# O QUE ELA VÊ HOJE, E POR QUE INCOMODA
#   O `fastfetch` abre o terminal dela com o logo do **Pop!_OS**, numa máquina
#   que se chama MeowSystem, tem gato no painel e cujo dono tem dois gatos
#   reais. O cartão de visita mostra a marca errada. A escolha dela, de
#   25/08/2026: a Coquinha, em ANSI colorido, no lugar do `pop`.
#
# NADA AQUI É DESENHADO À MÃO — E ISSO É REGRA, NÃO ZELO
#   Ela reprovou desenho autoral em 05/08/2026 ("sinceramente são péssimos") e
#   estava certa. O logo que este script gera sai de um arquivo que JÁ É DELA:
#   `assets/gatos/coquinha.svg`, a mesma logo que o `meow logo` põe no painel —
#   md5 idêntico ao `~/.config/cosmic/logos/meow-coquinha.svg` e ao
#   `~/coquinha.svg`. O script não inventa um pixel: ele **rasteriza e reduz**.
#
#   Registro da contradição com o `docs/SPRINTS.md`: a sprint diz "a partir de
#   FOTO dela". **Não existe foto da Coquinha nesta máquina** (varrido em
#   25/08/2026). O que existe é o SVG de traço acima. Foi ele que serviu, e o
#   teste de legibilidade abaixo é o que autoriza usá-lo.
#
# AS QUATRO MEDIÇÕES QUE DECIDIRAM O FORMATO (25/08/2026)
#   1. O `cosmic-term` NÃO TEM PROTOCOLO DE IMAGEM. Sondado ao vivo, dentro de
#      uma janela `cosmic-term` 1.6.0, lendo a resposta do próprio terminal:
#        DA1  (`\e[c`)  -> `\e[?6c`      ("VT102"; sem `;4` = **sem sixel**)
#        DA2  (`\e[>c`) -> `\e[>0;2501;1c`
#        query kitty (`\e_Gi=31,...,a=q\e\\` seguida de DA1) -> voltou **só** a
#          DA1, sem nenhuma resposta APC = **sem protocolo kitty**
#        XTSMGRAPHICS (`\e[?1;1;0S`) -> silêncio
#      Confere com o binário: `strings /usr/bin/cosmic-term | grep -ci sixel` e
#      o mesmo para `kitty` devolvem **0**. O VTE dele é o `alacritty_terminal`,
#      que nunca implementou nenhum dos dois. Ou seja: `logo.type` `sixel`,
#      `kitty` e `iterm` estão fora. **ANSI é o único caminho** — que já era a
#      escolha dela, agora medida em vez de suposta.
#
#   2. A CÉLULA DELA NÃO É 1:2, É 1:2,556. Medido pelo `TIOCGWINSZ` de uma
#      janela `cosmic-term` real (JetBrainsMono Nerd Font Mono 16):
#        linhas=23 colunas=103 xpixel=927 ypixel=529  ->  célula 9,00 x 23,00 px
#      É por isso que o "~40x20 células" do `docs/SPRINTS.md` **deforma**: 40
#      colunas por 20 linhas desenham um retângulo 28% mais alto que largo, e o
#      disco da Coquinha vira elipse. Para sair quadrado na TELA DELA a conta é
#      `linhas = colunas / 2,556` — 40 colunas pedem **16** linhas, não 20.
#
#   3. O `chafa` NÃO FOI INSTALADO, E NÃO FAZ FALTA. O binário não está na
#      máquina e `ldconfig -p | grep chafa` é vazio; o `--logo-type chafa` deste
#      `fastfetch` 2.61.0 até produz saída, mas em ASCII de 8 cores (`/`, `7`,
#      `*`, com `\e[36m`/`\e[37m`) — pior que o meio-bloco truecolor que o
#      conversor daqui escreve. Um `apt install` para piorar o resultado seria
#      dependência nova em troca de nada.
#
#   4. `logo.type: "file"` CONTAMINA, `file-raw` NÃO. Os dois foram rodados
#      sobre o mesmo `.ansi`: o `file` emite um `\e[36m` na frente do arquivo
#      (é a cor 1 dele) e ainda faz substituição de `$1`..`$9` no conteúdo. O
#      `file-raw` entrega byte por byte. Por isso o patch pede **`file-raw`**.
#      Em ambos o `~` do `logo.source` é expandido — conferido.
#
# O CONVERSOR: MEIO-BLOCO, DOIS PIXELS POR CÉLULA
#   Cada célula é um `▀` com a cor de CIMA no foreground e a de BAIXO no
#   background (truecolor 24 bits), o que dobra a resolução vertical. Onde só a
#   metade de baixo é opaca, o caractere vira `▄` e o fundo fica o do terminal —
#   assim o disco da Coquinha nasce recortado, sem retângulo preto em volta, e
#   funciona igual no tema claro dela.
#
#   Não usa PIL (esta máquina não tem) nem `chafa`. Usa o que já está aqui:
#   `rsvg-convert` rasteriza o SVG em 2048 px, o `convert` reduz por Lanczos e
#   cospe `txt:`, que é ASCII e se lê com dez linhas de Python. O `identify`/
#   `convert` são o ImageMagick 6 do sistema.
#
# A FRONTEIRA, QUE É A METADE DIFÍCIL DESTA SPRINT
#   A chave que faz o logo aparecer é `logo.source`, e ela mora em
#   `~/.config/fastfetch/config.jsonc` — que é **symlink para
#   `~/.config/zsh/fastfetch/`**, território do Ritual da Aurora, recusado pela
#   TRAVA 1 do `lib/comum.sh` (e com auto-commit a cada 10 min no repo PRIVADO
#   dela). O `docs/FRONTEIRA.md` já dizia isso na última linha da tabela:
#   *"tema do qBittorrent, ~/.config/fastfetch | Aurora | **Aurora**"*.
#
#   Então este script faz DUAS coisas e para:
#     - escreve o `.ansi` em `~/.local/share/meowsystem/fastfetch/`, que é NOSSO;
#     - **lê** o `config.jsonc` dela e diz se ele já aponta para o arquivo.
#   Se não apontar, ele imprime o patch exato e sai com **4**, não com 1.
#
#   O 4 NÃO É CAPRICHO DE CÓDIGO DE SAÍDA. O `meow-doctor.timer` roda às 5h e o
#   `ExecStopPost` notifica quando o código é 1. Um estado que o auto-reparo
#   NÃO PODE consertar, saindo 1, viraria "o auto-reparo corrigiu" na tela dela
#   toda madrugada, sem nada ter sido corrigido — foi ela quem apontou esse
#   risco, e é o mesmo motivo pelo qual o 4 já existe para a captura de tema.
#   O `bin/meow` trata o 4 como "não há nada que o auto-reparo deva fazer".
#
# O QUE ACONTECE SE O ARQUIVO SUMIR, E POR QUE NÃO É PERIGOSO
#   Ao contrário da sombra do applet de mídia (que, sem binário, abre um BURACO
#   na dock), um `logo.source` apontando para arquivo inexistente não derruba
#   nada: o `fastfetch` cai no logo detectado por distribuição e a linha de
#   comando dela continua funcionando. Por isso aqui não há fail-safe: o custo
#   de errar é o logo do Pop de volta, que é exatamente o estado de hoje.
#
# USO
#   fastfetch_logo.sh aplicar    gera o .ansi (idempotente) e confere a fronteira
#   fastfetch_logo.sh conferir   0 = tudo certo · 1 = o .ansi divergiu ·
#                                4 = o .ansi está certo e o config.jsonc (da
#                                    Aurora) ainda aponta para outro logo
#   fastfetch_logo.sh ver        imprime o logo no terminal, do jeito que ele sai
#   fastfetch_logo.sh patch      imprime o bloco JSON exato para o config.jsonc
#   fastfetch_logo.sh remover    apaga o .ansi (o fastfetch volta ao logo padrão)
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# A chave liga/desliga. Ela é LIDA aqui, e não só no `install.sh`, porque chave
# de configuração que ninguém lê é o defeito que este repositório já varreu uma
# vez (08/08/2026): o `meow configurar` perguntava, dizia "gravado", e a saída
# continuava idêntica. Com "nao", `aplicar` e `conferir` saem 0 sem escrever;
# `remover` continua funcionando, porque desligar não pode virar tranca.
FASTFETCH_LOGO="${FASTFETCH_LOGO:-sim}"

# O gato. `coquinha` e `mimir` saem de `assets/gatos/`; qualquer outro valor é
# tratado como caminho de arquivo, para ela poder apontar um SVG dela mesma.
FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_GATO:-coquinha}"

# LARGURA EM COLUNAS. 40 não é chute: é a largura do logo `pop` que este
# substitui (medido — o bloco de informação continua começando na MESMA coluna,
# então nada do texto dela se desloca). Mexer aqui é seguro; a altura se ajusta
# sozinha pela proporção da célula, logo abaixo.
FASTFETCH_LOGO_COLUNAS="${FASTFETCH_LOGO_COLUNAS:-40}"

# PROPORÇÃO ALTURA/LARGURA DA CÉLULA — 23,00 / 9,00 px, medido no cosmic-term
# dela (ver medição 2 do cabeçalho). É CONSTANTE de propósito: medir isto em
# tempo de execução tornaria o arquivo diferente conforme a janela, e o
# `conferir` (que regera e compara) acusaria divergência eterna. Quem mudar de
# fonte muda este número aqui, uma vez.
FASTFETCH_LOGO_CELULA="${FASTFETCH_LOGO_CELULA:-2.556}"

# Resolução em que o SVG é rasterizado antes de encolher. Alto de propósito: a
# redução por Lanczos a partir de 2048 px é o que preserva o traço do focinho.
FFL_RASTER=2048

FFL_BASE="$HOME/.local/share/meowsystem/fastfetch"
FFL_ALVO="$FFL_BASE/$(basename "${FASTFETCH_LOGO_GATO%.svg}").ansi"

# O config.jsonc DELA. Só é LIDO — nunca aberto para escrita, em nenhum caminho
# deste arquivo.
FFL_CONF_DELA="$HOME/.config/fastfetch/config.jsonc"

_ffl_svg() {
  case "$FASTFETCH_LOGO_GATO" in
    */*|*.svg) printf '%s' "$FASTFETCH_LOGO_GATO" ;;
    *)         printf '%s' "$MEOW_RAIZ/assets/gatos/$FASTFETCH_LOGO_GATO.svg" ;;
  esac
}

_ffl_linhas() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" \
      'BEGIN { n = int(c / r + 0.5); if (n < 1) n = 1; print n }'
}

# --- o conversor -------------------------------------------------------------
# DETERMINÍSTICO, que é o que torna o `conferir` possível: gera de novo num
# temporário e compara com o que está no disco. Sem isso toda checagem acusaria
# divergência e o auto-reparo entraria em ping-pong (a lição do `custom_logo_path`).
_ffl_gerar() {
  local destino="$1" svg="$2" colunas="$3" linhas="$4"
  python3 - "$svg" "$colunas" "$linhas" "$destino" "$FFL_RASTER" <<'PY'
import subprocess, sys

svg, colunas, linhas, destino, raster = (
    sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5]))

# 1. SVG -> PNG grande. O rsvg-convert é o mesmo renderizador que o delegado
#    `svg =>` do ImageMagick chama; usá-lo direto tira a dúvida de qual dos dois
#    (MSVG interno ou librsvg) atendeu.
png = subprocess.run(["rsvg-convert", "-w", str(raster), "-h", str(raster), svg],
                     check=True, capture_output=True).stdout

# 2. PNG -> grade de pixels em TEXTO. Sem PIL: o `txt:` do ImageMagick é ASCII,
#    uma linha por pixel, com `#RRGGBBAA` no meio. O `!` do -resize é
#    deliberado: a imagem é quadrada e a grade não é (2 pixels por célula, e a
#    célula não é 1:2), então a proporção TEM de ser forçada aqui — é isso que
#    faz o disco sair redondo na tela dela.
larg, alt = colunas, linhas * 2
txt = subprocess.run(
    ["convert", "png:-", "-alpha", "on", "-filter", "Lanczos",
     "-resize", "%dx%d!" % (larg, alt), "-depth", "8", "txt:-"],
    input=png, check=True, capture_output=True).stdout.decode()

px = {}
for l in txt.splitlines():
    if l.startswith("#") or ":" not in l:
        continue
    pos, resto = l.split(":", 1)
    x, y = (int(v) for v in pos.split(","))
    h = resto.split("#", 1)[1].split()[0]
    px[(x, y)] = tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))

# LIMIAR DE ALFA: 128. A borda do disco é antialiasada, e sem um corte cada
# pixel de meia transparência viraria cor cheia — o disco ganharia uma auréola
# de um pixel na cor errada sobre o fundo do terminal.
LIMIAR = 128
VAZIO = (0, 0, 0, 0)

partes = []
for ly in range(linhas):
    # Cada linha recomeça do zero: sem isso o estado vazaria de uma linha para a
    # outra e um `.ansi` cortado pela metade desenharia lixo colorido.
    fg = bg = "reset"
    linha = ["\x1b[0m"]
    for x in range(larg):
        cima, baixo = px.get((x, ly * 2), VAZIO), px.get((x, ly * 2 + 1), VAZIO)
        oc, ob = cima[3] >= LIMIAR, baixo[3] >= LIMIAR
        if oc and ob:
            novo_fg, novo_bg, ch = cima[:3], baixo[:3], "▀"
        elif oc:
            novo_fg, novo_bg, ch = cima[:3], None, "▀"
        elif ob:
            novo_fg, novo_bg, ch = baixo[:3], None, "▄"
        else:
            # Célula vazia: só o FUNDO importa. Não mexer no foreground poupa
            # uma sequência por pixel transparente — e são muitos.
            novo_fg, novo_bg, ch = fg, None, " "
        if novo_bg != bg:
            linha.append("\x1b[49m" if novo_bg is None
                         else "\x1b[48;2;%d;%d;%dm" % novo_bg)
            bg = novo_bg
        if novo_fg != fg:
            linha.append("\x1b[38;2;%d;%d;%dm" % novo_fg)
            fg = novo_fg
        linha.append(ch)
    linha.append("\x1b[0m")
    partes.append("".join(linha))

with open(destino, "w", encoding="utf-8") as f:
    f.write("\n".join(partes) + "\n")
PY
}

# --- escrita: temporário no diretório de DESTINO (TRAVA 2) -------------------
# O `meow_escrever` não serve aqui: ele recebe o conteúdo como argumento, e este
# conteúdo é um arquivo de 20 KB cheio de ESC — passá-lo por `$( )` e por
# `printf '%s'` é pedir para o shell comer byte. Segue-se o mesmo caminho do
# `som.sh`: escreve-se com `mv`, e por isso o conferidor compara com `cmp`.
_ffl_instalar() {
  local svg colunas linhas tmp
  svg="$(_ffl_svg)"; colunas="$FASTFETCH_LOGO_COLUNAS"; linhas="$(_ffl_linhas)"

  [ -f "$svg" ] || { meow_erro "não achei o SVG '$svg'"; return "$MEOW_ERRO"; }
  meow_destino_permitido "$FFL_ALVO" || return "$MEOW_ERRO"

  if meow_seco; then
    tmp="$(mktemp -p "${TMPDIR:-/tmp}" ".meow-ffl.XXXXXX")" || return "$MEOW_ERRO"
    if ! _ffl_gerar "$tmp" "$svg" "$colunas" "$linhas"; then
      rm -f "$tmp"; meow_erro "falha ao converter '$svg' para ANSI"; return "$MEOW_ERRO"
    fi
    if [ -f "$FFL_ALVO" ] && cmp -s "$tmp" "$FFL_ALVO"; then
      rm -f "$tmp"; return "$MEOW_OK"
    fi
    rm -f "$tmp"; meow_muda "mudaria $FFL_ALVO"; return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$FFL_BASE" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$FFL_BASE" ".meow-ffl.XXXXXX")" || return "$MEOW_ERRO"
  if ! _ffl_gerar "$tmp" "$svg" "$colunas" "$linhas"; then
    rm -f "$tmp"; meow_erro "falha ao converter '$svg' para ANSI"; return "$MEOW_ERRO"
  fi
  if [ -f "$FFL_ALVO" ] && cmp -s "$tmp" "$FFL_ALVO"; then
    rm -f "$tmp"; return "$MEOW_OK"          # regra 5: idêntico, não reescreve
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$FFL_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  meow_manifesto_registrar "$FFL_ALVO"
  return "$MEOW_DIVERGENTE"
}

# --- leitura do config.jsonc DELA -------------------------------------------
# JSONC não é JSON: tem comentários. E um `sed 's|//.*||'` ingênuo QUEBRA este
# arquivo em particular, porque a primeira linha dele é
# `"$schema": "https://github.com/..."` — o `//` está DENTRO de uma string. Daí a
# tira-comentários abaixo respeitar aspas e escapes.
#
# Devolve, em três linhas: `type`, `source` (com `~` expandido) e a contagem de
# módulos com `key` própria. A contagem é o critério de aceite da sprint ("os
# módulos em português continuam intactos") e serve de alarme se alguém, algum
# dia, colar o patch por cima do arquivo inteiro em vez de trocar duas chaves.
_ffl_ler_conf() {
  [ -f "$FFL_CONF_DELA" ] || return 1
  python3 - "$FFL_CONF_DELA" <<'PY'
import json, os, sys

bruto = open(sys.argv[1], encoding="utf-8").read()
saida, i, n, dentro, escapa = [], 0, len(bruto), False, False
while i < n:
    c = bruto[i]
    if dentro:
        saida.append(c)
        if escapa:      escapa = False
        elif c == "\\": escapa = True
        elif c == '"':  dentro = False
        i += 1
    elif c == '"':
        dentro = True; saida.append(c); i += 1
    elif c == "/" and i + 1 < n and bruto[i + 1] == "/":
        while i < n and bruto[i] != "\n": i += 1
    elif c == "/" and i + 1 < n and bruto[i + 1] == "*":
        i += 2
        while i + 1 < n and not (bruto[i] == "*" and bruto[i + 1] == "/"): i += 1
        i += 2
    else:
        saida.append(c); i += 1

try:
    d = json.loads("".join(saida))
except Exception as e:
    print("erro\t%s" % e); print(""); print("0"); sys.exit(0)

logo = d.get("logo") or {}
fonte = logo.get("source") or ""
if fonte.startswith("~"):
    fonte = os.path.expanduser(fonte)
mods = d.get("modules") or []
chaves = [m.get("key") for m in mods if isinstance(m, dict) and m.get("key")]
print(logo.get("type") or "")
print(fonte)
print(len(chaves))
PY
}

# 0 = o config.jsonc já aponta para o nosso .ansi · 1 = não aponta · 2 = não deu
# para ler. Imprime sempre uma linha dizendo o que viu.
_ffl_fronteira() {
  local dados tipo fonte nchaves
  if ! dados="$(_ffl_ler_conf 2>/dev/null)"; then
    meow_aviso "não achei $FFL_CONF_DELA — nada a conferir do lado da Aurora"
    return 2
  fi
  tipo="$(printf '%s' "$dados"  | sed -n '1p')"
  fonte="$(printf '%s' "$dados" | sed -n '2p')"
  nchaves="$(printf '%s' "$dados" | sed -n '3p')"
  case "$tipo" in
    erro*) meow_aviso "não consegui interpretar o config.jsonc dela: $tipo"
           return 2 ;;
  esac

  meow_info "config.jsonc dela: logo.type=\"$tipo\" logo.source=\"${fonte:-<vazio>}\""
  meow_info "  módulos com chave própria (as em português): $nchaves"

  if [ "$fonte" = "$FFL_ALVO" ] && [ "$tipo" = "file-raw" ]; then
    meow_ok "o config.jsonc dela já aponta para a Coquinha"
    return 0
  fi
  if [ "$fonte" = "$FFL_ALVO" ]; then
    meow_aviso "aponta para a Coquinha, mas com logo.type=\"$tipo\" — o certo é \"file-raw\""
    return 1
  fi
  return 1
}

_ffl_patch_texto() {
  cat <<TXT
  "logo": {
    "type": "file-raw",
    "source": "~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")",
    "padding": { "top": 6, "right": 4, "left": 0 }
  },
TXT
}

cmd_patch() {
  meow_info "cole isto NO LUGAR do bloco \"logo\" de $FFL_CONF_DELA"
  meow_info "(o arquivo é da Aurora — symlink para ~/.config/zsh/fastfetch/;"
  meow_info " este script não escreve nele, nem com sudo, nem por engano)"
  printf '\n'
  _ffl_patch_texto
  printf '\n'
  meow_info "o \"padding\" é o que já está lá e NÃO precisa mudar: com 6 linhas"
  meow_info "  de recuo o logo de $( _ffl_linhas ) linhas fica centrado no bloco de módulos"
  meow_info "cópia pronta no repositório: src/fastfetch/config-logo.jsonc.sugestao"
  return "$MEOW_OK"
}

cmd_aplicar() {
  local rc rcf
  [ "$FASTFETCH_LOGO" = "sim" ] || {
    meow_pula "FASTFETCH_LOGO=\"$FASTFETCH_LOGO\" no meow.conf — o logo do fastfetch fica como está"
    return "$MEOW_OK"; }
  meow_tem python3       || { meow_erro "falta python3";                 return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem rsvg-convert  || { meow_erro "falta rsvg-convert (librsvg2-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem convert       || { meow_erro "falta convert (imagemagick)";   return "$MEOW_SEM_DEPENDENCIA"; }

  _ffl_instalar; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"

  if [ "$rc" = "$MEOW_DIVERGENTE" ] && meow_seco; then
    meow_muda "geraria o(a) $FASTFETCH_LOGO_GATO em $FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células em $FFL_ALVO"
  elif [ "$rc" = "$MEOW_DIVERGENTE" ]; then
    meow_muda "$FASTFETCH_LOGO_GATO em ANSI ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células) em $FFL_ALVO"
    meow_info "para ver: scripts/fastfetch_logo.sh ver"
  else
    meow_ok "o logo ANSI já estava gerado"
  fi

  _ffl_fronteira; rcf=$?
  if [ "$rcf" = "1" ]; then
    printf '\n'
    meow_aviso "o fastfetch ainda NÃO vai mostrar a Coquinha: falta uma troca de"
    meow_aviso "  duas chaves no config.jsonc, que é da Aurora e não é nosso."
    printf '\n'
    _ffl_patch_texto
    printf '\n'
    meow_registrar "fastfetch_logo.sh aplicar rc=$rc fronteira=pendente"
    # O 1 VENCE O 4 QUANDO ESTA PASSAGEM ESCREVEU DE VERDADE. Devolver 4 aqui
    # esconderia do resumo do `install.sh` (e da notificação do doctor) um
    # arquivo que ACABOU de nascer — mentira de relatório na direção contrária à
    # do `midia_build`. Só quando não houve nada a escrever o código vira 4, que
    # é o "não há conserto nosso possível" do cabeçalho: aí o timer das 5h passa
    # todo dia sem pendurar "o auto-reparo corrigiu" na tela dela.
    [ "$rc" = "$MEOW_DIVERGENTE" ] && return "$MEOW_DIVERGENTE"
    return 4
  fi

  meow_registrar "fastfetch_logo.sh aplicar rc=$rc"
  return "$rc"
}

cmd_conferir() {
  local rc rcf
  [ "$FASTFETCH_LOGO" = "sim" ] || {
    meow_pula "FASTFETCH_LOGO=\"$FASTFETCH_LOGO\" no meow.conf — nada a conferir"
    return "$MEOW_OK"; }
  meow_tem python3      || { meow_erro "falta python3";                     return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem rsvg-convert || { meow_erro "falta rsvg-convert (librsvg2-bin)"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem convert      || { meow_erro "falta convert (imagemagick)";       return "$MEOW_SEM_DEPENDENCIA"; }

  if [ ! -f "$FFL_ALVO" ]; then
    meow_muda "logo ANSI ausente ($FFL_ALVO)"
    return "$MEOW_DIVERGENTE"
  fi

  MEOW_SECO=1 _ffl_instalar >/dev/null; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && return "$rc"
  if [ "$rc" != "$MEOW_OK" ]; then
    meow_muda "logo ANSI divergente do SVG/tamanho pedidos"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "logo ANSI conforme ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células)"

  _ffl_fronteira; rcf=$?
  case "$rcf" in
    0) return "$MEOW_OK" ;;
    2) return "$MEOW_OK" ;;   # sem config dela para conferir; o .ansi está certo
    *) meow_pula "o config.jsonc é da Aurora — 'fastfetch_logo.sh patch' mostra o que colar"
       return 4 ;;
  esac
}

# Imprime o arquivo como ele é. Sem `cat -v`, sem tradução: é o teste honesto de
# que os bytes que o fastfetch vai ler desenham a Coquinha.
cmd_ver() {
  [ -f "$FFL_ALVO" ] || { meow_erro "não há logo gerado — rode 'aplicar' antes"; return "$MEOW_DIVERGENTE"; }
  printf '\n'
  cat "$FFL_ALVO"
  printf '\n'
  meow_info "$FFL_ALVO — $FASTFETCH_LOGO_COLUNAS colunas x $(_ffl_linhas) linhas"
  meow_info "no lugar, com os módulos dela: fastfetch --logo-type file-raw --logo $FFL_ALVO"
  return "$MEOW_OK"
}

cmd_remover() {
  if [ ! -f "$FFL_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  meow_seco && { meow_muda "removeria $FFL_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$FFL_ALVO"
  # Só apaga o diretório se ele ficar vazio, e só o NOSSO: o
  # `~/.local/share/meowsystem` pode hospedar outra coisa amanhã.
  rmdir "$FFL_BASE" 2>/dev/null
  meow_muda "logo ANSI removido — o fastfetch volta ao logo padrão dele"
  meow_aviso "o config.jsonc dela continua como está: se ele aponta para este"
  meow_aviso "  arquivo, o fastfetch cai no logo da distribuição (não quebra nada)"
  meow_registrar "fastfetch_logo.sh remover"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  ver)      cmd_ver ;;
  patch)    cmd_patch ;;
  remover)  cmd_remover ;;
  *) meow_erro "uso: fastfetch_logo.sh {aplicar|conferir|ver|patch|remover}"; exit "$MEOW_ERRO" ;;
esac
