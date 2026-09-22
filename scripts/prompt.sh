#!/usr/bin/env bash
# prompt.sh — o prompt do zsh, e a única etapa deste projeto que termina com um
# comando na mão DELA em vez de um arquivo no disco.
#
# POR QUE ESTA É A ETAPA PARTIDA AO MEIO
#   O prompt do zsh mora em `~/.config/zsh/env.zsh`, que é o repositório do
#   Ritual da Aurora — com auto-commit a cada 10 minutos. A TRAVA 1 do
#   `lib/comum.sh` recusa aquele caminho POR CAMINHO (`vizinhos.conf`), e está
#   certa: um arquivo largado ali vira commit no repositório PRIVADO dela sem
#   ninguém apertar nada.
#
#   Só que a configuração do starship NÃO mora lá. Ela mora em
#   `~/.config/starship.toml`, que é um caminho comum do XDG e não pertence a
#   vizinho nenhum — medido: `meow_destino_permitido` o aceita. Então a sprint se
#   parte exatamente onde a fronteira parte:
#
#     NOSSO   ~/.config/starship.toml   -> este script instala e confere
#     DELA    ~/.config/zsh/env.zsh     -> sai como `assets/prompt/aurora.patch`
#
#   Isso não é meio-trabalho: é a única divisão que não mente. Um script que
#   escrevesse as duas metades atravessaria a fronteira; um que não escrevesse
#   nenhuma deixaria na mão dela um arquivo de 260 linhas para copiar.
#
# O QUE FOI MEDIDO ANTES DE ESCREVER ISTO (25/08/2026)
#   - `starship` NÃO está no apt do Pop!_OS 24.04 (noble). `apt-cache policy
#     starship` devolve VAZIO e `apt-cache show starship` diz "Nenhum pacote
#     encontrado". O que existe no universe são as CAIXAS de Rust
#     (`librust-starship-module-config-derive-dev`), que são fonte para
#     compilar outra coisa, não o binário. Instala por script oficial ou cargo.
#   - O prompt em uso NÃO era o `agnoster`. O `ZSH_THEME="agnoster"` da linha 9
#     era carregado pelo oh-my-zsh e SOBRESCRITO pelo `export PS1` da linha 135
#     do mesmo arquivo. Medido no shell vivo:
#       zsh -i -c 'print -r -- $PROMPT'
#     devolve o PS1 de fundo azul, nunca um segmento do agnoster.
#   - A Nerd Font dela é `JetBrainsMono Nerd Font Mono`, instalada pelo
#     `scripts/instalar_fontes.sh` em ~/.local/share/fonts/MeowSystem, e é a
#     mesma que o `cosmic-term` usa (chave `font_name`). Os 44 codepoints
#     não-ASCII do nosso `starship.toml` existem nela — conferido com
#     `fc-query -f '%{charset}'`.
#
# POR QUE NÃO EXISTE `--reverter` QUE DESFAÇA TUDO
#   Aqui o "reverter" do MeowSystem é o oposto do caso do applet de mídia. Lá,
#   apagar a sombra devolvia o applet de fábrica e a dock voltava a funcionar.
#   Aqui, apagar só a NOSSA metade (o `starship.toml`) com o `env.zsh` ainda
#   chamando o starship não devolve o prompt antigo: devolve o prompt PADRÃO do
#   starship, que ninguém escolheu. Por isso `PROMPT_STARSHIP="nao"` no meow.conf quer
#   dizer "não mexo", e não "desfaz" — e o `remover` existe, mas avisa alto e é
#   comando de mão, nunca de timer.
#
# USO
#   prompt.sh conferir   0 = conforme · 1 = divergente (nosso) · 3 = falta
#                        dependência · 4 = falta a metade DELA (o patch)
#   prompt.sh aplicar    instala ~/.config/starship.toml e diz o que sobra
#   prompt.sh mostrar    imprime o patch do env.zsh e o comando de aplicação
#   prompt.sh remover    tira o NOSSO arquivo (leia o aviso acima antes)
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# A CHAVE NÃO SE CHAMA `PROMPT`, E O MOTIVO É MEDIDO
#   `PROMPT` é a variável do prompt no zsh. O meow.conf é sourceado por bash
#   (`bin/meow` e `install.sh` são os dois `#!/usr/bin/env bash`), onde o nome é
#   inofensivo — mas basta alguém dar um `. ~/.config/meow/meow.conf` num zsh
#   para inspecionar o arquivo e o prompt daquele terminal virar "sim". Um nome
#   com dois caracteres a mais custa menos que esse susto.
PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}"
PROMPT_FONTE="$MEOW_RAIZ/assets/prompt/starship.toml"
PROMPT_PATCH="$MEOW_RAIZ/assets/prompt/aurora.patch"
PROMPT_ALVO="${PROMPT_ALVO:-$HOME/.config/starship.toml}"
# `ZDOTDIR` não chega aqui (este script roda em bash, e a variável é do shell
# interativo dela), então o padrão é a convenção — que é o que ela usa.
PROMPT_ZDOT="${ZDOTDIR:-$HOME/.config/zsh}"
PROMPT_ENV="$PROMPT_ZDOT/env.zsh"

