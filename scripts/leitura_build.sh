#!/usr/bin/env bash
# leitura_build.sh — compila o applet do modo de leitura e o põe na barra dela.
#
#   ./leitura_build.sh --conferir             não escreve; 1 se algo divergir
#   LEITURA_COMPILAR=1 ./leitura_build.sh     compila, instala e planta a sombra
#   ./leitura_build.sh --reverter             tira a sombra, o binário e a árvore
#
# ESTE ARQUIVO É O IRMÃO DO `midia_build.sh`, E A DIFERENÇA CABE EM DUAS LINHAS
#   Lá a receita é um clone do upstream mais um patch, e o carimbo guarda o
#   COMMIT do PINO. Aqui a receita é NOSSA — `src/applets/leitura/` mora no
#   repositório —, então não há clone, não há PINO, e o que o carimbo guarda são
#   os três arquivos que definem a compilação: o `main.rs`, o `Cargo.toml` (onde
#   o `rev` do libcosmic está pinado) e o `Cargo.lock` (que é nosso, porque não
#   há upstream de onde herdá-lo).
#
# A TRAVA É ESTRUTURAL, NÃO EDUCADA
#   `LEITURA_COMPILAR=1` é obrigatório para chegar ao `cargo`. Não é convenção:
#   o caminho é literalmente inalcançável sem a variável, e quem a exporta é o
#   `install.sh`. O `meow doctor` das 05:00 não a exporta e não tem como — no
#   pior caso ele ACUSA a divergência e escreve o comando na tela.
#
# O CARIMBO É O QUE FAZ A SEGUNDA PASSAGEM CUSTAR ZERO
#   Cinco campos. Batendo os cinco, este script devolve 0 sem invocar o cargo
#   uma única vez. MEDIDO no irmão: até um rebuild que não muda nada custa ~20s,
#   e o `meow-doctor.service` tem `TimeoutStartSec=5min`.
#
# O `meow_seco` VEM ANTES DE QUALQUER TOQUE NO RUSTUP, E ISSO É MEDIÇÃO
#   `rustc` nesta máquina é um shim do rustup. Sob `env -i HOME=<falso>` — que é
#   como o `tests/seco.sh` roda — o shim FALHA e ainda assim escreve
#   `.rustup/settings.toml` no HOME falso. Um `rustc -V` inocente no caminho do
#   `--conferir` faria o teste do seco acusar escrita num script que promete não
#   escrever nada. Por isso `_rustc_versao` devolve vazio no seco.
#
# `--locked` SEMPRE, E AQUI ELE PESA MAIS QUE NO IRMÃO
#   O `Cargo.lock` deste crate é o ÚNICO lock que existe: ninguém o herda de um
#   upstream. Sem `--locked`, uma compilação de amanhã resolveria 638 pacotes de
#   novo e pegaria versões que ninguém pediu, e a falha apareceria como erro de
#   compilação num dia em que ninguém mexeu em nada.
#
# ============================================================================
# A ORDEM — BINÁRIO, DEPOIS SOMBRA — E O BURACO QUE ELA EVITA
# ============================================================================
#   O `cosmic-panel` acha os applets pelo BASENAME do `.desktop` e consome o
#   slot no primeiro acerto. Sombra presente com binário ausente não devolve o
#   applet de fábrica: deixa um BURACO na barra. Por isso, aqui:
#
#     instalar   binário primeiro, sombra depois
#     remover    sombra primeiro, binário depois
#     consertar  binário sumiu  ->  a sombra é REMOVIDA
#     repor      sombra sumiu   ->  reescrita SEM cargo (ver `_sem_cargo`)
#
#   As duas últimas rodam MESMO SEM `LEITURA_COMPILAR`, e isso é o desenho: um
#   `rm` de arquivo nosso não é compilar, e 365 bytes de texto também não. As
#   duas vêm antes da trava, de propósito — ver `_orfa` e `_sem_cargo`.
#
#   A TERCEIRA PEÇA, `plugins_wings`, NÃO É ESCRITA POR ESTE ARQUIVO E NUNCA
#   SERÁ. É território da Aurora (docs/FRONTEIRA.md) e é onde moram os applets
#   dela. Este script CONFERE se a linha está lá e AVISA quando não está —
#   aviso, jamais divergência, porque o conserto não é dele.
#
#   E ELA NÃO É INERTE — O PLANO DE 29/08 ERRA AQUI, E O ERRO É PERIGOSO
#     O plano diz que `plugins_wings` "só vale no próximo início de sessão", e
#     usa isso como razão para tratar a escrita como inofensiva. MEDIDO em
#     30/08/2026, às 05:43, com a sessão dela de pé:
#       · `/proc/<pid do cosmic-panel>/fdinfo/*` tem um watch de inotify no
#         INODE do diretório `~/.config/cosmic/com.system76.CosmicPanel.Panel/v1`
#         — o painel está ouvindo aquele diretório agora;
#       · `plugins_wings` está na lista `must_recreate` do painel
#         (`cosmic-panel-bin/src/space_container/space_container.rs`, o braço
#         `c.plugins_wings != entry.plugins_wings`);
#       · escrever a linha RECRIOU o espaço da topbar NA HORA: o processo do
#         painel manteve o mesmo PID (189474) e TODOS os applets renasceram com
#         PIDs novos — inclusive o nosso, que apareceu na barra dela sem logout.
#
#     Ou seja, esta é a MESMA classe de evento que já apagou topbar e dock juntas
#     nesta máquina. Escrever `plugins_wings` é barato UMA VEZ e desastroso em
#     rajada — e é exatamente por isso que ele continua fora de todo script:
#     nenhum doctor, nenhum timer e nenhum `install.sh` pode tocá-lo.
#
# O QUE ESTE SCRIPT NÃO CONSEGUE CONSERTAR SOZINHO, E POR QUE ISSO É ACEITO
#   O `bin/meow` registra `leiturabin` em SEM_CONSERTO, e o laço de conserto dá
#   `continue` pelo NOME antes de olhar o código de saída. Ou seja: o doctor
#   nunca vai chamar o caminho que remove a sombra órfã — ele só acusa, com o
#   comando na tela.
#
#   No applet de mídia isso foi resolvido partindo em dois nomes (`midiabin` e
#   `midia`), e lá valia a pena: sem o conserto automático, a dock dela ficaria
#   sem o applet de mídia que o flatpak forneceria de graça. Aqui não existe
#   applet de fábrica por trás: se o nosso some, o pior caso é um espaço vazio
#   na topbar, e o `meow doctor` diz em uma linha qual comando o fecha. Um
#   segundo verificável para essa diferença seria mais superfície do que
#   conserto.
#
# CÓDIGOS DE SAÍDA (o contrato do projeto)
#   0 já estava certo · 1 divergia e foi consertado · 2 erro · 3 falta dependência
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

