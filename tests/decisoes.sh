#!/usr/bin/env bash
# decisoes.sh — uma decisão, um teste: desfazer uma decisão de quem usa deixa a suíte vermelha. (P86)
#
# Um caso por decisão de `docs/sprints/2026-10-09-uso-real/02-decisoes.md` (1 a 12,
# e o registro de 13 a 17), por regra do `GSD.md` e por quatro da leva H
# (`P82-abertos.md`, citadas como P82·N porque a numeração colide). O caso prova o
# comportamento quando dá para provar aqui, e o registro quando o código ainda não
# existe (13 a 17 chegam com a P87, a P88 e a P89).
#
# OS ÍCONES SÃO PERGUNTADOS AO RESOLVEDOR (`scripts/pack.py`), nunca a um caminho
# fixo: a P88 muda as pastas dos packs e estes casos têm de sobreviver a ela.
#
# 5 e 6 dependem do que está INSTALADO na máquina de quem usa (askpass, GPU, shim).
# Fora dela (sem `/usr/local/lib/aurora`) cada um sai «pulado» na própria linha; nunca
# lê o conteúdo da senha, só o modo do arquivo.
# Tudo numa casa de brinquedo, com falsos que recusam; nada de sudo, apt nem rede.
#   0 = passou · 1 = falhou
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf '  pulado: %s\n' "$*"; }
DEC="$RAIZ/docs/sprints/2026-10-09-uso-real/02-decisoes.md"
P82="$RAIZ/docs/sprints/2026-10-15-fechamento/P82-abertos.md"
# A casa de verdade só é LIDA (o runner a deixa dita); o HOME deste teste é de brinquedo.
REAL="${SUITE_CASA_REAL:-$HOME}"
ETC_ENV="${DEC_ETC_ENVIRONMENT:-/etc/environment}"   # só a prova de mutação troca isto
command -v python3 >/dev/null || { echo "pulado: sem python3"; exit 0; }

CASA="$T/casa"; FALSO="$T/falso"
mkdir -p "$CASA/.config/meow" "$CASA/.local/state/meowsystem" "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open gsettings dconf busctl gdbus; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
export HOME="$CASA" PATH="$FALSO:$PATH"
unset XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MEOW_CONF MEOW_ESTADO \
      DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY

# O registro tem a linha da decisão N, com a frase que a identifica.
registro() { # $1 N · $2 frase
  grep -E "^\| $1 \|" "$DEC" | grep -qF -- "$2"
}

