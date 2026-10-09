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
#   ONDE MORA A CÓPIA BOA MUDOU EM 13/08/2026 (chrome e steam)
#   Ela saiu de `~/.local/share/applications` e foi para
#   `/usr/local/share/applications`, e a causa é a MESMA descoberta do cabeçalho
#   deste arquivo, aplicada ao `Exec=` em vez do `NoDisplay`: o COSMIC não honra
#   `$XDG_DATA_HOME`. O arquivo do home estava correto no disco e o dock subia o
#   Chrome PELADO assim mesmo — medido no processo vivo, `/proc/PID/environ` sem
#   `LIBVA_DRIVER_NAME`. O que ele honra é o `XDG_DATA_DIRS`, e ali
#   `/usr/local/share` vem antes de `/usr/share`.
#
#   Some-se a isso o fato, já anotado acima, de que o `cosmic-app-library` NÃO
#   deduplica: manter o arquivo no home E em /usr/local dava DUAS entradas de
#   Chrome no lançador. Por isso é um lugar só, e o Aurora recolhe a cópia do
#   home. Detalhes em `docs/FRONTEIRA.md`.
#
#   Para ESTE script nada muda no mecanismo: marcar `NoDisplay=true` no arquivo
#   de `/usr/share` continua sendo a única coisa que esconde app.
#
#   Então ocultar a cópia do SISTEMA resolve os três — e é exatamente a mesma
#   operação da lista de cima. `NoDisplay` esconde do lançador e NÃO mexe nos
#   handlers de MIME e de esquema (`steam://`, `x-scheme-handler/https`): esses
#   continuam resolvendo, inclusive pelo arquivo oculto.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

# A pasta do sistema vem de fora só para o teste (P74): o `tests/` monta uma de
# brinquedo, e nada aqui escreve no /usr/share de verdade num teste.
SISTEMA="${MEOW_APLICATIVOS_SISTEMA:-/usr/share/applications}"

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
# Todos são o arquivo de `/usr/share`; a cópia que ela usa está em
# `/usr/local/share/applications` (chrome, steam — desde 13/08/2026) ou no
# Flatpak, e continua intocada.
OCULTAR_DUPLICATA=(
  google-chrome             # fica o de /usr/local/share: liga GPU e decode por hardware
  steam                     # fica o de /usr/local/share: passa pelo steam-resiliente.sh
  github-desktop            # fica o Flatpak; este .deb é de mai/2021
)

# Uma lista só para o laço — a divisão acima é para quem lê, não para o código.
OCULTAR+=("${OCULTAR_DUPLICATA[@]}")

# A LISTA DE FÁBRICA PASSA A TER UMA PORTA — 21/09/2026
#   As 32 linhas acima são o gosto de UMA máquina, e o `meow.conf.exemplo` já
#   dizia isso com todas as letras na chave `LANCADOR_SISTEMA`: "a lista de
#   nomes em `scripts/ocultar_apps.sh` é o gosto de quem escreveu, não o seu".
#   Dizer e não oferecer saída é a armadilha nº 3 do projeto — uma lista fechada
#   que só se muda editando código versionado, num arquivo que o `git pull` do
#   dia seguinte sobrescreve.
#
#   Quem NÃO tem aqueles aplicativos não perdia nada (o laço pula o `.desktop`
#   que não existe); quem tem OUTROS é que não tinha como dizer. Agora tem.
#
#   A CHAVE SUBSTITUI, NÃO ACRESCENTA, e isso é deliberado: esconder aplicativo
#   é mexer em `/usr/share` com sudo, e a única lista honesta é a que a pessoa
#   consegue ler inteira numa linha do conf dela. Uma chave que só ACRESCENTA
#   deixaria as 32 de fábrica invisíveis e impossíveis de tirar — e tirar uma é
#   metade do motivo de a chave existir. O valor de fábrica está escrito no
#   `meow.conf.exemplo`, então mexer nele é apagar um nome, não redigitar 32.
#
#   Vazia ou ausente, vale a lista daqui: um `meow.conf` escrito antes desta
#   chave existir continua se comportando exatamente como se comportava.
#
#   "VAZIA" É DEPOIS DE APARAR, E NÃO ANTES — corrigido em 21/09/2026
#   O primeiro desenho decidia pela lista de fábrica com um `[ -n ]` na chave
#   CRUA. Bastava `LANCADOR_OCULTAR=" "` — um espaço, ou uma vírgula solta —
#   para o teste dar verdadeiro, o laço descartar tudo o que aparou, e sobrar
#   uma lista VAZIA: zero aplicativo escondido, com o placar dizendo "0 na
#   lista de meow.conf" como se fosse escolha. O texto do conf promete que
#   "apagar a linha inteira (ou deixá-la vazia) devolve a lista de fábrica", e
#   uma linha com um espaço é uma linha vazia para qualquer pessoa que a leia.
#
#   Daí o array à parte: a lista da conf só SUBSTITUI a de fábrica depois de
#   provar que sobrou nome nela. Enquanto o `OCULTAR=()` vinha antes do laço,
#   não havia para onde voltar.
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
    # `-nome` é «este não», para os que o pack esconde (P74, logo abaixo).
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

