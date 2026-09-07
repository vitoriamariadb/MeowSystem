#!/usr/bin/env bash
# construir_icones.sh — monta o tema MeowSystem-Icons e a logo do painel.
#
# ONDE, E POR QUE AQUI
#   `~/.local/share/icons/MeowSystem-Icons`. Sem sudo, sem `/usr/share`, sem
#   envolver o Ritual da Aurora. Isso foi MEDIDO (docs/COSMIC-THEMING.md §2): o
#   laço externo da resolução de ícone do COSMIC é o NOME DO TEMA, não o
#   diretório-base. O tema selecionado é consultado primeiro em
#   `/usr/share/icons/<tema>` e logo depois em `~/.local/share/icons/<tema>` —
#   e só muito depois se chega ao `hicolor`. Como nenhum `/usr/share/icons/
#   MeowSystem-Icons` existe, o do usuário ganha sozinho.
#
#   Um teste anterior concluiu o contrário porque plantou o ícone no `hicolor`
#   do usuário: aquilo perdeu por estar no FIM DA CADEIA DE HERANÇA, não por ser
#   do usuário. A conclusão certa custou dois testes e está registrada no doc.
#
# DOIS GATOS, DOIS MECANISMOS DIFERENTES
#   - O botão do dock/menu vem do TEMA DE ÍCONES, pelo nome
#     `com.system76.CosmicPanelAppButton` / `com.system76.CosmicAppLibrary`.
#   - A logo do painel NÃO passa por tema de ícones: o applet LogoMenu guarda um
#     CAMINHO DE ARQUIVO em `custom_logo_path`. Por isso ela é tratada à parte.
#
# O ARQUIVO DA LOGO NÃO PODE TERMINAR EM `-symbolic.svg`
#   O applet faz `.symbolic(path.contains("-symbolic.svg"))` e achata o desenho
#   numa cor só. O nome que usamos é `meow-<flavor>.svg`, de propósito.
#
# O `gato-pop.svg` NÃO EXISTE MAIS
#   Ele era do Ritual da Aurora e era reinstalado a cada ciclo, num diretório em
#   que a chave `custom_logo_path` já apontava para um arquivo nosso. O self-heal
#   v3.56 aposentou a etapa e removeu o arquivo: `~/.config/cosmic/logos/` tem um
#   dono só, e é este projeto. Ver docs/FRONTEIRA.md.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
LOGOS_DIR="$HOME/.config/cosmic/logos"
TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1"
# (o diretório do applet LogoMenu não é mais tocado aqui — ver o bloco 3)

# Os dois nomes que o COSMIC pede para o botão de aplicativos. São dois porque o
# painel e o dock evoluíram separados e cada um pede o seu.
BOTOES=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)

FLAVOR="${FLAVOR:-mocha}"
LOGO="${LOGO:-$FLAVOR}"
ICONES_BASE="${ICONES_BASE:-Papirus-Dark}"

# ---------------------------------------------------------------------------
# `adicionar <pasta-ou-zip>` e `remover <nome>` — um acervo de ícones de fora
# ---------------------------------------------------------------------------
# O QUE A TELA PEDE, E POR QUE ELE MORA AQUI E NÃO NUM SCRIPT NOVO
#   A aba de ícones do painel oferece a chave `ICONES_BASE` — o tema que o nosso
#   herda —, e a lista dela sai do disco: todo diretório de
#   `~/.local/share/icons`, `~/.icons` e `/usr/share/icons` que tenha um
#   `index.theme` com `Directories=` e sem `Hidden=true`. Ou seja, a única forma
#   de a lista crescer é um tema novo entrar no disco, e não havia porta para
#   isso. Ela entra aqui porque este script é o dono de `~/.local/share/icons`
#   neste projeto e é quem escreve a linha `Inherits=$ICONES_BASE`: um segundo
#   script instalando tema no mesmo diretório seria a segunda verdade sobre o
#   mesmo disco — exatamente o "dois donos" que este arquivo persegue desde 08/08.
#
# O CRITÉRIO DE "ISTO É UM TEMA DE ÍCONES" NÃO É O NOME DA PASTA, É O ARQUIVO
#   `index.theme` com uma linha `Directories=` não-vazia. É a mesma regra que a
#   lista do painel usa, e ela existe por medição: sem o `Directories=`, um tema
#   de CURSOR (que também mora em `~/.local/share/icons` e também tem
#   `index.theme`) entraria na lista de temas de ícone, e escolhê-lo deixaria a
#   máquina com uma árvore sem um único ícone de aplicativo. Uma pasta de SVG
#   solta também não passa — e isso é resposta, não recusa: ícone avulso tem
#   outra porta, que é `assets/icones/overrides/`.
#
# TRÊS NOMES SÃO RECUSADOS, E CADA UM POR UM MOTIVO DIFERENTE
#   `$TEMA_NOME`  é o tema que ESTE script constrói. Deixar um pacote de fora
#                 cair em cima dele apagaria o trabalho das outras seis etapas de
#                 ícone na próxima linha do zip.
#   `hicolor`     é a hierarquia de RESERVA do freedesktop, não um tema. O
#                 `hicolor.sh` deste projeto já conserta o `index.theme` dela;
#                 sobrescrevê-lo esconde ícone de jogo da Steam (medido em 04/08).
#   `default`     é o ponteiro do compositor, escrito pelo `scripts/cursor.sh`.
#                 Um zip que se chamasse assim trocaria o cursor da tela inteira.
#
# O ARGUMENTO É DE FORA, E É TRATADO COMO TAL
#   Sem `eval`, sem `shell=True`: o caminho entra citado, o zip é aberto num
#   temporário (nunca no destino) e o que vira diretório é o `basename` peneirado
#   para `[A-Za-z0-9._-]`, nunca o caminho que veio dentro do pacote.
_ci_nome_seguro() {
  local n="$1"
  n="${n//[^A-Za-z0-9._-]/-}"
  n="${n#"${n%%[!.-]*}"}"
  printf '%s' "${n:0:80}"
}

