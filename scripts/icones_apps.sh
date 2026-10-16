#!/usr/bin/env bash
# icones_apps.sh — os ícones do LANÇADOR, em Catppuccin.
#
# Trocar o lançador por ele deixaria a tela vazia. Aquele pack foi para
# `mimetypes/`, onde ele brilha (ver icones_mimetypes.sh); o lançador precisava
# de outra fonte.
#
# `Daveedmee/catppuccin-icons` são as formas conhecidas de cada marca
# recoloridas na paleta — Firefox em pêssego, Discord em azul-céu, Spotify em
# verde pastel.
#
# O acervo entrega `.ico` de 256x256 a 24 bits por pixel, ou seja SEM canal
# alpha: usados assim, os ícones virariam quadrados sólidos sobre o papel de
# parede.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

# `ICONES_FLAVOR` TEM DOIS CONSUMIDORES, E O `meow.conf` SÓ DOCUMENTA UM O
# comentário da chave, no `meow.conf`, a descreve como sendo dos ícones de TIPO
# DE ARQUIVO (`icones_pastas.sh`, o pack `catppuccin/vscode-icons`).
#
# Não é dívida técnica e não se "conserta" recolorindo — recolorir desfaria uma
# decisão dela em silêncio, e ainda por cima num acervo de terceiro cuja licença
# o `packs/meowsystem/PROCEDENCIA.md` registra como não declarada.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
FLAVOR_ICONES="$(python3 "$RAIZ/scripts/pack.py" flavor-icones "$_pack_ref")" || FLAVOR_ICONES=""
# O acervo só tem duas variantes: dark=Macchiato, light=Latte. Frappé e Mocha
# caem no vizinho mais próximo em claridade, e o script DIZ que fez isso.
case "$FLAVOR_ICONES" in
  latte) VARIANTE="latte" ;;
  macchiato|'') VARIANTE="macchiato" ;;
  frappe|mocha) VARIANTE="macchiato"; APROXIMOU="$FLAVOR_ICONES" ;;
  *) exit "$MEOW_SEM_DEPENDENCIA" ;;
esac

ORIGEM="$RAIZ/assets/icones/catppuccin-apps/$VARIANTE"
MAPA="$RAIZ/packs/meowsystem/icones/apps.map"
TEMA="${ICONES_TEMA:-MeowSystem-Icons}"
BASE_TEMA="$HOME/.local/share/icons/$TEMA"
DESTINO="$BASE_TEMA/512x512/apps"

# A dock desenha ícone de aplicativo a **48 px** (medido por captura). Ou seja,
# o toolkit recebia um PNG de 512 e o reduzia **10,7×** em tempo de desenho, com
# o filtro dele — e é esse downscale que serrilha.
#
# O QUE DECIDE NÃO É A ORDEM DE `Directories=`, É O TAMANHO — e isto foi testado
# num tema de mentira com o mesmo nome nos dois diretórios, invertendo a ordem:
#
#     Directories=512x512/apps,48x48/apps  ->  pede 48px, abre 48x48/apps
#     Directories=48x48/apps,512x512/apps  ->  pede 48px, abre 48x48/apps
mapfile -t TAMANHOS_DERIVADOS < <(meow_icones_escada)
# O `\n` NÃO É ENFEITE — sem ele a varredura de órfão nunca saía do 512
#   Esta função é usada dentro de `$(for px in ...; do dir_de "$px"; done)`, e um
#   `printf` sem quebra de linha faz os dez caminhos virarem UMA palavra colada:
#       [/h/.../24x24/apps/h/.../32x32/apps]
#   O `for d in` recebia então um diretório inexistente, o `[ -d ]` falhava e o
#   laço fazia `continue` — calado. Medido com `bash -x`: dos onze
#   diretórios que este script escreve, a remoção de órfão visitava UM
#   (`512x512/apps`). Consequência prática: um aplicativo tirado do `apps.map`
#   deixava dez PNG para trás, e o `--conferir` dizia que estava tudo certo.
dir_de() { printf '%s/.local/share/icons/%s/%sx%s/apps\n' "$HOME" "$TEMA" "$1" "$1"; }

