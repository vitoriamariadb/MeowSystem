# P126 — o Discord oficial com o tema do pack, pelo meow

Anotada em 27/10 (pedido dela: o Discord desktop, não o Vesktop, com o tema). Fica para o próximo bloco.

## O que se mediu
- O Discord dela é o `.deb` oficial (`discord 1.0.136`), que se atualiza sozinho para `~/.config/discord/app-<versão>/`
  (hoje `app-1.0.166`). O cliente oficial não carrega tema; o módulo `scripts/temas-de-apps/discord/` só põe o CSS
  na pasta `themes/` de um cliente modificado e, sem ele, fica pendente.
- O coordenador injetou o Vencord à mão em 27/10: `VencordInstallerCli-linux -install -location
  ~/.config/discord/app-1.0.166` (o `resources/app.asar` virou `_app.asar` e um `app.asar` de 208 bytes que carrega
  `~/.config/Vencord/dist/patcher.js`), e rodou `scripts/aplicar_apps.sh aplicar` só para o discord.
- Cada atualização do Discord cria `app-<versão nova>/` sem o Vencord: o tema some até alguém injetar de novo.
- `packs/dracula/pack.json`, nota do bloco `discord`, diz «nesta máquina o Discord é o flatpak oficial»: errado hoje.

## Cura na origem
- O módulo do discord confere se o `app-<versão>` mais novo tem o Vencord e, se não tem, injeta (instalador do
  Vencord numa versão fixada, com sha256, guardado em `~/.local/share/meowsystem/`), com o Discord fechado; o
  pós-atualização vira gatilho do doctor (vigia `.path` em `~/.config/discord/`).
- Chave no `meow.conf` para não injetar (quem não quer cliente modificado). Reverter tira o Vencord.
- A nota do Dracula se corrige no lugar.

## Prova
- Teste num HOME de brinquedo com um `app-1.0.1/resources/app.asar` falso: a primeira passada injeta, a segunda não
  escreve, um `app-1.0.2/` novo é injetado na passada seguinte, reverter devolve o `app.asar` original byte a byte.
