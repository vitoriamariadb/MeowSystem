#!/usr/bin/env bash
# construir_icones.sh — monta o tema MeowSystem-Icons e a logo do painel.
#
# Sem sudo, sem `/usr/share`, sem envolver o Ritual da Aurora. Isso foi MEDIDO
# (docs/COSMIC-THEMING.md §2): o laço externo da resolução de ícone do COSMIC é
# o NOME DO TEMA, não o diretório-base.
#
# Um teste anterior concluiu o contrário porque plantou o ícone no `hicolor` do
# usuário: aquilo perdeu por estar no FIM DA CADEIA DE HERANÇA, não por ser do
# usuário.
#
#   - O botão do dock/menu vem do TEMA DE ÍCONES, pelo nome
#     `com.system76.CosmicPanelAppButton` / `com.system76.CosmicAppLibrary`.
#   - A logo do painel NÃO passa por tema de ícones: o applet LogoMenu guarda um
#     CAMINHO DE ARQUIVO em `custom_logo_path`. Por isso ela é tratada à parte.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# O `meow_tema_base_escondida` mora lá.
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
COSMIC="$(meow_cosmic_dir)"
LOGOS_DIR="$COSMIC/logos"
TK="$COSMIC/com.system76.CosmicTk/$(meow_cosmic_v com.system76.CosmicTk)"
# (o diretório do applet LogoMenu não é mais tocado aqui — ver o bloco 3)

# Os dois nomes que o COSMIC pede para o botão de aplicativos. São dois porque o
# painel e o dock evoluíram separados e cada um pede o seu.
BOTOES=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)

# Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
# Era `${FLAVOR:-mocha}`, o padrão de um pack só.
FLAVOR="$(meow_flavor)"
LOGO="${LOGO:-$FLAVOR}"
ICONES_BASE="${ICONES_BASE:-Papirus-Dark}"
# A base que o PACK traz mora aqui, ao lado do tema que a herda.
TEMA_BASE="$TEMA_NOME-Base"
BASE_DIR="$HOME/.local/share/icons/$TEMA_BASE"
# O que o `Inherits=` escreve. Começa como sempre foi, e a `_ci_base` o troca
# pela base do pack quando ela vale e está no disco.
HERDA="$ICONES_BASE"
# As camadas que ficam ATRÁS da base: `,<nome>` por camada que está no disco,
# na ordem do `icones.base.por_tras` do pack. Moram em `$TEMA_BASE-2`, `-3`…,
# ao lado da frente, com a mesma régua dela.
HERDA_ATRAS=""
# O `Comment=` do índice é o do PACK NO AR, no flavor da máquina. Era
# `Catppuccin $FLAVOR para o COSMIC` com qualquer pack — o Dracula instalado
# se descrevia como Catppuccin.
COMENTARIO_TEMA="$(python3 "$RAIZ/scripts/pack.py" tema-icones "$(meow_pack_dir)" "$FLAVOR" 2>/dev/null \
                     | sed -n 's/^comentario=//p')"
[ -n "$COMENTARIO_TEMA" ] || COMENTARIO_TEMA="MeowSystem $FLAVOR para o COSMIC"

# `adicionar <pasta-ou-zip>` e `remover <nome>` — um acervo de ícones de fora
#
# A aba de ícones do painel oferece a chave `ICONES_BASE` — o tema que o nosso
# herda —, e a lista dela sai do disco: todo diretório de
# `~/.local/share/icons`, `~/.icons` e `/usr/share/icons` que tenha um
# `index.theme` com `Directories=` e sem `Hidden=true`.
#
# Tema é o que tem `index.theme` com `Directories=` não-vazio: sem isso, um tema
# de cursor entraria na lista. `$TEMA_NOME`, `hicolor` e `default` são recusados
# (o tema daqui, a reserva do freedesktop e o ponteiro do compositor).
#
# O argumento é de fora: sem `eval`, citado, o zip abre num temporário e o
# diretório é o `basename` peneirado, nunca o caminho de dentro do pacote.
_ci_nome_seguro() {
  local n="$1"
  n="${n//[^A-Za-z0-9._-]/-}"
  n="${n#"${n%%[!.-]*}"}"
  printf '%s' "${n:0:80}"
}

_ci_nome_recusado() {
  case "$1" in
    "$TEMA_NOME") meow_erro "'$1' é o tema que este script constrói — recusado"; return 0 ;;
    "$TEMA_BASE"|"$TEMA_BASE"-[0-9]*) meow_erro "'$1' é a base que o pack traz, e quem a põe e a tira é o 'construir_icones.sh base' — recusado"; return 0 ;;
    hicolor)      meow_erro "'hicolor' é a hierarquia de reserva do sistema, não um tema — recusado"; return 0 ;;
    default)      meow_erro "'default' é o tema de ponteiro do compositor — recusado"; return 0 ;;
  esac
  return 1
}

# Um `index.theme` que declara pastas de tamanho: é o que separa tema de ícone de
# tema de cursor. `grep -q` sem regex complicada — a linha é `Directories=` com
# pelo menos um caractere depois.
_ci_e_tema_de_icones() {
  [ -f "$1/index.theme" ] && grep -qiE '^[[:space:]]*Directories[[:space:]]*=[[:space:]]*[^[:space:]]' "$1/index.theme"
}

