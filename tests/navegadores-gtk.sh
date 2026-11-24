#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
falhas=0
ok()    { printf 'ok: %s\n' "$1"; }
falha() { printf 'FALHOU: %s\n' "$1" >&2; [ -n "${2:-}" ] && printf '%s\n' "$2" >&2; falhas=$((falhas+1)); }

command -v python3 >/dev/null 2>&1 || { printf 'pulado: sem python3\n'; exit 0; }

T="$(mktemp -d)" || exit 2
trap 'rm -rf "$T"' EXIT
BIN="$T/bin"; CASA="$T/casa"; mkdir -p "$BIN" "$CASA/.config"
for x in sudo pkexec su apt apt-get systemctl pkill; do
  printf '#!/bin/sh\necho "recusado: %s" >&2\nexit 1\n' "$x" > "$BIN/$x"; chmod +x "$BIN/$x"
done
cat > "$BIN/pgrep" <<'FIM'
#!/bin/sh
[ "$1" = "-x" ] || exit 1
[ -f "$ABERTOS" ] && grep -qxF -- "$2" "$ABERTOS"
FIM
cat > "$BIN/flatpak" <<'FIM'
#!/bin/sh
[ "$1" = "ps" ] || exit 1
[ -f "$FLATPAK_ABERTOS" ] && cat "$FLATPAK_ABERTOS"
exit 0
FIM
chmod +x "$BIN/pgrep" "$BIN/flatpak"
ABERTOS="$T/abertos"; FLATPAK_ABERTOS="$T/flatpak-abertos"

CHROME="$CASA/.config/google-chrome"
CHROME2="$CHROME/Profile 1"
CHROME3="$CHROME/Profile 2"
CHROME4="$CHROME/Profile 3"
EDGE="$CASA/.var/app/com.microsoft.Edge/config/microsoft-edge/Default"
SNAP="$CASA/snap/chromium/common/chromium/Default"
BRAVE="$CASA/.config/BraveSoftware/Brave-Browser/Default"
VAZIO="$CASA/.config/chromium/Default"
TEMA_LOJA=jnegjmlkajgpjloaanncielldhcedhcp
TODOS=("$CHROME/Default" "$CHROME2" "$CHROME3" "$CHROME4" "$EDGE" "$SNAP" "$BRAVE" "$VAZIO")

mod() {
  env -i PATH="$BIN:$PATH" HOME="$CASA" XDG_CONFIG_HOME="$CASA/.config" XDG_DATA_HOME="$CASA/.local/share" \
      ABERTOS="$ABERTOS" FLATPAK_ABERTOS="$FLATPAK_ABERTOS" \
      MEOW_RAIZ="$RAIZ" MEOW_ESTADO="$T/estado" TMPDIR="$T" ${SECO:+MEOW_DRY_RUN=1} NO_COLOR=1 \
      bash -c '. "$MEOW_RAIZ/scripts/lib/comum.sh" || exit 2
               . "$MEOW_RAIZ/scripts/temas-de-apps/chromium/manifesto.sh" || exit 2
               meow_app_$1' x "$1" </dev/null 2>&1
}

json() { python3 -c 'import json,sys; json.dump(json.loads(sys.argv[1]), open(sys.argv[2], "w", encoding="utf-8"), separators=(",", ":"))' "$1" "$2"; }
tema() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])).get("extensions", {}).get("theme"), sort_keys=True))' "$1"; }
resto() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); d.get("extensions", {}).pop("theme", None); print(json.dumps(d, sort_keys=True))' "$1"; }
inteiro() { python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1])), sort_keys=True))' "$1"; }
fotografia() { local a; for a in "${TODOS[@]}"; do printf '%s %s\n' "$(stat -c '%Y %s' "$a/Preferences" 2>/dev/null)" "$(cat "$a/Preferences" 2>/dev/null)"; done | sha256sum; }

