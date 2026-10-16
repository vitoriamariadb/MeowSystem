# Fechamento da leva H — 16/10/2026

Branch `integracao/leva-h`, worktree `.wt-meow/integracao-h`. O `dev` não foi tocado. Este arquivo
fecha o bloco: o que a leva entregou, o QA de uso real final, as duas suítes, o que se confere à
mão e o que é decisão de quem usa.

## O que a leva H entregou

| sprint | o quê | onde está o detalhe |
|---|---|---|
| P81 | o compositor e o `cosmic-files` recompilam sozinhos, pela mesma função (`garantir_builds`) nos três gatilhos: pós-apt, login e o doctor das 5h | [P81](P81-build-sempre.md) |
| P84 | os 39 PNG feitos à mão viraram vetor, medidos por RMSE; o seletor os oferece sem a trava de raster | [P84](P84-png-para-vetor.md) |
| P82 | os abertos do uso real, em seis áreas, com as decisões 13 a 49 | [P82](P82-abertos.md) |
| P83 | a documentação do produto de hoje: o índice de P1 a P89, os dois README, PACKS, FRONTEIRA, COSMIC-THEMING, MANUTENCAO e o ESTADO-FINAL | [P83](P83-documentacao.md) |
| P85 | a série do compositor rebaseada para o 4d14528 (já vinha na branch, do `dev`) | [P85](P85-serie-no-4d14528.md) |

A ordem dos merges e a correção da integração estão em [01-integracao.md](01-integracao.md).

## O QA de uso real final

Painel da integração numa casa temporária: cópia de `~/.config/meow`, `~/.config/cosmic`,
`~/.local/share/icons`, `~/.local/share/backgrounds` e `~/.local/share/applications` (os originais
só lidos), falsos que recusam no PATH (sudo, pkexec, su, apt, cargo, curl, git de rede, systemctl
de escrita…), sem barramento da sessão. Prints em `.playwright-mcp/ux-h/` do checkout principal.

**O que passou sem defeito:**
- as 14 páginas a 1440 e a 375 px, sem erro no console;
- o seletor de ícone: as pastas de todos os packs, a busca, os 39 vetores da P84 sem trava, e
  «Usar este ícone» gravando só no `icones-escolhidos.map` da casa temporária;
- trocar para o Catppuccin e voltar ao Dracula: o conf volta ao mesmo efeito, e nenhuma escrita
  escapou dos falsos;
- o modo de leitura: «Restaurar ao padrão», a prévia «Como está / Como fica» e o «Aplicar»;
- o papel de parede: favoritar, «Usar», e a gaveta dizendo «trocou»;
- «Conferir a máquina»: o compositor aparece como estado (o shim, a versão e a série).

**O que achei e corrigi:**

| item | commit | defeito, como quem usa viu | agora |
|---|---|---|---|
| 1 | `32561d0` | a senha do askpass estava escrita na decisão 5, contra a regra S1 | a decisão fica, a senha sai |
| 2 | `321cf5e` | os vetores da P84 mostravam «Calendario», «Gerenciador de extensoes», «File Zilla», e a busca «visualizador» não achava o `visalizador-de-imagens` | o vetor tem o nome certo, e um `catalog.json` na pasta dá o nome em português e o texto da busca |
| 3 | `bfdedbe` | a pendência do menu de papel de parede, enquanto compila, aparecia como «Files_menu.sh» | aparece como «Construir o menu da área de trabalho» |
| 4 | `af722a3` | «Nada esperando» logo abaixo de «2 coisas esperam um clique» | «Nada por salvar» |
| 5 a 8 | `eb3353d`, `5c6fbd2`, `8782162`, `4d5a590` | seis linhas mandavam digitar: «rode: meow doctor --consertar», «'meow doctor --consertar' os escreve», «rode uma vez no terminal: ./install.sh», «rode 'meow ativar' com sudo disponível», «MIDIA_COMPILAR=1 /caminho/do/clone/…» e «ou agora, com 'meow wallpaper carrossel'» | cada uma diz o estado, ou o botão do painel |
| 9 | `92a8818` | — | as seis formas entram no `nada-manda-digitar.sh` (provado: o `wallpaper.sh` antigo deixa o teste vermelho, e o restaurado volta ao verde); a seção 2 deixava uma `/tmp/tmp.*` por rodada e agora a apaga |
| 10 | `4d6ee21` | o `doctor-so-le.sh` reconhecia o fim do doctor pela frase antiga | reconhece pela nova |
| 11 | `38bd420` | cada rodada da suíte deixava uma `/tmp/tmp.*` vazia: o gate para o `meow pack usar` pelo «Parar», e a cópia do conf (um `mktemp -d`) ficava | a cópia sai mesmo com a troca parada; o `casa-real.sh`, seção 3b, para a troca aos 0,3, 1 e 2 s e confere o TMPDIR (vermelho antes, verde depois) |

Prints do depois: `corrigido-01-inicio.jpg` a `corrigido-04-conferir.jpg`.

## As duas suítes

Duas rodadas seguidas do `tests/todos.sh` inteiro, no `38bd420` (o item 11 já dentro), cada uma
com a casa de brinquedo nova que o runner cria. Por fora do runner, um PATH sem barramento da sessão
e com falsos que recusam `cargo`, `just`, `make` e `rustup`.

