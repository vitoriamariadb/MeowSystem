# P165 — o Meow sabe o que deixa no disco (06/11/2026)

Pedido de 06/11/2026: a limpeza tem de ser contínua, e o app, consciente dos resíduos que deixa.

## Alcance

Produto: acontece em todo PC que compila as extensões, sem depender do hardware.

## O que se mediu

Na faxina do nitro-5, em 06/11, com o `/home` em 89%, o Meow era um dos maiores ocupantes, e só cinco agentes lendo o disco
acharam isso:

| Onde | Tamanho | O que é | Volta sozinho? |
| --- | --- | --- | --- |
| `~/.local/state/meowsystem/extensoes/.target` | 10 GB | Cargo target dos applets | sim, recompilando |
| `~/.cache/meowsystem/cosmic-comp` | 3,3 GB | build do compositor | sim, recompilando |
| `src/applets/leitura/target` | 1,5 GB | target órfão no checkout | sim, recompilando |
| `~/.cache/meowsystem/cosmic-prever` | 663 MB | build de prévia | sim, recompilando |
| `~/.cache/meowsystem/oraculo-tema` | 345 MB | cache do oráculo | sim |
| `.playwright-mcp` | 92 MB | capturas de sessões de prova | não precisa |
| `~/.local/state/meowsystem/backups` | 268 MB, 198 entradas | backups de cada operação | não |

São cerca de 16 GB reconstruíveis, fora do que é de quem usa.

No código, nada cuida disso:

- `cargo clean` não aparece em `scripts/`, `lib/` nem `bin/`. O `.target` único do `extensoes_build.sh` só cresce: cada
  versão de dependência soma artefato, e o que ficou velho nunca sai.
- `backups/` não tem rotação.
- `cmd_doctor` não mede disco nenhum. O app acusa um ícone errado, mas não 10 GB dele próprio.
- `meow_desinstalar` termina com «o estado e os backups ficam em $MEOW_ESTADO — apague à mão se quiser»: quem desinstala
  continua com os 10 GB e não é avisado do tamanho.
- A decisão de manter ou apagar exige saber o custo de refazer, e hoje só quem leu o código sabe que apagar o `.target`
  faz o próximo build compilar tudo.

## O problema

O Meow instala, compila e guarda como se o disco fosse infinito, e não sabe o que deixou para trás. Quem usa descobre pelo
sintoma, o disco cheio, sem saber o que é do Meow, o que é seguro apagar e o que custa caro refazer. Cada limpeza vira
investigação à mão, e no build seguinte tudo volta a crescer.

## A cura

O Meow passa a ser dono do que escreve: sabe o que deixou, quanto pesa, quanto custa refazer, e se limpa sozinho.

1. **Inventário único.** Todo caminho que o Meow escreve entra num registro com dono, categoria e custo de refazer. São três
   categorias: `reconstruível`, `backup` e `de quem usa`. Caminho que não está no registro é defeito, e um teste cobra isso.
2. **Limpeza contínua na origem.** Ao fim de cada build, o que não serve ao build atual sai: artefato de versão antiga, target
   órfão no checkout, prévia já aplicada. Backups com rotação por idade e quantidade, preservando sempre o `tema-PRIMEIRO`.
3. **Teto, não faxina.** Cada `reconstruível` tem um teto. Passou, o Meow corta o que está há mais tempo sem uso, sem perguntar.
   Nunca o build em uso, nunca durante um build (a trava em `lock` já existe), nunca `de quem usa`.
4. **Espaço visível.** Página na Central e `meow espaco`: quanto o Meow ocupa, por categoria, o que dá para liberar e quanto
   tempo o próximo build levará. Um botão, Liberar, com o preço escrito ao lado.
5. **Doctor com disco.** Uma linha com o peso do Meow. Acima do teto, conserta sozinho como o resto do doctor; com o disco
   apertado, avisa e aperta os tetos.
6. **Desinstalar limpo.** `meow_desinstalar` usa o inventário, apaga tudo o que é do Meow e diz quanto liberou. Só guarda os
   backups se quem usa escolher.

Os resíduos do Meow fora dele, como `~/.local/src/xdg-desktop-portal-cosmic/target` (2,8 GB), entram no mesmo inventário quando
vierem de um fluxo do Meow.

## Decisões de 06/11/2026

1. Tetos fixos: `.target` 8 GB; do compositor, o build em uso e um anterior; backups de 30 dias, sempre com o `tema-PRIMEIRO`. Faxina
   nenhuma pode forçar compilar o compositor a cada semana.
2. Corte por idade do artefato, por script próprio, sem dependência nova.
3. O `.target` continua único (P147).

Na tela vale a regra do GSD: nome curto, número e botão; o porquê e o custo de refazer vão na dica. Disco apertado o doctor resolve
apertando os tetos, sem aviso na tela (decisão 27).

## Como se prova

