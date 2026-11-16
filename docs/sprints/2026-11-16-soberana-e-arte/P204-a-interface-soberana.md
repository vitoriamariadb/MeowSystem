# P204 — a interface soberana: nenhum controle se desliga para explicar outro (16/11/2026)

Texto de quem usa: «coisas tipo essa tooltip não podem ocorrer na interface nunca. a interface é soberana.»

## O que se mediu
- `app/pagina/app.js` `motivoIndisponivel` + `controleDeAcao`: botão de ação com `indisponivel` sai `disabled` e a
  dica vira o motivo («Vale com «Como escolhe» em Girando», «Sem efeito agora», «Nada para escolher agora»).
- `app/pagina/app.js` `dominada` + `linhaDeChave`: linha `dominada` fica cinza e, na linha dupla, o controle ganha
  `desligado` + `data-dica` com o porquê e os inputs `disabled`. Fontes: `alturaForaDaProporcao`, `SOLTO_DE`,
  `dominada_por` (2 no `servidor.py`) e «Segue o horário da noite».
- `app/servidor.py`: 5 ações com `"indisponivel"`: `logo_trocar` e `logo_girar` (`_gato_so_nos_modos`),
  `areas_aplicar` (`_areas_sem_alfinete`, tipo `antes`), `areas_alfinetar_primeira` (`_areas_ja_alfinetadas`, tipo
  `feito`), `spicetify` (`_spicetify_ja_instalado`, tipo `feito`). `indisponivel()` também barra a execução (≈ linha 5505).
- Na foto: «Fixo» (FASTFETCH_LOGO_GATO) cinza com «Qual mascote» em «O outro»; «Girar» desligado com LOGO_MODO fora de
  `rotacao`.

## A cura na origem
Regra: controle visível sempre funciona, e o gesto nele vale.
- Dependência de modo (`pede`): o clique liga o modo pedido e faz a ação, no mesmo gesto (Girar grava `LOGO_MODO=rotacao`
  e gira; Aplicar grava `fixo` e aplica). Mexer numa chave `dominada_por`/sub de modo (ex.: «Fixo» do terminal) grava o
  modo que a faz valer (`FASTFETCH_LOGO_MODO` → o valor de «Sempre o mesmo») junto com o valor.
- `antes` (pré-requisito): o clique roda o pré-requisito e depois a ação.
- `feito` (já feito): a linha não aparece. Nada desligado com dica.
- `SOLTO_DE`: mexer na margem solta o painel/dock. Altura fora da proporção: a linha funciona normal, sem cinza.
- «Segue o horário da noite»: mexer no horário da área desliga o `mesmo_horario` ou grava no horário da noite — escolha
  o que o código já suporta; sem cinza, sem dica de motivo.
- Dica de motivo some do código: nenhum `data-dica`/`dica` com porquê de bloqueio; a dica de ajuda (`primeiraFrase(ajuda)`)
  continua.
- O servidor não recusa mais por `indisponivel` quando o painel manda o gesto com o modo junto; o CLI segue como está.

## Decisão
Linha nova no `docs/DECISOES.md` (57): «A interface é soberana: controle visível sempre funciona; o gesto liga o que
ele precisa, e nenhum controle fica desligado com dica de porquê» — sim de 16/11 (texto acima). Prova em
`tests/decisoes.sh`.

## Como se prova
- Teste de página (padrão `tests/app-uso-real.py`/`tests/personalizar-pagina.py`, HOME temporário): nenhum
  `button[disabled]`, `.desligado`, `.dominada` nem `[aria-disabled=true]` em nenhuma página; clicar «Girar» com
  LOGO_MODO=fixo grava `rotacao`; escrever em «Fixo» grava `FASTFETCH_LOGO_MODO` no valor de «Sempre o mesmo».
- `tests/decisoes.sh` com a linha 57: grep que falha se `motivoIndisponivel` ou `disabled: !!motivo` voltarem.
- Afetados verdes: `tests/app.sh`, `tests/app-uso-real.py`, `tests/glossario.sh`, `tests/decisoes.sh`.
