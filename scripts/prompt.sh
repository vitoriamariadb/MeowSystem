#!/usr/bin/env bash
# prompt.sh — o prompt do zsh, e a única etapa deste projeto que termina com um
# comando na mão DELA em vez de um arquivo no disco.
#
# O prompt do zsh mora em `~/.config/zsh/env.zsh`, que é o repositório do Ritual
# da Aurora — com auto-commit a cada 10 minutos.
#
# Só que a configuração do starship NÃO mora lá.
#
#     NOSSO   ~/.config/starship.toml   -> este script instala e confere
#     DELA    ~/.config/zsh/env.zsh     -> sai como `assets/prompt/aurora.patch`
#
# Isso não é meio-trabalho: é a única divisão que não mente.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}"
PROMPT_FONTE="$MEOW_RAIZ/assets/prompt/starship.toml"
PROMPT_ALVO="${PROMPT_ALVO:-$HOME/.config/starship.toml}"
# O `PROMPT_ZDOT`, o `PROMPT_ENV` e o `PROMPT_PATCH` saíram: eram o `env.zsh` do
# Spellbook e o patch para ele.

# A linha de instalação do starship, escrita uma vez só.
#
# O `--yes` entrou junto e é obrigatório: quem chama pelo painel não tem
# terminal, e um instalador que pergunta pendura o trabalho para sempre.
PROMPT_INSTALAR='curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"'
PROMPT_INSTALAR_ALT='cargo install starship --locked'

# --- as quatro perguntas, cada uma respondida por medição -------------------

# As duas pontas chamam esta mesma função; o que mudava era o PATH de quem
# chamava. A mesma pergunta, duas respostas.
_prompt_onde_starship() {
  local lugar
  for lugar in "$(command -v starship 2>/dev/null)" \
               "$HOME/.local/bin/starship" "$HOME/.cargo/bin/starship"; do
    [ -n "$lugar" ] && [ -x "$lugar" ] && { printf '%s' "$lugar"; return 0; }
  done
  return 1
}
_prompt_tem_starship() { _prompt_onde_starship >/dev/null; }

# As três perguntas ao `env.zsh` (o `starship init`, o `ZSH_THEME` e o
# `FZF_DEFAULT_OPTS`) saíram daqui — ver o cabeçalho.

# `meow_escrever` grava com `printf '%s'` e come o `\n` final do arquivo.
_PROMPT_PACK="$(meow_pack_dir)"
[ -n "$_PROMPT_PACK" ] || _PROMPT_PACK="$(meow_pack_padrao_dir 2>/dev/null || true)"
_PROMPT_PACK="$(basename "${_PROMPT_PACK:-meowsystem}")"
# O pack padrão (P96) é o Catppuccin dentro do meowsystem: a paleta do starship continua com o
# nome da família, `catppuccin_<flavor>`, que é o do preset de `assets/prompt/starship.toml`.
[ "$_PROMPT_PACK" = "meowsystem" ] && _PROMPT_PACK="catppuccin"

_prompt_desejado() {
  python3 -I - "$PROMPT_FONTE" "$(meow_paleta)" "$(meow_flavor)" "$_PROMPT_PACK" <<'PY'
import json, re, sys
fonte, paleta, flavor, pack = sys.argv[1:5]
with open(fonte, encoding="utf-8") as fh:
    texto = fh.read()
with open(paleta, encoding="utf-8") as fh:
    dados = json.load(fh)
cores = dados["flavors"][flavor]
nome = re.sub(r"[^a-z0-9_]", "_", f"{pack}_{flavor}".lower())
# A PALETA É DADO NÃO CONFIÁVEL, E O DESTINO É CÓDIGO — conferência da P74
#   (alerta de segurança de 09/10/2026). O `validar` confere o hex dos 26
#   slots e mais nada: um pack importado pode pôr na `ordem_canonica` um slot a
#   mais cujo valor fecha a aspa e abre um `[custom.x]` com `command = ...` —
#   e o starship roda esse comando a cada prompt. Só entra linha cujo nome é
#   uma palavra simples e cujo valor é `#RRGGBB`.
hexa = re.compile(r"^#[0-9A-Fa-f]{6}$")
bloco = f"[palettes.{nome}]\n" + "".join(
    f'{s} = "{cores[s].lower()}"\n' for s in (dados.get("ordem_canonica") or list(cores))
    if isinstance(s, str) and re.fullmatch(r"[a-z0-9]+", s)
    and isinstance(cores.get(s), str) and hexa.match(cores[s]))
texto = re.sub(r"^palette = '[^']*'$", f"palette = '{nome}'", texto, count=1, flags=re.M)
texto = re.sub(r'^\[palettes\.[^\]]+\]\n(?:[a-z0-9]+ = "#[0-9a-fA-F]{6}"\n)+', lambda _m: bloco,
               texto, count=1, flags=re.M)
sys.stdout.write(texto)
PY
}

