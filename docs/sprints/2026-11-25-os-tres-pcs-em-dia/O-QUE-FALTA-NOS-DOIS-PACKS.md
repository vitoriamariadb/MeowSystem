# O que falta nos dois packs (medido em 25/11/2026)

Fonte: `meow pack info`, `meow pack validar`, `meow apps`, `meow icones` e `meow cosmic icones` nos três PCs
(MeowSystem e Meow-portatil com `meowsystem`/mocha, nitro-5 com `dracula`/dracula), mais a lista dos apps visíveis de
cada um. Nada aqui foi desenhado nem aplicado: arte e gosto são de quem usa.

## Lado a lado

| peça | `meowsystem` | `dracula` |
|---|---|---|
| paleta | própria, 4 flavors (latte claro) | própria, 2 flavors (alucard claro) |
| ícones de app | traço do motor (3 mapas), 34 de 42 apps com desenho no MeowSystem | 268 no mapa próprio, 36 de 39 no nitro-5 |
| ícones-base | não declara: Papirus-Dark do `meow.conf` | própria (`dracula-icons`) |
| ícones de arquivo | 75 próprios | herda os 75 do `meowsystem` |
| pastas especiais | 7 | 10 |
| ponteiro | não declara: `CURSOR` do `meow.conf` | próprio (`Dracula-Cursor`) |
| papéis de parede | 6 desenhos (3 pares dia/noite) e a coleção do Catppuccin | 19 desenhos (3 pares dia/noite, 13 avulsos) |
| mascote | Mimir de dia, Coquinha de noite | morcego de dia e de noite |
| prompt | próprio | herda o preset, com as cores dele |
| sons | próprios | próprios |
| fontes | pasta `fontes/` no pack, sem declaração no `pack.json` | nenhuma |
| ícones de arquivo do VS Code | `catppuccin-vsc-icons` | nenhum |
| capturas na vitrine | 0 | 0 |

## Falta no `meowsystem`
1. COSMIC Viewer sem desenho (P297 passou a acusar). O Dracula tem (`apps/galaxy.svg`, escolha de 16/11).
2. Apps instalados que caem no ícone de fábrica ou no Papirus: Câmera (`io.github.cosmic_utils.camera`), VLC, Azahar,
   Super ZSNES, Steam Link, FogStripper, A Forja/FORJA, Pipeline EducaDados (os dois últimos com `Icon=` de caminho
   absoluto).
3. O pack não declara ponteiro nem ícones-base: valem o `CURSOR` (`catppuccin-mocha-mauve`) e o Papirus-Dark do
   `meow.conf`. Não medi o que acontece com eles numa troca de flavor.
4. Três pares de papel dia/noite, contra dezenove desenhos do Dracula.

## Falta no `dracula`
1. Tema de ícones de arquivo do VS Code (o `meowsystem` tem; o Dracula não declara `vscode-icones`).
2. Ícones de arquivo e preset do prompt herdados: funcionam na paleta, sem desenho próprio.
3. Cinco campos declarados no `pack.json` que nenhum código lê: `paleta.acentos`, `icones.apps.camada`,
   `icones.pastas.recolorir`, `origens.wallpapers.tipo`, `origens.wallpapers.se_vazio`.
4. Apps do nitro-5 sem desenho: Dédalo, FogStripper, Pipeline EducaDados.
5. Discord oficial não carrega tema; entra com cliente modificado (Vencord, Vesktop, BetterDiscord).
6. Cor do Catppuccin cravada em código, que aparece com o Dracula no ar: o menu do `meow` saiu na P298; sobram
   `gerador_circulo.py`, `btop-bat/manifesto.sh`, `spotify/acento.py`, `vidro.sh`, `afinar_conversor.py` e a reserva
   do `_tinta_do_traco`.

## Falta nos dois
1. Apps instalados sem módulo de tema: GIMP, VLC, GitHub Desktop (portátil), Foundry VTT e ghostwriter (nitro-5),
   Godot e o cliente da Steam (MeowSystem).
2. Capturas de tela na vitrine do pack (o painel mostra 0).
3. Firefox sem perfil no MeowSystem e no portátil: o tema entra sozinho quando o perfil existir.

## Decisões que são de quem usa
- Quais desenhos entram (Viewer, Câmera, VLC e os demais) e em que estilo.
- Se o `meowsystem` passa a declarar ponteiro e ícones-base por flavor.
- Se os cinco campos sem leitor do Dracula ganham código ou saem do `pack.json`.