# Instala UM diretório de tema. 0 = já idêntico · 1 = instalado · 2 = erro.
#
# A idempotência é por CONTEÚDO (regra 5 do projeto): "já existe uma pasta com
# esse nome" responderia 0 para um tema copiado pela metade, que é justamente o
# estado que a cópia em dois tempos abaixo existe para evitar.
_ci_instalar_tema() {
  local origem="$1" nome destino palco
  nome="$(_ci_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  destino="$HOME/.local/share/icons/$nome"
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq -- "$origem" "$destino" >/dev/null 2>&1; then
        meow_ok "o tema de ícones '$nome' já está instalado e idêntico"
        return "$MEOW_OK"
      fi
      meow_info "'$nome' está no disco e difere do pacote — substituindo"
    else
      meow_ok "o tema de ícones '$nome' já está instalado (sem 'diff' para comparar)"
      return "$MEOW_OK"
    fi
  fi

  if meow_seco; then
    meow_muda "instalaria o tema de ícones '$nome' em $HOME/.local/share/icons"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$HOME/.local/share/icons" || return "$MEOW_ERRO"
  # O palco nasce DENTRO do diretório de destino: `mv` entre sistemas de arquivos
  # não é atômico (TRAVA 2 do lib/comum.sh), e um tema de ícones tem milhares de
  # arquivos — tempo de sobra para um corte no meio.
  palco="$(mktemp -d -p "$HOME/.local/share/icons" ".meow-tema.XXXXXX")" || return "$MEOW_ERRO"
  if ! cp -a -- "$origem/." "$palco/"; then
    rm -rf "$palco"; meow_erro "não consegui copiar o tema '$nome'"; return "$MEOW_ERRO"
  fi
  chmod 755 "$palco"
  meow_guardar_pasta "$destino"
  rm -rf "$destino"
  if ! mv -f "$palco" "$destino"; then
    rm -rf "$palco"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi
  # O manifesto é o que permite ao `--uninstall` saber o que é nosso.
  meow_manifesto_registrar "$destino/index.theme"
  meow_muda "tema de ícones '$nome' instalado em $destino"
  return "$MEOW_DIVERGENTE"
}

_ci_colher_temas() {
  find "$1" -maxdepth 3 -type f -name index.theme -print0 2>/dev/null
}

_ci_adicionar() {
  local alvo="${1:-}" rc="$MEOW_OK" achou=0 e d
  if [ -z "$alvo" ]; then
    meow_erro "uso: construir_icones.sh adicionar <pasta-ou-zip>"
    return "$MEOW_ERRO"
  fi

  # ── uma pasta já aberta ───────────────────────────────────────────────────
  if [ -d "$alvo" ]; then
    if _ci_e_tema_de_icones "$alvo"; then
      _ci_instalar_tema "$alvo"; return $?
    fi
    while IFS= read -r -d '' d; do
      d="$(dirname -- "$d")"
      _ci_e_tema_de_icones "$d" || continue
      _ci_instalar_tema "$d"; e=$?
      [ "$e" -ge 2 ] && return "$e"
      [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
      achou=1
    done < <(_ci_colher_temas "$alvo")
    [ "$achou" = "1" ] || {
      meow_erro "'$alvo' não tem um index.theme com 'Directories=' — não é tema de ícones"
      meow_info "  um ícone avulso entra pelo «Adicionar ícone» da ficha de ícone"
      return "$MEOW_ERRO"; }
    meow_registrar "construir_icones.sh adicionar '$alvo'"
    return "$rc"
  fi

  [ -f "$alvo" ] || { meow_erro "não achei '$alvo'"; return "$MEOW_ERRO"; }
  case "$alvo" in
    *.zip|*.ZIP) : ;;
    *) meow_erro "só sei abrir .zip aqui (ou uma pasta de tema já aberta)"
       return "$MEOW_ERRO" ;;
  esac

  # No seco não se extrai: extrair é escrever, e `MEOW_DRY_RUN=1` promete não
  # escrever NADA — o `tests/seco.sh` roda num HOME de brinquedo justamente para
  # pegar quem escreve "só num temporário". O nome vira palpite, e diz-se que é.
  if meow_seco; then
    local palpite; palpite="$(_ci_nome_seguro "$(basename -- "${alvo%.*}")")"
    if [ -n "$palpite" ] && [ -d "$HOME/.local/share/icons/$palpite" ]; then
      meow_ok "o tema de ícones '$palpite' já está instalado"
      return "$MEOW_OK"
    fi
    meow_muda "instalaria um tema de ícones de '$alvo' em $HOME/.local/share/icons"
    meow_info "  no seco o nome é palpite pelo arquivo; quem decide é o conteúdo do pacote"
    return "$MEOW_DIVERGENTE"
  fi

  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }
  local tmp
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-tema-add.XXXXXX")" || return "$MEOW_ERRO"
  if ! unzip -q -o -- "$alvo" -d "$tmp/x" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi
  while IFS= read -r -d '' d; do
    d="$(dirname -- "$d")"
    _ci_e_tema_de_icones "$d" || continue
    _ci_instalar_tema "$d"; e=$?
    if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
    [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
    achou=1
  done < <(_ci_colher_temas "$tmp/x")
  rm -rf "$tmp"

  if [ "$achou" = "0" ]; then
    meow_erro "o pacote não tem um index.theme com 'Directories=' — não é tema de ícones"
    meow_info "  um ícone avulso entra pelo «Adicionar ícone» da ficha de ícone"
    return "$MEOW_ERRO"
  fi
  meow_registrar "construir_icones.sh adicionar '$alvo'"
  return "$rc"
}

