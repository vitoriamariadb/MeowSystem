#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | head -40 | sed 's/^/       /' >&2; falhas=$((falhas + 1)); }

for c in dpkg-deb git python3; do
  command -v "$c" >/dev/null 2>&1 || { printf 'pulado: sem %s\n' "$c"; exit 0; }
done

TMP="$(mktemp -d)" || exit 2
trap 'chmod -R u+w "$TMP" 2>/dev/null; rm -rf "$TMP"' EXIT
NEGADO='permission denied|permissão negada|read-only file system|sistema de arquivos somente leitura'

if "$RAIZ/scripts/deb.sh" '1.0;rm' --saida "$TMP/recusa" >/dev/null 2>&1 || [ -e "$TMP/recusa" ]; then
  falha "uma versão que o dpkg não aceita gerou pacote"
else
  ok "versão inválida é recusada antes de gerar"
fi

DEB="$("$RAIZ/scripts/deb.sh" --saida "$TMP/dist" 2>"$TMP/deb.err")"; rc=$?
if [ "$rc" != 0 ] || [ ! -f "$DEB" ]; then
  falha "o scripts/deb.sh não gerou o pacote (rc $rc)" "$(cat "$TMP/deb.err")"
  exit 1
fi
nome="$(basename "$DEB")"
if [[ $nome =~ ^meowsystem_[0-9]+\.[0-9]+\.[0-9]+(\+[0-9]+)?_all\.deb$ ]]; then
  ok "gerado $nome"
else
  falha "o nome do pacote não é meowsystem_<tag>[+commits]_all.deb: $nome"
fi
versao="${nome#meowsystem_}"; versao="${versao%_all.deb}"

campo() { dpkg-deb -f "$DEB" "$1" 2>/dev/null; }
[ "$(campo Package)" = "meowsystem" ] && [ "$(campo Architecture)" = "all" ] && [ "$(campo Version)" = "$versao" ] \
  && ok "controle: meowsystem $versao, all" || falha "controle errado" "$(dpkg-deb -I "$DEB" 2>&1)"
[[ $(campo Installed-Size) =~ ^[0-9]+$ ]] && ok "Installed-Size $(campo Installed-Size) KiB" || falha "Installed-Size não é número"
dep="$(campo Depends)"
faltam=""
for p in bash python3 python3-numpy git curl librsvg2-bin imagemagick libgtk-3-bin papirus-icon-theme; do
  [[ ", $dep," == *", $p"[\ ,]* ]] || faltam+="$p "
done
[ -z "$faltam" ] && ok "Depends traz o que o install.sh exige" || falha "Depends sem: $faltam" "$dep"
rec="$(campo Recommends)"
faltam=""
for p in build-essential pkgconf libxkbcommon-dev libwayland-dev libdbus-1-dev just libinput-dev libseat-dev; do
  [[ ", $rec," == *", $p"[\ ,]* ]] || faltam+="$p "
done
[ -z "$faltam" ] && ok "Recommends traz o que os applets e o compositor pedem para compilar" || falha "Recommends sem: $faltam" "$rec"
if dpkg-deb --ctrl-tarfile "$DEB" | tar -t 2>/dev/null | grep -qE '(pre|post)(inst|rm)$'; then
  falha "o pacote tem script de manutenção: o install é por pessoa, o apt não roda nada no HOME"
else
  ok "sem postinst nem prerm"
fi

dpkg-deb -c "$DEB" > "$TMP/lista" || { falha "dpkg-deb -c falhou"; exit 1; }
dpkg-deb --fsys-tarfile "$DEB" | tar -t > "$TMP/nomes" || { falha "a lista de nomes do pacote falhou"; exit 1; }
estranhos="$(awk '$2 != "root/root"' "$TMP/lista")"
[ -z "$estranhos" ] && ok "tudo de dono root/root" || falha "entrada sem dono root" "$estranhos"
fora_de_usr="$(grep -vE '^\./(usr(/.*)?)?$' "$TMP/nomes")"
[ -z "$fora_de_usr" ] && ok "nada fora de /usr (o pacote não toca /etc)" || falha "o pacote instala fora de /usr" "$fora_de_usr"
grep -qE ' \./usr/bin/meow -> \.\./share/meowsystem/bin/meow$' "$TMP/lista" \
  && ok "/usr/bin/meow é o link para ../share/meowsystem/bin/meow" || falha "/usr/bin/meow não aponta para o bin/meow do pacote"
for f in install.sh bin/meow; do
  grep -qE "^-rwxr-xr-x .* \./usr/share/meowsystem/$f$" "$TMP/lista" && ok "$f executável" || falha "$f sem 755 no pacote"
