#!/usr/bin/env bash
# autostart.sh — impede que um app suba sozinho no login, SEM escrever uma
# linha em `~/.config/autostart/`.
#
# ============================================================================
# LEIA ESTAS SEIS LINHAS ANTES DE MEXER AQUI
# ============================================================================
#   `~/.config/autostart/` é da AURORA (`docs/FRONTEIRA.md:52`). Este arquivo
#   NÃO abre aquele diretório, nem para apagar, nem para escrever `Hidden=true`.
#   O nome do script é `autostart` porque é assim que o problema se chama em
#   XDG e em systemd — quem for procurar "o app abre sozinho" vai grepar essa
#   palavra —, mas o único lugar em que ele escreve é
#   `~/.config/systemd/user/`, por `systemctl --user mask`.
#
# ============================================================================
# O QUE ESTE SCRIPT FAZ, E POR QUE É MASK E NÃO OUTRA COISA
# ============================================================================
#
# O CAMINHO INTEIRO, MEDIDO
#   Um `.desktop` em `~/.config/autostart/` não é lido pelo COSMIC diretamente:
#   quem o lê é o `systemd-xdg-autostart-generator`, que gera, em
#   `/run/user/1000/systemd/generator.late/`, uma unidade chamada
#       app-<id-escapado>@autostart.service
#   e a pendura em `xdg-desktop-autostart.target.wants/`. Conferido lendo a
#   unidade gerada do `openrgb-gloway`, que traz literalmente
#       SourcePath=/home/vitoriamaria/.config/autostart/openrgb-gloway.desktop
#       PartOf=graphical-session.target
#   O escape é o do systemd: `openrgb-gloway` vira `openrgb\x2dgloway`, e é por
#   isso que este script chama `systemd-escape` em vez de montar o nome à mão.
#
# POR QUE `Hidden=true` NO `.desktop` NÃO SERVE — E ESTE É O PONTO DA SPRINT L
#   Porque o arquivo não é nosso e não fica parado. Enquanto a seção "6.
#   autostart" do `aurora-qbittorrent-config.sh` estava LIGADA, ela recopiava o
#   `.desktop` do flatpak com um `cmp -s`: qualquer edição — `Hidden=true`
#   inclusive — contava como "diferente da fonte" e era sobrescrita **em
#   silêncio**, no próximo ciclo do `ritual-aurora-self-heal.timer` (~1h) ou
#   logo depois do próximo `apt`, pelo hook `99-ritual-aurora-self-heal`. Uma
#   edição que dura até uma hora não é conserto, é uma armadilha com fusível.
#
#   O mask não tem esse problema porque ele não disputa o `.desktop`: a Aurora
#   pode recopiar o arquivo para sempre, o generator pode gerar a unidade para
#   sempre, e a ATIVAÇÃO continua bloqueada.
#
# POR QUE O MASK GANHA DO GENERATOR — MEDIDO, NÃO SUPOSTO
#   `systemctl --user show --property=UnitPath` desta máquina, em ordem:
#       …/.config/systemd/user.control
#       /run/user/1000/systemd/user.control
#       /run/user/1000/systemd/transient
#       /run/user/1000/systemd/generator.early
#       /home/vitoriamaria/.config/systemd/user      <- o mask mora AQUI
#       …
#       /run/user/1000/systemd/generator.late        <- o autostart nasce AQUI
#   O `~/.config/systemd/user` aparece **doze posições antes** do
#   `generator.late`. O link para `/dev/null` que o `mask` planta lá vence, e o
#   `systemctl --user is-enabled` responde `masked`.
#
# ABRIR PELO ÍCONE CONTINUA FUNCIONANDO — PROVADO, NÃO SUPOSTO
#   O mask bloqueia a UNIDADE `app-<id>@autostart.service`, e o lançador não
#   passa por ela. Medido com `systemctl --user list-units 'app-*'` com a
#   sessão dela viva: todo app aberto pelo ícone vive num **escopo transitório**
#   de nome completamente diferente —
#       app-cosmic-steam-31887.scope                         (Steam, pelo dock)
#       app-cosmic-com.system76.CosmicAppList-5518.scope     (o terminal dela)
#       app-flatpak-io.github.…-4034194949.scope             (um flatpak)
#   "Application launched by COSMIC", `.scope` e não `.service`, com o PID no
#   nome. Um mask em `…@autostart.service` não alcança nenhum deles: são nomes
#   diferentes, criados na hora pela API do systemd.
#
#   E o `@autostart.service` só é puxado por `xdg-desktop-autostart.target`, que
#   sobe uma vez, no início da sessão. Fora do login ele não é alvo de ninguém.
#
# ============================================================================
# O ESTADO DO qBITTORRENT EM 25/08/2026 — A SPRINT L JÁ ESTAVA RESOLVIDA
# ============================================================================
#   Está registrado aqui porque quem ler a Sprint L vai procurar um defeito que
#   não existe mais, e gastar o dia:
#
#   1. A seção "6. autostart" do `aurora-qbittorrent-config.sh` foi **DESLIGADA
#      em 11/08/2026, a pedido dela**. O bloco de hoje (linhas 496-514) faz o
#      OPOSTO do que a sprint descreve — ele REMOVE o arquivo:
#          AUTOSTART="$HOME/.config/autostart/$APP.desktop"
#          if [ -f "$AUTOSTART" ]; then rm -f "$AUTOSTART"; …
#      com o comentário "A decisão de ligar isso foi minha, não dela, e ela
#      reclamou do app subindo no login."
#   2. `~/.config/autostart/` tem só `openrgb-gloway.desktop` e
#      `ritual_aurora.desktop`. Não há `.desktop` do qBittorrent.
#   3. O generator não gera mais a unidade: `ls /run/user/1000/systemd/
#      generator.late/ | grep -i qbit` não devolve nada.
#   4. O mask **já está aplicado**, à mão, desde 11/08 09:59:
#          ~/.config/systemd/user/app-org.qbittorrent.qBittorrent@autostart.service -> /dev/null
#   5. `pgrep -ai qbittorrent` não devolve nada: o app não está rodando.
#
#   Ou seja: o conserto já existe em DOIS lugares independentes. Este script não
#   inventa um terceiro — ele torna o de número 4 **conferível e reversível**
#   pelo projeto, que é o que faltava. Um link para `/dev/null` largado num
#   diretório de systemd, sem ninguém que saiba dizer quem o pôs lá nem como
#   tirar, é exatamente o tipo de coisa que este repositório existe para não ter.
#
# ============================================================================
# DESLIGAR TEM DE DESLIGAR — E POR ISSO ESTE SCRIPT ANOTA O ESTADO DE ANTES
# ============================================================================
#   O `remover` só desmascara o que **nós** mascaramos. O mask do qBittorrent é
#   anterior a este arquivo e foi feito pela mão dela em 11/08: desfazê-lo num
#   `meow desfazer` seria devolver um app que ela mandou calar, achando que
#   estava limpando a nossa sujeira. Por isso o `aplicar` grava, em
#       ~/.local/state/meowsystem/autostart-mascarados.tsv
#   o que `systemctl --user is-enabled` respondia ANTES de encostarmos na
#   unidade. Quem já estava `masked` sai da lista de responsabilidade nossa e o
#   `remover` o deixa exatamente como estava.
#
#   Tirar um nome de `AUTOSTART_BLOQUEADOS` **não** desmascara sozinho — o
#   `aplicar` só AVISA, com o comando na tela. Desmascarar é `remover`, que é um
#   verbo que a pessoa digita. Um script que desfaz o próprio trabalho porque
#   uma vírgula sumiu de um arquivo de configuração é como se perde uma escolha
#   sem ninguém saber por quê.
#
# O QUE ESTE SCRIPT NÃO FAZ, DE PROPÓSITO
#   - Não mata processo. Se o app já está aberto, ele continua aberto: o mask
#     vale para a ATIVAÇÃO, e o efeito aparece no próximo login. O `aplicar` diz
#     isso na tela quando encontra o processo vivo.
#   - Não chama `daemon-reload`. O `systemctl mask` já avisa o gerenciador; um
#     reload do gerenciador de usuário durante a sessão do COSMIC é risco sem
#     ganho nenhum aqui.
#   - Não usa `meow_escrever`. O que o mask planta é um SYMLINK para /dev/null,
#     e o `meow_escrever` grava arquivo comum — e o gerenciador precisa ser
#     avisado, o que só o `systemctl` faz. Pelo mesmo motivo o manifesto não
#     recebe o caminho: um `rm` cego do link, no `--uninstall`, deixaria o
#     gerenciador com uma visão velha. Quem desfaz é o `remover` daqui.
#
# USO
#   autostart.sh aplicar        mascara o que estiver em AUTOSTART_BLOQUEADOS
#   autostart.sh conferir       0 = tudo mascarado · 1 = falta algum · 3 = sem systemd
#   autostart.sh estado         diz, por app, o que o systemd responde hoje
#   autostart.sh remover [id…]  desmascara o que NÓS mascaramos (tudo, ou os id dados)
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# Lista separada por vírgula de IDs de `.desktop` SEM a extensão — é o mesmo
# nome que aparece em `~/.config/autostart/<id>.desktop`. VAZIO = não faz nada.
AUTOSTART_BLOQUEADOS="${AUTOSTART_BLOQUEADOS:-}"

