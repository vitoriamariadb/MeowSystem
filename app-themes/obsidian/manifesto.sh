#!/usr/bin/env bash
# app-themes/obsidian/manifesto.sh — Catppuccin Mocha no Obsidian (flatpak).
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO: nada de `exit`, nada de `set -e`.
# O `lib/comum.sh` já veio carregado pelo runner (e ele já fez `set -uo pipefail`,
# então toda variável opcional aqui usa `${VAR:-}`).
#
# O QUE ELE FAZ
#   1. instala <vault>/.obsidian/themes/Catppuccin/{theme.css,manifest.json}
#   2. aponta "cssTheme" para "Catppuccin" em <vault>/.obsidian/appearance.json
#   3. tira do "enabledCssSnippets" qualquer snippet com "dracula" no nome — o
#      dela é o `dracula_background`, que pinta o fundo por cima do tema e faria
#      o Catppuccin parecer quebrado.
#   O appearance.json é MESCLADO por python3/json: as outras chaves dela
#   (baseFontSize, nativeMenus, theme, accentColor...) ficam intactas.
#
# ------------------------------------------------------------------ ARMADILHAS
# Tudo abaixo foi MEDIDO nesta máquina em 2026-08-04, não deduzido.
#
# (1) `pgrep -f obsidian` ACUSA O PRÓPRIO SHELL QUE RODA O MÓDULO.
#     Medido: o `pgrep -f obsidian` do teste devolveu, além do app, o PID do zsh
#     cuja linha de comando apenas CITAVA a palavra "obsidian". Um módulo escrito
#     com o padrão ingênuo devolveria 3 ("app aberto") PARA SEMPRE, mesmo com o
#     Obsidian fechado — e nunca aplicaria nada. Por isso o padrão é ANCORADO:
#         ^/app/obsidian( |$)
#     que é a linha de comando real do flatpak (`exec zypak-wrapper /app/obsidian`
#     no `/app/bin/obsidian.sh`). Com o app aberto casou 6 processos, todos com
#     comm=obsidian; sem o app, casa zero. E não casa a si mesmo.
#
# (2) NÃO DÁ PARA USAR `pgrep -x obsidian`.
#     O comm dos processos do flatpak é mesmo "obsidian" (7 chars, escapa do
#     truncamento em 15 do /proc/PID/comm), mas o `~/.local/bin/obsidian` — que é
#     o obsidian-cli, um ELF completamente diferente do app — teria o MESMO comm.
#     A âncora na linha de comando distingue os dois; o `-x` não.
#
# (3) O OBSIDIAN REESCREVE O appearance.json SOZINHO.
#     Medido: só de ABRIR o app o mtime do appearance.json mudou. Ele é dono do
#     arquivo enquanto roda, e regrava ao sair — o que apagaria nossa escrita.
#     Por isso `meow_app_aplicar` recusa (devolve 3, com aviso) se achar o app
#     vivo. `meow_app_conferir` continua respondendo, porque LER é inofensivo.
#
#     MAS o guarda só vale para ESCRITA, e por isso ele vem DEPOIS do
#     levantamento do que está divergente — não antes. Na primeira versão a
#     ordem era a inversa, e o resultado (medido com o app aberto e o tema já
#     aplicado) era `conferir -> 0` e `aplicar -> 3`: o install.sh listava o
#     obsidian em "pulado", com três avisos de "feche o app", a cada hora do
#     self-heal, enquanto NÃO havia nada a fazer. Nada a fazer é 0, sempre.
#
# (3b) A TRAVA 1 DO comum.sh NÃO ALCANÇA QUEM NÃO USA `meow_escrever`.
#     O appearance.json é gravado pelo python (merge), não pela `meow_escrever`,
#     então ele passava ao largo de `meow_destino_permitido`. Provado num vault
#     de teste cujo caminho continha "com.system76.CosmicSettings.Shortcuts": os
#     arquivos do tema foram recusados pela trava, e o appearance.json foi
#     escrito assim mesmo. Quem escreve chama a trava — é a mesma regra que o
#     módulo do qBittorrent segue na cópia binária dele.
#
# (4) O `meow_escrever` TIRA O \n FINAL, e a conferência tem de tirar também.
#     Ele monta o conteúdo com `$(cat ...)` e grava com `printf '%s'`; substituição
#     de comando come as quebras de linha do fim. Medido: o theme.css instalado
#     fica com 2306520 bytes contra 2306521 do arquivo de origem. Se a conferência
#     usasse `cmp`, acusaria divergência eterna e o módulo reescreveria 2,3 MB a
#     cada ciclo. Por isso comparamos com a MESMA semântica de `$(cat ...)` que o
#     escritor usa — é a consistência entre escritor e conferente que garante a
#     idempotência, não o byte a byte com a origem.
#
# (5) MOCHA JÁ É O PADRÃO — não precisa de plugin nem de classe extra.
#     O flavor do tema sai de uma CLASSE no body (`.theme-dark.ctp-mocha`), e o
#     `default: ctp-mocha` mora num bloco de config do plugin Style Settings.
#     Isso levantou a dúvida: sem o plugin, o tema ficaria sem paleta? Não —
#     medido na linha 1547 do theme.css o seletor é `.theme-dark, .theme-dark
#     .ctp-mocha`, ou seja, o Mocha é o FALLBACK do modo escuro puro. E lá o
#     `--ctp-mauve: 203, 166, 247` é exatamente o #CBA6F7 do MeowSystem.
#     Nos dois caminhos ela cai no Mocha: o `"theme": "obsidian"` do vault já é
#     modo escuro, e o `obsidian-style-settings` está instalado e ativo.
#     Por isso NÃO mexemos na chave "theme" nem forçamos classe nenhuma.
#
# (6) O ACENTO DE FÁBRICA DO TEMA É LAVENDER, NÃO MAUVE — e isso ficou assim.
#     Medido: o tema define `--ctp-accent: var(--ctp-lavender)` (#B4BEFE), então
#     bordas de citação, marcador de lista e afins saem lavanda, e não no mauve
#     #CBA6F7 que é a assinatura do MeowSystem. A paleta mauve ESTÁ lá e correta
#     (`--ctp-mauve: 203, 166, 247`), só não é o acento.
#     Não mexemos: alinhar o acento exigiria um snippet novo em
#     `enabledCssSnippets` — justo o array que este módulo está LIMPANDO — e isso
#     está fora do que foi pedido. Se um dia ela quiser, é uma regra só:
#         .theme-dark { --ctp-accent: var(--ctp-mauve); }
#     num snippet próprio, habilitado por ela. Fica registrado como decisão, não
#     como esquecimento.
#
# (7) O VAULT É UM LINK PARA /mnt/Apate.
#     `~/Controle de Bordo` -> `/mnt/Apate/Controle de Bordo` (mesmo disco do
#     repo). Isso não muda nada aqui porque `meow_escrever` já cria o temporário
#     DENTRO do diretório de destino — o mv é atômico em qualquer um dos casos —
#     mas registra-se para ninguém "otimizar" para um `cp` de fora depois.
#
# ---------------------------------------------------------------------- ORIGEM
# Tema de terceiros, commit PINADO (detalhes em vendor/ORIGEM.md):
#   https://github.com/catppuccin/obsidian  ·  MIT
#   commit a498ec094a8e619e78bbaad93fb89cecd938f6c4  (2026-08-03)
#   manifest 0.4.47, minAppVersion 1.13.0 — e o Obsidian dela é 1.13.4.
# Os arquivos são VENDORADOS em vendor/: aplicar não depende de rede, e o que
# entra no vault é sempre o mesmo byte que foi revisado.

