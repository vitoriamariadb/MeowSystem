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

printf 'a fronteira: dados/ é o motor, packs/ é o tema\n\n'

fora=$(git -C "$RAIZ" ls-files -co --exclude-standard -- dados/temas)
n_original=$(versionados packs/meowsystem/temas/capturados/original | wc -l)
if [ -z "$fora" ] && [ "$n_original" -gt 0 ]; then
  ok "dados/temas/ não existe: a captura 'original' ($n_original arquivos, o molde do v1) mora no pack-base"
else
  falha "há tema em dados/temas/, ou a captura 'original' saiu do pack-base — tema é de um pack"
  printf '%s\n' "$fora" | amostra
fi

rons=$(versionados 'dados/*.ron' 'packs/*.ron' || true)
if [ -z "$rons" ]; then
  ok "nenhum .ron versionado em dados/ nem em packs/ — produto gerado mora em \$MEOW_ESTADO/temas/"
else
  falha "há .ron versionado: ele é saída de scripts/gerar_temas.py, não fonte"
  printf '%s\n' "$rons" | amostra
fi

n_up=$(versionados dados/icones/upstream | wc -l)
if [ "$n_up" = "0" ]; then
  ok "dados/icones/upstream/ tem 0 arquivos versionados — é acervo baixado, e o que se versiona é o script que baixa"
else
  falha "dados/icones/upstream/ tem $n_up arquivo(s) no git — é acervo de terceiro, baixado por scripts/baixar_upstream.sh"
  versionados dados/icones/upstream | amostra
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
  soltos=$(versionados dados | grep -Ei "($flavors)" || true)
  restantes="$soltos"
  for isento in ${ISENTOS[@]+"${ISENTOS[@]}"}; do
    n=$(printf '%s\n' "$restantes" | grep -c "^$isento" || true)
    if [ "$n" = "0" ]; then
      falha "a isenção '$isento' não cobre mais nada — apague-a deste teste"
    fi
    restantes=$(printf '%s\n' "$restantes" | grep -v "^$isento" || true)
  done
  if [ -z "$restantes" ]; then
    ok "nenhum arquivo de tema solto em dados/ (os temas de aplicativo moram nos packs)"
  else
    falha "há arquivo com nome de flavor em dados/, fora das isenções — ele veste alguém, logo é de um pack"
    printf '%s\n' "$restantes" | amostra
  fi
fi

sumidos=""
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="docs/CREDITOS.md: $c"$'\n'
done < <(grep -oE '`(packs|dados)/[^`<>*{} :]+`' "$RAIZ/docs/CREDITOS.md" | tr -d '`' | sort -u)
while IFS= read -r c; do
  [ -n "$(versionados "$c")" ] || sumidos+="packs/meowsystem/PROCEDENCIA.md: $c"$'\n'
done < <(awk -F'|' '/^\| acervo \| onde /{t=1; next} t && !/^\|/{t=0} t{print $3}' \
           "$RAIZ/packs/meowsystem/PROCEDENCIA.md" | grep -oE '`(packs|dados)/[^`<>*{} :]+`' | tr -d '`' | sort -u)
while IFS= read -r id; do
  [ -d "$RAIZ/packs/$id" ] || sumidos+="docs/PACKS.md: <clone>/packs/$id/"$'\n'
done < <(grep -oE '<clone>/packs/[a-z0-9-]+/' "$RAIZ/docs/PACKS.md" | sed 's#<clone>/packs/##; s#/$##' | sort -u)
if [ -z "$sumidos" ]; then
  ok "o CREDITOS.md, o PACKS.md e o PROCEDENCIA.md do pack-base só apontam para o que está no git"
else
  falha "caminho que não existe mais no CREDITOS.md, no PACKS.md ou no PROCEDENCIA.md do pack-base"
  printf '%s' "$sumidos" | amostra
fi

