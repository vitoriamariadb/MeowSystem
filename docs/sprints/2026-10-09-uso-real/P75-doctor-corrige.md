# P75 — O doctor corrige; nada manda consertar à mão; o que é decidido não volta

**Branch:** `sprint/p75` · **Fontes:** `01-regressoes.md` (D1, D2, D3, S4, S5, S6 e «Por que voltou»),
achados 3, 4, 5, 23.

## Pedido de quem usa
«O doctor não tem que avisar nada. Tem que corrigir.» «nenhuma feature pode mandar o usuário
consertar à mão» (21/09, ×3).

## Tarefas
1. **D1** — toda checagem que sabe a cura a aplica (ponte root, sem senha); nenhuma saída imprime
   `instale com`/`sudo apt …`; o veredito final reflete o pior estado (`!!`/`--` com cura possível
   nunca termina em «nada a consertar»; `bin/meow` ~2437).
2. **D2** — `meow status` e `meow doctor` leem o mesmo estado e nomeiam o mesmo tema; o status
   chama de divergência o que foi pulado; a tela não diz «aplicou» sem ter aplicado.
3. **Achados 3, 4, 5** — sem contradição entre linhas (base «confere» e «não instalada»); nenhuma
   linha vazia ou cortada (`files_menu`, `resgatados`, `escala`, `fontes`).
4. **D3** — `meow pack sincronizar` fora da passada do doctor (decisão «Aposentar tudo», 24/09).
5. **Chaves aposentadas** — `migrar_conf.py` ganha a lista de chaves aposentadas (começa por
   `ICONES_BASE`), não as devolve, e remove a linha ativa do conf; a chave sai do `meow.conf.exemplo`.
6. **Testes que não mentem** — tirar as isenções de `tests/sem-receita-no-log.sh:95-96`;
   `tests/git-limpo.sh` cobre o repositório inteiro durante uso do painel; testes rodam no
   repositório real; a suíte ganha um sudo falso no PATH para nunca escrever no sistema real (S6).
7. **S4** — `scripts/greeter.sh:266-271`: a ponte diz o motivo em vez de mandar para `/dev/null`.
8. **Achado 23** — dois painéis não dividem o mesmo `app.pid`; `--parar` só derruba o próprio.

## Prova
- `meow doctor` numa casa temporária com a base faltando → ele instala/repara e termina verde;
  com algo irreparável → termina vermelho, nunca «nada a consertar».
- `grep -rn "apt install" ` na saída do doctor → 0.
- conf com `ICONES_BASE` comentada → `migrar_conf.py` não a devolve.
- suíte inteira roda com o sudo falso e nenhum arquivo fora do HOME temporário muda.

## Estado da execução (09/10/2026, branch `sprint/p75`)

| # | estado | commit | prova curta |
|---|---|---|---|
| 1 D1 | feito | `25d2f1a` | ponte root ganhou o verbo `pacotes` (lista literal, igual à do `etapa_pacotes`, cobrada no teste); `pacotes`, `upstream`, `fontes`, `cursor` e `cli` saíram do `SEM_CONSERTO`; o 3 se confere de novo antes de ser pulado; o `--consertar` termina pelo DEPOIS (o que continua fora é nomeado e sai 2); o pulado que avisou (`!!`) pesa no veredito. `tests/doctor-veredito.sh` verde; numa casa temporária, `pacotes upstream icones completar pastas`: 1ª passada instala base e upstream, conserta `completar` e `pastas`, e termina VERMELHA nomeando `icones` (ver nota); 2ª passada `consertado`, rc=1; doctor seguinte `nada a consertar`, rc=0. `grep -ciE 'apt(-get)? install\|instale com'` na saída do doctor: 0. |
| 2 D2 | feito | `c276080` | `tema_ativo` pergunta o alvo primeiro: no `meow status` desta máquina (só leitura, sudo falso) `ativo alucard-mauve (o alvo é dracula-mauve)` virou `ativo dracula-mauve`; a lista «Divergências» usa a régua do veredito (`fora_do_lugar`) — pulado de rotina e escolha (4) saem dela. |
| 3 achados 3, 4, 5 | feito | `8b55fc8` | `files_menu`, `resgatados`, `escala`, `fontes` e `janelas` têm primeira linha inteira; a linha do pulado que avisou é a do aviso. Teste: nenhuma linha da tabela vazia ou terminada em `:`. A contradição do achado 4 some com o conf migrado (item 5): `icones ok … confere`, `pastas ok`, sem «não está instalada». |
| 4 D3 | feito | `2733c4b` | a passada do doctor não chama `pack.py sincronizar`; `tests/sem-dracula-os-theme.sh` agora cobra a ausência. |
| 5 chaves aposentadas | feito | `18c1d88`, `1098fb5` | `APOSENTADAS = {ICONES_BASE}` no `migrar_conf.py`; cópia do conf real: só a linha ativa `:1841` sai, o comentário de 24/09 fica; com o exemplo velho (com a chave) ela não volta. O doctor migra (`chk_conf`/`fix_conf`) — `tests/chaves-aposentadas.sh` verde. A chave saiu do exemplo; o servidor segue respondendo a base do pack sem o cartão. |
| 6 testes | feito, com uma ressalva | `af2686b` | `sem-receita-no-log.sh` sem as isenções do Papirus (e das outras seis frases que saíram; sobra a do `lib/preflight.sh`, que fala antes de existir ponte); `git-limpo.sh` §4 sobe o painel sobre o repositório real e o pega gravando ` M packs/dracula/icones/apps.map` (I3) — VERMELHO até a P73 item 6 entrar, de propósito; o teste devolve o que ele mesmo sujou. `todos.sh` põe `sudo`/`pkexec`/`su` falsos no PATH e HOME de brinquedo para a suíte inteira. Ressalva: o `seletor-do-pack.sh` segue numa cópia da árvore — ele cobra o comportamento da P60 que a P73 desfaz; a cobertura do repositório real foi para o `git-limpo.sh`. |
| 7 S4 | feito | `f561972` | a causa da recusa era `tar --no-absolute-names`, opção que o GNU tar 1.35 não tem (rc 64): o verbo `greeter-aplicar` recusava TODA chamada. Numa cópia isolada da ponte: antes rc=2 «tar recusado», depois rc=0 e o arquivo no destino; link simbólico recusado. O `greeter.sh` diz o motivo na linha da recusa. |
| 8 achado 23 | feito | `550e076` | registro por painel em `$MEOW_ESTADO/paineis/<pid>.pid`; `--parar`/`--estado` só tocam o processo vivo que roda o servidor DESTE clone. Medido com dois painéis no mesmo estado (um deste clone, um do checkout principal): `--parar` derrubou só o deste clone; o outro seguiu de pé. |

