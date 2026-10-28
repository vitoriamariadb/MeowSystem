# Conferência do bloco Flatpak (P127, P128, P129)

Conferi a branch `bloco/flatpak` contra a `integracao/central-e-gerador` com a diferença de três
pontos (`integracao/central-e-gerador...bloco/flatpak`). Usei essa diferença porque a integração
andou depois que o bloco nasceu. Rodei toda prova num HOME de brinquedo, e o navegador só headless.

## O que já estava certo

- Agora a cura nasce no lugar certo. O `_ft_override_usuario` só grava `ICON_THEME` e
  `XCURSOR_THEME`, e mais ninguém no repositório escreve `GTK_THEME`. O `xdg-data/icons` saiu, e o
  `xdg-config/gtk-4.0` também.
- O `meow pack usar` chama o `install.sh`. Ele roda a `etapa_flatpak_tema` (`flatpak_tema.sh
  aplicar`) e a `etapa_apps` (`aplicar_apps.sh aplicar`), nessa ordem.
- O doctor tem os pares `chk_`/`fix_` de `flatpakadwaita`, `flatpakicones` e `flatpakruntime`.
  O `fix_` do global vai pela ponte (`flatpak-global-limpar`).
- Os módulos de Krita, OBS e Waterfox guardam o que é dela:
  - o resto do `kritarc`, do `user.ini` e do `user.js` fica;
  - quando ela escolheu um tema à mão, o módulo responde 3 e não troca nada;
  - o reverter tira só o que o MeowSystem pôs.
- O `gtk.css` de um app libadwaita nunca é sobrescrito quando é dela.

## Achados e correções

| # | achado | correção | commit | prova |
|---|---|---|---|---|
| A | O override à parte que o bloco tira (o contorno antigo) era reconhecido só no formato que a prova inventou. O `flatpak override --unset-env=GTK_THEME` de verdade (1.18.1) grava duas linhas: `unset-environment=GTK_THEME;` no `[Context]` e `GTK_THEME=` no `[Environment]`. Com o arquivo real, o contorno ficava e o conferir não fechava. | O `_ft_eh_contorno` também conta a linha `unset-environment` do `[Context]`. | `5eedb592` | `tests/flatpak-tema.sh`: a fixture agora é o formato real, e uma checagem compara com o que o `/usr/bin/flatpak` grava num diretório de brinquedo. Sem a correção são 2 falhas; com ela, tudo verde. |
| B | O Flatseal (GJS) usa libadwaita, mas ficava de fora da lista. O JavaScript dele mora num `.gresource` comprimido (`pkg.require({ Adw: '1' })`), e o `grep` não acha nada ali. Pela máquina dela, eram 3 apps achados quando deviam ser 4. | Quando o `grep` falha, o `meow_flatpak_usa_libadwaita` extrai os recursos `.js`, `.ui`, `.py` e `.blp` com o `gresource`, e o padrão ficou mais largo. A chave do cache ganhou o sufixo `/recursos`, então o veredito antigo («nao») é refeito uma vez. O CI instala o `libglib2.0-bin` e o `libglib2.0-dev-bin`. | `32afcc7c` | `tests/flatpak-tema.sh` seção 15: um app com gresource comprimido feito pelo `glib-compile-resources` é achado, e o app GTK3 fica de fora. Sem a correção, falha. Na máquina dela, com o cache no scratch, os 4 são achados: Gradia, Flatseal, Upscaler e Calculadora. Na primeira passada foram 7 s; com o cache, 0,8 s. |
| C | O runtime do app era lido do rótulo `Runtime:` do `flatpak info`, e esse rótulo muda com a língua (`Laufzeitumgebung:` em alemão). Fora do inglês e do português, o app em runtime antigo passava despercebido. | O `meow_flatpak_runtime_gnome` usa `flatpak info --show-runtime`, que não é traduzido. | `22a09307` | O flatpak falso do teste agora imprime o rótulo em alemão e atende `--show-runtime`. Sem a correção são 7 falhas; com ela, tudo verde. Na máquina dela, com `LANGUAGE=de`: Calculadora 51, Flatseal 50. |
| D | O painel mostrava «Libadwaita» na lista Recebem o tema, um nome técnico. | Pus `libadwaita: "Apps GNOME"` no `NOME_DE_PROGRAMA`. | `7262c2a9` | A foto headless de `#ajustes/programas` (HOME de brinquedo) mostra «Apps GNOME» e «Waterfox» na lista. |
| E | Faltava uma prova de ponta a ponta para a troca de pack: os dois scripts de verdade em sequência, começando de um override com `GTK_THEME`. | Só prova nova. | `b19cd9a5` | `tests/temas-por-app.sh`: na sequência meowsystem → dracula → meowsystem pelo `flatpak_tema.sh aplicar tudo` e pelo `aplicar_apps.sh`, o `gtk.css` troca de cor nas duas idas, o `GTK_THEME`, o `gtk-4.0`, o `xdg-data/icons` e o `/usr/share/themes` saem, e o `gtk-3.0:ro` fica. Sem o `flatpak_tema.sh`, a prova fica vermelha. |

## HOME real

O bloco não tocou o HOME real.

- **`~/.local/share/flatpak/overrides/global`**: o md5 antes e depois do conferir é o mesmo, e o
  arquivo é das 10:06. Os overrides do BleachBit e do qBittorrent são dela, das 13:10 e das 15:51.
- **Outras pastas**:
  - `~/.local/share/applications` não tem arquivo com a marca `corrigir-flatpaks-libadwaita`;
  - `~/.local/share/dbus-1/services` não existe;
  - `~/.var/app` não foi tocado.
- **Cache**: o único arquivo novo é `~/.cache/meowsystem/flatpak-libadwaita.tsv` (21:06), um cache
  derivado que o implementador criou. Como a chave nova tem o sufixo `/recursos`, o primeiro doctor
  refaz o veredito e o Flatseal entra.

O conferir só de leitura na máquina dela dá:

- `usuario` 0;
- `libadwaita` 1 (o global dela tem `GTK_THEME=adw-gtk3-dark`, `gtk-4.0:ro` e `/usr/share/themes:ro`);
- `icones` 1;
- `runtime` 0;
- `global` 0.

Ou seja, o conserto no override dela fica para o fecho, como manda a regra de não tocar o HOME real.

## Fica de nota

- O Ghostwriter e os pendentes do implementador continuam abertos (estão na lista do fim do bloco).
- As chaves do Krita, do OBS e do Waterfox foram medidas na documentação, não num app aberto.
