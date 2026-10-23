#!/usr/bin/env bash
# ocultar_apps.sh — some com os aplicativos que ela nunca vai abrir.
#
# O `~/.local/share/applications/vim.desktop` tem `NoDisplay=true` E
# `Hidden=true`, e o Vim continua no lançador.
#
# Prova pelo lado oposto: Chrome e Steam têm `.desktop` de mesmo nome no home E
# em /usr/share, e o COSMIC mostra OS DOIS, desambiguando com "(Local)" e
# "(Sistema)" — os parênteses que ela viu.
#
# `NoDisplay=true` no próprio `/usr/share/applications/<app>.desktop`.
#
# Quase nenhum deles é removível.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# A pasta do sistema vem de fora só para o teste: o `tests/` monta uma de
# brinquedo, e nada aqui escreve no /usr/share de verdade num teste.
SISTEMA="${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"

# Um por linha, com o porquê ao lado.
OCULTAR=(
  # --- dependência de outro pacote, não aplicativo que se abre ---------------
  vim                       # editor de terminal; dependência, não aplicativo
  debian-xterm              # dependência de xinit e das bibliotecas da Steam
  debian-uxterm             # idem
  qt5ct                     # painel de tema Qt: os apps Qt dela são flatpak
  qt6ct                     # idem
  display-im6.q16           # ImageMagick: é o `convert`, não um visualizador
  info                      # TeXInfo, leitor de manual do GNU
  im-config                 # configurador de método de entrada (ibus e cia)
  ibus-setup                # idem
  org.freedesktop.IBus.Setup  # o mesmo ibus, com o ID novo — é este que aparecia
  org.gnome.font-viewer     # visualizador de fontes
  gnome-language-selector   # suporte a idiomas
  system-config-printer     # impressoras: o COSMIC tem a própria página

  # --- GNOME que o COSMIC já cobre, ou que ela não usa -----------------------
  org.gnome.eog             # Visualizador de Imagens: ela usa o do COSMIC
  org.gnome.Evince          # Visualizador de Documentos: o PDF abre no navegador
  org.gnome.baobab          # Analisador de Uso do Disco
  org.gnome.PowerStats      # Estatísticas de Energia: máquina de mesa, sem bateria
  org.gnome.seahorse.Application  # Senhas e Chaves
  org.gnome.DiskUtility     # Discos: o GParted cobre, e ela usa o terminal
  simple-scan               # Digitalizador: não há scanner nesta máquina
  yelp                      # Ajuda do GNOME: documenta um desktop que ela não usa
  gucharmap                 # Mapa de Caracteres

  # --- sistema avançado: existe, funciona, mas não é do dia a dia ------------
  # Nenhum destes foi desinstalado — todos continuam a um comando de distância
  # no terminal. O que sai é a presença no lançador.
  nm-connection-editor      # Configuração avançada de rede
  repoman                   # gerenciador de repositórios do Pop!_OS
  com.system76.Popsicle     # Gravador de USB
  gparted                   # particionador: uso raro e deliberado
  nvidia-settings           # painel da NVIDIA: sobe sozinho no autostart

  # --- duas entradas para o mesmo serviço ------------------------------------
  syncthing-start           # "Start Syncthing"
  syncthing-ui              # "Syncthing Web UI" — o mesmo serviço, dois ícones
)

