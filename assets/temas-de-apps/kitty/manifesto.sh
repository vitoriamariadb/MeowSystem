#!/usr/bin/env bash
# assets/temas-de-apps/kitty/manifesto.sh — o tema do pack no kitty.
#
# POR QUE ESTE MÓDULO NASCEU — 24/09/2026, sprint P42
#   A P37 mediu o que o tema Dracula de antes aplicava e o MeowSystem nunca
#   migrou, e o kitty estava na lista: aquele instalador copiava um
#   `current-theme.conf` com 36 hex escritos e acrescentava o `include` no
#   `kitty.conf`. A decisão de 23/09 foi "migrar para o pack". O tema passou a
#   ser um MODELO em `packs/<pack>/apps/` (a chave `apps.kitty.arquivo` do
#   pack.json), com o papel da cor no lugar dela, e quem põe o hex é o
#   `assets/temas-de-apps/modelo.py`, com a paleta do pack no ar. Com o flavor
#   claro do pack, o kitty fica claro; com outro pack que declare o bloco, fica
#   no dele. Este módulo não conhece nome de tema nenhum.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`: um
#   `exit` aqui derrubaria o `aplicar_apps.sh` inteiro no meio do catálogo.
#
# ONDE ELE ESCREVE, E POR QUE ALI
#   `current-theme.conf` é o arquivo de tema do próprio kitty — é onde o
#   `kitten themes` escreve quando ela escolhe um tema pela interface dele. E o
#   bloco `# BEGIN_KITTY_THEME … # END_KITTY_THEME` no fim do `kitty.conf` é a
#   convenção do mesmo `kitten themes`. Usar as duas portas do dono do app é o
#   que faz a escolha dela pelo `kitten themes` continuar valendo: ele reescreve
#   o arquivo SEM a nossa marca, e este módulo passa a vê-lo como tema dela.
#
#   O bloco entra no FIM, e isso é o defeito que ele evita: no kitty a última
#   linha vence, e o `kitty.conf` que o tema de antes deixou nesta máquina tem o
#   `include` na linha 2 e as dezesseis cores escritas logo depois (medido em
#   24/09/2026, `~/.config/kitty/kitty.conf`, 777 bytes) — o tema incluído nunca
#   pintou nada ali. Depois de posto, ele NÃO é arrastado de novo para o fim: o
#   que ela escrever abaixo dele é dela, e vence, que é como o kitty funciona.
#
# AS TRÊS SAÍDAS DA LEITURA (a regra da P18, `meow_app_tema_no_ar`)
#   sem tema         nem `current-theme.conf` nem cor no `kitty.conf`
#   do pack          o `current-theme.conf` tem a marca `meowsystem-tema:`
#   de terceiro      o arquivo existe sem a marca, OU o `kitty.conf` põe as
#                    cores ele mesmo, escritas ou por um `include` fora do bloco
#                    — é escolha dela, e a resposta é PERGUNTAR (ou deixar
#                    pendência), nunca sobrescrever calado.
#   A marca diz também pack e flavor. Um tema NOSSO de outro flavor não é de
#   terceiro: é o mesmo módulo de antes, e ele se atualiza sem perguntar.
#
# O `kitty.conf` NÃO PASSA PELA `meow_escrever`, E O MOTIVO É O DESINSTALADOR
#   Aquela função registra no manifesto o que grava, e o `--uninstall` apaga o
#   que está no manifesto. O `kitty.conf` é DELA — com a fonte, o tamanho da
#   janela e o que mais ela pôs lá —, e nós só mexemos no bloco do tema. Então
#   ele é gravado aqui, atômico e sem registro. O `current-theme.conf` NOSSO,
#   esse sim, vai pela `meow_escrever`.

_KITTY_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"
_KITTY_TEMA="$_KITTY_DIR/current-theme.conf"
_KITTY_CONF="$_KITTY_DIR/kitty.conf"
# O tema dela que tiramos do lugar, quando ela disse sim. Caminho FIXO, e não o
# `backups/<data>/` dos outros módulos: o `reverter` precisa achá-lo meses
# depois sem adivinhar a data.
_KITTY_ANTES="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/temas-de-apps/kitty/current-theme.conf.antes"
_KITTY_MODELO_PY="$MEOW_RAIZ/assets/temas-de-apps/modelo.py"

