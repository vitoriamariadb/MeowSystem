#!/usr/bin/env bash
# Ela desenhou os ícones dos projetos dela, exportou para PNG, e perdeu os SVG
# originais. Sobrou o PNG — e PNG num COSMIC a 100% de escala numa tela de 24" é
# exatamente o que ela descreveu: "meus pngs originais ficaram horríveis aqui no
# cosmic".
#
# Os 20 são os que este script instala.
#
# O `construir_convertidos.sh` NÃO servia para isto, e a diferença é de
# intenção: ele REESCREVE arte de terceiro no traço monocromático do Arcticons,
# para o app caber no tema.

set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"
# O `meow_icones_derivar` mora lá — ver o comentário do `_resgatados_instalar`.
# shellcheck source=../lib/icones.sh
. "$RAIZ/lib/icones.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
ALVO="$TEMA_DIR/scalable/apps"
APPS_USUARIO="$HOME/.local/share/applications"

# Têm cor Dracula fixa e moravam no motor (assets/icones/), onde o Catppuccin os
# herdava.
_pack_ref="$(meow_pack_dir)"
[ -n "$_pack_ref" ] || _pack_ref="$(meow_pack_padrao_dir || true)"
MAPA="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.resgatados.mapa 2>/dev/null)" || MAPA=""
ACERVO="$(python3 "$RAIZ/scripts/pack.py" acervo "$_pack_ref" icones.resgatados.desenhos 2>/dev/null)" || ACERVO=""
ACERVO="${ACERVO%/}"
SO_TIRAR=0
if [ -z "$MAPA" ] || [ -z "$ACERVO" ]; then
  # Só sai o que é byte a byte o desenho de quem os traz: o nome sozinho não
  #   diz de quem é o arquivo em `scalable/apps`, que tem outros donos.
  SO_TIRAR=1
  { IFS= read -r MAPA; IFS= read -r ACERVO; } < <(python3 -I - "$RAIZ/scripts" <<'PYFIM' 2>/dev/null
import os, sys
sys.path.insert(0, sys.argv[1])
import pack
for base in pack.raizes():
    try:
        ids = sorted(os.listdir(base))
    except OSError:
        continue
    for pid in ids:
        dir_pack = os.path.join(base, pid)
        if not os.path.isfile(os.path.join(dir_pack, "pack.json")):
            continue
        mapa = pack.acervo("icones.resgatados.mapa", ref=dir_pack)
        pasta = pack.acervo("icones.resgatados.desenhos", ref=dir_pack)
        if mapa and pasta:
            print(mapa)
            print(pasta.rstrip("/"))
            raise SystemExit(0)
PYFIM
)
fi

# Os `.desktop` cujo `Icon=` é caminho absoluto, e o nome de ícone que cada um
# passa a usar. A chave é o ARQUIVO, porque é ele que a cópia local sombreia.
declare -A DESKTOP_ABSOLUTO=(
  [guvcview.desktop]="guvcview"
)

# --- o mapa -------------------------------------------------------------------
# Uma linha por ícone: `nome : png-de-origem : autoria`.
#
# Os dois instaladores escrevem o MESMO `scalable/apps/<nome>.svg`, e medido
# numa casa de brinquedo, depois da instalação, o `--conferir` daqui saía 1
# acusando o desenho do pack como divergente — o doctor das 5h os trocaria um
# pelo outro todo dia, e o `nao` deste interruptor apagaria o arquivo do pack
# por nome, sem conferir o conteúdo.
_resgatados_cedidos() {
  MEOW_PACK_DIR="$(meow_pack_dir)" python3 "$RAIZ/scripts/pack.py" fontes 2>/dev/null \
    | awk -F'\t' '$3 ~ /^pack:/ || $3 == "escolha" { print $1 }'
}

_resgatados_todos() {
  sed -e 's/#.*//' "$MAPA" | awk -F: 'NF>=3 { gsub(/^[ \t]+|[ \t]+$/, "", $1); if ($1 != "") print $1 }'
}

# O nome vira `<nome>.svg` dentro do tema: só passa o de conjunto fechado
# (`meow_nome_seguro`), e a linha torta é pulada e contada
# (`_resgatados_tortos`).
_resgatados_nomes() {
  [ -f "$MAPA" ] || return 1
  local cedidos nome
  cedidos="$(_resgatados_cedidos)"
  _resgatados_todos \
    | awk -v cedidos="$cedidos" 'BEGIN { n = split(cedidos, c, "\n"); for (i = 1; i <= n; i++) fora[c[i]] = 1 }
                                 !($0 in fora)' \
    | while IFS= read -r nome; do meow_nome_seguro "$nome" && printf '%s\n' "$nome"; done
  return 0
}

_resgatados_tortos() {
  local nome n=0
  [ -f "$MAPA" ] || { printf 0; return 0; }
  while IFS= read -r nome; do meow_nome_seguro "$nome" || n=$((n + 1)); done < <(_resgatados_todos)
  printf '%s' "$n"
}

