#!/usr/bin/env bash
# ponte_root.sh — o braço root do MeowSystem, e a razão de a senha ser pedida
# UMA vez.
#
# Fonte-de-verdade: MeowSystem/scripts/ponte_root.sh
# Destino:          /usr/local/lib/meowsystem/ponte_root.sh  (0755, root:root)
# Regra:            /etc/sudoers.d/49-meowsystem-ponte       (0440, root:root)
# Quem instala:     install.sh, `etapa_ponte_root` — e é ele que pede a senha
#
# ============================================================================
# DE ONDE ISTO VEIO
# ============================================================================
# Ela, 08/09/2026: *"não conseguimos de alguma forma usar sudo só na instalar e
# criar um perfil naquele conf.d ... aquele que só preciso uma vez e fica lá
# registrado pra sempre? pode alterar o nosso install pra garantir o máximo de
# conforto pro user nesse sentido?"*
#
# O incômodo era real e media-se: `meow doctor --consertar` recusava consertar
# TRÊS itens (`ocultar`, `absolutos`, `lancadorapt`) com a mesma frase — "o
# conserto usa sudo, e o doctor não usa" —, e os três botões de senha do painel
# não tinham como pedir senha nenhuma, porque o painel roda sem terminal. O
# `full-upgrade` de 08/09 derrubou o hook do apt e o auto-reparo ficou olhando.
#
# ============================================================================
# POR QUE UMA PONTE, E NÃO `NOPASSWD` NOS COMANDOS QUE O PROJETO USA
# ============================================================================
# Porque não existe regra estreita para `install`. O que o projeto precisa é
# escrever `.desktop` em `/usr/share/applications`, e a regra
#
#     vitoriamaria ALL=(root) NOPASSWD: /usr/bin/install -m 644 * *
#
# é `NOPASSWD: ALL` com outro nome: o segundo `*` é qualquer destino, e escrever
# qualquer arquivo como root é ser root. O mesmo vale para `rm`, `cp` e `tee`.
#
# A saída é a que esta máquina JÁ usa para o Bluetooth do Hefesto
# (`/etc/sudoers.d/49-hefesto-bt-ponte`, 22/08/2026): um programa de root que
# implementa um conjunto FECHADO de verbos, com os destinos cravados aqui
# dentro, e uma regra de sudo que libera só ele.
#
# NENHUM VERBO TEM ARGUMENTO, e isso é a parte que fecha a porta. O nome do
# arquivo e o conteúdo entram por STDIN — a mesma disciplina que a ponte do
# Hefesto documenta ("o nome novo do adaptador entra pelo STDIN, não por argv,
# justamente para que não sobre argumento livre a casar"). Com zero argumento,
# a regra de sudo não tem um único curinga, e não há o que forjar.
#
# ============================================================================
# O QUE ESTA PONTE NÃO FAZ, DE PROPÓSITO
# ============================================================================
#   · não se instala nem se atualiza. Trocar o arquivo em `/usr/local/lib` e a
#     regra em `/etc/sudoers.d` continua pedindo a senha, no `install.sh`. Uma
#     ponte que pudesse regravar a si mesma seria uma ponte que qualquer coisa
#     rodando como ela reescreve para fazer outra coisa;
#   · não recebe caminho de origem. Todo destino é literal neste arquivo;
#   · não instala pacote, não chama `apt install`, não roda `.deb`. O
#     `atualizar` é `full-upgrade` dos repositórios já configurados;
#   · não apaga nada fora dos dois caminhos do hook de apt.
#
# O QUE ELA CUSTA, DITO SEM ENFEITE: quem puder rodar comando como a dona da
# máquina passa a poder, sem senha, marcar `.desktop` de sistema, atualizar os
# pacotes e reinstalar o hook do apt. É menos do que `NOPASSWD: ALL` por uma
# margem larga, e é mais do que nada. Desligar é `PONTE_ROOT="nao"` no
# `meow.conf` e `./install.sh` — a etapa então REMOVE a regra e o arquivo.
#
# CÓDIGOS DE SAÍDA: 0 fez · 2 erro · 3 falta condição (o caminho não existe)
set -euo pipefail
umask 022
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

