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

## O glossário aprovado (10/11)

`GLOSSARIO.md` fechado: coluna «quem usa» com as respostas do artifact e das perguntas. Leitura:
`sim` troca pelo proposto; `fica` e `não: original` mantêm o de hoje; `não: <texto>` e texto solto valem o que
ela escreveu; «sai» tira da tela. Várias respostas tiram linhas inteiras («Vale para», «Escolhida dura», o texto
de «Pôr agora», «Simular», «Toca nos apps», «Reler», «Mascote novo entra»).

Quem aplica:
- **Bloco B** aplica TODAS as trocas de nome do glossário (rótulos em `lugares.js`, `rotulo` do `servidor.py`,
  literais dos `.js` e `index.html`), mais as remoções da moldura: «Ver sem mudar», «Ensaio» e «Rodar de verdade»
  saem (a tela já mostra o resultado em tempo real; o gesto é só «Aplicar»), «Procurar um ajuste» vira «Buscar»,
  «Sem servidor» vira um estado com o motivo (ex.: «Não aplicado: falha no compositor»). Um teste lê o
  `GLOSSARIO.md` e falha se um termo trocado voltar.
- **Blocos A, C e D** fazem as remoções de linha das telas deles, sobre o B já integrado.

## Blocos em voo

| bloco | worktree | branch | agentes |
| --- | --- | --- | --- |
| B casca + glossário | `~/Desenvolvimento/.meow-wt-casca` | `bloco/casca` | um implementa, outro confere e corrige |

## Próximo passo

Bloco B em voo. Quando o conferente voltar: integrar `bloco/casca` no master, depois A, C e D (no máximo dois em voo).

## Para os blocos A, C e D

O bloco B aplicou toda troca de nome do glossário. As linhas «sai» de tela alheia seguem na tela e estão em
`AINDA_NA_TELA_DE_OUTRO_BLOCO` no `tests/glossario.sh`; quem remover a linha tira o termo dessa lista no mesmo commit.

| bloco | linhas que saem |
| --- | --- |
| A personalizar | Reler · Toca nos apps · Ouvir o instalado |
| C definir | Vale para · Versão do ponteiro · Escolhida dura · Versão do acervo |
| D manter | Mascote novo entra |

Leituras do B onde a resposta de quem usa era ambígua (conferir na revisão):
- «Carrossel agora · Próxima imagem» (resposta «Carrossel de Imagens»): «Carrossel agora» virou «Carrossel de Imagens»;
  «Próxima imagem» virou «Trocar o papel agora» (a proposta).
- «Voltar a girar · Girar» (resposta «Girar»): ficou como estava.
- «Ao ligar · Não abrem sozinhos» (proposta «Bloquear ao iniciar»): o bloco virou «Ao iniciar» e a linha «Bloquear ao iniciar».
- «Regravar o som» virou «Gerar Sons» (texto dela); a P188 propunha «Salvar o sino».
- Nome curto (até 3 palavras) das ações no `servidor.py`, exigido pelo `tests/app.sh`: onde o glossário passa disso, a
  tela diz o nome do glossário e o servidor diz a forma curta («Tema original», «Separar tons», «Ligar leitura agora»).
- «Painel e dock» virou «Barra e dock» (regra de família: painel não aparece mais na tela).
