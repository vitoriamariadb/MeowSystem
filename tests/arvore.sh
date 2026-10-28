#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }
git -C "$RAIZ" rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'pulado: %s não é um clone git\n' "$RAIZ"; exit 0; }

versionados() { git -C "$RAIZ" ls-files -- "$@"; }

amostra() {
  local n=0 linha
  while IFS= read -r linha; do
    [ -n "$linha" ] || continue
    n=$((n + 1))
    [ "$n" -le 5 ] && printf '         %s\n' "$linha" >&2
  done
  [ "$n" -gt 5 ] && printf '         ... e mais %d\n' "$((n - 5))" >&2
  return 0
}

printf 'a fronteira: assets/ é o motor, packs/ é o tema\n\n'

fora=$(versionados assets/temas | grep -v '^assets/temas/capturados/original/' || true)
if [ -z "$fora" ]; then
  ok "assets/temas/ só tem a captura 'original' ($(versionados assets/temas | wc -l) arquivos, o molde do v1)"
else
  falha "há tema versionado em assets/temas/ que não é a 'original' — ele pertence a um pack"
  printf '%s\n' "$fora" | amostra
fi

rons=$(versionados 'assets/*.ron' 'packs/*.ron' || true)
if [ -z "$rons" ]; then
  ok "nenhum .ron versionado em assets/ nem em packs/ — produto gerado mora em \$MEOW_ESTADO/temas/"
else
  falha "há .ron versionado: ele é saída de scripts/gerar_temas.py, não fonte"
  printf '%s\n' "$rons" | amostra
fi

n_up=$(versionados assets/icones/upstream | wc -l)
if [ "$n_up" = "0" ]; then
  ok "assets/icones/upstream/ tem 0 arquivos versionados — é acervo baixado, e o que se versiona é o script que baixa"
else
  falha "assets/icones/upstream/ tem $n_up arquivo(s) no git — é acervo de terceiro, baixado por scripts/baixar_upstream.sh"
  versionados assets/icones/upstream | amostra
fi

sobras=""
for caminho in src/applets assets/papeis-de-parede .playwright-mcp .trabalho-icones assets/icones/upstream; do
  [ -e "$RAIZ/$caminho" ] && sobras+="$caminho"$'\n'
done
for zip in "$RAIZ"/*.zip; do
  [ -e "$zip" ] && sobras+="$(basename "$zip")"$'\n'
done
if [ -z "$sobras" ]; then
  ok "a pasta não guarda build de applet, acervo de papel de parede, captura de navegador nem zip na raiz"
else
  falha "sobra na pasta do repositório: applet vive em extensoes/<id>, papel de parede em ~/.local/share/backgrounds, o git já guarda o resto"
  printf '%s' "$sobras" | amostra
fi

casa_de_ensaio="$(mktemp -d)"
trap 'rm -rf "$casa_de_ensaio"' EXIT
base_dentro="$(env -i PATH="$PATH" HOME="$casa_de_ensaio" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  WALLPAPER_BASE="$RAIZ/assets/papeis-de-parede" "$RAIZ/scripts/wallpaper.sh" base --conferir 2>&1)"; rc_dentro=$?
env -i PATH="$PATH" HOME="$casa_de_ensaio" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  WALLPAPER_BASE="$casa_de_ensaio/.local/share/backgrounds/meowsystem" \
  "$RAIZ/scripts/wallpaper.sh" base --conferir >/dev/null 2>&1; rc_fora=$?
if [ "$rc_dentro" = "1" ] && [ "$rc_fora" = "0" ]; then
  ok "o doctor diverge quando WALLPAPER_BASE mora dentro do repositório e passa quando mora fora"
else
  falha "a conferência da base do papel de parede não distingue dentro de fora (dentro=$rc_dentro fora=$rc_fora)"
  printf '%s\n' "$base_dentro" | amostra
fi

achadas=0
while IFS= read -r par; do
  [ -n "$par" ] || continue
  id_pack="${par%%/*}"; nome="${par##*/}"
  esperado="$RAIZ/packs/$id_pack/temas/capturados/$nome"
  resolvido="$(MEOW_PACK_DIR="$RAIZ/packs/$id_pack" \
    python3 "$RAIZ/scripts/pack.py" captura "$nome" 2>/dev/null)"
  if [ "$resolvido" = "$esperado" ]; then
    achadas=$((achadas + 1))
  else
    falha "a captura '$nome' do pack '$id_pack' não é a que o resolvedor acha"
    printf '         no disco:    %s\n' "$esperado" >&2
    printf '         resolvedor:  %s\n' "${resolvido:-<nada>}" >&2
  fi
