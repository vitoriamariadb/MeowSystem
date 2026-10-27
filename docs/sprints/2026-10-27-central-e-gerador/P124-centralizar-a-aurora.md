# P124 — o doctor desliga na Aurora o que o MeowSystem já faz

Pedido dela de 27/10: «migrar pro meowsystem e desabilitar onde mais tiver». Esta sprint cobre as
classes B do levantamento e o mecanismo de que as classes A (P125) e a P121 precisam.

- **Depende** da P121 integrada, porque mexe nos mesmos `vizinhos.tsv`, `tests/vizinhos.sh` e
  `bin/meow`.
- **Leia antes:** `relatorios/levantamento-aurora.md`, seções 0, 2, 3 e 4.

## O que se mediu
- Ninguém chama o `scripts/vizinhos.sh --desativar`: nem o `install.sh`, nem os `fix_*` do
  `bin/meow`, nem o `app/servidor.py`.
  - Não existe `~/.local/state/meowsystem/vizinhos-desativados.tsv`, e não há marca `#vizinhos` na
    Aurora.
  - O `--listar` dá quatro itens decididos e nunca aplicados: `caches-icones-casa` e
    `spellbook-terminal-{fastfetch,starship,fzf}`.
- O `--conferir` de hoje devolve rc 4, com «7 duplicata(s) nova(s)», e nenhuma tem saída.
- A briga viva do fastfetch:
  - o doctor transformou `~/.config/fastfetch` em diretório às 10:28;
  - a Aurora grava «criando symlink ~/.config/fastfetch (v3.34)» a cada passada, 37 vezes no log;
  - o `ln -sfn` deixou o lixo `~/.config/fastfetch/fastfetch -> ~/.config/zsh/fastfetch`.
- O `bloco` de hoje não corta uma linha só.
  - O `awk` só fecha numa linha que casa o fim **e não** contém o início, então
    `        _step_vidro_fosco` comentaria até a próxima linha casada.
  - Ele também pega a primeira ocorrência do início, sem conferir se é única. O self-heal tem 520
    linhas de histórico, que citam o próprio código.
- Desligar uma unidade de usuário da Aurora exige duas coisas:
  - cortar a instalação dela no self-heal;
  - tirar a unidade já habilitada.

  A cópia que roda é `/usr/local/sbin/ritual-aurora-self-heal.sh`. Ela reinstala as unidades de
  `$SRC` antes de se reinstalar (linha 2656), então tirar a unidade antes de a cópia nova chegar
  faz ela voltar uma vez.
- O `andromeda-autosync` (10 min) comita no repositório `Meow-Portatil` tudo o que muda em
  `~/.config/zsh`, e o `vizinhos.conf` protege essa árvore contra o `meow_escrever`.

## Causa
- O `vizinhos.sh` sabe cortar, mas o produto nunca o chama. O 23/09 («o que conflita migra e é
  desativado no outro») ficou só no contrato.
- O tipo `bloco` não tem forma de uma linha, nem guarda de âncora única, nem prova de que o arquivo
  cortado ainda roda.
- Não há tipo para unidade do systemd de usuário.

## Cura na origem
1. **`bin/meow`.**
   - O `chk_vizinhos` diverge (rc 1) quando há item **pronto**:
     - existe na casa e está ativo;
     - o `requer` está no MeowSystem instalado;
     - o último registro dele não é «restaurado»;
     - `VIZINHOS_DESATIVAR="sim"`.
   - Sem item pronto, o rc 4 das duplicatas fica como está.
   - O `fix_vizinhos` chama `scripts/vizinhos.sh --desativar-prontos`.
   - A segunda passada não escreve: o que foi cortado já está «desativado», e o que ela devolveu fica.
2. **`scripts/vizinhos.sh`.**
   - **O verbo `--desativar-prontos`:** corta os itens na ordem do `vizinhos.tsv`, um por um. A falha
     de um não para os outros, e o pior rc sai no fim.
   - **`fim` igual a `-` no `bloco`:** corta só a linha que contém o início.
   - **Âncora única:** um início que aparece mais de uma vez no arquivo recusa o corte («o trecho não
     é único em …»), sem mudar nada.
   - **Sintaxe depois do corte:** `bash -n` para `.sh`, `zsh -n` para `.zsh`, antes do `mv`. Se
     reprovar, nada muda e o item dá erro.
   - **Tipo `unidade`:**
     - `<arquivo>` é o `.timer` ou o `.path` em `$UNI`. A expansão nova `$UNI` vale
       `${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user`.
     - `<início>` é o item de `bloco` que precisa ter chegado, e `<fim>` é o arquivo instalado onde
       a marca dele precisa estar (`/usr/local/sbin/ritual-aurora-self-heal.sh`).
     - Enquanto a marca não chegou, o item diz «esperando a Aurora ler o corte» e não diverge.
     - Quando a marca chega: `systemctl --user disable --now`, e o arquivo mais o `.service` de mesmo
       nome vão para a cópia datada.
     - O `--restaurar` devolve os dois e religa.
