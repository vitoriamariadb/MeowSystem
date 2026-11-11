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

## Próximo passo

11/11: B integrado no master (235d7fec, conferente APROVADO, suíte 149/150) e P199 (o `restaurar.sh` verde de novo,
f60a4c11). B2 (P200) integrado em 11fb4bb7, suíte 151/151. A integrado em 47a097b3; suíte do master com A+B2: 153/153. C+D código integrado (c780b199, suíte 153/153; ASSETS_VIGIA aposentada).
Nada em voo. Falta: escolha da maquete do Manter (A https://claude.ai/artifact/Fo156xSuUHbMBwtAp9SmAk ·
B https://claude.ai/artifact/8KHASKZbRod3TPfWw2dZ14) e então o código da P196; as respostas do artifact dos nomes;
P201; as perguntas da faixa (↶ com padrão vazio, faixa sem valor lido); depois push, install e P194/P195 na sessão real.
Revisão com quem usa: https://claude.ai/artifact/QAMczhuH14p61bmUqDww6v (85 nomes do Verificar + 4 perguntas; ler com ArtifactData, coleção `respostas`). Próxima conversa com quem usa: os 85
nomes curtos do «Verificar o sistema» (`NOME_DA_CONFERENCIA` no `servidor.py`) e a P201. Quando cada conferente voltar: integrar no master; depois C e D juntos.
Vermelho antigo não se aceita: vira sprint e conserto. Suíte longa de agente: o agente espera em primeiro plano,
em pedaços de até 9 min, nunca encerra o turno «esperando».

Anotações para depois (não são escopo de bloco nenhum ainda):
- `tests/glossario.sh` lê `GLOSSARIO.md` e `textos_da_tela.py` de dentro desta leva: levar para fora de `docs/sprints` antes de arquivar.
- «Painel agora» (`painel_estado`) e «Pôr o mascote» (`logo_trocar`) no `rotulo` do servidor ainda usam palavra que saiu da tela.
- Código morto anterior ao B: `Manipulador._svg_vazado` e o `seco` do `/api/jogo-fora`.

## Para os blocos A, C e D

O bloco B aplicou toda troca de nome do glossário. As linhas «sai» de tela alheia seguem na tela e estão em
`AINDA_NA_TELA_DE_OUTRO_BLOCO` no `tests/glossario.sh`; quem remover a linha tira o termo dessa lista no mesmo commit.

| bloco | linhas que saem |
| --- | --- |
| A personalizar | Reler · Toca nos apps · Ouvir o instalado |
| C definir | Vale para · Versão do ponteiro · Escolhida dura · Versão do acervo |
| D manter | Mascote novo entra |

Leituras do B onde a resposta de quem usa era ambígua (conferir na revisão):
- «Carrossel agora · Próxima imagem» (resposta «não: Carrossel de Imagens»): «Carrossel agora» virou «Carrossel de Imagens»;
  «Próxima imagem» fica (sim de 11/11: «Só a linha»).
- «Voltar a girar · Girar»: a linha se chama «Girar» (sim de 11/11), na P200.
- «Pôr agora»: só o botão «Aplicar», sem nome de linha (sim de 11/11), na P200.
- «Ao ligar · Não abrem sozinhos» (proposta «Bloquear ao iniciar»): o bloco virou «Ao iniciar» e a linha «Bloquear ao iniciar».
- «Regravar o som» virou «Gerar Sons» (texto dela); a P188 propunha «Salvar o sino».
- O `rotulo` das ações no `servidor.py` aparece na tela (título da confirmação e nome na linha de progresso), então é o
  nome do glossário inteiro; o teto do `tests/app.sh` e do `tests/app-uso-real.py` é de seis palavras.
- «Painel e dock» virou «Barra e dock» (regra de família: painel não aparece mais na tela).
