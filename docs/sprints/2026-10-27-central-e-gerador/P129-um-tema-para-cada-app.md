# P129 — Um tema do pack para cada app

**Aberta em 27/10.** Depende da P127 (override global limpo).

**Pedido de quem usa (27/10):** «lá teremos a possibilidade de criar um tema ajustado pra cada app de acordo
com o nosso themepack», e na decisão da P127: «tira e vamos criar um tema pra cada app».

## O que se mediu
Tudo está em `relatorios/auditoria-tema-por-app.md` (medido no Nitro). Em resumo:
- Nos apps libadwaita, um `gtk.css` próprio do app (`~/.var/app/<id>/config/gtk-4.0/gtk.css`), com as
  variáveis CSS do libadwaita preenchidas pela paleta do pack, funciona: no Clapper o botão saiu exatamente no
  mauve do pack (`#CBA6F7`, medido no pixel). O app que fixa cor própria precisa de um seletor a mais (o
  Clapper fixa o fundo da tela inicial em `.initialstate`).
- Isso só funciona depois que a P127 tira o `xdg-config/gtk-4.0` do override global. Enquanto ele está lá, o
  app lê o `gtk.css` do COSMIC em vez do dele.
- Apps sem tema nenhum hoje, no Nitro: Clapper, Gradia, BoxBuddy, Warehouse e Upscaler (libadwaita), Waterfox
  (`userChrome.css`), Krita e Ghostwriter (esquema `.colors`) e OBS (tema `.obt`). Na máquina dela: Gradia,
  Upscaler, Calculadora e Flatseal (libadwaita), Krita e OBS. O módulo libadwaita acha os apps pela detecção da
  P127, sem lista de nomes.

## A cura, em ordem
1. **libadwaita:** um modelo de CSS gerado da paleta do pack (fundo, texto, cabeçalho, cartão, popover,
   acento, erro, sucesso), escrito na pasta de cada app libadwaita instalado. Ajuste fino por app num
   arquivo ao lado do modelo, só quando o app fixa cor própria. Começa pelos apps libadwaita que a detecção achar; o Clapper ganha o seletor `.initialstate`.
2. **Qt:** medir antes se o `kdeglobals` exposto já leva as cores ao qBittorrent, ZapZap e Ghostwriter.
   Depois, um esquema `.colors` gerado da paleta para Krita e Ghostwriter, e o tema `.obt` do OBS.
3. **Waterfox:** `userChrome.css` no perfil, gerado da paleta.
- Cada app entra como módulo em `scripts/temas-de-apps/<app>/`, no formato dos que já existem, com o par
  `chk_`/`fix_` no doctor. Trocar de pack ou de flavor reescreve; a segunda passada não escreve; o
  desinstalador apaga o que escreveu.
- Os dois packs (meowsystem e dracula) ganham o tema de cada app, como na P107 (histórico do git).

## Como se prova
- Casa de brinquedo: o módulo escreve o CSS com as cores do pack, trocar de pack troca as cores, a segunda
  passada não escreve, desinstalar apaga.
- Na máquina dela: print headless não pega app Flatpak, então o print de cada app fica na lista do que ela confere
  com a mão; o teste mede o CSS escrito. Print de cada app com a cor do acento conferida no pixel, nos dois packs.
- `tests/todos.sh` verde duas vezes.

## Execução

Feito em 27/10, quatro módulos novos em `scripts/temas-de-apps/`, no formato dos que já existiam, mais o motor `lib/tema_arquivo.sh` (marca `meowsystem-tema:` nas cinco primeiras linhas, estado ausente/alheio/igual/diferente, editor de INI para as chaves de seleção).