# A linha de instalação do starship, escrita uma vez só.
#
# ATÉ 22/09/2026 ELA NÃO ERA RODADA POR NINGUÉM — era impressa, e a pessoa que
# copiasse. A sprint P2 inverteu isso: quem a roda agora é o
# `cmd_instalar_starship`, aqui embaixo, e ela continua sendo UMA linha só para
# que o que a tela promete e o que o botão executa nunca possam divergir.
#
# O `--yes` entrou junto e é obrigatório: quem chama pelo painel não tem
# terminal, e um instalador que pergunta pendura o trabalho para sempre.
# O `--bin-dir` continua sendo o ponto todo — sem `sudo`, no diretório dela.
PROMPT_INSTALAR='curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"'
PROMPT_INSTALAR_ALT='cargo install starship --locked'

# --- as quatro perguntas, cada uma respondida por medição -------------------

_prompt_tem_starship() { meow_tem starship; }

# O `env.zsh` chama o starship? Casa a inicialização, não a palavra solta — um
# comentário mencionando "starship" não é o mesmo que o `eval` que o liga.
_prompt_env_liga_starship() {
  [ -f "$PROMPT_ENV" ] || return 1
  grep -qE 'starship[[:space:]]+init[[:space:]]+zsh' "$PROMPT_ENV"
}

# O `ZSH_THEME` ainda carrega tema do oh-my-zsh? Vazio ou ausente é o certo.
_prompt_env_tema_velho() {
  [ -f "$PROMPT_ENV" ] || return 1
  grep -qE '^[[:space:]]*ZSH_THEME=("[^"]+"|[^"[:space:]#]+)' "$PROMPT_ENV"
}

_prompt_env_tem_fzf() {
  [ -f "$PROMPT_ENV" ] || return 1
  grep -qE '^[[:space:]]*(export[[:space:]]+)?FZF_DEFAULT_OPTS=' "$PROMPT_ENV"
}

# COMPARAÇÃO PELO CRITÉRIO DO ESCRITOR, NUNCA `cmp`
#   `meow_escrever` grava com `printf '%s'` e come o `\n` final do arquivo. Um
#   `cmp -s` entre a fonte (que termina em nova linha) e o destino (que não
#   termina) acusaria divergência para SEMPRE, num arquivo perfeito — é o mesmo
#   defeito que o `chk_mimetypes` do `bin/meow` já documenta. As duas
#   substituições de comando abaixo aparam a nova linha final dos dois lados.
_prompt_toml_confere() {
  [ -f "$PROMPT_ALVO" ] || return 1
  [ "$(cat "$PROMPT_FONTE")" = "$(cat "$PROMPT_ALVO")" ]
}

# A trava vale? Se `~/.config/zsh` não estiver no `vizinhos.conf`, este script
# continua sem escrever lá — mas o resto do projeto perdeu a rede de proteção, e
# quem descobre isso tem de ser alguém, não um commit surpresa.
_prompt_avisar_trava() {
  if meow_destino_permitido "$PROMPT_ENV" 2>/dev/null; then
    meow_aviso "$PROMPT_ZDOT NÃO está protegido em $MEOW_VIZINHOS"
    meow_aviso "  este script não escreve lá de qualquer jeito, mas a TRAVA 1 está aberta"
    meow_info  "  há um modelo em $MEOW_RAIZ/vizinhos.conf.exemplo"
  fi
}

