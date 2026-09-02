#!/usr/bin/env bash
# assets/temas-de-apps/qbittorrent/manifesto.sh — Catppuccin Mocha no qBittorrent.
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
# ─────────────────────────────────────────────────────────────────────────────
# DESTRAVOU. O texto acima descreve o passado — atualizado em 25/08/2026.
# ─────────────────────────────────────────────────────────────────────────────
# O patch foi aplicado: `aurora-qbittorrent-config.sh:74` tem o case
# `catppuccin)`, e a máquina confirma que o tema está no ar:
#
#   ~/.local/state/aurora/qbittorrent-tema            -> catppuccin
#   .../qBittorrent/qBittorrent.conf UseCustomUITheme -> true
#   .../qBittorrent/qBittorrent.conf CustomUIThemePath -> .../catppuccin-mocha.qbtheme
#
# O código deste módulo SEMPRE esteve certo: `_meow_qbt_aurora_destravado` lê a
# allowlist ao vivo, então ele passou a aplicar sozinho no dia em que o Aurora
# mudou. Quem ficou para trás foi esta prosa — e por dias o `doctor` dizia uma
# coisa e o manifesto dizia outra. Achado pela auditoria de documentação de
# 25/08/2026, que é o motivo de este bloco existir em vez de o texto de cima ser
# simplesmente apagado: o raciocínio da trava continua valendo se o Aurora um dia
# reverter a allowlist.
#
# Quando destravar, o módulo continua NÃO escrevendo o `qBittorrent.conf`: ele
# instala o `.qbtheme`, grava o arquivo de estado e chama o próprio script do
# Aurora com `--tema catppuccin`. Quem escreve o conf segue sendo o Aurora, que
# é o único escritor que ninguém reverte. Dois donos no mesmo arquivo é o começo
# de toda guerra de idempotência.
#
# O PREÇO DESSA DELEGAÇÃO, dito na cara: `aurora-qbittorrent-config.sh` não é um
# aplicador de tema, é a configuração INTEIRA do qBittorrent. Chamá-lo também
# cria a árvore de `/mnt/Apate/Torrents`, aplica os overrides do flatpak, gera as
# credenciais da WebUI, escreve o `categories.json` e — se houver algo a mudar e
# nenhum download em andamento — FECHA e reabre o aplicativo. É o mesmo que o
# self-heal já faz de hora em hora, então não há efeito novo no sistema; mas
# significa que `meow_app_aplicar` pode reiniciar o cliente de torrent dela, e
# isso não pode ser surpresa para quem lê este arquivo depois.
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
# ─────────────────────────────────────────────────────────────────────────────
# TRÊS MANEIRAS DE ESTE MÓDULO MENTIR — todas reproduzidas em sandbox e fechadas
# ─────────────────────────────────────────────────────────────────────────────
#   1. Deduzir "apliquei" do exit code do Aurora. Com download em andamento ele
#      ADIA a gravação do conf e sai 0; o módulo devolvia 1 ("apliquei") em toda
#      rodada, para sempre, sem o conf jamais mudar. Agora o veredito sai de uma
#      RECONFERÊNCIA do estado real (passo 4 do `meow_app_aplicar`).
#   2. Tratar "script do Aurora ausente" como "liberado". O módulo instalava o
#      tema, não escrevia o conf e, na segunda rodada, devolvia 0 ("nada a
#      fazer") enquanto o `meow_app_conferir` devolvia 1 — dois códigos
#      contraditórios para o mesmo estado. Agora é 3, com o motivo na tela.
#   3. Prometer o qBittorrent NATIVO. O escritor do conf (o script do Aurora) é
#      flatpak-only; o caminho nativo levava ao mesmo laço eterno do item 1.
#      Agora é 3 declarado, não meia-boca silenciosa.
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

# Todo aviso estrutural sai UMA vez por processo: o runner chama
# detectar+conferir+aplicar em sequência e três cópias do mesmo parágrafo viram
# ruído que ninguém lê.
MEOW_QBT_JA_AVISOU=0          # a receita de destravamento
MEOW_QBT_AVISOU_NATIVO=0      # "só o flatpak é coberto"
MEOW_QBT_AVISOU_SEM_AURORA=0  # "o script do Aurora não está aqui"

