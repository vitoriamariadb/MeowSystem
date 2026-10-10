# Integração da P80 — acabamento — 10/10/2026

Branch `integracao/leva-g`, a partir do `47a487b`, na worktree
`~/Desenvolvimento/.wt-meow/integracao`. O dev e o checkout principal não foram tocados.

**Veredito:** a `sprint/p80` entrou sem conflito. A primeira dupla de suítes saiu com um vermelho
intermitente no gate (verde na rodada 1, vermelho na rodada 2). Achei a causa, que estava no
próprio gate e não no painel, e corrigi na origem. **A dupla refeita depois da cura sai verde nas
duas rodadas: 62 testes, 60 verdes, 2 pulados por ambiente, 0 vermelhos.**

## O que entrou

| ordem | commit | o quê | conflito |
|---|---|---|---|
| 1 | `5580d30` | merge da `sprint/p80` (28 commits até o `c46374e`): os 10 itens da spec, as 3 correções do conferente (itens 1 e 7) e as 6 do QA | nenhum |
| 2 | `e34845c` | integração: o gate espera a resposta do importar antes de contar o cartão do pack | — |

O que a P80 traz, em uma linha por item da spec:
1. a ficha de ícone mostra o nome do programa, e o nome inteiro fica na dica; o mesmo desenho tem
   o mesmo nome em toda pasta;
2. a paleta «Cor» só aparece com um traço marcado;
3. a pasta travada leva o selo de trava, e o porquê fica na dica;
4. Dia e noite usa o mesmo seletor de hora nas três linhas, na ordem começa | termina;
5. a fileira «Fundo» fica só em Cor e tela;
6. o `Trabalho.vivo()` responde pelo desfecho gravado, e o «saiu null» acabou;
7. a instalação e o `doctor --consertar` reciclam o painel uma vez só, no fim da passada (eram 4
   reciclos, agora é 1), e o `painel.sh reciclar` registra quem pediu;
8. as pendências apontam o botão que resolve; o papel de parede devolvido ganha «Era escolha
   minha»; o conserto instala o rust;
9. o `systemctl` falso do `convergencia.sh` recusa a escrita;
10. o «Usar este» de um pack que baixa mostra o selo «baixa da internet» (decisão 12).

O QA juntou: barra dupla em sete páginas, rótulo partido no meio da palavra, SVG com nome de PNG
(com leitor linear no lugar da regex que travava o servidor), «App do Chrome» no lugar do id,
«Criar a primeira área» apagada quando já há área, e a pendência já consertada saindo da lista.

## O vermelho intermitente, e a cura

**Sintoma.** Na rodada 2 da primeira dupla, o `app-completo.py` saiu `rc=1` com duas reprovações:
- `[Início › aba · Importar um pack] confirmar instala o pack, e ele ganha cartão na Início`;
- `[(fim)] o controle revelado «cartão de pack · Remover» (Início) apareceu e não foi acionado`.

A segunda mostra que o cartão nasceu, só que depois da conferência. Na rodada 1 o gate tinha
passado (643 s). Na rodada 2, com a máquina mais carregada, ele levou 702 s.

**Causa.** O pedido `POST /api/pack-importar` confirmado só nasce depois do `close` da caixa, num
salto assíncrono. O evento do pedido chega ao Python depois de o `assentar` olhar o
`pedidos_vivos`, que ainda diz 0. Enquanto o `meow pack importar` roda no servidor, o DOM fica
parado por 400 ms, e o `assentar` dá a página por assentada. Sobra a janela de 3 s do fim do
`assentar`, e uma instalação mais lenta passa dela: o gate conta os cartões antes de o servidor
responder. O painel estava certo, e quem errava a medida era o gate.

**Prova.**
- Com um `sleep 4` temporário na rota `/api/pack-importar` (só no confirmado), o gate
  `--aba Início` sai vermelho sempre, com as mesmas duas linhas.
