#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf '  pulado: %s\n' "$*"; }
DEC="$RAIZ/docs/DECISOES.md"
REAL="${SUITE_CASA_REAL:-$HOME}"
ETC_ENV="${DEC_ETC_ENVIRONMENT:-/etc/environment}"
command -v python3 >/dev/null || { echo "pulado: sem python3"; exit 0; }

CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$CASA/.config/meow" "$CASA/.local/state/meowsystem" "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open gsettings dconf busctl gdbus; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
export HOME="$CASA" PATH="$FALSO:$PATH"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MEOW_CONF MEOW_ESTADO \
      DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY

registro() {
  grep -E "^\| $1 \|" "$DEC" | grep -qF -- "$2"
}

cobre() {
  local n="$1" arq="$2" padrao="$3" cod="${4:-}" codpad="${5:-}"
  if ! grep -qE "^\| $n \|" "$DEC"; then falha "$n: a decisão saiu do registro"; return; fi
  if [ -f "$RAIZ/tests/$arq" ] && grep -qxF "  $arq" "$RAIZ/tests/todos.sh" \
     && grep -qE -- "$padrao" "$RAIZ/tests/$arq" \
     && { [ -z "$cod" ] || grep -qE -- "$codpad" "$RAIZ/$cod"; }; then
    ok "$n: tests/$arq prova${cod:+ (e $cod ainda tem o que ela lê)}"
  else
    falha "$n: tests/$arq não está no runner ou perdeu a prova de /$padrao/${cod:+, ou $cod perdeu /$codpad/}"
  fi
}

so_texto() {
  if registro "$1" 'só texto, nada no código a lê'; then ok "$1: dita como só texto no registro, sem prova de código"
  else falha "$1: a linha do registro não diz que é só texto"; fi
}

resolvedor() { python3 - "$RAIZ/scripts" "$@" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import pack
caso = sys.argv[2]
grupos = lambda no_ar="", cadeia=None: pack.acervos_de_icone(no_ar, cadeia)
_tab = os.path.join(os.path.dirname(sys.argv[1]), "packs", "CAMINHOS-DE-ANTES.tsv")
antes_png = [l.split("\t", 1)[0] for l in open(_tab, encoding="utf-8")] if os.path.exists(_tab) else []
def stems(pid):
    return {os.path.basename(a) for g in grupos() if g["pack"] == pid for a in g["arquivos"]}
if caso == "base":
    b = pack.base_de_icones("dracula") or {}
    print("frente=%s" % ("00a230a2" in b.get("url", "")))
    print("atras=%s" % (len(b.get("por_tras", [])) == 1 and "de2a8edd" in b["por_tras"][0]["url"]))
elif caso == "vetores":
    tem = stems("dracula")
    antes = {}
    tab = os.path.join(os.path.dirname(sys.argv[1]), "packs", "CAMINHOS-DE-ANTES.tsv")
    if os.path.exists(tab):
        for l in open(tab, encoding="utf-8"):
            if "\t" in l and not l.startswith("#"):
                k, v = l.rstrip("\n").split("\t", 1)
                antes[k] = v
    for n in sys.argv[3:]:
        if n + ".svg" not in tem and "packs/dracula/icones/biblioteca/feitos-a-mao/%s.svg" % n not in antes:
            print("falta=" + n)
    sem_vetor = sorted(os.path.splitext(os.path.basename(a))[0] for g in grupos()
                       if g["pack"] == "dracula" and g["tipo"] == "png"
                       for a in g["arquivos"]
                       if os.path.splitext(os.path.basename(a))[0] + ".svg" not in tem
                       and not any(k.endswith("/" + os.path.basename(a)) and ("/projetos/" in k or "/versoes/" in k)
                                   for k in antes_png))
    print("png_sem_vetor=" + ",".join(sem_vetor))
elif caso == "seletor":
    for no_ar in ("dracula", "meowsystem"):
        g = grupos(no_ar, pack.cadeia_de_acervo(no_ar))
        print("%s:packs=%s" % (no_ar, ",".join(sorted({x["pack"] for x in g if x["pack"]}))))
        print("%s:primeiro=%s:%s" % (no_ar, g[0]["pack"], g[0]["no_ar"]))
elif caso == "nomes":
    tem = stems("dracula")
    for n in sys.argv[3:]:
        print("%s=%s" % (n, n + ".svg" in tem))
elif caso == "autorais":
    nomes = [os.path.basename(a).lower() for g in grupos() if ":autorais" in g["id"] for a in g["arquivos"]]
    print("proibidos=" + ",".join(sorted(n for n in nomes if "hefesto" in n or "fogstripper" in n)))
PY
}

echo "== D1. a base do Dracula: circle por cima, main por trás"
r="$(resolvedor base 2>&1)"
{ grep -qx 'frente=True' <<< "$r" && grep -qx 'atras=True' <<< "$r"; } \
  && ok "1: o pack pina o circle (00a230a2) na frente e o main (de2a8edd) atrás" \
  || falha "1: a base do Dracula não é circle + main: $r"
registro 1 'As duas' && ok "1: o registro diz «as duas»" || falha "1: a decisão 1 saiu do registro"

echo "== D2. os PNG feitos à mão viraram vetor, e nenhum PNG ficou sem o vetor"
nomes39="Antigravity box-buddy calculadora calendario camera cheese citrix clapper Clapper com.system76.CosmicSettings dbeaver demo-general2018 discord Easy-Effects edge FileZilla firefox flatseal gerenciador-de-extensoes gerenciador-de-menu gimp-48 gimp gnome-folder gparted gradia Heroic-Games-Launcher hplj1020 krita linux-toys obsidian obs-studio opera spotify Tweaks visualizador-de-imagens vscode warehouse weylus whatsapp"
r="$(resolvedor vetores $nomes39 2>&1)"
grep -q '^falta=' <<< "$r" && falha "2: vetor dos feitos à mão que sumiu do pack Dracula: $(grep '^falta=' <<< "$r" | tr '\n' ' ')" \
  || ok "2: os 39 vetores dos feitos à mão estão no pack Dracula"
