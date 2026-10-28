# P134 — a Modificações padronizada, com tema adicionado, e garantida no install

Anotada em 28/10 (ela: «nossa guia modificações tem que tá no install também, temos que garantir isso»; «olhar se
cada quadradinho tá padronizado e universal, talvez um slide de ligado/desligado e uns 3 pontinhos pra configuração
dele»; «igual no extensões que podemos adicionar repositório, lá também temos que poder adicionar um tema padrão pra
cada aplicativo»). Entra nesta leva, por ordem dela.

## O que se mediu
- A porta Modificações (`app/pagina/modificacoes.js`, 163 linhas) monta um cartão por módulo de
  `scripts/temas-de-apps/<app>/` instalado e pelas linhas de `assets/contratos/modificacoes.tsv` (terminal, flatpak e
  as correções `terminal`, `prompt`, `flatpakadwaita`, `flatpakicones`, `flatpakruntime`). Os cartões não seguem um
  molde só (P130 deixou só o Terminal com página de detalhe).
- O install aplica os temas de app em `etapa_apps` (`scripts/aplicar_apps.sh`) e as correções em etapas soltas
  (`etapa_terminal`, `etapa_prompt`, `etapa_flatpak_tema`). Nada prova que todo cartão da Modificações tem etapa no
  install: um módulo novo pode aparecer na porta e ficar fora do install em silêncio.
- A Extensões tem «Adicionar repositório» (`app/pagina/extensoes.js:283-380`, diálogo `#adicionar`, servidor
  `_repositorio_no_ar`). A Modificações não tem como pôr um tema que não veio do pack.

## Cura na origem
1. **Garantia no install.** Um teste cruza a lista da Modificações (os módulos de `scripts/temas-de-apps/` e as linhas
   do `modificacoes.tsv`) com o que o install roda: todo módulo entra pelo `aplicar_apps.sh` da `etapa_apps`, e toda
   `correcao` do contrato aponta uma etapa existente do `install.sh` (coluna nova no `modificacoes.tsv`, ou a tabela
   `assets/contratos/chave-etapa.tsv` se já servir). Cartão sem etapa acende vermelho. O que faltar no install hoje
   entra.
2. **Um cartão só, universal.** Todo cartão da Modificações tem o mesmo molde: ícone, nome, a situação numa linha
   (o tema no ar, ou «não instalado»), um interruptor ligado/desligado (ligado = o MeowSystem tematiza o app;
   desligado = devolve o que estava antes e não toca mais, gravado no `meow.conf` pela chave que já existe para o app,
   ou uma nova `APPS_ATIVOS`/equivalente se não houver) e um botão «⋮» com as opções do app: escolher o tema,
   «Adicionar tema», «Voltar ao do pack» e, onde existir, a página de detalhe (Terminal). Correções usam o mesmo
   molde, com o interruptor e sem «Adicionar tema». Nenhum texto que explica; a interface mostra.
3. **Adicionar tema.** No «⋮» de cada app e num botão da porta, igual ao «Adicionar repositório» da Extensões
   (o mesmo diálogo em molde, não um diálogo novo de outro jeito): o usuário dá um arquivo ou uma URL do tema daquele
   app, o servidor confere o tipo que o módulo do app aceita, guarda em `~/.local/share/meowsystem/temas-de-apps/<app>/`
   e o grava como o padrão daquele app nesta máquina, acima do tema do pack. «Voltar ao do pack» desfaz. O doctor
   respeita o tema adicionado (não o troca pelo do pack) e o conserto o regrava se sumir. Pack continua só dado: o
   tema adicionado é do usuário, não entra no pack.

## Prova
- O teste do item 1 verde e vermelho quando se apaga a etapa de uma correção (prova pelo teste, não à mão).
- Teste de navegador headless (Playwright, HOME temporário, decisão 8): todos os cartões com o mesmo molde
  (interruptor e «⋮»), desligar um app devolve o de antes, adicionar um tema a um app falso aparece como o padrão e
  «Voltar ao do pack» desfaz.
- `./tests/todos.sh` verde.
