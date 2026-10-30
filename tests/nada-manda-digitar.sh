#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

printf '\n--- 1. nenhuma mensagem com receita de terminal ---\n'
achados="$(cd "$RAIZ" && grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*(pkill -[xf] |sudo -v|EXTENSOES_COMPILAR=1|meow files-menu build)' \
             scripts/*.sh lib/*.sh bin/meow install.sh 2>/dev/null)"
if [ -z "$achados" ]; then
  ok "nenhuma mensagem manda digitar pkill, sudo -v, EXTENSOES_COMPILAR=1 ou meow files-menu build"
else
  falha "mensagens que mandam digitar o conserto" "$achados"
fi

printf '\n--- 1b. as outras formas de receita (P82, item 1) ---\n'
MSG='^[^#]*(meow_(info|pula|aviso|muda|ok|erro)|echo|printf) '
FORMAS="(instale com|veja o motivo|adicione com|sudo -l|systemctl --user start|rode o install\\.sh|sudo apt install|rustup toolchain install|meow tema capturar|(capture antes|diagnóstico|e rode):? +.?meow [a-z]|rode: meow doctor --consertar|'meow doctor --consertar' os escreve|rode uma vez no terminal|com sudo disponível|para ter o nosso de volta|ou agora, com '|acrescente .*à mão|tire a linha à mão|faça uma vez, à mão)"
achados="$(cd "$RAIZ" && grep -nE "$MSG.*$FORMAS" scripts/*.sh lib/*.sh bin/meow install.sh 2>/dev/null \
             | grep -vE '"uso: meow ')"
if [ -z "$achados" ]; then
  ok "nenhuma mensagem manda armar o supervisor, rodar o install.sh, instalar com apt ou rustup, capturar o tema, adicionar papel de parede ou rodar sudo -l"
else
  falha "mensagens que ainda mandam digitar" "$achados"
fi

CASA1B="$(mktemp -d)" || exit 2
mkdir -p "$CASA1B/falso"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get; do
  printf '#!/bin/sh\nexit 1\n' > "$CASA1B/falso/$c"; chmod 755 "$CASA1B/falso/$c"
done
printf '#!/bin/sh\necho "curl $*" >> "%s/rede.log"\nexit 1\n' "$CASA1B" > "$CASA1B/falso/curl"
chmod 755 "$CASA1B/falso/curl"
env -i PATH="$CASA1B/falso:/usr/bin:/bin" HOME="$CASA1B" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" now-playing --aplicar >/dev/null 2>&1
if PATH=/usr/bin:/bin command -v cargo >/dev/null 2>&1; then
  printf '  --   o /usr/bin desta máquina tem cargo: o caso «sem cargo» não se monta aqui\n'
elif grep -q 'rustup' "$CASA1B/rede.log" 2>/dev/null; then
  ok "sem cargo, o applet de mídia vai buscar o rust pelo rustup, como o de leitura"
else
  falha "sem cargo, o applet de mídia não tentou instalar o rust" "rede: $(cat "$CASA1B/rede.log" 2>/dev/null)"
fi
rm -rf "$CASA1B"

printf '\n--- 1c. o terminal também não manda rodar (P90, item 10) ---\n'
achados="$(cd "$RAIZ" && grep -nE '\b[Rr]ode(-o)?\b' scripts/*.sh scripts/*.py lib/*.sh bin/meow install.sh app/run.sh \
             scripts/temas-de-apps/*/manifesto.sh 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
             | grep -vE 'uso: ')"
if [ -z "$achados" ]; then
  ok "nenhuma saída do terminal manda rodar: diz o feito, o estado ou o botão"
else
  falha "saídas do terminal que mandam rodar" "$achados"
fi

printf '\n--- 2. as pendências novas têm botão ---\n'
CASA2="$(mktemp -d)" || exit 2
saida="$(env -i PATH="$PATH" HOME="$CASA2" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
for p in ("instalar-com-root", "extensao-leitura"):
    print("%s=%s" % (p, servidor.ACAO_DA_PENDENCIA.get(p, "")))
