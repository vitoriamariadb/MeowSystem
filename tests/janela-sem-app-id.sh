#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'kill "${SERVIDOR:-}" 2>/dev/null; rm -rf "$T"' EXIT
falhas=0
ok()    { printf '  ok    %s\n' "$*"; }
falha() { printf '  FALHA %s\n' "$*"; falhas=$((falhas+1)); }
pula()  { printf '  pulado: %s\n' "$*"; }
PATCH="$RAIZ/patches/cosmic-comp-app-id-do-cliente.patch"

mkdir -p "$T/casa/.config/meow" "$T/run"
cat > "$T/compositor.py" <<'PY'
import os, socket, struct, sys

JANELAS = [("google-chrome", "Calendar - Google Chrome"),
           ("", "O teams.cloud.microsoft está compartilhando sua tela.")]
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

echo "== o patch"
grep -qE '^req[[:space:]]+cosmic-comp-app-id-do-cliente\.patch[[:space:]]+AURORA-APP-ID-CLIENTE$' "$RAIZ/patches/series" \
  && ok "o patch está na série, com marcador próprio" || falha "o patch não está na série"
grep -qF '"AURORA-APP-ID-CLIENTE-1"' "$PATCH" && grep -q '^+#\[used\]' "$PATCH" \
  && ok "o marcador sobrevive ao linker" || falha "falta o marcador com #[used]"
grep -q '^+            WindowSurface::X11(_) => None,' "$PATCH" \
  && ok "X11 fica de fora: todas as janelas X11 são do mesmo cliente" || falha "X11 entrou na herança"
grep -E '^\+' "$PATCH" | grep -qiE 'chrome|teams' && falha "o patch cita um app" || ok "o código do patch não cita app nenhum"

echo "== a herança, compilada do próprio patch"
export RUSTUP_HOME="${RUSTUP_HOME:-${SUITE_CASA_REAL:-$HOME}/.rustup}"
if ! rustc --version >/dev/null 2>&1; then
  pula "sem rustc nesta máquina: a herança não foi compilada"
else
  { sed -n '/^+fn app_id_do_irmao/,/^+}/p' "$PATCH" | sed 's/^+//'
    cat <<'RS'
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

if [ "$falhas" = 0 ]; then echo "janela-sem-app-id: tudo certo"; exit 0; fi
echo "janela-sem-app-id: $falhas falha(s)"; exit 1