[ "$(grep '^png_sem_vetor=' <<< "$r")" = "png_sem_vetor=" ] \
  && ok "2: nenhum PNG do pack ficou sem o vetor ao lado" || falha "2: PNG sem vetor: $(grep '^png_sem_vetor=' <<< "$r")"

echo "== D3. o seletor mostra só o acervo do pack em edição"
r="$(resolvedor seletor 2>&1)"
bom=1
for no_ar in dracula meowsystem; do
  grep -qx "$no_ar:packs=$no_ar" <<< "$r" || bom=0
  grep -qx "$no_ar:primeiro=$no_ar:True" <<< "$r" || bom=0
done
[ "$bom" = 1 ] && ok "3: com um pack em edição: só o acervo dele aparece, e o do outro nunca" \
  || falha "3: o seletor mistura acervos de packs: $r"
registro 3 'só o acervo do pack em edição' && registro 3 '26/10' \
  && ok "3: o registro diz «só o acervo do pack em edição», com o sim de 26/10" \
  || falha "3: a decisão 3 do registro não cita o acervo do pack em edição e o sim de 26/10"

echo "== D4. calcdeirao fica fora; jogos, rede e clima2 entram"
r="$(resolvedor nomes jogos rede clima2 2>&1)"
{ grep -qx 'jogos=True' <<< "$r" && grep -qx 'rede=True' <<< "$r" && grep -qx 'clima2=True' <<< "$r"; } \
  && ok "4: jogos, rede e clima2 estão no pack Dracula" || falha "4: jogos, rede ou clima2 saíram do pack: $r"
fora="$(find "$RAIZ/packs" \( -iname '*calcdeirao*' -o -iname '*caldeirao*' \) -print -quit)"
{ [ -z "$fora" ] && ! grep -rIliE 'calcdeirao|caldeir[aã]o' "$RAIZ/packs" --include='*.map' --include='pack.json' >/dev/null; } \
  && ok "4: nada do Caldeirão no pack (nome de arquivo, mapa, pack.json)" || falha "4: projeto pessoal dentro do pack: $fora"

echo "== D5. askpass ativo, e a senha nunca em arquivo do projeto"
if [ -d /usr/local/lib/aurora ]; then
  A=/usr/local/lib/aurora/askpass; S="$REAL/.config/zsh/.aurora-askpass-secret"
  [ -x "$A" ] && grep -qx "SUDO_ASKPASS=$A" "$ETC_ENV" \
    && ok "5: o askpass da Aurora é executável e está no /etc/environment" \
    || falha "5: o askpass não está ativo (executável em $A e SUDO_ASKPASS no /etc/environment)"
  [ "$(stat -c %a "$S" 2>/dev/null)" = "600" ] && [ -s "$S" ] \
    && ok "5: o arquivo do askpass é 600 e não está vazio" || falha "5: o arquivo do askpass não é 600 ou está vazio"
else
  pula "sem /usr/local/lib/aurora: esta não é a máquina de quem usa"
fi
if git -C "$RAIZ" ls-files 2>/dev/null | grep -qiE 'askpass-secret|\.secret$'; then
  falha "5: arquivo de segredo versionado: $(git -C "$RAIZ" ls-files | grep -iE 'askpass-secret|\.secret$' | head -2)"
else
  ok "5: nenhum arquivo de segredo versionado"
fi
registro 5 'askpass ativa' && ok "5: o registro diz «askpass ativa»" || falha "5: a decisão 5 saiu do registro"

echo "== D6. a GPU do compositor na placa dedicada"
if [ -d /usr/local/lib/aurora ]; then
  dedicada="$(bash "$RAIZ/scripts/gpu_compositor.sh" detectar 2>/dev/null)"
  atual="$(sed -n 's/^COSMIC_RENDER_DEVICE="\(.*\)"$/\1/p' "$ETC_ENV" | head -n1)"
  if [ -n "$dedicada" ]; then
    [ "$atual" = "$dedicada" ] \
      && ok "6: COSMIC_RENDER_DEVICE do /etc/environment é a placa dedicada desta máquina ($dedicada)" \
      || falha "6: a GPU do compositor não está na dedicada ($dedicada): o /etc/environment diz '${atual:-ausente}'; sem sim explícito de quem usa, ninguém reverte (GSD.md §1)"
  else
    [ -z "$atual" ] \
      && ok "6: uma GPU só: o /etc/environment não tem COSMIC_RENDER_DEVICE" \
      || falha "6: uma GPU só e o /etc/environment tem COSMIC_RENDER_DEVICE='$atual'"
  fi
else
  pula "sem /usr/local/lib/aurora: esta não é a máquina de quem usa"
fi
registro 6 'GPU_COMPOSITOR' && registro 6 '28/10' && ok "6: o registro guarda a chave e o aval de 28/10" || falha "6: a decisão 6 saiu do registro"
grep -q '^GPU_COMPOSITOR="dedicada"' "$RAIZ/meow.conf.exemplo" && grep -q 'etapa_compositor etapa_gpu ' "$RAIZ/install.sh" \
  && ok "6: a fábrica é a dedicada e o instalador tem a etapa" || falha "6: a decisão 6 perdeu a chave de fábrica ou a etapa"

echo "== o shim do compositor ligado (ESTADO.md de 15/10), no HOME de brinquedo"
grep -q '^COMPOSITOR="sim"' "$RAIZ/meow.conf.exemplo" && grep -qE 'etapa_extensoes etapa_compositor ' "$RAIZ/install.sh" \
  && ok "de fábrica COMPOSITOR=sim, e o install tem a etapa que liga o shim" \
  || falha "o shim do compositor deixou de ser de fábrica: falta COMPOSITOR=\"sim\" ou a etapa_compositor"
NO_COLOR=1 "$RAIZ/scripts/compositor_patches.sh" ativar >/dev/null 2>&1
[ -x "$CASA/.local/bin/cosmic-comp" ] && grep -q 'MEOW-COSMIC-COMP-SHIM-1' "$CASA/.local/bin/cosmic-comp" \
  && ok "ligar o compositor põe o shim do MeowSystem em ~/.local/bin/cosmic-comp" \
  || falha "ligar o compositor não pôs o shim em ~/.local/bin/cosmic-comp"