# Perguntas ao resolvedor de ícones, uma por chamada: imprime o que o caso conta.
resolvedor() { python3 - "$RAIZ/scripts" "$@" <<'PY'
import os, sys
sys.path.insert(0, sys.argv[1])
import pack
caso = sys.argv[2]
grupos = lambda no_ar="": pack.acervos_de_icone(no_ar)
def stems(pid):
    return {os.path.basename(a) for g in grupos() if g["pack"] == pid for a in g["arquivos"]}
if caso == "base":
    b = pack.base_de_icones("dracula") or {}
    print("frente=%s" % ("00a230a2" in b.get("url", "")))
    print("atras=%s" % (len(b.get("por_tras", [])) == 1 and "de2a8edd" in b["por_tras"][0]["url"]))
elif caso == "vetores":
    tem = stems("dracula")
    for n in sys.argv[3:]:
        if n + ".svg" not in tem:
            print("falta=" + n)
    sem_vetor = sorted(os.path.splitext(os.path.basename(a))[0] for g in grupos()
                       if g["pack"] == "dracula" and g["tipo"] == "png" for a in g["arquivos"]
                       if os.path.splitext(os.path.basename(a))[0] + ".svg" not in tem)
    print("png_sem_vetor=" + ",".join(sem_vetor))
elif caso == "seletor":
    for no_ar in ("dracula", "catppuccin"):
        g = grupos(no_ar)
        print("%s:packs=%s" % (no_ar, ",".join(sorted({x["pack"] for x in g if x["pack"]}))))
        print("%s:primeiro=%s:%s" % (no_ar, g[0]["pack"], g[0]["no_ar"]))
        print("%s:motor=%s" % (no_ar, any(not x["pack"] and x["acervo"] == "MeowSystem" for x in g)))
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
  && ok "o pack pina o circle (00a230a2) na frente e o main (de2a8edd) atrás" \
  || falha "a base do Dracula não é circle + main: $r"
registro 1 'As duas' && ok "o registro diz «as duas»" || falha "a decisão 1 saiu do registro"

echo "== D2. os PNG feitos à mão viraram vetor, e nenhum PNG ficou sem o vetor"
nomes39="Antigravity box-buddy calculadora calendario camera cheese citrix clapper Clapper com.system76.CosmicSettings dbeaver demo-general2018 discord Easy-Effects edge FileZilla firefox flatseal gerenciador-de-extensoes gerenciador-de-menu gimp-48 gimp gnome-folder gparted gradia Heroic-Games-Launcher hplj1020 krita linux-toys obsidian obs-studio opera spotify Tweaks visualizador-de-imagens vscode warehouse weylus whatsapp"
r="$(resolvedor vetores $nomes39 2>&1)"
grep -q '^falta=' <<< "$r" && falha "vetor dos feitos à mão que sumiu do pack Dracula: $(grep '^falta=' <<< "$r" | tr '\n' ' ')" \
  || ok "os 39 vetores dos feitos à mão estão no pack Dracula"
[ "$(grep '^png_sem_vetor=' <<< "$r")" = "png_sem_vetor=" ] \
  && ok "nenhum PNG do pack ficou sem o vetor ao lado" || falha "PNG sem vetor: $(grep '^png_sem_vetor=' <<< "$r")"

echo "== D3. o seletor mostra o acervo de todos os packs, o pack no ar primeiro"
r="$(resolvedor seletor 2>&1)"
bom=1
for no_ar in dracula catppuccin; do
  grep -qx "$no_ar:packs=catppuccin,dracula" <<< "$r" || bom=0
  grep -qx "$no_ar:primeiro=$no_ar:True" <<< "$r" || bom=0
  grep -qx "$no_ar:motor=True" <<< "$r" || bom=0
done
[ "$bom" = 1 ] && ok "com qualquer pack no ar: os dois packs e o motor aparecem, o do ar na frente" \
  || falha "o seletor não mostra todos os acervos: $r"

echo "== D4. calcdeirao fica fora; jogos, rede e clima2 entram"
r="$(resolvedor nomes jogos rede clima2 2>&1)"
{ grep -qx 'jogos=True' <<< "$r" && grep -qx 'rede=True' <<< "$r" && grep -qx 'clima2=True' <<< "$r"; } \
  && ok "jogos, rede e clima2 estão no pack Dracula" || falha "jogos, rede ou clima2 saíram do pack: $r"
fora="$(find "$RAIZ/packs" \( -iname '*calcdeirao*' -o -iname '*caldeirao*' \) -print -quit)"
{ [ -z "$fora" ] && ! grep -rIliE 'calcdeirao|caldeir[aã]o' "$RAIZ/packs" --include='*.map' --include='pack.json' >/dev/null; } \
  && ok "nada do Caldeirão no pack (nome de arquivo, mapa, pack.json)" || falha "projeto pessoal dentro do pack: $fora"

echo "== D5. askpass ativo, e a senha nunca em arquivo do projeto"
if [ -d /usr/local/lib/aurora ]; then
  A=/usr/local/lib/aurora/askpass; S="$REAL/.config/zsh/.aurora-askpass-secret"
  [ -x "$A" ] && grep -qx "SUDO_ASKPASS=$A" "$ETC_ENV" \
    && ok "o askpass da Aurora é executável e está no /etc/environment" \
    || falha "o askpass não está ativo (executável em $A e SUDO_ASKPASS no /etc/environment)"
  # Só o modo e o tamanho: o conteúdo nunca é lido.
  [ "$(stat -c %a "$S" 2>/dev/null)" = "600" ] && [ -s "$S" ] \
    && ok "o arquivo do askpass é 600 e não está vazio" || falha "o arquivo do askpass não é 600 ou está vazio"
else
  pula "sem /usr/local/lib/aurora: esta não é a máquina de quem usa"
fi
if git -C "$RAIZ" ls-files 2>/dev/null | grep -qiE 'askpass-secret|\.secret$'; then
  falha "arquivo de segredo versionado: $(git -C "$RAIZ" ls-files | grep -iE 'askpass-secret|\.secret$' | head -2)"
else
  ok "nenhum arquivo de segredo versionado"
fi
registro 5 'askpass ativa' && ok "o registro diz «askpass ativa»" || falha "a decisão 5 saiu do registro"

echo "== D6. a GPU do compositor na RTX"
if [ -d /usr/local/lib/aurora ]; then
  grep -qxF 'COSMIC_RENDER_DEVICE="0x10de:0x25a2"' "$ETC_ENV" \
    && ok "COSMIC_RENDER_DEVICE da RTX ativo no /etc/environment" \
    || falha "a GPU do compositor não está na RTX: sem sim explícito de quem usa, ninguém reverte (GSD.md §1)"
else
  pula "sem /usr/local/lib/aurora: esta não é a máquina de quem usa"
fi
registro 6 '0x10de:0x25a2' && ok "o registro guarda o dispositivo e o aval" || falha "a decisão 6 saiu do registro"

echo "== o shim do compositor ligado (ESTADO.md de 15/10)"
if [ -d /usr/local/lib/aurora ]; then
  [ -x "$REAL/.local/bin/cosmic-comp" ] && grep -q 'MEOW-COSMIC-COMP-SHIM-1' "$REAL/.local/bin/cosmic-comp" \
    && ok "~/.local/bin/cosmic-comp é o shim do MeowSystem" \
    || falha "o shim do compositor está desligado: o cosmic-comp do PATH não é o shim"
else
  pula "sem /usr/local/lib/aurora: esta não é a máquina de quem usa"
fi

echo "== D7. o «Consertar» do doctor baixa com o selo, sem caixa de pergunta"
r="$(python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
a = servidor.ACOES["doctor_consertar"]
print("rede=%s confirma=%s" % (a.get("rede"), a.get("confirma")))
PY
)"
[ "$r" = "rede=True confirma=False" ] && ok "doctor_consertar declara rede e não pergunta" || falha "o doctor_consertar mudou: $r"