moldes_fora=$(git -C "$RAIZ" ls-files -co --exclude-standard | grep -F '.modelo.' | grep -v '^packs/' || true)
if [ -z "$moldes_fora" ]; then
  ok "nenhum molde de tema (*.modelo.*) fora de packs/: o código não tem reserva própria"
else
  falha "molde de tema fora de packs/ — ele é do pack, nos dois packs do repositório"
  printf '%s\n' "$moldes_fora" | amostra
fi

EXTENSOES_DE_ARTE='svg|png|jpe?g|webp|css|toml|json|conf|colors|theme|tmtheme|qbtheme|ini|dconf|ovt|tdesktop-theme'
ISENCOES_DE_COR=(docs/logo.svg docs/capturas/ tests/oraculo/)
cor_fora=$(git -C "$RAIZ" ls-files -co --exclude-standard | python3 -c '
import os, re, sys
raiz, flavors, extensoes = sys.argv[1], [f for f in sys.argv[2].split("|") if f], sys.argv[3]
isencoes = sys.argv[4:]
arte = re.compile(r"\.(%s)$" % extensoes, re.I)
imagem = re.compile(r"\.(png|jpe?g|webp)$", re.I)
hexa = re.compile(r"#[0-9A-Fa-f]{6}(?![0-9A-Fa-f])")
nome = re.compile(r"(?<![A-Za-z0-9_])(%s)(?![A-Za-z0-9_])" % "|".join(map(re.escape, flavors)), re.I) if flavors else None
usadas = set()
for rel in sys.stdin.read().split("\n"):
    cheio = os.path.join(raiz, rel)
    if not rel or rel.startswith("packs/") or not arte.search(rel) or not os.path.isfile(cheio):
        continue
    isento = next((i for i in isencoes if rel == i or (i.endswith("/") and rel.startswith(i))), None)
    if isento:
        usadas.add(isento)
        continue
    if imagem.search(rel):
        print(rel + ":-: imagem")
        continue
    with open(cheio, encoding="utf-8", errors="replace") as fh:
        for n, linha in enumerate(fh, 1):
            for m in list(hexa.finditer(linha)) + (list(nome.finditer(linha)) if nome else []):
                print("%s:%d: %s" % (rel, n, m.group(0)))
for i in isencoes:
    if i not in usadas:
        print(i + ": a isenção não cobre mais nada")
' "$RAIZ" "$flavors" "$EXTENSOES_DE_ARTE" "${ISENCOES_DE_COR[@]}")
if [ -z "$cor_fora" ]; then
  ok "nenhum arquivo de arte ou de tema fora de packs/ traz cor ou nome de flavor (isentos: ${ISENCOES_DE_COR[*]})"
else
  falha "arquivo de arte ou de tema fora de packs/ com cor ou nome de flavor — a arte mora no pack"
  printf '%s\n' "$cor_fora" | sed 's/^/         /' >&2
fi

RAIZ_FECHADA=".gitattributes .github .gitignore .ignore .mailmap AGENTS.md GSD.md LICENSE README.en.md README.md dados docs install.sh meow.conf.exemplo packs scripts tests"
fora_da_raiz="$(versionados | cut -d/ -f1 | sort -u | grep -vxF -f <(tr ' ' '\n' <<< "$RAIZ_FECHADA") || true)"
if [ -z "$fora_da_raiz" ]; then
  ok "a raiz versionada é a da decisão 68: scripts/, dados/, packs/, tests/, docs/ e os arquivos soltos de hoje"
else
  falha "entrada versionada nova na raiz, fora das cinco pastas e dos arquivos soltos da decisão 68:"
  printf '%s\n' "$fora_da_raiz" | amostra
fi

printf '\n'
if [ "$ACHADOS" = "0" ]; then
  printf 'ok: a fronteira está de pé — o motor em dados/, o tema em packs/\n'
  exit 0
fi
printf 'NÃO: %d conferência(s) da fronteira falharam\n' "$ACHADOS" >&2
exit 1
