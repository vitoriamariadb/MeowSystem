#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }

command -v git >/dev/null 2>&1 || { printf 'pulado: sem git\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@exemplo.invalid GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@exemplo.invalid
mkdir -p "$T/falso" "$T/casa"
for c in sudo pkexec su apt apt-get pkill killall systemctl; do
  printf '#!/bin/sh\nexit 1\n' > "$T/falso/$c"; chmod 755 "$T/falso/$c"
done

TABELA="$T/tabela.tsv"
"$RAIZ/scripts/enxugar.sh" --tabela > "$TABELA"

eh_arquivo() { [[ "$(basename -- "$1")" =~ ^[^.].*\.[A-Za-z0-9]{1,8}$ ]]; }

monta() {
  local dir="$1" tipo molde caminho
  mkdir -p "$dir"
  git -C "$RAIZ" ls-files -z | (cd "$RAIZ" && tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$dir" || exit 2
  mkdir -p "$dir/docs/capturas"
  printf 'jpg guardado pelo git\n' > "$dir/docs/capturas/spotify.jpg"
  git -C "$dir" init -q -b dev
  git -C "$dir" add -f -A
  git -C "$dir" commit -q --no-verify -m base
  git -C "$dir" checkout -q --orphan arquivo
  git -C "$dir" rm -rq --cached . >/dev/null 2>&1
  printf 'registro antigo\n' > "$T/leia-arquivo"
  cp "$T/leia-arquivo" "$dir/ARQUIVO-LEIA-ME.md"
  git -C "$dir" add -f -- ARQUIVO-LEIA-ME.md
  git -C "$dir" commit -q --no-verify -m "arquivo: primeiro commit"
  git -C "$dir" checkout -q -f dev
  rm -f "$dir/ARQUIVO-LEIA-ME.md"
  while IFS=$'\t' read -r tipo molde; do
    [ -n "$tipo" ] || continue
    case "$molde" in
      *'*'*) continue ;;
    esac
    caminho="$molde"
    [ "$caminho" = "docs/capturas/spotify.jpg" ] && continue
    if eh_arquivo "$caminho"; then
      mkdir -p "$dir/$(dirname -- "$caminho")"
      printf 'conteúdo de %s\n' "$caminho" > "$dir/$caminho"
    else
      mkdir -p "$dir/$caminho/sub/__pycache__"
      printf 'um\n' > "$dir/$caminho/um.txt"
      printf 'dois\n' > "$dir/$caminho/sub/dois.txt"
      printf 'cache\n' > "$dir/$caminho/sub/__pycache__/x.pyc"
      printf 'P3\n1 1\n255\n1 2 3\n' > "$dir/$caminho/sub/imagem.png"
    fi
  done < "$TABELA"
  cp "$RAIZ/packs/meowsystem/icones/apps.map" "$dir/assets/icones/apps.map"
  printf 'outro conteúdo\n' > "$dir/assets/icones/pastas.map"
  printf 'sem par\n' > "$dir/assets/icones/appid.map"
}

instantaneo() {
  (cd "$1" && find . -path ./.git -prune -o \( -type f -o -type l \) -printf '%p %s %T@\n' | LC_ALL=C sort | sha256sum)
}

enxugar() {
  local dir="$1"; shift
  env -i PATH="$T/falso:$PATH" HOME="$T/casa" NO_COLOR=1 GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    GIT_AUTHOR_NAME=teste GIT_AUTHOR_EMAIL=teste@exemplo.invalid GIT_COMMITTER_NAME=teste GIT_COMMITTER_EMAIL=teste@exemplo.invalid \
    ${GIT_CONFIG_COUNT:+GIT_CONFIG_COUNT="$GIT_CONFIG_COUNT" GIT_CONFIG_KEY_0="$GIT_CONFIG_KEY_0" GIT_CONFIG_VALUE_0="$GIT_CONFIG_VALUE_0"} \
    "$RAIZ/scripts/enxugar.sh" --raiz "$dir" "$@" 2>&1
}

arvore() { env -i PATH="$T/falso:$PATH" HOME="$T/casa" NO_COLOR=1 bash "$1/tests/arvore.sh" 2>&1; }

caminhos_do() {
  local tipo="$1" molde
  while IFS=$'\t' read -r t molde; do
    [ "$t" = "$tipo" ] || continue
    case "$molde" in *'*'*) continue ;; esac
    [ "$molde" = "docs/capturas/spotify.jpg" ] && continue
    printf '%s\n' "$molde"
  done < "$TABELA"
}

