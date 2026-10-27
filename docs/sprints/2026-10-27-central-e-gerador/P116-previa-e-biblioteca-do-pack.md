# P116: a prévia e a Biblioteca mostram os ícones do pack

Itens 1 e 2 do `ANDAMENTO.md` (fotos 1 e 2). Relatório: `relatorios/levantamento-painel.md` §1 e §4.

## O que se mediu
Playwright headless numa casa de teste (`tests/app-completo.py`, HOME temporário), em 1920 px.
- **Tema** (`capturas/painel/tema-1920.png`).
  - Nos dois cartões, `dracula` e `meowsystem`, os seis SVG do dock da prévia têm os mesmos tamanhos de `innerHTML`: 223, 582, 251, 437, 209 e 172.
  - A pasta da janela de arquivos tem o mesmo hash nos dois.
  - Só o mascote muda.
- **Personalizar → Ícones → Biblioteca** (`capturas/painel/biblioteca-1920.png` e `biblioteca-um-icone.png`).
  - São 36 ícones, e todos vão como `<img src="/previa?tipo=arquivo&id=…packs/meowsystem/icones/biblioteca/…">`.
  - Na captura de um ícone, a luminância fica entre 2 e 31, com média 28, num cartão de fundo `rgb(30, 30, 46)`, cuja luminância é cerca de 32. O traço é praticamente da cor do fundo.

## Causa
- **Prévia:** `app/pagina/mesa.js:MESA`. `ICONES` (files, firefox, telegram, discord, spotify, terminal) e `PASTA` estão fixos no código, em contornos do Arcticons. O `cartaoDePack()` (`paginas.js:94`) e o `paginaCriar()` (`paginas.js:677`) desenham a mesma mesa para todo pack, e o `_cartoes_de_pack()` do servidor (`app/servidor.py`, perto da linha 620) não manda ícone nenhum.
- **Biblioteca:** `scripts/pack.py:acervo_para_levar()`.
  - Os itens da Biblioteca saem com `svg=None`, e o `_api_criar_ler()` os serve crus como `<img>`.
  - Os SVG da biblioteca têm `stroke="currentColor"`, e dentro de `<img>` o `currentColor` é preto.
  - Só o «Sistema» passa pela pintura com as cores do pack (`pastas_do_pack(dir_pack, cores)`).

## Cura na origem
1. `scripts/pack.py`: uma função `previa_do_pack(ident, flavor)`.
   - Ela resolve, pelo mapa de apps do próprio pack (com a herança), os seis nomes do dock e a `folder` das pastas.
   - Devolve o SVG de cada um já pintado com a paleta do flavor, pelo mesmo caminho do `acervo_para_levar(..., "apps"|"sistema", cores)`.
   - Ícone que o pack não traz fica de fora; ele nunca vem do outro pack (decisão 3).
2. `app/servidor.py:_cartoes_de_pack()` manda `previa: {dock: [...], pasta: ...}`, como `data:` URL. O `paginaCriar` pede o mesmo para o pack em edição.
3. `app/pagina/mesa.js` desenha `<img>` com esses SVG. Sem eles, fica o traço neutro de hoje: um risco cinza, nunca um ícone de outro pack.
4. `acervo_para_levar()`, ramo da biblioteca: entrega `svg` com o `currentColor` trocado pelo `text` do flavor, como o Sistema já faz. Assim o `_api_criar_ler()` serve `data:` em vez do arquivo cru.

## Prova
- `tests/app-completo.py --aba tema` (Playwright headless):
  - os `src` do dock do cartão `dracula` diferem dos do `meowsystem` em pelo menos 5 dos 6;
  - a pasta do Dracula é cheia e a do MeowSystem é contorno.
- `tests/app-completo.py --aba criar/icones`, aba Biblioteca:
  - captura de cada `img` com contraste ≥ 3 entre o pixel mais claro e o fundo do cartão;
  - `src` começa com `data:image/svg+xml`.
- `tests/pack.sh`, caso novo: `previa_do_pack("dracula", "dracula")` não devolve caminho nenhum dentro de `packs/meowsystem/`.

## Arquivos
`scripts/pack.py`, `app/servidor.py`, `app/pagina/mesa.js`, `app/pagina/paginas.js`,
`tests/app-completo.py`, `tests/pack.sh`.

## Fora desta sprint
- A aba «Do acervo» da ficha (oficina) também mostra glifos crus. Ela já pinta a lupa; os cartões entram junto só se o caminho for o mesmo `acervo_para_levar`. Senão, vai para depois.
- Ícones da bandeja e do sistema do Dracula: P117.
