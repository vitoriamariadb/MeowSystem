# Integração da leva H — 16/10/2026

Branch `integracao/leva-h`, worktree `.wt-meow/integracao-h`, a partir do `dev` (`dca414f`). Já
trazia a P85 (`8f55e73`) e o `dev` com as specs da P81 e da P86 (`eb4c3d1`). O `dev` não foi tocado.

## O que entrou, nesta ordem

| merge | branch | o quê | conflito |
|---|---|---|---|
| `d6d893c` | `sprint/p81` (`33ff8c8`, 14 commits) | build sempre, pela mesma função nos três gatilhos | nenhum |
| `96d4a99` | `sprint/p84` (`60a744c`, 5 commits) | os 39 feitos à mão viram vetor | nenhum |
| `096b134` | `sprint/p82` (`cab6642`, 53 commits) | os abertos do uso real | nenhum |
| `7792cbf` | — | correção da integração (abaixo) | — |

Sem conflito textual, mas 13 arquivos mudaram dos dois lados no merge da P82. Conferi os trechos de
cada um:
- `scripts/midia_build.sh` e `scripts/leitura_build.sh`: a P81 tirou a receita do cargo da tela e
  mandou o motivo para `$ESTADO/compilar.log`. A P82 trocou o `_garantir_cargo` local pelo
  `meow_garantir_cargo` do `lib/comum.sh`. O resultado tem as duas coisas. A linha «instale com
  rustup», que a P82 deixou como contexto, saiu, como a P81 queria.
- `install.sh`, `lib/desinstalar.sh`, `bin/meow`, `app/servidor.py` e `scripts/pack.py`: os trechos
  são de funções diferentes. A P81 mexe na unidade de login e no `SEM_CONSERTO`, a P84 no grupo dos
  feitos à mão, e a P82 no resto.
- `tests/todos.sh`: a P81 classifica dois testes novos, e a P82 põe os falsos de escrita. Ficaram as
  duas mudanças.

## Testes depois de cada merge

Rodei sempre com a casa de brinquedo e o envoltório da P82: sudo, pkexec e su recusam, os comandos
que escrevem no sistema recusam, e não há barramento da sessão. Também deixei falsos que recusam
cargo, just, make e rustup.

- **Depois da P81**, os testes dela e os que leem `patches/` (do lado da P85):
  `garantir-builds`, `cadeia-de-atualizacao`, `compositor-shim`, `cosmic-prever`,
  `volta-do-cosmic`, `nada-manda-digitar`, `pos-apt`, `doctor-veredito` e `app`. Todos rc=0.
- **Depois da P84**, os testes dela mais os da P81 que ela também toca: `acervo-da-ficha`, `pack`,
  `fonte-unica`, `pack-malicioso`, `app`, `garantir-builds`, `cadeia-de-atualizacao` e
  `app-uso-real.py` (python 3.12.1: 14 páginas, acabamento com 0 defeito). Todos rc=0.
- **Depois da P82**, a suíte inteira, `tests/todos.sh`:
  **64 testes: 63 verdes, 1 pulado (`conversor.sh`, falta dependência) e 0 vermelhos, rc=0.**
  - O gate `app-completo.py` passou em 692 s, e o `gate-link-externo.py` passou.
  - Os falsos recusaram 6 chamadas de sudo (`sudo -n true` e o `estado` da ponte) e 3 escritas de
    busctl.
  - O cargo foi chamado 10 vezes: o `cargo build` dos dois applets. Ele recusou todas, e nada
    compilou.
  - A árvore ficou limpa, e não sobrou nenhum `/tmp/meow-completo-*`.

## O que corrigi na integração

**`7792cbf`, `tests/nada-manda-digitar.sh`, seção 1b:**
- **Antes:** a seção isentava o `files_menu.sh`, o `midia_build.sh` e o `leitura_build.sh`, porque
  a P81 curava esses três em paralelo.
- **Agora:** com as duas sprints juntas, os três passam nas formas da seção, e a isenção saiu.
- **Prova:**
  - pus no `midia_build.sh` uma linha `meow_info "  veja o motivo: …"`, e o teste ficou vermelho
    nas seções 1b e 8;
  - restaurei o arquivo (`cmp` igual), e o teste voltou ao verde.

## P81 e P85 juntas

A P81 tira da lista a versão que está no degrau 4 enquanto nenhum arquivo do repositório ficar mais
novo que a matriz (`find … -newer`, no `garantir_builds.sh`). A série da P85 muda
`patches/versao` e três `.patch`. Quando esta integração chegar ao `dev`, o checkout reescreve esses
arquivos e eles ficam mais novos que a matriz. Então o próximo gatilho (login, pós-apt ou doctor)
volta a tentar o 4d14528, agora com a série rebaseada. É o caso que o
`tests/cadeia-de-atualizacao.sh` cobre: o rebase que chega pelo `git pull`.

## Para conferir à mão, na máquina, depois que o build em curso terminar

1. **O `install.sh` precisa rodar uma vez.** Só ele instala o `meow-builds-login.service` e atualiza
   o `meow-pos-apt.service` (P81). Sem a unidade de login, o build roda dentro do
   `meow-doctor.service`, que tem prazo de 5 min.
2. **A ponte root instalada precisa ser reinstalada** (P82, item 16).
3. **Os blocos órfãos do conf real saem no próximo `--consertar`** (P82, item 33).
4. **O compositor no 4d14528:** depois do primeiro gatilho, confira a matriz e o
   `MEOW_SHIM_SO_DIZER=1 ~/.local/bin/cosmic-comp`. O esperado é o build da casa, e não o
   `/usr/bin/cosmic-comp`.

## Ficou aberto, sem entrar nesta integração

- **O doctor ainda manda digitar** em linhas fora das sprints:
  - «rode: meow doctor --consertar»;
  - «'meow doctor --consertar' os escreve em…», na linha `gerar`;
  - «rode: meow ativar», no `icones_absolutos.sh` e no `nomes_apps.sh`;
  - «rode: scripts/construir_icones.sh», no `completar_icones.sh`;
  - as razões do `SEM_CONSERTO` para `convertidos` e `lancadorapt`.

  A P81 e a P82 listam cerca de 50 linhas assim.
- **Pastas `/tmp/tmp.*` vazias:** a suíte deixa uma ou duas a cada rodada. Uma vem do
  `nada-manda-digitar.sh`, seção 2; a outra aparece durante o gate. Apaguei as cinco das minhas
  rodadas. Em `/tmp` ainda há cerca de 30 de rodadas anteriores (15 e 16/10), que não apaguei.
- **O cargo de verdade:** sem o falso, a suíte chamaria o `cargo build` dos applets dentro da casa de
  brinquedo. Isso compilaria de verdade, longe do HOME real.
- **`clapper.svg` e `Clapper.svg`** diferem só na caixa (P84).
- **«Levar para o pack» não aparece para os feitos à mão** (P84).
- **A alvenaria do item 26 e o ResizeObserver** (P82), e o item 5 em parte (`jogos-fora.map` e
  `assets/gatos`).
- **Decisão de quem usa:** manter ou tirar o `NOPASSWD: ALL` do sudoers.