_prompt_toml_confere() {
  [ -f "$PROMPT_ALVO" ] || return 1
  [ "$(_prompt_desejado)" = "$(cat "$PROMPT_ALVO")" ]
}

# O `_prompt_avisar_trava` saiu com o `env.zsh`,: ele perguntava se o
# `~/.config/zsh` estava no `vizinhos.conf`, que é a mesma adivinhação de
# vizinho que o `bin/meow` e o `install.sh` deixaram de fazer no mesmo dia.

# Sem este arquivo, um "não quero" viraria a mesma pergunta amanhã, e a
# pendência que volta todo dia é a notificação que a pessoa aprende a ignorar.
#
# Mora no estado, e não no meow.conf, porque não é ajuste: é a resposta a uma
# pergunta.
PROMPT_RECUSA="$MEOW_ESTADO/starship-recusado"

_prompt_dizer_falta_starship() {
  if [ -f "$PROMPT_RECUSA" ]; then
    # Nem pendência: ela já respondeu. O `meow_info` fica porque o código de
    # saída (3) precisa de um porquê na tela, e este é o porquê.
    meow_pula "o starship não está instalado, e você disse que não o quer"
    meow_info "  apague $PROMPT_RECUSA para reabrir a pergunta"
    return 0
  fi
  # Eram dois `meow_aviso`, e o `!!` pesa no veredito do doctor
  # (`pulado_com_aviso`): com o PROMPT_STARSHIP de fábrica, a falta de um
  # opcional deixava o auto-reparo vermelho todo dia.
  meow_pula "o starship não está instalado — ele é opcional, e não vem no apt do Pop!_OS"
  # A RECEITA SAIU DA TELA E VIROU O VERBO ABAIXO. Ela continua existindo, em
  # `$PROMPT_INSTALAR`, mas agora como algo que este script EXECUTA — e não
  # como um parágrafo que manda a pessoa executar.
  MEOW_PENDENCIA_ROTINA=1 meow_pendencia_acionavel starship-ausente \
    "O prompt do terminal precisa do starship, e ele não vem no apt do Pop!_OS" \
    "./scripts/prompt.sh instalar-starship"
}

# O zsh vem primeiro porque é o shell que este projeto conhece; o bash,
# porque é o padrão do Pop!_OS.
_prompt_dizer_ligacao() {
  meow_info "o terminal liga o starship pelo bloco do MeowSystem (scripts/terminal_bloco.sh)"
}

# --- conferir ---------------------------------------------------------------
#
# 0 tudo no lugar · 1 o NOSSO arquivo divergiu (e o doctor conserta) · 3 falta o
# starship, ou a etapa está desligada (nada a fazer).
#
# O 4 era "o nosso lado está certo e o `env.zsh` não foi patcheado", e existia
# para impedir o ping-pong de um conserto que não alcança a linha do outro lado.
cmd_conferir() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

  local tem_ss=0 toml_ok=0
  _prompt_tem_starship      && tem_ss=1
  _prompt_toml_confere      && toml_ok=1

  if [ "$tem_ss" = "0" ]; then
    _prompt_dizer_falta_starship
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if [ "$toml_ok" = "0" ]; then
    [ -f "$PROMPT_ALVO" ] && meow_muda "$PROMPT_ALVO divergente do nosso preset" \
                          || meow_muda "$PROMPT_ALVO ausente"
    return "$MEOW_DIVERGENTE"
  fi

  meow_ok "prompt conforme (starship, na paleta do pack $_PROMPT_PACK, flavor $(meow_flavor))"
  return "$MEOW_OK"
}

