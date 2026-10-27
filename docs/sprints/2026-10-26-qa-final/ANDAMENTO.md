# Leva QA final (26/10/2026) — andamento

## Agora
- Entregues: QA, os 5 repos de applet, a maquete (aprovada), B0 inteiro (no dev em 15be6fdf; ganchos
  instalados: pre-commit no diretório comum, `ganchos.pre-push`/`ganchos.post-merge` por git config).
- 27/10: o PC reiniciou no meio; os 6 foram retomados pelo próprio histórico (nada se perdeu: commits e
  arquivos sujos nas worktrees). Chromium do Playwright agora em `~/.cache/ms-playwright` (o do scratchpad some no reboot).
- Em voo: 6 Sonnet, um por sprint, em `../MeowSystem-p109..p114` (branches `sprint/p109..p114`, do dev 15be6fdf).
- Fechadas: P111 (85/88, vermelhos só os aceitos + README, que o merge regenera) e P110 (9 commits; `todos.sh`
  limpo não rodou depois dos dois consertos finais, a integração roda). Para a conferência A: a P110 afrouxou o
  `tests/app-uso-real.py` (ignora o que rola por baixo das abas fixas): conferir se não esconde cobertura real.
- 27/10 ~03h: P110–P114 fechadas e juntas em `integracao/qa-final` (worktree `../MeowSystem-integracao`). Conflitos
  resolvidos pelo coordenador: a ficha de desenho do `oficina.js` ficou a da P112 (a da maquete); os `<link>`
  e os `<style>` do standalone somam os cinco CSS; portas com os nomes da P111 + Extensões da P114;
  pendência `leitura-applet` virou `extensao-leitura`. Suíte da integração: 92/100. Consertados depois:
  `app.sh` 12c e `p113-navegador.py`. Vermelhos que ficam para a conferência: `app-layout.py` (a ficha da
  P110 contra a da P112: «Usar» no rodapé e fora da grade), `app-completo.py` (`criar/sons`: «pergunta» e
  «resultado» abertos juntos), `extensoes-pagina.py` (espera `.abas-ajustes`, que a P110 tornou global).
  `readme.sh` se regenera no merge. P109 ainda na suíte final; entra antes dos conferentes.
- Depois: juntar as seis em `integracao/qa-final` → 2 Opus (`03-conferencia.md`) → merge no dev →
  remover as worktrees da leva (b0, maquete-a, maquete-b, p109..p114).
- Pedido de quem usa (27/10): ao fim de TUDO (merge no dev e worktrees removidas), desligar o PC sem
  perguntar: `sudo -A systemctl poweroff -i` (askpass; ignora apps abertos).

## Respostas de quem usa (26/10)
- Repos de applet: conta `vitoriamariadb`, nome `meowsystem-*`, pasta `~/Desenvolvimento/meowsystem-*`, app id `io.github.meowsystem.*`. Vão até o push. Compilam e instalam aqui (root por `sudo -A`, o askpass); não mexem na ordem do painel nem o reiniciam sozinhos.
- Repos: now-playing (fork), status-hub (fork), quick-settings (fork), leitura (sai de `src/applets/leitura`), performance (nasce do `~/.config/zsh/scripts/nitro`).
  Divisão: Claude 1 mídia · Claude 2 status-hub + quick-settings · Claude 3 leitura + performance.
- Aplicar: cada controle grava ao soltar; a barra de mudanças fica, só para desfazer.
- «Mais ajustes» some: tudo aparece direto na seção, o raro no fim.
- Decisão 3 do GSD caiu (sim de 26/10: «o que eu falei hoje sobrescreve»): ícone de um pack nunca aparece no outro.
- Dracula: gerador de ícones próprio, no estilo do Dracula; ícone de um pack nunca aparece no outro.
- Renomes: Criar tema → Personalizar · Ajustes → Definir · Cuidar → Manter. Sai «Conferir e consertar».
- Tema: sai «Ver» e «No ar agora» (os temas prontos já estão à vista e se põem no ar dali). Criar o meu: «tema» no fim.