rm -f "$CASA/.local/bin/cosmic-comp"

echo "== D7. o «Consertar» do doctor baixa com o selo, sem caixa de pergunta"
r="$(python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
a = servidor.ACOES["doctor_consertar"]
print("rede=%s confirma=%s" % (a.get("rede"), a.get("confirma")))
PY
)"
[ "$r" = "rede=True confirma=False" ] && ok "7: doctor_consertar declara rede e não pergunta" || falha "7: o doctor_consertar mudou: $r"

echo "== D8. o QA do painel recusa o HOME da conta"
mkdir -p "$T/falso-getent"
printf '#!/bin/sh\nprintf "%%s:x:1000:1000::%%s:/bin/bash\\n" "$(id -un)" "%s"\n' "$CASA" > "$T/falso-getent/getent"
chmod 755 "$T/falso-getent/getent"
timeout 20 env -i PATH="$T/falso-getent:$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
  MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe \
  "$RAIZ/app/run.sh" --sem-abrir > "$T/qa.log" 2>&1; rc=$?
{ [ "$rc" = 2 ] && grep -q recusado "$T/qa.log" && ! grep -q 'http://127' "$T/qa.log"; } \
  && ok "8: o run.sh --sem-abrir recusa o HOME da conta sem MEOW_QA_HOME_REAL=1" \
  || falha "8: o painel subiu para QA com o HOME da conta (rc=$rc): $(tail -2 "$T/qa.log")"

echo "== D9. pack importado não instala extensão sozinho; pack do repositório não precisa de gesto"
P9="$T/packs"; mkdir -p "$P9/noite"
cp "$RAIZ/packs/dracula/logo.svg" "$P9/noite/"
python3 - "$RAIZ/packs/dracula/paleta.json" "$P9/noite/paleta.json" <<'PY'
import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
d["nomes"] = {"dracula": "Noite", "alucard": "Noite Claro"}
json.dump(d, open(sys.argv[2], "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
printf '{"formato": 1, "id": "noite", "nome": "Noite", "heranca": "catppuccin",
 "paleta": {"arquivo": "paleta.json", "flavor_padrao": "dracula"}, "vitrine": {"capa": "logo.svg"},
 "apps": {"vscode": {"esquema": "Noite Escura", "origem": {"extensao": "noite.tema-noite",
   "url": "https://exemplo.invalid/noite.vsix", "sha256": "%s"}}}}\n' "$(printf 'x' | sha256sum | cut -d' ' -f1)" > "$P9/noite/pack.json"
extensoes() {
  printf 'PACK="%s"\nFLAVOR="dracula"\n' "$1" > "$T/ext.conf"
  env -i PATH="$PATH" HOME="$CASA" XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$P9" \
      MEOW_ESTADO="$T/estado9" MEOW_CONF="$T/ext.conf" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
print("lista=" + ",".join(servidor.PROVEDORES["extensoes_de_terceiro"]()))
PY
}
[ "$(extensoes noite)" = "lista=noite.tema-noite" ] && ok "9: o pack importado pede a extensão por nome, para o gesto" \
  || falha "9: o pack importado não aparece como pedido de gesto: $(extensoes noite)"
[ "$(extensoes dracula)" = "lista=" ] && ok "9: o pack do repositório não pede gesto nenhum" \
  || falha "9: o pack do repositório pede gesto: $(extensoes dracula)"

echo "== D10. «Restaurar ao padrão» grava o valor de fábrica e só nasce quando o valor difere"
if command -v node >/dev/null; then
  r="$(node - "$RAIZ/app/pagina/app.js" <<'JS' 2>&1
const fs = require("fs"), vm = require("vm");
const src = fs.readFileSync(process.argv[2], "utf8");
const pega = (nome) => {
  const i = src.indexOf("function " + nome + "(");
  if (i < 0) throw new Error("falta a função " + nome);
  let n = 0, j = src.indexOf("{", i);
  for (let k = j; k < src.length; k++) {
    if (src[k] === "{") n++;
    if (src[k] === "}" && --n === 0) return src.slice(i, k + 1);
  }
};
const gravados = [];
const ctx = { gravados, rotuloDeValor: (v) => v, icone: () => null,
  elemento: (_t, atrib) => atrib };
vm.createContext(ctx);
for (const f of ["padraoDe", "temOQueRestaurar", "botaoPadrao"]) vm.runInContext(pega(f), ctx);
const item = { chave: "X", aceita_vazio: true, padrao: "nao" };
const t = (c) => vm.runInContext(c, Object.assign(ctx, { item }));
console.log("nasce_diferente=" + t('temOQueRestaurar(item, "sim")'));
console.log("nao_nasce_no_padrao=" + !t('temOQueRestaurar(item, "nao")'));
console.log("nasce_vazio_com_fabrica_preenchida=" + t('temOQueRestaurar(item, "")'));
const b = t('botaoPadrao(item, (v) => { gravados.push(v); return true; })');
b.onclick();
console.log("grava=" + gravados.join("|"));
JS
)"
  { grep -qx 'nasce_diferente=true' <<< "$r" && grep -qx 'nao_nasce_no_padrao=true' <<< "$r" \
    && grep -qx 'nasce_vazio_com_fabrica_preenchida=true' <<< "$r" && grep -qx 'grava=nao' <<< "$r"; } \
    && ok "o botão grava item.padrao e só aparece quando o valor difere dele" \
    || falha "o «Restaurar ao padrão» mudou: $r"
else
  pula "sem node: a regra do botão não roda aqui"
fi

registro 10 'grava na hora' && registro 10 'sim de 26/10' && ok "10: o registro diz que o restaurar grava na hora, com o sim de 26/10" \
  || falha "a decisão 10 não diz que grava na hora"

echo "== D18. os ajustes gravam ao soltar; toda ação mostra a linha de progresso, sem janela de resultado nem ensaio"
registro 18 'sim de 26/10' && registro 18 'a barra só desfaz' && ok "18: o registro diz o grava-ao-soltar, com o sim de 26/10" \
  || falha "a decisão 18 não diz o grava-ao-soltar"