APLICATIVOS=/usr/share/applications
GREETER_HOME=/var/lib/cosmic-greeter
GREETER_CONF="$GREETER_HOME/.config/cosmic"
GREETER_DONO=cosmic-greeter
HOOK=/etc/apt/apt.conf.d/99-meow-lancador
WRAPPER=/usr/local/sbin/meow-lancador-apt.sh
# O PERFIL É GRAVADO PELO INSTALADOR, COM A SENHA, E LIDO AQUI. Ele não vem por
# argumento nem do ambiente: fosse o chamador quem escolhesse a raiz,
# `apt-hook-instalar` viraria "instale como root o script que eu apontar".
#
# São três linhas `chave=valor` — `raiz`, `usuaria` e `lar` — porque o wrapper do
# hook é um MOLDE: ele carrega `@ACERVO@`, `@USUARIA@` e `@LAR@`, e quem os
# substitui tem de ser quem sabe a verdade. O `install.sh` sabe; o chamador sem
# senha, não.
PERFIL=/usr/local/lib/meowsystem/perfil
REGRA=/etc/sudoers.d/49-meowsystem-ponte
PONTE=/usr/local/lib/meowsystem/ponte_root.sh

morrer() { printf 'ponte_root: %s\n' "$1" >&2; exit "${2:-2}"; }

# Todo uso privilegiado deixa rastro. Não é auditoria de verdade — é o mínimo
# para responder "quem mexeu no .desktop do Steam?" sem adivinhação.
anotar() {
  logger -t meowsystem-ponte -p auth.notice -- "$*" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# O nome de um `.desktop`, conferido com a régua mais apertada que ainda serve.
# Sem `/`, sem `..`, sem espaço, sem começar por ponto. E o alvo tem de JÁ
# existir: esta ponte edita arquivo de pacote, nunca cria um.
# ---------------------------------------------------------------------------
conferir_desktop() {
  local nome="$1"
  case "$nome" in
    *[!A-Za-z0-9._+-]*) morrer "nome com caractere proibido" ;;
    .*|*/*|"")          morrer "nome inválido" ;;
    *.desktop)          ;;
    *)                  morrer "o nome tem de terminar em .desktop" ;;
  esac
  [ "${#nome}" -le 128 ] || morrer "nome comprido demais"
  [ -f "$APLICATIVOS/$nome" ] || morrer "$APLICATIVOS/$nome não existe — esta ponte edita, não cria" 3
}

verbo="${1:-}"
[ "$#" -le 1 ] || morrer "esta ponte não aceita argumento — o dado entra por stdin"

case "$verbo" in

# --- .desktop de sistema ---------------------------------------------------
# stdin: primeira linha = o nome do arquivo; o resto = o conteúdo inteiro.
#
# O conteúdo é conferido antes de tocar no disco: tem de ser um Desktop Entry.
# Sem isso, um erro do chamador transformaria um `.desktop` de pacote em lixo, e
# o aplicativo sumiria do lançador sem uma palavra.
desktop)
  IFS= read -r nome || morrer "stdin vazio"
  conferir_desktop "$nome"
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  cat > "$tmp"
  [ -s "$tmp" ] || morrer "conteúdo vazio"
  head -c 4096 "$tmp" | grep -q '^\[Desktop Entry\]' || morrer "isto não é um .desktop"
  if cmp -s "$tmp" "$APLICATIVOS/$nome"; then exit 0; fi   # regra 5: nada a escrever
  install -m 644 -o root -g root "$tmp" "$APLICATIVOS/$nome" || morrer "não consegui escrever"
  anotar "desktop $nome"
  ;;

desktop-banco)
  command -v update-desktop-database >/dev/null 2>&1 || exit 0
  update-desktop-database "$APLICATIVOS" 2>/dev/null || true
  ;;

# --- a tela de login -------------------------------------------------------
# `greeter-ver` imprime `<md5>  <caminho relativo>` de tudo que existe hoje, numa
# chamada só. O `greeter.sh` fazia três `sudo` POR ARQUIVO numa árvore de ~190;
# aqui é um processo, e a comparação continua sendo por conteúdo.
greeter-ver)
  [ -d "$GREETER_CONF" ] || exit 3
  cd "$GREETER_CONF" || exit 3
  find . -mindepth 1 -type f -printf '%P\n' | sort | while IFS= read -r rel; do
    printf '%s  %s\n' "$(md5sum < "$rel" | cut -d' ' -f1)" "$rel"
  done
  ;;

# stdin: um tar. Extrai dentro do `.config/cosmic` do greeter, com o dono certo.
# `--no-absolute-names` e a recusa de `..` são o que impede o tar de escrever
# fora do destino — é o buraco clássico deste formato.
greeter-aplicar)
  [ -d "$GREETER_HOME" ] || exit 3
  id "$GREETER_DONO" >/dev/null 2>&1 || morrer "o usuário $GREETER_DONO não existe" 3
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  tar -x -C "$tmp" --no-absolute-names --no-same-owner -f - || morrer "tar recusado"
  ( cd "$tmp" && find . -mindepth 1 -printf '%P\n' ) | while IFS= read -r rel; do
    case "$rel" in ..*|*/../*|*/..) morrer "caminho com .. no tar" ;; esac
  done
  mkdir -p "$GREETER_CONF"
  cp -a "$tmp/." "$GREETER_CONF/"
  chown -R "$GREETER_DONO:$GREETER_DONO" "$GREETER_HOME/.config"
  chmod -R u=rwX,go= "$GREETER_HOME/.config"
  anotar "greeter-aplicar"
  ;;