# --- instalar -----------------------------------------------------------------
_resgatados_instalar() {
  [ "$SO_TIRAR" = "0" ] || { meow_pula "o pack no ar não traz resgatados"; return "$MEOW_SEM_DEPENDENCIA"; }
  local rc=0 nome origem
  local postos=0 faltando=()

  while read -r nome; do
    [ -n "$nome" ] || continue
    # O desenho é lido pelo `meow_dentro`: um link que sai da pasta do pack não
    # é desenho, e conta como ausente.
    origem="$(meow_dentro "$ACERVO" "$nome.svg")" || origem=""
    if [ -z "$origem" ] || [ ! -f "$origem" ]; then
      # Nome no mapa sem desenho no acervo: é falha de quem editou o mapa, e
      # dizer qual é vale mais que um total. Não aborta — os outros 19 não têm
      # culpa de um nome digitado errado.
      faltando+=("$nome"); continue
    fi
    # É o mesmo motivo do `_dracula_instalar`: o `meow icones fonte` diz o que
    # deriva de cada desenho perguntando ao `lib/icones.sh`, e o instalador
    # precisa escrever exatamente aquilo.
    meow_icones_derivar "$origem" "$nome" "$TEMA_DIR"
    case $? in
      0) : ;;
      1) postos=$((postos+1)) ;;
      *) rc=2 ;;
    esac
  done < <(_resgatados_nomes)

  if [ "${#faltando[@]}" -gt 0 ]; then
    meow_aviso "no mapa mas sem desenho em $ACERVO/: ${faltando[*]}"
    [ "$rc" = "0" ] && rc=1
  fi

  local rc_d; _resgatados_desktops_instalar; rc_d=$?
  [ "$rc_d" = "2" ] && rc=2
  [ "$rc_d" = "1" ] && [ "$rc" = "0" ] && rc=1

  local rc_c; _resgatados_cache; rc_c=$?
  [ "$rc_c" = "1" ] && [ "$rc" = "0" ] && rc=1

  if [ "$postos" -gt 0 ]; then
    meow_ok "$postos ícone(s) resgatado(s) no tema"
    _resgatados_avisar
    rc=1
  elif [ "$rc" = "0" ]; then
    # `ok`, e não `meow_debug`. Em silêncio, a linha `resgatados` do doctor
    # saía vazia: a tabela mostra a primeira linha do conferidor, e o
    # conferidor em dia não dizia nada.
    meow_ok "os $(_resgatados_estado | cut -d' ' -f1) resgatados já estão no tema"
  fi
  return "$rc"
}

#   O `cosmic-app-library` e o `cosmic-panel` NÃO ligam em GTK:
#       ldd /usr/bin/cosmic-app-library | grep -c libgtk   ->  0
#   Eles são libcosmic/iced e varrem o tema de ícones AO NASCER, guardando o
#   resultado em memória. Um SVG que chega depois disso não existe para eles até
#   o processo reiniciar — nem reindexar a cache do GTK ajuda, porque não é a
#   cache do GTK que eles leem.
_resgatados_avisar() {
  meow_seco && return 0
  meow_tela_reler
  case $? in
    0) meow_ok "os ícones resgatados já estão na dock e no menu" ;;
    3) meow_info "fora da sessão gráfica: os ícones resgatados aparecem no próximo login" ;;
  esac
  return 0
}

# Com um `icon-theme.cache` dentro do diretório do tema, o GTK lê a CACHE e
# IGNORA o disco: um SVG copiado depois dela simplesmente não existe para o
# resolvedor.
#
# Reindexar tem de ser parte de instalar.
_resgatados_cache() {
  local cache="$TEMA_DIR/icon-theme.cache"
  [ -f "$cache" ] || return 0
  [ -n "$(find "$ALVO" -name '*.svg' -newer "$cache" -print -quit 2>/dev/null)" ] || return 0

  if meow_seco; then
    meow_muda "reindexaria a cache do tema ($cache está velha e esconde os resgatados)"
    return 1
  fi
  if ! meow_tem gtk-update-icon-cache; then
    meow_aviso "$cache está velha e esconde os ícones novos, e não há gtk-update-icon-cache"
    meow_info  "  apague o arquivo: rm '$cache'"
    return 1
  fi
  if gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null; then
    meow_ok "cache do tema reindexada (ela escondia os resgatados)"
    return 1
  fi
  meow_aviso "não consegui reindexar $cache — apague-a se algum ícone não aparecer"
  return 1
}

# A cópia local do `.desktop`, para os que trazem o PNG por caminho absoluto.
# É `sed` numa linha só e o resto do arquivo passa intacto: trocar `Icon=` sem
# tocar em `Exec`, `Categories` ou nas traduções é o ponto.
_resgatados_desktops_instalar() {
  local rc=0 arquivo nome origem conteudo destino
  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    nome="${DESKTOP_ABSOLUTO[$arquivo]}"
    [ -f "$ACERVO/$nome.svg" ] || continue   # sem desenho, não há o que apontar
    origem="/usr/share/applications/$arquivo"
    destino="$APPS_USUARIO/$arquivo"
    # Se já existe cópia local, ela é a base — senão, a do sistema. Assim um
    # arquivo que ELA editou não é substituído pelo de fábrica.
    [ -f "$destino" ] && origem="$destino"
    [ -f "$origem" ] || continue
    conteudo="$(sed -E "s|^Icon=.*|Icon=$nome|" "$origem")" || { rc=2; continue; }
    meow_escrever "$destino" "$conteudo" 644
    case $? in 0) : ;; 1) [ "$rc" = "0" ] && rc=1 ;; *) rc=2 ;; esac
  done
  return "$rc"
}