# As 32 linhas acima são o gosto de UMA máquina, e o `meow.conf.exemplo` já
# dizia isso com todas as letras na chave `LANCADOR_SISTEMA`: "a lista de nomes
# em `scripts/ocultar_apps.sh` é o gosto de quem escreveu, não o seu".
#
# Quem NÃO tem aqueles aplicativos não perdia nada (o laço pula o `.desktop` que
# não existe); quem tem OUTROS é que não tinha como dizer.
#
# Enquanto o `OCULTAR=()` vinha antes do laço, não havia para onde voltar.
LANCADOR_OCULTAR="${LANCADOR_OCULTAR:-}"
LANCADOR_OCULTAR_FONTE="fábrica"
_da_conf=()
_fora=()
if [ -n "$LANCADOR_OCULTAR" ]; then
  while IFS= read -r _item; do
    # Apara espaço dos dois lados: o conf é escrito à mão e `a, b` é a forma
    # natural de escrever uma lista — o espaço colado no nome viraria um
    # `.desktop` que não existe e um "não instalado" silencioso no placar.
    _item="${_item#"${_item%%[![:space:]]*}"}"
    _item="${_item%"${_item##*[![:space:]]}"}"
    # `-nome` é «este não», para os que o pack esconde.
    case "$_item" in
      -?*) _fora+=("${_item#-}") ;;
      ?*)  _da_conf+=("$_item") ;;
    esac
  done < <(printf '%s\n' "$LANCADOR_OCULTAR" | tr ',' '\n')
  if [ "${#_da_conf[@]}" -gt 0 ]; then
    OCULTAR=("${_da_conf[@]}")
    LANCADOR_OCULTAR_FONTE="meow.conf"
  fi
fi

# O pack no ar declara a lista dele (`lancador.ocultar`, os overrides de
# `.desktop` que o tema Dracula de antes trazia), e ela se SOMA à do conf: a
# chave do conf é escrita por quem instala e vem com os 32 de fábrica, então
# uma lista do pack que só valesse com a chave vazia não valeria em lugar
# nenhum.
_do_pack="$(meow_pack_dir)"
[ -n "$_do_pack" ] || _do_pack="$(meow_pack_padrao_dir 2>/dev/null || true)"
declare -A _ja=()
for _item in "${OCULTAR[@]}"; do _ja["$_item"]=1; done
while IFS= read -r _item; do
  [ -n "$_item" ] && [ -z "${_ja[$_item]:-}" ] || continue
  OCULTAR+=("$_item"); _ja["$_item"]=1
done < <(python3 "$RAIZ/scripts/pack.py" ocultar "$_do_pack" 2>/dev/null)
if [ "${#_fora[@]}" -gt 0 ]; then
  _resto=()
  for _item in "${OCULTAR[@]}"; do
    printf '%s\n' "${_fora[@]}" | grep -qxF -- "$_item" || _resto+=("$_item")
  done
  OCULTAR=(${_resto[@]+"${_resto[@]}"})
fi
unset _do_pack _ja _resto

# A lista resolvida (fábrica, conf, pack e os `-nome`), para o `ocultar_casa.sh`
# esconder o que não mora em /usr/share pela mesma régua.
if [ "${1:-}" = "--lista" ]; then
  printf '%s\n' ${OCULTAR[@]+"${OCULTAR[@]}"}
  exit "$MEOW_OK"
fi

# Ele só desfazia uma marca pelo `-nome`. Trocar do Dracula para o Catppuccin
# deixava os 24 do `lancador.ocultar` do pack fora do lançador, porque a lista
# nova simplesmente não os nomeava mais.
MARCADOS="$MEOW_ESTADO/lancador-ocultos.txt"
_tem_marca() {
  awk 'ant == "[Desktop Entry]" && $0 == "NoDisplay=true" { achou = 1 } { ant = $0 } END { exit !achou }' "$1"
}
declare -A _meus=()
if [ -f "$MARCADOS" ]; then
  while IFS= read -r _item; do [ -n "$_item" ] && _meus["$_item"]=1; done < "$MARCADOS"
else
  for _item in "${OCULTAR[@]}"; do
    [ -f "$SISTEMA/$_item.desktop" ] && _tem_marca "$SISTEMA/$_item.desktop" && _meus["$_item"]=1
  done
fi

mudou=0
ausentes=0
sem_root=0