# A RECUSA FICA GRAVADA, E ESSA É A METADE QUE FALTAVA — 22/09/2026, sprint P2
#   A regra da P2 é "ou faz, ou oferece um botão que faz". Mas instalar o
#   starship BAIXA DA INTERNET, e isso é escolha genuína — então a outra metade
#   da regra vale junto: a tela pergunta UMA vez. Sem este arquivo, um "não
#   quero" viraria a mesma pergunta amanhã, e a pendência que volta todo dia é
#   a notificação que a pessoa aprende a ignorar.
#
#   Mora no estado, e não no meow.conf, porque não é ajuste: é a resposta a uma
#   pergunta. Apagar o arquivo faz a pergunta voltar, que é o desfazer óbvio.
PROMPT_RECUSA="$MEOW_ESTADO/starship-recusado"

_prompt_dizer_falta_starship() {
  meow_aviso "o starship NÃO está instalado, e ele não está no apt do Pop!_OS"
  meow_aviso "  (\`apt-cache policy starship\` devolve vazio nesta máquina)"
  if [ -f "$PROMPT_RECUSA" ]; then
    # Nem pendência: ela já respondeu. O `meow_info` fica porque o código de
    # saída (3) precisa de um porquê na tela, e este é o porquê.
    meow_info "  você já disse que não quer instalá-lo — apague $PROMPT_RECUSA para reabrir"
    return 0
  fi
  # A RECEITA SAIU DA TELA E VIROU O VERBO ABAIXO. Ela continua existindo, em
  # `$PROMPT_INSTALAR`, mas agora como algo que este script EXECUTA — e não
  # como um parágrafo que manda a pessoa executar.
  meow_pendencia_acionavel starship-ausente \
    "O prompt do terminal precisa do starship, e ele não vem no apt do Pop!_OS" \
    "./scripts/prompt.sh instalar-starship"
}

_prompt_dizer_metade_dela() {
  meow_info "falta a metade que é sua — o \`env.zsh\` é do Ritual da Aurora:"
  meow_info "  cd $PROMPT_ZDOT"
  meow_info "  patch -p1 --dry-run < $PROMPT_PATCH   # confere sem escrever"
  meow_info "  patch -p1           < $PROMPT_PATCH"
  meow_aviso "isso vira commit no seu repositório privado em até 10 min, sozinho"
}

# --- conferir ---------------------------------------------------------------
# OS QUATRO CÓDIGOS, E A RAZÃO DE O 4 EXISTIR AQUI
#   0 tudo no lugar · 1 o NOSSO arquivo divergiu (e o doctor conserta) · 3 falta
#   o starship, ou a etapa está desligada (nada a fazer) · 4 o nosso lado está
#   certo e o `env.zsh` não foi patcheado.
#
#   O 4 é o que impede o ping-pong. Sem ele esta etapa devolveria 1 todo dia,
#   para sempre, e o `meow doctor --consertar` rodaria um conserto que não pode
#   consertar nada — porque a linha que falta está do outro lado da fronteira.
#   O `bin/meow` já sabe ler o 4: "é escolha sua, não divergência".
cmd_conferir() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

  local tem_ss=0 toml_ok=0 env_ok=0 fzf_ok=0 tema_velho=0
  _prompt_tem_starship      && tem_ss=1
  _prompt_toml_confere      && toml_ok=1
  _prompt_env_liga_starship && env_ok=1
  _prompt_env_tem_fzf       && fzf_ok=1
  _prompt_env_tema_velho    && tema_velho=1

  # A metade meio-aplicada é a pior de todas e por isso vem primeiro: o env.zsh
  # chama o starship e o nosso .toml não está lá. O prompt na tela dela não é o
  # antigo nem o nosso — é o PADRÃO do starship, que ninguém escolheu.
  if [ "$env_ok" = "1" ] && [ "$toml_ok" = "0" ]; then
    meow_muda "o env.zsh já chama o starship, mas $PROMPT_ALVO não é o nosso"
    meow_aviso "o prompt na tela é o PADRÃO do starship — rode: meow doctor --consertar"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$tem_ss" = "0" ]; then
    _prompt_dizer_falta_starship
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ "$toml_ok" = "0" ]; then
    [ -f "$PROMPT_ALVO" ] && meow_muda "$PROMPT_ALVO divergente do nosso preset" \
                          || meow_muda "$PROMPT_ALVO ausente"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$env_ok" = "0" ] || [ "$fzf_ok" = "0" ]; then
    local falta=""
    [ "$env_ok" = "0" ] && falta="starship"
    [ "$fzf_ok" = "0" ] && falta="${falta:+$falta e }FZF_DEFAULT_OPTS"
    meow_info "o starship.toml está conforme; o env.zsh ainda não tem $falta"
    _prompt_dizer_metade_dela
    return 4
  fi

  if [ "$tema_velho" = "1" ]; then
    meow_aviso "o env.zsh liga o starship E ainda define ZSH_THEME — o oh-my-zsh"
    meow_aviso "  carrega um tema a cada shell só para jogá-lo fora. Sem sintoma na"
    meow_aviso "  tela, só custo de partida. O patch ao lado zera a chave."
  fi
  meow_ok "prompt conforme (starship, preset catppuccin-powerline, accent mauve)"
  return "$MEOW_OK"
}

