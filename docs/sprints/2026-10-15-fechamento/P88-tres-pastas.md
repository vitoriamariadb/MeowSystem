# P88 — O formato de pack com três pastas de ícone

**Branch:** `sprint/p88` (depois da leva H integrada; ANTES da P87) · **Decisão 14.**
**Pedido (15/10):** «Vamos unificar tudo lá, incluindo até as pastas, no máximo três: uma pra programas
definidos, pra linkar o SVG com o app; uma pra sistema; e outra pra biblioteca universal. Queria isso pro
formato dos packs meu e do MeowSystem e pros futuros.» Escolha: uma biblioteca por pack.

## O formato
```
packs/<id>/icones/
  apps/        desenho ligado a um programa (o apps.map aponta só para cá)
  sistema/     pastas, mimetypes, status, simbólicos (o tema monta a partir daqui)
  biblioteca/  todo o resto, para escolher no seletor (subpastas livres só como etiqueta, opcional)
  apps.map     a ligação programa → desenho
```
Flavor (claro/escuro, alucard/dracula, latte…mocha) vira sufixo ou subpasta DENTRO dessas três, nunca
uma quarta pasta. PNG feito à mão, recuperado, autoral, versão antiga: tudo é `biblioteca/` (ou `apps/`
se estiver ligado). O que diferencia origem é o `PROCEDENCIA.md`, não a pasta.

## Tarefas
1. **Pack-base `meowsystem`**: `assets/icones/` (traço Arcticons, resgatados, convertidos, retoques,
   autorais do motor) migra para `packs/meowsystem/` no formato novo; todo pack herda dele. Os mapas do
   motor (`*.map` em `assets/icones/`) viram o `apps.map` do pack-base. `assets/icones/` fica só com o
   que é ferramenta (gerador, molde), se sobrar algo.
2. **Migrar Dracula e Catppuccin**: `apps/`, `biblioteca/`, `feitos-a-mao/`, `pastas/`, `autorais/`,
   `mimetypes/`, e o que a leva H trouxer (vetores da P84) → as três pastas, por `git mv` (histórico
   preservado), sem perder um byte: conta por sha256 antes = depois.
3. **Motor lê o formato novo**: `scripts/pack.py` (resolvedor, `validar`, `info`, acervo da ficha),
   `lib/icones.sh`, os scripts de montagem do tema, o seletor (`app/servidor.py`, `app/pagina/app.js`:
   grupos = pack × apps/biblioteca; `sistema/` não é ícone de programa), o doctor, o exportar.
4. **Compatível para trás**: `.meowpack` antigo importado é convertido para o formato novo no
   `importar` (com a regra de pack da P78); o validador recusa quarta pasta em pack novo.
5. **Futuros**: `meow pack novo` cria as três pastas; `docs/PACKS.md` e `docs/FRONTEIRA.md` reescritos
   (a fronteira de 21/09 está revogada); exemplo mínimo de pack em `docs/`.

## Prova
- sha256 de todo ícone antes da migração == depois (nenhum perdido, nenhum duplicado por acidente).
- `pack.py validar` verde nos três packs; pack com quarta pasta → recusado; `.meowpack` antigo → importado
  e convertido.
- tema montado numa casa temporária igual ao de antes (mesmos nomes, mesmos bytes) — diff vazio.
- seletor no navegador (HOME temporário): pastas por pack, contagens batem com o disco.
- `tests/todos.sh` inteiro verde 2x.

## 6. Alterou o desenho, o resto se atualiza sozinho (decisão 15)
**Pedido (15/10):** «SVG alterado numa das três, qualquer outro arquivo, seja PNG ou afins, se auto atualiza».
- **Vigia**: unidade `.path` de usuário sobre `packs/*/icones/{apps,sistema,biblioteca}` e `apps.map` do
  pack no ar e dos packs herdados (o padrão do vigia de `assets/gatos/` que já existe), com espera curta
  (debounce) para uma rajada de salvamentos virar uma passada só.
- **Uma função, idempotente**: para cada arquivo cujo sha256 mudou desde a última passada (estado em
  `~/.local/state/meowsystem/derivados.tsv`), refaz SÓ os derivados dele: cópia/ligação no tema instalado,
  PNG por tamanho (rsvg-convert, se o tema usa raster), simbólico gerado, ícone do lançador (logo do pack),
  `gtk-update-icon-cache`; o seletor relê na próxima abertura (cache invalidado pelo sha256). Arquivo
  apagado → derivado sai. Um `meow_tela_reler` só no fim (P80).
- **Sem comando, sem frase**: nada de «rode meow icones reconstruir»; o doctor das 5h confere a mesma
  tabela e refaz o que o vigia perdeu (PC desligado na hora da edição).
- **Prova**: teste que edita um SVG numa casa temporária e confere, em até N segundos, o novo sha256 no
  tema instalado, o PNG re-renderizado e o cache novo; editar 2x o mesmo conteúdo → nada escreve; apagar
  → derivado some; rajada de 20 edições → uma passada.

## 7. Dois avisos da varredura de 15/10 (decisão 16)
- Os 19 desenhos com cor Dracula fixa que estão em `assets/icones/` vão para `packs/dracula`, NÃO para
  o pack-base `meowsystem` (senão o Catppuccin herda desenho Dracula). O pack-base fica com o neutro: traço
  Arcticons, convertidos, moldes.
- Precedência: desenho do pack vence o traço Arcticons em todo tamanho (hoje os 47 de 48 px encobrem 17
  desenhos do pack a 48 px), salvo escolha de traço de quem usa. Teste: o mesmo nome em `apps/` do pack e
  no traço → o tema montado tem o do pack em 48 px e em scalable.

## Alerta de segurança (16/10, revisão automática do 11c5c5b): `scripts/icones_resgatados.sh`
O mapa e a pasta dos resgatados passaram a vir do PACK (que pode ser importado), e o primeiro campo
de cada linha (`nome`) entra cru em `$ALVO/$nome.svg` e `$ACERVO/$nome.svg`: um `../../x` escreve ou
lê fora do tema. Obrigatório para o conferente: passar todo leitor de mapa que a P88 tocou pela regra
única da P78 (nome de conjunto fechado, `realpath` dentro da raiz do pack, symlink para fora
recusado, linha ruim pulada e contada) — e grep dos outros scripts que a P88 religou ao pack
(`icones_*.sh`, `construir_*.sh`, `lib/icones.sh`) atrás do mesmo padrão. Teste: pack importado com
`../../../../tmp/x : y` no mapa dos resgatados → nada fora do tema.
