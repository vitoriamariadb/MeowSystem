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