printf '\n--- 0. o que é dela só se move: imagem solta e os originais dos ícones vão para a branch ---\n'
imagem_apagada="$(awk -F'\t' '$1 == "apagar" && tolower($2) ~ /\.(png|jpe?g|webp|gif|svg)$/ { print $2 }' "$TABELA")"
originais="$(awk -F'\t' '$2 == ".trabalho-icones" { print $1 }' "$TABELA")"
dela_apagado="$(awk -F'\t' '$1 == "apagar" && ($2 ~ /^packs(\/|$)/ || $2 == "assets/apps/jogos-fora.map") { print $2 }' "$TABELA")"
if [ -z "$imagem_apagada" ] && [ "$originais" = arquivar ] && [ -z "$dela_apagado" ]; then
  ok "nenhuma imagem solta, nada de packs/ nem o jogos-fora.map vai para apagar; os PNG desenhados à mão vão para a branch"
else
  falha "a tabela apaga o que é dela" "imagem: ${imagem_apagada:-nenhuma}
.trabalho-icones: ${originais:-fora da tabela}
packs/jogos-fora: ${dela_apagado:-nenhum}"
fi

printf '\n--- 1. sem --aplicar só mostra: lista e tamanho, nada escrito ---\n'
A="$T/a"; monta "$A"
ARQ0="$(git -C "$A" rev-parse arquivo)"; HEAD0="$(git -C "$A" rev-parse HEAD)"
ANTES="$(instantaneo "$A")"
saida="$(enxugar "$A")"; rc=$?
faltou=""
while IFS= read -r c; do grep -qF -- "$c" <<< "$saida" || faltou+="$c "; done < <(caminhos_do apagar; caminhos_do arquivar)
if [ "$rc" = 0 ] && [ -z "$faltou" ] && grep -q 'nada foi escrito' <<< "$saida" \
   && grep -qE '^apagar: [0-9]' <<< "$saida" && grep -qE '^arquivo +[0-9,]+ (B|KB|MB|GB) ' <<< "$saida" \
   && [ "$(instantaneo "$A")" = "$ANTES" ] && [ "$(git -C "$A" rev-parse arquivo)" = "$ARQ0" ]; then
  ok "a lista traz cada caminho da tabela com destino e tamanho, e a pasta não mudou (rc=0)"
else
  falha "o ensaio escreveu ou deixou caminho de fora (rc=$rc, faltou: ${faltou:-nada})" "$saida"
fi
grep -qE 'apagar +[0-9,]+ (B|KB|MB|GB) +[0-9]+ +assets/icones/apps\.map +\(igual ao do pack\)' <<< "$saida" \
  && grep -qE 'arquivo +[0-9,]+ (B|KB|MB|GB) +[0-9]+ +assets/icones/pastas\.map' <<< "$saida" \
  && grep -qE 'arquivo +[0-9,]+ (B|KB|MB|GB) +[0-9]+ +assets/icones/appid\.map' <<< "$saida" \
  && ok "o mapa igual ao do pack vai para apagar; o diferente e o sem par vão para a branch" \
  || falha "os mapas não foram separados pela comparação com o pack" "$saida"
grep -qE 'fica +[0-9,]+ (B|KB|MB|GB) +1 +docs/capturas/spotify\.jpg' <<< "$saida" \
  && ok "o que o git guarda aparece como «fica»" || falha "o arquivo versionado não apareceu como «fica»" "$saida"
