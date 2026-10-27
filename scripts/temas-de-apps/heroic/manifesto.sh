#!/usr/bin/env bash

_HEROIC_APPID="com.heroicgameslauncher.hgl"
_HEROIC_ACENTO="${ACCENT:-mauve}"
_HEROIC_ORIGEM="$RAIZ/packs/meowsystem/temas-de-apps/heroic/upstream/themes"

_HEROIC_PALETA="$(meow_paleta)"

_HEROIC_TEMA=""; _HEROIC_EMBUTIDO=0; _HEROIC_MOTIVO=""
_heroic_do_pack() {
  local saida pack nome
  _HEROIC_TEMA=""; _HEROIC_EMBUTIDO=0; _HEROIC_MOTIVO=""
  saida="$(python3 "$MEOW_RAIZ/scripts/pack.py" adocao "${PACK:-}" "${FLAVOR:-}" 2>/dev/null)" \
    || { _HEROIC_MOTIVO="Heroic: o scripts/pack.py não disse qual é o pack no ar"; return 1; }
  pack="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  nome="$(printf '%s\n' "$saida" | sed -n 's/^nome=//p')"
  meow_app_tema_do_pack heroic.esquema
  if [ -z "$MEOW_APP_TEMA" ]; then
    _HEROIC_MOTIVO="Heroic: sem tema neste pack ($nome) — o Heroic fica como está"
    return 1
  fi
  if [ "$MEOW_APP_TEMA_PACK" != "$pack" ]; then
    _HEROIC_MOTIVO="Heroic: sem tema neste pack ($nome) — o que a herança traz é o '${MEOW_APP_TEMA//<accent>/$_HEROIC_ACENTO}', do pack $MEOW_APP_TEMA_PACK, e o tema de um pack não vale para outro"
    return 1
  fi
  case "$MEOW_APP_TEMA" in
    *.css)
      _HEROIC_TEMA="${MEOW_APP_TEMA//<accent>/$_HEROIC_ACENTO}"
      if [ ! -f "$_HEROIC_ORIGEM/$_HEROIC_TEMA" ]; then
        FLAVOR="" meow_app_tema_do_pack heroic.esquema
        _HEROIC_TEMA="${MEOW_APP_TEMA//<accent>/mauve}"
      fi
      if [ ! -f "$_HEROIC_ORIGEM/$_HEROIC_TEMA" ]; then
        _HEROIC_MOTIVO="Heroic: o pack $nome pede o tema '$_HEROIC_TEMA', que não está no acervo ($_HEROIC_ORIGEM)"
        _HEROIC_TEMA=""
        return 1
      fi ;;
    *) _HEROIC_TEMA="$MEOW_APP_TEMA"; _HEROIC_EMBUTIDO=1 ;;
  esac
  return 0
}

_heroic_tema() {
  printf '%s' "$_HEROIC_TEMA"
}

_HEROIC_REMENDO=(
  "--button-stroke|var(--accent)"
  "--icon-disabled|var(--disabled-button)"
  "--install-button|var(--secondary-button)"
  "--link-highlight|var(--accent)"
  "--modal-backdrop|var(--background-darker-80)"
  "--text-danger|var(--status-danger)"
  "--text-log|var(--status-warning)"
  "--text-quartenary|var(--neutral-04)"
  "--text-warning|var(--status-warning-hover)"

  "--text-hover|@accent"
  "--text-title|@text"
  "--download-button|@accent"
  "--background-secondary|@surface0"

  "--accent-overlay|@accent"
  "--accent-02|@accent+5b"
  "--brand-secondary|@accent"
  "--brand-text-01|@subtext1"
  "--brand-text-02|@subtext0"
  "--brand-text-05|@accent"
  "--primary-hover|@overlay0"
  "--primary-active|@accent"
  "--secondary-hover|@overlay0"
  "--status-default|@subtext0"
  "--status-default-hover|@subtext1"
  "--status-danger-hover|@maroon"
  "--status-success-hover|@teal"
  "--status-warning-hover|@peach"
  "--gamecard-title-color|@crust+cc"
  "--anticheat-denied|@red"
  "--alphabet-filter-bg-hover|@surface1"

  "--installing-effect|100%"
)

declare -A _HEROIC_PAL=()
_heroic_paleta_carregar() {
  [ "${#_HEROIC_PAL[@]}" -gt 0 ] && return 0
  [ -f "$_HEROIC_PALETA" ] || return 1
  local nome hex
  while IFS='=' read -r nome hex; do
    [ -n "$nome" ] && _HEROIC_PAL["$nome"]="$hex"
  done < <(python3 -I - "$_HEROIC_PALETA" <<'PY'
import json, sys, io
with io.open(sys.argv[1], encoding="utf-8") as f:
    d = json.load(f)
for flavor, cores in d.get("flavors", {}).items():
    for nome, hexa in cores.items():
        sys.stdout.write("%s.%s=%s\n" % (flavor, nome, hexa.lower()))
PY
)
  [ "${#_HEROIC_PAL[@]}" -gt 0 ]
}

