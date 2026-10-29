#!/usr/bin/env bash

MEOW_OBSIDIAN_APP_ID="md.obsidian.Obsidian"
MEOW_OBSIDIAN_TEMA=""
MEOW_OBSIDIAN_FONTE=""
MEOW_OBSIDIAN_VAULT="${MEOW_OBSIDIAN_VAULT:-}"
MEOW_OBSIDIAN_PADRAO_PROC='^/app/obsidian( |$)'

MEOW_OBSIDIAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEOW_OBSIDIAN_VENDOR="$(cd "$MEOW_OBSIDIAN_DIR/../../.." && pwd)/packs/meowsystem/temas-de-apps/obsidian/vendor"
MEOW_OBSIDIAN_BAIXADOS="${XDG_DATA_HOME:-$HOME/.local/share}/meowsystem/temas-de-apps/obsidian"

_meow_obsidian_cofre() {
  python3 -I - "${1:-um}" "$HOME/.var/app/$MEOW_OBSIDIAN_APP_ID/config/obsidian/obsidian.json" \
            "${XDG_CONFIG_HOME:-$HOME/.config}/obsidian/obsidian.json" <<'PYFIM'
import json, os, sys

todos = sys.argv[1] == "todos"
melhor = None
for arquivo in sys.argv[2:]:
    try:
        with open(arquivo, encoding="utf-8") as f:
            dados = json.load(f)
    except (OSError, ValueError):
        continue
    cofres = dados.get("vaults") if isinstance(dados, dict) else None
    if not isinstance(cofres, dict):
        continue
    for cofre in cofres.values():
        if not isinstance(cofre, dict):
            continue
        pasta = cofre.get("path")
        if not isinstance(pasta, str) or not os.path.isdir(os.path.join(pasta, ".obsidian")):
            continue
        if todos:
            sys.stdout.write(pasta + "\0")
            continue
        ts = cofre.get("ts")
        chave = (cofre.get("open") is True, ts if isinstance(ts, (int, float)) else 0)
        if melhor is None or chave > melhor[0]:
            melhor = (chave, pasta)
if melhor:
    print(melhor[1])
PYFIM
}

_meow_obsidian_rodando() {
  pgrep -f "$MEOW_OBSIDIAN_PADRAO_PROC" >/dev/null 2>&1
}

_meow_obsidian_appearance() { printf '%s/.obsidian/appearance.json' "$MEOW_OBSIDIAN_VAULT"; }
_meow_obsidian_tema_dir()   { printf '%s/.obsidian/themes/%s' "$MEOW_OBSIDIAN_VAULT" "$MEOW_OBSIDIAN_TEMA"; }

_OBS_PACK=""; _OBS_PACK_NOME=""; _OBS_EXIBE=""; _OBS_OUTROS=""; _OBS_PACKS=""
_OBS_URL=""; _OBS_SHA=""; _OBS_PASTA=""; _OBS_ORIGEM_RECUSA=""
_meow_obsidian_packs() {
  local saida
  saida="$(PACK="${PACK:-}" FLAVOR="${FLAVOR:-}" MEOW_PACKS_VALIDOS="$(meow_packs_validos)" \
             python3 -I - "$MEOW_RAIZ/scripts" <<'PYFIM' 2>/dev/null
import json, os, re, sys
sys.path.insert(0, sys.argv[1])
import pack

ident, dir_pack, _recusado = pack.adocao(os.environ.get("PACK", ""), os.environ.get("FLAVOR", ""))
nome = pack.campo(ident, "nome") or ident
exibe = nome
try:
    arq = pack.campo(ident, "paleta.arquivo", "paleta.json")
    with open(os.path.join(pack.achar(ident), arq), encoding="utf-8") as fh:
        nomes = json.load(fh).get("nomes") or {}
    exibe = nomes.get(pack.campo(ident, "paleta.flavor_padrao")) or nome
except (OSError, ValueError, TypeError, AttributeError):
    pass
validos = set(os.environ.get("MEOW_PACKS_VALIDOS", "").split())

def regua(ids):
    if not ids:
        return ""
    ids = sorted(r"[\W_]+".join(re.escape(p) for p in i.split("-") if p) for i in ids)
    return r"(?i)(?<![^\W_])(?:%s)(?![^\W_])" % "|".join(ids)

url = sha = pasta = recusa = ""
_quem, origem = pack.tema_de_app("apps.obsidian.origem", ref=dir_pack or None)
if origem is not None:
    try:
        o = pack.origem_pinada(origem, "apps.obsidian.origem")
        url, sha, pasta = o["url"], o["sha256"], o["pasta"]
    except pack.Recusa as e:
        recusa = " ".join(str(e).split())
    if any(c in v for v in (url, sha, pasta) for c in "\r\n"):
        url = sha = pasta = ""
        recusa = "apps.obsidian.origem: um dos campos tem quebra de linha"
print("pack=" + ident)
print("nome=" + " ".join(str(nome).splitlines()))
print("exibe=" + " ".join(str(exibe).splitlines()))
meus = {ident} | {a for a, d in getattr(pack, "APELIDOS", {}).items() if d == ident}
print("outros=" + regua(validos - meus))
print("packs=" + regua(validos | meus))
print("url=" + url)
print("sha256=" + sha)
print("pasta=" + pasta)
print("recusa=" + recusa)
PYFIM
)" || return 1
  _OBS_PACK="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  _OBS_PACK_NOME="$(printf '%s\n' "$saida" | sed -n 's/^nome=//p')"
  _OBS_EXIBE="$(printf '%s\n' "$saida" | sed -n 's/^exibe=//p')"
  _OBS_OUTROS="$(printf '%s\n' "$saida" | sed -n 's/^outros=//p')"
  _OBS_PACKS="$(printf '%s\n' "$saida" | sed -n 's/^packs=//p')"
  _OBS_URL="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  _OBS_SHA="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  _OBS_PASTA="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"
  _OBS_ORIGEM_RECUSA="$(printf '%s\n' "$saida" | sed -n 's/^recusa=//p')"
  [ -n "$_OBS_PACK" ]
}