# --- aplicar ----------------------------------------------------------------
# ESCREVE UM ARQUIVO SÓ, E ELE É NOSSO. A metade dela sai como texto na tela.
cmd_aplicar() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

  # Sem o starship, escrever a configuração dele seria plantar um arquivo que
  # nada lê — e presumir uma instalação que é decisão dela. O 3 é honesto: a
  # etapa se pula, e o `install.sh` a mostra em "pulado" em vez de "mexeu".
  if ! _prompt_tem_starship; then
    _prompt_dizer_falta_starship
    meow_info "depois de instalar, rode de novo: meow doctor --consertar"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  _prompt_avisar_trava

  local rc
  meow_escrever "$PROMPT_ALVO" "$(cat "$PROMPT_FONTE")" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui escrever $PROMPT_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_OK")   meow_ok "$PROMPT_ALVO já estava conforme" ;;
    *)  if meow_seco; then meow_muda "instalaria o preset em $PROMPT_ALVO"
        else meow_muda "preset catppuccin-powerline instalado em $PROMPT_ALVO"
             meow_info "vale no PRÓXIMO prompt — o starship relê o arquivo a cada desenho"
        fi ;;
  esac

  if _prompt_env_liga_starship && _prompt_env_tem_fzf; then
    meow_ok "o env.zsh já tem as duas linhas — nada sobra para você fazer"
  else
    _prompt_dizer_metade_dela
    [ "$rc" = "$MEOW_OK" ] && rc=4
  fi

  meow_registrar "prompt.sh aplicar rc=$rc"
  return "$rc"
}

# --- mostrar ----------------------------------------------------------------
cmd_mostrar() {
  [ -f "$PROMPT_PATCH" ] || { meow_erro "falta $PROMPT_PATCH"; return "$MEOW_ERRO"; }
  meow_titulo "O patch do env.zsh — o MeowSystem NÃO o aplica"
  printf '\n'
  cat "$PROMPT_PATCH"
  printf '\n'
  _prompt_dizer_metade_dela
  meow_info "para desfazer, byte a byte:"
  meow_info "  cd $PROMPT_ZDOT && patch -R -p1 < $PROMPT_PATCH"
  return "$MEOW_OK"
}