_ci_nome_recusado() {
  case "$1" in
    "$TEMA_NOME") meow_erro "'$1' é o tema que este script constrói — recusado"; return 0 ;;
    hicolor)      meow_erro "'hicolor' é a hierarquia de reserva do sistema, não um tema — recusado"; return 0 ;;
    default)      meow_erro "'default' é o tema de ponteiro do compositor — recusado"; return 0 ;;
  esac
  return 1
}

# Um `index.theme` que declara pastas de tamanho: é o que separa tema de ícone de
# tema de cursor. `grep -q` sem regex complicada — a linha é `Directories=` com
# pelo menos um caractere depois.
_ci_e_tema_de_icones() {
  [ -f "$1/index.theme" ] && grep -qiE '^[[:space:]]*Directories[[:space:]]*=[[:space:]]*[^[:space:]]' "$1/index.theme"
}

# Instala UM diretório de tema. 0 = já idêntico · 1 = instalado · 2 = erro.
#
# A idempotência é por CONTEÚDO (regra 5 do projeto): "já existe uma pasta com
# esse nome" responderia 0 para um tema copiado pela metade, que é justamente o
# estado que a cópia em dois tempos abaixo existe para evitar.
_ci_instalar_tema() {
  local origem="$1" nome destino palco
  nome="$(_ci_nome_seguro "$(basename -- "$origem")")"
  [ -n "$nome" ] || { meow_erro "nome de tema vazio dentro do pacote"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  destino="$HOME/.local/share/icons/$nome"
  meow_destino_permitido "$destino" || return "$MEOW_ERRO"

  if [ -d "$destino" ]; then
    if meow_tem diff; then
      if diff -rq -- "$origem" "$destino" >/dev/null 2>&1; then
        meow_ok "o tema de ícones '$nome' já está instalado e idêntico"
        return "$MEOW_OK"
      fi
      meow_info "'$nome' está no disco e difere do pacote — substituindo"
    else
      meow_ok "o tema de ícones '$nome' já está instalado (sem 'diff' para comparar)"
      return "$MEOW_OK"
    fi
  fi

  if meow_seco; then
    meow_muda "instalaria o tema de ícones '$nome' em $HOME/.local/share/icons"
    return "$MEOW_DIVERGENTE"
  fi

  mkdir -p "$HOME/.local/share/icons" || return "$MEOW_ERRO"
  # O palco nasce DENTRO do diretório de destino: `mv` entre sistemas de arquivos
  # não é atômico (TRAVA 2 do lib/comum.sh), e um tema de ícones tem milhares de
  # arquivos — tempo de sobra para um corte no meio.
  palco="$(mktemp -d -p "$HOME/.local/share/icons" ".meow-tema.XXXXXX")" || return "$MEOW_ERRO"
  if ! cp -a -- "$origem/." "$palco/"; then
    rm -rf "$palco"; meow_erro "não consegui copiar o tema '$nome'"; return "$MEOW_ERRO"
  fi
  chmod 755 "$palco"
  rm -rf "$destino"
  if ! mv -f "$palco" "$destino"; then
    rm -rf "$palco"; meow_erro "falha ao mover o tema para $destino"; return "$MEOW_ERRO"
  fi
  # O manifesto é o que permite ao `--uninstall` saber o que é nosso.
  meow_manifesto_registrar "$destino/index.theme"
  meow_muda "tema de ícones '$nome' instalado em $destino"
  return "$MEOW_DIVERGENTE"
}

_ci_colher_temas() {
  find "$1" -maxdepth 3 -type f -name index.theme -print0 2>/dev/null
}

_ci_adicionar() {
  local alvo="${1:-}" rc="$MEOW_OK" achou=0 e d
  if [ -z "$alvo" ]; then
    meow_erro "uso: construir_icones.sh adicionar <pasta-ou-zip>"
    return "$MEOW_ERRO"
  fi

  # ── uma pasta já aberta ───────────────────────────────────────────────────
  if [ -d "$alvo" ]; then
    if _ci_e_tema_de_icones "$alvo"; then
      _ci_instalar_tema "$alvo"; return $?
    fi
    while IFS= read -r -d '' d; do
      d="$(dirname -- "$d")"
      _ci_e_tema_de_icones "$d" || continue
      _ci_instalar_tema "$d"; e=$?
      [ "$e" -ge 2 ] && return "$e"
      [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
      achou=1
    done < <(_ci_colher_temas "$alvo")
    [ "$achou" = "1" ] || {
      meow_erro "'$alvo' não tem um index.theme com 'Directories=' — não é tema de ícones"
      meow_info "  para um ícone avulso o caminho é assets/icones/overrides/"
      return "$MEOW_ERRO"; }
    meow_registrar "construir_icones.sh adicionar '$alvo'"
    return "$rc"
  fi

  [ -f "$alvo" ] || { meow_erro "não achei '$alvo'"; return "$MEOW_ERRO"; }
  case "$alvo" in
    *.zip|*.ZIP) : ;;
    *) meow_erro "só sei abrir .zip aqui (ou uma pasta de tema já aberta)"
       return "$MEOW_ERRO" ;;
  esac

  # No seco não se extrai: extrair é escrever, e `MEOW_DRY_RUN=1` promete não
  # escrever NADA — o `tests/seco.sh` roda num HOME de brinquedo justamente para
  # pegar quem escreve "só num temporário". O nome vira palpite, e diz-se que é.
  if meow_seco; then
    local palpite; palpite="$(_ci_nome_seguro "$(basename -- "${alvo%.*}")")"
    if [ -n "$palpite" ] && [ -d "$HOME/.local/share/icons/$palpite" ]; then
      meow_ok "o tema de ícones '$palpite' já está instalado"
      return "$MEOW_OK"
    fi
    meow_muda "instalaria um tema de ícones de '$alvo' em $HOME/.local/share/icons"
    meow_info "  no seco o nome é palpite pelo arquivo; quem decide é o conteúdo do pacote"
    return "$MEOW_DIVERGENTE"
  fi

  meow_tem unzip || { meow_erro "falta unzip"; return "$MEOW_SEM_DEPENDENCIA"; }
  local tmp
  tmp="$(mktemp -d -p "${TMPDIR:-/tmp}" ".meow-tema-add.XXXXXX")" || return "$MEOW_ERRO"
  if ! unzip -q -o -- "$alvo" -d "$tmp/x" 2>/dev/null; then
    rm -rf "$tmp"; meow_erro "o zip veio corrompido — nada instalado"; return "$MEOW_ERRO"
  fi
  while IFS= read -r -d '' d; do
    d="$(dirname -- "$d")"
    _ci_e_tema_de_icones "$d" || continue
    _ci_instalar_tema "$d"; e=$?
    if [ "$e" -ge 2 ]; then rm -rf "$tmp"; return "$e"; fi
    [ "$e" = "1" ] && rc="$MEOW_DIVERGENTE"
    achou=1
  done < <(_ci_colher_temas "$tmp/x")
  rm -rf "$tmp"

  if [ "$achou" = "0" ]; then
    meow_erro "o pacote não tem um index.theme com 'Directories=' — não é tema de ícones"
    meow_info "  para um ícone avulso o caminho é assets/icones/overrides/"
    return "$MEOW_ERRO"
  fi
  meow_registrar "construir_icones.sh adicionar '$alvo'"
  return "$rc"
}

