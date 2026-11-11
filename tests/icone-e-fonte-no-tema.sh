#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

H="$T/home"; C="$H/.config/cosmic"; TK="$C/com.system76.CosmicTk/v1"
mkdir -p "$T/falso" "$TK"
for c in sudo pkexec su apt apt-get pkill killall systemctl notify-send; do
  printf '#!/bin/sh\nexit 1\n' > "$T/falso/$c"; chmod 755 "$T/falso/$c"
done
CASAS=(Dark Light Dark.Builder Light.Builder)
for n in "${CASAS[@]}"; do
  mkdir -p "$C/com.system76.CosmicTheme.$n/v2"; echo true > "$C/com.system76.CosmicTheme.$n/v2/is_dark"
done
printf '(\n    family: "Fira Sans",\n    weight: Normal,\n    stretch: Normal,\n    style: Normal,\n)' > "$TK/interface_font"

amb() {
  env -i PATH="$T/falso:$PATH" HOME="$H" USER="${USER:-t}" LANG=C.UTF-8 NO_COLOR=1 MEOW_IGNORA_DESKTOP=1 \
      MEOW_SEM_REDE=1 FLAVOR=mocha LOGO=mocha ACCENT=mauve MEOW_ESTADO="$T/estado" MEOW_CONF="$T/nao-existe.conf" MEOW_RAIZ="$RAIZ" "$@"
}
doutor() { local f="$1"; shift; amb "$@" bash -c 'source <(sed "/^despachar \"\\\$@\"\$/d" "$MEOW_RAIZ/bin/meow"); '"$f" 2>&1; }
foto() { (cd "$C" && find . -type f -printf '%p %T@ ' -exec sha256sum {} + | sort | sha256sum); }

echo "== 1. o ícone: as quatro casas do tema e o Tk, e a segunda passada não escreve"
amb bash "$RAIZ/scripts/construir_icones.sh" >"$T/i1" 2>&1
for n in "${CASAS[@]}"; do
  igual "CosmicTheme.$n/v2/icon_theme" "$(cat "$C/com.system76.CosmicTheme.$n/v2/icon_theme" 2>/dev/null)" '"MeowSystem-Icons"'
done
igual "CosmicTk/v1/icon_theme" "$(cat "$TK/icon_theme" 2>/dev/null)" '"MeowSystem-Icons"'
f1="$(foto)"
amb bash "$RAIZ/scripts/construir_icones.sh" >"$T/i2" 2>&1; rc=$?
igual "a segunda passada sai 0" "$rc" 0
igual "e não escreve nada na árvore do COSMIC" "$(foto)" "$f1"

echo "== 2. a fonte: font copia a interface_font do Tk, mono_font traz a do pack"
amb bash "$RAIZ/scripts/instalar_fontes.sh" >"$T/f1" 2>&1
for n in "${CASAS[@]}"; do
  d="$C/com.system76.CosmicTheme.$n/v2"
  igual "CosmicTheme.$n/v2/font é a interface_font do Tk" "$(cat "$d/font" 2>/dev/null)" "$(cat "$TK/interface_font")"
  grep -q 'family: "JetBrainsMono Nerd Font Mono"' "$d/mono_font" 2>/dev/null \
    && ok "CosmicTheme.$n/v2/mono_font é a do pack" || falha "CosmicTheme.$n/v2/mono_font: $(cat "$d/mono_font" 2>/dev/null)"
done
grep -q 'family: "JetBrainsMono Nerd Font Mono"' "$TK/monospace_font" \
  && ok "o Tk segue gravado (os applets da libcosmic antiga leem dele)" || falha "o Tk perdeu o monospace_font"
f2="$(foto)"
amb bash "$RAIZ/scripts/instalar_fontes.sh" >"$T/f2" 2>&1; rc=$?
igual "a segunda passada sai 0" "$rc" 0
igual "e não escreve nada na árvore do COSMIC" "$(foto)" "$f2"
amb bash "$RAIZ/scripts/instalar_fontes.sh" --conferir >/dev/null 2>&1; igual "e o --conferir sai 0" "$?" 0

echo "== 3. o doctor confere as cinco casas e acusa ~~ quando uma falta"
saida="$(doutor chk_efeito)"; igual "tudo no lugar: ok (rc 0)" "$?" 0
for n in "${CASAS[@]}"; do
  arq="$C/com.system76.CosmicTheme.$n/v2/icon_theme"; guardado="$(cat "$arq")"; rm -f "$arq"
  saida="$(doutor chk_efeito)"; rc=$?
  igual "sem o icon_theme de $n: ~~ (rc 1)" "$rc" 1
  [[ "$saida" == *"CosmicTheme.$n/v2"* ]] && ok "e diz qual casa" || falha "não disse a casa $n: $saida"
  saida_i="$(doutor chk_icones MEOW_DRY_RUN=1)"; rc=$?
  igual "o chk_icones também dá ~~ sem o icon_theme de $n" "$rc" 1
  printf '%s' "$guardado" > "$arq"
