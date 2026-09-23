#!/usr/bin/env bash
# fonte-unica.sh — um nome de ícone, um arquivo de onde ele sai, e esse arquivo
# mora no repositório.
#
# POR QUE ESTE ARQUIVO NASCEU EM 23/09/2026 (P28)
#   A diretriz: "centralizar os SVGs — e alterando lá alteraremos o resto".
#   Ela só vale se cada ícone tiver UMA fonte, e se essa fonte for um arquivo
#   daqui. Medido no dia em que a P28 foi escrita: o `net.waterfox.waterfox`
#   tinha a linha no `apps-resgatados.map` do motor e um `?` comentado no
#   `apps.map` do pack, e nenhum validador recusava um mapa de pack que
#   apontasse para `~/.local/share/icons/` — um diretório que outro programa
#   reescreve (o `rebuild_dracula_theme()` do Spellbook-OS, 21/09 16:52:33).
#
# O QUE ELE COBRA, REGRA POR REGRA DA P28
#   1. Um nome, uma fonte — na camada `scalable/apps`, onde dois donos disputam
#      o MESMO arquivo. Nome com duas fontes é falha; nome sem desenho também.
#   4. Mapa não aponta para fora: pack, `motor:` ou `pack:`, e só.
#   5. Arte de terceiro entra por cópia, com procedência: o Waterfox tem linha
#      no PROCEDENCIA.md do pack.
#   7. `meow icones fonte` responde com o arquivo e com o que deriva dele.
#   8. `sincronizar` compara e NÃO copia — nem quando a origem andou, nem
#      quando a cópia foi retocada.
#
# "CADA Icon= DA MÁQUINA", E POR QUE ELE NÃO LÊ A MÁQUINA
#   A sprint escreve a regra 1 sobre os `Icon=` desta máquina. O teste a cobra
#   sobre os MAPAS, que são o que o repositório promete: ler os `.desktop` de
#   quem roda faria o placar depender de quais aplicativos estão instalados, e
#   o CI diria verde ou vermelho por ausência, não por defeito — o que o
#   `tests/todos.sh` veio proibir. Quem quer a pergunta da máquina tem o
#   `meow icones fonte <nome>`, que este teste também exercita.
#
# CÓDIGOS DE SAÍDA (os do projeto)
#   0 = tudo cobrado passou · 1 = achados · 2 = erro deste teste.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/packs" "$T/xdg" "$T/home"

# O AMBIENTE É DE BRINQUEDO, E A RAZÃO É A LISTA DE RAÍZES
#   O `pack.py` procura packs em `$MEOW_PACKS`, no `$XDG_DATA_HOME` de quem roda
#   e no repositório. Sem o XDG de brinquedo, um pack que a pessoa tenha
#   instalado em `~/.local/share/meowsystem/packs/` entraria na conta, e o
#   teste mediria a máquina dela em vez do repositório.
amb() { env MEOW_PACKS="$T/packs" XDG_DATA_HOME="$T/xdg" HOME="$T/home" MEOW_RAIZ="$RAIZ" "$@"; }
pack_py() { amb python3 "$RAIZ/scripts/pack.py" "$@"; }

# Um pack mínimo e válido, para os casos que precisam de um mapa inventado. A
# paleta é a do Dracula: o que se testa aqui é o mapa, não a cor.
pack_de_brinquedo() {
  local id="$1" d="$T/packs/$1"
  mkdir -p "$d/icones/apps"
  cp "$RAIZ/packs/dracula/paleta.json" "$d/paleta.json"
  printf '{"formato": 1, "id": "%s", "nome": "%s", "paleta": {"arquivo": "paleta.json"}, "icones": {"apps": {"mapa": "icones/apps.map"}}}\n' \
    "$id" "$id" > "$d/pack.json"
  : > "$d/icones/apps.map"
  printf '%s' "$d"
}