echo "== D8. o QA do painel recusa o HOME da conta"
mkdir -p "$T/falso-getent"
printf '#!/bin/sh\nprintf "%%s:x:1000:1000::%%s:/bin/bash\\n" "$(id -un)" "%s"\n' "$CASA" > "$T/falso-getent/getent"
chmod 755 "$T/falso-getent/getent"
timeout 20 env -i PATH="$T/falso-getent:$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
  MEOW_RAIZ="$RAIZ" MEOW_CONF="$CASA/.config/meow/meow.conf" MEOW_PONTE=/nao/existe \
  "$RAIZ/app/run.sh" --sem-abrir > "$T/qa.log" 2>&1; rc=$?
{ [ "$rc" = 2 ] && grep -q recusado "$T/qa.log" && ! grep -q 'http://127' "$T/qa.log"; } \
  && ok "o run.sh --sem-abrir recusa o HOME da conta sem MEOW_QA_HOME_REAL=1" \
  || falha "o painel subiu para QA com o HOME da conta (rc=$rc): $(tail -2 "$T/qa.log")"

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
extensoes() { # $1 PACK
  printf 'PACK="%s"\nFLAVOR="dracula"\n' "$1" > "$T/ext.conf"
  env -i PATH="$PATH" HOME="$CASA" XDG_DATA_HOME="$CASA/.local/share" MEOW_PACKS="$P9" \
      MEOW_ESTADO="$T/estado9" MEOW_CONF="$T/ext.conf" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
print("lista=" + ",".join(servidor.PROVEDORES["extensoes_de_terceiro"]()))
PY
}
[ "$(extensoes noite)" = "lista=noite.tema-noite" ] && ok "o pack importado pede a extensão por nome, para o gesto" \
  || falha "o pack importado não aparece como pedido de gesto: $(extensoes noite)"
[ "$(extensoes dracula)" = "lista=" ] && ok "o pack do repositório não pede gesto nenhum" \
  || falha "o pack do repositório pede gesto: $(extensoes dracula)"

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
const ctx = { gravados, rotuloDeValor: (v) => v,
  elemento: (_t, atrib) => atrib };