3. **`meow.conf.exemplo`:** a chave `VIZINHOS_DESATIVAR="sim"`, com o porquê no nome e na ajuda.
4. **`assets/contratos/vizinhos.tsv`:** sete itens novos, com o início, o fim e o requer exatos do
   levantamento, seção 3.
   - `aurora-fastfetch-link` (bloco, self-heal);
   - `aurora-fastfetch-passo` (linha, `$ZD/install.sh`);
   - `aurora-completion-meow` (bloco);
   - `aurora-icone-applib` (bloco);
   - `aurora-stubs-ocultar` (bloco);
   - `aurora-gato-pop` (bloco);
   - `aurora-spicetify-instalar` (saida, `$ZD/scripts/spicetify-setup.sh`).

   Os motivos dizem quem é o dono no MeowSystem, sem aspas e sem `$`.
5. **`scripts/fastfetch_logo.sh`:** o `_ffl_assumir_diretorio` apaga
   `~/.config/fastfetch/fastfetch` quando ele é link para o ZDOTDIR, que é o lixo da briga. Fala em
   voz alta e não mexe em mais nada.
6. **`docs/FRONTEIRA.md`:** uma linha em «A regra». O vizinho confere e o MeowSystem desliga nele, só
   pelo `vizinhos.sh`, só em linhas marcadas e com cópia. É a única escrita na árvore de outro
   projeto, e o `VIZINHOS_DESATIVAR` a desliga.

## Prova
- **`tests/vizinhos.sh`, num HOME de brinquedo,** com cópias do self-heal, do `install.sh` e do
  `env.zsh` reais em `$ZD` falso:
  - **gatilho e segunda passada:** `chk_vizinhos` dá 1 com item pronto, e `fix_vizinhos` corta só os
    prontos. Na segunda passada, 0 ou 4 e nenhum `mtime` muda.
  - **o que ela devolveu fica:** item restaurado continua ativo na passada seguinte.
  - **a chave:** com `VIZINHOS_DESATIVAR="nao"`, nada é cortado.
  - **a linha:** `fim -` corta exatamente uma linha (`        _step_vidro_fosco`), e o `--restaurar`
    devolve byte a byte.
  - **âncora repetida:** um início que aparece duas vezes recusa o corte, e o arquivo fica com o
    mesmo md5.
  - **sintaxe:** um corte que quebraria o `bash -n` é recusado.
  - **`unidade`:**
    - sem a marca no «instalado» de brinquedo, espera e dá rc 0;
    - com a marca, chama `systemctl --user disable --now` (num falso que só registra a chamada) e
      move o `.timer` e o `.service`;
    - o `--restaurar` devolve os dois e chama `enable --now`.
  - **os sete itens novos e os quatro antigos** cortam nas cópias reais de hoje. O self-heal cortado
    passa `bash -n`, e o `env.zsh` cortado passa `zsh -n`.
  - **fastfetch:** um `~/.config/fastfetch` diretório com o link aninhado. O conserto apaga o link,
    e a segunda passada não escreve.
- `tests/decisoes.sh` e `tests/todos.sh --portatil` verdes.
- **Manual, com ela, depois da integração:**
  - o doctor das 5h (ou o botão de Manter) corta;
  - na passada seguinte do self-heal, o log não tem mais «criando symlink ~/.config/fastfetch»;
  - um terminal novo abre com **um** fastfetch e **um** prompt. Os três itens `spellbook-terminal-*`
    entram em vigor aqui pela primeira vez;
  - `scripts/vizinhos.sh --conferir` lista só o que ficou para a P125 e o que é da Aurora pela
    FRONTEIRA.

## Arquivos
- `scripts/vizinhos.sh`;
- `bin/meow`: só `chk_vizinhos` e `fix_vizinhos`;
- `meow.conf.exemplo`;
- `assets/contratos/vizinhos.tsv`: o cabeçalho do formato e os sete itens;
- `scripts/fastfetch_logo.sh`: só `_ffl_assumir_diretorio`;
- `docs/FRONTEIRA.md`: uma linha;
- `tests/vizinhos.sh`.