# ─────────────────────────────────────────────────────────────────────────────
# auxiliares
# ─────────────────────────────────────────────────────────────────────────────

# Onde o qBittorrent guarda a config. Só o FLATPAK conta aqui (5.2.3, via
# flathub), e não é preguiça: este módulo delega a escrita do `qBittorrent.conf`
# ao script do Aurora, e aquele script é flatpak-only por construção — ele abre
# com `command -v flatpak || exit 0` e `flatpak info "$APP" || exit 0`.
#
# MEDIDO em sandbox, não suposto: com o caminho nativo previsto aqui e o Aurora
# saindo 0 sem fazer nada, `meow_app_aplicar` devolvia 1 ("apliquei") em TODA
# rodada, para sempre, e o conf nunca era escrito. Prometer uma instalação que a
# única ferramenta de escrita não enxerga é a armadilha de idempotência da casa:
# dizer OK sem consertar nada. Enquanto ninguém escrever o conf nativo, o nativo
# é ausência DECLARADA (3, com aviso), não meia-boca silenciosa.
_meow_qbt_conf_dir() {
  meow_tem flatpak || return 1
  # por diretório, não por `flatpak info`: aquele cria o repositório ostree no
  # home só por ser perguntado, e detecção não pode escrever (ver lib/comum.sh).
  meow_flatpak_tem "$MEOW_QBT_APP_ID" || return 1
  printf '%s' "$HOME/.var/app/$MEOW_QBT_APP_ID/config/qBittorrent"
}

# Existe um qBittorrent nativo? Serve só para explicar o 3 em vez de sumir.
_meow_qbt_avisar_nativo() {
  [ "$MEOW_QBT_AVISOU_NATIVO" = "1" ] && return 0
  MEOW_QBT_AVISOU_NATIVO=1
  meow_aviso "há um qBittorrent NATIVO instalado, mas este módulo cobre só o flatpak"
  meow_info  "(quem escreve o conf é o script do Aurora, que é flatpak-only)"
  return 0
}

_meow_qbt_avisar_sem_aurora() {
  [ "$MEOW_QBT_AVISOU_SEM_AURORA" = "1" ] && return 0
  MEOW_QBT_AVISOU_SEM_AURORA=1
  meow_aviso "sem $MEOW_QBT_AURORA_FONTE não há quem escreva o qBittorrent.conf"
  meow_info  "(este módulo instala o tema e delega o conf ao Aurora — ver cabeçalho)"
  return 0
}

# O Aurora conhece `catppuccin`? Lemos o script VIVO em vez de guardar um
# "já destravei" em disco: assim, no minuto em que a Vitória acrescentar o case,
# este módulo passa a funcionar sozinho — e se ela desfizer, ele volta a travar
# sozinho também. Marcador em arquivo de estado seria a armadilha clássica de
# dizer "OK" sem que nada tenha sido consertado.
#
# Script ausente é NÃO-destravado, e não o contrário: quem não tem o Aurora não
# tem escritor do conf, e a `_meow_qbt_pronto` já barra esse caso antes com um
# 3 explicado. Tratar ausência como "liberado" fazia o módulo instalar o tema,
# não escrever o conf e, na segunda rodada, devolver 0 ("nada a fazer") enquanto
# a `meow_app_conferir` devolvia 1 — dois códigos contraditórios para o mesmo
# estado (reproduzido em sandbox).
_meow_qbt_aurora_destravado() {
  [ -f "$MEOW_QBT_AURORA_FONTE" ] || return 1
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
  # shellcheck disable=SC2016  # o $TEMAS_DIR é LITERAL de propósito: esta linha é
  # para ser copiada e colada dentro do script do Aurora, onde a variável existe.
  printf '       %scatppuccin) TEMA_PATH="$TEMAS_DIR/%s" ;;%s\n' \
         "$C_MAUVE" "$MEOW_QBT_ARQUIVO" "$C_ZERO"
  meow_info  ""
  # shellcheck disable=SC2016  # idem: "uso: $0" é o texto que está no arquivo dela.
  meow_info  "  2) ATUALIZAR o texto de uso na linha ${linha_uso:-<a do 'uso: \$0'>}, de:"
  meow_info  "       [--tema dracula|andromeda|nenhum]"
  meow_info  "     para:"
  printf '       %s[--tema dracula|andromeda|catppuccin|nenhum]%s\n' "$C_MAUVE" "$C_ZERO"
  meow_info  ""
  meow_info  "Edite a FONTE (o caminho acima), não /usr/local/bin: o self-heal roda a fonte"
  meow_info  "e reinstala a cópia. Este módulo não edita esse arquivo — ele está em"
  # shellcheck disable=SC2088  # o til aqui é prosa para ela ler, não caminho a expandir.
  meow_info  "~/.config/zsh, o repo com auto-commit em 10 minutos, e a escrita é recusada."
  return 0
}

