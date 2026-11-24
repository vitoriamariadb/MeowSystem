#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'kill "${SERVIDOR:-}" 2>/dev/null; rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf '  pulado: %s\n' "$*"; }
PATCH="$RAIZ/dados/patches/cosmic-comp-app-id-do-cliente.patch"

mkdir -p "$T/casa/.config/meow" "$T/run"
cat > "$T/compositor.py" <<'PY'
import os, socket, struct, sys

JANELAS = [("google-chrome", "Calendar - Google Chrome"),
           ("", "O teams.cloud.microsoft está compartilhando sua tela.")]
if len(sys.argv) > 2:
    JANELAS = [tuple(l.rstrip("\n").split("\t", 1)) for l in open(sys.argv[2]) if l.strip()]
IFACE = "ext_foreign_toplevel_list_v1"


def wstr(t):
    b = t.encode() + b"\0"
    return struct.pack("<I", len(b)) + b + b"\0" * ((-len(b)) % 4)


def ev(obj, op, corpo=b""):
    return struct.pack("<II", obj, ((8 + len(corpo)) << 16) | op) + corpo


srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
srv.bind(sys.argv[1])
srv.listen(4)
print("pronto", flush=True)
while True:
    c, _ = srv.accept()
    buf, lista = b"", None
    while True:
        d = c.recv(4096)
        if not d:
            break
        buf += d
        while len(buf) >= 8:
            obj, sz = struct.unpack("<II", buf[:8])
            tam, op = sz >> 16, sz & 0xFFFF
            if len(buf) < tam:
                break
            corpo, buf = buf[8:tam], buf[tam:]
            if obj == 1 and op == 1:
                registro = struct.unpack("<I", corpo)[0]
                c.sendall(ev(registro, 0, struct.pack("<I", 1) + wstr(IFACE) + struct.pack("<I", 1)))
            elif obj == 1 and op == 0:
                retorno = struct.unpack("<I", corpo)[0]
                for i, (app_id, titulo) in enumerate(JANELAS):
                    h = 0xff000000 + i
                    c.sendall(ev(lista, 0, struct.pack("<I", h)))
                    c.sendall(ev(h, 2, wstr(titulo)))
                    if app_id:
                        c.sendall(ev(h, 3, wstr(app_id)))
                c.sendall(ev(retorno, 0, struct.pack("<I", 0)))
            elif lista is None:
                lista = struct.unpack("<I", corpo[-4:])[0]
    c.close()
PY

ambiente() {
  env -i PATH="$PATH" HOME="$T/casa" NO_COLOR=1 XDG_RUNTIME_DIR="$T/run" WAYLAND_DISPLAY=sonda "$@"
}

echo "== a sonda vê a janela sem app_id"
python3 -I "$T/compositor.py" "$T/run/sonda" > "$T/pronto" & SERVIDOR=$!
for _ in $(seq 50); do [ -S "$T/run/sonda" ] && break; sleep 0.1; done
saida="$(ambiente python3 "$RAIZ/scripts/appid_sonda.py" --janelas)"; rc=$?
[ "$rc" = 0 ] && ok "a sonda fala com o compositor falso" || falha "a sonda saiu $rc"
grep -qF 'google-chrome	Calendar' <<< "$saida" && ok "a janela normal segue na lista" || falha "sumiu a janela normal: $saida"
grep -qF -- '-	O teams.cloud.microsoft' <<< "$saida" && ok "--janelas lista a barra, sem app_id" || falha "a barra não apareceu: $saida"
[ "$(cut -f1 <<< "$saida" | grep -c .)" = 2 ] && ok "o campo do app_id nunca fica vazio: o título não vira app_id" \
  || falha "campo vazio na saída: $saida"

echo "== o doctor aponta a janela, sem mandar digitar"
saida="$(ambiente bash "$RAIZ/scripts/appid_dock.sh" --conferir 2>&1)"
grep -qF 'janela sem app_id' <<< "$saida" && grep -qF 'compartilhando sua tela' <<< "$saida" \
  && ok "o --conferir aponta a barra" || falha "o doctor não apontou a barra: $saida"
grep -F 'teams.cloud' <<< "$saida" | grep -qiE 'cole|rode|digite' && falha "a linha manda digitar: $saida" || ok "a linha só aponta"
grep -q "app_id '-'" <<< "$saida" && falha "o traço virou app_id: $saida" || ok "o traço não vira app_id a casar"
cabeca="$(ambiente bash -c 'RAIZ="$1"; eval "$(sed -n "/^chk_janeladock()/,/^}/p" "$RAIZ/scripts/meow")"; chk_janeladock' _ "$RAIZ" 2>&1 | head -1)"
grep -qE '^[[:space:]]*!![[:space:]]+janela sem app_id' <<< "$cabeca" \
  && ok "o meow doctor mostra a janela: com rc 0, só o aviso na cabeça aparece" || falha "o aviso não está na cabeça do doctor: $cabeca"

