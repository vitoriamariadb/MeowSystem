# P175 — o que sobrou sem dono (06/11/2026)

Achados da P161, da P164 e da P165.

## O que se mediu

- `/api/precisa-de-gente` não tem leitor em `app/pagina`; a sentinela segue escrevendo em `precisa-de-gente.tsv`, e as linhas antigas `compositor-caiu` e `patch-obrigatorio` ficam nele sem efeito (decisão 55).
- `NA_MAQUINA`, em `app/servidor.py`, crava `v1` no caminho do `CosmicComp`; `scripts/areas.sh` resolve a versão por `meow_cosmic_v`. Se o esquema subir, o painel lê a pasta velha.
- O doctor no modo só leitura chama `sudo -n -l` e `ponte_root.sh estado` (`bin/meow`). Os falsos recusam na suíte, mas a chamada existe.

## A cura

- Sem leitor, a rota e o arquivo saem, ou a tela volta a mostrá-los: vale o que a decisão 55 pede, e a rota morta sai. As linhas antigas somem do arquivo na próxima passada do doctor.
- `NA_MAQUINA` resolve a versão como o `areas.sh`.
- No modo só leitura, o doctor não chama `sudo`.

## Como se prova

`tests/doctor-so-le.sh` sem nenhuma chamada a `sudo` registrada; teste com esquema `v2` no HOME temporário; `tests/precisa-de-gente.sh` ajustado.

## Execução

Commits `c7cb767b` e `1dcb10ae`.

- **O arquivo sem leitor.** Saíram a rota `/api/precisa-de-gente`, `precisa_de_gente()` no servidor e os dois verbos em `lib/comum.sh`. A sentinela guarda o vermelho no `meow.log` e no `sentinela.tsv`, que `meow cosmic sentinela ler` mostra. O arquivo velho, com as linhas `compositor-caiu` e `patch-obrigatorio`, sai pelo `estadovelho` do doctor, só no conserto. Decisão 55 intacta: nada voltou à tela.
- **`NA_MAQUINA`.** `_cosmic_pasta` resolve a versão como `meow_cosmic_v`, olhando `MEOW_COSMIC_SISTEMA`. Vale para o `CosmicComp`, para as barras e para o relógio, e também para os leitores do `CosmicComp` fora da tabela: a noite do applet, a leitura e as áreas fixas.
- **O doctor só lendo.** O `meow doctor` sem `--consertar` exporta `MEOW_SO_LE=1`. Com ele, `chk_ponte` confere arquivo, soma e o `raiz=` do perfil sem sudo; `meow_ponte_viva` olha a regra no disco; `meow_ponte` devolve 127; e o greeter fica em `--`. A medida com a ponte de brinquedo achou mais do que a sprint: 6 chamadas, incluindo `greeter-ver`, e uma delas no carregamento de todo `meow`, por causa do `SEM_CONSERTO`. Esse teste agora roda só antes do conserto.

Provas:

- `tests/doctor-so-le.sh` no código antigo: `1 sudo -n -l`, `3 sudo -n …/ponte_root.sh estado`, `1 sudo -n …/ponte_root.sh greeter-ver`, `1 sudo -n /usr/local/lib/meowsystem/ponte_root.sh estado`. No novo: `ok   nenhum sudo, pkill/kill/killall, e nenhum systemctl/gsettings/dconf que escreva`, `ok   fora do modo só leitura, a ponte viva continua sendo perguntada`, `passou: o doctor só lê, e o sinal não sai de casa`.
- `tests/contrato-cosmic.sh` no código antigo: `FALHA painel: esperava JANELAS_TILING=sim, veio: JANELAS_TILING=nao`. No novo: `ok    painel: JANELAS_TILING=sim, lido do v2`, `ok    painel: as áreas fixas vêm do v2`, `contrato-cosmic: tudo certo`.
- `tests/precisa-de-gente.sh`: `ok    as linhas antigas sumiram com o arquivo`, `ok    a passada seguinte não acha nada`, `precisa-de-gente: tudo certo`.
- Também verdes: `sentinela.sh`, `ponte-reparo.sh`, `ponte-so-reserva.sh`, `doctor-veredito.sh`, `compositor-shim.sh`, `wallpaper-base.sh`, `app.sh`, `areas-em-cada-tela.sh`, `leitura-fonte-unica.sh`, `manter-sem-pendencias.py`.

O preço de não chamar sudo, só no modo de leitura:

- O aviso do `NOPASSWD: ALL` (decisão 43) só aparece no `doctor --consertar`: sem sudo não há como saber. A linha da decisão não mudou.
- O hash da regra de sudo, o do polkit e a tela de login só se conferem no conserto.

Da mão de quem usa: depois do install, o botão de conferir do doctor no painel deve seguir em «nada a consertar», sem falsa divergência na ponte nem no greeter, e o `precisa-de-gente.tsv` deve sumir da casa na primeira passada do conserto.
