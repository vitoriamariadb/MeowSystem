#!/usr/bin/env bash
# midia_build.sh — compila o applet de mídia patchado e o instala em ~/.local/bin.
#
#   ./midia_build.sh --conferir            não escreve; 1 se o binário divergir da receita
#   MIDIA_COMPILAR=1 ./midia_build.sh      compila e instala
#
# POR QUE ESTE SCRIPT EXISTE SEPARADO DO `midia.sh`
#   Porque ele é a ÚNICA porta do projeto que compila, e compilar é a única
#   coisa que o `meow doctor` das 05:00 não pode fazer. Deixar as duas metades
#   no mesmo arquivo obrigaria o doctor a atravessar o caminho do `cargo` para
#   chegar às partes que ele PODE consertar (a sombra, as chaves, o fail-safe).
#   Separados, o `bin/meow` registra `midiabin` em SEM_CONSERTO e `midia` fora —
#   e o laço de conserto (bin/meow) dá `continue` pelo NOME antes de olhar o
#   código de saída, então um nome só não pode ser "consertável pela metade".
#
# A TRAVA É ESTRUTURAL, NÃO EDUCADA
#   `MIDIA_COMPILAR=1` é obrigatório para compilar. Não é uma convenção que se
#   pede que todo mundo respeite: o caminho do `cargo` é literalmente
#   INALCANÇÁVEL sem essa variável, e quem a exporta é o `install.sh`. O doctor
#   não a exporta e não tem como; no pior dos casos ele acusa a divergência e
#   escreve o comando na tela.
#
# O CARIMBO É O QUE FAZ A SEGUNDA PASSAGEM CUSTAR ZERO
#   Quatro campos: sha256 do patch, COMMIT do PINO, sha256 do binário instalado
#   e a versão do rustc. Batendo os quatro, este script devolve 0 SEM invocar o
#   cargo uma única vez. MEDIDO: até um rebuild que não muda nada custa ~20s, e
#   o `meow-doctor.service` tem `TimeoutStartSec=5min` — vinte segundos por dia
#   de nada é o tipo de gasto que ninguém vê e ninguém remove depois.
#
# O `meow_seco` VEM ANTES DE QUALQUER TOQUE NO RUSTUP, E ISSO É MEDIÇÃO
#   `rustc` nesta máquina é um shim do rustup. Sob `env -i HOME=<falso>` — que é
#   como `tests/seco.sh` roda — o shim FALHA e ainda assim escreve
#   `.rustup/settings.toml` no HOME falso. Um `rustc -V` inocente no caminho do
#   `--conferir` faria o teste do seco acusar escrita num script que promete não
#   escrever nada. Por isso `_rustc_versao` devolve vazio no seco, e o campo
#   simplesmente não entra na comparação.
#
# `--locked` SEMPRE, E NÃO É ZELO
#   O `Cargo.toml` do upstream aponta o libcosmic para o git SEM `rev`. Sem
#   `--locked`, uma compilação de amanhã pegaria outro commit do libcosmic sem
#   ninguém ter pedido — e a falha apareceria como erro de compilação num dia em
#   que ninguém mexeu em nada. Quem segura a versão é o `Cargo.lock` do upstream.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

RECEITA="$RAIZ/src/applets/now-playing"
PATCH="$RECEITA/0001-meow-capa-cor-controles.patch"
PINO="$RECEITA/PINO"

ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/midia"
ARVORE="$ESTADO/src"
ALVO="$ESTADO/target"
CARIMBO="$ESTADO/carimbo"

# O binário tem NOME PRÓPRIO, e não é enfeite. MEDIDO em 24/08/2026: o applet do
# flatpak roda com a cmdline `cosmic-ext-applet-now-playing` PELADA, debaixo de
# um `bwrap` — a string `flatpak run` vive só no `Exec=` do `.desktop` e nunca
# no processo. Com o mesmo nome, nenhum `pgrep` distinguiria o nosso do dele, e
# a conferência daria garantia falsa.
BINARIO="$HOME/.local/bin/meow-applet-now-playing"

MIDIA="${MIDIA:-sim}"
COMPILAR="${MIDIA_COMPILAR:-0}"