RECEITA="$RAIZ/src/applets/leitura"
FONTE="$RECEITA/src/main.rs"
MANIFESTO="$RECEITA/Cargo.toml"
TRAVA="$RECEITA/Cargo.lock"

ESTADO="${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/leitura"
ALVO="$ESTADO/target"
CARIMBO="$ESTADO/carimbo"

# O `app_id` está escrito em TRÊS lugares que precisam concordar: aqui, na
# constante `ID` do main.rs e na linha do `plugins_wings`. Divergir em um deles
# dá um applet que compila, instala e nunca aparece.
APP_ID="com.meowsystem.AppletLeitura"
BINARIO="$HOME/.local/bin/meow-applet-leitura"
SOMBRA="${XDG_DATA_HOME:-$HOME/.local/share}/applications/$APP_ID.desktop"
ASA="${XDG_CONFIG_HOME:-$HOME/.config}/cosmic/com.system76.CosmicPanel.Panel/v1/plugins_wings"

LEITURA_APPLET="${LEITURA_APPLET:-sim}"
COMPILAR="${LEITURA_COMPILAR:-0}"

CONFERIR=0; REVERTER=0
case "${1:-}" in
  --conferir) CONFERIR=1 ;;
  --reverter) REVERTER=1 ;;
  ''|--aplicar) ;;
  *) meow_erro "uso: $(basename "$0") [--conferir|--aplicar|--reverter]"; exit "$MEOW_ERRO" ;;