done
arq="$C/com.system76.CosmicTheme.Light/v2/mono_font"; guardado="$(cat "$arq")"
rm -f "$arq"; saida="$(doutor chk_efeito)"; igual "sem o mono_font de Light: ~~" "$?" 1
saida_f="$(amb MEOW_DRY_RUN=1 bash "$RAIZ/scripts/instalar_fontes.sh" --conferir 2>&1)"; igual "e o --conferir das fontes também" "$?" 1
printf '%s' "$guardado" > "$arq"
arq="$C/com.system76.CosmicTheme.Dark.Builder/v2/font"; guardado="$(cat "$arq")"
printf '(\n    family: "Outra",\n    weight: Normal,\n    stretch: Normal,\n    style: Normal,\n)' > "$arq"
saida="$(doutor chk_efeito)"; igual "font diferente da interface_font: ~~" "$?" 1
printf '%s' "$guardado" > "$arq"
rm -f "$C/com.system76.CosmicTheme.Dark/v2/icon_theme"
f3="$(foto)"
doutor fix_efeito >/dev/null; igual "fix_efeito diz que mexeu (rc 1)" "$?" 1
igual "e repõe o icon_theme" "$(cat "$C/com.system76.CosmicTheme.Dark/v2/icon_theme")" '"MeowSystem-Icons"'
saida="$(doutor chk_efeito)"; igual "depois do conserto, ok" "$?" 0
[ "$(foto)" != "$f3" ] && ok "o conserto escreveu" || falha "o conserto não escreveu"

echo "== 4. o efeito: o JSON do oráculo manda"
ORA="$T/oraculo.json"
printf '{"icon_theme":"Cosmic","font":{"family":"Fira Sans"},"mono_font":{"family":"JetBrainsMono Nerd Font Mono"}}' > "$ORA"
saida="$(doutor chk_efeito OT_EFEITO_JSON="$ORA")"; rc=$?
igual "icon_theme \"Cosmic\" no JSON: ~~ (rc 1)" "$rc" 1
[[ "$saida" == *"o oráculo"* && "$saida" == *"icon_theme é 'Cosmic'"* ]] && ok "e a frase cita o oráculo e o valor" || falha "frase: $saida"
printf '{"icon_theme":"MeowSystem-Icons","font":{"family":"Fira Sans"},"mono_font":{"family":"JetBrainsMono Nerd Font Mono"}}' > "$ORA"
saida="$(doutor chk_efeito OT_EFEITO_JSON="$ORA")"; igual "\"MeowSystem-Icons\" no JSON: ok (rc 0)" "$?" 0
printf '{"icon_theme":"MeowSystem-Icons","font":{"family":"Open Sans"},"mono_font":{"family":"JetBrainsMono Nerd Font Mono"}}' > "$ORA"
saida="$(doutor chk_efeito OT_EFEITO_JSON="$ORA")"; igual "font errada no JSON: ~~" "$?" 1
printf '{"name":"x"}' > "$ORA"
saida="$(doutor chk_efeito OT_EFEITO_JSON="$ORA")"; igual "JSON de libcosmic antiga, sem os campos: ok (o Tk vale)" "$?" 0

echo "== 5. aplicar o tema não apaga as chaves do MeowSystem"
f5="$(for n in "${CASAS[@]}"; do cat "$C/com.system76.CosmicTheme.$n/v2/icon_theme" "$C/com.system76.CosmicTheme.$n/v2/font" "$C/com.system76.CosmicTheme.$n/v2/mono_font"; done | sha256sum)"
amb MEOW_ESTADO="$T/estado" bash "$RAIZ/scripts/aplicar_tema.sh" original >"$T/a1" 2>&1; rc=$?
igual "aplicar_tema.sh original sai 0" "$rc" 0
f5b="$(for n in "${CASAS[@]}"; do cat "$C/com.system76.CosmicTheme.$n/v2/icon_theme" "$C/com.system76.CosmicTheme.$n/v2/font" "$C/com.system76.CosmicTheme.$n/v2/mono_font"; done | sha256sum)"
igual "icon_theme, font e mono_font das quatro casas ficam como estavam" "$f5b" "$f5"
saida="$(doutor chk_efeito)"; igual "e o doctor segue ok" "$?" 0
amb MEOW_ESTADO="$T/estado" MEOW_RESPEITAR_GUI=1 bash "$RAIZ/scripts/aplicar_tema.sh" original >"$T/a2" 2>&1; igual "com --respeitar-gui também sai 0" "$?" 0
saida="$(doutor chk_efeito)"; igual "e o doctor segue ok" "$?" 0

echo "== 6. o contrato vigia a casa, e o pós-apt refaz quando o hash muda"
grep -qP '^casa\tsrc/icon_theme\.rs\t[0-9a-f]{64}\t' "$RAIZ/assets/contratos/cosmic.tsv" \
  && ok "o contrato vigia src/icon_theme.rs" || falha "o contrato não vigia src/icon_theme.rs"
grep -qP '^casa\tcosmic-theme/src/model/theme\.rs\t[0-9a-f]{64}\t' "$RAIZ/assets/contratos/cosmic.tsv" \
  && ok "e cosmic-theme/src/model/theme.rs" || falha "o contrato não vigia o model/theme.rs"

