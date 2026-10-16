#!/usr/bin/env bash
# nada-manda-digitar.sh — saída do MeowSystem não manda a pessoa digitar o
# conserto. P79, item 5, 10/10/2026.
#
# O QUE ABRIU ISTO — o QA de uso real da P77
#   Dentro do painel, três saídas ainda eram receita de terminal:
#     · o `icones_apps_dracula.sh` (e o irmão `icones_resgatados.sh`): «para
#       ver agora… pkill -x cosmic-panel && pkill -f cosmic-app-library»;
#     · o instalador: «Para completá-las:  sudo -v && ./install.sh»;
#     · o doctor: «conserto: LEITURA_COMPILAR=1 …» e «para construir agora:
#       meow files-menu build».
#   O princípio de 09/10 é que o programa faz (ou põe o botão que faz). A tela
#   do painel tem a porta da tela inteira (`meow_tela_reler`), o «Instalar
#   tudo», o «Construir o menu da área de trabalho» e o «Consertar o que
#   estiver fora»; a saída passa a usar a porta, ou a pendência que o botão
#   resolve.
#
# O QUE ESTE TESTE COBRA
#   1. Nenhuma mensagem (`meow_info`, `meow_pula`, `meow_aviso`, `meow_muda`,
#      `meow_ok`, `meow_erro`) de `scripts/`, `lib/`, `bin/meow` ou do
#      `install.sh` carrega as quatro receitas.
#   2. As pendências novas têm botão no painel: `instalar-com-root` roda o
#      «Instalar tudo», e `leitura-applet` o «Consertar o que estiver fora».
#   3. Os dois scripts de ícone relêem a tela pela porta única, e não dizem
#      `pkill`.
#   5 a 7. (P80, item 8) A linha «resolve:» de uma pendência diz o botão, e
#      não o comando; o papel de parede devolvido vira pendência com o botão
#      que autoriza aquela imagem; e sem cargo o conserto instala o rust.
#
# PORTÁTIL: grep e python3.
#   0 = passou · 1 = falhou · 2 = erro deste teste
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ACHADOS=0
ok()    { printf '  ok   %s\n' "$*"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" | sed 's/^/       /' >&2; ACHADOS=$((ACHADOS + 1)); }
command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

printf '\n--- 1. nenhuma mensagem com receita de terminal ---\n'
achados="$(cd "$RAIZ" && grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*(pkill -[xf] |sudo -v|LEITURA_COMPILAR=1|meow files-menu build)' \
             scripts/*.sh lib/*.sh bin/meow install.sh 2>/dev/null)"
if [ -z "$achados" ]; then
  ok "nenhuma mensagem manda digitar pkill, sudo -v, LEITURA_COMPILAR=1 ou meow files-menu build"
else
  falha "mensagens que mandam digitar o conserto" "$achados"
fi

printf '\n--- 2. as pendências novas têm botão ---\n'
saida="$(env -i PATH="$PATH" HOME="$(mktemp -d)" python3 - "$RAIZ/app" <<'PY' 2>&1
import sys
sys.path.insert(0, sys.argv[1])
import servidor
for p in ("instalar-com-root", "leitura-applet"):
    print("%s=%s" % (p, servidor.ACAO_DA_PENDENCIA.get(p, "")))
PY
)"
if grep -qx 'instalar-com-root=instalar' <<< "$saida" && grep -qx 'leitura-applet=doctor_consertar' <<< "$saida"; then
  ok "instalar-com-root -> «Instalar tudo», leitura-applet -> «Consertar o que estiver fora»"
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
#   [Conferência da P79: com `LEITURA_APPLET="nao"` a pendência de uma passagem
#    anterior ficava na Início para sempre, pedindo um applet que ninguém quer.]
CASA="$(mktemp -d)" || exit 2
trap 'rm -rf "$CASA"' EXIT
FALSO="$CASA/falso"; mkdir -p "$FALSO"
for c in sudo pkexec su pkill killall notify-send systemd-run loginctl apt apt-get cargo; do
  printf '#!/bin/sh\nexit 1\n' > "$FALSO/$c"; chmod 755 "$FALSO/$c"
done
applet() {  # <sim|nao>
  env -i PATH="$FALSO:$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LEITURA_APPLET="$1" \
    "$RAIZ/scripts/leitura_build.sh" --aplicar > /dev/null 2>&1
}
TSV="$CASA/.local/state/meowsystem/pendencias.tsv"
applet sim; com="$(cut -f1 "$TSV" 2>/dev/null)"
applet nao; sem="$(cut -f1 "$TSV" 2>/dev/null)"
if grep -qx 'leitura-applet' <<< "$com" && ! grep -qx 'leitura-applet' <<< "$sem"; then
  ok "sem compilar, a pendência leitura-applet nasce; com LEITURA_APPLET=nao, ela sai"
