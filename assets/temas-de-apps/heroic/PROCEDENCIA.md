# De onde vem o tema do Heroic

| | |
|---|---|
| origem | <https://github.com/catppuccin/heroic> |
| **commit pinado** | `1248e2d24721aa1cc54f185b1b851826207a2b46` (também em `upstream/COMMIT`) |
| licença | MIT (Catppuccin) — cópia em `upstream/LICENSE` |
| o que veio | **56** arquivos `.css` (4 flavors × 14 accents), 240 KB |
| integridade | `SHA256SUMS`, uma linha por arquivo |
| autoria citada pelo upstream | [ndsboy](https://github.com/ndsboy), [DrymarchonShaun](https://github.com/DrymarchonShaun) |

## Por que o acervo vai para o git

É texto, e é pequeno. A regra do projeto que mantém acervo FORA do repositório
existe para binário grande — os 11 MB de cursores XCursor por flavor, as imagens
de 4K do wallhaven. 240 KB de CSS versionado é o que permite instalar sem rede e
conferir a procedência com um `sha256sum -c`.

Para refazer o acervo a partir do upstream:

```bash
git clone https://github.com/catppuccin/heroic /tmp/heroic
git -C /tmp/heroic checkout 1248e2d24721aa1cc54f185b1b851826207a2b46
rm -f assets/temas-de-apps/heroic/upstream/themes/*.css
cp /tmp/heroic/themes/*.css assets/temas-de-apps/heroic/upstream/themes/
cp /tmp/heroic/LICENSE assets/temas-de-apps/heroic/upstream/LICENSE
( cd assets/temas-de-apps/heroic/upstream && sha256sum themes/*.css > ../SHA256SUMS )
```

## O que o módulo faz com ele

O detalhe — as duas chaves, os dois arquivos, e por que a pasta de temas tem de
ser a do próprio Heroic — está no cabeçalho do `manifesto.sh`. Em uma linha:
os 56 CSS vão para `<config>/heroic/themes`, `customThemesPath` aponta para lá,
e `theme` recebe `catppuccin-<flavor>-<accent>` conforme o `meow.conf`.

## O que NÃO foi feito, e por quê

| ideia | por que ficou de fora |
|---|---|
| baixar em tempo de instalação | 56 arquivos de 1,8 KB não valem uma dependência de rede, e o modelo do `FONTES.tsv` existe para o que é grande demais para versionar |
| gerar o CSS a partir da nossa paleta | daria o mesmo resultado com mais código para manter, e perderia o mapeamento de variável do upstream — que é o trabalho de verdade dele, não a cor |
| escrever as chaves com `sed` | são dois JSON de estado vivo de um Electron; quem lê e escreve é o `python3` com `json`, preservando a indentação de cada um |