CONFERIR=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && CONFERIR=1

_sha() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

# Vazio no seco e quando o rustc não existe — ver o cabeçalho. Campo vazio não
# entra na comparação, em vez de fingir divergência.
_rustc_versao() {
  meow_seco && return 0
  meow_tem rustc || return 0
  rustc -V 2>/dev/null
}

_pino_ler() {
  [ -f "$PINO" ] || return 1
  # shellcheck source=/dev/null
  . "$PINO"
  [ -n "${URL:-}" ] && [ -n "${COMMIT:-}" ]
}

_carimbo_vivo() {
  printf 'patch %s\ncommit %s\nbinario %s\nrustc %s\n' \
    "$(_sha "$PATCH")" "${COMMIT:-}" "$(_sha "$BINARIO")" "$(_rustc_versao)"
}

# Compara campo a campo. Campo VIVO vazio é pulado (é o caso do rustc no seco);
# campo GRAVADO ausente conta como divergência, porque carimbo incompleto é
# carimbo de uma versão anterior deste script.
_carimbo_bate() {
  [ -f "$CARIMBO" ] || return 1
  local campo vivo gravado
  while read -r campo vivo; do
    [ -z "$vivo" ] && continue
    gravado="$(sed -n "s/^$campo //p" "$CARIMBO" | head -1)"
    [ "$gravado" = "$vivo" ] || return 1
  done <<< "$(_carimbo_vivo)"
  return 0
}

_pronto() {
  if [ ! -f "$PATCH" ] || [ ! -f "$PINO" ]; then
    meow_erro "falta $RECEITA (patch ou PINO) — repositório incompleto"
    return "$MEOW_ERRO"
  fi
  _pino_ler || { meow_erro "o PINO não tem URL/COMMIT"; return "$MEOW_ERRO"; }
  return "$MEOW_OK"
}

_conferir() {
  if [ ! -x "$BINARIO" ]; then
    meow_muda "o applet de mídia ainda não foi compilado ($BINARIO)"
    return "$MEOW_DIVERGENTE"
  fi
  if ! _carimbo_bate; then
    meow_muda "o applet de mídia instalado não é o desta receita (patch, commit ou rustc mudaram)"
    return "$MEOW_DIVERGENTE"
  fi
  meow_ok "applet de mídia $(_sha "$BINARIO" | cut -c1-8) já é o do repositório"
  return "$MEOW_OK"
}

# A ÁRVORE: clonar quando falta, e RECOLOCAR no pino quando existe. O critério é
# o SHA, não a existência do diretório — uma árvore parada num commit velho
# compila sem erro e entrega o applet errado, que é pior que não compilar.
_arvore_no_pino() {
  if [ ! -d "$ARVORE/.git" ]; then
    rm -rf "$ARVORE"
    mkdir -p "$(dirname "$ARVORE")" || return "$MEOW_ERRO"
    git clone -q --depth 50 "$URL" "$ARVORE" || {
      meow_aviso "não consegui clonar $URL (sem rede?) — fica para o próximo ciclo"
      return "$MEOW_SEM_DEPENDENCIA"
    }
  fi

  if [ "$(git -C "$ARVORE" rev-parse HEAD 2>/dev/null)" != "$COMMIT" ]; then
    # `--depth 50` é barato e cobre o caso normal. Quando o pino envelhece para
    # FORA da janela, o clone raso não tem o objeto e o checkout falha por um
    # motivo que não é erro de ninguém — daí o resgate. Mesmo critério do
    # scripts/baixar_upstream.sh.
    git -C "$ARVORE" checkout -q "$COMMIT" 2>/dev/null || {
      git -C "$ARVORE" fetch -q --unshallow 2>/dev/null || git -C "$ARVORE" fetch -q --all 2>/dev/null
      git -C "$ARVORE" checkout -q "$COMMIT" 2>/dev/null || {
        meow_erro "o commit $COMMIT não existe em $URL — confira o PINO"
        return "$MEOW_ERRO"
      }
    }
  fi
  return "$MEOW_OK"
}