AUTOSTART_REGISTRO="$MEOW_ESTADO/autostart-mascarados.tsv"

# `app-<escapado>@autostart.service` é o nome que o systemd-xdg-autostart-generator
# usa, e o escape é do systemd (o `-` vira `\x2d`). Montar à mão daria um nome
# que não casa com nada e um mask que não bloqueia coisa nenhuma.
_auto_unidade() {
  local id="$1" esc
  esc="$(systemd-escape -- "$id" 2>/dev/null)" || return 1
  [ -n "$esc" ] || return 1
  printf 'app-%s@autostart.service' "$esc"
}

# O `\n` do printf NÃO é enfeite: com `printf '%s'` a última (e única) linha sai
# sem quebra, o `read` devolve 1 no EOF, a condição do `while` falha e o corpo
# NUNCA roda. Escrito assim primeiro, o script deu rc=0 calado para uma lista
# com um item — o pior defeito possível aqui, porque "não fez nada" e "está tudo
# certo" ficam com a mesma cara na tela.
_auto_lista() {
  local item
  printf '%s\n' "$AUTOSTART_BLOQUEADOS" | tr ',' '\n' | while IFS= read -r item; do
    # apara espaço dos dois lados: `a, b` é escrita normal num arquivo de conf
    item="${item#"${item%%[![:space:]]*}"}"
    item="${item%"${item##*[![:space:]]}"}"
    [ -n "$item" ] && printf '%s\n' "$item"
  done
}

# 3 = falta dependência, e não 2 = erro: numa máquina sem systemd de usuário
# (ou num shell sem barramento) não há defeito nenhum a consertar, há assunto
# que não se aplica. É o que deixa o `meow doctor` ficar quieto.
_auto_dependencia() {
  if ! meow_tem systemctl || ! meow_tem systemd-escape; then
    meow_pula "sem systemctl/systemd-escape — nada a fazer com autostart"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! systemctl --user show --property=Version >/dev/null 2>&1; then
    meow_pula "sem gerenciador systemd de usuário ao alcance — nada a fazer"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# `masked` (link em ~/.config) e `masked-runtime` (link em /run) são as duas
# respostas que contam como "bloqueado". O rc do `is-enabled` é 1 para masked e
# 4 para not-found, então o que vale é o TEXTO, não o código.
_auto_estado_unidade() { systemctl --user is-enabled -- "$1" 2>/dev/null || true; }
_auto_mascarada()      { case "$(_auto_estado_unidade "$1")" in masked|masked-runtime) return 0 ;; esac; return 1; }

# Uma linha por id — a antiga sai antes de a nova entrar. O filtro é `awk` no
# CAMPO inteiro, e não `grep "^$id"`, pelo mesmo motivo do `meow_manifesto_registrar`:
# id de desktop é texto cheio de `.`, e num grep isso é expressão regular.
_auto_registrar() {
  local id="$1" unidade="$2" antes="$3"
  meow_seco && return 0
  mkdir -p "$MEOW_ESTADO" || return 0
  if [ -f "$AUTOSTART_REGISTRO" ]; then
    awk -F'\t' -v a="$id" '$1 != a' "$AUTOSTART_REGISTRO" > "$AUTOSTART_REGISTRO.tmp" 2>/dev/null \
      && mv -f "$AUTOSTART_REGISTRO.tmp" "$AUTOSTART_REGISTRO" 2>/dev/null
    rm -f "$AUTOSTART_REGISTRO.tmp" 2>/dev/null
  fi
  printf '%s\t%s\t%s\t%s\n' "$id" "$unidade" "$antes" "$(date -Iseconds)" >> "$AUTOSTART_REGISTRO"
  return 0
}

_auto_esquecer() {
  local id="$1"
  meow_seco && return 0
  [ -f "$AUTOSTART_REGISTRO" ] || return 0
  awk -F'\t' -v a="$id" '$1 != a' "$AUTOSTART_REGISTRO" > "$AUTOSTART_REGISTRO.tmp" 2>/dev/null \
    && mv -f "$AUTOSTART_REGISTRO.tmp" "$AUTOSTART_REGISTRO" 2>/dev/null
  rm -f "$AUTOSTART_REGISTRO.tmp" 2>/dev/null
  return 0
}

# O que o registro guarda sobre um id: campo 3 = o `is-enabled` de ANTES.
_auto_antes_de() {
  [ -f "$AUTOSTART_REGISTRO" ] || return 1
  awk -F'\t' -v a="$1" '$1 == a { print $3; achou=1 } END { exit !achou }' "$AUTOSTART_REGISTRO" 2>/dev/null
}

_auto_ids_registrados() {
  [ -f "$AUTOSTART_REGISTRO" ] || return 0
  awk -F'\t' '{ print $1 }' "$AUTOSTART_REGISTRO" 2>/dev/null
}

# O app está aberto AGORA? Não é para matar nada — é para o script poder dizer,
# na tela, que o efeito só aparece no próximo login. Sem esta linha o `aplicar`
# diria "pronto" e ela veria o app ali, na cara dela, contradizendo a mensagem.
#
# É `-x` no ÚLTIMO componente do id (`org.qbittorrent.qBittorrent` -> `qBittorrent`)
# e NÃO `pgrep -f` no id inteiro. O `-f` casa a linha de comando de qualquer
# processo — inclusive a do shell que chamou este script, se o nome do app
# estiver nela. Já me custou um diagnóstico errado hoje, medindo outra coisa:
# `pgrep -f cosmic-applet-time` devolveu o applet E o meu próprio `zsh -c`.
# Um falso positivo aqui vira um aviso "o app está aberto" que não é verdade.
_auto_vivo() { pgrep -i -x -- "${1##*.}" >/dev/null 2>&1; }

cmd_aplicar() {
  if [ -z "$AUTOSTART_BLOQUEADOS" ]; then
    meow_pula "AUTOSTART_BLOQUEADOS vazio — nenhum autostart a bloquear"
    return "$MEOW_OK"
  fi
  _auto_dependencia || return $?

  local rc="$MEOW_OK" id unidade antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || {
      meow_erro "não consegui montar o nome da unidade para '$id'"; rc="$MEOW_ERRO"; continue
    }

    if _auto_mascarada "$unidade"; then
      # Já estava bloqueado. Se ainda não está no registro, é mask de fora (a
      # mão dela, em 11/08, no caso do qBittorrent) — anotamos QUE era de fora,
      # para o `remover` não desfazer o que não foi nosso.
      if ! _auto_antes_de "$id" >/dev/null 2>&1; then
        _auto_registrar "$id" "$unidade" "masked-antes-de-nos"
        meow_ok "$id já estava mascarado por fora — anotado, e o 'remover' não vai desfazer"
      else
        meow_ok "$id já mascarado ($unidade)"
      fi
      continue
    fi

    antes="$(_auto_estado_unidade "$unidade")"; antes="${antes:-desconhecido}"
    if meow_seco; then
      meow_muda "mascararia $unidade (estado hoje: $antes)"
      rc="$MEOW_DIVERGENTE"; continue
    fi

    if systemctl --user mask -- "$unidade" >/dev/null 2>&1; then
      _auto_registrar "$id" "$unidade" "$antes"
      meow_muda "$id não sobe mais no login (mask em $unidade)"
      _auto_vivo "$id" && meow_aviso "$id está ABERTO agora — não vou fechá-lo; o efeito vale no próximo login"
      rc="$MEOW_DIVERGENTE"
    else
      meow_erro "systemctl --user mask falhou para $unidade"
      rc="$MEOW_ERRO"
    fi
  done <<< "$(_auto_lista)"

  # Órfãos: o que NÓS mascaramos e que saiu da lista do conf. Só aviso — ver o
  # "DESLIGAR TEM DE DESLIGAR" no cabeçalho.
  local reg
  while IFS= read -r reg; do
    [ -n "$reg" ] || continue
    _auto_lista | grep -qxF -- "$reg" && continue
    [ "$(_auto_antes_de "$reg" 2>/dev/null)" = "masked-antes-de-nos" ] && continue
    meow_aviso "'$reg' saiu de AUTOSTART_BLOQUEADOS mas continua mascarado."
    meow_aviso "  para devolvê-lo:  scripts/autostart.sh remover $reg"
  done <<< "$(_auto_ids_registrados)"

  meow_registrar "autostart.sh aplicar rc=$rc lista=$AUTOSTART_BLOQUEADOS"
  return "$rc"
}

cmd_conferir() {
  if [ -z "$AUTOSTART_BLOQUEADOS" ]; then
    meow_pula "AUTOSTART_BLOQUEADOS vazio — nada a conferir"
    return "$MEOW_OK"
  fi
  _auto_dependencia || return $?

  local rc="$MEOW_OK" id unidade
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || { meow_erro "id inválido: '$id'"; rc="$MEOW_ERRO"; continue; }
    if _auto_mascarada "$unidade"; then
      meow_ok "$id bloqueado no login"
    else
      meow_muda "$id NÃO está bloqueado ($unidade = $(_auto_estado_unidade "$unidade" | sed 's/^$/sem resposta/'))"
      [ "$rc" = "$MEOW_ERRO" ] || rc="$MEOW_DIVERGENTE"
    fi
  done <<< "$(_auto_lista)"
  return "$rc"
}

# Read-only. Mostra o que o systemd responde hoje para cada id da lista MAIS
# tudo o que já mascaramos um dia — inclusive o que saiu do conf e ficou para trás.
cmd_estado() {
  _auto_dependencia || return $?
  local vistos="" id unidade est antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    vistos="$vistos $id"
    unidade="$(_auto_unidade "$id")" || continue
    est="$(_auto_estado_unidade "$unidade")"; est="${est:-sem resposta}"
    antes="$(_auto_antes_de "$id" 2>/dev/null)" || antes="—"
    meow_info "$id: $est   (unidade: $unidade · antes de nós: ${antes:-—})"
  done <<< "$(_auto_lista)"

  while IFS= read -r id; do
    [ -n "$id" ] || continue
    case " $vistos " in *" $id "*) continue ;; esac
    unidade="$(_auto_unidade "$id")" || continue
    est="$(_auto_estado_unidade "$unidade")"; est="${est:-sem resposta}"
    meow_pula "$id: $est   (fora do conf, mas no nosso registro)"
  done <<< "$(_auto_ids_registrados)"

  meow_info "abrir pelo ícone não passa por estas unidades — ver o cabeçalho deste arquivo"
  return "$MEOW_OK"
}