# O kitty mora no PATH (apt, dnf, pacman) ou no instalador oficial, que põe o
# binário em `~/.local/kitty.app/bin` e só um link em `~/.local/bin`. Os
# diretórios de config sozinhos NÃO contam: nesta máquina `~/.config/kitty/`
# existe desde 26/06/2026 e o kitty não está instalado (medido em 24/09/2026) —
# é a sobra do tema de antes, e tematizar sobra é trabalho para ninguém.
_kitty_instalado() {
  meow_tem kitty || [ -x "$HOME/.local/kitty.app/bin/kitty" ]
}

# A marca do nosso arquivo, `<pack>/<flavor>`, ou vazio.
_kitty_marca() {
  sed -n 's/^# meowsystem-tema: \([^ ]*\).*$/\1/p' "$1" 2>/dev/null | head -n 1
}

# Cor no kitty.conf FORA do nosso bloco: escrita nele, ou num arquivo que ele
# inclui. As duas são tema à mão. Imprime o que achou, para a tela dizer qual.
#
# O `include` CONTA, E CONTAR SÓ A COR ESCRITA ERA O DEFEITO — 24/09/2026
#   A primeira versão só olhava a cor escrita no próprio arquivo, e o
#   dracula/kitty manda instalar justamente com `include dracula.conf`. Na
#   revisão da P42, uma casa de brinquedo com `font_size 12` e `include
#   gruvbox.conf` deu conferir "está sem tema" e aplicar rc=1, com o nosso
#   bloco no fim — e no kitty a última linha vence: o tema dela trocado calado,
#   que é a saída que a P18 proíbe.
#
#   O incluído só conta se PINTA: `include fontes.conf` com fonte e atalho não é
#   tema. O caminho se resolve como a documentação do kitty descreve (variável
#   de ambiente, `~`, relativo à pasta de quem inclui; `globinclude` pelo
#   padrão) — descrito, não medido: o kitty não está instalado nesta máquina. O
#   incluído do incluído também é lido. O que não existe o kitty ignora e não
#   pinta, então não conta; o que existe e não se deixa ler conta — ilegível não
#   é "sem tema" (a mesma regra do `appdata` no módulo do OnlyOffice).
_kitty_conf_tem_cor() {
  [ -f "$_KITTY_CONF" ] || return 1
  python3 - "$_KITTY_CONF" <<'PY'
import glob, os, re, sys

COR = re.compile(r"^\s*(foreground|background|color[0-9]+)\s")
INC = re.compile(r"^\s*(include|globinclude)\s+(.+?)\s*$")
vistos = set()


def linhas(arq):
    with open(arq, encoding="utf-8", errors="replace") as f:
        return f.read().split("\n")


def alvos(tipo, valor, pasta):
    alvo = os.path.expanduser(os.path.expandvars(valor))
    if not os.path.isabs(alvo):
        alvo = os.path.join(pasta, alvo)
    return sorted(glob.glob(alvo)) if tipo == "globinclude" else [alvo]


def pinta(arq):
    real = os.path.realpath(arq)
    if real in vistos:
        return False
    vistos.add(real)
    try:
        ls = linhas(arq)
    except FileNotFoundError:
        return False
    except OSError:
        return True
    for l in ls:
        if COR.match(l):
            return True
        m = INC.match(l)
        if m and any(pinta(a) for a in alvos(m.group(1), m.group(2), os.path.dirname(arq))):
            return True
    return False


conf = sys.argv[1]
vistos.add(os.path.realpath(conf))
try:
    raiz = linhas(conf)
except OSError:
    print("o kitty.conf, que não se deixa ler")
    sys.exit(0)
dentro = False
for l in raiz:
    if l.startswith("# BEGIN_KITTY_THEME"):
        dentro = True
    elif l.startswith("# END_KITTY_THEME"):
        dentro = False
    elif not dentro:
        if COR.match(l):
            print("as cores escritas no próprio kitty.conf")
            sys.exit(0)
        m = INC.match(l)
        if m and any(pinta(a) for a in alvos(m.group(1), m.group(2), os.path.dirname(conf))):
            print(f"{m.group(2)} (incluído pelo kitty.conf)")
            sys.exit(0)
sys.exit(1)
PY
}

