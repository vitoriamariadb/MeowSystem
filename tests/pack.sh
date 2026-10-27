#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ID="${1:-nord}"
case "$ID" in
  -h|--ajuda|--help)
    printf './tests/pack.sh [id]   monta um pack de mentira com esse id (padrão: nord)\n'; exit 0 ;;
  ''|*[!a-z0-9-]*|[!a-z]*)
    printf 'uso: %s [id]   — só minúsculas, dígitos e hífen, como o formato exige\n' \
      "$(basename "$0")" >&2; exit 2 ;;
esac
falhas=0
ok()     { printf 'ok: %s\n' "$1"; }
falha()  { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
PACKS="$T/packs"; PACK_DIR="$PACKS/$ID"; mkdir -p "$PACK_DIR" "$T/saida"

python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, sys, os
dir_pack, ident = sys.argv[1], sys.argv[2]
SLOTS = ["rosewater","flamingo","pink","mauve","red","maroon","peach","yellow",
         "green","teal","sky","sapphire","blue","lavender","text","subtext1",
         "subtext0","overlay2","overlay1","overlay0","surface2","surface1",
         "surface0","base","mantle","crust"]
claros = dict.fromkeys(SLOTS, "#D8DEE9")
escuro = dict.fromkeys(SLOTS, "#88C0D0")
escuro.update({"text": "#ECEFF4", "base": "#2E3440", "mantle": "#3B4252",
               "crust": "#434C5E", "mauve": "#B48EAD"})
claros.update({"text": "#2E3440", "base": "#ECEFF4", "mantle": "#E5E9F0",
               "crust": "#D8DEE9", "mauve": "#B48EAD"})
json.dump({"_comentario": "Pack de mentira do tests/pack.sh. Nao e o Nord de verdade.",
           "fonte": "https://www.nordtheme.com",
           "ordem_canonica": SLOTS,
           "claros": [ident + "claro"],
           "nomes": {ident: ident.capitalize(), ident + "claro": ident.capitalize() + " Claro"},
           "flavors": {ident: escuro, ident + "claro": claros}},
          open(os.path.join(dir_pack, "paleta.json"), "w"), indent=2, ensure_ascii=False)
json.dump({"formato": 1, "id": ident, "nome": ident.capitalize(),
           "paleta": {"arquivo": "paleta.json", "flavor_padrao": ident},
           "cosmic": {"nome_da_paleta": ident + "-<flavor>"},
           "vitrine": {"capa": "logo.svg"}},
          open(os.path.join(dir_pack, "pack.json"), "w"), indent=2, ensure_ascii=False)
PY
python3 "$RAIZ/scripts/pack.py" logo-gerado "$PACK_DIR" > "$PACK_DIR/logo.svg" || exit 2

amb() { env MEOW_PACKS="$PACKS" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" ID="$ID" "$@"; }
printf 'FLAVOR="%s"\nACCENT="mauve"\nMODO="escuro"\nLOGO="%s"\nPACK="%s"\n' \
  "$ID" "$ID" "$ID" > "$T/meow.conf"

saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack em \$MEOW_PACKS é encontrado e validado" \
  || falha "o pack em \$MEOW_PACKS não validou (rc=$rc)" "$saida"

saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  printf "%s\n%s\n" "$MEOW_PALETA" "$MEOW_PACK_DIR"')"; rc=$?
if [ "$rc" != "0" ]; then
  falha "meow_ponte_python falhou com um pack legítimo (rc=$rc)" "$saida"
else
  case "$saida" in
    "$PACK_DIR/paleta.json"*) ok "a ponte exporta MEOW_PALETA apontando para o pack" ;;
    *) falha "MEOW_PALETA não é a paleta do pack" "$saida" ;;
  esac
  case "$saida" in
    *"$PACK_DIR") ok "a ponte exporta MEOW_PACK_DIR apontando para o pack" ;;
    *) falha "MEOW_PACK_DIR não é o diretório do pack" "$saida" ;;
  esac
fi

saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  MEOW_PALETA=/tmp/nao-existe-mesmo.json meow_ponte_python' 2>&1)"; rc=$?
[ "$rc" = "2" ] \
  && ok "a ponte recusa a paleta inexistente (rc=2)" \
  || falha "a ponte aceitou uma paleta que não existe (rc=$rc)" "$saida"
case "$saida" in
  *nao-existe-mesmo.json*) ok "a recusa NOMEIA o arquivo que não existe" ;;
  *) falha "a recusa não disse qual arquivo faltava" "$saida" ;;
esac

l_ponte="$(grep -n '^  meow_ponte_python' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
l_pre="$(grep -n '^  meow_preflight' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
l_trava="$(grep -n '^  meow_travar' "$RAIZ/install.sh" | head -1 | cut -d: -f1)"
if [ -z "$l_ponte" ] || [ -z "$l_pre" ] || [ -z "$l_trava" ]; then
  falha "não achei a ponte, o pré-voo ou a trava no main() do install.sh" \
        "ponte=$l_ponte pre-voo=$l_pre trava=$l_trava"
elif [ "$l_ponte" -lt "$l_pre" ] && [ "$l_ponte" -lt "$l_trava" ]; then
  ok "a ponte roda antes do pré-voo e da trava (linhas $l_ponte < $l_pre, $l_trava)"
else
  falha "a ponte deixou de vir antes do pré-voo/trava" \
        "ponte=$l_ponte pre-voo=$l_pre trava=$l_trava"
fi

saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  python3 "$MEOW_RAIZ/scripts/gerar_temas.py" "$ID-mauve" --saida "'"$T"'/saida"' 2>&1)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "gerar_temas.py não gerou o tema do pack de terceiro (rc=$rc)" "$saida"
else
  nome="$(grep -m1 'name:' "$T/saida/meowsystem-$ID-mauve.ron" 2>/dev/null)"
  case "$nome" in
    *"\"$ID-$ID\""*) ok "o tema do pack se chama pelo pack, e não pelo Catppuccin" ;;
    *) falha "o palette.name não veio de cosmic.nome_da_paleta" "$nome" ;;
  esac
  grep -q '2E3440' "$T/saida/meowsystem-$ID-mauve.ron" \
    && ok "as cores do tema saíram da paleta do pack" \
    || falha "o tema não tem a cor de fundo do pack — a paleta veio de outro lugar"
fi

python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo)); p["creditos"] = "CREDITOS.md"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  falha "o pack promete CREDITOS.md, não entrega, e mesmo assim validou" "$saida"
else
  ok "o arquivo declarado e ausente recusa o pack (rc=$rc)"
  case "$saida" in
    *CREDITOS.md*) ok "a recusa NOMEIA o arquivo prometido" ;;
    *) falha "a recusa não disse qual arquivo faltava" "$saida" ;;
  esac
fi
printf 'creditos do pack de mentira\n' > "$PACK_DIR/CREDITOS.md"

python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo)); p["campo_que_ninguem_le"] = "x"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
case "$saida" in
  *campo_que_ninguem_le*) ok "o campo sem leitor aparece nomeado no aviso" ;;
  *) falha "o campo sem leitor passou em silêncio" "$saida" ;;
esac
[ "$rc" = "0" ] \
  && ok "o campo sem leitor é aviso, e não recusa" \
  || falha "o aviso de campo sem leitor recusou o pack (rc=$rc)" "$saida"

python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"] = {"autorais": {"gerar": False}}
p["origens"] = {"cursores": {"tema": "um-ponteiro-qualquer"}}
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ] && [[ "$saida" == *campo_que_ninguem_le* ]] \
   && [[ "$saida" != *icones.autorais.gerar* ]] && [[ "$saida" != *origens.cursores.tema* ]]; then
  ok "o aviso não chama de morto icones.autorais.gerar nem origens.cursores.tema, que têm leitor"
else
  falha "o aviso de campo morto acusou um campo que tem leitor (rc=$rc)" "$saida"
fi
python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p.pop("icones"); p.pop("origens")
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY

amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "o verbo 'caminho' ainda responde como sonda de existência" \
  || falha "o verbo 'caminho' parou de servir de sonda — o lib/comum.sh deixa de ver o pack, calado"

mkdir -p "$PACK_DIR/icones"
printf 'firefox : apps/firefox.svg\n' > "$PACK_DIR/icones/apps.map"
python3 - "$PACK_DIR" "$ID" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"] = {"apps": {"mapa": "icones/apps.map"}}
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.apps.mapa 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$saida" = "$PACK_DIR/icones/apps.map" ] \
  && ok "o acervo do pack de terceiro resolve fora de RAIZ/packs" \
  || falha "o acervo não resolveu o mapa do pack (rc=$rc)" "$saida"
amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.pastas.desenhos >/dev/null 2>&1 \
  && falha "o acervo inventou um caminho para uma categoria que o pack não declara" \
  || ok "categoria não declarada devolve ausência, e não um caminho torto"

raizes="$(amb python3 "$RAIZ/scripts/pack.py" raizes)"
case "$raizes" in
  "$PACKS"*) ok "as raízes honram \$MEOW_PACKS, e ele vem primeiro" ;;
  *) falha "\$MEOW_PACKS não é a primeira raiz" "$raizes" ;;
esac
dir_shell="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; PACK="$ID" meow_pack_dir')"
[ "$dir_shell" = "$PACK_DIR" ] \
  && ok "o shell acha o pack pela mesma lista de raízes" \
  || falha "meow_pack_dir não achou o pack em \$MEOW_PACKS" "$dir_shell"

cat > "$T/filho.sh" <<'FILHO'
#!/usr/bin/env bash
. "$MEOW_RAIZ/lib/comum.sh"
meow_ponte_python >/dev/null 2>&1 || exit 9
printf '%s\n%s\n' "$MEOW_PALETA" "$MEOW_PACK_DIR"
FILHO
chmod +x "$T/filho.sh"
saida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
  PACK=meowsystem FLAVOR=mocha meow_ponte_python >/dev/null 2>&1 || exit 9
  export PACK="$ID" FLAVOR="$ID"
  exec "'"$T"'/filho.sh"')"; rc=$?
if [ "$rc" != "0" ]; then
  falha "a ponte do filho falhou depois de o pai ter resolvido o embutido (rc=$rc)" "$saida"
else
  case "$saida" in
    "$PACK_DIR/paleta.json"*) ok "o filho reresolve a paleta com o conf novo, e não herda a do pai" ;;
    *) falha "o filho herdou a paleta do pai — o eco da ponte voltou a grudar" "$saida" ;;
  esac
  case "$saida" in
    *"$PACK_DIR") ok "a paleta e o diretório do pack saem do MESMO pack" ;;
    *) falha "a ponte exportou um par incoerente (paleta de um pack, diretório de outro)" "$saida" ;;
  esac
fi

embutida="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; PACK=meowsystem meow_paleta')"
saida="$(amb bash -c 'export MEOW_PALETA="'"$embutida"'"
  . "$MEOW_RAIZ/lib/comum.sh"
  PACK="$ID" FLAVOR="$ID" meow_ponte_python >/dev/null 2>&1 || exit 9
  export PACK="$ID" FLAVOR="$ID"
  exec "'"$T"'/filho.sh"')"; rc=$?
case "$saida" in
  "$embutida"*) ok "o MEOW_PALETA da pessoa atravessa o filho sem ser reresolvido" ;;
  *) falha "a escolha da pessoa foi descartada pelo filho (rc=$rc)" "$saida" ;;
esac

printf 'isto esta fora do pack\n' > "$T/fora-do-pack.map"
python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"]["apps"]["mapa"] = "../../fora-do-pack.map"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" acervo "$ID" icones.apps.mapa 2>&1)"; rc=$?
case "$saida" in
  *fora-do-pack.map*"sai de dentro do pack"*) ok "o acervo recusa o caminho que sai do pack, e o NOMEIA" ;;
  *) falha "o acervo leu (ou calou) um caminho que sai de dentro do pack (rc=$rc)" "$saida" ;;
esac
python3 - "$PACK_DIR" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["icones"]["apps"]["mapa"] = "icones/apps.map"
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY

for verbo in cmd_status cmd_doctor cmd_desfazer; do
  corpo="$(sed -n "/^$verbo()/,/^}/p" "$RAIZ/bin/meow")"
  if printf '%s\n' "$corpo" | grep -q 'carregar_conf --ponte-opcional'; then
    ok "$verbo não é trancado pela paleta"
  else
    falha "$verbo voltou a depender da paleta para rodar"
  fi
done


padrao="$(amb python3 "$RAIZ/scripts/pack.py" padrao 2>/dev/null)"
if [ -z "$padrao" ] || [ ! -f "$padrao/pack.json" ]; then
  falha "o pack padrão não é um diretório com pack.json" "padrao=$padrao"
else
  ok "o pack padrão tem pack.json, como qualquer outro"
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$padrao" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack padrão valida com as MESMAS regras do pack de terceiro" \
    || falha "o pack padrão não valida (rc=$rc)" "$saida"
  case "$saida" in
    *"NENHUM código lê"*) falha "o pack padrão declara campo sem leitor" "$saida" ;;
    *) ok "o pack padrão sai limpo do aviso de campo sem leitor" ;;
  esac
fi

corpo="$(sed -n '/^cmd_pack()/,/^}/p' "$RAIZ/bin/meow")"
if printf '%s\n' "$corpo" | grep -vE '^\s*#' | grep -q 'catppuccin'; then
  falha "cmd_pack voltou a cravar o nome de um pack em código" \
        "$(printf '%s\n' "$corpo" | grep -vE '^\s*#' | grep -n 'catppuccin')"
else
  ok "o cmd_pack não nomeia pack nenhum — a lista sai do disco"
fi
saida="$(env MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_ESTADO="$T/estado" \
         "$RAIZ/bin/meow" pack listar 2>&1)"
linha_padrao="$(printf '%s\n' "$saida" | grep -F "$padrao" || true)"
[ -n "$linha_padrao" ] \
  && ok "o pack padrão aparece no 'meow pack listar' com o diretório dele" \
  || falha "o pack padrão sumiu da lista, ou entrou sem vir da varredura" "$saida"

_velho='assets/paleta'"/catppuccin\.json"

_novo='packs/catppuccin'"/paleta\.json"

cravado="$(grep -rnE --include='*.sh' --include='*.py' --include='meow' \
             "($_velho|$_novo)" "$RAIZ/install.sh" "$RAIZ/lib" \
             "$RAIZ/scripts" "$RAIZ/app" "$RAIZ/bin" 2>/dev/null \
           | grep -v 'scripts/pack\.py:' \
           | grep -v 'scripts/derivar_claro\.py:' \
           | grep -vE ":[0-9]+:[^#]*#.*($_velho|$_novo)" \
           | grep -vE ':[0-9]+:\s*("""|#)' || true)"
if [ -n "$cravado" ]; then
  falha "código cravando o caminho da paleta do pack padrão:"
  printf '%s\n' "$cravado" | sed "s#^$RAIZ/#  #" >&2
else
  ok "nenhum código crava a paleta do pack padrão — todos passam pela porta"
fi

if command -v git >/dev/null 2>&1 \
   && git -C "$RAIZ" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  sumidos="$(git -C "$RAIZ" ls-files '*.svg' | while IFS= read -r f; do
               [ -e "$RAIZ/$f" ] || printf '%s\n' "$f"
             done)"
  [ -z "$sumidos" ] \
    && ok "todo SVG versionado existe no disco — nenhum sumiu numa mudança de casa" \
    || falha "SVG versionado que não está no disco:" "$sumidos"

  restos="$(git -C "$RAIZ" ls-files 'assets/icones/*/*.svg' \
              | grep -E '(mocha|macchiato|frappe|latte|dracula|alucard)' || true)"
  [ -z "$restos" ] \
    && ok "nenhum desenho de tema ficou em assets/icones/ — todo ícone que veste alguém mora no pack" \
    || falha "desenho de flavor ainda em assets/icones/:" "$restos"
fi

vazios="$(python3 - "$RAIZ" <<'PY'
import json, os, sys
raiz = sys.argv[1]
base = os.path.join(raiz, "packs")
for pid in sorted(os.listdir(base) if os.path.isdir(base) else []):
    dir_pack = os.path.join(base, pid)
    manifesto = os.path.join(dir_pack, "pack.json")
    if not os.path.isfile(manifesto):
        continue
    try:
        p = json.load(open(manifesto, encoding="utf-8"))
        declarado = ((p.get("icones") or {}).get("autorais") or {}).get("desenhos")
        if not declarado:
            continue
        acv = os.path.join(dir_pack, declarado)
        if not os.path.isdir(acv):
            continue
        arq = os.path.join(dir_pack, (p.get("paleta") or {}).get("arquivo", "paleta.json"))
        flavors = json.load(open(arq, encoding="utf-8")).get("flavors", {})
    except (OSError, ValueError):
        continue
    svgs = [a for a in os.listdir(acv) if a.endswith(".svg")]
    conta = {f: sum(1 for a in svgs if a.endswith("-%s.svg" % f)) for f in flavors}
    if any(conta.values()):
        for f, n in sorted(conta.items()):
            if n == 0:
                print("%s: o flavor %r não tem nenhum autoral, e os irmãos têm" % (pid, f))
PY
)"
[ -z "$vazios" ] \
  && ok "nenhum flavor cai no acervo autoral do vizinho — o claro de cada pack é dele" \
  || falha "flavor sem desenho autoral próprio (ele cai no acervo herdado, calado):" "$vazios"

base_mapa="$PACK_DIR/icones"
saida="$(printf 'apps/x.svg\nmotor:arcticons/y.svg\nmotor:apps/arcticons/z.svg\n' \
           | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null)"
esperado="$base_mapa/apps/x.svg
$RAIZ/packs/meowsystem/icones/sistema/y.svg
$RAIZ/packs/meowsystem/icones/apps/z.svg"
[ "$saida" = "$esperado" ] \
  && ok "'motor:' resolve no pack-base, a pasta de antes pela de hoje, e o resto cai dentro do pack" \
  || falha "o prefixo motor: não resolveu como o contrato manda" "$saida"

entrada="$(printf 'apps/a.svg\n../../fora.svg\nmotor:../../../etc/passwd\napps/b.svg\n')"
n_ent=$(printf '%s\n' "$entrada" | wc -l)
n_sai=$(printf '%s\n' "$entrada" \
          | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null | wc -l)
[ "$n_ent" = "$n_sai" ] \
  && ok "o resolvedor de alvo devolve uma linha por linha, mesmo recusando ($n_sai/$n_ent)" \
  || falha "o alvo perdeu o alinhamento entrada/saída — o paste vestiria o app errado" \
           "entrada=$n_ent saída=$n_sai"
fugas="$(printf '%s\n' "$entrada" \
           | amb python3 "$RAIZ/scripts/pack.py" alvo "$base_mapa" 2>/dev/null \
           | grep -v "^$base_mapa/" | grep -v "^$RAIZ/assets/icones/" | grep -v '^$' || true)"
[ -z "$fugas" ] \
  && ok "alvo que sai da raiz é recusado, e a linha volta vazia" \
  || falha "o resolvedor deixou um alvo escapar da raiz:" "$fugas"

mapa_t="$T/apps-parser.map"
printf '%s\n' \
  'um.motor : motor:arcticons/telegram.svg' \
  'dois.pack : apps/Warehouse.svg' \
  'tres.comentario : apps/Warehouse.svg # a procedência não entra em nada' \
  > "$mapa_t"
pares="$(MAPA="$mapa_t" ICONES_BASE_MAPA="$base_mapa" RAIZ="$RAIZ" bash -c '
  set -uo pipefail
  # [P73: o parser do shell é o `_dracula_pares_do_mapa`; ver o tests/fonte-unica.sh.]
  eval "$(sed -n "/^_dracula_pares_do_mapa() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares_do_mapa' 2>/dev/null)"
esperado_p="um.motor	$RAIZ/packs/meowsystem/icones/biblioteca/telegram.svg
dois.pack	$base_mapa/apps/Warehouse.svg
tres.comentario	$base_mapa/apps/Warehouse.svg"
[ "$pares" = "$esperado_p" ] \
  && ok "o parser do mapa entrega o prefixo 'motor:' inteiro ao resolvedor" \
  || falha "o parser do mapa truncou o caminho — o 'motor:' não chega ao resolvedor" "$pares"

onde="$(amb python3 "$RAIZ/scripts/pack.py" onde "$ID" icones.autorais.desenhos icones/autorais/ 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$onde" = "$PACK_DIR/icones/autorais/" ] && [ ! -d "$onde" ] \
  && ok "o 'onde' responde o endereço do acervo antes de ele existir" \
  || falha "o 'onde' não respondeu o acervo de um pack que ainda não o criou (rc=$rc)" "$onde"

mkdir -p "$PACK_DIR/capturas"
printf '# %s\n\nHistória com <script>alert(1)</script> e **negrito**.\n' "$ID" > "$PACK_DIR/LEIA-ME.md"
printf '\x89PNG\r\n\x1a\n' > "$PACK_DIR/capturas/tela.png"
cp "$PACK_DIR/logo.svg" "$T/logo-guardado.svg"
sed 's#</svg>#<script>alert(1)</script></svg>#' "$PACK_DIR/logo.svg" > "$PACK_DIR/outra-capa.svg"
por_vitrine() {
  python3 - "$PACK_DIR" "$1" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
p["autor"] = "o tests/pack.sh"
if sys.argv[2] == "-":
    p.pop("vitrine", None)
else:
    p["vitrine"] = json.loads(sys.argv[2])
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
}
VIT_BOA='{"capa": "logo.svg", "descricao_curta": "Um pack de mentira, para o teste.",
          "descricao": "LEIA-ME.md", "tags": ["escuro", "teste"],
          "capturas": ["capturas/tela.png"], "site": "https://www.nordtheme.com"}'

por_vitrine "$VIT_BOA"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a vitrine completa valida (capa, frase, história, tags, captura, site)" \
  || falha "a vitrine completa foi recusada (rc=$rc)" "$saida"

cabeca="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1 | head -6)"
case "$cabeca" in
  *"o tests/pack.sh"*"Um pack de mentira"*"escuro, teste"*"próprio: "*" · "*)
    ok "o info abre com autor, frase, tags e a linha próprio/herdado" ;;
  *) falha "as seis primeiras linhas do info não são a vitrine" "$cabeca" ;;