- **libadwaita:** `~/.var/app/<id>/config/gtk-4.0/gtk.css` para cada app que a detecção da P127 achar (`meow_flatpak_apps_libadwaita`), sem lista de nomes. O modelo `libadwaita.modelo.css` preenche as variáveis do libadwaita (acento, janela, vista, cabeçalho, barra lateral, cartão, popover, erro, sucesso, aviso, sombras); o ajuste fino mora em `libadwaita/ajustes/<app-id>.modelo.css` e é anexado só àquele app (o Clapper ganha `.initialstate`). `gtk.css` sem a marca é dela: não é sobrescrito nem apagado, o módulo avisa (3).
- **Krita:** esquema `MeowSystem.colors` gerado da paleta (forma `{{papel:csv}}` nova no `modelo.py`) em `~/.var/app/org.kde.krita/data/krita/color-schemes/` e em `~/.local/share/krita/color-schemes/` quando há Krita nativo, mais `[theme] Theme=MeowSystem` no `kritarc`. `Theme=` que ela escolheu à mão fica como está (3).
- **OBS:** em vez do `.obt` do texto da sprint, o certo é uma variante `.ovt` que estende o Yami (`obs.modelo.ovt`, id `com.obsproject.Yami.MeowSystem`); `dark` vem do tipo do flavor. Vai em `themes/MeowSystem.ovt` e `user.ini` ganha `[Appearance] Theme=`.
- **Waterfox:** `chrome/userChrome.css` em cada perfil do `profiles.ini` (nativo e Flatpak) e a linha `toolkit.legacyUserProfileCustomizations.stylesheets` no `user.js`, marcada para o reverter tirar só ela. Sem `profiles.ini` o módulo se pula (3).
- **Qt, medido:** o `~/.config/kdeglobals` desta máquina está vazio (só os cabeçalhos das seções), então ele não leva cor nenhuma ao qBittorrent, ZapZap e Krita; o `.colors` próprio é justificado.
- **Ghostwriter: não feito.** Não está instalado aqui e o formato do esquema dele não foi medido; escrever sem medir seria a promessa vazia que o `validar` avisa. Fica anotado como pendência com a medida a fazer no Nitro (`~/.var/app/*/` do Ghostwriter e o arquivo de tema que ele lê).
- Os dois packs (meowsystem e dracula) ganharam `apps.libadwaita|krita|obs|waterfox` (blocos sem `arquivo`: o modelo é do motor). `tests/temas-de-apps.sh` ganhou o teto 0 dos quatro. `libadwaita` e `waterfox` entraram no `APPS_ATIVOS` de fábrica do `meow.conf.exemplo` (`obs` e `krita` já estavam); o `meow.conf` dela não muda sozinho.
- Doctor: o par `chk_apps`/`fix_apps` já roda o `aplicar_apps.sh` sobre o `APPS_ATIVOS`, então os quatro entram nele. O desinstalador chama `aplicar_apps.sh reverter`, que desfaz os quatro (provado no driver numa casa de brinquedo).
- Correção achada no caminho: a leitura do Flatpak (`list`, `info`) criava `~/.local/share/flatpak/repo` numa casa de brinquedo e fazia `seco.sh` e `doctor-so-le.sh` ficarem vermelhos; `meow_flatpak_ler` usa `--system` quando o repositório do usuário não existe.

Provas: `tests/temas-por-app.sh` (novo, no `todos.sh` como portátil), nos dois packs: o conferir acusa antes, o ensaio seco não escreve, o aplicar veste a cor do pack (hex ou rgb do `base`) e nenhuma do outro, a segunda passada não escreve, ida e volta de pack troca a cor, o reverter tira o que pôs e o segundo fica quieto; mais o `gtk.css` alheio intacto, a seleção de tema dela intacta no Krita, `dark` true/false no OBS, o `user.js` preservado no Waterfox e o módulo pulando (3) sem o programa. `tests/temas-de-apps.sh` verde.

Fica para a mão dela: print de cada app com a cor do acento conferida no pixel, nos dois packs (Gradia, Upscaler, Calculadora, Krita, OBS; Clapper e Waterfox no Nitro); as chaves de seleção do Krita (`[theme] Theme`) e do OBS (`[Appearance] Theme`, id da variante) foram escritas pelo que os dois programas documentam e não medidas num app aberto; o perfil do Waterfox Flatpak idem.
