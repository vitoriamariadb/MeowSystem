# P283 — testes, etapa 4: um arquivo por área, e os pesados fora (23/11/2026)

Sim de quem usa, 24/11/2026 (AskUserQuestion): «Depois do push». Esta tarefa sai desta leva e abre a seguinte,
sobre a árvore de cinco pastas já publicada.

## O que se mediu (catálogo de 23/11)
Áreas dos 173 testes de hoje (a área de cada um é leitura do agente, pelo nome e pelo que o teste chama):

| área | testes | KB | área | testes | KB |
| --- | --- | --- | --- | --- | --- |
| painel no navegador | 24 | 348 | papel, som e logo | 10 | 83 |
| compositor, patches e builds | 19 | 250 | painel, lado do servidor | 10 | 104 |
| ícones | 18 | 168 | install e etapas | 9 | 47 |
| repositório e decisões | 16 | 155 | extensões | 7 | 67 |
| tema do COSMIC | 14 | 145 | atualiza, deb, espaço | 5 | 92 |
| temas de apps e flatpak | 14 | 243 | sessão (barra, palco) | 5 | 44 |
| packs | 10 | 280 | doctor e conf | 5 | 49 |
| vizinhos e lançador | 4 | 76 | ponte root | 3 | 48 |

- Os mais pesados: `pack.sh` (146 KB, 819 linhas de Python embutido), `temas-de-apps.sh` (97), `app-completo.py`
  (83), `app.sh` (55; 982 de 1121 linhas são Python em heredoc), `vizinhos.sh` (52), `espaco.sh` (50),
  `graficos.sh` (49). O peso é Python e JavaScript dentro de heredoc.
- O `todos.sh` roda em laço, um teste por vez. `convergencia.sh` roda o install três vezes; `seco.sh` e `perfil.sh`
  também rodam o install.
- O `tests/decisoes.sh` procura cada teste pelo nome, no formato `"  nome"` do `todos.sh`.

## A cura
1. Um arquivo de teste por área, escrito do zero contra a árvore final (P279), a partir da tabela de cobertura da
   P282 e da lista «sem prova» da P281. Doze ou dezesseis arquivos: a decidir com a tabela na mão.
2. Um apoio só (`tests/apoio/`): a casa de mentira, os falsos e um jeito único de chamar função do produto, no lugar
   dos 35 recortes com `sed`. O que o `app-completo.py` empresta aos outros vai para lá.
3. Os arquivos antigos saem todos no mesmo commit em que o da área fica verde.
4. O `todos.sh` roda as áreas em paralelo, cada uma com a casa dela.
5. O `tests/decisoes.sh` passa a apontar para o arquivo da área e a asserção dentro dele.
6. O pre-commit e o CI acompanham os nomes novos.

## Como se prova
- Cada arquivo de área nasce vermelho contra um defeito posto à mão em cada propriedade que ele diz provar, e só
  então substitui os antigos.
- Tabela de cobertura da P282 inteira coberta.
- Tempo da suíte medido antes e depois na mesma máquina, sem carga. Meta proposta: a suíte inteira abaixo de 25
  minutos no nitro-5.
- CI portátil verde, com «pulado é vermelho».

## O que esta tarefa fecha das levas antigas
`app-completo.py` instável na aba Tema; `app-completo.py --aba criar/sons` vermelho sozinho; os clones de fonte que
`graficos-fonte-real.sh` e `dock-fonte-real.sh` pedem e nada cria; `seco.sh` dependente de `systemd --user`;
`temas-de-apps.sh` dependente do PID 1; o teste do conta-gotas que não pega o botão pedindo `color-select`.