esac
meow_seco && [ "$REVERTER" = 0 ] && CONFERIR=1

_sha() { sha256sum -- "$1" 2>/dev/null | cut -d' ' -f1; }

# Vazio no seco e quando o rustc não existe — ver o cabeçalho. Campo vazio não
# entra na comparação, em vez de fingir divergência.
_rustc_versao() {
  meow_seco && return 0
  meow_tem rustc || return 0
  rustc -V 2>/dev/null
}

# O `Icon=` aponta para um nome do TEMA, não para um caminho: assim ele segue o
# tema de ícones que ela estiver usando, e continua existindo se o repositório
# sair do disco. `night-light-symbolic` está no Papirus e no Adwaita desta
# máquina (conferido em 30/08/2026), que são os dois que o COSMIC alcança.
#
# SEM `X-CosmicHoverPopup=Auto`, e isto é escolha, não esquecimento: com ela o
# popup abre ao PASSAR o mouse. Um popup de dois sliders que se abre sozinho
# quando o cursor atravessa a topbar é um convite a arrastar sem querer a
# temperatura da tela inteira. O applet de mídia pode: lá o popup só mostra.
_texto_sombra() {
  cat <<EOF
[Desktop Entry]
Name=Modo de leitura
Comment=Temperatura de cor e textura de papel, do MeowSystem
Exec=$BINARIO
Terminal=false
Type=Application
StartupNotify=true
Icon=night-light-symbolic
Categories=COSMIC;Utility;
Keywords=COSMIC;Applet;Leitura;Temperatura;Noite;
NoDisplay=true
X-CosmicApplet=true
X-CosmicShrinkable=true
EOF
}

_carimbo_vivo() {
  printf 'fonte %s\nreceita %s\ntrava %s\nbinario %s\nrustc %s\n' \
    "$(_sha "$FONTE")" "$(_sha "$MANIFESTO")" "$(_sha "$TRAVA")" \
    "$(_sha "$BINARIO")" "$(_rustc_versao)"
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
  local f
  for f in "$FONTE" "$MANIFESTO" "$TRAVA"; do
    if [ ! -f "$f" ]; then
      meow_erro "falta $f — repositório incompleto"
      return "$MEOW_ERRO"
    fi
  done
  return "$MEOW_OK"
}

# A asa da topbar é só LEITURA aqui. Devolve 0 quando o applet está citado.
_asa_cita() { grep -qs "\"$APP_ID\"" "$ASA"; }

# O FAIL-SAFE: sombra no disco com o binário fora. É o estado que deixa a barra
# dela com um BURACO, e o único que piora sozinho com o tempo.
#
# MORA AQUI, FORA DO `_conferir` E DO `_aplicar`, PORQUE PRECISA PASSAR POR CIMA
# DE DUAS GUARDAS, NÃO DE UMA
#   A trava do `LEITURA_COMPILAR` é a conhecida (remover uma sombra não é
#   compilar). A segunda é o `_pronto`, e ela custou uma medição para aparecer:
#   em 31/08/2026, com `src/applets/leitura/` fora da árvore — um `git checkout`
#   de qualquer commit anterior a 30/08 basta —, o `_pronto` devolvia 2 em
#   "repositório incompleto" ANTES de qualquer caminho olhar para a sombra, e o
#   buraco na topbar sobrevivia à execução inteira. O fail-safe não depende de
#   receita nenhuma: ele apaga um arquivo NOSSO cujo par não existe mais.
_orfa() { [ -f "$SOMBRA" ] && [ ! -x "$BINARIO" ]; }

