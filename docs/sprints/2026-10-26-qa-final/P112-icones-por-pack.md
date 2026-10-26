# P112 — cada pack com os seus ícones; o desenho chega ao desktop; gerador do Dracula

Leia `00-leva.md`. Itens: `relatorios/qa-1.md` Q1-01, Q1-19, Q1-02, Q1-05, Q1-06, Q1-07, Q1-08.

## Maquete
`maquete/b/personalizar.html#icones`: abas Apps/Sistema/Biblioteca, a oficina com um «Usar» e os dois geradores (MeowSystem traço, Dracula círculo) trocando pelo pack em edição.

## O que quem usa pediu
O ícone que ela desenha no Personalizar aparece no desktop, na dock e no lançador. Os ícones do pack
Dracula não aparecem no pack MeowSystem e vice-versa. O Dracula ganha um gerador de ícones no estilo
dele (base `circle` na frente, `main` atrás — decisão 1), separado do traço Arcticons do MeowSystem.

## Decisões que valem (ANDAMENTO.md)
- A decisão 3 do GSD («o seletor mostra o acervo de todos os packs») CAIU com o sim de 26/10: troque a
  linha no GSD/registro e a prova em `tests/decisoes.sh` no mesmo commit do código que separa.
- A oficina do Personalizar grava no pack em edição; se esse pack é o que está no ar, aplica.

## Ordem
1. Q1-01 e Q1-19: todo mapa que o servidor grava termina em `\n`, e todo `while read` de mapa lê a
   última linha mesmo sem `\n` (`|| [ -n "$linha" ]`). Teste com um mapa sem `\n` final.
2. Q1-02: «Usar» grava o desenho dentro do pack em edição (três pastas por pack, decisão 14); o
   `.meowpack` exportado leva o desenho. Prova: exportar e achar o arquivo.
3. Q1-05, Q1-06, Q1-07: o seletor, a aba Sistema e a Biblioteca mostram só o acervo do pack em edição;
   a aba Sistema mostra as pastas do pack na cor do tema, com nome legível (Documentos, Downloads…);
   o «Do tema» pré-selecionado é o desenho do pack certo. Causa em `scripts/pack.py` (as duas funções
   que juntam acervo de todos os packs).
4. Q1-08: gerador do Dracula. Os presets do MeowSystem geram traço Arcticons; o Dracula precisa do seu
   estilo (círculo de fundo + glifo). Leia como os ícones do pack Dracula são feitos hoje
   (`packs/dracula/`) e gere no mesmo molde, com a paleta Dracula. O gerador escolhido segue o pack em
   edição. Prova: gerar um ícone com o pack Dracula e comparar a estrutura do SVG com um ícone do pack.

## Fora desta sprint
Layout da oficina (P110), Mandar e rascunho (P113).
