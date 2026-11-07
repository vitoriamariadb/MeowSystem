# P178 — o sudo fora do doctor, e os restos antes do install (06/11/2026)

Decisão de quem usa em 06/11 e achados da P159, P165, P176.

## O que se mediu

- Só o nitro-5 tem `NOPASSWD: ALL`. Quem usa: tirar a regra e o aviso. A regra sai no fim, à mão do coordenador, depois do install; aqui sai só o aviso.
- `bin/meow`, `cmd_doctor`: o aviso do `NOPASSWD: ALL` e a chamada `sudo -n -l`.
- `bin/meow`, fim de `meow status`: «detalhes e conserto: meow doctor --consertar» manda digitar, e `tests/nada-manda-digitar.sh` não pega.
- `tests/restaurar.sh` falha: `desinstalar` mudou 2 arquivos e não deixou «Restaurar». Medido: a P165 faz o `desinstalar` apagar os backups, por decisão. Só o `desinstalar_guardando` guarda.
- `tests/etapa-compositor.sh:6` tem no `trap` um `cp` para um caminho de outra máquina e de uma sessão antiga.
- `scripts/ponte_root.sh`: cabeçalho cortado no meio da frase.
- `tests/modificacoes-pagina.py` é intermitente em `abrir_menu('enfeite')`.
- `scripts/graficos.sh`: portal sem `deb-src` repete a tentativa sem espera crescente; o build de 64 MB fica depois do `reverter` (cabe no inventário da P165).
- `derivar_flavor.py`, `derivar_vidro.py`, `derivar_acento.py` e `scripts/vidro.sh:197` cravam `Builder/v2`, enquanto o painel segue a versão do sistema.
- `/previa` responde «prévia ainda não gerada» também quando a imagem não existe mais.

## A cura

- O aviso e o `sudo -n -l` saem do doctor; a decisão 43 se reescreve com o sim de 06/11; a prova dela acompanha.
- A saída do `meow status` não manda digitar, e o teste passa a pegar esse jeito.
- `tests/restaurar.sh` trata `desinstalar` como a ação que apaga o próprio Restaurar, sem afrouxar as outras.
- O `trap` velho sai; o cabeçalho se completa ou sai; a intermitência se mede e se cura na causa.
- O portal entra na espera crescente e no inventário.
- Os escritores resolvem `Builder` pela mesma versão do painel.
- `/previa` diz a verdade nos dois casos.

## Como se prova

Os testes de cada item, cada um vermelho antes e verde depois quando couber; `tests/modificacoes-pagina.py` verde em 5 rodadas seguidas; `tests/restaurar.sh` verde.

## Execução

Bloco `bloco/restos`, 11 commits sobre `6e544a68`. A regra `NOPASSWD: ALL` no sudoers não foi tocada: é do coordenador, depois do install.

O que foi feito:

- **Aviso do sudo.** O bloco do `NOPASSWD: ALL` e o `sudo -n -l` saíram do `cmd_doctor`. A decisão 43 foi reescrita no mesmo commit, com o sim de 06/11, «Tirar a regra e o aviso». A prova em `tests/decisoes.sh` passou a cobrar que `bin/meow` não cite `NOPASSWD` nem chame `sudo -l`.
- **`meow status`.** O fim dizia «detalhes e conserto: meow doctor --consertar». Agora diz onde está o conserto, no painel, em «Consertar». O `tests/nada-manda-digitar.sh` ganhou o jeito «conserto: meow doctor», que antes escapava.
- **`tests/restaurar.sh`.** O `desinstalar` entra numa lista de ações que apagam o próprio «Restaurar» (decisão da P165). O teste agora cobra que ele não deixe «Restaurar»; as outras ações seguem sem afrouxo.
- **`tests/etapa-compositor.sh`.** O `trap` voltou a só apagar a casa de brinquedo. Uma regra nova em `tests/portabilidade.sh` pega `/tmp/claude-` dentro de código.
- **`scripts/ponte_root.sh`.** O cabeçalho que a ponte imprime de si (`sed -n '2,60p'`) acabava em «e dos». A frase se completou no lugar, nas mesmas três linhas. O teste está em `tests/ponte-so-reserva.sh`.
- **Intermitência de `tests/modificacoes-pagina.py`.** Medida: o clique no «⋮» do enfeite caía em `#resultado` (`<dialog>` modal) que abria depois. O `quieto` via a página livre em dois vãos: entre o clique e a resposta do `/api/rodar`, e entre o fim de um trabalho e o `depois` que encadeia o próximo; o «Voltar ao do pack» tinha um terceiro, entre o POST do tema padrão e o `rodar`. A cura é um contador, `TRABALHOS_A_CAMINHO`, em `app/pagina/app.js` e `modificacoes.js`, que o `quieto` lê.
- **Portal sem `deb-src`.** O 404 e o «sem deb-src» do `apt-get source` passaram a gravar a falha `baixar`, e o portal entra na espera crescente (1 h, 2 h, 4 h, até 7 dias). Falha de rede continua tentando na próxima passada, como a mensagem promete.
- **Inventário da P165.** Medido: `espaco.py cobre` acusava três caminhos sem dono, `~/.local/libexec/meow/graficos` (o build de 64 MB, que fica depois do `reverter` de propósito, para o próximo aplicar não compilar de novo), `$MEOW_CACHE/graficos` e `$MEOW_ESTADO/graficos`. Entraram em `assets/contratos/espaco.tsv`, e `tests/espaco.sh`, que estava vermelho por isso, voltou a verde.
- **`Builder` pela versão do sistema.** `derivar_acento.py`, `derivar_flavor.py`, `derivar_vidro.py` e `scripts/vidro.sh` resolvem `Builder/vN` como o painel: a maior `vN` de `/usr/share/cosmic/com.system76.CosmicTheme.<Árvore>.Builder`, com padrão v2. O `meow_cosmic_v` ganhou um segundo argumento opcional, o padrão.
- **`/previa`.** Responde «essa imagem não existe mais» quando o item sumiu da fonte ou o arquivo de origem não existe, e «prévia ainda não gerada» só quando a imagem existe e vai ser gerada.

