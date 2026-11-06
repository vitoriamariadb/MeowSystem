# P166 — o tema e o ícone vão para o Firefox (06/11/2026)

Pedido de quem usa em 06/11/2026: o Waterfox saiu e o Firefox do apt do Pop entrou; «o ícone no MeowSystem, movemos pro Firefox também».

## Alcance

Produto: vale para todo PC com o Firefox do apt (`~/.mozilla/firefox`) ou do Flatpak (`org.mozilla.firefox`). O pack ativo é o `dracula`, mas
o módulo de tema vive no motor e o pack `meowsystem` declara a mesma chave.

## O que se mediu

- 06/11: o `firefox` 159 do apt tem `/usr/share/applications/firefox.desktop` com `Icon=firefox` e `StartupWMClass=firefox`; os perfis
  moram em `~/.mozilla/firefox`. Não há mais `net.waterfox.waterfox` na máquina.
- O `apps.map` do Dracula só nomeava `net.waterfox.waterfox : apps/firefox.svg`; o `Icon=firefox` não tinha fonte no pack e caía no traço
  do `apps-arcticons.map` (`firefox:firefox:peach`), em `48x48/apps/firefox.svg`.
- O módulo `scripts/temas-de-apps/waterfox/` procura perfis em `~/.waterfox`; num PC só com Firefox ele diz «não está instalado», e o
  `APPS_ATIVOS` já traz `firefox` e não `waterfox`, então o módulo nem rodaria.
- O modelo CSS (`waterfox.modelo.css`) não tem seletor específico do Waterfox: só variáveis CSS em `:root`, as mesmas do chrome do Firefox. Não
  precisou de adaptação para o Firefox 159.

## A cura

1. Ícone: a linha `net.waterfox.waterfox` do `packs/dracula/icones/apps.map` vira `firefox` e `org.mozilla.firefox`, com o mesmo desenho
   `apps/firefox.svg`. Como o pack vence o traço também a 48 px (`_ceder_ao_pack`), o `48x48/apps/firefox.svg` antigo sai na próxima
   passada e o `scalable/apps/firefox.svg` resolve o `Icon=firefox`.
2. Tema: `scripts/temas-de-apps/waterfox/` vira `firefox/` (`git mv`), `_WF_` vira `_FF_`, raízes de perfil `~/.mozilla/firefox` e
   `~/.var/app/org.mozilla.firefox/.mozilla/firefox`, detecção por `meow_tem firefox`, flatpak ou perfil. A chave `waterfox` dos
   `pack.json` vira `firefox`.
3. Testes e documentos vivos trocam o nome; sprints antigas e relatórios ficam como história.

## Como se prova

1. `pack.py fonte firefox dracula` e `fonte org.mozilla.firefox dracula` devolvem `apps/firefox.svg`; o nome `net.waterfox.waterfox` não tem mais fonte.
2. Com o traço do Firefox já gravado em `48x48/apps`, a passada do arcticons com o Dracula no ar o remove (o pack cede), e o `scalable/apps/firefox.svg` fica.
3. `tests/temas-por-app.sh` e `tests/apps-frases.sh` aplicam e revertem o tema num perfil de `~/.mozilla/firefox` em HOME temporário.
4. `tests/todos.sh` verde; `grep -rIn -i waterfox` só acha história.
