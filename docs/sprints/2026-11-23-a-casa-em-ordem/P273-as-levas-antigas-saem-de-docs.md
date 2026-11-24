# P273 — as levas antigas e a maquete saem de `docs/` (23/11/2026)

## O que se mediu (catálogo de 23/11)
- `docs/sprints/` tem sete levas, 416 arquivos e cerca de 2280 KB. A decisão 24 e o `AGENTS.md:65` dizem que só a
  leva em curso fica no tronco.
- `2026-10-26-qa-final/maquete/`: 210 arquivos (206 SVG), 782 KB, sem nenhum leitor.
- Leitores de `docs/sprints/` no código: `tests/glossario.sh:5` (lê a leva de 10/11), `tests/decisoes.sh:406` (varre
  `docs/sprints/*/*.md`), `scripts/deb.sh:6`, `tests/deb.sh:71`, `tests/frases-velhas.sh:17` e
  `tests/portabilidade.sh:27` (exclusões).
- As referências a `assets/` dentro de `docs/sprints/` são 117 das 470 do repositório.

## A causa
Cada leva fechou sem tirar a anterior, e um teste passou a ler o glossário de dentro de uma delas.

## A cura na origem
1. O que as levas antigas deixaram em aberto fica escrito no `00-leva.md` desta (seção das herdadas).
2. O `GLOSSARIO.md` da leva de 10/11 vai para onde o `tests/glossario.sh` e o painel o leiam sem depender de leva
   (junto do `app/LEIA-ME.md`).
3. Saem as levas de 26/10, 27/10, 10/11, 16/11, 17/11, 18/11 e 19/11. Fica só esta.
4. O `tests/decisoes.sh:406` passa a valer para a leva que existir.

## Como se prova
- `tests/glossario.sh`, `tests/decisoes.sh`, `tests/deb.sh`, `tests/frases-velhas.sh` e `tests/portabilidade.sh`
  verdes.
- `ls docs/sprints` com uma pasta só.

## Ressalva
Com o histórico reescrito (P284), as levas antigas deixam de existir no GitHub. Elas ficam na cópia de segurança que
a P284 faz antes.

## Feito (23/11, bloco `barato-de-ler`)
- `docs/sprints/` tem uma pasta só. O glossário mora em `app/GLOSSARIO.md` e o leitor de textos do teste em
  `tests/auxiliares/textos_da_tela.py`; só o `tests/glossario.sh` os lê, e ele fica vermelho com um termo quebrado
  de propósito.
- Dois testes de navegador abriam a maquete apagada quando chamados com `--fotos`; passaram a não abrir.
