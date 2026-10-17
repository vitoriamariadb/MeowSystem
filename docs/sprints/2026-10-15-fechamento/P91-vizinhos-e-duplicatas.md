# P91 — Quem mais manda na máquina: conflitos e duplicatas com o MeowSystem

**Branch:** `sprint/p91` (depois da P90) · **Pedido de quem usa (17/10):** «procurar se tem algo no zsh ou
no Dracula theme ou qualquer outro repo local que entre em conflito com o MeowSystem, e se temos dois
scripts em cantos diferentes pra mesma coisa. Pra limparmos o meu PC e o da Vitória de forma que o
MeowSystem cuide de tudo, e isso sirva até pra apontar falhas de produtos nossos que estejam sendo
resolvidas por outro script fora daqui.»
**Regras que já valem:** «Spellbook em conflito migra para o meow» (23/09: o que conflita migra para o
MeowSystem e é desativado no outro; o que é só do PC fica); `vizinhos.conf` (caminhos que o MeowSystem não
escreve); decisão 6 e a guarda da GPU (Migração-OS, é do PC, fica fora do produto).

## O que se mede (só leitura, nesta máquina)
1. **Inventário de quem escreve no mesmo lugar** que o MeowSystem: `~/.config/zsh` (funções como
   `limpar_cache`, `_reconstruir_caches_icones`, `_fix_flatpak_icons`, `atualizar_tudo`, aliases),
   `~/Desenvolvimento/Dracula_OS-Theme`, `Dracula_Hyper-OS3`, `Spellbook-OS`, `NitroKit`, `Migração-OS`,
   `hefesto-*`, a Aurora (`/usr/local/lib/aurora`, `/usr/local/sbin`, `aurora-*.service`,
   `ritual-*`, `force-performance`, `autostart_performance`), crontab, `~/.config/systemd/user`,
   `/etc/systemd/system`, `~/.config/autostart`, hooks do apt (`/etc/apt/apt.conf.d`), `.desktop` em
   `~/.local/share/applications`. Para cada escrita: arquivo/chave, quem escreve, quando (gatilho), e se o
   MeowSystem escreve o mesmo.
2. **Duplicatas**: dois scripts (aqui e fora, ou dois fora) que fazem a mesma coisa — tema de ícones, cache
   de ícones, ícone da bandeja do flatpak, papel de parede, perfil de energia, atalhos, prompt, fontes,
   tema de apps, `apt` pós-atualização, compositor/patches.
3. **Falha de produto mascarada**: onde um script externo conserta algo que o MeowSystem (ou outro produto
   nosso) deveria fazer sozinho — cada caso vira um defeito com dono.

## O que se entrega
- `docs/pesquisas/2026-10-xx-vizinhos.md`: tabela responsabilidade × quem faz hoje × quem deve fazer ×
  ação (migrar para o meow / desativar fora / fica do PC / vira `vizinhos.conf`).
- **Migração**: o que é responsabilidade do MeowSystem entra nele (idempotente, com teste) e o de fora é
  desativado com backup e um caminho de volta — nunca apagado às cegas, e repositórios de terceiros
  (outros projetos dela e meus) recebem só um commit de desativação nos repositórios que são nossos.
- **O PC da Vitória** (`/home/vitoriamaria`, «Andromeda»): daqui não há acesso (a montagem remota recusou
  leitura em 15/10). Entregar `scripts/vizinhos.sh --inventario` (só leitura, sem rede) que ela roda lá e
  devolve a mesma tabela; a limpeza dela usa o mesmo `--desativar` com backup, rodado por ela.
- **Falhas de produto** viram sprints próprias no produto dono.

## Prova
- inventário reproduzível (`scripts/vizinhos.sh --inventario` sai igual em duas rodadas);
- depois da limpeza: `meow doctor` verde, e nenhuma responsabilidade com dois donos ativos (o próprio
  `vizinhos.sh` confere e o doctor passa a avisar duplicata nova — como estado, sem mandar digitar).