registro 18 'sim de 10/11' && registro 18 'linha de progresso' && ok "18: o registro diz a linha de progresso, com o sim de 10/11" \
  || falha "a decisão 18 não diz a linha de progresso com o sim de 10/11"
if grep -q 'id="bt-aplicar"\|id="botao-ensaiar"' "$RAIZ/app/pagina/index.html"; then
  falha "a barra de cima voltou a ter «Aplicar» ou «Ver sem mudar»"
else
  ok "a barra de cima não tem «Aplicar» nem «Ver sem mudar»"
fi
if grep -q 'id="resultado"\|id="confirmar-ensaio"\|id="ensaio-rodar"' "$RAIZ/app/pagina/index.html"; then
  falha "a janela de resultado ou o «Ver sem mudar» voltou ao painel"
else
  ok "o painel não tem janela de resultado nem «Ver sem mudar»"
fi
grep -q 'id="progresso"' "$RAIZ/app/pagina/index.html" && grep -q 'id="parar"' "$RAIZ/app/pagina/index.html" \
  && ok "a linha de progresso, com o Parar, está no header" || falha "a linha de progresso ou o Parar sumiu do header"

echo "== D11. a interface nunca pede senha (revoga a caixa do sudo de uma linha, sim de 23/10)"
registro 11 'a interface nunca pede senha' && ok "11: o registro diz a revogação, com o sim" || falha "a decisão 11 não diz a revogação no registro"
r="$(python3 - "$RAIZ/app/pagina" <<'PY' 2>&1
import glob, os, re, sys
texto = "\n".join(open(f, encoding="utf-8").read() for f in sorted(glob.glob(os.path.join(sys.argv[1], "*")))
                  if f.endswith((".js", ".html")))
texto = re.sub(r"/\*.*?\*/|<!--.*?-->", "", texto, flags=re.S)
print("campo_de_senha=%s" % bool(re.search(r"""type[=:]\s*["']password""", texto)))
print("pkexec=%s" % ("pkexec" in texto))
print("selo_pede_senha=%s" % bool(re.search(r"pede senha", texto, re.I)))
app = open(os.path.join(sys.argv[1], "app.js"), encoding="utf-8").read()
m = re.search(r"async function semPonte\(\) \{(.*?)\n\}\n", app, re.S)
print("sem_ponte_conserta=%s" % bool(m and 'doctor_consertar' in m.group(1)))
print("root_sem_ponte=%s" % bool(re.search(r"deRoot\(acao\) && !ESQUEMA\.ponte", app)))
PY
)"
{ grep -qx 'campo_de_senha=False' <<< "$r" && grep -qx 'pkexec=False' <<< "$r" && grep -qx 'selo_pede_senha=False' <<< "$r" \
  && grep -qx 'sem_ponte_conserta=True' <<< "$r" && grep -qx 'root_sem_ponte=True' <<< "$r"; } \
  && ok "nenhum campo de senha, pkexec ou selo «pede senha»; sem a ponte, o painel oferece o conserto" \
  || falha "a interface voltou a pedir senha: $r"

reparo="$(sed -n '/^fix_ponte() {/,/^}/p' "$RAIZ/bin/meow")"
{ registro 11 'Não quero recolocar senha direto' \
  && grep -qF 'action.lookup("verb") == "start"' "$RAIZ/assets/ponte/49-meowsystem-ponte-reparo.rules" \
  && grep -q 'systemctl start --no-ask-password' <<< "$reparo" && ! grep -qE 'pkexec|sudo -v' <<< "$reparo"; } \
  && ok "11: o reparo da ponte também não pede senha (a extensão de 24/10, com a frase)" \
  || falha "11: o registro não diz a extensão, ou o reparo da ponte pede senha"

echo "== D12. trocar de pack leva o ponteiro do pack"
conf() {
  local arq="$1"; shift
  cp "$RAIZ/meow.conf.exemplo" "$arq"
  python3 - "$arq" "$@" <<'PY'
import re, sys
arq, pares = sys.argv[1], sys.argv[2:]
t = open(arq, encoding="utf-8").read()
for par in pares:
    k, v = par.split("=", 1)
    t, n = re.subn(r"(?m)^%s=.*$" % re.escape(k), lambda m: "%s=%s" % (k, v), t)
    if not n:
        t += "\n%s=%s\n" % (k, v)
open(arq, "w", encoding="utf-8").write(t)
PY
}
C12="$CASA/.config/meow/meow.conf"
conf "$C12" 'PACK="dracula"' 'FLAVOR="dracula"' 'CURSOR="Dracula-Cursor"'
env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 XDG_CONFIG_HOME="$CASA/.config" \
    XDG_STATE_HOME="$CASA/.local/state" "$RAIZ/bin/meow" pack usar meowsystem --sem-aplicar >/dev/null 2>&1
[ "$(grep -E '^CURSOR=' "$C12" | tail -n1)" = 'CURSOR="catppuccin-mocha-light"' ] \
  && ok "12: Dracula -> Catppuccin: o ponteiro vira o do pack novo" || falha "12: o ponteiro não acompanhou o pack: $(grep -E '^CURSOR=' "$C12" | tail -n1)"

echo "== 13 a 17. o registro guarda as cinco, com a frase que as identifica"
registro 13 'Joga tudo pro pack' && registro 13 'Tudo entra no pack' && ok "13: tudo entra no pack" || falha "a decisão 13 saiu do registro"
registro 14 'Três pastas por pack' && ok "14: três pastas por pack" || falha "a decisão 14 saiu do registro"
registro 15 'se atualiza sozinho' && ok "15: o derivado se atualiza sozinho" || falha "a decisão 15 saiu do registro"
registro 16 'Os achados da varredura' && ok "16: os achados da varredura" || falha "a decisão 16 saiu do registro"
registro 13 'Os projetos pessoais entram no Dracula' && registro 13 'Uma versão por ícone' \
  && ok "13: uma versão por ícone, e os projetos pessoais entram no Dracula (sim de 23/10)" \
  || falha "a decisão 13 não diz a troca de 23/10"
