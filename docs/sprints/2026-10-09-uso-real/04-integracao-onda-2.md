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

## P79 — a casa real — 10/10/2026

Merge `4e98e52` da `sprint/p79` (`ef309f8`, 25 commits, 7 deles do conferente) sobre o
`bb7f29b`. Sem conflito: o `bb7f29b` é a base da própria `sprint/p79`. São 32 arquivos, com
1605 linhas a mais e 125 a menos. A integração não precisou de commit de código.

**Veredito:** a P79 entra. **A suíte inteira roda com 57 verdes, 2 pulados por ambiente e
1 vermelho, que é intermitente e já existia antes da P79.** O gate repetido sozinho, inteiro,
passa.

### O que entrou

1. **Decisão 9.** A extensão do VS Code de pack importado só entra por gesto explícito. O
   gesto instala pelo id, da loja oficial, e a URL e o sha256 do pack são ignorados. O
   servidor só aceita um id da lista que o pack no ar pede.
2. **Decisão 10.** O «Restaurar ao padrão» grava o `item.padrao` e o vazio vira «Não tocar».
   O ponteiro usa o `padrao_do_pack`, com a mesma régua da troca de pack, e a grade dele tem
   «Não tocar».
3. **Decisão 11.** A caixa do sudo ficou em uma linha, e o porquê foi para a dica.
4. **Casa real.** O vestígio de outro pack (`ICONES_FLAVOR`, `CURSOR`, `ICONES_PASTAS`) volta
   ao pack no ar, e a troca de pack leva o ponteiro e as pastas junto. A variante do próprio
   pack continua sendo uma escolha de quem usa.
5. **Nada manda digitar.** O `pkill`, o `sudo -v` e os builds viraram a ação feita ou o botão
   que a faz. A pendência `leitura-applet` sai quando `LEITURA_APPLET="nao"`.
6. **Achados técnicos.**
   - O mapa CRLF não perde linhas.
   - O BOM não esconde o `#!`.
   - O vidro lê o `MEOW_COSMIC_DIR`.
   - Com `LOGO_MODO` vazio, a moldura do gato usa o modo que vale.
   - O papel de parede ganhou a estrela de favoritar.
   - O «Créditos» do gate aguenta a repintura.

Testes novos: `casa-real.sh`, `nada-manda-digitar.sh`, `achados-tecnicos.sh` e o
`gate-link-externo.py`. A `temas-de-apps.sh`, a `restos-do-painel.sh`, a `pack.sh`, a
`instalacao.sh` e o gate cresceram. O `todos.sh` foi de 56 para 60.

### Testes

O ambiente é o da onda 2. Cada rodada tem um HOME temporário novo e roda sem
`DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` e `DISPLAY`, então nenhum
teste alcança os serviços nem a tela de verdade. Os falsos à frente do PATH registram e
recusam: `sudo`, `pkexec`, `su`, `pkill`, `kill`, `killall`, `notify-send`, `systemd-run`,
`loginctl`, `apt`, `apt-get` e `xdg-open`. O `systemctl`, o `gsettings` e o `dconf` só deixam
passar a leitura. O Playwright vem do Python do pyenv (3.12.1).

**Rodada 1:** 57 verdes, 2 pulados e 1 vermelho, o `convergencia.sh`. O gate passou em 650 s.
- O vermelho veio do meu falso, e não do código. O `systemctl` falso respondia 0 ao
  `enable`, enquanto o `is-enabled` real, sem barramento, dizia «não». As etapas dos serviços
  apareciam como `mexeu:` em toda passagem.
- Prova: com o falso recusando (rc=1), o teste sozinho converge em 3 passagens. Sem o falso,
  também.

**Rodada 2, com o falso recusando:** 57 verdes, 2 pulados e 1 vermelho. O `convergencia.sh`
passou em 103 s. O vermelho é o gate, em 685 s, com uma reprovação: «O que a atualização
mudaria» terminou em «SAIU NULL · 0S».
- A causa é uma corrida no `Trabalho` do `app/servidor.py`, e não a P79, que não toca essa
  classe. O `vivo()` pergunta ao `proc.poll()`, mas o `rc` e o `fim` só são gravados depois,
  pela thread `_ler`. Se a página pergunta nesse intervalo, recebe `vivo: false` com
  `rc: null`, e os segundos medidos são `time.time() - comeco`, perto de 0.
