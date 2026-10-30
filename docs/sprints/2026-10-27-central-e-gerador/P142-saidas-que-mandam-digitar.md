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

## Execução

Commit `270a0264`.

- **Cursor** (`scripts/cursor.sh`): sem rede, a saída diz que nada foi instalado e que o doctor tenta de novo na
  passada seguinte; o ponteiro adicionado diz onde escolher, pelo nome que o painel mostra
  (`meow_onde_no_painel CURSOR`). O `depois` do envio no painel passou de «Tema do ponteiro» para «Ponteiro», o nome
  que a tela tem.
- **Janelas e relógio**: escolhi a segunda via, só dizer o fato. A decisão 34 e o desenho do doctor não permitem
  que ele adote a escolha da GUI sem mexer na regra «o conf manda»; as saídas dizem que o valor do `meow.conf`
  manda e onde ele se escolhe no painel. O doctor não mudou.
- Os demais achados do `grep` da sprint foram reescritos para o fato: `construir_icones.sh`, `forma.sh` (três
  frases), `escala.sh`, `areas.sh`, `leitura.sh`, `terminal.sh`, `wallpaper.sh` (`cmd_dispensar` sem «Início»),
  `completar_icones.sh` (a pendência de tema mora em Tema), `lib/desinstalar.sh`, `lib/preflight.sh` e dois avisos
  do `bin/meow`.
- `porta_das_pendencias()` virou `nome_da_porta_cuidar()` no `app/servidor.py` e em `tests/app.sh`.
- **Prova**: `tests/nada-manda-digitar.sh` ganhou a seção 9 (o `grep` da sprint sem achado em `scripts`, `bin` e
  `lib`; nenhuma saída cita a Início; o nome antigo da porta não volta; o ponteiro adicionado diz onde escolher).
  Rodado: verde.
- **Ficou de fora**: `scripts/temas-de-apps/` (outro bloco). `bin/meow` ainda tem a ajuda e o `--help`, como a
  sprint manda. As frases de `meow_pula` com o nome da chave («TERMINAL_ESQUEMA="nao" no meow.conf — o terminal
  fica com a paleta de fábrica» e parecidas) dizem o estado e não mandam fazer nada; ficaram.

### Conferência

- **`pack.py` fora do `grep`**: a sprint pedia o `pack.py` junto e ele ficou. O importar dizia «Para aplicar:
  PACK=… e FLAVOR=… no meow.conf»; o `meow pack novo` mandava rodar `meow pack info`; o «Remover» do pack no ar citava
  um «Usar este» que a tela não tem e mandava rodar `meow pack usar`. Agora: «O cartão dele já está em Tema, com o
  «Aplicar tema»», a herança dita sem comando e o botão pelo nome da tela. Commit `5682ff73`; a seção 9 de
  `tests/nada-manda-digitar.sh` passou a conferir o `pack.py` (no código de antes acusa as quatro linhas).
- **Frases que ainda não falavam como a tela**: a escala dizia «escala 1.0» onde o painel mostra «100%»; o terminal
  dizia «pede sem esquema»; o `depois` do ponteiro enviado mandava «salve», e o painel grava ao soltar. Commit
  `66058b03`.
- **Ponteiro enviado pelo painel**: a sprint pedia que ele entrasse no `meow.conf` pela escrita única. Ficou como o
  implementador deixou, sem registrar: o «Trazer .zip» mora na própria linha «Ponteiro» e, ao voltar, o ponteiro novo
  aparece entre as escolhas, a um clique. Trocar sozinho fixaria o ponteiro, contra a decisão 12 («o pack decide, o
  usuário pode fixar») e contra o importar de pack («importar é ganhar uma opção»).
- **Motivo apontado que a tela não mostra**: o `completar_icones.sh` trocou «na Início» por «no cartão dele, em
  Tema», mas o cartão não mostra os `problemas` do pack. A frase diz só o fato. Commit `7b89cbb6`.
- Conferido sem achado: o rename `nome_da_porta_cuidar()` pegou todos os chamadores (só Python; o JS nunca o chamou);
  o `grep` da sprint sai vazio; zero comentário novo; nenhum «vestir» nas frases novas.
- **Prova**: `tests/nada-manda-digitar.sh` verde; suíte inteira no fim da P143.
