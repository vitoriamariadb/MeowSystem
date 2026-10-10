# Integração da onda 2 — P78 e P77 — 10/10/2026

Branch `integracao/leva-g`, a partir do `af3159f`, na worktree
`~/Desenvolvimento/.wt-meow/integracao`. O dev e o checkout principal não foram tocados.

**Veredito:** os dois blocos entraram sem conflito de texto. Achei 3 defeitos, todos corrigidos e
provados vermelhos antes e verdes depois. **A suíte inteira fica verde: 56 testes, 54 verdes,
2 pulados por ambiente e 0 vermelhos.** O gate `app-completo.py` e o `app-uso-real.py` passam.
Os 3 vermelhos que a onda 1 deixou também saíram: o gate, o `portabilidade.sh` e o
`doctor-so-le.sh`.

## O que entrou

| ordem | merge | bloco | conflito |
|---|---|---|---|
| 1 | `8e0f202` | P78: segurança e gate (pack é dado e nunca código, CSP em toda imagem, decisões 7 e 8) | nenhum |
| 2 | `9f75ebf` | P77: a interface mostra (sem texto, a régua do texto visível, o gate de uso real) | nenhum, nem de texto em `servidor.py` e `app.js`, que os dois tocam |

Os dois blocos tocam os mesmos 8 arquivos: `servidor.py`, `app.js`, `vidro.sh`, `bin/meow`, os
manifestos do kitty e do GNOME Terminal, `app-completo.py` e `todos.sh`. Li os dois lados de cada
um, procurando conflito de sentido:
- a CSP da P78 fica no `_responder` e cobre toda imagem, inclusive as da P77; nenhuma rota nova
  escreve `Content-Type` por fora dele;
- o filtro de cor do kitty e do GNOME Terminal (P78) convive com a troca de «dela» por «seu» (P77);
- o ensaio do `vidro.sh` (P77) convive com o `python3 -I` (P78);
- a trava da decisão 8 no `run.sh` (P78) não barra nenhum teste novo da P77.

Os commits da própria integração:

| commit | defeito | prova |
|---|---|---|
| `2c26af8` | O `tests/app-texto-visivel.py` chegou da P77 executável e sem classificação no `todos.sh`. Com isso a guarda do runner saía 2 **antes de rodar qualquer teste**, já na `sprint/p77` | antes: «FALHOU: teste sem classificação em tests/todos.sh: app-texto-visivel.py». Depois, a suíte roda os 56. Ele entra em MAQUINA, fora do SEM_PULO, porque o próprio cabeçalho diz «não é gate, é a régua» |
| `a93ff98` | **Conflito de sentido entre P77 e P78.** A P77 pôs na gaveta uma terceira porta do «Consertar o que estiver fora». A P78 (decisão 7) passou a declarar `rede: True` nessa ação e pôs o selo «baixa da internet» só nas duas portas que existiam. A porta nova baixava sem selo, e o gate não via, porque conferia o selo depois do clique, quando o botão da gaveta já sumiu. Agora o selo aparece logo depois do botão e sai junto com ele, e o gate confere a porta da gaveta antes do clique | `--aba Início` com o gate novo e o `app.js` de antes: rc=1, «"Consertar o que estiver fora" na gaveta mostra o selo… » reprovado. Com o `app.js` novo: rc=0, «todos os controles acionados, console limpo» |
| `1af83ad` | **Vermelho que veio da P77**, e não da integração. O `1141764` (QA, item 1b) faz o «Restaurar ao padrão» do deslizante só nascer sobre uma escolha. Na casa de fábrica do `app-navegador.py` ele some, e o teste ainda cobrava `restaurar > 0`. O relatório do QA dizia 156/156, mas essa medida é de antes do 1b | exportação do `7ecd63d` (antes do 1b): 156/156, «(0 contra 1)». `sprint/p77` e integração: 155/156. Agora o teste cobra a regra da P77 (nenhum dos dois botões sobre o valor de fábrica): 156/156. O código de antes do 1b reprova a cobrança nova |

## Testes

Ambiente: HOME temporário novo por rodada, e falsos à frente do PATH que registram e não
executam: `sudo`, `pkexec`, `su`, `pkill`, `killall`, `notify-send`, `systemd-run`, `loginctl`,
`apt`, `apt-get` e `xdg-open`. O `systemctl`, o `gsettings`, o `dconf` e o `busctl` só deixam
passar a leitura. O Playwright vem do Python do pyenv (3.12.1). O `todos.sh` põe por cima a
casa de brinquedo dele.

**Depois do merge da P78:** `pack-malicioso`, `pack-dracula-completo`, `sem-dracula-os-theme`,
`doctor-so-le`, `temas-de-apps`, `fonte-unica`, `flavor-padrao`, `sem-receita-no-log`,
`git-limpo`, `portabilidade`, `numeros` e `vidro-do-cosmic` passaram, e o `pack.sh` saiu pulado
(ambiente).

**Depois do merge da P77:**
- Verdes: `app.sh`, `leitura-fonte-unica`, `vidro-do-cosmic`, `frases-velhas`, `notas-de-funcao`,
  `estilo`, `temas-de-apps`, `pack-malicioso`, `numeros`, `portabilidade` e `git-limpo`.
