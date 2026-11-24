# AGENTS.md

Guia curto para quem vai ler ou mudar este repositório.

## O que é

MeowSystem veste o COSMIC (Pop!_OS 24.04) inteiro a partir de um theme pack: tema, ícones,
painel, dock, terminal, login, papel de parede e os temas de dentro dos programas. Um doctor
confere e conserta sozinho. Bash 4.3+ e Python 3 só com a biblioteca padrão.

## Mapa

Na raiz, cinco pastas e os arquivos `install.sh` (o instalador: etapas idempotentes, a segunda passada não
escreve nada), `meow.conf.exemplo`, `README.md`, `AGENTS.md` e `GSD.md`.

| pasta | o que mora | o que não mora |
|---|---|---|
| `scripts/` | todo o código: uma etapa por arquivo; `pack.py` resolve o pack e o acervo | arte, tema, dado |
| `scripts/meow` | a CLI: `doctor`, `pack`, `icones`, `compositor`, o menu | — |
| `scripts/lib/` | funções comuns (`comum.sh`: log, códigos de saída, travas) | etapa que roda sozinha |
| `scripts/app/` | o painel local: `servidor.py` e `pagina/` (HTML, JS, CSS) | cor: vem da paleta do pack no ar |
| `scripts/oraculo-tema/` | o oráculo do tema, em Rust | o build: compila fora do clone |
| `scripts/temas-de-apps/` | o código de cada app (`manifesto.sh`) | molde e tema de app: moram no pack |
| `dados/` | o que o código lê e não é arte: `contratos/`, `apps/`, `extensoes/`, `pacotes/`, `ponte/`, `zsh/`, o molde `dados/paleta/cosmic-map.json` | desenho, paleta, molde de tema |
| `dados/systemd/` | as unidades de usuário (doctor, vigias `.path`, sentinela) | — |
| `dados/patches/` | as séries de patches: `cosmic-comp` (`series`, `versao`), o portal (`graficos.*`) e a dock (`dock.*`) | — |
| `dados/deb/` | o `control` e o `copyright` do pacote que `scripts/deb.sh` monta | — |
| `packs/` | os theme packs: toda a arte e todo dado de tema (`icones/`, `mascote/`, `wallpapers/`, `temas-de-apps/`, `sons/`, `temas/`) | código, fora a exceção da decisão 67 |
| `tests/` | a suíte; `tests/todos.sh` roda tudo | — |
| `docs/` | o manual (`PACKS.md`, `FRONTEIRA.md`, `ESTADO-FINAL.md`, `MANUTENCAO.md`) e o registro `DECISOES.md` | — |

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
- Agente não roda `install.sh`, `meow compositor` nem `meow doctor --consertar` com o HOME real; quem coordena a
  sessão (o orquestrador) pode.
- Senha nunca vai para commit nem documento; o segredo do askpass mora só no arquivo 600 dele, fora do repositório.
- Commit pequeno, por caminho (nunca `git add -A`), em português.

## Comentários

Zero comentário; o porquê mora no nome, no teste e no commit; informação errada se sobrescreve
no lugar, nunca se acrescenta. Ficam só shebang, licença, diretiva (`shellcheck`, `noqa`) e a
ajuda que o programa imprime de si. `scripts/comentarios.py zerar` corta sem mudar a `impressao`
do código; o `scripts/higiene.sh` zera as linhas novas do commit e corrige número que os testes sabem.

## Onde não ler por padrão

- `docs/sprints/`: só a leva em curso; leia o arquivo citado. O registro antigo mora na cópia de segurança de antes da raiz nova (decisão 24).
- `packs/*/icones/` (milhares de SVG), `docs/capturas/`.
- Dado de terceiro e arquivo gerado, que não se edita: `packs/*/temas-de-apps/*/upstream/`, `packs/*/temas-de-apps/*/vendor/`
  e `packs/*/temas/capturados/`.
- Registro e catálogo, grandes e sem código: os `catalog.json`, as `PROCEDENCIA.md` e `packs/CAMINHOS-DE-ANTES.tsv`.
- O `.ignore` da raiz diz isso ao `rg`: a busca já os pula. Para buscar neles de propósito, use `rg -u` ou passe o caminho do arquivo.
