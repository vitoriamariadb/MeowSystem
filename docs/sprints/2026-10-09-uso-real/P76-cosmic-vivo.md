# P76 — Sobreviver às atualizações do COSMIC (o sistema vivo)

**Branch:** `sprint/p76` · **Fonte:** `docs/pesquisas/2026-10-09-cosmic-vivo.md` (tarefas 1–9).

## Pedido de quem usa
«Ele tem que sobreviver independente do upgrade do COSMIC: eles atualizam e isso não quebra nada,
e evolui com o sistema operacional. Ele tem que ser vivo.» «definitivo, modular, independente,
idempotente».

## Tarefas (ordem de risco)
1. Rebasear o patch do menu de papel de parede do `cosmic-files` para o 1.10 (`src/menu.rs`).
2. Compositor no escopo do usuário: build em `~/.local/libexec/meow/cosmic-comp/<versão>`, shim
   `~/.local/bin/cosmic-comp` que usa o build só se a versão bate com o dpkg e não houve queda; senão
   o de fábrica. `/usr/bin` volta de fábrica. **NÃO ativar nesta máquina**: entregar desligado,
   com o comando de ativação e o de volta, porque a prova exige um login.
3. `meow cosmic prever`: pré-voo do candidato antes do `full-upgrade` (esquema/chaves dos .deb
   novos, série de patches no fonte novo, rust-version, revisão do libcosmic, guarda do fonte).
4. Gatilho pós-apt + unit `.path` do usuário que reconstrói de forma idempotente o que mudou de
   versão; `patches/versao` vira tabela gravada pela máquina; patch opcional que falha sai só ele.
5. Rust e volta: não apagar o único `.deb` de fábrica; fonte guardado fora de `~/.cache`.
6. Contrato de esquema: `contratos/cosmic.tsv` + `meow_cosmic_v` no lugar do `v1` fixo; furo de
   `lib/preflight.sh:71`; `.path` do raio vigiando o namespace.
7. Oráculo do tema: derivação real do libcosmic na revisão do `cosmic-settings` instalado.
8. Applets próprios seguem a revisão do libcosmic do painel; `leiturabin`/`midiabin` saem de
   `SEM_CONSERTO`.
9. Miúdos: `escala.sh` com `cosmic-randr list --kdl`, regex do backoff, `CosmicViewer` sem arte,
   comentário do `appid_dock.sh`.

## Prova
- patch do cosmic-files aplica com `-F0` no fonte 1.10 (já baixado no scratchpad da auditoria).
- `meow cosmic prever` contra o 1.10 → relatório verde/vermelho por item.
- simulação de troca de versão (dpkg falso) → shim cai na fábrica; gatilho reconstrói; idempotente
  (2ª passada não escreve nada).
