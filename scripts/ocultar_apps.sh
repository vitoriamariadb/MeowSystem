#!/usr/bin/env bash
# ocultar_apps.sh — some com os aplicativos que ela nunca vai abrir.
#
# O QUE ELA VÊ HOJE, E POR QUE
#   O lançador mostra Vim, XTerm, UXTerm, qt5ct, ImageMagick, TeXInfo — coisas que
#   são dependência de outro pacote, não aplicativo que se abre. O Ritual da Aurora
#   já tentou escondê-los, e o comentário lá diz o motivo da tentativa:
#       "Overrides em ~/.local/share/applications têm prioridade sobre /usr/share."
#
#   ESSA PREMISSA É FALSA NO COSMIC — medido em 2026-08-04. O
#   `~/.local/share/applications/vim.desktop` tem `NoDisplay=true` E `Hidden=true`
#   desde 03/08, e o Vim continua no lançador. O `cosmic-app-library` NÃO
#   deduplica por ID: ele varre todos os diretórios de `applications`, pula o
#   arquivo que tem `NoDisplay`, e mostra o outro assim mesmo. Foi a mesma
#   descoberta que fez o ZapZap aparecer duas vezes.
#
#   Prova pelo lado oposto: Chrome e Steam têm `.desktop` de mesmo nome no home E
#   em /usr/share, e o COSMIC mostra OS DOIS, desambiguando com "(Local)" e
#   "(Sistema)" — os parênteses que ela viu. Não é sujeira dela: é o COSMIC
#   avisando que achou dois.
#
# ENTÃO A ÚNICA COISA QUE FUNCIONA É MARCAR O ARQUIVO DO SISTEMA
#   `NoDisplay=true` no próprio `/usr/share/applications/<app>.desktop`. Isso é
#   território do apt: um `apt upgrade` do pacote devolve o arquivo original e o
#   aplicativo reaparece. Por isso este script é idempotente e roda no `install.sh`
#   e no `meow doctor` — reaparecer é esperado, ficar assim não.
#
# POR QUE NÃO DESINSTALAR
#   Quase nenhum deles é removível. `xterm` é dependência de `xinit` e das
#   bibliotecas da Steam; `vim-tiny`/`vim-common` são seed do Ubuntu; o
#   ImageMagick é o `convert` que ESTE projeto usa para montar ícone. Ocultar é o
#   que dá para fazer sem quebrar coisa boa.
#
# A LISTA É CURTA E EXPLÍCITA, de propósito
#   Nada de heurística do tipo "esconde tudo que for Categories=System". Cada
#   linha aqui é uma decisão dela, e o dia em que ela quiser um de volta é uma
#   linha a remover.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

SISTEMA="/usr/share/applications"

# Um por linha, com o porquê ao lado. Só entra o que ela pediu.
OCULTAR=(
  vim                       # editor de terminal; dependência, não aplicativo
  debian-xterm              # dependência de xinit e das bibliotecas da Steam
  debian-uxterm             # idem
  qt5ct                     # painel de tema Qt: os apps Qt dela são flatpak
  qt6ct                     # idem
  display-im6.q16           # ImageMagick: é o `convert`, não um visualizador
  info                      # TeXInfo, leitor de manual do GNU
  im-config                 # configurador de método de entrada (ibus e cia)
  ibus-setup                # idem
  org.gnome.font-viewer     # visualizador de fontes
  gnome-language-selector   # suporte a idiomas
  system-config-printer     # impressoras: o COSMIC tem a própria página
)

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

  if [ ! -w "$arq" ] && ! sudo -n true 2>/dev/null; then
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
  if sudo install -m 644 "$tmp" "$arq" 2>/dev/null; then
    mudou=1
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done

if [ "$sem_root" -gt 0 ]; then
  meow_aviso "$sem_root aplicativo(s) precisam de sudo para ocultar"
  meow_info "rode o install.sh de novo com sudo disponível"
fi

if [ "$mudou" = "0" ]; then
  meow_ok "aplicativos de sistema já ocultos (${#OCULTAR[@]} na lista, $ausentes não instalados)"
  exit "$MEOW_OK"
fi

meow_seco && exit "$MEOW_DIVERGENTE"

meow_tem update-desktop-database && sudo update-desktop-database "$SISTEMA" 2>/dev/null || true
meow_ok "aplicativos de sistema ocultos do lançador"
meow_info "vale no próximo início do lançador"
exit "$MEOW_DIVERGENTE"