cmd_remover() {
  _auto_dependencia || return $?

  local alvos
  if [ "$#" -gt 0 ]; then alvos="$(printf '%s\n' "$@")"
  else                    alvos="$(_auto_ids_registrados)"; fi

  if [ -z "$alvos" ]; then
    meow_pula "não há nada no nosso registro para desmascarar"
    return "$MEOW_OK"
  fi

  local rc="$MEOW_OK" id unidade antes
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    unidade="$(_auto_unidade "$id")" || { meow_erro "id inválido: '$id'"; rc="$MEOW_ERRO"; continue; }

    antes="$(_auto_antes_de "$id" 2>/dev/null)" || antes=""
    if [ -z "$antes" ]; then
      meow_pula "$id não está no nosso registro — não fomos nós que mascaramos, não mexo"
      continue
    fi
    if [ "$antes" = "masked-antes-de-nos" ]; then
      meow_pula "$id já estava mascarado antes do MeowSystem — deixo como estava"
      _auto_esquecer "$id"
      continue
    fi
    if ! _auto_mascarada "$unidade"; then
      meow_ok "$id já não está mascarado"
      _auto_esquecer "$id"
      continue
    fi
    if meow_seco; then
      meow_muda "desmascararia $unidade (devolvendo ao estado '$antes')"
      rc="$MEOW_DIVERGENTE"; continue
    fi
    if systemctl --user unmask -- "$unidade" >/dev/null 2>&1; then
      _auto_esquecer "$id"
      meow_muda "$id devolvido ao autostart (unmask em $unidade, estado de antes: $antes)"
      meow_info "volta a subir no próximo login, se o .desktop dele existir em ~/.config/autostart"
      rc="$MEOW_DIVERGENTE"
    else
      meow_erro "systemctl --user unmask falhou para $unidade"
      rc="$MEOW_ERRO"
    fi
  done <<< "$alvos"

  meow_registrar "autostart.sh remover rc=$rc"
  return "$rc"
}

sub="${1:-aplicar}"; shift 2>/dev/null || true
case "$sub" in
  aplicar)  cmd_aplicar ;;
  conferir) cmd_conferir ;;
  estado)   cmd_estado ;;
  remover)  cmd_remover "$@" ;;
  *) meow_erro "uso: autostart.sh {aplicar|conferir|estado|remover [id…]}"; exit "$MEOW_ERRO" ;;
esac
