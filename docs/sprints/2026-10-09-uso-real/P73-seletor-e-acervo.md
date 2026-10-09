# P73 — O seletor de ícone mostra o acervo inteiro, em pastas

**Branch:** `sprint/p73` · **Fontes:** `docs/pesquisas/2026-10-09-paridade-de-icones.md` (T1–T5),
`01-regressoes.md` (I3, I4, I8, I9), `00-achados-como-usuario.md` (1, 2, 7, 24), `02-decisoes.md` (2, 3, 4).

## Pedido de quem usa (09/10)
«Era pra aparecerem todos os Drácula feitos e todos os do MeowSystem feitos, numa pasta cada.
Independente do app que eu escolher, eu deveria acessar todas as imagens disponíveis, não só as
que mapeamos à mão.» «Sem texto na interface; no máximo vira dica.»

## Tarefas
1. **T1** — fim do teto de 60 por grupo (`servidor.py` ~9174); a ficha abre sem filtro pela 1ª
   palavra (`app.js` ~2981); grupos = pastas por acervo, com contagem, rolagem/paginação e o pack
   no ar primeiro.
2. **T2** — o motor lê todas as pastas (inclui `resgatados/`, `arcticons/`, autorais de todos os
   flavors, `-alucard`). Decisão 3: acervos de TODOS os packs aparecem, cada um na sua pasta.
3. **T3** — busca pelo nome do app (comentário do `apps.map`) e pelo significado (`catalog.json`
   do Dracula_OS-Theme trazido para `packs/dracula/icones/biblioteca/`, linha no PROCEDENCIA.md).
4. **T4** — apps com trava (COSMIC, Hefesto, Fogstripper, mozc): o acervo aparece, e a trava é
   estado visual + dica, não grupo sumido.
5. **T5** — os 175 SVG de `Dracula_OS-Theme/src/icons/current/scalable/apps` entram na biblioteca
   (sha256, PROCEDENCIA). Decisão 2: os 38+30 PNG feitos à mão entram como PNG agora (pasta própria).
   Decisão 4: `calcdeirao` fica fora; `jogos`, `rede`, `clima2` entram.
6. **I3** — escolher ícone no painel NÃO grava no repositório: a escolha vai para o estado do
   usuário (`~/.config/meow/…`); gravar no pack só por gesto explícito («Levar para o pack»).
   Reverter o ` M packs/dracula/icones/apps.map` do dev que o painel sujou.
7. **I8** — syncthing, spotify, discord: os resgatados aprovados entram nos mapas.
8. **I9** — o ícone do lançador do MeowSystem é o `logo.svg` do pack no ar.
9. **Achado 24** — a origem de cada ícone da grade (pack / nosso / traço / de fábrica) vira
   estado visual (selo, cor, agrupamento), sem frase; o «por quê» fica na dica.

## Prova
- teste novo: para cada pasta de acervo, total oferecido == nº de SVG/PNG da pasta (sha256);
  conta `versionados − oferecíveis` sobra só `pastas/`, `gatos/`, `logo.svg`.
- busca: «firefox» acha `net.waterfox.waterfox.svg`; «alienígena» acha `alien.svg`.
- `git status` limpo depois de escolher 3 ícones no painel (teste no repositório real, não em cópia).
- uso real no navegador com prints antes/depois: seletor de 3 apps, busca, troca de ícone.
