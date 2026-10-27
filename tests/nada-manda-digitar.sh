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

printf '\n--- 5. a pendência aponta o botão que resolve, e não o comando ---\n'
saida="$(env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_pendencia_acionavel starship-ausente "O starship falta" "./scripts/prompt.sh instalar-starship"' 2>&1)"
if ! grep -q 'scripts/prompt.sh' <<< "$saida" && grep -q '«Resolver», em Manter' <<< "$saida"; then
  ok "a linha «resolve:» diz o botão («Resolver», em Manter), sem o comando"
else
  falha "a pendência ainda manda digitar o comando" "$saida"
fi

printf '\n--- 6. o papel de parede devolvido vira botão, e não «meow wallpaper permitir» ---\n'
achados="$(grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*meow wallpaper permitir' "$RAIZ/scripts/wallpaper.sh")"
[ -z "$achados" ] && ok "o wallpaper.sh não manda digitar «meow wallpaper permitir»" \
  || falha "o wallpaper.sh manda digitar «meow wallpaper permitir»" "$achados"
mkdir -p "$CASA/.local/state/meowsystem"
printf 'wallpaper-fonte-revertida\twallpaper.sh\tA imagem de fundo apontava para %s/Imagens/minha.png\tmeow wallpaper permitir %s/Imagens/minha.png\t2026-10-10T00:00:00-03:00\n' \
  "$CASA" "$CASA" >> "$CASA/.local/state/meowsystem/pendencias.tsv"
saida="$(env -i PATH="$PATH" HOME="$CASA" python3 - "$RAIZ/app" "$CASA/Imagens/minha.png" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
p = next((x for x in servidor.pendencias() if x["id"] == "wallpaper-fonte-revertida"), {})
for e in p.get("escolha") or []:
    print("escolha=%s|%s" % (e["acao"], e["argumento"]))
acao = servidor.ACOES.get("wallpaper_permitir") or {}
print("argv=%s" % " ".join(acao.get("argv") or []))
print("cerca=%s" % (sys.argv[2] in servidor.PROVEDORES[acao.get("arg", "")]() if acao.get("arg") in servidor.PROVEDORES else False))
PY
)"
if grep -qx "escolha=wallpaper_permitir|$CASA/Imagens/minha.png" <<< "$saida" \
   && grep -q '^argv=.*wallpaper permitir @ARG@$' <<< "$saida" && grep -qx 'cerca=True' <<< "$saida"; then
  ok "a pendência do papel de parede devolvido tem o botão que autoriza aquela imagem"
else
  falha "a pendência do papel de parede devolvido não tem o botão que autoriza" "$saida"
fi

printf '\n--- 6b. «Deixar assim» tira o cartão sem autorizar a imagem (P82, item 3; decisão 13) ---\n'
mkdir -p "$CASA/.config/meow"; cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
antes_conf="$(sha256sum < "$CASA/.config/meow/meow.conf")"
pendencia_e_botao() {
  env -i PATH="$PATH" HOME="$CASA" python3 -I - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
p = next((x for x in servidor.pendencias() if x["id"] == "wallpaper-fonte-revertida"), None)
print("cartao=%s" % bool(p))
for e in (p or {}).get("escolha") or []:
    print("escolha=%s|%s" % (e["acao"], e["rotulo"]))
print("argv=%s" % " ".join((servidor.ACOES.get("wallpaper_dispensar") or {}).get("argv") or [])[-19:])
PY
}
antes_p="$(pendencia_e_botao)"
env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  "$RAIZ/bin/meow" wallpaper dispensar >/dev/null 2>&1
depois_p="$(pendencia_e_botao)"
if grep -qx 'escolha=wallpaper_dispensar|Deixar assim' <<< "$antes_p" \
   && grep -qx 'argv=wallpaper dispensar' <<< "$antes_p" \
   && grep -qx 'cartao=False' <<< "$depois_p" \
   && [ "$(sha256sum < "$CASA/.config/meow/meow.conf")" = "$antes_conf" ]; then
  ok "«Deixar assim» tira o cartão do papel de parede devolvido, e o meow.conf não muda (sha256 igual)"
else
  falha "«Deixar assim» não tirou o cartão, ou mexeu no conf" "antes: $antes_p / depois: $depois_p"
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

printf '\n'
[ "$ACHADOS" -eq 0 ] || { printf 'FALHOU: %s achado(s)\n' "$ACHADOS" >&2; exit 1; }
printf 'passou: nada manda digitar\n'
exit 0