esac

rm -f "$PACK_DIR/logo.svg"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
if [ "$rc" = "0" ]; then
  falha "sem a capa, o pack validou" "$saida"
else
  case "$saida" in
    *vitrine.capa*logo.svg*) ok "sem a capa, validar recusa (rc=$rc) e nomeia o arquivo que falta" ;;
    *) falha "a recusa sem capa não nomeou o arquivo" "$saida" ;;
  esac
fi
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "sem a capa o motor continua vendo o pack — a vitrine não tranca o tema" \
  || falha "a capa ausente fez o pack sumir da sonda do meow_pack_dir"
cp "$T/logo-guardado.svg" "$PACK_DIR/logo.svg"

por_vitrine '{"capa": "logo.svg", "descricao_curta": "12345678901234567890123456789012345678901234567890123456789012345678901234567890X"}'
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && ok "a frase acima do teto não tira o pack do motor" \
  || falha "a frase acima do teto fez o pack sumir da sonda do meow_pack_dir"
saida="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"NÃO VALIDA"*"81 caracteres"* ]] \
  && ok "o info mostra o pack de frase comprida, e diz o que falta" \
  || falha "o info escondeu o pack de frase comprida, ou não disse por quê (rc=$rc)" "$saida"

por_vitrine '{"capa": "logo.svg", "site": "http://exemplo.org"}'
amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id >/dev/null 2>&1 \
  && falha "o site em http:// não tirou o pack do motor — o docs/PACKS.md diz que tira" \
  || ok "o site em http:// tira o pack do motor, como toda URL fora de https"
por_vitrine "$VIT_BOA"

while IFS='|' read -r bloco espera nome; do
  por_vitrine "$bloco"
  saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1 </dev/null)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$espera"* ]]; then
    ok "recusa $nome (rc=$rc)"
  else
    falha "não recusou $nome, ou não disse por quê (rc=$rc)" "$saida"
  fi
done <<'CASOS'
-|'vitrine'|o pack sem bloco vitrine
{"descricao_curta": "sem capa"}|vitrine.capa: é obrigatória|a vitrine sem capa declarada
{"capa": "capturas/tela.png"}|não é .svg|a capa que não é SVG
{"capa": "../fora.svg"}|sai de dentro do pack|a capa fora do pack
{"capa": "outra-capa.svg"}|outra-capa.svg: tem <script>|a capa que é outro SVG, com script: ela é o logo, e passa pela conferência dele
{"capa": "logo.svg", "descricao_curta": "12345678901234567890123456789012345678901234567890123456789012345678901234567890X"}|81 caracteres, e o teto é 80|a frase curta acima de 80
{"capa": "logo.svg", "site": "http://exemplo.org"}|só https|o site em http
{"capa": "logo.svg", "site": "javascript:alert(1)"}|vitrine.site|o site em javascript:
{"capa": "logo.svg", "descricao": "pack.json"}|vitrine.descricao|a história que não é Markdown
CASOS
por_vitrine "$VIT_BOA"

saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
ident = sys.argv[2]
achados = [p for p in servidor.packs_com_vitrine() if p["id"] == ident]
if not achados:
    print("o pack de mentira não veio no /api/packs"); sys.exit(1)
p = achados[0]
erros = []
if "<script>alert(1)</script>" not in p["descricao"]:
    erros.append("a história não chegou crua: %r" % p["descricao"][:80])
if not p["capa"] or p["problemas"]:
    erros.append("a capa não veio, ou veio com problema: %r %r" % (p["capa"], p["problemas"]))
if p["site"] != "https://www.nordtheme.com" or len(p["capturas"]) != 1:
    erros.append("site ou capturas errados: %r %r" % (p["site"], p["capturas"]))
if "próprio: " not in p["origem"] or len(p["amostra"]) != 26:
    erros.append("origem ou amostra errados: %r (%d cores)" % (p["origem"], len(p["amostra"])))
capa = servidor.arte_da_vitrine(ident, "capa")
if not capa or capa[1] != "image/svg+xml":
    erros.append("a capa não é servida como SVG: %r" % (capa and capa[1]))
elif capa[0].decode("utf-8") != servidor.modulo_pack().logo(ident, ident):
    erros.append("a capa servida não é o que o logo() responde no flavor padrão")
if not servidor.arte_da_vitrine(ident, "0"):
    erros.append("a captura declarada não é servida")
for arte in ("1", "../pack.json", "../../../etc/passwd", "-1", ""):
    if servidor.arte_da_vitrine(ident, arte) is not None:
        erros.append("a rota de arte serviu %r" % arte)
if servidor.arte_da_vitrine(os.path.join(sys.argv[1], "packs", "dracula"), "capa") is not None:
    erros.append("a rota de arte aceitou um CAMINHO no lugar do id")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o /api/packs leva a história crua, e a rota de arte só serve o que o pack declarou" \
  || falha "o painel não honra a vitrine" "$saida"

saida="$(amb python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
erros = []
cartoes = {p["id"]: p for p in servidor.packs_com_vitrine()}
for ident, arquivo in (("dracula", "morcego-dia.svg"), ("meowsystem", "mimir.svg")):
    arte = servidor.arte_da_vitrine(ident, "mascote")
    with open(os.path.join(sys.argv[1], "packs", ident, "mascote", arquivo), "rb") as fh:
        esperado = fh.read()
    if not arte or arte[0] != esperado or arte[1] != "image/svg+xml":
        erros.append("a rota de arte não serviu o mascote de %s (%s)" % (ident, arquivo))
    if not cartoes.get(ident, {}).get("mascote", "").endswith("&arte=mascote"):
        erros.append("o cartão de %s não leva a URL do mascote dele" % ident)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
corpo="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
[ "$rc" = "0" ] && grep -q 'p.no_ar || !p.mascote ? urlDoGato(.*) : p.mascote' <<< "$corpo" \
  && ok "o cartão de cada pack mostra o mascote dele, e não o do pack no ar" \
  || falha "a prévia do cartão mostra o mascote do pack no ar em todos os cartões" "$saida"

por_vitrine '{"capa": "outra-capa.svg"}'
saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
ident = sys.argv[2]
p = [p for p in servidor.packs_com_vitrine() if p["id"] == ident][0]
erros = []
if servidor.arte_da_vitrine(ident, "capa") is not None:
    erros.append("a rota de arte serviu a capa com <script>")
if p["capa"] or not any("<script>" in x for x in p["problemas"]):
    erros.append("o cartão levou a capa, ou não disse o motivo: %r %r" % (p["capa"], p["problemas"]))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
info="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"
[ "$rc" = "0" ] && [[ "$info" == *"NÃO VALIDA"*"outra-capa.svg: tem <script>"* ]] \
  && ok "a capa com script não é servida, e o cartão e o info dizem por quê" \
  || falha "a capa com script chegou ao painel, ou ninguém disse por quê" "$saida
$info"
por_vitrine "$VIT_BOA"

corpo="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
if [ -z "$corpo" ]; then
  falha "não achei cartaoDePack em app/pagina/paginas.js"
elif printf '%s\n' "$corpo" | grep -vE '^\s*(\*|/\*|//)' \
     | grep -qE '\bhtml:|innerHTML|insertAdjacentHTML|outerHTML|DOMParser|p\.descricao'; then
  falha "o cartão de pack interpreta HTML ou desenha a história de terceiro" \
        "$(printf '%s\n' "$corpo" | grep -nE '\bhtml:|innerHTML|insertAdjacentHTML|outerHTML|DOMParser|p\.descricao')"
else
  ok "o cartão de pack se monta nó a nó por texto, sem a história de terceiro"
fi