_meow_obsidian_do_pack() {
  MEOW_OBSIDIAN_TEMA=""; MEOW_OBSIDIAN_FONTE=""; _OBS_URL=""; _OBS_SHA=""; _OBS_PASTA=""; _OBS_ORIGEM_RECUSA=""
  _meow_obsidian_packs || { meow_app_sem "obsidian: o scripts/pack.py não disse qual é o pack no ar"; return; }
  meow_app_tema_do_pack obsidian.esquema
  if [ -z "$MEOW_APP_TEMA" ]; then
    meow_app_sem "obsidian: sem tema neste pack ($_OBS_PACK_NOME) — o Obsidian fica como está"
    return
  fi
  if [ "$MEOW_APP_TEMA_PACK" != "$_OBS_PACK" ]; then
    meow_app_sem "obsidian: sem tema neste pack ($_OBS_PACK_NOME) — o que a herança traz é o '$MEOW_APP_TEMA', do pack $MEOW_APP_TEMA_PACK, e o tema de um pack não vale para outro"
    return
  fi
  case "$MEOW_APP_TEMA" in
    */*|.|..|*$'\n'*)
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME dá ao tema um nome que não serve de pasta ('$MEOW_APP_TEMA') — nada é escrito"
      return ;;
  esac
  MEOW_OBSIDIAN_TEMA="$MEOW_APP_TEMA"
  if [ -n "$_OBS_ORIGEM_RECUSA" ]; then
    meow_app_sem "obsidian: a origem do tema '$MEOW_OBSIDIAN_TEMA' no pack $_OBS_PACK_NOME não serve — $_OBS_ORIGEM_RECUSA"
    return
  fi
  if [ -z "$_OBS_URL" ]; then
    MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_VENDOR/$MEOW_OBSIDIAN_TEMA"
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/theme.css" ] || [ ! -f "$MEOW_OBSIDIAN_FONTE/manifest.json" ]; then
      meow_app_sem "obsidian: o pack $_OBS_PACK_NOME pede o tema '$MEOW_OBSIDIAN_TEMA', que não está em $MEOW_OBSIDIAN_VENDOR e não tem origem para descer"
      return
    fi
    return "$MEOW_OK"
  fi
  MEOW_OBSIDIAN_FONTE="$MEOW_OBSIDIAN_BAIXADOS/$_OBS_SHA"
  return "$MEOW_OK"
}

_meow_obsidian_fonte_pronta() {
  [ -n "$_OBS_SHA" ] || return 0
  [ -f "$MEOW_OBSIDIAN_FONTE/.meow-origem" ] \
    && grep -qx "sha256=$_OBS_SHA" "$MEOW_OBSIDIAN_FONTE/.meow-origem" \
    && ( cd "$MEOW_OBSIDIAN_FONTE" && sha256sum --status -c .meow-somas.sha256 ) 2>/dev/null
}

_meow_obsidian_baixar() {
  local palco src nome obtido f sobra
  for f in curl tar sha256sum; do
    meow_tem "$f" || { meow_app_sem "obsidian: falta '$f' para baixar o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME"; return; }
  done
  meow_destino_permitido "$MEOW_OBSIDIAN_FONTE" || return "$MEOW_ERRO"
  mkdir -p "$MEOW_OBSIDIAN_BAIXADOS" || return "$MEOW_ERRO"
  for sobra in "$MEOW_OBSIDIAN_BAIXADOS"/.meow-descendo.*; do
    [ -d "$sobra" ] && rm -rf -- "$sobra"
  done
  palco="$(mktemp -d -p "$MEOW_OBSIDIAN_BAIXADOS" ".meow-descendo.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "obsidian: baixando o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME…"
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 300 --retry 3 --retry-delay 2 -o "$palco/pacote" "$_OBS_URL" 2>/dev/null; then
    rm -rf "$palco"
    meow_app_sem "obsidian: não consegui baixar o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME (sem rede?) — fica para o próximo ciclo"
    return
  fi
  if ! echo "$_OBS_SHA  $palco/pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$palco/pacote" | cut -d' ' -f1)"
    rm -rf "$palco"
    meow_erro "obsidian: o sha256 do tema '$MEOW_OBSIDIAN_TEMA' não bate com o que o pack $_OBS_PACK_NOME pinou — nada instalado"
    meow_info "  esperado $_OBS_SHA"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  if ! { mkdir "$palco/x" && tar -xf "$palco/pacote" -C "$palco/x"; } 2>/dev/null; then
    rm -rf "$palco"
    meow_erro "obsidian: o pacote do tema '$MEOW_OBSIDIAN_TEMA' veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi
  src="$palco/x/$_OBS_PASTA"
  nome=""
  if [ -f "$src/theme.css" ] && [ ! -L "$src/theme.css" ] && [ -f "$src/manifest.json" ] && [ ! -L "$src/manifest.json" ]; then
    nome="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8")).get("name", ""))' \
              "$src/manifest.json" 2>/dev/null)"
  fi
  if [ "$nome" != "$MEOW_OBSIDIAN_TEMA" ]; then
    rm -rf "$palco"
    meow_erro "obsidian: o pacote não traz em '$_OBS_PASTA' o theme.css e o manifest.json do tema '$MEOW_OBSIDIAN_TEMA'${nome:+ (o manifest diz '$nome')} — nada instalado"
    return "$MEOW_ERRO"
  fi
  if ! { mkdir "$palco/tema" && cp -- "$src/theme.css" "$src/manifest.json" "$palco/tema/" \
         && ( cd "$palco/tema" && sha256sum theme.css manifest.json > .meow-somas.sha256 ) \
         && printf 'sha256=%s\nurl=%s\n' "$_OBS_SHA" "$_OBS_URL" > "$palco/tema/.meow-origem"; }; then
    rm -rf "$palco"
    meow_erro "obsidian: não consegui guardar o tema baixado em $MEOW_OBSIDIAN_BAIXADOS"
    return "$MEOW_ERRO"
  fi
  rm -rf -- "$MEOW_OBSIDIAN_FONTE"
  if ! mv -f -- "$palco/tema" "$MEOW_OBSIDIAN_FONTE"; then
    rm -rf "$palco"
    meow_erro "obsidian: não consegui pôr o tema baixado em $MEOW_OBSIDIAN_FONTE"
    return "$MEOW_ERRO"
  fi
  rm -rf "$palco"
  meow_muda "obsidian: tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME baixado e conferido pelo sha256"
  return "$MEOW_DIVERGENTE"
}

_meow_obsidian_igual() {
  local origem="$1" destino="$2"
  [ -f "$destino" ] || return 1
  [ "$(cat "$origem" 2>/dev/null)" = "$(cat "$destino" 2>/dev/null)" ]
}

_meow_obsidian_backup() {
  local arquivo="$1" rotulo="$2" destino
  meow_guardar_antes "$1"
  [ -f "$arquivo" ] || return 0
  meow_seco && return 0
  : "${MEOW_OBSIDIAN_BACKUP_DIR:=${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  mkdir -p "$destino" || return 1
  cp -p -- "$arquivo" "$destino/$rotulo" || return 1
  return 0
}

_meow_obsidian_hospedeiro() {
  local cofre="$1" id resto origem
  case "$cofre" in
    /run/user/*/doc/*/*)
      id="${cofre#/run/user/*/doc/}"; resto="${id#*/}"; id="${id%%/*}"
      origem="$(flatpak documents --columns=id,origin 2>/dev/null \
                | awk -F'\t' -v id="$id" '$1 == id { print $2; exit }')"
      [ -n "$origem" ] || return 1
      printf '%s/%s' "$(dirname -- "$origem")" "$resto" ;;
    *) printf '%s' "$cofre" ;;
  esac
}