- Com a cura e o mesmo `sleep 4`, ele fica verde: o gesto leva 9,7 s, e o cartão é contado depois
  da resposta.
- Sem o `sleep`, com a cura, também fica verde (5,8 s). O `sleep` foi tirado (`git checkout`) e não
  entrou em commit nenhum.

**Cura (`e34845c`).** O clique em «Importar» fica dentro de um `expect_response` do
`/api/pack-importar`, com teto de 130 s, porque o servidor dá 120 s ao `importar`. Só depois disso
vem o `assentar`. A mudança é só no `tests/app-completo.py`.

## As duas suítes

Ambiente de cada rodada:
- HOME temporário novo, criado com `mktemp -d`;
- sem `DBUS_SESSION_BUS_ADDRESS`, `XDG_RUNTIME_DIR`, `WAYLAND_DISPLAY` nem `DISPLAY`;
- falsos à frente do PATH que registram e não executam: `sudo`, `pkexec`, `su`, `kill`, `pkill`,
  `killall`, `notify-send`, `systemd-run`, `loginctl`, `apt`, `apt-get` e `xdg-open`;
- o `systemctl`, o `gsettings` e o `dconf` só deixam passar leitura;
- o Playwright vem do Python do pyenv (3.12.1);
- o `todos.sh` põe por cima a casa de brinquedo dele, com o sudo que recusa.

| rodada | código | `app-completo.py` | placar | tempo |
|---|---|---|---|---|
| 1 (antes da cura) | `5580d30` | ok, 643 s | 60 verdes, 2 pulados, 0 vermelhos | 1851 s |
| 2 (antes da cura) | `5580d30` | **FALHOU**, 702 s | 59 verdes, 2 pulados, 1 vermelho | 1923 s |
| **3** | `e34845c` | ok, 705 s | **60 verdes, 2 pulados, 0 vermelhos** | 1912 s |
| **4** | `e34845c` | ok, 640 s | **60 verdes, 2 pulados, 0 vermelhos** | 1864 s |

- **Pulados nas quatro rodadas** (ambiente): o `pack.sh` (falta o `Dracula_OS-Theme` no HOME de
  brinquedo) e o `conversor.sh` (falta o Papirus).
- **sudo:** 6 chamadas por rodada (4 `sudo -n true`, 2 `ponte_root.sh estado`), todas recusadas.
- **Escritas paradas no falso:** `gsettings set` do agente (5), `systemd-run` do build do
  cosmic-files (3), `notify-send` (4) e um `apt list --upgradable`.
- O `app-uso-real.py` passou nas quatro rodadas (67 s), e o `app-navegador.py` também (163 s).
- **HOME real:** um `find -newer` a partir do início das rodadas saiu vazio. Procurei em
  `~/.config/meow`, `~/.local/share/icons`, `~/.local/bin`, `~/.config/systemd/user`,
  `~/.config/cosmic`, `~/.local/libexec`, `~/.config/kitty`, `~/.local/share/applications`,
  `/usr/local/lib/meowsystem` e `/etc/sudoers.d`. Nenhum painel meu ficou de pé.
- **`/tmp`:** cada rodada deixa três restos vazios ou de brinquedo: uma pasta `meow-completo-*` do
  `app-completo.py`, uma pasta `tmp.*` e uma pasta `tmp*` com `bom.conf` e `quebrado.conf` do
  `app.sh`. Isso já acontecia antes da P80: havia 15 `meow-completo-*` antigos. Apaguei só os
  restos das minhas rodadas, e o `/tmp` voltou à lista de antes.

## Aberto, com dono

1. **`obsidian.png` do pack é um SVG com nome de PNG.** O painel já mostra, mas o arquivo continua
   travado como «feito à mão em PNG». Dono: **decisão de quem usa** (renomear para `.svg` no pack,
   que é dado).
