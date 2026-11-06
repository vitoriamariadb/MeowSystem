# P162 — a barra de compartilhar sem dono na dock (06/11/2026)

Relato de 06/11/2026: a barra «O teams.cloud.microsoft está compartilhando sua tela.» aparece na dock sem ícone e
fica bugada. «Ela deveria ser do Chrome.» Sem relação com o tema do MeowSystem: a barra é uma janela do Chrome.

## Alcance

Produto, não máquina: o patch vale para qualquer janela sem `app_id`, sem lista de nomes e sem citar o Chrome. A dock é
aparência, então está dentro da fronteira do MeowSystem. A sonda e o doctor ganham em todo PC.

## O que se mediu

Com a barra no ar, às 11:56, lendo `ext_foreign_toplevel_list_v1` sem filtro:

| app_id | título |
|---|---|
| `com.system76.CosmicTerm` | Terminal |
| `google-chrome` | Calendar … Microsoft Teams - Google Chrome |
| `com.system76.CosmicFiles` | registro — Gestor de Arquivos |
| *(vazio)* | O teams.cloud.microsoft está compartilhando sua tela. |
| `com.system76.CosmicTerm` | Novo terminal — Terminal |

- A barra é uma janela própria, com `app_id` vazio. Sem `app_id`, nenhum `.desktop` casa, e a dock mostra a engrenagem
  genérica como app separado.
- `scripts/appid_sonda.py` descarta janela sem `app_id` (`if v["app_id"]`). Por isso `--janelas` não a lista, `--casar`
  sai vazio e `meow doctor` não a enxerga.
- A ponte da dock (`appid_dock.sh`, `appid.map`) não resolve: ela casa pela string do `app_id`, e aqui não há string.

**O «bugada» medido é outro defeito, a P160:** o portal caiu às 11:49:17, mas às 11:56 a barra seguia dizendo que
compartilhava. No PipeWire não havia `cosmic-screencast`, só o nó `chrome` em `Stream/Input/Video`, sem fonte. O Chrome
não percebe a queda, e a barra fica no ar com a imagem morta.

## A causa

O compositor anuncia o `app_id` vazio. Que o Chrome nunca chame `set_app_id` nessa janela é dedução; confirmar com
`WAYLAND_DEBUG=client` num Chrome à parte. Não há flag conhecida do Chrome para isso, e nada do MeowSystem participa.

## A cura

Decisão de 06/11/2026: a opção 1, herdar do cliente, mais o item 3. Se o compositor não guardar o cliente nesse ponto, a sprint
para e volta a quem usa; a opção 2 não entra sem novo sim.

Fazer a barra pertencer ao Chrome na dock, sem lista de nomes:

1. Patch no `cosmic-comp`: janela sem `app_id` herda o de outra janela do mesmo cliente Wayland. Vale para qualquer app
   com esse comportamento, e a barra entra no ícone do Chrome. Entra em `patches/`, na série do compositor da sessão; a tela de
   login usa `/usr/bin/cosmic-comp` (uid do greeter) e não recebe o patch.
2. Alternativa no `cosmic-app-list`: esconder da dock janela sem `app_id`. Mais simples, mas a barra some em vez de
   virar do Chrome, e esconde também janela legítima.
3. Em qualquer caso, a sonda passa a listar janelas sem `app_id`, e o `meow doctor` as aponta.

Avaliar antes se o `cosmic-comp` guarda o cliente da janela no ponto em que anuncia o `app_id`.

## Enquanto isso

- «Ocultar» tira a barra da tela sem parar o compartilhamento. Não testado se ela sai da dock também.
- Se a imagem morreu, «Parar de compartilhar» e compartilhar de novo.

## Como se prova

1. Compartilhar tela: a dock mostra só o Chrome, sem engrenagem.
2. `appid_sonda.py --janelas` lista a barra.
3. Fechar a última janela normal do Chrome com a barra aberta não deixa ícone órfão.