# O que está no ar, em duas variáveis: `_KITTY_NO_AR` é o que a tela diz e
# `_KITTY_NOSSO` é 1 quando o arquivo leva a nossa marca.
_kitty_no_ar() {
  local de_la
  _KITTY_NO_AR=""; _KITTY_NOSSO=0
  if [ -f "$_KITTY_TEMA" ]; then
    _KITTY_NO_AR="$(_kitty_marca "$_KITTY_TEMA")"
    if [ -n "$_KITTY_NO_AR" ]; then _KITTY_NOSSO=1; else _KITTY_NO_AR="$_KITTY_TEMA"; fi
  elif de_la="$(_kitty_conf_tem_cor)"; then
    _KITTY_NO_AR="$de_la"
  fi
}

# O bloco, do jeito que o `kitten themes` o escreve, com o nome do nosso tema.
_kitty_bloco() {
  printf '# BEGIN_KITTY_THEME\n# %s (MeowSystem)\ninclude current-theme.conf\n# END_KITTY_THEME' "$1"
}

# O nosso bloco, exato, em qualquer lugar do kitty.conf.
_kitty_bloco_presente() {
  [ -f "$_KITTY_CONF" ] || return 1
  awk -v b="$_KITTY_BLOCO" 'BEGIN { RS = "\001" } index($0, b) { achou = 1 } END { exit !achou }' "$_KITTY_CONF"
}

# O kitty.conf sem nenhum bloco de tema, e com o dado no fim (ou sem bloco
# nenhum, quando o argumento é vazio).
_kitty_conf_com_bloco() {
  local bloco="$1" resto=""
  # `$( )` come as linhas em branco do fim, e é de propósito: o bloco tirado
  # não deixa um rastro de linhas vazias a cada troca de flavor.
  [ -f "$_KITTY_CONF" ] && resto="$(awk '
      /^# BEGIN_KITTY_THEME/ { dentro = 1; next }
      /^# END_KITTY_THEME/   { dentro = 0; next }
      !dentro { print }
    ' "$_KITTY_CONF")"
  if [ -n "$resto" ] && [ -n "$bloco" ]; then
    printf '%s\n\n%s' "$resto" "$bloco"
  else
    printf '%s%s' "$resto" "$bloco"
  fi
}