PY
)"
rm -rf "$CASA2"
if grep -qx 'instalar-com-root=instalar' <<< "$saida" && grep -qx 'extensao-leitura=doctor_consertar' <<< "$saida"; then
  ok "instalar-com-root -> «Instalar tudo», extensao-leitura -> «Consertar o que estiver fora»"
else
  falha "as pendências novas não têm botão no painel" "$saida"
fi

printf '\n--- 3. os scripts de ícone relêem a tela pela porta única ---\n'
faltam=""
for s in icones_apps_dracula.sh icones_resgatados.sh; do
  grep -qE '^[^#]*meow_tela_reler' "$RAIZ/scripts/$s" || faltam+=" $s"
done
if [ -z "$faltam" ]; then
  ok "o icones_apps_dracula.sh e o icones_resgatados.sh chamam o meow_tela_reler"
else
  falha "sem a porta única da tela:$faltam"
fi

printf '\n--- 4. a pendência do applet nasce sem compilar e sai sem applet pedido ---\n'
CASA="$(mktemp -d)" || exit 2
trap 'rm -rf "$CASA"' EXIT
FALSO="$CASA/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get cargo; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
applet() {
  env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LEITURA_APPLET="$1" \
    "$RAIZ/scripts/extensoes_build.sh" --todas --aplicar > /dev/null 2>&1
}
TSV="$CASA/.local/state/meowsystem/pendencias.tsv"
applet sim; com="$(cut -f1 "$TSV" 2>/dev/null)"
applet nao; sem="$(cut -f1 "$TSV" 2>/dev/null)"
if grep -qx 'extensao-leitura' <<< "$com" && ! grep -qx 'extensao-leitura' <<< "$sem"; then
  ok "sem compilar, a pendência extensao-leitura nasce; com LEITURA_APPLET=nao, ela sai"
else
  falha "a pendência do applet não nasce ou não sai" "com: $com / sem: $sem"
fi

printf '\n--- 5. a pendência aponta o botão que resolve, nunca o comando, e vai para o registro ---\n'
pendencia() {
  env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
    bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_pendencia_acionavel "$@"' _ "$@" 2>&1
}
LOG="$CASA/.local/state/meowsystem/meow.log"
saida="$(pendencia starship-ausente "O starship falta" "./scripts/prompt.sh instalar-starship")"
pendencia starship-ausente "O starship falta" "./scripts/prompt.sh instalar-starship" >/dev/null
sem_lugar="$(pendencia coisa-sem-lugar "Algo ficou de fora" "./scripts/qualquer.sh consertar")"
if ! grep -q 'scripts/prompt.sh' <<< "$saida" && grep -q '«Instalar», em Manter › Instalar de novo' <<< "$saida" \
   && ! grep -qE 'resolve|scripts/' <<< "$sem_lugar" \
   && [ "$(grep -c 'ficou para depois: O starship falta$' "$LOG" 2>/dev/null)" = 1 ] \
   && ! grep -q 'Pendências' <<< "$saida"; then
  ok "a linha «resolve:» diz o botão de verdade, sem comando; sem lugar, não diz nada; o registro ganha a frase uma vez só"
else
  falha "a pendência ainda manda digitar, cita o cartão de pendências ou não foi para o registro" \
    "$saida / sem lugar: $sem_lugar / registro: $(cat "$LOG" 2>/dev/null)"
fi

printf '\n--- 6. o papel de parede devolvido aponta as «Pastas suas», e não «meow wallpaper permitir» ---\n'
achados="$(grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*meow wallpaper permitir' "$RAIZ/scripts/wallpaper.sh")"
[ -z "$achados" ] && ok "o wallpaper.sh não manda digitar «meow wallpaper permitir»" \
  || falha "o wallpaper.sh manda digitar «meow wallpaper permitir»" "$achados"
