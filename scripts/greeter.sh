#!/usr/bin/env bash
# greeter.sh — a TELA DE LOGIN também é dela.
#
# O QUE ESTAVA ACONTECENDO
#   O `cosmic-greeter` roda como um usuário próprio (`cosmic-greeter`, uid 987) e
#   lê a configuração dele em `/var/lib/cosmic-greeter/.config/cosmic/`. As pastas
#   de tema existiam lá — `CosmicTheme.Dark/v1`, `.Dark/v2`, `.Light`, `.Mode` —
#   e estavam TODAS VAZIAS (medido em 2026-08-05). Pasta vazia não é meio-termo:
#   o COSMIC cai no tema embutido, e a tela de login abria em azul de fábrica,
#   a única superfície da máquina que ainda não era Catppuccin.
#
# A TELA DE BLOQUEIO JÁ ERA DELA, E POR OUTRO CAMINHO
#   O mesmo binário faz as duas coisas, mas com sessões diferentes. Bloqueio roda
#   DENTRO da sessão dela, lê `~/.config/cosmic` e por isso sempre esteve certo —
#   é o mesmo processo que aparecia no journal reclamando do wallpaper dela:
#       cosmic-greeter[3112]: failed to read wallpaper "/home/vitoriamaria/..."
#   Login roda ANTES de existir sessão, e é só ele que precisa desta cópia.
#
# NÃO MEXEMOS NO TEMA DE ÍCONES DELE, E ISSO É DELIBERADO
#   A tentação é escrever `CosmicTk/v1/icon_theme` com "MeowSystem-Icons" para
#   fechar o conjunto. Não funciona, e falha do pior jeito: nosso tema mora em
#   `~/.local/share/icons`, dentro de uma home com modo `drwx------`. O uid 987
#   não consegue nem listar o diretório. O resultado seria um greeter apontando
#   para um tema que ele não pode ler — ícone faltando em vez de ícone errado.
#   Se um dia isso for desejado, o caminho é instalar o tema em
#   `/usr/share/icons`, que é território da Aurora e do apt (lib/comum.sh, trava 1).
#
# SÓ PREENCHEMOS PASTA QUE ELE JÁ TEM
#   As `.Builder` ficam de fora: são insumo da GUI de temas, que o greeter não
#   tem. Criar árvore nova na configuração de um serviço do sistema é o tipo de
#   coisa que funciona hoje e confunde o diagnóstico daqui a um ano.
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

GREETER_HOME="${GREETER_HOME:-/var/lib/cosmic-greeter}"
DESTINO="$GREETER_HOME/.config/cosmic"
DONO="cosmic-greeter"

# As três árvores que o greeter de fato lê. Ordem sem importância: nenhuma
# depende da outra.
ARVORES=(
  com.system76.CosmicTheme.Dark
  com.system76.CosmicTheme.Light
  com.system76.CosmicTheme.Mode
)

alvo_tema() {
  # Mesmo nome de captura que o resto do projeto usa: <flavor>-<accent>.
  local flavor="${FLAVOR:-mocha}" accent="${ACCENT:-mauve}"
  printf '%s-%s' "$flavor" "$accent"
}

ALVO="$(alvo_tema)"
CAPTURA="$RAIZ/state/tema/$ALVO"

[ -d "$CAPTURA" ] || {
  meow_aviso "não há captura para '$ALVO' — a tela de login fica como está"
  meow_info "capture antes: meow tema capturar $ALVO"
  exit "$MEOW_SEM_DEPENDENCIA"
}

# TUDO que olha para dentro do home do greeter passa por sudo, INCLUSIVE o teste
# de existência. `/var/lib/cosmic-greeter` é `drwxr-x---` do uid 987: um `[ -d ]`
# comum devolve falso por PERMISSÃO, não por ausência, e a primeira versão deste
# script anunciou "não há cosmic-greeter nesta máquina" numa máquina que tem.
# Um diagnóstico errado com cara de diagnóstico certo é o pior resultado possível.
if ! sudo -n test -d "$DESTINO" 2>/dev/null; then
  if sudo -n true 2>/dev/null; then
    meow_pula "não há cosmic-greeter nesta máquina ($DESTINO)"
    exit "$MEOW_OK"
  fi
  meow_aviso "não consigo olhar $DESTINO sem sudo — tela de login não conferida"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

id "$DONO" >/dev/null 2>&1 || {
  meow_aviso "o usuário '$DONO' não existe — a tela de login fica como está"
  exit "$MEOW_SEM_DEPENDENCIA"
}

# --- o que mudaria ----------------------------------------------------------
# Compara por CONTEÚDO (regra 5). `sudo cat` por arquivo é caro, então a leitura
# do lado do greeter passa por um `find` só, e a comparação é feita por md5 dos
# dois lados. Numa árvore de ~190 arquivos isso é a diferença entre uma dúzia de
# chamadas de sudo e duzentas.
pendentes=()
for arvore in "${ARVORES[@]}"; do
  [ -d "$CAPTURA/$arvore" ] || continue
  # `-mindepth 1` para o caminho relativo nunca ser "."
  while IFS= read -r rel; do
    fonte="$CAPTURA/$arvore/$rel"
    dest="$DESTINO/$arvore/$rel"
    if ! sudo -n test -f "$dest" 2>/dev/null; then
      pendentes+=("$arvore/$rel"); continue
    fi
    if ! sudo -n cmp -s "$fonte" "$dest" 2>/dev/null; then
      pendentes+=("$arvore/$rel")
    fi
  done < <(cd "$CAPTURA/$arvore" && find . -mindepth 1 -type f -printf '%P\n' | sort)
done

if [ "${#pendentes[@]}" -eq 0 ]; then
  meow_ok "a tela de login já está no tema '$ALVO'"
  exit "$MEOW_OK"
fi

if meow_seco; then
  meow_muda "vestiria a tela de login com '$ALVO' (${#pendentes[@]} arquivo(s))"
  exit "$MEOW_DIVERGENTE"
fi

if ! sudo -n true 2>/dev/null; then
  meow_aviso "a tela de login precisa de sudo (${#pendentes[@]} arquivo(s) pendentes)"
  meow_info "rode o install.sh de novo com sudo disponível"
  exit "$MEOW_SEM_DEPENDENCIA"
fi

# --- escrever ---------------------------------------------------------------
# `install -D` cria o diretório-pai, escreve e ajusta dono e modo numa chamada só;
# sem ele seriam três, e um `chown` esquecido deixa o greeter sem poder LER a
# própria configuração — que falha silenciosa, de novo com o tema de fábrica.
erros=0
for rel in "${pendentes[@]}"; do
  if ! sudo install -D -o "$DONO" -g "$DONO" -m 644 \
        "$CAPTURA/$rel" "$DESTINO/$rel" 2>/dev/null; then
    meow_erro "não consegui escrever $DESTINO/$rel"
    erros=$((erros + 1))
  fi
done

[ "$erros" -eq 0 ] || exit "$MEOW_ERRO"

meow_ok "tela de login vestida com '$ALVO' (${#pendentes[@]} arquivo(s))"
meow_info "aparece no próximo logout — o greeter lê a configuração ao subir"
exit "$MEOW_DIVERGENTE"
