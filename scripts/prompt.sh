#!/usr/bin/env bash
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

PROMPT_STARSHIP="${PROMPT_STARSHIP:-sim}"
PROMPT_FONTE="$MEOW_RAIZ/assets/prompt/starship.toml"
PROMPT_ALVO="${PROMPT_ALVO:-$HOME/.config/starship.toml}"

PROMPT_INSTALAR='curl -sS https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"'

_prompt_onde_starship() {
  local lugar
  for lugar in "$(command -v starship 2>/dev/null)" \
               "$HOME/.local/bin/starship" "$HOME/.cargo/bin/starship"; do
    [ -n "$lugar" ] && [ -x "$lugar" ] && { printf '%s' "$lugar"; return 0; }
  done
  return 1
}
_prompt_tem_starship() { _prompt_onde_starship >/dev/null; }

_PROMPT_PACK="$(meow_pack_dir)"
[ -n "$_PROMPT_PACK" ] || _PROMPT_PACK="$(meow_pack_padrao_dir 2>/dev/null || true)"
_PROMPT_PACK="$(basename "${_PROMPT_PACK:-meowsystem}")"
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

PROMPT_RECUSA="$MEOW_ESTADO/starship-recusado"

_prompt_dizer_falta_starship() {
  if [ -f "$PROMPT_RECUSA" ]; then
    meow_pula "o starship não está instalado, e você disse que não o quer"
    meow_info "  apague $PROMPT_RECUSA para reabrir a pergunta"
    return 0
  fi
  meow_pula "o starship não está instalado — ele é opcional, e não vem no apt do Pop!_OS"
  MEOW_PENDENCIA_ROTINA=1 meow_pendencia_acionavel starship-ausente \
    "O prompt do terminal precisa do starship, e ele não vem no apt do Pop!_OS" \
    "./scripts/prompt.sh instalar-starship"
}

_prompt_dizer_ligacao() {
  meow_info "o terminal liga o starship pelo bloco do MeowSystem (scripts/terminal_bloco.sh)"
}

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

cmd_aplicar() {
  if [ "$PROMPT_STARSHIP" != "sim" ]; then
    meow_pula "prompt desligado no meow.conf (PROMPT_STARSHIP=\"$PROMPT_STARSHIP\")"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$PROMPT_FONTE" ] || { meow_erro "falta $PROMPT_FONTE"; return "$MEOW_ERRO"; }

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

  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && _prompt_dizer_ligacao

  meow_registrar "prompt.sh aplicar rc=$rc"
  return "$rc"
}

cmd_mostrar() {
  meow_titulo "O que liga o starship"
  printf '\n'
  _prompt_dizer_ligacao
  meow_info "o preset que ela desenha é o nosso: $PROMPT_ALVO"
  return "$MEOW_OK"
}

cmd_remover() {
  if [ ! -f "$PROMPT_ALVO" ]; then meow_pula "nada a remover"; return "$MEOW_OK"; fi
  meow_aviso "se o seu shell ainda inicia o starship, tirar este arquivo não devolve"
  meow_aviso "  o prompt antigo — devolve o prompt PADRÃO do starship. Tire a linha antes."
  meow_seco && { meow_muda "removeria $PROMPT_ALVO"; return "$MEOW_DIVERGENTE"; }
  rm -f "$PROMPT_ALVO"
  meow_muda "removido $PROMPT_ALVO"
  meow_registrar "prompt.sh remover"
  return "$MEOW_DIVERGENTE"
}


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
  if ! sh -c "$PROMPT_INSTALAR" || ! _prompt_tem_starship; then
    meow_erro "o instalador do starship falhou (sem rede?)"
    return "$MEOW_ERRO"
  fi
  meow_muda "starship instalado em $HOME/.local/bin"
  meow_pendencia_resolvida starship-ausente
  meow_registrar "prompt.sh instalar-starship"
  cmd_aplicar || true
  return "$MEOW_DIVERGENTE"
}

cmd_instalar() {
  if [ "$PROMPT_STARSHIP" = "sim" ] && ! _prompt_tem_starship && [ ! -f "$PROMPT_RECUSA" ]; then
    cmd_instalar_starship
    return $?
  fi
  cmd_aplicar
}

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
  onde-starship)      _prompt_onde_starship ;;
  *) meow_erro "uso: prompt.sh {aplicar|instalar|conferir|mostrar|remover|instalar-starship|nao-quero-starship|onde-starship}"; exit "$MEOW_ERRO" ;;
esac
