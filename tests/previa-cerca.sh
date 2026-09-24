#!/usr/bin/env bash
# A CERCA DA ROTA QUE SERVE IMAGEM, E O LINK QUE TROCA DE TIPO NO MEIO.
#
# O QUE ESTE TESTE PEGA JÁ ACONTECEU, EM 09/09/2026
#   A oficina de desenho precisava mostrar a arte de fábrica ao lado das
#   variações, e o «Original» aparecia como ícone quebrado: a arte de metade
#   dos aplicativos desta máquina é um link do flatpak que aponta para
#   `~/.local/share/flatpak/app/<id>/.../<hash>/...`, fora de toda raiz
#   permitida. A cura foi aceitar TAMBÉM o caminho como foi pedido.
#
#   Só que a peneira de extensão passou junto para o caminho pedido — e aí ela
#   olhava o NOME, não o arquivo. Um link chamado `.svg`, plantado dentro de
#   uma raiz permitida, servia qualquer coisa que a usuária consegue ler.
#   Medido: um link em `~/.local/share/icons` apontando para um `.txt` fora de
#   toda raiz devolveu 200, com o conteúdo na resposta.
#
#   Não é escalada de privilégio: plantar o link exige escrita numa das raízes,
#   e quem a tem já lê os arquivos dela. Mas uma das raízes é `assets/icones`,
#   do repositório, que é PÚBLICO — um link simbólico numa contribuição viraria
#   leitura de arquivo na máquina de quem rodasse o painel.
#
# AS DUAS METADES, E ELAS ANDAM JUNTAS
#   O conserto não pode desfazer a cura. O link do flatpak preserva a extensão
#   do outro lado (`.svg` -> `.svg`), então exigir que as duas batam deixa
#   passar o caso real e barra o link que troca de tipo. Por isso este arquivo
#   afirma as duas coisas: o que TEM de passar e o que TEM de ser recusado.
#
#   Recusa é sempre 404, nunca 403: uma resposta diferente por caminho
#   transformaria a rota em sonda de existência de arquivo.
#
# O PAINEL SOBE NUMA CASA DE BRINQUEDO, E NUNCA CONTRA O HOME DELA —
# 24/09/2026, sprint P40
#   Até aqui este arquivo subia o `app/run.sh` com o ambiente de quem o chamava
#   e plantava a isca no `~/.local/share/icons` DE VERDADE — e o próprio
#   `run.sh` gravava o `app.pid` no estado dela. O `trap` tirava a isca, mas a
#   regra do projeto é que nada da interface é aplicado em sandbox; quem vai
#   para a sandbox é o TESTE, e os dois testes de navegador já tinham ido na
#   P33. Este ficou para trás, e a revisão da P33 o achou.
#
#   O ambiente é o `env -i` do `tests/convergencia.sh`: HOME e `MEOW_CONF` no
#   temporário, `MEOW_PONTE` para o vazio e um `sudo` falso na frente do PATH —
#   numa máquina com `NOPASSWD: ALL` o `sudo -n` de verdade PASSA. A cerca da
#   rota monta as raízes da casa pelo `expanduser` a cada pedido, então com o
#   HOME trocado ela cerca a casa de brinquedo, e é essa que se mede.
#
#   E A CASA NÃO FICA VAZIA, pelo motivo que o `tests/app-navegador.py` conta:
#   vazia ela mediria menos e seguiria verde. As duas vias que a casa dela tinha
#   e o brinquedo não teria são plantadas com a forma da máquina (medida no
#   `readlink` de um link real do flatpak): o link de `exports/` que resolve
#   para `app/<id>/.../<hash>/export/...`, FORA de toda raiz, e a capa `.jpg` da
#   Steam. Antes elas eram achadas no HOME dela, e uma máquina sem flatpak ou
#   sem Steam as pulava. E as duas recusas de arquivo dela — a chave privada e o
#   `meow.conf` — ganham arquivo de verdade na casa: sem ele o 404 viria do
#   "não existe", e não da cerca que este teste existe para medir.
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

nosso="$(ls "$RAIZ"/assets/icones/convertidos-apps/*.svg 2>/dev/null | head -1)"
[ -n "$nosso" ] && serve "$nosso" "arte do próprio repositório" \
  || printf 'pulado: sem acervo convertido\n'

exit "$falhas"