saida_arvore="$(arvore "$A")"
grep -q 'NÃO  sobra na pasta' <<< "$saida_arvore" \
  && ok "a regra da árvore acusa a pasta antes de enxugar" || falha "o tests/arvore.sh não acusou a pasta cheia"

printf '\n--- 2. --aplicar: o registro vai à branch arquivo por worktree, o resto é apagado ---\n'
declare -A SOMA=()
while IFS= read -r c; do
  if [ -f "$A/$c" ]; then SOMA["$c"]="$(sha256sum < "$A/$c")"
  else SOMA["$c/um.txt"]="$(sha256sum < "$A/$c/um.txt")"; SOMA["$c/sub/imagem.png"]="$(sha256sum < "$A/$c/sub/imagem.png")"; fi
done < <(caminhos_do arquivar)
SOMA["assets/icones/pastas.map"]="$(sha256sum < "$A/assets/icones/pastas.map")"
SOMA["assets/icones/appid.map"]="$(sha256sum < "$A/assets/icones/appid.map")"
mkdir -p "$T/ganchos"; printf '#!/bin/sh\nexit 1\n' > "$T/ganchos/pre-commit"; chmod 755 "$T/ganchos/pre-commit"
printf '#!/bin/sh\nexit 1\n' > "$T/ganchos/commit-msg"; chmod 755 "$T/ganchos/commit-msg"
saida="$(GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0="$T/ganchos" enxugar "$A" --aplicar)"; rc=$?
sobrou=""
while IFS= read -r c; do [ -e "$A/$c" ] && sobrou+="$c "; done < <(caminhos_do apagar; caminhos_do arquivar)
[ -e "$A/assets/icones/apps.map" ] && sobrou+="apps.map "
[ -e "$A/assets/icones/pastas.map" ] && sobrou+="pastas.map "
if [ -z "$sobrou" ] && [ -f "$A/docs/capturas/spotify.jpg" ] && [ -d "$A/assets/papeis-de-parede" ]; then
  ok "tudo o que a tabela manda apagar ou arquivar saiu; o versionado e o acervo do doctor ficaram"
else
  falha "sobrou ou sumiu o que não devia (sobrou: ${sobrou:-nada})" "$saida"
fi
[ "$rc" = 3 ] && grep -q 'pendente: assets/papeis-de-parede' <<< "$saida" \
  && ok "com o acervo de papel de parede ainda no clone, o script termina em 3 e manda rodar o doctor" \
  || falha "o pendente do doctor não foi dito (rc=$rc)" "$saida"
ARQ1="$(git -C "$A" rev-parse arquivo)"
faltam=""
for c in "${!SOMA[@]}"; do
  [ "$(git -C "$A" show "arquivo:levas/2026-10-27-pasta-local/$c" 2>/dev/null | sha256sum)" = "${SOMA[$c]}" ] || faltam+="$c "
done
if [ "$ARQ1" != "$ARQ0" ] && [ "$(git -C "$A" rev-list --count "$ARQ0..$ARQ1")" = 1 ] && [ -z "$faltam" ] \
   && git -C "$A" cat-file -e "arquivo:ARQUIVO-LEIA-ME.md" 2>/dev/null \
   && git -C "$A" cat-file -e "arquivo:levas/2026-10-27-pasta-local/LEIA-ME.md" 2>/dev/null; then
  ok "a branch arquivo ganhou UM commit com cada arquivo byte a byte (inclusive imagem ignorada pelo .gitignore), e o que já tinha ficou"
else
  falha "o commit na branch arquivo está errado (faltam: ${faltam:-nenhum}, novos: $(git -C "$A" rev-list --count "$ARQ0..$ARQ1"))" "$saida"
fi
if git -C "$A" ls-tree -r --name-only arquivo | grep -qE '__pycache__|\.pyc$'; then
  falha "cache do Python foi para a branch arquivo"