# --- conferência (leitura pura) ---------------------------------------------
# A sombra órfã não é conferida aqui: o `main` a intercepta antes (ver `_orfa`).
_conferir() {
  if [ ! -x "$BINARIO" ]; then
    meow_muda "o applet do modo de leitura ainda não foi compilado ($BINARIO)"
    return "$MEOW_DIVERGENTE"
  fi

  if ! _carimbo_bate; then
    meow_muda "o applet de leitura instalado não é o desta receita (fonte, Cargo.toml, Cargo.lock ou rustc mudaram)"
    return "$MEOW_DIVERGENTE"
  fi

  # (1) A sombra, comparada por CONTEÚDO e não com `cmp`. O `meow_escrever`
  # grava com `printf '%s'` e come o `\n` final: um `cmp` acusaria divergência
  # para sempre num arquivo perfeito.
  if [ ! -f "$SOMBRA" ] || [ "$(_texto_sombra)" != "$(cat "$SOMBRA" 2>/dev/null)" ]; then
    meow_muda "a sombra do applet de leitura não está no lugar ($SOMBRA)"
    return "$MEOW_DIVERGENTE"
  fi

  # (2) A asa é AVISO, nunca divergência: o arquivo é da Aurora e nenhum script
  # nosso escreve nele. Um `--consertar` que não pode consertar é uma linha
  # amarela eterna, e linha amarela eterna se aprende a ignorar.
  if ! _asa_cita; then
    meow_aviso "o applet está instalado, mas a topbar não o cita — acrescente \"$APP_ID\" à mão em:"
    meow_aviso "  $ASA  (o painel recria a topbar na hora; o shader é que espera o logout)"
  fi

  meow_ok "applet do modo de leitura $(_sha "$BINARIO" | cut -c1-8) já é o do repositório"
  return "$MEOW_OK"
}

