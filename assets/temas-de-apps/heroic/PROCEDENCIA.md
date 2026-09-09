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
e `theme` recebe **`catppuccin-<flavor>-<accent>.css`** conforme o `meow.conf`.

### O `.css` no valor da chave, e a afirmação errada que estava aqui

Até 08/09/2026 este arquivo dizia que `theme` recebia o nome **sem** a extensão.
É falso no Heroic 2.22.1, e foi essa frase — repetida no cabeçalho do módulo e
no commit `764e230` — que fez o defeito parecer medido. A prova está no handler,
lido no `app.asar` da versão instalada:

```js
addHandler("getThemeCSS", async (event, theme) => {
  const cssPath = path.join(customThemesPath, theme);   // não acrescenta ".css"
  if (!existsSync(cssPath)) return "";                  // e some calado
  return readFileSync(cssPath, "utf-8");
});
```

O front só tira a extensão **depois** de pedir o arquivo, para transformar o
nome em classe do `body` (`e.replace(".css", "")`). Essa substituição é a prova:
ela só existe porque há o que substituir. Sem o `.css`, o backend procura um
arquivo com o nome exato, não acha, devolve string vazia — e a tela fica de
fábrica, sem erro e sem aviso. O verificador `heroictema` do `meow doctor` relê
esse handler a cada passagem para que a próxima mudança de forma tenha nome.

`midnightMirage`, no `reverter`, continua **sem** extensão: é tema embutido, e o
front pula o `getThemeCSS` para os embutidos.

### O remendo das variáveis

O arquivo instalado não é a cópia do upstream: é **o CSS do upstream mais um
bloco nosso no fim**, com o mesmo seletor. Medido em 09/09/2026 no `app.asar`: o
Heroic 2.22.1 lê **256** variáveis por `var(--…)` e o acervo define **56**. Das
201 que faltam, entram no bloco as que são cor e que ou morrem com a nossa
classe no `body` (o Heroic só as define dentro de `body.<tema-embutido>`) ou
sobrevivem com o hex de fábrica. A tabela — uma linha por variável, com o hex
saindo de `assets/paleta/catppuccin.json` e nunca escrito à mão — está no
`manifesto.sh`, junto com o critério de exclusão.

O `SHA256SUMS` continua conferindo a cópia do upstream **no repositório**; quem
confere o arquivo instalado é o `meow_app_conferir`, comparando com o texto
composto pela mesma régua que o escreveu.

## O que NÃO foi feito, e por quê

| ideia | por que ficou de fora |
|---|---|
| baixar em tempo de instalação | 56 arquivos de 1,8 KB não valem uma dependência de rede, e o modelo do `FONTES.tsv` existe para o que é grande demais para versionar |
| gerar o CSS a partir da nossa paleta | meia verdade, corrigida em 09/09/2026: o mapeamento de variável do upstream continua sendo o trabalho de verdade dele, mas está um ano atrás do Heroic — daí o bloco do remendo, que é o menor complemento que fecha a diferença sem reescrever o acervo |
| escrever as chaves com `sed` | são dois JSON de estado vivo de um Electron; quem lê e escreve é o `python3` com `json`, preservando a indentação de cada um |
