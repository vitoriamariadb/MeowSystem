#!/usr/bin/env bash

MEOW_TARQ_MARCA="meowsystem-tema:"
MEOW_TARQ_MODELO_PY="$MEOW_RAIZ/scripts/temas-de-apps/modelo.py"

meow_tarq_nosso() {
  [ -f "$1" ] && head -n 5 -- "$1" 2>/dev/null | grep -qF -- "$MEOW_TARQ_MARCA"
}

meow_tarq_detectar() {
  local rotulo="$1" trilha="$2" saida
  MEOW_APP_MOTIVO=""
  meow_tem python3 || { meow_app_sem "$rotulo: falta python3, que monta o tema com a paleta do pack"; return; }
  meow_app_tema_do_pack "$trilha.arquivo"
  TARQ_DE="$MEOW_APP_TEMA_PACK"
  [ -n "$MEOW_APP_TEMA" ] || { meow_app_sem "$rotulo: o pack no ar não declara tema para o $rotulo"; return; }
  TARQ_MODELO="$MEOW_APP_TEMA"
  TARQ_BASE="$(meow_tarq_montar "$TARQ_MODELO")" \
    || { meow_app_sem "$rotulo: o modelo do pack $TARQ_DE não montou — $TARQ_BASE"; return; }
  TARQ_QUERO="$TARQ_DE/${FLAVOR:-}"
  return "$MEOW_OK"
}

meow_tarq_montar() {
  python3 "$MEOW_TARQ_MODELO_PY" "$1" "$(meow_paleta)" "${FLAVOR:-}" "${TARQ_DE:-}" 2>&1
}

meow_tarq_estado() {
  local destino="$1" desejado="$2"
  if [ ! -f "$destino" ]; then printf 'ausente'; return; fi
  if ! meow_tarq_nosso "$destino"; then printf 'alheio'; return; fi
  if [ "$(cat "$destino")" = "$desejado" ]; then printf 'igual'; else printf 'diferente'; fi
}

meow_tarq_escrever() {
  local destino="$1" conteudo="$2" rc
  meow_escrever "$destino" "$conteudo" 644; rc=$?
  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && printf '\n' >> "$destino"
  return "$rc"
}

meow_tarq_conferir_um() {
  local rotulo="$1" destino="$2" desejado="$3"
  case "$(meow_tarq_estado "$destino" "$desejado")" in
    igual)     return "$MEOW_OK" ;;
    ausente)   meow_muda "$rotulo: falta $destino"; return "$MEOW_DIVERGENTE" ;;
    diferente) meow_muda "$rotulo: $destino não é o do pack de agora ($TARQ_QUERO)"; return "$MEOW_DIVERGENTE" ;;
    alheio)    meow_pula "$rotulo: $destino existe e não veio do MeowSystem — deixei como está"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
}

meow_tarq_aplicar_um() {
  local rotulo="$1" destino="$2" desejado="$3" rc
  case "$(meow_tarq_estado "$destino" "$desejado")" in
    igual) return "$MEOW_OK" ;;
    alheio) meow_pula "$rotulo: $destino existe e não veio do MeowSystem — deixei como está"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
  meow_tarq_escrever "$destino" "$desejado"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && { meow_erro "$rotulo: falhou ao escrever $destino"; return "$MEOW_ERRO"; }
  meow_seco || meow_ok "$rotulo: tema do pack em $destino ($TARQ_QUERO)"
  return "$rc"
}

meow_tarq_reverter_um() {
  local rotulo="$1" destino="$2"
  meow_tarq_nosso "$destino" || return "$MEOW_OK"
  if meow_seco; then meow_muda "$rotulo: tiraria $destino"; return "$MEOW_DIVERGENTE"; fi
  rm -f -- "$destino" || { meow_erro "$rotulo: não consegui tirar $destino"; return "$MEOW_ERRO"; }
  rmdir --ignore-fail-on-non-empty -- "$(dirname "$destino")" 2>/dev/null
  meow_ok "$rotulo: $destino saiu"
  return "$MEOW_DIVERGENTE"
}

meow_tarq_somar() {
  local rc pior=0 sem=0
  for rc in "$@"; do
    case "$rc" in
      0) ;;
      3) sem=1 ;;
      1) [ "$pior" -ge 2 ] || pior=1 ;;
      *) pior=2 ;;
    esac
  done
  [ "$pior" -ne 0 ] && return "$pior"
  [ "$sem" = 1 ] && return "$MEOW_SEM_DEPENDENCIA"
  return "$MEOW_OK"
}