- `app-uso-real.py`: 14 páginas, 0 defeitos.
- Gate `app-completo.py`: rc=0 em 637 s, com 716 controles, 621 acionados e 2203 conferências.
- `app-navegador.py`: 155/156, o vermelho do `1af83ad`.

**Suíte inteira no `1af83ad`, `./tests/todos.sh`:** 56 testes, 54 verdes, 2 pulados, 0 vermelhos.
- **Pulados:** o `pack.sh` (falta o `Dracula_OS-Theme` no HOME de brinquedo) e o `conversor.sh`
  (falta o Papirus). Os dois são de ambiente.
- **Gates:** o `app-completo.py` passou em 663 s e o `app-uso-real.py` em 43 s.
- **sudo:** 6 chamadas (4 `sudo -n true`, 2 `ponte_root.sh estado`), e nenhuma chegou ao sistema.
- **Escritas paradas no falso:** `systemctl enable --now`, `daemon-reload`, `gsettings set`,
  `systemd-run` (build do cosmic-files) e `notify-send`.

**HOME real:** fiz um `find -newer` a partir do início da sessão em `~/.config/meow`,
`~/.local/share/icons`, `~/.local/bin`, `~/.config/systemd/user`, `~/.config/cosmic`,
`~/.local/libexec`, `~/.config/kitty`, `~/.local/share/applications`, `~/.config/Code`,
`/usr/local/lib/meowsystem` e `/etc/sudoers.d`. Saiu vazio. Nenhum painel meu ficou de pé.

## Aberto, com dono

1. **O VS Code instala a extensão que o pack nomeia** (P78, gravidade alta). Dono: **decisão de
   quem usa**. O sha256 vem do próprio pack: prova integridade, não confiança. Um pack de terceiro
   escolhe código que roda a cada abertura do editor. As opções:
   - só pack do motor instala extensão;
   - uma lista fechada de publicadores;
   - a pergunta da P46.
2. **O nome do «Restaurar ao padrão»** nas chaves com padrão de fábrica preenchido
   (`RELOGIO_SEGUNDOS`, «Janelas lado a lado», `LEITURA_AGENDA`). Fora do padrão, o botão grava
   vazio («não toca») e mostra o valor da máquina no parêntese. Dono: **decisão de produto**, e
   depois a próxima leva. As saídas possíveis:
   - dois gestos com dois nomes;
   - o botão grava `item.padrao`.
3. **Casa real** (achados do QA da P77). Dono: **doctor / próxima leva**, com decisão de pack
   no primeiro item.
   - `ICONES_FLAVOR="macchiato"` com o Dracula no ar.
   - Trocar de pack deixa `CURSOR` e `ICONES_PASTAS` no Dracula.
   - O `CosmicBackground` aponta para uma pasta, e o doctor não acusa.
4. **Saídas que ainda mandam digitar** (`pkill`, `sudo -v && ./install.sh`,
   `meow files-menu build`) e a caixa do sudo com parágrafo de 4 linhas. Dono: **próxima leva**.
   O texto da caixa é decisão de quem usa.
5. **Achados técnicos.** Dono: **próxima leva**. Estão listados nas specs: P78 e P77, em
   «Achados para a próxima leva».
   - Mapa CRLF perde as linhas.
   - O `_proibido` não vê o BOM antes do `#!`.
   - O `vidro_janela.py` ignora o `MEOW_COSMIC_DIR`.
   - O `LOGO_MODO=""` deixa a moldura do gato vazia.
   - O «Créditos» do gate é intermitente.
   - Não há gesto de favoritar papel de parede.
6. **Restos fora desta integração.** Dono: **quem usa**.
   - O painel PID 1985165, do checkout principal, que é de 09/10 e não foi derrubado.
   - O arquivo `mktemp` que um teste da trava da P78 deixou em `/tmp`.
7. **O dev vai conflitar** nas specs P73/P74 (onda 1, item 3), se o dev ainda não recebeu a
   onda 1. Dono: **quem fizer o merge no dev**.

## O que quem usa confere com a mão

1. **Decida o item 1** (extensão do VS Code). Até lá, pack de terceiro com `apps.vscode` instala
   extensão sem perguntar.
2. **Na Início, aperte «Conferir a máquina».** Com divergência, a gaveta oferece «Consertar o que
   estiver fora» com o selo «baixa da internet» ao lado, e o botão da Início também tem o selo.
   Faça isso com um HOME de teste: o conserto escreve e baixa.
3. **Passe pelas 14 páginas a 1440 px e a 375 px.** Confira que quase não há texto, que o `?` abre
   a dica e que nenhum «Restaurar ao padrão» aparece sobre valor que já é o de fábrica.
4. **Antes do merge no dev, os itens 1 e 2 da conferência à mão da onda 1** (`03-integracao-onda-1.md`):
   - a escolha do ghostwriter;
   - o `.gitignore` sujo.

   Depois do merge, rode `./install.sh` uma vez.
5. **Num terminal kitty com um pack de terceiro**, confira que o tema troca as cores e que linha
   que não é cor é avisada e pulada.