# Pedido expresso dela: estes ficam como estão, venha o que vier.
INTOCAVEIS_PREFIXO=(steam_icon_)
INTOCAVEIS=(fogstripper hefesto-dualsense4unix com.vitoriamaria.HefestoDualsense4Unix)

intocavel() {
  local n="$1" i
  for i in "${INTOCAVEIS[@]}"; do [ "$n" = "$i" ] && return 0; done
  for i in "${INTOCAVEIS_PREFIXO[@]}"; do case "$n" in "$i"*) return 0 ;; esac; done
  return 1
}

# A remoção de órfão daqui apaga `.png` cujo nome não está no `apps.map`. Isso
# era certo enquanto TODO `.png` de `<tam>/apps` fosse meu — e não é mais:
#
#   `packs/meowsystem/icones/apps-hicolor.map`  o `completar_icones.sh` copia a marca de fábrica do
#                             `hicolor` do sistema para o diretório do tamanho
#                             REAL dela (`thunderbird` -> `128x128/apps`), que é
#                             um dos meus;
#   `assets/icones/curadoria.map`     o `importar_icones.sh` instala a arte que ELA
#                             escolheu na página de curadoria, e um PNG escolhido
#                             vai para `<lado>x<lado>/apps` pelo mesmo motivo.
declare -A ALHEIO_ARQ=()   # "128x128/apps/thunderbird.png" -> 1
declare -A CURADO=()       # nome escolhido por ela na página -> 1
_ler_alheios() {
  local linha chave caminho ext subdir lado
  # `nome:caminho-no-sistema` — a marca de fábrica. O diretório de destino sai
  # do caminho da fonte, exatamente como o `completar_icones.sh` o deriva.
  if [ -f "$RAIZ/packs/meowsystem/icones/apps-hicolor.map" ]; then
    while IFS= read -r linha; do
      case "$linha" in ''|'#'*) continue ;; esac
      chave="${linha%%:*}"; caminho="${linha#*:}"
      [ -n "$chave" ] && [ -n "$caminho" ] || continue
      lado="$(basename "$(dirname "$(dirname "$caminho")")")"
      case "$lado" in
        [0-9]*x[0-9]*) ALHEIO_ARQ["$lado/apps/$chave.png"]=1 ;;
      esac
    done < "$RAIZ/packs/meowsystem/icones/apps-hicolor.map"
  fi
  # `chave<TAB>extensão<TAB>subdiretório` — escrito pelo `importar_icones.sh`.
  # Ele só existe depois da primeira importação; ausência não é defeito.
  if [ -f "$RAIZ/assets/icones/curadoria.map" ]; then
    while IFS=$'\t' read -r chave ext subdir; do
      case "$chave" in ''|'#'*) continue ;; esac
      [ -n "$ext" ] && [ -n "$subdir" ] || continue
      CURADO["$chave"]=1
      ALHEIO_ARQ["$subdir/$chave.$ext"]=1
    done < "$RAIZ/assets/icones/curadoria.map"
  fi
  return 0
}

_nao_e_meu() {
  local arq="$1" nome="$2"
  [ -n "${ALHEIO_ARQ[${arq#"$BASE_TEMA/"}]:-}" ] && return 0
  intocavel "$nome"
}

declare -A MAPA_LIDO=()
_ler_mapa() {
  local linha nome arq
  while IFS= read -r linha; do
    case "$linha" in ''|'#'*) continue ;; esac
    nome="${linha%%:*}"; arq="${linha#*:}"
    [ -n "$nome" ] && [ -n "$arq" ] || continue
    intocavel "$nome" && continue
    # Escolha dela na página de curadoria vence o acervo, e vence CALANDO este
    # script: o nome sai daqui, meus onze arquivos viram órfãos na varredura e
    # saem, e o que sobra é o dela.
    if [ -n "${CURADO[$nome]:-}" ]; then
      meow_debug "$nome: arte escolhida na curadoria — não é mais deste acervo"
      continue
    fi
    MAPA_LIDO["$nome"]="$arq"
  done < "$MAPA"
  # `return 0` NÃO É DECORAÇÃO: um `while` devolve o status do último comando do
  # corpo.
  return 0
}

