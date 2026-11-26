# P303 — o glifo do pack virava código no ZapZap (25/11/2026)

Achado pelo conferente do bloco da bandeja. O defeito já estava no `master` (`11ed66b`); o bloco novo só abriu mais
uma entrada para ele, ao ler o glifo da pasta `desenhos` da bandeja do pack.

## O que se mediu
- `scripts/icones_tray_zapzap.sh` troca o conteúdo do bloco `_SYMBOLIC = """…"""` do `tray_icon.py` do ZapZap pelo
  texto do SVG do pack.
- Um glifo com `"""` fecha a string, e o resto do arquivo vira código Python. Provado com um pack em `MEOW_PACKS`:
  um `os.system` entra no `tray_icon.py`, e o `compile()` que o script faz antes de escrever aceita, porque o
  resultado é Python válido.
- `meow pack validar` não olha o conteúdo do glifo.
- Alcance: pede um pack de fora malicioso instalado e o ZapZap presente. Os dois packs do repositório não têm esse
  conteúdo.

## A causa
O texto de um arquivo de pack era colado dentro do fonte de outro programa sem conferir que continuava sendo só
desenho.

## A cura na origem
O bloco `_SYMBOLIC` é do ZapZap: ele é uma string de aspas triplas que o próprio app passa por `format`, então o
desenho tem de continuar entrando como texto ali. A cura é o glifo só entrar se não puder mudar a forma do arquivo
(`971054f` na branch do bloco):
- recusa `"""`, barra invertida, `DOCTYPE` e `ENTITY`;
- recusa chave solta, que quebraria o `format`;
- recusa qualquer elemento que não seja forma de desenho;
- recusa glifo que é link simbólico ou que sai da pasta do pack pelo caminho real, na Steam e no ZapZap.
Na integração, o glifo da Steam ganhou a mesma guarda de só formas: sem ela, um `<image>` no glifo embutia no PNG da
bandeja um arquivo vizinho do SVG temporário.
Toda recusa sai com rc=2 e nada escrito. `0089eda` cobre também a pasta `desenhos` que sobe (`../`), é absoluta ou
passa por link: o pack inteiro é recusado pela guarda `_dentro` do `pack.py`, que já existia.

## Como se prova
`tests/bandeja-por-pack.sh`: seis casos do glifo do ZapZap e um do glifo da Steam, vermelhos sem o conserto e verdes com ele, e três da pasta
`desenhos`. Com `meowsystem`/mocha a saída dos três scripts e os arquivos gerados são idênticos aos do `master`.

## O que fica de fora
A mesma colagem em outros scripts que escrevem arquivo de outro programa a partir de arquivo de pack não foi
varrida neste bloco.
