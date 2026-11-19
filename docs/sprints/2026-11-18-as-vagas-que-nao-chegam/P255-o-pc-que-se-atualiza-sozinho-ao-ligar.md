# P255 — o PC puxa o que está no ar e se instala sozinho ao ligar (19/11/2026)

Pedido de quem usa, 19/11: «Faz um update automático diário pra ele sempre dar um pull do que temos online mais
recente pro Pc da pessoa. De forma que eu consigo sempre respeitar as opções dela anteriores mas sempre manter o app
dela sinronizado. Sempre ao ligar o pc. E já rodar o install também completo e build. Ele inicia uns 3 minutos após
dar boot no Pc pra evitar Race condition. Pra todos as extensões. A ideia é eu só precisar dar push num Pc e os
outros atualizam por default.» Resposta à trava (AskUserQuestion, 19/11): «Só com o CI verde».

## O que se mediu (coordenador, 19/11)
- Hoje cada PC só recebe o que está no `master` quando alguém entra por SSH e roda `git pull` e `./install.sh`. Em
  19/11 o desktop estava 60 commits atrás e o portátil, fora da rede, segue atrás.
- O produto já tem timers de usuário (`meow-doctor.timer` às 5h com `meow doctor --consertar`, `meow-sentinela`),
  instalados pelo `install.sh` e tirados pelo `lib/desinstalar.sh`. Nenhum puxa o repositório.
- O install é idempotente e lê o `meow.conf` de quem usa: rodar de novo respeita as escolhas dela.
- O install pede o sudo uma vez (`install.sh:822`, `sudo -A -v` com `SUDO_ASKPASS`); sem ele «a ponte fica de fora, e
  o resto vai».
- Em 18/11 um pull no portátil criou commit local pelo gancho pós-merge (P250, curado): checkout à frente do tronco
  não aceita `--ff-only`.

## A cura
1. Uma unidade de usuário nova (`meow-atualiza.service` e `.timer`), instalada pelo `install.sh` e tirada pelo
   desinstalar: `OnBootSec=3min` e uma vez por dia (`OnUnitActiveSec=1d`), para o PC que não desliga.
2. O serviço chama um verbo novo do `meow` (um script em `scripts/`, uma etapa por arquivo) que, na ordem:
   a. sai calado se outro `meow` segura a trava, se não há rede, ou se a raiz do checkout não é um clone do tronco;
   b. `git fetch` do `origin`; se o `master` de lá é o de cá, sai calado;
   c. só segue se o checkout está limpo, na branch do tronco e sem commit à frente; senão avisa uma vez e não toca;
   d. só puxa commit com o run `testes` do GitHub **verde** (API pública de checks do commit, sem credencial); run
      em curso: tenta de novo na próxima volta; run vermelho: não puxa e avisa uma vez por commit;
   e. `git merge --ff-only` até o commit verde mais novo;
   f. `./install.sh` completo (todas as extensões e os builds), com o `meow.conf` de quem usa como está;
   g. registra em `~/.local/state/meowsystem/atualiza.log` e avisa numa notificação curta o que entrou.
3. Chave no `meow.conf.exemplo` (`ATUALIZA="sim"` de fábrica), lida pelo verbo e mostrada no painel como os outros
   controles; `nao` desliga o timer. O doctor confere o timer (`chk_`/`fix_`).
4. O que precisa de root no install sem ninguém na frente: usar o que o install já usa (askpass quando existe, a
   ponte root quando instalada); sem nenhum dos dois, o resto vai e o log diz o que ficou de fora. A interface nunca
   pede senha (decisão 11).
5. Se o install falha no meio, o checkout fica no commit novo, o log guarda o erro, a notificação diz, e a volta
   seguinte tenta de novo; nunca um laço de install a cada minuto.

## Como se prova
`tests/atualiza.sh` novo, no runner, com um `origin` de mentira e um `curl` falso para a API: (1) tronco igual: não
faz nada; (2) commit novo com run verde: avança e chama o install uma vez; (3) run vermelho ou em curso: não avança;
(4) checkout sujo ou à frente: não toca e avisa uma vez; (5) `ATUALIZA="nao"`: nada; (6) outro `meow` na trava: sai;
(7) sem rede: sai calado; (8) a unidade tem `OnBootSec=3min`. Teste nunca chama `sudo`, `git push` nem rede de
verdade. Mais `tests/decisoes.sh`, `higiene.sh`, `nada-manda-digitar.sh`, `convergencia.sh`, `doctor-veredito.sh`.

## Nos três PCs
Os três. Depois deste install, um push verde chega aos outros dois no boot seguinte ou em até um dia.

## Decisão nova para o registro
«O PC puxa o `master` verde do GitHub e roda o install completo 3 minutos depois de ligar e uma vez por dia, com as
escolhas de quem usa; `ATUALIZA="nao"` desliga» — sim de 19/11 (o pedido acima e «Só com o CI verde»).
