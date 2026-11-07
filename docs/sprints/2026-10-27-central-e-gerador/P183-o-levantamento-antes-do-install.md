# P183 — o levantamento antes do install (07/11/2026)

Pedido de quem usa, depois da P182: «Não conseguimos verificar antes e de forma preventiva corrigir os problemas?». Só no CLI.

## O que se mediu

Em 07/11, rodar o install e os builds levou mais de duas horas, porque cada problema só aparecia depois de o anterior sair do caminho: os applets presos, o fonte que o repositório já não servia, o portal do rebuild local, o `/tmp` de 4 GB, os testes presos ao disco, as tags velhas. Cinco dos sete se viam antes de rodar qualquer coisa, só lendo a máquina.

## A cura

`meow levantamento` lê a máquina inteira, sem parar no primeiro achado e sem escrever um byte, e imprime a lista:

- **disco**: o espaço livre no cache contra o que o build do compositor pede;
- **rede**: os nomes que os builds baixam (crates, GitHub, o repositório do Pop);
- **ponte root**: se o sudo da ponte responde sem senha;
- **fontes do apt**: se o repositório ainda serve o fonte de cada pacote que o MeowSystem compila (cosmic-comp, cosmic-files, xdg-desktop-portal-cosmic), já sem o sufixo de rebuild local; e quantos pacotes do COSMIC esperam o apt;
- **builds**: o estado do compositor, do menu e do portal;
- **applets**: os que gravaram falha com o pino atual, com o motivo do cargo;
- **git**: se o clone está no mesmo commit e nas mesmas tags do GitHub;
- **doctor**: as linhas que o doctor diz divergentes.

Sai 0 sem achado e 1 com algum. A versão de base do fonte sai do `graficos.sh` para o `lib/comum.sh` (`meow_versao_do_fonte`), e os dois usam a mesma.

## Como se prova

`tests/levantamento.sh`, com falsos para `df`, `getent`, `apt-cache`, `dpkg-query`, `sudo`, `git`, o `garantir_builds.sh` e o doctor:

- máquina limpa: sai 0 e diz que não há nada a resolver;
- máquina com um problema em cada item: sai 1 e lista todos, na ordem, sem parar no primeiro;
- o HOME fica idêntico byte a byte;
- nenhuma linha manda digitar.

Na máquina real: `meow levantamento` em menos de um minuto.
