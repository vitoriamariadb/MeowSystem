#!/usr/bin/env bash
# A oficina de desenho precisava mostrar a arte de fábrica ao lado das
# variações, e o «Original» aparecia como ícone quebrado: a arte de metade dos
# aplicativos desta máquina é um link do flatpak que aponta para
# `~/.local/share/flatpak/app/<id>/.../<hash>/...`, fora de toda raiz permitida.
#
# Um link chamado `.svg`, plantado dentro de uma raiz permitida, servia qualquer
# coisa que a usuária consegue ler.
#
# Não é escalada de privilégio: plantar o link exige escrita numa das raízes, e
# quem a tem já lê os arquivos dela.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
H="$T/casa"
ISCA="$H/.local/share/icons/meow-teste-isca.svg"
LOG="$T/painel.log"
# O painel morre ANTES do `rm -rf`, e o `wait` é o que garante isso: com o
# HOME dele dentro do temporário, um servidor ainda de pé recriaria pasta no
# que acabou de ser apagado.
limpar() {
  [ -n "${PAINEL:-}" ] && { kill "$PAINEL" 2>/dev/null; wait "$PAINEL" 2>/dev/null; }
  rm -rf "$T"
}
trap limpar EXIT INT TERM

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

FALSO="$T/falso"
mkdir -p "$FALSO" "$H/.config/meow" "$H/.ssh"
cat > "$FALSO/sudo" <<'SUDO'
#!/bin/sh
printf 'sudo: recusado pelo tests/previa-cerca.sh\n' >&2
exit 1
SUDO
chmod 755 "$FALSO/sudo"
CONF="$H/.config/meow/meow.conf"
cp "$RAIZ/meow.conf.exemplo" "$CONF"
printf 'chave de brinquedo, não é chave de ninguém\n' > "$H/.ssh/id_rsa"
chmod 600 "$H/.ssh/id_rsa"

printf 'segredo de teste\n' > "$T/alvo.txt"
mkdir -p "$(dirname "$ISCA")"
ln -sfn "$T/alvo.txt" "$ISCA"

# O «Original» da oficina: o flatpak de usuária exporta a arte como link, e o
# link sai da raiz permitida. A extensão é a mesma dos dois lados, como na
# máquina — é o caso que a cerca TEM de deixar passar.
APP="org.meow.Teste"
ARTE="$H/.local/share/flatpak/app/$APP/x86_64/stable/0123abcd/export/share/icons/hicolor/scalable/apps/$APP.svg"
ELO="$H/.local/share/flatpak/exports/share/icons/hicolor/scalable/apps/$APP.svg"
mkdir -p "$(dirname "$ARTE")" "$(dirname "$ELO")"
printf '<svg xmlns="http://www.w3.org/2000/svg" width="1" height="1"/>\n' > "$ARTE"
ln -sfn "$ARTE" "$ELO"

# A capa da Steam, no caminho do `appcache/librarycache`. A rota não decodifica
# a imagem, só a serve: os quatro bytes de início e fim de JPEG bastam.
CAPA="$H/.steam/steam/appcache/librarycache/1000/0a1b2c/library_capsule.jpg"
mkdir -p "$(dirname "$CAPA")"
printf '\377\330\377\331' > "$CAPA"

# `--sem-abrir` NUNCA sai daqui: uma janela na tela dela por causa de um teste é
# o próprio defeito que este repositório evita.
env -i PATH="$FALSO:$PATH" HOME="$H" USER="${USER:-t}" LANG="${LANG:-C.UTF-8}" \
  MEOW_CONF="$CONF" MEOW_PONTE=/nao/existe \
  "$RAIZ/app/run.sh" --sem-abrir > "$LOG" 2>&1 &
PAINEL=$!
url=""
for _ in $(seq 1 40); do
  url="$(grep -o 'http://127\.0\.0\.1:[0-9]*/?t=[A-Za-z0-9_-]*' "$LOG" | head -1)"
  [ -n "$url" ] && break
  sleep 1
done
[ -n "$url" ] || { falha "o painel não subiu — nada a conferir"; exit 1; }
BASE="${url%%/\?t=*}"; TOK="${url##*t=}"

codigo() {
  curl -s -o /dev/null -w '%{http_code}' -H "X-Meow-Token: $TOK" \
    --get --data-urlencode "tipo=arquivo" --data-urlencode "id=$1" "$BASE/previa"
}
recusa() { [ "$(codigo "$1")" = "404" ] && ok "recusa: $2" || falha "SERVIU o que não devia: $2"; }
serve()  { [ "$(codigo "$1")" = "200" ] && ok "serve: $2"  || falha "recusou o que devia servir: $2"; }

# --- o que TEM de ser recusado ----------------------------------------------
recusa "$ISCA" "link .svg apontando para .txt fora das raízes"
recusa "/etc/shadow" "/etc/shadow"
recusa "/etc/passwd" "/etc/passwd"
recusa "/usr/share/icons/../../../etc/passwd" "travessia com .. saindo da raiz"
recusa "$H/.ssh/id_rsa" "chave privada dela"
recusa "$CONF" "o arquivo de configuração dela"
recusa "/usr/share/icons" "um diretório, não um arquivo"
recusa "$H/.local/share/icons/nao-existe-mesmo.svg" "arquivo que não existe"

# --- o que TEM de continuar servindo ----------------------------------------
# Cada um representa uma via diferente, e as três já quebraram uma vez:
#   arquivo comum · link do flatpak (o «Original» da oficina) · JPEG da Steam.
comum="$(ls /usr/share/icons/Papirus/64x64/apps/*.svg 2>/dev/null | head -1)"
[ -n "$comum" ] && serve "$comum" "arquivo comum do Papirus" \
  || printf 'pulado: sem Papirus nesta máquina\n'

serve "$ELO" "link do flatpak — é o «Original» da oficina"
serve "$CAPA" "capa JPEG da Steam"

nosso="$(ls "$RAIZ"/packs/meowsystem/icones/apps/convertidos/*.svg 2>/dev/null | head -1)"
[ -n "$nosso" ] && serve "$nosso" "arte do próprio repositório" \
  || printf 'pulado: sem acervo convertido\n'

exit "$falhas"
