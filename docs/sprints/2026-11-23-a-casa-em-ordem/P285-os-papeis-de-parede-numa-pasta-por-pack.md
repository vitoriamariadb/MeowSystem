# P285 — os papéis de parede numa pasta só por pack (23/11/2026)

Pedido de quem usa, 23/11: «a pasta de wallpapers tem que ser unificada por pack».

## O que se mediu (nitro-5, 23/11)
No repositório, os dois packs não têm o mesmo desenho de pasta:

| pack | `wallpapers/` |
| --- | --- |
| `meowsystem` | plano: `papeis.tsv`, `FONTES.tsv`, `BANIDOS.txt.padrao`, `lado.tsv.padrao`, `CREDITOS.md`, `LICENSE`, e uma subpasta `pares/` (6) |
| `dracula` | cinco subpastas: `catedral/` (4), `cemiterio/` (3), `noite/` (3), `ornamento/` (3) e `pares/` (6), mais `papeis.tsv` e `LICENSE` |

- A origem dos papéis do `meowsystem` está inteira no `pack.json` (repositório, commit e a curadoria `FONTES.tsv`).
  A do `dracula` aponta para duas chaves do conf de quem usa: `WALLPAPER_DRACULA_REPO` e `WALLPAPER_DRACULA_COMMIT`.
- No disco, os dois packs dividem uma base só, `~/.local/share/backgrounds/meowsystem/`, com cinco pastas:
  `ativos/` (27 arquivos), `ativos-dia/` (4), `ativos-noite/` (16), `ativos-pack/` (20) e `originais/` (0). O pack de
  cada imagem vai no prefixo do nome (decisões 25 e 63).
- O `.gitignore` ainda traz oito linhas de `packs/meowsystem/wallpapers/{ativos,ativos-dia,…}`, de quando a base
  morava no repositório.

## A causa
Cada leva de papel de parede acrescentou uma pasta (os pares, as cenas do Dracula, os grupos de dia e de noite) sem
uma regra de pasta como a dos ícones (decisão 14).

## A cura na origem
1. No repositório, uma regra só: `packs/<id>/wallpapers/` plana, com as imagens do pack, o `papeis.tsv` (que já diz
   o par, a cena e a autoria) e a receita da origem. As subpastas de cena e `pares/` viram coluna do `papeis.tsv`.
2. A origem dos papéis do Dracula passa para o `pack.json` dele; as duas chaves saem do conf de fábrica, com a
   migração do conf de quem as mudou.
3. No disco, uma pasta por pack dentro da base, no lugar do prefixo no nome; o grupo de dia e o de noite passam a
   ser lidos do `papeis.tsv` e da medida de luz, sem pasta própria. Só a pasta do pack no ar gira; a imagem de quem
   usa, sem pack, tem a pasta dela e gira com qualquer um (decisão 25).
4. O install migra a base antiga uma vez, com cópia de antes; o que quem usa apagou (`BANIDOS.txt`) continua apagado.

## Onde vale
Sim de quem usa, 23/11/2026 (AskUserQuestion): «Nos dois», no repositório e no disco.

## Como se prova
- `tests/tres-pastas.sh` ganha a regra dos papéis: nenhuma subpasta em `packs/*/wallpapers/`.
- `tests/papel-em-par.sh`, `tests/semente-dos-papeis.sh`, `tests/apagar-papel.sh` e `tests/creditos-dos-papeis.sh`
  verdes.
- Casa de mentira com a base antiga: uma passada migra, a segunda não escreve, e o carrossel gira só o pack no ar.
- No nitro-5: trocar de pack e voltar, e o papel apagado antes não volta.

## Nos três PCs
A base de cada PC é migrada no install da P284. No desktop a base pode morar em outro disco (`WALLPAPER_BASE`):
medir antes.

## Feito (24/11, bloco `papeis-por-pack`, integrado em `06c6f9be`)
- Repositório: `packs/*/wallpapers/` plana nos dois packs; 25 SVG movidos, nenhum perdido. O par já morava no
  `papeis.tsv`. As pastas de cena do Dracula não viraram coluna: os 13 desenhos soltos não estão na tabela, e pô-los
  mudaria a semente. A cena de cada um ficou no `packs/dracula/CREDITOS.md`.
- Disco: `<base>/<id>/` por pack, `<base>/Minhas/` para a imagem de quem usa e `<base>/.girando/`, a única derivada
  (o `cosmic-bg` gira um diretório só). O grupo de dia e o de noite saem do `papeis.tsv` e da luz, sem pasta.
- A migração roda antes de semear, com cópia `.antes-pastas` do que traduz, e não copia imagem entre discos. Ensaio
  com os nomes reais do nitro-5: 27 imagens viram 14, 6 e 7; os 381 banidos continuam banidos.
- Decisões 25 e 63 reescritas no lugar com o sim de 23/11.
- A origem dos papéis do Dracula entrou no `pack.json` em 24/11 (bloco `papeis-origem`, `eb76985d`), com o sim de
  quem usa. O gancho de commit não redige o nome da conta aqui desde 06/11, e o acervo é público. As duas chaves
  `WALLPAPER_DRACULA_*` se aposentaram: valor igual ao do pack some sem aviso; valor diferente é posto de lado com
  uma linha de aviso. No nitro-5 o conjunto semeado é o mesmo, byte a byte (14 e 14). Quem conferiu desfez a soma
  dos desenhos soltos, que devolvia arte banida, e fechou uma execução de código pelo `ignorar` de pack importado
  (`788ded77`).
- Quem conferiu achou cinco defeitos na migração e corrigiu (`b83160e8`): o banido voltava depois de uma falha no
  meio; falha de escrita saía como «ok», com traceback; dois nomes de antes no mesmo nome novo travavam a migração
  para sempre; `cat-.png` virava arquivo oculto; e `ativos/` noutro disco só avisava e a semente baixava de novo.
  Agora toda falha antes de mover sai com erro 2 e «nada foi movido», o nome ocupado ganha `-2` com aviso e o outro
  disco para tudo. Dez casos em casa de mentira, com o md5 de todas as imagens igual antes e depois.
- Medido por leitura: nitro-5 com 27 imagens e desktop com 49, base no mesmo disco e nenhum nome repetido. O
  portátil não respondeu por ssh.
- Cruzamento na integração: 32 de 32 verdes.
- Falta, no passo 10: a migração de verdade em cada PC, com os comandos do `relato-conf-papeis.md`.
- Anotado para outra leva: a semente e o envio de foto ainda podem criar o mesmo nome em duas pastas
  (`dracula/x.png` e `Minhas/x.png`), e o carrossel, o `BANIDOS` e o lado usam só o nome.