# --- remover ----------------------------------------------------------------
# Não é o inverso do `aplicar`, e o aviso é a parte que importa: ver o cabeçalho.
cmd_remover() {
  if [ ! -f "$PROMPT_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  if _prompt_env_liga_starship; then
    meow_aviso "o env.zsh AINDA chama o starship. Tirar só este arquivo não devolve"
    meow_aviso "  o prompt antigo — devolve o prompt PADRÃO do starship."
    meow_info  "  desfaça a outra metade primeiro:"
    meow_info  "    cd $PROMPT_ZDOT && patch -R -p1 < $PROMPT_PATCH"
  fi
  meow_seco && { meow_muda "removeria $PROMPT_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$PROMPT_ALVO"
  meow_muda "removido $PROMPT_ALVO"
  meow_registrar "prompt.sh remover"
  return "$MEOW_DIVERGENTE"
}


# --- instalar-starship ------------------------------------------------------
# O CONSERTO QUE ERA UM PARÁGRAFO — 22/09/2026, sprint P2
#   Esta função é a receita que o `_prompt_dizer_falta_starship` imprimia,
#   virada ato. Ela não é esperteza nova: é a MESMA linha, lida da MESMA
#   variável (`PROMPT_INSTALAR`) que o cabeçalho deste arquivo já documentava
#   desde 25/08/2026 — só que agora quem a roda é o projeto.
#
#   BAIXA DA INTERNET, e isso é dito antes de baixar. É o rótulo que os cartões
#   de ação do painel já usam, e a pendência que leva a este verbo o herda.
#
#   SEM SUDO, E ISSO É O DESENHO: o instalador oficial aceita `--bin-dir`, e
#   `~/.local/bin` é da pessoa. Um conserto que pedisse root aqui não poderia
#   ser botão no painel, que roda sem terminal (ver docs/FRONTEIRA.md, a ponte).
cmd_instalar_starship() {
  if _prompt_tem_starship; then
    meow_ok "o starship já está instalado ($(command -v starship))"
    meow_pendencia_resolvida starship-ausente
    return "$MEOW_OK"
  fi
  meow_tem curl || { meow_erro "falta o curl, e é ele que busca o instalador"; return "$MEOW_SEM_DEPENDENCIA"; }

  meow_info "BAIXA DA INTERNET: starship.rs, para ~/.local/bin (sem sudo)"
  if meow_seco; then
    meow_muda "instalaria o starship em ~/.local/bin"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$HOME/.local/bin" 2>/dev/null || true
  # `sh -c` SOBRE UMA CONSTANTE DESTE ARQUIVO, e não sobre entrada de ninguém:
  # é o que permite a linha existir uma vez só, dez linhas acima, em vez de uma
  # cópia aqui e outra na frase da tela — que foi como as receitas deste projeto
  # envelheceram até agora.
  if ! sh -c "$PROMPT_INSTALAR"; then
    meow_erro "o instalador do starship falhou (sem rede?)"
    meow_info "a alternativa, pelo cargo: $PROMPT_INSTALAR_ALT"
    return "$MEOW_ERRO"
  fi
  meow_muda "starship instalado em $HOME/.local/bin"
  meow_pendencia_resolvida starship-ausente
  meow_registrar "prompt.sh instalar-starship"
  meow_info "agora rode:  meow doctor --consertar  — é ele que escreve o preset"
  return "$MEOW_DIVERGENTE"
}

# --- nao-quero-starship -----------------------------------------------------
# A OUTRA RESPOSTA, e ela precisa existir para a pergunta ser uma pergunta.
cmd_recusar_starship() {
  meow_seco && { meow_muda "gravaria a recusa em $PROMPT_RECUSA"; return "$MEOW_DIVERGENTE"; }
  mkdir -p "$MEOW_ESTADO" 2>/dev/null || true
  cat > "$PROMPT_RECUSA" <<FIM
Você disse que não quer instalar o starship, em $(date '+%d/%m/%Y %H:%M:%S').

Enquanto este arquivo existir, o MeowSystem não volta a oferecer a instalação:
a etapa do prompt se pula, sem escrever nada, e o resto do tema segue igual.

Para reabrir a pergunta, apague este arquivo.
FIM
  meow_pendencia_resolvida starship-ausente
  meow_muda "recusa gravada — o starship não volta a ser oferecido"
  return "$MEOW_DIVERGENTE"
}

case "${1:-aplicar}" in
  aplicar)          cmd_aplicar ;;
  conferir)         cmd_conferir ;;
  mostrar|patch)    cmd_mostrar ;;
  remover)          cmd_remover ;;
  instalar-starship)  cmd_instalar_starship ;;
  nao-quero-starship) cmd_recusar_starship ;;
  *) meow_erro "uso: prompt.sh {aplicar|conferir|mostrar|remover|instalar-starship|nao-quero-starship}"; exit "$MEOW_ERRO" ;;
esac