done < <(versionados 'packs/*/temas/capturados/*' \
         | awk -F/ 'NF>=5 {print $2"/"$5}' | sort -u)
[ "$achadas" -gt 0 ] \
  && ok "as $achadas capturas dos packs são exatamente as que o pack.py resolve" \
  || falha "nenhum pack traz captura — o docs/PACKS.md promete que eles podem"

flavors=$(python3 - "$RAIZ" <<'PY'
import glob, json, os, sys
raiz = sys.argv[1]
nomes = set()
for p in glob.glob(os.path.join(raiz, "packs", "*", "paleta.json")):
    try:
        with open(p, encoding="utf-8") as fh:
            d = json.load(fh)
    except (OSError, json.JSONDecodeError):
        continue
    fl = d.get("flavors")
    nomes.update(fl.keys() if isinstance(fl, dict) else (fl or []))
    nomes.update(d.get("claros") or [])
print("|".join(sorted(n for n in nomes if n)))
PY
)
if [ -z "$flavors" ]; then
  falha "não consegui ler nenhum flavor de packs/*/paleta.json — sem isso esta conferência não mede nada"
else
  ISENTOS=()
  soltos=$(versionados assets | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in ${ISENTOS[@]+"${ISENTOS[@]}"}; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
      falha "a isenção '$isento' não cobre mais nada — apague-a deste teste"
    fi
    restantes=$(printf '%s\n' "$restantes" | grep -v "^$isento" || true)
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em assets/ (os temas de aplicativo moram nos packs)"
  else
    falha "há arquivo com nome de flavor em assets/, fora das isenções — ele veste alguém, logo é de um pack"
    printf '%s\n' "$restantes" | amostra
  fi
fi

sumidos=""
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="docs/CREDITOS.md: $c"$'\n'
done < <(grep -oE '`(packs|assets)/[^`<>*{} :]+`' "$RAIZ/docs/CREDITOS.md" | tr -d '`' | sort -u)
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="packs/meowsystem/PROCEDENCIA.md: $c"$'\n'
done < <(awk -F'|' '/^\| acervo \| onde /{t=1; next} t && !/^\|/{t=0} t{print $3}' \
           "$RAIZ/packs/meowsystem/PROCEDENCIA.md" | grep -oE '`(packs|assets)/[^`<>*{} :]+`' | tr -d '`' | sort -u)
while IFS= read -r id; do
  [ -d "$RAIZ/packs/$id" ] || sumidos+="docs/PACKS.md: <clone>/packs/$id/"$'\n'
done < <(grep -oE '<clone>/packs/[a-z0-9-]+/' "$RAIZ/docs/PACKS.md" | sed 's#<clone>/packs/##; s#/$##' | sort -u)
if [ -z "$sumidos" ]; then
  ok "o CREDITOS.md, o PACKS.md e o PROCEDENCIA.md do pack-base só apontam para o que está no git"
else
  falha "caminho que não existe mais no CREDITOS.md, no PACKS.md ou no PROCEDENCIA.md do pack-base"
  printf '%s' "$sumidos" | amostra
fi

printf '\n'
if [ "$ACHADOS" = "0" ]; then
  printf 'ok: a fronteira está de pé — o motor em assets/, o tema em packs/\n'
  exit 0
fi
printf 'NÃO: %d conferência(s) da fronteira falharam\n' "$ACHADOS" >&2
exit 1
