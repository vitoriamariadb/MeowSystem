#!/usr/bin/env bash
# A promessa do README: a instalação CONVERGE — chega uma passagem em que nada
# mais é escrito.
#
# Etapa que devolve 0 depois de escrever.
#
# 3 passagens, 59 etapas, nada mais a escrever.", que tomou o lugar de "nenhuma
# etapa precisou escrever nada" — nem chega a ser impressa.
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
H="$(mktemp -d)"; FALSO="$(mktemp -d)"; trap 'rm -rf "$H" "$FALSO"' EXIT

# O `MEOW_PONTE=/nao/existe` lá embaixo cobre as etapas que PERGUNTAM pela
# ponte.
#
# Sem sudo a `etapa_ponte_root` já sabe se pular sozinha ("sem terminal para
# pedir a senha — a ponte fica de fora", devolve MEOW_SEM_DEPENDENCIA), e
# `pulado:` não conta como `mexeu:` — a convergência que este teste mede
# continua sendo medida, agora sem escrever em /usr.
# Com `NOPASSWD: ALL` o `sudo -n true` de verdade passa e a etapa escreveria em
# `/usr/local/lib`; por isso o falso recusa.
cat > "$FALSO/sudo" <<'FIM'
#!/bin/sh
printf 'sudo: recusado pelo tests/convergencia.sh\n' >&2
exit 1
FIM
chmod 755 "$FALSO/sudo"

# Medido de novo hoje com um falso assim à frente do PATH: `painel leitura logo
# wallpaper assets vigia_flatpak vigia_qt vigia_apt autoreparo` em todas as
# passagens.
#
# O teste não pode depender do falso de quem o roda.
cat > "$FALSO/systemctl" <<FIM
#!/bin/bash
case " \$* " in
  *" is-active "*|*" is-enabled "*|*" is-failed "*|*" show "*|*" status "*|*" cat "*\
  |*" list-units "*|*" list-unit-files "*|*" list-timers "*|*" show-environment "*\
  |*" get-default "*|*" --version "*)
    IFS=: read -ra _dirs <<< "\$PATH"
    for _d in "\${_dirs[@]}"; do
      [ "\$_d" = "$FALSO" ] && continue
      [ -x "\$_d/systemctl" ] && exec "\$_d/systemctl" "\$@"
    done
    exit 1 ;;
esac
printf 'systemctl: recusado pelo tests/convergencia.sh (%s)\n' "\$*" >&2
exit 1
FIM
chmod 755 "$FALSO/systemctl"

PASSAGENS="${PASSAGENS:-3}"

correr() {
  # `MEOW_PONTE` APONTA PARA O VAZIO, E ISSO NÃO É PARANOIA: este teste roda o
  # instalador num HOME de brinquedo, onde não há `meow.conf` e toda chave cai
  # no padrão.
  env -i PATH="$FALSO:$PATH" HOME="$H" USER="${USER:-t}" \
    MEOW_IGNORA_DESKTOP=1 NO_COLOR=1 MEOW_PONTE=/nao/existe \
    bash "$RAIZ/install.sh" 2>&1
}

saida=""
for i in $(seq 1 "$PASSAGENS"); do
  saida="$(correr)"
  printf 'passagem %s: %s\n' "$i" \
    "$(printf '%s' "$saida" | grep 'mexeu:' || printf 'nada mudou')"
done

if printf '%s' "$saida" | grep -q 'mexeu:'; then
  printf 'FALHOU: ainda mexia na passagem %s — alguma etapa não é idempotente\n' \
    "$PASSAGENS" >&2
  exit 1
fi
printf 'ok: convergiu em %s passagens\n' "$PASSAGENS"