MEOW_OBSIDIAN_APP_ID="md.obsidian.Obsidian"
MEOW_OBSIDIAN_TEMA="Catppuccin"
# O vault é configurável, mas o padrão é o dela.
MEOW_OBSIDIAN_VAULT="${MEOW_OBSIDIAN_VAULT:-$HOME/Controle de Bordo}"
# Ver armadilha (1): o padrão precisa ser ancorado, ou casa o próprio shell.
MEOW_OBSIDIAN_PADRAO_PROC='^/app/obsidian( |$)'

# Raiz do módulo — resolvida a partir deste arquivo, que é `source`.
MEOW_OBSIDIAN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEOW_OBSIDIAN_VENDOR="$MEOW_OBSIDIAN_DIR/vendor/$MEOW_OBSIDIAN_TEMA"

# --- utilitários internos ---------------------------------------------------

# O app está aberto? Ver armadilhas (1) e (2).
_meow_obsidian_rodando() {
  pgrep -f "$MEOW_OBSIDIAN_PADRAO_PROC" >/dev/null 2>&1
}

_meow_obsidian_appearance() { printf '%s/.obsidian/appearance.json' "$MEOW_OBSIDIAN_VAULT"; }
_meow_obsidian_tema_dir()   { printf '%s/.obsidian/themes/%s' "$MEOW_OBSIDIAN_VAULT" "$MEOW_OBSIDIAN_TEMA"; }

