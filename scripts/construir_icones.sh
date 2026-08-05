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
# NÃO MEXEMOS NO `gato-pop.svg`
#   Aquele arquivo é do Ritual da Aurora, reinstalado a cada ciclo. Apontamos a
#   chave para um arquivo NOSSO e o deixamos em paz — assim os dois convivem sem
#   ninguém desfazer o trabalho do outro de hora em hora.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

TEMA_NOME="${NOME_TEMA_ICONES:-MeowSystem-Icons}"
TEMA_DIR="$HOME/.local/share/icons/$TEMA_NOME"
LOGOS_DIR="$HOME/.config/cosmic/logos"
TK="$HOME/.config/cosmic/com.system76.CosmicTk/v1"
APPLET="$HOME/.config/cosmic/dev.cappsy.CosmicExtAppletLogoMenu/v1"

# Os dois nomes que o COSMIC pede para o botão de aplicativos. São dois porque o
# painel e o dock evoluíram separados e cada um pede o seu.
BOTOES=(com.system76.CosmicPanelAppButton com.system76.CosmicAppLibrary)

FLAVOR="${FLAVOR:-mocha}"
LOGO="${LOGO:-$FLAVOR}"
ICONES_BASE="${ICONES_BASE:-Papirus-Dark}"

indice() {
  cat <<FIM
[Icon Theme]
Name=$TEMA_NOME
Comment=Catppuccin $FLAVOR para o COSMIC — gerado pelo MeowSystem-Theme
Inherits=$ICONES_BASE,breeze-dark,Cosmic,Adwaita,hicolor
Directories=scalable/apps

[scalable/apps]
Size=128
Context=Applications
Type=Scalable
MinSize=8
MaxSize=512
FIM
}

mudou=0

# --- 1. o índice do tema ----------------------------------------------------
# `Directories=` é a ÚNICA chave de tamanho que a crate do COSMIC lê; Type,
# MinSize e MaxSize são texto morto para ela (medido). Ficam por educação, para
# outros toolkits que leiam o mesmo tema.
meow_escrever "$TEMA_DIR/index.theme" "$(indice)" 644
case $? in 1) mudou=1 ;; 2) meow_erro "não consegui escrever o index.theme"; exit "$MEOW_ERRO" ;; esac

# --- 2. o gato do botão -----------------------------------------------------
GATO_PAINEL="$RAIZ/assets/meow-${FLAVOR}-painel.svg"
if [ ! -f "$GATO_PAINEL" ]; then
  meow_erro "falta $GATO_PAINEL — rode scripts/gerar_gato.py"
  exit "$MEOW_SEM_DEPENDENCIA"
fi
for nome in "${BOTOES[@]}"; do
  meow_escrever "$TEMA_DIR/scalable/apps/$nome.svg" "$(cat "$GATO_PAINEL")" 644
  case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar $nome"; exit "$MEOW_ERRO" ;; esac
done

# --- 3. a logo do painel (caminho de arquivo, não tema) ---------------------
LOGO_SVG="$RAIZ/assets/meow-${LOGO}-painel.svg"
[ -f "$LOGO_SVG" ] || LOGO_SVG="$GATO_PAINEL"
DESTINO_LOGO="$LOGOS_DIR/meow-${FLAVOR}.svg"
meow_escrever "$DESTINO_LOGO" "$(cat "$LOGO_SVG")" 644
case $? in 1) mudou=1 ;; 2) meow_erro "falhou ao instalar a logo"; exit "$MEOW_ERRO" ;; esac

# O RON quer a string entre aspas e SEM newline no fim — é assim que o COSMIC
# grava, e um \n a mais faz o applet ignorar o valor calado.
meow_escrever "$APPLET/custom_logo_path" "\"$DESTINO_LOGO\"" 644
case $? in 1) mudou=1 ;; esac
meow_escrever "$APPLET/custom_logo_active" "true" 644
case $? in 1) mudou=1 ;; esac

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
# O cosmic-panel não vigia arquivo nenhum (zero fds de inotify, medido): um ícone
# reescrito só aparece no próximo início dele. A tentação é reiniciar sempre que
# algo mudar. O problema é que reiniciar tem custo real e cumulativo:
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

if [ "$precisa_reiniciar" = "0" ]; then
  meow_ok "tema '$TEMA_NOME' atualizado (os ícones novos aparecem no próximo login)"
  exit "$MEOW_DIVERGENTE"
fi

if pgrep -x cosmic-panel >/dev/null 2>&1; then
  pkill -x cosmic-panel
  voltou=0
  for _ in $(seq 1 20); do
    sleep 0.5
    if pgrep -x cosmic-panel >/dev/null 2>&1; then voltou=1; break; fi
  done

  # NUNCA CONFIAR NO RESPAWN — aprendido na tela dela, em 04/08/2026.
  # O `cosmic-session` normalmente ressuscita o painel em ~4ms, e a versão
  # anterior deste bloco apenas ESPERAVA por isso. Mas o respawn tem limite: com
  # o painel morto e revivido muitas vezes na mesma sessão (388 registros no
  # journal daquele boot), o session desistiu — e o script seguiu imprimindo
  # "tema instalado e ativo" enquanto a Vitória ficava SEM painel e SEM dock,
  # numa máquina de UMA tela só. Mentir sobre o sucesso é o pior modo de falha
  # possível: ela só descobriu olhando.
  #
  # Agora, se o respawn não vier, subimos o painel nós mesmos. `setsid` para ele
  # não morrer junto com este script.
  if [ "$voltou" = "0" ]; then
    meow_aviso "o cosmic-session não trouxe o painel de volta — subindo eu mesma"
    setsid cosmic-panel >/dev/null 2>&1 &
    for _ in $(seq 1 20); do
      sleep 0.5
      if pgrep -x cosmic-panel >/dev/null 2>&1; then voltou=1; break; fi
    done
  fi

  if [ "$voltou" = "0" ]; then
    meow_erro "o painel NÃO voltou. Rode 'setsid cosmic-panel &' ou relogue."
    exit "$MEOW_ERRO"
  fi
fi

meow_ok "tema '$TEMA_NOME' instalado e ativo"
exit "$MEOW_DIVERGENTE"
