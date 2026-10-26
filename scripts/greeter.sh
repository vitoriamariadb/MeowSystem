#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/comum.sh
. "$RAIZ/lib/comum.sh"

GREETER_HOME="${GREETER_HOME:-/var/lib/cosmic-greeter}"
DESTINO="$GREETER_HOME/.config/cosmic"
DONO="cosmic-greeter"

ARVORES=(
  com.system76.CosmicTheme.Dark
  com.system76.CosmicTheme.Light
  com.system76.CosmicTheme.Mode
)

alvo_tema() {
  local flavor accent="${ACCENT:-mauve}"
  flavor="$(meow_flavor)"
  printf '%s-%s' "$flavor" "$accent"
}

ALVO="$(alvo_tema)"
CAPTURA="$(meow_captura "$ALVO")"

avatar_nosso() {
  local md5="$1" f
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

  desejado="$(find "$(meow_mascote_dir)/" -maxdepth 1 -name '*.svg' \
                ! -name '*-symbolic.svg' 2>/dev/null | sort | head -n1)"
  [ -n "$desejado" ] && [ -f "$desejado" ] \
    || { meow_pula "não há mascote em $(meow_mascote_dir) para o avatar"; return 0; }
  md5_novo="$(md5sum < "$desejado" | cut -d' ' -f1)"

  atual_arq="$(busctl get-property org.freedesktop.Accounts "$objeto" \
                 org.freedesktop.Accounts.User IconFile 2>/dev/null \
               | sed -n 's/^s "\(.*\)"$/\1/p')"

  md5_atual=""
  if [ -n "$atual_arq" ]; then
    md5_atual="$(md5sum < "$atual_arq" 2>/dev/null | cut -d' ' -f1)"
  fi
  if [ -n "$atual_arq" ] && [ -z "$md5_atual" ] \
     && { [ -e "$atual_arq" ] || [ ! -x "$(dirname "$atual_arq")" ]; }; then
    meow_aviso "não consigo ler o avatar atual da tela de login — avatar pendente"
    return 0
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

  local tmp; tmp="$(mktemp --suffix=.svg)" || return 2
  cat "$desejado" > "$tmp"; chmod 644 "$tmp"
  if busctl call org.freedesktop.Accounts "$objeto" org.freedesktop.Accounts.User \
       SetIconFile s "$tmp" >/dev/null 2>&1; then
    rm -f "$tmp"
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
    meow_pula "não há cosmic-greeter nesta máquina ($DESTINO)"
    exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_OK")"
  fi
fi

if [ "$GREETER_VISTO" = "0" ]; then
  meow_aviso "não consigo olhar $DESTINO sem a ponte — tela de login pendente"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
fi

id "$DONO" >/dev/null 2>&1 || {
  meow_aviso "o usuário '$DONO' não existe — a tela de login fica como está"
  exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
}

pendentes=()
for arvore in "${ARVORES[@]}"; do
  [ -d "$CAPTURA/$arvore" ] || continue
  meow_dentro "$CAPTURA" "$arvore" >/dev/null || {
    meow_aviso "greeter: $arvore da captura é link para fora dela — pulada"; continue; }
  while IFS= read -r rel; do
    fonte="$CAPTURA/$arvore/$rel"
    if [ "${GREETER_MD5["$arvore/$rel"]:-}" != "$(md5sum < "$fonte" | cut -d' ' -f1)" ]; then
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

if meow_ponte_viva; then
  if motivo="$( { tar -c -C "$CAPTURA" -f - "${pendentes[@]}" | meow_ponte greeter-aplicar >/dev/null; } 2>&1 )"; then
    meow_muda "tela de login vestida com '$ALVO' (${#pendentes[@]} arquivo(s), pela ponte)"
    meow_registrar "greeter.sh $ALVO ${#pendentes[@]} arquivo(s)"
    exit "$MEOW_DIVERGENTE"
  fi
  motivo="$(printf '%s' "$motivo" | sed 's/^ponte_root: //' | paste -sd';' - | sed 's/;/; /g')"
  meow_aviso "a ponte recusou vestir a tela de login (${motivo:-ela não disse por quê})"
  exit "$MEOW_ERRO"
fi

meow_aviso "a tela de login espera a ponte (${#pendentes[@]} arquivo(s) pendentes)"
exit "$([ "$mudou_avatar" = 1 ] && echo "$MEOW_DIVERGENTE" || echo "$MEOW_SEM_DEPENDENCIA")"
