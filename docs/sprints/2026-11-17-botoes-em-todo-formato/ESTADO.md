# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | implementada e testada; falta o conferente e a integração |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.

## P212: o que se mediu e o que falta (agente implementador, 17/11)
- Medido com perfil temporário (Chrome 157): no perfil novo, `extensions.theme.system_theme = 1` sem `id` já vale o modo GTK e o Chrome não reescreve. No perfil REAL (cópia com a conta Google, sincronia pausada) isso NÃO basta: ao abrir, o Chrome devolve `id = user_color_theme_id`, `system_theme = 0` e as chaves `browser.theme.*`, lidas do cache de sincronia (`Sync Data`), não do Preferences. Só ficou GTK com `sync.keep_everything_synced = false` (e `sync.themes = false` por clareza) no perfil com conta. O módulo faz isso só em perfil com conta e guarda os valores de antes para o reverter.
- Foto: `fotos/chrome-antes-e-depois.png` (ignorada pelo git): cópia do perfil real, aplicar pelo módulo, Chrome aberto de verdade: botões morcego, caixão e ossos; a segunda passada e o conferir dão 0 depois do Chrome fechar.
- Limite medido: só com a sincronia PAUSADA (o caso do perfil dela). Com a sincronia ativa a nuvem pode mandar o tema de volta; não foi medido.
- Edge (flatpak, tema da loja com `pack`) e Brave/Chromium não têm binário medido aqui: o módulo tira `id`, `pack` e liga `system_theme`, a mesma chave do motor. Snap: caminhos conferidos só por documentação, sem `snapd`.
- Falta para valer no PC dela (fora do escopo do bloco): `scripts/aplicar_apps.sh` (`pasta_de`) não mapeia os slugs `chrome` e `brave`, que ela já tem no `APPS_ATIVOS`, para a pasta `chromium`; e o `meow.conf` dela não tem `chromium`. O `meow.conf.exemplo` ganhou `chromium`, que o `tests/apps-em-todo-pack.sh` exige.
