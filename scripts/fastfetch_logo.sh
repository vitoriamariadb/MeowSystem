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

# --- 01/09/2026: O GATO DO TERMINAL PASSA A SEGUIR O RELÓGIO ------------------
# Ela pediu o mesmo que o dock: Coquinha de dia, Mimir de noite. Aqui é MUITO
# mais barato que lá — o `fastfetch` lê o arquivo do logo a cada execução, não
# guarda nada, e não há painel para reciclar. Trocar o conteúdo do arquivo é o
# recurso inteiro.
#
#   espelho (padrão) o terminal mostra o gato que o dock NÃO está mostrando.
#   hora    o terminal segue o relógio igual ao dock — os dois iguais.
#   fixo    `FASTFETCH_LOGO_GATO` vence sempre — o comportamento até 31/08.
#
# --- O MODO `espelho`, E POR QUE ELE É UMA REGRA E NÃO QUATRO VALORES --------
# O PEDIDO DELA, 01/09/2026: *"mimir de dia, e durante o dia no terminal fica a
# coquinha. coquinha de noite e durante a noite o mimir fica no terminal. pra
# sempre termos os 2?"*
#
# Dava para atender fixando quatro chaves — `LOGO_DIA=mimir`,
# `LOGO_NOITE=coquinha`, `FASTFETCH_LOGO_DIA=coquinha`,
# `FASTFETCH_LOGO_NOITE=mimir`. Funcionaria HOJE e envelheceria no primeiro dia
# em que ela trocasse o gato do dock: as quatro chaves são dois pares que
# precisam ser mantidos opostos à mão, e nada avisaria se eles deixassem de ser.
# Um dia os dois mostrariam o mesmo gato e o "sempre termos os 2" viraria
# mentira em silêncio.
#
# A REGRA É "O OUTRO", e ela se mantém sozinha. Trocar `LOGO_DIA` no meow.conf
# passa a bastar: o terminal segue, invertido, sem tocar em mais nada.
#
# DE ONDE SAI "O QUE O DOCK ESTÁ MOSTRANDO": do ARQUIVO no tema de ícones, não
# de um cálculo paralelo. Recomputar a fase aqui seria uma SEGUNDA opinião sobre
# a mesma pergunta — e num dia de borda (o tique das 18:00 pegando um dos dois
# antes do outro) as duas discordariam. Lendo o disco, o pior caso é o terminal
# ficar um tique atrás, nunca contradizer o que ela vê.
#
# COM MAIS DE DOIS GATOS NO ACERVO, "o outro" vira "o SEGUINTE na ordem
# alfabética, em círculo". Com dois, que é o caso dela, as duas definições são a
# mesma coisa. É o mesmo critério de ordem que o `logo.sh` usa para girar.
#
# O ARQUIVO PASSA A SE CHAMAR `gato.ansi`, E O NOME IMPORTA
#   No modo `fixo` o destino continua `<nome-do-gato>.ansi`, e um arquivo
#   chamado `coquinha.ansi` contém a Coquinha. No modo `hora` o conteúdo muda
#   duas vezes por dia: manter o nome `coquinha.ansi` faria um arquivo mentir
#   sobre si mesmo metade do tempo, e quem fosse depurar leria o nome e pararia
#   ali. `gato.ansi` diz o que é — o gato da vez.
FASTFETCH_LOGO_MODO="${FASTFETCH_LOGO_MODO:-espelho}"
FASTFETCH_LOGO_DIA="${FASTFETCH_LOGO_DIA:-${LOGO_DIA:-coquinha}}"
FASTFETCH_LOGO_NOITE="${FASTFETCH_LOGO_NOITE:-${LOGO_NOITE:-mimir}}"

# --- A FRONTEIRA MUDOU DE LADO, E ISSO É DECISÃO CONSCIENTE -------------------
# ATÉ 31/08/2026 este script SÓ LIA o `config.jsonc` dela e imprimia o patch,
# saindo 4. O cabeçalho explicava: o arquivo é symlink para
# `~/.config/zsh/fastfetch/`, território do Ritual da Aurora, recusado pela
# TRAVA 1 do `lib/comum.sh`, e com auto-commit a cada 10 min no repo PRIVADO dela.
#
# O QUE MUDOU
#   1. Ela pediu, em 01/09/2026, que tudo fosse "idempotente e autoajustável de
#      forma que ele sobreviva sempre". Um recurso cuja última etapa é um humano
#      colando JSON à mão não sobrevive a nada.
#   2. O modo `hora` torna a pendência PERMANENTE em vez de pontual: sem a troca
#      da linha, o terminal fica com a Coquinha das 18h às 7h, todo dia, para
#      sempre — e o script diria "gerei o mimir" enquanto a tela mostra a
#      coquinha. Aviso que se repete todo dia é aviso que se aprende a ignorar.
#   3. Ela já autorizou a direção em 05/08/2026: "o Andromeda pode ser corrigido
#      pelo MeowSystem". A regra que fica é a mesma de lá — corrigir vale quando
#      o outro lado está objetivamente atrás, e NUNCA em silêncio.
#
# AS QUATRO GUARDAS, sem as quais isto seria exatamente o que a TRAVA 1 impede
#   1. UMA LINHA, NUNCA O ARQUIVO. A escrita é cirúrgica: troca `logo.source` (e
#      `logo.type`, se estiver errado) e mais nada. Comentários, os módulos em
#      português, a ordem das chaves e o `padding` saem intactos — e o
#      `_ffl_ler_conf` conta os módulos com chave própria justamente para
#      acusar o dia em que alguém colar por cima do arquivo inteiro.
#   2. BACKUP ANTES, sempre, em `$MEOW_ESTADO/backups/`. É o mesmo idioma do
#      `meow_backup_sistema`, e pelo mesmo motivo: sem ele, "desfazer" seria
#      reinstalar o repo dela.
#   3. EM VOZ ALTA. Nenhuma escrita aqui acontece sem uma linha na tela dizendo
#      qual arquivo de qual vizinho foi tocado.
#   4. `FASTFETCH_LOGO_CONF="nao"` volta ao comportamento antigo (só imprime o
#      patch e sai 4), sem editar script nenhum.
#
# E O SELF-HEAL NÃO DISPUTA ESTA LINHA — MEDIDO EM 01/09/2026
#   `grep -n fastfetch /usr/local/sbin/ritual-aurora-self-heal.sh` devolve TRÊS
#   linhas, todas sobre o SYMLINK `~/.config/fastfetch -> ~/.config/zsh/fastfetch`
#   (self-heal:1585-1587). O CONTEÚDO do `config.jsonc` não é escrito por ele em
#   ponto nenhum. Sem isso, isto aqui seria ping-pong de hora em hora — os dois
#   donos da mesma linha, que é o defeito que este projeto mais persegue.
FASTFETCH_LOGO_CONF="${FASTFETCH_LOGO_CONF:-sim}"

# LARGURA EM COLUNAS. 40 não é chute: é a largura do logo `pop` que este
# substitui (medido — o bloco de informação continua começando na MESMA coluna,
# então nada do texto dela se desloca). Mexer aqui é seguro.
FASTFETCH_LOGO_COLUNAS="${FASTFETCH_LOGO_COLUNAS:-40}"

# ALTURA EM LINHAS — nova em 06/09/2026, e ela desmente o que este arquivo dizia
# antes ("a altura não se configura").
#
#   Vazio (o padrão) continua sendo o comportamento de sempre: a altura sai de
#   `colunas / FASTFETCH_LOGO_CELULA`, e o gato sai redondo.
#
#   Com número, ela manda. Isso permite um gato mais alto numa tela que tem
#   altura sobrando — mas sair da proporção da célula DEFORMA o desenho, porque
#   o `-resize LxA!` do conversor (linha ~419) estica sem perguntar. Então o
#   `aplicar` mede a distância da proporção e AVISA quando ela passa de 12%. Um
#   gato oval por escolha dela é escolha; um gato oval calado é defeito.
FASTFETCH_LOGO_LINHAS="${FASTFETCH_LOGO_LINHAS:-}"

# PROPORÇÃO ALTURA/LARGURA DA CÉLULA — 23,00 / 9,00 px, medido no cosmic-term
# dela (ver medição 2 do cabeçalho). É CONSTANTE de propósito: medir isto em
# tempo de execução tornaria o arquivo diferente conforme a janela, e o
# `conferir` (que regera e compara) acusaria divergência eterna. Quem mudar de
# fonte muda este número aqui, uma vez.
FASTFETCH_LOGO_CELULA="${FASTFETCH_LOGO_CELULA:-2.556}"

# AS DUAS MEDIDAS DO ESPAÇO EM VOLTA DO GATO, que até 06/09/2026 estavam
# cravadas no `config.jsonc` dela e só se mudavam abrindo o arquivo:
#   QUEBRAS  linhas em branco antes do desenho  (`padding.top`)
#   RECUO    colunas entre o desenho e o texto  (`padding.right`, no tabular)
FASTFETCH_LOGO_QUEBRAS="${FASTFETCH_LOGO_QUEBRAS:-auto}"
FASTFETCH_LOGO_RECUO="${FASTFETCH_LOGO_RECUO:-3}"

