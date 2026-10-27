# Contorno local do Nitro (27/10)

O que roda hoje no Nitro, fora do produto: `~/.local/bin/corrigir-flatpaks-libadwaita` com o gatilho
`corrigir-flatpaks-libadwaita.path` do systemd do usuário, e um script por app no `~/Desktop`. É a fonte que a P127 e
a P128 levam para `scripts/flatpak_tema.sh`, o doctor e os módulos; não entra no repositório como script.
Quando a P127 e a P128 chegarem ao Nitro, o `--remover` desliga o gatilho e os overrides por app saem pelo doctor.

## O script global

```bash
#!/usr/bin/env bash
# Corrige o visual (e o crash de abertura) de apps Flatpak que usam libadwaita no COSMIC.
#
# Causas, diagnosticadas em 2026-10-27 com o Clapper:
#   1. O override global define GTK_THEME=adw-gtk3-dark: com essa variável o libadwaita
#      não carrega o próprio estilo (ícone minúsculo, layout sem formatação).
#   2. O override global expõe xdg-config/gtk-4.0, onde o COSMIC gera um gtk.css que deixa
#      o libadwaita novo com fundo branco e texto branco.
#   3. O override global expõe xdg-data/icons, mas o Flatpak já monta esses ícones em
#      /run/host/user-share/icons: os temas aparecem duas vezes no caminho de busca e o
#      GTK 4.20 entra em recursão infinita em real_choose_icon quando o app cria um
#      Gtk.IconTheme sem tela (o Warehouse faz isso). Tirar a exposição não perde ícone.
#   4. Runtime GNOME <= 47 (GTK 4.16) dá segfault em linux_dmabuf_tranche_done no Wayland
#      do COSMIC. Contorno: forçar um runtime GNOME >= 48 no .desktop e no serviço D-Bus.
#
# O override global fica intacto (ele dá o tema escuro aos apps GTK3).
# Idempotente: rodar de novo não muda nada que já esteja certo.
# Tudo mora em $HOME, então apt upgrade não desfaz nada.
#
# Uso:
#   corrigir-flatpaks-libadwaita.sh             aplica em todos os apps libadwaita instalados
#   corrigir-flatpaks-libadwaita.sh --instalar  aplica e passa a reaplicar sozinho a cada
#                                               instalação/atualização de Flatpak e no login
#   corrigir-flatpaks-libadwaita.sh --remover   desliga a reaplicação automática

set -euo pipefail

NOME=corrigir-flatpaks-libadwaita
DESTINO="$HOME/.local/bin/$NOME"
UNIDADES="$HOME/.config/systemd/user"
APPS_LOCAIS="$HOME/.local/share/applications"
DBUS_LOCAL="$HOME/.local/share/dbus-1/services"
RUNTIME_MINIMO=48

usa_libadwaita() {
    local arquivos
    arquivos="$(flatpak info --show-location "$1")/files"
    grep -rqaE 'libadwaita-1\.so|require_version\(.Adw.|gi://Adw' "$arquivos" 2>/dev/null
}

corrigir_tema() {
    local id=$1 atual
    atual=$(flatpak override --user --show "$id" 2>/dev/null || true)
    if grep -q 'unset-environment=.*GTK_THEME' <<<"$atual" &&
       grep -q '!xdg-config/gtk-4.0' <<<"$atual" &&
       grep -q '!xdg-data/icons' <<<"$atual"; then
        echo "  tema: já corrigido"
        return
    fi
    flatpak override --user --unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0 \
        --nofilesystem=xdg-data/icons "$id"
    echo "  tema: corrigido"
}

# Primeiro runtime validado que estiver instalado, ou vazio. O mais novo não serve:
# o GTK do GNOME 51 liga no GStreamer do sistema e o Clapper (que traz o próprio)
# morre com "undefined symbol: gst_play_config_set_loop".
RUNTIMES_VALIDADOS="49 50"
runtime_novo() {
    local v
    for v in $RUNTIMES_VALIDADOS; do
        flatpak info "org.gnome.Platform//$v" >/dev/null 2>&1 && { echo "$v"; return; }
    done
}

corrigir_runtime() {
    local id=$1 versao alvo desktop export_desktop servico export_servico
    versao=$(flatpak info "$id" | sed -n 's|.*Runtime: org.gnome.Platform/[^/]*/||p')
    desktop="$APPS_LOCAIS/$id.desktop"
    export_desktop=$(flatpak info --show-location "$id")/export/share/applications/$id.desktop
    servico="$DBUS_LOCAL/$id.service"
    export_servico=$(flatpak info --show-location "$id")/export/share/dbus-1/services/$id.service

    # App já num runtime bom: tira o contorno, se houver, para não prendê-lo a um runtime velho.
    if [[ -z "$versao" || "$versao" -ge $RUNTIME_MINIMO ]]; then
        if [[ -f "$desktop" ]] && grep -q -- '--runtime=org.gnome.Platform//' "$desktop"; then
            sed -i -E 's| --runtime=org\.gnome\.Platform//[0-9]+||' "$desktop"
            echo "  runtime: app saiu do runtime $RUNTIME_MINIMO-, contorno removido do .desktop"
        fi
        if [[ -f "$servico" ]] && grep -q "# $NOME" "$servico"; then
            rm -f "$servico"
            echo "  runtime: serviço D-Bus local removido"
        fi
        return
    fi

    alvo=$(runtime_novo)
    if [[ -z "$alvo" ]]; then
        echo "  runtime: GNOME $versao trava no COSMIC e não há runtime GNOME >= $RUNTIME_MINIMO instalado" >&2
        echo "           instale um: flatpak install --user flathub org.gnome.Platform//49" >&2
        return
    fi

    mkdir -p "$APPS_LOCAIS" "$DBUS_LOCAL"
    # Mantém uma cópia local já existente (pode ter traduções próprias); senão parte do export.
    [[ -f "$desktop" ]] || cp "$export_desktop" "$desktop"
    if ! grep -q -- "--runtime=org.gnome.Platform//$alvo " "$desktop"; then
        sed -i -E 's| --runtime=org\.gnome\.Platform//[0-9]+||' "$desktop"
        sed -i "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$alvo |" "$desktop"
        update-desktop-database "$APPS_LOCAIS" 2>/dev/null || true
        echo "  runtime: .desktop forçado para GNOME $alvo (app pede $versao)"
    else
        echo "  runtime: .desktop já forçado para GNOME $alvo"
    fi

    # .desktop com DBusActivatable=true é aberto pelo serviço D-Bus, não pelo Exec.
    if [[ -f "$export_servico" ]]; then
        local novo
        novo=$(printf '# %s\n' "$NOME"; sed "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$alvo |" "$export_servico")
        if [[ ! -f "$servico" ]] || [[ "$(cat "$servico")" != "$novo" ]]; then
            printf '%s\n' "$novo" >"$servico"
            busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null 2>&1 || true
            echo "  runtime: serviço D-Bus forçado para GNOME $alvo"
        else
            echo "  runtime: serviço D-Bus já forçado"
        fi
    fi
}

aplicar() {
    local id achou=0
    for id in $(flatpak list --app --columns=application | sort -u); do
        usa_libadwaita "$id" || continue
        achou=1
        echo "$id"
        corrigir_tema "$id"
        corrigir_runtime "$id"
    done
    [[ $achou == 1 ]] || echo "Nenhum app libadwaita encontrado."
}

instalar() {
    mkdir -p "$(dirname "$DESTINO")" "$UNIDADES"
    install -m 755 "$(readlink -f "$0")" "$DESTINO"

    cat >"$UNIDADES/$NOME.service" <<EOF
[Unit]
Description=Corrige apps Flatpak libadwaita no COSMIC

[Service]
Type=oneshot
ExecStart=$DESTINO

[Install]
WantedBy=default.target
EOF

    # Instalar, atualizar ou remover um Flatpak reescreve os exports: dispara a correção.
    cat >"$UNIDADES/$NOME.path" <<EOF
[Unit]
Description=Reaplica a correção libadwaita quando Flatpaks mudam

[Path]
PathChanged=$HOME/.local/share/flatpak/exports/share/applications
PathChanged=/var/lib/flatpak/exports/share/applications
Unit=$NOME.service

[Install]
WantedBy=default.target
EOF

    systemctl --user daemon-reload
    systemctl --user enable --now "$NOME.path" >/dev/null 2>&1
    systemctl --user enable "$NOME.service" >/dev/null 2>&1
    echo "Reaplicação automática ligada ($NOME.path + login)."
}

remover() {
    systemctl --user disable --now "$NOME.path" "$NOME.service" >/dev/null 2>&1 || true
    rm -f "$UNIDADES/$NOME.path" "$UNIDADES/$NOME.service" "$DESTINO"
    systemctl --user daemon-reload
    echo "Reaplicação automática desligada. Os overrides já aplicados continuam."
}

case "${1:-}" in
    --instalar) aplicar; instalar ;;
    --remover) remover ;;
    "") aplicar ;;
    *) echo "uso: $0 [--instalar|--remover]" >&2; exit 2 ;;
esac
```