CASA="$T/casa"; mkdir -p "$CASA"
cp "$RAIZ/meow.conf.exemplo" "$T/usar.conf"
usar_amb() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/usar.conf" \
    MEOW_COSMIC_DIR="$CASA/cosmic" NO_COLOR=1 "$@"
}
tema_do_conf() {
  usar_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"
    set -a; . "$MEOW_CONF"; set +a
    meow_ponte_python >/dev/null 2>&1 || exit 9
    par="$FLAVOR-$ACCENT"
    "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$par" >/dev/null 2>&1 || exit 8
    "$MEOW_RAIZ/scripts/aplicar_tema.sh" "$par" --conferir >/dev/null 2>&1; rc=$?
    printf "%s %s %s\n" "$(basename "$MEOW_PACK_DIR")" "$par" "$rc"'
}
sem_as_duas() { grep -vE '^(PACK|FLAVOR|CURSOR|LOGO|LOGO_DIA|LOGO_NOITE|FASTFETCH_LOGO_GATO)=' "$1"; }
mascote_do_conf() {
  printf '%s|%s|%s' "$(sed -n 's/^LOGO_DIA="\([^"]*\)".*/\1/p' "$T/usar.conf" | tail -n1)" \
    "$(sed -n 's/^LOGO_NOITE="\([^"]*\)".*/\1/p' "$T/usar.conf" | tail -n1)" \
    "$(sed -n 's/^FASTFETCH_LOGO_GATO="\([^"]*\)".*/\1/p' "$T/usar.conf" | tail -n1)"
}
logo_do_conf() { sed -n 's/^LOGO="\([^"]*\)".*/\1/p' "$T/usar.conf" | tail -n1; }
mascote_do_painel() {
  usar_amb python3 -I - "$RAIZ/app" <<'PY' 2>/dev/null
import sys
sys.path.insert(0, sys.argv[1])
import servidor
v = servidor.valores_brutos()
print("|".join(v.get(k, "?") for k in ("LOGO_DIA", "LOGO_NOITE", "FASTFETCH_LOGO_GATO")), end="")
PY
}

sed -i 's/^LOGO_MODO="[^"]*"/LOGO_MODO="fixo"/' "$T/usar.conf"
antes="$(sem_as_duas "$T/usar.conf")"
saida="$(usar_amb "$RAIZ/bin/meow" pack usar dracula --sem-aplicar 2>&1)"; rc=$?
if [ "$rc" = "0" ] && grep -qx 'PACK="dracula"' "$T/usar.conf" \
   && grep -q '^FLAVOR="dracula"' "$T/usar.conf" && grep -q '^CURSOR="Dracula-Cursor"' "$T/usar.conf" \
   && [ "$(sem_as_duas "$T/usar.conf")" = "$antes" ]; then
  ok "meow pack usar grava PACK e FLAVOR, leva o ponteiro do pack, e nenhuma outra linha do conf"
else
  falha "meow pack usar dracula não gravou só as duas chaves (rc=$rc)" "$saida"
fi
ida_mascote="$(mascote_do_conf)"
[ "$ida_mascote" = "morcego-dia|morcego-noite|morcego-noite" ] && [ "$(mascote_do_painel)" = "$ida_mascote" ] \
  && ok "o mascote de fábrica vai junto para o do Dracula, no conf e no painel ($ida_mascote)" \
  || falha "o mascote não acompanhou o pack" "conf '$ida_mascote', painel '$(mascote_do_painel)'"
ida_logo="$(logo_do_conf)"
[ "$ida_logo" = "morcego-noite" ] \
  && ok "com LOGO_MODO=fixo, o LOGO de fábrica vai junto para o do Dracula ($ida_logo)" \
  || falha "o LOGO do modo fixo ficou no mascote do pack de antes" "veio '$ida_logo', esperava 'morcego-noite'"
ida="$(tema_do_conf)"
[ "$ida" = "dracula dracula-mauve 0" ] \
  && ok "depois da troca, o tema no disco é o do Dracula ($ida)" \
  || falha "o tema no disco não é o do pack escolhido" "esperava 'dracula dracula-mauve 0', veio '$ida'"

saida="$(usar_amb "$RAIZ/bin/meow" pack usar meowsystem --sem-aplicar 2>&1)"; rc=$?
volta="$(tema_do_conf)"
if [ "$rc" = "0" ] && grep -qx 'PACK="meowsystem"' "$T/usar.conf" \
   && [ "$volta" = "meowsystem mocha-mauve 0" ]; then
  ok "e a volta: o flavor que não é do pack cai no padrão dele, e o tema no disco acompanha ($volta)"
else
  falha "a volta ao Catppuccin não levou o tema junto (rc=$rc, veio '$volta')" "$saida"
fi
volta_mascote="$(mascote_do_conf)"
[ "$volta_mascote" = "mimir|coquinha|coquinha" ] && [ "$(mascote_do_painel)" = "$volta_mascote" ] \
  && ok "e o mascote volta ao de fábrica do MeowSystem ($volta_mascote)" \
  || falha "o mascote não voltou com o pack" "conf '$volta_mascote', painel '$(mascote_do_painel)'"
volta_logo="$(logo_do_conf)"
[ "$volta_logo" = "coquinha" ] \
  && ok "e o LOGO do modo fixo volta ao de fábrica do MeowSystem ($volta_logo)" \
  || falha "o LOGO do modo fixo não voltou com o pack" "veio '$volta_logo', esperava 'coquinha'"
sed -i 's/^LOGO_DIA="[^"]*"/LOGO_DIA="coquinha"/' "$T/usar.conf"
usar_amb "$RAIZ/bin/meow" pack usar dracula --sem-aplicar >/dev/null 2>&1
sed -i -e 's/^LOGO_NOITE="[^"]*"/LOGO_NOITE="morcego"/' -e 's/^LOGO="[^"]*"/LOGO="morcego"/' "$T/usar.conf"
usar_amb "$RAIZ/bin/meow" pack usar meowsystem --sem-aplicar >/dev/null 2>&1
escolhido="$(mascote_do_conf)|$(logo_do_conf)"
[ "$escolhido" = "coquinha|morcego|coquinha|morcego" ] \
  && ok "o mascote que ela escolheu não é trocado ($escolhido)" \
  || falha "a troca de pack mexeu num mascote escolhido" "veio '$escolhido', esperava 'coquinha|morcego|coquinha|morcego'"
sed -i -e 's/^LOGO_DIA="[^"]*"/LOGO_DIA="mimir"/' -e 's/^LOGO_NOITE="[^"]*"/LOGO_NOITE="coquinha"/' "$T/usar.conf"
residuo="$(usar_amb "$RAIZ/scripts/aplicar_tema.sh" dracula-mauve --conferir >/dev/null 2>&1; echo $?)"
[ "$residuo" != "0" ] \
  && ok "o tema do pack de antes deixou de conferir: nada dele ficou no disco" \
  || falha "o COSMIC de brinquedo ainda confere com o Dracula depois da volta"

copia="$(cat "$T/usar.conf")"
usar_amb "$RAIZ/bin/meow" pack usar dracula mocha --sem-aplicar >/dev/null 2>&1; r1=$?
usar_amb "$RAIZ/bin/meow" pack usar nao-existe --sem-aplicar >/dev/null 2>&1; r2=$?
usar_amb env MEOW_DRY_RUN=1 "$RAIZ/bin/meow" pack usar dracula --sem-aplicar >/dev/null 2>&1; r3=$?
if [ "$r1" != "0" ] && [ "$r2" != "0" ] && [ "$r3" = "1" ] && [ "$(cat "$T/usar.conf")" = "$copia" ]; then
  ok "flavor de outro pack, pack inexistente e ensaio saem sem escrever (rc=$r1 $r2 $r3)"
else
  falha "meow pack usar escreveu onde devia recusar (rc=$r1 $r2 $r3)" "$(diff <(printf '%s\n' "$copia") "$T/usar.conf")"
fi

saida="$(usar_amb env MEOW_PACKS="$PACKS" "$RAIZ/bin/meow" pack usar "$ID" --sem-aplicar 2>&1)"; rc=$?
[ "$rc" = "0" ] && grep -qx "PACK=\"$ID\"" "$T/usar.conf" && grep -q "^FLAVOR=\"$ID\"" "$T/usar.conf" \
  && ok "o pack de terceiro também se usa pelo verbo, com o flavor padrão dele" \
  || falha "meow pack usar $ID não gravou o pack de terceiro (rc=$rc)" "$saida"

vestigios_do_painel() {
  usar_amb env MEOW_CONF="$1" python3 - "$RAIZ" <<'PY' 2>/dev/null
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
print(" ".join(sorted(k for k in servidor.valores_brutos() if servidor._vestigio_de_pack(k))))
PY
}
vest_caso() {
  local conf="$T/vest.conf" saida painel k faltou=""
  sed "$4" "$RAIZ/meow.conf.exemplo" > "$conf"
  saida="$(usar_amb env MEOW_CONF="$conf" "$RAIZ/bin/meow" pack usar "$2" --sem-aplicar 2>&1)"
  painel="$(vestigios_do_painel "$conf")"
  for k in $painel; do grep -qw -- "$k" <<< "$saida" || faltou="$faltou $k"; done
  if [ -n "$3" ] && ! grep -qw -- "$3" <<< "$painel"; then
    falha "$1: o caso deixou de montar o que mede (o painel marca '$painel', esperava $3)"
  elif [ -z "$3" ] && { [ -n "$painel" ] || grep -q 'continuam valendo.*CURSOR' <<< "$saida"; }; then
    falha "$1: o terminal ou o painel acusam um vestígio que não existe (painel: '$painel')" "$saida"
  elif [ -n "$faltou" ]; then
    falha "$1: o painel marca$faltou e o terminal não disse" "$saida"
  else
    ok "$1 (painel: '${painel:-nenhum}')"
  fi
}
vest_caso "Catppuccin -> Dracula: o CURSOR que o Dracula receita não é vestígio" \
  dracula "" 's/^PACK=.*/PACK="meowsystem"/'
vest_caso "Dracula -> Catppuccin: o CURSOR fixado do Dracula é vestígio, e o terminal diz" \
  catppuccin CURSOR 's/^PACK=.*/PACK="dracula"/; s/^FLAVOR=.*/FLAVOR="dracula"/; s/^CURSOR=.*/CURSOR="Dracula-Cursor-Branco"/'
vest_caso "sabor sem PACK -> Dracula: o CURSOR do Latte é vestígio, e o terminal diz" \
  dracula CURSOR 's/^FLAVOR=.*/FLAVOR="latte"/; s/^CURSOR=.*/CURSOR="catppuccin-latte-dark"/'

FAM="$T/familia.conf"
sed 's/^PACK=.*/PACK="dracula"/; s/^FLAVOR=.*/FLAVOR="dracula"/' "$RAIZ/meow.conf.exemplo" > "$FAM"
printf '\nMEOW_FAMILIA_PALETA="dracula"\n' >> "$FAM"
fam_amb() { usar_amb env MEOW_CONF="$FAM" MEOW_PACKS="$PACKS" MEOW_ESTADO="$T/estado-familia" "$@"; }
etapa_apps_bb() {
  fam_amb bash -c 'set -a; . "$MEOW_CONF"; set +a
    APPS_ATIVOS="bat,btop" "$MEOW_RAIZ/scripts/aplicar_apps.sh" aplicar' 2>&1
}
if ! command -v bat >/dev/null 2>&1 && ! command -v batcat >/dev/null 2>&1 \
   && ! command -v btop >/dev/null 2>&1; then
  printf 'pulado: nem bat nem btop nesta máquina — a etapa apps não chega a procurar o tema\n'
else
  for alvo in dracula meowsystem "$ID"; do
    troca=""
    [ "$alvo" = dracula ] || troca="$(fam_amb "$RAIZ/bin/meow" pack usar "$alvo" --sem-aplicar 2>&1)"
    saida="$(etapa_apps_bb)"; rc=$?
    if [ "$rc" = 2 ] || grep -q 'falharam' <<< "$saida"; then
      falha "com a chave velha no conf, a etapa apps falhou depois de usar $alvo (rc=$rc)" "$saida"
    elif grep -q 'MEOW_FAMILIA_PALETA' <<< "$troca"; then
      falha "o meow pack usar $alvo ainda lista MEOW_FAMILIA_PALETA, que não é mais lida" "$troca"
    else
      ok "com a chave velha no conf, usar $alvo e a etapa apps termina sem falhar (rc=$rc)"
    fi
  done
  for arq in "$CASA/.config/bat/themes/Catppuccin Mocha.tmTheme" "$CASA/.config/btop/themes/catppuccin_mocha.theme"; do
    case "$arq" in
      */bat/*) command -v bat >/dev/null 2>&1 || command -v batcat >/dev/null 2>&1 || continue ;;
      *) command -v btop >/dev/null 2>&1 || continue ;;
    esac
    [ -f "$arq" ] && ok "a volta instalou $(basename "$arq"), e não o da família que a chave dizia" \
      || falha "a volta ao Catppuccin não instalou $(basename "$arq")" "$(ls -R "$CASA/.config" 2>&1 | head -20)"
  done
  grep -q "não tem tema vendorizado" <<< "$saida" \
    && ok "o pack de mentira, sem tema de bat e btop, é pendência dita, e não erro" \
    || falha "o pack de mentira não disse que o flavor dele não tem tema de bat e btop" "$saida"
fi

saida="$(env MEOW_RAIZ="$RAIZ" MEOW_PACK_DIR="$RAIZ/packs/dracula" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
esquema = servidor.ler_esquema()
vocab = servidor.modulo_pack().vocabulario("dracula")
servidor._com_o_vocabulario_do_pack(esquema, vocab, {"FLAVOR": "dracula"})
item = {i["chave"]: i for i in esquema}
erros = []
fl = item["ICONES_FLAVOR"]
if fl["opcoes"] != ["dracula", "alucard"] or any("Catppuccin" in r for r in fl["rotulos"].values()):
    erros.append("variante dos ícones de arquivo: %r %r" % (fl["opcoes"], fl.get("rotulos")))
if item["ICONES_DRACULA"]["titulo"] != "Ícones do pack nos aplicativos" \
        or "«Dracula»" not in item["ICONES_DRACULA"]["frase"]:
    erros.append("o ajuste dos ícones de aplicativo ainda nomeia um pack no rótulo")
molde = item["ICONES_PASTAS"]["molde_pastas"]
rotulos = [o["rotulo"] for o in molde["variantes"] + molde["cores"]]
for palavra in ("Mocha", "Frappé", "Latte", "${FLAVOR}", "${ACCENT}", "cat-"):
    if any(palavra in r for r in rotulos) or palavra in item["ICONES_PASTAS"]["frase"]:
        erros.append("as pastas ainda mostram %r" % palavra)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "com o Dracula no ar, a aba Ícones oferece o vocabulário dele, e não o do Catppuccin" \
  || falha "a aba Ícones ainda fala Catppuccin com o Dracula no ar" "$saida"

viaja() { amb env XDG_DATA_HOME="$T/xdg" MEOW_ESTADO="$T/estado" "$@" </dev/null; }
somas() { ( cd "$1" && find . -type f -printf '%P\n' | LC_ALL=C sort | xargs -d '\n' sha256sum ); }
NOVO="$ID-viaja"
DA_PESSOA="$T/xdg/meowsystem/packs"
conf_antes="$(sha256sum < "$T/meow.conf")"

saida="$(viaja "$RAIZ/bin/meow" pack novo "$NOVO" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -f "$PACKS/$NOVO/pack.json" ]; then
  falha "meow pack novo não criou o pack (rc=$rc)" "$saida"
else
  ok "meow pack novo cria o pack a partir do que está no ar"
  cmp -s "$PACKS/$NOVO/paleta.json" "$PACK_DIR/paleta.json" \
    && ok "a paleta do pack novo é a que está no ar, byte a byte" \
    || falha "a paleta do pack novo não é a do pack no ar"
  achado="$(python3 - "$PACKS/$NOVO/pack.json" "$ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
def andar(n, t=""):
    if isinstance(n, dict):
        for k, v in n.items():
            yield from andar(v, f"{t}.{k}")
    elif isinstance(n, list):
        for i, v in enumerate(n):
            yield from andar(v, f"{t}[{i}]")
    elif isinstance(n, str) and n.startswith(("/", "~")):
        yield f"{t} = {n}"
erros = list(andar(p))
if p.get("heranca") != sys.argv[2]:
    erros.append(f"heranca = {p.get('heranca')!r}, e o pack no ar é {sys.argv[2]!r}")
print("\n".join(erros))
PY
)"
  [ -z "$achado" ] \
    && ok "o resto vem do pack no ar pela herança, por id, sem caminho absoluto" \
    || falha "o pack.json novo aponta para a máquina, ou não herda do pack no ar:" "$achado"
fi
saida="$(viaja "$RAIZ/bin/meow" pack novo "$NOVO" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"já existe"* ]] \
  && ok "o novo não escreve por cima de um pack que já existe (rc=$rc)" \
  || falha "o novo aceitou um id que já existe (rc=$rc)" "$saida"

somas "$PACKS/$NOVO" > "$T/saiu.sha"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$NOVO" "$T/$NOVO.meowpack" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ -s "$T/$NOVO.meowpack" ] \
  && ok "meow pack exportar escreve o .meowpack" \
  || falha "o exportar falhou (rc=$rc)" "$saida"
rm -rf "${PACKS:?}/$NOVO"
importou="$(viaja "$RAIZ/bin/meow" pack importar "$T/$NOVO.meowpack" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -d "$DA_PESSOA/$NOVO" ]; then
  falha "o importar não instalou o pack exportado (rc=$rc)" "$importou"
else
  ok "meow pack importar instala na raiz da pessoa"
  saida="$(viaja "$RAIZ/bin/meow" pack validar "$NOVO" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack importado valida (rc=0)" \
    || falha "o pack importado não valida (rc=$rc)" "$saida"
  chegou="$(somas "$DA_PESSOA/$NOVO")"
  [ "$chegou" = "$(cat "$T/saiu.sha")" ] \
    && ok "cada arquivo chegou com o sha256 com que saiu ($(wc -l < "$T/saiu.sha") arquivos)" \
    || falha "o que chegou não é o que saiu" "$(diff <(printf '%s\n' "$chegou") "$T/saiu.sha")"
fi
[ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] && [[ "$importou" == *"nada foi aplicado"* ]] \
  && ok "importar não aplica: o meow.conf não mudou, e a saída diz isso" \
  || falha "o importar mexeu no meow.conf, ou não disse que não aplicou" "$importou"
rm -rf "${DA_PESSOA:?}/$NOVO"

cat > "$T/forja.py" <<'PY'
import hashlib, io, subprocess, sys, tarfile
origem, saida, modo, *resto = sys.argv[1:]
bruto = subprocess.run(["zstd", "-d", "-c", "-q", origem], capture_output=True, check=True).stdout
velho = tarfile.open(fileobj=io.BytesIO(bruto))
arquivos = {m.name: velho.extractfile(m).read() for m in velho if m.isfile()}
ident = next(n.split("/")[0] for n in arquivos if "/" in n)
links = []
if modo == "extra":      # um arquivo a mais, e o MANIFESTO certinho
    rel, dado = resto[0], resto[1].encode().decode("unicode_escape").encode()
    arquivos[f"{ident}/{rel}"] = dado
    arquivos["MANIFESTO"] += f"{hashlib.sha256(dado).hexdigest()}  {rel}\n".encode()
elif modo == "troca":    # o conteúdo muda, o MANIFESTO não
    arquivos[f"{ident}/{resto[0]}"] = resto[1].encode()
elif modo == "fuga":
    arquivos["../fora.txt"] = b"fora"
elif modo == "link":
    links.append(resto[0])
buf = io.BytesIO()
with tarfile.open(fileobj=buf, mode="w") as tar:
    for nome, dado in arquivos.items():
        info = tarfile.TarInfo(nome)
        info.size, info.mode = len(dado), 0o755   # o tar pede execução; ninguém dá
        tar.addfile(info, io.BytesIO(dado))
    for rel in links:
        info = tarfile.TarInfo(f"{ident}/{rel}")
        info.type, info.linkname = tarfile.SYMTYPE, "/etc/passwd"
        tar.addfile(info)
comprimido = subprocess.run(["zstd", "-q", "-c"], input=buf.getvalue(), capture_output=True, check=True)
open(saida, "wb").write(comprimido.stdout)
PY
printf 'isto não e zstd\n' > "$T/texto.meowpack"
while IFS='|' read -r modo rel dado espera nome; do
  if [ "$modo" = "texto" ]; then
    forjado="$T/texto.meowpack"
  else
    forjado="$T/forjado.meowpack"
    python3 "$T/forja.py" "$T/$NOVO.meowpack" "$forjado" "$modo" "$rel" "$dado" || exit 2
  fi
  saida="$(viaja "$RAIZ/bin/meow" pack importar "$forjado" 2>&1)"; rc=$?
  restos="$(ls -A "$DA_PESSOA" 2>/dev/null)"
  if [ "$rc" != "0" ] && [[ "$saida" == *"$espera"* ]] && [ -z "$restos" ]; then
    ok "recusa $nome (rc=$rc), e nada foi escrito"
  else
    falha "não recusou $nome, não disse qual arquivo, ou deixou rastro (rc=$rc)" "$saida
restos: $restos"
  fi
done <<CASOS
extra|ganchos.sh|#!/bin/sh\necho oi|$NOVO/ganchos.sh: é script de shell|o .sh dentro do tarball, dizendo qual arquivo
extra|icones/leia.txt|#!/usr/bin/env python3|$NOVO/icones/leia.txt: começa com #!|o script com outro nome, pelo #!
troca|pack.json|{}|sha256 não confere|o arquivo que mudou depois de exportado
fuga|||sai do pack|a entrada que sai do diretório do pack
link|icones/senha.svg||não é arquivo comum|o link simbólico
texto|||não é um .meowpack|o arquivo que não é zstd
CASOS
python3 "$T/forja.py" "$T/$NOVO.meowpack" "$T/forjado.meowpack" extra nota.md "oi" || exit 2
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/forjado.meowpack" 2>&1)"; rc=$?
execs="$(find "$DA_PESSOA/$NOVO" -type f -perm /111 2>/dev/null)"
[ "$rc" = "0" ] && [ -f "$DA_PESSOA/$NOVO/nota.md" ] && [ -z "$execs" ] \
  && ok "o bit de execução do tar não chega ao disco — tudo nasce 0644" \
  || falha "o importado ganhou bit de execução, ou não foi importado (rc=$rc)" "$saida
$execs"
rm -rf "${DA_PESSOA:?}/$NOVO"

LIC="$ID-licenca"
viaja "$RAIZ/bin/meow" pack novo "$LIC" >/dev/null 2>&1 || falha "o novo não criou $LIC"
exporta_recusa() {
  rm -f "$T/lic.meowpack"
  saida="$(viaja "$RAIZ/bin/meow" pack exportar "$LIC" "$T/lic.meowpack" 2>&1)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$1"* ]] && [ ! -e "$T/lic.meowpack" ]; then
    ok "o exportar recusa $2 (rc=$rc), e não escreve o arquivo"
  else
    falha "o exportar não recusou $2, ou não disse por quê (rc=$rc)" "$saida"
  fi
}
printf '| arquivo | lido de | licença | sha256 |\n|---|---|---|---|\n| `logo.svg` | `~/x/logo.svg` |  | `%064d` |\n' 0 \
  > "$PACKS/$LIC/PROCEDENCIA.md"
exporta_recusa "logo.svg não diz a licença" "a arte de terceiro sem licença no PROCEDENCIA.md"
rm -f "$PACKS/$LIC/PROCEDENCIA.md"
python3 - "$PACKS/$LIC/pack.json" <<'PY' || exit 2
import json, sys
p = json.load(open(sys.argv[1])); p.pop("creditos", None)
json.dump(p, open(sys.argv[1], "w"), indent=2, ensure_ascii=False)
PY
mv "$PACKS/$LIC/CREDITOS.md" "$T/creditos-guardado.md"
exporta_recusa "sem o CREDITOS.md" "o pack sem CREDITOS.md"
mv "$T/creditos-guardado.md" "$PACKS/$LIC/CREDITOS.md"
rm -f "$PACKS/$LIC/logo.svg"
exporta_recusa "vitrine.capa" "o pack que não valida"
rm -rf "${PACKS:?}/$LIC"

saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/com.meowpack" 2>&1)"; rc=$?
lista="$(zstd -d -c -q "$T/com.meowpack" 2>/dev/null | tar -tf - 2>/dev/null)"
[ "$rc" = "0" ] && [[ "$saida" == *"1 imagem(ns)"*"ninguém para perguntar"* ]] \
  && [[ "$lista" == *"$ID/capturas/tela.png"* ]] \
  && ok "o exportar diz quanto pesam as imagens, e sem terminal elas vão junto" \
  || falha "o exportar não disse o tamanho das imagens, ou as deixou de fora (rc=$rc)" "$saida"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/sem.meowpack" --sem-imagens 2>&1)"; rc=$?
lista="$(zstd -d -c -q "$T/sem.meowpack" 2>/dev/null | tar -tf - 2>/dev/null)"
capturas="$(zstd -d -c -q "$T/sem.meowpack" 2>/dev/null | tar -xOf - "$ID/pack.json" 2>/dev/null \
            | python3 -c 'import json,sys; print(json.load(sys.stdin)["vitrine"].get("capturas"))' 2>&1)"
[ "$rc" = "0" ] && [[ "$lista" != *"tela.png"* ]] && [ "$capturas" = "[]" ] \
  && ok "--sem-imagens deixa o PNG de fora, e a vitrine da cópia não o promete" \
  || falha "o --sem-imagens levou a imagem, ou a vitrine ficou prometendo (rc=$rc)" "$saida
capturas: $capturas"

saida="$(viaja "$RAIZ/bin/meow" pack exportar "$ID" "$T/nao-existe/x.meowpack" 2>&1)"; rc=$?
[ "$rc" = "2" ] && [[ "$saida" == *"esse diretório não existe"* ]] \
  && [[ "$saida" != *"Traceback"* ]] && [ ! -e "$T/nao-existe" ] \
  && ok "o exportar para um diretório que não existe diz isso numa linha (rc=$rc)" \
  || falha "o exportar para um diretório que não existe não saiu limpo (rc=$rc)" "$saida"

cat > "$T/contrato.py" <<'PY'
import base64, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
arquivo, destino, dir_id = sys.argv[1:]
ident = os.path.basename(dir_id)
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
h._baixar = lambda corpo, nome, tipo: (200, {"arquivo": nome, "cabeca": corpo[:4]})
erros = []
pedido = {"nome": os.path.basename(arquivo),
          "conteudo": base64.b64encode(open(arquivo, "rb").read()).decode()}

st, r = h._api_pack_importar(dict(pedido))
if not (st == 200 and r.get("precisa_confirmar") is True and isinstance(r.get("resumo"), str)
        and r.get("titulo") and len(next(iter((r.get("pack") or {}).get("paleta", {}).values()), [])) == 26):
    erros.append(f"o ensaio do importar não pediu confirmação com resumo e paleta: {st} {r}")
if os.path.exists(destino):
    erros.append("o ensaio do importar escreveu o pack")
st, r = h._api_pack_importar(dict(pedido, confirmar=True))
if os.path.exists(destino) or r.get("instalado"):
    erros.append("`confirmar`, a palavra que a página não manda, instalou o pack")
st, r = h._api_pack_importar(dict(pedido, confirmado=True))
if not (st == 200 and r.get("instalado") is True and r.get("frase") and os.path.isdir(destino)):
    erros.append(f"com `confirmado: true` o importar não instalou: {st} {r}")

st, r = h._api_pack_exportar({"id": [ident], "medir": ["1"]})
if not (st == 200 and r.get("imagens") == 1 and isinstance(r.get("tamanho_sem_imagens"), str)):
    erros.append(f"o medir não disse as imagens e o tamanho: {st} {r}")
st, r = h._api_pack_exportar({"id": [ident], "imagens": ["nao"]})
if not (st == 200 and r.get("cabeca") == b"\x28\xb5\x2f\xfd"):
    erros.append(f"o exportar não devolveu o .meowpack: {st} {r}")
creditos = os.path.join(dir_id, "CREDITOS.md")
os.rename(creditos, creditos + ".fora")
try:
    for consulta in ({"id": [ident], "medir": ["1"]}, {"id": [ident]}):
        st, r = h._api_pack_exportar(consulta)
        if not (st == 400 and "CREDITOS.md" in r.get("erro", "")):
            erros.append(f"o pack que o exportar recusa não voltou como erro ({consulta}): {st} {r}")
finally:
    os.rename(creditos + ".fora", creditos)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja python3 "$T/contrato.py" "$T/$NOVO.meowpack" "$DA_PESSOA/$NOVO" "$PACKS/$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "as rotas falam o contrato dos botões: ensaio, confirmado, medir, e a recusa como erro" \
  || falha "as rotas do .meowpack não falam o contrato da página" "$saida"
rm -rf "${DA_PESSOA:?}/$NOVO"

corpo="$(sed -n '/^async function importarPack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
exporta="$(sed -n '/^async function exportarPack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
packs="$(sed -n '/^function passoMandar(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
faltam=""
for palavra in "confirmado: true" "r.precisa_confirmar" "!r.instalado"; do
  [[ "$corpo" == *"$palavra"* ]] || faltam+=" importarPack:'$palavra'"
done
for palavra in '"&medir=1"' '"&imagens=nao"' "resposta.ok" "perguntar("; do
  [[ "$exporta" == *"$palavra"* ]] || faltam+=" exportarPack:'$palavra'"
done
[[ "$packs" == *"exportarPack(pack.id)"* && "$packs" != *'href: `/api/pack-exportar'* ]] \
  || faltam+=" passoMandar: o exportar voltou a ser um link"
[ -z "$faltam" ] \
  && ok "a página manda confirmado, desenha o pack, só diz 'entrou' com instalado, e pergunta antes de baixar" \
  || falha "a página deixou de falar o contrato das rotas:$faltam"

mexer_pack() {
  python3 - "$1" "$2" <<'PY' || exit 2
import json, os, sys
alvo = os.path.join(sys.argv[1], "pack.json")
p = json.load(open(alvo))
def fundir(a, b):
    for k, v in b.items():
        if v is None:
            a.pop(k, None)
        elif isinstance(v, dict) and isinstance(a.get(k), dict):
            fundir(a[k], v)
        else:
            a[k] = v
fundir(p, json.loads(sys.argv[2]))
json.dump(p, open(alvo, "w"), indent=2, ensure_ascii=False)
PY
}
TEMA="$PACK_DIR/cursores/$ID-roxo"
mkdir -p "$TEMA/cursors" "$PACK_DIR/fontes" "$PACK_DIR/icones/pastas" \
         "$PACK_DIR/icones/mimetypes" "$PACK_DIR/icones/autorais"
printf 'Xcur de mentira' > "$TEMA/cursors/default"
ln -sf default "$TEMA/cursors/left_ptr"
printf '[Icon Theme]\nName=%s-roxo\n' "$ID" > "$TEMA/index.theme"
printf '\x00\x01\x00\x00fonte de mentira' > "$PACK_DIR/fontes/Mentira-Regular.ttf"
printf '{}\n' > "$PACK_DIR/cosmic-map.json"
mexer_pack "$PACK_DIR" '{
  "cosmic": {"mapa": "cosmic-map.json"},
  "icones": {"pastas": {"desenhos": "icones/pastas/"},
             "mimetypes": {"desenhos": "icones/mimetypes/"},
             "autorais": {"desenhos": "icones/autorais/"}},
  "origens": {"cursores": {"proprio": "cursores/'"$ID"'-roxo"},
              "wallpapers": {"tipo": "github-arvore", "repo_do_conf": "WALLPAPER_SEMENTE_REPO"}},
  "apps": {"spotify": {"spicetify_tema": "Mentira", "esquema": "Mentira"}},
  "som": {"fundamental": 440.0},
  "fontes": {"proprio": [{"arquivo": "fontes/Mentira-Regular.ttf"}]}}'

saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o pack com ponteiro e fontes próprios valida" \
  || falha "o pack com ponteiro e fontes próprios foi recusado (rc=$rc)" "$saida"
case "$saida" in
  *origens.wallpapers.tipo*) ok "os campos de wallpapers seguem nomeados como campo morto" ;;
  *) falha "o aviso de campo morto parou de nomear origens.wallpapers — o bloco sem leitor ficou calado" "$saida" ;;
esac

info="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID" 2>&1)"
tabela="$(printf '%s\n' "$info" | sed -n '/^  ----/,$p' | tail -n +2)"
nao_proprias=""
for cat in paleta cosmic.mapa icones.apps icones.pastas icones.mimetypes icones.autorais \
           cursores apps som fontes; do
  printf '%s\n' "$tabela" | grep -qE "^  $cat +PRÓPRIO" || nao_proprias="$nao_proprias $cat"
done
[ -z "$nao_proprias" ] \
  && ok "as dez categorias declaradas e lidas saem PRÓPRIO no info" \
  || falha "categorias declaradas que o info não chama de PRÓPRIO:$nao_proprias" "$tabela"
printf '%s\n' "$tabela" | grep -qE '^  wallpapers +DO MOTOR, ou inexistente +scripts/wallpaper\.sh' \
  && ok "wallpapers declarado sai DO MOTOR, e diz de onde — o info não diz PRÓPRIO sem leitor" \
  || falha "o info voltou a classificar wallpapers pelo bloco que ninguém lê" "$tabela"
n_fixas="$(printf '%s\n' "$tabela" | grep -cE '^  (gerador|prompt|fastfetch) +DO MOTOR — não declarável')"
n_linhas="$(printf '%s\n' "$tabela" | grep -c .)"
[ "$n_fixas" = "3" ] && [ "$n_linhas" = "16" ] \
  && ok "gerador, prompt e fastfetch aparecem como não declaráveis, o mascote é do pack, e a tabela tem as 16 linhas" \
  || falha "a tabela do info não tem as 16 linhas, ou as 3 fixas no motor (linhas=$n_linhas, fixas=$n_fixas)" "$tabela"
case "$tabela" in
  *"CURSOR=\"$ID-roxo\", do pack $ID"*"1 fonte(s), do pack $ID"*)
    ok "o info diz o valor de CURSOR e quantas fontes, e de quem" ;;
  *) falha "a coluna do info não diz o ponteiro e as fontes que a cadeia acha" "$tabela" ;;
esac

saida="$(amb python3 - "$RAIZ" "$ID" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "scripts"))
import pack
TETO = 220
base = os.path.join(sys.argv[1], "packs")
refs = [sys.argv[2]] + sorted(n for n in os.listdir(base)
                              if os.path.isfile(os.path.join(base, n, "pack.json")))
medidas, longos = [], []
for ref in refs:
    with open(os.path.join(pack.achar(ref), "pack.json"), encoding="utf-8") as fh:
        linha = pack.resumo_de_origem(json.load(fh))
    medidas.append("%s %d" % (ref, len(linha)))
    if len(linha) > TETO:
        longos.append("%s: %d caracteres — %s" % (ref, len(linha), linha))
print("\n".join(longos) if longos else ", ".join(medidas))
sys.exit(1 if longos else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a linha de origem do cartão cabe nos 220 da P7 ($saida)" \
  || falha "a linha de origem do cartão passou dos 220 caracteres da P7" "$saida"

saida="$(amb python3 "$RAIZ/scripts/pack.py" ponteiro "$ID" 2>&1)"
[ "$saida" = "pack=$ID
dir=$TEMA
valor=$ID-roxo" ] \
  && ok "o verbo 'ponteiro' devolve o pack, o tema e o valor da chave" \
  || falha "o verbo 'ponteiro' não respondeu o que o cursor.sh lê" "$saida"
saida="$(amb python3 "$RAIZ/scripts/pack.py" tipografia "$ID" 2>&1)"
[ "$saida" = "$(printf '%s\tMentira-Regular.ttf\t%s\t-' "$ID" "$PACK_DIR/fontes/Mentira-Regular.ttf")" ] \
  && ok "o verbo 'tipografia' devolve a fonte, de onde ela sai e de quem" \
  || falha "o verbo 'tipografia' não respondeu o que o instalar_fontes.sh lê" "$saida"

FILHO="$PACKS/$ID-filho"; mkdir -p "$FILHO"
cp "$PACK_DIR/paleta.json" "$PACK_DIR/logo.svg" "$FILHO/"
printf '{"formato": 1, "id": "%s-filho", "nome": "Filho", "heranca": "%s",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "%s"}, "vitrine": {"capa": "logo.svg"}}\n' \
  "$ID" "$ID" "$ID" > "$FILHO/pack.json"
tabela="$(amb python3 "$RAIZ/scripts/pack.py" info "$ID-filho" 2>&1 | sed -n '/^  ----/,$p')"
if printf '%s\n' "$tabela" | grep -qE "^  cursores +HERDADO de $ID +CURSOR=\"$ID-roxo\", do pack $ID" \
   && printf '%s\n' "$tabela" | grep -qE "^  fontes +HERDADO de $ID +1 fonte\(s\), do pack $ID" \
   && printf '%s\n' "$tabela" | grep -qE "^  som +DO MOTOR"; then
  ok "o filho herda ponteiro e fontes do pai, e o som dele é o do motor"
else
  falha "a herança de ponteiro, fontes ou som não saiu como o código resolve" "$tabela"
fi

recusa() {
  local R="$T/recusa"
  saida="$(env MEOW_PACKS="$R" MEOW_RAIZ="$RAIZ" python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
  if [ "$rc" != "0" ] && [[ "$saida" == *"$2"* ]]; then
    ok "recusa $1 (rc=$rc)"
  else
    falha "não recusou $1, ou não disse por quê (rc=$rc)" "$saida"
  fi
}
copia() { rm -rf "$T/recusa"; mkdir -p "$T/recusa"; cp -a "$PACK_DIR" "$T/recusa/$ID"; C="$T/recusa/$ID"; }
SHA_A="$(printf 'a%.0s' $(seq 64))"
copia; ln -s /etc/hostname "$C/cursores/$ID-roxo/cursors/fora"
recusa "o ponteiro com link para fora do tema" "aponta para fora do tema"
copia; ln -s hand2 "$C/cursores/$ID-roxo/cursors/hand"
recusa "o ponteiro com link que não leva a nada" "não leva a arquivo nenhum"
copia; rm -f "$C/cursores/$ID-roxo/cursors/default" "$C/cursores/$ID-roxo/cursors/left_ptr"
recusa "o ponteiro sem default nem left_ptr" "não tem default nem left_ptr"
copia; mv "$C/cursores/$ID-roxo" "$C/cursores/$ID roxo"; mexer_pack "$C" "{\"origens\": {\"cursores\": {\"proprio\": \"cursores/$ID roxo\"}}}"
recusa "o ponteiro com espaço no nome" "o tema chama-se"
copia; mexer_pack "$C" '{"origens": {"cursores": {"herda": "catppuccin"}}}'
recusa "proprio e herda juntos no ponteiro" "'proprio' e 'herda' ao mesmo tempo"
copia; mexer_pack "$C" '{"origens": {"cursores": {"proprio": "cursores/nao-existe"}}}'
recusa "o ponteiro declarado e ausente" "NÃO existe no pack"
copia; printf '\x89PNG\r\n' > "$C/fontes/Mentira-Regular.ttf"
recusa "a fonte que não é fonte por dentro" "não é TrueType nem OpenType"
copia; mexer_pack "$C" "{\"fontes\": {\"proprio\": [{\"nome\": \"X.ttf\", \"url\": \"http://exemplo.org/X.ttf\", \"sha256\": \"$SHA_A\"}]}}"
recusa "a fonte em http" "só https"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"nome": "X.ttf", "url": "https://exemplo.org/X.ttf"}]}}'
recusa "a fonte de fora sem sha256" "declara as três"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"arquivo": "fontes/Mentira-Regular.ttf"}, {"arquivo": "fontes/Mentira-Regular.ttf"}]}}'
recusa "duas fontes com o mesmo nome" "um nome, um arquivo no disco"
copia; mexer_pack "$C" '{"fontes": {"proprio": [{"arquivo": "../fora.ttf"}]}}'
recusa "a fonte fora do pack" "sai de dentro do pack"
copia; mexer_pack "$C" '{"fontes": {"proprio": null, "herda": "pack-que-nao-existe"}}'
recusa "as fontes herdadas de um pack que não existe" "pack-que-nao-existe"
rm -rf "$T/recusa"

H="$T/casa-p12"; mkdir -p "$H"
printf 'PACK="%s-filho"\nCURSOR="%s-roxo"\n' "$ID" "$ID" > "$T/meow-p12.conf"
painel_cursor() {
  env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    MEOW_CONF="$T/meow-p12.conf" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
t, p = servidor._temas_de_cursor(), servidor._prev_cursores()
print(len(t), len(p), " ".join(t))
PY
}
script_cursor() {
  env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" NO_COLOR=1 \
    PACK="$ID-filho" CURSOR="$ID-roxo" "$@" bash "$RAIZ/scripts/cursor.sh" "${ACAO:-listar}" 2>&1
}
read -r n_t n_p nomes <<< "$(painel_cursor)"
if [ "$n_t" = "$n_p" ] && [[ " $nomes " == *" $ID-roxo "* ]] && [[ "$(script_cursor)" == *"$ID-roxo"* ]]; then
  ok "o ponteiro do pack está nas duas listas antes de instalar, com uma prévia por opção ($n_p de $n_t)"
else
  falha "o painel e o script não oferecem o ponteiro do pack juntos" "painel: $n_t $n_p $nomes
script: $(script_cursor)"
fi
saida="$(ACAO=aplicar script_cursor MEOW_DRY_RUN=1)"
if [[ "$saida" == *"vem do pack $ID"*"instalaria o ponteiro"* ]] && [[ "$saida" != *baixaria* ]] \
   && [ -z "$(find "$H" -mindepth 1 2>/dev/null)" ]; then
  ok "o aplicar em seco instala do pack, sem rede, e não escreve nada"
else
  falha "o aplicar em seco não veio do pack, baixaria da rede, ou escreveu" "$saida
$(find "$H" -mindepth 1 2>/dev/null | head -5)"
fi
mkdir -p "$H/.local/share/icons/$ID-roxo"
read -r n_t n_p nomes <<< "$(painel_cursor)"
if [ "$n_t" = "$n_p" ] && [[ " $nomes " != *" $ID-roxo "* ]] && [[ "$(script_cursor)" != *"$ID-roxo"* ]]; then
  ok "com o nome sequestrado por um diretório exato, o ponteiro do pack sai das duas listas"
else
  falha "o nome sequestrado deixou o ponteiro do pack numa das listas" "painel: $n_t $n_p $nomes
script: $(script_cursor)"
fi
rm -rf "$H/.local"

mkdir -p "$T/bin"
cat > "$T/bin/gsettings" <<'G'
#!/bin/sh
f="$HOME/.gsettings-de-mentira-$3"   # uma por chave: a do tamanho não é a do tema
case "$1" in
  get) if [ -f "$f" ]; then printf "'%s'\n" "$(cat "$f")"; else printf "'Adwaita'\n"; fi ;;
  set) printf '%s' "$4" > "$f" ;;
esac
G
chmod +x "$T/bin/gsettings"
ln -s . "$TEMA/cursors/aqui"
ACAO=aplicar PATH="$T/bin:$PATH" script_cursor >/dev/null
saida="$(ACAO=aplicar PATH="$T/bin:$PATH" script_cursor)"; rc_a=$?
saida_c="$(ACAO=conferir PATH="$T/bin:$PATH" script_cursor)"; rc_c=$?
if [ "$rc_a" = "0" ] && [[ "$saida" == *"já está instalado e idêntico"* ]] && [ "$rc_c" = "0" ]; then
  ok "o ponteiro do pack instalado converge: a segunda passagem diz idêntico, e o conferir concorda"
else
  falha "o ponteiro do pack não convergiu (aplicar rc=$rc_a, conferir rc=$rc_c)" "$saida
$saida_c"
fi
rm -f "$TEMA/cursors/aqui"; rm -rf "$H"; mkdir -p "$H"

ln -s hand2 "$TEMA/cursors/hand"
saida="$(ACAO=aplicar script_cursor MEOW_DRY_RUN=1)"
if [[ "$saida" == *"não leva a arquivo nenhum"*"o ponteiro do pack foi ignorado"* ]] \
   && [[ "$saida" != *"vem do pack"* ]]; then
  ok "o ponteiro do pack com link que não leva a nada é ignorado, e o cursor.sh diz por quê"
else
  falha "o cursor.sh usou o ponteiro recusado, ou calou o motivo" "$saida"
fi
rm -f "$TEMA/cursors/hand"

saida="$(env -i PATH="$PATH" HOME="$H" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" NO_COLOR=1 \
  PACK="$ID-filho" MEOW_DRY_RUN=1 bash "$RAIZ/scripts/instalar_fontes.sh" 2>&1)"; rc=$?
if [ "$rc" = "3" ]; then
  printf 'pulado: o instalar_fontes.sh não tem as ferramentas dele nesta máquina\n'
elif [[ "$saida" == *"instalaria a fonte Mentira-Regular.ttf do pack $ID"* ]]; then
  ok "o instalar_fontes.sh lê as fontes que o pack herda, e diz de quem"
else
  falha "o instalar_fontes.sh não leu as fontes do pack (rc=$rc)" "$saida"
fi

CSV_ID="$ID-csv"; CSV_DIR="$PACKS/$CSV_ID"
python3 - "$RAIZ" "$T/cores.csv" "$T/duas.csv" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1] + "/packs/dracula/paleta.json", encoding="utf-8"))
with open(sys.argv[2], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n")
    for s in d["ordem_canonica"]:
        fh.write(f"{s},tinta,{d['flavors']['dracula'][s]}\n")
with open(sys.argv[3], "w", encoding="utf-8") as fh:
    fh.write("slot,flavor,hex\n")
    for f, nome in (("dracula", "tinta"), ("alucard", "papel")):
        for s in d["ordem_canonica"]:
            fh.write(f"{s},{nome},{d['flavors'][f][s]}\n")
PY
[ "$(wc -l < "$T/cores.csv")" = "27" ] || falha "o CSV de teste não tem cabeçalho + 26 linhas"

amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/cores.csv" > "$T/csv-paleta.json" 2> "$T/csv.err"; rc=$?
aviso_csv="$(cat "$T/csv.err")"
[ "$rc" = "0" ] \
  && ok "o CSV de 26 linhas vira paleta.json (rc=0)" \
  || falha "o de-csv recusou um CSV certo (rc=$rc)" "$aviso_csv"
[[ "$aviso_csv" == *"aviso"*"régua de contraste"*"tinta: blue/base"* ]] \
  && ok "a régua de contraste avisa com a lista do que reprovou, sem bloquear" \
  || falha "a régua de contraste não disse o que reprovou" "$aviso_csv"

saida="$(amb python3 - "$RAIZ" "$T/csv-paleta.json" <<'PY' 2>&1
import json, sys
d = json.load(open(sys.argv[1] + "/packs/dracula/paleta.json", encoding="utf-8"))
o = json.load(open(sys.argv[2], encoding="utf-8"))
erros = []
if o.get("claros") != ["tintaclaro"] or o.get("derivados") != {"tintaclaro": "tinta"}:
    erros.append("claros/derivados: %r %r" % (o.get("claros"), o.get("derivados")))
else:
    dif = [s for s in d["ordem_canonica"]
           if o["flavors"]["tintaclaro"][s].upper() != d["flavors"]["alucard"][s].upper()]
    if dif:
        erros.append("o claro derivado difere do alucard em %d slot(s): %s" % (len(dif), ", ".join(dif)))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o claro derivado é o alucard, 26 de 26 — o método é o do projeto, não um segundo" \
  || falha "a derivação do claro deixou de ser a que gerou o alucard" "$saida"

saida="$(amb python3 "$RAIZ/scripts/derivar_claro.py" 2>/dev/null \
         | python3 -c 'import json, sys
porta = json.load(sys.stdin)
csv = json.load(open(sys.argv[1], encoding="utf-8"))["flavors"]["tintaclaro"]
dif = [s for s in csv if porta.get(s) != csv[s]] + sorted(set(porta) - set(csv))
print(", ".join(dif))
sys.exit(1 if dif else 0)' "$T/csv-paleta.json" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o derivar_claro.py e o de-csv dão o mesmo claro, 26 de 26 — uma régua, duas portas" \
  || falha "o derivar_claro.py e o de-csv divergem no claro (rc=$rc)" "$saida"

novo_csv="$(amb env MEOW_ESTADO="$T/estado" "$RAIZ/bin/meow" pack novo "$CSV_ID" --de-csv "$T/cores.csv" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -f "$CSV_DIR/pack.json" ]; then
  falha "meow pack novo --de-csv não criou o pack (rc=$rc)" "$novo_csv"
else
  ok "meow pack novo --de-csv cria o pack a partir do CSV"
  cmp -s "$T/csv-paleta.json" "$CSV_DIR/paleta.json" \
    && ok "o paleta.json do novo é o que o de-csv imprime, byte a byte — uma tradução só" \
    || falha "o novo --de-csv escreveu uma paleta diferente da do de-csv" \
             "$(diff "$T/csv-paleta.json" "$CSV_DIR/paleta.json" | head -8)"
  [[ "$novo_csv" == *"aviso"*"régua de contraste"*"tinta: blue/base"* ]] \
    && ok "o novo --de-csv roda a régua de contraste e avisa, sem bloquear" \
    || falha "o novo --de-csv não disse o que reprovou na régua" "$novo_csv"
fi
achado="$(python3 - "$CSV_DIR/pack.json" "$(basename "$padrao")" "$ID" "$CSV_ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
padrao, no_ar, dado = sys.argv[2], sys.argv[3], sys.argv[4]
erros = []
esperado = " ".join(parte.capitalize() for parte in dado.split("-"))
if p.get("nome") != esperado:
    erros.append(f"nome = {p.get('nome')!r}: o id {dado!r} foi dado, e o nome é {esperado!r}")
if p.get("heranca") != padrao:
    erros.append(f"heranca = {p.get('heranca')!r}: é o pack padrão ({padrao!r}), e não o no ar ({no_ar!r})")
if (p.get("paleta") or {}).get("flavor_padrao") != "tinta":
    erros.append(f"flavor_padrao = {(p.get('paleta') or {}).get('flavor_padrao')!r}; o primeiro do CSV é 'tinta'")
if "som" in p:
    erros.append("o timbre do ar entrou num pack de CSV")
if ((p.get("icones") or {}).get("autorais") or {}).get("gerar") is not True:
    erros.append("sem icones.autorais.gerar, os autorais ficam nos flavors do pai")
print("\n".join(erros))
PY
)"
[ -z "$achado" ] \
  && ok "o pack de CSV herda do padrão, o flavor_padrao é o primeiro do CSV, e o nome sai do id dado" \
  || falha "o pack.json do novo --de-csv não é o que a sprint pede" "$achado"
saida="$(amb "$RAIZ/bin/meow" pack validar "$CSV_ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" != *"NENHUM código lê"* ]] \
  && ok "o pack feito de CSV valida (rc=0), sem campo que ninguém lê" \
  || falha "o pack feito de CSV não valida, ou declara campo morto (rc=$rc)" "$saida"
saida="$(amb "$RAIZ/bin/meow" pack info "$CSV_ID" 2>&1)"
[[ "$(grep claro <<< "$saida")" == *"claro: derivado do escuro pelo método do Latte (não é próprio)"* ]] \
  && ok "o info diz que o claro é derivado, e não próprio" \
  || falha "o info não diz que o claro foi derivado" "$saida"
linha_autorais="$(grep '^  icones.autorais ' <<< "$saida")"
[[ "$linha_autorais" == *"PRÓPRIO"*"18 desenho(s), 2 flavor(s)"* ]] \
  && ok "os ícones autorais nascem próprios, nas cores do CSV: 18 desenhos, 2 flavors" \
  || falha "os ícones autorais do pack de CSV não são dele" "$linha_autorais"
sed 's/,tinta,/,meu-tema,/' "$T/cores.csv" > "$T/hifen.csv"
saida="$(amb "$RAIZ/bin/meow" pack novo "$CSV_ID-hifen" --de-csv "$T/hifen.csv" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"o CSV não virou paleta"*"flavor 'meu-tema' — uma palavra só"* ]] \
  && [ ! -e "$PACKS/$CSV_ID-hifen" ] \
  && ok "o flavor com hífen no CSV é recusado pelo novo, com a linha, e nada é escrito" \
  || falha "o novo --de-csv aceitou o flavor com hífen, ou deixou rastro (rc=$rc)" "$saida"
saida="$(amb "$RAIZ/bin/meow" pack novo "$CSV_ID-sem" --de-csv 2>&1)"; rc=$?
[ "$rc" = "2" ] && [[ "$saida" == *"pede o arquivo"* ]] \
  && ok "o --de-csv sem arquivo é erro de uso (rc=2)" \
  || falha "o --de-csv sem arquivo não foi erro de uso (rc=$rc)" "$saida"

saida="$(amb python3 - "$RAIZ" "$CSV_ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
p = [p for p in servidor.packs_com_vitrine() if p["id"] == sys.argv[2]][0]
erros = []
if "herdado de" not in p.get("origem", ""):
    erros.append("o cartão não diz o que veio por herança: %r" % p.get("origem"))
if p.get("claros_derivados") != [{"flavor": "tintaclaro", "de": "tinta"}]:
    erros.append("o cartão não diz que o claro é derivado: %r" % p.get("claros_derivados"))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o /api/packs leva a herança e o claro derivado para o cartão" \
  || falha "o cartão do pack de CSV esconde de onde vieram as coisas" "$saida"
cp "$CSV_DIR/paleta.json" "$T/paleta-boa.json"
python3 - "$CSV_DIR/paleta.json" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["derivados"] = {"tintaclaro": "nenhum"}
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$CSV_ID" 2>&1)"; rc=$?
amb python3 "$RAIZ/scripts/pack.py" caminho "$CSV_ID" id >/dev/null 2>&1; rc_motor=$?
info="$(amb python3 "$RAIZ/scripts/pack.py" info "$CSV_ID" 2>&1)"
[ "$rc" = "1" ] && [[ "$saida" == *"'derivados'"*"tintaclaro"* ]] && [ "$rc_motor" = "0" ] \
  && [[ "$info" != *"derivado do escuro"* ]] \
  && ok "o derivados torto é recusado no validar, sem tirar o pack do motor" \
  || falha "o derivados torto passou, ou tirou o pack do motor (validar=$rc caminho=$rc_motor)" "$saida
$info"
python3 - "$CSV_DIR/paleta.json" "$T/paleta-boa.json" <<'PY' || exit 2
import json, sys
d = json.load(open(sys.argv[2], encoding="utf-8"))
d["claros"] = None
json.dump(d, open(sys.argv[1], "w", encoding="utf-8"), indent=2, ensure_ascii=False)
PY
saida="$(amb python3 - "$RAIZ" "$CSV_ID" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
p = [p for p in servidor.packs_com_vitrine() if p["id"] == sys.argv[2]][0]
print(p.get("claros_derivados"))
sys.exit(0 if p.get("claros_derivados") == [] else 1)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "claros: null não derruba o /api/packs, e o cartão não inventa derivado" \
  || falha "claros: null derrubou o /api/packs (rc=$rc)" "$saida"
cp "$T/paleta-boa.json" "$CSV_DIR/paleta.json"

corpo="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
printf '%s\n' "$corpo" | grep -q 'p.claros_derivados' && printf '%s\n' "$corpo" | grep -q 'dica: derivado ? "Claro derivado"' \
  && ok "o cartão de pack marca a variante clara derivada, com a dica" \
  || falha "o cartão de pack não lê claros_derivados"
cp "$T/cores.csv" "$T/Minha Tinta.csv"
conf_antes="$(sha256sum < "$T/meow.conf")"
importou="$(viaja "$RAIZ/bin/meow" pack importar "$T/Minha Tinta.csv" 2>&1)"; rc=$?
if [ "$rc" != "0" ] || [ ! -d "$DA_PESSOA/minha-tinta" ]; then
  falha "o importar não instalou o .csv (rc=$rc)" "$importou"
else
  ok "meow pack importar aceita um .csv solto, e o id sai do nome do arquivo"
  saida="$(viaja "$RAIZ/bin/meow" pack validar minha-tinta 2>&1)"; rc=$?
  n_autorais="$(find "$DA_PESSOA/minha-tinta/icones/apps" -name '*.svg' | wc -l)"
  mesma="$(python3 -c 'import json, sys
a, b = (json.load(open(x, encoding="utf-8")) for x in sys.argv[1:])
for d in (a, b): d.pop("_comentario", None)
print("sim" if a == b else "nao")' "$T/csv-paleta.json" "$DA_PESSOA/minha-tinta/paleta.json")"
  [ "$rc" = "0" ] && [ "$mesma" = "sim" ] && [ "$n_autorais" = "18" ] \
    && ok "o pack importado do .csv valida, com a paleta e os autorais do novo --de-csv" \
    || falha "o .csv importado não é o pack que o novo --de-csv monta (rc=$rc, $n_autorais autorais)" "$saida"
fi
[ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] && [[ "$importou" == *"nada foi aplicado"* ]] \
  && [[ "$importou" == *"claro derivado    : tintaclaro"* ]] \
  && ok "importar o .csv não aplica, e a saída diz o claro derivado" \
  || falha "o importar do .csv mexeu no meow.conf, ou calou o claro derivado" "$importou"
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/Minha Tinta.csv" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"já existe"*"com outro nome, ele vira outro pack"* ]] \
  && [[ "$saida" == *"meow pack remover minha-tinta"* ]] \
  && ok "o mesmo .csv de novo é recusado, dizendo que o nome do arquivo faz o id e como tirar o de lá" \
  || falha "o .csv importado duas vezes não foi recusado como devia (rc=$rc)" "$saida"

nome_csv="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["nome"])' \
  "$DA_PESSOA/minha-tinta/pack.json" 2>&1)"
cp "$T/cores.csv" "$T/tinta de teste.csv"
nome_minusculo="$(amb python3 - "$RAIZ" "$T/tinta de teste.csv" <<'PY' 2>&1
import json, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "scripts"))
import pack
arquivos, _p, _r = pack.montar_novo(pack.id_do_csv(sys.argv[2]), sys.argv[2])
print(json.loads(arquivos["pack.json"])["nome"])
PY
)"
[ "$nome_csv" = "Minha Tinta" ] && [ "$nome_minusculo" = "Tinta de teste" ] \
  && ok "o nome do pack de CSV sai do arquivo como foi escrito («Minha Tinta», «Tinta de teste»)" \
  || falha "o nome do pack de CSV não é o do arquivo" "Minha Tinta.csv -> $nome_csv; tinta de teste.csv -> $nome_minusculo"

cp "$T/cores.csv" "$T/qa-um.csv"
viaja env MEOW_PACK_NOME="QA Um" "$RAIZ/bin/meow" pack importar "$T/qa-um.csv" >/dev/null 2>&1
nome_digitado="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["nome"])' \
  "$DA_PESSOA/qa-um/pack.json" 2>&1)"
[ "$nome_digitado" = "QA Um" ] \
  && ok "o nome digitado no painel vai para o pack.json do CSV importado" \
  || falha "o nome digitado não chegou ao pack.json (veio «$nome_digitado»)"
rm -rf "${DA_PESSOA:?}/qa-um"

printf 'FLAVOR="tinta"\nACCENT="mauve"\nMODO="escuro"\nPACK="minha-tinta"\n' > "$T/remover.conf"
remover() { viaja env MEOW_CONF="$T/remover.conf" "$RAIZ/bin/meow" pack remover "$@" 2>&1; }
faltam=""
saida="$(remover minha-tinta)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"está no ar"* ]] && [ -d "$DA_PESSOA/minha-tinta" ] \
  || faltam+=" o pack no ar saiu, ou não disse que está no ar (rc=$rc: $saida);"
printf 'FLAVOR="%s"\nACCENT="mauve"\nMODO="escuro"\nPACK="%s"\n' "$ID" "$ID" > "$T/remover.conf"
saida="$(remover dracula)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"vem com o MeowSystem"* ]] \
  || faltam+=" o dracula do projeto não foi recusado como do MeowSystem (rc=$rc: $saida);"
saida="$(remover '../fora')"; rc=$?
[ "$rc" = "1" ] || faltam+=" um id com barra passou (rc=$rc);"
mkdir -p "$DA_PESSOA/filho"
printf '{"formato": 1, "id": "filho", "nome": "Filho", "icones": {"mimetypes": {"herda": "minha-tinta"}}}\n' \
  > "$DA_PESSOA/filho/pack.json"
saida="$(remover minha-tinta)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"Filho herda do Minha Tinta"* ]] \
  || faltam+=" o pack de quem outro herda saiu, ou não disse quem herda (rc=$rc: $saida);"
rm -rf "${DA_PESSOA:?}/filho"
saida="$(viaja env MEOW_CONF="$T/remover.conf" MEOW_DRY_RUN=1 "$RAIZ/bin/meow" pack remover minha-tinta 2>&1)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"removeria"*"nada foi apagado"* ]] && [ -f "$DA_PESSOA/minha-tinta/pack.json" ] \
  || faltam+=" o ensaio apagou, ou não disse o que apagaria (rc=$rc: $saida);"
saida="$(viaja env MEOW_CONF="$T/remover.conf" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
por_id = {p["id"]: p for p in servidor.packs_com_vitrine()}
erros = []
if (por_id.get("minha-tinta") or {}).get("remover") != {"pode": True, "motivo": ""}:
    erros.append("o cartão do importado: %r" % (por_id.get("minha-tinta") or {}).get("remover"))
if (por_id.get("dracula") or {}).get("remover") is not None:
    erros.append("o cartão do dracula do projeto ganhou remover: %r" % por_id["dracula"]["remover"])
if servidor._packs_removiveis() != ["minha-tinta"]:
    erros.append("a cerca do argumento: %r" % servidor._packs_removiveis())
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)" || faltam+=" a tela não pergunta à mesma regra: $saida;"
remover_antes="$(sha256sum < "$T/remover.conf")"
saida="$(remover minha-tinta)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"removido"* ]] && [ ! -e "$DA_PESSOA/minha-tinta" ] \
  && [ -z "$(find "$DA_PESSOA" -maxdepth 1 -name '.saindo-*' 2>/dev/null)" ] \
  && [ "$(sha256sum < "$T/remover.conf")" = "$remover_antes" ] \
  || faltam+=" o remover de verdade não tirou o pack inteiro, ou deixou o oculto (rc=$rc: $saida);"
til="$(env HOME=/casa/de/teste python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import pack
print(pack._til("/casa/de/teste/.local/share/meowsystem/packs/x"), pack._til("/casa/de/testex/y"))' \
  "$RAIZ/scripts" 2>&1)"
[ "$til" = "~/.local/share/meowsystem/packs/x /casa/de/testex/y" ] \
  || faltam+=" a saída do remover não troca a casa por ~ ($til);"
[ -z "$faltam" ] \
  && ok "meow pack remover tira o importado, recusa o do projeto, o no ar e o herdado, e ensaia sem apagar" \
  || falha "o meow pack remover não cumpre a regra:$faltam"
rm -rf "${DA_PESSOA:?}/minha-tinta"

cat > "$T/contrato-csv.py" <<'PY'
import base64, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
arquivo, destino = sys.argv[1:]
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
erros = []
pedido = {"nome": "Minha Tinta.csv",
          "conteudo": base64.b64encode(open(arquivo, "rb").read()).decode()}
st, r = h._api_pack_importar(dict(pedido))
pack = r.get("pack") or {}
if not (st == 200 and r.get("precisa_confirmar") is True and "minha-tinta" in r.get("resumo", "")
        and len(pack.get("paleta", {}).get("tinta", [])) == 26):
    erros.append(f"o ensaio do .csv não pediu confirmação com o pack desenhado: {st} {r}")
if pack.get("derivados") != {"tintaclaro": "tinta"} or not any("blue/base" in l for l in pack.get("regua", [])):
    erros.append(f"o pack do ensaio não traz o claro derivado e a régua: {pack.get('derivados')} {pack.get('regua')}")
if pack.get("icones") != 18 or "herdado de" not in pack.get("ponteiro", ""):
    erros.append(f"o pack do ensaio não diz os autorais próprios e o que é herdado: {pack}")
if os.path.exists(destino):
    erros.append("o ensaio do .csv escreveu o pack")
st, r = h._api_pack_importar(dict(pedido, confirmado=True))
if not (st == 200 and r.get("instalado") is True and os.path.isdir(destino)):
    erros.append(f"com `confirmado: true` o .csv não foi instalado: {st} {r}")
st, r = h._api_pack_importar(dict(pedido, nome="???.csv"))
if not (st == 400 and "nome do arquivo" in r.get("erro", "")):
    erros.append(f"o .csv sem nome que vire id não voltou como erro: {st} {r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja python3 "$T/contrato-csv.py" "$T/cores.csv" "$DA_PESSOA/minha-tinta" 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$(sha256sum < "$T/meow.conf")" = "$conf_antes" ] \
  && ok "a rota do importar aceita o .csv com o contrato da tela, e não aplica" \
  || falha "a rota do importar não fala o contrato para o .csv, ou mexeu no meow.conf" "$saida"
rm -rf "${DA_PESSOA:?}/minha-tinta"
packs_js="$(sed -n '/^function botaoAbrirTema(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
faltam=""
[[ "$packs_js" == *'accept: ".meowpack,.csv"'* ]] || faltam+=" botaoAbrirTema:'accept .csv'"
[ -z "$faltam" ] \
  && ok "a página aceita o .csv no «Abrir um tema»" \
  || falha "a página não fala o .csv:$faltam"

saida="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/duas.csv" 2>/dev/null)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *'"claros": ['*'"papel"'* ]] && [[ "$saida" != *'"derivados"'* ]] \
  && ok "com o claro no CSV, ele é reconhecido pela medida e nada é derivado" \
  || falha "o CSV com claro próprio foi derivado mesmo assim (rc=$rc)" "$saida"

recusa_csv() {
  cat > "$T/ruim.csv"
  local out err rc
  out="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/ruim.csv" 2> "$T/ruim.err")"; rc=$?
  err="$(cat "$T/ruim.err")"
  [ "$rc" = "1" ] && [ -z "$out" ] && [[ "$err" == *"$2"* ]] \
    && [[ "$err" == "  erro o CSV não virou paleta: "* ]] \
    && ok "recusa $1 (rc=1): $2" \
    || falha "não recusou $1 como devia (rc=$rc)" "$err"
}
recusa_csv "o slot desconhecido" "ruim.csv:5: slot desconhecido 'mauv'" < <(sed 's/^mauve,/mauv,/' "$T/cores.csv")
recusa_csv "o slot faltando" "não tem 2 slot(s):
      teal, crust" < <(sed '/^crust,/d; /^teal,/d' "$T/cores.csv")
recusa_csv "o hex sem #" "ruim.csv:16: text = 'F8F8F2' não é #RRGGBB" < <(sed 's/^text,tinta,#/text,tinta,/' "$T/cores.csv")
recusa_csv "o slot repetido" "já veio na linha 25" < <(cat "$T/cores.csv"; printf 'base,tinta,#000000\n')
recusa_csv "o CSV sem cabeçalho" "ruim.csv:1: a primeira linha tem de ser o cabeçalho" < <(tail -n +2 "$T/cores.csv")
recusa_csv "o flavor com espaço" "ruim.csv:2: flavor 'Meu Tema' — uma palavra só" < <(sed 's/,tinta,/,Meu Tema,/' "$T/cores.csv")
recusa_csv "o flavor com \$(…)" "ruim.csv:2: flavor 'x\$(id)' — uma palavra só, em minúsculas" < <(sed 's/,tinta,/,x$(id),/' "$T/cores.csv")
recusa_csv "o flavor com maiúscula" "ruim.csv:2: flavor 'Tinta' — uma palavra só" < <(sed 's/,tinta,/,Tinta,/' "$T/cores.csv")
n="$(grep -c "flavor 'Tinta'" "$T/ruim.err")"
[ "$n" = "1" ] \
  && ok "o flavor recusado sai uma vez, na primeira linha dele" \
  || falha "o flavor recusado saiu $n vez(es), uma por linha" "$(head -6 "$T/ruim.err")"
recusa_csv "o CSV com ';', dizendo qual é o defeito" "este arquivo usa ';'" < <(sed 's/,/;/g' "$T/cores.csv")

sed 's/#\(.*\)$/#\L\1/; s/^text,tinta,.*/text,tinta,#303240/' "$T/cores.csv" > "$T/minusc.csv"
saida="$(amb python3 "$RAIZ/scripts/pack.py" de-csv "$T/minusc.csv" 2> "$T/minusc.err")"; rc=$?
aviso_csv="$(cat "$T/minusc.err")"
n_text="$(grep -c 'tinta: text/base' "$T/minusc.err")"
[ "$rc" = "0" ] && [ "$n_text" = "1" ] && [[ "$aviso_csv" == *"o \`validar\` recusa o pack"* ]] \
  && ok "o text reprovado nas duas réguas sai uma vez só, dizendo que o validar recusa" \
  || falha "o text reprovado saiu $n_text vez(es) no aviso (rc=$rc)" "$aviso_csv"
[ "$rc" = "0" ] && [[ "$saida" == *'"base": "#282A36"'* ]] && ! grep -q '"#[0-9A-F]*[a-f]' <<< "$saida" \
  && ok "o hex minúsculo do CSV sai em maiúsculas, como nas paletas daqui" \
  || falha "o hex do CSV não saiu em maiúsculas" "$(grep -n '"#[0-9A-F]*[a-f]' <<< "$saida" | head -3)"

saida="$(env MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_ESTADO="$T/estado" \
         "$RAIZ/bin/meow" pack de-csv "$T/cores.csv" "$T/destino.json" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"um CSV só"* ]] && [ ! -e "$T/destino.json" ] \
  && ok "meow pack de-csv com dois argumentos recusa, e diz que o destino vai pelo '>'" \
  || falha "meow pack de-csv aceitou um segundo argumento (rc=$rc)" "$saida"

CASA_ALHEIA="/home/fulano"
MAC_ALHEIO="/Users/fulano"

for p in meowsystem dracula; do
  saida="$(viaja "$RAIZ/bin/meow" pack validar "$RAIZ/packs/$p" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "o pack $p do repositório valida com a régua do nome de usuário (rc=0)" \
    || falha "o pack $p do repositório não valida (rc=$rc)" "$saida"
done

CASA_CSV="$T$CASA_ALHEIA"
mkdir -p "$CASA_CSV"
cp "$T/cores.csv" "$CASA_CSV/casa-tinta.csv"
CASA_ID="$ID-casa"; CASA_DIR="$PACKS/$CASA_ID"
saida="$(viaja "$RAIZ/bin/meow" pack novo "$CASA_ID" --de-csv "$CASA_CSV/casa-tinta.csv" 2>&1)"; rc=$?
vazou="$(grep -rn "/home/" "$CASA_DIR" 2>/dev/null)"
[ "$rc" = "0" ] && [ -f "$CASA_DIR/pack.json" ] && [ -z "$vazou" ] \
  && ok "o novo --de-csv de um CSV dentro de uma casa passa na régua, e a casa não entra no pack" \
  || falha "o novo --de-csv de um CSV dentro de uma casa recusou, ou levou a casa (rc=$rc)" "$saida
$vazou"
saida="$(viaja "$RAIZ/bin/meow" pack importar "$CASA_CSV/casa-tinta.csv" 2>&1)"; rc=$?
vazou="$(grep -rn "/home/" "$DA_PESSOA/casa-tinta" 2>/dev/null)"
[ "$rc" = "0" ] && [ -d "$DA_PESSOA/casa-tinta" ] && [ -z "$vazou" ] \
  && ok "o importar do mesmo .csv passa na régua, e a casa não entra no pack" \
  || falha "o importar de um .csv dentro de uma casa recusou, ou levou a casa (rc=$rc)" "$saida
$vazou"
rm -rf "${DA_PESSOA:?}/casa-tinta"

mkdir -p "$CASA_CSV/.config/cosmic/com.system76.CosmicTheme.Mode/v1"
printf 'true' > "$CASA_CSV/.config/cosmic/com.system76.CosmicTheme.Mode/v1/is_dark"
saida="$(amb env -u MEOW_COSMIC_DIR HOME="$CASA_CSV" MEOW_ESTADO="$T/estado" \
         MEOW_PACK_DIR="$CASA_DIR" bash "$RAIZ/scripts/capturar_tema.sh" tinta-mauve </dev/null 2>&1)"; rc=$?
origem="$(sed -n 's/^origem: //p' "$CASA_DIR/temas/capturados/tinta-mauve/captura.txt" 2>/dev/null)"
# shellcheck disable=SC2088
[ "$rc" = "0" ] && [ "$origem" = "~/.config/cosmic" ] \
  && ok "o capturar_tema.sh grava origem: ~/.config/cosmic, e não a casa de quem capturou" \
  || falha "a captura não gravou a origem com ~ (rc=$rc, origem=$origem)" "$saida"

printf '\nlido de ~/Desenvolvimento/tinta/logo.svg\nforma: /home/<nome>/.config/cosmic\n' \
  >> "$CASA_DIR/CREDITOS.md"
printf '\x89PNG\r\n\x1a\n\0\0\0\0%s/Imagens/tela.png\n' "$CASA_ALHEIA" > "$CASA_DIR/tela.png"
mkdir -p "$CASA_DIR/.git"
printf '[remote]\n\turl = %s/tinta.git\n' "$CASA_ALHEIA" > "$CASA_DIR/.git/config"
saida="$(viaja "$RAIZ/bin/meow" pack validar "$CASA_ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a régua deixa passar o ~/, o <nome> de exemplo, o binário e o oculto (rc=0)" \
  || falha "a régua recusou o que não leva nome de ninguém (rc=$rc)" "$saida"

printf 'lido de %s/Downloads/tinta.csv\n' "$CASA_ALHEIA" >> "$CASA_DIR/CREDITOS.md"
n_cred="$(wc -l < "$CASA_DIR/CREDITOS.md")"
svg="$(cd "$CASA_DIR" && find icones -name '*.svg' | LC_ALL=C sort | head -n1)"
printf '<!-- exportado de %s/Desktop/tinta.svg -->\n' "$MAC_ALHEIO" >> "$CASA_DIR/$svg"
n_svg="$(wc -l < "$CASA_DIR/$svg")"
saida="$(viaja "$RAIZ/bin/meow" pack validar "$CASA_ID" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"2 linha(s) com a casa de alguém"* ]] \
  && [[ "$saida" == *"CREDITOS.md:$n_cred: $CASA_ALHEIA/"* ]] \
  && [[ "$saida" == *"$svg:$n_svg: $MAC_ALHEIO/"* ]] \
  && ok "o validar recusa /home/<nome>/ e /Users/<nome>/, dizendo arquivo e linha, os dois de uma vez" \
  || falha "o validar não recusou a casa de alguém como devia (rc=$rc)" "$saida"
amb python3 "$RAIZ/scripts/pack.py" caminho "$CASA_ID" id >/dev/null 2>&1 \
  && ok "a régua é da porta de quem publica: a sonda do motor ainda vê o pack" \
  || falha "a régua tirou o pack do motor"
rm -f "$T/casa.meowpack"
saida="$(viaja "$RAIZ/bin/meow" pack exportar "$CASA_ID" "$T/casa.meowpack" 2>&1)"; rc=$?
[ "$rc" != "0" ] && [[ "$saida" == *"CREDITOS.md:$n_cred:"* ]] && [ ! -e "$T/casa.meowpack" ] \
  && ok "o exportar herda a régua: recusa, diz a linha, e não escreve o arquivo (rc=$rc)" \
  || falha "o exportar levou a casa de alguém, ou não disse onde (rc=$rc)" "$saida"

python3 "$T/forja.py" "$T/$NOVO.meowpack" "$T/forjado.meowpack" extra nota-casa.md \
  "lido de $CASA_ALHEIA/tema/logo.svg" || exit 2
saida="$(viaja "$RAIZ/bin/meow" pack importar "$T/forjado.meowpack" 2>&1)"; rc=$?
restos="$(ls -A "$DA_PESSOA" 2>/dev/null)"
[ "$rc" != "0" ] && [[ "$saida" == *"nota-casa.md:1: $CASA_ALHEIA/"* ]] && [ -z "$restos" ] \
  && ok "o importar herda a régua: recusa o .meowpack com a casa de alguém, e nada é escrito (rc=$rc)" \
  || falha "o importar aceitou a casa de alguém, ou deixou rastro (rc=$rc)" "$saida
restos: $restos"

P35="$T/p35"; H35="$P35/casa"; mkdir -p "$P35/packs" "$H35"
cp -a "$PACK_DIR" "$P35/packs/$ID"
PADRAO_ID="$(basename "$(amb python3 "$RAIZ/scripts/pack.py" padrao)")"
dos_dois() {
  env -i PATH="$PATH" HOME="$H35" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$P35/packs" \
    MEOW_CONF="$P35/meow.conf" NO_COLOR=1 "$@"
}

SABORES="dracula alucard mocha latte inexistente $ID ${ID}claro"
adocao_shell="$(for f in $SABORES; do
  printf '%s ' "$f"
  dos_dois PACK="" FLAVOR="$f" bash -c '. "$MEOW_RAIZ/lib/comum.sh"
    d="$(meow_pack_dir)"; basename "${d:-$(meow_pack_padrao_dir)}"' 2>&1
done)"
adocao_painel="$(dos_dois python3 - $SABORES <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
for f in sys.argv[1:]:
    with open(servidor.CONF, "w", encoding="utf-8") as fh:
        fh.write('PACK=""\nFLAVOR="%s"\n' % f)
    print(f, servidor._pack_adotado())
PY
)"
if [ "$adocao_shell" = "$adocao_painel" ] \
   && [[ "$adocao_shell" == *"alucard dracula"* ]] && [[ "$adocao_shell" == *"${ID}claro $ID"* ]] \
   && [[ "$adocao_shell" == *"mocha $PADRAO_ID"* ]] && [[ "$adocao_shell" == *"inexistente $PADRAO_ID"* ]]; then
  ok "PACK vazio: shell e painel adotam o mesmo pack para os $(wc -w <<< "$SABORES") sabores, alucard -> dracula"
