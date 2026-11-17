# Estado da leva de 17/11 (coordenador)

| tarefa | árvore / branch | situação |
| --- | --- | --- |
| P212 navegadores no modo GTK | `.meow-wt-navegadores` / `bloco/navegadores` | conferida e corrigida (só o tema sai da sincronia, perfil só conectado à conta, Edge sem sincronia tocada); foto com cópia do perfil real; falta a integração |
| P213 Electron | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |
| P214 Qt e outros formatos | `.meow-wt-toolkits` / `bloco/toolkits` | escrita; agentes a lançar |

## Próximo passo
1. Criar as duas árvores a partir do `master` e lançar os dois workflows (4 agentes: 2 por bloco).
2. Integrar cada bloco em `integracao/2026-11-17` quando o conferente voltar; suíte inteira; `master`; push.
3. Coordenador: `meow doctor --consertar` real com Chrome e Edge fechados; quem usa confere as fotos.

## P212: o que se mediu e o que falta (agente implementador, 17/11)
- Medido com perfil temporário (Chrome 157): no perfil novo, `extensions.theme.system_theme = 1` sem `id` já vale o modo GTK e o Chrome não reescreve. No perfil REAL (cópia com a conta Google, sincronia pausada) isso NÃO basta: ao abrir, o Chrome devolve `id = user_color_theme_id` e `system_theme = 0`, porque o tema vem da conta.
- Conferente, 17/11: o `sync.keep_everything_synced = false` sozinho desligava TODOS os tipos de sincronia (o Chrome registra cada `sync.<tipo>` com padrão falso). Corrigido: no perfil que sincroniza tudo, o módulo grava `keep_everything_synced = false`, `themes = false` e os outros 13 tipos do Chrome 157 (`strings` do binário) em `true`; no perfil que já escolhe tipos, só `themes = false`. O perfil só conectado à conta (`Profile 14` dela, sem `has_setup_completed`) ignora essas chaves: medido que precisa de `sync.selected_types_per_account[<hash da conta>]["sync.themes"] = false` e de tirar `browser.theme.saved_local_theme`, senão o Chrome restaura o Clássico guardado. O Edge (tipos próprios: `collections`, `edge_wallet`) não tem a sincronia tocada. O reverter devolve a sincronia mesmo com o tema trocado à mão.
- Foto do conferente: `fotos/chrome-real-antes-e-depois.png` (ignorada pelo git): cópias do `Default` e do `Profile 14` reais, HOME temporário, aplicar pelo módulo, Chrome aberto de verdade: em cima o Clássico (botões genéricos), embaixo os dois perfis com morcego e caixão do pack; o conferir e a segunda passada dão 0 depois do Chrome fechar.
- Limite medido: só com a sincronia PAUSADA (o caso do perfil dela). Com a sincronia ativa a nuvem pode mandar o tema de volta; não foi medido.
- Edge (flatpak, tema da loja com `pack`) e Brave/Chromium não têm binário medido aqui: o módulo tira `id`, `pack` e liga `system_theme`, a mesma chave do motor. Snap: caminhos conferidos só por documentação, sem `snapd`.
- Falta para valer no PC dela (fora do escopo do bloco): `scripts/aplicar_apps.sh` (`pasta_de`) não mapeia os slugs `chrome` e `brave`, que ela já tem no `APPS_ATIVOS`, para a pasta `chromium`; e o `meow.conf` dela não tem `chromium`. O `meow.conf.exemplo` ganhou `chromium`, que o `tests/apps-em-todo-pack.sh` exige.
