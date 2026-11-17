# Leva de 17/11/2026 — os botões da janela em todo formato de app

Texto de quem usa, 17/11 (foto dos botões do pack num app nativo e foto do Chrome e do Edge com os botões genéricos):
«isso funciona pros apps nativos eu creio. Mas não funciona pros apps em flatpak, snap, deb e outros. chrome edge
são exemplos mas isso acende um alerta sobre os formatos de apps e coberturas do meowsystem. Pode corrigir isso?»
Depois: «whatsapp também. enfim. deve ter vários outros formatos.»

Respostas (AskUserQuestion, 17/11): navegadores Chromium no modo GTK («1-ok eu acho. se mudar muito fazemos um tema
próprio pra eles.»); Electron entra nesta leva («Electron junto»).

| bloco | árvore | tarefas | agentes |
| --- | --- | --- | --- |
| A navegadores | `../.meow-wt-navegadores`, `bloco/navegadores` | P212 | implementa (agente high) → confere e corrige (agente high) |
| B toolkits | `../.meow-wt-toolkits`, `bloco/toolkits` | P213, P214 | implementa (agente high) → confere e corrige (agente high) |

Arquivos disjuntos: A toca `scripts/temas-de-apps/chromium/`, os testes dele e `docs/DECISOES.md`; B toca os
manifestos dos apps Electron e Qt (`scripts/temas-de-apps/<app>/`, `scripts/temas-de-apps/toolkits-gtk-qt/`) e os
testes deles, nunca `docs/DECISOES.md` (devolve a linha proposta ao coordenador). Integração em
`integracao/2026-11-17`, depois `master`, push.

## O que já se mediu (coordenador, 17/11)
- Apps COSMIC: os botões vêm de `window-{close,maximize,minimize,restore}-symbolic` do tema de ícones `MeowSystem-Icons`.
- Flatpak enxerga o tema: `/run/host/user-share/icons/MeowSystem-Icons` existe no sandbox e o portal
  (`org.freedesktop.portal.Settings`) entrega `icon-theme = 'MeowSystem-Icons'`.
- Chrome (deb, `/opt/google/chrome`) e Edge (flatpak `com.microsoft.Edge`) estão no modo Clássico
  (`extensions.theme.system_theme = 0`; Chrome com `extensions.theme.id = user_color_theme_id`, Edge com um tema da
  loja). O Clássico desenha botões próprios.
- O binário do Chrome pede `window-*-symbolic` ao tema de ícones no modo GTK. Prova: Chrome com perfil temporário e
  `system_theme = 1` mostrou morcego, caixão e ossos do pack (foto fora do git, que ignora PNG: `docs/sprints/2026-11-17-botoes-em-todo-formato/fotos/chrome-gtk-e-cosmic.png` no checkout principal, linha de cima; a de
  baixo é um app COSMIC). Diferença vista: no Chrome os ícones saem cinza, no COSMIC saem na cor de destaque.
- Snap: sem `snapd` neste PC. AppImage: não medido.