# Escrita ATÔMICA do kitty.conf dela, sem manifesto (ver o cabeçalho).
_kitty_gravar_conf() {
  local novo="$1" tmp
  meow_destino_permitido "$_KITTY_CONF" || return "$MEOW_ERRO"
  # Sem nada além do nosso bloco, o arquivo vazio é o que nós criamos: sai
  # inteiro, em vez de ficar um kitty.conf de uma linha em branco.
  if [ -z "$novo" ]; then
    [ -f "$_KITTY_CONF" ] || return "$MEOW_OK"
    if meow_seco; then meow_muda "tiraria $_KITTY_CONF, que só tinha o bloco do tema"; return "$MEOW_DIVERGENTE"; fi
    rm -f -- "$_KITTY_CONF" || return "$MEOW_ERRO"
    return "$MEOW_DIVERGENTE"
  fi
  [ -f "$_KITTY_CONF" ] && [ "$novo" = "$(cat "$_KITTY_CONF")" ] && return "$MEOW_OK"
  if meow_seco; then meow_muda "mudaria o bloco do tema em $_KITTY_CONF"; return "$MEOW_DIVERGENTE"; fi
  mkdir -p "$_KITTY_DIR" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$_KITTY_DIR" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  printf '%s\n' "$novo" > "$tmp" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod --reference="$_KITTY_CONF" "$tmp" 2>/dev/null || chmod 644 "$tmp"
  mv -f "$tmp" "$_KITTY_CONF" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# 0 = o programa está nesta máquina · 1 = não está. A regra de "instalado" que
# a tabela do `meow apps` pergunta e o `detectar` abre com ela (24/09/2026, P49;
# ver o quinto verbo no `rodar_modulo` do scripts/aplicar_apps.sh).
meow_app_instalado() { _kitty_instalado; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "kitty: não está instalado"; return; }
  meow_tem python3 || { meow_app_sem "kitty: falta python3, que monta o tema com a paleta do pack"; return; }
  # SEM `$( )`: a resposta vem pelas duas variáveis (ver lib/comum.sh).
  meow_app_tema_do_pack kitty.arquivo
  _KITTY_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "kitty: o pack no ar não declara tema para o kitty"; return; }
  _KITTY_QUERO="$_KITTY_DE/${FLAVOR:-}"
  # O modelo que não monta (flavor que a paleta não tem, papel mal escrito) é
  # pendência com o motivo do próprio `modelo.py`, como o Spotify faz com o
  # flavor inexistente: é o meow.conf ou o pack que precisam de olho.
  _KITTY_DESEJADO="$(python3 "$_KITTY_MODELO_PY" "$MEOW_APP_TEMA" "$(meow_paleta)" "${FLAVOR:-}" "$_KITTY_DE" 2>&1)" \
    || { meow_app_sem "kitty: o modelo do pack $_KITTY_DE não montou — $_KITTY_DESEJADO"; return; }
  _KITTY_NOME="$(python3 "$_KITTY_MODELO_PY" --nome "$(meow_paleta)" "${FLAVOR:-}" 2>/dev/null)"
  _KITTY_BLOCO="$(_kitty_bloco "$_KITTY_NOME")"
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _kitty_no_ar
  if [ "$_KITTY_NOSSO" != 1 ]; then
    if [ -z "$_KITTY_NO_AR" ]; then
      meow_muda "kitty: está sem tema — o pack $_KITTY_DE traz '$_KITTY_NOME'"
      return "$MEOW_DIVERGENTE"
    fi
    meow_pula "kitty: está em '$_KITTY_NO_AR', que não veio daqui — trocar é decisão dela"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ "$(cat "$_KITTY_TEMA")" != "$_KITTY_DESEJADO" ]; then
    meow_muda "kitty: o tema do MeowSystem no disco é '$_KITTY_NO_AR', e o de agora é '$_KITTY_QUERO' (ou o modelo mudou)"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _kitty_bloco_presente; then
    meow_muda "kitty: o tema está no disco, mas o kitty.conf não o inclui"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "kitty: já está no tema do pack (do pack $_KITTY_DE) — $_KITTY_QUERO"
  return "$MEOW_OK"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente kitty; return; }
  _kitty_no_ar
  local mudou=0

  if [ "$_KITTY_NOSSO" = 1 ]; then
    # Nosso, de outro flavor ou de outro pack: é a mesma casa, e se atualiza sem
    # perguntar. O "já está" só sai no fim, se nada mudou — dizê-lo antes e
    # reescrever o arquivo logo depois (o modelo do pack mudou) seria a tela
    # afirmando as duas coisas.
    [ "$_KITTY_NO_AR" = "$_KITTY_QUERO" ] \
      || meow_muda "kitty: o tema do MeowSystem estava em '$_KITTY_NO_AR' — passa a '$_KITTY_QUERO'"
  else
    meow_app_tema_no_ar kitty "$_KITTY_NO_AR" "$_KITTY_QUERO" "$_KITTY_DE" pergunte
    [ $? = "$MEOW_DIVERGENTE" ] || return "$MEOW_SEM_DEPENDENCIA"
    # Ela disse sim a trocar um tema dela: o arquivo dela é guardado ANTES, uma
    # vez só — a segunda troca guardaria o nosso por cima do dela.
    if [ -f "$_KITTY_TEMA" ] && [ ! -f "$_KITTY_ANTES" ] && ! meow_seco; then
      mkdir -p "$(dirname "$_KITTY_ANTES")" && cp -a -- "$_KITTY_TEMA" "$_KITTY_ANTES" \
        || { meow_erro "kitty: não consegui guardar o tema dela antes de trocar"; return "$MEOW_ERRO"; }
      meow_info "kitty: o tema dela ficou guardado em $_KITTY_ANTES"
    fi
  fi

  meow_escrever "$_KITTY_TEMA" "$_KITTY_DESEJADO" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "kitty: falhou ao escrever $_KITTY_TEMA"; return "$MEOW_ERRO" ;; esac

  if ! _kitty_bloco_presente; then
    _kitty_gravar_conf "$(_kitty_conf_com_bloco "$_KITTY_BLOCO")"
    case $? in 1) mudou=1 ;; 2) meow_erro "kitty: falhou ao escrever $_KITTY_CONF"; return "$MEOW_ERRO" ;; esac
  fi

  if [ "$mudou" = 0 ]; then
    meow_app_tema_no_ar kitty "$_KITTY_QUERO" "$_KITTY_QUERO" "$_KITTY_DE"
    return "$MEOW_OK"
  fi
  meow_seco && return "$MEOW_DIVERGENTE"
  # O kitty lê o tema ao abrir. Mandar sinal para os abertos seria mexer em
  # processo vivo a partir de um teste de brinquedo também, e o atalho dele já
  # existe para isso.
  meow_ok "kitty: tema do pack aplicado — $_KITTY_NOME (vale na próxima janela, ou ctrl+shift+F5)"
  return "$MEOW_DIVERGENTE"
}

