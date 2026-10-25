# P103 — As pontas soltas da P101 e do pulado da suíte

**Status: EM VOO em 24/10.** Quem usa (24/10): «Não dá pra disparar agentes opus pra ir fazendo já isso
localmente?». Roda junto da P102. A P102 mexe em fotos, perfil, fontes, `install.sh` (`--perfil`) e
`wallpaper.sh`, então este bloco não toca nesses pontos além do mínimo.

Cada item: teste vermelho antes, verde depois, um commit por item, diff conferido (o gancho troca palavras).

## 1. O `LOGO` do modo fixo acompanha a troca de pack
- Medido (P101, achados do agente 1): a troca de pack leva `LOGO_DIA`, `LOGO_NOITE` e `FASTFETCH_LOGO_GATO`
  (`scripts/migrar_conf.py`, `_mascote_junto`), mas o `LOGO` do `LOGO_MODO="fixo"` fica no mascote do pack de antes.
- Cura: mesma regra das outras três. O valor de fábrica do pack de antes vira o do pack novo, e o que quem
  usa escolheu fica. Só grava nome (`RE_NOME`, item 7 da P101).
- Prova: `meow pack usar`, ida e volta no HOME temporário, com `LOGO_MODO="fixo"`.

## 2. A frase «precisa de sudo» do `icones_absolutos.sh`
- Medido: sem ponte, `scripts/icones_absolutos.sh` ainda diz «Icon= precisa(m) de sudo para trocar». O
  caminho é pendência desde a P101 (item 3), e nenhuma saída manda digitar (GSD §2).
- Cura: a saída diz o mesmo que as outras pendências da ponte, sem mandar rodar sudo.
- Prova: teste com a ponte ausente que lê a saída.

## 3. O avatar do greeter quando o atual é ilegível
- Medido: em `scripts/greeter.sh`, quando o avatar atual não pode ser lido, o `md5_atual` fica vazio e o
  mascote é posto por cima sem saber se aquele avatar era nosso. Já era assim antes da P101.
- Cura: se não dá para saber se o avatar é nosso, não escreve; vira pendência. Um avatar escolhido por quem
  usa nunca é trocado às cegas.
- Prova: teste com o avatar ilegível, em que nada é escrito e a pendência aparece.

## 4. O `pack.sh` sem clone externo (pulado não é verde)
- Medido: `tests/pack.sh` pula a conferência da biblioteca do Dracula quando
  `~/Desenvolvimento/Dracula_OS-Theme/src/icons/new-sessao-atual` não existe. Essa pasta foi apagada desta
  máquina em 24/10 e não existe em nenhuma outra. Resultado: a suíte dá 76 verdes e 1 pulado.
- Cura: a origem vira dado no repositório. Uma lista fixa dos sha256 da origem (295 SVG) entra no pack do
  Dracula, com o commit de procedência do `AndreBFarias/Dracula_OS-Theme`, e o teste conta contra essa lista.
  O teste não pode mais pular por causa disso.
- A origem para gerar a lista uma vez está clonada (esparsa) em
  `/tmp/claude-1000/-home-andrefarias-Desenvolvimento-MeowSystem/420d7b5e-bfff-4e01-83fc-0804b8335adb/scratchpad/dracula-bib/src/icons/new-sessao-atual`.
  O commit de procedência sai do `git -C .../dracula-bib log -1`.
- Prova: `tests/todos.sh` com 77 verdes e 0 pulados. Trocar um sha da lista deixa o teste vermelho.

## 5. Textos do servidor com as abas e as frases de antes (P98, «ficou de fora» 1 e ressalva 1)
- Medido: o `--onde` do servidor (`onde_na_tela`, `ABA_INICIO`, `DESCRICAO_SECAO` em `app/servidor.py`) ainda
  nomeia as abas antigas, e o `install.sh` fala «na aba Cor e tela». Também passam de três palavras o nome de
  pendência «Construir o menu da área de trabalho» e o botão «Trocar pelo tema do pack».
- Cura: o servidor lê os nomes das 4 portas de onde o front já tem (`app/pagina/lugares.js`), sem uma
  segunda tabela, e os textos ficam curtos (GSD §2: nome curto, o porquê vai para a dica).
- Prova: teste que confere que todo destino do `--onde` existe no `lugares.js`, e `tests/frases-velhas.sh`.

## Fora daqui
- P100 (o patch v2 da Vitória) e o resto da P98 (a ponte pelo «Conferir», papéis e sons no formato de pack, e
  o que no mockup não tem motor) ficam para depois da P102, porque ela mexe no formato de pack.
