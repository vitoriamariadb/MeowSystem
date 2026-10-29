# P142 — as saídas dos scripts que ainda mandam digitar

Anotada em 27/10 (bloco Textos) e 29/10; medida de novo em 29/10 no `dev` (29350d13).

## O que se mediu
- `scripts/cursor.sh:188-191`: sem rede, ensina `curl`, `unzip` e `$0 aplicar` à mão; `:390`: «para usá-lo:
  CURSOR=... no meow.conf, e depois 'meow aplicar'».
- `scripts/construir_icones.sh:182`: «troque a chave antes do próximo 'meow aplicar'».
- `scripts/forma.sh:94` e `:129`: citam `meow doctor --consertar`, `./install.sh` e `meow forma` como ordem.
- `scripts/janelas.sh:180-182` e `scripts/relogio.sh:103-105`: «esvazie JANELAS_TILING / RELOGIO_SEGUNDOS no
  meow.conf — senão o doctor devolve».
- `scripts/wallpaper.sh:972` (`cmd_dispensar`): «o aviso saiu da Início» — a Início não mostra mais pendências; elas
  moram na porta que `porta_das_pendencias()` devolve.
- `app/servidor.py:4791`: `porta_das_pendencias()` devolve o nome da porta `cuidar`; o nome não diz mais o que faz.
- Procurar o resto com `grep -rnE "(meow_info|meow_aviso|meow_erro|meow_ok|meow_muda).*('meow |\"meow |rode|digite|no meow.conf|\\./install)" scripts bin lib`
  e o `pack.py`.

## Cura na origem
- Cada saída diz o fato e o que o programa vai fazer, sem mandar a pessoa digitar ou editar arquivo. Onde a frase
  existe porque falta o caminho automático, o caminho entra:
  - o cursor sem rede tenta de novo na passada seguinte do doctor (a frase diz isso);
  - o cursor adicionado entra no `meow.conf` pela escrita única do painel, quando a chamada vem do painel; senão a
    frase diz onde escolher (a porta do painel, pelo nome que o painel mostra);
  - janelas/relógio mudados pela GUI: o doctor adota a escolha dela no `meow.conf` em vez de devolver, OU a frase só
    diz o fato. Escolha a que respeita `docs/DECISOES.md`; anote em `## Execução`.
- `porta_das_pendencias()` ganha um nome que diz o que é (o nome da porta `cuidar`); os chamadores mudam junto.
- A `meow_ajuda` e o `--help` (a ajuda que o programa imprime de si) ficam como estão.

## Prova
- O `grep` acima sem achado fora da ajuda; os testes que citam essas frases atualizados no mesmo commit;
  `tests/decisoes.sh` verde no que é desta sprint.
