# P235 — janelas do sistema sem ícone no dock (17/11/2026)

Texto de quem usa, 17/11 (foto do diálogo «Abrir arquivo» com a engrenagem genérica no dock): «cosmic files dialog
aparece sem icone. ele não é o único já vi isso ocorrer com várias coisinhas do sistema operacional assim.»

## O que se mediu (coordenador, 17/11)
- O diálogo do portal (`org.freedesktop.portal.FileChooser.OpenFile`) abre uma janela com app_id
  `com.system76.CosmicFilesDialog` e título vazio (`scripts/appid_sonda.py --janelas`). Não há `.desktop` com esse id
  nem `StartupWMClass` igual, e o `cosmic-app-list` casa por igualdade de string inteira: sai a engrenagem.
- O mecanismo de cura já existe: `assets/apps/appid.map` (app_id medido → `.desktop` real) gera a «ponte»
  (`X-MeowSystem=janela-dock`), e a sonda tem `--casar` e `--sugerir`. Falta o parque das janelas do SISTEMA, que só
  aparecem quando um diálogo abre.

## A cura na origem
1. Medir, abrindo cada janela do sistema pelos caminhos que não mudam nada: portais (`FileChooser` OpenFile,
   SaveFile e pasta; `OpenURI` com escolha de app; `Screenshot` interativo; `Print` se houver backend), prompt do
   chaveiro (`gcr-prompter`/`gcr4`), pedido de senha do Wi-Fi do applet de rede, agente do polkit (abrir e CANCELAR:
   nunca autenticar), `pinentry`, as páginas do `cosmic-settings`, o `cosmic-initial-setup`, o `cosmic-osd` e o que
   mais o varrimento de `strings` dos binários `cosmic-*`, `xdg-desktop-portal-*` e `/usr/libexec/*` sugerir com
   prefixo de domínio reverso. Toda medição é no palco (`scripts/palco.sh`, P238), e cada janela fecha com ele: o
   diálogo do `xdg-desktop-portal-cosmic` NÃO fecha por `Request.Close` (o backend não exporta Request, a chamada
   dá `UnknownObject`) nem morre com a conexão de quem chamou (medido: o diálogo seguiu aberto depois).
2. Cada app_id medido sem casamento vira linha no `appid.map` para o `.desktop` dono (diálogo de arquivos →
   `com.system76.CosmicFiles`, prompt do chaveiro → o das senhas, etc.), com a medição escrita no bloco de
   comentário do mapa (o mapa é dado, e o formato dele já aceita essa nota). Sem dono possível: anotar no mapa por
   quê, como o `CosmicScreenshot` já está.
3. A ponte respeita o que o mapa já exige: nunca vencer um `.desktop` real, `alias` quando dois app_id vão ao mesmo
   alvo, idempotente.

## Como se prova
Teste com HOME temporário e a sonda falsa (o `tests/janela-sem-app-id.sh` tem o compositor falso): as janelas novas
casam depois da ponte, a segunda passada não escreve. Na máquina, depois do install (coordenador): abrir o diálogo
de arquivos e ver o ícone do Gestor de Arquivos no dock.

## Medido (agente do bloco, 17/11, tudo no palco)
- Sem casamento, e curado no `appid.map`: só `com.system76.CosmicFilesDialog` (FileChooser OpenFile, SaveFile e
  pasta, o mesmo app_id) → `com.system76.CosmicFiles`.
- Já casam (a ponte seria recusada): `xdg-desktop-portal-gtk` («Abrir com» e «Imprimir», no `.desktop` «Portal»,
  `Icon=applications-system-symbolic`), `gcr-prompter` (chaveiro e `pinentry-gnome3`), `cosmic-settings` e as
  páginas dele, `cosmic-initial-setup`, `cosmic-store`, `cosmic-monitor`.
- Sem toplevel (superfície de camada, a dock nunca vê): Screenshot interativo, ScreenCast, Access, o agente do
  polkit do `cosmic-osd` (aberto com um polkitd e um logind falsos num barramento privado do palco, e cancelado),
  `cosmic-osd`, `cosmic-launcher`, `cosmic-app-library`, `cosmic-workspaces`.
- Fora do alcance do palco: a senha do Wi-Fi do applet de rede e o `nm-connection-editor` (pedem o NetworkManager
  do sistema); o `gcr-ssh-askpass` só roda chamado pelo `gcr-ssh-agent`.
- O que o palco não prova: a dock real desenhando o ícone (o painel não sobe lá), a GPU real e duas telas. A prova
  na máquina continua com o coordenador, depois do install.
