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