# --- 1. regra 4 e regra 1 nos packs de verdade --------------------------------
#   O `validar` passou a ler as LINHAS do mapa de aplicativos: alvo fora das
#   três casas, nome repetido e alvo ausente são recusa. Todo pack do
#   repositório tem de passar por ele.
for d in "$RAIZ"/packs/*/; do
  id="$(basename "$d")"
  saida="$(pack_py validar "$id" 2>&1)"; rc=$?
  [ "$rc" = "0" ] \
    && ok "pack $id valida, com as linhas do mapa de aplicativos conferidas" \
    || falha "pack $id não valida (rc=$rc)" "$saida"
done

# E nenhum nome da camada `scalable/apps` tem duas fontes, ou nenhuma, com
# cada pack como o ativo — o mapa do pack mais o `apps-resgatados.map` do motor,
# que escrevem no mesmo diretório.
for d in "$RAIZ"/packs/*/; do
  id="$(basename "$d")"
  linhas="$(pack_py fontes "$id" 2>"$T/erro")"
  [ -s "$T/erro" ] && falha "pack $id: o 'fontes' recusou linhas de mapa" "$(cat "$T/erro")"
  dup="$(printf '%s\n' "$linhas" | cut -f1 | grep . | sort | uniq -d)"
  [ -z "$dup" ] \
    && ok "pack $id: nenhum nome de scalable/apps com duas fontes ($(printf '%s\n' "$linhas" | grep -c .) nomes)" \
    || falha "pack $id: nome com mais de uma fonte — um nome, uma fonte:" "$dup"
  sem=""
  while IFS=$'\t' read -r nome fonte _; do
    [ -n "$nome" ] || continue
    case "$fonte" in /*) f="$fonte" ;; *) f="$RAIZ/$fonte" ;; esac
    [ -f "$f" ] || sem="$sem$nome -> $fonte
"
  done <<< "$linhas"
  [ -z "$sem" ] \
    && ok "pack $id: toda fonte nomeada existe no repositório" \
    || falha "pack $id: nome no mapa sem desenho no disco:" "$sem"
done

# --- 2. o Waterfox: uma fonte, no pack, com procedência ----------------------
saida="$(pack_py fonte net.waterfox.waterfox dracula 2>&1)"; rc=$?
[ "$rc" = "0" ] && [ "$saida" = "net.waterfox.waterfox	packs/dracula/icones/apps/net.waterfox.waterfox.svg	pack:dracula" ] \
  && ok "o Waterfox tem uma fonte só, e ela é packs/dracula/icones/apps/net.waterfox.waterfox.svg" \
  || falha "a fonte do Waterfox não é a do pack (rc=$rc)" "$saida"

# A linha que saiu do motor não pode voltar calada: com ela, o resgate e o pack
# escreveriam o mesmo arquivo, e o doctor trocaria um pelo outro todo dia.
if sed -e 's/#.*//' "$RAIZ/assets/icones/apps-resgatados.map" | grep -q '^[[:space:]]*net\.waterfox\.waterfox[[:space:]]*:'; then
  falha "o apps-resgatados.map voltou a nomear o Waterfox — duas fontes para um nome"
else
  ok "o apps-resgatados.map não nomeia mais o Waterfox"
fi

grep -q '^| `icones/apps/net.waterfox.waterfox.svg` |' "$RAIZ/packs/dracula/PROCEDENCIA.md" \
  && ok "o Waterfox copiado tem linha de procedência no pack" \
  || falha "packs/dracula/PROCEDENCIA.md não tem a linha do Waterfox — arte copiada sem origem"

