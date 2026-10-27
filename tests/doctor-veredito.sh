#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf '  NÃO  %s\n' "$*" >&2; ACHADOS=$((ACHADOS + 1)); }
ACHADOS=0

TMP="$(mktemp -d)" || { printf 'erro: mktemp\n' >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
FALSO="$TMP/falso"; mkdir -p "$FALSO" || exit 2
export DOCTOR_REGISTRO="$TMP/registro"; : > "$DOCTOR_REGISTRO"
for c in sudo pkill killall notify-send systemd-run pkexec; do
  printf '#!/bin/sh\necho "$(basename "$0") $*" >> "$DOCTOR_REGISTRO"\nexit 1\n' > "$FALSO/$c"
  chmod 755 "$FALSO/$c"
done

cenario() {
  local defs="$1"; shift
  local casa="${CASA_CENARIO:-$TMP/casa-$RANDOM}"
  mkdir -p "$casa/.config/meow"
  cp "$RAIZ/meow.conf.exemplo" "$casa/.config/meow/meow.conf"
  env PATH="${PATH_CENARIO:-$FALSO}:$PATH" HOME="$casa" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    XDG_CONFIG_HOME="$casa/.config" XDG_STATE_HOME="$casa/.local/state" \
    bash -c '
      source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow")
      source "$1"; shift
      "${CMD_CENARIO:-cmd_doctor}" "$@"' _ "$defs" "$@" 2>&1
}

printf '\n--- 1. o veredito sem conserto ---\n'
cat > "$TMP/c1" <<'FIM'
VERIFICAVEIS=(a b)
chk_a() { echo "tudo certo"; return 0; }
chk_b() { meow_aviso "a peça não está no disco — pulado"; return 3; }
FIM
saida="$(cenario "$TMP/c1")"; rc=$?
if [ "$rc" = "1" ] && ! grep -q 'nada a consertar' <<< "$saida" \
   && grep -qE '^ *!! +b ' <<< "$saida"; then
  ok "o pulado que avisou sai em !!, e o doctor sai 1 sem «nada a consertar»"
else
  falha "o pulado que avisou não pesou (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c2" <<'FIM'
VERIFICAVEIS=(a b)
chk_a() { echo "tudo certo"; return 0; }
chk_b() { meow_pula "o Heroic não está instalado — nada a fazer"; return 3; }
FIM
saida="$(cenario "$TMP/c2")"; rc=$?
if [ "$rc" = "0" ] && grep -q 'nada a consertar' <<< "$saida"; then
  ok "o pulado de rotina (--) não é divergência"
else
  falha "o pulado de rotina virou divergência (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c2c" <<'FIM'
VERIFICAVEIS=(prompt)
FIM
mkdir -p "$TMP/casa-recusa/.local/state/meowsystem"
: > "$TMP/casa-recusa/.local/state/meowsystem/starship-recusado"
sem_starship="$(printf '%s' "$PATH" | tr ':' '\n' | while IFS= read -r d; do
  [ -n "$d" ] && [ ! -x "$d/starship" ] && printf '%s:' "$d"; done)"
saida="$(PATH="${sem_starship%:}" CASA_CENARIO="$TMP/casa-recusa" cenario "$TMP/c2c")"; rc=$?
if [ "$rc" = "0" ] && grep -qE '^ *-- +prompt ' <<< "$saida" && grep -q 'nada a consertar' <<< "$saida"; then
  ok "o starship recusado sai em --, e o doctor sai 0"
else
  falha "a recusa do starship pesou como divergência (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c2b" <<'FIM'
VERIFICAVEIS=(a b c)
chk_a() { echo "tudo certo"; return 0; }
chk_b() { meow_pula "o Heroic não está instalado — nada a fazer"; return 3; }
chk_c() { meow_pula "o applet desligou o 'Agendar' — o degrau é o que você arrastou"; return 4; }
FIM
saida="$(CMD_CENARIO=cmd_status cenario "$TMP/c2b")"; rc=$?
if [ "$rc" = "0" ] && grep -q 'nada divergente' <<< "$saida" \
   && ! grep -q 'meow doctor --consertar' <<< "$saida"; then
  ok "o status não chama de divergência o pulado nem a escolha dela"
