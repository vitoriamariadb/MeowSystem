# As pesquisas

Cada arquivo aqui é o registro bruto de uma investigação — o que foi medido, por
quem, com que método, e o que sobrou depois de alguém tentar derrubar. Eles não
são documentação do que o projeto faz (isso está no `README.md` e nos
cabeçalhos dos scripts): são o **caderno de campo**.

**Por que ficam no repositório.** Uma decisão sem a medição que a produziu
envelhece calada: seis meses depois ninguém lembra se aquele número foi medido
ou chutado, e o próximo a mexer refaz o trabalho — ou, pior, desfaz a correção
por achar que era capricho. Guardar a pesquisa é o que permite dizer "isto foi
medido em tal dia, assim" em vez de "acho que sim".

## O que tem aqui

| arquivo | o quê |
|---|---|
| `2026-08-05-bugs-icones-portabilidade.json` | ícones que não apareciam, e o que era portabilidade e o que era defeito |
| `2026-08-05-svg-dock-e-greeter.json` | o SVG do dock e o da tela de login |
| `2026-08-29-modo-leitura-e-botoes.md` · `.json` · `.html` | o modo de leitura e os botões da barra de título |
| `2026-08-29-sliders-modo-leitura.json` | os controles do modo de leitura |
| **`2026-09-01-auditoria-painel-51-frentes.json`** | a página de configuração usada por uma varredura completa num navegador real: **120 achados**, 40 deles quebrados |
| **`2026-09-01-correcao-painel.json`** | as três correções em paralelo (servidor, conf de exemplo, testes) e o que os revisores acharam de cada uma |
| **`2026-09-02-validacao-painel-29-frentes.json`** | a validação depois do conserto: **244 features exercidas**, 169 funcionando |

## As três de setembro, e por que elas vieram em série

Ela olhou a página do `app/` e disse duas coisas no mesmo fôlego: *"o layout tá
totalmente sem simetria"* e *"eu realmente não sei se ele funciona de fato"*. A
primeira metade se resolve olhando. A segunda, não — e foi o que produziu este
trio:

1. **Auditoria** (uma varredura completa) — nove percorreram as abas clicando em tudo, com
   o modo seco ligado. Todo achado marcado como quebrado foi entregue a um
   cético independente, instruído a **refutar**, com a ordem de refutar na
   dúvida. Sobraram 120, e a lista virou o plano de correção.
2. **Correção** (6 frentes) — três corrigiram, cada um em **um arquivo
   diferente**, para não colidirem; três revisaram, lendo o diff sem confiar no
   relatório. Um dos revisores reprovou a entrega e achou duas regressões — uma
   delas minha.
3. **Validação** (uma varredura completa) — a mesma disciplina, agora perguntando "funciona?"
   em vez de "está errado?". 244 features exercidas, uma a uma.

**O que isso ensinou, e vale além desta página:** o que um frente relata como
quebrado sobrevive menos da metade das vezes a um segundo frente tentando
reproduzir. O cético não é zelo — é o que separa achado de palpite.