meow_tarq_ini() {
  python3 -I - "$@" <<'PY'
import sys

acao, arq, secao, chave, valor = sys.argv[1:6]
try:
    with open(arq, encoding="utf-8") as f:
        texto = f.read()
except OSError:
    texto = ""
linhas = texto.rstrip("\n").split("\n") if texto.strip() else []


def faixa():
    if secao == "":
        return 0, next((i for i, l in enumerate(linhas) if l.startswith("[")), len(linhas)), None
    ini = None
    for i, l in enumerate(linhas):
        if l.startswith("["):
            if ini is not None:
                return ini, i, ini - 1
            if l.strip() == "[" + secao + "]":
                ini = i + 1
    return (ini, len(linhas), ini - 1) if ini is not None else (None, None, None)


def achar(a, b):
    return next((i for i in range(a, b) if linhas[i].startswith(chave + "=")), None)


a, b, cab = faixa()
i = achar(a, b) if a is not None else None

if acao == "pegar":
    if i is not None:
        print(linhas[i][len(chave) + 1:])
    sys.exit(0)

if acao == "por":
    if a is None:
        if linhas:
            linhas.append("")
        linhas += ["[" + secao + "]", chave + "=" + valor]
    elif i is not None:
        linhas[i] = chave + "=" + valor
    else:
        linhas.insert(a, chave + "=" + valor)
elif acao == "tirar" and i is not None and (valor == "" or linhas[i][len(chave) + 1:] == valor):
    del linhas[i]
    if cab is not None:
        resto = [x for x in linhas[a:b - 1] if x.strip()]
        if not resto:
            del linhas[cab:b - 1]
            while cab > 0 and cab - 1 < len(linhas) and not linhas[cab - 1].strip():
                del linhas[cab - 1]
                cab -= 1
sys.stdout.write("\n".join(linhas))
PY
}

meow_tarq_chave_estado() {
  local atual
  atual="$(meow_tarq_ini pegar "$1" "$2" "$3" x)"
  if [ "$atual" = "$4" ]; then printf 'igual'
  elif [ -z "$atual" ]; then printf 'ausente'
  else printf 'alheio'; fi
}

meow_tarq_chave_conferir() {
  local rotulo="$1" arq="$2" secao="$3" chave="$4" valor="$5"
  case "$(meow_tarq_chave_estado "$arq" "$secao" "$chave" "$valor")" in
    igual)   return "$MEOW_OK" ;;
    ausente) meow_muda "$rotulo: $chave=$valor falta em $arq"; return "$MEOW_DIVERGENTE" ;;
    alheio)  meow_pula "$rotulo: $arq escolhe outro tema em $chave — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
}

meow_tarq_chave_aplicar() {
  local rotulo="$1" arq="$2" secao="$3" chave="$4" valor="$5" novo rc
  case "$(meow_tarq_chave_estado "$arq" "$secao" "$chave" "$valor")" in
    igual)  return "$MEOW_OK" ;;
    alheio) meow_pula "$rotulo: $arq escolhe outro tema em $chave — trocar é decisão sua"; return "$MEOW_SEM_DEPENDENCIA" ;;
  esac
  novo="$(meow_tarq_ini por "$arq" "$secao" "$chave" "$valor")" || { meow_erro "$rotulo: não montei $arq"; return "$MEOW_ERRO"; }
  meow_tarq_escrever "$arq" "$novo"; rc=$?
  [ "$rc" = "$MEOW_ERRO" ] && { meow_erro "$rotulo: falhou ao escrever $arq"; return "$MEOW_ERRO"; }
  return "$rc"
}

meow_tarq_chave_reverter() {
  local rotulo="$1" arq="$2" secao="$3" chave="$4" valor="$5" novo
  [ "$(meow_tarq_chave_estado "$arq" "$secao" "$chave" "$valor")" = igual ] || return "$MEOW_OK"
  if meow_seco; then meow_muda "$rotulo: tiraria $chave de $arq"; return "$MEOW_DIVERGENTE"; fi
  novo="$(meow_tarq_ini tirar "$arq" "$secao" "$chave" "$valor")" || return "$MEOW_ERRO"
  if [ -z "$novo" ]; then rm -f -- "$arq"; else meow_tarq_escrever "$arq" "$novo" >/dev/null; fi
  meow_ok "$rotulo: $chave saiu de $arq"
  return "$MEOW_DIVERGENTE"
}
