#!/usr/bin/env bash
# app-themes/qbittorrent/manifesto.sh — Catppuccin Mocha no qBittorrent.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Nada de `exit`, nada de `set -e`:
# um `exit` aqui derrubaria o runner inteiro no meio do catálogo.
#
# ─────────────────────────────────────────────────────────────────────────────
# LEIA ISTO ANTES DE MEXER: o qBittorrent NÃO é nosso território.
# ─────────────────────────────────────────────────────────────────────────────
# O tema do qBittorrent é escrito pelo Ritual da Aurora, em
# `~/.config/zsh/scripts/aurora-qbittorrent-config.sh`, que o self-heal roda a
# cada ciclo (de hora em hora, no boot e depois de todo apt). Esse script:
#
#   1. resolve o tema por uma allowlist FECHADA — `dracula|andromeda|nenhum`;
#   2. REBAIXA para `dracula` qualquer valor que não conheça (o `*)` do case);
#   3. grava `Preferences/General/UseCustomUITheme` e `CustomUIThemePath` como
#      chaves ESTRUTURAIS, ou seja, reforçadas SEMPRE (não são "gosto");
#   4. sobrescreve o arquivo de estado `~/.local/state/aurora/qbittorrent-tema`
#      com o nome já rebaixado.
#
# Consequência medida, não suposta: escrever `catppuccin` no `qBittorrent.conf`
# por fora seria desfeito em até uma hora, E o arquivo de estado voltaria a
# dizer `dracula` — deixando a Vitória com um tema que "some sozinho" e sem
# nenhuma pista de por quê. Esse é exatamente o tipo de sintoma bizarro dias
# depois que a TRAVA 1 do `lib/comum.sh` existe para evitar.
#
# Por isso este módulo é HONESTO em vez de esperto: enquanto `catppuccin` não
# estiver na allowlist do Aurora, ele devolve MEOW_SEM_DEPENDENCIA (3) e imprime
# o patch exato que destrava. Ele NÃO edita o script do Aurora — aquilo mora em
# `~/.config/zsh`, o repo com auto-commit em 10 minutos, e a própria
# `meow_destino_permitido` recusaria a escrita.
#
# Quando destravar, o módulo continua NÃO escrevendo o `qBittorrent.conf`: ele
# instala o `.qbtheme`, grava o arquivo de estado e chama o próprio script do
# Aurora com `--tema catppuccin`. Quem escreve o conf segue sendo o Aurora, que
# é o único escritor que ninguém reverte. Dois donos no mesmo arquivo é o começo
# de toda guerra de idempotência.
#
# ─────────────────────────────────────────────────────────────────────────────
# ARMADILHA DO BINÁRIO: `meow_escrever` NÃO serve aqui.
# ─────────────────────────────────────────────────────────────────────────────
# O `.qbtheme` é um Qt Binary Resource (`.rcc`, magic `qres`) cheio de bytes NUL.
# A `meow_escrever` recebe o conteúdo como STRING, e toda substituição de comando
# do bash (`$(cat arquivo)`) descarta os NUL e come os newlines finais — o tema
# chegaria ao destino corrompido, e o qBittorrent subiria sem estilo nenhum
# logando só "Failed to load UI theme". Por isso a cópia binária tem função
# própria aqui embaixo, com o mesmo cuidado atômico da `meow_escrever`:
# temporário criado DENTRO do diretório de destino (o repo mora em /mnt/Apate e
# o destino em /home — `mv` entre eles não seria atômico) e `mv -f` no fim.
#
# Procedência do arquivo, commit pinado e sha256: veja `PROCEDENCIA.md`.
# Lá também está registrado que o acento upstream é AZUL (#89b4fa), não o mauve
# da casa — medido descomprimindo o `config.json` de dentro do `.rcc`.

# --- identidade do módulo ---------------------------------------------------
MEOW_QBT_APP_ID="org.qbittorrent.qBittorrent"
MEOW_QBT_NOME_AURORA="catppuccin"          # o nome que o Aurora precisa conhecer
MEOW_QBT_ARQUIVO="catppuccin-mocha.qbtheme"
MEOW_QBT_SHA256="f6ddf59ed881ea4a423e8d48a73f6f507c594a560f398097891fcb70bc8255e1"

# A fonte mora ao lado deste manifesto, dê onde der o `source`.
MEOW_QBT_DIR_MODULO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEOW_QBT_ORIGEM="$MEOW_QBT_DIR_MODULO/$MEOW_QBT_ARQUIVO"

