#!/usr/bin/env bash
set -uo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)" || exit 2
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p "$TMP/falso" "$TMP/casa" "$TMP/raiz"
for c in sudo pkexec su apt apt-get cargo just make rustup curl wget pkill killall \
         notify-send systemd-run loginctl xdg-open flatpak; do
  printf '#!/bin/sh\necho "%s $*" >> "%s/recusas.log"\nexit 1\n' "$c" "$TMP" > "$TMP/falso/$c"
  chmod 755 "$TMP/falso/$c"
done
real_systemctl="$(command -v systemctl 2>/dev/null || true)"
cat > "$TMP/falso/systemctl" <<FIM
#!/bin/sh
for a in "\$@"; do case "\$a" in -*) ;; *) verbo="\$a"; break ;; esac; done
case " \${verbo:-} " in
  " is-active "|" is-enabled "|" status "|" show "|" cat "|" list-units "|" list-unit-files "|"  ")
    [ -n "$real_systemctl" ] && exec "$real_systemctl" "\$@"; exit 1 ;;
esac
echo "systemctl \$*" >> "$TMP/recusas.log"; exit 1
FIM
chmod 755 "$TMP/falso/systemctl"

git -C "$RAIZ" ls-files -z --cached --others --exclude-standard \
  | (cd "$RAIZ" && tar --null -T - -cf - 2>/dev/null) | tar -xf - -C "$TMP/raiz" || exit 2

CASA="$TMP/casa"
mkdir -p "$CASA/.config/meow" "$CASA/.config/cosmic/com.system76.CosmicComp/v1" \
         "$CASA/.local/state/meowsystem" "$CASA/.local/share/applications"
cp "$RAIZ/meow.conf.exemplo" "$CASA/.config/meow/meow.conf"
printf '[\n    (\n        output: (\n            name: "DP-1",\n            edid: None,\n        ),\n        tiling_enabled: false,\n        id: Some("c0ffee"),\n        name: Some("Brinquedo"),\n    ),\n    (\n        output: (\n            name: "DP-1",\n            edid: None,\n        ),\n        tiling_enabled: false,\n        id: Some("decafe"),\n        name: Some("Quintal"),\n    ),\n]\n' \
  > "$CASA/.config/cosmic/com.system76.CosmicComp/v1/pinned_workspaces"

unset DBUS_SESSION_BUS_ADDRESS XDG_RUNTIME_DIR WAYLAND_DISPLAY DISPLAY \
      XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME MEOW_CONF MEOW_ESTADO
export HOME="$CASA" PATH="$TMP/falso:$PATH" MEOW_PONTE="$TMP/sem-ponte" MEOW_SEM_REDE=1

python3 -I - "$TMP/raiz" "$@" <<'PY'
import hashlib, importlib.util, os, sys, time

raiz, so = sys.argv[1], sys.argv[2:]
casa = os.environ["HOME"]
spec = importlib.util.spec_from_file_location("servidor", os.path.join(raiz, "app", "servidor.py"))
sv = importlib.util.module_from_spec(spec)
sys.argv = [sys.argv[0]]
spec.loader.exec_module(sv)

FORA = [sv.ESTADO, os.path.join(casa, ".cache")]


def foto():
    vista = {}
    for base, pastas, arquivos in os.walk(casa):
        pastas[:] = [p for p in pastas if os.path.join(base, p) not in FORA]
        for a in arquivos:
            c = os.path.join(base, a)
            if c in FORA:
                continue
            if os.path.islink(c):
                vista[c] = "-> " + os.readlink(c)
                continue
            try:
                with open(c, "rb") as fh:
                    vista[c] = hashlib.sha256(fh.read()).hexdigest()
            except OSError:
                vista[c] = "?"
    return vista


def rodar(acao, arg):
    t, erro = sv.iniciar(acao, arg, confirmado=True)
    if erro:
        return None, erro
    fim = time.time() + 300
    while t.vivo() and time.time() < fim:
        time.sleep(0.2)
    if t.vivo():
        t.parar()
        return t, "passou de 300 s"
    time.sleep(0.3)
    return t, None


falhas, vistas = [], 0
for ident, acao in sv.ACOES.items():
    if ident == "restaurar" or (so and ident not in so):
        continue
    arg = ""
    if "arg" in acao:
        opcoes = sv.PROVEDORES[acao["arg"]]()
        if not opcoes:
            continue
        arg = opcoes[-1]
    if sv.indisponivel(ident):
        continue
    antes = foto()
    t, erro = rodar(ident, arg)
    if t is None:
        print(f"  -- {ident}: não rodou ({erro})")
        continue
    vistas += 1
    depois = foto()
    tem = ident in sv.restauros()
    if not sv.escreve(acao):
        if tem:
            falhas.append(f"{ident}: só lê e deixou «Restaurar»")
        if depois != antes:
            falhas.append(f"{ident}: só lê e mudou {sorted(set(depois.items()) ^ set(antes.items()))[:2]}")
        print(f"  ok {ident}: só lê")
        continue
    if depois == antes:
        fora_do_motor = []
        if tem:
            with open(os.path.join(sv.restauros()[ident], "tocados.tsv"), encoding="utf-8") as fh:
                fora_do_motor = [l for l in fh.read().splitlines()
                                 if not l.startswith(sv.ESTADO + os.sep)]
        if fora_do_motor:
            falhas.append(f"{ident}: não mudou nada e deixou «Restaurar» ({fora_do_motor[:2]})")
        print(f"  ok {ident}: nada mudou (rc {t.rc})")
        continue
    if not tem:
        mudou = sorted(k for k in set(antes) | set(depois) if antes.get(k) != depois.get(k))
        falhas.append(f"{ident}: mudou {len(mudou)} arquivo(s) e não deixou «Restaurar»: "
                      + ", ".join(m.replace(casa, "~") for m in mudou[:4]))
        print(f"  XX {ident}")
        continue
    pasta = sv.restauros()[ident]
    with open(os.path.join(pasta, "tocados.tsv"), encoding="utf-8") as fh:
        tocados = fh.read().splitlines()
    r, erro = rodar("restaurar", ident)
    if r is None or erro or r.rc not in (0, 1):
        falhas.append(f"{ident}: o «Restaurar» não rodou ({erro or r.rc})")
        continue
    volta = foto()
    resto = sorted(k for k in set(antes) | set(volta) if antes.get(k) != volta.get(k))
    if resto:
        falhas.append(f"{ident}: o «Restaurar» não voltou {len(resto)} arquivo(s): "
                      + ", ".join(m.replace(casa, "~") for m in resto[:4]))
        if os.environ.get("MEOW_TESTE_DETALHE"):
            alvo = resto[0]
            for m in resto[:60]:
                print("    -", m.replace(casa, "~"))
            print("    antes:", antes.get(alvo), "depois:", depois.get(alvo), "volta:", volta.get(alvo))
            print("    na lista:", [t for t in tocados if alvo.startswith(t.split("\t")[0])][:6])
            print("    saída do restaurar:", "\n".join(r.linhas[-8:]))
        print(f"  XX {ident}")
    elif ident in sv.restauros():
        falhas.append(f"{ident}: o «Restaurar» continua oferecido depois de restaurar")
    else:
        print(f"  ok {ident}: voltou byte a byte")

if falhas:
    print(f"\nFALHOU: {len(falhas)} ação(ões)")
    for f in falhas:
        print("  - " + f)
    sys.exit(1)
print(f"\nok: {vistas} ações rodadas; toda que mudou a casa volta byte a byte com o «Restaurar».")
PY
