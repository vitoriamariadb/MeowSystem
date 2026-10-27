# `app/`: o painel

Uma página local que faz pela tela tudo o que se faz editando o `~/.config/meow/meow.conf` ou
digitando `meow`. As 123 chaves, com o valor escolhido, o de fábrica e o porquê atrás do **?**; e
67 ações, com a saída aparecendo ao vivo enquanto rodam.

```bash
./app/run.sh        # ou: meow abrir, ou o ícone MeowSystem no lançador
```

`app/` e não `painel/` porque «painel» já é a barra de cima do COSMIC (`scripts/painel.sh`,
`meow-painel.service`). `apps`, no plural, são os programas que o projeto veste; `app` é este.

## O que tem dentro

```
app/
  run.sh          sobe o servidor, abre o navegador e derruba tudo ao sair
  servidor.py     lê o conf, escreve pelo meow_conf_definir, roda as ações
  pagina/
    index.html    o esqueleto (nenhum nome de chave nele)
    lugares.js    as quatro portas e o que cada uma mostra
    app.js        monta a tela a partir do que o servidor derivou
    paginas.js    Tema, Criar tema e Cuidar
    oficina.js    o seletor e a oficina de ícones
    mesa.js       a prévia da área de trabalho no cartão do pack e em Criar tema
    estilo.css    o visual (nenhum hex nele)
    standalone.*  só existem dentro do HTML exportado
```

## As portas

| porta | o que tem |
|---|---|
| **Tema** | um cartão por pack instalado: logo, paleta, o que é próprio e o que herda. **Vestir**, **Remover**, **Abrir um tema** (`.meowpack` ou `.csv` de cores) |
| **Criar tema** | os passos Cores, Ícones, Papel de parede, Sons e Mandar (**Baixar o tema**) |
| **Ajustes** | painel e dock, janelas, papel de parede, mascote, dia e noite, terminal, programas |
| **Cuidar** | o doctor e o **Consertar**, as pendências, **Guardar ajustes** e **Trazer ajustes** |

A barra de cima tem **Aplicar**, **Desfazer**, **Ver sem mudar**, **Procurar um ajuste**,
**Créditos** e **Esta tela num arquivo**.

## O catálogo é derivado

Não existe lista de chaves aqui. O `servidor.py` lê o `meow.conf.exemplo` e tira de lá, para cada
chave, a ordem, a seção, o comentário que a explica, as opções, a faixa, se é lista, horário ou
vazio, e se é essencial. São as mesmas regras do `wiz_ler_esquema` do `bin/meow`: uma chave nova
no exemplo aparece na página sozinha. O `tests/app.sh` compara as duas leituras.

## Quem escreve

- **No `meow.conf`, só o `meow_conf_definir`** do `lib/comum.sh`, num bash só por lote. Uma
  segunda rotina de escrita na mesma chave é defeito.
- **Aplicar** é uma rota só (`/api/salvar`): confere todas as escolhas, grava e começa o
  `./install.sh`. Uma escolha recusada barra o lote inteiro, antes de qualquer escrita.
- **Ver sem mudar** mostra um gesto antes de ele valer, numa janela de resultado com **Parar**,
  **Guardar** e **Rodar de verdade**. Não há interruptor global de ensaio; um `MEOW_DRY_RUN` herdado
  do terminal sai do ambiente de tudo que o painel roda.
- **Restaurar** grava o valor de fábrica e só aparece quando o valor difere (decisão 10).
- **Trazer ajustes não grava**: o arquivo vira escolha pendente, e quem escreve é o Aplicar.
- **Um trabalho por vez.** O `install.sh` e o `meow doctor --consertar` pegam o `flock` de
  `~/.local/state/meowsystem/lock`; o servidor recusa o segundo e diz qual está correndo. A saída
  fica no servidor: a página pode recarregar e voltar ao mesmo trabalho.
- **A interface nunca pede senha** (decisão 11). O que precisa de root passa pela ponte
  ([`docs/FRONTEIRA.md`](../docs/FRONTEIRA.md#a-ponte-root)).
- **O painel mostra a máquina.** As chaves vazias («não tocar») mostram o que o COSMIC guarda
  agora (`NA_MAQUINA` no `servidor.py`), e a página relê quando um trabalho termina.

## Como ele é servido

`python3` da biblioteca padrão (`http.server`), sem dependência nova.

- `127.0.0.1` em porta efêmera; nenhum bind em `0.0.0.0`.
- Token de sessão sorteado a cada execução, comparado com `hmac.compare_digest`; o `app.js` o tira
  da barra de endereço no primeiro instante e ele não vai para disco.
- `Host` conferido contra `(127.0.0.1|localhost):<porta>` (fecha o DNS rebinding); `Origin`,
  quando vem, tem de bater.
- Nenhum comando vem da página como texto: ela manda o `id` de uma ação de um dicionário fechado, e
  o argumento é conferido contra uma lista montada do disco. Não há `shell=True`.
- O `run.sh --sem-abrir` recusa o HOME da conta sem `MEOW_QA_HOME_REAL=1` (decisão 8).

## A cor não mora no CSS

O `estilo.css` não tem hex. Quem define `var(--base)`, `var(--accent)` e as outras é o
`/paleta.css`, que o servidor gera da paleta do pack no ar, no flavor e no modo do `meow.conf`. O
acento aparece só no que está ligado, selecionado ou é a ação principal.

## Esta tela num arquivo

Baixa a tela inteira num `.html` só, que abre sem Python e sem o projeto. É o `app.js` de verdade
contra dados congelados: o `standalone.js` troca o `fetch` pelo JSON embutido e as imagens pelos
`data:`. Nada nele grava: as rotas que escrevem respondem com o aviso.

## Instalação e conferência

| onde | o quê |
|---|---|
| `install.sh` | a etapa `atalho` (`scripts/atalho.sh`) |
| `meow doctor` | a linha `atalho`: o `.desktop`, o lançador e o bit de execução |
| `meow doctor --consertar` | o mesmo `scripts/atalho.sh` |
| `install.sh --uninstall` | `atalho.sh --reverter` |

O `.desktop` aponta para `~/.local/bin/meow-painel`, não para o clone: o lançador resolve a raiz
pelo ponteiro `~/.local/state/meowsystem/raiz` e, quando não a acha, avisa por notificação.