else
  falha "a adoção do shell e a do painel divergem, ou não adotam pelo sabor declarado" "shell:
$adocao_shell
painel:
$adocao_painel"
fi

for d in ".local/share/icons/foo-cursors" ".icons/Bar" ".local/share/icons/Zeta-cursors" \
         ".icons/.oculto" ".local/share/icons/Sequestro-cursors"; do
  mkdir -p "$H35/$d/cursors"; printf 'Xcur de mentira' > "$H35/$d/cursors/left_ptr"
done
mkdir -p "$H35/.local/share/icons/Sequestro"
printf '[Icon Theme]\nName=Sequestro\nDirectories=48x48/apps\n' > "$H35/.local/share/icons/Sequestro/index.theme"
printf 'PACK=""\nFLAVOR="%s"\n' "${ID}claro" > "$P35/meow.conf"
lista_shell="$(dos_dois PACK="" FLAVOR="${ID}claro" LC_ALL=pt_BR.UTF-8 \
  bash "$RAIZ/scripts/cursor.sh" listar 2> "$P35/listar.err")"
lista_painel="$(dos_dois python3 - <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
print("\n".join(servidor._temas_de_cursor()))
PY
)"
casos="$(grep -xE "Bar|Zeta|foo|\.oculto|$ID-roxo|Sequestro" <<< "$lista_shell" | tr '\n' ' ')"
if [ "$lista_shell" = "$lista_painel" ] && [ "$casos" = ".oculto Bar Zeta foo $ID-roxo " ]; then
  ok "cursor.sh listar e o painel: o mesmo conjunto, na mesma ordem ($(wc -l <<< "$lista_shell") ponteiros, o do pack adotado pelo sabor incluído)"