# Compara com a MESMA semântica do meow_escrever — ver armadilha (4).
# 0 = igual, 1 = diferente/ausente.
_meow_obsidian_igual() {
  local origem="$1" destino="$2"
  [ -f "$destino" ] || return 1
  [ "$(cat "$origem" 2>/dev/null)" = "$(cat "$destino" 2>/dev/null)" ]
}

# Backup antes de sobrescrever QUALQUER arquivo que já era dela.
# Um diretório por execução, para dar para desfazer tudo junto.
_meow_obsidian_backup() {
  local arquivo="$1" rotulo="$2" destino
  [ -f "$arquivo" ] || return 0
  meow_seco && return 0
  # ISO sem ':' — é o formato que os outros módulos do MeowSystem já usam nesta
  # mesma pasta de backups (visto em backups/2026-08-04T20-14-44 do módulo Qt).
  : "${MEOW_OBSIDIAN_BACKUP_DIR:=${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/backups/$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  mkdir -p "$destino" || return 1
  cp -p -- "$arquivo" "$destino/$rotulo" || return 1
  return 0
}

# O leitor/mesclador do appearance.json. Fica aqui dentro para o módulo ser um
# arquivo só. Modos: "conferir" (não escreve) e "aplicar".
# Códigos: 0 = já está certo · 1 = divergente (ou mesclado) · 2 = erro.
_meow_obsidian_json() {
  local modo="$1" arquivo="$2" tema="$3"
  MEOW_PY_SECO="$(meow_seco && echo 1 || echo 0)" \
  python3 - "$modo" "$arquivo" "$tema" <<'PYFIM'
import json, os, sys, tempfile

modo, caminho, tema = sys.argv[1], sys.argv[2], sys.argv[3]
seco = os.environ.get("MEOW_PY_SECO") == "1"

existia = os.path.exists(caminho)
if existia:
    try:
        with open(caminho, encoding="utf-8") as f:
            texto = f.read()
        dados = json.loads(texto) if texto.strip() else {}
    except (OSError, ValueError) as e:
        sys.stderr.write("appearance.json ilegível (%s)\n" % e)
        sys.exit(2)
    if not isinstance(dados, dict):
        sys.stderr.write("appearance.json não é um objeto JSON\n")
        sys.exit(2)
else:
    dados = {}

# Assinatura do ANTES: se nada mudar, não se escreve nada (regra 5).
antes = json.dumps(dados, sort_keys=True)
motivos = []

if dados.get("cssTheme") != tema:
    motivos.append("cssTheme=%r -> %r" % (dados.get("cssTheme"), tema))
    dados["cssTheme"] = tema

# O snippet "dracula_background" pinta o fundo por cima e faria o Catppuccin
# parecer quebrado. Só mexemos no ARRAY: o .css dela continua no disco, então
# reverter é só remarcar o snippet na interface.
snippets = dados.get("enabledCssSnippets")
if isinstance(snippets, list):
    limpos = [s for s in snippets
              if not (isinstance(s, str) and "dracula" in s.lower())]
    if limpos != snippets:
        removidos = [s for s in snippets if s not in limpos]
        motivos.append("snippets removidos: %s" % ", ".join(map(str, removidos)))
        dados["enabledCssSnippets"] = limpos

if not existia:
    motivos.append("appearance.json não existia")

if json.dumps(dados, sort_keys=True) == antes and existia:
    sys.exit(0)

for m in motivos:
    sys.stderr.write("  %s\n" % m)

if modo == "conferir" or seco:
    sys.exit(1)

# O Obsidian grava com indentação de 2 e SEM \n final (medido no arquivo dela);
# e, como é JS, não escapa acento. Imitamos para não gerar ruído de diff.
saida = json.dumps(dados, indent=2, ensure_ascii=False)
pasta = os.path.dirname(caminho) or "."
try:
    os.makedirs(pasta, exist_ok=True)
    # Temporário no MESMO diretório do destino: o os.replace só é atômico
    # dentro do mesmo sistema de arquivos.
    fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow-appearance.")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(saida)
    os.chmod(tmp, 0o644)
    os.replace(tmp, caminho)
except OSError as e:
    sys.stderr.write("falhou ao gravar appearance.json (%s)\n" % e)
    try:
        os.unlink(tmp)
    except (OSError, NameError):
        pass
    sys.exit(2)
sys.exit(1)
PYFIM
}