semear() {
  rm -rf "$CASA" "$T/estado"; mkdir -p "$CASA/.config" "$CASA/.local/share/flatpak/app/com.microsoft.Edge/x86_64/stable/0123abcd"
  ln -sfn 0123abcd "$CASA/.local/share/flatpak/app/com.microsoft.Edge/x86_64/stable/active"
  : > "$ABERTOS"; : > "$FLATPAK_ABERTOS"
  local a
  for a in "${TODOS[@]}"; do mkdir -p "$a"; done
  json '{"extensions":{"theme":{"id":"user_color_theme_id","system_theme":0},"ui":{"x":1}},"browser":{"theme":{"color_scheme2":2,"user_color2":-1714692,"saved_local_theme":"CAAQAUgB"}},"profile":{"name":"Pessoa 1"}}' "$CHROME/Default/Preferences"
  json '{"extensions":{"theme":{"id":"user_color_theme_id","system_theme":0}},"profile":{"name":"Pessoa 2"},"account_info":[{"email":"a@b"}],"sync":{"has_setup_completed":true,"keep_everything_synced":true}}' "$CHROME2/Preferences"
  json '{"extensions":{"theme":{"id":"user_color_theme_id","system_theme":0}},"account_info":[{"email":"c@d"}],"sync":{"gaia_id":"123","selected_types_per_account":{"x":{"sync.tabs":true}}},"browser":{"theme":{"saved_local_theme":"CAAQAEgB","user_color2":5}}}' "$CHROME3/Preferences"
  json '{"extensions":{"theme":{"id":"user_color_theme_id","system_theme":0}},"account_info":[{"email":"e@f"}],"sync":{"has_setup_completed":true,"keep_everything_synced":false,"bookmarks":true,"passwords":false}}' "$CHROME4/Preferences"
  json '{"extensions":{"theme":{"id":"jnegjmlkajgpjloaanncielldhcedhcp","pack":"/x/Extensions/jnegj/1.0.2_0","system_theme":0},"settings":{"jnegjmlkajgpjloaanncielldhcedhcp":{"disable_reasons":[],"path":"jnegjmlkajgpjloaanncielldhcedhcp/1.0.2_0","manifest":{"name":"Roxo","theme":{"colors":{}}}},"fclbdkbhjlgkbpfldjodgjncejkkjcme":{"disable_reasons":[],"manifest":{"name":"Bloqueador"}}}},"browser":{"theme":{"follows_system_colors":false}},"account_info":[{"email":"g@h"}],"sync":{"has_setup_completed":true,"keep_everything_synced":true,"collections":true}}' "$EDGE/Preferences"
  mkdir -p "$EDGE/Extensions/$TEMA_LOJA/1.0.2_0"; printf '{"theme":{}}' > "$EDGE/Extensions/$TEMA_LOJA/1.0.2_0/manifest.json"
  json '{"extensions":{"theme":{"system_theme":0}},"homepage":"about:blank"}' "$SNAP/Preferences"
  json '{"extensions":{"theme":{"id":"","system_theme":1}},"brave":{"x":2}}' "$BRAVE/Preferences"
  json '{"profile":{"name":"sem tema"}}' "$VAZIO/Preferences"
  chmod 600 "$CHROME/Default/Preferences"
}

gtk() { [ "$(tema "$1/Preferences")" = '{"system_theme": 1}' ] || [ "$(tema "$1/Preferences")" = '{"id": "", "system_theme": 1}' ]; }

semear
saida="$(mod conferir)"; rc=$?
[ "$rc" = 1 ] && ok "antes de aplicar, o conferir acusa o modo Clássico" \
  || falha "o conferir antes de aplicar devia dar 1 e deu $rc" "$saida"

antes="$(fotografia)"
saida="$(SECO=1 mod aplicar)"; rc=$?
[ "$antes" = "$(fotografia)" ] && [ ! -e "$T/estado" ] && ok "o ensaio seco não escreve nada, nem o guardado" \
  || falha "o ensaio seco mexeu nos perfis ou no estado" "$saida"

printf 'chrome\n' > "$ABERTOS"
antes_chrome="$(inteiro "$CHROME/Default/Preferences")"; antes_chrome2="$(inteiro "$CHROME2/Preferences")"; antes_snap="$(inteiro "$SNAP/Preferences")"
saida="$(mod aplicar)"; rc=$?
if [ "$rc" = 1 ] && [ "$antes_chrome" = "$(inteiro "$CHROME/Default/Preferences")" ] \
   && [ "$antes_chrome2" = "$(inteiro "$CHROME2/Preferences")" ] && [ "$antes_snap" = "$(inteiro "$SNAP/Preferences")" ] \
   && gtk "$EDGE" && gtk "$VAZIO"; then
  ok "com o Chrome aberto, os perfis dele e o snap ficam pendentes sem escrita; o resto entra"
