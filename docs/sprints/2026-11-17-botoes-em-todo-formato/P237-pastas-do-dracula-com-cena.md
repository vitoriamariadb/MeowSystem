# P237 — as pastas especiais do Dracula ganham cena (17/11/2026)

Texto de quem usa, 17/11: «nossos ícones de pastas do dracula a exceção do gerenciador de arquivos as demais são
muito sem graça. pode melhorar elas?»

## O que se mediu (coordenador, 17/11)
`packs/dracula/icones/sistema/`: o `folder.svg` comum tem cena (casa assombrada, lua cheia, morcegos sobre o corpo
escuro com borda roxa, a borda nítida do P208). As nove especiais (`folder-documents`, `-download`, `-music`,
`-pictures`, `-publicshare`, `-templates`, `-videos`, `user-home`, `user-desktop`) repetem o corpo cinza-ardósia
com um glifo genérico chapado no meio (folha, seta verde, nota, montanha, globo, dois quadrados, play, casa,
monitor). Mapa: `icones/pastas.map`.

## A cura na origem
Só `packs/dracula/` (os nove SVG e o `PROCEDENCIA.md`). Cada pasta mantém o corpo e a borda do `folder.svg` (mesma
silhueta, mesmo peso de borda) e troca o glifo por uma cena pequena no traço da casa assombrada (silhuetas com
duas ou três cores da paleta, lua ou brilho de destaque), lendo o papel da pasta de longe:
1. Documentos: grimório aberto com uma vela.
2. Downloads: morcego mergulhando com a seta formada pelas asas.
3. Música: órgão de tubos (ou violino com arco) com notas no ar.
4. Imagens: retrato em moldura gótica com a lua.
5. Público: corvo mensageiro com uma carta no bico.
6. Modelos: moldes de vela e um castiçal (o molde que se repete).
7. Vídeos: lanterna mágica projetando um morcego.
8. Pasta pessoal: o castelo na colina com uma janela acesa (o «lar»).
9. Área de trabalho: espelho gótico de moldura ornada.
Desenho original, nada copiado. A cena lê em 32 px (dock e diálogo) e não vira mancha em 16 px; em 16 px, se
precisar, a cena simplifica para a silhueta principal, sem trocar o corpo.

## Como se prova
`tests/icones-do-sistema.sh`, `tests/desenho-no-pack.sh`, os de procedência e o que cobre a borda da P208
(`tests/app-completo.py` olha a pasta com borda); folha antigo × novo em 16, 32, 48 e 96 px no fundo escuro e no
claro, lado a lado com o `folder.svg` e o ícone do Gestor de Arquivos, para quem usa aprovar antes do merge.