else
  falha "o status chamou de divergência o que foi pulado (rc=$rc)"; sed -n '/Divergências/,$p' <<< "$saida" | sed 's/^/       /' >&2
fi

printf '\n--- 2. o --consertar termina pelo depois ---\n'
cat > "$TMP/c3" <<'FIM'
VERIFICAVEIS=(dep b)
M="$HOME/marca"
chk_dep() { [ -f "$M.dep" ] && { echo "dep no lugar"; return 0; }; echo "falta dep"; return 1; }
fix_dep() { : > "$M.dep"; echo "dep posta"; return 1; }
chk_b() {
  [ -f "$M.dep" ] || { meow_aviso "sem dep — b pulado"; return 3; }
  [ -f "$M.b" ] && { echo "b no lugar"; return 0; }
  echo "b fora"; return 1
}
fix_b() { : > "$M.b"; echo "b posto"; return 1; }
FIM
saida="$(cenario "$TMP/c3" --consertar)"; rc=$?
if [ "$rc" = "1" ] && grep -q 'b posto' <<< "$saida" && grep -q 'consertado' <<< "$saida"; then
  ok "o 3 cuja dependência chegou na mesma passada foi consertado (rc=1, «consertado»)"
else
  falha "o 3 com a dependência recém-posta não foi consertado (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c4" <<'FIM'
VERIFICAVEIS=(a convertidos)
chk_a() { echo "tudo certo"; return 0; }
chk_convertidos() { echo "falta reconverter"; return 1; }
FIM
saida="$(cenario "$TMP/c4" --consertar)"; rc=$?
if [ "$rc" = "2" ] && grep -q 'convertidos — continua fora' <<< "$saida" \
   && ! grep -q 'nada a consertar' <<< "$saida"; then
  ok "o que não tem conserto automático termina vermelho e nomeado (rc=2)"
else
  falha "o sem-conserto terminou como se nada estivesse fora (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c5" <<'FIM'
VERIFICAVEIS=(a)
chk_a() { echo "a fora"; return 1; }
fix_a() { echo "a consertado (mentira)"; return 1; }
FIM
saida="$(cenario "$TMP/c5" --consertar)"; rc=$?
if [ "$rc" = "2" ] && ! grep -q 'consertado —' <<< "$saida"; then
  ok "o conserto que diz que fez e não fez não vira «consertado» (rc=2)"
else
  falha "o conserto que não fez virou «consertado» (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

cat > "$TMP/c5b" <<'FIM'
VERIFICAVEIS=(a b)
M="$HOME/marca"
chk_a() { [ -f "$M.b" ] && { echo "a desarrumada pelo b"; return 1; }; echo "a no lugar"; return 0; }
chk_b() { [ -f "$M.b" ] && { echo "b no lugar"; return 0; }; echo "b fora"; return 1; }
fix_b() { : > "$M.b"; echo "b posto"; return 1; }
FIM
saida="$(cenario "$TMP/c5b" --consertar)"; rc=$?
if [ "$rc" = "2" ] && grep -q '^ *erro a — continua fora' <<< "$saida" \
   && ! grep -q 'tudo no lugar' <<< "$saida"; then
  ok "a linha que estava no lugar e o conserto de outra desarrumou é nomeada (rc=2)"
else
  falha "a passada não viu a linha que o conserto desarrumou (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