else
  falha "o navegador aberto foi tocado, ou o resto não entrou (rc=$rc)" "$saida"
fi
printf '%s\n' "$saida" | grep -q 'está aberto' && ok "o aviso de pendência diz que o navegador está aberto" \
  || falha "faltou o aviso de navegador aberto" "$saida"

: > "$ABERTOS"
saida="$(mod aplicar)"; rc=$?
tudo=1; for a in "${TODOS[@]}"; do gtk "$a" || tudo=0; done
if [ "$rc" = 1 ] && [ "$tudo" = 1 ]; then
  ok "deb, flatpak, snap e perfil extra: todos ficam com system_theme 1 e sem tema próprio"
else
  falha "o aplicar não pôs todos no modo GTK (rc=$rc)" "$saida"
fi
if [ "$(tema "$EDGE/Preferences")" = '{"system_theme": 1}' ] && [ "$(tema "$CHROME/Default/Preferences")" = '{"system_theme": 1}' ]; then
  ok "o id e o pack do tema próprio saem"
else
  falha "sobrou id ou pack do tema próprio" "$(tema "$EDGE/Preferences") $(tema "$CHROME/Default/Preferences")"
fi
if python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert d["extensions"]["ui"]=={"x":1} and d["browser"]["theme"]["user_color2"]==-1714692 and d["profile"]["name"]=="Pessoa 1"' "$CHROME/Default/Preferences" \
   && [ "$(stat -c %a "$CHROME/Default/Preferences")" = 600 ]; then
  ok "o resto do Preferences e a permissão ficam como estavam"
else
  falha "o aplicar mexeu no que não era dele"
fi

if python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))["sync"]
outros=("apps","autofill","bookmarks","cookies","extensions","passwords","payments","preferences","product_comparison","reading_list","saved_tab_groups","tabs","typed_urls")
assert d["keep_everything_synced"] is False and d["themes"] is False and all(d[k] is True for k in outros)
for p in sys.argv[2:]:
    assert "sync" not in json.load(open(p))' "$CHROME2/Preferences" "$CHROME/Default/Preferences" "$SNAP/Preferences"; then
  ok "perfil que sincroniza tudo: só o tema sai da sincronia (senão a nuvem devolve o Clássico ao abrir), os outros tipos seguem ligados; perfil sem conta não ganha chave de sincronia"
else
  falha "o perfil que sincroniza tudo não ficou com tudo menos o tema, ou o perfil sem conta ganhou chave de sincronia" "$(inteiro "$CHROME2/Preferences")"
fi
if python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))["sync"]
assert d=={"has_setup_completed":True,"keep_everything_synced":False,"bookmarks":True,"passwords":False,"themes":False}, d' "$CHROME4/Preferences"; then
  ok "perfil que já escolhe o que sincroniza: só o tema sai, as escolhas dele ficam"
else
  falha "o aplicar mexeu nas escolhas de sincronia de quem já escolhia" "$(inteiro "$CHROME4/Preferences")"
fi
if python3 -c '
import json,sys,hashlib,base64
d=json.load(open(sys.argv[1]))
h=base64.b64encode(hashlib.sha256(b"123").digest()).decode()
assert d["sync"]["selected_types_per_account"]=={"x":{"sync.tabs":True},h:{"sync.themes":False}}, d["sync"]
assert "keep_everything_synced" not in d["sync"] and d["browser"]["theme"]=={"user_color2":5}' "$CHROME3/Preferences"; then
  ok "perfil só conectado à conta: o tema sai da escolha da conta e o tema local guardado (o Clássico) sai junto"
else
  falha "o perfil só conectado à conta não tirou o tema da conta, ou sobrou o tema local guardado" "$(inteiro "$CHROME3/Preferences")"
fi
python3 -c '
import json,sys
assert json.load(open(sys.argv[1]))["sync"]=={"has_setup_completed":True,"keep_everything_synced":True,"collections":True}' "$EDGE/Preferences" \
  && ok "o Edge, de sincronia com outros tipos, não tem a sincronia tocada" \
  || falha "o aplicar mexeu na sincronia do Edge" "$(inteiro "$EDGE/Preferences")"