# Backup obrigatório antes de sobrescrever qualquer arquivo dela.
_meow_qbt_backup() {
  local alvo="$1" dir base
  [ -e "$alvo" ] || return 0
  base="$(basename "$alvo")"
  # Carimbo ISO com `-` no lugar do `:` — é o formato que os outros módulos já
  # usam em `backups/` (ex.: 2026-08-04T20-14-44). Todos escrevem no MESMO
  # diretório, então o nome tem de ser uniforme para a pasta continuar legível;
  # e dois-pontos em nome de pasta ainda incomoda rsync, tar e a ponte LAN.
  dir="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/${_MEOW_QBT_ISO:-$(date +%Y-%m-%dT%H-%M-%S)}"
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
# núcleo comum das três funções: dá para trabalhar? (0 = sim, 3 = não)
# ─────────────────────────────────────────────────────────────────────────────
# As três funções públicas precisam desta mesma checagem, mas ela NÃO pode ser
# feita chamando `meow_app_detectar` silenciado: o guarda de "imprime a receita
# uma vez só" marcaria como já-avisado no chamado mudo, e a receita nunca
# chegaria à tela. Por isso o núcleo é separado do relato.
_meow_qbt_pronto() {
  _meow_qbt_conf_dir >/dev/null || {
    if meow_tem qbittorrent; then
      _meow_qbt_avisar_nativo
    else
      meow_pula "qBittorrent não instalado"
    fi
    return "$MEOW_SEM_DEPENDENCIA"
  }
  if [ ! -s "$MEOW_QBT_ORIGEM" ]; then
    meow_aviso "falta o tema em $MEOW_QBT_ORIGEM (veja PROCEDENCIA.md para rebaixar)"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # Sem o script do Aurora não há escritor para o conf: dependência faltando (3),
  # nunca um "apliquei" pela metade.
  if [ ! -f "$MEOW_QBT_AURORA_FONTE" ]; then
    _meow_qbt_avisar_sem_aurora
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! _meow_qbt_aurora_destravado; then
    _meow_qbt_receita
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
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
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"
  meow_ok "qBittorrent presente e o Aurora conhece '$MEOW_QBT_NOME_AURORA'"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_conferir — 0 aplicado, 1 divergente, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_conferir() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

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
  #
  # E `-x` junto do `-F`: sem casar a LINHA INTEIRA, um valor que apenas CONTÉM
  # o nosso caminho passaria por bom — `...=/outro/lugar/catppuccin-mocha.qbtheme.bak`
  # ou um prefixo diferente que termine igual. O Aurora usa `grep -qxF` pela
  # mesma razão. O conf real (linha 107 aqui) é exatamente `chave=valor`, sem
  # espaço nem CR, então o `-x` é seguro.
  if [ -f "$conf" ]; then
    grep -qxF "General\\CustomUIThemePath=$destino" "$conf" || {
      meow_muda "CustomUIThemePath não aponta para o nosso tema"
      divergiu=1
    }
    grep -qxF 'General\UseCustomUITheme=true' "$conf" || {
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
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "qBittorrent já está com o Catppuccin Mocha — nada a fazer"
    return "$MEOW_OK"
  }

  # Um carimbo só para toda a aplicação: os arquivos salvos nesta passada têm de
  # cair na MESMA pasta de backup, senão desfazer vira caça ao tesouro.
  _MEOW_QBT_ISO="$(date +%Y-%m-%dT%H-%M-%S)"
  # Sem contador de "mudou" de propósito: quem decide o código de saída no fim é
  # a RECONFERÊNCIA do estado real, não a soma dos passos que tentamos. Ver o
  # comentário do passo 3.
  local conf_dir destino rc
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
    # No seco a `_meow_qbt_instalar_tema` já disse "instalaria" — repetir aqui
    # como "instalado" faria o dry-run mentir que escreveu.
    1) meow_seco || meow_muda "tema instalado em $destino" ;;
    *) meow_erro "não consegui instalar o .qbtheme"; return "$MEOW_ERRO" ;;
  esac

  # --- 2. o estado do Aurora ------------------------------------------------
  # É por este arquivo que o Aurora decide o tema quando ninguém passa --tema.
  # Sem escrevê-lo, o próximo ciclo do self-heal leria `dracula` e reverteria.
  if [ "$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)" != "$MEOW_QBT_NOME_AURORA" ]; then
    if meow_seco; then
      meow_muda "gravaria '$MEOW_QBT_NOME_AURORA' em $MEOW_QBT_AURORA_ESTADO"
    else
      _meow_qbt_backup "$MEOW_QBT_AURORA_ESTADO" || return "$MEOW_ERRO"
      meow_escrever "$MEOW_QBT_AURORA_ESTADO" "$MEOW_QBT_NOME_AURORA" 644
      case $? in
        1) meow_muda "estado do Aurora -> $MEOW_QBT_NOME_AURORA" ;;
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

  # Chegar aqui com o script ausente é impossível: a `_meow_qbt_pronto` já barrou
  # esse caso com 3. Sem essa pré-condição o módulo instalaria o tema e nunca
  # escreveria o conf, terminando em 0 com o app ainda em Dracula.
  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$MEOW_QBT_NOME_AURORA"; then
    meow_erro "o script do Aurora falhou ao aplicar o tema"
    return "$MEOW_ERRO"
  fi

  # --- 4. o veredito sai do ESTADO REAL, não do exit code do Aurora ---------
  # MEDIDO em sandbox: com download em andamento, o Aurora imprime "NÃO vou
  # fechar", ADIA a gravação do conf e sai 0. Deduzir "apliquei" desse 0 fazia
  # `meow_app_aplicar` devolver 1 em toda rodada, para sempre, sem nunca ter
  # escrito o conf — enquanto a `meow_app_conferir` seguia dizendo 1 também.
  # Reconferir custa um `flatpak info` e dois greps, e é o que impede o módulo
  # de mentir. Só chegamos até aqui porque a conferência inicial acusou
  # divergência, então nenhum caminho daqui para baixo pode devolver 0.
  if meow_app_conferir >/dev/null 2>&1; then
    meow_ok "qBittorrent com Catppuccin Mocha aplicado"
    # O aviso do acento sai só quando o tema de fato ficou vivo — repeti-lo a
    # cada ciclo em que o Aurora adiou seria ruído sobre algo que ela ainda nem
    # viu na tela. Honestidade sobre o visual, medido em PROCEDENCIA.md.
    meow_aviso "atenção: o acento deste tema upstream é AZUL (#89b4fa), não o mauve #CBA6F7 da casa"
    return "$MEOW_DIVERGENTE"
  fi
  meow_aviso "o Aurora rodou mas o conf ainda não reflete o tema — ele adia a gravação"
  meow_aviso "quando há download em andamento (fechar o app perderia progresso)."
  meow_aviso "nada se perdeu: o tema já está no disco e o próximo ciclo ocioso aplica."
  return "$MEOW_DIVERGENTE"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter qbittorrent` e o passo 2/6 do `--uninstall`.
#
# QUEM ESCREVE O CONF CONTINUA SENDO O AURORA — inclusive para desfazer.
#   O `aplicar` delega porque o `qBittorrent.conf` é território dele e porque só
#   ele sabe fechar o app sem matar download em andamento. Desfazer pela nossa
#   mão aqui seria abrir uma segunda porta para o mesmo arquivo, justamente no
#   caminho que roda uma vez na vida e ninguém testa de novo.
#
# O DESTINO É `dracula`, E NÃO "SEM TEMA"
#   A allowlist do Aurora é `dracula|andromeda|catppuccin|nenhum`, e `dracula` é
#   o que ele usa quando o estado não diz nada (`TEMA=dracula`, no próprio
#   script). Era o que estava lá antes de nós; é para lá que devolvemos. Pedir
#   `nenhum` deixaria o app cru, que não é o estado anterior — seria uma terceira
#   escolha, tomada por nós, em nome dela.
_MEOW_QBT_TEMA_AURORA_PADRAO="${MEOW_QBT_TEMA_AURORA_PADRAO:-dracula}"

meow_app_reverter() {
  _meow_qbt_pronto || return "$MEOW_SEM_DEPENDENCIA"

  local conf_dir destino estado mudou=0
  conf_dir="$(_meow_qbt_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  destino="$conf_dir/themes/$MEOW_QBT_ARQUIVO"
  estado="$(cat "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null)"

  if [ ! -f "$destino" ] && [ "$estado" != "$MEOW_QBT_NOME_AURORA" ]; then
    meow_ok "qBittorrent já estava sem o Catppuccin"
    return "$MEOW_OK"
  fi

  if meow_seco; then
    [ -f "$destino" ] && meow_muda "removeria $destino"
    [ "$estado" = "$MEOW_QBT_NOME_AURORA" ] && \
      meow_muda "gravaria '$_MEOW_QBT_TEMA_AURORA_PADRAO' em $MEOW_QBT_AURORA_ESTADO"
    meow_muda "rodaria: $MEOW_QBT_AURORA_FONTE --tema $_MEOW_QBT_TEMA_AURORA_PADRAO"
    return "$MEOW_DIVERGENTE"
  fi

  # 1. o estado do Aurora PRIMEIRO. Se a ordem se invertesse e algo falhasse no
  #    meio, o self-heal leria 'catppuccin' no próximo ciclo e reaplicaria tudo
  #    — desfazer que se desfaz sozinho é pior do que não desfazer.
  #    Escrita direta, não `meow_escrever`: este arquivo é do Aurora, e registrá-lo
  #    no manifesto faria o desinstalador apagar o estado dele no passo seguinte.
  if [ "$estado" = "$MEOW_QBT_NOME_AURORA" ]; then
    if printf '%s' "$_MEOW_QBT_TEMA_AURORA_PADRAO" > "$MEOW_QBT_AURORA_ESTADO" 2>/dev/null; then
      mudou=1; meow_muda "estado do Aurora -> $_MEOW_QBT_TEMA_AURORA_PADRAO"
    else
      meow_erro "não consegui gravar $MEOW_QBT_AURORA_ESTADO"
      return "$MEOW_ERRO"
    fi
  fi

  # 2. o conf, pelo dono dele.
  meow_info "delegando o conf ao Aurora (ele é o dono do qBittorrent.conf)"
  if ! bash "$MEOW_QBT_AURORA_FONTE" --tema "$_MEOW_QBT_TEMA_AURORA_PADRAO"; then
    meow_erro "o script do Aurora falhou ao devolver o tema"
    return "$MEOW_ERRO"
  fi

  # 3. só agora o nosso arquivo sai — e só se o conf tiver deixado de apontar
  #    para ele. Remover antes de o Aurora reescrever o conf deixaria o
  #    qBittorrent com CustomUIThemePath para um arquivo inexistente, que é como
  #    se abre um app sem interface.
  if [ -f "$destino" ]; then
    if grep -qxF "General\\CustomUIThemePath=$destino" "$conf_dir/qBittorrent.conf" 2>/dev/null; then
      meow_aviso "o conf ainda aponta para $destino — o Aurora adiou a gravação (download em andamento?)"
      meow_aviso "o .qbtheme fica onde está; rode de novo com o app ocioso"
    elif rm -f "$destino"; then
      mudou=1; meow_muda "tema removido de $destino"
    fi
  fi

  [ "$mudou" = "0" ] && { meow_ok "qBittorrent já estava sem o Catppuccin"; return "$MEOW_OK"; }
  meow_ok "qBittorrent de volta ao tema $_MEOW_QBT_TEMA_AURORA_PADRAO do Aurora"
  meow_info "tire 'qbittorrent' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
