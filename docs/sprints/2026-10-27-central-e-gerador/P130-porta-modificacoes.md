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

## Execução

Bloco `bloco/modificacoes`, 27/10.

### O que mudou
- **A porta.** `PORTAS` ganha a sexta, Modificações, ao lado da Extensões. A página mora em
  `app/pagina/modificacoes.js` e `modificacoes.css`, no desenho da maquete `maquete/modificacoes.html`:
  uma grade de cartões, um por programa, com a pílula do estado, uma linha por item e o «Pôr no lugar»
  quando o item está fora do lugar.
- **De onde vem o cartão.** `meow apps cartoes` junta duas fontes, e o painel não cita programa
  nenhum pelo nome:
  - os módulos de `scripts/temas-de-apps/` (o `tabela` do `aplicar_apps.sh`, mais as pastas que o
    `APPS_ATIVOS` ainda não tem);
  - as correções declaradas em `assets/contratos/modificacoes.tsv` (`cartao  correcao  <alvo>  rótulo`),
    medidas pelo mesmo `chk_<alvo>` do doctor.

  O mesmo TSV dá nome, ícone e dono (`flatpak  modulo  libadwaita`). Módulo novo vira cartão sozinho.
  `tests/modificacoes.sh` prova isso com um módulo de brinquedo e uma correção de brinquedo.
- **O interruptor do tema.**
  - Ligar grava a pasta no `APPS_ATIVOS`, e a etapa `apps` aplica, pelo `chave-etapa.tsv` de sempre.
  - Desligar roda primeiro `meow apps reverter <pasta>`, que desfaz o que o módulo escreveu, e só então
    tira os nomes do `APPS_ATIVOS`.
  - O `meow.conf` continua sendo a fonte de verdade.
- **As correções.** `meow apps corrigir <nome>` roda o `fix_<nome>`. Ele só aceita um nome que o TSV
  declara e que tenha `fix_`. Ficaram declaradas:
  - no cartão Terminal: as cores do terminal e a linha de comando;
  - no cartão Apps Flatpak: libadwaita, ícones em dobro e runtime, da P127 e da P128.
- **O Terminal.** Sai do Definir e vira o cartão Terminal. O «Abrir» leva a `#modificacoes/terminal`, com
  a tela de antes inteira (prévia, cores, linha de comando, fonte).
- **A Programas.** Sai dela o bloco «Recebem o tema» (`APPS_ATIVOS`, «Aplicar agora», «Conferir») e sai a
  «Loja do Spotify», que vai para o cartão do Spotify (`LUGAR_MODIFICACOES.chaves`, só quando o cartão
  existe). Junto saíram a `gradeDeProgramas` e o CSS `.liga-programas`. Nenhum controle ficou em dois
  lugares: `migracao-do-painel.py` dá «0 sem destino».
- **O servidor.**
  - `/api/modificacoes` devolve os cartões.
  - Há três ações ocultas: `modificacao_aplicar`, `modificacao_reverter` e `modificacao_corrigir`, com
    o argumento validado pela lista de módulos e pela de correções.
  - O inventário espelha o `LUGAR_MODIFICACOES`.
- **Contagens fixas que viraram lidas.** `app-acessibilidade.py` contava cinco portas, e agora conta
  as de `PORTAS`. `extensoes-pagina.py` contava sete abas no Definir, e agora conta as de `AJUSTES`.
- **O README** ganha a porta e a captura dos cartões. `scripts/readme.py` espera a página sair do
  esqueleto antes de fotografar. `tests/readme.sh` conta as portas a partir de `PORTAS`, e não mais de um
  cinco fixo.

### Provas
- `tests/modificacoes.sh` (portátil, no `todos.sh`), numa raiz copiada com um módulo de brinquedo:
  - o módulo vira linha do `cartoes`, e a correção declarada entra no cartão dele;
  - aplicar escreve, e a segunda aplicação não reescreve (mtime igual);
  - tirar apaga;
  - `corrigir` recusa nome não declarado e nome com lixo;
  - `modificacoes.js` não cita programa.
- `tests/app-completo.py --aba modificacoes` planta o módulo `brinquedo` na casa de brinquedo e passa
  pelos dois caminhos, `modificacoes` e `modificacoes/terminal`, cartão por cartão e controle por
  controle. No fluxo próprio do brinquedo:
  - ligar aplica e põe o nome no `APPS_ATIVOS`;
  - desligar apaga o arquivo e tira o nome;
  - a aplicação que vem depois não põe o tema de volta;
  - ligar de novo põe o tema de volta;
  - «Aplicar» em todos não reescreve o arquivo (mtime em ns igual), e o cartão diz «Aplicado».

  Resultado: 88 conferências, ok.
- `app-layout.py`: Terminal e Linha colorida mudam a prévia em `modificacoes/terminal`, e as duas rotas
  novas entram na leva de larguras. `app-navegador.py`: 40 conferências, ok.

- `tests/todos.sh`, 1ª passada: 109 testes, 105 verdes, 0 pulados e 4 vermelhos.
  - `decisoes.sh` e `restaurar.sh` são os aceitos:
    - `decisoes.sh`: a GPU (D6) e o «24: cita docs/pesquisas/» do `tests/enxugar.sh`, os dois
      anteriores a este bloco;
    - `restaurar.sh`: o `pack_usar` e o `desinstalar`.
  - `app-acessibilidade.py` e `extensoes-pagina.py` eram as contagens fixas, que já estão curadas.
    Rodados sozinhos, os dois ficam verdes.

### O que ficou diferente do pedido, e por quê
- A correção não tem interruptor: não existe chave no `meow.conf` que a ligue ou desligue. O doctor
  sempre a quer no lugar, então o cartão mostra «No lugar», ou o botão «Pôr no lugar».
- Os cartões das correções do Flatpak, Apps Flatpak e libadwaita, só aparecem depois da integração com
  o `bloco/flatpak`, porque os `chk_flatpak*` e o módulo `libadwaita` moram lá. O contrato já os
  declara e o caminho é o genérico, já provado pelo brinquedo.
- Vencord (P126) e Clapper (P128) não ganharam linha própria. O Vencord já aparece no motivo do cartão
  Discord. O Clapper entra pelo runtime do cartão Apps Flatpak.

### Para a integração
- `git merge-tree` com o `bloco/flatpak` dá conflito em `README.md` e `README.en.md` (os números) e em
  `bin/meow`, no `VERIFICAVEIS`, que é diferença das bases e não código deste bloco. O conserto é
  regerar o README (`scripts/readme.sh`) depois do merge.
- `app-layout.py` falhou duas vezes em três no «↶ mora na célula da coluna», e passou na terceira. A
  causa medida: com o servidor lento, há 45 gravações em fila (`EM_VOO`). Quando uma gravação antiga da
  mesma chave volta, o `enviarLote` apaga a `MUDANCAS` mais nova e a tela volta ao valor velho. A corrida
  é anterior a este bloco e a cura não foi feita aqui.