_heroic_cor() {
  local flavor="$1" acento="$2" r="$3" alfa="" hex
  case "$r" in
    @*) ;;
    *)  printf '%s' "$r"; return 0 ;;
  esac
  r="${r#@}"
  case "$r" in *+*) alfa="${r#*+}"; r="${r%%+*}" ;; esac
  [ "$r" = "accent" ] && r="$acento"
  hex="${_HEROIC_PAL[$flavor.$r]:-}"
  [ -n "$hex" ] || return 1
  printf '%s%s' "$hex" "$alfa"
}

_heroic_bloco() {
  local classe="$1" flavor="$2" acento="$3" item nome receita valor
  _heroic_paleta_carregar || return 1
  printf '%s\n' "/* MeowSystem — as cores que o Heroic 2.22.1 usa e o acervo de maio/2025 não define."
  printf '%s\n' "   Medido no app.asar da versão instalada; a tabela mora no manifesto.sh. */"
  printf 'body.%s {\n' "$classe"
  for item in "${_HEROIC_REMENDO[@]}"; do
    nome="${item%%|*}"; receita="${item#*|}"
    valor="$(_heroic_cor "$flavor" "$acento" "$receita")" || return 1
    printf '  %s: %s;\n' "$nome" "$valor"
  done
  printf '%s' "}"
}

_heroic_css() {
  local arq="$1" base flavor acento bloco
  base="$(basename "$arq" .css)"
  acento="${base##*-}"; flavor="${base%-*}"; flavor="${flavor##*-}"
  bloco="$(_heroic_bloco "$base" "$flavor" "$acento")" || return 1
  printf '%s\n\n%s' "$(cat "$arq")" "$bloco"
}

_heroic_conf_dir() {
  local f="$HOME/.var/app/$_HEROIC_APPID/config/heroic"
  [ -d "$f" ] && { printf '%s' "$f"; return 0; }
  [ -d "$HOME/.config/heroic" ] && { printf '%s' "$HOME/.config/heroic"; return 0; }
  return 1
}

_heroic_presente() {
  meow_flatpak_tem "$_HEROIC_APPID" && return 0
  meow_tem heroic && return 0
  return 1
}

_heroic_rodando() {
  if meow_tem flatpak; then
    flatpak ps --columns=application 2>/dev/null | grep -qx -- "$_HEROIC_APPID" && return 0
  fi
  pgrep -x heroic >/dev/null 2>&1 && return 0
  return 1
}

_heroic_json_com() {
  local arquivo="$1" caminho="$2" valor="$3" recuo="$4"
  python3 -I - "$arquivo" "$caminho" "$valor" "$recuo" <<'PY'
import json, sys, io
arquivo, caminho, valor, recuo = sys.argv[1:5]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except FileNotFoundError:
    d = {}
except ValueError:
    sys.exit(2)
if not isinstance(d, dict):
    sys.exit(2)
partes = caminho.split(".")
alvo = d
for p in partes[:-1]:
    if not isinstance(alvo.get(p), dict):
        alvo[p] = {}
    alvo = alvo[p]
if valor == "":
    alvo.pop(partes[-1], None)
else:
    alvo[partes[-1]] = valor
sys.stdout.write(json.dumps(d, indent=("\t" if recuo == "tab" else 2), ensure_ascii=False))
PY
}

