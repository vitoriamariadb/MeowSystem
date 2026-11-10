# Andamento da leva a casca do painel

## O pedido (10/11/2026)

Seis fotos em `fotos/`, com o texto de quem usa resumido por item na sprint correspondente.

## Respostas de quem usa (AskUserQuestion, 10/11)

| tema | decisão |
| --- | --- |
| P189 | a linha de progresso vale para TODA ação: a janela de resultado sai do painel inteiro. A decisão 18 se reescreve no mesmo commit, com este sim |
| P190 | «Recarregar o painel» reinicia a barra do COSMIC (o `extensao_reiniciar_painel`) |
| P191 | sem registro na tela: some a contagem, a lista de últimas mudanças, o bloco Registro do Manter e o «Registro de <applet>» do build que falhou. O log segue no disco e no `meow doctor` |
| P188 | «Toca no COSMIC» vira «Nativo do COSMIC» (texto de quem usa) |

## Blocos

| bloco | sprints | arquivos principais | worktree e branch |
| --- | --- | --- | --- |
| E palavras | P184 | `GLOSSARIO.md` | sem código: quem usa aprova a tabela antes dos outros blocos aplicarem |
| A personalizar | P185, P186, P187, P188 | `oficina.js`, `paginas.js`, `scripts/som.sh`, `servidor.py` (`/som`, ícones) | a criar |
| B casca | P189, P190, P191 | `app.js`, `index.html`, `estilo.css`, `lugares.js` (`LUGAR_TOPO`, `LUGAR_JANELA`) | a criar |
| C definir | P192, P193, P194, P195 | `app.js` (`controleFaixa`), `lugares.js`, `patches/`, `scripts/areas.sh` | a criar |
| D manter e extensões | P196, P197, P198 | `lugares.js` (`LUGAR_CUIDAR`), `extensoes.js`, `espaco.js`, CSS da tela | a criar |

A e B tocam `paginas.js`/`app.js` em pontos diferentes, mas B muda o `rodar()`, que A usa: B integra antes de A.
C e D têm arquivos disjuntos entre si.

## Ordem

1. P184: a tabela do glossário, aprovada por quem usa.
2. B (a casca), depois A, C e D, no máximo dois em voo.
3. Integração, suíte inteira, push, install nas três máquinas; P194 e P195 medidas na sessão real.

## Próximo passo

Varredura feita (`relatorios/textos-da-tela.tsv`, 582 textos; script `relatorios/textos_da_tela.py`). `GLOSSARIO.md` com 97 linhas propostas espera a aprovação de quem usa.