# O QUE O PACK ESCONDE ENTRA SOMADO — 09/10/2026, P74 item 9 (T5)
#   O pack no ar declara a lista dele (`lancador.ocultar`, os overrides de
#   `.desktop` que o tema Dracula de antes trazia), e ela se SOMA à do conf: a
#   chave do conf é escrita por quem instala e vem com os 32 de fábrica, então
#   uma lista do pack que só valesse com a chave vazia não valeria em lugar
#   nenhum. Tirar um nome do pack é escrevê-lo com `-` na frente, no conf — a
#   mesma linha que a pessoa já lê inteira. Nome repetido entra uma vez.
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
  # A CÓPIA VEM ANTES DA ESCRITA, SEMPRE. Este arquivo é do apt, e até aqui
  # marcá-lo era uma via de mão única: `dpkg -V` acusava a divergência e não
  # havia de onde voltar. Se não der para guardar, não se escreve — `meow
  # desfazer --lancador` é a contrapartida de mexer em /usr/share.
  if ! meow_backup_sistema "$arq"; then
    meow_aviso "não consegui guardar cópia de $arq — não vou marcá-lo"
    rm -f "$tmp"
    continue
  fi
  if meow_desktop_escrever "$arq" "$tmp"; then
    mudou=1
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done

# O «-nome» DEVOLVE O QUE JÁ ESTAVA ESCONDIDO — conferência da P74, 09/10/2026
#   Sem isto o `-nome` só impedia de esconder: um app que uma passada anterior
#   já tinha marcado (o pack Dracula esconde o `mpv`, por exemplo) continuava
#   fora do lançador, e a frase do meow.conf.exemplo («para manter um deles à
#   vista, escreva `-nome`») não era verdade. Desfaz-se só a marca na forma que
#   este script escreve — a linha `NoDisplay=true` logo depois de
#   `[Desktop Entry]` — e só nos nomes que a pessoa pediu com `-`. A cópia vem
#   antes da escrita, como acima.
devolvidos=0
for app in ${_fora[@]+"${_fora[@]}"}; do
  arq="$SISTEMA/$app.desktop"
  [ -f "$arq" ] || continue
  awk 'ant == "[Desktop Entry]" && $0 == "NoDisplay=true" { achou = 1 } { ant = $0 } END { exit !achou }' "$arq" \
    || continue
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
    mudou=1; devolvidos=$((devolvidos+1))
  else
    sem_root=$((sem_root+1))
  fi
  rm -f "$tmp"
done
[ "$devolvidos" -gt 0 ] && meow_muda "$devolvidos aplicativo(s) de volta ao lançador, pelo «-nome» do LANCADOR_OCULTAR"

if [ "$sem_root" -gt 0 ]; then
  meow_aviso "$sem_root aplicativo(s) precisam de sudo para ocultar"
  meow_info "rode o install.sh de novo com sudo disponível"
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