# O TÍTULO DO BLOCO. Vazio = o fastfetch decide. Ver `meow.conf.exemplo`.
FASTFETCH_TITULO="${FASTFETCH_TITULO:-}"

# ONDE CADA LINHA DE INFORMAÇÃO COMEÇA: `tabular` (o único que o fastfetch sabe
# fazer) ou `contorno` (o texto abraça a silhueta do gato). O `contorno` é
# composto por fora — ver `_ffl_alinhamento` e `scripts/fastfetch_alinhar.py`.
FASTFETCH_LOGO_ALINHAR="${FASTFETCH_LOGO_ALINHAR:-tabular}"

# Resolução em que o SVG é rasterizado antes de encolher. Alto de propósito: a
# redução por Lanczos a partir de 2048 px é o que preserva o traço do focinho.
FFL_RASTER=2048

FFL_BASE="$HOME/.local/share/meowsystem/fastfetch"

# --- QUEM É O GATO DA VEZ, E ONDE ELE MORA ----------------------------------
# No modo `hora` a janela vem do `lib/noite.sh` — a MESMA que decide o gato do
# dock. Duas noites nesta máquina é o que aquele arquivo existe para impedir.

# O gato que está NO BOTÃO DO DOCK agora, pelo arquivo — ou vazio se não der
# para dizer. Compara por conteúdo (`cmp`), não por nome: o arquivo do tema de
# ícones se chama `com.system76.CosmicPanelAppButton.svg` e não carrega o nome
# do gato em lugar nenhum.
_ffl_gato_do_dock() {
  local tema="${NOME_TEMA_ICONES:-MeowSystem-Icons}" svg botao
  botao="$HOME/.local/share/icons/$tema/scalable/apps/com.system76.CosmicPanelAppButton.svg"
  [ -f "$botao" ] || return 1
  for svg in "$MEOW_RAIZ/assets/gatos"/*.svg; do
    [ -f "$svg" ] || continue
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    cmp -s "$svg" "$botao" && { basename "${svg%.svg}"; return 0; }
  done
  return 1
}

# O SEGUINTE no acervo, em círculo. Com dois gatos, é "o outro".
_ffl_o_outro() {
  local atual="$1" i
  local -a nomes=()
  while IFS= read -r svg; do
    case "$(basename "$svg")" in *-symbolic.svg) continue ;; esac
    nomes+=("$(basename "${svg%.svg}")")
  done < <(find "$MEOW_RAIZ/assets/gatos" -maxdepth 1 -name '*.svg' 2>/dev/null | LC_ALL=C sort)
  [ "${#nomes[@]}" -ge 2 ] || return 1
  for i in "${!nomes[@]}"; do
    [ "${nomes[$i]}" = "$atual" ] && { printf '%s' "${nomes[$(( (i + 1) % ${#nomes[@]} ))]}"; return 0; }
  done
  return 1
}

FFL_FASE=""; FFL_PORQUE=""
case "$FASTFETCH_LOGO_MODO" in
  espelho)
    FFL_ALVO="$FFL_BASE/gato.ansi"
    _dock="$(_ffl_gato_do_dock || true)"
    _outro=""
    [ -n "$_dock" ] && _outro="$(_ffl_o_outro "$_dock" || true)"
    if [ -n "$_outro" ]; then
      FASTFETCH_LOGO_GATO="$_outro"; FFL_PORQUE="o dock está com $_dock"
    else
      # CAIR PARA A FASE, e não para o primeiro do acervo. Isto acontece na
      # PRIMEIRA instalação (o botão do dock ainda não existe) e num acervo de
      # um gato só. Cair na fase invertida mantém a promessa "os dois na tela"
      # assim que houver dois; cair no primeiro do acervo daria os dois iguais.
      # shellcheck source=../lib/noite.sh
      . "$MEOW_RAIZ/lib/noite.sh"
      if meow_e_noite; then FFL_FASE="noite"; FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_DIA}"
      else                  FFL_FASE="dia";   FASTFETCH_LOGO_GATO="${FASTFETCH_LOGO_NOITE}"; fi
      FFL_PORQUE="não li o botão do dock; espelhei a fase ($FFL_FASE)"
    fi
    unset _dock _outro ;;
  hora)
    # shellcheck source=../lib/noite.sh
    . "$MEOW_RAIZ/lib/noite.sh"
    if meow_e_noite; then FFL_FASE="noite"; FASTFETCH_LOGO_GATO="$FASTFETCH_LOGO_NOITE"
    else                  FFL_FASE="dia";   FASTFETCH_LOGO_GATO="$FASTFETCH_LOGO_DIA"; fi
    FFL_PORQUE="modo hora, $FFL_FASE"
    FFL_ALVO="$FFL_BASE/gato.ansi" ;;
  *)
    FFL_ALVO="$FFL_BASE/$(basename "${FASTFETCH_LOGO_GATO%.svg}").ansi" ;;
esac

# O config.jsonc DELA. Só é LIDO — nunca aberto para escrita, em nenhum caminho
# deste arquivo.
FFL_CONF_DELA="$HOME/.config/fastfetch/config.jsonc"

_ffl_svg() {
  case "$FASTFETCH_LOGO_GATO" in
    */*|*.svg) printf '%s' "$FASTFETCH_LOGO_GATO" ;;
    *)         printf '%s' "$MEOW_RAIZ/assets/gatos/$FASTFETCH_LOGO_GATO.svg" ;;
  esac
}

# A ALTURA, EM LINHAS. A chave vence; vazia, a proporção da célula decide.
#
# TODA A ALTURA PASSA POR AQUI, e isso é o que faz o carimbo continuar honesto:
# ele guarda `<gato> <colunas> <linhas>`, e as linhas saem desta função. Uma
# chave de altura que entrasse por qualquer outro caminho deixaria o carimbo
# dizendo "já está certo" sobre um arquivo que não corresponde ao conf — e o
# `meow-gato.timer`, que roda de cinco em cinco minutos, repetiria a mentira
# para sempre.
_ffl_linhas() {
  case "$FASTFETCH_LOGO_LINHAS" in
    ''|*[!0-9]*)
      awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" \
          'BEGIN { n = int(c / r + 0.5); if (n < 1) n = 1; print n }' ;;
    *) [ "$FASTFETCH_LOGO_LINHAS" -ge 1 ] 2>/dev/null \
         && printf '%s' "$FASTFETCH_LOGO_LINHAS" || printf '1' ;;
  esac
}

# Quanto o tamanho pedido se afasta da proporção da célula, em por cento. É o
# número que o `aplicar` usa para decidir se avisa — ver o bloco de
# `FASTFETCH_LOGO_LINHAS` lá em cima.
_ffl_desvio() {
  awk -v c="$FASTFETCH_LOGO_COLUNAS" -v r="$FASTFETCH_LOGO_CELULA" -v l="$(_ffl_linhas)" \
      'BEGIN { ideal = c / r; if (ideal <= 0) { print 0; exit }
               d = (l - ideal) / ideal * 100; if (d < 0) d = -d; printf "%d", d + 0.5 }'
}

# O CARIMBO, EM UM LUGAR SÓ. Ele era montado por `printf` em três pontos deste
# arquivo, e cada campo novo tinha de ser lembrado nos três — a receita para o
# `conferir` dizer "conforme" sobre um desenho que mudou. Agora quem acrescenta
# campo acrescenta aqui, e os três pontos acompanham.
#
# Os campos são TUDO O QUE O GERADOR CONSOME: trocar qualquer um deles tem de
# regerar o `.ansi`. `blocos` entrou junto com a altura, e ele faltava desde
# sempre — mudar `FASTFETCH_LOGO_BLOCOS` de `auto` para `quadrante` mudava o
# desenho e o carimbo dizia que estava tudo certo.
_ffl_carimbo_texto() {
  printf '%s %s %s %s' "$(basename "${FASTFETCH_LOGO_GATO%.svg}")" \
    "$FASTFETCH_LOGO_COLUNAS" "$(_ffl_linhas)" "$(_ffl_blocos)"
}

# O alinhamento pedido, com o desconhecido caindo no que sempre valeu.
_ffl_alinhamento() {
  case "$FASTFETCH_LOGO_ALINHAR" in
    contorno|degraus|crescente|reto) printf '%s' "$FASTFETCH_LOGO_ALINHAR" ;;
    *)                               printf 'tabular' ;;
  esac
}

# O `meow-fetch` precisa estar no cano? Só quando o alinhamento não é o do
# fastfetch. O título não entra nesta conta: ele é escrito no `config.jsonc` e
# vale nos dois caminhos.
_ffl_quer_meow_fetch() {
  [ "$(_ffl_alinhamento)" != "tabular" ]
}