python3 -c '
import json,sys
s=json.load(open(sys.argv[1]))["extensions"]["settings"]
assert s[sys.argv[2]]["disable_reasons"]==[1] and s["fclbdkbhjlgkbpfldjodgjncejkkjcme"]["disable_reasons"]==[]' "$EDGE/Preferences" "$TEMA_LOJA" \
  && [ -f "$T/estado/temas-de-apps/chromium/"*"/$TEMA_LOJA/1.0.2_0/manifest.json" ] \
  && ok "o tema da loja fica desligado como no Usar GTK do navegador (senão ele volta ao abrir), guardado para o reverter; as outras extensões ficam" \
  || falha "o tema da loja seguiu ligado, não foi guardado, ou outra extensão foi tocada" "$(inteiro "$EDGE/Preferences")"

antes="$(fotografia)"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(fotografia)" ] && ok "a segunda passada fica quieta e não escreve" \
  || falha "a segunda passada não ficou quieta (rc=$rc)" "$saida"
saida="$(mod conferir)"; rc=$?
[ "$rc" = 0 ] && ok "depois de aplicar, o conferir fecha" || falha "o conferir depois de aplicar devia dar 0 e deu $rc" "$saida"

json '{"extensions":{"theme":{"id":"","system_theme":1}},"profile":{"name":"Pessoa 1"}}' "$CHROME/Default/Preferences"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 0 ] && ok "o navegador gravar id vazio ao sair não vira divergência" \
  || falha "o id vazio que o próprio navegador grava reabriu a divergência (rc=$rc)" "$saida"

semear
mod aplicar >/dev/null
printf 'com.microsoft.Edge\n' > "$FLATPAK_ABERTOS"
saida="$(mod reverter)"; rc=$?
if [ "$rc" = 1 ] && [ "$(tema "$EDGE/Preferences")" = '{"system_theme": 1}' ] && [ "$(tema "$CHROME/Default/Preferences")" = '{"id": "user_color_theme_id", "system_theme": 0}' ]; then
  ok "reverter com o Edge aberto devolve os outros e deixa o Edge como está"
else
  falha "o reverter com o Edge aberto não separou o aberto dos fechados (rc=$rc)" "$saida"
fi
semear
mod aplicar >/dev/null
python3 -c '
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["extensions"]["settings"].pop(sys.argv[2])
json.dump(d,open(p,"w"))' "$EDGE/Preferences" "$TEMA_LOJA"
rm -rf "$EDGE/Extensions/$TEMA_LOJA"
saida="$(mod conferir)"; rc=$?
[ "$rc" = 0 ] && ok "o navegador desinstalar o tema desligado não vira divergência" \
  || falha "o tema desinstalado pelo navegador reabriu a divergência (rc=$rc)" "$saida"
mod reverter >/dev/null
python3 -c '
import json,sys
s=json.load(open(sys.argv[1]))["extensions"]["settings"][sys.argv[2]]
assert s["disable_reasons"]==[] and s["manifest"]["name"]=="Roxo"' "$EDGE/Preferences" "$TEMA_LOJA" \
  && [ -f "$EDGE/Extensions/$TEMA_LOJA/1.0.2_0/manifest.json" ] && [ ! -e "$T/estado/temas-de-apps/chromium" ] \
  && ok "o reverter devolve o tema da loja que o navegador desinstalou, ligado, e apaga a cópia" \
  || falha "o reverter não devolveu o tema da loja desinstalado" "$(inteiro "$EDGE/Preferences")"

semear
python3 -c '
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["extensions"]["theme"]={"id":"","system_theme":1}
json.dump(d,open(p,"w"))' "$EDGE/Preferences"
for a in "${TODOS[@]}"; do [ "$a" = "$EDGE" ] || rm -rf "$a"; done
saida="$(mod conferir)"; rc=$?
[ "$rc" = 1 ] && ok "tema da loja ligado com system_theme 1: o conferir acusa, porque o navegador o veste ao abrir" \
  || falha "o conferir não viu o tema da loja ligado (rc=$rc)" "$saida"

