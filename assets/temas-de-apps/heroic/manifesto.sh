#!/usr/bin/env bash
# assets/temas-de-apps/heroic/manifesto.sh — Catppuccin dentro do Heroic Games Launcher.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Sem `exit`, sem `set -e`.
#
# POR QUE ELE EXISTE
#   Pedido dela em 08/09/2026: *"temos alguma seção eu imagino que instale temas
#   dentro dos apps como spotify, qbtorrent e afins pro heroic games, adiciona
#   isso aqui também: https://github.com/catppuccin/heroic"*. O lugar na tela é
#   "Lançadores e jogos", que é onde o Heroic já aparece.
#
# ─────────────────────────────────────────────────────────────────────────────
# O QUE O HEROIC CHAMA DE TEMA, LIDO NO CÓDIGO-FONTE
# ─────────────────────────────────────────────────────────────────────────────
#   Um tema do Heroic é um ARQUIVO CSS solto numa pasta, e nada mais. Duas
#   chaves o ligam, e elas moram em arquivos DIFERENTES:
#
#     customThemesPath   a pasta onde procurar. Vive em `AppSettings`
#                        (`src/common/types.ts`), e o backend a grava em
#                        `<config>/heroic/config.json`, dentro de
#                        `defaultSettings`.
#     theme              o tema escolhido. Vive no `configStore` do FRONT
#                        (`src/frontend/state/GlobalState.tsx`:
#                        `configStore.get('theme', 'midnightMirage')`), que o
#                        `electronStores.ts` aponta para `cwd: 'store'` — ou
#                        seja, `<config>/heroic/store/config.json`, na RAIZ do
#                        objeto, e não dentro de `settings`.
#
#   O valor de `theme` é o nome do arquivo sem o `.css`, e é também o seletor
#   que o CSS usa: `catppuccin-mocha-mauve.css` abre com
#   `body.catppuccin-mocha-mauve { … }`. Escrever um nome que não tem arquivo
#   deixa o Heroic com o tema de fábrica e nenhum aviso.
#
# ─────────────────────────────────────────────────────────────────────────────
# ONDE A PASTA DE TEMAS PODE FICAR — E POR QUE NÃO EM ~/.local/share
# ─────────────────────────────────────────────────────────────────────────────
#   MEDIDO, com `flatpak info --show-permissions com.heroicgameslauncher.hgl`:
#   a lista de `filesystems` traz `~/.steam`, `~/Games/Heroic:create`, `/mnt`,
#   `~/.local/share/applications`, `~/.local/share/lutris` — e NÃO traz
#   `~/.local/share/meowsystem`. Instalar os temas no nosso diretório de dados
#   daria uma pasta que existe, com os 56 arquivos certos dentro, e que o Heroic
#   não enxerga: a lista de temas dele abriria vazia, sem erro nenhum.
#
#   Então a pasta é a DELE: `<config>/heroic/themes`. E o caminho absoluto é o
#   mesmo dos dois lados da caixa — medido rodando dentro do sandbox:
#       $ flatpak run --command=sh com.heroicgameslauncher.hgl -c 'echo $XDG_CONFIG_HOME'
#       /home/vitoriamaria/.var/app/com.heroicgameslauncher.hgl/config
#   É por isso que gravar o caminho do HOST na chave funciona.
#
# ─────────────────────────────────────────────────────────────────────────────
# A ARMADILHA: O HEROIC REESCREVE OS DOIS ARQUIVOS AO SAIR
# ─────────────────────────────────────────────────────────────────────────────
#   Os dois são estado vivo de um Electron aberto. Escrever com o app rodando é
#   escrever num arquivo que vai ser sobrescrito pela memória dele no fechamento
#   — e o módulo diria "aplicado" com a tela mostrando o tema antigo. Por isso
#   `_heroic_rodando` recusa antes de tocar em qualquer coisa, com o código de
#   dependência ausente: não é erro, é "agora não".
#
#   Pela mesma razão nada aqui é escrito por regex no texto cru do JSON. Quem lê
#   e escreve é o `python3`, com `json`, preservando a indentação de cada
#   arquivo — o `store/config.json` usa TAB e o `config.json` usa dois espaços,
#   conferido com `cat -A`. Um `sed` numa chave que não existe ainda não
#   acrescenta nada, e num arquivo de 60 chaves a diferença não aparece.
#
# O ACERVO
#   56 CSS (4 flavors x 14 accents) de https://github.com/catppuccin/heroic,
#   MIT, pinados no commit do arquivo `upstream/COMMIT` e conferidos pelo
#   `SHA256SUMS`. São 240 KB de texto: vão para o git, ao contrário dos cursores
#   e dos papéis de parede, porque texto pequeno versionado é o que permite
#   instalar sem rede.

