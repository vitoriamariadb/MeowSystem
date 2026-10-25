#!/bin/sh
# meow-lancador-apt.sh — o braço root do lançador, chamado pelo hook de apt.
#
# Fonte-de-verdade: MeowSystem/scripts/meow-lancador-apt.sh
# Destino:          /usr/local/sbin/meow-lancador-apt.sh  (0755, root:root)
# Quem chama:       /etc/apt/apt.conf.d/99-meow-lancador  (DPkg::Post-Invoke)
# Quem instala:     install.sh, `etapa_lancador_apt`
#
# O porquê deste arquivo existir está no `99-meow-lancador`. Aqui fica só o que
# é mecânica, e cada bloco abaixo é uma armadilha que ele desarma.
#
# Um Post-Invoke que sai != 0 faz o `apt` terminar em erro.

# O `apt full-upgrade` de `set 2 15:21:34` atualizou o pacote `code` e devolveu
# `Name=Visual Studio Code` ao `/usr/share/applications/code.desktop`.
#
# `ocultar_apps.sh` e `nomes_apps.sh` escrevem no MESMO diretório, pelo MESMO
# motivo, e são desfeitos pelo MESMO evento.
#
# O CÓDIGO DE SAÍDA É DOBRADO, com a mesma regra do `scripts/apos_flatpak.sh`: 2
# vence tudo · 1 vence 0 · 0 só sobrevive se ninguém consertou nada.

ACERVO="@ACERVO@"
USUARIA="@USUARIA@"
LAR="@LAR@"

ALVO="$ACERVO/scripts/ocultar_apps.sh"
ALVO_NOMES="$ACERVO/scripts/nomes_apps.sh"
ESTADO="$LAR/.local/state/meowsystem"
LOG="$ESTADO/apt-lancador.log"

# QUEM RODA O CLONE É ELA, NUNCA ROOT — P108 (conferência), 25/10/2026.
#   O apt chama isto como root, e os dois alvos moram no clone, que ela edita sem
#   senha: rodá-los como root punha código dela em root no apt seguinte (medido
#   no container: uma linha no `ocultar_apps.sh` criou um arquivo em `/root`). O
#   log e o `chown` do estado moram no lar dela, e um link no lugar do log levava
#   a escrita e o `chown` de root a qualquer arquivo. Então root, aqui, só se
#   troca por ela, e tudo o mais corre com o uid dela. O que precisa de root (os
#   `.desktop` de `/usr/share/applications`) passa pela ponte, como no painel. Se
#   a troca falha, nada do clone roda.
if [ "$(id -u)" = 0 ]; then
  [ -n "$USUARIA" ] && [ "$USUARIA" != root ] || exit 0
  cd / && runuser -u "$USUARIA" -- "$0"
  exit 0
fi

registrar() {
  [ -d "$ESTADO" ] || return 0
  printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG" 2>/dev/null
  # Um arquivo que só cresce é um problema que aparece daqui a anos. Mesma poda
  # do `meow-doctor.service`, e o temporário nasce no MESMO diretório para que o
  # `mv` seja atômico.
  if [ -f "$LOG" ] && [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 262144 ]; then
    tail -n 400 "$LOG" > "$LOG.novo" 2>/dev/null &&
      mv -f "$LOG.novo" "$LOG" 2>/dev/null
  fi
  chown "$USUARIA:$USUARIA" "$LOG" 2>/dev/null
  return 0
}

# O disco Ápate desmontado NÃO é erro: é uma máquina onde o repositório não está
# à mão agora. Fica calado no apt e registrado no log, se o log der para escrever.
if [ ! -x "$ALVO" ]; then
  registrar "pulado — $ALVO não está executável (o Ápate está montado?)"
  exit 0
fi

# `HOME` é o que faz o `lib/comum.sh` derivar os caminhos dela; `MEOW_ESTADO`
# explícito porque é ele que o `meow desfazer --lancador` vai ler depois.
HOME="$LAR"
MEOW_ESTADO="$ESTADO"
export HOME MEOW_ESTADO

saida="$("$ALVO" 2>&1)"
rc=$?

# O segundo alvo: o `Name=` curto dos `.desktop` do apt. Ausente não é falha —
# um repositório mais velho que esta mudança simplesmente não tem o arquivo, e
# quebrar o `apt` dela por isso seria desproporcional.
if [ -x "$ALVO_NOMES" ]; then
  saida_nomes="$("$ALVO_NOMES" --so-sistema 2>&1)"
  rc_nomes=$?
  saida="$saida${saida_nomes:+ | $saida_nomes}"
  # A dobra: 2 vence tudo, 1 vence 0.
  case "$rc_nomes" in
    2) rc=2 ;;
    1) [ "$rc" = 2 ] || rc=1 ;;
    3) ;;
    0) ;;
    *) rc=2 ;;
  esac
fi

# 0 = já estava oculto · 1 = divergia e foi reaplicado · o resto é problema.
case "$rc" in
  0) ;;
  1)
    # O script acabou de criar `backups/<carimbo>-sistema/` como root dentro do
    # home dela. Sem isto, o diretório de estado deixa de ser dela.
    chown -R "$USUARIA:$USUARIA" "$ESTADO" 2>/dev/null
    registrar "reaplicado após apt — $(printf '%s' "$saida" | tr '\n' ' ')"
    ;;
  *)
    registrar "FALHOU (rc=$rc) — $(printf '%s' "$saida" | tr '\n' ' ')"
    ;;
esac

exit 0
