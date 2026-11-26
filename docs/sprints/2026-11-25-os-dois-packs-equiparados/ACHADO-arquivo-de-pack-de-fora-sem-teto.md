# Achado · arquivo de pack de fora sem teto de tamanho (25/11/2026)

Do conferente do bloco do núcleo, sem conserto neste bloco.

## O que se mediu
- `pack.json`, `paleta.json` e `procedencia.tsv` de pack de fora, como FIFO e como pasta, nos verbos `prompt`,
  `validar`, `info`, `sincronizar` e `exportar`: nenhuma trava e nenhum traceback (o código confere arquivo comum
  antes de abrir). Rodado.
- Os três são lidos inteiros, sem teto de tamanho (`json.load` e o leitor do TSV). Lido, não rodado: arquivo enorme
  gasta memória e tempo, sem travar para sempre.
- Os mapas (`.map`) do pack de fora não foram sondados.
- A corrida em que um link é trocado entre a conferência do caminho e a abertura não foi provada.

## A cura que falta
Um leitor só para arquivo de pack de fora: arquivo comum, teto de tamanho, sem seguir link para fora do pack, e toda
falha vira recusa com uma frase. O `starship.toml` já passa por um assim (`304f8b2`); os outros arquivos e os mapas
entram no mesmo leitor.

## Como se prova
`tests/pack-malicioso.sh`: cada arquivo que o motor lê de pack de fora, em cada verbo, como arquivo enorme, FIFO,
pasta e link, com teto de tempo no teste.
