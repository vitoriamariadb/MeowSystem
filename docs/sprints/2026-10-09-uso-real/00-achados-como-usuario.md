# Uso real do app, como usuário — 09/10/2026

Sessão no navegador (Playwright, 1440 px), sem teste automatizado: cliquei no
que um usuário clicaria. Prints em `.playwright-mcp/ux/` (fora do git).
Servidor: `./app/run.sh --sem-abrir`, branch `dev` em `ff02037`.

## A queixa que abriu tudo

Na home, com o Dracula no ar, ao trocar o ícone de um aplicativo os 600+ SVG
Dracula que existem não aparecem, nem os feitos à mão, nem os ajustados.

**Medido (print 06 e 07):** o seletor de «Ícone de agente» mostra 120 desenhos:
60 no grupo «Dracula» (`.do-pack`) e cerca de 60 em «Traço, na cor abaixo».
Não há pasta por acervo (Dracula, MeowSystem autorais, ajustados).
A busca por `firefox` devolve **um** desenho de traço; o Firefox-Dracula que o
pack carrega (Waterfox) não aparece.
O doctor diz `pack Dracula: 204 de 204 no tema` e `svg: 79 desenho(s) nossos`.

Contagem e causa no código: a auditoria
`docs/pesquisas/2026-10-09-paridade-de-icones.md`.

## Achados, por página

