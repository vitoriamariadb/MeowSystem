# P91 — Quem mais manda na máquina: conflitos e duplicatas com o MeowSystem

**Status: EXECUTADA em 17/10 na `sprint/p91` — espera o merge (ver «Execução», no fim).** Quem usa mandou executar em 17/10 («li a spec, pode mandar um Opus executar»).

**Branch:** `sprint/p91` · **Pedido de quem usa (17/10):** «procurar se tem algo no zsh ou
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
- **O PC da Vitória** (a casa dela, «Andromeda»): daqui não há acesso (a montagem remota recusou
  leitura em 15/10). Entregar `scripts/vizinhos.sh --inventario` (só leitura, sem rede) que ela roda lá e
  devolve a mesma tabela; a limpeza dela usa o mesmo `--desativar` com backup, rodado por ela.
- **Falhas de produto** viram sprints próprias no produto dono.

## Prova
- inventário reproduzível (`scripts/vizinhos.sh --inventario` sai igual em duas rodadas);
- depois da limpeza: `meow doctor` verde, e nenhuma responsabilidade com dois donos ativos (o próprio
  `vizinhos.sh` confere e o doctor passa a avisar duplicata nova — como estado, sem mandar digitar).

**Nota de quem usa (17/10):** «nada deveria estar no Migração-OS»: o que for operacional lá (scripts, unidades, ganchos) é tratado como vizinho a migrar — do PC → Spellbook-OS/aurora; do produto → MeowSystem. A guarda da GPU já foi movida para a Aurora (aurora-gpu-compositor); não mexa nela.

## Execução (17/10)

Relatório com a tabela inteira, as provas e os limites da medida:
[`docs/pesquisas/2026-10-17-vizinhos.md`](../../pesquisas/2026-10-17-vizinhos.md).

**Números:** 112 escritas inventariadas (65 escritores; 5 por gatilho automático, 97 à mão, 10
desativadas), 9 duplicatas com o MeowSystem, 4 falhas de produto mascaradas.

**O que entrou no MeowSystem (`sprint/p91`, com teste):**
- `scripts/vizinhos.sh` — `--inventario` (só lê, sem rede, duas rodadas iguais), `--listar`,
  `--desativar <item>` (cópia datada em `~/.local/state/meowsystem/vizinhos/` e linha em
  `vizinhos-desativados.tsv`), `--restaurar <item>|todos`, `--revisado` e `--conferir`; o catálogo é
  dado, em `contratos/vizinhos.tsv`; nenhum caminho desta máquina no código. Teste:
  `tests/vizinhos.sh` (portátil, casa de brinquedo).
- a linha `vizinhos` do doctor: duplicata automática que ninguém revisou aparece como `--` (código 4,
  escolha dela), sem conserto e sem mandar digitar. O doctor passa a 66 conferências.
- migração (falha F4): o `hicolor.sh` reindexa a cache do hicolor da casa quando outro programa
  plantou ícone sem reindexar — antes, quem fazia era o `atualizar_icones` do zsh, à mão.

**Desativado nesta máquina (fora do MeowSystem):** cinco scripts do `Dracula_OS-Theme`
(`reaplicar_tema.sh`, `instalar_apt_hook.sh`, `reparar_hicolor_index.sh`, `normalizar_desktops.sh`,
`instalar_spicetify.sh`), cada um com a prova de que o MeowSystem instalado já cumpre sozinho (as
linhas do doctor no relatório), pelo `vizinhos.sh --desativar` e um commit só de desativação lá
(`f41ee47a`). O `meow doctor` depois: as mesmas linhas de antes, `nada a consertar`.

**Ficou do PC:** atalhos, `mimeapps.list` e editor padrão, o `.desktop` do Chrome com slice e
extensão, fontes de documento, a guarda da GPU, o askpass, o perfil de energia, o sudoers, o shim.

**Espera o merge:** `caches-icones-casa` (o laço de `~/.local/share/icons` no
`_reconstruir_caches_icones` do Spellbook): o `--desativar` recusa sozinho até o MeowSystem
instalado ter o `_hicolor_cache_velha`; depois do install, desativar e commitar no Spellbook.

**Migração-OS:** nada operacional dele está instalado (medido); a guarda da GPU já é da Aurora.
O `medir-compositor.sh` é do PC e vai para o Spellbook (P94); o resto é registro.

**Sprints novas, registradas e NÃO executadas:**
- [P92](P92-doutor-do-menu.md) — o doutor do menu vem para o MeowSystem (F1 `StartupWMClass` e F2
  lançador órfão); depois, desativar o `aurora-desktop-guards-apply.sh` no Spellbook.
- [P93](P93-ocultar-alcanca-tudo.md) — o `ocultar` alcança flatpak e home (F3); depois, as 25 cópias
  do `aplicar_overrides.sh` saem.
- [P94](P94-vizinhos-de-fora.md) — fora do MeowSystem: o Alt+F2 pede `meow painel reciclar`, o
  `install.sh --activate` do Dracula e o NitroKit, o `medir-compositor.sh` para o Spellbook.

**Para desfazer tudo:** `scripts/vizinhos.sh --restaurar todos`.