semear
orig=(); for a in "${TODOS[@]}"; do orig+=("$(inteiro "$a/Preferences")"); done
mod aplicar >/dev/null
saida="$(mod reverter)"; rc=$?
volta=1; i=0; for a in "${TODOS[@]}"; do [ "${orig[$i]}" = "$(inteiro "$a/Preferences")" ] || { volta=0; falha "o reverter não devolveu $a" "${orig[$i]} / $(inteiro "$a/Preferences")"; }; i=$((i+1)); done
[ "$rc" = 1 ] && [ "$volta" = 1 ] && ok "o reverter devolve cada perfil ao JSON de antes, inclusive o que não tinha tema" \
  || falha "o reverter não fechou (rc=$rc)" "$saida"
[ ! -e "$T/estado/chromium-antes.json" ] && ok "o guardado some quando o último perfil volta" || falha "o guardado ficou depois do último reverter"
saida="$(mod reverter)"; rc=$?
[ "$rc" = 0 ] && ok "o segundo reverter fica quieto" || falha "o segundo reverter devia dar 0 e deu $rc" "$saida"

semear
antes_chrome2="$(inteiro "$CHROME2/Preferences")"
mod aplicar >/dev/null
python3 -c '
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["extensions"]["theme"]={"id":"abcdefghijklmnopabcdefghijklmnop","system_theme":0}
json.dump(d,open(p,"w"))' "$CHROME2/Preferences"
mod aplicar >/dev/null
mod reverter >/dev/null
if python3 -c '
import json,sys
a=json.loads(sys.argv[2]); d=json.load(open(sys.argv[1]))
assert d["sync"]==a["sync"], d["sync"]' "$CHROME2/Preferences" "$antes_chrome2"; then
  ok "a sincronia volta à de antes, mesmo com um tema trocado no meio e um segundo aplicar"
else
  falha "o reverter perdeu a sincronia de antes" "$(inteiro "$CHROME2/Preferences")"
fi
semear
mod aplicar >/dev/null
python3 -c '
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d["extensions"]["theme"]={"id":"abcdefghijklmnopabcdefghijklmnop","system_theme":0}
json.dump(d,open(p,"w"))' "$CHROME2/Preferences"
mod reverter >/dev/null
python3 -c '
import json,sys
d=json.load(open(sys.argv[1]))
assert d["sync"]=={"has_setup_completed":True,"keep_everything_synced":True} and d["extensions"]["theme"]["id"]=="abcdefghijklmnopabcdefghijklmnop"' "$CHROME2/Preferences" \
  && ok "o reverter devolve a sincronia mesmo quando o tema já foi trocado à mão, e não pisa no tema novo" \
  || falha "o reverter deixou a sincronia desligada ou pisou no tema escolhido à mão" "$(inteiro "$CHROME2/Preferences")"

semear
printf '{ isto não é json' > "$CHROME/Default/Preferences"
for a in "$CHROME2" "$CHROME3" "$CHROME4" "$EDGE" "$SNAP" "$BRAVE" "$VAZIO"; do rm -f "$a/Preferences"; done
antes="$(fotografia)"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 3 ] && [ "$antes" = "$(fotografia)" ] && ok "Preferences ilegível: deixa como está e avisa (3)" \
  || falha "Preferences ilegível devia dar 3 sem escrita (rc=$rc)" "$saida"

semear
printf 'com.microsoft.Edge\n' > "$FLATPAK_ABERTOS"
antes_edge="$(inteiro "$EDGE/Preferences")"
mod aplicar >/dev/null
[ "$antes_edge" = "$(inteiro "$EDGE/Preferences")" ] && gtk "$CHROME/Default" && ok "o Edge flatpak aberto fica pendente pelo flatpak ps" \
  || falha "o Edge flatpak aberto foi tocado, ou o deb não entrou"

semear
for a in "${TODOS[@]}"; do [ "$a" = "$BRAVE" ] || rm -rf "$a"; done
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 0 ] && ok "só perfil já no modo GTK: nada a fazer (0)" || falha "perfil já no GTK devia dar 0 e deu $rc" "$saida"
rm -rf "$CASA/.config"
saida="$(mod aplicar)"; rc=$?
[ "$rc" = 3 ] && ok "sem perfil nenhum: pendente (3), sem erro" || falha "sem perfil devia dar 3 e deu $rc" "$saida"

echo
if [ "$falhas" = 0 ]; then echo "navegadores-gtk: tudo certo"; exit 0; fi
echo "navegadores-gtk: $falhas falha(s)"; exit 1