_meow_obsidian_git() {
  local modo="$1" tema="${2:-}" cofre raiz rel attrs linha filtro limpar vestir
  meow_tem git || return "$MEOW_OK"
  cofre="$(_meow_obsidian_hospedeiro "$MEOW_OBSIDIAN_VAULT")" || return "$MEOW_OK"
  raiz="$(git -C "$cofre" rev-parse --show-toplevel 2>/dev/null)" || return "$MEOW_OK"
  rel="$(realpath -m --relative-to="$raiz" "$cofre/.obsidian/appearance.json")" || return "$MEOW_OK"
  git -C "$raiz" ls-files --error-unmatch -- "$rel" >/dev/null 2>&1 || return "$MEOW_OK"
  attrs="$(git -C "$raiz" rev-parse --path-format=absolute --git-path info/attributes 2>/dev/null)" \
    || return "$MEOW_OK"
  filtro="$MEOW_RAIZ/scripts/temas-de-apps/obsidian/filtro_git.py"
  linha="/${rel// /[[:space:]]} filter=meow-obsidian"
  limpar="python3 '$filtro' limpar %f"
  vestir="python3 '$filtro' vestir"

  local tem_linha=0 tem_cfg=0
  grep -qxF -- "$linha" "$attrs" 2>/dev/null && tem_linha=1
  [ "$(git -C "$raiz" config --local --get filter.meow-obsidian.clean 2>/dev/null)" = "$limpar" ] \
    && [ "$(git -C "$raiz" config --local --get filter.meow-obsidian.smudge 2>/dev/null)" = "$vestir" ] \
    && [ "$(git -C "$raiz" config --local --get meow.obsidian-tema 2>/dev/null)" = "$tema" ] && tem_cfg=1

  case "$modo" in
    conferir)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] && return "$MEOW_OK"
      meow_muda "obsidian: o git do cofre ainda não sabe que o tema é desta máquina ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
    aplicar)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] && return "$MEOW_OK"
      if meow_seco; then
        meow_muda "obsidian: ensinaria ao git do cofre que o tema é desta máquina ($raiz)"
        return "$MEOW_DIVERGENTE"
      fi
      meow_destino_permitido "$attrs" || return "$MEOW_ERRO"
      git -C "$raiz" config --local filter.meow-obsidian.clean "$limpar" \
        && git -C "$raiz" config --local filter.meow-obsidian.smudge "$vestir" \
        && git -C "$raiz" config --local meow.obsidian-tema "$tema" || return "$MEOW_ERRO"
      if [ "$tem_linha" = 0 ]; then
        mkdir -p -- "$(dirname -- "$attrs")" && printf '%s\n' "$linha" >> "$attrs" || return "$MEOW_ERRO"
      fi
      meow_muda "obsidian: o git do cofre guarda o tema dele e escreve o desta máquina ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
    renovar)
      [ "$tem_linha" = 1 ] && [ "$tem_cfg" = 1 ] || return "$MEOW_OK"
      meow_seco && return "$MEOW_OK"
      git -C "$raiz" diff --quiet -- "$rel" 2>/dev/null && git -C "$raiz" add -- "$rel" 2>/dev/null
      return "$MEOW_OK" ;;
    conferir-desfazer|desfazer)
      [ "$tem_linha" = 0 ] && [ -z "$(git -C "$raiz" config --local --get-regexp '^filter\.meow-obsidian\.|^meow\.obsidian-tema$' 2>/dev/null)" ] \
        && return "$MEOW_OK"
      [ "$modo" = "conferir-desfazer" ] && return "$MEOW_DIVERGENTE"
      if meow_seco; then
        meow_muda "obsidian: tiraria do git do cofre o filtro do tema ($raiz)"
        return "$MEOW_DIVERGENTE"
      fi
      git -C "$raiz" config --local --remove-section filter.meow-obsidian 2>/dev/null
      git -C "$raiz" config --local --unset meow.obsidian-tema 2>/dev/null
      if [ "$tem_linha" = 1 ]; then
        local tmp; tmp="$(mktemp -p "$(dirname -- "$attrs")" .meow.XXXXXX)" || return "$MEOW_ERRO"
        grep -vxF -- "$linha" "$attrs" > "$tmp"; mv -f -- "$tmp" "$attrs" || return "$MEOW_ERRO"
      fi
      meow_muda "obsidian: o filtro do tema saiu do git do cofre ($raiz)"
      return "$MEOW_DIVERGENTE" ;;
  esac
  return "$MEOW_ERRO"
}