registro 16 'sim explícito de 23/10' \
  && ok "16 (3): o Citrix veste o desenho escolhido em 23/10, com o sim citado" \
  || falha "a decisão 16 (3) não diz o sim de 23/10 sobre o Citrix"
for n in Ubuntu-selfservice Ubuntu-wfica Ubuntu-receiver; do
  a="$(python3 "$RAIZ/scripts/pack.py" fonte "$n" dracula 2>/dev/null | cut -f2)"
  [ -n "$a" ] && [ -f "$RAIZ/$a" ] && cmp -s "$RAIZ/$a" "$RAIZ/packs/dracula/icones/apps/Ubuntu-selfservice.svg" \
    || { falha "16 (3): $n não veste o desenho do Citrix escolhido em 23/10 ($a)"; continue; }
done
ok "16 (3): os nomes do Citrix vestem o mesmo desenho, o escolhido em 23/10"
for n in com.beholder.app elden-ring-tracker protocolo-ouroboros; do
  python3 "$RAIZ/scripts/pack.py" fonte "$n" dracula >/dev/null 2>&1 \
    && ok "13: $n veste o desenho dele no Dracula" || falha "13: $n não veste desenho no Dracula"
done
registro 17 'AGENTS.md' && ok "17: o AGENTS.md é exceção do sanitizador" || falha "a decisão 17 saiu do registro"
cobre 14 acervo-da-ficha.sh 'as três pastas são planas'
cobre 15 derivados.sh 'o SVG editado chegou ao tema instalado'
cobre 15 derivados.sh 'salvar de novo o mesmo conteúdo não escreve nada'
git -C "$RAIZ" ls-files --error-unmatch AGENTS.md >/dev/null 2>&1 \
  && ok "17: o AGENTS.md está versionado" || falha "17: o AGENTS.md saiu do repositório"
r="$(resolvedor autorais 2>&1)"
[ "$r" = "proibidos=" ] && ok "29: hefesto e fogstripper fora dos autorais dos packs" || falha "29: projeto pessoal nos autorais: $r"
c="$(grep -E '^LANCADOR_OCULTAR=' "$RAIZ/meow.conf.exemplo" | head -1)"
grep -qiE 'google-chrome|steam|github-desktop' <<< "$c" \
  && falha "30: o lançador de fábrica volta a esconder Chrome, Steam ou github-desktop" \
  || ok "30: o lançador de fábrica não esconde Chrome, Steam nem github-desktop"
grep -qxF 'NOME_TEMA_ICONES="MeowSystem-Icons"' "$RAIZ/meow.conf.exemplo" \
  && ok "36: o tema instalado continua MeowSystem-Icons" || falha "36: o nome do tema instalado mudou"
python3 - "$RAIZ/scripts/migrar_conf.py" <<'PY' && ok "ICONES_BASE: aposentada no migrar, sem linha ativa no exemplo" || falha "ICONES_BASE voltou: aposentada fora do migrar_conf.py ou com linha ativa no exemplo"
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
exemplo = open(sys.argv[1].replace("scripts/migrar_conf.py", "meow.conf.exemplo"), encoding="utf-8").read()
sys.exit(0 if re.search(r'APOSENTADAS = \{[^}]*"ICONES_BASE"', src) and not re.search(r"(?m)^ICONES_BASE=", exemplo) else 1)
PY
if grep -qE 'NOPASSWD|sudo -n -l|sudo -l' "$RAIZ/bin/meow"; then
  falha "43: o doctor volta a avisar do NOPASSWD ou a listar as regras do sudo"
else
  ok "43: o doctor não avisa do NOPASSWD nem lista as regras do sudo"
fi

echo "== os princípios, cada um com o teste que o cobra dentro do runner"
for t in nada-manda-digitar.sh pack-malicioso.sh convergencia.sh doctor-so-le.sh; do
  { [ -x "$RAIZ/tests/$t" ] && grep -qE "^  $t( |$)" "$RAIZ/tests/todos.sh"; } \
    && ok "$t existe e está no runner" || falha "$t saiu do runner (princípio sem prova)"
done
{ grep -qE '^  app-uso-real.py$' "$RAIZ/tests/todos.sh" && grep -q 'texto corrido com' "$RAIZ/tests/app-uso-real.py" \
  && grep -qE '140' "$RAIZ/tests/app-uso-real.py"; } \
  && ok "nenhuma frase longa na tela: o gate app-uso-real.py é obrigatório (teto de 140)" \
  || falha "o gate de frase longa saiu do runner ou perdeu o teto"
r="$(cd "$RAIZ" && git ls-files -z | xargs -0 python3 scripts/comentarios.py conferir 2>&1)" \
  && ok "zero comentário no código versionado" || falha "voltou comentário: $(head -n3 <<< "$r" | tr '\n' ' ')"

echo "== o GSD.md carrega as regras e cita as decisões"
G="$RAIZ/GSD.md"
tem() { [ -f "$G" ] && grep -qF -- "$1" "$G"; }
[ -f "$G" ] && ok "GSD.md na raiz" || falha "falta o GSD.md na raiz"
{ tem 'Decisão de quem usa só se desfaz com sim explícito sobre aquele tema' && tem 'Frase genérica não autoriza'; } \
  && ok "a regra do sim explícito está escrita" || falha "o GSD.md perdeu a regra do sim explícito"
tem 'Zero comentário; o porquê mora no nome, no teste e no commit' \
  && ok "a regra do zero comentário está escrita" || falha "o GSD.md perdeu a regra do zero comentário"
tem 'docs/DECISOES.md' && ok "o GSD.md cita o registro" || falha "o GSD.md não cita o docs/DECISOES.md"
n="$(grep -cE '^\| [0-9]+ \|' "$DEC")"
[ "$n" -ge 26 ] && [ "$(grep -oE '^\| [0-9]+ \|' "$DEC" | tr -dc '0-9\n' | paste -sd' ')" = "$(seq -s' ' 1 "$n")" ] \
  && ok "o registro numera as $n decisões de 1 a $n, uma linha cada" || falha "o registro pulou ou repetiu número"
