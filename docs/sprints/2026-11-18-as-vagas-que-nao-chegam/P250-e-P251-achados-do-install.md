# P250 e P251 — o que o install de 18/11 nos PCs da Vitória mostrou (18/11/2026)

## P250 — o `git pull` cria um commit local com a captura do README
- **O que se mediu (portátil, 18/11 15:26):** o `git pull --ff-only` do `23e2a859` para o `9ed03775` terminou com
  «readme: regerado no commit a36f51e1». O commit, feito pelo gancho pós-merge com a identidade da máquina, só troca
  `docs/capturas/readme/modificacoes.png` (98320 → 98014 bytes) e deixou o `master` de lá 1 à frente do
  `origin/master`. O coordenador o desfez com `git reset --keep origin/master` (o commit segue no reflog de lá). No
  desktop, o pull de 1 commit de documentos não criou commit.
- **A causa (a provar):** a captura do painel sai com bytes diferentes em cada máquina, e o gancho pós-merge
  (`scripts/gancho-post-merge.sh`, decisão 45) roda em todo checkout que tem os ganchos, não só no de quem integra.
  Um checkout com commit local não aceita o próximo `git pull --ff-only`.
- **A cura na origem:** o gancho só faz commit quando o que mudou é texto que vem do código; a captura só entra se a
  diferença de imagem passa de um limiar medido, ou só na árvore de integração. Decidir qual das duas com a medida.
- **Como se prova:** teste em `tests/ganchos.sh`: merge que não muda o que o README lê não cria commit; captura com os
  mesmos pixels e bytes diferentes não cria commit.
- **Nos três PCs:** resolve nos três; hoje todo pull pode deixar o checkout à frente do tronco.

## P251 — o portal de captura não tem build nos PCs da Vitória
- **O que se mediu (18/11):** desktop: «o build do portal 1.11.0~1792525517~24.04~f448ddf+0~hefesto1 está de lado
  (caiu) — o portal do pacote segue valendo». Portátil: `graficos_estado=nao-encaixa` para o
  `xdg-desktop-portal-cosmic` `1.11.0~1794346005~24.04~6e68360`. nitro-5: sem queixa no doctor.
- **A causa (a provar):** no portátil, a série `patches/graficos.series` não entra na versão nova do portal; no
  desktop, o build entrou e caiu repetido ao subir, e o shim o pôs de lado. A versão do desktop traz `+0~hefesto1`:
  não é o pacote do Pop!_OS.
- **A cura na origem:** rebase da série para a versão do portátil (ou `fim <versão>` no `patches/graficos.versao`, se
  ela já traz a correção oficial dos #286 e #384); no desktop, ler o registro da queda antes de decidir.
- **Como se prova:** `tests/graficos.sh`, `tests/graficos-fonte-real.sh` e `tests/patch-que-sobe.sh` verdes;
  `scripts/garantir_builds.sh estado` com `graficos_estado=ok` nos três; compartilhar tela no palco.
- **Nos três PCs:** desktop e portátil. nitro-5 já tem o build.

- **Medida de 18/11 21h55 (`scripts/garantir_builds.sh estado`, só leitura):** nitro-5 `graficos_estado=ok` com o
  pacote `…1792525517~24.04~f448ddf`, a versão do `patches/graficos.versao`; desktop `graficos_estado=falhou` com
  `…f448ddf+0~hefesto1`; portátil `graficos_estado=nao-encaixa` com `…1794346005~24.04~6e68360`.

## Para o conferente do bloco A
O `packs/meowsystem/icones/sistema.map` liga `soneca-desperto-symbolic` e `soneca-ronronar-symbolic` a `soneca-desperto`
e `soneca-ronronar`, e `packs/meowsystem/icones/sistema/` não tem esses dois arquivos: nos PCs da Vitória a Soneca usa
o SVG do applet, no `hicolor`. Conferir se é a intenção da decisão 59 ou linha de mapa sem desenho.