# --- 1. detectar ------------------------------------------------------------
# Nunca falha: 0 = tem, 3 = não tem. App ausente não é erro.
meow_app_detectar() {
  if ! meow_tem flatpak; then
    meow_pula "obsidian: flatpak não está instalado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # python3 faz o merge do appearance.json e pgrep é o guarda do app aberto.
  # Sem eles não há como trabalhar — e isso é dependência faltando (3), não erro
  # (2). Medido num PATH mínimo sem python3: antes desta checagem o `detectar`
  # dizia 0 e o `aplicar` morria com 2, o que joga o obsidian em "falhou" no
  # install.sh por causa de uma dependência ausente. Pior no caso do pgrep: sem
  # ele o guarda do app aberto falharia PARA ABERTO — escreveria com o Obsidian
  # vivo, e o app desfaria tudo ao sair.
  # (python3 PRESENTE mas quebrado continua sendo 2: aí é erro de verdade.)
  local falta
  for falta in python3 pgrep; do
    if ! meow_tem "$falta"; then
      meow_pula "obsidian: falta '$falta' (sem ele não dá para aplicar com segurança)"
      return "$MEOW_SEM_DEPENDENCIA"
    fi
  done
  # O teste por DIRETÓRIO cobre usuário, sistema e ~/.var/app — e não cria um
  # repositório ostree inteiro só por perguntar, que é o que `flatpak info`
  # fazia num HOME sem flatpak nenhum (medido em 10/08/2026). Detecção com
  # efeito colateral faz o MEOW_DRY_RUN=1 mentir.
  if ! meow_flatpak_tem "$MEOW_OBSIDIAN_APP_ID"; then
    meow_pula "obsidian: $MEOW_OBSIDIAN_APP_ID não instalado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  # Sem vault não há o que tematizar — também não é erro.
  if [ ! -d "$MEOW_OBSIDIAN_VAULT/.obsidian" ]; then
    meow_pula "obsidian: vault '$MEOW_OBSIDIAN_VAULT' não encontrado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if [ ! -f "$MEOW_OBSIDIAN_VENDOR/theme.css" ] || [ ! -f "$MEOW_OBSIDIAN_VENDOR/manifest.json" ]; then
    meow_erro "obsidian: falta o tema vendorado em $MEOW_OBSIDIAN_VENDOR"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  return "$MEOW_OK"
}

# --- 2. conferir ------------------------------------------------------------
# 0 = já aplicado · 1 = divergente · 3 = app ausente.
# Ler é inofensivo mesmo com o app aberto, então aqui não se recusa nada.
meow_app_conferir() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  local tema_dir divergente=0
  tema_dir="$(_meow_obsidian_tema_dir)"

  _meow_obsidian_igual "$MEOW_OBSIDIAN_VENDOR/theme.css" "$tema_dir/theme.css" \
    || { meow_muda "obsidian: theme.css ausente ou diferente"; divergente=1; }
  _meow_obsidian_igual "$MEOW_OBSIDIAN_VENDOR/manifest.json" "$tema_dir/manifest.json" \
    || { meow_muda "obsidian: manifest.json ausente ou diferente"; divergente=1; }

  _meow_obsidian_json conferir "$(_meow_obsidian_appearance)" "$MEOW_OBSIDIAN_TEMA"
  case $? in
    0) ;;
    1) meow_muda "obsidian: appearance.json divergente"; divergente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_DIVERGENTE" ;;
  esac

  if [ "$divergente" = "0" ]; then
    meow_ok "obsidian: Catppuccin Mocha já aplicado"
    return "$MEOW_OK"
  fi
  # Aviso útil: divergente + app aberto = o aplicar vai recusar.
  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: está ABERTO — feche-o para o MeowSystem poder aplicar"
  fi
  return "$MEOW_DIVERGENTE"
}