_meow_obsidian_json() {
  local modo="$1" arquivo="$2" tema="$3" outros="${4:-}"
  MEOW_PY_SECO="$(meow_seco && echo 1 || echo 0)" \
  python3 -I - "$modo" "$arquivo" "$tema" "$outros" <<'PYFIM'
import json, os, re, sys, tempfile

modo, caminho, tema = sys.argv[1], sys.argv[2], sys.argv[3]
outros = sys.argv[4]
seco = os.environ.get("MEOW_PY_SECO") == "1"
desfazer = modo in ("conferir-desfazer", "desfazer")

existia = os.path.exists(caminho)
if existia:
    try:
        with open(caminho, encoding="utf-8") as f:
            texto = f.read()
        dados = json.loads(texto) if texto.strip() else {}
    except (OSError, ValueError) as e:
        sys.stderr.write("appearance.json ilegível (%s)\n" % e)
        sys.exit(2)
    if not isinstance(dados, dict):
        sys.stderr.write("appearance.json não é um objeto JSON\n")
        sys.exit(2)
else:
    dados = {}

antes = json.dumps(dados, sort_keys=True)
motivos = []

if desfazer:
    if dados.get("cssTheme") in [t for t in tema.split("\n") if t]:
        motivos.append("cssTheme=%r -> ''" % dados.get("cssTheme"))
        dados["cssTheme"] = ""
elif dados.get("cssTheme") != tema:
    motivos.append("cssTheme=%r -> %r" % (dados.get("cssTheme"), tema))
    dados["cssTheme"] = tema

snippets = None if desfazer else dados.get("enabledCssSnippets")
if isinstance(snippets, list) and outros:
    limpos = [s for s in snippets
              if not (isinstance(s, str) and re.search(outros, s))]
    if limpos != snippets:
        removidos = [s for s in snippets if s not in limpos]
        motivos.append("snippets removidos: %s" % ", ".join(map(str, removidos)))
        dados["enabledCssSnippets"] = limpos

if not existia and not desfazer:
    motivos.append("appearance.json não existia")

if json.dumps(dados, sort_keys=True) == antes and (existia or desfazer):
    sys.exit(0)

for m in motivos:
    sys.stderr.write("  %s\n" % m)

if modo in ("conferir", "conferir-desfazer") or seco:
    sys.exit(1)

saida = json.dumps(dados, indent=2, ensure_ascii=False)
pasta = os.path.dirname(caminho) or "."
try:
    os.makedirs(pasta, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow-appearance.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(saida)
    os.chmod(tmp, 0o644)
    os.replace(tmp, caminho)
except OSError as e:
    sys.stderr.write("falhou ao gravar appearance.json (%s)\n" % e)
    try:
        os.unlink(tmp)
    except (OSError, NameError):
        pass
    sys.exit(2)
sys.exit(1)
PYFIM
}

meow_app_instalado() { meow_flatpak_tem "$MEOW_OBSIDIAN_APP_ID"; }

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  if ! meow_tem flatpak; then
    meow_app_sem "obsidian: flatpak não está instalado"
    return
  fi
  local falta
  for falta in python3 pgrep; do
    if ! meow_tem "$falta"; then
      meow_app_sem "obsidian: falta '$falta' (sem ele não dá para aplicar com segurança)"
      return
    fi
  done
  if ! meow_app_instalado; then
    meow_app_sem "obsidian: $MEOW_OBSIDIAN_APP_ID não instalado"
    return
  fi
  [ -n "$MEOW_OBSIDIAN_VAULT" ] || MEOW_OBSIDIAN_VAULT="$(_meow_obsidian_cofre)"
  if [ -z "$MEOW_OBSIDIAN_VAULT" ]; then
    meow_app_sem "obsidian: o Obsidian ainda não conhece cofre nenhum (obsidian.json) — abra um cofre nele, ou diga qual em MEOW_OBSIDIAN_VAULT"
    return
  fi
  if [ ! -d "$MEOW_OBSIDIAN_VAULT/.obsidian" ]; then
    meow_app_sem "obsidian: vault '$MEOW_OBSIDIAN_VAULT' não encontrado"
    return
  fi
  [ "${1:-}" = "sem-pack" ] && return "$MEOW_OK"
  _meow_obsidian_do_pack || return
  return "$MEOW_OK"
}

