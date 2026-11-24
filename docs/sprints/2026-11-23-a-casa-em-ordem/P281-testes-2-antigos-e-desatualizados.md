# P281 — testes, etapa 2: os mais antigos e desatualizados (23/11/2026)

## O que se mediu (catálogo de 23/11)
Parados, com o alvo mudando depois (última mudança de conteúdo do teste; commits do alvo depois dela):

| teste | parado desde | commits do alvo depois |
| --- | --- | --- |
| `um-cartao-por-jogo.sh` | 24/09 | 6 |
| `escala-kdl.sh` | 09/10 | 5 |
| `volta-do-cosmic.sh` | 09/10 | 30 |
| `reler-uma-vez.sh` | 10/10 | 24 |
| `backoff-do-supervisor.sh` | 15/10 | 17 (o `painel-fantasma.sh` cobre o mesmo supervisor) |
| `cosmic-prever.sh` | 17/10 | 31 |
| `sem-receita-no-log.sh` | 23/10 | 43 |
| `notas-de-funcao.sh` | 23/10 | 17 |
| `reversao.sh` | 23/10 | 17 |
| `escritorio.sh` | 24/10 | 33 |
| `perfil.sh` | 24/10 | 39 |
| `pack-malicioso.sh` | 25/10 | 70 |
| `desenho-no-pack.sh`, `pack-traz-o-que-usa.sh` | 26/10 | 36 e 39 |

Só vigiam migração já concluída: `sem-dracula-os-theme.sh`, `precisa-de-gente.sh` §3-4, `lancador-do-meow.sh:52`,
`arvore.sh:53`, `decisoes.sh:446`, `fonte-unica.sh` («o Waterfox saiu»), `pack-traz-o-que-usa.sh:37` e
`wallpaper-base.sh`.

## A regra desta etapa
Um teste sai quando o que ele guarda não tem mais como voltar (a migração acabou e o caminho antigo não existe) ou
quando outro teste prova a mesma propriedade. Se nenhuma das duas vale, o teste sai e a propriedade entra na lista
«sem prova» deste arquivo, para ganhar prova nova na P283. Nada sai calado.

## A cura
1. Para cada linha das duas listas: ler o teste, dizer em uma frase a propriedade, e marcar «sem volta», «coberto
   por <teste>» ou «sem prova».
2. Apagar, um commit por teste, com o `todos.sh` e o `tests/decisoes.sh` no mesmo commit.
3. `pack-malicioso.sh` e `sem-dracula-os-theme.sh` são exigidos pelo `decisoes.sh` (decisões 41 e 47): só saem com a
   linha da decisão apontando para a prova que fica.

## Como se prova
- `tests/decisoes.sh` verde depois de cada commit.
- A suíte inteira no fim, com o número de testes, o tempo e a lista «sem prova» anotados no `ESTADO.md`.

## O que a leitura mostrou (23/11, pelo coordenador)
Os 14 testes da primeira tabela estão parados porque continuam valendo: cada um chama uma função viva do produto
com uma casa de mentira, todos rodam em menos de um minuto (a soma dos 14 dá 110 s) e nenhum tem outra prova.
- `backoff-do-supervisor.sh` não é coberto pelo `painel-fantasma.sh`: só ele chama `meow_painel_espera_supervisor`.
- `escala-kdl.sh`, `volta-do-cosmic.sh`, `reler-uma-vez.sh`, `cosmic-prever.sh`, `reversao.sh`, `escritorio.sh`,
  `perfil.sh`, `notas-de-funcao.sh`, `desenho-no-pack.sh` e `um-cartao-por-jogo.sh`: única prova da função que chamam.
- `pack-malicioso.sh` e `sem-dracula-os-theme.sh`: exigidos pelas decisões 41 e 47.

As guardas de migração concluída são linhas soltas dentro de testes vivos (`lancador-do-meow.sh:52`, a linha do
Waterfox no `fonte-unica.sh`, a da decisão 24 no `decisoes.sh`). Custam zero segundo e o que guardam pode voltar por
um commit distraído. As duas que eram repetição (`precisa-de-gente.sh` §3 e §4) saíram na P280.

## Veredito
Nesta etapa não sai arquivo nenhum. «Antigo» não quer dizer «desatualizado»: o corte de verdade é o da P282 (a
tabela de cobertura diz o que tem duas provas) e o da P283 (um arquivo por área, escrito do zero). A lista «sem
prova» fica vazia.