else
  falha "cursor.sh listar e o painel listam ponteiros diferentes, ou em outra ordem" "os casos, na ordem do shell: $casos
shell:
$lista_shell
$(cat "$P35/listar.err")
painel:
$lista_painel"
fi

saida="$(amb python3 - "$RAIZ" "$T/doc" <<'PY' 2>&1
import json, os, subprocess, sys
raiz, base = sys.argv[1], sys.argv[2]
pack_py = os.path.join(raiz, "scripts", "pack.py")
linhas = open(os.path.join(raiz, "docs", "PACKS.md"), encoding="utf-8").read().split("\n")
blocos, i = [], 0
while i < len(linhas):
    cerca = linhas[i].strip()
    if cerca.startswith("```json"):
        j = i + 1
        while j < len(linhas) and not linhas[j].strip().startswith("```"):
            j += 1
        blocos.append((i + 1, cerca[3:].split()[1:], "\n".join(linhas[i + 1:j])))
        i = j
    i += 1

erros, paletas, packs, desenhos, fragmentos = [], [], [], [], 0
for num, marcas, corpo in blocos:
    if marcas == ["fragmento"]:
        fragmentos += 1
        for texto in (corpo, "{" + corpo + "}"):
            try:
                json.loads(texto)
                break
            except ValueError:
                pass
        else:
            erros.append(f"PACKS.md:{num}: o fragmento não é JSON, nem sozinho nem entre chaves")
        continue
    if marcas:
        erros.append(f"PACKS.md:{num}: marcador {' '.join(marcas)!r} — o único que existe é 'fragmento'")
        continue
    try:
        obj = json.loads(corpo)
    except ValueError as e:
        erros.append(f"PACKS.md:{num}: não é JSON ({e}).\n"
                     f"    Se é um pedaço de arquivo, a cerca é ```json fragmento")
        continue
    if isinstance(obj, dict) and "flavors" in obj:
        paletas.append((num, obj))
    elif isinstance(obj, dict) and "formato" in obj:
        packs.append((num, obj))
    elif isinstance(obj, dict) and "papeis" in obj and "svg" in obj:
        desenhos.append((num, obj))
    else:
        erros.append(f"PACKS.md:{num}: um JSON inteiro que não é pack.json, paleta nem desenho.\n"
                     f"    Ou ele é um pedaço (```json fragmento), ou este teste aprende a validá-lo")
