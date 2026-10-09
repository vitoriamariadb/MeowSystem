# P74 — O pack Dracula é um tema completo, montado certo e exportável

**Branch:** `sprint/p74` · **Fontes:** paridade T6–T10, `01-regressoes.md` (I1, I2, I7, I10, T1–T7),
achado 9, `02-decisoes.md` (1).

## Pedido de quem usa
«aqui deveria ter tudo do theme dracula», «onde o nosso faltar preciso que vc crie», «ao resetar o
PC terei tudo conforme o tema dracula?», «conseguiremos gerar e exportar temas completos?».

## Tarefas
1. **I1/I2** — todo leitor da base de ícones pergunta ao `pack.py:_base_escolhida`
   (`construir_pastas.sh:107`, `completar_icones.sh:149` e qualquer outro); pastas coloridas
   voltam. (A aposentadoria da chave `ICONES_BASE` no conf/exemplo/migrador é da P75.)
2. **T10 + decisão 1** — base em duas camadas: `circle` por cima, `main` por trás, ambas pinadas
   por sha256; os 458 simbólicos perdidos voltam.
3. **T6** — escolher o pack Dracula liga os desenhos de app dele (sem `ICONES_DRACULA=nao` padrão).
4. **T7** — `meow pack exportar` (ou o verbo que já existir) gera tema instalável: nome por
   pack+flavor, `Inherits` só do que vai junto, `Comment` do pack (não «Catppuccin»).
5. **T8** — `index.theme` certo na 1ª passada (Directories calculado do disco no fim); o laço de
   5 repetições do install.sh deixa de ser necessário.
6. **T9 + I7** — mimetypes Dracula próprios (do flavor `css-variables` + paleta) e as pastas que
   faltam (`folder`, `user-home`, `user-desktop`).
7. **T1 (regressões)** — nada Catppuccin com o Dracula no ar: starship `palette`, ícones de
   arquivo, prompt, aba Terminal.
8. **T2** — Obsidian para de oscilar: o tema do cofre é aplicado sem brigar com o git do cofre.
9. **T3, T4, T5, T6, T7** — sons do pack (os 25 .oga ou o motivo virar cura), qBittorrent sem
   depender da Aurora, os 30 overrides de .desktop no pack, Vesktop com `enabledThemes`,
   papéis de parede SVG 4k rasterizados.
10. **I10** — com MODO=claro, traço do dock e pastas usam a paleta do lado vestido.

## Prova
- uma passada das etapas de ícone numa casa temporária → `validar_index.py` sem faltas.
- `pack.py info dracula`: nada «herdado do Catppuccin» que tenha cura; mimetypes PRÓPRIO.
- exportar → instalar num HOME limpo → cache reconstruído, 0 links para fora, 230+ apps.
- `comm` dos simbólicos do tema antigo contra tema+base → 0.

## Segurança (acrescentado às 18:45 de 09/10, revisão automática de segurança, `scripts/pack.py`)

Obrigatório para o conferente da P74: a revisão acusou *parser differential / path traversal*
em `scripts/pack.py`, no código novo da base em camadas (commit 13929d4, `origem_pinada` e quem
monta `<nossa>-Base-<n>`). Regra: um caminho vindo de `pack.json` (ou de uma origem pinada) é
validado e USADO pela mesma forma normalizada — `os.path.realpath` contra a raiz permitida —,
nunca validado como texto (regex, `startswith`, `split('/')`) e usado por outro parser (git,
tar, shell). Nome de camada/pasta de destino só de um conjunto fechado (`[A-Za-z0-9._-]`, sem
`..`). Teste com um pack malicioso (`"origem": {"caminho": "a/../../../../etc"}`, nome com `/`,
symlink no checkout pinado) provando que nada é lido nem escrito fora da raiz.

**Segundo alerta (18:50, commit c0b89b0, `scripts/icones_apps_dracula.sh`): path traversal.** As
duas colunas de cada linha de `apps.map` (do pack, de pack importado e das escolhas do painel no
estado do usuário) são dado não confiável: o nome do ícone de destino só de `[A-Za-z0-9._+-]`
sem `/` nem `..`; o desenho de origem resolvido com `realpath` e aceito só dentro da raiz do pack
(ou de `assets/icones/`). Linha que falha é pulada e contada no log, sem abortar o resto. Mesmo
teste do pack malicioso, agora com `../../../../etc/passwd : x` e `x : ../../../.ssh/id_ed25519`.
