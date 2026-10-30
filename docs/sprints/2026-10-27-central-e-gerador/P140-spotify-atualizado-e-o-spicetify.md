# P140 — o Spotify atualiza e o spicetify para de aplicar, calado

Anotada em 29/10, no install final da leva (HOME real).

## O que se mediu
- Passagem 1: `erro o 'spicetify apply' falhou — o Spotify segue com o tema de antes`, com o aviso do spicetify
  v2.46.4: «Preprocessed Spotify data is outdated. Please run "spicetify restore backup apply"».
- Passagem 2: `ok Spotify já está em catppuccin/meumeowportatil, do pack meowsystem — nada a fazer`, e o install fecha
  com `rc=0`. A conferência lê o `config-xpui.ini`, não o Spotify aplicado: diz que está certo o que não foi aplicado.

## Cura na origem
- O módulo `scripts/temas-de-apps/spotify/` reconhece o Spotify atualizado (o aviso «outdated», ou o backup de outra
  versão) e refaz sozinho o `spicetify backup apply` / `restore backup apply` (decisão 7: o doctor corrige).
- A conferência confere o tema aplicado no Spotify, não só a config; com o apply falhado, ela não diz «nada a fazer».

## Prova
- Teste com um `spicetify` falso que responde «outdated» no primeiro apply: o módulo refaz o backup e aplica; a
  segunda passada não escreve; com o apply falhando de verdade, a conferência sai divergente, não ok.
- Na máquina dela: o Spotify aberto com o tema do pack.

## Execução

Bloco `apps`, branch `bloco/apps-p140`, 29/10/2026.

- **Item.** `scripts/temas-de-apps/spotify/manifesto.sh`. A conferência passou a olhar o que o spicetify aplicou, não só
  o `config-xpui.ini`: o módulo grava `~/.local/state/meowsystem/temas-de-apps/spotify/aplicado` (tema, esquema, sha256
  do `color.ini`, versão do spicetify e pasta do app) só depois de um apply que deu certo, e compara com ele. Apply
  que falhou, ou app que atualizou, fica divergente. O aviso «outdated» (ou o backup de outra versão) faz o módulo
  refazer o backup sozinho, com o Spotify fechado: app de fábrica leva o backup velho para
  `~/.local/state/meowsystem/backups/spotify-spicetify-<data>` e roda `backup apply`; app já com o tema roda
  `restore backup apply`. `RECUPERACAO.md` ganhou o resumo do automático.
- **Commit.** `fix(spotify): o apply desatualizado refaz o backup do spicetify sozinho, e a conferência olha o que foi aplicado`.
- **Prova.** `tests/spotify-atualizado.sh` (registrado no `todos.sh`), com `spicetify` falso num HOME de brinquedo:
  a passada que ouve «outdated» refaz o backup e aplica; a segunda passada não escreve; com o apply falhando de verdade
  a conferência sai divergente; sem rede. Contra o módulo antigo o teste tinha 8 falhas; contra o novo, `tudo certo`.
  A suíte inteira está no fim da `## Execução` da P141.
- **Ficou de fora.** O Spotify real dela não foi tocado (regra do bloco): «o Spotify aberto com o tema do pack» é
  o que ela confere com a mão depois do merge. Dois efeitos além do pedido: a frase «tire 'spotify' de APPS_ATIVOS»
  saiu do reverter (ver P141), e a conferência passou a divergir uma vez no HOME dela, até o primeiro apply bom
  gravar o `aplicado`.

### Conferência (29/10)

- **Achado 1: janela em branco.** Com o backup de outra versão e o app já modificado, o refazer rodava
  `restore backup apply` e copiava a UI velha para o app novo. Agora isso dá erro antes de qualquer `spicetify config`,
  e nada é mexido (prova 3b nova em `tests/spotify-atualizado.sh`).
- **Achado 2: pergunta do spicetify.** A cadeia `restore backup apply` pergunta «There is available backup… [y/N]».
  Sem terminal ela recusa; com o stdin num tty, a saída capturada por `$()` trava sem aparecer. Agora roda com `-q`, só
  quando o backup é da versão do app, e toda chamada ao spicetify roda com `</dev/null`. O `spicetify` falso do teste
  pergunta como o real, e a prova 2 só fica verde com o `-q`.
- **Commit.** `fix(spotify): backup de outra versão com app modificado não restaura; cadeia do spicetify com -q e sem terminal`.
- **No HOME dela (só leitura).** `[Backup] version` é igual ao flatpak (1.2.95.453), o app está tematizado e o
  spicetify é o 2.46.4. O caminho real é `apply`, ou `-q restore backup apply` se o spicetify disser «outdated».
- **Só a máquina prova.** Que o `-q` do spicetify 2.46.4 responde sim nessa pergunta, e que o Spotify abre com o tema.