done
grep -qE ' \./usr/share/doc/meowsystem/copyright$' "$TMP/lista" && grep -qE ' \./usr/share/doc/meowsystem/changelog\.gz$' "$TMP/lista" \
  && ok "copyright e changelog.gz em /usr/share/doc/meowsystem" || falha "falta copyright ou changelog.gz"
proibidos="$(grep -E '^\./usr/share/meowsystem/(tests|docs/sprints|docs/capturas|\.github|packaging)/|/\.git(ignore|attributes)?$' "$TMP/nomes")"
[ -z "$proibidos" ] && ok "sem tests/, docs/sprints/, docs/capturas/ nem arquivos do git" || falha "o pacote leva o que não é do programa" "$proibidos"

esperados="$(cd "$RAIZ" && git ls-files | grep -vE '^(tests/|docs/sprints/|docs/capturas/|\.github/|packaging/)|^(\.gitignore|\.gitattributes|LICENSE)$' \
             | while IFS= read -r f; do [ -e "$f" ] || [ -L "$f" ] && printf './usr/share/meowsystem/%s\n' "$f"; done | LC_ALL=C sort)"
levados="$(grep -v '/$' "$TMP/nomes" | grep '^\./usr/share/meowsystem/' | LC_ALL=C sort)"
diferenca="$(diff <(printf '%s\n' "$esperados") <(printf '%s\n' "$levados"))"
[ -z "$diferenca" ] && ok "o pacote leva exatamente o que o git lista ($(printf '%s\n' "$levados" | grep -c .) arquivos)" \
  || falha "a lista do pacote difere do git ls-files" "$diferenca"

ARV="$TMP/raiz"
dpkg-deb -x "$DEB" "$ARV" || { falha "dpkg-deb -x falhou"; exit 1; }
CASA_PACOTE="$ARV/usr/share/meowsystem"
antes="$(cd "$ARV" && find . -print0 | LC_ALL=C sort -z | xargs -0 stat -c '%n %s %Y' 2>/dev/null | sha256sum)"
chmod -R a-w "$ARV"

FALSO="$TMP/falso"
mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get xdg-open \
         cargo rustup just make systemctl gsettings dconf busctl flatpak curl wget git; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done

rodar() {
  local casa="$1"; shift
  env -i PATH="$FALSO:/usr/local/bin:/usr/bin:/bin" HOME="$casa" USER="${USER:-t}" LANG=C.UTF-8 \
    NO_COLOR=1 MEOW_SEM_REDE=1 MEOW_SIM=1 MEOW_IGNORA_DESKTOP=1 MEOW_PONTE=/nao/existe "$@"
}

C1="$TMP/casa-ajuda"; mkdir -p "$C1"
saida="$(rodar "$C1" "$ARV/usr/bin/meow" --help 2>&1)"; rc=$?
[ "$rc" = 0 ] && [[ $saida == *"meow aplicar"* ]] && ok "o /usr/bin/meow do pacote acha a raiz e responde" \
  || falha "meow --help de dentro do pacote saiu $rc" "$saida"

C2="$TMP/casa-seca"; mkdir -p "$C2"
saida="$(rodar "$C2" "$ARV/usr/bin/meow" aplicar --seco 2>&1)"; rc=$?
sobra="$(cd "$C2" && find . -type f ! -path './.local/state/meowsystem/lock')"
if [ "$rc" -ge 2 ] && [ "$rc" != 3 ]; then
  falha "meow aplicar --seco do pacote saiu $rc" "$(printf '%s\n' "$saida" | tail -20)"
elif [ -n "$sobra" ]; then
  falha "o seco escreveu no HOME" "$sobra"
else
  ok "meow aplicar --seco roda da árvore só leitura (rc $rc) e não escreve no HOME"
fi
printf '%s\n' "$saida" > "$TMP/saidas"

saida="$(rodar "$C2" "$ARV/usr/bin/meow" doctor 2>&1)"; rc=$?
[ "$rc" -le 1 ] && ok "meow doctor roda da árvore só leitura (rc $rc)" || falha "meow doctor do pacote saiu $rc" "$(printf '%s\n' "$saida" | tail -20)"
printf '%s\n' "$saida" >> "$TMP/saidas"