2. **A pendência `wallpaper-fonte-revertida` não tem como ser dispensada.** Se a devolução estava
   certa, o cartão fica na Início até alguém clicar «Era escolha minha», e esse clique autorizaria
   a imagem errada. Dono: **decisão de produto**, depois a próxima leva.
3. **Botão aceso sobre trabalho já feito: «Instalar o starship»**, com o starship em
   `~/.cargo/bin`. É a mesma contradição das áreas, só que sem passo seguinte para apontar. Dono:
   **próxima leva**.
4. **Ainda mandam digitar.** Dono: **próxima leva**.
   - o `painel.sh reciclar` («arme o supervisor… systemctl --user start …»);
   - o `construir_icones.sh` («diagnóstico: meow painel estado»);
   - o `midia_build.sh`, o `lib/preflight.sh` e o «veja o motivo com…» do `leitura_build.sh`.
5. **Nomes e textos.** Dono: **próxima leva**; os erros de digitação são **dado do pack**.
   - App sem linha de mapa nem `.desktop` ganha nome genérico: `io.github.shiftey.Desktop` vira
     «Desktop», `com.obsproject.Studio` vira «Studio».
   - 174 de 469 desenhos da biblioteca Dracula não têm descrição no `catalog.json` e mostram o nome
     do arquivo em inglês.
   - Erros de digitação no pack: «Visalizador», «Calendario», «Gerenciador de extensoes».
   - Nomes em inglês que vêm do próprio `.desktop` («Online Accounts», «Mobile Network»).
   - O balão do app diz a origem como «usuária» (`DIRS_DESKTOP`).
6. **A 375 px.** Dono: **próxima leva**.
   - O item da página aberta não rola para a vista no menu horizontal.
   - A prévia fixa no topo cobre parte dos cartões.
   - O «?» da prévia de Manutenção fica por cima do desenho.
   - A `trava_pack` passa do teto do balão e sai cortada (já era assim antes da P80).
7. **Achados técnicos.** Dono: **próxima leva**.
   - `Trabalho.vivo()`: um neto que segure o stdout deixaria o trabalho «vivo» para sempre. Nenhuma
     ação de hoje faz isso.
   - O `assentar` do gate tem a mesma corrida em qualquer gesto cujo pedido nasça depois de um
     salto assíncrono (como o `close` de uma caixa). Curei o caso que ficou vermelho; os outros só
     aparecem se o servidor demorar mais de 3 s.
   - O `app-completo.py` e o `app.sh` deixam resto em `/tmp` a cada rodada (ver «As duas suítes»).
8. **Abertos que vêm da onda 2 e seguem de pé** (`04-integracao-onda-2.md`): a extensão do VS Code
   que o pack nomeia (decisão de quem usa) e o nome do «Restaurar ao padrão» (decisão de produto).
9. **O dev ainda não recebeu nada disto.** Dono: **quem fizer o merge no dev**, de uma vez, no fim.

## O que quem usa confere com a mão

1. **Ficha de ícone** (Ícones, um app como o Firefox):
   - os rótulos são nomes de programa, inteiros, sem palavra partida;
   - a paleta «Cor» só aparece quando um traço está marcado;
   - a pasta dos PNG mostra o selo de trava, e o porquê está na dica.
2. **Dia e noite:** as três linhas usam o mesmo seletor de hora, na ordem começa | termina. A
   fileira «Fundo» só aparece em Cor e tela.
3. **Instalação real** (`./install.sh`, depois do merge no dev): o painel do COSMIC recicla **uma
   vez**, no fim. O `meow.log` diz «pedido por fim da passada (…)» com os scripts que pediram.
   Confira que a faixa verde de 09/10 não voltou.
4. **Início, com uma casa de teste:** «Importar um pack» com um `.csv` faz o cartão aparecer depois
   da confirmação, e o «Remover» tira o cartão e a pasta.
5. **Decida o item 1** (renomear `obsidian.png`) e **o item 2** (como dispensar a pendência do
   papel de parede devolvido).
