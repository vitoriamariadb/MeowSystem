# Manutenção: o que acontece sozinho depois de cada atualização

O MeowSystem mantém dois builds próprios: o compositor (`cosmic-comp` com a série de `patches/`) e o
menu de papel de parede da área de trabalho (`cosmic-files`). Cada build vale para uma versão do
pacote. Quando o apt troca a versão, o build é refeito sozinho, sem sudo e sem pergunta.

## A cadeia de atualização

Os passos abaixo são os da cadeia de manutenção completa, a que roda na máquina de origem:
`sudo apt update && sudo apt full-upgrade && topgrade && sudo apt autoremove && cargo update && sudo apt autoclean && limpar_cache`.
O `limpar_cache` é uma função do shell daquela máquina, e não do MeowSystem; a linha dele vale
para qualquer limpeza do `~/.cache`.

| Passo | O que o MeowSystem faz |
|---|---|
| `apt update` | Nada. Nenhuma versão mudou, e nenhum byte é escrito. |
| `apt full-upgrade` | O hook de apt toca o carimbo, e o `meow-pos-apt` acorda. O menu é compilado primeiro (minutos), depois o compositor (até meia hora, com prioridade mínima). |
| `topgrade` | Nada, se não trouxer COSMIC novo. Se trouxer, vale o passo de cima. |
| `apt autoremove`, `apt autoclean`, `apt clean` | Nada. O fonte baixado fica guardado em `~/.local/share/meowsystem/fontes/`, fora do cache do apt. |
| `cargo update` | Não é do MeowSystem. Fora de uma pasta de projeto ele sai com o código 101, e um `&&` depois dele interrompe o resto da cadeia. |
| `limpar_cache` | O `~/.cache` some, e os builds continuam. A árvore de compilação se refaz do fonte guardado no próximo build. |

## Os três gatilhos

Os três chamam a mesma função, `scripts/garantir_builds.sh`. Ela compila só o que falta para a versão
instalada. Uma segunda passada não escreve nada.

1. **Depois de todo apt**: `meow-pos-apt.path`, que vigia o carimbo do hook.
2. **Uma vez por login**: `meow-builds-login.service`. Ele pega o apt feito com a sessão fechada ou
   pelo TTY, quando nenhum vigia de usuário está de pé.
3. **No doctor**: às 5h e no «Consertar» do painel. O build roda em segundo plano, e a linha
   `patches` do doctor mostra «construindo».

Uma passada por vez: se o apt chega no meio do build do login, ele espera e confere de novo.

## Antes do apt

`meow cosmic prever` lê o COSMIC que está na fila do apt, sem instalar nada, e diz se a série de
patches e o esquema de chaves vão entrar na versão nova. O build pergunta ao fonte do
`cosmic-comp` qual receita ele traz: `just build-vendored` (do 4d14528 em diante), `make VENDOR=1`
(os fontes de antes) ou, sem nenhuma das duas, o `cargo build --frozen --offline` direto.

## O que só vale no próximo login

- **O compositor.** A sessão aberta segura o binário antigo. O build novo entra no próximo login,
  pelo shim em `~/.local/bin/cosmic-comp`. No doctor, a linha diz «build pronto, vale no próximo login».
- **O menu da área de trabalho.** Janelas novas do gerenciador de arquivos já trazem o menu novo. A
  área de trabalho só o mostra no próximo login.

## Quando um build não sai

- **Patch obrigatório que não entra na versão nova.** Nada é trocado, e a sessão sobe com o
  compositor de fábrica. A versão espera um rebase do patch, num commit. Até lá nenhum gatilho
  tenta de novo; quando o commit chega em `patches/`, o próximo gatilho compila a mesma versão.
- **Patch opcional que não entra.** Ele sai do build, e só o efeito dele fica de fora.
- **Erro de rede ou de compilação.** O próximo gatilho tenta de novo. O registro do compositor fica em
  `~/.cache/meowsystem/cosmic-comp/compilar-<versão>.log`.
- **Build que cai duas vezes seguidas ao subir a sessão.** A guarda do shim o põe de lado, e a
  sessão volta ao compositor de fábrica até a próxima versão.

## Como voltar

Na página Extensões, aba Builds, **Remover** no cartão do Compositor tira o shim e grava
`COMPOSITOR="nao"` no `meow.conf`; o próximo login usa o compositor do pacote. Os builds ficam
guardados, sem efeito. **Instalar** no mesmo cartão religa o shim. Com `COMPOSITOR="sim"`, o install
e o doctor ligam o shim sozinhos quando o build da casa está pronto.

Para o menu da área de trabalho, ponha `FILES_MENU="nao"` no `meow.conf`. O doctor seguinte devolve o
menu de fábrica.

O que o projeto entrega, o que roda sozinho e quando, e o caminho de volta de cada coisa estão
em [`ESTADO-FINAL.md`](ESTADO-FINAL.md).
