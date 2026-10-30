# P141 — os módulos de app param de mandar digitar, e o fundo do chat do ZapZap

Anotada em 29/10, das pendências legadas do `ANDAMENTO.md` (28/10 e 29/10).

## O que se mediu
- `scripts/temas-de-apps/qbittorrent/manifesto.sh:445` e `:483`: o reverter termina com «tire 'qbittorrent' de
  APPS_ATIVOS no meow.conf, ou o doctor das 05:00 reaplica». Saída que manda editar arquivo (decisão: o doctor
  corrige; nenhuma saída manda digitar). Sem o passo, o doctor das 05:00 reaplica o tema que ela acabou de tirar.
- `scripts/temas-de-apps/waterfox/manifesto.sh:34`: «nenhum perfil em profiles.ini ainda — abra o Waterfox uma vez».
- ZapZap: anotado em 28/10 «o fundo do chat do ZapZap» sem medida. Medir primeiro: o CSS que o módulo gera
  (`zapzap.modelo.css` preenchido) contra o DOM do WhatsApp Web que o ZapZap carrega; o fundo da conversa
  (a área atrás das bolhas, com o papel de parede do WhatsApp) fica com a cor de fábrica ou com a do pack?

## Cura na origem
- Reverter um app é desligar o app: o reverter do qBittorrent tira `qbittorrent` do `APPS_ATIVOS` pelo mesmo
  caminho de escrita do `meow.conf` que o painel usa (a escrita única da P139), e a frase vira só o fato.
  Se outros módulos têm a mesma frase, o mesmo conserto vale para eles (`grep -rn APPS_ATIVOS scripts/temas-de-apps`).
- Waterfox sem perfil: a saída diz o estado sem ordem («ainda sem perfil; o tema entra quando o perfil existir»), e o
  tema entra sozinho na passada seguinte do doctor depois que o perfil nasce (vigia ou a passada normal; o que for
  mais simples e provado).
- ZapZap: se a medida confirmar o fundo de fábrica, o modelo pinta o fundo da conversa com a cor do pack (as duas
  paletas); se não confirmar, a `## Execução` registra a medida e nada muda.

## Prova
- Teste: reverter o qBittorrent num HOME de brinquedo tira `qbittorrent` do `APPS_ATIVOS`; a segunda passada não
  escreve; nenhuma saída dos módulos tocados contém «meow.conf», «abra», «rode», «digite».
- Waterfox: HOME sem perfil não sai com ordem; com o perfil criado, a passada seguinte aplica.
- ZapZap: o CSS gerado com as paletas `meowsystem` e `dracula` tem a regra do fundo; teste do módulo verde.

## Execução

Bloco `apps`, branch `bloco/apps-p140`, 29/10/2026.

- **qBittorrent e a mesma frase nos outros.** `meow_app_desligar` (em `lib/comum.sh`) tira o slug do `APPS_ATIVOS`
  por `meow_conf_definir`, o caminho único que o painel usa, e diz só o fato («qbittorrent desligado — o doctor das 05:00
  não reaplica»). Idempotente: a segunda passada não acha o slug e não escreve; no «ver sem mudar» não escreve.
  A mesma frase de ordem existia em doze módulos (vscode, onlyoffice, telegram, kitty, toolkits-gtk-qt, btop-bat,
  gnome-terminal, zapzap, discord, obsidian, qbittorrent, spotify), e todos passaram a chamar a função (a sprint
  mandava estender se houvesse). `lib/desinstalar.sh` roda o reverter com `MEOW_REVERTER_SEM_DESLIGAR=1`: desinstalar
  apaga o `meow.conf` inteiro e não precisa reescrevê-lo antes. Mais duas frases de ordem do qBittorrent saíram
  («veja a PROCEDENCIA.md», «feche-o»). Ficam, fora do pedido, «feche-o» no OnlyOffice (`:221`) e no Obsidian (`:454`).
- **Waterfox.** «ainda sem perfil; o tema entra quando o perfil existir». Mais simples e provado: a passada normal
  seguinte, sem vigia novo.