# O desfazer do `adicionar`. Só apaga em `~/.local/share/icons`: tema de
# `/usr/share/icons` é do gerenciador de pacotes (a TRAVA 1 recusa o caminho de
# qualquer jeito) e tema em `~/.icons` não foi este script que pôs lá. E se o que
# sair for o `ICONES_BASE` em vigor, a herança do nosso tema aponta para o vazio
# — então avisa-se, em vez de deixar a máquina descobrir sozinha.
_ci_remover() {
  local nome; nome="$(_ci_nome_seguro "${1:-}")"
  [ -n "$nome" ] || { meow_erro "uso: construir_icones.sh remover <nome>"; return "$MEOW_ERRO"; }
  _ci_nome_recusado "$nome" && return "$MEOW_ERRO"
  local dir="$HOME/.local/share/icons/$nome"
  if [ ! -d "$dir" ]; then
    meow_pula "'$nome' não está em $HOME/.local/share/icons — nada a remover"
    return "$MEOW_OK"
  fi
  meow_destino_permitido "$dir" || return "$MEOW_ERRO"
  if meow_seco; then
    meow_muda "removeria $dir"; return "$MEOW_DIVERGENTE"
  fi
  rm -rf "$dir" || { meow_erro "não consegui remover $dir"; return "$MEOW_ERRO"; }
  meow_muda "tema de ícones '$nome' removido de $HOME/.local/share/icons"
  [ "$nome" = "$ICONES_BASE" ] && \
    meow_aviso "esse era o ICONES_BASE — troque a chave antes do próximo 'meow aplicar'"
  meow_registrar "construir_icones.sh remover $nome"
  return "$MEOW_DIVERGENTE"
}