vm.createContext(ctx);
for (const f of ["padraoDe", "temOQueRestaurar", "rotuloVazio", "tituloDoRestaurar", "botaoVazio"])
  vm.runInContext(pega(f), ctx);
const item = { aceita_vazio: true, padrao: "nao" };
const t = (c) => vm.runInContext(c, Object.assign(ctx, { item }));
console.log("nasce_diferente=" + t('temOQueRestaurar(item, "sim")'));
console.log("nao_nasce_no_padrao=" + !t('temOQueRestaurar(item, "nao")'));
console.log("nasce_vazio_com_fabrica_preenchida=" + t('temOQueRestaurar(item, "")'));
const botao = t('botaoVazio(item, () => {}, async (v) => { gravados.push(v); return true; })');
botao.onclick().then(() => console.log("grava=" + gravados.join("|")));
JS
)"
  { grep -qx 'nasce_diferente=true' <<< "$r" && grep -qx 'nao_nasce_no_padrao=true' <<< "$r" \
    && grep -qx 'nasce_vazio_com_fabrica_preenchida=true' <<< "$r" && grep -qx 'grava=nao' <<< "$r"; } \
    && ok "o botão grava item.padrao e só aparece quando o valor difere dele" \
    || falha "o «Restaurar ao padrão» mudou: $r"
else
  pula "sem node: a regra do botão não roda aqui"
fi

echo "== D11. a caixa do sudo tem uma linha; o porquê fica na dica"
r="$(python3 - "$RAIZ/app/pagina/app.js" <<'PY' 2>&1
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
m = re.search(r"function caixaDoSudo\(\) \{(.*?)\n\}\n", src, re.S)
corpo = m.group(1) if m else ""
fortes = re.findall(r'elemento\("strong", \{ texto: "([^"]+)" \}\)', corpo)
print("linha=%s" % (len(fortes) == 1 and len(fortes[0]) <= 60))
print("porque_na_dica=%s" % ("gatilhoDeDica(" in corpo))
print("sem_paragrafo_solto=%s" % (len(re.findall(r'elemento\("p"', corpo)) == 1))
PY
)"
{ grep -qx 'linha=True' <<< "$r" && grep -qx 'porque_na_dica=True' <<< "$r" && grep -qx 'sem_paragrafo_solto=True' <<< "$r"; } \
  && ok "uma linha curta na caixa e o parágrafo só dentro da dica" || falha "a caixa do sudo mudou: $r"