_pronto() {
  if [ ! -d "$ORIGEM" ]; then
    meow_pula "o acervo Catppuccin de aplicativos não está em assets/icones/catppuccin-apps/$VARIANTE"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  [ -f "$MAPA" ] || { meow_pula "sem packs/meowsystem/icones/apps.map — nada a vestir"; return "$MEOW_SEM_DEPENDENCIA"; }
  return "$MEOW_OK"
}

_desejado() {
  local nome arq
  for nome in "${!MAPA_LIDO[@]}"; do
    arq="${MAPA_LIDO[$nome]}"
    [ -f "$ORIGEM/$arq.png" ] && printf '%s\t%s\n' "$nome" "$ORIGEM/$arq.png"
  done
}

# Mesma disciplina do icones_mimetypes.sh: compara como o escritor escreve. Aqui
# o conteúdo é binário, então a comparação é `cmp` — e a escrita é `cp`, não
# `meow_escrever`, justamente para que os dois falem a mesma língua.
#
# O mtime é o mesmo teste que o `completar_icones.sh` já usa para a cache do GTK
# (`themes.bin` não pode ser mais velho que o `.tmTheme`) — se o acervo mudar, o
# derivado é refeito; se não mudou, ninguém escreve nada.
_derivado_ok() {
  local arq="$1" origem="$2" px="$3" dim
  [ -f "$arq" ] || return 1
  [ "$arq" -nt "$origem" ] || [ "$arq" -ef "$origem" ] || return 1
  dim="$(identify -format '%wx%h' "$arq" 2>/dev/null)" || return 1
  [ "$dim" = "${px}x${px}" ]
}

_conferir() {
  local nome origem faltam=0 diferem=0 orfaos=0 total=0 arq px
  while IFS=$'\t' read -r nome origem; do
    total=$((total + 1))
    if [ ! -f "$DESTINO/$nome.png" ]; then faltam=$((faltam + 1))
    elif ! cmp -s "$origem" "$DESTINO/$nome.png"; then diferem=$((diferem + 1))
    fi
    for px in "${TAMANHOS_DERIVADOS[@]}"; do
      _derivado_ok "$(dir_de "$px")/$nome.png" "$origem" "$px" || faltam=$((faltam + 1))
    done
  done < <(_desejado)
  # ÓRFÃO EM TODOS OS DIRETÓRIOS, E SÓ `.png` — a extensão é o que separa os
  # dois acervos de aplicativo.
  local d
  for d in "$DESTINO" $(for px in "${TAMANHOS_DERIVADOS[@]}"; do dir_de "$px"; done); do
    [ -d "$d" ] || continue
    for arq in "$d"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      _nao_e_meu "$arq" "$nome" && continue
      [ -n "${MAPA_LIDO[$nome]:-}" ] || orfaos=$((orfaos + 1))
    done
  done
  if [ "$faltam" = 0 ] && [ "$diferem" = 0 ] && [ "$orfaos" = 0 ]; then
    meow_ok "$total aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_muda "aplicativos: $faltam a instalar, $diferem a atualizar, $orfaos a remover (de $total)"
  return "$MEOW_DIVERGENTE"
}