else
  ok "__pycache__ não viaja para a branch arquivo"
fi
if [ "$(git -C "$A" rev-parse --abbrev-ref HEAD)" = dev ] && [ "$(git -C "$A" rev-parse HEAD)" = "$HEAD0" ] \
   && [ "$(git -C "$A" worktree list | wc -l)" = 1 ] && [ ! -d "$A/.git/worktrees" ] \
   && [ -z "$(git -C "$A" status --porcelain --untracked-files=no)" ]; then
  ok "o checkout principal segue em dev, no mesmo commit, sem worktree sobrando; o hook que recusa tudo não barrou o commit do arquivo"
else
  falha "o enxugar mexeu na branch do checkout principal ou deixou worktree" "$(git -C "$A" worktree list; git -C "$A" status --short | head)"
fi

printf '\n--- 3. o doctor moveu o acervo: a segunda passada fecha e não escreve ---\n'
rm -rf "$A/assets/papeis-de-parede"
saida="$(enxugar "$A" --aplicar)"; rc=$?
ANTES="$(instantaneo "$A")"
saida2="$(enxugar "$A" --aplicar)"; rc2=$?
if [ "$rc" = 0 ] && [ "$rc2" = 0 ] && [ "$(git -C "$A" rev-parse arquivo)" = "$ARQ1" ] \
   && [ "$(instantaneo "$A")" = "$ANTES" ] && grep -q 'nada a enxugar' <<< "$saida2"; then
  ok "sem pendência o script sai em 0, não faz commit novo e a repetição não muda nada"
else
  falha "a repetição escreveu ou o final não foi 0 (rc=$rc/$rc2)" "$saida
$saida2"
fi
saida_arvore="$(arvore "$A")"
if grep -q 'ok: a fronteira está de pé' <<< "$saida_arvore"; then
  ok "depois de enxugar, o tests/arvore.sh do clone passa"
else
  falha "o tests/arvore.sh continua vermelho depois de enxugar" "$(tail -8 <<< "$saida_arvore")"
fi

printf '\n--- 4. se a branch arquivo não abre, o registro fica e só o cache sai ---\n'
B="$T/b"; monta "$B"
rm -rf "$B/assets/papeis-de-parede"
git -C "$B" worktree add -q "$T/ocupa-arquivo" arquivo
saida="$(enxugar "$B" --aplicar)"; rc=$?
registro_ficou=1
while IFS= read -r c; do [ -e "$B/$c" ] || registro_ficou=0; done < <(caminhos_do arquivar)
cache_saiu=1
while IFS= read -r c; do [ -e "$B/$c" ] && cache_saiu=0; done < <(caminhos_do apagar)
if [ "$rc" = 1 ] && [ "$registro_ficou" = 1 ] && [ "$cache_saiu" = 1 ] \
   && grep -q 'não consegui' <<< "$saida"; then
  ok "sem onde guardar o registro nada de registro é apagado; o cache saiu e o script falha (rc=$rc)"
else
  falha "a falha do worktree apagou registro ou não avisou (rc=$rc, registro_ficou=$registro_ficou, cache_saiu=$cache_saiu)" "$saida"
fi

printf '\n--- 4b. arquivo que não chega igual à branch: nada de registro é apagado ---\n'
D="$T/d"; monta "$D"
rm -rf "$D/assets/papeis-de-parede"
printf '*.txt filter=muda\n' > "$T/atributos"
git -C "$D" config core.attributesFile "$T/atributos"
git -C "$D" config filter.muda.clean "sed s/um/UM/"
ARQ_D0="$(git -C "$D" rev-parse arquivo)"
saida="$(enxugar "$D" --aplicar)"; rc=$?
registro_ficou=1
while IFS= read -r c; do [ -e "$D/$c" ] || registro_ficou=0; done < <(caminhos_do arquivar)
if [ "$rc" = 1 ] && [ "$registro_ficou" = 1 ] && [ "$(git -C "$D" rev-parse arquivo)" = "$ARQ_D0" ] \
   && grep -q 'não chegou igual' <<< "$saida"; then
  ok "o conteúdo é conferido arquivo a arquivo contra o que a branch recebeu: diferente, nada sai e não há commit (rc=1)"
