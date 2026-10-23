# P99 — Os apps Flatpak vestem o tema do pack no ar

**Pedido de quem usa (23/10):** o MeowSystem assume o que hoje o `NitroKit/src/unificador_temas_dracula.sh`
faz à mão. Medido pela P94 (`docs/sprints/2026-10-15-fechamento/P94-vizinhos-de-fora.md`).

## O que se mediu
O override global do Flatpak nesta máquina aponta para `ICON_THEME=Dracula-Icones`, `GTK_THEME=Dracula`,
`XCURSOR_THEME=Dracula-Cursor`, com `--filesystem` para `/usr/share/icons` e `/usr/share/themes`; quem pôs
foi o NitroKit, à mão, no tempo do GNOME. Nada no MeowSystem cuida disso: numa máquina nova os Flatpak
ficam sem o tema, e se o tema Dracula antigo sumir (P95) eles ficam sem ícone.

## A cura
- Etapa do `install.sh` e par `chk_`/`fix_` no doctor: o override do Flatpak do USUÁRIO (`flatpak override
  --user`, sem senha) aponta para o tema de ícones, o cursor e o GTK que o MeowSystem instala, com acesso de
  leitura às pastas dele; troca junto quando o pack muda; a segunda passada não escreve; o desinstalador
  devolve o de antes (cópia guardada, como as outras escritas).
- O override global antigo (do sistema) é lido e, se apontar para tema que não existe, o doctor mostra o
  estado (sem mandar digitar); a correção dele passa pela ponte root, nunca por caixa de senha.
- **LibreOffice sai de tudo** (quem usa, 23/10: «não vamos usar isso. usamos apenas o OnlyOffice. é bom
  retirarmos de tudo quanto é canto»). Nada de escondê-lo: o MeowSystem não o cita mais (`scripts/pack.py`,
  `docs/PACKS.md` e afins; o histórico em `docs/historico/` fica).
- **O install troca o LibreOffice pelo OnlyOffice** (quem usa, 23/10: «MeowSystem remove no install»): etapa
  nova coberta pela senha única do install — `apt purge` dos pacotes `libreoffice*` (30 nesta máquina; o
  Pop!_OS recém-formatado também os traz) e o OnlyOffice do Flathub (`org.onlyoffice.desktopeditors`,
  `--user`) quando faltar, com o tema de app dele aplicado. Idempotente (sem LibreOffice e com OnlyOffice, não
  escreve nada); o doctor mostra o estado e o `--consertar` repõe pela ponte root, sem caixa de senha; o
  desinstalador registra o que saiu e, ao desinstalar, devolve o LibreOffice pelo apt. Teste com `apt`,
  `dpkg` e `flatpak` falsos; nada de apt de verdade.
- Depois do install: `unificador_temas_dracula.sh` e `ritual_de_harmonia.sh` do NitroKit saem pelo
  `scripts/vizinhos.sh --desativar` (itens novos no contrato), commit só disso lá. O
  `reparo_completo_sistema.sh` fica.

## Como se prova
Teste em casa de brinquedo com `flatpak` falso: o doctor vê, o `--consertar` aplica, a segunda passada não
escreve, trocar de pack troca o override, o desinstalador devolve. `tests/todos.sh` verde duas vezes.

## Execução (23/10)

Feito tudo menos o último item da cura (desativar os dois scripts no NitroKit), que é pós-install.

| item da cura | onde | situação |
|---|---|---|
| override do Flatpak do usuário veste o tema | `scripts/flatpak_tema.sh`, etapa `flatpak_tema` do `install.sh` | feito |
| par `chk_`/`fix_` no doctor | `flatpaktema` (usuário) e `flatpakglobal` (sistema) no `bin/meow` | feito |
| troca junto com o pack | lê `NOME_TEMA_ICONES`, `CURSOR` e o `gtk-theme` do que está no ar a cada passada | feito |
| o desinstalador devolve o de antes | `reverter` guarda e devolve só as chaves e pastas que ele mexeu (`flatpak-tema-antes.tsv`) | feito |
| override global do sistema | lido; só o que aponta para tema que não existe sai, pela ponte root (verbo `flatpak-global-limpar`); sem a ponte vira a pendência `flatpak-global-sistema`, com botão | feito |
| LibreOffice sai de tudo | fora de `LANCADOR_OCULTAR`, de `ocultar_apps.sh`, do `pack.py` e do `docs/PACKS.md`; `docs/historico/` e as medições antigas ficam | feito |
| o install troca o LibreOffice pelo OnlyOffice | `scripts/escritorio.sh`, etapa `escritorio` do `install.sh` (antes da `apps`, que veste o OnlyOffice); o OnlyOffice vem do Flathub com `flatpak install --user` quando falta, e o `purge` dos `libreoffice*` só roda com ele instalado | feito |
| a ponte root tira e devolve | verbos `libreoffice-remover` (sem argumento; recusa inteiro se o apt levasse junto o que não é do LibreOffice) e `libreoffice-devolver` (stdin, só nomes `libreoffice*`) | feito |
| doctor do escritório | `onlyoffice` (usuário, com rede) e `libreoffice` (root) no `bin/meow`, ambos antes de `apps`; sem a ponte, `libreoffice` entra no `SEM_CONSERTO` e vira a pendência `libreoffice-sistema`, com botão | feito |
| o desinstalador devolve o LibreOffice | `escritorio.sh reverter`, antes de a ponte sair, com a lista guardada em `libreoffice-antes.tsv`; o OnlyOffice instalado fica | feito |
| NitroKit: itens no contrato | `nitrokit-unificador-temas` e `nitrokit-ritual-harmonia`, com `requer` em `scripts/flatpak_tema.sh:flatpak override --user` | feito |
| NitroKit: desativar | `scripts/vizinhos.sh --desativar` depois do install | **fica para depois do install** |

**Prova:** `tests/flatpak-tema.sh`, em casa de brinquedo, com `flatpak`, `sudo` e `gsettings` falsos e uma
cópia da ponte com os destinos trocados: o doctor vê sem escrever, o `--consertar` aplica, a segunda passada
não escreve, trocar de pack troca o override, o global só perde o que aponta para o vazio, a ponte recusa
chave e valor que não são dela, o desinstalador devolve o arquivo byte a byte, e os dois itens do NitroKit
esperam o MeowSystem instalado que cuida do Flatpak. Também prova que o LibreOffice não está escondido em lugar nenhum (nem `startcenter`, nem no `meow.conf.exemplo`, `pack.py` e `docs/PACKS.md`).
Está no `tests/todos.sh`.

`tests/escritorio.sh`, com `flatpak`, `dpkg-query`, `apt-get` e `sudo` falsos e a cópia da ponte: o doctor vê sem
escrever; o LibreOffice só sai com o OnlyOffice no lugar (sem rede, ele fica); sem a ponte vira pendência com
botão e não pede senha; com a ponte saem só os `libreoffice*` (o de configuração sobrada também) e o vizinho
fica; a segunda passada não escreve; a ponte recusa o que o apt levaria junto, nome de fora e de shell; o
desinstalador devolve os pacotes, e sem a ponte só avisa onde a lista ficou. Também no `tests/todos.sh`.

**Fica de fora:** desativar os dois scripts no NitroKit (precisa do install rodado, para o `requer` passar).
Os pacotes do LibreOffice desta máquina só saem quando o install rodar: nada de apt de verdade aqui. O
desinstalador não tira o OnlyOffice que o install trouxe, porque é o escritório em uso.