C3="$TMP/casa-instalada"; mkdir -p "$C3"
if command -v strace >/dev/null 2>&1; then
  rodar "$C3" strace -f -qq -o "$TMP/trace" \
    -e trace=open,openat,creat,mkdir,mkdirat,rename,renameat,renameat2,unlink,unlinkat,rmdir,symlink,symlinkat,link,linkat,chmod,fchmodat,truncate,utimensat \
    bash "$CASA_PACOTE/install.sh" > "$TMP/install.log" 2>&1
  rc=$?
  cat "$TMP/install.log" >> "$TMP/saidas"
  tentativas="$(grep -F "\"$ARV/" "$TMP/trace" | grep -v '__pycache__' \
                | grep -E '(open|openat)\(.*O_(WRONLY|RDWR|CREAT)|(creat|mkdir|mkdirat|rename|renameat|renameat2|unlink|unlinkat|rmdir|symlink|symlinkat|link|linkat|chmod|fchmodat|truncate|utimensat)\(' \
                | sed -E 's/^[0-9]+ +//' | LC_ALL=C sort -u)"
  [ -z "$tentativas" ] && ok "o install.sh de verdade (rc $rc) não tentou escrever na árvore instalada" \
    || falha "o install.sh tentou escrever dentro de /usr/share/meowsystem" "$tentativas"
  [ "$(cat "$C3/.local/state/meowsystem/raiz" 2>/dev/null)" = "$CASA_PACOTE" ] \
    && ok "o ponteiro da raiz aponta para a árvore do pacote" || falha "o ponteiro da raiz não aponta para o pacote: $(cat "$C3/.local/state/meowsystem/raiz" 2>/dev/null)"
  [ -x "$C3/.local/bin/meow" ] && ok "~/.local/bin/meow instalado" || falha "o install não pôs ~/.local/bin/meow"
else
  printf 'pulado: sem strace, a escrita calada do install.sh na árvore não foi medida\n'
fi

C4="$TMP/casa-painel"; mkdir -p "$C4"
saida="$(rodar "$C4" python3 - "$CASA_PACOTE/app/servidor.py" "$C4" <<'PY' 2>&1
import base64, json, os, subprocess, sys, time, urllib.request, zlib, struct
servidor, casa = sys.argv[1], sys.argv[2]
amb = dict(os.environ, MEOW_APP_VIGIA="0", MEOW_APP_SEM_JANELA="1")
amb.pop("MEOW_RAIZ", None)
p = subprocess.Popen([sys.executable, servidor], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=amb)
try:
    url = p.stdout.readline().strip()
    if not url.startswith("http://127.0.0.1:"):
        print("FALHOU: o painel não subiu da árvore só leitura:", url, p.stderr.read()[-2000:])
        sys.exit(1)
    base, token = url.split("/?t=")
    def bloco(tipo, dados):
        return struct.pack(">I", len(dados)) + tipo + dados + struct.pack(">I", zlib.crc32(tipo + dados))
    png = (b"\x89PNG\r\n\x1a\n" + bloco(b"IHDR", struct.pack(">IIBBBBB", 1, 1, 8, 2, 0, 0, 0))
           + bloco(b"IDAT", zlib.compress(b"\x00\xf5\xc2\xe7")) + bloco(b"IEND", b""))
    corpo = json.dumps({"tipo": "parede", "nome": "do-pacote.png",
                        "conteudo": base64.b64encode(png).decode()}).encode()
    pedido = urllib.request.Request(base + "/api/acervo", data=corpo, method="POST",
                                    headers={"X-Meow-Token": token, "Content-Type": "application/json"})
    try:
        resposta = json.loads(urllib.request.urlopen(pedido, timeout=60).read())
    except urllib.error.HTTPError as e:
        resposta = {"erro": e.read().decode(errors="replace")}
    esperado = os.path.join(casa, ".local", "share", "backgrounds", "meowsystem", "ativos", "do-pacote.png")
    if resposta.get("ok") and os.path.realpath(resposta.get("destino", "")) == os.path.realpath(esperado) \
            and os.path.isfile(esperado):
        print("ok: o papel de parede enviado pelo painel cai no ativos de quem usa")
    else:
        print("FALHOU: o envio de papel de parede não foi para o ativos de quem usa:", resposta)
finally:
    p.terminate()
    try:
        p.wait(timeout=10)
    except subprocess.TimeoutExpired:
        p.kill()
PY
)"
printf '%s\n' "$saida" | grep -q '^ok:' && ok "${saida#ok: }" || falha "painel servido do pacote" "$saida"

depois="$(cd "$ARV" && find . -print0 | LC_ALL=C sort -z | xargs -0 stat -c '%n %s %Y' 2>/dev/null | sha256sum)"
[ "$antes" = "$depois" ] && ok "a árvore instalada saiu idêntica" || falha "a árvore instalada mudou"
negados="$(grep -iE "$NEGADO" "$TMP/saidas")"
[ -z "$negados" ] && ok "nenhuma saída fala de permissão negada" || falha "saída com permissão negada" "$negados"

if [ "$falhas" -gt 0 ]; then
  printf '%s falha(s)\n' "$falhas" >&2
  exit 1
fi
printf 'o pacote %s instala e roda da árvore só leitura\n' "$nome"
