# P130 — A porta Modificações: o que o MeowSystem muda em cada programa

**Decidida em 27/10.** Depende da P129 (o tema por app é o conteúdo principal dos cartões).

**Pedido de quem usa (27/10):** «Tenho pensado numa guia nova chamada modificações que dentro dela teremos
modificações específicas pra cada programa. tipo spotify, discord, telegram, e afins que já temos, até
terminal e as correções pra esses outros problemas em específicos.» E depois: «ele fica ao lado da aba
extensões e será chamada de Modificações».

## Decisões de quem usa (27/10)
- **Lugar:** uma porta nova no topo, ao lado da Extensões: Tema · Personalizar · Definir · Manter ·
  Extensões · **Modificações**.
- **A Programas continua** onde está (Definir → Programas). A Modificações não a substitui.
- **Tudo o que é tema de programa fica só na Modificações** (quem usa: «vamos centralizar isso na
  modificações»). Sai da Programas o bloco «Recebem o tema» (`APPS_ATIVOS`, «Aplicar agora», «Conferir»,
  `app/pagina/lugares.js:233-237`) e a «Loja do Spotify» (`SPOTIFY_MARKETPLACE`, `:241`), que vai para o
  cartão do Spotify. A Programas fica com o Lançador (arrumar e escondidos) e os Jogos.
- **O Terminal vira cartão** da Modificações e sai do Definir.
- **Um tema do pack para cada app** (P129), e o `GTK_THEME` global sai (P127).
- Não perguntado, segue como recomendação: mostrar só os apps instalados.

## O que existe hoje (medido em 27/10 na `integracao/central-e-gerador`, commit `50f259de`)
- `app/pagina/lugares.js:3-9`: as cinco portas (`PORTAS`). A Extensões (`id: "extensoes"`) tem as abas
  Applets e Builds (`app/pagina/app.js:1233`, `app/pagina/extensoes.js`), pela P114 e pela P120.
- `app/pagina/lugares.js:218` e `:231`: Terminal e Programas são abas da porta Definir (`AJUSTES`).
- Itens por programa que já existem e viram cartões: os módulos de `scripts/temas-de-apps/` (btop-bat,
  discord, gnome-terminal, heroic, kitty, obsidian, onlyoffice, qbittorrent, spotify, telegram, vscode,
  zapzap), o tema do Spotify que mora no pack (P113) e o Vencord no Discord oficial (P126).
- As correções de Flatpak da P127 e da P128 não têm lugar no painel.
- As portas foram desenhadas por maquete (`docs/sprints/2026-10-26-qa-final/maquete/b/extensoes.html`).

## A ideia
Cada programa instalado é um cartão, e cada cartão junta tudo o que o MeowSystem faz nele:
- **Tema:** o módulo de `scripts/temas-de-apps/<app>/`, ou o tema por app da P129.
- **Correções:** o que faz o programa funcionar no COSMIC, como o runtime da P128 (Clapper) e o Vencord
  da P126 (Discord).
- **Estado:** aplicado, fora do lugar ou desligado, pelo mesmo `chk_` do doctor, e um interruptor por item.

## A cura
- Maquete primeiro, no padrão das outras portas (`maquete/b/`), com a skill `design-humano` (que usa a `hallmark`). A maquete mora em
  `docs/sprints/2026-10-27-central-e-gerador/maquete/modificacoes.html`.
- Um manifesto por programa juntando tema e correções, com `chk_`/`fix_` de cada item; a fonte de verdade
  continua no `meow.conf`.
- A porta nova e cada controle entram no inventário de `tests/app-completo.py` no mesmo commit.
- O Terminal sai do `AJUSTES` e vira cartão, com a tela de hoje inteira como detalhe.
- O bloco «Recebem o tema» e a «Loja do Spotify» saem da Programas no mesmo commit em que os cartões
  ganham o interruptor de tema; a chave `APPS_ATIVOS` do `meow.conf` continua sendo a fonte de verdade,
  agora lida e escrita pelos cartões. Nenhum controle fica em dois lugares.

## Como se prova
- `tests/app-completo.py` passa pela porta nova, cartão por cartão e interruptor por interruptor.
- Desligar uma modificação desfaz o que ela escreveu; ligar de novo não escreve nada na segunda vez.
- `tests/todos.sh` verde duas vezes.