# QUANTAS LINHAS O BLOCO DE INFORMAÇÃO OCUPA, medido rodando o fastfetch sem
# logo. É o que o `auto` das quebras precisa saber, e não há como derivá-lo do
# conf: quem decide são os módulos do `config.jsonc` dela, que são dela.
#
# O `--pipe false` importa: com o cano detectado o fastfetch some com as cores
# E com algumas linhas, e a conta sairia curta.
#
# MEMOIZADO, e não por elegância: uma passagem de `aplicar` que precisa
# consertar o config.jsonc chamava isto SEIS vezes, e o `conferir` do doctor,
# duas — cada uma um `fastfetch` inteiro. Pior: o `logo.sh` roda
# `FFL_FUNDO=1 LOG_NIVEL=silencioso fastfetch_logo.sh aplicar` de cinco em cinco
# minutos (`FASTFETCH_LOGO_MODO="hora"`), e o `silencioso` não evita nada — a
# substituição de comando acontece na EXPANSÃO DO ARGUMENTO do `meow_info`,
# antes de o `meow_quieto` poder devolver. O cabeçalho do `meow-gato.timer`
# crava "0,05 s por tique", que era verdade antes de a fronteira consultar o
# fastfetch.
_ffl_linhas_do_texto() {
  if [ -z "${FFL_TEXTO_LINHAS:-}" ]; then
    if meow_tem fastfetch; then
      FFL_TEXTO_LINHAS="$(fastfetch --logo none --pipe false 2>/dev/null | wc -l)"
    else
      FFL_TEXTO_LINHAS=0
    fi
  fi
  printf '%s' "$FFL_TEXTO_LINHAS"
}

# O `padding.top` que o config.jsonc deve levar. Com `auto`, é a metade da
# sobra entre a altura do gato e a altura do texto — a mesma conta que o
# `fastfetch_alinhar.py` faz do lado do contorno, para os dois alinhamentos
# ficarem centrados do mesmo jeito.
_ffl_quebras() {
  case "$FASTFETCH_LOGO_QUEBRAS" in
    ''|auto)
      awk -v g="$(_ffl_linhas)" -v t="$(_ffl_linhas_do_texto)" \
          'BEGIN { n = int((t - g) / 2); if (n < 0) n = 0; print n }' ;;
    *[!0-9]*) printf '6' ;;
    *) printf '%s' "$FASTFETCH_LOGO_QUEBRAS" ;;
  esac
}

# --- QUAL BLOCO A FONTE DELA SABE DESENHAR -----------------------------------
# 01/09/2026, pedido dela depois de ver o gato do terminal: "outra fonte
# melhoraria?" e "o projeto precisa ser mais inteligente pra se adaptar nesse
# sentido". As duas perguntas têm a mesma resposta, e ela é medível.
#
# O TETO DE DETALHE DE UM DESENHO FEITO DE LETRAS é quantos subpixels cabem numa
# célula, e isso depende do que a FONTE tem:
#
#   half   `▀▄`        1x2 por célula   qualquer fonte
#   quad   `▘▝▖▗▚▞…`   2x2              qualquer fonte monoespaçada séria
#   sext   `🬀🬁🬂…`      2x3              Symbols for Legacy Computing (Unicode 13)
#
# MEDIDO NA MÁQUINA DELA, hoje: a `JetBrainsMono Nerd Font Mono` NÃO tem os
# sextantes — renderizados com ela, os glifos saem em branco (média de pixel
# 0.000, contra 0.234 do `▘` e 0.936 do `█`). Varri as fontes instaladas: NENHUMA
# tem. Por isso o padrão cai em `quad`, e é isso que ela vê hoje.
#
# ENTÃO POR QUE O CÓDIGO DOS SEXTANTES EXISTE: porque a fonte do terminal é
# escolha dela e muda. Cascadia Code nova, JuliaMono e Iosevka têm os glifos; no
# dia em que ela trocar, o gato ganha 50% de detalhe vertical SOZINHO, sem
# ninguém lembrar de vir aqui. É a mesma disciplina do resto do projeto: medir a
# máquina e escolher, em vez de chumbar o que era verdade um dia.
#
# A GUARDA CONTRA O FALSO POSITIVO: existir o glifo não basta — se ele vier de
# uma fonte de FALLBACK com métrica diferente, o mosaico abre frestas. Por isso
# o teste é feito no ARQUIVO da fonte do terminal (via `fc-match`), não no nome:
# o fallback do fontconfig não entra na conta.
#
# `FASTFETCH_LOGO_BLOCOS` no meow.conf: auto (padrão) · quadrante · sextante.
_ffl_fonte_arquivo() {
  local nome
  nome="$(sed -n 's/^"\(.*\)"$/\1/p' "$HOME/.config/cosmic/com.system76.CosmicTerm/v1/font_name" 2>/dev/null)"
  [ -n "$nome" ] || nome="${FASTFETCH_LOGO_FONTE:-monospace}"
  fc-match -f '%{file}' "$nome:spacing=100" 2>/dev/null
}

_ffl_tem_sextante() {
  meow_tem convert || return 1
  local arq media
  arq="$(_ffl_fonte_arquivo)"
  [ -n "$arq" ] && [ -f "$arq" ] || return 1
  # Um glifo ausente é desenhado como NADA (ou como .notdef vazio) — a média de
  # pixel do rótulo é 0. É o mesmo teste que reprovou a fonte dela hoje, e ele
  # não precisa de fontTools, que não está instalado nesta máquina.
  media="$(convert -background black -fill white -font "$arq" -pointsize 40 \
             label:"🬀" -format "%[fx:mean]" info: 2>/dev/null)"
  case "${media:-0}" in
    0|0.0|0.00*|"") return 1 ;;
    *) return 0 ;;
  esac
}

_ffl_blocos() {
  case "${FASTFETCH_LOGO_BLOCOS:-auto}" in
    quadrante) printf 'quad' ;;
    sextante)  printf 'sext' ;;
    *) if _ffl_tem_sextante; then printf 'sext'; else printf 'quad'; fi ;;
  esac
}

# --- o conversor -------------------------------------------------------------
# DETERMINÍSTICO, que é o que torna o `conferir` possível: gera de novo num
# temporário e compara com o que está no disco. Sem isso toda checagem acusaria
# divergência e o auto-reparo entraria em ping-pong (a lição do `custom_logo_path`).
_ffl_gerar() {
  local destino="$1" svg="$2" colunas="$3" linhas="$4"
  python3 - "$svg" "$colunas" "$linhas" "$destino" "$FFL_RASTER" "$(_ffl_blocos)" <<'PY'
import subprocess, sys

svg, colunas, linhas, destino, raster, blocos = (
    sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), sys.argv[4], int(sys.argv[5]),
    sys.argv[6])
# Quantos subpixels cabem na célula, decidido lá fora por MEDIÇÃO da fonte.
SX, SY = (2, 3) if blocos == "sext" else (2, 2)

# 1. SVG -> PNG grande. O rsvg-convert é o mesmo renderizador que o delegado
#    `svg =>` do ImageMagick chama; usá-lo direto tira a dúvida de qual dos dois
#    (MSVG interno ou librsvg) atendeu.
# O `-a` NÃO É ENFEITE — 01/09/2026. Sem ele, `-w R -h R` estica o desenho para
# encher o quadrado, e o viewBox dos gatos deixou de ser quadrado no dia em que
# ela aumentou o gato dentro do quadro (1030x1079 no Mimir). Medido: o gato saía
# 254 px de largura por 255 de altura onde o certo é 243x255 — 4,5% mais gordo,
# um círculo virando elipse. Com `-a` a proporção é preservada e o que sobra do
# quadrado fica transparente, que é exatamente o que a grade de blocos ignora.
png = subprocess.run(["rsvg-convert", "-a", "-w", str(raster), "-h", str(raster), svg],
                     check=True, capture_output=True).stdout

# 2. PNG -> grade de pixels em TEXTO. Sem PIL: o `txt:` do ImageMagick é ASCII,
#    uma linha por pixel, com `#RRGGBBAA` no meio. O `!` do -resize é
#    deliberado: a imagem é quadrada e a grade não é (2x2 pixels por célula, e a
#    célula não é 1:1), então a proporção TEM de ser forçada aqui — é isso que
#    faz o disco sair redondo na tela dela.
#
# QUATRO PIXELS POR CÉLULA, E NÃO DOIS — 01/09/2026, pedido dela: "não
# conseguimos melhorar a resolução dos meus gatos no terminal?". A versão
# anterior amostrava `colunas x (linhas*2)` = 40x32 e desenhava com `▀`/`▄`
# (meio bloco): um subpixel de 8x8 px na tela dela, que é o serrilhado grosso
# que ela apontou. Com os QUADRANTES do bloco Unicode (▘▝▖▗▚▞▌▐▛▜▙▟) cabem
# QUATRO subpixels por célula, e a amostragem passa a 80x32 — o dobro de
# detalhe horizontal, na MESMA área da tela e sem mexer no layout dela.
#
# POR QUE NÃO SEXTANTES (2x3, que dariam 80x48): MEDIDO na fonte do terminal
# dela. `JetBrainsMonoNerdFontMono-Regular.ttf` não tem os glifos de
# `Symbols for Legacy Computing` (U+1FB00–1FB3B) — renderizados com ela, saem
# em branco (média de pixel 0.000, contra 0.234 do `▘` e 0.936 do `█`). Um
# gato desenhado com caractere ausente vira uma parede de retângulos vazios.
larg, alt = colunas * SX, linhas * SY
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

