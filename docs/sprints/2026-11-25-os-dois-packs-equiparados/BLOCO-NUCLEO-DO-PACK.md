# Bloco · o núcleo do pack: a tabela da procedência e o prompt de pack pessoal (25/11/2026)

Duas tarefas na mesma área (`scripts/pack.py` e o que ele lê), em sequência, um commit ou mais por tarefa.

## Tarefa 1 · a tabela da `PROCEDENCIA.md` do Dracula vira dado

### O que se mediu
`packs/dracula/PROCEDENCIA.md` tem 1506 linhas e 302 KB; 89% é uma tabela que o `scripts/pack.py` lê (P278, em
`docs/sprints/2026-11-23-a-casa-em-ordem/P278-o-manual-em-dia-e-curto.md`). Um documento que é quase todo dado de
máquina não se lê, e o dado fica preso num formato de prosa.

### A cura na origem
A tabela passa para um arquivo de dados do pack (TSV, no mesmo estilo dos outros dados do repositório, sem
comentário) e o leitor do `pack.py` lê de lá. A `PROCEDENCIA.md` fica só com a prosa e aponta para o arquivo. Vale
para todo pack: se o `meowsystem` ou um pack pessoal tiver a mesma tabela, o leitor acha os dois formatos durante a
migração só se a medida mostrar que existe pack de fora no formato antigo; se não, o formato antigo sai.

### Como se prova
Teste vermelho antes e verde depois: o que o `pack.py` devolvia a partir da tabela é idêntico, linha a linha, lendo
do arquivo novo (compare a saída dos verbos que usam a tabela antes e depois). `scripts/meow pack validar dracula`
sem aviso novo; `tests/numeros.sh`, `tests/caminhos-do-manual.sh`, `tests/pack-dracula-completo.sh` e os testes que
citam a procedência verdes.

## Tarefa 2 · o prompt próprio em pack pessoal (decisão nova, muda a 67)

### O que se mediu
A decisão 67 (`docs/DECISOES.md`) diz que nenhuma configuração que roda comando vem de pack de fora do repositório:
o `starship.toml` de pack importado não é lido (`scripts/pack.py`, `if achado and not do_repositorio(achado)`;
`tests/pack-malicioso.sh`). Resultado: pack pessoal só entrega a paleta ao prompt. Em 25/11 ela decidiu: «Abre o
prompt para pack pessoal».

### A cura na origem
O arquivo do pack de fora nunca é copiado nem lido pelo starship. O motor lê o TOML com o `tomllib` da biblioteca
padrão, confere contra uma lista escrita do que é permitido (tabelas, chaves e tipos de valor que só mudam
aparência: formato, estilo, símbolo, cor, ordem dos módulos) e escreve ele mesmo o arquivo que vale, a partir do que
aprovou. O que roda comando ou lê o ambiente fica de fora por construção: `custom.*`, qualquer chave `command`,
`commands`, `when`, `shell`, `env_var`, e tudo que não estiver na lista. Chave fora da lista recusa o prompt do pack
inteiro, com uma frase que diz qual chave e por quê, e o prompt cai no do pack-base; não se aplica metade.
A lista mora em dado (`dados/`), não no código. Pack do repositório continua como está.

A decisão 67 ganha a exceção escrita, e entra a decisão nova com a frase dela («Abre o prompt para pack pessoal»,
25/11/2026, página de decisões), guardada por `tests/decisoes.sh`.

### Como se prova
`tests/pack-malicioso.sh` ganha os casos, vermelhos antes e verdes depois: pack de fora com prompt só de aparência
entra; com `[custom.x]`, com `command`, com `when`, com `shell`, com `env_var`, com chave desconhecida, com valor de
tipo errado, com quebra de linha ou aspas tentando abrir tabela nova no arquivo gerado: recusado inteiro, e o
arquivo gerado nunca contém o que foi recusado. O `starship` de verdade, se instalado, carrega o arquivo gerado sem
erro (`starship print-config` ou equivalente, com HOME temporário).

## As regras da casa que valem aqui
`AGENTS.md` e `GSD.md` inteiros. Zero comentário no código. Sem `sudo`; sem `install.sh`, `meow compositor`,
`meow doctor --consertar` nem `meow apps aplicar` com o HOME real; sem janela. Teste pelo
`./tests/todos.sh --so=…`, e `./tests/todos.sh --portatil` no fim. Commit por caminho, em português, sem marca de
ferramenta, antes de rodar a suíte. Sem push. O que se achar fora do escopo vira `ACHADO-<nome>.md` nesta pasta.
