# P176 — o que a conferência deixou (06/11/2026)

Achados da conferência da P172 a P175, antes do install.

## O que se mediu

- `meow status` roda `rodar_checks` sem `MEOW_SO_LE`, e um comando só de leitura ainda chama `sudo -n <ponte> estado`. Lido no código.
- `app/servidor.py` crava a versão do esquema em `_flavor_na_tela`, `_acento_na_tela` (`CosmicTheme.Mode/v1`, `CosmicTheme.%s.Builder/v2`) e no programa que lê o teto do painel (`CosmicPanel.$b/v1`, perto da linha 1850). O fallback de `_cosmic_pasta` é `v1`, então trocar direto faria o `Builder/v2` cair em `v1`.
- `CONF_COMP`, em `app/servidor.py`, não tem leitor.
- `meow_travar` troca o cadeado quando o dono não parece meow: com um processo de `comm` só `sleep` segurando o lock, `meow espaco liberar` seguiu e cortou.
- `tests/etapa-compositor.sh` deixa `README.md` e `README.en.md` sujos na árvore (doctor 82→83, 130→131 ajustes, 67→69 ações). O teste não cita o README; o caminho exato não foi achado.

## A cura

- `meow status` lê com `MEOW_SO_LE=1`, sem `sudo`.
- O painel resolve a versão de cada esquema como os escritores, com o fallback certo para cada um.
- `CONF_COMP` sai.
- Medir se um build que perdeu o `bash` e deixou filhos herdando o lock fica desprotegido contra o Liberar; se fica, a trava confere quem segura o `flock` antes de trocar.
- Achar quem regenera o README no teste e fazer o teste não sujar a árvore.

## Como se prova

`tests/doctor-so-le.sh` estendido a `meow status`, sem `sudo` registrado; teste com `Mode/v2` e `Builder/v3` no HOME temporário; teste do cadeado com filho herdeiro; `git status` limpo depois de `tests/etapa-compositor.sh`.

## Execução

Commits `14bf01b1` (status), `a721633c` (esquema do painel), `cd06935f` (cadeado) e `adc14562` (README).

- **`meow status`.** Exporta `MEOW_SO_LE=1` antes de carregar a conf. Com a ponte de brinquedo, o código antigo registrou `sudo -n /usr/local/lib/meowsystem/ponte_root.sh estado`; o novo não registra sudo nenhum, chega até as divergências e não escreve arquivo na casa.
- **Esquema do tema no painel.** `_cosmic_pasta` ganhou o parâmetro `padrao`. O `Mode` resolve pelo sistema com padrão `v1`; o `Builder`, via `_builder_do_tema`, com padrão `v2`, que é o que os escritores gravam. O programa do teto do painel já resolvia por `meow_cosmic_v` desde a P173, então não havia o que mudar ali. `CONF_COMP` saiu.
- **Cadeado, medido: não há buraco, e nada foi corrigido.** Num HOME temporário, um `cargo` falso sem bash segurando o `lock` fez o `meow espaco liberar` trocar o cadeado, como a sprint mediu. Mas o corte só aconteceu onde ninguém construía: com o `builds.lock` preso pelo órfão, nada saiu (`há build em curso, Applets fica para depois`, idem Compositor); com o `.cargo-lock` do compositor preso, o compositor ficou e só o `.target` dos applets saiu. O Liberar não depende do cadeado do meow: ele segura o `builds.lock` e confere o `.cargo-lock` de cada alvo. Conferir quem segura o `flock` do meow antes de trocar não fecharia nada além disso.
- **README sujo.** Quem regenerava era o próprio `tests/etapa-compositor.sh`: a seção 7 chama `tests/numeros.sh` com `MEOW_NUMEROS_CORRIGIR=1`, que também corrige os números dos README. Agora o teste passa `MEOW_NUMEROS_CORRIGIR=versao`, que só conserta `patches/versao`.

Provas:

- `tests/doctor-so-le.sh` no código antigo: `NÃO  o meow status chamou sudo: sudo -n /usr/local/lib/meowsystem/ponte_root.sh estado`. No novo: `ok   o meow status só lê: nenhum sudo registrado`, `ok   e o meow status chegou até as divergências`, `passou: o doctor só lê, e o sinal não sai de casa`.
- `tests/esquema-do-tema.sh` (novo, em `tests/todos.sh`) no código antigo: `FALHA flavor não veio de Mode/v2 e Builder/v3: flavor=None`, `FALHA leu a versão velha`. No novo: os quatro `ok` e `passou: o painel lê o esquema do tema como os escritores`.
- `tests/trava-herdada.sh`: `ok: um build órfão que herdou o cadeado e segura o builds.lock não perde o corte: o Liberar nada tira`, `ok: um cargo órfão segura o .cargo-lock do alvo dele, e só o que ele constrói fica`, `tudo certo`.
- `tests/etapa-compositor.sh`: `etapa-compositor: tudo verde`, e `git status` sem `README.md` nem `README.en.md` depois (antes: ambos `M`). `tests/contrato-cosmic.sh`: `contrato-cosmic: tudo certo`.

Fica de fora: `tests/numeros.sh` acusa 7 números velhos nos README na árvore deste bloco; este bloco não os tocou. `tests/decisoes.sh` acusa `o registro pulou ou repetiu número`, que a sprint não trata. Os escritores de `derivar_flavor.py`, `derivar_vidro.py` e `derivar_acento.py` ainda cravam `Builder/v2`.