# O script do Aurora: a FONTE é que manda. O self-heal roda a cópia de
# `~/.config/zsh/scripts/` (linha do `bash "$SRC/..."`) e só depois a instala em
# /usr/local/bin — patchar só o /usr/local/bin seria revertido no ciclo seguinte.
MEOW_QBT_AURORA_FONTE="$HOME/.config/zsh/scripts/aurora-qbittorrent-config.sh"
MEOW_QBT_AURORA_ESTADO="$HOME/.local/state/aurora/qbittorrent-tema"

# Só imprimimos a receita de destravamento UMA vez por processo: o runner chama
# detectar+conferir+aplicar em sequência e três cópias do mesmo parágrafo viram
# ruído que ninguém lê.
MEOW_QBT_JA_AVISOU=0

# ─────────────────────────────────────────────────────────────────────────────
# auxiliares
# ─────────────────────────────────────────────────────────────────────────────

# Onde o qBittorrent guarda a config. Aqui a instalação é FLATPAK (5.2.3, via
# flathub) — é a que o Aurora gerencia. O caminho nativo fica previsto porque
# custa duas linhas, mas está marcado como NÃO TESTADO nesta máquina: não há
# qBittorrent nativo instalado para conferir.
_meow_qbt_conf_dir() {
  if meow_tem flatpak && flatpak info "$MEOW_QBT_APP_ID" >/dev/null 2>&1; then
    printf '%s' "$HOME/.var/app/$MEOW_QBT_APP_ID/config/qBittorrent"
    return 0
  fi
  if meow_tem qbittorrent; then
    printf '%s' "$HOME/.config/qBittorrent"   # NÃO TESTADO nesta máquina
    return 0
  fi
  return 1
}

# O Aurora conhece `catppuccin`? Lemos o script VIVO em vez de guardar um
# "já destravei" em disco: assim, no minuto em que a Vitória acrescentar o case,
# este módulo passa a funcionar sozinho — e se ela desfizer, ele volta a travar
# sozinho também. Marcador em arquivo de estado seria a armadilha clássica de
# dizer "OK" sem que nada tenha sido consertado.
_meow_qbt_aurora_destravado() {
  # Sem o script do Aurora não há trava nenhuma (máquina que não é a dela).
  [ -f "$MEOW_QBT_AURORA_FONTE" ] || return 0
  grep -qE "^[[:space:]]*${MEOW_QBT_NOME_AURORA}\)" "$MEOW_QBT_AURORA_FONTE"
}

# A receita de destravamento, com o número de linha resolvido AO VIVO. Hardcodar
# "linha 68" envelheceria mal: qualquer edição no script do Aurora empurra tudo
# para baixo e a instrução passaria a apontar para o lugar errado.
_meow_qbt_receita() {
  [ "$MEOW_QBT_JA_AVISOU" = "1" ] && return 0
  MEOW_QBT_JA_AVISOU=1

  local linha_case linha_uso
  linha_case="$(grep -nE '^[[:space:]]*andromeda\)' "$MEOW_QBT_AURORA_FONTE" 2>/dev/null | head -1 | cut -d: -f1)"
  linha_uso="$(grep -nF 'dracula|andromeda|nenhum' "$MEOW_QBT_AURORA_FONTE" 2>/dev/null | head -1 | cut -d: -f1)"

  meow_aviso "qBittorrent TRAVADO pelo Ritual da Aurora — o tema não pode ser aplicado ainda."
  meow_info  "O Aurora resolve o tema por uma allowlist fechada (dracula|andromeda|nenhum) e"
  meow_info  "REBAIXA para dracula qualquer valor desconhecido, a cada ciclo do self-heal."
  meow_info  ""
  meow_info  "Para destravar, DUAS edições no lado do Andromeda:"
  meow_info  ""
  meow_info  "  arquivo: $MEOW_QBT_AURORA_FONTE"
  meow_info  ""
  meow_info  "  1) ACRESCENTAR um case, logo depois da linha ${linha_case:-<a do 'andromeda)'>}:"
  meow_info  ""
  printf '       %scatppuccin) TEMA_PATH="$TEMAS_DIR/%s" ;;%s\n' \
         "$C_MAUVE" "$MEOW_QBT_ARQUIVO" "$C_ZERO"
  meow_info  ""
  meow_info  "  2) ATUALIZAR o texto de uso na linha ${linha_uso:-<a do 'uso: \$0'>}, de:"
  meow_info  "       [--tema dracula|andromeda|nenhum]"
  meow_info  "     para:"
  printf '       %s[--tema dracula|andromeda|catppuccin|nenhum]%s\n' "$C_MAUVE" "$C_ZERO"
  meow_info  ""
  meow_info  "Edite a FONTE (o caminho acima), não /usr/local/bin: o self-heal roda a fonte"
  meow_info  "e reinstala a cópia. Este módulo não edita esse arquivo — ele está em"
  meow_info  "~/.config/zsh, o repo com auto-commit em 10 minutos, e a escrita é recusada."
  return 0
}