velhos="$(grep -lE '02-decisoes\.md|P82-abertos\.md' "$RAIZ/AGENTS.md" "$G" "$RAIZ"/docs/*.md "$RAIZ"/docs/sprints/*/*.md "$RAIZ"/tests/* "$RAIZ"/packs/*/*.md 2>/dev/null | grep -v '/tests/decisoes\.sh$')"
[ -z "$velhos" ] && ok "ninguém aponta para os registros antigos" || falha "ainda aponta para o registro antigo: $velhos"
faltam=""
for k in 'Teste nunca chama `sudo` de verdade' 'HOME temporário' 'troca palavras' '/tmp' 'Senha nunca'; do tem "$k" || faltam+=" «$k»"; done
[ -z "$faltam" ] && ok "as armadilhas estão no GSD.md" || falha "o GSD.md perdeu a armadilha:$faltam"
tem 'NOPASSWD' && falha "a armadilha do sudo ainda depende da regra NOPASSWD, que sai das máquinas" || ok "a armadilha do sudo vale sem a regra NOPASSWD"

[ -f "$RAIZ/packs/meowsystem/mascote/coquinha.svg" ] && [ -f "$RAIZ/packs/meowsystem/mascote/mimir.svg" ] \
  && [ "$(ls "$RAIZ"/packs/dracula/mascote/morcego*.svg 2>/dev/null | wc -l)" = 3 ] && ! ls -d "$RAIZ"/assets/gat[o]s >/dev/null 2>&1 \
  && [ "$(python3 "$RAIZ/scripts/pack.py" mascote-padrao dracula dia)" = morcego-dia ] \
  && ok "19: cada pack tem o seu mascote, e o de fábrica do Dracula é o morcego" \
  || falha "19: o mascote não mora no pack, ou o Dracula não tem o morcego de fábrica"
[ -x "$RAIZ/scripts/terminal_bloco.sh" ] && grep -q 'etapa_bloco_terminal' "$RAIZ/install.sh" \
  && grep -q '^_excecao_do_zshrc' "$RAIZ/scripts/terminal_bloco.sh" && grep -q 'MEOW_EXCECOES_LOCAIS' "$RAIZ/lib/comum.sh" \
  && grep -q 'terminal_bloco.sh" remover' "$RAIZ/lib/desinstalar.sh" \
  && [ "$(grep -c '^item	spellbook-terminal-' "$RAIZ/assets/contratos/vizinhos.tsv")" = 3 ] \
  && ok "20: o bloco do terminal é do MeowSystem, e o do Spellbook sai pelo vizinhos.tsv" \
  || falha "20: falta o bloco do terminal, a remoção dele ou os itens do Spellbook"
faltam=""
for p in build-essential pkgconf libxkbcommon-dev libwayland-dev libdbus-1-dev libudev-dev; do
  grep -qxF "applets	$p" "$RAIZ/assets/pacotes/compilar.tsv" || faltam+=" $p"
done
for p in just cmake libinput-dev libseat-dev libdisplay-info-dev; do
  grep -qxF "compositor	$p" "$RAIZ/assets/pacotes/compilar.tsv" || faltam+=" $p"
done
grep -q 'meow_pacotes_de_compilar_faltando' <(sed -n '/^etapa_pacotes()/,/^}/p' "$RAIZ/install.sh") \
  || faltam+=" (a etapa_pacotes não lê a lista)"
[ -z "$faltam" ] && grep -q 'ppa:zhangsongcui3371/fastfetch' "$RAIZ/install.sh" \
  && ok "21: o instalador declara o que os applets e o compositor compilam e o PPA do fastfetch" \
  || falha "21: falta dependência declarada:${faltam:- o PPA do fastfetch}"
grep -q 'git clone https://github.com/vitoriamariadb/MeowSystem.git' "$RAIZ/README.md" \
  && ok "22: o README manda baixar de vitoriamariadb/MeowSystem" || falha "22: o README não aponta para vitoriamariadb/MeowSystem"
registro 22 'vitoriamariadb/MeowSystem' && ok "22: o registro guarda o repositório da casa" \
  || falha "a decisão 22 saiu do registro"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d["origens"]["wallpapers"].get("repo") else 1)' \
    "$RAIZ/packs/meowsystem/pack.json" 2>/dev/null && ! grep -q 'meow wallpaper semear  ' "$RAIZ/install.sh" \
  && ok "23: a origem dos papéis de parede é do pack, e o install não manda digitar" \
  || falha "23: o pack não declara a origem dos papéis de parede, ou o install manda semear"
[ ! -e "$RAIZ/docs/folhas" ] && [ ! -e "$RAIZ/docs/pesquisas" ] && [ ! -e "$RAIZ/scripts/icones_apps.sh" ] \
  && ! grep -rqs 'catppuccin-apps' "$RAIZ/install.sh" "$RAIZ/bin/meow" "$RAIZ/scripts" \
  && ok "24: as folhas, a pesquisa bruta e a etapa morta saíram" \
  || falha "24: voltou folha, pesquisa bruta ou a etapa do catppuccin-apps"
citas="$(git -C "$RAIZ" grep -nE 'docs/pesquisas/[0-9A-Za-z]' -- . ':!docs/sprints' ':!tests/decisoes.sh' 2>/dev/null \
  | grep -vE '(git show [0-9a-f^]+|arquivo):docs/pesquisas/' || true)"
[ -z "$citas" ] \
  && ok "24: nenhum arquivo cita docs/pesquisas/ sem o git show da ponta antiga" \
  || falha "24: cita docs/pesquisas/ sem o git show 1b15ccb1^: $(printf '%s\n' "$citas" | head -2)"
alheias="$(python3 "$RAIZ/scripts/pack.py" colecoes-alheias "$RAIZ/packs/dracula")"
grep -qx "prefixo	cat" <<< "$alheias" \
  && grep -q 'PACK_ATIVOS=' "$RAIZ/scripts/wallpaper.sh" \
  && ok "25: o papel de parede de outro pack não gira (o Catppuccin é alheio com o Dracula no ar)" \
  || falha "25: o wallpaper.sh não separa a coleção do pack no ar"
