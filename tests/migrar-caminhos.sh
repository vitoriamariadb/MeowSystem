#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
command -v python3 >/dev/null || { printf 'pulado: sem python3\n'; exit 3; }
T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; falhas=$((falhas + 1)); }

mkdir -p "$T/casa/.config/meow"
export HOME="$T/casa" MEOW_CONF="$T/casa/.config/meow/meow.conf"
unset MEOW_ICONES_ESCOLHAS MEOW_ICONES_TRACO
ESC="$T/casa/.config/meow/icones-escolhidos.map"
TRA="$T/casa/.config/meow/icones-traco.map"
MIGRAR() { python3 "$RAIZ/scripts/pack.py" migrar-caminhos "$@"; }

printf '# as minhas escolhas\n\nzeta : packs/dracula/icones/biblioteca/009-crystal-ball.svg   # Bola de cristal\nalfa : packs/dracula/icones/apps/steam.svg\nbeta : pack:dracula:apps/steam.svg\n   \ngama : assets/icones/resgatados/luna.svg' > "$ESC"
printf '#!cor-por-categoria\n# traço meu\nfoo:assets/icones/resgatados/luna.svg:blue\nbar:firefox:green:alias\n' > "$TRA"
cp "$ESC" "$T/esc.antes"; cp "$TRA" "$T/tra.antes"

saida="$(MIGRAR --conferir)"
{ [ -n "$saida" ] && cmp -s "$ESC" "$T/esc.antes" && cmp -s "$TRA" "$T/tra.antes"; } \
  && ok "--conferir conta o que traduziria e não escreve" || falha "--conferir escreveu ou calou: $saida"

MIGRAR >/dev/null
[ "$(sed -n 3p "$ESC")" = 'zeta : packs/dracula/icones/apps/009-crystal-ball.svg   # Bola de cristal' ] \
  && ok "o caminho de antes vira o de hoje, e o rótulo fica" || falha "linha 3 do mapa de escolhas: $(sed -n 3p "$ESC")"
[ "$(sed -n 7p "$ESC")" = 'gama : packs/dracula/icones/apps/luna.svg' ] \
  && ok "o padrão de pasta também traduz, e a última linha sem quebra continua sem quebra" || falha "linha 7: $(sed -n 7p "$ESC")"
[ "$(sed -n 3p "$TRA")" = 'foo:packs/dracula/icones/apps/luna.svg:blue' ] \
  && ok "o glifo com caminho do mapa de traço é traduzido" || falha "linha 3 do traço: $(sed -n 3p "$TRA")"
diff <(sed -e 's#packs/dracula/icones/apps/009-crystal-ball.svg#X#;s#packs/dracula/icones/apps/luna.svg#Y#' "$ESC") \
     <(sed -e 's#packs/dracula/icones/biblioteca/009-crystal-ball.svg#X#;s#assets/icones/resgatados/luna.svg#Y#' "$T/esc.antes") >/dev/null \
  && ok "comentário, linha em branco, ordem e linha sem caminho antigo ficam como estavam" || falha "o mapa de escolhas perdeu algo além do caminho"
[ "$(sed -n '1,2p;4p' "$TRA")" = "$(sed -n '1,2p;4p' "$T/tra.antes")" ] \
  && ok "a diretiva #! e a linha sem caminho ficam" || falha "o traço perdeu a diretiva ou a linha simples"
{ cmp -s "$ESC.antes-caminhos" "$T/esc.antes" && cmp -s "$TRA.antes-caminhos" "$T/tra.antes"; } \
  && ok "a cópia de antes guarda os dois arquivos como estavam" || falha "a cópia de antes não confere"

cp "$ESC" "$T/esc.depois"; cp "$TRA" "$T/tra.depois"
saida="$(MIGRAR)"
{ [ -z "$saida" ] && cmp -s "$ESC" "$T/esc.depois" && cmp -s "$TRA" "$T/tra.depois" && [ -z "$(MIGRAR --conferir)" ]; } \
  && ok "a segunda passada não escreve nada" || falha "a segunda passada escreveu: $saida"

printf 'soneca-desperto-symbolic : assets/extensoes/icones/soneca.svg\n' > "$ESC"; rm -f "$TRA"
MIGRAR >/dev/null
[ "$(cat "$ESC")" = 'soneca-desperto-symbolic : packs/meowsystem/icones/sistema/soneca.svg' ] \
  && ok "o ícone do cartão de applet escolhido no mapa vai para o pack-base (P274)" || falha "o ícone do cartão não migrou: $(cat "$ESC")"

rm -f "$ESC" "$ESC.antes-caminhos" "$TRA" "$TRA.antes-caminhos"
saida="$(MIGRAR)"
{ [ -z "$saida" ] && [ ! -e "$ESC" ] && [ ! -e "$TRA" ]; } \
  && ok "sem os mapas de quem usa, nada é criado" || falha "a migração criou mapa que não existia: $saida"

printf 'saiu : packs/dracula/icones/biblioteca/feitos-a-mao/citrix.svg   # foi embora\n' > "$ESC"
cp "$ESC" "$T/saiu.antes"
saida="$(MIGRAR)"
{ [ -z "$saida" ] && cmp -s "$ESC" "$T/saiu.antes" && [ ! -e "$ESC.antes-caminhos" ]; } \
  && ok "o caminho que saiu sem sucessor fica como estava, sem cópia" || falha "a linha do caminho que saiu mudou: $(cat "$ESC")"

printf 'zeta : packs/dracula/icones/biblioteca/009-crystal-ball.svg\n' > "$ESC"
cp "$ESC" "$T/so-leitura.antes"
chmod 555 "$T/casa/.config/meow"
saida="$(MIGRAR 2>&1)"; rc=$?
chmod 755 "$T/casa/.config/meow"
{ [ "$rc" != 0 ] && cmp -s "$ESC" "$T/so-leitura.antes" && [[ $saida == *"não consegui escrever"* ]] && [[ $saida != *Traceback* ]]; } \
  && ok "na pasta só-leitura a migração diz que não conseguiu e não mexe no mapa" || falha "pasta só-leitura: rc=$rc $saida"

mkdir -p "$T/dotfiles"
mv "$ESC" "$T/dotfiles/icones-escolhidos.map"
ln -s "$T/dotfiles/icones-escolhidos.map" "$ESC"
MIGRAR >/dev/null
[ "$(cat "$ESC")" = 'zeta : packs/dracula/icones/apps/009-crystal-ball.svg' ] \
  && ok "o mapa que é link simbólico também é traduzido" || falha "link simbólico: $(cat "$ESC")"

grep -q 'pack.py" migrar-caminhos' "$RAIZ/install.sh" \
  && ok "o install chama a migração na etapa da configuração" || falha "o install não chama a migração"

[ "$falhas" = 0 ]
