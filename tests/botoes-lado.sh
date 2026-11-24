#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else falha "$1 (esperado '$3', veio '$2')"; fi; }

mkdir -p "$T/bin"
for c in sudo pkexec su systemctl systemd-run pkill apt apt-get; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/proibido.log"\nexit 1\n' "$c" "$T" > "$T/bin/$c"
done
cat > "$T/bin/gsettings" <<FIM2
#!/bin/sh
arq="$T/gsettings.valor"
case "\$1" in
  get) [ -f "\$arq" ] || exit 1; printf "'%s'\n" "\$(cat "\$arq")" ;;
  set) printf '%s' "\$4" > "\$arq"; echo "set \$*" >> "$T/gsettings.log" ;;
  *) exit 1 ;;
esac
FIM2
chmod 755 "$T/bin"/*

CANO="/usr/bin:/bin"
rodar() {
  local verbo="$1" lado="$2"; shift 2
  env -i PATH="$T/bin:$CANO" HOME="$T/casa" BOTOES_LADO="$lado" MEOW_ESTADO="$T/estado" "$@" \
    "$RAIZ/scripts/botoes_lado.sh" "$verbo" > "$T/saida" 2>&1
}
zerar() {
  rm -rf "$T/casa" "$T/gsettings.valor" "$T/gsettings.log" "$T/estado"
  mkdir -p "$T/casa/.config/gtk-3.0" "$T/casa/.config/gtk-4.0" "$T/estado"
  printf '%s' "$1" > "$T/gsettings.valor"
  printf '[Settings]\ngtk-theme-name=Adwaita\ngtk-decoration-layout=%s\n' "$1" > "$T/casa/.config/gtk-3.0/settings.ini"
  printf '[Settings]\ngtk-decoration-layout=%s\ngtk-application-prefer-dark-theme=1\n' "$1" > "$T/casa/.config/gtk-4.0/settings.ini"
}
tres() {
  igual "$1: gsettings" "$(cat "$T/gsettings.valor")" "$2"
  igual "$1: GTK 3" "$(sed -n 's/^gtk-decoration-layout=//p' "$T/casa/.config/gtk-3.0/settings.ini")" "$2"
  igual "$1: GTK 4" "$(sed -n 's/^gtk-decoration-layout=//p' "$T/casa/.config/gtk-4.0/settings.ini")" "$2"
}

echo "== regra do espelho: o lado troca, a ordem que a pessoa tinha fica espelhada na borda"
zerar 'close,maximize,minimize:'
rodar aplicar direita; igual "esquerda para direita sai 1" "$?" 1
tres "direita" ':minimize,maximize,close'
grep -q 'gtk-theme-name=Adwaita' "$T/casa/.config/gtk-3.0/settings.ini" && ok "as outras linhas do settings.ini ficam" || falha "perdeu linha vizinha"
rodar aplicar esquerda; igual "direita para esquerda sai 1" "$?" 1
tres "esquerda" 'close,maximize,minimize:'

echo "== a ordem de quem tinha outra ordem"
zerar 'close,minimize,maximize:'
rodar aplicar direita
tres "close,minimize,maximize: vai à direita espelhado" ':maximize,minimize,close'
zerar ':maximize,minimize,close'
rodar aplicar esquerda
tres ":maximize,minimize,close: vai à esquerda espelhado" 'close,minimize,maximize:'
zerar 'appmenu:minimize,maximize,close'
rodar aplicar direita
tres "o que já tinha botão à direita junta tudo à direita" ':appmenu,minimize,maximize,close'

echo "== linha que falta no settings.ini nasce do valor do gsettings; arquivo ausente não nasce"
zerar ':minimize,maximize,close'
printf '[Settings]\ngtk-theme-name=Adwaita\n' > "$T/casa/.config/gtk-3.0/settings.ini"
rm -f "$T/casa/.config/gtk-4.0/settings.ini"
rodar aplicar esquerda
igual "gsettings" "$(cat "$T/gsettings.valor")" 'close,maximize,minimize:'
igual "GTK 3 ganha a linha" "$(sed -n 's/^gtk-decoration-layout=//p' "$T/casa/.config/gtk-3.0/settings.ini")" 'close,maximize,minimize:'
[ ! -e "$T/casa/.config/gtk-4.0/settings.ini" ] && ok "GTK 4 ausente não é criado" || falha "criou o settings.ini do GTK 4"
printf '[Settings]\n' > "$T/casa/.config/gtk-4.0/settings.ini"
printf '[Outra]\nx=1\n' > "$T/casa/.config/gtk-3.0/settings.ini"
rodar aplicar direita
grep -qx 'gtk-decoration-layout=:minimize,maximize,close' "$T/casa/.config/gtk-4.0/settings.ini" && ok "seção [Settings] vazia ganha a linha" || falha "GTK 4: $(cat "$T/casa/.config/gtk-4.0/settings.ini")"
grep -qx '\[Settings\]' "$T/casa/.config/gtk-3.0/settings.ini" && grep -qx 'x=1' "$T/casa/.config/gtk-3.0/settings.ini" \
  && ok "arquivo sem [Settings] ganha a seção e guarda o resto" || falha "GTK 3: $(cat "$T/casa/.config/gtk-3.0/settings.ini")"

echo "== valor que não dá para entender vira o padrão do lado"
zerar 'banana'
rodar aplicar esquerda
tres "valor ilegível, esquerda" 'close,maximize,minimize:'
zerar 'close:foo'
rodar aplicar direita
tres "botão desconhecido, direita" ':minimize,maximize,close'

echo "== a segunda passada não escreve nada"
zerar 'close,maximize,minimize:'
rodar aplicar direita
sleep 1; touch "$T/marco"; sleep 1
rodar aplicar direita; igual "segunda passada sai 0" "$?" 0
igual "e não escreve nada" "$(find "$T/casa" "$T/gsettings.valor" -newer "$T/marco" -type f)" ""
[ "$(grep -c '^set ' "$T/gsettings.log")" = 1 ] && ok "e o gsettings recebeu um set só" || falha "gsettings.log: $(cat "$T/gsettings.log")"

echo "== conferir diz a divergência e não escreve"
zerar 'close,maximize,minimize:'
sleep 1; touch "$T/marco"; sleep 1
rodar conferir direita; igual "conferir sai 1" "$?" 1
igual "e não escreve nada" "$(find "$T/casa" "$T/gsettings.valor" -newer "$T/marco" -type f)" ""
rodar conferir esquerda; igual "conferir no lado certo sai 0" "$?" 0

echo "== modo seco não escreve"
sleep 1; touch "$T/marco"; sleep 1
rodar aplicar direita MEOW_DRY_RUN=1; igual "seco sai 1" "$?" 1
igual "e não escreve nada" "$(find "$T/casa" "$T/gsettings.valor" -newer "$T/marco" -type f)" ""
grep -q 'close,maximize,minimize:' "$T/gsettings.valor" && ok "o valor segue o de antes" || falha "seco mudou o gsettings"

echo "== chave inválida recusa"
zerar 'close,maximize,minimize:'
rodar aplicar meio; igual "BOTOES_LADO=meio sai 2" "$?" 2
grep -q "esperado direita ou esquerda" "$T/saida" && ok "e diz o que esperava" || falha "mensagem: $(cat "$T/saida")"
tres "e nada mudou" 'close,maximize,minimize:'

echo "== sem gsettings sai SEM_DEPENDENCIA"
zerar 'close,maximize,minimize:'
mkdir -p "$T/semgs"
for c in sed awk cat dirname mktemp mv chmod readlink cp mkdir date env grep cut tr rm basename sort find; do
  p="$(command -v "$c")" && ln -sf "$p" "$T/semgs/$c"
done
env -i PATH="$T/semgs" HOME="$T/casa" BOTOES_LADO=direita MEOW_ESTADO="$T/estado" \
  "$(command -v bash)" "$RAIZ/scripts/botoes_lado.sh" aplicar > "$T/saida" 2>&1
igual "sem gsettings sai 3" "$?" 3
tres "e nada mudou" 'close,maximize,minimize:'

[ ! -e "$T/proibido.log" ] && ok "nada chamou sudo, pkexec, systemctl nem apt" || falha "proibido: $(cat "$T/proibido.log")"

printf '\n'
if [ "$falhas" = 0 ]; then echo "botoes-lado: tudo certo"; exit 0; fi
echo "botoes-lado: $falhas falha(s)"; exit 1
