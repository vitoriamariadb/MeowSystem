# Pack mínimo

O exemplo do formato de pack com três pastas de ícone (decisão 14).

```
pack-minimo/
  pack.json        formato 2: o id, o nome, a paleta e o que os ícones declaram
  paleta.json      um flavor, com as 26 cores
  logo.svg         a capa (gerada: `python3 scripts/pack.py logo-gerado <pasta>`)
  CREDITOS.md      de onde vem a arte, e sob que licença
  icones/
    apps.map       programa → desenho (`org.gnome.Console : apps/org.gnome.Console.svg`)
    pastas.map     nome de pasta → desenho
    apps/          o desenho ligado a um programa
    sistema/       pastas, tipos de arquivo, status (aqui, `pastas/folder.svg`)
    biblioteca/    o resto, para escolher no painel (aqui, `estrela.svg`)
```

Uma quarta pasta em `icones/` é recusada pelo `meow pack validar`. Flavor é
sufixo do nome ou subpasta de uma das três. O que o pack não traz vem do
pack-base do MeowSystem. O `docs/PACKS.md` tem o formato inteiro.
