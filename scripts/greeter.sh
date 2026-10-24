#!/usr/bin/env bash
# greeter.sh — a TELA DE LOGIN também é dela.
#
# A tentação é escrever `CosmicTk/v1/icon_theme` com "MeowSystem-Icons" para
# fechar o conjunto. Não funciona, e falha do pior jeito: nosso tema mora em
# `~/.local/share/icons`, dentro de uma home com modo `drwx------`.
#
# As `.Builder` ficam de fora: são insumo da GUI de temas, que o greeter não
# tem.
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
  # Vazio, vale o flavor padrão do pack no ar: o `meow_flavor` (lib/comum.sh).
  # Era `${FLAVOR:-mocha}`, o padrão de um pack só.
  local flavor accent="${ACCENT:-mauve}"
  flavor="$(meow_flavor)"
  printf '%s-%s' "$flavor" "$accent"
}

ALVO="$(alvo_tema)"
# A captura mora dentro do pack dono, e este script roda pelo hook e pelo timer
# — sem a ponte do `meow_ponte_python`. O `meow_captura` refaz a ponte sozinho;
# ver o cabeçalho dele em lib/comum.sh.
CAPTURA="$(meow_captura "$ALVO")"

# Se o avatar atual não for reconhecidamente nosso, este script NÃO TOCA.
avatar_nosso() {
  local md5="$1" f
  # Só o acervo: os `assets/meow-*.svg` foram excluídos e os globs não casariam
  # nada. O md5 guardado, logo abaixo, é o que ainda reconhece um avatar posto
  # por uma versão anterior deste script.
  for f in "$RAIZ"/packs/*/mascote/*.svg; do
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

  # Poderia ser o mascote que está no ar, mas aí o avatar da tela de login trocaria
  # junto com a rotação diária, e cada troca é uma escrita no AccountsService
  # via D-Bus.
  desejado="$(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' \
                ! -name '*-symbolic.svg' 2>/dev/null | sort | head -n1)"
  [ -n "$desejado" ] && [ -f "$desejado" ] \
    || { meow_pula "não há mascote em $(meow_mascote_dir) para o avatar"; return 0; }
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
    meow_ok "avatar da tela de login já é o mascote $(basename "${desejado%.svg}")"
    return 0
  fi

  if [ -n "$md5_atual" ] && ! avatar_nosso "$md5_atual"; then
    meow_pula "há um avatar que não é nosso na tela de login — respeitado"
    return 0
  fi

  if meow_seco; then
    meow_muda "poria o mascote $(basename "${desejado%.svg}") como avatar da tela de login"
    return 1
  fi

  # O daemon roda como root e COPIA o arquivo para /var/lib/AccountsService/
  # assets/icones/.
  local tmp; tmp="$(mktemp --suffix=.svg)" || return 2
  cat "$desejado" > "$tmp"; chmod 644 "$tmp"
  if busctl call org.freedesktop.Accounts "$objeto" org.freedesktop.Accounts.User \
       SetIconFile s "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
    # `>` trunca antes de escrever, e quem lê no meio (linha 98, a comparação
    # que evita a chamada ao Accounts) veria md5 vazio e refaria o trabalho.
    meow_escrever "$MEOW_ESTADO/greeter-avatar.md5" "$md5_novo" 644 >/dev/null || true
    meow_ok "avatar da tela de login: mascote $(basename "${desejado%.svg}")"
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
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
}

# TUDO que olha para dentro do home do greeter passa por sudo, INCLUSIVE o teste
# de existência.
declare -A GREETER_MD5=()
GREETER_VISTO=0
if meow_ponte_viva; then
  _saida="$(meow_ponte greeter-ver 2>/dev/null)"; _rc=$?
  if [ "$_rc" = 0 ]; then
    GREETER_VISTO=1
    while read -r _md5 _rel; do
      [ -n "${_rel:-}" ] && GREETER_MD5["$_rel"]="$_md5"
    done <<<"$_saida"
  elif [ "$_rc" = 3 ]; then
    # A ponte respondeu que a pasta não existe: nenhum sudo fora dela para confirmar.
    meow_pula "não há cosmic-greeter nesta máquina ($DESTINO)"
    exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_OK")"
  fi
fi

if [ "$GREETER_VISTO" = "0" ] && ! sudo -n test -d "$DESTINO" 2>/dev/null; then
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
  # A ÁRVORE TEM DE MORAR NA CAPTURA — P78, 09/10/2026. A captura pode ser de
  #   um pack de terceiro, e o `cd` abaixo segue symlink: uma árvore que fosse
  #   link para fora mandaria para o greeter (pela ponte, como root) o que
  #   estivesse no destino. O `find` já não segue link de arquivo (`-type f`).
  meow_dentro "$CAPTURA" "$arvore" >/dev/null || {
    meow_aviso "greeter: $arvore da captura é link para fora dela — pulada"; continue; }
  # `-mindepth 1` para o caminho relativo nunca ser "."
  while IFS= read -r rel; do
    fonte="$CAPTURA/$arvore/$rel"
    dest="$DESTINO/$arvore/$rel"
    if [ "$GREETER_VISTO" = "1" ]; then
      # A árvore já foi lida inteira; aqui é só comparar dois md5.
      if [ "${GREETER_MD5["$arvore/$rel"]:-}" != "$(md5sum < "$fonte" | cut -d' ' -f1)" ]; then
        pendentes+=("$arvore/$rel")
      fi
      continue
    fi
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

# PELA PONTE: um tar com só os pendentes, e ela extrai com o dono certo. Assim
# a tela de login passa a ser consertável pelo painel e pelo auto-reparo, que é
# o que ela pediu em 08/09/2026 — antes, sem terminal, esta etapa só avisava.
#
# E A RECUSA DIZ O MOTIVO — P75, 09/10/2026 (S4, P70 item 1). A saída de erro
# da ponte ia para o `/dev/null`, e a única frase na tela era "a ponte recusou":
# a ponte recusava TODA chamada (uma opção de tar que não existe, ver o bloco do
# `greeter-aplicar` em scripts/ponte_root.sh) e ninguém tinha como ver. Agora o
# que a ponte e o sudo disseram vem junto, na mesma linha.
if meow_ponte_viva; then
  if motivo="$( { tar -c -C "$CAPTURA" -f - "${pendentes[@]}" | meow_ponte greeter-aplicar >/dev/null; } 2>&1 )"; then
    meow_muda "tela de login vestida com '$ALVO' (${#pendentes[@]} arquivo(s), pela ponte)"
    meow_registrar "greeter.sh $ALVO ${#pendentes[@]} arquivo(s)"
    exit "$MEOW_DIVERGENTE"
  fi
  motivo="$(printf '%s' "$motivo" | sed 's/^ponte_root: //' | paste -sd';' - | sed 's/;/; /g')"
  meow_aviso "a ponte recusou vestir a tela de login (${motivo:-ela não disse por quê}) — tentando pelo caminho antigo"
fi

if ! sudo -n true 2>/dev/null; then
  meow_aviso "a tela de login precisa de sudo (${#pendentes[@]} arquivo(s) pendentes)"
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