grep -q '"$MEOW_RAIZ/scripts/prompt.sh" instalar$' "$RAIZ/install.sh" \
  && ok "26: o starship desce com o install" || falha "26: a etapa do prompt não instala o starship"
registro 46 'par_do_outro_lado' && grep -q '^def par_do_outro_lado' "$RAIZ/scripts/derivar_flavor.py" \
  && grep -q 'par_do_outro_lado' "$RAIZ/tests/variante.sh" && grep -q '^  variante.sh$' "$RAIZ/tests/todos.sh" \
  && ok "46: as duas regras do lado vestido passam pelo par_do_outro_lado, e o variante.sh vigia" \
  || falha "46: o lado vestido saiu do registro, do derivar_flavor ou do variante.sh"
n="$(grep -lF '/^_dracula_pares_do_mapa() {' "$RAIZ"/tests/* 2>/dev/null | grep -vc '/decisoes\.sh$')"
registro 47 '_dracula_pares_do_mapa' && grep -q '^_dracula_pares_do_mapa() {$' "$RAIZ/scripts/icones_apps_dracula.sh" \
  && [ "$n" -ge 3 ] && ok "47: o filtro do _dracula_pares_do_mapa fica, e $n testes o extraem verbatim" \
  || falha "47: a função mudou de forma ou saiu do registro ($n testes a extraem)"
registro 48 'ICONES_BASE:-Papirus-Dark' && grep -rqF 'ICONES_BASE:-Papirus-Dark' "$RAIZ/scripts" "$RAIZ/lib" \
  && ok "48: os leitores do ICONES_BASE ficam com o mesmo padrão" || falha "48: a decisão saiu do registro"
registro 49 'cosmic_prever.sh' && grep -q 'SUMIU do' "$RAIZ/scripts/cosmic_prever.sh" \
  && ok "49: o pré-voo acusa a chave que some do binário" || falha "49: o pré-voo não acusa mais a chave que some"
registro 51 'BANIDOS.txt.padrao' && grep -q 'BANIDOS.txt.padrao' "$RAIZ/scripts/wallpaper.sh" \
  && grep -q '^limpar_banidos()' "$RAIZ/scripts/wallpaper.sh" && ! grep -qE 'favoritar|desbanir' "$RAIZ/scripts/wallpaper.sh" \
  && ok "51: o lixo apaga de vez, o checkout perde a receita, e as banidas saem pela etapa" \
  || falha "51: o lixo voltou a mover para banidos/, ou a decisão saiu do registro"
cobre 51 apagar-papel.sh 'banir apaga a imagem com emoji' scripts/wallpaper.sh 'na_fonte'
registro 52 'packs/<id>/' && grep -q '^def motivo_para_nao_aprimorar' "$RAIZ/scripts/pack.py" \
  && grep -q 'href: "#novo/cores"' "$RAIZ/app/pagina/paginas.js" && grep -q '"/api/pack-cores"' "$RAIZ/app/servidor.py" \
  && ok "52: Criar o meu tema gera um tema novo; o Personalizar aprimora o tema no ar" \
  || falha "52: o Criar e o Personalizar voltaram a ser o mesmo fluxo, ou a decisão saiu do registro"
registro 54 'sim de 06/11' && registro 54 'Cria outra build' && [ -x "$RAIZ/scripts/graficos.sh" ] && [ -x "$RAIZ/scripts/portal_shim.sh" ] \
  && [ -f "$RAIZ/patches/graficos.series" ] && [ -f "$RAIZ/patches/graficos.versao" ] \
  && grep -q '^chrome-policy)' "$RAIZ/scripts/ponte_root.sh" && grep -q '^etapa_graficos()' "$RAIZ/install.sh" \
  && ! grep -q 'dmabuf, fixated' "$RAIZ"/patches/xdg-desktop-portal-cosmic-*.patch \
  && ok "54: o portal e a policy do Chrome são uma build própria, com shim, série e verbo na ponte, sem o SHM forçado" \
  || falha "54: falta o script, o shim, a série, o verbo da ponte ou a etapa do portal, ou o SHM forçado entrou"
registro 56 'espaco.tsv' && [ -f "$RAIZ/assets/contratos/espaco.tsv" ] && [ -f "$RAIZ/scripts/espaco.py" ] \
  && grep -q 'espaco.py" continua' "$RAIZ/scripts/extensoes_build.sh" && grep -q '^chk_disco' "$RAIZ/bin/meow" \
  && grep -q 'meow_desinstalar_espaco$' "$RAIZ/lib/desinstalar.sh" && grep -q '"espaco_liberar"' "$RAIZ/app/servidor.py" \
  && ok "56: o MeowSystem tem inventário do que escreve, limpa no fim do build e no doctor, mostra o Espaço e desinstala limpo" \
  || falha "56: o inventário, a limpeza do build, o doctor, a página ou o desinstalador saiu, ou a decisão saiu do registro"
registro 37 'sons/' && grep -q 'som-padrao' "$RAIZ/scripts/ponte_root.sh" && grep -q 'passo_sons' "$RAIZ/scripts/cosmic_pos_apt.sh" \
  && [ -f "$RAIZ/assets/sons/eventos.json" ] \
  && ok "37: os sons do pack vão ao sistema pela ponte, o pós-apt os repõe e a página lista cada evento" \
  || falha "37: a ponte, o pós-apt ou o catálogo de sons saiu"
