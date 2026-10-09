#!/usr/bin/env bash
# volta-do-cosmic.sh — o caminho de volta do COSMIC sobrevive à limpeza? (P76)
#
# Duas guardas da tarefa 5 (`docs/pesquisas/2026-10-09-cosmic-vivo.md` §3 e §4.7):
#   1. o `atualizar_sistema.sh limpar` guarda o `.deb` da versão INSTALADA de
#      cada `cosmic-*` antes do `apt clean` — no seco ele diz qual guardaria; no
#      de verdade copia, e a segunda passagem não copia de novo; da guarda sai
#      só o que não é nem o instalado nem o mais novo dos outros;
#   2. o `compositor_patches.sh guardar` leva o fonte do `~/.cache` para
#      `~/.local/share/meowsystem/fontes/`, sem apagar a origem, e é
#      idempotente.
# `dpkg-query`, `apt` e `sudo` falsos (o `sudo` só registra), HOME e cache do
# apt de brinquedo, `MEOW_PONTE` apontando para o vazio. Nada escreve fora daqui.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin" "$T/arquivos" "$T/lar"
printf 'cosmic-comp\t0.1~b\tinstalled\ncosmic-files\t1.9~a\tinstalled\n' > "$T/dpkg.tsv"
cat > "$T/bin/dpkg-query" <<FIM
#!/bin/sh
# Com -f e um nome só, devolve a versão dele; senão, a tabela inteira.
case "\$*" in *'\${Version}'*' cosmic-'[a-z]*)
  for a; do :; done; awk -F'\t' -v p="\$a" '\$1==p{printf "%s", \$2}' "$T/dpkg.tsv" ;;
*) cat "$T/dpkg.tsv" ;; esac
FIM
printf '#!/bin/sh\necho "sudo $*" >> "%s/sudo.log"\nexit 0\n' "$T" > "$T/bin/sudo"
printf '#!/bin/sh\nexit 0\n' > "$T/bin/apt"
chmod 755 "$T/bin/"*
: > "$T/arquivos/cosmic-comp_0.1~b_amd64.deb"
: > "$T/arquivos/cosmic-files_1.9~a_amd64.deb"
: > "$T/arquivos/cosmic-panel_1.9~a_amd64.deb"   # não instalado: não se guarda

limpar() {
  HOME="$T/lar" PATH="$T/bin:$PATH" MEOW_PONTE=/nao/existe MEOW_ESTADO="$T/lar/estado" \
  AS_ARQUIVOS="$T/arquivos" "$RAIZ/scripts/atualizar_sistema.sh" limpar 2>&1
}
G="$T/lar/.local/share/meowsystem/debs"

echo "== limpar no seco"
saida="$(MEOW_DRY_RUN=1 limpar)"
printf '%s' "$saida" | grep -q 'guardaria cosmic-comp_0.1~b_amd64.deb' && ok "diz que guardaria o do cosmic-comp instalado" || falha "não citou o cosmic-comp: $saida"
printf '%s' "$saida" | grep -q 'cosmic-panel' && falha "citou o cosmic-panel, que não está instalado" || ok "não cita o que não está instalado"
[ -d "$G" ] && falha "o seco criou a guarda" || ok "o seco não escreveu"

echo "== limpar de verdade"
limpar >/dev/null
[ -f "$G/cosmic-comp_0.1~b_amd64.deb" ] && [ -f "$G/cosmic-files_1.9~a_amd64.deb" ] && ok "os dois instalados foram guardados" || falha "faltou guardar: $(ls "$G" 2>/dev/null)"
igual "nada além deles" "$(ls "$G" | wc -l)" 2
grep -q 'apt clean' "$T/sudo.log" && ok "e o clean rodou depois (pelo sudo falso)" || falha "o clean não rodou"
saida="$(limpar)"
printf '%s' "$saida" | grep -q 'guardado cosmic' && falha "a segunda passagem copiou de novo" || ok "a segunda passagem não copia de novo"

echo "== a poda da guarda: fica o instalado e o mais novo dos outros"
: > "$G/cosmic-comp_0.1~a_amd64.deb"
: > "$G/cosmic-comp_0.0~z_amd64.deb"
limpar >/dev/null
[ -f "$G/cosmic-comp_0.1~b_amd64.deb" ] && ok "o instalado ficou" || falha "o instalado saiu"
[ -f "$G/cosmic-comp_0.1~a_amd64.deb" ] && ok "o passo para trás ficou" || falha "o passo para trás saiu"
[ -f "$G/cosmic-comp_0.0~z_amd64.deb" ] && falha "o mais velho ficou" || ok "o mais velho saiu"

echo "== o fonte do compositor sai do cache"
C="$T/lar/.cache/meowsystem/cosmic-comp"; F="$T/lar/.local/share/meowsystem/fontes/cosmic-comp"
mkdir -p "$C"; echo dsc > "$C/cosmic-comp_0.1~b.dsc"; echo tar > "$C/cosmic-comp_0.1~b.tar.xz"
guardar() { HOME="$T/lar" PATH="$T/bin:$PATH" MEOW_ESTADO="$T/lar/estado" "$RAIZ/scripts/compositor_patches.sh" guardar >/dev/null 2>&1; }
MEOW_DRY_RUN=1 guardar; igual "seco: diz que guardaria (1)" "$?" 1
[ -d "$F" ] && falha "o seco criou a guarda do fonte" || ok "o seco não escreveu"
guardar; igual "de verdade: guardou (1)" "$?" 1
[ -f "$F/cosmic-comp_0.1~b.dsc" ] && [ -f "$F/cosmic-comp_0.1~b.tar.xz" ] && ok "o .dsc e o .tar.xz estão na guarda" || falha "faltou: $(ls "$F" 2>/dev/null)"
[ -f "$C/cosmic-comp_0.1~b.tar.xz" ] && ok "a origem no cache ficou" || falha "a origem foi apagada"
guardar; igual "segunda vez: nada a fazer (0)" "$?" 0

echo
if [ "$falhas" = 0 ]; then echo "volta-do-cosmic: tudo certo"; exit 0; fi
echo "volta-do-cosmic: $falhas falha(s)"; exit 1