# O desfazer do `adicionar`.
_ci_remover() {
  local nome; nome="$(_ci_nome_seguro "${1:-}")"
  [ -n "$nome" ] || { meow_erro "uso: construir_icones.sh remover <nome>"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  local dir="$HOME/.local/share/icons/$nome"
  if [ ! -d "$dir" ]; then
    meow_pula "'$nome' não está em $HOME/.local/share/icons — nada a remover"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$dir" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "removeria $dir"; return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$dir" || { meow_erro "não consegui remover $dir"; return "$MEOW_ERRO"; }
  meow_muda "tema de ícones '$nome' removido de $HOME/.local/share/icons"
  [ "$nome" = "$ICONES_BASE" ] && \
    meow_aviso "esse era o ICONES_BASE — troque a chave antes do próximo 'meow aplicar'"
  meow_registrar "construir_icones.sh remover $nome"
  return "$MEOW_DIVERGENTE"
}

# A BASE QUE O PACK TRAZ
#
# A regra — o `ICONES_BASE` escrito à mão vence, o de fábrica cede ao pack, sem
# base na cadeia vale o de fábrica — mora no `base_que_vale` do
# `scripts/pack.py`, uma vez, e este script lê a resposta.

# Os alvos de link que caem FORA do diretório, um por linha. `realpath` de
# todos de uma vez, e não um por link: o ramo circle tem 12.456 links, e um
# `realpath` por link levaria segundos a cada instalação.
_ci_links_fora() {
  local dir; dir="$(realpath -m -- "$1")"
  find "$dir" -type l -print0 2>/dev/null | xargs -0 -r realpath -m -- 2>/dev/null \
    | grep -v -e "^$dir/" -e "^$dir\$" || true
}

# A que já conferia, instalada antes desta data, não tem o `Hidden=true`: ele
# entra aqui, e o manifesto dela é refeito na mesma linha (ver o
# `meow_tema_base_escondida`, no lib/icones.sh).
_ci_base_esconder() {
  if awk '/^\[/{sec=$0} sec=="[Icon Theme]" && $0=="Hidden=true"{achou=1} END{exit !achou}' \
       "$BASE_DIR/index.theme" 2>/dev/null; then
    return "$MEOW_OK"
  fi
  if meow_seco; then
    meow_muda "esconderia dos seletores a base em $BASE_DIR (Hidden=true)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_tema_base_escondida "$BASE_DIR"
  case $? in
    0) return "$MEOW_OK" ;;
    1) meow_muda "a base em $BASE_DIR saiu dos seletores de tema (Hidden=true)"
       return "$MEOW_DIVERGENTE" ;;
    *) meow_erro "não consegui esconder a base em $BASE_DIR"; return "$MEOW_ERRO" ;;
  esac
}

# 0 = a base instalada é a do pino e está inteira.
_ci_base_confere() {
  local links
  [ -f "$BASE_DIR/.meow-origem" ] && grep -qx "sha256=$1" "$BASE_DIR/.meow-origem" || return 1
  links="$(sed -n 's/^links=//p' "$BASE_DIR/.meow-origem")"
  [ "$(find "$BASE_DIR" -type l 2>/dev/null | wc -l)" = "${links:-x}" ] || return 1
  ( cd "$BASE_DIR" && sha256sum --status -c .meow-somas.sha256 ) 2>/dev/null
}

# Tira a base quando o pack no ar não a usa. SÓ A NOSSA: o `.meow-origem` é
# escrito por quem instala, e um diretório com este nome sem ele é de outra
# pessoa — que não se apaga em nome de limpeza.
_ci_base_tirar() {
  [ -d "$BASE_DIR" ] || return "$MEOW_OK"
  if [ ! -f "$BASE_DIR/.meow-origem" ]; then
    meow_aviso "$BASE_DIR existe e não foi este script que o pôs lá — fica como está"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$BASE_DIR" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "removeria $BASE_DIR ($1)"
    return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$BASE_DIR" || { meow_erro "não consegui remover $BASE_DIR"; return "$MEOW_ERRO"; }
  meow_muda "a base de ícones saiu de $BASE_DIR ($1)"
  return "$MEOW_DIVERGENTE"
}