## Por app

Gradia, BoxBuddy, Warehouse e Upscaler são o mesmo script, trocando o id (`be.alexandervanhee.gradia`,
`io.github.dvlv.boxbuddyrs`, `io.github.flattool.Warehouse`, `io.gitlab.theevilskeleton.Upscaler`):

```bash
#!/usr/bin/env bash
# Gradia (be.alexandervanhee.gradia): desfaz, só para este app, o tema global dos Flatpaks que quebra o libadwaita.
# Também tira xdg-data/icons: o Flatpak já monta os ícones em /run/host/user-share/icons, e em dobro
# o GTK 4.20 entra em recursão infinita (Warehouse dava segfault ao abrir).
# GTK_THEME=adw-gtk3-dark desliga o estilo do libadwaita; o gtk.css do COSMIC deixa o fundo branco.
# Idempotente: o override grava sempre o mesmo valor.
set -euo pipefail
flatpak override --user --unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0 --nofilesystem=xdg-data/icons be.alexandervanhee.gradia
echo "Gradia corrigido. Feche e abra o app de novo."
```

O Clapper soma o runtime da P128:

```bash
#!/usr/bin/env bash
# Clapper (com.github.rafostar.Clapper): duas correções no COSMIC.
# 1. Runtime GNOME 47 (GTK 4.16) dá segfault ao abrir no Wayland do COSMIC: força o runtime 49
#    no .desktop e no serviço D-Bus (o .desktop é DBusActivatable, o lançador usa o serviço).
# 2. Desfaz, só para este app, o tema global dos Flatpaks que quebra o libadwaita.
# Idempotente.
set -euo pipefail
ID=com.github.rafostar.Clapper
RT=49
EXPORT=$(flatpak info --show-location $ID)/export/share
DESKTOP=$HOME/.local/share/applications/$ID.desktop
SERVICO=$HOME/.local/share/dbus-1/services/$ID.service

flatpak info org.gnome.Platform//$RT >/dev/null 2>&1 || flatpak install --user -y flathub org.gnome.Platform//$RT

mkdir -p "$(dirname "$DESKTOP")" "$(dirname "$SERVICO")"
[[ -f "$DESKTOP" ]] || cp "$EXPORT/applications/$ID.desktop" "$DESKTOP"
grep -q -- "--runtime=org.gnome.Platform//$RT " "$DESKTOP" ||
    sed -i "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$RT |" "$DESKTOP"
update-desktop-database "$(dirname "$DESKTOP")" 2>/dev/null || true

NOVO=$(printf '# corrigir-flatpaks-libadwaita\n'; sed "s|flatpak run |flatpak run --runtime=org.gnome.Platform//$RT |" "$EXPORT/dbus-1/services/$ID.service")
if [[ ! -f "$SERVICO" ]] || [[ "$(cat "$SERVICO")" != "$NOVO" ]]; then
    printf '%s\n' "$NOVO" >"$SERVICO"
    busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus ReloadConfig >/dev/null
fi

flatpak override --user --unset-env=GTK_THEME --nofilesystem=xdg-config/gtk-4.0 --nofilesystem=xdg-data/icons $ID
echo "Clapper corrigido. Feche e abra o app de novo."
```