# O DESPACHO É ANTES DE TUDO, E SÓ RECONHECE OS DOIS VERBOS NOVOS
#   Argumento nenhum continua sendo a construção do tema, que é como o
#   `install.sh` e o `bin/meow` chamam este script desde sempre. Um argumento
#   desconhecido vira ERRO (2) em vez de cair calado na construção: a lição está
#   escrita no `instalar_fontes.sh`, onde `--dry-run` — o nome da VARIÁVEL
#   documentada — caía no ramo que ESCREVE com quem digitou jurando que só tinha
#   conferido.
case "${1:-}" in
  "")        : ;;
  adicionar) _ci_adicionar "${2:-}"; exit $? ;;
  remover)   _ci_remover   "${2:-}"; exit $? ;;
  *)
    meow_erro "argumento desconhecido: $1"
    meow_info "  uso: construir_icones.sh [adicionar <pasta-ou-zip> | remover <nome>]"
    meow_info "  sem argumento, ele constrói o tema '$TEMA_NOME'"
    exit "$MEOW_ERRO" ;;
esac

# Os `<tam>/places` que existem DE FATO dentro do tema, um por linha. O glob do
# bash já devolve ordenado, então a lista é estável entre execuções — requisito
# para o `meow_escrever` conseguir comparar por conteúdo. O filtro `NxN` existe
# porque um diretório de nome inesperado viraria um `Size=` inválido no índice.
#
# `scalable` ENTROU EM 08/08/2026, e não é simetria gratuita com o `status`
#   `scalable/places` é onde o `icones_pastas.sh` põe as pastas especiais em
#   Catppuccin. Sem estar aqui, o diretório existiria no disco e NINGUÉM o
#   acharia — é o erro clássico de quem monta tema de ícones à mão, e este
#   projeto já o cometeu uma vez com os próprios `<tam>/places`.
places_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/places; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/places}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

# `scalable/mimetypes` é o pack Catppuccin vestindo TIPO DE ARQUIVO, posto lá pelo
# `icones_mimetypes.sh`. Vale a mesma regra do §1: declarar só o que EXISTE. Se a
# lista viesse fixa, uma máquina sem o pack teria um `Directories=` apontando para
# o vazio — e foi exatamente esse o defeito que custou as "três rodadas".
tem_mimetypes() { [ -d "$TEMA_DIR/scalable/mimetypes" ]; }

# `512x512/apps` é o acervo Catppuccin de APLICATIVO (PNG com alpha, posto pelo
# icones_apps.sh). Fica num tamanho fixo, e não em `scalable/`, porque é raster:
# declarar raster como escalável é o defeito que o thunderbird.png já cometeu
# aqui — e que foi consertado em 10/08/2026 pelo mesmo princípio (o raster do
# `hicolor` agora vai para o diretório do tamanho real dele). Vem ANTES de `scalable/apps` na lista para vencer o desenho autoral nos
# nomes em que os dois existem — a ordem de `Directories=` é a ordem de busca.
tem_apps_png() { [ -d "$TEMA_DIR/512x512/apps" ]; }

# Os `<tam>/apps` que existem no disco, do MENOR para o maior — e a razão de
# existirem é o serrilhado.
#
# Até 08/08/2026 o acervo raster de aplicativo morava só em `512x512/apps`, e a
# dock, que desenha a 48 px, recebia um PNG de 512 para reduzir 10,7× em tempo de
# desenho. Ela viu na tela: "cheio de serrilhados". Agora o `icones_apps.sh`
# entrega 48, 64, 128 e 256 já reduzidos com Lanczos, e o resolvedor pega o
# tamanho exato — mas só se ele estiver DECLARADO aqui. Diretório no disco que
# ninguém declara é diretório que ninguém acha (§2 do COSMIC-THEMING), e este
# projeto já cometeu esse erro uma vez com os próprios `<tam>/places`.
#
# Derivado do disco, como todo o resto deste arquivo: assim um tamanho novo em
# `TAMANHOS_DERIVADOS` aparece aqui sozinho, e um que saia deixa de ser
# declarado sem ninguém editar duas listas.
apps_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/apps; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/apps}")"
    case "$tam" in
      512x512|scalable) continue ;;          # esses dois têm bloco próprio
      [0-9]*x[0-9]*) printf '%s\n' "$tam" ;;
    esac
  done | sort -t x -k1,1n
}

