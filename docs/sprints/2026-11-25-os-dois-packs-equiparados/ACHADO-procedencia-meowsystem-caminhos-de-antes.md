# Achado · duas linhas do procedencia.tsv do pack-base apontam para arquivo que não existe (25/11/2026)

## O que se mediu
`meow pack sincronizar meowsystem` sai 1 com «2 divergente(s)»: `icones/biblioteca/folder.svg` e
`icones/biblioteca/shield.svg` estão na tabela e não existem no pack (hoje são `icones/sistema/folder.svg` e
`icones/sistema/shield.svg`; a linha diz «antes em `icones/sistema/arcticons/…`»). Já era assim antes de a tabela virar
`procedencia.tsv`: a saída do `sincronizar` é idêntica nos dois formatos, linha a linha.

## A causa
A linha da P96 (23/10/2026) foi escrita com a pasta `biblioteca/`; a regra de uma versão por ícone mandou os dois
para `sistema/` e a linha ficou com o caminho de antes.

## A cura na origem
Trocar a primeira coluna das duas linhas para `icones/sistema/…`, e a prova é `sincronizar meowsystem` sair 0.
Não foi feito: fora do escopo do bloco (o bloco só move a tabela, sem mudar o que o `sincronizar` devolve).