meow_app_conferir() {
  meow_app_detectar || { meow_app_pendente obsidian; return; }

  local tema_dir divergente=0
  tema_dir="$(_meow_obsidian_tema_dir)"

  if ! _meow_obsidian_fonte_pronta; then
    meow_muda "obsidian: o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME ainda não desceu"
    divergente=1
  else
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/theme.css" "$tema_dir/theme.css" \
      || { meow_muda "obsidian: theme.css ausente ou diferente"; divergente=1; }
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/manifest.json" "$tema_dir/manifest.json" \
      || { meow_muda "obsidian: manifest.json ausente ou diferente"; divergente=1; }
  fi

  _meow_obsidian_json conferir "$(_meow_obsidian_appearance)" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS"
  case $? in
    0) ;;
    1) meow_muda "obsidian: appearance.json divergente"; divergente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_DIVERGENTE" ;;
  esac
  _meow_obsidian_git conferir "$MEOW_OBSIDIAN_TEMA" || divergente=1

  if [ "$divergente" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já aplicado"
    return "$MEOW_OK"
  fi
  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: está ABERTO — feche-o para o MeowSystem poder aplicar"
  fi
  return "$MEOW_DIVERGENTE"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente obsidian; return; }

  local tema_dir appearance mudou=0 rc
  tema_dir="$(_meow_obsidian_tema_dir)"
  appearance="$(_meow_obsidian_appearance)"

  if ! _meow_obsidian_fonte_pronta; then
    if meow_seco; then
      meow_muda "obsidian: baixaria o tema '$MEOW_OBSIDIAN_TEMA' do pack $_OBS_PACK_NOME ($_OBS_URL)"
    else
      _meow_obsidian_baixar; rc=$?
      [ "$rc" = 1 ] || rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" "${MEOW_OBSIDIAN_BAIXADOS%/*}" \
                                "${MEOW_OBSIDIAN_BAIXADOS%/*/*}" 2>/dev/null
      case $rc in
        1) ;;
        3) meow_app_pendente obsidian; return ;;
        *) return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  local -a pendentes=()
  local arquivo
  for arquivo in theme.css manifest.json; do
    _meow_obsidian_igual "$MEOW_OBSIDIAN_FONTE/$arquivo" "$tema_dir/$arquivo" \
      || pendentes+=("$arquivo")
  done

  local json_pendente=0
  _meow_obsidian_json conferir "$appearance" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS" 2>/dev/null
  rc=$?
  case $rc in
    0) ;;
    1) json_pendente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_ERRO" ;;
  esac

  local git_pendente=0
  _meow_obsidian_git conferir "$MEOW_OBSIDIAN_TEMA" >/dev/null 2>&1 || git_pendente=1

  if [ "${#pendentes[@]}" -eq 0 ] && [ "$json_pendente" = "0" ] && [ "$git_pendente" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já estava aplicado"
    return "$MEOW_OK"
  fi

  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e desfaria a troca."
    meow_aviso "obsidian: aberto agora; a próxima passada com ele fechado aplica."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$appearance" || return "$MEOW_ERRO"

  unset MEOW_OBSIDIAN_BACKUP_DIR

  for arquivo in "${pendentes[@]}"; do
    if ! _meow_obsidian_backup "$tema_dir/$arquivo" "$arquivo"; then
      meow_erro "obsidian: não consegui fazer backup de $arquivo"
      return "$MEOW_ERRO"
    fi
    if [ ! -f "$MEOW_OBSIDIAN_FONTE/$arquivo" ]; then
      if meow_seco; then meow_muda "mudaria $tema_dir/$arquivo"; mudou=1; continue; fi
      meow_erro "obsidian: $MEOW_OBSIDIAN_FONTE/$arquivo sumiu no meio da passada — nada escrito"
      return "$MEOW_ERRO"
    fi
    meow_escrever "$tema_dir/$arquivo" "$(cat "$MEOW_OBSIDIAN_FONTE/$arquivo")" 644
    rc=$?
    case $rc in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao instalar $arquivo"; return "$MEOW_ERRO" ;;
    esac
  done

  if [ "$json_pendente" = "1" ]; then
    _meow_obsidian_backup "$appearance" "appearance.json" || {
      meow_erro "obsidian: não consegui fazer backup do appearance.json"
      return "$MEOW_ERRO"
    }
    _meow_obsidian_json aplicar "$appearance" "$MEOW_OBSIDIAN_TEMA" "$_OBS_OUTROS"
    case $? in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao mesclar o appearance.json"; return "$MEOW_ERRO" ;;
    esac
  fi

  if [ "$git_pendente" = "1" ]; then
    _meow_obsidian_git aplicar "$MEOW_OBSIDIAN_TEMA"
    case $? in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: não consegui pôr o filtro do tema no git do cofre"; return "$MEOW_ERRO" ;;
    esac
  fi

  [ "$json_pendente" = "1" ] || [ "$git_pendente" = "1" ] && _meow_obsidian_git renovar "$MEOW_OBSIDIAN_TEMA"

  if [ "$mudou" = "0" ]; then
    meow_ok "obsidian: $_OBS_EXIBE já estava aplicado"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "obsidian: (seco) aplicaria o $_OBS_EXIBE no vault"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -n "${MEOW_OBSIDIAN_BACKUP_DIR:-}" ] && [ -d "${MEOW_OBSIDIAN_BACKUP_DIR:-}/obsidian" ]; then
    meow_info "obsidian: backup do que existia em $MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  fi
  meow_ok "obsidian: $_OBS_EXIBE aplicado — reabra o app para ver"
  meow_registrar "obsidian: cssTheme=$MEOW_OBSIDIAN_TEMA em $MEOW_OBSIDIAN_VAULT"
  return "$MEOW_DIVERGENTE"
}