Provas, literais:

- `tests/modificacoes-pagina.py`, 6 rodadas em paralelo, antes da cura: `rc=1` nas 6, `<dialog open="" id="resultado" ...> intercepts pointer events`. Depois: `54 conferências rc=0` nas 6.
- `tests/modificacoes-pagina.py`, 5 rodadas seguidas: `rodada 1 rc=0 54 conferências` até `rodada 5 rc=0 54 conferências`.
- `tests/restaurar.sh` inteiro: `ok desinstalar: apagou os backups e o próprio «Restaurar»`, `ok: 51 ações rodadas; toda que mudou a casa volta byte a byte com o «Restaurar».`, `rc=0`. Antes: `FALHOU: 1 ação(ões) - desinstalar: mudou 2 arquivo(s) e não deixou «Restaurar»`.
- `tests/decisoes.sh`: `ok    43: o doctor não avisa do NOPASSWD nem consulta o sudo`, `decisoes: tudo certo`. Antes: `FALHA 43: o doctor volta a avisar do NOPASSWD ou a consultar o sudo`, com a prova nova sobre o código velho.
- `tests/nada-manda-digitar.sh`: `passou: nada manda digitar`. Antes, com a regra nova: `bin/meow:1760: meow_info "detalhes e conserto: meow doctor --consertar"`.
- `tests/ponte-so-reserva.sh`: `ok    o cabeçalho que a ponte imprime de si termina a frase`, `tudo ok`. Antes: `FALHA ... override global do Flatpak que apontam para tema que não existe, e dos`.
- `tests/etapa-compositor.sh`: `etapa-compositor: tudo verde`. `tests/portabilidade.sh` com o trap velho: `FALHOU: 1 achado(s) de portabilidade`; com o trap novo: `ok: portabilidade: nenhuma receita presa à máquina de quem a escreveu (3 isenções)`.
- `tests/graficos.sh`, seção 13b nova, para `sem-deb-src` e `sem-fonte`: `ok    ...: o portal espera, não é pendente de imediato`, `...: a falha gravada é a do download`, `...: a segunda tentativa soma, e a espera dobra`. Antes da cura, as três vermelhas nas duas variantes.
- `tests/espaco.sh`: `espaco: tudo certo`. Antes: `FALHA todo caminho que o código escreve em estado e cache tem dono no registro`, `sem dono: .../.local/state/meowsystem/graficos`.
- `tests/acento.sh`: `acento: tudo certo`, com três provas novas (`Builder/v3` quando o sistema está em v3, v2 sem a pasta, nenhum escritor crava `Builder/v2`), as três vermelhas antes. `vidro-do-cosmic.sh`, `flavor-padrao.sh`, `oraculo-tema.sh`, `derivados.sh`, `contrato-cosmic.sh`, `claro-do-pack.sh`, `variante.sh`, `notas-de-funcao.sh`, `garantir-builds.sh`, `doctor-so-le.sh` e `espaco-pagina.py`, todos verdes.
- `tests/previa-cerca.sh`: `ok: a prévia diz «ainda não gerada» só quando a imagem existe, e «não existe mais» quando sumiu`.

Falha que continua e não é desta sprint: `tests/graficos.sh` segue com 2 `FALHA pede gente, sem receita` (cat: `precisa-de-gente.tsv` inexistente). Medido: a P175 apagou `meow_precisa_de_gente` e `meow_precisa_de_gente_resolvida` de `lib/comum.sh`, e `scripts/graficos.sh` ainda chama as duas (linhas do `cmd_compilar` e do `cmd_aplicar`). Está como achado.

Falta da mão de quem usa:

- Tirar a regra `NOPASSWD: ALL` do sudoers depois do install, com `visudo -c` e prova do `sudo -A` antes (do coordenador).
- A ponte instalada só ganha o cabeçalho novo com o install.