PONTE_DIR="$TMP/ponte"; mkdir -p "$PONTE_DIR"
cat > "$PONTE_DIR/ponte_root.sh" <<'FIM'
#!/bin/sh
[ "$1" = "pacotes" ] || exit 0
cat > "$PONTE_DIR_REG/recebido"
: > "$PONTE_DIR_REG/instalado"
FIM
chmod 755 "$PONTE_DIR/ponte_root.sh"
cat > "$TMP/c6" <<'FIM'
VERIFICAVEIS=(pacotes)
SEM_CONSERTO=" "
_pacotes_faltando() { [ -f "$PONTE_DIR_REG/instalado" ] || echo papirus-icon-theme; }
FIM
mkdir -p "$TMP/sudo-ponte"
cat > "$TMP/sudo-ponte/sudo" <<FIM
#!/bin/sh
[ "\$1" = "-n" ] && [ "\$2" = "$PONTE_DIR/ponte_root.sh" ] && { shift; exec "\$@"; }
echo "sudo \$*" >> "\$DOCTOR_REGISTRO"; exit 1
FIM
chmod 755 "$TMP/sudo-ponte/sudo"
printf 'lar=%s\n' "$TMP/casa-ponte" > "$PONTE_DIR/perfil"
saida="$(PATH_CENARIO="$TMP/sudo-ponte:$FALSO" MEOW_PONTE="$PONTE_DIR/ponte_root.sh" PONTE_DIR_REG="$PONTE_DIR" \
         CASA_CENARIO="$TMP/casa-ponte" cenario "$TMP/c6" --consertar)"; rc=$?
if [ "$rc" = "1" ] && [ "$(cat "$PONTE_DIR/recebido" 2>/dev/null)" = "papirus-icon-theme" ] \
   && grep -q 'consertado' <<< "$saida"; then
  ok "o pacote que falta foi pela ponte root (stdin: papirus-icon-theme), sem senha, e terminou verde"
else
  falha "o pacote que falta não foi pela ponte (rc=$rc)"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
fi

printf '\n--- 3. a base de ícones que falta ---\n'
CASA="$TMP/casa-base"; mkdir -p "$CASA/.local/share/icons/MeowSystem-Icons/scalable/apps"
printf '[Icon Theme]\nName=MeowSystem-Icons\nDirectories=scalable/apps\n\n[scalable/apps]\nSize=48\nType=Scalable\n' \
  > "$CASA/.local/share/icons/MeowSystem-Icons/index.theme"
for s in completar_icones construir_pastas; do
  saida="$(env PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 MEOW_DRY_RUN=1 \
             ICONES_BASE="Base-Que-Nao-Existe" ICONES_PASTAS="cat-mocha-mauve" \
             MEOW_CAT_FOLDERS="$TMP/sem-upstream" "$RAIZ/scripts/$s.sh" 2>&1)"; rc=$?
  if { [ "$rc" = "3" ] || [ "$rc" = "1" ]; } && grep -qE '^ *!! .*Base-Que-Nao-Existe' <<< "$saida" \
     && ! grep -qiE 'apt(-get)? install|instale com' <<< "$saida"; then
    ok "$s: sem a base sai $rc (não 0), com !! e sem receita"
  else
    falha "$s: sem a base saiu $rc"; printf '%s\n' "$saida" | sed 's/^/       /' >&2
  fi
done

printf '\n--- 4. a passada inteira, sem receita ---\n'
CASA="$TMP/casa-inteira"; mkdir -p "$CASA"
env PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" doctor > "$TMP/inteira" 2>&1
if grep -qiE 'apt(-get)? install|instale com' "$TMP/inteira"; then
  falha "o doctor ainda imprime receita:"; grep -iE 'apt(-get)? install|instale com' "$TMP/inteira" | sed 's/^/       /' >&2
else
  ok "nenhuma linha do doctor manda instalar à mão"
fi
vazias="$(grep -E '^  (ok|~~|--|!!|erro) +[a-z_]+( *| .*:)$' "$TMP/inteira")"
if [ -n "$vazias" ]; then
  falha "linha da tabela vazia ou cortada:"; printf '%s\n' "$vazias" | sed 's/^/       /' >&2
else
  ok "toda linha da tabela diz alguma coisa inteira"
fi

