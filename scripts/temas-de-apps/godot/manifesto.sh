#!/usr/bin/env bash

. "$MEOW_RAIZ/scripts/lib/tema_arquivo.sh"

_GODOT_FLATPAK="org.godotengine.Godot"
_GODOT_NOME="MeowSystem"

_godot_pastas() {
  local pasta
  for pasta in "${XDG_CONFIG_HOME:-$HOME/.config}/godot" "$HOME/.var/app/$_GODOT_FLATPAK/config/godot"; do
    compgen -G "$pasta/editor_settings-4*.tres" >/dev/null && printf '%s\n' "$pasta"
  done
}

_godot_tres() {
  python3 -I -c '
import re
import sys

modo, arq, nosso = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
meta = {}
secao = None
for linha in sys.stdin.read().split("\n"):
    m = re.match(r"\[(.+)\]\s*$", linha)
    if m:
        secao = m.group(1)
        continue
    m = re.match(r"([A-Za-z0-9_/]+)=\"(.*)\"\s*$", linha)
    if m and secao == "meowsystem":
        meta[m.group(1)] = m.group(2)


def rgb(hexa):
    hexa = hexa.lstrip("#")
    return [int(hexa[i:i + 2], 16) for i in (0, 2, 4)]


def cor(hexa):
    return "Color(" + ", ".join(format(v / 255, ".6g") for v in rgb(hexa)) + ", 1)"


try:
    with open(arq, encoding="utf-8") as f:
        linhas = f.read().rstrip("\n").split("\n")
except OSError:
    sys.exit(2)

minor = re.search(r"editor_settings-4\.(\d+)\.tres$", arq)
texto = "\n".join(linhas)
if "\ninterface/theme/color_preset " in texto:
    chave_preset = "interface/theme/color_preset"
elif "\ninterface/theme/preset " in texto:
    chave_preset = "interface/theme/preset"
else:
    chave_preset = "interface/theme/color_preset" if minor and int(minor.group(1)) >= 7 else "interface/theme/preset"
K_BASE, K_ACENTO, K_CONTRASTE = "interface/theme/base_color", "interface/theme/accent_color", "interface/theme/contrast"
K_TEXTO = "text_editor/theme/color_theme"
NOME = sys.argv[4]
contraste = meta["contraste_light" if meta["tipo"] == "light" else "contraste_dark"]
quer = {
    chave_preset: "\"Custom\"",
    K_BASE: cor(meta["base_color"]),
    K_ACENTO: cor(meta["accent_color"]),
    K_CONTRASTE: contraste,
}
quer_texto = "\"" + NOME + "\""


def indice(chave):
    prefixo = chave + " = "
    return next((i for i, l in enumerate(linhas) if l.startswith(prefixo)), None)


def valor(chave):
    i = indice(chave)
    return None if i is None else linhas[i][len(chave) + 3:]


def sem_aspas(v):
    return None if v is None else v.strip("\"")


def mesma_cor(a, b):
    if a is None:
        return False
    m = re.fullmatch(r"Color\(([^)]*)\)", a.strip())
    if not m:
        return False
    partes = [p.strip() for p in m.group(1).split(",")]
    try:
        atual = [round(float(p) * 255) for p in partes[:3]]
    except ValueError:
        return False
    return atual == rgb_de_cor(b)


def rgb_de_cor(c):
    return [round(float(p) * 255) for p in re.fullmatch(r"Color\(([^)]*)\)", c).group(1).split(",")[:3]]


def mesmo_numero(a, b):
    try:
        return abs(float(a) - float(b)) < 0.005
    except (TypeError, ValueError):
        return False


preset = sem_aspas(valor(chave_preset))
tema_texto = sem_aspas(valor(K_TEXTO))
interface_igual = (preset == "Custom" and mesma_cor(valor(K_BASE), quer[K_BASE])
                   and mesma_cor(valor(K_ACENTO), quer[K_ACENTO])
                   and mesmo_numero(valor(K_CONTRASTE), quer[K_CONTRASTE]))
texto_igual = tema_texto == NOME
interface = "igual" if interface_igual else ("muda" if (preset in (None, "Default") or (preset == "Custom" and nosso)) else "alheio")
escrito = "igual" if texto_igual else ("muda" if tema_texto in (None, "Default") else "alheio")
partes = (interface, escrito)


def veredito():
    if "muda" in partes:
        return "misto" if "alheio" in partes else "muda"
    return "alheio" if "alheio" in partes else "igual"


def por(chave, v):
    i = indice(chave)
    if i is not None:
        linhas[i] = chave + " = " + v
        return
    j = next((k for k, l in enumerate(linhas) if l.strip() == "[resource]"), None)
    if j is None:
        linhas.extend(["", "[resource]"])
        j = len(linhas) - 1
    linhas.insert(j + 1, chave + " = " + v)


def tirar(chave):
    i = indice(chave)
    if i is not None:
        del linhas[i]


if modo == "estado":
    print(veredito())
elif modo == "aplicar":
    if interface == "muda":
        for k, v in quer.items():
            por(k, v)
    if escrito == "muda":
        por(K_TEXTO, quer_texto)
    print(veredito())
    sys.stdout.write("\n".join(linhas))
elif modo == "reverter":
    if interface_igual:
        for k in quer:
            tirar(k)
    if texto_igual:
        tirar(K_TEXTO)
    print("muda" if (interface_igual or texto_igual) else "igual")
    sys.stdout.write("\n".join(linhas))
' "$@"
}