# --- 3. o que sobrou de `~/` nos mapas do motor é procedência, não alvo -------
#   A P28 contou 23 linhas de `assets/icones/*.map` com caminho da máquina. A
#   do Waterfox saiu com ele. As que ficam são a coluna do meio do
#   `apps-resgatados.map`: onde o PNG foi ACHADO em 11/09/2026, lida só pela
#   folha de antes-e-depois — o instalador lê o primeiro campo e instala
#   `resgatados/<nome>.svg`. Esta conferência trava as duas metades: nenhum
#   OUTRO mapa ganha linha útil com `~/` ou `/home/`, e toda linha dessas no
#   resgatados tem o desenho dela no acervo.
fora=""
for mapa in "$RAIZ"/assets/icones/*.map "$RAIZ"/packs/*/icones/*.map; do
  while IFS= read -r linha; do
    case "$mapa" in
      */assets/icones/apps-resgatados.map)
        nome="$(printf '%s' "$linha" | cut -d: -f1 | tr -d '[:space:]')"
        [ -f "$RAIZ/assets/icones/resgatados/$nome.svg" ] || fora="$fora${mapa#"$RAIZ"/}: $linha
" ;;
      *) fora="$fora${mapa#"$RAIZ"/}: $linha
" ;;
    esac
  done < <(sed -e 's/#.*//' "$mapa" | grep -E '~/\.local|/home/' || true)
done
[ -z "$fora" ] \
  && ok "nenhum mapa tem alvo na máquina; o que resta de '~/' é a procedência do resgate" \
  || falha "linha útil de mapa com caminho da máquina:" "$fora"

# --- 4. regra 4, pelo lado de quem escreve um pack ---------------------------
d="$(pack_de_brinquedo maquina)"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$d/icones/apps/steam.svg"
for alvo in '~/.local/share/icons/Dracula-Icones/scalable/apps/steam.png' \
            '/usr/share/icons/hicolor/scalable/apps/steam.svg' \
            'motor:/etc/passwd' 'pack:/etc:x.svg' 'pack:nao-existe:apps/x.svg'; do
  printf 'steam : %s\n' "$alvo" > "$d/icones/apps.map"
  saida="$(pack_py validar maquina 2>&1)"; rc=$?
  [ "$rc" = "1" ] \
    && ok "o validar recusa o alvo '$alvo'" \
    || falha "o validar aceitou um alvo fora das três casas: '$alvo' (rc=$rc)" "$saida"
done
printf 'steam : ~/x.svg\n' > "$d/icones/apps.map"
# A saída é guardada antes do `grep`: com `pipefail`, o 1 da recusa (que é o
# esperado) mancharia o cano inteiro e o teste falharia sobre o acerto.
saida="$(pack_py validar maquina 2>&1)"
printf '%s' "$saida" | grep -q 'endereço desta máquina' \
  && ok "a recusa do '~/' diz que é endereço da máquina, e não 'desenho ausente'" \
  || falha "a recusa do '~/' não nomeia a causa" "$saida"

# `pack:` é a terceira casa, e ela resolve dentro do OUTRO pack.
printf 'steam : pack:catppuccin:autorais/fogstripper-mocha.svg\n' > "$d/icones/apps.map"
saida="$(pack_py validar maquina 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && ok "'pack:<id>:<caminho>' resolve dentro de <aquele pack>/icones/" \
  || falha "o prefixo pack: não resolveu um arquivo que existe (rc=$rc)" "$saida"
saida="$(printf 'pack:catppuccin:../../dracula/paleta.json\n' | pack_py alvo "$d/icones" 2>/dev/null)"
[ -z "$saida" ] \
  && ok "'pack:' que sai do outro pack é recusado, e a linha volta vazia" \
  || falha "o prefixo pack: deixou um alvo escapar" "$saida"

# --- 5. regra 1, pelo lado de quem escreve um pack ---------------------------
printf 'steam : apps/steam.svg\nsteam : apps/steam.svg\n' > "$d/icones/apps.map"
saida="$(pack_py validar maquina 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'já está na linha 1' \
  && ok "o mesmo nome duas vezes no mapa é recusa, e ela diz a linha" \
  || falha "o validar aceitou um nome repetido no mapa (rc=$rc)" "$saida"

