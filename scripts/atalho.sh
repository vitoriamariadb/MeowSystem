#!/usr/bin/env bash
# atalho.sh — planta (ou tira) o `.desktop` que abre o painel de configuração.
#
#   ./atalho.sh              instala o atalho "MeowSystem" no lançador
#   ./atalho.sh --conferir   não escreve; 1 se divergir, 3 se não houver o que fazer
#   ./atalho.sh --reverter   tira o atalho e o `run.sh` copiado
#
# ─────────────────────────────────────────────────────────────────────────────
# É O ÚNICO ÍCONE DESTE PROJETO QUE ABRE UMA JANELA
# ─────────────────────────────────────────────────────────────────────────────
# Tudo o mais que o MeowSystem instala é tema, ícone de OUTRO aplicativo, applet
# de barra ou unidade de systemd. Este é o `.desktop` do MeowSystem ele mesmo — o
# que ela clica no lançador para abrir a página de configuração.
#
# ─────────────────────────────────────────────────────────────────────────────
# O `Exec=` APONTA PARA UMA CÓPIA, E NÃO PARA O CLONE
# ─────────────────────────────────────────────────────────────────────────────
# A saída óbvia era `Exec=/mnt/Apate/Desenvolvimento/MeowSystem/app/run.sh`, e ela
# tem um defeito conhecido: o repositório mora num NVMe separado, e o dia em que o
# Ápate não montar é o dia em que o ícone do lançador vira um clique que não faz
# nada — sem mensagem, sem log, sem nada na tela dizendo por quê. É o mesmo
# raciocínio que fez `etapa_cli` COPIAR o `bin/meow` para `~/.local/bin` em vez de
# linká-lo: "a cópia roda e diz 'não achei o repositório', que é uma resposta".
#
# Então o que vai para `~/.local/bin/meow-painel` é um lançador de três linhas que
# resolve a raiz do jeito que o `bin/meow` já resolve (o ponteiro
# `~/.local/state/meowsystem/raiz`), e chama o `app/run.sh` de lá. Sem o disco, ele
# diz o que houve. Com o disco, é o mesmo script de sempre — nunca uma segunda
# cópia do painel que envelheceria em silêncio.
#
# ─────────────────────────────────────────────────────────────────────────────
# `Terminal=true`, E ISSO É DECISÃO, NÃO PREGUIÇA
# ─────────────────────────────────────────────────────────────────────────────
# O `run.sh` é um processo que FICA DE PÉ: ele sobe o servidor, abre o navegador e
# espera. Com `Terminal=false` ele viraria um processo invisível, e fechar o
# painel exigiria descobrir o PID — para uma coisa que abre `./install.sh` isso é
# ruim. Com `Terminal=true` nasce uma janela de terminal que é, literalmente, o
# interruptor: fechar aquela janela derruba o servidor (o `trap ... HUP` do
# `run.sh` cobre exatamente esse caso, e foi por isso que ele foi escrito).
#
# A janela também é onde a URL aparece, e é onde um traceback do Python apareceria.
# Um painel que pode rodar o instalador não deve esconder a própria saída.
#
# ─────────────────────────────────────────────────────────────────────────────
# O ÍCONE É NOME DE TEMA, NUNCA CAMINHO — e a escolha está declarada
# ─────────────────────────────────────────────────────────────────────────────
# `Icon=preferences-desktop-theme`, pelo mesmo motivo que o `leitura_build.sh` dá
# para o applet dele: um nome resolve pelo TEMA em uso e continua existindo se o
# repositório sair do disco; um caminho absoluto vira ícone quebrado.
#
# O nome escolhido é o que o PRÓPRIO PROJETO já usa: o `meow_notificar` de
# `lib/comum.sh` manda `-i preferences-desktop-theme` em toda notificação do
# MeowSystem desde a primeira versão. O ícone do painel é o mesmo dos avisos dele
# — uma coisa a menos para lembrar.
#
# ELE NÃO É DESENHO NOSSO, E ISSO ESTÁ DITO: conferido em 01/09/2026, o nome não
# aparece em `assets/icones/*.map` nem em `MeowSystem-Icons/`; quem o desenha é o
# Papirus, que é o `ICONES_BASE` de que o nosso tema herda. Ou seja: ele resolve
# ATRAVÉS do nosso tema, mas o traço é de terceiro. Para trocar por arte nossa,
# basta um `.svg` em `MeowSystem-Icons/scalable/apps/` com este nome — nada aqui
# muda, porque o `.desktop` pede pelo nome e não pelo arquivo.
#
# ─────────────────────────────────────────────────────────────────────────────
# ONDE ELE É INSTALADO, E POR QUE NÃO EM /usr/share
# ─────────────────────────────────────────────────────────────────────────────
# `~/.local/share/applications/`. A TRAVA 1 recusa `/usr/share` e está certa, e
# aqui nem há motivo para disputá-la: o problema do `cosmic-app-library` que
# obriga o `ocultar_apps.sh` a escrever lá é sobre ESCONDER um `.desktop` que já
# existe no sistema (bug pop-os/cosmic-applets#667). Criar um `.desktop` NOVO no
# home funciona normalmente — não há nada no sistema com este ID para deduplicar.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