| # | Página | O que se vê | Gravidade |
|---|---|---|---|
| 1 | Ícones | Seletor de ícone mostra 60 Dracula + 60 traço; nada da biblioteca inteira, sem pastas por acervo | alta |
| 2 | Ícones | Busca por nome não acha desenho do pack (firefox → 1 de traço) | alta |
| 3 | Instalação → Conferir | Veredito «TUDO CONFERE / nada a consertar» com `!! completar: MeowSystem-Icons-Base não está instalado` e `-- pastas ... pastas coloridas puladas` na mesma saída | alta |
| 4 | Instalação → Conferir | Contradição: `icones: a base ... está em ~/.local/share/icons/MeowSystem-Icons-Base e confere` e, três linhas depois, `MeowSystem-Icons-Base não está instalado` | alta |
| 5 | Instalação → Conferir | Linhas vazias ou cortadas: `files_menu`, `resgatados` sem texto; `escala: saídas ligadas agora:` sem saída; `fontes: Fonte da interface` sem valor | média |
| 6 | Ícones | A prévia do tema (desenho das pastas) fica flutuando por cima do conteúdo ao rolar | média |
| 7 | Ícones | agente, COSMIC Viewer: «de fábrica», sem desenho Dracula | média |
| 8 | Início | O card do pack não é clicável; só o link pequeno «Mais sobre este pack», que abre uma tabela técnica numa coluna estreita e estica o card | média |
| 9 | Início / pack | O Dracula herda do Catppuccin: mapa do COSMIC, ícones de arquivo, fontes; papéis de parede «do motor, ou ausente». Não é um tema Dracula completo | alta (paridade) |
| 10 | Cor e tela | «Commit do acervo do Dracula» (hash de 40 hex) e «Acervo de papel de parede» (repositório GitHub) expostos como ajuste de usuário | média |
| 11 | Cor e tela | Três controles para a mesma decisão: «Variante do tema», «Theme pack», «Claro ou escuro»; e o pack também se escolhe na home | média |
| 12 | Ícones | «Logo própria do Hefesto» com caminho `$HOME/Desenvolvimento/hefesto-...`: coisa do PC dela dentro do produto; conta como «mudado por você» na home | média |
| 13 | Painel e dock | «Painel descolado da borda: Sim» com «Distância da borda: 0»; os dois dizem o contrário | média |
| 14 | Painel e dock | «Restaurar ao padrão (0)» aparece quando o valor já é o padrão | baixa |
| 15 | Papel de parede | A coleção (o que importa) fica no fim, depois de 11 ações técnicas; «Recusadas 62» > «No carrossel 29» sem explicação | média |
| 16 | Papel de parede | «Quanto tempo dura a imagem escolhida» mostra `30m` num campo que diz «em minutos» | baixa |
| 17 | Logo do sistema | Seis controles entrelaçados para «qual gato aparece» (Qual gato / troca sozinho / como é escolhido / de dia / de noite / gira) com caixas «quem manda é…»; o botão «Restaurar ao padrão» aparece como mais um bloco no meio dos gatos | alta (UX) |
| 18 | Logo do sistema | Prévia «No terminal» desenha só um contorno vazio | média |
| 19 | Lançadores | «Nenhum jogo instalado na Steam» e, abaixo, «2 jogos têm atalho» com a própria Steam listada como jogo | média |
| 20 | Lançadores | O lançador esconde Google Chrome, Steam e github-desktop, que estão em uso (o Chrome está na dock) — conferir se foi pedido | média |
| 21 | Manutenção | Cada Sim/Não usa a mesma ilustração quase idêntica: 12 desenhos que não distinguem nada; ajustes de síntese de som (Hz, senoide) para usuário comum; «Instalar o starship» em Manutenção, e não em Terminal | média |
| 22 | Geral | Primeira carga com o servidor frio: 7,5 s de tela vazia com «carregando…» | média |
| 24 | Ícones | A grade mistura quatro origens sem legenda: «Dracula» (arte do pack), «nosso» (autoral), «rosa/roxo claro/verde» (traço Arcticons numa cor) e «de fábrica». Para o usuário, uns «acionam o tema» e outros não, sem razão visível | alta (UX) |
| 25 | Dia e noite | Três agendas para o mesmo conceito: «noite» (gato), «tema claro» (deslizante sem valor, «como está») e «imagem escura» (18:00–07:00). Os campos da noite aparecem vazios `--:--` enquanto a home diz «das 18:00 às 07:00» | alta (UX) |
| 26 | Modo de leitura | Duas fontes de verdade: o app diz 3500 K e «Sim», a máquina está em 6300 K e «Não» porque «quem guarda é o controle do painel»; o usuário não sabe qual vale | alta |
| 27 | Modo de leitura | A prévia é a mesma foto estática nos dois cartões; não simula a temperatura nem a textura escolhidas | média |
| 28 | Todas | Cada página abre com «Desenho, não é a sua tela: …» (parágrafo de 2 a 4 linhas) e cada ajuste tem legenda explicativa; contra «sem texto, show don't tell» | alta (UX) |
| 29 | Áreas de trabalho | Nomes das áreas num campo de texto separado por vírgula («Pop, OS»), sem arrastar para ordenar nem prévia real do painel | média |
| 30 | Todas | O comando cru (`./scripts/...`, `meow ...`) aparece em cada ação, ao lado de «ver comando» que mostra o mesmo | baixa |
| 31 | Sistema | A faixa verde de 17:26 nasceu quando `scripts/painel.sh reciclar()` mandou SIGTERM ao `cosmic-panel` (17:26:01) e a dock renasceu com o compositor na AMD; quem chamou o `reciclar` não ficou registrado. Causa raiz da GPU: `Migração-OS/levas/leva-08-gpu-regressao.md` | alta |
| 23 | Geral | Dois painéis de pé dividem o mesmo `app.pid`: um `--parar` de outro processo derrubou o meu (exit 143), duas vezes em 10 min | média |

## O que fica para o bloco de correção

Cada linha acima vira tarefa com causa, cura na origem e prova, depois que a
auditoria de paridade e a caça às regressões (pedidos antigos que voltaram)
devolverem.

## Princípios ditos por quem usa nesta sessão (valem para toda tarefa)

1. O doctor não avisa: corrige. Nada de `instale com: sudo apt ...`; e nunca
   «TUDO CONFERE» com algo fora.
2. Interface moderna, *show, don't tell*: sem texto na tela; no máximo vira
   dica (tooltip). A clareza vem do arranjo, sem gerar dúvida.
3. Correção definitiva, modular, independente e idempotente; nada de
   contorno barato.
4. Tem que sobreviver às atualizações do COSMIC e evoluir com o sistema.