_heroic_backup() {
  local origem="$1" carimbo destino rel
  meow_guardar_antes "$1"
  [ -f "$origem" ] || return 0
  carimbo="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_ESTADO/backups/$carimbo"
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  mkdir -p "$destino/$(dirname "$rel")" || return 1
  cp -p -- "$origem" "$destino/$rel" || return 1
  ( cd "$destino" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  printf '%s\n' "$origem" >> "$destino/origens.txt" || return 1
  meow_info "backup: $destino/$rel"
  return 0
}

_heroic_json_le() {
  local arquivo="$1" caminho="$2"
  python3 -I - "$arquivo" "$caminho" <<'PY'
import json, sys, io
arquivo, caminho = sys.argv[1:3]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(1)
for p in caminho.split("."):
    if not isinstance(d, dict) or p not in d:
        sys.exit(1)
    d = d[p]
sys.stdout.write(d if isinstance(d, str) else json.dumps(d))
PY
}

meow_app_instalado() { _heroic_presente; }

meow_app_detectar() {
  meow_app_instalado || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic instalado, mas ainda não abriu uma vez — sem pasta de configuração"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  _heroic_do_pack || { meow_pula "$_HEROIC_MOTIVO"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_ok "Heroic presente, configuração em $dir"
  return "$MEOW_OK"
}

meow_app_conferir() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir tema pasta divergiu=0 falta=0 f alvo
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  _heroic_do_pack || { meow_pula "$_HEROIC_MOTIVO"; return "$MEOW_SEM_DEPENDENCIA"; }
  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  if [ "$_HEROIC_EMBUTIDO" = "0" ]; then
    for f in "$_HEROIC_ORIGEM"/*.css; do
      alvo="$(_heroic_css "$f")" || {
        meow_erro "não consegui ler $_HEROIC_PALETA — sem fonte de cor, não dá para compor o tema"
        return "$MEOW_ERRO"
      }
      [ "$alvo" = "$(cat "$pasta/$(basename "$f")" 2>/dev/null)" ] || falta=$((falta + 1))
    done
    [ "$falta" = "0" ] || { meow_muda "$falta dos 56 temas não estão em $pasta"; divergiu=1; }

    [ "$(_heroic_json_le "$dir/config.json" defaultSettings.customThemesPath)" = "$pasta" ] \
      || { meow_muda "customThemesPath não aponta para $pasta"; divergiu=1; }
  fi
  [ "$(_heroic_json_le "$dir/store/config.json" theme)" = "$tema" ] \
    || { meow_muda "o tema escolhido não é $tema"; divergiu=1; }

  if [ "$divergiu" = "0" ]; then
    meow_ok "Heroic com $tema aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

meow_app_aplicar() {
  _heroic_presente || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir tema pasta mudou=0 rc f conteudo
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic ainda não abriu uma vez — nada para configurar"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  _heroic_do_pack || { meow_pula "$_HEROIC_MOTIVO"; return "$MEOW_SEM_DEPENDENCIA"; }

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "Heroic já está no nosso tema — nada a fazer"
    return "$MEOW_OK"
  }

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — ele reescreve a configuração ao sair; a próxima passada com ele fechado aplica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  local novo
  if [ "$_HEROIC_EMBUTIDO" = "1" ]; then
    meow_seco || _heroic_backup "$dir/store/config.json"
    novo="$(_heroic_json_com "$dir/store/config.json" theme "$tema" tab)" \
      || { meow_erro "não consegui ler $dir/store/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
    meow_escrever "$dir/store/config.json" "$novo"
    rc=$?
    [ "$rc" -ge 2 ] && return "$MEOW_ERRO"
    if [ "$rc" = "1" ]; then
      meow_ok "Heroic com o tema $tema, o tema que o próprio Heroic traz — a janela mostra na próxima vez que abrir"
      return "$MEOW_DIVERGENTE"
    fi
    meow_ok "Heroic já está no nosso tema"
    return "$MEOW_OK"
  fi

  for f in "$_HEROIC_ORIGEM"/*.css; do
    conteudo="$(_heroic_css "$f")" || {
      meow_erro "não consegui ler $_HEROIC_PALETA — sem fonte de cor, não dá para compor o tema"
      return "$MEOW_ERRO"
    }
    meow_escrever "$pasta/$(basename "$f")" "$conteudo"
    rc=$?
    [ "$rc" = "1" ] && mudou=1
    [ "$rc" -ge 2 ] && return "$MEOW_ERRO"
  done

  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "$pasta" espaco)" \
    || { meow_erro "não consegui ler $dir/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  novo="$(_heroic_json_com "$dir/store/config.json" theme "$tema" tab)" \
    || { meow_erro "não consegui ler $dir/store/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/store/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  if [ "$mudou" = "1" ]; then
    meow_ok "Heroic com o tema $tema — a janela mostra na próxima vez que abrir"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "Heroic já está no nosso tema"
  return "$MEOW_OK"
}

meow_app_reverter() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir pasta mudou=0 rc novo f
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  pasta="$dir/themes"

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — a próxima passada com ele fechado aplica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/store/config.json" theme midnightMirage tab)" || return "$MEOW_ERRO"
  meow_escrever "$dir/store/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "" espaco)" || return "$MEOW_ERRO"
  meow_escrever "$dir/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1

  if ! meow_seco; then
    for f in "$_HEROIC_ORIGEM"/*.css; do
      [ -f "$pasta/$(basename "$f")" ] || continue
      rm -f -- "$pasta/$(basename "$f")" && mudou=1
    done
    rmdir "$pasta" 2>/dev/null || true
  fi

  [ "$mudou" = "1" ] && { meow_ok "Heroic de volta ao midnightMirage"; return "$MEOW_DIVERGENTE"; }
  meow_ok "Heroic já estava de fábrica"
  return "$MEOW_OK"
}