# ============================================================================
# O QUE NÃO É COMPILAÇÃO NÃO PODE EXIGIR A TRAVA DE COMPILAR
# ============================================================================
#   Até 31/08/2026 as duas metades deste script viviam ATRÁS do
#   `LEITURA_COMPILAR`, e o preço apareceu na medição daquele dia: com a sombra
#   apagada e todo o resto perfeito, `--conferir` devolvia 1 e `--aplicar`
#   devolvia 3 dizendo "precisa ser compilado" — para reescrever 365 bytes de
#   texto. Numa máquina sem rustup a sombra NUNCA voltaria, porque o
#   `meow_tem cargo` corta três linhas adiante.
#
#   O QUE ESTA FUNÇÃO CURA, MEDIDO: com a sombra apagada, `--aplicar` SEM
#   `LEITURA_COMPILAR` repôs os 365 bytes e o `--conferir` seguinte devolveu 0.
#   O ganho é de quem CHAMA este script — o `./install.sh` e a mão dela.
#
#   O QUE ELA **NÃO** CURA: O DOCTOR. E ISSO PRECISA ESTAR ESCRITO AQUI
#     O irmão de mídia parte as metades em DOIS arquivos (`midia_build.sh`
#     compila, `midia.sh` põe a sombra) e só o primeiro está em SEM_CONSERTO —
#     por isso o doctor conserta a sombra dele sozinho. Aqui a separação é por
#     CAMINHO DE CÓDIGO, e caminho de código o doctor não enxerga: o `bin/meow`
#     lista `leiturabin` em `SEM_CONSERTO`, e o laço de conserto do `cmd_doctor`
#     dá `continue` pelo NOME antes de olhar o código de saída. Nem existe um
#     `fix_leiturabin` para ser chamado. Ou seja, `meow doctor --consertar`
#     continua imprimindo "sem conserto automático" para o applet de leitura,
#     para sempre — a linha amarela eterna segue de pé, e uma versão anterior
#     deste parágrafo dizia que ela tinha sido curada. Não foi.
#
#     A DÍVIDA, PARA QUEM REABRIR A CONTA: tirar `leiturabin` do `SEM_CONSERTO` e
#     escrever um `fix_leiturabin` que chame este script sem `LEITURA_COMPILAR`
#     fecharia o buraco. É outro arquivo (`bin/meow`) e outra decisão — e o
#     cabeçalho deste já pesou que um segundo nome verificável seria mais
#     superfície do que conserto, porque aqui o pior caso é um slot vazio na
#     topbar, e não um applet de fábrica mascarado como no irmão.
#
#   Devolve 0 quando não sobrou nada para o cargo fazer.
_sem_cargo() {
  local pronto="$ALVO/release/meow-applet-leitura" gravado r

  # O seco não chega aqui hoje — `meow_seco` força `CONFERIR=1` lá em cima e o
  # `main` desvia para o `_conferir`. O cinto fica porque o `install -D` abaixo
  # não passa por `meow_escrever` e não tem trava própria: quem um dia mexer
  # naquela linha não pode ganhar uma escrita de brinde.
  meow_seco && return 1

  if [ ! -x "$BINARIO" ]; then
    # O BINÁRIO SUMIU MAS A ÁRVORE DE BUILD AINDA TEM O DELE — repor é uma cópia,
    # não uma compilação. A prova é o carimbo, pelo sha, e ela é obrigatória:
    # uma árvore parada num `main.rs` velho entrega um applet que roda e está
    # errado, que é pior que não ter applet (é o mesmo perigo que o
    # `_arvore_no_pino` do irmão evita com o commit do PINO).
    [ -x "$pronto" ] || return 1
    # Aqui o campo `binario` do carimbo VIVO sai da conta sozinho: sem arquivo
    # instalado o `_sha` devolve vazio e o laço do `_carimbo_bate` pula o campo.
    # Sobra exatamente o que interessa — fonte, receita, trava e rustc iguais.
    _carimbo_bate || return 1
    gravado="$(sed -n 's/^binario //p' "$CARIMBO" | head -1)"
    [ -n "$gravado" ] || return 1
    [ "$gravado" = "$(_sha "$pronto")" ] || return 1

    meow_destino_permitido "$BINARIO" || return 1
    install -Dm0755 "$pronto" "$BINARIO" || return 1
    meow_manifesto_registrar "$BINARIO"
    meow_muda "o binário sumiu e a árvore de build ainda tinha o dele — reposto sem compilar"
  else
    _carimbo_bate || return 1
  fi

  # A SOMBRA SÓ AGORA, e a ordem binário→sombra do cabeçalho vale aqui igual: no
  # ramo de cima o binário acabou de ser instalado, no de baixo ele já estava.
  meow_escrever "$SOMBRA" "$(_texto_sombra)" 644; r=$?
  [ "$r" = 2 ] && { meow_erro "não consegui escrever $SOMBRA"; return 1; }
  return 0
}