1. Teste de inventário: rodar install e build em HOME temporário; todo caminho criado está no registro.
2. Dois builds com versões diferentes de dependência: o tamanho do `.target` não soma os dois.
3. Cache acima do teto: o doctor corta e o build em uso continua de pé.
4. Backups acima da rotação: sobram os mais novos e o `tema-PRIMEIRO`.
5. `meow espaco` bate com `du` dentro de 5%.
6. `meow desinstalar` em HOME temporário: nenhum caminho do inventário sobra, e o valor que ele diz bate com o medido.

## Execução

Feita em 06/11/2026, na `bloco/disco`. Decisão 56 em `docs/DECISOES.md`, no mesmo commit do código (`e97c8ab9`).

### O que foi feito

| Item | Commit | Onde |
| --- | --- | --- |
| 1. Inventário único | `e97c8ab9` | `assets/contratos/espaco.tsv` (nove campos: id, categoria, caminho, nome, refazer em min, teto em MB, corte, o que o desinstalar faz, dica) |
| 2. Limpeza contínua na origem | `e97c8ab9` | `scripts/espaco.py continua`, chamado no fim de cada build de applet (`_limpar_fim_de_build` no `extensoes_build.sh`); o oráculo apaga o próprio trabalho depois de instalar |
| 3. Tetos | `e97c8ab9`, `ea1a7559` | `.target` 8 GB; do compositor e do menu do Arquivos, a versão em uso e uma anterior (cache, pronto em `libexec` e no estado, fonte guardado); backups 30 dias com o `tema-PRIMEIRO` sempre |
| 4. `meow espaco` e a página | `799074a3`, `96a40060` | `meow espaco`, `json`, `inventario`, `aparar`, `liberar`; aba **Espaço** na Central de extensões (`#extensoes/espaco`), com o botão Liberar e o preço ao lado |
| 5. Doctor com disco | `799074a3` | `chk_disco` e `fix_disco`; com o disco em 85% ou mais os tetos caem pela metade, sem aviso na tela |
| 6. Desinstalar limpo | `830d17e8`, `f0390bb3` | `meow_desinstalar_espaco` em `lib/desinstalar.sh`; `--guardar-backups` no `install.sh` e a ação «Desinstalar e guardar» na página Manter; os `.desktop` do sistema voltam antes de os backups saírem, e o shim e o menu patchado saem junto |
| Provas | `0559c5de`, `4bc18c4e`, `ea1a7559`, `69a0a7fe` | `tests/espaco.sh` (137 conferências) e `tests/espaco-pagina.py` (26) |

### O que escolhi onde a sprint não cobria

- **«Central» é a Central de extensões.** A página é a terceira aba dela, depois de Applets e Builds. O CSS mora no `extensoes.css`.
- **«O que não serve ao build atual» sai pelo próprio cargo.** Depois de compilar, uma segunda passada `cargo build --message-format=json --offline` (tudo fresco, instantânea) lista as unidades do build; o hash de cada uma vai para `extensoes/<id>/uso.lista`. O cargo cita o binário só como `release/<bin>`, então o hash dele vem do link duro em `deps/`. Com todo applet instalado listado, sai do `.target` o que nenhuma lista cita. Enquanto algum applet não tem lista, o que as outras citam fica, e o resto sai por idade (7 dias) e por teto, do mais velho para o mais novo.
- **Idade de arquivo é `max(mtime, atime)`, de pasta é `mtime`, e há uma guarda de 10 minutos** (o que foi tocado agora nunca sai, mesmo sem trava). Pasta não usa `atime` porque medir a lê: o próprio doctor renovaria a idade. O `/home` desta máquina é `noatime`: aqui a idade é só `mtime`, então o artefato reaproveitado parece parado, e sem lista o próximo build recompila o que o corte tirou, sem perda de dado. Com lista completa a idade não decide nada.
- **«Nunca durante um build» é a `builds.lock` mais a trava `.cargo-lock` do próprio cargo**, testada com `flock` não bloqueante. A `lock` do meow não serve: o doctor a segura enquanto corta.
- **Backups:** além dos 30 dias, no máximo 100 (número meu); apertado, 15 dias e 50. `tema-PRIMEIRO` nunca entra na conta.
- **Prévia e oráculo parados há 7 dias saem** (1 dia com o disco apertado). O compositor só perde o que passa de duas versões; o fonte `.dsc`/`.tar` sai do cache quando já está em `~/.local/share/meowsystem/fontes`.
- **`guardados:N` é o corte do que já está pronto ou baixado por versão de pacote:** o build do compositor em `libexec`, o menu do Arquivos no estado e os fontes guardados. Fica a versão que o `dpkg` diz, se existir, e as mais novas até somar duas. Não entra no preço do Liberar, porque nada se recompila. O compilador do compositor já poda o cache para a versão atual, então a de lá raramente chega a duas.
- **Liberar** corta tudo o que é `reconstruível` e cortável, inclusive o cache do compositor; os tetos e a limpeza do doctor nunca forçam o compositor a recompilar. O build em uso (`~/.local/libexec/meow`, o binário em `~/.local/bin`) nunca sai, fora o desinstalar.
- **O tempo de refazer é estimativa fixa do registro** (10 min os applets, 4 o compositor, 3 o oráculo); a dica diz «~N min».
- **Categorias:** `de quem usa` é estado e escolha (nunca tem corte); build em uso é `reconstruível` com corte `nunca` ou `guardados`. O desinstalar deixa `nao` (temas importados, oficina, configuração, repositórios adicionados, cópias dos vizinhos desligados), `passo` (ícones, fontes, binários, lançadores, coleção e curadoria de papéis, que os passos antigos já tratam) e leva o resto.
- **Os resíduos fora do Meow** (`.playwright-mcp`, `~/.local/src/xdg-desktop-portal-cosmic/target`) não entram: nenhum fluxo do Meow os cria nesta branch. Entram no `espaco.tsv` quando a P159 trouxer o fluxo.
- **Sem teto:** `extensoes-fontes` e `upstream-cache` têm tamanho fixo, e `oraculo-builds` cresce devagar, um binário por revisão do libcosmic (três aqui).
- **O desinstalar devolve os `.desktop` pela ponte.** Se ela não estiver viva, ele avisa o que não devolveu e os backups saem do mesmo jeito.