_aplicar() {
  # Conferir ANTES: é o que garante que a segunda passagem não chama o cargo.
  _conferir >/dev/null 2>&1 && { _conferir; return $?; }

  if [ "$COMPILAR" != "1" ]; then
    meow_pula "o applet de mídia precisa ser compilado, e compilar não é do doctor"
    meow_info "  rode: MIDIA_COMPILAR=1 $RAIZ/scripts/midia_build.sh"
    meow_info "  (o ./install.sh já exporta essa chave sozinho)"
    # 3, e NÃO 1. No contrato deste projeto 1 é "divergia e FOI CONSERTADO", e
    # aqui nada foi consertado — a permissão de compilar é que falta. Com 1, o
    # resumo do install.sh diria `mexeu: midia_build` em toda execução sem um
    # byte ter sido escrito, que é a mentira de relatório que o `concluir()`
    # existe para não deixar acontecer. Com 3 isto cai em "pulados", que é a
    # verdade: a etapa não rodou porque falta algo que não é dela resolver.
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem cargo; then
    meow_pula "sem cargo nesta máquina — o applet de mídia fica de fora"
    meow_info "  instale com rustup e rode o install.sh de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$BINARIO" || return "$MEOW_ERRO"
  mkdir -p "$ESTADO" || { meow_erro "não consegui criar $ESTADO"; return "$MEOW_ERRO"; }

  _arvore_no_pino
  case $? in
    2) return "$MEOW_ERRO" ;;
    3) return "$MEOW_SEM_DEPENDENCIA" ;;
  esac

  # O reset é OBRIGATÓRIO: sem ele, a segunda compilação com o patch alterado
  # aplicaria a diferença por cima de uma árvore já patchada — e o resultado é
  # indefinido, não um erro.
  git -C "$ARVORE" checkout -q -- . || { meow_erro "não consegui limpar a árvore"; return "$MEOW_ERRO"; }
  if ! git -C "$ARVORE" apply "$PATCH"; then
    meow_erro "o patch não aplica em $COMMIT — o upstream mexeu nos arquivos que tocamos"
    meow_info "  regenere: git -C $ARVORE diff > $PATCH"
    return "$MEOW_ERRO"
  fi

  meow_info "compilando o applet de mídia (a primeira vez leva ~2min)"
  if ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$ARVORE/Cargo.toml" >/dev/null 2>&1; then
    meow_erro "o cargo falhou — provável deriva do libcosmic (o Cargo.toml o aponta sem rev)"
    meow_info "  veja o motivo: CARGO_TARGET_DIR=$ALVO cargo build --release --locked --manifest-path $ARVORE/Cargo.toml"
    meow_info "  o binário anterior segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
  fi

  local recem="$ALVO/release/cosmic-ext-applet-now-playing"
  [ -x "$recem" ] || { meow_erro "o cargo terminou e não deixou binário em $recem"; return "$MEOW_ERRO"; }

  install -Dm0755 "$recem" "$BINARIO" || { meow_erro "não consegui instalar $BINARIO"; return "$MEOW_ERRO"; }
  strip "$BINARIO" 2>/dev/null

  # O `install -D` não passa por `meow_escrever`, então o manifesto (que é quem
  # o `--uninstall` lê) precisa ser alimentado à mão. Sem esta linha o binário
  # sobreviveria a uma desinstalação do MeowSystem.
  meow_manifesto_registrar "$BINARIO"

  _carimbo_vivo > "$CARIMBO" || { meow_erro "não consegui gravar o carimbo"; return "$MEOW_ERRO"; }
  meow_ok "applet de mídia compilado e instalado ($(_sha "$BINARIO" | cut -c1-8))"
  return "$MEOW_DIVERGENTE"
}

main() {
  if [ "$MIDIA" != "sim" ]; then
    # Desligar é trabalho do `midia.sh --reverter`, que remove na ORDEM certa
    # (sombra antes do binário). Dois donos para a mesma remoção é como se cria
    # o estado em que a sombra fica sem binário — que deixa a dock com um buraco.
    meow_pula "MIDIA=\"$MIDIA\" no meow.conf — o applet de mídia não é compilado"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"