# --- aplicação ---------------------------------------------------------------
_aplicar() {
  # Conferir ANTES: é o que garante que a segunda passagem não chama o cargo.
  _conferir >/dev/null 2>&1 && { _conferir; return $?; }

  # E, antes da trava, tentar fechar sem o cargo o que não precisa dele.
  if _sem_cargo; then
    _conferir
    meow_registrar "leitura_build.sh reconciliou sem compilar"
    return "$MEOW_DIVERGENTE"
  fi

  if [ "$COMPILAR" != "1" ]; then
    meow_pula "o applet do modo de leitura precisa ser compilado, e compilar não é do doctor"
    meow_info "  rode: LEITURA_COMPILAR=1 $RAIZ/scripts/leitura_build.sh"
    meow_info "  (o ./install.sh já exporta essa chave sozinho)"
    # 3, e NÃO 1. No contrato deste projeto 1 é "divergia e FOI CONSERTADO", e
    # aqui nada foi consertado — falta a permissão de compilar. Com 1, o resumo
    # do install.sh diria `mexeu: leitura_build` em toda execução sem um byte
    # ter sido escrito.
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  if ! meow_tem cargo; then
    meow_pula "sem cargo nesta máquina — o applet do modo de leitura fica de fora"
    meow_info "  instale com rustup e rode o install.sh de novo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  meow_destino_permitido "$BINARIO" || return "$MEOW_ERRO"
  mkdir -p "$ESTADO" || { meow_erro "não consegui criar $ESTADO"; return "$MEOW_ERRO"; }

  meow_info "compilando o applet do modo de leitura (build frio de libcosmic: dezenas de minutos)"
  if ! CARGO_TARGET_DIR="$ALVO" cargo build --release --locked \
        --manifest-path "$MANIFESTO" >/dev/null 2>&1; then
    meow_erro "o cargo falhou — veja o motivo com:"
    meow_info "  CARGO_TARGET_DIR=$ALVO cargo build --release --locked --manifest-path $MANIFESTO"
    meow_info "  o binário anterior, se houver, segue instalado e funcionando; nada foi trocado"
    return "$MEOW_ERRO"
  fi

  local recem="$ALVO/release/meow-applet-leitura"
  [ -x "$recem" ] || { meow_erro "o cargo terminou e não deixou binário em $recem"; return "$MEOW_ERRO"; }

  install -Dm0755 "$recem" "$BINARIO" || { meow_erro "não consegui instalar $BINARIO"; return "$MEOW_ERRO"; }

  # O `install -D` não passa por `meow_escrever`, então o manifesto (que é quem
  # o `--uninstall` lê) precisa ser alimentado à mão. Sem esta linha o binário
  # sobreviveria a uma desinstalação do MeowSystem.
  meow_manifesto_registrar "$BINARIO"

  # A SOMBRA SÓ AGORA — ver o cabeçalho. Entre a linha acima e esta não existe
  # instante em que a sombra esteja no disco sem o binário.
  meow_escrever "$SOMBRA" "$(_texto_sombra)" 644
  case $? in
    2) meow_erro "não consegui escrever $SOMBRA"; return "$MEOW_ERRO" ;;
  esac

  _carimbo_vivo > "$CARIMBO" || { meow_erro "não consegui gravar o carimbo"; return "$MEOW_ERRO"; }

  meow_ok "applet do modo de leitura compilado e instalado ($(_sha "$BINARIO" | cut -c1-8))"
  if ! _asa_cita; then
    meow_aviso "falta a última peça, e ela é à mão: acrescente \"$APP_ID\" a"
    meow_aviso "  $ASA"
    meow_aviso "  (arquivo da Aurora; escrever nele RECRIA a topbar na hora — faça uma vez, à mão)"
  else
    meow_info "a topbar já cita o applet — ele sobe junto com o painel"
  fi
  meow_registrar "leitura_build.sh instalou $(_sha "$BINARIO" | cut -c1-8)"
  return "$MEOW_DIVERGENTE"
}