# 1 = instalada · 2 = erro (sha256, pacote, pasta, link) · 3 = sem rede ou sem ferramenta
_ci_base_baixar() {
  local url="$1" sha="$2" pasta="$3" pack="$4" palco src obtido fora f
  meow_destino_permitido "$BASE_DIR" || return "$MEOW_ERRO"
  # A mesma régua do `_ci_base_tirar`: sem o `.meow-origem`, o diretório com
  # este nome é de outra pessoa, e escrever por cima dele é apagá-lo.
  if [ -d "$BASE_DIR" ] && [ ! -f "$BASE_DIR/.meow-origem" ]; then
    meow_aviso "$BASE_DIR existe e não foi este script que o pôs lá — não escrevo por cima"
    meow_info "  tire-o ou renomeie-o, e a base do pack $pack desce na passagem seguinte"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  for f in curl tar sha256sum realpath; do
    meow_tem "$f" || {
      meow_aviso "falta '$f' — a base de ícones do pack $pack fica para o próximo ciclo"
      return "$MEOW_SEM_DEPENDENCIA"; }
  done
  mkdir -p "$HOME/.local/share/icons" || return "$MEOW_ERRO"
  palco="$(mktemp -d -p "$HOME/.local/share/icons" ".meow-base.XXXXXX")" || return "$MEOW_ERRO"
  meow_info "baixando a base de ícones do pack $pack…"
  # `--proto =https` nos dois sentidos, como no `instalar_fontes.sh`: o
  # `pack.py` só deixa passar URL em https, e um redirecionamento para http
  # seria a mesma porta por trás.
  if ! curl -sSfL --proto '=https' --proto-redir '=https' --connect-timeout 15 \
       --max-time 600 --retry 3 --retry-delay 2 -o "$palco/pacote" "$url" 2>/dev/null; then
    rm -rf "$palco"
    meow_aviso "não consegui baixar a base de ícones do pack $pack (sem rede?) — fica para o próximo ciclo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if ! echo "$sha  $palco/pacote" | sha256sum --status -c - 2>/dev/null; then
    obtido="$(sha256sum "$palco/pacote" | cut -d' ' -f1)"
    rm -rf "$palco"
    meow_erro "sha256 da base de ícones não bate com o que o pack $pack pinou"
    meow_info "  esperado $sha"
    meow_info "  obtido   $obtido"
    return "$MEOW_ERRO"
  fi
  mkdir "$palco/x" || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  if ! tar -xf "$palco/pacote" -C "$palco/x" 2>/dev/null; then
    rm -rf "$palco"; meow_erro "o pacote da base de ícones veio corrompido — nada instalado"
    return "$MEOW_ERRO"
  fi
  src="$palco/x/$pasta"
  # O `pack.py` valida o texto da `pasta` (sem `..`, sem barra na frente), mas
  # quem a usa é o disco: um pacote pinado por um pack importado pode trazer a
  # pasta, ou um diretório do caminho dela, como LINK para fora do palco — e aí
  # o `.meow-origem` e o manifesto abaixo seriam escritos dentro do alvo do
  # link, e o `mv` poria o link no lugar da base.
  # Por isso nenhum componente do caminho pode ser link, e o `realpath` dele tem de
  # cair dentro do que o `tar` abriu.
  local dentro resolvido parcial comp
  dentro="$(realpath -e -- "$palco/x")"
  resolvido="$(realpath -e -- "$src" 2>/dev/null)" || resolvido=""
  parcial="$palco/x"
  for comp in ${pasta//\// }; do
    parcial="$parcial/$comp"
    if [ -L "$parcial" ]; then resolvido=""; break; fi
  done
  case "$resolvido" in
    "$dentro"/*) : ;;
    *) rm -rf "$palco"
       meow_erro "a pasta '$pasta' do pacote da base do pack $pack é link, ou sai do pacote — nada instalado"
       return "$MEOW_ERRO" ;;
  esac
  if ! _ci_e_tema_de_icones "$src"; then
    rm -rf "$palco"
    meow_erro "o pacote não tem '$pasta' com um index.theme de tema de ícones — nada instalado"
    meow_info "  é o 'icones.base.origem.pasta' do pack $pack que diz onde o tema está"
    return "$MEOW_ERRO"
  fi
  fora="$(_ci_links_fora "$src")"
  if [ -n "$fora" ]; then
    rm -rf "$palco"
    meow_erro "a base do pack $pack tem link apontando para fora do tema — nada instalado"
    meow_info "  $(printf '%s\n' "$fora" | head -1)"
    return "$MEOW_ERRO"
  fi
  # Escondida dos seletores ANTES do manifesto: o `index.theme` com o
  # `Hidden=true` é o que ele mede.
  meow_tema_base_escondida "$src" >/dev/null
  [ "$?" -le 1 ] || { rm -rf "$palco"; meow_erro "não consegui esconder a base de ícones"; return "$MEOW_ERRO"; }
  # O manifesto nasce do que acabou de ser conferido, e fora do tema: um
  # arquivo escrito lá dentro durante o `find` entraria na própria lista.
  if ! ( cd "$src" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 -r sha256sum ) > "$palco/somas"; then
    rm -rf "$palco"; meow_erro "não consegui medir a base de ícones"; return "$MEOW_ERRO"
  fi
  mv -f "$palco/somas" "$src/.meow-somas.sha256" || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  printf 'sha256=%s\nurl=%s\nlinks=%s\n' "$sha" "$url" "$(find "$src" -type l | wc -l)" > "$src/.meow-origem" \
    || { rm -rf "$palco"; return "$MEOW_ERRO"; }
  chmod 755 "$src"
  # O `rm -rf` vinha antes do `mv`, e um `mv` que falhasse deixava o índice de
  # antes apontando para uma base apagada, com a construção dizendo que o tema
  # "fica como estava".
  if [ -e "$BASE_DIR" ] || [ -L "$BASE_DIR" ]; then
    mv -f "$BASE_DIR" "$palco/antes" || {
      rm -rf "$palco"; meow_erro "não consegui tirar do lugar a base de antes, em $BASE_DIR"
      return "$MEOW_ERRO"; }
  fi
  if ! mv -f "$src" "$BASE_DIR"; then
    if [ -e "$palco/antes" ] || [ -L "$palco/antes" ]; then mv -f "$palco/antes" "$BASE_DIR"; fi
    rm -rf "$palco"; meow_erro "falha ao mover a base de ícones para $BASE_DIR"; return "$MEOW_ERRO"
  fi
  rm -rf "$palco"
  # Medido pela revisão: a desinstalação tira este index.theme e deixa 12.514
  # arquivos e 12.456 links (54 MB), que nem são mais um tema.
  meow_manifesto_registrar "$BASE_DIR/index.theme"
  meow_muda "base de ícones do pack $pack instalada em $BASE_DIR"
  return "$MEOW_DIVERGENTE"
}

# A base do Dracula é o `circle` do m4thewz; o `Dracula-Icones` de antes
# herdava o `circle` e, ATRÁS dele, o `main`, e é do `main` que vinham 458
# nomes `*-symbolic` que a cadeia nova perdeu (medido contra o backup
# congelado).

# Tira as camadas `$TEMA_BASE-<n>` com n >= $1 (as que o pack no ar não usa).
_ci_base_tirar_atras() {
  local desde="$1" porque="$2" d n rc pior="$MEOW_OK" BASE_DIR
  for d in "$HOME/.local/share/icons/$TEMA_BASE"-[0-9]*; do
    [ -d "$d" ] || continue
    n="${d##*-}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    [ "$n" -ge "$desde" ] || continue
    BASE_DIR="$d"
    _ci_base_tirar "$porque"; rc=$?
    [ "$rc" -gt "$pior" ] && pior="$rc"
  done
  return "$pior"
}

# Põe ou confere cada camada de trás, das linhas `atras=` do verbo (em $1), e
# escreve o `HERDA_ATRAS`. 0 = nada mudou · 1 = mudou · 2 = erro
_ci_base_camadas() {
  local linhas="$1" pack="$2" url sha pasta n=1 rc pior="$MEOW_OK" BASE_DIR
  HERDA_ATRAS=""
  while IFS=$'\t' read -r url sha pasta; do
    [ -n "$url" ] || continue
    n=$((n + 1))
    BASE_DIR="$HOME/.local/share/icons/$TEMA_BASE-$n"
    if _ci_base_confere "$sha"; then
      HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"
      _ci_base_esconder; rc=$?
      [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
      [ "$rc" -gt "$pior" ] && pior="$rc"
      continue
    fi
    if meow_seco; then
      meow_muda "baixaria a camada $n da base de ícones do pack $pack e a instalaria em $BASE_DIR"
      HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"; pior="$MEOW_DIVERGENTE"
      continue
    fi
    _ci_base_baixar "$url" "$sha" "$pasta" "$pack"; rc=$?
    case "$rc" in
      1) HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"; pior="$MEOW_DIVERGENTE" ;;
      3) # Sem rede: a camada de antes, se houver, segue valendo, como na frente.
         if [ -f "$BASE_DIR/.meow-origem" ] && _ci_e_tema_de_icones "$BASE_DIR"; then
           HERDA_ATRAS="$HERDA_ATRAS,$TEMA_BASE-$n"
         fi ;;
      *) return "$MEOW_ERRO" ;;
    esac
  done < <(printf '%s\n' "$linhas" | sed -n 's/^atras=//p')
  _ci_base_tirar_atras "$((n + 1))" "o pack $pack traz $((n - 1)) camada(s) por trás"; rc=$?
  [ "$rc" -gt "$pior" ] && pior="$rc"
  return "$pior"
}

# Decide o `$HERDA` e põe (ou tira) a base no disco.
# 0 = nada mudou · 1 = mudou, ou mudaria no seco · 2 = erro
_ci_base() {
  local saida quem tema pack url sha pasta rc rc_atras
  HERDA="$ICONES_BASE"
  HERDA_ATRAS=""
  meow_tem python3 || return "$MEOW_OK"
  # `"$(meow_pack_dir)"` vazio é o pack padrão, a mesma porta do `cursor.sh` e
  # do `instalar_fontes.sh`.
  if ! saida="$(ICONES_BASE="$ICONES_BASE" NOME_TEMA_ICONES="$TEMA_NOME" \
                python3 "$RAIZ/scripts/pack.py" base-icones "$(meow_pack_dir)")"; then
    meow_aviso "não deu para ler a base de ícones do pack — o '$TEMA_NOME' herda de '$ICONES_BASE', como antes"
    return "$MEOW_OK"
  fi
  quem="$(printf '%s\n' "$saida" | sed -n 's/^quem=//p')"
  tema="$(printf '%s\n' "$saida" | sed -n 's/^tema=//p')"
  pack="$(printf '%s\n' "$saida" | sed -n 's/^pack=//p')"
  url="$(printf '%s\n' "$saida" | sed -n 's/^url=//p')"
  sha="$(printf '%s\n' "$saida" | sed -n 's/^sha256=//p')"
  pasta="$(printf '%s\n' "$saida" | sed -n 's/^pasta=//p')"

  if [ "$quem" != "pack" ]; then
    HERDA="${tema:-$ICONES_BASE}"
    # QUANDO O CONF VENCE O PACK, A TELA DIZ OS DOIS — é a regra do "Quem
    # vence" do docs/PACKS.md, e é o caso desta máquina: o meow.conf dela diz
    # `ICONES_BASE="Dracula-Icones"`, e o Dracula agora traz a própria base.
    [ "$quem" = "conf" ] && [ -n "$pack" ] && \
      meow_info "o pack $pack traz uma base de ícones; vale o ICONES_BASE=\"$tema\" do meow.conf"
    _ci_base_tirar "o '$TEMA_NOME' herda de '$HERDA'"; rc=$?
    _ci_base_tirar_atras 2 "o '$TEMA_NOME' herda de '$HERDA'"; rc_atras=$?
    [ "$rc_atras" -gt "$rc" ] && rc="$rc_atras"
    return "$rc"
  fi

  # As camadas de trás antes da frente: elas não decidem nada da frente, e
  # assim os três retornos de baixo (confere, seco, baixou) levam o delas junto.
  _ci_base_camadas "$saida" "$pack"; rc_atras=$?
  [ "$rc_atras" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"

  if _ci_base_confere "$sha"; then
    meow_ok "a base de ícones do pack $pack está em $BASE_DIR e confere"
    HERDA="$TEMA_BASE"
    _ci_base_esconder; rc=$?
    [ "$rc" = "$MEOW_ERRO" ] && return "$MEOW_ERRO"
    [ "$rc" -gt "$rc_atras" ] && rc_atras="$rc"
    return "$rc_atras"
  fi
  # No seco não se baixa: baixar é gastar a rede dela para ensaiar, e abrir o
  # pacote é escrever. O `Inherits=` do ensaio é o que a execução deixaria.
  if meow_seco; then
    meow_muda "baixaria a base de ícones do pack $pack e a instalaria em $BASE_DIR"
    HERDA="$TEMA_BASE"
    return "$MEOW_DIVERGENTE"
  fi
  _ci_base_baixar "$url" "$sha" "$pasta" "$pack"; rc=$?
  case "$rc" in
    1) HERDA="$TEMA_BASE"; return "$MEOW_DIVERGENTE" ;;
    3) # Sem rede: uma base de antes (de outro pino) continua sendo base, e é
       # melhor que nenhuma; sem nada no disco, o de fábrica segura a cadeia.
       if [ -f "$BASE_DIR/.meow-origem" ] && _ci_e_tema_de_icones "$BASE_DIR"; then
         HERDA="$TEMA_BASE"
         meow_info "  fica a base que já estava em $BASE_DIR"
       else
         meow_info "  até lá o '$TEMA_NOME' herda de '$ICONES_BASE'"
       fi
       return "$rc_atras" ;;
    *) return "$MEOW_ERRO" ;;
  esac
}

_ci_base_cmd() {
  local rc
  _ci_base; rc=$?
  meow_info "o '$TEMA_NOME' herda de '$HERDA$HERDA_ATRAS'"
  return "$rc"
}

# O RESTO DA CADEIA, DEPOIS DA BASE. Uma constante, porque são dois a escrever
# a linha `Inherits=`: a construção e o `indice` (que a relê do disco).
CAUDA_HERANCA="breeze-dark,Cosmic,Adwaita,hicolor"

# O DEFEITO, MEDIDO numa casa de brinquedo com o Dracula: uma passada das etapas
# de ícone deixava o `Directories=` sem `48x48/apps`, `scalable/mimetypes` e os
# dois `status`.
#
# A CURA é uma etapa única, a última que escreve no tema: esta.
_ci_indice_cmd() {
  local rc=0 cache="$TEMA_DIR/icon-theme.cache" herda
  if [ ! -f "$TEMA_DIR/index.theme" ]; then
    meow_pula "o tema '$TEMA_NOME' ainda não tem índice — quem o escreve primeiro é a construção"
    return "$MEOW_OK"
  fi
  herda="$(sed -n 's/^Inherits=//p' "$TEMA_DIR/index.theme" | head -1)"
  HERDA="${herda%",$CAUDA_HERANCA"}"; HERDA_ATRAS=""
  [ -n "$HERDA" ] || HERDA="$ICONES_BASE"
  meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
  case $? in
    1) rc="$MEOW_DIVERGENTE" ;;
    2) meow_erro "não consegui escrever o index.theme"; return "$MEOW_ERRO" ;;
  esac
  if [ -f "$cache" ] && [ -n "$(find "$TEMA_DIR" -newer "$cache" -print -quit 2>/dev/null)" ]; then
    if meow_seco; then
      meow_muda "reindexaria a cache do tema (ela é mais velha que algum arquivo dele)"
      rc="$MEOW_DIVERGENTE"
    elif meow_tem gtk-update-icon-cache && gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
      rc="$MEOW_DIVERGENTE"
    else
      meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
    fi
  fi
  [ "$rc" = "$MEOW_OK" ] && meow_ok "índice do '$TEMA_NOME' descreve o disco"
  [ "$rc" = "$MEOW_DIVERGENTE" ] && ! meow_seco && meow_muda "índice do '$TEMA_NOME' refeito do disco"
  return "$rc"
}

case "${1:-}" in
  "")        : ;;
  adicionar) _ci_adicionar "${2:-}"; exit $? ;;
  remover)   _ci_remover   "${2:-}"; exit $? ;;
  base)      _ci_base_cmd;           exit $? ;;
  indice)    : ;;   # despachado depois do `indice()`, que ele usa
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: construir_icones.sh [adicionar <pasta-ou-zip> | remover <nome> | base | indice]"
    meow_info "  sem argumento, ele constrói o tema '$TEMA_NOME'"
    exit "$MEOW_ERRO" ;;
esac

# Os `<tam>/places` que existem DE FATO dentro do tema, um por linha. O glob do
# bash já devolve ordenado, então a lista é estável entre execuções — requisito
# para o `meow_escrever` conseguir comparar por conteúdo.
#
# `scalable` ENTROU, e não é simetria gratuita com o `status` `scalable/places`
# é onde o `icones_pastas.sh` põe as pastas especiais em Catppuccin.
places_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/places; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/places}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

# `scalable/mimetypes` é o pack Catppuccin vestindo TIPO DE ARQUIVO, posto lá
# pelo `icones_mimetypes.sh`. Vale a mesma regra do §1: declarar só o que
# EXISTE.
tem_mimetypes() { [ -d "$TEMA_DIR/scalable/mimetypes" ]; }

# `512x512/apps` é o acervo Catppuccin de APLICATIVO (PNG com alpha, posto pelo
# icones_apps.sh).
tem_apps_png() { [ -d "$TEMA_DIR/512x512/apps" ]; }

# Os `<tam>/apps` que existem no disco, do MENOR para o maior — e a razão de
# existirem é o serrilhado.
#
# Ela viu na tela: "cheio de serrilhados".
#
# Derivado do disco, como todo o resto deste arquivo: assim um tamanho novo em
# `TAMANHOS_DERIVADOS` aparece aqui sozinho, e um que saia deixa de ser
# declarado sem ninguém editar duas listas.
apps_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/apps; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/apps}")"
    case "$tam" in
      512x512|scalable) continue ;;          # esses dois têm bloco próprio
      [0-9]*x[0-9]*) printf '%s\n' "$tam" ;;
    esac
  done | sort -t x -k1,1n
}

# `48x48/apps` é o Arcticons vestindo APLICATIVO, posto lá pelo
# `icones_apps_arcticons.sh`. Mesma regra dos outros: declarar só o que EXISTE.
#
# `scalable/apps` já tem TRÊS donos (`completar_icones.sh`, `logo.sh` e o
# bootstrap logo abaixo).
tem_apps_traco() { [ -d "$TEMA_DIR/48x48/apps" ]; }

# `<tam>/status` é o Arcticons vestindo os ícones do PRÓPRIO COSMIC, posto lá
# pelo `icones_sistema.sh`. Mesma regra dos outros: declarar só o que EXISTE.
status_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/status; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/status}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

indice() {
  local dirs="" tam
  # Ordem crescente, derivada do disco.
  while IFS= read -r tam; do [ -n "$tam" ] && dirs="$dirs$tam/apps,"; done < <(apps_no_disco)
  tem_apps_png && dirs="${dirs}512x512/apps,"
  dirs="${dirs}scalable/apps"
  tem_mimetypes && dirs="$dirs,scalable/mimetypes"
  while IFS= read -r tam; do dirs="$dirs,$tam/status"; done < <(status_no_disco)
  while IFS= read -r tam; do dirs="$dirs,$tam/places"; done < <(places_no_disco)

  cat <<FIM
[Icon Theme]
Name=$TEMA_NOME
Comment=$COMENTARIO_TEMA
Inherits=$HERDA$HERDA_ATRAS,$CAUDA_HERANCA
Directories=$dirs

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=8
MaxSize=512
FIM

  while IFS= read -r tam; do
    [ -n "$tam" ] || continue
    cat <<FIM

[$tam/apps]
Size=${tam%%x*}
Context=Applications
Type=Fixed
FIM
  done < <(apps_no_disco)

  if tem_apps_png; then
    cat <<'FIM'

[512x512/apps]
Size=512
Context=Applications
Type=Fixed
FIM
  fi

  # (o bloco de `48x48/apps` sai do laço genérico acima, junto com 64, 128 e
  # 256.

  if tem_mimetypes; then
    cat <<'FIM'

[scalable/mimetypes]
Size=64
Context=MimeTypes
Type=Scalable
MinSize=8
MaxSize=512
FIM
  fi

  while IFS= read -r tam; do
    if [ "$tam" = scalable ]; then
      cat <<FIM

[scalable/status]
Size=48
Context=Status
Type=Scalable
MinSize=8
MaxSize=512
FIM
    else
      cat <<FIM

[$tam/status]
Size=${tam%%x*}
Context=Status
Type=Fixed
FIM
    fi
  done < <(status_no_disco)

  while IFS= read -r tam; do
    if [ "$tam" = scalable ]; then
      cat <<FIM

[scalable/places]
Size=48
Context=Places
Type=Scalable
MinSize=8
MaxSize=512
FIM
    else
      cat <<FIM

[$tam/places]
Size=${tam%%x*}
Context=Places
Type=Fixed
FIM
    fi
  done < <(places_no_disco)
}

# O `indice` usa o `indice()` e as funções de disco logo acima, e por isso é
# despachado aqui, e não no `case` do topo.
if [ "${1:-}" = "indice" ]; then
  _ci_indice_cmd
  exit $?
fi

mudou=0

# --- 0. a base que o nosso tema herda ---------------------
# ANTES do índice, porque é ela que decide o `Inherits=`.
_ci_base
case $? in
  1) mudou=1 ;;
  2) meow_erro "a base de ícones do pack não entrou — o tema '$TEMA_NOME' fica como estava"
     exit "$MEOW_ERRO" ;;
esac

# --- 1. o índice do tema ----------------------------------------------------
# `Directories=` é a ÚNICA chave de tamanho que a crate do COSMIC lê; Type,
# MinSize e MaxSize são texto morto para ela (medido). Ficam por educação, para
# outros toolkits que leiam o mesmo tema.
#
# Cada um desfazia o outro, e os DOIS devolviam 1 ("estava divergente,
# consertei") em TODA rodada — seis rodadas seguidas em teste, sem nunca
# convergir.
meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
case $? in 1) mudou=1 ;; 2) meow_erro "não consegui escrever o index.theme"; exit "$MEOW_ERRO" ;; esac

# --- 2. o gato do botão -----------------------------------------------------
#
# Ela mandou excluir os gatos do projeto e ficar só com a Coquinha e o Mimir,
# então o gerador e os SVG foram embora — e com eles o único caminho que este
# script conhecia.
#
# Acervo vazio não é erro daqui: quem sabe dizer isso é o `logo.sh`, que já
# avisa "solte um .svg lá e ele entra".
GATO_PISO=""
if [ -d "$RAIZ/assets/gatos" ]; then
  GATO_PISO="$(find "$RAIZ/assets/gatos" -maxdepth 1 -name '*.svg' \
                 ! -name '*-symbolic.svg' | sort | head -n1)"
fi
# Este laço escrevia o gato do dock a partir de um caminho FIXO
# (`assets/meow-${FLAVOR}-painel.svg`), em toda rodada.
#
# Agora quem veste o botão é o `scripts/logo.sh`, que é o dono do acervo e de
# quem está no ar.
if [ -n "$GATO_PISO" ]; then
  for nome in "${BOTOES[@]}"; do
    [ -f "$TEMA_DIR/scalable/apps/$nome.svg" ] && continue
    meow_escrever "$TEMA_DIR/scalable/apps/$nome.svg" "$(cat "$GATO_PISO")" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar $nome"; exit "$MEOW_ERRO" ;; esac
  done
fi

# --- 3. a logo do painel (caminho de arquivo, não tema) ---------------------
#
# Ficaram DOIS DONOS DA MESMA LINHA, o modo de falha que este projeto persegue
# desde o começo: girei para `mimir`, rodei o `install.sh`, e a etapa de ícones
# (que roda ANTES da de logo) devolveu tudo para `meow-mocha.svg`.
#
# O que havia aqui era o "piso" — garantir que `~/.config/cosmic/logos/
# meow-<flavor>.svg` existisse, copiado do gato gerado do flavor.
#
# Agora o diretório tem dono único, e é o `logo.sh`.

# --- 4. selecionar o tema ---------------------------------------------------
# Sem isto nada acima aparece: o tema só entra na busca se for O SELECIONADO.
#
# A troca do NOME do tema é o único evento que obriga a reiniciar o painel (ver
# o bloco 5).
tema_mudou_de_nome=0
[ "$(cat "$TK/icon_theme" 2>/dev/null)" = "\"$TEMA_NOME\"" ] || tema_mudou_de_nome=1
meow_escrever "$TK/icon_theme" "\"$TEMA_NOME\"" 644
case $? in 1) mudou=1 ;; esac

if [ "$mudou" = "0" ]; then
  meow_ok "ícones e logo já no lugar"
  exit "$MEOW_OK"
fi

if meow_seco; then
  exit "$MEOW_DIVERGENTE"
fi

# --- 5. fazer o COSMIC reler ------------------------------------------------
# O cosmic-panel e o cosmic-app-list leem a config no início da sessão e não a
# vigiam.
#
# O cosmic-panel não vigia NADA DISTO — mas vigia outras coisas, e a frase que
# estava aqui ("zero fds de inotify, medido") era falsa.
#
# Trocar o NOME do tema de ícones é o único evento que realmente exige o
# reinício, e acontece uma vez por instalação.
precisa_reiniciar=0
[ "$tema_mudou_de_nome" = "1" ] && precisa_reiniciar=1

# DUAS RECUSAS ANTES DE MATAR — as duas custaram a tela dela.
#
# O `tests/convergencia.sh:25` roda tudo com `env -i HOME="$H"`, num HOME
# descartável — e é o certo: nada do ~/.config dela é tocado.
#
# O comentário acima diz "o cosmic-session respawna em ~4ms".
_ci_home_e_da_sessao() {
  local dono
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] && [ "$HOME" = "$dono" ]
}
_ci_espera_do_supervisor() {   # ms que o cosmic-session vai dormir, ou vazio
  journalctl --user -b -t cosmic-session --no-pager 2>/dev/null \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+'
}

if [ "$precisa_reiniciar" = "1" ] && ! _ci_home_e_da_sessao; then
  meow_aviso "HOME de teste ($HOME): não reinicio o painel da sessão real"
  meow_info  "  o pkill não conhece HOME — mataria a barra de quem está usando a máquina"
  precisa_reiniciar=0
fi

if [ "$precisa_reiniciar" = "1" ]; then
  _ci_espera="$(_ci_espera_do_supervisor)"
  case "$_ci_espera" in
    ''|*[!0-9]*) : ;;   # sem registro: o supervisor ainda não falhou, pode matar
    *)
      if [ "$_ci_espera" -gt 5000 ]; then
        meow_aviso "não vou reiniciar o painel: o cosmic-session dormiria $(( _ci_espera / 60000 ))min antes de trazê-lo de volta"
        meow_info  "  os ícones novos aparecem no próximo login, que é quando o contador zera"
        meow_info  "  (o backoff é 2^restarts x sorteio(0..9) ms, sem teto e sem zerar por sucesso)"
        precisa_reiniciar=0
      fi
      ;;
  esac
fi

if [ "$precisa_reiniciar" = "0" ]; then
  meow_ok "tema '$TEMA_NOME' atualizado (os ícones novos aparecem no próximo login)"
  exit "$MEOW_DIVERGENTE"
fi

# Este bloco fazia `pkill -x cosmic-panel` e, se o respawn não viesse em 10s,
# `setsid cosmic-panel &`.
#
# Além disso, ter DOIS spawners no projeto é o que produz dois painéis
# disputando as mesmas layer surfaces.
_ci_reler=0
meow_tela_reler || _ci_reler=$?
if [ "$_ci_reler" = 1 ]; then
  meow_erro "não consegui reciclar o painel — os ícones novos aparecem no próximo login"
  exit "$MEOW_ERRO"
fi

meow_ok "tema '$TEMA_NOME' instalado e ativo"
exit "$MEOW_DIVERGENTE"