echo "== o patch"
grep -qE '^req[[:space:]]+cosmic-comp-app-id-do-cliente\.patch[[:space:]]+AURORA-APP-ID-CLIENTE$' "$RAIZ/dados/patches/series" \
  && ok "o patch está na série, com marcador próprio" || falha "o patch não está na série"
grep -qF '"AURORA-APP-ID-CLIENTE-1"' "$PATCH" && grep -q '^+#\[used\]' "$PATCH" \
  && ok "o marcador sobrevive ao linker" || falha "falta o marcador com #[used]"
grep -q '^+            WindowSurface::X11(_) => None,' "$PATCH" \
  && ok "X11 fica de fora: todas as janelas X11 são do mesmo cliente" || falha "X11 entrou na herança"
grep -E '^\+' "$PATCH" | grep -qiE 'chrome|teams' && falha "o patch cita um app" || ok "o código do patch não cita app nenhum"
grep -A2 '^+.*new_toplevel::<D>($' "$PATCH" | grep -q 'herdado' \
  && ok "a janela nasce com o herdado: a dock a agrupa no Add" || falha "new_toplevel não anuncia o herdado"
grep -qE '^[ +-][[:space:]]*pub fn refresh' "$PATCH" \
  && falha "o patch mexe no refresh: mudar o app_id depois apaga da dock as janelas com ele" \
  || ok "o app_id não muda depois do anúncio: o Update da dock não apaga as irmãs"
[ "$(grep -c '^+.*app_id_herdado = ' "$PATCH")" = 1 ] && ok "a herança é gravada num ponto só" || falha "a herança é gravada em mais de um ponto"

echo "== a herança, compilada do próprio patch"
export RUSTUP_HOME="${RUSTUP_HOME:-${SUITE_CASA_REAL:-$HOME}/.rustup}"
if ! rustc --version >/dev/null 2>&1; then
  pula "sem rustc nesta máquina: a herança não foi compilada"