for app in "${OCULTAR[@]}"; do
  arq="$SISTEMA/$app.desktop"
  [ -f "$arq" ] || { ausentes=$((ausentes+1)); continue; }

  # Já está oculto? Comparar por conteúdo, não por existência (regra 5).
  if grep -qE '^NoDisplay=true' "$arq" 2>/dev/null; then
    continue
  fi

  if meow_seco; then
    meow_muda "ocultaria $app"
    mudou=1
    continue
  fi

  if ! meow_desktop_pode "$arq"; then
    sem_root=$((sem_root+1))
    continue
  fi

  # Acrescenta a chave logo depois de [Desktop Entry], que é onde ela vale. Pôr
  # no fim do arquivo funcionaria por acaso: se houver uma seção [Desktop Action]
  # depois, a chave cairia DENTRO dela e não faria efeito nenhum.
  novo="$(awk '
    /^\[Desktop Entry\]/ && !feito { print; print "NoDisplay=true"; feito=1; next }
    { print }
  ' "$arq")"

  tmp="$(mktemp)"
  printf '%s\n' "$novo" > "$tmp"
  # Este arquivo é do apt, e até aqui marcá-lo era uma via de mão única:
  # `dpkg -V` acusava a divergência e não havia de onde voltar.
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou marcá-lo"
    rm -f "$tmp"
    continue
  fi
  if meow_desktop_escrever "$arq" "$tmp"; then
    mudou=1; _meus["$app"]=1
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done

# A cópia vem antes da escrita, como acima.
declare -A _na_lista=()
for _item in "${OCULTAR[@]}"; do _na_lista["$_item"]=1; done
_devolver=(${_fora[@]+"${_fora[@]}"})
for _item in "${!_meus[@]}"; do
  [ -n "${_na_lista[$_item]:-}" ] && continue
  printf '%s\n' ${_fora[@]+"${_fora[@]}"} | grep -qxF -- "$_item" || _devolver+=("$_item")
done
devolvidos=0
for app in ${_devolver[@]+"${_devolver[@]}"}; do
  arq="$SISTEMA/$app.desktop"
  [ -f "$arq" ] || { [ -z "${_na_lista[$app]:-}" ] && unset '_meus[$app]'; continue; }
  _tem_marca "$arq" || { [ -z "${_na_lista[$app]:-}" ] && unset '_meus[$app]'; continue; }
  if meow_seco; then
    meow_muda "devolveria $app ao lançador"
    mudou=1
    continue
  fi
  if ! meow_desktop_pode "$arq"; then
    sem_root=$((sem_root+1))
    continue
  fi
  novo="$(awk 'ant == "[Desktop Entry]" && $0 == "NoDisplay=true" && !feito { feito = 1; ant = $0; next }
               { print; ant = $0 }' "$arq")"
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou devolvê-lo"
    continue
  fi
  tmp="$(mktemp)"
  printf '%s\n' "$novo" > "$tmp"
  if meow_desktop_escrever "$arq" "$tmp"; then
    mudou=1; devolvidos=$((devolvidos+1)); unset '_meus[$app]'
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done
[ "$devolvidos" -gt 0 ] && meow_muda "$devolvidos aplicativo(s) de volta ao lançador"

# A anotação se grava só fora do ensaio, e só quando muda (o `meow_escrever`
# compara antes): a 2ª passada não escreve nada.
if ! meow_seco; then
  mkdir -p "$MEOW_ESTADO" 2>/dev/null
  meow_escrever "$MARCADOS" "$(printf '%s\n' "${!_meus[@]}" | LC_ALL=C sort | sed '/^$/d')" 644 >/dev/null
fi

if [ "$sem_root" -gt 0 ]; then
  meow_aviso "$sem_root aplicativo(s) precisam de sudo para ocultar"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "aplicativos de sistema já ocultos (${#OCULTAR[@]} na lista de $LANCADOR_OCULTAR_FONTE, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_desktop_banco "$SISTEMA"
meow_ok "aplicativos de sistema ocultos do lançador"
meow_info "vale no próximo início do lançador"
exit "$MEOW_DIVERGENTE"
