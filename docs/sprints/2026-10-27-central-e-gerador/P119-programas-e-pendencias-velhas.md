# P119: a busca de programas, duas pendências do Manter e a limpeza que ficou

Item 5 do `ANDAMENTO.md` (foto 3) e o rabo da leva QA final (`docs/sprints/2026-10-26-qa-final/ANDAMENTO.md:9-14`).

## O que se mediu
- **Busca de programas**, Playwright headless, Definir → Programas em 1920 px (`capturas/painel/programas-1920.png`).
  - Os dois `input.ficha-nova` têm 160 px.
  - O de «Escondidos» fica numa caixa de 850 px e o de «Não abrem sozinhos» numa de 160 px.
  - O texto de exemplo aparece cortado: «Procurar um prog».
  - A lista é um `<datalist>` nativo, cuja janela de sugestões o Chromium desenha larga e com o id em negrito (foto 3).
- **Spotify no Manter.**
  - `scripts/temas-de-apps/spotify/manifesto.sh:332` grava a pendência `spicetify-tema-ausente`, com o comando `meow apps aplicar spotify`.
  - `app/servidor.py` não tem esse id nem em `ACAO_DA_PENDENCIA` nem em `NOME_DA_PENDENCIA` (linhas 4296-4323).
  - Resultado: o cartão sai sem nome e sem «Resolver» (`conferencia-b.md:50`).
- **«Regravar o som».**
  - `scripts/som.sh:_som_tema()`, linha 177, chama `meow_guardar_pasta "$SOM_TEMA_DIR"` antes de o Python comparar origem e destino.
  - Com tudo no lugar, o `tocados.tsv` ganha a linha `pasta`.
  - O `_guardar_restauro()` do servidor guarda o restauro e o painel mostra «Restaurar». Esse «Restaurar» devolve uma cópia idêntica (`conferencia-a.md:48`).
- **Citações a `docs/pesquisas/`.** Seis arquivos rastreados citam uma pasta que saiu do dev pela decisão 24:
  - `assets/contratos/cosmic.tsv:3`;
  - `packs/dracula/PROCEDENCIA.md:107`;
  - `patches/LEIA-ME.txt:301`;
  - `patches/cosmic-comp-modo-leitura.patch:48,117`;
  - `scripts/oraculo_tema.py:15`.
  - A ponta da branch `arquivo` não tem `docs/pesquisas/` (`git ls-tree -r arquivo | grep -c pesquisas` dá 0). Os textos só existem antes de `1b15ccb1`.
- **Ganchos.** `.git/hooks` tem 13 cópias `.bak-*` e `.antes-meowsystem`, além dos `.sample`. Nenhum roda, porque `git config core.hooksPath` aponta para `~/.config/git/hooks`.
- **Imagens.** `docs/capturas/desktop-claro.png`, `fastfetch.png` e `lancador.jpg` são rastreadas desde `32ad49d5` (06/09) e nenhum arquivo fora de `docs/sprints/` as cita.

## Causa
- **Busca:** `app/pagina/app.js:controleLista()` usa `<datalist>` e a classe `campo ficha-nova`, e `app/pagina/estilo.css:211` fixa `.ficha-nova { width: 160px }`. O componente da maquete aprovada (`docs/sprints/2026-10-26-qa-final/maquete/a/definir.js:sugestoes()`/`porFicha()`) não foi portado. O CSS dele (`.nova-ficha`, `.sugestoes`, `estilo.css:655-659,712-713`) já está lá, sem uso.
- **Spotify:** a P109 perdeu a entrada do `NOME_DA_PENDENCIA`, e a P113 tirou o download sem dar outra ação.
- **Som:** em `som.sh:_som_tema()`, o «guardar antes» vem antes de saber se algo muda.
- **Os três de limpeza:** sobraram da P96 (decisão 24).

## Cura na origem
1. Portar o combobox da maquete para `controleLista()`:
   - wrapper `.nova-ficha` com `role=combobox`;
   - lista `.sugestoes` com ícone, nome e id pequeno, no máximo 8 resultados, setas e Enter;
   - o campo com a largura da lista (`min(360px, 100%)`), e o texto de exemplo da maquete: «Esconder um programa» e «Impedir um programa».
   - Tirar o `<datalist>` e o `width: 160px`.
2. `NOME_DA_PENDENCIA["spicetify-tema-ausente"] = "Tema do Spotify"` e `ACAO_DA_PENDENCIA["spicetify-tema-ausente"] = "apps_aplicar"`. Essa ação aplica o tema do pack nos programas marcados e não baixa nada.
3. `som.sh:_som_tema()`: o Python diz primeiro se mudaria (como já faz no modo `conferir`), e o `meow_guardar_pasta` só roda quando a resposta é sim.
4. As seis citações passam a dizer `git show 1b15ccb1^:docs/pesquisas/<arquivo>`. O `tests/decisoes.sh` (prova 24) ganha a regra: arquivo rastreado fora de `docs/sprints/` não cita `docs/pesquisas/` sem esse `git show`.
5. Tirar as três imagens órfãs. Os `.bak-*` de `.git/hooks` saem com a palavra dela, porque são locais e não são do repositório.

## Prova
- `tests/app-completo.py --aba ajustes/programas`, Playwright headless:
  - o campo tem pelo menos 300 px;
  - digitar «brinq» mostra uma opção com o nome «Leitor de Brinquedo»;
  - Enter cria a ficha `org.gnome.Evince`;
  - não existe `datalist` na página.
- `tests/app-completo.py --aba cuidar`, com `spicetify-tema-ausente` plantada no `pendencias.tsv`: o cartão tem o título «Tema do Spotify» e o botão `acao:apps_aplicar`.
- `tests/sons-do-pack.sh`, caso novo, com `som.sh aplicar` duas vezes no HOME temporário e `MEOW_BACKUPS` apontado:
  - a segunda passada deixa o `tocados.tsv` vazio ou ausente;
  - o servidor não oferece «Restaurar» depois dela.
- `tests/decisoes.sh` verde com a regra nova, e vermelho com uma citação crua plantada.

## Arquivos
`app/pagina/app.js`, `app/pagina/estilo.css`, `app/servidor.py`, `scripts/som.sh`,
`assets/contratos/cosmic.tsv`, `packs/dracula/PROCEDENCIA.md`, `patches/LEIA-ME.txt`,
`patches/cosmic-comp-modo-leitura.patch`, `scripts/oraculo_tema.py`, `docs/capturas/` (as três),
`tests/app-completo.py`, `tests/sons-do-pack.sh`, `tests/decisoes.sh`.

## Item do coordenador (27/10)
- `scripts/painel.sh` (perto da função `reciclar`, ~linha 144) imprime para digitar «meow painel reciclar». Regra:
  nenhuma saída manda digitar. Cura: a saída diz o que acontece e o doctor (ou o botão «Reiniciar o painel» da P120)
  faz; prova em `tests/frases-velhas.sh` (nenhum «digite»/«rode `meow`» nas saídas de `scripts/`).

## Fora desta sprint
- A P123 leva `docs/pesquisas/` para a branch `arquivo`. Se ela entrar antes, a citação do item 4 passa a ser `arquivo:docs/pesquisas/<arquivo>`, e a regra do `decisoes.sh` aceita as duas formas. A cópia local de `docs/pesquisas/` não tem os dois arquivos de `2026-10-09`; eles só existem em `1b15ccb1^`.
- O comentário `# POR QUE ESTE ARQUIVO EXISTE` do `cosmic.tsv` contraria a regra de zero comentário. Quem resolve é o `scripts/higiene.sh`, não esta sprint.
- Mudar o `patches/series` não entra.
