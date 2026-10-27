# AGENTS.md

Guia curto para quem vai ler ou mudar este repositório.

## O que é

MeowSystem veste o COSMIC (Pop!_OS 24.04) inteiro a partir de um theme pack: tema, ícones,
painel, dock, terminal, login, papel de parede e os temas de dentro dos programas. Um doctor
confere e conserta sozinho. Bash 4.3+ e Python 3 só com a biblioteca padrão.

## Mapa

| pasta | o que tem |
|---|---|
| `install.sh` | o instalador: etapas idempotentes, a segunda passada não escreve nada |
| `bin/meow` | a CLI: `doctor`, `pack`, `icones`, `compositor`, o menu |
| `lib/` | funções comuns (`comum.sh`: log, códigos de saída, travas) |
| `scripts/` | uma etapa por arquivo; `pack.py` resolve o pack e o acervo; `temas-de-apps/` é o código de cada app |
| `app/` | o painel local: `servidor.py` e `pagina/` (HTML, JS, CSS) |
| `packs/` | os theme packs, só dados: `icones/`, `mascote/`, `wallpapers/`, `temas-de-apps/`, `sons/`, `temas/` |
| `assets/` | o que o programa usa em todo pack: modelos que a paleta preenche, mapas de app, `contratos/` |
| `patches/` | a série de patches do `cosmic-comp` (`series`, `versao`) |
| `src/` | applets e o oráculo em Rust |
| `systemd/` | unidades de usuário (doctor, vigias `.path`, sentinela) |
| `tests/` | a suíte; `tests/todos.sh` roda tudo |
| `docs/` | manual (`PACKS.md`, `FRONTEIRA.md`, `ESTADO-FINAL.md`, `MANUTENCAO.md`) e o registro `DECISOES.md` |

## Rodar a suíte

```bash
./tests/todos.sh             # tudo (a máquina com COSMIC)
./tests/todos.sh --portatil  # só o que roda sem COSMIC (CI)
```

O `todos.sh` já monta um HOME temporário, põe no PATH falsos que recusam escrita (`sudo`,
`pkexec`, `su`, `apt`, `pkill`, `systemctl` de escrita) e tira o barramento da sessão. Teste
avulso fora dele precisa do mesmo: `sudo` aqui é sem senha e escreve no sistema real.
Os testes de navegador usam o primeiro `python3` com Playwright (PATH, pyenv ou
`~/.local/share/meowsystem/venv-testes`).

Pulado não é verde. Toda afirmação precisa de prova rodada.

## Regras invioláveis

- Leia [`GSD.md`](GSD.md): as regras, as decisões e as armadilhas, cada uma guardada por
  `tests/decisoes.sh`.
- Decisões de quem usa: [`docs/DECISOES.md`](docs/DECISOES.md). Só se desfazem com sim explícito
  sobre o tema.
- O doctor corrige; nenhuma saída manda digitar. Interface mostra, não explica.
- Pack é dado. A arte mora no pack.
- Não rode `install.sh`, `meow compositor` nem `meow doctor --consertar` com o HOME real.
- Senha nunca vai para arquivo, commit ou documento.
- Commit pequeno, por caminho (nunca `git add -A`), em português.

## Comentários

Zero comentário; o porquê mora no nome, no teste e no commit; informação errada se sobrescreve
no lugar, nunca se acrescenta. Ficam só shebang, licença, diretiva (`shellcheck`, `noqa`) e a
ajuda que o programa imprime de si. `scripts/comentarios.py zerar` corta sem mudar a `impressao`
do código; o `scripts/higiene.sh` zera as linhas novas do commit e corrige número que os testes sabem.

## Onde não ler por padrão

- `docs/sprints/`: só a leva em curso; leia o arquivo citado. O registro antigo mora na branch
  `arquivo`.
- `packs/*/icones/` (milhares de SVG), `docs/capturas/`.
