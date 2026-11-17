# Estado da leva de 17/11 (coordenador)

Pedido de 17/11: workflows liberados sem teto de agentes nem de cota nesta leva («Sem limitação de percentual e sem
limitação de uso […] aumentarmos a qualidade do produto como um todo»).

| bloco | tarefa | árvore / branch | situação |
| --- | --- | --- | --- |
| A | P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | retomado após a queda; já tem `6a379c22`, `1fa64bb2` |
| B | P213 Electron, P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | retomado; já tem até `83cb20f2` (achados viraram P215 a P219) |
| C | P220 botões do Dracula | `.meow-wt-arte-botoes` / `bloco/arte-botoes` | pronto: folha aprovada («Aprovo»); restaurar = grade meio erguida («Grade meio erguida»), feito pelo coordenador em `b52884a4`; APLICADO no tema real em 17/11 18:58 a partir desta árvore (queixa dela: «o morcego ficou minúsculo» na barra de título, era o desenho do P207), `--conferir` ok |
| D | P231 vagas no pack e no criador | `.meow-wt-produto` / `bloco/produto` | retomado; já tem `3bf3632f`, `05d071ea`; Soneca `67741ed` em `../meowsystem-soneca-p231` (sem push) |
| E | P232 Dracula na barra | `.meow-wt-arte-dracula2` / `bloco/arte-dracula2` | pronto (`7b320a63`, `c3dded60`, `feb47b6d`, `46660190`); escolhas: corrente, AMPULHETA (níveis legíveis em 16 px, folha `fotos/P232-bateria-vela-x-ampulheta.png`), Soneca e notificação aprovadas; variantes em `icones/biblioteca/` (`-vela`, `-frasco`, `-teia`); APLICADO no tema real 17/11 ~19h20 a partir desta árvore (inclui o P220), `--conferir` 344 ok |
| F | P233 arte do MeowSystem | `.meow-wt-arte-meow` / `bloco/arte-meow` | pronto (`b2aaa8a7`, `2ac2d2cc`, `7d758965`); escolhas: arranhão, novelo, peixe; Wi-Fi reforçado («Reforçar os níveis») |
| G | P234 papéis dia e noite | `.meow-wt-papeis` / `bloco/papeis` | pronto (`4d461716`, `e76a0d33`): 6 pares em `packs/*/wallpapers/pares/<cena>-{dia,noite}.svg`; casar com a declaração de par do P231 na integração |
| H | P235 janelas do sistema sem ícone | `.meow-wt-janelas` / `bloco/janelas` | retomado, sem commit ainda; medido: o diálogo de arquivos é `com.system76.CosmicFilesDialog` |
| I | P236 parte 1, dock casa por padrão | `.meow-wt-dock` / `bloco/dock` | retomado, sem commit ainda |
| H2 | P236 parte 2, padrões no `appid.map` | `bloco/janelas` | espera o H voltar («Os dois», AskUserQuestion 17/11) |
| K | P238 palco headless | `.meow-wt-palco` / `bloco/palco` | pronto (`c49f28f6`, `ad8fa961`, `3c61f045`): cosmic-comp winit no Xvfb, SSD do COSMIC com a arte do pack, sem apt; levado por merge para A, B e H, retomados 17/11 com a regra do palco no prompt |
| J | P237 pastas do Dracula com cena | `.meow-wt-pastas-dracula` / `bloco/pastas-dracula` | pronto (`07fb3279`, `5f5afecd`); aprovado por quem usa 17/11 («Aprovo e aplica»); APLICADO no tema real (icones_pastas.sh, 10 ok) |

Quadro de arte: <https://claude.ai/artifact/WkX5Moc3PoYQt6H1rkzZrP>, aprovado inteiro («Tudo aprovado»), virou P230 a
P234.

Queda da sessão em 17/11 (fim da tarde): 6 workflows e o agente da ampulheta pararam no meio, com as árvores limpas e
os commits salvos. Retomados com `resumeFromRunId` (o agente que já tinha terminado volta do cache).

Achados para a próxima leva: `scripts/icones_sistema.sh` injeta a espessura do MeowSystem em todo traço `currentColor`
de qualquer pack (pack de terceiro com traço fino sai engordado); `wifi.svg`, `battery.svg` e `plugged-into-power` das
Configurações do MeowSystem no desenho antigo.

## Próximo passo
1. Esperar os blocos retomados. Integrar em `integracao/2026-11-17` (worktree `../.meow-wt-integracao` com a branch
   nova) na ordem C, E, F, G, J (arte), D (vagas, casando o par do G), A, B, H, H2, I; resolver o `PROCEDENCIA.md` do
   Dracula e o `ESTADO.md` à mão.
2. Suíte inteira na integração; vermelho se corrige.
3. `master`, push do MeowSystem; push da Soneca (`p231`) e o pino novo.
4. Coordenador: `install.sh`/`meow doctor --consertar` real com Chrome e Edge fechados, build do dock; quem usa confere
   no uso real.
