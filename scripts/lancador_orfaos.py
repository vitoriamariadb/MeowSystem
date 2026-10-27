#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

WRAPPERS = {"env", "nice", "systemd-run", "gtk-launch", "dbus-run-session",
            "setsid", "nohup", "ionice", "pkexec"}
NAMESPACE = {"distrobox-enter", "toolbox", "flatpak-spawn", "podman", "docker",
             "lxc", "ssh", "chroot"}
SHELL = {"sh", "bash", "zsh", "fish", "dash"}
RE_APPID = re.compile(r"^[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+){2,}$")

DADOS = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local/share")
DIRS = [DADOS / "applications", DADOS / "flatpak/exports/share/applications"]
NOSSO_BIN = str(Path.home() / ".local/bin/meow")


def campos(arq: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    try:
        texto = arq.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return out
    dentro = False
    for linha in texto.splitlines():
        linha = linha.strip()
        if linha.startswith("["):
            if dentro:
                break
            dentro = linha == "[Desktop Entry]"
            continue
        if dentro and "=" in linha and not linha.startswith("#"):
            chave, _, valor = linha.partition("=")
            out.setdefault(chave.strip(), valor.strip())
    return out


_FLATPAK: set[str] | None = None
_FLATPAK_LIDO = False


def flatpak_instalado(appid: str) -> bool:
    global _FLATPAK, _FLATPAK_LIDO
    if not _FLATPAK_LIDO:
        _FLATPAK_LIDO = True
        try:
            r = subprocess.run(["flatpak", "list", "--columns=application"],
                               capture_output=True, text=True, timeout=30)
            if r.returncode == 0:
                _FLATPAK = {l.strip() for l in r.stdout.splitlines() if l.strip()} or None
        except (OSError, subprocess.SubprocessError):
            _FLATPAK = None
    return True if _FLATPAK is None else appid in _FLATPAK


def existe(caminho: str) -> bool:
    return bool(caminho and (shutil.which(caminho) or Path(caminho).is_file()))


def alvo_existe(c: dict[str, str]) -> bool:
    tryexec = c.get("TryExec", "").strip().strip("\"'")
    if tryexec:
        if existe(tryexec):
            return True
        partes = tryexec.split()
        return len(partes) > 1 and existe(partes[0])
    linha = c.get("Exec", "")
    if not linha:
        return True
    try:
        toks = [t for t in shlex.split(linha) if not t.startswith("%")]
    except ValueError:
        return True
    while toks:
        cabeca = Path(toks[0].strip("\"'")).name
        if cabeca == "flatpak":
            for t in toks[1:]:
                if RE_APPID.match(t.strip("\"'")):
                    return flatpak_instalado(t.strip("\"'"))
            return True
        if cabeca in NAMESPACE:
            return existe(toks[0].strip("\"'"))
        if cabeca in SHELL and any(t == "-c" for t in toks[1:3]):
            return True
        if cabeca in WRAPPERS:
            if "--" in toks:
                toks = toks[toks.index("--") + 1:]
                continue
            toks = toks[1:]
            while toks and (toks[0].startswith("-") or "=" in toks[0]):
                toks = toks[1:]
            continue
        return existe(toks[0].strip("\"'"))
    return True


def nosso(arq: Path, c: dict[str, str]) -> bool:
    try:
        texto = arq.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return True
    if re.search(r"^X-MeowSystem", texto, re.M):
        return True
    return c.get("Exec", "").strip("\"'").startswith(NOSSO_BIN)


def main() -> int:
    for raiz in DIRS:
        if not raiz.is_dir():
            continue
        for arq in sorted(raiz.rglob("*.desktop")):
            c = campos(arq)
            if c.get("Type", "Application") != "Application" or not c.get("Exec"):
                continue
            if nosso(arq, c) or alvo_existe(c):
                continue
            alvo = c.get("TryExec") or c.get("Exec", "")
            print(f"{arq}\t{c.get('Name', arq.stem)}\t{alvo[:60]}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