_meow_obsidian_nossos() {
  python3 -I - "$MEOW_OBSIDIAN_VENDOR" "$MEOW_OBSIDIAN_BAIXADOS" <<'PYFIM' 2>/dev/null
import json, os, sys

def pastas(base, marca):
    try:
        nomes = sorted(os.listdir(base))
    except OSError:
        return []
    return [os.path.join(base, n) for n in nomes
            if not n.startswith(".") and os.path.isdir(os.path.join(base, n))
            and (not marca or os.path.isfile(os.path.join(base, n, marca)))]

for pasta in pastas(sys.argv[1], "") + pastas(sys.argv[2], ".meow-origem"):
    try:
        with open(os.path.join(pasta, "manifest.json"), encoding="utf-8") as fh:
            nome = json.load(fh).get("name")
    except (OSError, ValueError, AttributeError):
        continue
    if isinstance(nome, str) and nome not in ("", ".", "..") and not set("\t\n/") & set(nome) \
       and os.path.isfile(os.path.join(pasta, "theme.css")):
        print(pasta + "\t" + nome)
PYFIM
}

_meow_obsidian_snippets_desmarcados() {
  python3 -I - "$@" <<'PYFIM' 2>/dev/null
import json, os, re, sys

packs = sys.argv[1]
achados = []
for cofre in sys.argv[2:]:
    try:
        with open(os.path.join(cofre, ".obsidian", "appearance.json"), encoding="utf-8") as fh:
            ligados = json.load(fh).get("enabledCssSnippets") or []
        arquivos = sorted(os.listdir(os.path.join(cofre, ".obsidian", "snippets")))
    except (OSError, ValueError, AttributeError):
        continue
    for arq in arquivos:
        nome = arq[:-len(".css")] if arq.endswith(".css") else ""
        if nome and nome not in ligados and nome not in achados \
           and packs and re.search(packs, nome):
            achados.append(nome)
for nome in achados:
    print(nome)
PYFIM
}