saida="$(env -i PATH="$PATH" HOME="$CASA" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
print("onde=%s" % servidor.onde_na_tela(servidor.PENDENCIA_PAREDE))
print("chave=%s" % servidor.onde_na_tela("WALLPAPER_FONTES_PERMITIDAS"))
PY
)"
onde="$(sed -n 's/^onde=//p' <<< "$saida")"
if [ -n "$onde" ] && [ "$onde" = "$(sed -n 's/^chave=//p' <<< "$saida")" ] && grep -q '«Pastas suas»' <<< "$onde"; then
  ok "a pendência do papel de parede devolvido leva às «Pastas suas», onde a imagem dela fica autorizada ($onde)"
else
  falha "a pendência do papel de parede devolvido não leva às «Pastas suas»" "$saida"
fi

printf '\n--- 6b. «meow wallpaper dispensar» tira a pendência sem autorizar a imagem ---\n'
mkdir -p "$CASA/.config/meow"; cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
printf 'wallpaper-fonte-revertida\twallpaper.sh\tA imagem de fundo apontava para %s/Imagens/minha.png\tmeow wallpaper permitir %s/Imagens/minha.png\t2026-10-10T00:00:00-03:00\n' \
  "$CASA" "$CASA" >> "$CASA/.local/state/meowsystem/pendencias.tsv"
antes_conf="$(sha256sum < "$CASA/.config/meow/meow.conf")"
env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" wallpaper dispensar >/dev/null 2>&1
if ! grep -q '^wallpaper-fonte-revertida	' "$CASA/.local/state/meowsystem/pendencias.tsv" \
   && [ "$(sha256sum < "$CASA/.config/meow/meow.conf")" = "$antes_conf" ]; then
  ok "a pendência do papel de parede sai, e o meow.conf não muda (sha256 igual)"
else
  falha "o dispensar não tirou a pendência, ou mexeu no conf" "$(cat "$CASA/.local/state/meowsystem/pendencias.tsv")"
fi

printf '\n--- 7. sem cargo, o conserto instala o rust (e não manda instalar) ---\n'
achados="$(grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*instale com rustup' "$RAIZ/scripts/extensoes_build.sh")"
[ -z "$achados" ] && ok "o extensoes_build.sh não manda «instale com rustup»" \
  || falha "o extensoes_build.sh manda instalar o rust à mão" "$achados"
SEM_CARGO="$CASA/sem-cargo"; mkdir -p "$SEM_CARGO"
cp -a "$FALSO"/. "$SEM_CARGO"/ && rm -f "$SEM_CARGO/cargo"
REDE="$CASA/rede.log"; : > "$REDE"
printf '#!/bin/sh\necho "curl $*" >> "%s"\nexit 1\n' "$REDE" > "$SEM_CARGO/curl"; chmod 755 "$SEM_CARGO/curl"
rm -f "$TSV"
saida="$(env -i PATH="$SEM_CARGO:/usr/bin:/bin" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LEITURA_APPLET=sim \
  EXTENSOES_COMPILAR=1 "$RAIZ/scripts/extensoes_build.sh" leitura --aplicar 2>&1)"
if PATH=/usr/bin:/bin command -v cargo >/dev/null 2>&1; then
  printf '  --   o /usr/bin desta máquina tem cargo: o caso «sem cargo» não se monta aqui\n'
elif grep -q 'rustup' "$REDE" && grep -qx 'extensao-leitura' <<< "$(cut -f1 "$TSV" 2>/dev/null)"; then
  ok "sem cargo, o conserto vai buscar o rust pelo rustup; sem rede, a pendência do botão fica"
else
  falha "sem cargo, o conserto não tentou instalar o rust, ou não deixou a pendência" \
        "rede: $(cat "$REDE") / pendências: $(cut -f1 "$TSV" 2>/dev/null) / saída: $(tail -3 <<< "$saida")"
fi