else
  falha "um arquivo mudado no caminho passou pela conferência (rc=$rc, registro_ficou=$registro_ficou)" "$saida"
fi
git -C "$D" config --unset core.attributesFile
git -C "$D" config --remove-section filter.muda

printf '\n--- 4c. segunda leva: o que já está na branch sai sem commit novo, e a lista do LEIA-ME só cresce ---\n'
saida="$(enxugar "$D" --aplicar)"; rc=$?
ARQ_D1="$(git -C "$D" rev-parse arquivo)"
git -C "$D" show "arquivo:levas/2026-10-27-pasta-local/docs/folhas/um.txt" > /dev/null 2>&1 || falha "a primeira leva não arquivou docs/folhas" "$saida"
mkdir -p "$D/docs/folhas"
git -C "$D" show "arquivo:levas/2026-10-27-pasta-local/docs/folhas/um.txt" > "$D/docs/folhas/um.txt"
saida2="$(enxugar "$D" --aplicar)"; rc2=$?
printf 'outra captura\n' > "$D/aba7.png"
saida3="$(enxugar "$D" --aplicar)"; rc3=$?
ARQ_D3="$(git -C "$D" rev-parse arquivo)"
leia="$(git -C "$D" show "arquivo:levas/2026-10-27-pasta-local/LEIA-ME.md" 2>/dev/null)"
faltou_na_lista=""
while IFS= read -r c; do grep -qxF -- "- \`$c\`" <<< "$leia" || faltou_na_lista+="$c "; done < <(caminhos_do arquivar)
if [ "$rc" = 0 ] && [ "$rc2" = 0 ] && [ "$rc3" = 0 ] && [ ! -e "$D/docs/folhas" ] && [ ! -e "$D/aba7.png" ] \
   && [ "$(git -C "$D" rev-list --count "$ARQ_D1..$ARQ_D3")" = 1 ] && [ -z "$faltou_na_lista" ] \
   && [ "$(git -C "$D" show "arquivo:levas/2026-10-27-pasta-local/aba7.png")" = "outra captura" ] \
   && git -C "$D" cat-file -e "arquivo:levas/2026-10-27-pasta-local/docs/pesquisas/sub/imagem.png" 2>/dev/null \
   && git -C "$D" cat-file -e "arquivo:levas/2026-10-27-pasta-local/Imagem colada.png" 2>/dev/null; then
  ok "repetido igual: sai sem commit; novo: um commit, e o LEIA-ME guarda os caminhos das duas levas"
else
  falha "a segunda leva perdeu a lista ou fez commit à toa (rc=$rc/$rc2/$rc3, commits=$(git -C "$D" rev-list --count "$ARQ_D1..$ARQ_D3"), faltou: ${faltou_na_lista:-nada})" "$saida2
$saida3"
fi

printf '\n--- 5. recusas ---\n'
saida="$(enxugar "$T/casa" --aplicar)"; rc=$?
[ "$rc" = 2 ] && ok "pasta que não é clone git: recusa (rc=2)" || falha "aceitou pasta sem git (rc=$rc)" "$saida"
saida="$(enxugar "$A" --sim-para-tudo)"; rc=$?
[ "$rc" = 2 ] && ok "opção desconhecida: recusa (rc=2); o script não tem pergunta interativa" || falha "opção estranha não foi recusada (rc=$rc)"

printf '\n'
if [ "$ACHADOS" = 0 ]; then
  printf 'ok: o enxugar lista antes, guarda o registro na branch arquivo e só então apaga\n'
  exit 0
fi
printf 'NÃO: %d verificação(ões) falharam\n' "$ACHADOS" >&2
exit 1