printf '\n--- 5. a lista da ponte é a do install.sh ---\n'
do_install="$( (sed -n '/^etapa_pacotes()/,/^}/p' "$RAIZ/install.sh" \
  | grep -oE '\]=[a-zA-Z0-9_.+-]+|faltam\+=\([a-zA-Z0-9_.+-]+\)' \
  | sed -E 's/^\]=//; s/^faltam\+=\((.*)\)$/\1/'
  sed -n '/^MEOW_DEPS_DOS_APPLETS=/,/"$/p' "$RAIZ/lib/comum.sh" | grep -oE '\|[a-z0-9.+-]+' | tr -d '|' \
  ) | LC_ALL=C sort -u | paste -sd' ' -)"
da_ponte="$(sed -n 's/^ *PERMITIDOS=" \(.*\) "$/\1/p' "$RAIZ/scripts/ponte_root.sh" \
  | tr ' ' '\n' | LC_ALL=C sort -u | paste -sd' ' -)"
if [ -n "$do_install" ] && [ "$do_install" = "$da_ponte" ]; then
  ok "a ponte instala exatamente os pacotes do install.sh ($do_install)"
else
  falha "as listas divergem — install.sh: [$do_install] · ponte: [$da_ponte]"
fi

printf '\n--- 6. a ponte não segue link no destino do greeter (P82, item 16) ---\n'
PONTE_COPIA="$TMP/ponte-copia.sh"
LAR_G="$TMP/greeter"
sed -e "s#^GREETER_HOME=.*#GREETER_HOME=\"$LAR_G\"#" \
    -e "s#^GREETER_DONO=.*#GREETER_DONO=\"$(id -un)\"#" \
    -e 's#^anotar() {#anotar() { return 0#' \
    "$RAIZ/scripts/ponte_root.sh" > "$PONTE_COPIA"
DESTINO_G="$LAR_G/.config/cosmic/com.system76.CosmicTheme.Dark/v1"
mkdir -p "$DESTINO_G" "$TMP/alvo-do-elo" "$TMP/tar/com.system76.CosmicTheme.Dark/v1"
printf 'de fora\n' > "$TMP/alvo-do-elo/segredo"
ln -s "$TMP/alvo-do-elo/segredo" "$DESTINO_G/accent"
printf 'isca\n' > "$TMP/tar/com.system76.CosmicTheme.Dark/v1/accent"
( cd "$TMP/tar" && tar -cf - . ) | bash "$PONTE_COPIA" greeter-aplicar >/dev/null 2>"$TMP/ponte.err"; rc_ponte=$?
if [ "$rc_ponte" -ne 0 ] && [ "$(cat "$TMP/alvo-do-elo/segredo")" = "de fora" ]; then
  ok "um link simbólico no destino recusa o greeter-aplicar (rc=$rc_ponte), e nada é escrito através dele"
else
  falha "o greeter-aplicar seguiu o link do destino (rc=$rc_ponte; o alvo de fora diz '$(cat "$TMP/alvo-do-elo/segredo")')"
fi
rm -f "$DESTINO_G/accent"
( cd "$TMP/tar" && tar -cf - . ) | bash "$PONTE_COPIA" greeter-aplicar >/dev/null 2>>"$TMP/ponte.err"; rc_ponte=$?
if [ "$rc_ponte" -eq 0 ] && [ "$(cat "$LAR_G/.config/cosmic/com.system76.CosmicTheme.Dark/v1/accent" 2>/dev/null)" = "isca" ]; then
  ok "sem link no destino, o greeter-aplicar copia como antes"
else
  falha "sem link no destino, o greeter-aplicar não copiou (rc=$rc_ponte): $(tail -2 "$TMP/ponte.err")"
fi
mkfifo "$TMP/tar/com.system76.CosmicTheme.Dark/v1/cano"
( cd "$TMP/tar" && tar -cf - . ) | bash "$PONTE_COPIA" greeter-aplicar >/dev/null 2>>"$TMP/ponte.err"; rc_ponte=$?
if [ "$rc_ponte" -ne 0 ] && [ ! -e "$DESTINO_G/cano" ]; then
  ok "um FIFO no tar recusa o greeter-aplicar (rc=$rc_ponte), e nada chega ao destino"