# DESFAZER NÃO DEPENDE DO PACK NEM DO APP
#   O `detectar` exige o kitty instalado e um pack que declare o tema. Nenhuma
#   das duas coisas importa aqui: quem trocou para o Catppuccin, ou tirou o
#   kitty, continua com o nosso arquivo no disco, e é a marca que diz de quem ele
#   é. Por isso este verbo não chama o `detectar`.
meow_app_reverter() {
  local marca bloco=""
  marca="$(_kitty_marca "$_KITTY_TEMA")"
  if [ -z "$marca" ]; then
    meow_ok "kitty: nenhum tema do MeowSystem no disco — nada a desfazer"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "kitty: tiraria o tema do pack ($marca)$([ -f "$_KITTY_ANTES" ] && printf ' e devolveria o dela')"
    return "$MEOW_DIVERGENTE"
  fi
  if [ -f "$_KITTY_ANTES" ]; then
    cp -a -- "$_KITTY_ANTES" "$_KITTY_TEMA" && rm -f -- "$_KITTY_ANTES" \
      || { meow_erro "kitty: não consegui devolver o tema dela"; return "$MEOW_ERRO"; }
    # O tema dela volta, e o `include` fica — sem ele o arquivo devolvido não
    # pintaria nada. Só o nome do nosso tema sai do bloco.
    bloco="$(printf '# BEGIN_KITTY_THEME\ninclude current-theme.conf\n# END_KITTY_THEME')"
    meow_ok "kitty: o tema dela voltou para $_KITTY_TEMA"
  else
    rm -f -- "$_KITTY_TEMA" || { meow_erro "kitty: não consegui tirar $_KITTY_TEMA"; return "$MEOW_ERRO"; }
    meow_ok "kitty: o tema do pack saiu do kitty"
  fi
  if [ -f "$_KITTY_CONF" ] && grep -q '^# .* (MeowSystem)$' "$_KITTY_CONF"; then
    _kitty_gravar_conf "$(_kitty_conf_com_bloco "$bloco")"
    [ $? = "$MEOW_ERRO" ] && { meow_erro "kitty: não consegui tirar o bloco do tema do kitty.conf"; return "$MEOW_ERRO"; }
  fi
  meow_info "tire 'kitty' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
