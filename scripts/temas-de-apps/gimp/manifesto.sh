#!/usr/bin/env bash

. "$MEOW_RAIZ/scripts/lib/tema_arquivo.sh"

_GIMP_ID="org.gimp.GIMP"
_GIMP_NOME="MeowSystem"
_GIMP_DADOS_FLATPAK="/app/share/gimp/3.0"

_gimp_dados_nativo() {
  local dados
  for dados in /usr/share/gimp/3.0 /usr/local/share/gimp/3.0; do
    [ -d "$dados/themes/Default" ] && { printf '%s\n' "$dados"; return; }
  done
}

_gimp_alvos() {
  local flatpak=0 dados dir
  meow_tem flatpak && meow_flatpak_tem "$_GIMP_ID" && flatpak=1
  if [ "$flatpak" = 1 ]; then
    dados="$_GIMP_DADOS_FLATPAK"
  elif meow_tem gimp; then
    dados="$(_gimp_dados_nativo)"
    [ -n "$dados" ] || return 0
  else
    return 0
  fi
  for dir in "${XDG_CONFIG_HOME:-$HOME/.config}"/GIMP/3.* "$HOME/.var/app/$_GIMP_ID/config/GIMP"/3.*; do
    [ -d "$dir" ] && printf '%s\t%s\n' "$dir" "$dados"
  done
}

_gimp_tipo() {
  printf '%s\n' "$TARQ_BASE" | sed -n 's|^/\* tipo: \([a-z]*\) \*/$|\1|p' | head -n 1
}

_gimp_css() {
  printf '%s' "$TARQ_BASE" | python3 -I -c '
import sys

dados, tipo = sys.argv[1], sys.argv[2]
linhas = sys.stdin.read().split("\n")
alvo = "/* escuro */" if tipo == "dark" else "/* claro */"
saida = [linhas[0], "", "@import url(\"file://" + dados + "/themes/Default/gimp-" + tipo + ".css\");", ""]
dentro = False
for linha in linhas[1:]:
    if linha in ("/* escuro */", "/* claro */"):
        dentro = linha == alvo
        continue
    if dentro:
        saida.append(linha)
sys.stdout.write("\n".join(saida).rstrip("\n"))
' "$1" "$2"
}

_gimp_rc() {
  python3 -I -c '
import re
import sys

acao, arq, valor = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    with open(arq, encoding="utf-8") as f:
        texto = f.read()
except OSError:
    texto = ""
linhas = texto.rstrip("\n").split("\n") if texto.strip() else []
i = next((k for k, l in enumerate(linhas) if re.match(r"\(theme\s+\"", l)), None)
atual = ""
if i is not None:
    m = re.match(r"\(theme\s+\"(.*)\"\)\s*$", linhas[i])
    atual = m.group(1) if m else "?"
if acao == "pegar":
    print(atual)
    sys.exit(0)
if acao == "por":
    nova = "(theme \"" + valor + "\")"
    if i is None:
        linhas.append(nova)
    else:
        linhas[i] = nova
elif acao == "tirar" and i is not None and atual == valor:
    del linhas[i]
sys.stdout.write("\n".join(linhas))
' "$@"
}

_gimp_rc_estado() {
  case "$(_gimp_rc pegar "$1" x)" in
    "$_GIMP_NOME") printf 'igual' ;;
    ""|Default) printf 'ausente' ;;
    *) printf 'alheio' ;;
  esac
}

_gimp_rc_conferir() {
  local arq="$1"
  case "$(_gimp_rc_estado "$arq")" in
    igual) return "$MEOW_OK" ;;
    ausente) meow_muda "gimp: (theme \"$_GIMP_NOME\") falta em $arq"; return "$MEOW_DIVERGENTE" ;;
    alheio) meow_pula "gimp: $arq escolhe outro tema em theme — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
}

_gimp_rc_aplicar() {
  local arq="$1" novo rc
  case "$(_gimp_rc_estado "$arq")" in
    igual) return "$MEOW_OK" ;;
    alheio) meow_pula "gimp: $arq escolhe outro tema em theme — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
  novo="$(_gimp_rc por "$arq" "$_GIMP_NOME")" || { meow_erro "gimp: não montei $arq"; return "$MEOW_ERRO"; }
  meow_tarq_escrever "$arq" "$novo"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && { meow_erro "gimp: falhou ao escrever $arq"; return "$MEOW_ERRO"; }
  return "$rc"
}

_gimp_rc_reverter() {
  local arq="$1" novo
  [ "$(_gimp_rc_estado "$arq")" = igual ] || return "$MEOW_OK"
  if meow_seco; then meow_muda "gimp: tiraria theme de $arq"; return "$MEOW_DIVERGENTE"; fi
  novo="$(_gimp_rc tirar "$arq" "$_GIMP_NOME")" || return "$MEOW_ERRO"
  if [ -z "$novo" ]; then rm -f -- "$arq"; else meow_tarq_escrever "$arq" "$novo" >/dev/null; fi
  meow_ok "gimp: theme saiu de $arq"
  return "$MEOW_DIVERGENTE"
}

meow_app_instalado() { [ -n "$(_gimp_alvos)" ]; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "gimp: não está instalado, ou ainda não criou a pasta de configuração — abra o GIMP uma vez"; return; }
  meow_tarq_detectar gimp gimp || return $?
  [ -n "$(_gimp_tipo)" ] || meow_app_sem "gimp: o modelo do pack $TARQ_DE não diz o tipo (claro ou escuro) do flavor"
}

_gimp_cada() {
  local acao="$1" dir dados tipo outro css pasta arq rcs=()
  tipo="$(_gimp_tipo)"
  [ "$tipo" = dark ] && outro=light || outro=dark
  while IFS=$'\t' read -r dir dados; do
    [ -n "$dir" ] || continue
    pasta="$dir/themes/$_GIMP_NOME"
    arq="$pasta/gimp-$tipo.css"
    css="$(_gimp_css "$dados" "$tipo")"
    "meow_tarq_${acao}_um" "gimp" "$arq" "$css"; rcs+=($?)
    if [ "$acao" = aplicar ]; then
      meow_tarq_reverter_um gimp "$pasta/gimp-$outro.css" >/dev/null; rcs+=($?)
    fi
    [ "$(meow_tarq_estado "$arq" "$css")" = alheio ] && continue
    "_gimp_rc_${acao}" "$dir/gimprc"; rcs+=($?)
  done < <(_gimp_alvos)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _gimp_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "gimp: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente gimp; return; }
  _gimp_cada aplicar
}

meow_app_reverter() {
  local dir dados pasta variante rcs=() soma
  while IFS=$'\t' read -r dir dados; do
    [ -n "$dir" ] || continue
    pasta="$dir/themes/$_GIMP_NOME"
    _gimp_rc_reverter "$dir/gimprc"; rcs+=($?)
    for variante in dark light; do
      meow_tarq_reverter_um gimp "$pasta/gimp-$variante.css"; rcs+=($?)
    done
  done < <(_gimp_alvos)
  [ "${#rcs[@]}" -gt 0 ] || { meow_ok "gimp: não está instalado — nada a desfazer"; return "$MEOW_OK"; }
  meow_tarq_somar "${rcs[@]}"
  soma=$?
  [ "$soma" = "$MEOW_DIVERGENTE" ] && meow_app_desligar gimp
  return "$soma"
}