| rodada | resultado | os gates de navegador |
|---|---|---|
| 1 | **64 testes: 63 verdes, 1 pulado, 0 vermelhos, rc=0** | `app-completo.py` 696 s, `app-uso-real.py` 89 s, `gate-link-externo.py` 4 s |
| 2 | **64 testes: 63 verdes, 1 pulado, 0 vermelhos, rc=0** | `app-completo.py` 704 s, `app-uso-real.py` 89 s, `gate-link-externo.py` 3 s |

- O pulado é o `conversor.sh` nas duas: falta o `catppuccin-apps/macchiato/spotify.png`, que não
  é versionado.
- Nas duas, os falsos recusaram 6 chamadas de sudo (`sudo -n true` e o `estado` da ponte) e 3
  escritas de busctl. O `cargo` foi chamado 10 vezes por rodada (o build dos dois applets), e
  recusou todas.
- Não sobrou nenhuma `/tmp/tmp.*` nem `/tmp/meow-completo-*`. A árvore ficou limpa.

**Antes delas, uma rodada de descoberta** (no `92a8818`, antes do item 10) deu 60 verdes, 2
pulados e 2 vermelhos:
- `doctor-so-le.sh` procurava a frase antiga do doctor. Curado no item 10.
- `notas-de-funcao.sh` ficou vermelho porque eu fiz um commit enquanto ele rodava («o teste mexeu no
  repositório»). Sozinho, ele passa. Não é defeito do produto.
- `restos-do-painel.sh` saiu pulado porque o PATH do envoltório não tinha o `node`. Com o `node`
  no PATH, ele passou nas duas rodadas.

Depois dessa rodada, as duas seguintes (no `4d6ee21`) também deram 63 verdes, mas cada uma deixou
uma `/tmp/tmp.*` vazia. Achei a causa com um `inotifywait` em `/tmp` durante o gate. Ela virou o
item 11, e por isso as duas rodadas valem a partir dele.

## O que quem usa confere à mão

1. **Depois que o build em curso terminar, rodar o `install.sh` uma vez** (instala o
   `meow-builds-login.service` da P81 e reinstala a ponte, P82 item 16).
2. **O compositor no 4d14528:** depois do primeiro gatilho, `MEOW_SHIM_SO_DIZER=1
   ~/.local/bin/cosmic-comp` diz o build da casa, e não o `/usr/bin/cosmic-comp`.
3. **No painel:** Ícones → um programa → «feitos à mão» mostra «Calendário» e «Visualizador de
   imagens»; a Início diz «Nada por salvar».
4. **Depois do próximo boot:** o compositor na RTX (decisão 6).

## O que é decisão de quem usa e ficou

- **A senha do askpass no histórico do `dev`.** O commit `63ed2ca` (`docs(sprints): estado - leva H
  em voo, askpass e shim`) tem a senha em texto. Nenhum remoto o contém hoje. Antes de publicar o
  `dev`: reescrever esse commit, ou trocar a senha. A escolha é de quem usa.
- **`NOPASSWD: ALL` no sudoers da conta**, desde abril. Com a ponte e o askpass, o MeowSystem não
  precisa dele; o doctor só diz o estado (decisão 48 da P82).
- **A GPU do compositor na RTX** (decisão 6): aplicada em 15/10, vale no próximo boot. A volta é o
  `Migração-OS/scripts/gpu-2026-10-09/reverter.sh --restaurar <backup> --aplicar`.
- **O checkout do `dev` tem `.gitignore` e `packs/dracula/icones/pastas/folder-download.svg`
  mudados sem commit** (visto no começo desta sessão). O merge da integração no `dev` precisa saber
  o que fazer com eles.

## Ficou aberto, com dono

- **Ainda há cerca de 35 linhas que mandam digitar** fora do caminho que o QA percorreu: as razões
  do `SEM_CONSERTO` (`rode: meow ativar`, `rode: ./install.sh`), o `lib/desinstalar.sh` (`rode: sudo
  rm -f …`), o `prompt.sh`, o `completar_icones.sh`, o `icones_absolutos.sh`, o `nomes_apps.sh`, o
  `wallpaper.sh` (`rode: meow wallpaper aplicar`) e o `install.sh` sem systemd (`troque na mão com
  'meow logo'`). A lista sai de um `grep -nE "(rode|digite|_COMPILAR=1 )"` nas mensagens de
  `scripts/`, `lib/`, `bin/meow` e `install.sh`. Dono: o próximo bloco (P86, item 3, «nenhuma saída
  manda digitar»).
- **A pendência `instalar-com-root` leva ao «Instalar tudo»**, e o painel não tem terminal para pedir
  a senha. Nesta máquina o `NOPASSWD` esconde isso. Numa conta sem ele, o botão roda sem a ponte
  e a pendência volta. O askpass ativo (decisão 5) é o caminho (`sudo -A` quando não há terminal),
  mas ele mexe na segurança. Dono: o próximo bloco, com a palavra de quem usa.
- **A prévia fixa no topo cobre parte dos cartões ao rolar**, também a 1440 px (já registrado a 375 px
  na P80).
- **P86 a P89** estão escritas e não implementadas (o índice está em `docs/SPRINTS.md`).