# OS GLIFOS, INDEXADOS PELA MÁSCARA DE SUBPIXELS
#   O bit `i` é o subpixel `i` na ordem de leitura: esquerda->direita,
#   cima->baixo. Em 2x2, bit0 = superior-esquerdo … bit3 = inferior-direito.
#   Em 2x3 a mesma regra dá seis bits, e é exatamente a convenção do bloco
#   Unicode `Symbols for Legacy Computing`, o que faz a fórmula abaixo ser uma
#   soma e não uma tabela de 60 linhas.
QUAD = " ▘▝▀▖▌▞▛▗▚▐▜▄▙▟█"


def glifo(m, n):
    """O caractere que acende os subpixels de `m`, num mosaico de `n` deles."""
    if n == 4:
        return QUAD[m]
    # 2x3. Os quatro casos fora do bloco 1FB00 são os que a Unicode já tinha:
    # vazio, cheio, e as duas colunas inteiras (que são os meios-blocos).
    if m == 0:
        return " "
    if m == 63:
        return "█"
    if m == 21:      # 0b010101 — coluna esquerda inteira
        return "▌"
    if m == 42:      # 0b101010 — coluna direita inteira
        return "▐"
    i = m - 1 - (1 if m > 21 else 0) - (1 if m > 42 else 0)
    return chr(0x1FB00 + i)