### Provas (literais, HOME temporário, falsos no PATH, nenhum `sudo` chamado pelos testes)

```
tests/espaco.sh           espaco: tudo certo        (137 ok)
tests/espaco-pagina.py    26 conferências
tests/extensoes.sh        extensoes.sh: tudo verde
tests/extensoes-gesto.sh  rc=0
tests/extensoes-install.sh extensoes-install.sh: tudo verde
tests/applet-pino.sh      applet-pino: tudo certo
tests/oraculo-tema.sh     oraculo-tema: tudo certo
tests/app.sh, reversao.sh, nada-manda-digitar.sh, doctor-so-le.sh, doctor-veredito.sh, notas-de-funcao.sh  rc=0
tests/extensoes-pagina.py, app-acessibilidade.py, app-layout.py, app-texto-visivel.py  rc=0
```

Por «Como se prova»:

1. Inventário: `tests/espaco.sh` cria em HOME temporário cada nome que o código escreve em estado e cache, em todas as formas de citar a pasta, e roda `espaco.py cobre` (rc 0); um arquivo sem linha no registro dá rc 1 e é apontado. Depois roda o `extensoes_build.sh` de verdade, com `cargo` e `git` falsos, e `cobre --casa` confere que nada do que nasceu na casa fica sem dono. Os nomes reais desta máquina passaram pelo mesmo crivo. O `install.sh` não foi rodado (regra do GSD); a parte estática cobre os caminhos que ele escreve.
2. Dois builds, `v1` e `v2` de uma dependência: depois do segundo, `libdep-<hash de v1>`, o fingerprint e a saída de build dela somem, o de `v2` fica, e o `.target` mede o mesmo (dentro de 20%). O cargo falso segue o JSON medido no cargo 1.99. Com o cargo real em HOME temporário: depois do doctor o `cargo build -v` diz `Fresh` em tudo, e trocar a versão de uma dependência tira só a unidade velha.
3. Teto de 1 MB num registro de teste: `chk_disco` dá 1, com a trava `.cargo-lock` tomada o corte espera e o doctor dá 0 dizendo «build em curso», livre a trava o mais velho sai primeiro, o binário do build em uso fica, a segunda passada dá 0. Disco a 92%: ficam menos unidades do que a 10%.
4. 130 backups recentes: sobram os 100 mais novos e o `tema-PRIMEIRO`; dos 9 com idades de 3 a 365 dias, ficam os 4 dos últimos 30 dias e o `tema-PRIMEIRO`.
5. `meow espaco json`: o total bate com `du -sk` de estado, cache e libexec dentro de 5%, e o liberável com o `du` do `.target` mais o cache do compositor dentro de 5%.
6. `espaco.py desinstalar`: nenhum caminho `sim` sobra, o que é de quem usa fica, e o valor impresso bate com o `du` do que saiu dentro de 5%. Com `MEOW_GUARDAR_BACKUPS=1` os backups ficam. O `meow_desinstalar` inteiro roda num clone mínimo em HOME temporário: o ensaio não apaga nada, o valor dito bate com o medido, o `.desktop` volta ao do apt antes de o backup sair, o shim e o menu saem, nada renasce depois, e o que é de quem usa fica.

### O que falta

- Rodar a suíte inteira (`./tests/todos.sh`): é do coordenador.
- Os números do README (83 conferências, 69 ações): o sanitizador do gancho troca o nome do coautor ao se commitar o README, e a decisão 45 manda regerar no merge. Fica para o `scripts/readme.sh` da integração; até lá o `numeros.sh` acusa só o README.
- `tests/decisoes.sh` acusa a numeração (a 56 não tem 54 e 55 aqui; chegam com os outros blocos) e o comentário no `.gitignore`, que não é meu.
- Nada de `install.sh`, `meow doctor --consertar` ou `meow espaco liberar` com o HOME real.
