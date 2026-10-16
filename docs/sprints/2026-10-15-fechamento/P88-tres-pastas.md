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
