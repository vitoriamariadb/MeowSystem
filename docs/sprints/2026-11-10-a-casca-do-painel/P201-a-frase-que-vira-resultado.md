# P201 — a frase que vira resultado se explica sozinha (11/11/2026)

Achado do conferente da P200. Regra de quem usa: «o negócio não é autodescritivo não pode ser. nunca».

## O que se mediu

Com a P200, o resultado das ações que só leem aparece na própria linha, tirado da saída do script (sem
prefixo, cortado no « — », caminho trocado por nome de arquivo, até 6 linhas). O «Verificar o sistema» já mostra
só o nome curto de cada conferência (`NOME_DA_CONFERENCIA`). As outras 12 ações mostram a frase do terminal, e
ela é jargão. Medido na casa de brinquedo do `tests/resultado-na-linha.py`:

| ação (linha) | o que aparece hoje |
| --- | --- |
| `painel_estado` (Estado atual) | «Compositor : pid 4153», «Painel : do supervisor=<nenhum> nossos=<nenhum>», «Supervisor : dormiria 256 ms (0 min) antes de repor», «Laço :» |
| `painel_teto` (Arredondamento máximo) | «Compositor: CLAMPA (o teto acima não se aplica» |
| `areas_ver` (Áreas agora) | «Para o meow.conf: AREAS_NOMES="Brinquedo, Quintal" AREAS_FOLGA=""»; a frase quebrada em duas linhas vira «…lê este arquivo uma» e «Vez, ao iniciar.» |
| `wallpaper` (Carrossel de Imagens) | «Ordem: aleatoria (Random)», «Limiar: 0.37 de luminância (0 escuras \| 0 claras…» |
| `files_menu` (Menu agora) | «Chave : FILES_MENU="sim" autobuild="sim"», «Artefato : <não existe para esta versão>», «Cosmic-files cosmic-files [PATCHADO]» |
| `logo_listar` (Mascote agora) | «Coquinha», «Mimir»: a lista, sem dizer qual está em uso |
| `leitura` (Leitura agora) | «Meow.conf LEITURA_AGENDA="sim" rampa=0min», «Alvo do conf 3500K / 0.35» |
| `jogos` (Conferir jogos) | «Mudaria meow-steam-1715980.desktop» |
| `jogos_heroic` (Conferir Heroic) | «Heroic não instalado (ou nunca aberto)» — já se lê |
| `sistema_ver` (O que muda) | «1/3 Pacotes do sistema», «A lista pode estar velha; o \`aplicar\` roda \`apt update\` antes», frase partida em duas linhas |
| `icones` (Tema instalado) | «Ícones mudaria index.theme» |
| `apps` (Conferir, Modificações) | a tabela do terminal linha a linha: «Programa instalado tema nomes no meow.conf», «Btop-bat sim pendente bat, btop» |

## Causa

As frases foram escritas para o terminal (`meow <coisa> estado`), com nome de chave, id de pacote e coluna de
tabela. A P200 reaproveita a saída sem uma frase própria para a tela.

## A cura na origem

- Cada uma dessas ações ganha, no script, um resumo de uma a três frases que uma pessoa entende (o que está
  valendo, o que mudaria), sem nome de chave do `meow.conf`, sem id interno, sem tabela; a saída longa continua
  para o terminal.
- A frase quebrada em duas linhas (`areas.sh`, `atualizar_sistema.sh`) vira uma linha só.
- `apps`: o resumo diz quais programas têm tema pendente, pelo nome do programa.
- Na mesma passada, a dica (hover) do item do «Verificar o sistema» pode levar o porquê de cada conferência,
  quando a frase do doctor daquela conferência estiver legível.
- Toda palavra nova entra pelo glossário, com quem usa.

## Como se prova

- `tests/resultado-na-linha.py`: para cada uma das 12 ações, nenhum texto do resultado casa nome de chave
  (`[A-Z_]{4,}=`), `=<`, `[PATCHADO]`, crase ou id de arquivo `.desktop`/`.theme`.
- Suíte inteira sem vermelho.

Tamanho: 3 h.