_HEROIC_APPID="com.heroicgameslauncher.hgl"
_HEROIC_FLAVOR="${FLAVOR:-mocha}"
_HEROIC_ACENTO="${ACCENT:-mauve}"
_HEROIC_ORIGEM="$RAIZ/assets/temas-de-apps/heroic/upstream/themes"

# O nome do tema é o nome do arquivo. Se a combinação de flavor e accent dela
# não existir no acervo (accent novo do Catppuccin, por exemplo), o módulo cai
# no par de fábrica do projeto em vez de gravar um nome sem arquivo.
_heroic_tema() {
  local nome="catppuccin-${_HEROIC_FLAVOR}-${_HEROIC_ACENTO}"
  [ -f "$_HEROIC_ORIGEM/$nome.css" ] || nome="catppuccin-mocha-mauve"
  printf '%s' "$nome"
}

# A raiz de configuração: flatpak primeiro, porque é como ela tem.
_heroic_conf_dir() {
  local f="$HOME/.var/app/$_HEROIC_APPID/config/heroic"
  [ -d "$f" ] && { printf '%s' "$f"; return 0; }
  [ -d "$HOME/.config/heroic" ] && { printf '%s' "$HOME/.config/heroic"; return 0; }
  return 1
}

_heroic_presente() {
  meow_flatpak_tem "$_HEROIC_APPID" && return 0
  meow_tem heroic && return 0
  return 1
}

# `flatpak ps`, E NUNCA `pgrep -f` — 08/09/2026, medido no primeiro teste.
#   `pgrep -f com.heroicgameslauncher.hgl` casou com o PRÓPRIO comando que
#   estava perguntando: a linha de comando do shell que roda o módulo contém o
#   id do app, e o `-f` compara a linha inteira. O módulo se recusou a aplicar
#   dizendo "o Heroic está aberto" numa máquina com o Heroic fechado — e teria
#   feito isso para sempre, calado, porque a recusa é um "pendente" e não um
#   erro. `flatpak ps` responde pelo id exato, uma linha por app rodando.
_heroic_rodando() {
  if meow_tem flatpak; then
    flatpak ps --columns=application 2>/dev/null | grep -qx -- "$_HEROIC_APPID" && return 0
  fi
  pgrep -x heroic >/dev/null 2>&1 && return 0
  return 1
}

# Devolve o JSON inteiro, já com a chave posta. Sem escrever nada: quem escreve
# é a `meow_escrever`, que compara por conteúdo e não toca no arquivo à toa.
_heroic_json_com() {
  local arquivo="$1" caminho="$2" valor="$3" recuo="$4"
  python3 - "$arquivo" "$caminho" "$valor" "$recuo" <<'PY'
import json, sys, io
arquivo, caminho, valor, recuo = sys.argv[1:5]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except FileNotFoundError:
    d = {}
except ValueError:
    sys.exit(2)          # JSON quebrado: quem conserta é ela, não nós
if not isinstance(d, dict):
    sys.exit(2)
partes = caminho.split(".")
alvo = d
for p in partes[:-1]:
    if not isinstance(alvo.get(p), dict):
        alvo[p] = {}
    alvo = alvo[p]
if valor == "":
    alvo.pop(partes[-1], None)
else:
    alvo[partes[-1]] = valor
sys.stdout.write(json.dumps(d, indent=("\t" if recuo == "tab" else 2), ensure_ascii=False))
PY
}

