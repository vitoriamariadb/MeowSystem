# P217 — o Telegram veste os botões do pack (17/11/2026)

## O que se mediu
Telegram flatpak (`org.telegram.desktop`, Qt próprio) com cópia da config: barra própria com `_ □ ×` genéricos
(foto). A opção «Usar moldura do sistema» (Configurações > Avançado) troca para a moldura do COSMIC.

## A causa
A barra é desenhada pelo Telegram; a opção mora no `tdata/settings*`, binário criptografado, sem chave de texto.

## A cura na origem
Ainda sem caminho limpo: medir se a versão do flatpak lê alguma variável ou argumento para a moldura nativa
(`TDESKTOP_*`, `-nativeframe` ou parecido) antes de qualquer gesto. Sem isso, nada se força (o doctor não manda
digitar); fica registrado como formato sem cura.

## Como se prova
Foto antes e depois com a cópia da config, e o teste do manifesto `telegram` com HOME temporário se a cura existir.
