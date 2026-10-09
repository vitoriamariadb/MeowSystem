# P75 — O doctor corrige; nada manda consertar à mão; o que é decidido não volta

**Branch:** `sprint/p75` · **Fontes:** `01-regressoes.md` (D1, D2, D3, S4, S5, S6 e «Por que voltou»),
achados 3, 4, 5, 23.

## Pedido de quem usa
«O doctor não tem que avisar nada. Tem que corrigir.» «nenhuma feature pode mandar o usuário
consertar à mão» (21/09, ×3).

## Tarefas
1. **D1** — toda checagem que sabe a cura a aplica (ponte root, sem senha); nenhuma saída imprime
   `instale com`/`sudo apt …`; o veredito final reflete o pior estado (`!!`/`--` com cura possível
   nunca termina em «nada a consertar»; `bin/meow` ~2437).
2. **D2** — `meow status` e `meow doctor` leem o mesmo estado e nomeiam o mesmo tema; o status
   chama de divergência o que foi pulado; a tela não diz «aplicou» sem ter aplicado.
3. **Achados 3, 4, 5** — sem contradição entre linhas (base «confere» e «não instalada»); nenhuma
   linha vazia ou cortada (`files_menu`, `resgatados`, `escala`, `fontes`).
4. **D3** — `meow pack sincronizar` fora da passada do doctor (decisão «Aposentar tudo», 24/09).
5. **Chaves aposentadas** — `migrar_conf.py` ganha a lista de chaves aposentadas (começa por
   `ICONES_BASE`), não as devolve, e remove a linha ativa do conf; a chave sai do `meow.conf.exemplo`.
6. **Testes que não mentem** — tirar as isenções de `tests/sem-receita-no-log.sh:95-96`;
   `tests/git-limpo.sh` cobre o repositório inteiro durante uso do painel; testes rodam no
   repositório real; a suíte ganha um sudo falso no PATH para nunca escrever no sistema real (S6).
7. **S4** — `scripts/greeter.sh:266-271`: a ponte diz o motivo em vez de mandar para `/dev/null`.
8. **Achado 23** — dois painéis não dividem o mesmo `app.pid`; `--parar` só derruba o próprio.

## Prova
- `meow doctor` numa casa temporária com a base faltando → ele instala/repara e termina verde;
  com algo irreparável → termina vermelho, nunca «nada a consertar».
- `grep -rn "apt install" ` na saída do doctor → 0.
- conf com `ICONES_BASE` comentada → `migrar_conf.py` não a devolve.
- suíte inteira roda com o sudo falso e nenhum arquivo fora do HOME temporário muda.