APP_ID="com.meowsystem.Painel"
DESKTOP="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
LANCADOR="$HOME/.local/bin/meow-painel"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

# --- os dois textos ---------------------------------------------------------
# O lançador que sobrevive ao Ápate desmontado. Ele repete a busca de raiz do
# `bin/meow` em versão curta: o ponteiro que o `etapa_cli` grava, e nada mais —
# quem tem o clone no disco tem o ponteiro apontando para ele.
_texto_lancador() {
  cat <<'FIM'
#!/usr/bin/env bash
# meow-painel — abre o painel de configuração do MeowSystem.
# GERADO por scripts/atalho.sh. Não edite: a próxima passagem do instalador
# reescreve este arquivo. O que ele faz de verdade mora em app/run.sh.
set -uo pipefail
ponteiro="${XDG_STATE_HOME:-$HOME/.local/state}/meowsystem/raiz"
raiz="${MEOW_RAIZ:-}"
[ -n "$raiz" ] || raiz="$(head -n1 "$ponteiro" 2>/dev/null || true)"

if [ -z "$raiz" ] || [ ! -x "$raiz/app/run.sh" ]; then
  printf 'meow-painel: não achei o repositório do MeowSystem.\n' >&2
  printf '  procurei em: %s\n' "${raiz:-(o ponteiro $ponteiro está vazio ou não existe)}" >&2
  printf '\n  Se o disco do clone não estiver montado, é isso. Monte-o e tente de novo.\n' >&2
  printf '  Para apontar à mão:  MEOW_RAIZ=/caminho/do/clone meow-painel\n' >&2
  # Sem isto a janela de terminal fecharia antes de alguém ler o que houve — que
  # é exatamente o "clique que não faz nada" que este lançador existe para evitar.
  printf '\n  (ENTER para fechar) ' >&2
  read -r _ 2>/dev/null || sleep 20
  exit 3
fi
exec "$raiz/app/run.sh" "$@"
FIM
}

# `Keywords` em português E o nome das coisas que ela procuraria: o lançador do
# COSMIC casa por prefixo em Name, GenericName e Keywords, e "tema" é a palavra
# com que alguém procura isto — não "MeowSystem", que é preciso já saber.
#
# UMA categoria principal, e isso é medido: `desktop-file-validate` em
# 01/09/2026 avisou que `Settings;DesktopSettings;Utility;` tem DUAS categorias
# principais (Settings e Utility) e que "application might appear more than once
# in the application menu". `DesktopSettings` é subcategoria de `Settings`, e o
# par sozinho não gera aviso nenhum.
_texto_desktop() {
  cat <<FIM
[Desktop Entry]
Type=Application
Name=MeowSystem
GenericName=Configuração do tema
Comment=Configurar o tema, os ícones, o papel de parede e os gatos — numa página só
Exec=$LANCADOR
Icon=preferences-desktop-theme
Terminal=true
StartupNotify=true
Categories=Settings;DesktopSettings;
Keywords=meow;meowsystem;tema;theme;catppuccin;icones;ícones;gato;papel de parede;wallpaper;cosmic;aparência;
FIM
}