meow_app_instalado() { [ -n "$(_godot_pastas)" ]; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_app_instalado || { meow_app_sem "godot: sem configuração do editor — abra o Godot uma vez"; return; }
  meow_tarq_detectar godot godot
}

_godot_arquivo() {
  local acao="$1" arq="$2" nosso="$3" saida veredito texto rc
  saida="$(printf '%s' "$TARQ_BASE" | _godot_tres "${acao/conferir/estado}" "$arq" "$nosso" "$_GODOT_NOME")" \
    || { meow_erro "godot: não consegui ler $arq"; return "$MEOW_ERRO"; }
  veredito="${saida%%$'\n'*}"
  texto="${saida#*$'\n'}"
  case "$acao:$veredito" in
    conferir:igual|aplicar:igual|reverter:igual) return "$MEOW_OK" ;;
    conferir:alheio|aplicar:alheio)
      meow_pula "godot: $arq escolhe outro tema do editor — trocar é decisão sua"
      return "$MEOW_SEM_DEPENDENCIA" ;;
    conferir:*)
      meow_muda "godot: $arq não está no tema do pack de agora ($TARQ_QUERO)"
      return "$MEOW_DIVERGENTE" ;;
  esac
  meow_tarq_escrever "$arq" "$texto"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && { meow_erro "godot: falhou ao escrever $arq"; return "$MEOW_ERRO"; }
  meow_seco && return "$rc"
  if [ "$acao" = reverter ]; then
    meow_ok "godot: tema do pack saiu de $arq"
  else
    meow_ok "godot: tema do pack em $arq ($TARQ_QUERO)"
    [ "$veredito" = misto ] && meow_pula "godot: parte de $arq é escolha sua — deixei como está"
  fi
  return "$rc"
}

_godot_cada() {
  local acao="$1" pasta tet arq nosso rcs=()
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    tet="$pasta/text_editor_themes/$_GODOT_NOME.tet"
    "meow_tarq_${acao}_um" "godot" "$tet" "$TARQ_BASE"; rcs+=($?)
    [ "$(meow_tarq_estado "$tet" "$TARQ_BASE")" = alheio ] && continue
    meow_tarq_nosso "$tet" && nosso=1 || nosso=0
    for arq in "$pasta"/editor_settings-4*.tres; do
      _godot_arquivo "$acao" "$arq" "$nosso"; rcs+=($?)
    done
  done < <(_godot_pastas)
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _godot_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "godot: já está no tema do pack ($TARQ_QUERO)"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente godot; return; }
  _godot_cada aplicar
}

meow_app_reverter() {
  local pasta tet arq rcs=() soma
  meow_app_instalado || { meow_ok "godot: sem configuração do editor — nada a desfazer"; return "$MEOW_OK"; }
  meow_app_detectar || { meow_app_pendente godot; return; }
  while IFS= read -r pasta; do
    [ -n "$pasta" ] || continue
    tet="$pasta/text_editor_themes/$_GODOT_NOME.tet"
    if meow_tarq_nosso "$tet"; then
      for arq in "$pasta"/editor_settings-4*.tres; do
        _godot_arquivo reverter "$arq" 1; rcs+=($?)
      done
    fi
    meow_tarq_reverter_um godot "$tet"; rcs+=($?)
  done < <(_godot_pastas)
  meow_tarq_somar "${rcs[@]}"
  soma=$?
  [ "$soma" = "$MEOW_DIVERGENTE" ] && meow_app_desligar godot
  return "$soma"
}
