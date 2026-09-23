#!/usr/bin/env bash
# spicetify_setup.sh — põe o BINÁRIO do spicetify nesta máquina, e só isso.
#
# ============================================================================
# POR QUE ESTE ARQUIVO EXISTE — 22/09/2026, sprint P29
# ============================================================================
#   A decisão dela, de 21/09/2026: "tudo que for relacionado a tema é para ser
#   do MeowSystem". O `spicetify-setup.sh` estava do lado errado — no
#   Spellbook, que é o repositório da máquina dela —, e era a peça que faltava
#   para a pendência do Spotify ter conserto.
#
#   O `assets/temas-de-apps/spotify/manifesto.sh` já dizia, desde a P2, por que
#   aquela pendência nascia SEM botão:
#
#     "O BINÁRIO continua sem botão. (...) o script que resolveria direito —
#      spicetify-setup.sh, 277 linhas — mora naquele outro repositório, que
#      quem clonar ESTE não terá."
#
#   Agora tem. É este arquivo, e ele é o comando que a pendência publica.
#
# ============================================================================
# O QUE VEIO DO SPELLBOOK, O QUE NÃO VEIO, E A MEDIÇÃO DE CADA RECUSA
# ============================================================================
#   O script de lá tem 277 linhas e faz OITO coisas. Vieram DUAS. As outras
#   seis não são trabalho que falta: são trabalho que este projeto já faz, e
#   melhor. Copiá-las criaria duas verdades sobre o mesmo arquivo de
#   configuração — que é exatamente o defeito que a P29 veio extinguir, não
#   espalhar.
#
#   VEIO  1. instalar o binário do spicetify
#   VEIO  2. apontar o `prefs_path` para o Spotify flatpak
#
#   NÃO VEIO  3. `config current_theme Sleek` / `color_scheme Dracula`
#       Medido no arquivo de lá, em 22/09/2026: `TEMA="Sleek"`,
#       `ESQUEMA="Dracula"`. Este projeto é Catppuccin, com o flavor e o acento
#       saindo do `meow.conf` e da paleta do pack — quem manda nisso é o
#       `meow_app_aplicar` do manifesto do Spotify. Trazer estas duas linhas
#       poria dois donos no `config-xpui.ini`, e o último a rodar venceria.
#
#   NÃO VEIO  4. baixar temas por `git clone` de `spicetify/spicetify-themes`
#       O manifesto já baixa o tema catppuccin PINADO POR COMMIT
#       (`_spot_tema_baixar`, `_SPOT_TEMA_COMMIT`), com a mesma disciplina do
#       `scripts/cursor.sh`. Um `git clone --depth=1` do `main` de outro
#       repositório é a versão sem pino da mesma coisa.
#
#   NÃO VEIO  5. instalar o Marketplace por `curl | sh` do `main`
#       O manifesto já o instala, pinado por TAG DE RELEASE
#       (`_spot_mp_instalar`, `_SPOT_MP_RELEASES`), e só quando
#       `_spot_mp_quer` diz que ela o quer.
#
#   NÃO VEIO  6. `spicetify restore` + `clear` + `backup apply`
#       Esta é a recusa que mais importa, e o motivo está escrito no bloco 5 do
#       manifesto do Spotify: `spicetify backup` FOTOGRAFA O QUE ESTÁ NO DISCO.
#       Rodá-lo com o Catppuccin já aplicado congela o tema do Meow como se
#       fosse o "vanilla" de fábrica, e aí `spicetify restore` nunca mais
#       devolve o original. O de fábrica está guardado em quatro lugares com
#       sha conferido justamente porque alguém quase o perdeu assim.
#
#   NÃO VEIO  7. `config extensions` com dez `.js` e `custom_apps` com quatro
#       São o gosto dela na máquina dela. Não são tema, e este projeto não
#       escolhe extensão de Spotify por ninguém.
#
#   NÃO VEIO  8. `validar()` conferindo `bookmark.js` e o tema `Sleek`
#       Confere o que o item 7 escreveu. Sem o item 7, confere o vazio.
#
# ============================================================================
# O INSTALADOR OFICIAL NÃO É CHAMADO, E ISSO FOI MEDIDO EM 10/08/2026
# ============================================================================
#   O `install.sh` oficial do spicetify honra `ZDOTDIR` (linhas 105-107 dele) e,
#   NESTA máquina, acrescentaria `export PATH=$PATH:$HOME/.spicetify` em
#   `~/.config/zsh/.zshrc` — que é repositório git do Ritual da Aurora, com
#   auto-commit a cada 10 minutos. Sujar o repo dela e brigar com o self-heal
#   por causa de uma linha de PATH não vale, e a TRAVA 1 do `lib/comum.sh`
#   recusaria a escrita de qualquer jeito.
#
#   Ele também PERGUNTA, no fim, "Do you also want to install spicetify
#   Marketplace? (Y/n)", lendo de `/dev/tty`. Sem terminal a resposta vem vazia
#   e o Marketplace é instalado sem ninguém ter pedido.
#
#   Em 10/08/2026 a saída foi rodar o instalador TRUNCADO na linha 88. Funcionou
#   e não serve como código: "linha 88" é um número do arquivo de outra pessoa,
#   que muda no próximo release e passa a cortar no lugar errado — calado.
#
#   AQUI A INSTALAÇÃO É FEITA À MÃO, PINADA POR VERSÃO. São três passos que o
#   instalador oficial também dá, sem os dois que não queremos: baixar o
#   tarball do release, conferir que ele abriu, e pôr o binário em
#   `~/.spicetify`. Nenhum arquivo de shell é tocado — nem o `.zshrc`, nem o
#   `.bashrc`, nem o `env.zsh`.
#
#   E O PATH NÃO PRECISA SER ESCRITO POR NINGUÉM: o manifesto do Spotify acha o
#   binário nos DOIS lugares (`command -v spicetify` e
#   `~/.spicetify/spicetify`) desde 10/08/2026, exatamente para que instalar
#   não exija mexer no shell de quem quer que seja.
#
# ============================================================================
# ESTE ARQUIVO NUNCA USA SUDO
# ============================================================================
#   Tudo o que ele escreve está sob `$HOME/.spicetify` e sob a configuração do
#   spicetify. Não há um `sudo` aqui, e não deve haver: a ponte root deste
#   projeto tem oito verbos e nenhum deles é "instalar binário de usuário".
#
# USO
#   spicetify_setup.sh conferir   0 = o binário está aqui · 1 = falta · 3 = sem curl/tar
#   spicetify_setup.sh instalar   baixa o release pinado e o põe em ~/.spicetify
#   spicetify_setup.sh prefs      só aponta o prefs_path para o Spotify flatpak
#
#   MEOW_DRY_RUN=1 diz tudo o que faria e não escreve um byte.
set -uo pipefail