## Item do coordenador (27/10)
- O `requer` de `aurora-compositor` e `aurora-night-light` (P121) confere só que o shim existe; tem de conferir que o build da versão instalada vale (o shim usaria o build), senão depois de um apt upgrade ela entra sem modo de leitura nenhum.
- Com os applets em `PADRAO=sim` e o cargo falhando, cada passada do doctor recompila todos e regrava `extensoes/<id>/falhou`: falha registrada espera gatilho novo (versão, pino, gesto), não recompila a cada passada (`relatorios/conferencia-central.md`, «Final»).
- Numa casa sem rede o doctor regrava a cada passada as tentativas de compilar as extensões, o `pendencias.tsv` e a semeadura do papel de parede. Cura: a segunda passada do doctor não escreve nada, também sem rede; prova num HOME temporário sem rede (conferência final do Painel, `relatorios/conferencia-painel.md`, «Final»).

## Fora desta sprint
- As migrações A (P125): painel fantasma, vidro maximizado e o vigia da #2059.
- Os alfinetes (D1, P125 se o coordenador aceitar).
- A cadeia do clipboard (depois da P122).
- Mexer em qualquer script da Aurora fora das linhas marcadas.
- Apagar arquivo da Aurora.
- O `~/.claude/CLAUDE.md` dela.

## Execução
Bloco «aurora», árvore `MeowSystem-aurora`, branch `bloco/aurora`.

### Commits
- `5701e821` `scripts/vizinhos.sh`: `--prontos`, `--desativar-prontos`, `fim -` de uma linha, âncora
  única, `bash -n`/`zsh -n` antes do `mv`, tipo `unidade` com a expansão `$UNI` (e `$SBIN`, que o
  teste aponta para uma cópia).
- `428e5d14` `vizinhos.tsv`: os sete itens. O `requer` do `aurora-compositor` e do
  `aurora-night-light` passou a `build:` (o shim de pé **e** o build da versão instalada valendo).
- `1d04155f` `chk_vizinhos`/`fix_vizinhos` e `VIZINHOS_DESATIVAR` no `meow.conf.exemplo` e no painel
  (`lugares.js`). O gancho do commit acertou a contagem no README, no README.en e no `app/LEIA-ME.md`.
- `669fae20` `fastfetch_logo.sh`: `_ffl_assumir_diretorio` apaga o link aninhado; o `cmd_conferir`
  ganhou a mesma conferência, para o doctor ver o link.
- `cba8a85e` `docs/FRONTEIRA.md`: a linha da regra.
- `4c0795de` `tests/vizinhos.sh`.
- Itens do coordenador: `53fa1155` (falha gravada espera gatilho novo), `d7a5fc0d` (pendência igual
  não regrava), `eeeabcea` (semeadura do papel de parede só quando muda), `19c2f807`
  (`tests/segunda-passada-sem-rede.sh`, novo).
- Achados da suíte no caminho: `cd28a58d` (o desinstalador desliga `meow-vidro.*`) e `646ea0a1`
  (`VIZINHOS_DESATIVAR` na `chave-etapa.tsv`).

### Provas rodadas
- `tests/vizinhos.sh` verde: gatilho e segunda passada, item restaurado fica, a chave, a linha
  byte a byte, âncora repetida, sintaxe, `unidade` (espera, `disable --now`, volta com `enable --now`),
  os itens novos e antigos nas cópias reais, fastfetch. Sem a cura ficou vermelho.
- `tests/segunda-passada-sem-rede.sh` verde: a segunda e a terceira passadas do doctor sem rede não
  compilam e não escrevem nada.
- `tests/decisoes.sh`: só o vermelho aceito (GPU D6).

### O que mudou de lugar
- A D10 (os itens do compositor e do night-light que dependem do shim) foi para a P125, no
  `d3e28257`.
- O bloco 9 do `tests/vizinhos.sh` corta as cópias do `~/.config/zsh` real: na máquina sem a Aurora
  ele pula esse bloco (pulado não é verde: lá a prova é a dos blocos 1 a 8).

### Conferir com a mão
- O doctor das 5h (ou Manter) corta; o log do self-heal não diz mais «criando symlink
  ~/.config/fastfetch»; um terminal novo abre com um fastfetch e um prompt.
- `scripts/vizinhos.sh --listar` mostra só o que é da Aurora pela FRONTEIRA.