echo "== D12. trocar de pack leva o ponteiro do pack"
conf() { # $1 arquivo; $2.. CHAVE=valor
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
    XDG_STATE_HOME="$CASA/.local/state" "$RAIZ/bin/meow" pack usar catppuccin --sem-aplicar >/dev/null 2>&1
[ "$(grep -E '^CURSOR=' "$C12" | tail -n1)" = 'CURSOR="catppuccin-mocha-light"' ] \
  && ok "Dracula -> Catppuccin: o ponteiro vira o do pack novo" || falha "o ponteiro não acompanhou o pack: $(grep -E '^CURSOR=' "$C12" | tail -n1)"

echo "== 13 a 17. o registro guarda as cinco, com a frase que as identifica"
registro 13 'Joga tudo pro pack' && registro 13 'Tudo entra no pack' && ok "13: tudo entra no pack" || falha "a decisão 13 saiu do registro"
registro 14 'Três pastas por pack' && ok "14: três pastas por pack" || falha "a decisão 14 saiu do registro"
registro 15 'se atualiza sozinho' && ok "15: o derivado se atualiza sozinho" || falha "a decisão 15 saiu do registro"
registro 16 'Os achados da varredura' && ok "16: os achados da varredura" || falha "a decisão 16 saiu do registro"
registro 17 'AGENTS.md' && ok "17: o AGENTS.md é exceção do sanitizador" || falha "a decisão 17 saiu do registro"
r="$(resolvedor autorais 2>&1)"
[ "$r" = "proibidos=" ] && ok "P82·16: hefesto e fogstripper fora dos autorais dos packs" || falha "projeto pessoal nos autorais: $r"
c="$(grep -E '^LANCADOR_OCULTAR=' "$RAIZ/meow.conf.exemplo" | head -1)"
grep -qiE 'google-chrome|steam|github-desktop' <<< "$c" \
  && falha "P82·17: o lançador de fábrica volta a esconder Chrome, Steam ou github-desktop" \
  || ok "P82·17: o lançador de fábrica não esconde Chrome, Steam nem github-desktop"
grep -qxF 'NOME_TEMA_ICONES="MeowSystem-Icons"' "$RAIZ/meow.conf.exemplo" \
  && ok "P82·31: o tema instalado continua MeowSystem-Icons" || falha "P82·31: o nome do tema instalado mudou"
python3 - "$RAIZ/scripts/migrar_conf.py" <<'PY' && ok "ICONES_BASE: aposentada no migrar, sem linha ativa no exemplo" || falha "ICONES_BASE voltou: aposentada fora do migrar_conf.py ou com linha ativa no exemplo"
import re, sys
src = open(sys.argv[1], encoding="utf-8").read()
exemplo = open(sys.argv[1].replace("scripts/migrar_conf.py", "meow.conf.exemplo"), encoding="utf-8").read()
sys.exit(0 if re.search(r'APOSENTADAS = \{[^}]*"ICONES_BASE"', src) and not re.search(r"(?m)^ICONES_BASE=", exemplo) else 1)
PY
if grep -rn 'sudo -l' "$RAIZ/bin/meow" | grep -q 'NOPASSWD'; then
  falha "P82·48: o aviso do NOPASSWD volta a mandar rodar sudo -l"
else
  ok "P82·48: o aviso do NOPASSWD diz o estado, sem receita"
fi

echo "== os princípios, cada um com o teste que o cobra dentro do runner"
for t in nada-manda-digitar.sh pack-malicioso.sh convergencia.sh doctor-so-le.sh; do
  { [ -x "$RAIZ/tests/$t" ] && grep -qE "^  $t " "$RAIZ/tests/todos.sh"; } \
    && ok "$t existe e está no runner" || falha "$t saiu do runner (princípio sem prova)"
done
{ grep -qE '^  app-uso-real.py$' "$RAIZ/tests/todos.sh" && grep -q 'texto corrido com' "$RAIZ/tests/app-uso-real.py" \
  && grep -qE '140' "$RAIZ/tests/app-uso-real.py"; } \
  && ok "nenhuma frase longa na tela: o gate app-uso-real.py é obrigatório (teto de 140)" \
  || falha "o gate de frase longa saiu do runner ou perdeu o teto"

echo "== o GSD.md carrega as regras e cita as decisões"
G="$RAIZ/GSD.md"
tem() { [ -f "$G" ] && grep -qF -- "$1" "$G"; }
[ -f "$G" ] && ok "GSD.md na raiz" || falha "falta o GSD.md na raiz"
{ tem 'Decisão de quem usa só se desfaz com sim explícito sobre aquele tema' && tem 'Frase genérica não autoriza'; } \
  && ok "a regra do sim explícito está escrita" || falha "o GSD.md perdeu a regra do sim explícito"
{ tem 'docs/sprints/2026-10-09-uso-real/02-decisoes.md' && tem 'P82-abertos.md'; } \
  && ok "o GSD.md cita o caminho das duas listas de decisão" || falha "o GSD.md não cita os registros"
faltam=""
for n in 1 2 3 4 5 6 7 8 9 10 11 12; do
  { [ -f "$G" ] && grep -qE "^\| $n \|" "$G"; } || faltam+=" $n"
done
[ -z "$faltam" ] && ok "as decisões 1 a 12 estão no GSD.md" || falha "decisões fora do GSD.md:$faltam"
faltam=""
for k in 'NOPASSWD' 'HOME temporário' 'troca palavras' '/tmp' 'Senha nunca'; do tem "$k" || faltam+=" «$k»"; done
[ -z "$faltam" ] && ok "as armadilhas estão no GSD.md" || falha "o GSD.md perdeu a armadilha:$faltam"

echo
if [ "$falhas" = 0 ]; then echo "decisoes: tudo certo"; exit 0; fi
echo "decisoes: $falhas falha(s)"; exit 1