# Backup obrigatório antes de sobrescrever qualquer arquivo dela.
_meow_qbt_backup() {
  local alvo="$1" dir base
  [ -e "$alvo" ] || return 0
  base="$(basename "$alvo")"
  dir="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${_MEOW_QBT_ISO:-$(date -Iseconds)}"
  mkdir -p "$dir" || { meow_erro "não consegui criar $dir"; return 1; }
  cp -a -- "$alvo" "$dir/$base" || { meow_erro "backup de $alvo falhou"; return 1; }
  meow_info "backup: $dir/$base"
  return 0
}

# Cópia BINÁRIA atômica — a `meow_escrever` corromperia o .rcc (ver cabeçalho).
# Devolve MEOW_OK se já estava igual, MEOW_DIVERGENTE se copiou, MEOW_ERRO se falhou.
_meow_qbt_instalar_tema() {
  local origem="$1" destino="$2" dir tmp
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"
  cmp -s -- "$origem" "$destino" && return "$MEOW_OK"

  if meow_seco; then
    meow_muda "instalaria $destino"
    return "$MEOW_DIVERGENTE"
  fi

  _meow_qbt_backup "$destino" || return "$MEOW_ERRO"
  dir="$(dirname "$destino")"
  mkdir -p "$dir" || return "$MEOW_ERRO"
  tmp="$(mktemp -p "$dir" ".meow.XXXXXX")" || return "$MEOW_ERRO"
  cp -- "$origem" "$tmp"     || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  chmod 644 "$tmp"
  mv -f -- "$tmp" "$destino" || { rm -f "$tmp"; return "$MEOW_ERRO"; }
  return "$MEOW_DIVERGENTE"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_detectar — 0 se dá para trabalhar, 3 se não dá. Nunca falha.
# ─────────────────────────────────────────────────────────────────────────────
# A trava do Aurora entra AQUI, e não como erro, de propósito: para o runner,
# "o Aurora não me deixa escrever este tema" é indistinguível de uma dependência
# faltando — não há nada a consertar do nosso lado, e reportar divergência
# eterna a cada ciclo treinaria a Vitória a ignorar o relatório. 3 é o código
# que faz o auto-reparo ficar quieto; a receita impressa é o que dá o próximo passo.
meow_app_detectar() {
  local conf_dir
  conf_dir="$(_meow_qbt_conf_dir)" || {
    meow_pula "qBittorrent não instalado"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  if [ ! -s "$MEOW_QBT_ORIGEM" ]; then
    meow_aviso "falta o tema em $MEOW_QBT_ORIGEM (veja PROCEDENCIA.md para rebaixar)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! _meow_qbt_aurora_destravado; then
    _meow_qbt_receita
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_ok "qBittorrent presente e o Aurora conhece '$MEOW_QBT_NOME_AURORA'"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_conferir — 0 aplicado, 1 divergente, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_conferir() {
  meow_app_detectar >/dev/null 2>&1 || {
    # Repete a detecção sem silenciar, para a mensagem certa chegar à tela.
    meow_app_detectar
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local conf_dir conf destino divergiu=0
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  conf="$conf_dir/qBittorrent.conf"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"

  cmp -s -- "$MEOW_QBT_ORIGEM" "$destino" || {
    meow_muda "o .qbtheme não está instalado (ou está diferente) em $destino"
    divergiu=1
  }

  # A chave no INI é `General\CustomUIThemePath`. A barra invertida é escape de
  # regex num grep comum — o teste daria sempre "não bate" e o módulo se
  # declararia divergente para sempre. Por isso: grep -F, literal. (É a mesma
  # pedra em que o próprio script do Aurora tropeçou e documentou.)
  if [ -f "$conf" ]; then
    grep -qF "General\\CustomUIThemePath=$destino" "$conf" || {
      meow_muda "CustomUIThemePath não aponta para o nosso tema"
      divergiu=1
    }
    grep -qF 'General\UseCustomUITheme=true' "$conf" || {
      meow_muda "UseCustomUITheme não está em true"
      divergiu=1
    }
  else
    meow_muda "$conf ainda não existe"
    divergiu=1
  fi

  # O estado do Aurora tem de concordar, senão o próximo ciclo desfaz tudo.
  [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" = "$MEOW_QBT_NOME_AURORA" ] || {
    meow_muda "o estado do Aurora não diz '$MEOW_QBT_NOME_AURORA'"
    divergiu=1
  }

  if [ "$divergiu" = "0" ]; then
    meow_ok "qBittorrent com Catppuccin Mocha aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_aplicar — 0 nada a fazer, 1 aplicou, 2 erro, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_aplicar() {
  meow_app_detectar >/dev/null 2>&1 || { meow_app_detectar; return "$MEOW_SEM_DEPENDENCIA"; }

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "qBittorrent já está com o Catppuccin Mocha — nada a fazer"
    return "$MEOW_OK"
  }

  _MEOW_QBT_ISO="$(date -Iseconds)"
  local conf_dir destino rc mudou=0
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"

  # Integridade antes de instalar: um download que virou página de erro HTTP
  # tem o tamanho e o nome certos e só falha lá na frente, dentro do app, com um
  # "Failed to load UI theme" que não diz nada. Conferimos o sha256 pinado.
  if meow_tem sha256sum; then
    local soma
    soma="$(sha256sum -- "$MEOW_QBT_ORIGEM" 2>/dev/null | cut -d' ' -f1)"
    if [ "$soma" != "$MEOW_QBT_SHA256" ]; then
      meow_erro "sha256 do tema não confere (esperado $MEOW_QBT_SHA256, veio $soma)"
      return "$MEOW_ERRO"
    fi
  fi

  # --- 1. o arquivo do tema -------------------------------------------------
  _meow_qbt_instalar_tema "$MEOW_QBT_ORIGEM" "$destino"
  rc=$?
  case "$rc" in
    0) : ;;
    1) mudou=1; meow_muda "tema instalado em $destino" ;;
    *) meow_erro "não consegui instalar o .qbtheme"; return "$MEOW_ERRO" ;;
  esac

  # --- 2. o estado do Aurora ------------------------------------------------
  # É por este arquivo que o Aurora decide o tema quando ninguém passa --tema.
  # Sem escrevê-lo, o próximo ciclo do self-heal leria `dracula` e reverteria.
  if [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" != "$MEOW_QBT_NOME_AURORA" ]; then
    if meow_seco; then
      meow_muda "gravaria '$MEOW_QBT_NOME_AURORA' em $MEOW_QBT_AURORA_ESTADO"
      mudou=1
    else
      _meow_qbt_backup "$MEOW_QBT_AURORA_ESTADO" || return "$MEOW_ERRO"
      meow_escrever "$MEOW_QBT_AURORA_ESTADO" "$MEOW_QBT_NOME_AURORA" 644
      case $? in
        1) mudou=1; meow_muda "estado do Aurora -> $MEOW_QBT_NOME_AURORA" ;;
        2) meow_erro "não consegui gravar $MEOW_QBT_AURORA_ESTADO"; return "$MEOW_ERRO" ;;
      esac
    fi
  fi

  # --- 3. o conf, escrito por quem é dono dele ------------------------------
  # NÃO tocamos no qBittorrent.conf. Chamamos o script do Aurora, que sabe
  # fechar o app antes de gravar (ele reescreve o conf inteiro ao sair) e que
  # tem a guarda de não matar o app com download em andamento — guarda que
  # existe porque em 2026-08-02 um download de minissérie foi perdido assim.
  if meow_seco; then
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $MEOW_QBT_NOME_AURORA"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -x "$MEOW_QBT_AURORA_FONTE" ] || [ -f "$MEOW_QBT_AURORA_FONTE" ]; then
    meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
    if bash "$MEOW_QBT_AURORA_FONTE" --tema "$MEOW_QBT_NOME_AURORA"; then
      mudou=1
    else
      meow_erro "o script do Aurora falhou ao aplicar o tema"
      return "$MEOW_ERRO"
    fi
  else
    meow_aviso "script do Aurora ausente — o tema está no disco, mas o conf não foi tocado"
    meow_aviso "ative à mão: Ferramentas > Preferências > Comportamento > usar tema personalizado"
  fi

  # Honestidade sobre o resultado visual (medido, ver PROCEDENCIA.md).
  meow_aviso "atenção: o acento deste tema upstream é AZUL (#89b4fa), não o mauve #CBA6F7 da casa"

  [ "$mudou" = "1" ] && return "$MEOW_DIVERGENTE"
  return "$MEOW_OK"
}
