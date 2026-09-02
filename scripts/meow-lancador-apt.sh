#!/bin/sh
# meow-lancador-apt.sh — o braço root do lançador, chamado pelo hook de apt.
#
# Fonte-de-verdade: MeowSystem/scripts/meow-lancador-apt.sh
# Destino:          /usr/local/sbin/meow-lancador-apt.sh  (0755, root:root)
# Quem chama:       /etc/apt/apt.conf.d/99-meow-lancador  (DPkg::Post-Invoke)
# Quem instala:     install.sh, `etapa_lancador_apt`
#
# O porquê deste arquivo existir está no `99-meow-lancador`. Aqui fica só o que é
# mecânica, e cada bloco abaixo é uma armadilha que ele desarma.
#
# POR QUE UM WRAPPER, E NÃO O ocultar_apps.sh DIRETO NO apt.conf
#   Quatro razões, e nenhuma delas cabe numa linha de apt.conf:
#     1. O repositório mora em /mnt/Apate — um NVMe separado. Se ele não montar,
#        chamar o script direto imprimiria erro em TODO apt, para sempre.
#     2. O apt roda como root, e `$HOME` vira `/root`. O `lib/comum.sh` deriva
#        `MEOW_ESTADO` de `$HOME`: sem correção, o backup do .desktop iria parar
#        em `/root/.local/state/meowsystem` e o `meow desfazer --lancador` — que
#        ela roda como ELA — nunca o acharia. Um backup que o botão de volta não
#        enxerga é o mesmo que não ter backup.
#     3. O que o script criar no home dela nasce root:root. Sem o chown, o
#        próximo `meow` rodado por ela bate em "permissão negada" no próprio
#        diretório de estado.
#     4. Citação em apt.conf é um campo minado (aspas dentro de aspas dentro de
#        `sh -c`). Uma linha só, chamando um caminho fixo, não tem como sair
#        errado.
#
# POR QUE @ACERVO@/@USUARIA@/@LAR@ E NÃO UM ESPECIFICADOR
#   As unidades do systemd deste projeto usam `%h` justamente para NÃO precisar
#   de substituição — o arquivo instalado fica byte a byte igual ao do repo e o
#   `meow_escrever` compara por conteúdo. Um script de shell não tem `%h`.
#   A substituição acontece uma vez, no install, e o resultado é ESTÁVEL (mesmo
#   repo, mesma usuária) — então a comparação por conteúdo continua valendo e
#   este passo segue idempotente, que é o que a regra de ouro cobra.
#
# SAI SEMPRE 0
#   Um Post-Invoke que sai != 0 faz o `apt` terminar em erro. Ver o cabeçalho do
#   `99-meow-lancador`.

# ============================================================================
# SÃO DOIS ALVOS DESDE 02/09/2026, E O SEGUNDO CHEGOU TARDE
# ============================================================================
#   O `apt full-upgrade` de `set 2 15:21:34` atualizou o pacote `code` e devolveu
#   `Name=Visual Studio Code` ao `/usr/share/applications/code.desktop`. O hook
#   rodou — e reaplicou só o `NoDisplay`, porque era só isso que ele conhecia. O
#   nome curto ("VS Code") ficou esperando o `meow-doctor.timer` das 05:00, que
#   não conserta nomes de /usr/share por decisão registrada (o conserto usa sudo
#   e o doctor nunca usa).
#
#   `ocultar_apps.sh` e `nomes_apps.sh` escrevem no MESMO diretório, pelo MESMO
#   motivo, e são desfeitos pelo MESMO evento. Ter um no gatilho e o outro não
#   era um descuido, não uma escolha.
#
#   O `--so-sistema` NÃO É OPCIONAL AQUI. Sem ele o `nomes_apps.sh` também
#   passaria pelos `.desktop` do home dela — e este processo é root, então o
#   `meow_escrever` (temporário + rename) deixaria os arquivos com dono
#   root:root. É a armadilha 3 do bloco acima, vista de outro ângulo.
#
# O CÓDIGO DE SAÍDA É DOBRADO, com a mesma regra do `scripts/apos_flatpak.sh`:
#   2 vence tudo · 1 vence 0 · 0 só sobrevive se ninguém consertou nada.
#   Sem dobrar, um `ocultar` que consertou (1) seguido de um `nomes` já correto
#   (0) perderia o chown e a linha de log — justamente na vez que importava.

ACERVO="@ACERVO@"
USUARIA="@USUARIA@"
LAR="@LAR@"

ALVO="$ACERVO/scripts/ocultar_apps.sh"
ALVO_NOMES="$ACERVO/scripts/nomes_apps.sh"
ESTADO="$LAR/.local/state/meowsystem"
LOG="$ESTADO/apt-lancador.log"

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
# Só o 1 justifica mexer em dono de arquivo e só o 1 vale uma linha de log com
# conteúdo — um log que escreve "nada a fazer" depois de todo apt é um log que
# ninguém lê no dia em que ele tiver algo a dizer.
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