MEOW_RAIZ="${MEOW_RAIZ:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck source=../lib/comum.sh
. "$MEOW_RAIZ/lib/comum.sh"

# A VERSÃO É PINADA, E O PINO TEM DATA
#   2.45.1 é o que esta máquina tem instalado em 22/09/2026 (medido:
#   `~/.spicetify/spicetify --version`). Pinar é a mesma regra do tema
#   catppuccin (commit) e do Marketplace (tag): um `latest` faz o mesmo comando
#   instalar coisas diferentes em dias diferentes, e aí não há o que conferir.
SPICE_VERSAO="${SPICE_VERSAO:-2.45.1}"
SPICE_DIR="${SPICE_DIR:-$HOME/.spicetify}"
SPICE_BIN="$SPICE_DIR/spicetify"
SPICE_RELEASES="${SPICE_RELEASES:-https://github.com/spicetify/cli/releases/download}"

# O prefs do Spotify flatpak. É o único caminho coberto, e pelo mesmo motivo do
# manifesto: o Spotify desta casa é flatpak de usuário.
SPICE_PREFS_FLATPAK="${SPICE_PREFS_FLATPAK:-$HOME/.var/app/com.spotify.Client/config/spotify/prefs}"

# --- o binário --------------------------------------------------------------
_spice_achar() {
  [ -x "$SPICE_BIN" ] && { printf '%s' "$SPICE_BIN"; return 0; }
  command -v spicetify 2>/dev/null && return 0
  return 1
}

# `uname -m` -> o nome que o release usa. Só os dois que existem em release
# linux do spicetify; o resto sai como vazio e vira uma recusa explicada, em
# vez de um download 404 com cara de erro de rede.
_spice_arquitetura() {
  case "$(uname -m)" in
    x86_64|amd64)  printf 'amd64' ;;
    aarch64|arm64) printf 'arm64' ;;
    *)             return 1 ;;
  esac
}

cmd_conferir() {
  local achado
  if achado="$(_spice_achar)"; then
    local v; v="$("$achado" --version 2>/dev/null || printf 'desconhecida')"
    meow_ok "spicetify $v em $achado"
    return "$MEOW_OK"
  fi
  meow_muda "o spicetify não está instalado — é ele que pinta o Spotify"
  meow_info "o conserto é: scripts/spicetify_setup.sh instalar"
  return "$MEOW_DIVERGENTE"
}