# --- o hook de apt do lançador ---------------------------------------------
# A origem NÃO vem do chamador: vem do arquivo que o instalador gravou como
# root. Ver o comentário do `PERFIL`.
apt-hook-instalar)
  [ -r "$PERFIL" ] || morrer "o perfil não foi registrado — rode ./install.sh" 3
  raiz=""; usuaria=""; lar=""
  # `|| [ -n "$chave" ]` NÃO É DEFENSIVA À TOA: um arquivo sem `\n` na última
  # linha faz o `read` devolver 1 no fim, e o `while` descarta a linha que ele
  # ACABOU de ler. Medido em 08/09/2026 — o `perfil` era gravado com
  # `printf '%s'` (a substituição de comando come o `\n` final), o `lar` nunca
  # era atribuído, e a ponte recusava repor o hook do apt dizendo "lar inválido".
  # O gravador foi corrigido junto; esta linha é para o dia em que outro
  # gravador esquecer.
  while IFS='=' read -r chave valor || [ -n "${chave:-}" ]; do
    case "$chave" in raiz) raiz="$valor" ;; usuaria) usuaria="$valor" ;; lar) lar="$valor" ;; esac
    chave=""
  done < "$PERFIL"
  case "$raiz" in /*) ;; *) morrer "raiz inválida no perfil" ;; esac
  case "$lar"  in /*) ;; *) morrer "lar inválido no perfil" ;; esac
  case "$usuaria" in ''|*[!a-z0-9._-]*) morrer "usuária inválida no perfil" ;; esac
  fonte_w="$raiz/scripts/meow-lancador-apt.sh"
  fonte_h="$raiz/scripts/99-meow-lancador"
  [ -f "$fonte_w" ] && [ -f "$fonte_h" ] || morrer "não achei os arquivos do hook em $raiz" 3
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  # O MESMO MOLDE QUE O `install.sh` PREENCHE, com os mesmos três valores — e
  # eles vêm do perfil, não do ambiente. Fazer diferente aqui produziria dois
  # wrappers possíveis para o mesmo arquivo, e a etapa nunca convergiria.
  sed -e "s|@ACERVO@|$raiz|g" -e "s|@USUARIA@|$usuaria|g" -e "s|@LAR@|$lar|g" \
      "$fonte_w" > "$tmp" || morrer "não consegui preencher o molde"
  install -m 755 -o root -g root "$tmp" "$WRAPPER" || morrer "não consegui instalar o wrapper"
  # O hook vai por ÚLTIMO: enquanto ele não existe, nada chama o wrapper. Na
  # ordem inversa haveria uma janela — curta, mas real — em que um apt disparado
  # nesse instante chamaria um caminho que ainda não existe. Mesma ordem do
  # `etapa_lancador_apt`, e pelo mesmo motivo.
  install -m 644 -o root -g root "$fonte_h" "$HOOK" || morrer "não consegui instalar o hook"
  anotar "apt-hook-instalar de $raiz"
  ;;

apt-hook-remover)
  rm -f "$HOOK" "$WRAPPER"
  anotar "apt-hook-remover"
  ;;

# --- a máquina em dia ------------------------------------------------------
# `full-upgrade` dos repositórios JÁ configurados. Esta ponte não acrescenta
# repositório, não instala pacote por nome e não roda `.deb`.
atualizar)
  export DEBIAN_FRONTEND=noninteractive
  anotar "atualizar"
  apt update || exit 2
  apt full-upgrade -y -o Dpkg::Options::=--force-confold || exit 2
  ;;

limpar)
  export DEBIAN_FRONTEND=noninteractive
  anotar "limpar"
  apt autoclean -y || true
  apt autoremove -y -o Dpkg::Options::=--force-confold || true
  apt clean || true
  ;;

# --- diagnóstico e a própria regra -----------------------------------------
# `estado` é o que o `meow doctor` chama. Ele não escreve nada e não é
# privilegiado de verdade — mas mora aqui para a resposta vir de DENTRO da
# ponte instalada, e não de uma suposição sobre ela.
estado)
  printf 'ponte=%s\n' "$([ -x "$PONTE" ] && echo sim || echo nao)"
  printf 'regra=%s\n' "$([ -f "$REGRA" ] && echo sim || echo nao)"
  # O md5 DA REGRA, e ele existe por um motivo prático: o `etapa_ponte_root` do
  # instalador precisa saber se o arquivo em /etc já é o desejado, e a regra é
  # 0440 root:root — ela não tem como ler. Sem isto a etapa comparava com
  # `sudo -n cat`, que NÃO está na regra: com o cache do sudo frio a leitura
  # voltava vazia, a etapa concluía "diverge" e pedia senha numa máquina que já
  # estava pronta. Medido em 08/09/2026 rodando o instalador como o painel o
  # roda, sem terminal: "a ponte fica de fora" numa ponte instalada e correta.
  printf 'regra_md5=%s\n' "$(md5sum < "$REGRA" 2>/dev/null | cut -d' ' -f1)"
  printf 'perfil=%s\n' "$([ -r "$PERFIL" ] && echo sim || echo nao)"
  printf 'raiz=%s\n'  "$(sed -n 's/^raiz=//p' "$PERFIL" 2>/dev/null || printf '(nenhuma)')"
  printf 'hook=%s\n'  "$([ -f "$HOOK" ] && [ -x "$WRAPPER" ] && echo sim || echo nao)"
  printf 'versao=%s\n' "$(md5sum < "$PONTE" 2>/dev/null | cut -d' ' -f1)"
  ;;

# A REGRA É IMPRESSA AQUI E ESCRITA PELO INSTALADOR, e essa separação é o
# ponto: quem escreve em `/etc/sudoers.d` é o `install.sh`, com a senha na mão.
# A ponte só sabe DIZER qual é a regra dela — assim o texto mora junto do
# programa que ele descreve, e não pode divergir dele.
#
# O usuário vem do ambiente (`SUDO_USER` quando isto roda por sudo, `USER`
# quando roda direto) porque um nome vindo de argumento seria o único argumento
# livre da ponte inteira, e ele estaria justamente na linha que decide QUEM
# ganha a regra.
regra-sudo)
  quem="${SUDO_USER:-${USER:-}}"
  case "$quem" in
    ''|root)            morrer "não sei para quem escrever a regra" ;;
    *[!a-z0-9._-]*)     morrer "nome de usuário inesperado" ;;
  esac
  cat <<REGRA_FIM
# /etc/sudoers.d/49-meowsystem-ponte — gerado por
# $PONTE regra-sudo
#
# O braço root do MeowSystem (decisão dela, 08/09/2026: "usar sudo só na
# instalação e criar um perfil naquele conf.d"). NÃO editar à mão: o install
# regrava, e \`PONTE_ROOT="nao"\` no meow.conf apaga.
#
# A regra é estreita de propósito: caminho absoluto, verbos nomeados um a um, e
# NENHUM curinga — porque nenhum verbo da ponte aceita argumento. O nome do
# arquivo e o conteúdo entram pelo STDIN, exatamente como na ponte do Hefesto ao
# lado, para que não sobre argumento livre a casar aqui.
Cmnd_Alias MEOWSYSTEM_PONTE = \\
    $PONTE desktop, \\
    $PONTE desktop-banco, \\
    $PONTE greeter-ver, \\
    $PONTE greeter-aplicar, \\
    $PONTE apt-hook-instalar, \\
    $PONTE apt-hook-remover, \\
    $PONTE atualizar, \\
    $PONTE limpar, \\
    $PONTE estado

$quem ALL=(root) NOPASSWD: MEOWSYSTEM_PONTE
REGRA_FIM
  ;;

''|-h|--help|ajuda)
  sed -n '2,60p' "$0"
  printf '\nverbos: desktop · desktop-banco · greeter-ver · greeter-aplicar ·\n'
  printf '        apt-hook-instalar · apt-hook-remover · atualizar · limpar ·\n'
  printf '        estado · regra-sudo\n'
  ;;

*) morrer "verbo desconhecido: $verbo" ;;
esac
exit 0
