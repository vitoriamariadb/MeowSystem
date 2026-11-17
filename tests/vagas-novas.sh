#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 3; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
FALSO="$T/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su apt cargo just make pkill; do
  printf '#!/bin/sh\nprintf "%s: recusado pelo tests/vagas-novas.sh\\n" >&2\nexit 1\n' "$c" > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done
CASA="$T/casa"
MEU="$CASA/.local/share/meowsystem/packs/meu-dracula"
HICOLOR="$CASA/.local/share/icons/hicolor/scalable/status"
mkdir -p "$CASA/.config/meow" "$MEU" "$CASA/.local/state/meowsystem" "$HICOLOR" || exit 2
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf" || exit 2
printf '{"formato": 2, "id": "meu-dracula", "nome": "Meu Dracula", "heranca": "dracula", "icones": {"sistema": {"herda": "dracula"}}}\n' > "$MEU/pack.json"
cp "$RAIZ/packs/dracula/paleta.json" "$MEU/paleta.json"
for modo in desperto ronronar; do
  printf '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path d="M4 4h40" fill="none" stroke="currentColor" stroke-width="3"/></svg>\n' \
    > "$HICOLOR/soneca-$modo-symbolic.svg"
done

amb() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 \
    MEOW_CONF="$CASA/.config/meow/meow.conf" XDG_CONFIG_HOME="$CASA/.config" \
    XDG_DATA_HOME="$CASA/.local/share" XDG_STATE_HOME="$CASA/.local/state" \
    MEOW_ESTADO="$CASA/.local/state/meowsystem" PYTHONDONTWRITEBYTECODE=1 MEOW_RAIZ="$RAIZ" "$@"
}

amb python3 - "$RAIZ" "$MEU" <<'PY'
import base64
import hashlib
import json
import os
import sys

raiz, meu = sys.argv[1], sys.argv[2]
sys.path.insert(0, os.path.join(raiz, "app"))
sys.path.insert(0, os.path.join(raiz, "scripts"))
import servidor  # noqa: E402
import pack  # noqa: E402

falhas = []


def checa(cond, frase, detalhe=""):
    if cond:
        print("ok: " + frase)
    else:
        falhas.append(frase + (" — " + detalhe if detalhe else ""))
    return cond


m = servidor.Manipulador.__new__(servidor.Manipulador)
resposta = {}
m._json = lambda dados, codigo=200: resposta.update(dados=dados, codigo=codigo)


def chamar(metodo, arg):
    resposta.clear()
    metodo(arg)
    return resposta.get("dados") or {}


JANELA = {"window-close-symbolic", "window-minimize-symbolic", "window-maximize-symbolic",
          "window-restore-symbolic", "list-add-symbolic"}
SONECA = {"soneca-desperto-symbolic", "soneca-ronronar-symbolic"}

for pid in ("meowsystem", "dracula"):
    mapa = os.path.join(raiz, "packs", pid, "icones", "sistema.map")
    nomes = {l.split(":", 1)[0] for l in open(mapa, encoding="utf-8") if not l.startswith("#") and ":" in l}
    checa(SONECA <= nomes, "%s: o mapa de ícones tem as duas vagas da Soneca" % pid)
    itens = pack.acervo_para_levar(None, "sistema", pid)
    janela = {i["nome"] for i in itens if i["grupo"] == "janela"}
    checa(janela == JANELA, "%s: Botões da janela é fechar, minimizar, maximizar, restaurar e +" % pid, repr(sorted(janela)))
    soneca = {i["nome"]: i for i in itens if i["grupo"] == "soneca"}
    checa(set(soneca) == SONECA, "%s: o grupo Soneca tem as duas vagas" % pid, repr(sorted(soneca)))
    checa({i["rotulo"] for i in soneca.values()} == {"Desperto", "Ronronar"}, "%s: as vagas da Soneca com nome curto" % pid)

sem = pack.sistema_do_pack(pack.achar("dracula"))
checa(all(os.path.realpath(a).startswith(os.path.realpath(os.environ["XDG_DATA_HOME"]))
          for n, a, *_ in sem if n in SONECA),
      "sem o desenho no pack, a vaga mostra o padrão que o applet instalou")

lido = chamar(m._api_criar_ler, {"base": ["dracula"]})
textos = {t["extensao"]: t for t in lido.get("textos", [])}
chaves = {c["chave"]: c for c in textos.get("soneca", {}).get("chaves", [])}
checa(chaves.get("desperto", {}).get("padrao") == "Desperto" and chaves.get("ronronar", {}).get("padrao") == "Ronronar",
      "o criador recebe os dois textos da Soneca com o padrão do pino", repr(textos))
