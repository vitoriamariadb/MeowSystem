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

## Execução

Bloco `apps`, branch `bloco/apps-p140`, 29/10/2026.

- **Item.** `scripts/temas-de-apps/discord/manifesto.sh`. O módulo acha o `~/.config/discord/app-<versão>` mais novo
  e confere se tem o Vencord (`resources/_app.asar` guardado e o `app.asar` que carrega o `patcher.js`). Sem ele, com o
  Discord fechado, injeta com o `VencordInstallerCli-linux -install -location <app>`, na versão fixada **v1.4.2**
  (sha256 `52642c85…c815d`, medido contra o release do GitHub em 29/10), baixado uma vez para
  `~/.local/share/meowsystem/vencord/v1.4.2/` e conferido a cada uso. O sha que não bate é erro e nada é injetado. Com o
  Discord aberto a passada sai pendente (o Vencord entra na seguinte). A pasta `themes/` do Vencord entra na lista
  mesmo sem outro cliente; o tema e o `enabledThemes` seguem o caminho que já existia.
- **Reverter** devolve o `_app.asar` ao lugar de `app.asar` em cada `app-*`, direto no disco (sem instalador, sem rede),
  tira o tema e desliga `discord` do `APPS_ATIVOS` (P141).
- **Chave e gatilho.** `DISCORD_VENCORD="sim"` no `meow.conf` (par `chave-etapa.tsv`, linha do painel «Vencord no Discord»,
  texto em `meow.conf.exemplo`): `nao` não injeta e tira o vigia. O gatilho é o par `systemd/meow-discord.path` /
  `.service`, instalado por `scripts/vigia_discord.sh` (etapa `etapa_vigia_discord`, conferência e conserto `discordvigia`
  no doctor, e a lista de `lib/desinstalar.sh`). Vigia `installer.db` e `build_info.json` de `~/.config/discord/`, não a
  pasta inteira: o Discord reescreve `Cookies-journal` o tempo todo e a pasta disparava sem parar. O serviço só roda
  com `DISCORD_VENCORD=sim` e `discord` no `APPS_ATIVOS`, e aplica só o Discord. A nota do pack Dracula
  deixou de dizer «flatpak oficial».
- **Commits.** `feat(discord): o meow injeta o Vencord no app novo do Discord oficial e o vigia repõe depois da atualização`
  (módulo, teste, chave, vigia, nota do Dracula).
- **Prova.** `tests/discord-vencord.sh` (15 provas, no `todos.sh`), num HOME de brinquedo com `app-1.0.1/resources/app.asar`
  falso, instalador falso e `curl` falso (sem rede): a primeira passada injeta e guarda o original; a segunda não escreve
  nem chama o instalador, e o download aconteceu uma vez; `app-1.0.2` novo é acusado e injetado sem baixar de novo;
  Discord aberto não injeta; `DISCORD_VENCORD=nao` não injeta; sha errado é erro; reverter devolve o `app.asar` original
  byte a byte, tira o tema e desliga o app do `APPS_ATIVOS`, e a segunda passada não escreve.
- **Ficou de fora.** O Discord real dela não foi tocado: o `app-1.0.166` já tem o Vencord (injeção à mão do coordenador),
  e o `.path` só passa a valer depois do próximo `install.sh` com o HOME real, que este bloco não roda. Atualização com o
  Discord reaberto sozinho antes do serviço rodar deixa o Vencord para o doctor das 05:00 ou para a próxima mudança do
  `installer.db`; um vigia do processo ficou de fora para não crescer o escopo.