## Pedido original (resumo, para as sprints)
Instalar tudo: modal quebra o layout e o log dá erro (hicolor escreve toda passada).
Prévia: dock não atualiza; prévia e menu esquerdo/superior fixos; tela mais larga, menu lateral vira horizontal acima da prévia.
Lançador: sugestão de apps ao digitar. Spotify: tema dentro do pack meowsystem, aplica em definitivo, sem «Baixar».
Fonte do terminal e o que precisa instalar: o pack traz; a interface não pede (no máximo trazer .zip, como o cursor).
Manter: bloco Outro computador/Atualizar/Instalar de novo com texto e botões ao lado do svg.
Sons: separados por pack; lista dos sons do Pop!_OS e como trocar; o sino do volume não gera. Mandar: seção vazia.
Personalizar: desenho gerado não chega ao ícone final do desktop; Trazer .zip / Tema instalado / Reconstruir não fazem sentido; Variantes dos ícones quebrado; layout dos geradores.
Créditos e README ruins; André entra como coautor.
Modo leitura sumiu do painel; gerador de build (idempotência do PC) também.
Seção Extensões: mostra os applets, deixa o usuário adicionar repo (central de applets), sem brigar com o sistema.

## Entregue
- QA 3: `relatorios/qa-3.md` (hicolor: `scripts/jogos_steam.sh:207` e `jogos_heroic.sh:274` criam temporário dentro do hicolor; curar renderizando fora). 5 perguntas no fim do relatório, juntar com as dos outros QA.
- meowsystem-leitura e meowsystem-performance: no GitHub (main), instalados em ~/.local (`./install.sh --remover` desfaz). Falta: pôr no painel e reiniciá-lo (gesto de quem usa); sprint de integração segue o INTEGRACAO.md de cada um.
- meowsystem-now-playing: no GitHub (main, 8 commits, 56 testes). NÃO instalado (o agente recusou a liberação vinda por mensagem). Sprint de integração: `INTEGRACAO.md` do repo (PINO, midia_build.sh, midia.sh, tests/midia.sh, cache ~/.cache/meowsystem-now-playing). A provar: painel aceita id interno diferente do nome do .desktop.
- QA 1: `relatorios/qa-1.md` (20 itens). Q1-01: mapa sem `\n` final em `app/servidor.py` → `while read` perde a última linha (o desenho novo nunca instala). A decisão 3 já está respondida (cai).
- meowsystem-status-hub («Bandeja», `io.github.meowsystem.Bandeja`) e meowsystem-quick-settings («Ajustes rápidos», `io.github.meowsystem.AjustesRapidos`): no GitHub, instalados em ~/.local. Troca no painel e reinício: gesto de quem usa. Integração: INTEGRACAO.md de cada um (mesmo contrato de tema).
- Anotação para depois: `aurora-claude-workspace.sh run` adivinha o app id pelo binário; applet com app id diferente precisa de `AURORA_CLAUDE_APPID`.

## Respostas às perguntas dos relatórios (26/10)
- Identidade: commits como Vitória (vitoriamaria.sds), André coautor. Casa: `vitoriamariadb/MeowSystem` (decisão 22 cai). README, Créditos e LICENSE com os dois nomes.
- Extensões: porta própria no topo (Tema · Personalizar · Definir · Manter · Extensões). Adicionar repo de qualquer URL, por gesto, SHA pinado, sem sudo.
- «Gerador de build» = estado dos builds: ver e refazer compositor, menu do Arquivos e applets (mora em Extensões/Manter).
- Sons do carregador e da bateria: troca em /usr/share/sounds/Pop pela ponte; o pós-apt repõe. Cada pack traz os seus sons (MeowSystem ganha os seus); `SOM_*` do meow.conf deixa de vencer o pack.
- Padrões que eu fixei (ela pode desfazer): oficina do Personalizar grava no pack em edição e, se é o pack no ar, aplica; itens de máquina do Q1-09 vão para Manter; «Falta a ponte» oferece «Consertar a ponte»; chave sem aplicador próprio grava e roda o instalador em segundo plano, sem janela; desfazer guarda as últimas 20 enquanto a aba está aberta; Programas sem prévia, grade larga; modo de leitura volta como bloco em Dia e noite, e o applet aparece em Extensões; fonte do terminal vendorada no pack, sem seletor novo; aplicar por etapa (uma etapa por chave) é aceito; o «Instalar» da extensão do VS Code de pack importado fica (decisão 9).