# --- remover ------------------------------------------------------------------
# Desligar desliga: some o SVG que este script pôs, e o PNG que estava atrás dele
# volta a ser o que o resolvedor acha. Por NOME, nunca por varredura — o
# `scalable/apps` tem outros dois donos.
_resgatados_remover() {
  local rc=0 nome tirados=0 arquivo de_quem
  while read -r nome; do
    [ -n "$nome" ] || continue
    [ -f "$ALVO/$nome.svg" ] || continue
    if [ "$SO_TIRAR" = "1" ] && { ! de_quem="$(meow_dentro "$ACERVO" "$nome.svg")" \
         || [ "$(cat "$ALVO/$nome.svg")" != "$(cat "$de_quem" 2>/dev/null)" ]; }; then
      continue
    fi
    if meow_seco; then
      meow_muda "removeria $ALVO/$nome.svg"; rc=1; continue
    fi
    rm -f "$ALVO/$nome.svg" && tirados=$((tirados+1)) || rc=2
  done < <(_resgatados_nomes)

  # A cópia local do `.desktop` some inteira: ela só existia para trocar o
  # `Icon=`, e o arquivo do sistema por baixo volta a valer intacto.
  for arquivo in "${!DESKTOP_ABSOLUTO[@]}"; do
    [ -f "$APPS_USUARIO/$arquivo" ] || continue
    [ -f "/usr/share/applications/$arquivo" ] || continue  # sem original, não apaga
    grep -q "^Icon=${DESKTOP_ABSOLUTO[$arquivo]}$" "$APPS_USUARIO/$arquivo" || continue
    if meow_seco; then
      meow_muda "removeria $APPS_USUARIO/$arquivo"; rc=1; continue
    fi
    rm -f "$APPS_USUARIO/$arquivo" || rc=2
  done

  # O `-newer` não serve aqui (arquivo apagado não tem data), então a condição é
  # ter apagado alguma coisa.
  if [ "$tirados" -gt 0 ] && [ -f "$TEMA_DIR/icon-theme.cache" ] && meow_tem gtk-update-icon-cache; then
    gtk-update-icon-cache -q -f "$TEMA_DIR" 2>/dev/null \
      && meow_ok "cache do tema reindexada (ela ainda anunciava os retirados)" \
      || meow_aviso "não consegui reindexar a cache — apague $TEMA_DIR/icon-theme.cache se algum ícone sumir"
  fi

  [ "$tirados" -gt 0 ] && { meow_ok "$tirados ícone(s) resgatado(s) retirado(s) do tema"; rc=1; }
  # Desligado e já sem nenhum no tema: a linha do doctor também precisa dizer
  # alguma coisa.
  if [ "$rc" = "0" ]; then
    if [ "$SO_TIRAR" = "1" ]; then meow_ok "o pack no ar não traz resgatados — nenhum no tema"
    else meow_ok "resgatados desligados — nenhum no tema"; fi
  fi
  return "$rc"
}

# --- estado -------------------------------------------------------------------
_resgatados_estado() {
  local total=0 postos=0 nome
  while read -r nome; do
    [ -n "$nome" ] || continue
    total=$((total+1))
    [ -f "$ALVO/$nome.svg" ] && postos=$((postos+1))
  done < <(_resgatados_nomes)
  printf '%s %s' "$postos" "$total"
}

# --- ponto de entrada ---------------------------------------------------------
_resgatados_aplicar() {
  local tortos
  tortos="$(_resgatados_tortos)"
  [ "${tortos:-0}" -gt 0 ] && meow_aviso "$tortos linha(s) com nome fora da forma no mapa dos resgatados — pulada(s)"
  if [ "${ICONES_RESGATADOS:-sim}" = "sim" ] && [ "$SO_TIRAR" = "0" ]; then _resgatados_instalar
  else _resgatados_remover; fi
}

case "${1:-aplicar}" in
  aplicar|--aplicar) _resgatados_aplicar ;;
  # `--conferir` é o `aplicar` de olhos abertos e mãos no bolso: o `meow_seco`
  # faz o `meow_escrever` relatar em vez de gravar, e o código de saída 1 é o
  # que o `meow doctor` lê como "divergente".
  --conferir) MEOW_SECO=1 _resgatados_aplicar ;;
  instalar) _resgatados_instalar ;;
  remover)  _resgatados_remover ;;
  estado)   _resgatados_estado ;;
  *) printf 'uso: icones_resgatados.sh [aplicar|--conferir|instalar|remover|estado]\n' >&2; exit 2 ;;
esac
