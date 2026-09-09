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
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
ISCA="$HOME/.local/share/icons/meow-teste-isca.svg"
LOG="$T/painel.log"
# A isca sai SEMPRE, inclusive se o teste morrer no meio: ela é um link dentro
# de um diretório da máquina dela, e deixar lixo lá é pior que falhar.
limpar() { rm -f "$ISCA"; [ -n "${PAINEL:-}" ] && kill "$PAINEL" 2>/dev/null; rm -rf "$T"; }
trap limpar EXIT INT TERM

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas+1)); }

printf 'segredo de teste\n' > "$T/alvo.txt"
mkdir -p "$(dirname "$ISCA")"
ln -sfn "$T/alvo.txt" "$ISCA"

# `--sem-abrir` NUNCA sai daqui: uma janela na tela dela por causa de um teste é
# o próprio defeito que este repositório evita.
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
recusa "$HOME/.ssh/id_rsa" "chave privada dela"
recusa "$HOME/.config/meow/meow.conf" "o arquivo de configuração dela"
recusa "/usr/share/icons" "um diretório, não um arquivo"
recusa "$HOME/.local/share/icons/nao-existe-mesmo.svg" "arquivo que não existe"

# --- o que TEM de continuar servindo ----------------------------------------
# Cada um representa uma via diferente, e as três já quebraram uma vez:
#   arquivo comum · link do flatpak (o «Original» da oficina) · JPEG da Steam.
comum="$(ls /usr/share/icons/Papirus/64x64/apps/*.svg 2>/dev/null | head -1)"
[ -n "$comum" ] && serve "$comum" "arquivo comum do Papirus" \
  || printf 'pulado: sem Papirus nesta máquina\n'

elo="$(find "$HOME/.local/share/flatpak/exports/share/icons" -name '*.svg' -type l 2>/dev/null | head -1)"
[ -n "$elo" ] && serve "$elo" "link do flatpak — é o «Original» da oficina" \
  || printf 'pulado: sem link de flatpak nesta máquina\n'

capa="$(ls "$HOME"/.steam/steam/appcache/librarycache/*/*/library_capsule.jpg 2>/dev/null | head -1)"
[ -n "$capa" ] && serve "$capa" "capa JPEG da Steam" \
  || printf 'pulado: sem capa da Steam nesta máquina\n'

nosso="$(ls "$RAIZ"/assets/icones/convertidos-apps/*.svg 2>/dev/null | head -1)"
[ -n "$nosso" ] && serve "$nosso" "arte do próprio repositório" \
  || printf 'pulado: sem acervo convertido\n'

exit "$falhas"