P="$T/pa"; mkdir -p "$P/bin" "$P/home/.local/bin" "$P/estado"
printf '#!/bin/sh\nprintf "%%s\\t%%s\\tinstalled\\n" cosmic-settings "$(cat %s/versao)"\n' "$P" > "$P/bin/dpkg-query"
chmod 755 "$P/bin/dpkg-query"
printf '#!/bin/sh\n[ "$1" = revisao ] && { echo dd108aa99d7306110eef06da43eafc109e1ab151; exit 0; }\nexit 0\n' > "$P/oraculo"
printf '#!/bin/sh\necho "doctor $*" >> %s/log\n' "$P" > "$P/doctor"
printf '#!/bin/sh\nexit 0\n' > "$P/builds"
printf '#!/bin/sh\nexit 0\n' > "$P/compositor"
printf '#!/bin/sh\nexit 0\n' > "$P/som"
printf '#!/bin/sh\ncat %s/conteudo\n' "$P" > "$P/buscar"
chmod 755 "$P/oraculo" "$P/doctor" "$P/builds" "$P/compositor" "$P/som" "$P/buscar"
printf 'conteudo da revisao nova\n' > "$P/conteudo"
hash_certo="$(sha256sum < "$P/conteudo" | cut -d' ' -f1)"
hash_errado="$(printf 'outro\n' | sha256sum | cut -d' ' -f1)"
contrato() { printf 'casa\tsrc/icon_theme.rs\t%s\tdd108aa\tx\ncasa\tcosmic-theme/src/model/theme.rs\t%s\tdd108aa\tx\n' "$1" "$1" > "$P/contrato.tsv"; }
pos_apt() {
  HOME="$P/home" PATH="$P/bin:$T/falso:$PATH" MEOW_ESTADO="$P/estado" MEOW_CONF="$T/nao-existe.conf" \
    PA_DOCTOR="$P/doctor" PA_ORACULO="$P/oraculo" PA_BUILDS="$P/builds" PA_COMPOSITOR="$P/compositor" PA_SOM="$P/som" \
    PA_CANDIDATO="$P/candidato.tsv" PA_CONTRATO="$P/contrato.tsv" PA_BUSCAR="$P/buscar" \
    "$RAIZ/scripts/cosmic_pos_apt.sh" >"$P/saida" 2>&1
}
contrato "$hash_certo"; echo 1.0~a > "$P/versao"; : > "$P/log"; pos_apt
igual "hash igual ao do contrato: não refaz o ícone" "$(grep -c '^doctor icones reconstruir' "$P/log")" 0
igual "hash igual ao do contrato: não refaz a fonte" "$(grep -c '^doctor fontes aplicar' "$P/log")" 0
contrato "$hash_errado"; echo 1.0~b > "$P/versao"; : > "$P/log"; pos_apt
igual "hash trocado: refaz o ícone" "$(grep -c '^doctor icones reconstruir' "$P/log")" 1
igual "hash trocado: refaz a fonte" "$(grep -c '^doctor fontes aplicar' "$P/log")" 1
grep -q 'icon_theme.rs mudou no libcosmic dd108aa' "$P/saida" && ok "e diz qual arquivo mudou" || falha "a saída não citou o arquivo: $(cat "$P/saida")"
: > "$P/conteudo"; echo 1.0~c > "$P/versao"; : > "$P/log"; pos_apt
igual "sem rede (arquivo vazio) não vira mudança" "$(grep -c '^doctor icones reconstruir' "$P/log")" 0

echo "== 7. o vizinho que grava a fonte é território das fontes"
V="$T/viz"; mkdir -p "$V/casa/.config/zsh/aurora" "$V/casa/.config/systemd/user/default.target.wants" "$V/etc" "$V/dev"
cat > "$V/casa/.config/zsh/aurora/fonte.sh" <<'FIM'
#!/bin/sh
printf 'x' > "$HOME/.config/cosmic/com.system76.CosmicTheme.Dark/v2/mono_font"
FIM
chmod 755 "$V/casa/.config/zsh/aurora/fonte.sh"
printf '[Service]\nExecStart=%%h/.config/zsh/aurora/fonte.sh\n' > "$V/casa/.config/systemd/user/vizinho-fonte.service"
ln -s ../vizinho-fonte.service "$V/casa/.config/systemd/user/default.target.wants/vizinho-fonte.service"
inv="$(env -i PATH="$T/falso:/usr/bin:/bin" HOME="$V/casa" ZDOTDIR="$V/casa/.config/zsh" VIZINHOS_ETC="$V/etc" \
        VIZINHOS_DESENV="$V/dev" VIZINHOS_CRONTAB="$T/sem-cron" MEOW_ESTADO="$V/estado" NO_COLOR=1 \
        bash "$RAIZ/scripts/vizinhos.sh" --inventario 2>&1)"
printf '%s\n' "$inv" | grep -q '^fontes	.*fonte.sh' \
  && ok "o script que grava mono_font aparece em fontes" || falha "vizinhos não viu o mono_font: $inv"

echo
if [ "$falhas" -eq 0 ]; then echo "tudo certo"; else echo "$falhas falha(s)"; exit 1; fi