# --- 3. aplicar -------------------------------------------------------------
# 0 = nada a fazer · 1 = aplicou · 2 = erro · 3 = app ausente (ou aberto).
meow_app_aplicar() {
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"

  local tema_dir appearance mudou=0 rc
  tema_dir="$(_meow_obsidian_tema_dir)"
  appearance="$(_meow_obsidian_appearance)"

  # --- 3.0 — LEVANTAR o que falta, ANTES de qualquer guarda ou escrita.
  # Duas coisas dependem desta ordem (ver armadilha 3):
  #   · "nada a fazer" é 0, mesmo com o Obsidian aberto. Recusar antes de olhar
  #     devolvia 3 ("pulado") a cada ciclo com o tema já aplicado;
  #   · o backup e a pasta de backup só nascem quando existe escrita para
  #     desfazer — medido: três rodadas no-op deixavam três pastas em backups/,
  #     e o self-heal roda de hora em hora.
  local -a pendentes=()
  local arquivo
  for arquivo in theme.css manifest.json; do
    _meow_obsidian_igual "$MEOW_OBSIDIAN_VENDOR/$arquivo" "$tema_dir/$arquivo" \
      || pendentes+=("$arquivo")
  done

  local json_pendente=0
  _meow_obsidian_json conferir "$appearance" "$MEOW_OBSIDIAN_TEMA" 2>/dev/null
  rc=$?
  case $rc in
    0) ;;                   # já está como queremos: nem backup, nem escrita
    1) json_pendente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_ERRO" ;;
  esac

  if [ "${#pendentes[@]}" -eq 0 ] && [ "$json_pendente" = "0" ]; then
    meow_ok "obsidian: Catppuccin Mocha já estava aplicado"
    return "$MEOW_OK"
  fi

  # --- 3.0b — só agora o guarda do app aberto. Armadilha (3): com o app vivo,
  # ele regrava o appearance.json ao sair e apagaria o que fizermos. Recusar é o
  # certo — e recusa NÃO é erro.
  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e desfaria a troca."
    meow_aviso "obsidian: feche o Obsidian e rode de novo."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # --- 3.0c — TRAVA 1 no caminho que NÃO passa pela `meow_escrever`.
  # O appearance.json é gravado pelo python; sem esta linha ele escreveria em
  # território proibido se `MEOW_OBSIDIAN_VAULT` apontasse para lá (ver 3b).
  meow_destino_permitido "$appearance" || return "$MEOW_ERRO"

  # Zerado a cada execução para o backup ser um diretório só por rodada.
  unset MEOW_OBSIDIAN_BACKUP_DIR

  # --- 3.1 — os dois arquivos do tema.
  for arquivo in "${pendentes[@]}"; do
    # Só faz backup se JÁ existia algo ali (um Catppuccin antigo, por exemplo).
    if ! _meow_obsidian_backup "$tema_dir/$arquivo" "$arquivo"; then
      meow_erro "obsidian: não consegui fazer backup de $arquivo"
      return "$MEOW_ERRO"
    fi
    meow_escrever "$tema_dir/$arquivo" "$(cat "$MEOW_OBSIDIAN_VENDOR/$arquivo")" 644
    rc=$?
    case $rc in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao instalar $arquivo"; return "$MEOW_ERRO" ;;
    esac
  done

  # --- 3.2 — o appearance.json, por MERGE (as chaves dela ficam).
  if [ "$json_pendente" = "1" ]; then
    _meow_obsidian_backup "$appearance" "appearance.json" || {
      meow_erro "obsidian: não consegui fazer backup do appearance.json"
      return "$MEOW_ERRO"
    }
    _meow_obsidian_json aplicar "$appearance" "$MEOW_OBSIDIAN_TEMA"
    case $? in
      0) ;;
      1) mudou=1 ;;
      *) meow_erro "obsidian: falhou ao mesclar o appearance.json"; return "$MEOW_ERRO" ;;
    esac
  fi

  if [ "$mudou" = "0" ]; then
    meow_ok "obsidian: Catppuccin Mocha já estava aplicado"
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "obsidian: (seco) aplicaria o Catppuccin Mocha no vault"
    return "$MEOW_DIVERGENTE"
  fi

  if [ -n "${MEOW_OBSIDIAN_BACKUP_DIR:-}" ] && [ -d "${MEOW_OBSIDIAN_BACKUP_DIR:-}/obsidian" ]; then
    meow_info "obsidian: backup do que existia em $MEOW_OBSIDIAN_BACKUP_DIR/obsidian"
  fi
  meow_ok "obsidian: Catppuccin Mocha aplicado — reabra o app para ver"
  meow_registrar "obsidian: cssTheme=$MEOW_OBSIDIAN_TEMA em $MEOW_OBSIDIAN_VAULT"
  return "$MEOW_DIVERGENTE"
}