# O empate entre o pack e o motor: um pack que vista a `luna` escreveria o
# mesmo `scalable/apps/luna.svg` que o resgate escreve.
cp "$RAIZ/assets/icones/resgatados/luna.svg" "$d/icones/apps/luna.svg"
printf 'luna : apps/luna.svg\n' > "$d/icones/apps.map"
saida="$(pack_py fonte luna maquina 2>&1)"; rc=$?
[ "$rc" = "1" ] && [ "$(printf '%s\n' "$saida" | grep -c '^luna	')" = "2" ] \
  && ok "o 'fonte' mostra as duas fontes de um empate e sai 1" \
  || falha "o 'fonte' escondeu um empate entre o pack e o resgate (rc=$rc)" "$saida"

# --- 6. os dois parsers do mapa concordam ------------------------------------
#   O `_dracula_pares` do shell e o `ler_mapa` do Python leem o mesmo formato.
#   A função do shell é extraída VERBATIM, como no `tests/pack.sh`: uma cópia
#   dela aqui seria a que passaria no dia em que a original quebrasse.
sh_pares="$(MAPA="$RAIZ/packs/dracula/icones/apps.map" ICONES_BASE_MAPA="$RAIZ/packs/dracula/icones" RAIZ="$RAIZ" \
  amb bash -c 'set -uo pipefail
  eval "$(sed -n "/^_dracula_pares() {\$/,/^}\$/p" "$RAIZ/scripts/icones_apps_dracula.sh")"
  _dracula_pares' 2>/dev/null | sort)"
py_pares="$(pack_py fontes dracula 2>/dev/null | awk -F'\t' -v r="$RAIZ" '$3 ~ /^pack:/ {print $1 "\t" r "/" $2}' | sort)"
[ -n "$sh_pares" ] && [ "$sh_pares" = "$py_pares" ] \
  && ok "o parser do shell e o do pack.py leem o mapa do Dracula igual ($(printf '%s\n' "$py_pares" | grep -c .) linhas)" \
  || falha "os dois parsers do mapa discordam" "$(diff <(printf '%s\n' "$sh_pares") <(printf '%s\n' "$py_pares"))"

# --- 7. o que deriva de uma fonte, e o instalador escreve exatamente isso -----
tema="$T/home/tema"
plano="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivados "$1" net.waterfox.waterfox "$2"' _ "$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg" "$tema")"
[ "$plano" = "scalable	$tema/scalable/apps/net.waterfox.waterfox.svg" ] \
  && ok "uma fonte SVG deriva o vetor em scalable/apps" \
  || falha "o plano de derivados não é o esperado" "$plano"
amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivados "$1" x "$2"' _ "$RAIZ/assets/icones/resgatados/ANTES-E-DEPOIS.png" "$tema" >/dev/null 2>&1
[ "$?" = "2" ] \
  && ok "raster não é fonte: um PNG é recusado com 2" \
  || falha "o derivar aceitou um PNG como fonte"
r1="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivar "$1" net.waterfox.waterfox "$2"; printf %s $?' _ "$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg" "$tema" 2>/dev/null | tail -c1)"
r2="$(amb bash -c '. "$MEOW_RAIZ/lib/comum.sh"; . "$MEOW_RAIZ/lib/icones.sh"
  meow_icones_derivar "$1" net.waterfox.waterfox "$2"; printf %s $?' _ "$RAIZ/packs/dracula/icones/apps/net.waterfox.waterfox.svg" "$tema" 2>/dev/null | tail -c1)"
[ "$r1" = "1" ] && [ "$r2" = "0" ] && [ -f "$tema/scalable/apps/net.waterfox.waterfox.svg" ] \
  && ok "o derivar escreve na primeira vez e não reescreve na segunda (1, depois 0)" \
  || falha "o derivar não é idempotente (primeira=$r1 segunda=$r2)"

# --- 8. `meow icones fonte`, de ponta a ponta --------------------------------
printf 'FLAVOR="dracula"\nACCENT="mauve"\nICONES_DRACULA="sim"\n' > "$T/meow.conf"
saida="$(amb env MEOW_CONF="$T/meow.conf" "$RAIZ/bin/meow" icones fonte net.waterfox.waterfox 2>&1)"; rc=$?
[ "$rc" = "0" ] \
  && [ "$(printf '%s\n' "$saida" | sed -n 1p)" = "fonte: packs/dracula/icones/apps/net.waterfox.waterfox.svg" ] \
  && [ "$(printf '%s\n' "$saida" | sed -n 2p)" = "deriva: scalable" ] \
  && ok "meow icones fonte diz a fonte do Waterfox e o que deriva dela" \
  || falha "meow icones fonte não respondeu como a P28 pede (rc=$rc)" "$saida"