# --- aplicar ----------------------------------------------------------------
# ESCREVE UM ARQUIVO SÓ, E ELE É NOSSO. A linha do shell sai como texto na tela.
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
    meow_info "o preset entra assim que o starship estiver instalado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  local rc
  meow_escrever "$PROMPT_ALVO" "$(_prompt_desejado)" 644; rc=$?
  case "$rc" in
    "$MEOW_ERRO") meow_erro "não consegui escrever $PROMPT_ALVO"; return "$MEOW_ERRO" ;;
    "$MEOW_OK")   meow_ok "$PROMPT_ALVO já estava conforme" ;;
    *)  if meow_seco; then meow_muda "instalaria o preset em $PROMPT_ALVO"
        else meow_muda "prompt na paleta do pack $_PROMPT_PACK ($(meow_flavor)) instalado em $PROMPT_ALVO"
             meow_info "vale no PRÓXIMO prompt — o starship relê o arquivo a cada desenho"
        fi ;;
  esac

  # A linha do shell só é dita quando o arquivo acabou de mudar: é a hora em
  # que alguém está olhando para o prompt. Repeti-la a cada passagem do timer
  # seria o aviso que se aprende a ignorar.
  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && _prompt_dizer_ligacao

  meow_registrar "prompt.sh aplicar rc=$rc"
  return "$rc"
}

# --- mostrar ----------------------------------------------------------------
cmd_mostrar() {
  meow_titulo "O que liga o starship"
  printf '\n'
  _prompt_dizer_ligacao
  meow_info "o preset que ela desenha é o nosso: $PROMPT_ALVO"
  return "$MEOW_OK"
}

# --- remover ----------------------------------------------------------------
# Não é o inverso do `aplicar`, e o aviso é a parte que importa: ver o cabeçalho.
cmd_remover() {
  if [ ! -f "$PROMPT_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  # Sem ler o shell de ninguém não dá para saber se a linha do starship ainda
  # está lá — então o aviso sai sempre, que é o lado seguro de errar.
  meow_aviso "se o seu shell ainda inicia o starship, tirar este arquivo não devolve"
  meow_aviso "  o prompt antigo — devolve o prompt PADRÃO do starship. Tire a linha antes."
  meow_seco && { meow_muda "removeria $PROMPT_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$PROMPT_ALVO"
  meow_muda "removido $PROMPT_ALVO"
  meow_registrar "prompt.sh remover"
  return "$MEOW_DIVERGENTE"
}


# --- instalar-starship ------------------------------------------------------
#
# Esta função é a receita que o `_prompt_dizer_falta_starship` imprimia, virada
# ato.
#
# BAIXA DA INTERNET, e isso é dito antes de baixar.
#
# SEM SUDO, E ISSO É O DESENHO: o instalador oficial aceita `--bin-dir`, e
# `~/.local/bin` é da pessoa.
cmd_instalar_starship() {
  if _prompt_tem_starship; then
    meow_ok "o starship já está instalado ($(_prompt_onde_starship))"
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
  cmd_aplicar || true
  return "$MEOW_DIVERGENTE"
}

# --- instalar ----------------------------------------------------------------
# A etapa do install: o starship desce com ele, como o fastfetch, salvo a recusa
# gravada; depois, o preset.
cmd_instalar() {
  if [ "$PROMPT_STARSHIP" = "sim" ] && ! _prompt_tem_starship && [ ! -f "$PROMPT_RECUSA" ]; then
    cmd_instalar_starship
    return $?
  fi
  cmd_aplicar
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
  instalar)         cmd_instalar ;;
  conferir)         cmd_conferir ;;
  mostrar|patch)    cmd_mostrar ;;
  remover)          cmd_remover ;;
  instalar-starship)  cmd_instalar_starship ;;
  nao-quero-starship) cmd_recusar_starship ;;
  # Existe para o pré-voo do `install.sh` perguntar AQUI: com o `meow_tem`
  # dele, que só olha o PATH de agora, eram três donos do «tem starship», e
  # numa passagem com o PATH do systemd o pré-voo dizia «sem starship» na mesma
  # rodada em que esta etapa dizia «conforme».
  onde-starship)      _prompt_onde_starship ;;
  *) meow_erro "uso: prompt.sh {aplicar|instalar|conferir|mostrar|remover|instalar-starship|nao-quero-starship|onde-starship}"; exit "$MEOW_ERRO" ;;
esac