printf '\n--- 8. as linhas dos builds dizem o estado, sem comando (P81) ---\n'
RECEITA='(meow compositor|meow painel reciclar|rode:|veja o motivo|CARGO_TARGET_DIR=|EXTENSOES_COMPILAR=1|instale com rustup)'
MSG='^[^#]*(meow_(info|pula|aviso|muda|ok|erro)|_cp_diz [a-z]+) '
achados="$(
  for f in cmd_conferir cmd_compilar; do
    sed -n "/^$f()/,/^}/p" "$RAIZ/scripts/compositor_patches.sh" | grep -E "$MSG.*$RECEITA" | sed "s/^/compositor_patches.sh $f: /"
  done
  cd "$RAIZ" && grep -nE "$MSG.*$RECEITA" scripts/files_menu.sh scripts/extensoes_build.sh scripts/extensoes_tema.sh \
    scripts/garantir_builds.sh scripts/cosmic_pos_apt.sh 2>/dev/null)"
[ -z "$achados" ] && ok "o conferir e o compilar do compositor, o menu, os dois applets e os gatilhos não mandam digitar" \
  || falha "linhas dos builds que mandam digitar" "$achados"
grep -qE '^SEM_CONSERTO=.* patches ' "$RAIZ/bin/meow" \
  && falha "a linha patches ainda está em SEM_CONSERTO (o doctor não a conserta)" \
  || ok "a linha patches tem conserto: o doctor compila"

printf '\n--- 9. as saídas dos scripts dizem o fato, sem mandar digitar nem editar o conf (P142) ---\n'
achados="$(cd "$RAIZ" && grep -nE "(meow_info|meow_aviso|meow_erro|meow_ok|meow_muda).*('meow |\"meow |rode|digite|no meow.conf|\./install)" \
             scripts/*.sh bin/meow lib/*.sh 2>/dev/null)"
[ -z "$achados" ] && ok "nenhuma saída de script, de bin/meow ou de lib manda digitar, rodar ou editar o meow.conf" \
  || falha "saídas que ainda mandam digitar ou editar o conf" "$achados"

achados="$(cd "$RAIZ" && grep -nE '(print\(|Recusa\(|return [a-z]+, \(f).*(no meow\.conf\.|meow pack (info|usar))|ou o meow pack usar|«Usar este»' scripts/pack.py)"
[ -z "$achados" ] && ok "o pack.py não manda editar o conf nem rodar outro meow pack, e cita o botão pelo nome da tela" \
  || falha "saídas do pack.py que mandam digitar ou citam botão que não existe" "$achados"

achados="$(cd "$RAIZ" && grep -nE 'Início' scripts/*.sh lib/*.sh bin/meow 2>/dev/null)"
[ -z "$achados" ] && ok "nenhuma saída manda olhar a Início, que não mostra pendência" \
  || falha "saída que cita a Início" "$achados"

grep -rq 'porta_das_pend[e]ncias' "$RAIZ/app" "$RAIZ/tests" 2>/dev/null \
  && falha "o nome antigo da porta Manter voltou" \
  || ok "a porta Manter tem o nome que diz o que é: nome_da_porta_cuidar"

DIZER="$(sed -n '/^_cursor_dizer_como_usar()/,/^}/p' "$RAIZ/scripts/cursor.sh")"
saida="$(
  meow_info() { printf '%s\n' "$*"; }
  meow_onde_no_painel() { printf '«Ponteiro», em Definir\n'; }
  CURSOR="" CURSOR_ADICIONADO="Novo"
  eval "$DIZER"
  _cursor_dizer_como_usar
)"
grep -q "escolha-o em «Ponteiro», em Definir" <<< "$saida" && ! grep -q 'meow.conf' <<< "$saida" \
  && ok "o ponteiro adicionado diz onde escolher, pelo nome que o painel mostra" \
  || falha "o ponteiro adicionado não diz onde escolher" "$saida"

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: nada manda digitar\n'
exit 0