# --- DESFAZER (11/08/2026) --------------------------------------------------
# Chegam aqui `meow apps reverter obsidian` e o passo 2/6 do `--uninstall`.
#
# A MESMA RECUSA DO `aplicar`, PELO MESMO MOTIVO
#   Com o Obsidian aberto, ele regrava o `appearance.json` ao sair e desfaria o
#   nosso desfazer — o tema voltaria sozinho e pareceria que o comando mentiu.
#   Recusar é a resposta certa, e recusa não é erro (3, "pendente").
#
# `cssTheme=""` É O PADRÃO DO OBSIDIAN, não um valor inventado: é o que o app
# grava quando ela escolhe o tema base na interface.
#
# O QUE NÃO VOLTA: o snippet `dracula_background` que o `aplicar` desmarcou. O
# `.css` dele nunca saiu do disco (ver `_meow_obsidian_json`) — remarcar é um
# clique na interface, e adivinhar por ela seria repor uma escolha que não é
# nossa. A mensagem diz onde está.
meow_app_reverter() {
  meow_app_detectar || {
    meow_pula "Obsidian não instalado (ou o vault não está onde eu procuro)"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  local tema_dir appearance mudou=0 arquivo rc
  tema_dir="$(_meow_obsidian_tema_dir)"
  appearance="$(_meow_obsidian_appearance)"

  # Levantar ANTES de recusar por app aberto: com nada a fazer, "já estava
  # desfeito" é 0 mesmo com o Obsidian na tela.
  local -a nossos=()
  for arquivo in theme.css manifest.json; do
    _meow_obsidian_igual "$MEOW_OBSIDIAN_VENDOR/$arquivo" "$tema_dir/$arquivo" \
      && nossos+=("$arquivo")
  done
  local json_pendente=0
  _meow_obsidian_json conferir "$appearance" "" >/dev/null 2>&1
  case $? in
    0) ;;
    1) json_pendente=1 ;;
    *) meow_erro "obsidian: não consegui ler o appearance.json"; return "$MEOW_ERRO" ;;
  esac

  if [ "${#nossos[@]}" -eq 0 ] && [ "$json_pendente" = "0" ]; then
    meow_ok "obsidian: já estava sem o Catppuccin"
    return "$MEOW_OK"
  fi

  if _meow_obsidian_rodando; then
    meow_aviso "obsidian: o app está ABERTO — nada foi escrito."
    meow_aviso "obsidian: ele regrava o appearance.json ao sair e traria o tema de volta."
    meow_aviso "obsidian: feche o Obsidian e rode de novo."
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$appearance" || return "$MEOW_ERRO"

  if meow_seco; then
    [ "${#nossos[@]}" -gt 0 ] && meow_muda "obsidian: removeria ${nossos[*]} de $tema_dir"
    [ "$json_pendente" = "1" ] && meow_muda "obsidian: cssTheme voltaria ao padrão do app"
    return "$MEOW_DIVERGENTE"
  fi

  # 1. os dois arquivos do tema — só saem os que ainda são byte a byte os nossos.
  #    Um `theme.css` que ela editou deixou de ser nosso e fica.
  for arquivo in ${nossos[@]+"${nossos[@]}"}; do
    if rm -f "$tema_dir/$arquivo"; then mudou=1; else
      meow_erro "obsidian: não consegui remover $tema_dir/$arquivo"; return "$MEOW_ERRO"
    fi
  done
  # `rmdir` sem `-p` e sem `-f`: some se ficou vazio, fica se ela pôs algo lá.
  [ -d "$tema_dir" ] && rmdir "$tema_dir" 2>/dev/null
  [ "$mudou" = "1" ] && meow_muda "obsidian: tema $MEOW_OBSIDIAN_TEMA removido do vault"

  # 2. o appearance.json, pelo mesmo varredor que o aplicou. O python grava
  #    direto (não passa por `meow_escrever`), então nada disto entra no
  #    manifesto — que é o que impede o desinstalador de apagar o arquivo depois.
  if [ "$json_pendente" = "1" ]; then
    _meow_obsidian_json aplicar "$appearance" ""
    rc=$?
    case $rc in
      0|1) mudou=1; meow_muda "obsidian: cssTheme de volta ao padrão do app" ;;
      *) meow_erro "obsidian: falhou ao devolver o appearance.json"; return "$MEOW_ERRO" ;;
    esac
  fi

  [ "$mudou" = "0" ] && { meow_ok "obsidian: já estava sem o Catppuccin"; return "$MEOW_OK"; }
  meow_ok "obsidian: sem o Catppuccin — reabra o app para ver"
  meow_info "o snippet 'dracula_background' continua no disco, desmarcado: Aparência > Snippets CSS"
  meow_info "tire 'obsidian' de APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica"
  return "$MEOW_DIVERGENTE"
}
