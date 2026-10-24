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
#     <usuário> ALL=(root) NOPASSWD: /usr/bin/install -m 644 * *
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
#   · não instala pacote por nome livre e não roda `.deb`. O `atualizar` é
#     `full-upgrade` dos repositórios já configurados, e o `pacotes` (P75,
#     09/10/2026) instala só nomes de uma lista LITERAL aqui dentro — ver o
#     bloco dele;
#   · não apaga nada fora dos dois caminhos do hook de apt e do da completion
#     do zsh (este desde a P47, 24/09/2026), das três chaves de tema do
#     override global do Flatpak que apontam para tema que não existe, e dos
#     pacotes `libreoffice*` que o dpkg diz estarem instalados (com a ponte UNO
#     que sai junto com eles).
#
# O QUE ELA CUSTA, DITO SEM ENFEITE: quem puder rodar comando como a dona da
# máquina passa a poder, sem senha, marcar `.desktop` de sistema, atualizar os
# pacotes, reinstalar o hook do apt e pôr no `fpath` de fábrica do zsh a
# completion do `meow` que estiver no clone registrado — que o zsh de QUALQUER
# usuário carrega quando completa `meow` (P47; a conferência do verbo aceita só
# arquivo que começa por `#compdef meow`, e o preço está escrito lá). É menos do
# que `NOPASSWD: ALL` por uma margem larga, e é mais do que nada. Desligar é
# `PONTE_ROOT="nao"` no `meow.conf` e `./install.sh` — a etapa então REMOVE a
# regra e o arquivo.
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
# O primeiro diretório do `fpath` de fábrica do zsh desta distribuição
# (`zsh -f -c 'print -l $fpath'`, medido em 24/09/2026) — ver `completion-instalar`.
COMPLETION=/usr/local/share/zsh/site-functions/_meow
REGRA=/etc/sudoers.d/49-meowsystem-ponte
PONTE=/usr/local/lib/meowsystem/ponte_root.sh
FLATPAK_GLOBAL=/var/lib/flatpak/overrides/global
USR_SHARE=/usr/share

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

# O que é do LibreOffice e não começa por `libreoffice`: a ponte UNO, que depende
# do `libreoffice-core` e sai com ele. É a lista que o `purge` pode levar junto e
# que a volta aceita.
do_libreoffice() {
  case "$1" in
    libreoffice*|python3-uno|ure|ure-java|uno-libs-private|libuno-*|libunoloader-java) return 0 ;;
  esac
  return 1
}

# Os `libreoffice*` instalados (ou só com a configuração que sobrou), um por linha.
libreoffice_instalados() {
  dpkg-query -W -f='${db:Status-Abbrev} ${Package}\n' 'libreoffice*' 2>/dev/null \
    | awk '$1 ~ /^.[ic]/ && $2 ~ /^libreoffice/ { print $2 }'
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
# O que impede o tar de escrever fora do destino — o buraco clássico deste
# formato — é o padrão do GNU tar (tira a `/` do começo e recusa membro com
# `..`), a extração num temporário, a recusa de `..` e de link simbólico no que
# saiu dele, e só então a cópia.
#
# O `--no-absolute-names` QUE MORAVA AQUI NÃO EXISTE — P75, 09/10/2026 (S4)
#   O GNU tar tem `-P/--absolute-names` e não tem a forma negativa: medido com o
#   tar 1.35 desta máquina, `tar -x --no-absolute-names` sai 64 com "opção
#   desconhecida". Este verbo recusou TODA chamada desde que nasceu, com a
#   frase "tar recusado", e o `greeter.sh` mandava essa frase para o
#   `/dev/null` — a tela de login "precisava de sudo" numa máquina com a ponte
#   no ar, e ninguém sabia por quê (01-regressoes.md, S4; P70 item 1). O que a
#   flag pretendia, o padrão do tar já faz; o link simbólico, que ela nem
#   cobria, passa a ser recusado abaixo.
greeter-aplicar)
  [ -d "$GREETER_HOME" ] || exit 3
  id "$GREETER_DONO" >/dev/null 2>&1 || morrer "o usuário $GREETER_DONO não existe" 3
  tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
  tar -x -C "$tmp" --no-same-owner -f - || morrer "tar recusado: o que chegou pelo stdin não se extrai"
  [ -z "$(find "$tmp" -mindepth 1 -type l -print -quit)" ] || morrer "link simbólico no tar"
  # O `..` FORA DO CANO, E O LINK DO DESTINO — 15/10/2026, P82 (item 16)
  #   A recusa de `..` morava num `| while`, e o `morrer` dali saía só do
  #   subshell do cano: o verbo seguia para a cópia. Agora é uma pergunta só,
  #   antes da cópia, na casca principal.
  #   E o `cp -a` do GNU escreve ATRAVÉS de um link simbólico que já esteja no
  #   destino (medido: o alvo de fora recebe o conteúdo e o `cp` sai 0). O
  #   tar sem link não basta; um link no lar do greeter, de qualquer origem,
  #   recusa o verbo inteiro antes de qualquer escrita.
  if ( cd "$tmp" && find . -mindepth 1 -printf '%P\n' ) | grep -qE '(^|/)\.\.(/|$)'; then
    morrer "caminho com .. no tar"
  fi
  for alvo in "$GREETER_HOME/.config" "$GREETER_CONF"; do
    [ ! -L "$alvo" ] || morrer "link simbólico no destino: $alvo"
  done
  if [ -d "$GREETER_CONF" ] && [ -n "$(find "$GREETER_CONF" -mindepth 1 -type l -print -quit)" ]; then
    morrer "link simbólico no destino, dentro de $GREETER_CONF"
  fi
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
  [ -r "$PERFIL" ] || morrer "o perfil não foi registrado: o «Instalar tudo» o registra" 3
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

