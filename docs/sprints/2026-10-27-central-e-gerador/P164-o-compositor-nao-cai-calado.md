# P164 — o compositor não cai calado na fábrica (06/11/2026)

Decisão de 06/11/2026: «Liberar sozinho». Revê a retenção do degrau 2 da P154, com sim explícito.

## Alcance

Produto: acontece em todo PC a cada apt do `cosmic-comp` cujo patch entre com o contexto mudado.

## O que se mediu

- 05/11: o build 8cb1802 foi marcado `ruim` depois de quedas por abort em `libgallium`, fora do código dos patches. O shim não
  distingue a causa.
- 06/11: o apt trouxe o ec674cd. O `garantir_builds` compilou sozinho, com os 5 marcadores, mas `sem-workspace-vazio` e
  `menu-clique-curto` entraram no degrau 2, e o build ficou `retido` esperando o «Instalar» da página Extensões.
- Resultado: a sessão rodou com o binário de fábrica, 0 marcadores `AURORA-*`, sem Modo de Leitura e com o «5» da P161, sem
  nada dizer por quê. Só o aviso do applet de leitura apontava o sintoma.

## A cura

1. Build com todos os `req` e marcadores presentes e teste de fumaça bom entra no próximo login sem clique. A rede continua
   sendo o shim: duas quedas curtas e volta à fábrica.
2. Registrar o `-F1` no estado, para o doctor saber que o patch entrou com contexto mudado.
3. Avaliar se queda fora do código dos patches, como a de `libgallium`, deve consumir o `ruim`: o build de 05/11 saiu de cena
   por um defeito que a fábrica também tem (quedas em 29/10 e 03/11). Medido na P167: as duas quedas de 05/11 vêm no mesmo segundo
   de um `ring gfx_0.1.0 timeout` da amdgpu.
4. Decisão de 06/11/2026: a queda na fábrica não aparece na tela, nem no Manter. A decisão 27 vale ao pé da letra: fica no log e
   no `meow doctor`. O parágrafo do `docs/ESTADO-FINAL.md` que diz que o Manter mostra a pendência do compositor se reescreve, e o
   código que a mostra sai.
5. `patches/versao` parou em 4d14528, três versões atrás do ec674cd: atualizar e fazer o trilho mantê-lo verdadeiro.
6. Registrar em `docs/DECISOES.md`, no commit do código: «Build do compositor com todos os `req`, marcadores e fumaça entra sem clique» (sim de 06/11: «Liberar sozinho»).

Reescrever o trecho da P154 e as entradas de `patches/LEIA-ME.txt` e `tests/etapa-compositor.sh` que cobram a retenção.

## Como se prova

1. Simular apt com degrau 2 em HOME temporário: o build entra sem `liberar`, e o shim o escolhe.
2. Build que cai duas vezes no início volta à fábrica.
3. `meow doctor` conserta sozinho quando a sessão está em binário diferente do esperado, sem mandar digitar.

## Execução

| item | commit | o que ficou |
|---|---|---|
| 1, liberar sozinho | 1e6b201b | `retido`, `liberar` e «Em observação» saem. O shim só olha `ruim`, `req` e fumaça. O doctor renova o shim velho (`cuidar`) e apaga as marcas antigas `retido` e `liberado` |
| 2, `-F1` no estado | 1e6b201b, 0d4ec455 | linha `contexto=` no `estado`; o `conferir` diz quais patches entraram com o contexto mudado. O rebuild sobre a árvore já remendada guarda a linha |
| 3, queda fora do código | 8b9cc289, 0d4ec455 | avaliado e feito: queda a até 5 s de `ring … timeout` ou `GPU HANG` no kernel não consome o build. O shim não muda: duas partidas curtas e volta à fábrica. Provado nos dois canais, journal e coredump, com `coredumpctl` falso no teste |
| 4, fora da tela | 1e6b201b | saem os cartões `compositor-caiu` e `patch-obrigatorio` e as pílulas «Falhou» e «Não encaixa» do cartão do compositor, que passa a dizer «Não instalada». Fica no `meow.log` e no `conferir`. `docs/ESTADO-FINAL.md` reescrito |
| 5, `patches/versao` | 31f3e852, 0d4ec455 | ec674cd. O `tests/numeros.sh` compara com a matriz, e o gancho de commit corrige sozinho. Só para a frente: a casa com versão mais velha não puxa o arquivo para trás |
| 6, decisão 55 | 1e6b201b | no mesmo commit do código, com prova em `tests/decisoes.sh` |

Medido no journal real, só leitura, sobre o build 8cb1802 de 05/11:

```
resets: 1793848697 1793850193
quedas com o filtro: 0
quedas sem o filtro: 6
```

O `coredumpctl` sem resposta deixou de contar como registro lido. Era isso que deixava vermelho, na base, o caso «sem registro legível» do `tests/compositor-shim.sh`.

Provas, no molde do `tests/todos.sh`, HOME temporário e `sudo registrado: 0`:

```
compositor-shim.sh rc=0  compositor-shim: tudo certo
garantir-builds.sh rc=0  garantir-builds: tudo certo
etapa-compositor.sh rc=0  etapa-compositor: tudo verde
patch-que-sobe.sh rc=0  patch-que-sobe: tudo certo
precisa-de-gente.sh rc=0  precisa-de-gente: tudo certo
extensoes.sh rc=0  extensoes.sh: tudo verde
extensoes-pagina.py rc=0  103 conferências
manter-sem-pendencias.py rc=0
doctor-veredito.sh rc=0  passou: o doctor corrige, e o veredito é o pior estado
nada-manda-digitar.sh rc=0  passou: nada manda digitar
```

- Prova 1: `tests/etapa-compositor.sh`, seção 6: degrau 2 no compilar, sem `liberar`, e o shim escolhe o build.
- Prova 2: `tests/compositor-shim.sh`, «a guarda de queda»: o 3º início volta à fábrica.
- Prova 3: `tests/compositor-shim.sh`, «P164 1»: shim velho, `conferir` sai 1, `cuidar` renova sem mandar digitar, a segunda passada sai 0.

`tests/decisoes.sh` sai 1 aqui por dois motivos, nenhum do bloco: `.gitignore` com comentário, vermelho na base, e «o registro pulou ou repetiu número», porque a 54 é de outro bloco e só fecha na integração.

Sessão em binário de fábrica com build bom, sem shim velho, não tem conserto sem novo login: o `conferir` diz «vale no próximo login» e sai 0.

Da mão de quem usa, depois do install e do reboot: `meow compositor qual` aponta o build, e a sessão tem os marcadores.