else
  { sed -n '/^+fn app_id_do_irmao/,/^+}/p;/^+fn app_id_herdado/,/^+}/p' "$PATCH" | sed 's/^+//'
    cat <<'RS'
trait Window {
    fn app_id(&self) -> String;
    fn client_id(&self) -> Option<u32>;
    fn alive(&self) -> bool;
}
struct J(&'static str, Option<u32>, bool);
impl Window for J {
    fn app_id(&self) -> String {
        self.0.to_string()
    }
    fn client_id(&self) -> Option<u32> {
        self.1
    }
    fn alive(&self) -> bool {
        self.2
    }
}
#[test]
fn janela_nova_herda_da_irma_viva() {
    let irmas = [J("morta", Some(1), false), J("google-chrome", Some(1), true)];
    assert_eq!(app_id_herdado(&J("", Some(1), true), &irmas), Some("google-chrome".to_string()));
}
#[test]
fn janela_com_app_id_proprio_nao_herda() {
    assert_eq!(app_id_herdado(&J("outro", Some(1), true), &[J("google-chrome", Some(1), true)]), None);
}
#[test]
fn janela_x11_nao_herda() {
    assert_eq!(app_id_herdado(&J("", None, true), &[J("google-chrome", None, true)]), None);
}
fn irmas() -> Vec<(Option<u32>, String)> {
    vec![
        (Some(1), String::new()),
        (None, "xwayland".to_string()),
        (Some(2), "outro".to_string()),
        (Some(1), "google-chrome".to_string()),
        (Some(1), "chrome-pwa".to_string()),
    ]
}
#[test]
fn herda_a_primeira_irma_com_app_id() {
    assert_eq!(app_id_do_irmao(&1, irmas()), Some("google-chrome".to_string()));
}
#[test]
fn nao_herda_de_outro_cliente() {
    assert_eq!(app_id_do_irmao(&3, irmas()), None);
}
#[test]
fn sem_irma_com_app_id_nao_herda() {
    assert_eq!(app_id_do_irmao(&1, vec![(Some(1), String::new())]), None);
}
#[test]
fn janela_sem_cliente_nao_e_irma() {
    assert_eq!(app_id_do_irmao(&1, vec![(None, "xwayland".to_string())]), None);
}
RS
  } > "$T/heranca.rs"
  if rustc --edition 2021 --test -o "$T/heranca" "$T/heranca.rs" > "$T/rustc" 2>&1 && "$T/heranca" > "$T/saida" 2>&1; then
    ok "$(grep 'test result' "$T/saida")"
  else
    falha "a herança não passou: $(cat "$T/rustc" "$T/saida" 2>/dev/null)"
  fi
fi

echo "== as janelas do sistema medidas no palco ganham a ponte (P235)"
SIS="$T/sistema/applications"; APPS="$T/casa/.local/share/applications"
mkdir -p "$SIS" "$APPS" "$T/run2" "$T/estado"
printf '[Desktop Entry]\nType=Application\nName=Arquivos\nExec=cosmic-files %%U\nIcon=com.system76.CosmicFiles\n' \
  > "$SIS/com.system76.CosmicFiles.desktop"
printf '[Desktop Entry]\nType=Application\nName=Portal\nIcon=applications-system-symbolic\nExec=/usr/libexec/xdg-desktop-portal-gtk\nNoDisplay=true\n' \
  > "$SIS/xdg-desktop-portal-gtk.desktop"
printf '[Desktop Entry]\nType=Application\nName=Access Prompt\nIcon=security-medium\nExec=/usr/libexec/gcr-prompter\nNoDisplay=true\n' \
  > "$SIS/gcr-prompter.desktop"
printf '%s\t\n' com.system76.CosmicFilesDialog xdg-desktop-portal-gtk gcr-prompter com.system76.CosmicFiles > "$T/sistema.janelas"
python3 -I "$T/compositor.py" "$T/run2/sonda" "$T/sistema.janelas" > /dev/null & SERVIDOR2=$!
trap 'kill "${SERVIDOR:-}" "${SERVIDOR2:-}" 2>/dev/null; rm -rf "$T"' EXIT
for _ in $(seq 50); do [ -S "$T/run2/sonda" ] && break; sleep 0.1; done
sistema() {
  env -i PATH="$PATH" HOME="$T/casa" NO_COLOR=1 XDG_RUNTIME_DIR="$T/run2" WAYLAND_DISPLAY=sonda \
    XDG_DATA_DIRS="$T/sistema" MEOW_ESTADO="$T/estado" "$@"
}
fotografar() { (cd "$T" && find casa sistema -printf '%p %s %T@\n' | sort); }
casa_de() { sistema python3 "$RAIZ/scripts/appid_sonda.py" --casar <<< "$1" | cut -f2,3; }
grep -qxF 'com.system76.CosmicFilesDialog:com.system76.CosmicFiles' "$RAIZ/dados/apps/appid.map" \
  && ok "o mapa leva o diálogo de arquivos ao Gestor de Arquivos" || falha "o diálogo de arquivos não está no mapa"
[ "$(casa_de com.system76.CosmicFilesDialog)" = "-	-" ] \
  && ok "antes da ponte o diálogo não casa: a dock desenha a engrenagem" || falha "o diálogo já casava: $(casa_de com.system76.CosmicFilesDialog)"
sistema bash "$RAIZ/scripts/appid_dock.sh" --aplicar > "$T/aplicar" 2>&1; rc=$?
ponte="$APPS/meow-janela-com.system76.CosmicFilesDialog.desktop"
[ "$rc" = 1 ] && grep -qx 'StartupWMClass=com.system76.CosmicFilesDialog' "$ponte" \
  && grep -qx 'Icon=com.system76.CosmicFiles' "$ponte" && grep -qx 'Name=Arquivos' "$ponte" && grep -qx 'NoDisplay=true' "$ponte" \
  && ok "a ponte nasce com o nome e o ícone do Gestor de Arquivos, escondida" || falha "a ponte não saiu certa (rc $rc): $(cat "$T/aplicar" "$ponte" 2>&1)"
[ "$(casa_de com.system76.CosmicFilesDialog)" = "StartupWMClass	$ponte" ] \
  && ok "depois da ponte o diálogo casa" || falha "o diálogo segue sem casar: $(casa_de com.system76.CosmicFilesDialog)"
[ "$(casa_de com.system76.CosmicFiles)" = "id	$SIS/com.system76.CosmicFiles.desktop" ] \
  && ok "a janela do próprio Gestor segue no .desktop real" || falha "a ponte venceu o .desktop real: $(casa_de com.system76.CosmicFiles)"
for j in xdg-desktop-portal-gtk gcr-prompter; do
  [ "$(casa_de "$j")" = "id	$SIS/$j.desktop" ] && ! ls "$APPS" | grep -qF "$j" \
    && ok "$j já casa no .desktop dele e não ganha ponte" || falha "$j: $(casa_de "$j"); $(ls "$APPS")"
done
grep -qF 'janela(s) aberta(s) cujo app_id não casa' "$T/aplicar" \
  && falha "o doctor ainda acusa janela do sistema sem casamento: $(cat "$T/aplicar")" || ok "nenhuma janela do sistema medida fica sem casamento"
antes="$(fotografar)"
sistema bash "$RAIZ/scripts/appid_dock.sh" --aplicar > /dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && [ "$antes" = "$(fotografar)" ] && ok "a segunda passada não escreve" || falha "a segunda passada escreveu (rc $rc)"

if [ "$falhas" = 0 ]; then echo "janela-sem-app-id: tudo certo"; exit 0; fi
echo "janela-sem-app-id: $falhas falha(s)"; exit 1