# --- estado ------------------------------------------------------------------
_confere_arquivo() {   # 0 = igual, 1 = divergente
  local alvo="$1" esperado="$2"
  [ -f "$alvo" ] || return 1
  [ "$esperado" = "$(cat "$alvo" 2>/dev/null)" ]
}

_conferir() {
  local faltando=()
  _confere_arquivo "$DESKTOP" "$(_texto_desktop)"   || faltando+=("$APP_ID.desktop")
  _confere_arquivo "$LANCADOR" "$(_texto_lancador)" || faltando+=("meow-painel")
  # O bit de execução conta como divergência: um lançador sem `+x` é um ícone
  # que abre e fecha na mesma hora, e nada na tela explica.
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then faltando+=("meow-painel sem +x"); fi
  # A página é o que o atalho abre. Sem ela o atalho é um botão que dá 500 —
  # e a causa (clone incompleto) merece ser dita aqui, não no navegador.
  if [ ! -f "$RAIZ/app/pagina/index.html" ] || [ ! -f "$RAIZ/app/servidor.py" ]; then
    meow_erro "o atalho existe mas app/ está incompleto neste clone"
    return "$MEOW_ERRO"
  fi

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_muda "atalho do painel a instalar: ${faltando[*]}"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "atalho \"MeowSystem\" no lançador, abrindo app/run.sh"
  return "$MEOW_OK"
}

_aplicar() {
  local mudou=0 rc

  meow_escrever "$LANCADOR" "$(_texto_lancador)" 755; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $LANCADOR"; return "$MEOW_ERRO" ;;
  esac
  # Mesmo cinto do `etapa_cli`: a `meow_escrever` sai ANTES do chmod quando o
  # conteúdo já confere, então um arquivo que perdeu o bit nunca o recuperaria.
  if [ -f "$LANCADOR" ] && [ ! -x "$LANCADOR" ]; then chmod 755 "$LANCADOR"; mudou=1; fi

  meow_escrever "$DESKTOP" "$(_texto_desktop)" 644; rc=$?
  case "$rc" in
    0) ;;
    1) mudou=1 ;;
    *) meow_erro "não consegui escrever $DESKTOP"; return "$MEOW_ERRO" ;;
  esac

  if [ "$mudou" = 0 ]; then
    meow_ok "atalho \"MeowSystem\" já está no lançador"
    return "$MEOW_OK"
  fi

  # O MENU DE LANÇAMENTO NÃO RELÊ SOZINHO — e é por isso que esta linha existe.
  # `lib/comum.sh` mede o caso: o `cosmic-app-library` e o `cosmic-launcher`
  # resolvem os `.desktop` no arranque e guardam. Sem chacoalhá-los, o atalho
  # está no disco e não está na tela dela, que são perguntas diferentes — e é
  # exatamente o "instalei e não apareceu" que aquele cabeçalho explica.
  # Chamar isto SÓ quando algo mudou é obrigatório: a função fecha a grade de
  # aplicativos se ela estiver aberta.
  meow_lancador_reler

  case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) meow_aviso "~/.local/bin não está no \$PATH — o atalho funciona, mas 'meow-painel' na mão não" ;;
  esac

  meow_ok "atalho \"MeowSystem\" instalado no lançador"
  meow_info "  abre em: $LANCADOR  ->  $RAIZ/app/run.sh"
  return "$MEOW_DIVERGENTE"
}

_reverter() {
  local n=0
  for arq in "$DESKTOP" "$LANCADOR"; do
    [ -e "$arq" ] || continue
    if meow_seco; then meow_muda "removeria $arq"; else rm -f "$arq"; fi
    n=$((n+1))
  done
  if [ "$n" = 0 ]; then
    meow_pula "o atalho do painel não estava instalado"
    return "$MEOW_OK"
  fi
  meow_seco || meow_lancador_reler
  meow_seco || meow_ok "atalho do painel removido ($n arquivo(s))"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"