# Regra 4: antes de sobrescrever, sempre. Mesmo carimbo e mesmo formato dos
# outros módulos — a pasta `backups/` é compartilhada, e um carimbo com dois
# pontos ordenaria antes de todos os com hífen (ver o helper 3 do módulo do VS
# Code, que documenta a medição).
_heroic_backup() {
  local origem="$1" carimbo destino rel
  [ -f "$origem" ] || return 0
  carimbo="${MEOW_CARIMBO:-$(date +%Y-%m-%dT%H-%M-%S)}"
  destino="$MEOW_ESTADO/backups/$carimbo"
  case "$origem" in
    "$HOME"/*) rel="${origem#"$HOME"/}" ;;
    *)         rel="fora-da-home/${origem#/}" ;;
  esac
  mkdir -p "$destino/$(dirname "$rel")" || return 1
  cp -p -- "$origem" "$destino/$rel" || return 1
  ( cd "$destino" && sha256sum -- "$rel" >> manifesto.sha256 ) || return 1
  printf '%s\n' "$origem" >> "$destino/origens.txt" || return 1
  meow_info "backup: $destino/$rel"
  return 0
}

_heroic_json_le() {
  local arquivo="$1" caminho="$2"
  python3 - "$arquivo" "$caminho" <<'PY'
import json, sys, io
arquivo, caminho = sys.argv[1:3]
try:
    with io.open(arquivo, encoding="utf-8") as f:
        d = json.load(f)
except Exception:
    sys.exit(1)
for p in caminho.split("."):
    if not isinstance(d, dict) or p not in d:
        sys.exit(1)
    d = d[p]
sys.stdout.write(d if isinstance(d, str) else json.dumps(d))
PY
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_detectar — 0 presente, 3 ausente.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_detectar() {
  _heroic_presente || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic instalado, mas ainda não abriu uma vez — sem pasta de configuração"
    return "$MEOW_SEM_DEPENDENCIA"
  }
  meow_ok "Heroic presente, configuração em $dir"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_conferir — 0 aplicado, 1 divergente, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_conferir() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir tema pasta divergiu=0 falta=0 f
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  # COMPARA COMO A `meow_escrever` ESCREVE, E NÃO COM `cmp` — 08/09/2026.
  #   `cmp` acusou 56 de 56 diferentes num diretório com os 56 arquivos certos.
  #   A causa é a regra 5 do contrato: `meow_escrever` grava com `printf '%s'`,
  #   sem a quebra de linha final, e compara por conteúdo do mesmo jeito. Os
  #   arquivos do upstream TÊM a quebra final. Byte a byte eles diferem sempre;
  #   pela régua que os escreveu, são iguais — e é essa a régua que vale, senão
  #   o módulo reescreve os 56 a cada passagem e nunca diz "conforme".
  for f in "$_HEROIC_ORIGEM"/*.css; do
    [ "$(cat "$f")" = "$(cat "$pasta/$(basename "$f")" 2>/dev/null)" ] || falta=$((falta + 1))
  done
  [ "$falta" = "0" ] || { meow_muda "$falta dos 56 temas não estão em $pasta"; divergiu=1; }

  [ "$(_heroic_json_le "$dir/config.json" defaultSettings.customThemesPath)" = "$pasta" ] \
    || { meow_muda "customThemesPath não aponta para $pasta"; divergiu=1; }
  [ "$(_heroic_json_le "$dir/store/config.json" theme)" = "$tema" ] \
    || { meow_muda "o tema escolhido não é $tema"; divergiu=1; }

  if [ "$divergiu" = "0" ]; then
    meow_ok "Heroic com $tema aplicado"
    return "$MEOW_OK"
  fi
  return "$MEOW_DIVERGENTE"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_aplicar — 0 nada a fazer, 1 aplicou, 2 erro, 3 ausente/travado.
# ─────────────────────────────────────────────────────────────────────────────
meow_app_aplicar() {
  _heroic_presente || { meow_pula "Heroic não está instalado"; return "$MEOW_SEM_DEPENDENCIA"; }
  local dir tema pasta mudou=0 rc f
  dir="$(_heroic_conf_dir)" || {
    meow_pula "Heroic ainda não abriu uma vez — nada para configurar"
    return "$MEOW_SEM_DEPENDENCIA"
  }

  meow_app_conferir >/dev/null 2>&1 && {
    meow_ok "Heroic já está no nosso tema — nada a fazer"
    return "$MEOW_OK"
  }

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — ele reescreve a configuração ao sair; feche e rode de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  tema="$(_heroic_tema)"
  pasta="$dir/themes"

  # 1. os 56 CSS. `meow_escrever` compara por conteúdo: numa máquina já pronta
  #    isto não escreve um byte, que é a regra 5 do contrato.
  for f in "$_HEROIC_ORIGEM"/*.css; do
    meow_escrever "$pasta/$(basename "$f")" "$(cat "$f")"
    rc=$?
    [ "$rc" = "1" ] && mudou=1
    [ "$rc" -ge 2 ] && return "$MEOW_ERRO"
  done

  # 2. a pasta, no arquivo do backend.
  local novo
  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "$pasta" espaco)" \
    || { meow_erro "não consegui ler $dir/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  # 3. o tema escolhido, no arquivo do front.
  novo="$(_heroic_json_com "$dir/store/config.json" theme "$tema" tab)" \
    || { meow_erro "não consegui ler $dir/store/config.json — o JSON está quebrado"; return "$MEOW_ERRO"; }
  meow_escrever "$dir/store/config.json" "$novo"
  rc=$?
  [ "$rc" = "1" ] && mudou=1
  [ "$rc" -ge 2 ] && return "$MEOW_ERRO"

  if [ "$mudou" = "1" ]; then
    meow_ok "Heroic vestido de $tema — a janela mostra na próxima vez que abrir"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "Heroic já está no nosso tema"
  return "$MEOW_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# meow_app_reverter — devolve o tema de fábrica e leva os nossos CSS embora.
# ─────────────────────────────────────────────────────────────────────────────
#   `midnightMirage` é o padrão do Heroic, escrito no próprio código
#   (`ContextProvider.tsx`: `theme: 'midnightMirage'`) — não é um chute nosso.
#   O `customThemesPath` volta a não existir, e não a existir vazio: chave vazia
#   é uma decisão escrita, e aqui a decisão é não ter opinião.
meow_app_reverter() {
  _heroic_presente || return "$MEOW_SEM_DEPENDENCIA"
  local dir pasta mudou=0 rc novo f
  dir="$(_heroic_conf_dir)" || return "$MEOW_SEM_DEPENDENCIA"
  pasta="$dir/themes"

  if _heroic_rodando; then
    meow_pula "o Heroic está aberto — feche e rode de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_seco || { _heroic_backup "$dir/config.json"; _heroic_backup "$dir/store/config.json"; }
  novo="$(_heroic_json_com "$dir/store/config.json" theme midnightMirage tab)" || return "$MEOW_ERRO"
  meow_escrever "$dir/store/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1
  novo="$(_heroic_json_com "$dir/config.json" defaultSettings.customThemesPath "" espaco)" || return "$MEOW_ERRO"
  meow_escrever "$dir/config.json" "$novo"; rc=$?
  [ "$rc" = "1" ] && mudou=1

  # Só os NOSSOS arquivos saem, e um a um pelo nome do acervo: a pasta pode ter
  # um tema que ela mesma pôs lá, e apagar a pasta inteira levaria o dela junto.
  if ! meow_seco; then
    for f in "$_HEROIC_ORIGEM"/*.css; do
      [ -f "$pasta/$(basename "$f")" ] || continue
      rm -f -- "$pasta/$(basename "$f")" && mudou=1
    done
    rmdir "$pasta" 2>/dev/null || true
  fi

  [ "$mudou" = "1" ] && { meow_ok "Heroic de volta ao midnightMirage"; return "$MEOW_DIVERGENTE"; }
  meow_ok "Heroic já estava de fábrica"
  return "$MEOW_OK"
}