else
  falha "o greeter-aplicar aceitou um FIFO no tar (rc=$rc_ponte)"
fi
rm -f "$TMP/tar/com.system76.CosmicTheme.Dark/v1/cano"

printf '\n--- 7. o instalar_fontes.sh pede a ferramenta que falta pela ponte (P82, item 16) ---\n'
SEM_CURL="$TMP/sem-curl"; INST="$TMP/instalado"; PONTE2="$TMP/ponte2"
mkdir -p "$SEM_CURL" "$INST" "$PONTE2" "$TMP/sudo-ponte2" "$TMP/casa-fontes/.config"
for b in /usr/bin/*; do
  [ "${b##*/}" = curl ] || ln -s "$b" "$SEM_CURL/${b##*/}" 2>/dev/null
done
cat > "$PONTE2/ponte_root.sh" <<FIM
#!/bin/sh
[ "\$1" = "pacotes" ] || exit 0
cat > "$PONTE2/recebido"
grep -qx curl "$PONTE2/recebido" && { printf '#!/bin/sh\nexit 1\n' > "$INST/curl"; chmod 755 "$INST/curl"; }
exit 0
FIM
chmod 755 "$PONTE2/ponte_root.sh"
printf 'lar=%s\n' "$TMP/casa-fontes" > "$PONTE2/perfil"
cat > "$TMP/sudo-ponte2/sudo" <<FIM
#!/bin/sh
[ "\$1" = "-n" ] && [ "\$2" = "$PONTE2/ponte_root.sh" ] && { shift; exec "\$@"; }
echo "sudo \$*" >> "\$DOCTOR_REGISTRO"; exit 1
FIM
chmod 755 "$TMP/sudo-ponte2/sudo"
saida="$(env -i PATH="$TMP/sudo-ponte2:$FALSO:$INST:$SEM_CURL" HOME="$TMP/casa-fontes" NO_COLOR=1 \
           DOCTOR_REGISTRO="$DOCTOR_REGISTRO" MEOW_PONTE="$PONTE2/ponte_root.sh" \
           bash "$RAIZ/scripts/instalar_fontes.sh" 2>&1)"
if [ "$(cat "$PONTE2/recebido" 2>/dev/null)" = "curl" ] && ! grep -q 'faltam ferramentas' <<< "$saida"; then
  ok "sem curl, o instalar_fontes.sh o pede pela ponte (stdin: curl) e segue, sem «faltam ferramentas»"
else
  falha "sem curl, o instalar_fontes.sh não pediu pela ponte (recebido: '$(cat "$PONTE2/recebido" 2>/dev/null)')"
  printf '%s\n' "$saida" | grep -i 'falta\|ponte' | head -5 | sed 's/^/       /' >&2
fi

printf '\n--- 8. o starship é opcional (P82, item 2; decisão 14) ---\n'
CASA_S="$TMP/casa-starship"; mkdir -p "$CASA_S/.config/meow"
cp "$RAIZ/meow.conf.exemplo" "$CASA_S/.config/meow/meow.conf"
SEM_STARSHIP="$TMP/sem-starship"; mkdir -p "$SEM_STARSHIP"
for b in /usr/bin/*; do
  [ "${b##*/}" = starship ] || ln -s "$b" "$SEM_STARSHIP/${b##*/}" 2>/dev/null
done
saida="$(env -i PATH="$FALSO:$SEM_STARSHIP" HOME="$CASA_S" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
           MEOW_DRY_RUN=1 PROMPT_STARSHIP=sim "$RAIZ/scripts/prompt.sh" conferir 2>&1)"; rc=$?
if [ "$rc" = 3 ] && ! grep -qE '^[[:space:]]*!! ' <<< "$saida"; then
  ok "sem starship, a linha prompt é pulado de rotina (rc=3, sem !!): o doctor não fica vermelho por ela"