- **ZapZap, a medida.** O WhatsApp Web (cache do ZapZap) define o papel de parede do chat em duas variáveis,
  `--WDS-systems-chat-background-wallpaper` e a irmã `-RGB`, e o mesmo vale para a bolha recebida e a bolha sobreposta.
  O modelo pintava a cor, mas deixava os três `-RGB` de fábrica: o que usa os canais (`rgba(var(...), alfa)`)
  continuava com a cor de fábrica. Defeito real, confirmado; o modelo ganhou as três linhas `-RGB` (`{{crust:rgb}}`,
  `{{base:rgb}}`, `{{mantle:rgb}}`). **Não provado offline:** se a classe do tema de conversa que o usuário escolhe
  fica num descendente que sobrescreve a regra de `:root`. Só a vista dela no ZapZap aberto fecha isso.
- **Commits.**
  - `fix(apps): reverter um app desliga o app no APPS_ATIVOS pela escrita única do meow.conf, e a frase vira só o fato`
  - `fix(apps): Waterfox sem perfil diz o estado, e o fundo da conversa do ZapZap ganha os canais RGB do pack`
  - o fecho do bloco, com as frases do qBittorrent, o `--help` do `meow apps reverter` e os números dos README.
- **Prova.** `tests/apps-frases.sh` (11 provas, no `todos.sh`): o reverter do qBittorrent tira o slug e mantém o
  comentário da linha; a segunda passada não escreve; a saída não tem «meow.conf», «abra», «rode», «digite»; Waterfox sem
  perfil sem ordem e, com o perfil criado, a passada seguinte aplica e a outra não escreve; o CSS do ZapZap com as paletas
  `meowsystem` e `dracula` tem a regra do fundo da conversa, com os canais RGB.

### Conferência (29/10)

- **ZapZap, provado offline.** No cache do WhatsApp Web, `WAWebConversationPanelWrapper` põe o `wallpaperStyle` do tema
  de conversa (`WAWebChatThemeDefinitions.stylex`, 236 classes, 17 variáveis `--WDS-*`) no `div#main`. O `bubbleStyle`
  e o `WAWebVibrantOutgoingOverrides` vão nos descendentes da mensagem. Esses elementos declaram as variáveis eles
  mesmos, e o `!important` do `:root` não alcança variável redeclarada num descendente. Cura no modelo:
  - `#main` entrou na lista de seletores;
  - uma regra `#main *` põe `inherit !important` nas 17 variáveis do tema de conversa.

  Prova: `tests/zapzap-tema-de-conversa.py`, headless e no `todos.sh`. Sem o `#main`, o tema de conversa vence; com
  ele, fundo, frente, bolhas e acento ficam no pack.
- **`meow_app_desligar`.** Usa a escrita única (`meow_conf_definir`), não desliga no `desinstalar`
  (`MEOW_REVERTER_SEM_DESLIGAR=1`), e o painel fica coerente. Faltava em heroic, krita, libadwaita, obs e waterfox,
  e o `--help` prometia para todos: os cinco ganharam a chamada.
- **Frases.** «feche-o» saiu do OnlyOffice e do Obsidian. O desfazer com o app aberto dizia «sai na próxima passada»
  (qBittorrent, Heroic, Obsidian), e nenhuma passada refaz um desfazer: agora diz «nada foi desfeito, e o tema fica».
- **Commits.**
  - `fix(zapzap): o tema de conversa do WhatsApp não vence a paleta no #main nem nas bolhas`
  - `fix(apps): heroic, krita, libadwaita, obs e waterfox também se desligam do APPS_ATIVOS ao desfazer`
  - `fix(apps): app aberto no desfazer diz que nada foi desfeito, sem «feche-o» nem promessa de passada`
- **Anotado para a P142.** O reverter do ZapZap ainda manda `flatpak update com.rtosta.zapzap`.
- **Só a máquina prova.** O ZapZap aberto, com um tema de conversa escolhido, no pack.
- **Suíte inteira (conferência).** `./tests/todos.sh`: 124 testes, 122 verdes, 0 pulados, 2 vermelhos.
  - `restaurar.sh` é vermelho aceito.
  - `temas-por-app.sh` caiu porque o `meow.conf` que o desfazer cria no HOME de brinquedo traz `#1E1E2E` no texto
    do exemplo. O teste deixou de contar o `meow.conf` como arquivo com tema, e rodado sozinho dá 78 provas, tudo verde.