# --- a completion do zsh -----------------------------------------------------
# POR QUE ELA ENTROU NA PONTE — 24/09/2026 (P47)
#   O zsh só procura completion no `fpath`, e o de fábrica desta distribuição
#   começa em `/usr/local/share/zsh/site-functions`. A P44 pôs o `_meow` em
#   `~/.local/share/zsh/site-functions`, que não está nele: medido no zsh
#   interativo dela, `whence -w _meow` respondia `none` e o TAB não completava.
#   Pôr o diretório no `fpath` seria editar o `.zshrc` de alguém; pôr o arquivo
#   onde o zsh JÁ procura é root, e root sem senha é esta ponte.
#
# A ORIGEM VEM DO PERFIL, como no `apt-hook-instalar`: a `raiz` que o
#   instalador gravou como root. O chamador não escolhe arquivo nenhum.
#
# O QUE SE CONFERE, E POR QUE NA CÓPIA: o clone é gravável por quem chama, e o
#   que ele contém vira código que o zsh de todo usuário carrega ao completar
#   `meow`. A ponte não tem como julgar o código; ela garante o que dá para
#   garantir — que o arquivo é a completion do `meow` (primeira linha
#   `#compdef meow`, até 64 KiB; a de hoje tem 9) e que o que se conferiu é o
#   que se instala: o arquivo é lido UMA vez, para um temporário, e tudo
#   depois disso olha o temporário. Um symlink trocado no meio do caminho não
#   tem como pôr outra coisa lá. O diretório de destino é do pacote do zsh, e
#   esta ponte não cria diretório de sistema: sem ele, 3.
completion-instalar)
  [ -d "${COMPLETION%/*}" ] || morrer "${COMPLETION%/*} não existe" 3
  [ -r "$PERFIL" ] || morrer "o perfil não foi registrado: o «Instalar tudo» o registra" 3
  raiz="$(sed -n 's/^raiz=//p' "$PERFIL" | head -n1)"
  case "$raiz" in /*) ;; *) morrer "raiz inválida no perfil" ;; esac
  fonte="$raiz/assets/zsh/_meow"
  [ -f "$fonte" ] || morrer "não achei $fonte" 3
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
  head -c 65537 "$fonte" > "$tmp" || morrer "não consegui ler $fonte"
  [ "$(stat -c %s "$tmp")" -le 65536 ] || morrer "$fonte é grande demais para uma completion"
  [ "$(head -n1 "$tmp")" = "#compdef meow" ] || morrer "$fonte não começa por #compdef meow"
  if cmp -s "$tmp" "$COMPLETION"; then exit 0; fi   # regra 5: nada a escrever
  install -m 644 -o root -g root "$tmp" "$COMPLETION" || morrer "não consegui instalar $COMPLETION"
  anotar "completion-instalar de $raiz"
  ;;

# O `--uninstall` a tira, e tira pela ponte ANTES de a ponte sair — é a ordem
# de `lib/desinstalar.sh`. Caminho literal, como o do hook.
completion-remover)
  rm -f "$COMPLETION"
  anotar "completion-remover"
  ;;

# --- o override global do Flatpak --------------------------------------------
# O NitroKit pôs `ICON_THEME`, `GTK_THEME` e `XCURSOR_THEME` no override do
# SISTEMA, apontando para temas que a máquina pode já não ter. O dado entra por
# stdin, `CHAVE=valor` por linha, e só passa a chave das três com o valor que o
# arquivo tem de fato e cujo tema não existe em /usr/share nem no lar do perfil:
# o tema que existe fica. Só essas linhas saem; o resto do arquivo é preservado.
flatpak-global-limpar)
  [ -f "$FLATPAK_GLOBAL" ] || exit 0
  lar=""
  [ -r "$PERFIL" ] && lar="$(sed -n 's/^lar=//p' "$PERFIL" | head -n1)"
  case "$lar" in ''|/*) ;; *) morrer "lar inválido no perfil" ;; esac
  tmp="$(mktemp)"; pedidos="$(mktemp)"; trap 'rm -f "$tmp" "$pedidos"' EXIT
  while IFS= read -r linha || [ -n "${linha:-}" ]; do
    [ -n "$linha" ] || continue
    chave="${linha%%=*}"; valor="${linha#*=}"
    case "$chave" in ICON_THEME|XCURSOR_THEME|GTK_THEME) ;; *) morrer "chave fora da lista desta ponte: $chave" ;; esac
    case "$valor" in ''|.*|*[!A-Za-z0-9._+-]*) morrer "nome de tema inválido" ;; esac
    [ "${#valor}" -le 128 ] || morrer "nome de tema comprido demais"
    grep -qxF -- "$chave=$valor" "$FLATPAK_GLOBAL" || continue
    existe=0
    for raiz in "$USR_SHARE/icons" "$USR_SHARE/themes" \
                ${lar:+"$lar/.local/share/icons" "$lar/.local/share/themes" "$lar/.icons" "$lar/.themes"}; do
      [ -d "$raiz/$valor" ] && existe=1
    done
    [ "$existe" = "1" ] || printf '%s=%s\n' "$chave" "$valor" >> "$pedidos"
  done
  [ -s "$pedidos" ] || exit 0
  # O grupo que ficou sem chave sai junto: um `[Environment]` vazio é lixo.
  { grep -vxF -f "$pedidos" "$FLATPAK_GLOBAL" || true; } | awk '
    function solta() { if (cab != "" && n > 0) printf "%s", buf; cab = ""; buf = ""; n = 0 }
    /^\[/ { solta(); cab = $0; buf = $0 "\n"; next }
    cab == "" { print; next }
    NF { buf = buf $0 "\n"; n++; next }
    { buf = buf "\n" }
    END { solta() }' > "$tmp"
  if grep -q . "$tmp"; then
    install -m 644 -o root -g root "$tmp" "$FLATPAK_GLOBAL" || morrer "não consegui escrever $FLATPAK_GLOBAL"
  else
    rm -f "$FLATPAK_GLOBAL"
  fi
  anotar "flatpak-global-limpar $(tr '\n' ' ' < "$pedidos")"
  ;;

# --- o LibreOffice sai (o escritório é o OnlyOffice) --------------------------
# `libreoffice-remover` não recebe nada: a lista é a que o dpkg dá para
# `libreoffice*` AGORA. Antes do `purge` o apt simula (no purge a linha é `Purg`,
# não `Remv`), e se levaria junto o que não é do LibreOffice o verbo recusa
# inteiro. O stdout é a lista do que sai, para a volta; a fala do apt vai ao stderr.
libreoffice-remover)
  mapfile -t pacotes < <(libreoffice_instalados)
  [ "${#pacotes[@]}" -gt 0 ] || exit 0
  export DEBIAN_FRONTEND=noninteractive
  simulado="$(apt-get -s purge "${pacotes[@]}" 2>/dev/null)" || morrer "o apt não simulou a remoção"
  mapfile -t saem < <(printf '%s\n' "$simulado" | awk '/^(Purg|Remv) / { sub(/:.*/, "", $2); print $2 }')
  outros=""
  for p in "${saem[@]}"; do do_libreoffice "$p" || outros+="$p "; done
  [ -z "$outros" ] || morrer "o apt tiraria junto o que não é do LibreOffice ($outros): não toco em nada"
  anotar "libreoffice-remover ${#saem[@]} pacotes"
  printf '%s\n' "${pacotes[@]}" "${saem[@]}" | sort -u
  apt-get purge -y "${pacotes[@]}" >&2 || exit 2
  ;;