else
  falha "a pendência do applet não nasce ou não sai" "com: $com / sem: $sem"
fi

# --- P80, item 8: os três que sobraram da P79 -----------------------------------
#   (docs/sprints/2026-10-09-uso-real/04-integracao-onda-2.md, «Aberto», item 3)

printf '\n--- 5. a pendência aponta o botão que resolve, e não o comando ---\n'
saida="$(env -i PATH="$PATH" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 \
  bash -c '. "$MEOW_RAIZ/lib/comum.sh"; meow_pendencia_acionavel starship-ausente "O starship falta" "./scripts/prompt.sh instalar-starship"' 2>&1)"
if ! grep -q 'scripts/prompt.sh' <<< "$saida" && grep -q '«Instalar o starship»' <<< "$saida"; then
  ok "a linha «resolve:» diz o botão («Instalar o starship»), sem o comando"
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

printf '\n--- 7. sem cargo, o conserto instala o rust (e não manda instalar) ---\n'
achados="$(grep -nE '^[^#]*meow_(info|pula|aviso|muda|ok|erro) .*instale com rustup' "$RAIZ/scripts/leitura_build.sh")"
[ -z "$achados" ] && ok "o leitura_build.sh não manda «instale com rustup»" \
  || falha "o leitura_build.sh manda instalar o rust à mão" "$achados"
# Os falsos de cima, menos o `cargo` (é a falta dele que este caso monta), e um
# `curl` que anota e recusa: a rede não sai do teste.
SEM_CARGO="$CASA/sem-cargo"; mkdir -p "$SEM_CARGO"
cp -a "$FALSO"/. "$SEM_CARGO"/ && rm -f "$SEM_CARGO/cargo"
REDE="$CASA/rede.log"; : > "$REDE"
printf '#!/bin/sh\necho "curl $*" >> "%s"\nexit 1\n' "$REDE" > "$SEM_CARGO/curl"; chmod 755 "$SEM_CARGO/curl"
rm -f "$TSV"
saida="$(env -i PATH="$SEM_CARGO:/usr/bin:/bin" HOME="$CASA" MEOW_RAIZ="$RAIZ" NO_COLOR=1 LEITURA_APPLET=sim \
  LEITURA_COMPILAR=1 "$RAIZ/scripts/leitura_build.sh" --aplicar 2>&1)"
if PATH=/usr/bin:/bin command -v cargo >/dev/null 2>&1; then
  printf '  --   o /usr/bin desta máquina tem cargo: o caso «sem cargo» não se monta aqui\n'
elif grep -q 'rustup' "$REDE" && grep -qx 'leitura-applet' <<< "$(cut -f1 "$TSV" 2>/dev/null)"; then
  ok "sem cargo, o conserto vai buscar o rust pelo rustup; sem rede, a pendência do botão fica"
else
  falha "sem cargo, o conserto não tentou instalar o rust, ou não deixou a pendência" \
        "rede: $(cat "$REDE") / pendências: $(cut -f1 "$TSV" 2>/dev/null) / saída: $(tail -3 <<< "$saida")"
fi

printf '\n--- 8. as linhas dos builds dizem o estado, sem comando (P81) ---\n'
#   [15/10/2026: a linha `patches` do doctor listava «meow compositor --seco»,
#    «meow compositor ativar»…; a última linha do log do pós-apt real era «ou
#    agora, com: meow painel reciclar»; o applet de mídia e o de leitura,
#    quando o cargo falhava, mandavam colar a linha do cargo. Quem conserta é
#    o `--consertar` (a função única dos builds); a linha diz o estado.]
#   Só os verbos que o doctor e os gatilhos rodam: o `conferir` e o
#   `compilar` do compositor. O `reverter`, o `validar` e o `aplicar` são
#   verbos de quem digita, e nomear o vizinho ali é a resposta pedida.
RECEITA='(meow compositor|meow painel reciclar|rode:|veja o motivo|CARGO_TARGET_DIR=|MIDIA_COMPILAR=1|instale com rustup)'
MSG='^[^#]*(meow_(info|pula|aviso|muda|ok|erro)|_cp_diz [a-z]+) '
achados="$(
  for f in cmd_conferir cmd_compilar; do
    sed -n "/^$f()/,/^}/p" "$RAIZ/scripts/compositor_patches.sh" | grep -E "$MSG.*$RECEITA" | sed "s/^/compositor_patches.sh $f: /"
  done
  cd "$RAIZ" && grep -nE "$MSG.*$RECEITA" scripts/files_menu.sh scripts/midia_build.sh scripts/leitura_build.sh \
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