_aplicar() {
  local nome origem arq mudou=0 postos=0 removidos=0
  while IFS=$'\t' read -r nome origem; do
    if [ -f "$DESTINO/$nome.png" ] && cmp -s "$origem" "$DESTINO/$nome.png"; then continue; fi
    if meow_seco; then meow_muda "mudaria $DESTINO/$nome.png"; mudou=1; postos=$((postos+1)); continue; fi
    meow_destino_permitido "$DESTINO/$nome.png" || return "$MEOW_ERRO"
    mkdir -p "$DESTINO"
    local tmp; tmp="$(mktemp -p "$DESTINO" ".meow.XXXXXX")"
    cp -f "$origem" "$tmp" && chmod 644 "$tmp" && mv -f "$tmp" "$DESTINO/$nome.png" \
      || { rm -f "$tmp"; meow_erro "não consegui escrever $DESTINO/$nome.png"; return "$MEOW_ERRO"; }
    mudou=1; postos=$((postos + 1))
  done < <(_desejado)

  # Os derivados: um arquivo por tamanho que o COSMIC de fato pede, para que ele
  # nunca precise reduzir 512 px em tempo de desenho. É isto que tira o
  # serrilhado — ver o cabeçalho.
  local px dir
  while IFS=$'\t' read -r nome origem; do
    for px in "${TAMANHOS_DERIVADOS[@]}"; do
      dir="$(dir_de "$px")"
      _derivado_ok "$dir/$nome.png" "$origem" "$px" && continue
      if meow_seco; then
        meow_muda "geraria ${px}x${px} de $nome"; mudou=1; postos=$((postos+1)); continue
      fi
      meow_destino_permitido "$dir/$nome.png" || return "$MEOW_ERRO"
      mkdir -p "$dir"
      local tmp2; tmp2="$(mktemp -p "$dir" ".meow.XXXXXX")"
      # `-filter Lanczos` é o ponto do exercício: é o filtro que a folha usou e
      # que ela viu liso. `-background none` porque estes PNG têm alpha, e sem
      # isso o `convert` acha um fundo branco.
      if convert "$origem" -background none -filter Lanczos -resize "${px}x${px}" \
                 -strip PNG32:"$tmp2" 2>/dev/null; then
        chmod 644 "$tmp2"
        mv -f "$tmp2" "$dir/$nome.png" \
          || { rm -f "$tmp2"; meow_erro "não consegui escrever $dir/$nome.png"; return "$MEOW_ERRO"; }
        mudou=1; postos=$((postos + 1))
      else
        rm -f "$tmp2"
        # Sem `convert` não há derivado, e o ícone continua vindo do 512 —
        # serrilhado, mas presente. Aviso, não erro: o instalador não pode
        # parar por causa da nitidez de um ícone.
        meow_aviso "não consegui gerar ${px}x${px} de $nome (falta imagemagick?)"
      fi
    done
  done < <(_desejado)

  for dir in "$DESTINO" $(for px in "${TAMANHOS_DERIVADOS[@]}"; do dir_de "$px"; done); do
    [ -d "$dir" ] || continue
    for arq in "$dir"/*.png; do
      [ -e "$arq" ] || continue
      nome="$(basename "$arq" .png)"
      _nao_e_meu "$arq" "$nome" && continue
      if [ -z "${MAPA_LIDO[$nome]:-}" ]; then
        if meow_seco; then meow_muda "removeria $arq (saiu do mapa)"
        else meow_destino_permitido "$arq" || return "$MEOW_ERRO"; rm -f "$arq"; fi
        mudou=1; removidos=$((removidos + 1))
      fi
    done
  done

  if [ "$mudou" = 0 ]; then
    # O NÚMERO ENTRA AQUI PORQUE ELE FALTAVA — e a falta era visível na tela: o
    # `--conferir` dizia "16 aplicativos já com ícone Catppuccin" e o
    # `--aplicar`, no mesmo estado, dizia "aplicativos já com ícone Catppuccin",
    # sem contagem.
    local quantos; quantos="$(_desejado | wc -l)"
    meow_ok "$quantos aplicativos já com ícone Catppuccin ${APROXIMOU:+($APROXIMOU aproximado para $VARIANTE)}"
    return "$MEOW_OK"
  fi
  meow_info "aplicativos: $postos posto(s), $removidos removido(s) — Catppuccin $VARIANTE"
  return "$MEOW_DIVERGENTE"
}

main() {
  _pronto || return $?
  _ler_alheios
  _ler_mapa
  case "${1:-}" in
    --conferir) _conferir ;;
    ''|--aplicar) _aplicar ;;
    *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; return "$MEOW_ERRO" ;;
  esac
}

APROXIMOU="${APROXIMOU:-}"
main "$@"