Suíte (`./tests/todos.sh --portatil`, com o sudo falso e a casa de brinquedo novos): 28 verdes, 2 vermelhos
— `git-limpo.sh` (o I3, de propósito, até a P73) e `portabilidade.sh` (anterior, ver achados). Sudo recusado
e registrado: 2 chamadas (`ponte_root.sh estado`, do `chk_ponte`). Nenhum arquivo mudou em `~/.config/meow`,
`~/.local/share/icons`, `~/.local/state/meowsystem`, `~/.local/bin`, `~/.config/systemd/user`,
`/usr/local/lib/meowsystem` nem `/etc/sudoers.d` durante a passada. O `pack.sh` saía «pulado» sob a casa de
brinquedo (lia a origem da biblioteca no HOME) e o `doctor-so-le.sh` vermelho (procurava o painel da sessão
pelo HOME): os dois leem a casa real por `SUITE_CASA_REAL`, só leitura — rodados à parte, verdes.
Da máquina: `previa-cerca.sh` e `pastas-do-pack.sh` verdes; os de navegador não foram rodados.

Notas para a integração:
- **A ponte instalada precisa ser reinstalada** (`./install.sh`, pede a senha uma vez): o verbo `pacotes` e o conserto do `greeter-aplicar` só valem depois. Até lá o `chk_ponte` diz «diverge do repositório» (a ponte segue no `SEM_CONSERTO`: escrever em `/etc/sudoers.d` é decisão com senha).
- **1ª passada vermelha numa casa nova**: o `index.theme` do `icones` não converge numa passada (é a P74 item 5). O veredito agora diz isso, em vez de «consertado».
- Arquivos de outros blocos tocados no mínimo: `scripts/completar_icones.sh` e `scripts/construir_pastas.sh` (só as linhas da mensagem e o código de saída; as linhas 107/149 do leitor são da P74), `scripts/files_menu.sh` (1 linha, ~199; P76), `scripts/escala.sh` (bloco do `--conferir`; a P76 mexe no `saidas()`), `app/servidor.py` (o `ICONES_BASE` ~1456 e o `finally` do `main`; P73/P77), `tests/app.sh` (isenção das aposentadas, lida do `migrar_conf.py`), `tests/sem-dracula-os-theme.sh`.
- `meow doctor` sem `--consertar` continua só lendo (contrato da P44 e o «Conferir a máquina», que promete não escrever): quem corrige é o `--consertar` — o botão «Consertar» e o auto-reparo das 5h. O veredito dos dois agora é o mesmo.

## Achados para a próxima leva

- `meow-doctor.service`: com o veredito honesto, «ficou fora» sai 2 e a unidade fica `failed` sem notificação (o `ExecStopPost` só avisa no 1). Decidir se o 2 também avisa.
- Frases que ainda mandam fazer à mão, fora do recorte desta spec: `chk_tema` («importe … pela GUI e rode: meow tema capturar»), `greeter.sh` («rode o install.sh de novo com sudo disponível», «capture antes»), `files_menu.sh` («para construir agora: meow files-menu build»), `midia_build.sh`/`leitura_build.sh` («instale com rustup» — P76 item 8), o aviso do `NOPASSWD: ALL` («veja de onde vem: sudo -l», decisão 5 de 02-decisoes.md).
- `instalar_fontes.sh`: ferramentas que faltam (curl, xz, unzip…) e a `pop-fonts` são nomeadas, mas não estão no `pacotes` da ponte — sem cura.
- `docs/FRONTEIRA.md` ainda conta «oito verbos fechados»; a ponte tem o `pacotes` agora.
- `pack.py:ICONES_BASE_DO_EXEMPLO` e os leitores `${ICONES_BASE:-…}` (install.sh, construir_icones.sh, bin/meow) ficam sem razão quando a P74 item 1 os trocar pela pergunta ao pack; aí a isenção das aposentadas no `tests/app.sh` deixa de casar sozinha.
- `tests/portabilidade.sh` falha no dev desde `f24868c`: `docs/pesquisas/2026-10-09-cosmic-vivo.md:198` escreve a casa de uma pessoa.