# --- 9. regra 8: sincronizar compara e NÃO copia -----------------------------
d="$(pack_de_brinquedo copia)"
origem="$T/origem/steam.svg"; mkdir -p "$T/origem"
cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$origem"
cp "$origem" "$d/icones/apps/steam.svg"
sha_reg="$(sha256sum "$origem" | cut -d' ' -f1)"
procedencia() {
  printf '# teste\n\n| arquivo | lido de | licença | copiado em | sha256 |\n|---|---|---|---|---|\n'
  printf '| `icones/apps/steam.svg` | `%s` | GPL-3.0 | 2026-09-23 | `%s` |\n' "$1" "$sha_reg"
}
procedencia "$origem" > "$d/PROCEDENCIA.md"

saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q '1 de 1 em dia' \
  && ok "cópia e origem iguais ao registro: em dia, 0" \
  || falha "sincronizar não reconheceu uma cópia em dia (rc=$rc)" "$saida"

printf '<!-- o upstream andou -->\n' >> "$origem"
antes="$(sha256sum "$d/icones/apps/steam.svg" | cut -d' ' -f1)"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
depois="$(sha256sum "$d/icones/apps/steam.svg" | cut -d' ' -f1)"
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'ORIGEM andou' && [ "$antes" = "$depois" ] \
  && ok "a origem andou: diz que andou, sai 1, e a cópia do pack fica intacta" \
  || falha "sincronizar com a origem nova (rc=$rc, cópia mudou? $([ "$antes" = "$depois" ] && echo não || echo SIM))" "$saida"
printf '%s' "$saida" | grep -q "cp '" \
  && ok "o gesto é impresso para quem decide, e não executado" \
  || falha "sincronizar não mostrou o comando do gesto" "$saida"

cp "$RAIZ/packs/dracula/icones/apps/steam.svg" "$origem"
printf '<!-- retoque daqui -->\n' >> "$d/icones/apps/steam.svg"
o_antes="$(sha256sum "$origem" | cut -d' ' -f1)"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'RETOCADA' \
  && [ "$(sha256sum "$origem" | cut -d' ' -f1)" = "$o_antes" ] \
  && grep -q 'retoque daqui' "$d/icones/apps/steam.svg" \
  && ok "retoque daqui: é dito como retoque, e nenhum dos dois lados é tocado" \
  || falha "sincronizar tratou mal uma cópia retocada (rc=$rc)" "$saida"

cp "$origem" "$d/icones/apps/steam.svg"; rm -f "$origem"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "0" ] && printf '%s' "$saida" | grep -q 'não está nesta máquina' \
  && ok "origem fora desta máquina não é divergência: diz, e sai 0" \
  || falha "sincronizar tratou a origem ausente como divergência (rc=$rc)" "$saida"

procedencia "$T/home/.bashrc" > "$d/PROCEDENCIA.md"; : > "$T/home/.bashrc"
saida="$(pack_py sincronizar copia 2>&1)"; rc=$?
[ "$rc" = "1" ] && printf '%s' "$saida" | grep -q 'não é o mesmo tipo de arquivo' \
  && ok "a coluna 'lido de' não abre arquivo de outro tipo (um pack de terceiro escreve o dado dele)" \
  || falha "sincronizar abriu uma origem de extensão diferente (rc=$rc)" "$saida"

printf '\n'
if [ "$falhas" -eq 0 ]; then
  ok "um nome, uma fonte — e a fonte mora no repositório"
  exit 0
fi
printf 'FALHOU: %s conferência(s)\n' "$falhas" >&2
exit 1