- O script dessa ação é rápido e não mudou.
- Depois disso:
  - a aba Atualização sozinha passou 3 vezes em 3;
  - o gate inteiro, sozinho, deu rc=0 em 646 s, com 730 controles, 628 acionados, 2259
    conferências e o console limpo.

**Pulados (ambiente):** o `pack.sh`, porque falta o `Dracula_OS-Theme` no HOME de brinquedo,
e o `conversor.sh`, porque falta o Papirus. Na corrida do conferente, com o HOME de onde o
`Dracula_OS-Theme` é lido, o `pack.sh` passou.

**sudo:** 6 chamadas por rodada (4 `sudo -n true` e 2 `ponte_root.sh estado`). Todas foram
recusadas pelo falso.

**Escritas paradas no falso:** `systemctl --user enable` e `daemon-reload`, `gsettings set`,
`systemd-run` (build do files-menu) e `notify-send`.

**HOME real:** rodei um `find -newer` a partir do início da rodada 1 nas mesmas pastas da onda
2 e em `~/.local/state/meowsystem` e `/etc/apt/apt.conf.d`. Só mudaram o `wallpaper.log` e o
`wallpaper-vistas.txt`. Quem os escreveu foi o `meow-wallpaper.service` real da máquina, às
11:12:13, pelo journal; nenhum teste escreveu ali.

O painel de pé na integração (PID 4067964, HOME `scratchpad/uso-final`) é de 07:04, de antes
desta integração. Ele é de quem coordena e não foi derrubado. Ele lê do disco os arquivos da
página, que agora são os da P79, mas o `servidor.py` dele continua o que foi carregado às
07:04.

### Aberto, com dono

1. **A corrida do `Trabalho.vivo()`** deixa o gate intermitente: «saiu null · 0s» numa ação
   rápida. Dono: **próxima leva**. A cura na origem é o `vivo()` responder pelo desfecho
   gravado (`self.fim is None`), e não pelo `poll()`. Para provar, monte no
   `app-navegador.py` uma pergunta entre o fim do processo e o `rc`.
2. **O gate falhou uma vez na corrida do conferente e passou em seguida.** Foram três ações
   do «⋯» de Lançadores e jogos, com «nunca apareceu». Pode ser a mesma família de corrida, e
   não está provado. Dono: **próxima leva**.
3. **Ainda há linhas mandando digitar.** Dono: **próxima leva**.
   - O «resolve: <comando>» de toda pendência.
   - O `meow wallpaper permitir`.
   - O «instale com rustup e rode o install.sh de novo» do `leitura_build.sh`.
4. **Uma instalação pode reciclar o painel até três vezes.** O arcticons, o dracula e os
   resgatados chamam o `meow_tela_reler`, cada um. Dono: **próxima leva**.
5. **Trocar do Catppuccin de fábrica para o Dracula muda o ponteiro para `Dracula-Cursor`,**
   que baixa da rede. Segue o «o pack decide» da spec, mas muda o comportamento. Dono:
   **decisão de quem usa**.
6. **O `convergencia.sh` depende do falso do `systemctl`.** Um falso que finge escrever deixa
   o teste vermelho. Os itens da onda 2 não registram como era o falso da rodada verde.
   Dono: **quem escrever o próximo roteiro de suíte**. O falso de escrita tem de recusar
   (rc≠0), como o `sudo`.

Da lista «Aberto» da onda 2, a P79 fecha os itens 2, 3, 4 e 5 e a decisão do item 1. Os itens
6 (restos fora da integração) e 7 (o dev conflitar nas specs P73/P74) continuam como estavam.

### O que quem usa confere com a mão

1. **No painel com um HOME de teste e o Dracula no ar**, faça os três gestos do ponteiro:
   - «Restaurar ao padrão» grava o ponteiro do Dracula, e não o `catppuccin-mocha-light`;
   - «Não tocar» aparece na grade;
   - a troca para o Catppuccin leva o ponteiro e as pastas junto.
2. **Com um pack importado que tenha `apps.vscode`:** sem o gesto nada instala, e a pendência
   mostra o id exato que vai ser instalado.
3. **A caixa do sudo** ocupa uma linha, e o «?» abre o porquê.
4. **Na casa real, rode `meow doctor` sem `--consertar`.** A linha `conf` só acusa o
   `ICONES_FLAVOR` (macchiato → o flavor do pack).