checa(chaves.get("ronronar", {}).get("valor") == "Descansando", "o Dracula em edição mostra Descansando",
      repr(chaves))
lido = chamar(m._api_criar_ler, {"base": ["meowsystem"]})
valores = {c["chave"]: c["valor"] for t in lido.get("textos", []) for c in t["chaves"]}
checa(valores == {"desperto": "", "ronronar": ""}, "o MeowSystem em edição fica no padrão", repr(valores))

arq = os.path.join(meu, "pack.json")
r = chamar(m._api_criar, {"id": "meu-dracula", "tipo": "textos", "extensao": "soneca", "textos": {"ronronar": "Sono"}})
checa(r.get("ok"), "o criador grava o texto no pack", repr(r))
checa(pack.textos_da_extensao("soneca", "meu-dracula") == {"ronronar": "Sono", "desperto": "Desperto"},
      "o pack da pessoa troca um texto e herda o outro", repr(pack.textos_da_extensao("soneca", "meu-dracula")))
antes = (os.stat(arq).st_mtime_ns, hashlib.sha256(open(arq, "rb").read()).hexdigest())
os.utime(arq, ns=(antes[0] - 10**9, antes[0] - 10**9))
antes = os.stat(arq).st_mtime_ns
chamar(m._api_criar, {"id": "meu-dracula", "tipo": "textos", "extensao": "soneca", "textos": {"ronronar": "Sono"}})
checa(os.stat(arq).st_mtime_ns == antes, "o mesmo texto de novo não escreve o pack.json")
r = chamar(m._api_criar, {"id": "meu-dracula", "tipo": "textos", "extensao": "soneca", "textos": {"ronronar": "a\nb"}})
checa(resposta.get("codigo") == 400, "texto em duas linhas é recusado", repr(r))
r = chamar(m._api_criar, {"id": "meu-dracula", "tipo": "textos", "extensao": "outra", "textos": {"x": "y"}})
checa(resposta.get("codigo") == 404, "extensão que não é da casa é recusada", repr(r))

svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16"><path d="M2 2l12 12" stroke="currentColor"/></svg>\n'
for nome in ("window-close-symbolic", "soneca-desperto-symbolic"):
    r = chamar(m._api_criar, {"id": "meu-dracula", "tipo": "sistema", "nome": nome, "levar": True,
                              "conteudo": base64.b64encode(svg.encode()).decode()})
    checa(r.get("ok") and os.path.isfile(os.path.join(meu, "icones", "sistema", nome + ".svg")),
          "%s: trocado por arquivo no pack da pessoa" % nome, repr(r))

if falhas:
    for f in falhas:
        print("FALHOU: " + f, file=sys.stderr)
    sys.exit(1)
PY
rc_py=$?

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }
[ "$rc_py" = 0 ] || falha "a parte do criador falhou"

tema="$CASA/.local/share/icons/MeowSystem-Icons"
mkdir -p "$tema"
printf '[Icon Theme]\nName=MeowSystem-Icons\nInherits=hicolor\nDirectories=scalable/apps\n' > "$tema/index.theme"
amb PACK=meu-dracula FLAVOR=dracula "$RAIZ/scripts/icones_sistema.sh" --aplicar >"$T/aplicar" 2>&1
grep -q 'M2 2l12 12' "$tema/scalable/actions/window-close-symbolic.svg" 2>/dev/null \
  && ok "o fechar trocado no criador chega ao tema instalado" || falha "o fechar trocado não chegou" "$(cat "$T/aplicar")"
grep -q 'M2 2l12 12' "$tema/scalable/status/soneca-desperto-symbolic.svg" 2>/dev/null \
  && ok "a vaga Desperto da Soneca chega ao tema, em status" || falha "a vaga da Soneca não chegou" "$(ls -R "$tema" | head -20)"
[ ! -e "$tema/scalable/status/soneca-ronronar-symbolic.svg" ] \
  && ok "a vaga sem desenho no pack fica com o padrão do applet, no hicolor" || falha "o Ronronar saiu sem desenho"
amb PACK=meu-dracula FLAVOR=dracula "$RAIZ/scripts/icones_sistema.sh" --aplicar >/dev/null 2>&1
[ $? = 0 ] && ok "a segunda passada não escreve nada" || falha "a segunda passada escreveu"

grep -q '"janela", "Botões da janela"' "$RAIZ/app/pagina/paginas.js" && grep -q '"soneca", "Soneca"' "$RAIZ/app/pagina/paginas.js" \
  && ok "o criador mostra os grupos Botões da janela e Soneca" || falha "faltam os grupos no criador"

if [ "$falhas" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$falhas" >&2
  exit 1
fi
exit 0
