# Saídas do oráculo do tema, guardadas como prova

Cada `.json` é a saída do `meow-oraculo-tema` (`src/oraculo-tema`) sobre a
receita da captura `packs/dracula/temas/capturados/dracula-mauve`, na árvore e
na revisão do libcosmic do nome do arquivo. Geradas em 09/10/2026 (P76):

- `d77e99f` é o libcosmic do cosmic-settings 1.9 instalado nesta máquina;
- `5a8bd94` é o do cosmic-settings 1.10 que estava na fila do apt.

O `tests/oraculo-tema.sh` as compara com a cópia em Python
(`scripts/derivar_flavor.py`) sem precisar de cargo nem de rede. Para
refazê-las: `scripts/oraculo_tema.sh construir` na revisão, e o binário sobre
uma cópia de `com.system76.CosmicTheme.<Árvore>.Builder` dentro de um
diretório chamado `cosmic`.