# `libreoffice-devolver` é a volta, para o desinstalador: os nomes entram por
# stdin, um por linha, e só passa o que é do LibreOffice com os caracteres de
# um nome de pacote. Um nome fora derruba o verbo antes do apt.
libreoffice-devolver)
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
    [ -n "$nome" ] || continue
    case "$nome" in *[!a-z0-9.+-]*) morrer "nome de pacote inválido" ;; esac
    do_libreoffice "$nome" || morrer "pacote fora do LibreOffice: $nome"
    pedidos+=("$nome")
  done
  [ "${#pedidos[@]}" -gt 0 ] || morrer "stdin vazio"
  export DEBIAN_FRONTEND=noninteractive
  anotar "libreoffice-devolver ${#pedidos[@]} pacotes"
  apt-get install -y --no-install-recommends "${pedidos[@]}" || exit 2
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

# --- os pacotes de que o projeto depende — P75, 09/10/2026 -----------------
# POR QUE ESTE VERBO NASCEU
#   Ela, 21/09/2026, três vezes: «nenhuma feature pode mandar o usuário
#   consertar à mão». O `meow doctor` sabia que faltava o Papirus, sabia o
#   pacote, e imprimia `sudo apt install papirus-icon-theme` para ela copiar —
#   o conserto conhecido devolvido como tarefa. O `tests/sem-receita-no-log.sh`
#   isentava a frase com a promessa "o dia em que a ponte ganhar um verbo de
#   pacote, estas viram botão". É hoje.
#
# POR QUE ISTO NÃO É `apt install` LIVRE
#   O nome entra por STDIN, um por linha, e só passa o que estiver na lista
#   LITERAL abaixo — que mora neste arquivo, instalado como root, e não no
#   clone, que é gravável por quem chama. Um nome fora dela derruba o verbo
#   inteiro antes de qualquer `apt`: nada se instala pela metade. Os nomes são
#   os do `etapa_pacotes` do install.sh (o array `NECESSARIOS` mais os dois que
#   moram fora dele), e o `tests/doctor-veredito.sh` cobra que as duas listas
#   sejam a mesma: uma cópia que envelhece calada é a armadilha nº 3.
#
# O QUE ELE CUSTA: quem rodar como a dona da máquina instala, sem senha, um
#   destes treze pacotes dos repositórios já configurados. Nada além deles.
#   [P82, 15/10/2026: `curl`, `xz-utils`, `unzip` e `pop-fonts` entraram — o
#   `instalar_fontes.sh` os nomeava como faltando e não tinha a quem pedir.]
pacotes)
  PERMITIDOS=" librsvg2-bin imagemagick libgtk-3-bin python3 git btop bat papirus-icon-theme python3-numpy curl xz-utils unzip pop-fonts build-essential pkg-config libxkbcommon-dev libwayland-dev libdbus-1-dev software-properties-common "
  pedidos=()
  while IFS= read -r nome || [ -n "${nome:-}" ]; do
    [ -n "$nome" ] || continue
    case "$PERMITIDOS" in
      *" $nome "*) pedidos+=("$nome") ;;
      *) morrer "pacote fora da lista desta ponte: $nome" ;;
    esac
  done
  [ "${#pedidos[@]}" -gt 0 ] || morrer "stdin vazio"
  export DEBIAN_FRONTEND=noninteractive
  anotar "pacotes ${pedidos[*]}"
  apt-get install -y --no-install-recommends "${pedidos[@]}" || exit 2
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
    $PONTE completion-instalar, \\
    $PONTE completion-remover, \\
    $PONTE flatpak-global-limpar, \\
    $PONTE libreoffice-remover, \\
    $PONTE libreoffice-devolver, \\
    $PONTE atualizar, \\
    $PONTE pacotes, \\
    $PONTE limpar, \\
    $PONTE estado

$quem ALL=(root) NOPASSWD: MEOWSYSTEM_PONTE
REGRA_FIM
  ;;

''|-h|--help|ajuda)
  sed -n '2,60p' "$0"
  printf '\nverbos: desktop · desktop-banco · greeter-ver · greeter-aplicar ·\n'
  printf '        apt-hook-instalar · apt-hook-remover · completion-instalar ·\n'
  printf '        completion-remover · flatpak-global-limpar · libreoffice-remover ·\n'
  printf '        libreoffice-devolver · atualizar · pacotes · limpar · estado ·\n'
  printf '        regra-sudo\n'
  ;;

*) morrer "verbo desconhecido: $verbo" ;;
esac
exit 0