cmd_instalar() {
  local achado
  if achado="$(_spice_achar)"; then
    local v; v="$("$achado" --version 2>/dev/null || printf 'desconhecida')"
    meow_ok "spicetify $v já está em $achado — nada a fazer"
    return "$MEOW_OK"
  fi

  meow_tem curl || { meow_pula "sem curl — não dá para baixar o spicetify"; return "$MEOW_SEM_DEPENDENCIA"; }
  meow_tem tar  || { meow_pula "sem tar — não dá para abrir o release";      return "$MEOW_SEM_DEPENDENCIA"; }

  local arq
  arq="$(_spice_arquitetura)" || {
    meow_erro "arquitetura sem release de linux no spicetify: $(uname -m)"
    meow_info "o projeto publica amd64 e arm64; instale à mão se a sua for outra"
    return "$MEOW_ERRO"
  }

  local nome="spicetify-$SPICE_VERSAO-linux-$arq.tar.gz"
  local url="$SPICE_RELEASES/v$SPICE_VERSAO/$nome"

  if meow_seco; then
    meow_muda "baixaria $url"
    meow_muda "e abriria o binário em $SPICE_DIR (nenhum byte escrito neste ensaio)"
    return "$MEOW_OK"
  fi

  # O `mktemp -d` e o `trap`: o tarball não fica no disco depois. Um `.tar.gz`
  # de 11 MB esquecido em /tmp é o tipo de sujeira que ninguém liga a este
  # script seis meses depois.
  local tmp
  tmp="$(mktemp -d)" || { meow_erro "não consegui criar diretório temporário"; return "$MEOW_ERRO"; }
  trap 'rm -rf "$tmp"' RETURN

  meow_info "baixando spicetify $SPICE_VERSAO ($arq)"
  if ! curl -fsSL -o "$tmp/$nome" "$url"; then
    meow_erro "falhou o download de $url"
    meow_info "confira a rede, ou se a versão $SPICE_VERSAO ainda tem release publicado"
    return "$MEOW_ERRO"
  fi

  mkdir -p "$SPICE_DIR" || { meow_erro "não consegui criar $SPICE_DIR"; return "$MEOW_ERRO"; }
  if ! tar -xzf "$tmp/$nome" -C "$SPICE_DIR"; then
    meow_erro "o tarball baixou mas não abriu — arquivo truncado ou corrompido"
    return "$MEOW_ERRO"
  fi

  if [ ! -x "$SPICE_BIN" ]; then
    meow_erro "o tarball abriu e não há binário executável em $SPICE_BIN"
    return "$MEOW_ERRO"
  fi

  meow_ok "spicetify $("$SPICE_BIN" --version 2>/dev/null) instalado em $SPICE_DIR"
  # A frase existe para que ninguém saia procurando a linha de PATH que o
  # instalador oficial escreveria — ver o bloco do cabeçalho.
  meow_info "nenhum arquivo de shell foi tocado: quem acha o binário é o próprio módulo do Spotify"
  cmd_prefs
  return "$MEOW_OK"
}

# --- o prefs_path -----------------------------------------------------------
# A SEGUNDA COISA QUE VEIO DO SPELLBOOK, E A ÚNICA QUE ELE FAZIA MELHOR
#   O spicetify precisa saber onde está o `prefs` do Spotify, e no flatpak ele
#   não está no lugar que o padrão do spicetify supõe. Sem esta linha o
#   `spicetify apply` reclama de um caminho que não existe.
#
#   O QUE NÃO VEIO JUNTO: o script de lá, quando não achava o `prefs`, ABRIA O
#   SPOTIFY em segundo plano, esperava até 30 segundos em laço e matava o
#   processo. Aqui não: subir o app de alguém para gerar um arquivo é efeito
#   colateral grande demais para um passo de configuração, e é a mesma classe
#   do `flatpak info` que este projeto já teve de tapar (perguntar não pode ser
#   escrever). Sem `prefs`, a frase diz o que fazer: abra o Spotify uma vez.
cmd_prefs() {
  local cli
  cli="$(_spice_achar)" || { meow_pula "sem spicetify instalado — nada a configurar"; return "$MEOW_SEM_DEPENDENCIA"; }

  if [ ! -f "$SPICE_PREFS_FLATPAK" ]; then
    meow_pula "não achei o prefs do Spotify flatpak em $SPICE_PREFS_FLATPAK"
    meow_info "abra o Spotify uma vez: ele cria o arquivo no primeiro início"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if meow_seco; then
    meow_muda "apontaria o prefs_path do spicetify para $SPICE_PREFS_FLATPAK"
    return "$MEOW_OK"
  fi

  if ! "$cli" config prefs_path "$SPICE_PREFS_FLATPAK" >/dev/null 2>&1; then
    meow_erro "o spicetify recusou gravar prefs_path"
    return "$MEOW_ERRO"
  fi
  meow_ok "prefs_path do spicetify aponta para o Spotify flatpak"
  return "$MEOW_OK"
}

case "${1:-conferir}" in
  conferir) cmd_conferir ;;
  instalar) cmd_instalar ;;
  prefs)    cmd_prefs ;;
  *) meow_erro "uso: spicetify_setup.sh {conferir|instalar|prefs}"; exit "$MEOW_ERRO" ;;
esac