cobre 27 manter-sem-pendencias.py 'o Manter .* e o Tema não mostram'
cobre 27 apagar-papel.sh 'a devolvida segue em ativos/ sem entrar na lista'
cobre 28 seletor-do-pack.sh 'a escolha sai do estado de quem usa' app/servidor.py '/api/app-icone'
cobre 28 git-limpo.sh 'a linha, o retoque e o construído foram para o estado de quem usa'
cobre 31 pack-dracula-completo.sh 'o Vesktop veste o Discord do pack Dracula' packs/dracula/icones/apps.map 'dev\.vencord\.Vesktop'
cobre 31 pack-dracula-completo.sh 'o traço do Firefox é peach' packs/meowsystem/icones/apps-arcticons.map '^firefox:firefox:peach$'
cobre 32 pack-dracula-completo.sh 'Hidden=true' scripts/construir_icones.sh 'Hidden=true'
cobre 32 pack-dracula-completo.sh 'Tema-Base,Tema-Base-2,Cosmic,Adwaita,hicolor' lib/icones.sh 'Cosmic,Adwaita,hicolor'
cobre 33 pack-dracula-completo.sh 'o Catppuccin não herda a lista' scripts/ocultar_apps.sh 'pack\.py" ocultar'
cobre 34 app.sh 'a noite com uma ponta só é recusada \(409\)' app/servidor.py 'a noite pede as duas pontas'
grep -q 'value: "", texto: "Automático"' "$RAIZ/app/pagina/app.js" && ! grep -q 'não tocar\|⊘' "$RAIZ/app/pagina/app.js" \
  && ok "34: o valor vazio chama «Automático» no painel" \
  || falha "34: o valor vazio do painel mudou de nome"
cobre 35 fonte-unica.sh 'ICONES_DRACULA="nao"' scripts/icones_apps_dracula.sh 'ICONES_DRACULA:-sim\}" = "nao"'
! grep -q 'ICONES_DRACULA' "$RAIZ/scripts/migrar_conf.py" \
  && ok "35: o migrar_conf.py não toca na chave ICONES_DRACULA: o «nao» escrito fica como está" \
  || falha "35: o migrar_conf.py passou a mexer no ICONES_DRACULA"
so_texto 38
cobre 39 pack-dracula-completo.sh 'o pack Dracula não guarda tipo de arquivo pintado nem cópia do molde'
faltam_pasta=""
for pack in meowsystem dracula; do
  [ -n "$(find "$RAIZ/packs/$pack/icones/biblioteca" -maxdepth 1 -iname '*folder*' -print -quit)" ] || faltam_pasta+=" $pack"
done
comuns="$(comm -12 <(ls "$RAIZ/packs/meowsystem/icones/biblioteca" | grep -i folder | sort) \
                   <(ls "$RAIZ/packs/dracula/icones/biblioteca" | grep -i folder | sort) | wc -l)"
[ -z "$faltam_pasta" ] && [ "$comuns" = 0 ] \
  && ok "39: cada pack guarda os desenhos de pasta na biblioteca dele, e nenhum nome se repete nos dois" \
  || falha "39: pasta fora da biblioteca do pack (sem:${faltam_pasta:- nenhum}, repetidos: $comuns)"
so_texto 40
cobre 41 pack-malicioso.sh 'um mapa que aponta para fora recusa o pack inteiro' scripts/pack.py 'def _dentro'
cobre 41 pack-malicioso.sh 'as linhas ruins foram puladas e as boas chegaram ao tema'
cobre 42 sem-dracula-os-theme.sh 'não chama o .pack.py sincronizar' scripts/pack.py 'não é o mesmo tipo de arquivo'
cobre 44 oraculo-tema.sh 'd77e99f Light: só background.component.pressed difere' scripts/oraculo_tema.py 'comparar'
cobre 45 ganchos.sh 'chama o readme.sh --commit' scripts/readme.sh 'commit'
cobre 50 extensoes-gesto.sh 'instalar um repo do usuário: compila, não mexe no EXTENSOES' bin/meow 'EXTENSOES_COMPILAR=1'
cobre 53 areas-em-cada-tela.sh 'a tela do notebook ganha Pop e OS, nessa ordem' scripts/areas.sh 'pinned_workspaces'
cobre 53 nomes-nas-duas-telas.sh 'a cópia não entra no arquivo' patches/cosmic-comp-nomes-nas-duas-telas.patch 'AURORA-AREAS-NOMES-2'
cobre 53 nomes-nas-duas-telas.sh 'a janela volta ao religar' patches/cosmic-comp-nomes-nas-duas-telas.patch 'fn devolver_janelas'
registro 55 'entra sem clique' && ! grep -q 'retido\|liberar' "$RAIZ/scripts/compositor_shim.sh" \
  && ! grep -q 'cmd_liberar\|compositor-caiu' "$RAIZ/scripts/compositor_patches.sh" \
  && ! grep -q 'patch-obrigatorio' "$RAIZ/scripts/garantir_builds.sh" \
  && ! grep -q 'Não encaixa\|Em observação' "$RAIZ/app/pagina/extensoes.js" \
  && ok "55: o build bom entra sem clique, e a queda não vai para a tela" \
  || falha "55: o compositor voltou a esperar o clique, ou a queda voltou à tela"
! grep -qE '^opt[[:space:]]' "$RAIZ/patches/series" \
  && grep -q 'Uniform::new("leitura_atenuacao"' "$RAIZ/patches/cosmic-comp-modo-leitura.patch" \
  && ! grep -q 'Uniform::new("leitura_temp"' "$RAIZ/patches/cosmic-comp-modo-leitura.patch" \
  && ok "P100: a série é toda req (dela, 28/09) e o neutro do modo de leitura é o zero" \
  || falha "P100: voltou patch opt na série, ou o uniform leitura_temp de neutro 1.0"

sem_linha=""; total=0
while read -r n; do
  total=$((total + 1))
  grep -qE "((ok|falha|pula) \"$n( \([0-9]+\))?: |^(cobre|so_texto) $n( |$))" "$RAIZ/tests/decisoes.sh" || sem_linha="$sem_linha $n"
done < <(grep -oE '^\| [0-9]+ \|' "$DEC" | tr -dc '0-9\n')
[ -z "$sem_linha" ] && ok "todas as $total decisões do registro têm linha aqui: decisões sem linha, 0" \
  || falha "decisões sem linha em tests/decisoes.sh:$sem_linha"

echo
if [ "$falhas" = 0 ]; then echo "decisoes: tudo certo"; exit 0; fi
echo "decisoes: $falhas falha(s)"; exit 1