else
  falha "sem starship, a linha prompt pesa no veredito (rc=$rc): $(grep -E '!!' <<< "$saida" | head -2 | tr '\n' ' ')"
fi
mkdir -p "$CASA_S/.cargo/bin"; printf '#!/bin/sh\nexit 0\n' > "$CASA_S/.cargo/bin/starship"
chmod 755 "$CASA_S/.cargo/bin/starship"
acoes="$(env -i PATH="$SEM_STARSHIP" HOME="$CASA_S" MEOW_RAIZ="$RAIZ" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
print("tem=%s" % ("prompt_instalar_starship" in servidor.ACOES or "prompt_instalar_starship" in servidor.ACAO_DA_PENDENCIA.values()))
PY
)"
[ "$acoes" = "tem=False" ] \
  && ok "o painel não oferece mais «Instalar o starship»: quem o instala é o install" \
  || falha "o painel ainda oferece instalar o starship ($acoes)"

printf '\n--- 9. o starship desce com o install (decisão de 23/10) ---\n'
CASA_I="$TMP/casa-install"; mkdir -p "$CASA_I/.config/meow" "$TMP/curl-starship"
cp "$RAIZ/meow.conf.exemplo" "$CASA_I/.config/meow/meow.conf"
cat > "$TMP/curl-starship/curl" <<CURL
#!/bin/sh
echo "\$*" >> "$TMP/curl-starship.log"
printf '%s\n' 'while [ "\$#" -gt 0 ]; do [ "\$1" = --bin-dir ] && d="\$2"; shift; done' \
  'mkdir -p "\$d" && printf "#!/bin/sh\nexit 0\n" > "\$d/starship" && chmod 755 "\$d/starship"'
CURL
chmod 755 "$TMP/curl-starship/curl"; : > "$TMP/curl-starship.log"
instalar() { env -i PATH="$TMP/curl-starship:$FALSO:$SEM_STARSHIP" HOME="$CASA_I" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
               PROMPT_STARSHIP=sim "$RAIZ/scripts/prompt.sh" instalar 2>&1; }
mkdir -p "$CASA_I/.local/state/meowsystem"; : > "$CASA_I/.local/state/meowsystem/starship-recusado"
saida="$(instalar)"; rc=$?
[ "$rc" = 3 ] && [ ! -s "$TMP/curl-starship.log" ] \
  && ok "com a recusa gravada, o install não baixa o starship" \
  || falha "o install baixou o starship recusado (rc=$rc)"
rm -f "$CASA_I/.local/state/meowsystem/starship-recusado"
saida="$(instalar)"; rc=$?
if [ "$rc" = 1 ] && [ -x "$CASA_I/.local/bin/starship" ] && [ -f "$CASA_I/.config/starship.toml" ] \
   && grep -q 'starship.rs/install.sh' "$TMP/curl-starship.log"; then
  ok "sem starship, o install o baixa para ~/.local/bin e põe o preset"
else
  falha "o install não instalou o starship (rc=$rc): $(tail -2 <<< "$saida" | tr '\n' ' ')"
fi
n="$(grep -c . "$TMP/curl-starship.log")"
saida="$(instalar)"; rc=$?
[ "$rc" = 0 ] && [ "$(grep -c . "$TMP/curl-starship.log")" = "$n" ] \
  && ok "a segunda passada não baixa nem escreve" || falha "a segunda passada baixou ou escreveu (rc=$rc)"
grep -q '"$MEOW_RAIZ/scripts/prompt.sh" instalar$' "$RAIZ/install.sh" \
  && ok "a etapa do prompt do install chama o instalar" || falha "a etapa do prompt do install não instala o starship"
printf '\n'
if [ "$ACHADOS" -gt 0 ]; then
  printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2
  exit 1
fi
printf 'passou: o doctor corrige, e o veredito é o pior estado\n'
exit 0
