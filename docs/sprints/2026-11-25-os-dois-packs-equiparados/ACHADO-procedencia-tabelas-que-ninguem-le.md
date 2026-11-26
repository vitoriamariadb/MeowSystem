# Achado · as outras tabelas dos PROCEDENCIA.md nunca foram lidas pelo motor (25/11/2026)

## O que se mediu
O leitor antigo do `pack.py` parava no fim da PRIMEIRA tabela com as colunas `arquivo`, `lido de` e `sha256`. Ficaram
fora da leitura, em prosa, as linhas das tabelas seguintes: no `packs/meowsystem/PROCEDENCIA.md`, quatro tabelas de seis
colunas (os papéis de parede de P234, o desligar de P253, os botões de P256, a lateral de P259; 35 linhas no total
contando a que migrou, 50 com as outras de forma parecida); no `packs/dracula/PROCEDENCIA.md`, as tabelas de cinco colunas
(temas de aplicativo, pastas especiais, ícones de arquivo; entre elas 5 linhas da biblioteca, `discord-c.svg`,
`guvcview-2.svg`, `md.obsidian.Obsidian.svg`, `mozc.svg`, `org.telegram.desktop.svg`).
Consequência: o `exportar` não confere a licença dessas linhas, e o `sincronizar` não confere que o arquivo existe.

## Por que o bloco não mexeu
A prova do bloco é a saída idêntica dos verbos antes e depois; ler mais linhas mudaria o resultado. A migração levou
só o que o leitor lia.

## A cura na origem
Decidir, linha a linha, o que é tabela de procedência (vai para o `procedencia.tsv`, e o `sincronizar` e o `exportar`
passam a vê-las) e o que é prosa com tabela (fica). O `tests/pack.sh` já lê as duas fontes para o sha256 e para a
biblioteca; a prova nova seria `exportar` recusar uma linha sem licença em cada uma.