meow_app_reverter() {
  meow_app_detectar sem-pack || { meow_app_pendente obsidian; return; }
  _meow_obsidian_packs || _OBS_PACK_NOME="tema do MeowSystem"

  local -a lidos=() cofres=()
  local -A vistos=()
  local c real
  mapfile -d '' -t lidos < <(_meow_obsidian_cofre todos)
  for c in "$MEOW_OBSIDIAN_VAULT" ${lidos[@]+"${lidos[@]}"}; do
    real="$(readlink -m -- "$c")"
    [ -n "${vistos[$real]:-}" ] && continue
    vistos[$real]=1
    cofres+=("$c")
  done

  local -a fontes=() nomes=() baixados=()
  local fonte nome nossos_nomes
  while IFS=$'\t' read -r fonte nome; do
    fontes+=("$fonte"); nomes+=("$nome")
    [ -f "$fonte/.meow-origem" ] && baixados+=("$fonte")
  done < <(_meow_obsidian_nossos)
  nossos_nomes="$(printf '%s\n' ${nomes[@]+"${nomes[@]}"})"
  local -a sobras=()
  local sobra
  for sobra in "$MEOW_OBSIDIAN_BAIXADOS"/.meow-descendo.*; do
    [ -d "$sobra" ] && sobras+=("$sobra")
  done

  local MEOW_OBSIDIAN_VAULT tema_dir appearance mudou=0 algum=0 arquivo i k p lista tem
  local -a json_de=() tem_de=() git_de=() par_cofre=() par_tema=() par_arquivos=() com_algo=()

  for i in "${!cofres[@]}"; do
    MEOW_OBSIDIAN_VAULT="${cofres[$i]}"
    appearance="$(_meow_obsidian_appearance)"
    tem=0
    for k in "${!fontes[@]}"; do
      tema_dir="$MEOW_OBSIDIAN_VAULT/.obsidian/themes/${nomes[k]}"
      lista=""
      for arquivo in theme.css manifest.json; do
        _meow_obsidian_igual "${fontes[k]}/$arquivo" "$tema_dir/$arquivo" && lista+=" $arquivo"
      done
      [ -n "$lista" ] || continue
      par_cofre+=("$i"); par_tema+=("${nomes[k]}"); par_arquivos+=("$lista"); tem=1
    done
    json_de[i]=0
    _meow_obsidian_json conferir-desfazer "$appearance" "$nossos_nomes" >/dev/null 2>&1
    case $? in
      0) ;;
      1) json_de[i]=1 ;;
      *) meow_erro "obsidian: não consegui ler o appearance.json de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
    esac
    git_de[i]=0
    _meow_obsidian_git conferir-desfazer >/dev/null 2>&1 || git_de[i]=1
    [ "${git_de[i]}" = "1" ] && tem=1
    tem_de[i]="$tem"
    [ "$tem" = "1" ] || [ "${json_de[i]}" = "1" ] || continue
    algum=1
    com_algo+=("$MEOW_OBSIDIAN_VAULT")
    meow_destino_permitido "$appearance" || return "$MEOW_ERRO"
  done
  [ "${#baixados[@]}" -gt 0 ] && algum=1
  [ "${#sobras[@]}" -gt 0 ] && algum=1

  if [ "$algum" = "0" ]; then
    meow_seco || rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" 2>/dev/null
    meow_ok "obsidian: já estava sem o $_OBS_PACK_NOME"
    return "$MEOW_OK"
  fi

  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e traria o tema de volta."
    meow_aviso "obsidian: aberto agora; a próxima passada com ele fechado aplica."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  unset MEOW_OBSIDIAN_BACKUP_DIR

  for i in "${!cofres[@]}"; do
    [ "${tem_de[i]}" = "1" ] || [ "${json_de[i]}" = "1" ] || continue
    MEOW_OBSIDIAN_VAULT="${cofres[$i]}"
    appearance="$(_meow_obsidian_appearance)"

    if meow_seco; then
      for p in "${!par_cofre[@]}"; do
        [ "${par_cofre[p]}" = "$i" ] || continue
        meow_muda "obsidian: removeria${par_arquivos[p]} de $MEOW_OBSIDIAN_VAULT/.obsidian/themes/${par_tema[p]}"
      done
      [ "${json_de[i]}" = "1" ] && meow_muda "obsidian: cssTheme de '$MEOW_OBSIDIAN_VAULT' voltaria ao padrão do app"
      [ "${git_de[i]}" = "1" ] && _meow_obsidian_git desfazer
      continue
    fi

    if [ "${git_de[i]}" = "1" ]; then
      _meow_obsidian_git desfazer
      case $? in
        0|1) mudou=1 ;;
        *) meow_erro "obsidian: não consegui tirar o filtro do git de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
      esac
    fi

    for p in "${!par_cofre[@]}"; do
      [ "${par_cofre[p]}" = "$i" ] || continue
      tema_dir="$MEOW_OBSIDIAN_VAULT/.obsidian/themes/${par_tema[p]}"
      for arquivo in ${par_arquivos[p]}; do
        if rm -f "$tema_dir/$arquivo"; then mudou=1; else
          meow_erro "obsidian: não consegui remover $tema_dir/$arquivo"; return "$MEOW_ERRO"
        fi
      done
      [ -d "$tema_dir" ] && rmdir "$tema_dir" 2>/dev/null
      meow_muda "obsidian: tema ${par_tema[p]} removido de '$MEOW_OBSIDIAN_VAULT'"
    done

    if [ "${json_de[i]}" = "1" ]; then
      _meow_obsidian_backup "$appearance" "$((i + 1))-$(basename -- "$MEOW_OBSIDIAN_VAULT")-appearance.json" || {
        meow_erro "obsidian: não consegui fazer backup do appearance.json de '$MEOW_OBSIDIAN_VAULT'"
        return "$MEOW_ERRO"
      }
      _meow_obsidian_json desfazer "$appearance" "$nossos_nomes"
      case $? in
        0|1) mudou=1; meow_muda "obsidian: cssTheme de '$MEOW_OBSIDIAN_VAULT' de volta ao padrão do app" ;;
        *) meow_erro "obsidian: falhou ao devolver o appearance.json de '$MEOW_OBSIDIAN_VAULT'"; return "$MEOW_ERRO" ;;
      esac
    fi
  done

  for fonte in ${baixados[@]+"${baixados[@]}"}; do
    if meow_seco; then meow_muda "obsidian: removeria o tema baixado em $fonte"; continue; fi
    if rm -rf -- "$fonte"; then mudou=1; meow_muda "obsidian: o tema baixado saiu de $fonte"; else
      meow_erro "obsidian: não consegui remover $fonte"; return "$MEOW_ERRO"
    fi
  done
  for sobra in ${sobras[@]+"${sobras[@]}"}; do
    if meow_seco; then meow_muda "obsidian: removeria a sobra de uma descida interrompida, $sobra"; continue; fi
    if rm -rf -- "$sobra"; then mudou=1; meow_muda "obsidian: a sobra de uma descida interrompida saiu de $sobra"; else
      meow_erro "obsidian: não consegui remover $sobra"; return "$MEOW_ERRO"
    fi
  done
  meow_seco && return "$MEOW_DIVERGENTE"
  rmdir -- "$MEOW_OBSIDIAN_BAIXADOS" 2>/dev/null || true

  [ "$mudou" = "0" ] && { meow_ok "obsidian: já estava sem o $_OBS_PACK_NOME"; return "$MEOW_OK"; }
  if [ -n "${MEOW_OBSIDIAN_BACKUP_DIR:-}" ] && [ -d "${MEOW_OBSIDIAN_BACKUP_DIR:-}/obsidian" ]; then
    meow_info "obsidian: backup do que existia em $MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  fi
  meow_ok "obsidian: sem o $_OBS_PACK_NOME — reabra o app para ver"
  while IFS= read -r nome; do
    [ -n "$nome" ] && meow_info "o snippet '$nome' continua no disco, desmarcado: Aparência > Snippets CSS"
  done < <(_meow_obsidian_snippets_desmarcados "$_OBS_PACKS" ${com_algo[@]+"${com_algo[@]}"})
  meow_app_desligar obsidian
  return "$MEOW_DIVERGENTE"
}