if len(paletas) != 1 or not packs:
    erros.append(f"o PACKS.md tem {len(paletas)} paleta(s) e {len(packs)} pack.json inteiros — "
                 f"o pack do exemplo precisa de uma paleta e de pelo menos um pack.json")

def escrever(d, rel, texto):
    alvo = os.path.join(d, rel)
    os.makedirs(os.path.dirname(alvo), exist_ok=True)
    with open(alvo, "w", encoding="utf-8") as fh:
        fh.write(texto)

for num, p in (packs if not erros else []):
    d = os.path.join(base, str(p.get("id")))
    escrever(d, "pack.json", json.dumps(p, ensure_ascii=False, indent=2))
    escrever(d, (p.get("paleta") or {}).get("arquivo") or "paleta.json",
             json.dumps(paletas[0][1], ensure_ascii=False, indent=2))
    if p.get("creditos"):
        escrever(d, p["creditos"], "Tudo aqui é de quem escreveu o exemplo.\n")
    pasta = ((p.get("icones") or {}).get("autorais") or {}).get("desenhos") or "icones/autorais/"
    os.makedirs(os.path.join(d, pasta), exist_ok=True)
    for k, (_n, desenho) in enumerate(desenhos):
        escrever(d, os.path.join(pasta, f"exemplo{k}.json"), json.dumps(desenho, ensure_ascii=False))
    capa = (p.get("vitrine") or {}).get("capa")
    if capa:
        r = subprocess.run([sys.executable, pack_py, "logo-gerado", d], capture_output=True, text=True)
        escrever(d, capa, r.stdout)
    r = subprocess.run([sys.executable, pack_py, "validar", d], capture_output=True, text=True)
    if r.returncode != 0:
        erros.append(f"PACKS.md:{num}, com a paleta da linha {paletas[0][0]} e "
                     f"{len(desenhos)} desenho(s): o validar recusa (rc={r.returncode})\n"
                     + (r.stderr.strip() or r.stdout.strip()))
if erros:
    print("\n".join(erros))
    sys.exit(1)
print(f"{len(packs)} pack.json, {len(paletas)} paleta e {len(desenhos)} desenho validados; "
      f"{fragmentos} fragmento(s) conferidos como JSON")
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "os exemplos do docs/PACKS.md passam pelo validar ($saida)" \
  || falha "um exemplo do docs/PACKS.md não passa pelo validar" "$saida"

saida="$(amb python3 - "$RAIZ" <<'PY' 2>&1
import ast, os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
fonte = open(servidor.__file__, encoding="utf-8").read()
fn = [n for n in ast.walk(ast.parse(fonte))
      if isinstance(n, ast.FunctionDef) and n.name == "_flavor_no_modo"]
linhas = [i for i, l in enumerate(fonte.splitlines(), 1) if "claros[0]" in l]
erros = []
if not fn or len(linhas) != 1 or not (fn[0].lineno <= linhas[0] <= fn[0].end_lineno):
    erros.append(f"o primeiro claro do pack no ar está fora da função, ou copiado: linhas {linhas}")
else:
    for claros, modo, esperado in ((["papel", "outro"], "claro", "papel"),
                                   (["papel"], "escuro", "tinta"),
                                   ([], "claro", "tinta")):
        servidor._paleta_dados = lambda c=claros: {"claros": c}
        if servidor._flavor_no_modo("tinta", modo) != esperado:
            erros.append(f"claros={claros} modo={modo}: esperava {esperado!r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o claro da página sai de uma função só, e ela responde o que as três cópias respondiam" \
  || falha "o claro da página voltou a ser copiado, ou a função mudou de resposta" "$saida"

cartao="$(sed -n '/^function cartaoDePack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
faltam=""
[[ -n "$cartao" && "$cartao" != *"p.origem"* && "$cartao" != *"herdado d"* ]] || faltam+=" o cartão imprime a herança crua;"
[ -z "$faltam" ] \
  && ok "o cartão não imprime a herança crua do pack" \
  || falha "o rótulo de herança voltou a ter duas formas:$faltam"

AVISO="$ID-aviso"
cat > "$T/p34-rotas.py" <<'PY'
import base64, json, os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
aviso, pai = sys.argv[1:]
h = servidor.Manipulador.__new__(servidor.Manipulador)
h._json = lambda dados, status=200: (status, dados)
erros = []
for nome, conteudo, esperado in (("Meu Tema.meowpack", "isto não e zstd".encode(),
                                  "Meu Tema.meowpack: não é um .meowpack"),
                                 ("Minha Tinta.csv", b"slot,flavor,hex\n\xff\xfe\n",
                                  "Minha Tinta.csv: não é texto UTF-8")):
    st, r = h._api_pack_importar({"nome": nome, "conteudo": base64.b64encode(conteudo).decode()})
    erro = r.get("erro", "")
    if st != 400 or esperado not in erro or "meow-importa" in erro:
        erros.append(f"a recusa de {nome!r} não diz o arquivo dela: {st} {erro!r}")
st, r = h._api_pack_exportar({"id": [aviso], "medir": ["1"]})
if not (st == 200 and any(f"'{pai}', que não vem com o MeowSystem" in a for a in r.get("avisos", []))):
    erros.append(f"o medir do exportar não traz o aviso do comando: {st} {r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
saida="$(viaja "$RAIZ/bin/meow" pack novo "$AVISO" 2>&1)"; rc=$?
if [ "$rc" != "0" ]; then
  falha "o meow pack novo não montou o pack que herda de fora (rc=$rc)" "$saida"
else
  python3 - "$PACKS/$AVISO/pack.json" "$ID" <<'PY'
import json, sys
p = json.load(open(sys.argv[1], encoding="utf-8"))
p["heranca"] = sys.argv[2]
json.dump(p, open(sys.argv[1], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
  exportou="$(viaja "$RAIZ/bin/meow" pack exportar "$AVISO" "$T/$AVISO.meowpack" --seco 2>&1)"
  saida="$(viaja python3 "$T/p34-rotas.py" "$AVISO" "$ID" 2>&1)"; rc=$?
  [ "$rc" = "0" ] && [[ "$exportou" == *"'$ID', que não vem com o MeowSystem"* ]] \
    && ok "o importar recusa dizendo o arquivo dela, e o aviso do exportar chega à tela como no terminal" \
    || falha "o importar cita o temporário do servidor, ou o aviso do exportar não chega à tela" \
             "$saida$exportou"
  exporta="$(sed -n '/^async function exportarPack(/,/^}/p' "$RAIZ/app/pagina/paginas.js")"
  [[ "$exporta" == *"m.avisos"* && "$exporta" == *"m.imagens || avisos.length"* ]] \
    && ok "a caixa do exportar mostra o aviso, e aparece por ele mesmo sem imagens" \
    || falha "a página não mostra o aviso do exportar"
fi
rm -rf "${PACKS:?}/$AVISO"

mkdir -p "$T/tj/tom-e-jerry"
saida="$(amb python3 - "$RAIZ" "$PACK_DIR" "$T/tj" <<'PY' 2>&1
import json, os, shutil, subprocess, sys
import xml.etree.ElementTree as ET
raiz, fonte, base = sys.argv[1:]
gerador = os.path.join(raiz, "scripts", "gerar_icones_autorais.py")
SVG = "{http://www.w3.org/2000/svg}title"
erros = []

def gerar(dir_pack, *extra):
    amb = dict(os.environ, MEOW_PACK_DIR=dir_pack)
    amb.pop("MEOW_PALETA", None)
    return subprocess.run([sys.executable, gerador, *extra], env=amb, capture_output=True, text=True)

for ident in sorted(os.listdir(os.path.join(raiz, "packs"))):
    d = os.path.join(raiz, "packs", ident)
    pasta = os.path.join(d, "icones", "autorais")
    if not os.path.isdir(pasta) or not any(a.endswith(".svg") for a in os.listdir(pasta)):
        continue
    r = gerar(d, "--conferir", "--saida", pasta)
    if r.returncode != 0:
        erros.append(f"{ident}: o versionado não é o que o gerador desenha:\n"
                     + "\n".join(l for l in r.stdout.splitlines() if "ok " not in l))
    nome = json.load(open(os.path.join(d, "pack.json"), encoding="utf-8"))["nome"]
    for arq in sorted(a for a in os.listdir(pasta) if a.endswith(".svg")):
        t = ET.parse(os.path.join(pasta, arq)).getroot().find(SVG).text or ""
        dono = t.split(" — ", 1)[-1]
        if not dono.startswith(nome) or f"{nome} {nome}" in dono:
            erros.append(f"{ident}/{arq}: o título é {t!r}")

d = os.path.join(base, "tom-e-jerry")
for arq in ("paleta.json", "pack.json"):
    shutil.copy(os.path.join(fonte, arq), d)
p = json.load(open(os.path.join(d, "pack.json"), encoding="utf-8"))
p.update(id="tom-e-jerry", nome="Tom & Jerry")
json.dump(p, open(os.path.join(d, "pack.json"), "w", encoding="utf-8"), ensure_ascii=False)
saida = os.path.join(base, "saida")
r = gerar(d, "--saida", saida)
if r.returncode != 0:
    erros.append(f"o gerador recusou o pack «Tom & Jerry»: {r.stderr or r.stdout}")
else:
    for arq in sorted(os.listdir(saida)):
        try:
            t = ET.parse(os.path.join(saida, arq)).getroot().find(SVG).text or ""
        except ET.ParseError as e:
            erros.append(f"{arq}: não é XML com o nome do pack dentro ({e})")
            continue
        if " — Tom & Jerry " not in t:
            erros.append(f"{arq}: o título é {t!r}")
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o título dos autorais diz o pack dono do flavor, o versionado confere, e um nome com & não quebra o SVG" \
  || falha "o título dos autorais não diz o pack dono, ou o versionado não foi regerado" "$saida"

P31_CASA="$T/p31casa"; P31_CONF="$T/p31.conf"; mkdir -p "$P31_CASA"
p31_amb() {
  env -i PATH="$PATH" HOME="$P31_CASA" LANG=C.UTF-8 NO_COLOR=1 MEOW_RAIZ="$RAIZ" \
    MEOW_CONF="$P31_CONF" MEOW_PONTE=/nao/existe "$@"
}
cat > "$T/p31painel.py" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
h = servidor.Manipulador.__new__(servidor.Manipulador)
item = next(i for i in h._dados_esquema()["chaves"] if i["chave"] == "ICONES_FLAVOR")
print(item.get("efetivo") or "")
PY
p31_flavor_do_script() {
  sed -n -e "s/.* — flavor \([a-z0-9_]*\)$/\1/p" \
         -e "s/.* vestid[oa]s de [A-Z][A-Za-z]* \([a-z0-9_]*\)$/\1/p" \
         -e "s/.*para o flavor '\([a-z0-9_]*\)'.*/\1/p" \
         -e "s|.*catppuccin-apps/\([a-z0-9_]*\)$|\1|p" \
         -e "s/.* — Catppuccin \([a-z0-9_]*\)$/\1/p" | tail -1
}
p31_caso() {
  sed -e "s/^PACK=.*/PACK=\"$2\"/" -e "s/^FLAVOR=.*/FLAVOR=\"$3\"/" "$RAIZ/meow.conf.exemplo" > "$P31_CONF"
  [ -z "$4" ] || sed -i "s/^ICONES_FLAVOR=.*/$4/" "$P31_CONF"
  local painel script saida visto apps divergiu="" proprias=""
  painel="$(p31_amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_ponte_python >/dev/null 2>&1 || exit 9
    exec python3 "$1"' _ "$T/p31painel.py" 2>/dev/null | tail -1)"
  for script in icones_mimetypes icones_pastas; do
    saida="$(p31_amb bash -c 'set -a; . "$MEOW_CONF"; set +a
      PASTAS_XDG=sim MEOW_DRY_RUN=1 "$MEOW_RAIZ/scripts/$1.sh" --aplicar 2>&1' _ "$script")"
    visto="$(p31_flavor_do_script <<< "$saida")"
    apps="$5"
    case "$apps" in latte) ;; frappe|macchiato|mocha) apps="macchiato" ;; *) apps="" ;; esac
    if [ "$script" = "icones_apps" ]; then
      [ "$visto" = "$apps" ] || divergiu+=" $script='$visto' (esperava $apps)"
    elif [ "$script" = "icones_pastas" ] && [ -f "$RAIZ/packs/$2/icones/sistema/folder-documents.svg" ]; then
      proprias=1
      [[ "$saida" == *"desenhos do pack "* && "$saida" != *Catppuccin* ]] \
        || divergiu+=" $script não diz os desenhos do pack: $(tail -1 <<< "$saida")"
    else
      [ "$visto" = "$painel" ] || divergiu+=" $script='$visto'"
    fi
  done
  if [ "$painel" != "$5" ]; then
    falha "$1: o painel diz '$painel', e a regra manda '$5'"
  elif [ -n "$divergiu" ]; then
    falha "$1: o painel diz '$painel' e o shell discorda:$divergiu"
  elif [ -n "$proprias" ]; then
    ok "$1: painel, icones_mimetypes e icones_apps dizem '$painel', e as pastas especiais são os desenhos do pack"
  else
    ok "$1: painel e os três icones_*.sh dizem '$painel'"
  fi
}
p31_caso "Dracula no ar, conf de fábrica: o dracula do próprio pack" \
  dracula dracula "" dracula
p31_caso "Catppuccin no Latte, conf de fábrica: o latte do próprio tema" \
  meowsystem latte "" latte
p31_caso "Dracula no ar, ICONES_FLAVOR=\"latte\" escrito à mão: o conf vence" \
  dracula dracula 'ICONES_FLAVOR="latte"' latte
p31_caso "Catppuccin no Latte, ICONES_FLAVOR vazio: vazio acompanha o tema" \
  meowsystem latte 'ICONES_FLAVOR=""' latte

saida="$(env -u MEOW_PACK_DIR MEOW_RAIZ="$RAIZ" PACK=dracula FLAVOR=dracula ICONES_FLAVOR=dracula \
         python3 "$RAIZ/scripts/pack.py" flavor-icones dracula 2>&1)"; rc=$?
env -u MEOW_PACK_DIR MEOW_RAIZ="$RAIZ" FLAVOR= ICONES_FLAVOR= \
  python3 "$RAIZ/scripts/pack.py" flavor-icones meowsystem >/dev/null 2>&1; rc_vazio=$?
[ "$rc" = "0" ] && [ "$saida" = "dracula" ] && [ "$rc_vazio" = "1" ] \
  && ok "pack.py flavor-icones dracula responde dracula (o acervo é dele desde a P74), e sem conf nenhum sai 1" \
  || falha "o verbo flavor-icones não responde como a regra (rc=$rc/$rc_vazio)" "$saida"

cat > "$T/p31variante.py" <<'PY'
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
pack, deriva = sys.argv[1], sys.argv[2] == "deriva"
esquema = servidor.ler_esquema()
vocab = servidor.modulo_pack().vocabulario(pack)
servidor._com_o_vocabulario_do_pack(esquema, vocab, {"FLAVOR": vocab["flavor_padrao"]})
item = next(i for i in esquema if i["chave"] == "FLAVOR")
cru = next(i for i in servidor.ler_esquema() if i["chave"] == "FLAVOR")
erros = []
ids = [f["id"] for f in vocab["flavors"]]
if sorted(item["opcoes"]) != sorted(ids):
    erros.append("oferece %r, e o pack tem %r" % (item["opcoes"], ids))
for f in vocab["flavors"]:
    rot = item["rotulos"].get(f["id"], "")
    if not rot.startswith(f["nome"]) or (f.get("derivado") != rot.endswith("(derivado)")):
        erros.append("rótulo de %s: %r" % (f["id"], rot))
    q = servidor.validar_valor(cru, f["id"])
    if q:
        erros.append("a cerca recusa %s: %s" % (f["id"], q))
if deriva and not any(r.endswith(" (derivado)") for r in item["rotulos"].values()):
    erros.append("o claro derivado do pack de CSV não diz que é derivado: %r" % item["rotulos"])
if not servidor.validar_valor(cru, "nao-existe-em-pack-nenhum"):
    erros.append("a cerca aceitou um flavor que nenhum pack tem")
for palavra in ("Mocha", "Frappé", "Latte", "Macchiato", "Catppuccin"):
    if any(palavra in r for r in item["rotulos"].values()) or palavra in item.get("frase", ""):
        erros.append("a «Variante do tema» ainda diz %r" % palavra)
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
for caso in "dracula desenhado" "$ID-csv deriva"; do
  pack="${caso% *}"
  saida="$(amb python3 "$T/p31variante.py" $caso 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "a «Variante do tema» com o $pack no ar: os flavors dele, e a cerca aceita todos" \
    || falha "a «Variante do tema» com o $pack no ar não fala o pack" "$saida"
done

tira="$(cat "$RAIZ"/app/pagina/*.js | grep -v '^[[:space:]]*\(\*\|//\|/\*\)' | grep -c 'Catppuccin')"
queda="$(sed -n '/^def logo_do_painel(/,/^def /p' "$RAIZ/app/servidor.py" \
         | grep -v '^[[:space:]]*#' | grep -c '"mocha"')"
[ "$tira" = "0" ] && [ "$queda" = "0" ] \
  && ok "o balão da tira e a queda do logo_do_painel não cravam o Catppuccin" \
  || falha "sobrou nome de pack cravado: tira=$tira, \"mocha\" no logo_do_painel=$queda"

BIB="$RAIZ/packs/dracula/icones/biblioteca"
LISTA_BIB="$RAIZ/packs/dracula/icones/biblioteca-origem.sha256"
conta="$(python3 - "$LISTA_BIB" "$BIB" <<'PY'
import hashlib, os, re, sys
def shas(d):
    if not os.path.isdir(d):
        return {}
    return {hashlib.sha256(open(os.path.join(d, a), "rb").read()).hexdigest(): a
            for a in sorted(os.listdir(d)) if a.endswith(".svg")}
origem, commit = {}, ""
if os.path.isfile(sys.argv[1]):
    for l in open(sys.argv[1], encoding="utf-8"):
        m = re.match(r"^# commit: ([0-9a-f]{40})$", l.rstrip("\n"))
        if m:
            commit = m.group(1)
        m = re.match(r"^([0-9a-f]{64})  (\S+\.svg)$", l.rstrip("\n"))
        if m:
            origem[m.group(1)] = m.group(2)
pack = {**shas(sys.argv[2]), **shas(os.path.join(os.path.dirname(sys.argv[2]), "apps"))}
tabela = os.path.join(os.path.dirname(sys.argv[2]), "..", "..", "CAMINHOS-DE-ANTES.tsv")
saiu = set()
if os.path.exists(tabela):
    for l in open(tabela, encoding="utf-8"):
        if "\t" in l and not l.startswith("#"):
            k, v = l.rstrip("\n").split("\t", 1)
            if not v and k.startswith("packs/dracula/icones/biblioteca/") and k.count("/") == 4:
                saiu.add(os.path.basename(k))
faltam = sorted(a for s, a in origem.items() if s not in pack and a not in saiu)
origem = {s: a for s, a in origem.items() if a not in saiu}
print(f"{len(origem) - len(faltam)} {len(origem)} {commit or '-'}")
print("\n".join(faltam))
PY
)"
achados="$(printf '%s\n' "$conta" | sed -n 1p)"
read -r bib_tem bib_total bib_commit <<< "$achados"
[ -n "${bib_total:-}" ] && [ "$bib_tem" = "$bib_total" ] && [ "$bib_total" != "0" ] && [ "$bib_commit" != "-" ] \
  && ok "por sha256, a biblioteca do Dracula_OS-Theme (commit ${bib_commit:0:12}) está no pack (apps/ e biblioteca/, menos o que quem usa tirou): $bib_tem de $bib_total" \
  || falha "a biblioteca do pack não confere com a lista da origem ($achados)" \
           "$(printf '%s\n' "$conta" | tail -n +2 | head -20)"

