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
#
# AS DUPLICATAS SÃO OUTRO PROBLEMA, E SE RESOLVEM PELO MESMO LADO
#   Três aplicativos apareciam DUAS vezes no lançador dela — "(Local)" e
#   "(Sistema)", "(Flatpak)" e "(Sistema)". Não é sujeira: é o COSMIC achando
#   dois `.desktop` de mesmo ID e desambiguando com o sufixo, porque ele não
#   deduplica (a mesma descoberta que fez o ZapZap aparecer em dobro).
#
#   Em todos os três casos a cópia boa é a que NÃO está em `/usr/share`:
#     google-chrome  o override dela liga aceleração de GPU e decode por
#                    hardware (LIBVA_DRIVER_NAME=nvidia + VaapiVideoDecoder). O
#                    do sistema abre o Chrome sem nada disso.
#     steam          o override dela chama o `steam-resiliente.sh`, que cura o
#                    cliente zumbi. O do sistema chama o binário cru.
#     github-desktop o do sistema é de mai/2021 e não recebe update; o Flatpak
#                    (io.github.shiftey.Desktop) é o que ela mantém atualizado.
#
#   Então ocultar a cópia do SISTEMA resolve os três — e é exatamente a mesma
#   operação da lista de cima. `NoDisplay` esconde do lançador e NÃO mexe nos
#   handlers de MIME e de esquema (`steam://`, `x-scheme-handler/https`): esses
#   continuam resolvendo, inclusive pelo arquivo oculto.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

SISTEMA="/usr/share/applications"

# Um por linha, com o porquê ao lado. Só entra o que ela pediu.
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

# As DUPLICATAS. Separadas da lista de cima porque o motivo é outro: aqui o
# aplicativo FICA — o que sai é a segunda cópia dele. Ver o cabeçalho.
# Todos são o arquivo de `/usr/share`; a cópia que ela usa está no home ou no
# Flatpak e continua intocada.
OCULTAR_DUPLICATA=(
  google-chrome             # fica o do home: liga GPU e decode por hardware
  steam                     # fica o do home: passa pelo steam-resiliente.sh
  github-desktop            # fica o Flatpak; este .deb é de mai/2021
)

# Uma lista só para o laço — a divisão acima é para quem lê, não para o código.
OCULTAR+=("${OCULTAR_DUPLICATA[@]}")

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
  # A CÓPIA VEM ANTES DA ESCRITA, SEMPRE. Este arquivo é do apt, e até aqui
  # marcá-lo era uma via de mão única: `dpkg -V` acusava a divergência e não
  # havia de onde voltar. Se não der para guardar, não se escreve — `meow
  # desfazer --lancador` é a contrapartida de mexer em /usr/share.
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou marcá-lo"
    rm -f "$tmp"
    continue
  fi
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