def _media(cores):
    n = len(cores)
    return (sum(c[0] for c in cores) // n,
            sum(c[1] for c in cores) // n,
            sum(c[2] for c in cores) // n)


def _erro(cores, m):
    """Quão longe cada pixel fica da média do seu grupo, na partição `m`."""
    a = [c for i, c in enumerate(cores) if m >> i & 1]
    b = [c for i, c in enumerate(cores) if not (m >> i & 1)]
    total = 0
    for grupo in (a, b):
        if not grupo:
            continue
        med = _media(grupo)
        for c in grupo:
            total += sum((c[k] - med[k]) ** 2 for k in (0, 1, 2))
    return total


N = SX * SY
partes = []
for ly in range(linhas):
    # Cada linha recomeça do zero: sem isso o estado vazaria de uma linha para a
    # outra e um `.ansi` cortado pela metade desenharia lixo colorido.
    fg = bg = "reset"
    linha = ["\x1b[0m"]
    for x in range(colunas):
        celula = [px.get((x * SX + dx, ly * SY + dy), VAZIO)
                  for dy in range(SY) for dx in range(SX)]
        cheios = [i for i, c in enumerate(celula) if c[3] >= LIMIAR]

        if not cheios:
            # Célula vazia: só o FUNDO importa. Não mexer no foreground poupa
            # uma sequência por pixel transparente — e são muitos.
            novo_fg, novo_bg, ch = fg, None, " "
        elif len(cheios) < N:
            # BORDA DO DISCO: o que é transparente TEM de ficar no fundo do
            # terminal, senão o papel de parede dela some atrás de um retângulo.
            # Então aqui a partição não é escolhida — ela é imposta pelo alfa.
            m = sum(1 << i for i in cheios)
            novo_fg, novo_bg, ch = _media([celula[i] for i in cheios]), None, glifo(m, N)
        else:
            # MIOLO OPACO: aí sim há liberdade, e a pergunta é qual partição em
            # dois grupos descreve melhor os subpixels. Testam-se todas (a
            # sólida inclusa, que vence quando são quase iguais) e fica a de
            # menor erro quadrático. Empate resolve pelo menor índice, porque
            # este arquivo PRECISA ser determinístico: o `conferir` gera de novo
            # e compara byte a byte.
            melhor = min(range(1 << N), key=lambda m: (_erro(celula, m), m))
            a = [celula[i] for i in range(N) if melhor >> i & 1]
            b = [celula[i] for i in range(N) if not (melhor >> i & 1)]
            novo_fg = _media(a) if a else _media(b)
            novo_bg = _media(b) if b else _media(a)
            ch = glifo(melhor, N)
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

# --- A GUARDA BARATA, E POR QUE ELA PRECISOU EXISTIR -------------------------
# MEDIDO EM 01/09/2026: um `aplicar` que não muda nada custa 0,37 s — porque
# `_ffl_instalar` gera o ANSI num temporário SEMPRE, só para poder comparar. É o
# preço do determinismo, e estava certo enquanto isto rodava uma vez por
# `install.sh`. Com o `meow-gato.timer` de cinco em cinco minutos passariam a ser
# 288 rasterizações de 2048 px por dia = ~106 s de CPU, para um efeito que
# acontece DUAS vezes.
#
# O CARIMBO GUARDA TUDO O QUE O GERADOR CONSOME, e é por isso que ele é uma
# linha com quatro campos e não só o nome: mudar `FASTFETCH_LOGO_COLUNAS` no
# conf tem de regerar, e um carimbo só com o nome do gato diria "já está certo".
#   <nome-do-gato> <colunas> <linhas> <blocos>
# Quem monta a linha é `_ffl_carimbo_texto`, e é lá que se acrescenta campo.
#
# AS TRÊS PORTAS QUE ATRAVESSAM A GUARDA — sem elas isto vira cache que mente:
#   1. o `.ansi` não existe (alguém apagou, ou é a primeira vez);
#   2. o carimbo não bate (trocou de gato, de largura ou de proporção);
#   3. o SVG é MAIS NOVO que o `.ansi` (ela redesenhou o gato no acervo).
#
# E O `conferir` NÃO USA A GUARDA, DE PROPÓSITO. Ele é o comando do
# `meow-doctor.timer`, roda uma vez por dia e a função dele é justamente
# desconfiar do carimbo: se o conversor mudar de código, ou se alguém editar o
# `.ansi` à mão, quem acusa é ele. Barato no minuto, desconfiado no dia.
_ffl_carimbo() { printf '%s/.gato-atual' "$FFL_BASE"; }
_ffl_ja_esta_certo() {
  local svg="$1" colunas="$2" linhas="$3" querido lido
  [ -f "$FFL_ALVO" ] || return 1
  lido="$(cat "$(_ffl_carimbo)" 2>/dev/null)" || return 1
  querido="$(_ffl_carimbo_texto)"
  [ "$lido" = "$querido" ] || return 1
  [ -f "$svg" ] && [ "$svg" -nt "$FFL_ALVO" ] && return 1
  return 0
}

_ffl_instalar() {
  local svg colunas linhas tmp
  svg="$(_ffl_svg)"; colunas="$FASTFETCH_LOGO_COLUNAS"; linhas="$(_ffl_linhas)"

  [ -f "$svg" ] || { meow_erro "não achei o SVG '$svg'"; return "$MEOW_ERRO"; }
  meow_destino_permitido "$FFL_ALVO" || return "$MEOW_ERRO"

  if [ "${FFL_FUNDO:-0}" = "1" ] && _ffl_ja_esta_certo "$svg" "$colunas" "$linhas"; then
    return "$MEOW_OK"
  fi

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
    rm -f "$tmp"
    # O CARIMBO É REESCRITO MESMO SEM MUDANÇA, e essa linha é o que faz a guarda
    # barata nascer valendo numa máquina que já tinha o `.ansi` no lugar. Sem
    # ela, a primeira rodada depois desta versão passaria pelo caminho caro e a
    # SEGUNDA também — para sempre, porque nada jamais escreveria o carimbo.
    printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
    return "$MEOW_OK"                        # regra 5: idêntico, não reescreve
  fi
  chmod 644 "$tmp"
  mv -f "$tmp" "$FFL_ALVO" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  printf '%s\n' "$(_ffl_carimbo_texto)" > "$(_ffl_carimbo)" 2>/dev/null || true
  meow_manifesto_registrar "$FFL_ALVO"
  _ffl_varrer_orfaos
  return "$MEOW_DIVERGENTE"
}

# --- O QUE SOBROU DO MODO ANTERIOR SAI DO DISCO ------------------------------
# Regra 3 do contrato: reescrever o estado inteiro, nunca acrescentar. Sem isto,
# trocar `FASTFETCH_LOGO_MODO` de `fixo` para `hora` deixaria o `coquinha.ansi`
# de 20 KB parado ali para sempre — um arquivo que ninguém lê, que ninguém sabe
# de onde veio, e que ainda por cima PARECE a fonte do logo para quem for
# depurar. É o mesmo motivo pelo qual o `logo.sh` apaga os `meow-*.svg` que
# saíram do acervo.
#
# SÓ SE APAGA `.ansi` DENTRO DE `$FFL_BASE`, que é diretório NOSSO, criado por
# este script e por mais ninguém — e nunca o alvo da vez.
_ffl_varrer_orfaos() {
  local velho
  [ -d "$FFL_BASE" ] || return 0
  for velho in "$FFL_BASE"/*.ansi; do
    [ -f "$velho" ] || continue
    [ "$velho" = "$FFL_ALVO" ] && continue
    if meow_seco; then meow_muda "removeria $velho (sobrou do modo anterior)"
    else rm -f "$velho" && meow_info "removi $(basename "$velho") (sobrou do modo anterior)"; fi
  done
  return 0
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
pad = logo.get("padding") or {}
print(logo.get("type") or "")
print(fonte)
print(len(chaves))
# As duas medidas do espaço em volta do gato entraram na leitura em 06/09/2026:
# sem elas, mudar só `FASTFETCH_LOGO_QUEBRAS` no conf não disparava escrita
# nenhuma — a fronteira olhava para `source` e `type`, via que estavam certos, e
# dizia "já aponta para o nosso .ansi" sobre um arquivo com o recuo velho.
print(pad.get("top", ""))
print(pad.get("right", ""))
PY
}

# --- a escrita cirúrgica no config.jsonc dela --------------------------------
# TROCA DUAS CHAVES E MAIS NADA. Não reserializa o JSON: um `json.dump` mataria
# os comentários (é JSONC), a ordem das chaves e a indentação dela — e o arquivo
# vive num repo com auto-commit, então o diff de 10 minutos depois seria o
# arquivo inteiro reescrito por um enfeite. O que se faz aqui é achar o VALOR de
# `logo.source` (e de `logo.type`) DENTRO do bloco `"logo"`, por varredura que
# respeita aspas e escapes, e substituir o intervalo de bytes.
#
# O `~` VAI LITERAL, e isso é medido: o cabeçalho deste arquivo registra que o
# `fastfetch` expande `~` em `logo.source` nos dois tipos (`file` e `file-raw`).
# Gravar o caminho absoluto funcionaria igual, mas quebraria o arquivo dela no
# dia em que o home mudasse de nome — e o resto do arquivo usa `~`.
_ffl_escrever_conf() {
  local alvo_rel="~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")"
  local bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"

  if meow_seco; then
    meow_muda "mudaria logo.source de $FFL_CONF_DELA para \"$alvo_rel\""
    return "$MEOW_DIVERGENTE"
  fi

  # GUARDA 2: backup antes de encostar. Falhar aqui ABORTA a escrita — sem rede
  # de segurança não se mexe no arquivo de outro projeto, ponto.
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return "$MEOW_ERRO"; }
  cp -a "$FFL_CONF_DELA" "$bkp/config.jsonc" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_CONF_DELA — não vou escrever"; return "$MEOW_ERRO"; }

  # A ESCRITA MORA NO `fastfetch_conf.py`, E ISSO NÃO É ORGANIZAÇÃO: é a mesma
  # lição que já custou o arquivo dela uma vez. Este trecho era um heredoc de
  # 90 linhas de Python, e ele tinha o defeito de camada de sempre — trocava os
  # números do padding de dentro de um COMENTÁRIO. Com a linha antiga comentada
  # logo acima da que vale (o jeito mais comum de mexer em JSONC), a escrita
  # acertava o comentário, o padding de verdade ficava como estava, e a
  # divergência voltava todo dia: o aviso "escrevi no config.jsonc" saía em
  # toda passagem sobre um arquivo que nunca mudava.
  #
  # Duas varreduras de ESCRITA de JSONC em duas linguagens divergiriam de novo.
  # Agora é uma só, com máscara de comentários, e ela confere que o resultado
  # ainda é JSONC válido antes de gravar. O `_ffl_ler_conf` continua com a
  # varredura dele porque só LÊ (e conta os módulos com chave própria, que é
  # outra pergunta): um leitor que erre devolve um número torto, não um arquivo
  # truncado.
  #
  # 0 = nada a mudar · 1 = mudou · 2 = não deu.
  python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" escrever-logo \
    "$FFL_CONF_DELA" "$alvo_rel" "$(_ffl_quebras)" "$FASTFETCH_LOGO_RECUO"
  case "$?" in
    0) meow_ok "o config.jsonc dela já estava como o meow.conf pede"
       return "$MEOW_OK" ;;
    2) meow_erro "não consegui escrever em $FFL_CONF_DELA"
       meow_info  "  backup intacto: $bkp/config.jsonc"
       return "$MEOW_ERRO" ;;
  esac

  # GUARDA 3: em voz alta, sempre. Tocar arquivo de vizinho sem dizer é
  # exatamente o que a TRAVA 1 existe para impedir.
  meow_aviso "escrevi no config.jsonc da Aurora (logo.source -> $alvo_rel)"
  meow_info  "  backup: $bkp/config.jsonc"
  meow_info  "  desligue com FASTFETCH_LOGO_CONF=\"nao\" no ~/.config/meow/meow.conf"
  meow_registrar "fastfetch_logo.sh escreveu logo.source=$alvo_rel em $FFL_CONF_DELA"
  return "$MEOW_DIVERGENTE"
}

# 0 = o config.jsonc já aponta para o nosso .ansi · 1 = não aponta · 2 = não deu
# para ler. Imprime sempre uma linha dizendo o que viu.
_ffl_fronteira() {
  local dados tipo fonte nchaves pad_topo pad_recuo
  if ! dados="$(_ffl_ler_conf 2>/dev/null)"; then
    meow_aviso "não achei $FFL_CONF_DELA — nada a conferir do lado da Aurora"
    return 2
  fi
  tipo="$(printf '%s' "$dados"  | sed -n '1p')"
  fonte="$(printf '%s' "$dados" | sed -n '2p')"
  nchaves="$(printf '%s' "$dados" | sed -n '3p')"
  pad_topo="$(printf '%s' "$dados"  | sed -n '4p')"
  pad_recuo="$(printf '%s' "$dados" | sed -n '5p')"
  case "$tipo" in
    erro*) meow_aviso "não consegui interpretar o config.jsonc dela: $tipo"
           return 2 ;;
  esac

  meow_info "config.jsonc dela: logo.type=\"$tipo\" logo.source=\"${fonte:-<vazio>}\""
  # A LINHA SÓ SE MONTA SE ALGUÉM FOR LER. O `$(_ffl_quebras)` roda um
  # `fastfetch` inteiro quando as quebras estão em `auto`, e a substituição de
  # comando acontece na expansão do argumento — antes de o `meow_info` poder
  # calar pelo `LOG_NIVEL=silencioso`. É o tique de cinco minutos do
  # `meow-gato.timer` pagando por um número que ele descarta.
  meow_quieto || meow_info "  padding: topo=${pad_topo:-<sem>} recuo=${pad_recuo:-<sem>} (o conf pede $(_ffl_quebras) e $FASTFETCH_LOGO_RECUO)"
  meow_info "  módulos com chave própria (as em português): $nchaves"

  if [ "$fonte" != "$FFL_ALVO" ]; then
    return 1
  fi
  if [ "$tipo" != "file-raw" ]; then
    meow_aviso "aponta para $(basename "$FFL_ALVO"), mas com logo.type=\"$tipo\" — o certo é \"file-raw\""
    return 1
  fi
  # O PADDING SÓ É COBRADO NO ALINHAMENTO TABULAR. No `contorno` quem desenha o
  # espaço é o `meow-fetch`, com as mesmas duas chaves passadas na linha de
  # comando — o `padding` do config.jsonc fica sem efeito, e cobrá-lo daria uma
  # divergência eterna sobre um número que ninguém lê.
  if [ "$(_ffl_alinhamento)" = "tabular" ]; then
    if [ -n "$pad_topo" ] && [ "$pad_topo" != "$(_ffl_quebras)" ]; then
      meow_muda "o padding.top do config.jsonc é $pad_topo e o conf pede $(_ffl_quebras)"
      return 1
    fi
    if [ -n "$pad_recuo" ] && [ "$pad_recuo" != "$FASTFETCH_LOGO_RECUO" ]; then
      meow_muda "o padding.right do config.jsonc é $pad_recuo e o conf pede $FASTFETCH_LOGO_RECUO"
      return 1
    fi
  fi
  meow_ok "o config.jsonc dela já aponta para $(basename "$FFL_ALVO")"
  return 0
}

# ============================================================================
# O CONTORNO: O TEXTO ABRAÇANDO O GATO — 06/09/2026
# ============================================================================
# Pedido dela, com setas desenhadas por cima de uma captura do terminal — e as
# setas apontavam para colunas DIFERENTES em cada linha, seguindo a silhueta do
# desenho. O `scripts/fastfetch_alinhar.py` conta a medição que prova que o
# fastfetch não sabe fazer isso sozinho. Aqui está o resto: onde o compositor
# entra na vida dela sem que o MeowSystem vire dono do terminal dos outros.
#
# A PEÇA É UM LANÇADOR EM ~/.local/bin, COMO O `meow-painel`
#   Pelo mesmo motivo daquele: o repositório mora num NVMe separado, e o dia em
#   que o Ápate não montar não pode ser o dia em que o terminal dela abre com um
#   erro de Python. O `meow-fetch` resolve a raiz pelo ponteiro
#   `~/.local/state/meowsystem/raiz` e, sem ela, roda o `fastfetch` puro e cala.
#
# E A CHAVE DECIDE EM TEMPO DE EXECUÇÃO, NÃO DE INSTALAÇÃO
#   O `meow-fetch` lê o `FASTFETCH_LOGO_ALINHAR` a cada chamada. Com `tabular`
#   ele é um `exec fastfetch` e mais nada — mesma saída, mesmo custo. Isso é o
#   que permite tocar o `env.zsh` UMA VEZ e nunca mais: trocar de alinhamento
#   depois é mudar uma chave no conf dela, sem escrita em arquivo de vizinho,
#   sem `git` de outro projeto se mexendo, sem nada para desfazer.
_ffl_meow_fetch() { printf '%s/.local/bin/meow-fetch' "$HOME"; }

_ffl_texto_meow_fetch() {
  cat <<'FIM'
#!/usr/bin/env bash
# meow-fetch — o fastfetch com o gato do MeowSystem alinhado como o meow.conf pede.
#
# NÃO É UM SUBSTITUTO DO FASTFETCH. Com FASTFETCH_LOGO_ALINHAR="tabular" (o
# padrão) ele é um `exec fastfetch "$@"` e mais nada: mesma saída, mesmo custo,
# mesmos argumentos. Só o `contorno` faz este arquivo ter trabalho.
#
# Ele é gerado por scripts/fastfetch_logo.sh e conferido pelo `meow doctor`.
# Editar aqui não adianta: a próxima passagem reescreve.
set -uo pipefail

conf="${MEOW_CONF:-$HOME/.config/meow/meow.conf}"
alinhar="tabular"; recuo="3"; topo="auto"
if [ -r "$conf" ]; then
  # Subshell: o conf é um arquivo de atribuições, mas ler o arquivo de
  # configuração de um projeto para dentro do ambiente do terminal dela seria
  # exportar cem variáveis em toda janela nova.
  #
  # AS DUAS COSTURAS AQUI SÃO CONTRA UM MODO DE FALHA CALADO.
  #   `set +u`: a subshell herdava o `set -u` da linha acima, e uma linha do
  #   conf que expandisse variável não definida matava a subshell ANTES do
  #   `printf`. O `eval` recebia string vazia, o alinhamento caía no `tabular`
  #   do padrão, e a saída ficava byte a byte igual ao fastfetch puro: sem gato
  #   e sem uma palavra de aviso. Nenhum `conferir` acusava, porque ele lê o
  #   conf por outro caminho.
  #
  #   `>/dev/null` no `.`: o stdout do conf não era isolado, então um `echo` de
  #   dentro dele ia para o `eval` — `echo "conf carregado"` virava
  #   `conf: comando não encontrado` em toda janela nova.
  dados="$(
    set +u
    . "$conf" >/dev/null 2>&1
    printf 'alinhar=%q; recuo=%q; topo=%q\n' \
      "${FASTFETCH_LOGO_ALINHAR:-tabular}" \
      "${FASTFETCH_LOGO_RECUO:-3}" "${FASTFETCH_LOGO_QUEBRAS:-auto}"
  )"
  if [ -n "$dados" ]; then
    eval "$dados"
  else
    printf 'meow-fetch: não consegui ler %s — alinhamento tabular\n' "$conf" >&2
  fi
fi

# O TÍTULO NÃO PASSA POR AQUI, e a tentativa de fazê-lo passar está registrada
# porque ela custou uma tela em branco: o fastfetch 2.61.0 REMOVEU as opções de
# módulo da linha de comando —
#
#   Error: Unsupported module option: --title-format
#          Support of module options has been removed.
#          Please add the flag to the JSON config instead.
#
# e, como ele sai com erro antes de imprimir uma linha, o compositor recebia
# entrada vazia e o terminal abria só com o gato. Quem escreve o formato do
# título é o `fastfetch_logo.sh`, no `config.jsonc`, pelas mesmas quatro
# guardas de sempre.
case "$alinhar" in
  contorno|degraus|crescente|reto) ;;
  *) exec fastfetch "$@" ;;
esac

ponteiro="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem/raiz"
raiz="${MEOW_RAIZ:-}"
[ -n "$raiz" ] || raiz="$(head -n1 "$ponteiro" 2>/dev/null || true)"
alinhador="$raiz/scripts/fastfetch_alinhar.py"
gato="$HOME/.local/share/meowsystem/fastfetch/gato.ansi"

# SEM O DISCO, O TERMINAL ABRE IGUAL. Um `fastfetch` que falha porque o NVMe do
# projeto não montou seria o pior lugar possível para este projeto aparecer.
# O `python3` entra na lista porque ele é peça do cano como as outras três.
if [ -z "$raiz" ] || [ ! -f "$alinhador" ] || [ ! -f "$gato" ] \
   || ! command -v python3 >/dev/null 2>&1; then
  exec fastfetch "$@"
fi

# O CANO NÃO É O ÚNICO CAMINHO DA SAÍDA, e essa era a falha que a guarda acima
# não cobria: passada a guarda, o que a tela mostrava era só o que saísse do
# python. Um traceback, um gato.ansi ilegível, qualquer coisa — e o stdout ia a
# ZERO byte: a saudação inteira sumia numa janela nova. Aqui o fetch vai para
# uma variável primeiro, e o alinhado só a substitui se der certo E vier com
# conteúdo. O pior caso volta a ser o que o cabeçalho promete: o fastfetch
# tabular, sem gato.
saida="$(fastfetch --logo none "$@")"
if alinhada="$(printf '%s\n' "$saida" \
     | python3 "$alinhador" --gato "$gato" --recuo "$recuo" --topo "$topo" \
         --modo "$alinhar")" && [ -n "$alinhada" ]; then
  printf '%s\n' "$alinhada"
else
  printf '%s\n' "$saida"
fi
FIM
}

# 0 = já estava certo · 1 = escrevi (ou escreveria) · 2 = erro
_ffl_instalar_meow_fetch() {
  local alvo texto
  alvo="$(_ffl_meow_fetch)"; texto="$(_ffl_texto_meow_fetch)"
  if [ -f "$alvo" ] && [ -x "$alvo" ] && [ "$(cat "$alvo")" = "$texto" ]; then
    return 0
  fi
  meow_seco && { meow_muda "escreveria $alvo"; return 1; }
  mkdir -p "$(dirname "$alvo")" || return 2
  printf '%s\n' "$texto" > "$alvo" || return 2
  chmod 755 "$alvo" || return 2
  meow_manifesto_registrar "$alvo"
  return 1
}

# --- a fronteira do lado do zsh ---------------------------------------------
# O ARQUIVO É DA AURORA, e a disciplina é a mesma do `config.jsonc`: só se
# escreve com `FASTFETCH_LOGO_CONF="sim"`, sempre com backup antes, sempre em
# voz alta depois, e só a LINHA que interessa — o `~/.config/zsh` tem
# auto-commit de 10 em 10 minutos, então um arquivo reescrito viraria um diff
# gigante por causa de um enfeite.
#
# E a troca é de uma palavra: `fastfetch --pipe false` vira `meow-fetch --pipe
# false`. O `sed` de tradução que vem depois no cano dela continua intacto, e o
# `command -v fastfetch` que guarda o bloco continua sendo o teste certo — o
# `meow-fetch` não serve para nada sem o fastfetch instalado.
FFL_ZSH_DELA="${MEOW_ZSH_ENV:-$HOME/.config/zsh/env.zsh}"
FFL_ZSH_ANTES='fastfetch --pipe false | sed -E'
FFL_ZSH_DEPOIS='meow-fetch --pipe false | sed -E'

# Qual das duas linhas está lá: `meow` (nossa), `puro` (a dela), `nenhuma`.
_ffl_zsh_estado() {
  [ -r "$FFL_ZSH_DELA" ] || { printf 'nenhuma'; return; }
  if grep -qF "$FFL_ZSH_DEPOIS" "$FFL_ZSH_DELA"; then printf 'meow'
  elif grep -qF "$FFL_ZSH_ANTES" "$FFL_ZSH_DELA"; then printf 'puro'
  else printf 'nenhuma'; fi
}

# Deixa a linha do env.zsh de acordo com `FASTFETCH_LOGO_ALINHAR`.
# 0 = já estava certo · 1 = mudei (ou mudaria) · 2 = não dá para mudar daqui
_ffl_zsh_fronteira() {
  local estado querido de para bkp
  estado="$(_ffl_zsh_estado)"
  if _ffl_quer_meow_fetch; then
    querido="meow"; de="$FFL_ZSH_ANTES"; para="$FFL_ZSH_DEPOIS"
  else
    querido="puro"; de="$FFL_ZSH_DEPOIS"; para="$FFL_ZSH_ANTES"
  fi
  [ "$estado" = "$querido" ] && return 0
  if [ "$estado" = "nenhuma" ]; then
    # Nem uma linha nem outra: este arquivo NÃO inventa a chamada do fastfetch
    # no zsh de ninguém. Diz o que falta e sai.
    meow_pula "não achei a linha do fastfetch em $FFL_ZSH_DELA"
    meow_info  "  o contorno (e o título próprio) precisam da chamada \`meow-fetch --pipe false\`"
    return 2
  fi
  if [ "$FASTFETCH_LOGO_CONF" != "sim" ]; then
    meow_pula "FASTFETCH_LOGO_CONF=\"nao\" — não toco no env.zsh da Aurora"
    meow_info  "  troque à mão em $FFL_ZSH_DELA:"
    meow_info  "    de:   $de"
    meow_info  "    para: $para"
    return 2
  fi
  meow_seco && { meow_muda "trocaria \`${de%% |*}\` por \`${para%% |*}\` em $FFL_ZSH_DELA"; return 1; }

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return 2; }
  cp -a "$FFL_ZSH_DELA" "$bkp/env.zsh" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_ZSH_DELA — não vou escrever"; return 2; }

  python3 - "$FFL_ZSH_DELA" "$de" "$para" <<'PY' || return 2
import os, sys, tempfile
caminho, de, para = sys.argv[1], sys.argv[2], sys.argv[3]
bruto = open(caminho, encoding="utf-8").read()
if de not in bruto:
    sys.exit(1)
# `replace(..., 1)`: uma ocorrência, a primeira. Se um dia houver duas, a
# segunda fica e o `conferir` continua acusando — o que é melhor que este
# arquivo decidir sozinho sobre um trecho que ele não entende.
saida = bruto.replace(de, para, 1)
d = os.path.dirname(os.path.realpath(caminho))
fd, tmp = tempfile.mkstemp(dir=d, prefix=".meow-ffl.")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(saida)
    os.chmod(tmp, 0o644)
    os.replace(tmp, os.path.realpath(caminho))
except Exception:
    os.path.exists(tmp) and os.unlink(tmp)
    raise
PY

  meow_aviso "escrevi no env.zsh da Aurora (a chamada do fastfetch virou \`${para%% *}\`)"
  meow_info  "  backup: $bkp/env.zsh"
  meow_info  "  vale no PRÓXIMO terminal — este aqui já leu o arquivo"
  meow_registrar "fastfetch_logo.sh trocou a chamada do fastfetch em $FFL_ZSH_DELA para ${para%% *}"
  return 1
}

# --- o formato do título, no config.jsonc dela -------------------------------
# ELE TEM DE MORAR LÁ, e a alternativa foi tentada e medida: o fastfetch 2.61.0
# recusa `--title-format` com "Support of module options has been removed.
# Please add the flag to the JSON config instead" e SAI ANTES de imprimir uma
# linha — o terminal abria só com o gato, sem uma palavra de informação.
#
# A escrita é do mesmo tipo cirúrgico do `logo.source`: acha a entrada `title`
# dentro do array `modules` e troca só ela. Dois formatos existem no mundo real,
# e os dois são tratados:
#
#   "title"                                    a forma curta, que é a dela
#   { "type": "title", "format": "…" }         a forma longa, com o formato
#
# Com `FASTFETCH_TITULO` vazio, o caminho anda para trás: a forma longa volta a
# ser a curta, e o fastfetch decide o título como sempre decidiu. É o mesmo
# desfazer do alinhamento — nada aqui é de mão única.

# 0 = já está como o conf pede · 1 = precisa mudar · 2 = não deu para ler
_ffl_titulo_confere() {
  local atual rc
  [ -f "$FFL_CONF_DELA" ] || return 2
  # O `2` PRECISA CHEGAR INTEIRO até aqui — "não há módulo title neste arquivo"
  # e "o título é outro" são respostas diferentes, e só a segunda autoriza
  # escrever. Um `| grep` engoliria o código de saída do python e as duas
  # virariam a mesma coisa: o script passaria a tentar escrever num arquivo que
  # não tem onde receber.
  atual="$(python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" ler-titulo "$FFL_CONF_DELA" 2>/dev/null)"
  rc=$?
  [ "$rc" = "0" ] || return 2
  [ "$atual" = "$FASTFETCH_TITULO" ]
}

_ffl_escrever_titulo() {
  local bkp
  _ffl_titulo_confere; case $? in 0) return 0 ;; 2) return 2 ;; esac

  if [ "$FASTFETCH_LOGO_CONF" != "sim" ]; then
    meow_pula "FASTFETCH_LOGO_CONF=\"nao\" — não escrevo o título no config.jsonc"
    meow_info  "  para pôr à mão, troque \"title\" por:"
    meow_info  "    { \"type\": \"title\", \"format\": \"$FASTFETCH_TITULO\" }"
    return 2
  fi
  if meow_seco; then
    meow_muda "poria o título \"$FASTFETCH_TITULO\" em $FFL_CONF_DELA"
    return 1
  fi

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return 2; }
  cp -a "$FFL_CONF_DELA" "$bkp/config.jsonc" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_CONF_DELA — não vou escrever"; return 2; }

  python3 "$MEOW_RAIZ/scripts/fastfetch_conf.py" escrever-titulo \
    "$FFL_CONF_DELA" "$FASTFETCH_TITULO"
  case $? in 2) meow_erro "não consegui escrever o título em $FFL_CONF_DELA"; return 2 ;; esac

  if [ -n "$FASTFETCH_TITULO" ]; then
    meow_aviso "escrevi o título no config.jsonc da Aurora (\"$FASTFETCH_TITULO\")"
  else
    meow_aviso "devolvi o título do config.jsonc da Aurora ao padrão do fastfetch"
  fi
  meow_info  "  backup: $bkp/config.jsonc"
  meow_registrar "fastfetch_logo.sh escreveu title.format=$FASTFETCH_TITULO em $FFL_CONF_DELA"
  return 1
}

_ffl_patch_texto() {
  # OS NÚMEROS SAEM DO CONF, e não são mais constantes. Antes este bloco imprimia
  # `top: 6, right: 4` fixos e a linha seguinte dizia que o padding "não precisa
  # mudar" — o que deixou de ser verdade no dia em que a altura do gato virou
  # chave: um gato de 25 linhas com recuo de 6 empurra o texto para fora da tela.
  cat <<TXT
  "logo": {
    "type": "file-raw",
    "source": "~/.local/share/meowsystem/fastfetch/$(basename "$FFL_ALVO")",
    "padding": { "top": $(_ffl_quebras), "right": $FASTFETCH_LOGO_RECUO, "left": 0 }
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
  meow_info "o \"padding\" vem do meow.conf: FASTFETCH_LOGO_QUEBRAS=$FASTFETCH_LOGO_QUEBRAS -> $(_ffl_quebras)"
  meow_info "  e FASTFETCH_LOGO_RECUO=$FASTFETCH_LOGO_RECUO, para um gato de $(_ffl_linhas) linhas"
  meow_info "cópia pronta no repositório: assets/fastfetch/config-logo.jsonc.sugestao"
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
    meow_muda "$FASTFETCH_LOGO_GATO em ANSI ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células)${FFL_PORQUE:+ — $FFL_PORQUE}"
    meow_info "para ver: scripts/fastfetch_logo.sh ver"
  else
    meow_ok "o logo ANSI já estava gerado (${FASTFETCH_LOGO_GATO}${FFL_PORQUE:+ — $FFL_PORQUE})"
  fi

  # O GATO OVAL É AVISADO, NÃO IMPEDIDO. A altura virou chave dela em
  # 06/09/2026, e o conversor estica com `-resize LxA!` sem perguntar: fora da
  # proporção da célula o círculo vira elipse. Doze por cento é onde isso começa
  # a se ver na tela (medido, comparando 25 e 28 linhas para 64 colunas).
  _dv="$(_ffl_desvio)"
  if [ "${_dv:-0}" -gt 12 ] 2>/dev/null; then
    meow_aviso "o gato vai sair ${_dv}% fora da proporção da célula (esticado)"
    meow_info  "  para o desenho redondo: deixe FASTFETCH_LOGO_LINHAS vazio,"
    meow_info  "  ou use $(awk -v c=$FASTFETCH_LOGO_COLUNAS -v r=$FASTFETCH_LOGO_CELULA 'BEGIN{printf "%d", c/r + 0.5}') linhas para $FASTFETCH_LOGO_COLUNAS colunas"
  fi
  unset _dv

  # O COMPOSITOR. Ele é instalado sempre, e não só quando o alinhamento pede:
  # ele mesmo lê a chave e vira `exec fastfetch` no tabular sem título próprio,
  # e é isso que permite trocar de alinhamento sem tocar em arquivo de vizinho
  # de novo. Ver o bloco "O CONTORNO" lá em cima.
  _ffl_instalar_meow_fetch; _rcm=$?
  case "$_rcm" in
    1) rc="$MEOW_DIVERGENTE"; meow_muda "meow-fetch em $(_ffl_meow_fetch)" ;;
    2) meow_erro "não consegui escrever o $(_ffl_meow_fetch)" ;;
  esac
  unset _rcm

  # O 2 SOBE PARA 4, e não some no 0. O `_ffl_zsh_fronteira` devolve 2 quando o
  # env.zsh não tem NENHUMA das duas formas — nem a nossa, nem a dela. Isso não
  # é "está tudo certo": é a peça do contorno faltando na tela. Deixar cair no
  # 0 fazia o `aplicar` terminar verde com o gato invisível.
  _ffl_zsh_fronteira; _rcz=$?
  case "$_rcz" in
    1) rc="$MEOW_DIVERGENTE" ;;
    2) [ "$rc" = "$MEOW_OK" ] && rc=4 ;;
  esac
  unset _rcz

  _ffl_escrever_titulo; _rct=$?
  [ "$_rct" = "1" ] && rc="$MEOW_DIVERGENTE"
  unset _rct

  _ffl_fronteira; rcf=$?

  # A FRONTEIRA SE CONSERTA SOZINHA, quando ela deixou. Ver o bloco
  # `FASTFETCH_LOGO_CONF` lá em cima: as quatro guardas, o porquê da mudança e
  # a medição que descarta ping-pong com o self-heal.
  if [ "$rcf" = "1" ] && [ "$FASTFETCH_LOGO_CONF" = "sim" ] && [ -f "$FFL_CONF_DELA" ]; then
    local rce; _ffl_escrever_conf; rce=$?
    if [ "$rce" = "$MEOW_DIVERGENTE" ]; then
      rc="$MEOW_DIVERGENTE"
      # Reconferir em vez de assumir: se a troca não pegou (um `logo` aninhado
      # inesperado, um arquivo que mudou entre a leitura e a escrita), o patch
      # impresso abaixo continua sendo a saída honesta. Assumir sucesso aqui
      # seria o "consertei" sem conserto que o `4` deste script existe para evitar.
      meow_seco || { _ffl_fronteira >/dev/null 2>&1; rcf=$?; }
    elif [ "$rce" = "$MEOW_ERRO" ]; then
      meow_erro "não consegui escrever no config.jsonc — deixo o patch abaixo"
    fi
    # `rce` = 0 é "não havia o que trocar": a fronteira acusa divergência em
    # algo que esta escrita não cobre (uma chave `padding` que o arquivo dela
    # não tem, por exemplo). O `rcf` fica como estava e o patch abaixo sai — que
    # é a saída honesta, e não um "consertei" sobre um arquivo intocado.
  fi

  if [ "$rcf" = "1" ]; then
    printf '\n'
    meow_aviso "o fastfetch ainda NÃO vai mostrar o gato: falta uma troca de"
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
  meow_ok "logo ANSI conforme ($FASTFETCH_LOGO_COLUNAS x $(_ffl_linhas) células, $(_ffl_blocos))"
  meow_info "alinhamento: $(_ffl_alinhamento) · $(_ffl_quebras) linha(s) antes, recuo de $FASTFETCH_LOGO_RECUO"

  # As duas peças do contorno entram na conferência do `doctor`: sem isto, o
  # `meow-fetch` podia ficar desatualizado ou a linha do env.zsh podia voltar
  # ao `fastfetch` puro (um `git checkout` no repo da Aurora basta) e nada
  # acusaria — o gato continuaria certo no disco e errado na tela.
  # O SECO É OBRIGATÓRIO AQUI, e a linha logo acima já dizia isso para a irmã
  # (`MEOW_SECO=1 _ffl_instalar`). Sem ele, `_ffl_instalar_meow_fetch` GRAVA o
  # arquivo com modo 755, registra no manifesto, e só depois o `conferir`
  # imprime "está desatualizado" — o diagnóstico consertava o que estava
  # diagnosticando, e a passagem seguinte devolvia 0. Isso desmentia a promessa
  # do `bin/meow` de que "conferir é leitura: nenhum caminho de doctor sem
  # --consertar escreve configuração", inclusive no timer das 5h.
  if ! MEOW_SECO=1 _ffl_instalar_meow_fetch >/dev/null; then
    meow_muda "o $(_ffl_meow_fetch) está desatualizado (ou não existe)"
    return "$MEOW_DIVERGENTE"
  fi
  if [ "$(_ffl_zsh_estado)" != "$(_ffl_quer_meow_fetch && printf meow || printf puro)" ]; then
    case "$(_ffl_zsh_estado)" in
      # 4, E NÃO 0. Sem NENHUMA das duas formas no env.zsh, a peça que põe o
      # contorno na tela dela simplesmente não existe — e o ramo antigo caía
      # fora do `case` sem `return`, então a função terminava em 0 e o doctor
      # marcava o fastfetch verde. É o estado de uma máquina nova, e o de um
      # `git checkout` no repo da Aurora que mude a FORMA do bloco. O 4 é o
      # "está pendente e não há conserto nosso possível" que este arquivo já
      # usa: aparece no relatório sem pendurar "o auto-reparo corrigiu".
      nenhuma) meow_pula "não achei a linha do fastfetch em $FFL_ZSH_DELA"
               meow_info "  o contorno precisa da chamada \`meow-fetch --pipe false\` lá"
               return 4 ;;
      *) meow_muda "a chamada do fastfetch no env.zsh não combina com FASTFETCH_LOGO_ALINHAR=\"$(_ffl_alinhamento)\""
         return "$MEOW_DIVERGENTE" ;;
    esac
  fi

  if _ffl_titulo_confere; then :; else
    [ "$?" = "1" ] && {
      meow_muda "o título do config.jsonc não é o que o conf pede (\"$FASTFETCH_TITULO\")"
      return "$MEOW_DIVERGENTE"; }
  fi

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

# --- desfazer a fronteira, na hora de desinstalar ----------------------------
# ESTE É O ÚNICO PEDAÇO DO FASTFETCH QUE O MANIFESTO NÃO ALCANÇA.
#   O `gato.ansi` e o `~/.local/bin/meow-fetch` entram no manifesto pela
#   `meow_manifesto_registrar` e saem no passo 4 do desinstalador. A LINHA do
#   `env.zsh` não: ela é uma escrita cirúrgica dentro de um arquivo que é da
#   Aurora, e o manifesto — que apaga arquivos inteiros — nunca poderia cuidar
#   dela.
#
#   O ESTRAGO DE NÃO FAZER ISTO é diário e barulhento: o passo 4 apaga o
#   `meow-fetch`, a linha continua chamando o `meow-fetch`, e cada terminal que
#   ela abrir depois de desinstalar abre com `command not found`. Desinstalar
#   tem de devolver a máquina, não deixar um buraco no shell.
#
#   POR QUE AQUI O `FASTFETCH_LOGO_CONF` NÃO GUARDA NADA
#   Ele guarda a ESCRITA, e com razão: pôr a nossa chamada no arquivo dela é
#   uma decisão dela. Tirá-la não é — se a linha diz `meow-fetch` e o
#   `meow-fetch` está saindo do disco, restaurar `fastfetch` é conserto, não
#   opinião. E o teste continua sendo o texto: sem a nossa linha lá, este
#   caminho não escreve nada.
cmd_reverter() {
  local estado bkp
  estado="$(_ffl_zsh_estado)"
  if [ "$estado" != "meow" ]; then
    meow_pula "a chamada do fastfetch no env.zsh não é nossa — nada a desfazer"
    return "$MEOW_OK"
  fi
  meow_seco && {
    meow_muda "devolveria \`${FFL_ZSH_ANTES%% |*}\` em $FFL_ZSH_DELA"
    return "$MEOW_DIVERGENTE"
  }

  bkp="$MEOW_ESTADO/backups/$MEOW_CARIMBO-vizinho"
  mkdir -p "$bkp" 2>/dev/null || { meow_erro "não consegui criar $bkp"; return "$MEOW_ERRO"; }
  cp -a "$FFL_ZSH_DELA" "$bkp/env.zsh" 2>/dev/null \
    || { meow_erro "não consegui guardar backup de $FFL_ZSH_DELA — não vou escrever"; return "$MEOW_ERRO"; }

  python3 - "$FFL_ZSH_DELA" "$FFL_ZSH_DEPOIS" "$FFL_ZSH_ANTES" <<'PY_REVERTER' || return "$MEOW_ERRO"
import os, sys, tempfile
caminho, de, para = sys.argv[1], sys.argv[2], sys.argv[3]
bruto = open(caminho, encoding="utf-8").read()
if de not in bruto:
    sys.exit(1)
saida = bruto.replace(de, para, 1)
d = os.path.dirname(os.path.realpath(caminho))
fd, tmp = tempfile.mkstemp(dir=d, prefix=".meow-ffl.")
try:
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(saida)
    os.chmod(tmp, 0o644)
    os.replace(tmp, os.path.realpath(caminho))
except Exception:
    os.path.exists(tmp) and os.unlink(tmp)
    raise
PY_REVERTER

  meow_aviso "devolvi a chamada \`fastfetch\` no env.zsh da Aurora"
  meow_info  "  backup: $bkp/env.zsh"
  meow_info  "  vale no PRÓXIMO terminal — este aqui já leu o arquivo"
  meow_registrar "fastfetch_logo.sh reverter — env.zsh voltou a chamar fastfetch"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  ver)      cmd_ver ;;
  patch)    cmd_patch ;;
  remover)  cmd_remover ;;
  reverter) cmd_reverter ;;
  *) meow_erro "uso: fastfetch_logo.sh {aplicar|conferir|ver|patch|remover|reverter}"; exit "$MEOW_ERRO" ;;
esac
