#!/usr/bin/env bash
# desinstalar.sh — tira o MeowSystem da máquina. Lê o manifesto; não adivinha.
#
# ESTE ARQUIVO É `source`, NÃO EXECUTADO. Quem chama é `./install.sh --uninstall`.
#
# POR QUE UM MANIFESTO, E NÃO UMA LISTA ESCRITA À MÃO
#   Uma segunda lista envelheceria em silêncio: cada etapa nova escreveria num
#   lugar que o desinstalador não conhece, e ninguém descobriria isso até alguém
#   tentar desinstalar. Quem preenche o manifesto é a `meow_escrever`, que é o
#   único ponto por onde as escritas de configuração passam.
#
# A ORDEM É A PARTE QUE IMPORTA
#   Os relógios saem PRIMEIRO. O `meow-doctor.timer` dispara às 5h e reaplica
#   tudo — desinstalar com ele ligado é desinstalar até a próxima madrugada.
#
# O QUE ELE NUNCA REMOVE
#   Pacote do apt (foram instalados a pedido, mas podem ser de outra coisa
#   agora), o clone do repositório, e os backups — que são a única prova do que
#   havia antes. Nem arquivo que a pessoa editou depois: o sha256 do manifesto é
#   o que separa "isto é nosso" de "isto virou dela".
meow_desinstalar() {
  meow_titulo "MeowSystem — desinstalar"
  meow_info "isto NÃO desinstala pacotes do apt nem apaga o clone do repositório"
  meow_seco && meow_aviso "modo seco: nada será removido"

  meow_passo "1/5 Relógios"
  if ! meow_seco; then
    # `|| true` porque desligar unidade que não existe devolve != 0, e isso não
    # é falha: é a máquina já estando como queremos deixá-la.
    systemctl --user disable --now \
      meow-doctor.timer meow-doctor.service \
      meow-logo.timer meow-logo.service \
      meow-wallpaper.timer meow-wallpaper.service \
      meow-assets.path meow-assets.service 2>/dev/null || true
    find "$HOME/.config/systemd/user" -maxdepth 1 -name 'meow-*' \
      \( -name '*.service' -o -name '*.timer' -o -name '*.path' \) -delete 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
    meow_ok "unidades meow-* desligadas e removidas"
  else
    meow_muda "desligaria e removeria as unidades meow-* de ~/.config/systemd/user"
  fi

  meow_passo "2/5 Tema do COSMIC"
  # O alvo é o PRIMEIRO backup de tema — o COSMIC de antes do MeowSystem NESTA
  # máquina. A captura `state/tema/original` NÃO serve para isto: ela foi tirada
  # de um home específico e está no git.
  local primeiro=""
  local d
  for d in "$MEOW_ESTADO"/backups/*-tema-PRIMEIRO-*; do
    [ -d "$d" ] && { primeiro="$d"; break; }
  done
  if [ -n "$primeiro" ]; then
    meow_info "devolvendo o COSMIC ao estado de $(basename "$primeiro" | cut -c1-19)"
    if meow_seco; then
      meow_muda "copiaria $primeiro/com.system76.CosmicTheme.* para ~/.config/cosmic/"
    else
      cp -a "$primeiro"/com.system76.CosmicTheme.* "$HOME/.config/cosmic/" 2>/dev/null || true
      meow_ok "tema devolvido"
    fi
  else
    meow_aviso "não há backup pré-instalação em $MEOW_ESTADO/backups/*-tema-PRIMEIRO-*"
    meow_info "  o tema do COSMIC fica como está — ajuste em Configurações > Aparência"
    meow_info "  (a captura state/tema/original NÃO serve: é o tema de outra máquina)"
  fi

  meow_passo "3/5 Arquivos que este projeto escreveu"
  if [ -f "$MEOW_MANIFESTO" ]; then
    # O clone tem de sair da conta ANTES do laço. A `meow_escrever` é usada
    # também para gerar arquivo DENTRO do repositório (`icons/curadoria.map`, por
    # exemplo), e essas linhas entram no manifesto como todas as outras — mas
    # aquilo é versionado, quem responde por elas é o git, e o cabeçalho deste
    # arquivo promete não tocar no clone. Sem o `-n`, um `MEOW_RAIZ` vazio viraria
    # o padrão `/*`, que casa com tudo: a guarda seria o oposto dela mesma.
    #
    # A comparação é entre caminhos CANÔNICOS, e isso não é preciosismo: aqui
    # `~/Desenvolvimento` é um symlink para `/mnt/Apate/Desenvolvimento`, então o
    # mesmo arquivo do clone tem dois nomes e só um deles começa com o
    # `$MEOW_RAIZ`. É o mesmo `readlink -m` que a TRAVA 1 usa, pelo mesmo motivo.
    local raiz_clone=""
    [ -n "${MEOW_RAIZ:-}" ] && raiz_clone="$(readlink -m -- "$MEOW_RAIZ")"
    local alvo _quando sha agora real n=0
    while IFS=$'\t' read -r alvo _quando sha; do
      [ -n "$alvo" ] || continue
      if [ -n "$raiz_clone" ]; then
        real="$(readlink -m -- "$alvo")"
        case "$real" in "$raiz_clone"/*)
          meow_pula "é do clone e o git responde por ele, fica: $alvo"; continue ;;
        esac
      fi
      # Nada de fora do home: manifesto de um HOME de teste (ou de outra máquina,
      # se alguém copiar o estado) aponta para caminho que não é nosso para apagar.
      case "$alvo" in "$HOME"/*) ;; *) continue ;; esac
      [ -f "$alvo" ] || continue
      agora="$(sha256sum -- "$alvo" 2>/dev/null | cut -d' ' -f1)"
      if [ -n "$sha" ] && [ "$sha" != "-" ] && [ "$agora" != "$sha" ]; then
        meow_pula "mudou depois que escrevemos, fica: $alvo"
        continue
      fi
      if meow_seco; then meow_muda "removeria $alvo"; else rm -f "$alvo"; fi
      n=$((n+1))
    done < "$MEOW_MANIFESTO"
    meow_seco || meow_ok "$n arquivo(s) removidos pelo manifesto"
  else
    meow_pula "sem manifesto em $MEOW_MANIFESTO — nada a remover por lista"
    meow_info "  o manifesto só existe a partir da primeira instalação que o gravou"
  fi

  meow_passo "4/5 Árvores inteiras"
  local dir
  for dir in "$HOME/.local/share/icons/${NOME_TEMA_ICONES:-MeowSystem-Icons}" \
             "$HOME/.local/share/fonts/MeowSystem" \
             "$HOME/.local/share/backgrounds/meowsystem"; do
    [ -d "$dir" ] || continue
    if meow_seco; then meow_muda "removeria $dir/"; else rm -rf "$dir"; meow_ok "removido $dir/"; fi
  done
  if ! meow_seco; then
    meow_tem gtk-update-icon-cache && gtk-update-icon-cache -f "$HOME/.local/share/icons" 2>/dev/null
    meow_tem fc-cache && fc-cache -f "$HOME/.local/share/fonts" 2>/dev/null
  fi

  meow_passo "5/5 CLI e estado"
  if meow_seco; then
    meow_muda "removeria ~/.local/bin/meow e a completion do zsh"
  else
    rm -f "$HOME/.local/bin/meow"
    # A completion mora em /usr/local/share/zsh/site-functions desde 08/2026 (o
    # porquê está no install.sh): lá quem manda é o root, e quem instala é o
    # Ritual da Aurora. Sem permissão nós não apagamos escondido nem falhamos
    # calados — dizemos o comando e seguimos.
    COMP_MEOW="${MEOW_COMPLETIONS_DIR:-/usr/local/share/zsh/site-functions}/_meow"
    if [ -e "$COMP_MEOW" ]; then
      if [ -w "$(dirname "$COMP_MEOW")" ]; then
        rm -f "$COMP_MEOW"
      else
        meow_info "a completion é do root: sudo rm -f $COMP_MEOW"
      fi
    fi
    unset COMP_MEOW
    rm -f "$MEOW_ESTADO/raiz"
    meow_ok "CLI removida"
  fi
  meow_info "o estado e os backups ficam em $MEOW_ESTADO — apague à mão se quiser"
  meow_info "se LANCADOR_SISTEMA era \"sim\": rode antes  meow desfazer --lancador"
  return 0
}