# --- reversão ----------------------------------------------------------------
# A ORDEM É A METADE DO VALOR: a sombra sai PRIMEIRO; só depois o binário. O
# contrário abriria a janela em que a barra fica com um slot vazio — o mesmo
# buraco que o fail-safe existe para tapar.
#
# A linha do `plugins_wings` NÃO é removida daqui, e não é descuido: o arquivo é
# da Aurora, este script nunca escreveu nele, e uma asa sem a sombra
# correspondente é inofensiva — o painel simplesmente não acha o applet e segue.
_reverter() {
  local mexeu=0
  if meow_seco; then
    [ -f "$SOMBRA" ]  && { meow_muda "removeria a sombra $SOMBRA"; mexeu=1; }
    [ -e "$BINARIO" ] && { meow_muda "removeria o binário $BINARIO"; mexeu=1; }
    [ -d "$ESTADO" ]  && { meow_muda "removeria a árvore de build $ESTADO"; mexeu=1; }
    [ "$mexeu" = 1 ] && return "$MEOW_DIVERGENTE"
    meow_pula "não há applet de leitura nosso para remover"
    return "$MEOW_OK"
  fi

  [ -f "$SOMBRA" ]  && { rm -f "$SOMBRA";  mexeu=1; }
  [ -e "$BINARIO" ] && { rm -f "$BINARIO"; mexeu=1; }
  [ -d "$ESTADO" ]  && { rm -rf "$ESTADO"; mexeu=1; }
  # As cinco chaves do CosmicComp ficam: são o estado do modo de leitura, e o
  # `scripts/leitura.sh` continua lendo e escrevendo nelas sem este applet.
  # Zerar aqui apagaria o ajuste dela por causa de uma desinstalação de interface.

  if [ "$mexeu" = 0 ]; then
    meow_pula "não havia applet de leitura nosso para remover"
    return "$MEOW_OK"
  fi
  if _asa_cita; then
    meow_aviso "a topbar ainda cita \"$APP_ID\" — tire a linha à mão de $ASA"
    meow_aviso "  (inofensivo: sem a sombra o painel apenas ignora o nome)"
  fi
  meow_ok "applet do modo de leitura removido — a topbar volta sem ele no próximo login"
  return "$MEOW_DIVERGENTE"
}

main() {
  [ "$REVERTER" = 1 ] && { _reverter; return $?; }
  if [ "$LEITURA_APPLET" != "sim" ]; then
    # Desligar tem de DESLIGAR. Deixar de instalar manteria de pé a sombra que
    # uma execução anterior escreveu, e o sintoma seria "desliguei e continua",
    # que é o pior de todos porque não há onde olhar.
    if [ -f "$SOMBRA" ] || [ -x "$BINARIO" ]; then
      meow_muda "LEITURA_APPLET=\"$LEITURA_APPLET\" no meow.conf, mas o applet continua instalado"
      [ "$CONFERIR" = 1 ] && return "$MEOW_DIVERGENTE"
      _reverter; return $?
    fi
    meow_pula "LEITURA_APPLET=\"$LEITURA_APPLET\" no meow.conf — sem applet do modo de leitura"
    return "$MEOW_SEM_DEPENDENCIA"
  fi

  # O FAIL-SAFE, e ele vem antes do `_pronto` — ver `_orfa`. Buraco na barra
  # dela não espera repositório completo para ser tapado.
  if _orfa; then
    # `|| meow_seco` é redundante hoje (o seco já força `CONFERIR=1` lá em cima)
    # e fica de propósito: é o que impede este `rm` de escapar se alguém um dia
    # mexer naquela linha.
    if [ "$CONFERIR" = 1 ] || meow_seco; then
      meow_muda "a sombra do applet de leitura existe e o binário não — a topbar fica com um slot vazio"
      meow_info "  conserto: LEITURA_COMPILAR=1 $RAIZ/scripts/leitura_build.sh"
      return "$MEOW_DIVERGENTE"
    fi
    rm -f "$SOMBRA"
    meow_aviso "a sombra estava órfã e foi removida — a topbar volta sem o applet, em vez de com um buraco"
    meow_info "  para tê-lo de volta: LEITURA_COMPILAR=1 $RAIZ/scripts/leitura_build.sh"
    return "$MEOW_DIVERGENTE"
  fi

  _pronto || return $?
  if [ "$CONFERIR" = 1 ]; then _conferir; else _aplicar; fi
}

main "$@"
