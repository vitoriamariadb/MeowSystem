# P184 — o glossário da interface (10/11/2026)

Foto `fotos/4-registro.png`. Texto de quem usa: «esse tipo de linguagem não é linguagem comercial/humana. Preciso de
uma lista de troca de termos, palavras e expressões pra deixarmos melhor e mais claro a interface.» E: «o negócio
não é autodescritivo, não pode ser. nunca.»

## O que se mediu

1. Rótulos que só a dica explica: «Liberar» (`lugares.js:320`, `espaco.js:48`), «Aprimorar» (`paginas.js:782`),
   «Quanto fala» e «Cópias guardadas» (`lugares.js:276-277`), «Cortar o repetido», «Mascote novo entra»,
   «Consertos de sistema», «Ponte fora», «Folga no nome», «Reconstruível», «7 remendos».
2. Não existe lista única de termos: cada sprint batizou o seu, e o mesmo gesto tem nomes diferentes
   («Refazer», «Reconstruir», «Tentar de novo», «Regravar»).

## A cura na origem

1. Script (mecânico, sem agente) que extrai todo texto visível: `r:` e `b:` de `lugares.js`, `rotulo` do
   `servidor.py`, literais de `elemento(... texto:)`, `botao("…")`, `dica:` e `index.html`. Saída:
   `relatorios/textos-da-tela.tsv` (texto, arquivo:linha, tela).
2. `GLOSSARIO.md` nesta pasta: uma linha por termo, `hoje | proposto | por quê`. Critério único: quem lê só o
   nome sabe o que acontece ao clicar; linguagem de produto, sem jargão da casa.
3. Quem usa aprova a tabela. Depois disso, um teste lê o `GLOSSARIO.md` e falha se um termo da coluna «hoje»
   voltar à tela.

Sementes da tabela (proposta, a aprovar):

| hoje | proposto |
| --- | --- |
| Aprimorar / Aprimorar Dracula | Salvar no tema / Editar Dracula |
| Liberar | Apagar arquivos recriáveis |
| Reconstruível | Recriável |
| Quanto fala | sai (P191) |
| Cópias guardadas | Backups guardados |
| Toca no COSMIC / Toca nos apps | Nativo do COSMIC / Dos apps |
| Refazer / Reconstruir / Tentar de novo | Recompilar (builds) · Refazer (ícones) |
| 7 remendos | 7 patches |
| Cortar o repetido | Desligar o que conflita |
| Ponte fora / Sem ponte | Permissão de sistema desligada |
| Guardar ajustes / Trazer ajustes | Exportar ajustes / Importar ajustes |

## Como se prova

- `relatorios/textos-da-tela.tsv` cobre todas as telas (contagem por tela no topo).
- `GLOSSARIO.md` com o sim de quem usa citado.
- `tests/glossario.sh` vermelho com um termo velho plantado, verde sem ele.

Tamanho: varredura 30 min; a tabela inteira, uma conversa com quem usa.