# `48x48/apps` é o Arcticons vestindo APLICATIVO, posto lá pelo
# `icones_apps_arcticons.sh`. Mesma regra dos outros: declarar só o que EXISTE.
#
# POR QUE UM DIRETÓRIO PRÓPRIO, E POR QUE 48
#   `scalable/apps` já tem TRÊS donos (`completar_icones.sh`, `logo.sh` e o
#   bootstrap logo abaixo). O script novo precisa remover órfão quando uma linha
#   sai do mapa, e remover órfão em diretório de dono compartilhado apagaria
#   arquivo dos outros. 48 não é chute: a dock dela está em `size L` e desenha
#   ícone de aplicativo a 48 px (medido por captura de tela em 08/08/2026), e é
#   a mesma convenção do Papirus, que também guarda SVG em `48x48/apps`.
tem_apps_traco() { [ -d "$TEMA_DIR/48x48/apps" ]; }

# `<tam>/status` é o Arcticons vestindo os ícones do PRÓPRIO COSMIC, posto lá pelo
# `icones_sistema.sh`. Mesma regra dos outros: declarar só o que EXISTE.
#
# SÃO DOIS TAMANHOS DE PROPÓSITO, E ISSO FOI MEDIDO
#   O mesmo ícone entra em `22x22/status` com o traço dobrado e em
#   `scalable/status` com o traço fino do pack. Funciona porque a crate do COSMIC
#   escolhe POR TAMANHO, não pela ordem desta lista: plantando o mesmo nome nos
#   dois e rodando o `cosmic-settings` sob strace, ele abriu o grande mesmo com o
#   22x22 declarado primeiro. É o que dá à barra um traço que se enxerga a 22px
#   sem engrossar o ícone das Configurações.
status_no_disco() {
  local d tam
  for d in "$TEMA_DIR"/*/status; do
    [ -d "$d" ] || continue
    tam="$(basename "${d%/status}")"
    case "$tam" in
      [0-9]*x[0-9]*|scalable) printf '%s\n' "$tam" ;;
    esac
  done
}

indice() {
  local dirs="" tam
  # Ordem crescente, derivada do disco. Não é ela que DECIDE — o resolvedor
  # escolhe pelo tamanho mais próximo (ver o cabeçalho do icones_apps.sh) —, mas é
  # a ordem que o `hicolor.sh` adota pelo mesmo motivo e mantém o arquivo legível.
  # `apps_no_disco` cobre TODO `<tam>/apps`, o do Arcticons e os derivados do
  # acervo raster: uma lista só, para não haver duas verdades sobre o mesmo disco.
  while IFS= read -r tam; do [ -n "$tam" ] && dirs="$dirs$tam/apps,"; done < <(apps_no_disco)
  tem_apps_png && dirs="${dirs}512x512/apps,"
  dirs="${dirs}scalable/apps"
  tem_mimetypes && dirs="$dirs,scalable/mimetypes"
  while IFS= read -r tam; do dirs="$dirs,$tam/status"; done < <(status_no_disco)
  while IFS= read -r tam; do dirs="$dirs,$tam/places"; done < <(places_no_disco)

  cat <<FIM
[Icon Theme]
Name=$TEMA_NOME
Comment=Catppuccin $FLAVOR para o COSMIC — gerado pelo MeowSystem-Theme
Inherits=$ICONES_BASE,breeze-dark,Cosmic,Adwaita,hicolor
Directories=$dirs

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=8
MaxSize=512
FIM

  while IFS= read -r tam; do
    [ -n "$tam" ] || continue
    cat <<FIM

[$tam/apps]
Size=${tam%%x*}
Context=Applications
Type=Fixed
FIM
  done < <(apps_no_disco)

  if tem_apps_png; then
    cat <<'FIM'

[512x512/apps]
Size=512
Context=Applications
Type=Fixed
FIM
  fi

  # (o bloco de `48x48/apps` sai do laço genérico acima, junto com 64, 128 e 256.
  #  Havia um `if tem_apps_traco` fixo aqui e ele passou a duplicar a seção quando
  #  os derivados nasceram — `Type=Fixed` com SVG dentro convive, é o que o
  #  Papirus faz no `48x48/apps` dele, mas declarar duas vezes o mesmo diretório
  #  é um índice que se contradiz.)

  if tem_mimetypes; then
    cat <<'FIM'

[scalable/mimetypes]
Size=64
Context=MimeTypes
Type=Scalable
MinSize=8
MaxSize=512
FIM
  fi

  while IFS= read -r tam; do
    if [ "$tam" = scalable ]; then
      cat <<FIM

[scalable/status]
Size=48
Context=Status
Type=Scalable
MinSize=8
MaxSize=512
FIM
    else
      cat <<FIM

[$tam/status]
Size=${tam%%x*}
Context=Status
Type=Fixed
FIM
    fi
  done < <(status_no_disco)

  while IFS= read -r tam; do
    if [ "$tam" = scalable ]; then
      cat <<FIM

[scalable/places]
Size=48
Context=Places
Type=Scalable
MinSize=8
MaxSize=512
FIM
    else
      cat <<FIM

[$tam/places]
Size=${tam%%x*}
Context=Places
Type=Fixed
FIM
    fi
  done < <(places_no_disco)
}

mudou=0

# --- 1. o índice do tema ----------------------------------------------------
# `Directories=` é a ÚNICA chave de tamanho que a crate do COSMIC lê; Type,
# MinSize e MaxSize são texto morto para ela (medido). Ficam por educação, para
# outros toolkits que leiam o mesmo tema.
#
# O ÍNDICE DESCREVE O QUE ESTÁ NO DISCO — E É ISSO QUE IMPEDE UM LAÇO ETERNO
#   MEDIDO em 2026-08-04, com o auto-reparo diário já ligado: este script gravava
#   `Directories=scalable/apps` FIXO, e o `construir_pastas.sh` reescrevia a mesma
#   linha acrescentando os `<tam>/places`. Cada um desfazia o outro, e os DOIS
#   devolviam 1 ("estava divergente, consertei") em TODA rodada — seis rodadas
#   seguidas em teste, sem nunca convergir.
#   As consequências não eram cosméticas: o `meow doctor` acusava divergência para
#   sempre, o timer das 5h consertaria e avisaria todo dia (exatamente o que o
#   auto-reparo existe para não fazer), e no intervalo entre a gravação daqui e a
#   do outro script as pastas dela ficavam FORA do índice — isto é, azuis,
#   herdadas do Papirus, até a rodada seguinte.
#   A correção é não ter dois donos da mesma linha: a lista sai dos diretórios que
#   existem em `$TEMA_DIR`. O que o `construir_pastas.sh` instalar entra no índice
#   na próxima passagem por aqui, e a condição `grep -q 48x48/places` dele nunca
#   mais dispara. Numa máquina recém-instalada isso custa uma gravação a mais na
#   segunda rodada (a primeira roda antes de os diretórios existirem); da terceira
#   em diante não se escreve mais nada.
meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
case $? in 1) mudou=1 ;; 2) meow_erro "não consegui escrever o index.theme"; exit "$MEOW_ERRO" ;; esac

# --- 2. o gato do botão -----------------------------------------------------
# O PISO SAI DO ACERVO DELA, NÃO DE UM GATO GERADO
#   Até 08/08/2026 este piso era `assets/meow-<flavor>-painel.svg`, desenhado por
#   `scripts/gerar_gato.py`. Ela mandou excluir os gatos do projeto e ficar só
#   com a Coquinha e o Mimir, então o gerador e os SVG foram embora — e com eles
#   o único caminho que este script conhecia.
#
#   Acervo vazio não é erro daqui: quem sabe dizer isso é o `logo.sh`, que já
#   avisa "solte um .svg lá e ele entra". Abortar com 3 faria a etapa de ícones
#   inteira parar por causa de uma pasta de gatos vazia — e o tema de ícones não
#   tem nada que ver com o acervo.
GATO_PISO=""
if [ -d "$RAIZ/assets/gatos" ]; then
  GATO_PISO="$(find "$RAIZ/assets/gatos" -maxdepth 1 -name '*.svg' \
                 ! -name '*-symbolic.svg' | sort | head -n1)"
fi
# SÓ NO BOOTSTRAP — O DONO DESTE ARQUIVO PASSOU A SER O logo.sh EM 05/08/2026
#   Este laço escrevia o gato do dock a partir de um caminho FIXO
#   (`assets/meow-${FLAVOR}-painel.svg`), em toda rodada. O efeito, medido no dia
#   em que ela apontou o gato do canto e perguntou por que não era a Coquinha:
#   o ícone que ela olha todo dia NUNCA participou da rotação, e a rotação
#   inteira mirava no applet Logo Menu, que não está montado em barra nenhuma.
#
#   Agora quem veste o botão é o `scripts/logo.sh`, que é o dono do acervo e de
#   quem está no ar. Aqui fica só o bootstrap: se o arquivo ainda não existe
#   (máquina nova, antes de a etapa de logo rodar), põe o gato do flavor para
#   que não haja um botão sem ícone no meio da instalação. Escrever sempre
#   traria de volta os DOIS DONOS descritos no §3 logo abaixo — e aquele defeito
#   desfazia a rotação em silêncio a cada `install.sh`.
if [ -n "$GATO_PISO" ]; then
  for nome in "${BOTOES[@]}"; do
    [ -f "$TEMA_DIR/scalable/apps/$nome.svg" ] && continue
    meow_escrever "$TEMA_DIR/scalable/apps/$nome.svg" "$(cat "$GATO_PISO")" 644
    case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar $nome"; exit "$MEOW_ERRO" ;; esac
  done
fi

# --- 3. a logo do painel (caminho de arquivo, não tema) ---------------------
# O ARQUIVO É DAQUI; A CHAVE QUE APONTA PARA ELE É DO `scripts/logo.sh`.
#
# Até 05/08/2026 este script escrevia os dois, e aí nasceu a rotação de gatos —
# que também precisa da chave. Ficaram DOIS DONOS DA MESMA LINHA, o modo de
# falha que este projeto persegue desde o começo: girei para `mimir`, rodei o
# `install.sh`, e a etapa de ícones (que roda ANTES da de logo) devolveu tudo
# para `meow-mocha.svg`. Medido, e não deduzido — a rotação se desfazia sozinha
# a cada instalação, sem erro nenhum na tela.
#
# A DIVISÃO ACABOU EM 08/08/2026: ESTA SEÇÃO NÃO ESCREVE MAIS NADA.
#
# O que havia aqui era o "piso" — garantir que `~/.config/cosmic/logos/
# meow-<flavor>.svg` existisse, copiado do gato gerado do flavor. Com os gatos
# do projeto excluídos a pedido dela (só Coquinha e Mimir), o piso perdeu a
# fonte; e ele já era o último resquício dos dois donos: o `logo.sh` instala
# TODOS os gatos do acervo neste mesmo diretório e remove os `meow-*.svg` que
# não estão no acervo — ou seja, ele apagava este arquivo a cada rodada e este
# script o recriava na seguinte. Medido no disco em 08/08: `meow-mocha.svg`
# continuava lá, sozinho, sem participar de rotação nenhuma.
#
# Agora o diretório tem dono único, e é o `logo.sh`.

# --- 4. selecionar o tema ---------------------------------------------------
# Sem isto nada acima aparece: o tema só entra na busca se for O SELECIONADO.
#
# A troca do NOME do tema é o único evento que obriga a reiniciar o painel (ver
# o bloco 5). Marcamos aqui, antes de escrever: se a chave já apontava para o
# nosso tema, não houve troca de nome.
tema_mudou_de_nome=0
[ "$(cat "$TK/icon_theme" 2>/dev/null)" = "\"$TEMA_NOME\"" ] || tema_mudou_de_nome=1
meow_escrever "$TK/icon_theme" "\"$TEMA_NOME\"" 644
case $? in 1) mudou=1 ;; esac

if [ "$mudou" = "0" ]; then
  meow_ok "ícones e logo já no lugar"
  exit "$MEOW_OK"
fi

if meow_seco; then
  exit "$MEOW_DIVERGENTE"
fi

# --- 5. fazer o COSMIC reler ------------------------------------------------
# O cosmic-panel e o cosmic-app-list leem a config no início da sessão e não a
# vigiam. SIGTERM: o cosmic-session respawna em ~4ms e trata exit 15 como
# "reiniciar" — é o mesmo caminho que o vigia do painel fantasma usa.
# SÓ REINICIA O PAINEL SE O TEMA MUDOU DE NOME — e isto custou a tela dela duas vezes.
#
# O cosmic-panel não vigia NADA DISTO — mas vigia outras coisas, e a frase que
# estava aqui ("zero fds de inotify, medido") era falsa. Medido de novo em
# 05/08/2026 por `/proc/<pid>/fdinfo/*`: ele mantém SEIS watches, sobre
# `CosmicPanel/v1`, `CosmicPanel.Panel/v1`, `CosmicPanel.Dock/v1`,
# `CosmicTheme.Mode/v1`, `CosmicTheme.Light/v2` e `CosmicTheme.Dark/v2`.
# O que ele NÃO vigia é o `CosmicTk/icon_theme` e os arquivos de ícone — que são
# justamente o que este script mexe. Ou seja: a conclusão abaixo continua de pé,
# só a justificativa estava errada. (É por isso que o `vidro.sh`, que escreve em
# `CosmicPanel.*/v1`, aplica na hora sem reiniciar nada.)
#
# Um ícone reescrito só aparece no próximo início dele. A tentação é reiniciar
# sempre que algo mudar. O problema é que reiniciar tem custo real e cumulativo:
#   - a tela dela PISCA a cada vez;
#   - o respawn do cosmic-session tem limite, e depois de muitas mortes na mesma
#     sessão ele desiste — foi assim que ela ficou sem painel e sem dock duas
#     vezes em 04/08/2026, numa máquina de uma tela só;
#   - e se a gente sobe um painel enquanto o session acorda, ficam DOIS painéis
#     empilhados (aconteceu, ela mandou a captura rindo).
#
# Trocar o NOME do tema de ícones é o único evento que realmente exige o
# reinício, e acontece uma vez por instalação. Ícone reescrito dentro do mesmo
# tema espera o próximo login — e o script diz isso em voz alta, em vez de
# derrubar o painel dela para economizar uma espera.
precisa_reiniciar=0
[ "$tema_mudou_de_nome" = "1" ] && precisa_reiniciar=1

# DUAS RECUSAS ANTES DE MATAR — as duas custaram a tela dela em 26/08/2026.
#
# (1) HOME DE BRINQUEDO AINDA MATA O PAINEL DE VERDADE.
#     O `tests/convergencia.sh:25` roda tudo com `env -i HOME="$H"`, num HOME
#     descartável — e é o certo: nada do ~/.config dela é tocado. Mas o `pgrep`
#     e o `pkill` logo abaixo NÃO olham HOME nenhum: eles varrem a tabela de
#     processos da máquina e derrubam o cosmic-panel da SESSÃO REAL. Rodar a
#     suíte de testes com ela usando o computador apagava topbar e dock.
#     Se o HOME não é o do dono da sessão gráfica, este script não tem painel
#     nenhum para reiniciar — o dele é imaginário.
#
# (2) MATAR SÓ VALE SE ALGUÉM FOR RESSUSCITAR.
#     O comentário acima diz "o cosmic-session respawna em ~4ms". Isso é
#     verdade no começo da sessão e MENTIRA depois: o backoff dele é
#     `2^restarts` ms vezes um inteiro sorteado de 0 a 9, sem teto, e o contador
#     nunca zera por sucesso. Medido em 26/08/2026, no restart 23, a espera saiu
#     `58720256ms` — 16h18min. Matar o painel nesse estado não é reiniciar: é
#     apagar a barra até o próximo login.
#     A espera vigente está no journal do próprio supervisor, de graça.
_ci_home_e_da_sessao() {
  local dono
  dono="$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)"
  [ -n "$dono" ] && [ "$HOME" = "$dono" ]
}
_ci_espera_do_supervisor() {   # ms que o cosmic-session vai dormir, ou vazio
  journalctl --user -b -t cosmic-session --no-pager 2>/dev/null \
    | grep -oE 'sleeping for [0-9]+ms before restarting process cosmic-panel' \
    | tail -1 | grep -oE '[0-9]+'
}

if [ "$precisa_reiniciar" = "1" ] && ! _ci_home_e_da_sessao; then
  meow_aviso "HOME de teste ($HOME): não reinicio o painel da sessão real"
  meow_info  "  o pkill não conhece HOME — mataria a barra de quem está usando a máquina"
  precisa_reiniciar=0
fi

if [ "$precisa_reiniciar" = "1" ]; then
  _ci_espera="$(_ci_espera_do_supervisor)"
  case "$_ci_espera" in
    ''|*[!0-9]*) : ;;   # sem registro: o supervisor ainda não falhou, pode matar
    *)
      if [ "$_ci_espera" -gt 5000 ]; then
        meow_aviso "não vou reiniciar o painel: o cosmic-session dormiria $(( _ci_espera / 60000 ))min antes de trazê-lo de volta"
        meow_info  "  os ícones novos aparecem no próximo login, que é quando o contador zera"
        meow_info  "  (o backoff é 2^restarts x sorteio(0..9) ms, sem teto e sem zerar por sucesso)"
        precisa_reiniciar=0
      fi
      ;;
  esac
fi

if [ "$precisa_reiniciar" = "0" ]; then
  meow_ok "tema '$TEMA_NOME' atualizado (os ícones novos aparecem no próximo login)"
  exit "$MEOW_DIVERGENTE"
fi

# O RECICLAR ENTRA PELA PORTA ÚNICA — 26/08/2026
#   Este bloco fazia `pkill -x cosmic-panel` e, se o respawn não viesse em 10s,
#   `setsid cosmic-panel &`. Os dois pedaços eram bugs conhecidos, e os dois
#   custaram a tela dela:
#
#   1. `setsid cosmic-panel` SEM sanear o ambiente é o bug de um caractere de
#      25/08: sem `env -i` o painel herda `PANEL_NOTIFICATIONS_FD` e
#      `X_PRIVILEGED_WAYLAND_SOCKET` de quem chamou, e sobe SEM bandeja e SEM
#      botão de desligar (panic em libcosmic wayland_handler.rs:110 para
#      StatusArea, Power, Audio e Network). E isto roda desatendido às 05:00,
#      pelo meow-doctor.timer.
#   2. `pgrep -x cosmic-panel` como prova de sucesso responde "existe algum?",
#      não "voltou o meu" — declara vitória vendo o processo velho agonizando,
#      ou o painel de outro spawner.
#
#   Além disso, ter DOIS spawners no projeto é o que produz dois painéis
#   disputando as mesmas layer surfaces. Agora existe um: scripts/painel.sh.
#   Ele sabe sanear o ambiente, sabe se o cosmic-session ainda socorre (o
#   backoff dele não tem teto e nunca zera), e recusa matar quando ninguém vai
#   repor — inclusive quando este script roda num HOME de teste.
if pgrep -x cosmic-panel >/dev/null 2>&1; then
  "$RAIZ/scripts/painel.sh" reciclar || {
    meow_erro "não consegui reciclar o painel — os ícones novos aparecem no próximo login"
    meow_info "  diagnóstico: meow painel estado"
    exit "$MEOW_ERRO"
  }
fi

meow_ok "tema '$TEMA_NOME' instalado e ativo"
exit "$MEOW_DIVERGENTE"
