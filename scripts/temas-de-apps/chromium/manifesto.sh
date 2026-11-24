#!/usr/bin/env bash

. "$MEOW_RAIZ/scripts/lib/tema_arquivo.sh"

_CR_ROTULO="chromium"

_CR_PY='
import base64, hashlib, json, os, shutil, sys, tempfile

modo, caminho, estado = sys.argv[1], sys.argv[2], sys.argv[3]


def ler(c):
    try:
        with open(c, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return None


def gravar(c, dados):
    pasta = os.path.dirname(c)
    os.makedirs(pasta, exist_ok=True)
    try:
        permissao = os.stat(c).st_mode & 0o777
    except FileNotFoundError:
        permissao = 0o600
    fd, tmp = tempfile.mkstemp(dir=pasta, prefix=".meow.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(json.dumps(dados, separators=(",", ":"), ensure_ascii=False))
        os.chmod(tmp, permissao)
        os.replace(tmp, c)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def tema_de(d):
    e = d.get("extensions")
    t = e.get("theme") if isinstance(e, dict) else None
    return t if isinstance(t, dict) else None


def pegar(d, chaves):
    for k in chaves:
        if not isinstance(d, dict) or k not in d:
            return None
        d = d[k]
    return d


def por(d, chaves, valor):
    if valor is None:
        pilha = []
        for k in chaves[:-1]:
            if not isinstance(d.get(k), dict):
                return
            pilha.append((d, k))
            d = d[k]
        d.pop(chaves[-1], None)
        for pai, k in reversed(pilha[1:]):
            if pai[k] == {}:
                pai.pop(k)
        return
    for k in chaves[:-1]:
        if not isinstance(d.get(k), dict):
            d[k] = {}
        d = d[k]
    d[chaves[-1]] = valor


OUTROS_TIPOS = ("apps", "autofill", "bookmarks", "cookies", "extensions", "passwords", "payments", "preferences",
               "product_comparison", "reading_list", "saved_tab_groups", "tabs", "typed_urls")
TEMA_LOCAL = ("browser", "theme", "saved_local_theme")


def tema_sai_da_conta(d):
    s = d.get("sync") if isinstance(d.get("sync"), dict) else {}
    if "/microsoft-edge" in caminho:
        return {}
    if s.get("has_setup_completed"):
        m = {("sync", "themes"): False}
        if s.get("keep_everything_synced") is not False:
            m[("sync", "keep_everything_synced")] = False
            m.update({("sync", k): True for k in OUTROS_TIPOS})
    elif isinstance(s.get("gaia_id"), str) and s["gaia_id"]:
        conta = base64.b64encode(hashlib.sha256(s["gaia_id"].encode()).digest()).decode()
        m = {("sync", "selected_types_per_account", conta, "sync.themes"): False}
    else:
        return {}
    m[TEMA_LOCAL] = None
    return m


def extensoes(d):
    s = pegar(d, ("extensions", "settings"))
    return s if isinstance(s, dict) else {}


def temas_ligados(d, tema_id=None):
    return [k for k, e in extensoes(d).items()
            if isinstance(e, dict) and not e.get("disable_reasons")
            and (k == tema_id or "theme" in (e.get("manifest") if isinstance(e.get("manifest"), dict) else {}))]


def desligar(e):
    r = e.get("disable_reasons")
    e["disable_reasons"] = r | 1 if isinstance(r, int) else (r if isinstance(r, list) else []) + [1]


def copias(c):
    return os.path.join(os.path.dirname(estado), "temas-de-apps", "chromium", hashlib.sha256(c.encode()).hexdigest()[:16])


def apagar_copias(c):
    shutil.rmtree(copias(c), ignore_errors=True)
    pasta = os.path.dirname(copias(c))
    for _ in range(2):
        try:
            os.rmdir(pasta)
        except OSError:
            return
        pasta = os.path.dirname(pasta)


def no_gtk(d):
    t = tema_de(d)
    if not (bool(t) and t.get("system_theme") == 1 and not t.get("id") and not t.get("pack")):
        return False
    if temas_ligados(d):
        return False
    return all(pegar(d, c) == v for c, v in tema_sai_da_conta(d).items())


try:
    prefs = ler(caminho)
    if not isinstance(prefs, dict):
        raise ValueError
except (ValueError, OSError):
    print("invalido")
    sys.exit(2)

guardado = ler(estado) if os.path.exists(estado) else {}
if not isinstance(guardado, dict):
    guardado = {}

if modo == "estado":
    print("gtk" if no_gtk(prefs) else "classico")
    sys.exit(0)

if modo == "guardado":
    sys.exit(0 if caminho in guardado else 1)

if modo == "aplicar":
    if no_gtk(prefs):
        sys.exit(0)
    atual = tema_de(prefs)
    anterior = guardado.get(caminho, {})
    conta = [c for c in anterior.get("conta", []) if isinstance(c, list) and len(c) == 3]
    ja = {tuple(c[0]) for c in conta}
    mudancas = {c: v for c, v in tema_sai_da_conta(prefs).items() if pegar(prefs, c) != v}
    conta += [[list(c), pegar(prefs, c), v] for c, v in mudancas.items() if c not in ja]
    temas = anterior.get("temas", {}) if isinstance(anterior.get("temas"), dict) else {}
    ligados = temas_ligados(prefs, (atual or {}).get("id"))
    for k in ligados:
        temas.setdefault(k, json.loads(json.dumps(extensoes(prefs)[k])))
        origem, copia = os.path.join(os.path.dirname(caminho), "Extensions", k), os.path.join(copias(caminho), k)
        if os.path.isdir(origem) and not os.path.exists(copia):
            shutil.copytree(origem, copia, symlinks=True)
    guardado[caminho] = {
        "theme": json.loads(json.dumps(atual)),
        "extensions": anterior.get("extensions", "extensions" in prefs),
        "conta": conta,
        "temas": temas,
    }
    gravar(estado, guardado)
    for k in ligados:
        desligar(extensoes(prefs)[k])
    for c, v in mudancas.items():
        por(prefs, c, v)
    novo = dict(atual or {})
    novo["system_theme"] = 1
    novo.pop("id", None)
    novo.pop("pack", None)
    prefs.setdefault("extensions", {})["theme"] = novo
    gravar(caminho, prefs)
    sys.exit(1)

if modo == "reverter":
    if caminho not in guardado:
        sys.exit(0)
    mudou = 0
    if no_gtk(prefs):
        antes = guardado[caminho].get("theme")
        if antes is None:
            prefs.get("extensions", {}).pop("theme", None)
            if not prefs.get("extensions") and not guardado[caminho].get("extensions"):
                prefs.pop("extensions", None)
        else:
            prefs.setdefault("extensions", {})["theme"] = antes
        for k, e in guardado[caminho].get("temas", {}).items():
            agora = extensoes(prefs).get(k)
            if agora is None:
                prefs.setdefault("extensions", {}).setdefault("settings", {})[k] = e
                origem, destino = os.path.join(copias(caminho), k), os.path.join(os.path.dirname(caminho), "Extensions", k)
                if os.path.isdir(origem) and not os.path.exists(destino):
                    shutil.copytree(origem, destino, symlinks=True)
            elif isinstance(agora, dict):
                if "disable_reasons" in e:
                    agora["disable_reasons"] = e["disable_reasons"]
                else:
                    agora.pop("disable_reasons", None)
        mudou = 1
    for c, velho, meu in guardado[caminho].get("conta", []):
        if pegar(prefs, c) == meu and velho != meu:
            por(prefs, c, velho)
            mudou = 1
    if mudou:
        gravar(caminho, prefs)
    apagar_copias(caminho)
    del guardado[caminho]
    if guardado:
        gravar(estado, guardado)
    else:
        os.unlink(estado)
    sys.exit(mudou)

sys.exit(2)
'

_cr_fontes() {
  local n
  for n in google-chrome google-chrome-beta google-chrome-unstable; do
    printf 'nativo\tchrome\t%s\n' "$HOME/.config/$n"
  done
  for n in microsoft-edge microsoft-edge-beta microsoft-edge-dev; do
    printf 'nativo\tmsedge\t%s\n' "$HOME/.config/$n"
  done
  printf 'nativo\tchromium\t%s\n' "$HOME/.config/chromium"
  for n in Brave-Browser Brave-Browser-Beta Brave-Browser-Nightly; do
    printf 'nativo\tbrave\t%s\n' "$HOME/.config/BraveSoftware/$n"
  done
  printf 'flatpak\tcom.google.Chrome\t%s\n' "$HOME/.var/app/com.google.Chrome/config/google-chrome"
  printf 'flatpak\tcom.microsoft.Edge\t%s\n' "$HOME/.var/app/com.microsoft.Edge/config/microsoft-edge"
  printf 'flatpak\torg.chromium.Chromium\t%s\n' "$HOME/.var/app/org.chromium.Chromium/config/chromium"
  printf 'flatpak\tcom.brave.Browser\t%s\n' "$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
  printf 'snap\tchromium,chrome\t%s\n' "$HOME/snap/chromium/common/chromium"
  printf 'snap\tchromium,chrome\t%s\n' "$HOME/snap/chromium/current/.config/chromium"
  printf 'snap\tbrave\t%s\n' "$HOME/snap/brave/common/.config/BraveSoftware/Brave-Browser"
  printf 'snap\tbrave\t%s\n' "$HOME/snap/brave/current/.config/BraveSoftware/Brave-Browser"
}

_cr_perfis() {
  local tipo id raiz perfil
  while IFS=$'\t' read -r tipo id raiz; do
    [ -d "$raiz" ] || continue
    for perfil in "$raiz"/Default "$raiz"/Profile\ *; do
      [ -f "$perfil/Preferences" ] && printf '%s\t%s\t%s\n' "$tipo" "$id" "$perfil/Preferences"
    done
  done < <(_cr_fontes)
}

_cr_aberto() {
  local tipo="$1" id="$2" nome
  if [ "$tipo" = flatpak ]; then
    meow_tem flatpak && flatpak ps --columns=application 2>/dev/null | grep -xF "$id" >/dev/null
    return
  fi
  local -a nomes=()
  IFS=',' read -ra nomes <<< "$id"
  for nome in "${nomes[@]}"; do
    pgrep -x "$nome" >/dev/null 2>&1 && return 0
  done
  return 1
}

_cr_py() {
  python3 -I -c "$_CR_PY" "$1" "$2" "${MEOW_ESTADO:-$HOME/.local/state/meowsystem}/chromium-antes.json"
}

_cr_comandos() {
  local c
  for c in google-chrome google-chrome-stable microsoft-edge microsoft-edge-stable chromium chromium-browser brave-browser; do
    meow_tem "$c" && return 0
  done
  return 1
}

meow_app_instalado() {
  local id
  _cr_comandos && return 0
  for id in com.google.Chrome com.microsoft.Edge org.chromium.Chromium com.brave.Browser; do
    meow_tem flatpak && meow_flatpak_tem "$id" && return 0
  done
  [ -n "$(_cr_perfis | head -n 1)" ]
}

meow_app_detectar() {
  MEOW_APP_MOTIVO=""
  meow_tem python3 || { meow_app_sem "$_CR_ROTULO: falta python3, que edita o Preferences do navegador"; return; }
  meow_app_instalado || { meow_app_sem "$_CR_ROTULO: nenhum navegador Chromium instalado"; return; }
  [ -n "$(_cr_perfis | head -n 1)" ] || { meow_app_sem "$_CR_ROTULO: ainda sem perfil; o modo GTK entra quando o navegador criar o dele"; return; }
  return "$MEOW_OK"
}

_cr_conferir_um() {
  local arquivo="$1" estado
  estado="$(_cr_py estado "$arquivo")" || { meow_pula "$_CR_ROTULO: $arquivo não é um JSON legível — deixei como está"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ "$estado" = gtk ] && return "$MEOW_OK"
  meow_muda "$_CR_ROTULO: $arquivo está no modo Clássico, com os botões da janela do próprio navegador"
  return "$MEOW_DIVERGENTE"
}

_cr_aplicar_um() {
  local tipo="$1" id="$2" arquivo="$3" estado rc
  estado="$(_cr_py estado "$arquivo")" || { meow_pula "$_CR_ROTULO: $arquivo não é um JSON legível — deixei como está"; return "$MEOW_SEM_DEPENDENCIA"; }
  [ "$estado" = gtk ] && return "$MEOW_OK"
  if _cr_aberto "$tipo" "$id"; then
    meow_pula "$_CR_ROTULO: o navegador está aberto — ele reescreve o Preferences ao sair; a próxima passada com ele fechado aplica"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if meow_seco; then meow_muda "$_CR_ROTULO: poria $arquivo no modo GTK"; return "$MEOW_DIVERGENTE"; fi
  meow_destino_permitido "$arquivo" || return "$MEOW_ERRO"
  meow_guardar_antes "$arquivo"
  _cr_py aplicar "$arquivo"; rc=$?
  [ "$rc" -ge 2 ] && { meow_erro "$_CR_ROTULO: falhou ao escrever $arquivo"; return "$MEOW_ERRO"; }
  [ "$rc" = 1 ] && meow_ok "$_CR_ROTULO: $arquivo no modo GTK, com os botões e as cores do pack"
  return "$rc"
}

_cr_reverter_um() {
  local tipo="$1" id="$2" arquivo="$3" rc
  _cr_py guardado "$arquivo" || return "$MEOW_OK"
  if _cr_aberto "$tipo" "$id"; then
    meow_pula "$_CR_ROTULO: o navegador está aberto — nada foi desfeito em $arquivo"
    return "$MEOW_SEM_DEPENDENCIA"
  fi
  if meow_seco; then meow_muda "$_CR_ROTULO: devolveria o tema de antes a $arquivo"; return "$MEOW_DIVERGENTE"; fi
  meow_destino_permitido "$arquivo" || return "$MEOW_ERRO"
  meow_guardar_antes "$arquivo"
  _cr_py reverter "$arquivo"; rc=$?
  [ "$rc" -ge 2 ] && { meow_erro "$_CR_ROTULO: falhou ao devolver $arquivo"; return "$MEOW_ERRO"; }
  [ "$rc" = 1 ] && meow_ok "$_CR_ROTULO: $arquivo voltou ao tema de antes"
  return "$rc"
}

_cr_cada() {
  local acao="$1" tipo id arquivo rcs=()
  while IFS=$'\t' read -r tipo id arquivo; do
    [ -n "$arquivo" ] || continue
    if [ "$acao" = conferir ]; then _cr_conferir_um "$arquivo"; else "_cr_${acao}_um" "$tipo" "$id" "$arquivo"; fi
    rcs+=($?)
  done < <(_cr_perfis)
  [ "${#rcs[@]}" -gt 0 ] || return "$MEOW_OK"
  meow_tarq_somar "${rcs[@]}"
}

meow_app_conferir() {
  local rc
  meow_app_detectar || return "$MEOW_SEM_DEPENDENCIA"
  _cr_cada conferir; rc=$?
  [ "$rc" = "$MEOW_OK" ] && meow_ok "$_CR_ROTULO: os navegadores já estão no modo GTK"
  return "$rc"
}

meow_app_aplicar() {
  meow_app_detectar || { meow_app_pendente "$_CR_ROTULO"; return; }
  _cr_cada aplicar
}

meow_app_reverter() {
  local rc
  [ -n "$(_cr_perfis | head -n 1)" ] || { meow_ok "$_CR_ROTULO: nenhum perfil — nada a desfazer"; return "$MEOW_OK"; }
  _cr_cada reverter; rc=$?
  [ "$rc" = "$MEOW_DIVERGENTE" ] && meow_app_desligar "$_CR_ROTULO"
  return "$rc"
}
