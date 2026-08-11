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

# ---------------------------------------------------------------------------
# FASE 1 — O AVATAR, QUE NÃO PRECISA DE sudo E POR ISSO VEM ANTES DE TUDO
#
# O gato JÁ ESTAVA na tela de login desta máquina — `/var/lib/AccountsService/
# icons/vitoriamaria` bate byte a byte com `assets/meow-mocha-preto.svg`. Mas
# nenhum script deste repositório sabia disso: foi posto na mão em 04/08/2026, e
# numa máquina recém-instalada simplesmente não existiria. Era um enfeite sem
# dono, do tipo que some no primeiro reset e ninguém sabe repor.
#
# POR QUE ANTES DO PORTÃO DE sudo
#   Trocar o próprio avatar NÃO precisa de root: o polkit
#   `org.freedesktop.accounts.change-own-user-data` tem `implicit any: yes`
#   (medido). O portão que existe mais abaixo — o `sudo -n test -d` — é
#   necessário para o TEMA, que mora num diretório `drwxr-x---` do uid 987. Se o
#   avatar ficasse depois dele, uma rodada sem sudo em cache abortaria o módulo
#   inteiro e o avatar nunca chegaria. O `doctor.log` mostra isso acontecendo
#   todo dia: "greeter: falta dependência", na rodada automática das 5h.
#
# O GREETER RENDERIZA SVG — CONFERIDO, NÃO SUPOSTO
#   Havia a suspeita de que ele só lesse raster (a crate `image` não traz codec
#   de SVG). Mas `strings /usr/bin/cosmic-greeter` acha `resvg` 18 vezes e
#   `usvg` 35: o suporte entra por outra crate. O SVG serve, e é o que já está
#   em produção aqui desde 04/08.
#
# A GUARDA QUE IMPEDE O PIOR PING-PONG DE TODOS
#   Se o avatar atual não for reconhecidamente nosso, este script NÃO TOCA.
#   Sem isso, o dia em que ela puser uma foto própria pelo Ajustes → Sistema e
#   Contas, o timer diário a apagaria de madrugada — e brigar com a USUÁRIA é
#   pior do que brigar com a Aurora, porque ela não tem log para consultar.
avatar_nosso() {
  local md5="$1" f
  # Só o acervo: os `assets/meow-*.svg` foram excluídos em 08/08/2026 e os globs
  # não casariam nada. O md5 guardado, logo abaixo, é o que ainda reconhece um
  # avatar posto por uma versão anterior deste script.
  for f in "$RAIZ"/assets/gatos/*.svg; do
    [ -f "$f" ] || continue
    [ "$(md5sum < "$f" | cut -d' ' -f1)" = "$md5" ] && return 0
  done
  [ -f "$MEOW_ESTADO/greeter-avatar.md5" ] && \
    [ "$(cat "$MEOW_ESTADO/greeter-avatar.md5")" = "$md5" ] && return 0
  return 1
}

fase_avatar() {
  meow_tem busctl || { meow_pula "sem busctl — avatar da tela de login fica como está"; return 0; }

  local objeto desejado atual_arq md5_atual md5_novo
  objeto="$(busctl call org.freedesktop.Accounts /org/freedesktop/Accounts \
              org.freedesktop.Accounts FindUserByName s "$USER" 2>/dev/null \
            | sed -n 's/^o "\(.*\)"$/\1/p')"
  [ -n "$objeto" ] || { meow_pula "AccountsService não respondeu — avatar como está"; return 0; }

  # O AVATAR SAI DO ACERVO DELA, E É O PRIMEIRO EM ORDEM ALFABÉTICA — NÃO O DA
  # ROTAÇÃO. Até 08/08/2026 era `assets/meow-<flavor>-preto.svg`, do gerador que
  # ela mandou excluir. Poderia ser o gato que está no ar, mas aí o avatar da
  # tela de login trocaria junto com a rotação diária, e cada troca é uma escrita
  # no AccountsService via D-Bus. Estável é melhor: um gato só, sempre o mesmo,
  # e quem quiser trocar renomeia o arquivo ou põe a própria foto — que o
  # `avatar_nosso` respeita.
  desejado="$(find "$RAIZ/assets/gatos" -maxdepth 1 -name '*.svg' \
                ! -name '*-symbolic.svg' 2>/dev/null | sort | head -n1)"
  [ -n "$desejado" ] && [ -f "$desejado" ] \
    || { meow_pula "não há gato em assets/gatos/ para o avatar"; return 0; }
  md5_novo="$(md5sum < "$desejado" | cut -d' ' -f1)"

  atual_arq="$(busctl get-property org.freedesktop.Accounts "$objeto" \
                 org.freedesktop.Accounts.User IconFile 2>/dev/null \
               | sed -n 's/^s "\(.*\)"$/\1/p')"

  # Ler o arquivo apontado pode exigir root (é 0644 mas o diretório é do root);
  # `sudo -n` sem senha é opcional aqui — sem ele, cai no md5 guardado por nós.
  md5_atual=""
  if [ -n "$atual_arq" ]; then
    md5_atual="$(md5sum < "$atual_arq" 2>/dev/null | cut -d' ' -f1)"
    [ -z "$md5_atual" ] && md5_atual="$(sudo -n md5sum < "$atual_arq" 2>/dev/null | cut -d' ' -f1)"
  fi

  if [ "$md5_atual" = "$md5_novo" ]; then
    meow_ok "avatar da tela de login já é o gato $(basename "${desejado%.svg}")"
    return 0
  fi

  if [ -n "$md5_atual" ] && ! avatar_nosso "$md5_atual"; then
    meow_pula "há um avatar que não é nosso na tela de login — respeitado"
    return 0
  fi

  if meow_seco; then
    meow_muda "poria o gato $(basename "${desejado%.svg}") como avatar da tela de login"
    return 1
  fi

  # O daemon roda como root e COPIA o arquivo para /var/lib/AccountsService/
  # icons/. O caminho de origem precisa ser legível por ele — o repo pode estar
  # numa partição que só o usuário monta, então a origem é uma cópia em /tmp
  # com modo 644, e não o caminho do repo.
  local tmp; tmp="$(mktemp --suffix=.svg)" || return 2
  cat "$desejado" > "$tmp"; chmod 644 "$tmp"
  if busctl call org.freedesktop.Accounts "$objeto" org.freedesktop.Accounts.User \
       SetIconFile s "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    # `>` trunca antes de escrever, e quem lê no meio (linha 98, a comparação
    # que evita a chamada ao Accounts) veria md5 vazio e refaria o trabalho.
    # `meow_escrever` é temporário + `mv`, que o leitor não consegue pegar pela
    # metade.
    meow_escrever "$MEOW_ESTADO/greeter-avatar.md5" "$md5_novo" 644 >/dev/null || true
    meow_ok "avatar da tela de login: gato $(basename "${desejado%.svg}")"
    return 1
  fi
  rm -f "$tmp"
  meow_aviso "não consegui trocar o avatar (o polkit pode ter recusado)"
  return 0
}

mudou_avatar=0
fase_avatar; [ $? = 1 ] && mudou_avatar=1

[ -d "$CAPTURA" ] || {
  meow_aviso "não há captura para '$ALVO' — a tela de login fica como está"
  meow_info "capture antes: meow tema capturar $ALVO"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
}

# TUDO que olha para dentro do home do greeter passa por sudo, INCLUSIVE o teste
# de existência. `/var/lib/cosmic-greeter` é `drwxr-x---` do uid 987: um `[ -d ]`
# comum devolve falso por PERMISSÃO, não por ausência, e a primeira versão deste
# script anunciou "não há cosmic-greeter nesta máquina" numa máquina que tem.
# Um diagnóstico errado com cara de diagnóstico certo é o pior resultado possível.
if ! sudo -n test -d "$DESTINO" 2>/dev/null; then
  if sudo -n true 2>/dev/null; then
    meow_pula "não há cosmic-greeter nesta máquina ($DESTINO)"
    exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_OK")"
  fi
  meow_aviso "não consigo olhar $DESTINO sem sudo — tela de login não conferida"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
fi

id "$DONO" >/dev/null 2>&1 || {
  meow_aviso "o usuário '$DONO' não existe — a tela de login fica como está"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
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
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_OK")"
fi

if meow_seco; then
  meow_muda "vestiria a tela de login com '$ALVO' (${#pendentes[@]} arquivo(s))"
  exit "$MEOW_DIVERGENTE"
fi

if ! sudo -n true 2>/dev/null; then
  meow_aviso "a tela de login precisa de sudo (${#pendentes[@]} arquivo(s) pendentes)"
  meow_info "rode o install.sh de novo com sudo disponível"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
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