sem_linha=""
for f in "$BIB"/*.svg; do
  [ -e "$f" ] || continue
  grep -qF "| \`icones/biblioteca/$(basename "$f")\` |" "$RAIZ/packs/dracula/PROCEDENCIA.md" \
    || sem_linha="$sem_linha$(basename "$f")
"
done
[ -d "$BIB" ] && [ -z "$sem_linha" ] \
  && ok "todo desenho da biblioteca do Dracula tem a linha dele no PROCEDENCIA.md" \
  || falha "desenho na biblioteca sem procedência (ou a biblioteca sumiu):" "$sem_linha"

esperado="$(python3 - "$RAIZ/packs/dracula/icones" <<'PY'
import hashlib, os, sys
ic = sys.argv[1]
h = lambda p: hashlib.sha256(open(p, "rb").read()).hexdigest()
nomes = {}
for linha in open(os.path.join(ic, "apps.map"), encoding="utf-8"):
    util = linha.split("#", 1)[0]
    nome, sep, alvo = util.partition(":")
    if sep and nome.strip() and alvo.strip():
        nomes[nome.strip()] = alvo.strip()
vestidos = {h(os.path.join(ic, a)) for a in nomes.values() if os.path.isfile(os.path.join(ic, a))}
bib = os.path.join(ic, "biblioteca")
soltos = sum(1 for a in os.listdir(bib) if a.endswith(".svg") and h(os.path.join(bib, a)) not in vestidos)
print(f"{len(nomes)} apps, {soltos} na biblioteca sem app ligado")
PY
)"
linha="$(amb python3 "$RAIZ/scripts/pack.py" info dracula 2>&1 | grep -E '^  icones\.apps ')"
[ -n "$esperado" ] && [[ "$linha" == *"$esperado" ]] \
  && ok "o info do Dracula conta a biblioteca: $esperado" \
  || falha "o info não conta a biblioteca como a conta de fora" "esperava '$esperado', veio '$linha'"

mkdir -p "$PACK_DIR/icones/biblioteca"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$PACK_DIR/icones/biblioteca/vapor.svg"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "um pack de terceiro com biblioteca de SVG valida" \
  || falha "a biblioteca de SVG foi recusada (rc=$rc)" "$saida"
printf 'rascunho' > "$PACK_DIR/icones/biblioteca/rascunho.png"
mkdir -p "$PACK_DIR/icones/biblioteca/etiqueta"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$PACK_DIR/icones/biblioteca/etiqueta/vapor2.svg"
ln -s /etc/hostname "$PACK_DIR/icones/biblioteca/link.svg"
printf 'nota' > "$PACK_DIR/icones/biblioteca/etiqueta/nota.txt"
saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$ID" 2>&1)"; rc=$?
[ "$rc" = "1" ] && [[ "$saida" == *"link.svg"* ]] && [[ "$saida" == *"etiqueta/nota.txt"* ]] \
  && [[ "$saida" != *"rascunho.png"* ]] && [[ "$saida" != *"vapor2.svg"* ]] \
  && ok "o validar aceita PNG e subpasta na biblioteca, recusa link e o que não é imagem, e nomeia todos de uma vez" \
  || falha "a forma da biblioteca não é a da decisão 14 (rc=$rc)" "$saida"
rm -rf "$PACK_DIR/icones/biblioteca/etiqueta" "$PACK_DIR/icones/biblioteca/rascunho.png"
saida="$(amb python3 "$RAIZ/scripts/pack.py" caminho "$ID" id 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "a sonda do motor (caminho) segue vendo o pack com a biblioteca suja" \
  || falha "um arquivo solto na biblioteca derrubou a sonda do motor (rc=$rc)" "$saida"
rm -rf "$PACK_DIR/icones/biblioteca"

REDE="$T/rede"; BIN41="$T/bin41"; H41="$T/casa-p41"
mkdir -p "$REDE" "$BIN41" "$H41" "$T/pacote41/tema-de-mentira-1a2b/scalable/apps" \
         "$T/pacote41/ponteiro-de-mentira/cursors"
cat > "$BIN41/curl" <<'C'
#!/bin/sh
# curl de mentira do tests/pack.sh (P41): nunca abre a rede.
dest=""; url=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o) dest="$2"; shift 2 ;;
    --proto|--proto-redir|--connect-timeout|--max-time|--retry|--retry-delay) shift 2 ;;
    -*) shift ;;
    *) url="$1"; shift ;;
  esac
done
printf '%s\n' "$url" >> "$REDE/.chamadas"
arq="$REDE/$(basename "$url")"
[ -f "$arq" ] || exit 22
cp "$arq" "$dest"
C
chmod +x "$BIN41/curl"
printf '[Icon Theme]\nName=Mentira\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$T/pacote41/tema-de-mentira-1a2b/index.theme"
printf '<svg xmlns="http://www.w3.org/2000/svg"/>\n' > "$T/pacote41/tema-de-mentira-1a2b/scalable/apps/editor.svg"
ln -s editor.svg "$T/pacote41/tema-de-mentira-1a2b/scalable/apps/text-editor.svg"
tar -czf "$REDE/base.tar.gz" -C "$T/pacote41" tema-de-mentira-1a2b || exit 2
printf 'Xcur de mentira' > "$T/pacote41/ponteiro-de-mentira/cursors/default"
ln -s default "$T/pacote41/ponteiro-de-mentira/cursors/left_ptr"
printf '[Icon Theme]\nName=ponteiro-de-mentira\n' > "$T/pacote41/ponteiro-de-mentira/index.theme"
tar -cJf "$REDE/ponteiro.tar.xz" -C "$T/pacote41" ponteiro-de-mentira || exit 2
SHA_BASE="$(sha256sum "$REDE/base.tar.gz" | cut -d' ' -f1)"
SHA_PONT="$(sha256sum "$REDE/ponteiro.tar.xz" | cut -d' ' -f1)"

PIN="$ID-pinado"; mkdir -p "$PACKS/$PIN"
cp "$PACK_DIR/paleta.json" "$PACK_DIR/logo.svg" "$PACKS/$PIN/"
printf '{"formato": 1, "id": "%s", "nome": "Pinado", "heranca": "%s",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "%s"}, "vitrine": {"capa": "logo.svg"},
 "icones": {"base": {"origem": {"url": "https://exemplo.invalid/p41/base.tar.gz",
   "sha256": "%s", "pasta": "tema-de-mentira-1a2b"}}},
 "origens": {"cursores": {"origem": {"nome": "%s-baixado",
   "url": "https://exemplo.invalid/p41/ponteiro.tar.xz", "sha256": "%s",
   "pasta": "ponteiro-de-mentira"}}}}\n' \
  "$PIN" "$ID" "$ID" "$SHA_BASE" "$ID" "$SHA_PONT" > "$PACKS/$PIN/pack.json"

saida="$(amb python3 "$RAIZ/scripts/pack.py" validar "$PIN" 2>&1)"; rc=$?
if [ "$rc" = "0" ] && [[ "$saida" != *icones.base* ]] && [[ "$saida" != *cursores.origem* ]]; then
  ok "o pack com base e ponteiro baixados valida, e nenhum dos campos novos é campo morto"
else
  falha "o pack com as origens pinadas não validou, ou o aviso chamou um campo novo de morto (rc=$rc)" "$saida"
fi

exemplo_py="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import pack; print(pack.ICONES_BASE_DO_EXEMPLO)' "$RAIZ/scripts")"
aposentada="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import migrar_conf; print("ICONES_BASE" in migrar_conf.APOSENTADAS)' "$RAIZ/scripts")"
if ! grep -qE '^[[:space:]]*ICONES_BASE=' "$RAIZ/meow.conf.exemplo" && [ "$aposentada" = "True" ] \
   && [ "$exemplo_py" = "Papirus-Dark" ]; then
  ok "a ICONES_BASE está aposentada (fora do exemplo, na lista do migrar_conf) e o Papirus-Dark antigo cede"
else
  falha "a aposentadoria da ICONES_BASE não está inteira" "exemplo tem a chave? $(grep -c '^ICONES_BASE=' "$RAIZ/meow.conf.exemplo") · aposentada=$aposentada · pack.py='$exemplo_py'"
fi

base_verbo() { amb env ICONES_BASE="$1" python3 "$RAIZ/scripts/pack.py" base-icones "$PIN" 2>&1; }
v_fab="$(base_verbo Papirus-Dark)"; v_vazio="$(base_verbo "")"; v_mao="$(base_verbo Outro-Tema)"
if [[ "$v_fab" == *"quem=pack"*"pack=$PIN"*"sha256=$SHA_BASE"* ]] && [[ "$v_vazio" == *"quem=pack"* ]] \
   && [[ "$v_mao" == *"quem=conf"*"tema=Outro-Tema"*"pack=$PIN"* ]]; then
  ok "o Papirus-Dark de fábrica e o vazio cedem à base do pack; o ICONES_BASE escrito à mão vence, e o pack é dito"
else
  falha "o verbo base-icones não aplicou a regra de quem vence" "fábrica: $v_fab
vazio: $v_vazio
à mão: $v_mao"
fi

v_nossa="$(base_verbo MeowSystem-Icons-Base)"
linha="$(amb env ICONES_BASE=MeowSystem-Icons-Base python3 "$RAIZ/scripts/pack.py" info "$PIN" 2>&1 | grep -E '^  icones\.base ')"
if [[ "$v_nossa" == *"quem=pack"*"pack=$PIN"* ]] && [[ "$linha" == *"do pack $PIN"* ]] \
   && [[ "$linha" != *"vale o ICONES_BASE"* ]]; then
  ok "o ICONES_BASE que nomeia a nossa própria base é a do pack, no verbo e no info"
else
  falha "o ICONES_BASE=\"MeowSystem-Icons-Base\" foi lido como escolha à mão" "verbo: $v_nossa
info: $linha"
fi

base_sh() {
  local pedido="$1"; shift
  env -i PATH="$BIN41:$PATH" HOME="$H41" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" REDE="$REDE" NO_COLOR=1 \
    PACK="$PIN" FLAVOR="$ID" ICONES_BASE="$pedido" "$@" bash "$RAIZ/scripts/construir_icones.sh" base 2>&1
}
BASE41="$H41/.local/share/icons/MeowSystem-Icons-Base"
chamadas() { if [ -s "$REDE/.chamadas" ]; then grep -c . "$REDE/.chamadas"; else printf '0'; fi; }

saida="$(base_sh Papirus-Dark MEOW_DRY_RUN=1)"; rc=$?
if [ "$rc" = "1" ] && [[ "$saida" == *"baixaria a base"* ]] && [ "$(chamadas)" = "0" ] \
   && [ -z "$(find "$H41" -mindepth 1 2>/dev/null)" ]; then
  ok "em seco, a base diz que desceria — sem chamar o curl e sem escrever no HOME"
else
  falha "o seco da base baixou, escreveu, ou não disse (rc=$rc, chamadas=$(chamadas))" "$saida"
fi

saida="$(base_sh Papirus-Dark)"; rc=$?
if [ "$rc" = "1" ] && [ -f "$BASE41/scalable/apps/editor.svg" ] && [ -L "$BASE41/scalable/apps/text-editor.svg" ] \
   && grep -qx "sha256=$SHA_BASE" "$BASE41/.meow-origem" 2>/dev/null \
   && [[ "$saida" == *"herda de 'MeowSystem-Icons-Base'"* ]]; then
  ok "a base baixa, confere o sha256, entra com os links, e o tema passa a herdar dela"
else
  falha "a base não desceu inteira, ou o tema não herda dela (rc=$rc)" "$saida
$(find "$H41" -mindepth 1 2>/dev/null | head -8)"
fi
saida="$(base_sh Papirus-Dark)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"confere"* ]] && [ "$(chamadas)" = "1" ] \
  && ok "a segunda passagem confere a base pelo conteúdo e não baixa de novo" \
  || falha "a base não convergiu na segunda passagem (rc=$rc, chamadas=$(chamadas))" "$saida"
rm -f "$BASE41/scalable/apps/editor.svg"
saida="$(base_sh Papirus-Dark)"; rc=$?
[ "$rc" = "1" ] && [ -f "$BASE41/scalable/apps/editor.svg" ] && [ "$(chamadas)" = "2" ] \
  && ok "um arquivo que some da base é percebido pelo conteúdo, e a base volta inteira" \
  || falha "a base com arquivo faltando passou por inteira (rc=$rc, chamadas=$(chamadas))" "$saida"

mkdir -p "$T/binmv41"
printf '#!/bin/sh\ncase "$*" in *tema-de-mentira-1a2b*MeowSystem-Icons-Base*) exit 1 ;; esac\nexec %s "$@"\n' \
  "$(command -v mv)" > "$T/binmv41/mv"
chmod +x "$T/binmv41/mv"
rm -f "$BASE41/scalable/apps/editor.svg"
saida="$(base_sh Papirus-Dark PATH="$T/binmv41:$BIN41:$PATH")"; rc=$?
if [ "$rc" = "2" ] && [ -f "$BASE41/index.theme" ] && grep -qx "sha256=$SHA_BASE" "$BASE41/.meow-origem" 2>/dev/null \
   && [ -L "$BASE41/scalable/apps/text-editor.svg" ] \
   && [ -z "$(find "$H41/.local/share/icons" -maxdepth 1 -name '.meow-base.*' 2>/dev/null)" ]; then
  ok "o mv que falha ao pôr a base nova devolve a de antes, e nenhum palco fica para trás"
else
  falha "o mv que falhou deixou o tema sem base, ou deixou sobra (rc=$rc)" "$saida
$(find "$H41/.local/share/icons" -maxdepth 2 2>/dev/null | head -8)"
fi

env -i PATH="$BIN41:$PATH" HOME="$H41" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" REDE="$REDE" NO_COLOR=1 \
  PACK="$PIN" FLAVOR="$ID" ICONES_BASE="Papirus-Dark" bash "$RAIZ/scripts/construir_icones.sh" >/dev/null 2>&1
herda="$(sed -n 's/^Inherits=//p' "$H41/.local/share/icons/MeowSystem-Icons/index.theme" 2>/dev/null)"
[[ "$herda" == "MeowSystem-Icons-Base,"* ]] \
  && ok "o index.theme do MeowSystem-Icons herda da base do pack ($herda)" \
  || falha "o index.theme não herda da base do pack" "Inherits=$herda"

saida="$(base_sh MeowSystem-Icons-Base)"; rc=$?
[ "$rc" = "0" ] && [ -f "$BASE41/.meow-origem" ] && [[ "$saida" == *"herda de 'MeowSystem-Icons-Base'"* ]] \
  && [[ "$saida" != *"vale o ICONES_BASE"* ]] \
  && ok "o construir lê o ICONES_BASE=\"MeowSystem-Icons-Base\" como a base do pack, e ela fica" \
  || falha "o construir tratou a nossa base como escolha à mão (rc=$rc)" "$saida"

saida="$(base_sh Outro-Tema)"; rc=$?
if [ "$rc" = "1" ] && [ ! -e "$BASE41" ] && [[ "$saida" == *"vale o ICONES_BASE=\"Outro-Tema\""* ]] \
   && [[ "$saida" == *"herda de 'Outro-Tema'"* ]]; then
  ok "o ICONES_BASE escrito à mão vence a base do pack, a base sai do disco, e a linha diz os dois"
else
  falha "o ICONES_BASE escrito à mão não venceu, ou a base ficou, ou a tela calou (rc=$rc)" "$saida"
fi
linha="$(amb env ICONES_BASE=Outro-Tema python3 "$RAIZ/scripts/pack.py" info "$PIN" 2>&1 | grep -E '^  icones\.base ')"
[[ "$linha" == *PRÓPRIO*"exemplo.invalid/p41/base.tar.gz"*"do pack $PIN"*"vale o ICONES_BASE=\"Outro-Tema\""* ]] \
  && ok "o info diz de onde a base desce, de quem, e que o meow.conf vale" \
  || falha "a linha icones.base do info não diz a origem, o pack e quem vale" "$linha"

mkdir -p "$BASE41"; printf 'de outra pessoa\n' > "$BASE41/index.theme"
base_sh Outro-Tema >/dev/null; saida="$(base_sh Papirus-Dark)"; rc=$?
if [ "$(cat "$BASE41/index.theme" 2>/dev/null)" = "de outra pessoa" ] && [ "$rc" = "0" ] \
   && [[ "$saida" == *"não foi este script que o pôs lá"* ]] && [[ "$saida" == *"herda de 'Papirus-Dark'"* ]]; then
  ok "um diretório com o nome da base e sem o marcador não é apagado nem sobrescrito"
else
  falha "o diretório de outra pessoa foi mexido, ou a tela não disse (rc=$rc)" "$saida"
fi
rm -rf "$BASE41"

cp "$REDE/base.tar.gz" "$T/base-certa.tar.gz"; printf 'x' >> "$REDE/base.tar.gz"
saida="$(base_sh Papirus-Dark)"; rc=$?
if [ "$rc" = "2" ] && [[ "$saida" == *"não bate"*"esperado $SHA_BASE"* ]] && [ ! -e "$BASE41" ] \
   && [ -z "$(find "$H41/.local/share/icons" -maxdepth 1 -name '.meow-base.*' 2>/dev/null)" ]; then
  ok "o pacote que não confere com o sha256 pinado é recusado, e nada fica no disco"
else
  falha "o sha256 errado passou, ou deixou sobra (rc=$rc)" "$saida"
fi
rm -f "$REDE/base.tar.gz"
saida="$(base_sh Papirus-Dark)"; rc=$?
[ "$rc" = "0" ] && [[ "$saida" == *"sem rede"* ]] && [[ "$saida" == *"herda de 'Papirus-Dark'"* ]] \
  && ok "sem rede, a base fica para o próximo ciclo e o tema herda do de fábrica" \
  || falha "sem rede a base não saiu limpa (rc=$rc)" "$saida"
mv "$T/base-certa.tar.gz" "$REDE/base.tar.gz"

recusa41() {
  rm -rf "$T/recusa41"; mkdir -p "$T/recusa41"; cp -a "$PACKS/$PIN" "$PACK_DIR" "$T/recusa41/"
  mexer_pack "$T/recusa41/$PIN" "$2"
  saida="$(env MEOW_PACKS="$T/recusa41" MEOW_RAIZ="$RAIZ" python3 "$RAIZ/scripts/pack.py" validar "$PIN" 2>&1)"; rc=$?
  if [ "$rc" = "1" ] && [[ "$saida" == *"$3"* ]]; then
    ok "recusa $1"
  else
    falha "não recusou $1, ou não disse por quê (rc=$rc)" "$saida"
  fi
}
recusa41 "a base em http" '{"icones": {"base": {"origem": {"url": "http://exemplo.invalid/b.tar.gz"}}}}' "só https"
recusa41 "a base sem sha256" '{"icones": {"base": {"origem": {"sha256": null}}}}' "declara pasta, sha256, url"
recusa41 "a base com '..' na pasta" '{"icones": {"base": {"origem": {"pasta": "../fora"}}}}' "sem '..'"
recusa41 "a base num .zip" '{"icones": {"base": {"origem": {"url": "https://exemplo.invalid/b.zip"}}}}' "não termina em"
recusa41 "a base com origem e herda juntas" "{\"icones\": {\"base\": {\"herda\": \"$ID\"}}}" "'origem' e 'herda' ao mesmo tempo"
recusa41 "o ponteiro com origem e herda juntos" "{\"origens\": {\"cursores\": {\"herda\": \"$ID\"}}}" '`origem` vem sozinha'
recusa41 "o ponteiro baixado sem nome" '{"origens": {"cursores": {"origem": {"nome": null}}}}' "declara nome, pasta, sha256, url"
rm -rf "$T/recusa41"

saida="$(amb python3 "$RAIZ/scripts/pack.py" ponteiro "$PIN" 2>&1)"
[ "$saida" = "pack=$PIN
dir=
valor=$ID-baixado
url=https://exemplo.invalid/p41/ponteiro.tar.xz
sha256=$SHA_PONT
pasta=ponteiro-de-mentira" ] \
  && ok "o verbo 'ponteiro' entrega o baixado com a origem, e ele vence o PRÓPRIO do pack de quem herda" \
  || falha "o verbo 'ponteiro' não respondeu o ponteiro baixado" "$saida"
cursor41() {
  env -i PATH="$BIN41:$T/bin:$PATH" HOME="$H41" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" REDE="$REDE" NO_COLOR=1 \
    PACK="$PIN" CURSOR="$ID-baixado" "$@" bash "$RAIZ/scripts/cursor.sh" aplicar 2>&1
}
rm -rf "$H41"; mkdir -p "$H41"; : > "$REDE/.chamadas"
saida="$(cursor41 MEOW_DRY_RUN=1)"; rc=$?
if [ "$rc" = "1" ] && [[ "$saida" == *"baixaria o ponteiro '$ID-baixado' do pack $PIN"* ]] \
   && [ "$(chamadas)" = "0" ] && [ -z "$(find "$H41" -mindepth 1 2>/dev/null)" ]; then
  ok "o aplicar em seco diz que baixaria o ponteiro do pack, sem rede e sem escrever"
else
  falha "o aplicar em seco do ponteiro baixado baixou, escreveu ou não disse (rc=$rc)" "$saida"
fi
saida="$(cursor41)"; rc=$?
saida2="$(cursor41)"; rc2=$?
if [ "$rc" = "1" ] && [ -f "$H41/.local/share/icons/$ID-baixado-cursors/cursors/default" ] \
   && [ -L "$H41/.local/share/icons/$ID-baixado-cursors/cursors/left_ptr" ] \
   && [ "$rc2" = "0" ] && [[ "$saida2" == *"já está instalado"* ]] && [ "$(chamadas)" = "1" ]; then
  ok "o ponteiro desce, entra como <valor>-cursors com os links, e a segunda passagem não baixa de novo"
else
  falha "o ponteiro baixado não entrou, ou não convergiu (rc=$rc, rc2=$rc2, chamadas=$(chamadas))" "$saida
$saida2"
fi
rm -rf "$H41"; mkdir -p "$H41"; printf 'x' >> "$REDE/ponteiro.tar.xz"
saida="$(cursor41)"; rc=$?
[ "$rc" = "2" ] && [[ "$saida" == *"não bate"* ]] && [ ! -e "$H41/.local/share/icons/$ID-baixado-cursors" ] \
  && ok "o ponteiro que não confere com o sha256 pinado é recusado, e nada entra" \
  || falha "o ponteiro com sha256 errado passou (rc=$rc)" "$saida"
linha="$(amb python3 "$RAIZ/scripts/pack.py" info "$PIN" 2>&1 | grep -E '^  cursores ')"
[[ "$linha" == *PRÓPRIO*"CURSOR=\"$ID-baixado\", do pack $PIN, baixado de exemplo.invalid"* ]] \
  && ok "o info diz o valor do ponteiro baixado, de quem, e de onde desce" \
  || falha "a linha cursores do info não diz o ponteiro baixado" "$linha"

NETO="$ID-neto"; mkdir -p "$PACKS/$NETO"; cp "$PACK_DIR/paleta.json" "$PACK_DIR/logo.svg" "$PACKS/$NETO/"
printf '{"formato": 1, "id": "%s", "nome": "Neto", "heranca": "%s",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "%s"}, "vitrine": {"capa": "logo.svg"}}\n' \
  "$NETO" "$PIN" "$ID" > "$PACKS/$NETO/pack.json"
tabela="$(amb python3 "$RAIZ/scripts/pack.py" info "$NETO" 2>&1)"
if printf '%s\n' "$tabela" | grep -qE "^  icones\.base +HERDADO de $PIN +exemplo\.invalid/.*do pack $PIN" \
   && printf '%s\n' "$tabela" | grep -qE "^  cursores +HERDADO de $PIN +CURSOR=\"$ID-baixado\", do pack $PIN"; then
  ok "quem herda do pinado recebe a base e o ponteiro dele, e a tabela diz de quem"
else
  falha "a base ou o ponteiro baixados não sobem pela herança" "$tabela"
fi
rm -rf "$PACKS/$NETO" "$PACKS/$PIN" "$H41"

so_repo() { env -u MEOW_PACK_DIR -u MEOW_PACKS XDG_DATA_HOME="$T/xdg41" MEOW_RAIZ="$RAIZ" "$@"; }
v_dr="$(so_repo ICONES_BASE=Papirus-Dark python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1)"
v_dr_mao="$(so_repo ICONES_BASE=Dracula-Icones python3 "$RAIZ/scripts/pack.py" base-icones dracula 2>&1)"
p_dr="$(so_repo python3 "$RAIZ/scripts/pack.py" ponteiro dracula 2>&1)"
if [[ "$v_dr" == *"quem=pack"*"pack=dracula"*"url=https://github.com/m4thewz/dracula-icons/archive/"* ]] \
   && printf '%s\n' "$v_dr" | grep -qE '^sha256=[0-9a-f]{64}$' \
   && [[ "$v_dr_mao" == *"quem=conf"*"tema=Dracula-Icones"* ]] \
   && [[ "$p_dr" == *"valor=Dracula-Cursor"*"url=https://github.com/dracula/gtk/releases/download/"* ]]; then
  ok "o pack Dracula declara a base e o ponteiro pinados, e o ICONES_BASE escrito à mão continua vencendo"
else
  falha "o pack Dracula não declara a base e o ponteiro como a P41 pede" "$v_dr
$v_dr_mao
$p_dr"
fi

for app in kitty gnome-terminal telegram discord onlyoffice; do
  saida="$(amb python3 "$RAIZ/scripts/pack.py" app dracula "apps.$app.arquivo" 2>&1)"; rc=$?
  valor="$(printf '%s\n' "$saida" | sed -n 's/^valor=//p')"
  if [ "$rc" = 0 ] && printf '%s\n' "$saida" | grep -qx 'pack=dracula' \
     && [ -f "$valor" ] && [ "${valor#"$RAIZ/scripts/temas-de-apps/$app/"}" != "$valor" ]; then
    ok "o Dracula declara o tema do $app, e o modelo mora no motor ($(basename "$valor"))"
  else
    falha "apps.$app.arquivo do Dracula não resolveu para o modelo do motor (rc=$rc)" "$saida"
  fi
  [ ! -e "$RAIZ/packs/dracula/apps" ] && [ ! -e "$RAIZ/packs/dracula/temas-de-apps/$app" ] \
    && ok "o modelo do $app não tem cópia dentro do pack" \
    || falha "o modelo do $app tem cópia dentro do pack"
done
saida="$(amb python3 "$RAIZ/scripts/pack.py" app meowsystem apps.kitty.arquivo 2>&1)"
if printf '%s\n' "$saida" | grep -qx 'pack=meowsystem'; then
  ok "o pack padrão responde pelo próprio kitty — declarado, e não empréstimo"
else
  falha "o kitty do pack padrão não é dele" "$saida"
fi

app55() { so_repo python3 "$RAIZ/scripts/pack.py" app "$1" "apps.$2" 2>&1; }
valor55() { app55 "$1" "$2" | sed -n 's/^valor=//p'; }
faltam=""
for par in "meowsystem obsidian.esquema Catppuccin" "meowsystem vscode.esquema Catppuccin Mocha" \
           "meowsystem vscode.origem.extensao Catppuccin.catppuccin-vsc" \
           "meowsystem vscode-icones.esquema catppuccin-mocha" \
           "dracula obsidian.esquema Dracula Official" "dracula vscode.esquema Dracula Theme" \
           "dracula vscode.origem.extensao dracula-theme.theme-dracula" "dracula heroic.esquema dracula"; do
  read -r p trilha esperado <<< "$par"
  saida="$(app55 "$p" "$trilha")"
  printf '%s\n' "$saida" | grep -qx "pack=$p" && [ "$(valor55 "$p" "$trilha")" = "$esperado" ] \
    || faltam+=" $p/$trilha ($saida);"
done
[ "$(so_repo env FLAVOR=latte python3 "$RAIZ/scripts/pack.py" app meowsystem apps.heroic.esquema | sed -n 's/^valor=//p')" \
  = "catppuccin-latte-<accent>.css" ] || faltam+=" heroic do catppuccin com FLAVOR=latte;"
[ -z "$faltam" ] \
  && ok "os dois packs declaram o tema do Obsidian, do VS Code e do Heroic, e cada um responde pelo dele" \
  || falha "o bloco apps da P55 não responde como declarado:$faltam"

faltam=""
for app in obsidian vscode; do
  url="$(valor55 dracula "$app.origem.url")"; sha="$(valor55 dracula "$app.origem.sha256")"
  [[ "$url" == https://* ]] && [[ "$sha" =~ ^[0-9a-f]{64}$ ]] || faltam+=" $app: url ou sha256 fora da forma ($url $sha);"
  grep -qF "$sha" "$RAIZ/packs/dracula/PROCEDENCIA.md" || faltam+=" $app: o sha256 não está no PROCEDENCIA.md;"
done
pasta="$(valor55 dracula obsidian.origem.pasta)"
[[ "$pasta" =~ ^[A-Za-z0-9_][A-Za-z0-9._-]*$ ]] && [[ "$(valor55 dracula obsidian.origem.url)" == *"/archive/${pasta#obsidian-}.tar.gz" ]] \
  || faltam+=" obsidian: a pasta ($pasta) não é a do commit da URL;"
[ -z "$faltam" ] \
  && ok "o Obsidian e o VS Code do Dracula descem pinados, e o PROCEDENCIA.md traz os dois sha256" \
  || falha "o pino do tema de fora do Dracula:$faltam"

saida="$(app55 dracula vscode-icones.esquema)"
printf '%s\n' "$saida" | grep -qx 'pack=meowsystem' \
  && ok "os ícones de VS Code do Dracula sobem ao Catppuccin pela herança — e o módulo os recusa (temas-de-apps.sh)" \
  || falha "apps.vscode-icones do Dracula não subiu ao Catppuccin, e o teste do módulo deixou de provar a recusa" "$saida"
mortos="$(so_repo python3 "$RAIZ/scripts/pack.py" validar dracula 2>&1; so_repo python3 "$RAIZ/scripts/pack.py" validar meowsystem 2>&1)"
if printf '%s\n' "$mortos" | grep -qE '^ +apps\.'; then
  falha "um campo do bloco apps da P55 caiu no aviso de campo morto" "$mortos"
else
  ok "nenhum campo do bloco apps da P55 é campo morto, no Dracula nem no Catppuccin"
fi

H51="$T/casa-p51"; TD51="$H51/term"; BIN51="$T/bin51"
mkdir -p "$TD51" "$BIN51"
printf '#!/bin/sh\nexit 0\n' > "$BIN51/cosmic-term"; chmod +x "$BIN51/cosmic-term"
term51() {
  env -i PATH="$BIN51:$PATH" HOME="$H51" MEOW_RAIZ="$RAIZ" MEOW_PACKS="$PACKS" \
    MEOW_CONF="$H51/meow.conf" MEOW_ESTADO="$H51/estado" NO_COLOR=1 TERMINAL_DIR="$TD51" \
    PACK="$1" FLAVOR="$2" ACCENT="mauve" TERMINAL_ESQUEMA="${3:-sim}" \
    bash "$RAIZ/scripts/terminal.sh" aplicar 2>&1
}
sel51() { cat "$TD51/syntax_theme_$1" 2>/dev/null; }

saida="$(term51 catppuccin mocha)"
if [ "$(sel51 dark)" = '"Catppuccin Mocha"' ] && [ "$(sel51 light)" = '"Catppuccin Latte"' ]; then
  ok "com o Catppuccin no ar o terminal seleciona Catppuccin Mocha / Catppuccin Latte"
else
  falha "o Catppuccin não selecionou o esquema dele (dark=$(sel51 dark) light=$(sel51 light))" "$saida"
fi
saida="$(term51 dracula dracula)"
if [ "$(sel51 dark)" = '"Dracula"' ] && [ "$(sel51 light)" = '"Alucard"' ] \
   && ! printf '%s\n' "$saida" | grep -q 'NÃO selecionado'; then
  ok "trocar para o Dracula troca a seleção: o nome que o Catppuccin escreveu é do MeowSystem"
else
  falha "a troca de pack deixou o esquema do Dracula instalado e não selecionado (dark=$(sel51 dark))" "$saida"
fi
printf '"Minha Escolha"' > "$TD51/syntax_theme_dark"
saida="$(term51 dracula dracula)"
[ "$(sel51 dark)" = '"Minha Escolha"' ] \
  && ok "um esquema que nenhum pack gera é escolha dela, e fica" \
  || falha "o terminal.sh sobrescreveu uma seleção que não é de pack nenhum" "$saida"
rm -f "$TD51"/*
term51 dracula dracula >/dev/null
saida="$(term51 dracula dracula "nao")"
if [ ! -e "$TD51/color_schemes_dark" ] && [ ! -e "$TD51/syntax_theme_dark" ]; then
  ok "TERMINAL_ESQUEMA=\"nao\" com o Dracula no ar tira o esquema dele"
else
  falha "TERMINAL_ESQUEMA=\"nao\" deixou o esquema do Dracula no terminal" "$saida"
fi

C51="$T/cosmic-p51/com.system76.CosmicComp/v1"; mkdir -p "$C51"
printf '0' > "$C51/leitura_temperatura"; printf '0.00' > "$C51/leitura_textura"
saida="$(env MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_COSMIC_DIR="$T/cosmic-p51" \
  XDG_STATE_HOME="$T/estado-p51" \
  MEOW_PACK_DIR="$RAIZ/packs/dracula" python3 - "$RAIZ" <<'PY' 2>&1
import os, sys
sys.path.insert(0, os.path.join(sys.argv[1], "app"))
import servidor
erros = []
mod = servidor.modulo_pack()
mt = mod.vocabulario("dracula")["mimetypes"]
if mt.get("claros") != ["alucard"]:
    erros.append("os claros do dono do acervo: %r" % mt.get("claros"))
luz = mt.get("luz") or {}
if sorted(luz, key=luz.get) != ["dracula", "alucard"]:
    erros.append("a luz do dono do acervo fora de ordem: %r" % luz)
item = {i["chave"]: i for i in servidor.ler_esquema()}
for chave in ("LEITURA_TEMPERATURA", "LEITURA_TEXTURA"):
    if item[chave]["valendo_agora"] is not None or item[chave]["desligado_agora"] is not True:
        erros.append("%s com 0 na máquina: valendo_agora=%r desligado_agora=%r"
                     % (chave, item[chave]["valendo_agora"], item[chave]["desligado_agora"]))
esquema = servidor.ler_esquema()
vocab = mod.vocabulario("dracula")
servidor._com_o_vocabulario_do_pack(esquema, vocab, {"FLAVOR": "dracula"})
for f in vocab["flavors"]:
    sem = [s for s in mod.SLOTS if (f["nomes_de_cor"].get(s) or s) == s]
    if sem:
        erros.append("%s: cores sem nome em português: %s" % (f["id"], ", ".join(sem)))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "o latte herdado tem a régua do dono, a textura zerada é desligado, e as 26 cores têm nome" \
  || falha "o que a revisão da P51 reprovou voltou" "$saida"

UP56="$T/papirus-folders-p56"; mkdir -p "$UP56/src/64x64/places"
for fl in latte frappe macchiato mocha; do
  for cor in mauve pink blue; do : > "$UP56/src/64x64/places/folder-cat-$fl-$cor-documents.svg"; done
done
saida="$(env -u NOME_TEMA_ICONES MEOW_RAIZ="$RAIZ" MEOW_CONF="$T/meow.conf" MEOW_CAT_FOLDERS="$UP56" \
  MEOW_PACK_DIR="$RAIZ/packs/dracula" python3 - "$RAIZ" <<'PY' 2>&1
import os, subprocess, sys
raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "app"))
import servidor
mod = servidor.modulo_pack()
erros = []
for pack, flavor in (("dracula", "dracula"), ("dracula", "alucard"), ("meowsystem", "latte")):
    esquema = servidor.ler_esquema()
    vocab = mod.vocabulario(pack)
    servidor._com_o_vocabulario_do_pack(esquema, vocab, {
        "FLAVOR": flavor, "ICONES_PASTAS": "cat-%s-mauve" % flavor})
    molde = {i["chave"]: i for i in esquema}["ICONES_PASTAS"]["molde_pastas"]
    ids = sorted(f["id"] for f in vocab["flavors"])
    ofertas = sorted(v["valor"] for v in molde["variantes"][1:])
    if ofertas != ids:
        erros.append("%s: as variantes são %r, e o pack tem %r" % (pack, ofertas, ids))
    if molde["fora_do_papirus"]:
        erros.append("%s/%s: a página ainda diz que a pasta sai na variante escura (%r)"
                     % (pack, flavor, molde["fora_do_papirus"]))
    do_fl = next(f for f in vocab["flavors"] if f["id"] == flavor)
    nomes = servidor._nomes_de_cor(dict(zip(mod.SLOTS[:14], do_fl["cores"])))
    for c in molde["cores"][1:]:
        if c["rotulo"].lower() != nomes[c["valor"]]:
            erros.append("%s/%s: %s se chama %r, e a cor que a pasta recebe é %r"
                         % (pack, flavor, c["valor"], c["rotulo"], nomes[c["valor"]]))
esquema = servidor.ler_esquema()
if any(i["chave"] == "ICONES_BASE" for i in esquema):
    erros.append("a ICONES_BASE aposentada voltou a ter cartão no painel")
vocab = mod.vocabulario("dracula")
servidor._com_o_vocabulario_do_pack(esquema, vocab, {
    "FLAVOR": "dracula", "NOME_TEMA_ICONES": "Tema-P56"})
vale = (vocab.get("base_de_icones") or {}).get("vale")
amb_verbo = dict(os.environ, NOME_TEMA_ICONES="Tema-P56")
amb_verbo.pop("ICONES_BASE", None)
verbo = subprocess.run(
    [sys.executable, os.path.join(raiz, "scripts", "pack.py"), "base-icones", "dracula"],
    capture_output=True, text=True, env=amb_verbo).stdout
if vale != "Tema-P56-Base" or "quem=pack" not in verbo:
    erros.append("o painel e o verbo discordam da base: vale=%r, verbo=%r"
                 % (vale, verbo.splitlines()[:1]))
if "NOME_TEMA_ICONES" in os.environ:
    erros.append("o NOME_TEMA_ICONES ficou no ambiente do servidor: %r" % os.environ["NOME_TEMA_ICONES"])
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "«Cor das pastas» oferece os flavors do pack no ar com o nome da cor que a pasta recebe, e a base de ícones lê o nome do tema do conf" \
  || falha "as pastas ou a base de ícones ainda falam do Catppuccin, ou do tema errado" "$saida"
printf 'PACK="%s"\nFLAVOR="%s"\n' "$ID" "$ID" > "$T/ajuda-p56.conf"
nome56="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["nome"])' "$PACK_DIR/pack.json")"
cabeca56="$(amb env MEOW_CONF="$T/ajuda-p56.conf" HOME="$T/casa-ajuda-p56" NO_COLOR=1 \
  "$RAIZ/bin/meow" ajuda 2>&1 | sed -n 2p)"
[ "$cabeca56" = "meow — $nome56 para o COSMIC" ] \
  && ok "o cabeçalho do meow ajuda diz o pack no ar: $cabeca56" \
  || falha "o cabeçalho do meow ajuda não diz o pack no ar ($nome56)" "$cabeca56"

saida="$(amb python3 - "$RAIZ" <<'PY' 2>&1
import os, subprocess, sys
raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "scripts"))
import pack
erros = []
nota = pack.NOTA_DA_CATEGORIA.get("icones.pastas") or ""
if "especiais" not in nota or "papirus-folders" not in nota:
    erros.append("a nota das pastas não diz o que elas vestem: %r" % nota)
for ref in ("dracula", os.environ["ID"]):
    pastas = next((c for c in pack.vocabulario(ref)["categorias"] if c["categoria"] == "pastas"), {})
    if pastas.get("nota") != nota:
        erros.append("%s: o «Mais sobre» não recebe a nota das pastas: %r" % (ref, pastas))
    info = subprocess.run([sys.executable, os.path.join(raiz, "scripts", "pack.py"), "info", ref],
                          capture_output=True, text=True).stdout
    linha = next((l for l in info.splitlines() if l.strip().startswith("icones.pastas")), "")
    if not nota or nota not in linha:
        erros.append("%s: a linha do info não diz o que as pastas vestem: %r" % (ref, linha))
print("\n".join(erros))
sys.exit(1 if erros else 0)
PY
)"; rc=$?
[ "$rc" = "0" ] \
  && ok "as pastas dizem o que o desenho do pack veste, no info" \
  || falha "a tabela ainda diz «pastas: próprio» sem dizer o que o desenho veste" "$saida"

printf 'PACK="%s"\nFLAVOR=""\nACCENT="mauve"\nMODO="escuro"\n' "$ID" > "$T/vazio-p56.conf"
printf 'PACK=""\nFLAVOR=""\nACCENT="mauve"\nMODO="escuro"\n' > "$T/vazio-padrao-p56.conf"
padrao56="$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["paleta"]["flavor_padrao"])' \
  "$(amb python3 "$RAIZ/scripts/pack.py" padrao)/pack.json")"
divergem=""
for par in "vazio-p56:$ID" "vazio-padrao-p56:$padrao56"; do
  conf="$T/${par%%:*}.conf"; quer="${par#*:}"
  shell="$(amb env MEOW_CONF="$conf" HOME="$T/casa-vazio-p56" bash -c '
    . "$MEOW_RAIZ/lib/comum.sh"
    RAIZ="$MEOW_RAIZ"; CONF="$MEOW_CONF_ARQUIVO"; CONF_PADRAO="$MEOW_CONF_PADRAO"
    eval "$(sed -n "/^carregar_conf() {/,/^}/p" "$RAIZ/bin/meow")"
    carregar_conf >/dev/null 2>&1 || exit 9
    printf "%s" "$FLAVOR"' 2>&1)"
  painel="$(amb env MEOW_CONF="$conf" HOME="$T/casa-vazio-p56" python3 -c '
import os, sys
sys.path.insert(0, os.path.join(os.environ["MEOW_RAIZ"], "app"))
import servidor
print((servidor.conf_exportada() or {}).get("FLAVOR", ""))' 2>&1)"
  [ -n "$quer" ] && [ "$shell" = "$quer" ] && [ "$painel" = "$quer" ] \
    || divergem+=" ${par%%:*}: shell '$shell', painel '$painel', o pack diz '$quer';"
done
[ -z "$divergem" ] \
  && ok "com o FLAVOR vazio o shell e o painel caem no flavor_padrao do pack ($ID e $padrao56), como a página" \
  || falha "com o FLAVOR vazio o shell ou o painel não caem no padrão do pack:$divergem"

resultado="$(amb python3 - "$RAIZ" <<'PY'
import hashlib, os, sys
raiz = sys.argv[1]
sys.path.insert(0, os.path.join(raiz, "scripts"))
import pack
def conteudos(pack_id):
    base = os.path.join(raiz, "packs", pack_id, "icones")
    saida = set()
    for pasta, _, arqs in os.walk(base):
        for a in arqs:
            if a.endswith(".svg"):
                saida.add(open(os.path.join(pasta, a), encoding="utf-8", errors="replace").read())
    return saida
proprios = {"dracula": conteudos("dracula"), "meowsystem": conteudos("meowsystem")}
problemas = []
for ident, flavor in (("dracula", "dracula"), ("dracula", "alucard"), ("meowsystem", "mocha")):
    previa = pack.previa_do_pack(ident, flavor)
    outro = "meowsystem" if ident == "dracula" else "dracula"
    if len(previa["dock"]) < 5 or not previa["pasta"]:
        problemas.append(f"{ident}/{flavor}: prévia magra ({len(previa['dock'])} apps)")
    for d in previa["dock"] + [{"app": "pasta", "svg": previa["pasta"]}]:
        if d["svg"] in proprios[outro]:
            problemas.append(f"{ident}/{flavor}: {d['app']} é arte do {outro}")
print("; ".join(problemas) if problemas else "limpo")
PY
)"
[ "$resultado" = "limpo" ] \
  && ok "a prévia do pack só usa arte do próprio pack: o dock e a pasta do Dracula não trazem um traço do meowsystem, e vice-versa" \
  || falha "a prévia do pack misturou arte de outro pack" "$resultado"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "o pack de terceiro é honrado de ponta a ponta"
  exit 0
fi
printf 'FALHOU: %d achado(s)\n' "$falhas" >&2
exit 1
