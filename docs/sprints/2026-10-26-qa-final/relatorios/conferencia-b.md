# Conferência B — P112, P113 e P114

Worktree `MeowSystem-conf-b`, branch `conferencia/b`, saída de `integracao/qa-final` (`63ee3497`).

## O que conferi

- As provas das três `## Execução`, rodadas de novo na suíte (HOME de brinquedo, falsos de `sudo`):
  `mapas-fim-de-linha.sh`, `acervo-do-pack-em-edicao.sh`, `seletor-do-pack.sh`, `acervo-da-ficha.sh`,
  `desenho-no-pack.sh`, `gerador-dracula.sh`, `icones-por-pack.py`, `p113-navegador.py`,
  `sons-do-pack.sh`, `ponte-so-reserva.sh`, `pos-apt.sh`, `pack-traz-o-que-usa.sh`,
  `nada-manda-digitar.sh`, `extensoes.sh`, `extensoes-gesto.sh`, `garantir-builds.sh`, `midia.sh`,
  `leitura-fonte-unica.sh`, `migracao-do-painel.py`, `app-completo.py`, `app-layout.py`,
  `app-acessibilidade.py`: 22 verdes, 0 pulados, 0 vermelhos.
- Personalizar (Ícones com Apps, Sistema, Biblioteca e a ficha; Sons; Mandar) e Extensões (Applets,
  Builds, Adicionar repositório), como quem usa: Playwright headless em 1920×1080 e 1280×800, nos
  dois packs, com a medida de vazamento lateral em cada passo. Nenhum erro de JavaScript.
- As junções das seis sprints em `app.js`, `paginas.js`, `oficina.js`, `extensoes.js`, `servidor.py`,
  `pack.py` e `index.html` (as resoluções de conflito de cada merge da integração).

## O que corrigi

| commit | o quê | prova |
|---|---|---|
| `2d544ce1` | o «Regravar» do sino chamava `guardarBandeja`, que a P109 tirou; agora espera a gravação ao soltar e só regrava com o sino gravado | `app-completo.py --aba criar/sons`, `p113-navegador.py` |
| `aca6f96d` | a ficha do ícone abria dentro de uma célula da grade, com caixa dentro de caixa e dois «Usar»; agora toma o lugar da grade, com olho e mão sem moldura e um só «Usar» no rodapé, e cabe na janela (corpo rola, rodapé fica); o CSS morto da P110 saiu | `app-layout.py` (4 larguras × Gerar/Do acervo × topo/fim), `icones-por-pack.py` |
| `6d240553` | as abas de Extensões criavam um segundo `#abas` dentro da página e o teste não as achava; agora usam a barra global, como na maquete, e Definir refaz as suas ao voltar | `extensoes-pagina.py` |
| `01a2dfcd` | «quatro portas» virou cinco, com Extensões, no `ESTADO-FINAL.md` e no `app/LEIA-ME.md` | `numeros.sh` |
| `51a4e2b6` | o cartão de Extensões ganhava uma segunda coluna pela regra do cartão de Manter, e o nome partia em «Toca ndo agora»; agora tem uma coluna, como na maquete | `extensoes-pagina.py`, que agora mede as colunas e as abas (vermelho sem a cura) |
| `8650db6f` | Q1-08: com a ficha de um app aberta no MeowSystem, trocar para o Dracula deixava o gerador de traço; a oficina agora recomeça quando o pack de base muda. O teste zerava a oficina por fora e escondia o defeito; agora não zera | `icones-por-pack.py` (vermelho sem a cura) |

## A suíte inteira

`./tests/todos.sh` em `8650db6f`: 102 testes, 95 verdes, 0 pulados, 7 vermelhos.

- `readme.sh`: o gancho do merge refaz o README.
- `decisoes.sh`: vermelho aceito (GPU e shim do compositor da máquina).
- `app.sh`, `chave-etapa.sh`, `app-navegador.py` e `restaurar.sh`: da conferente A.
- `extensoes-pagina.py`: a causa é a mesma do `chave-etapa.sh`. Sem linha na tabela,
  `BUILDS_AO_ENTRAR` cai em `*`. Ligar «Refazer ao entrar na sessão» roda o `install.sh` inteiro, que
  segura o lugar do trabalho, e o «Adicionar repositório» seguinte termina em erro. A A já curou isso
  em `f95fa9d3` (`BUILDS_AO_ENTRAR` com `-`). Com a tabela dela no lugar, `extensoes-pagina.py` e
  `chave-etapa.sh` ficam verdes (39 s, contra 133 s com o install inteiro correndo junto). Não
  gravei a tabela aqui, para não colidir com a A na integração.

## O que ficou de fora, com o porquê

- A prévia desenha as pastas da janela de arquivos com o mesmo contorno (`mesa.js`, `PASTA`) nos
  dois packs, enquanto as pastas do Dracula são cheias e cinzas. Confirmado em 1920 e em 1280. A prévia é
  da P110 (conferente A).
- A pendência `spicetify-tema-ausente` perdeu o nome «Tema do Spotify» no merge da P109 e não tem
  ação: se aparecer, o Manter a mostra sem «Resolver». A P113 tirou de propósito a ação de baixar.
- Na aba «Do acervo» da ficha, os glifos de traço da grade aparecem escuros no fundo escuro (o SVG vai
  cru como imagem). A lupa já pinta o glifo escolhido na cor do traço. O defeito é anterior a esta leva.

## Para conferir com a mão

1. Personalizar → Ícones → abra um app: a ficha toma o lugar da grade, há um só «Usar» e ele fica à
   vista ao rolar.
2. Abra o mesmo app, troque o pack de base para Dracula em Cores e volte: os cartões são de círculo.
3. Extensões: as abas Applets e Builds ficam na faixa de cima, e cada cartão mostra o nome inteiro numa linha.
4. Sons → «Regravar»: o sino toca o som que está na barra.
