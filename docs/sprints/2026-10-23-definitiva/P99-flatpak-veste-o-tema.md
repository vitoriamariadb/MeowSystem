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
  `docs/PACKS.md` e afins; o histórico em `docs/historico/` fica). Remover os pacotes da máquina é outra
  tarefa, decidida à parte.
- Depois do install: `unificador_temas_dracula.sh` e `ritual_de_harmonia.sh` do NitroKit saem pelo
  `scripts/vizinhos.sh --desativar` (itens novos no contrato), commit só disso lá. O
  `reparo_completo_sistema.sh` fica.

## Como se prova
Teste em casa de brinquedo com `flatpak` falso: o doctor vê, o `--consertar` aplica, a segunda passada não
escreve, trocar de pack troca o override, o desinstalador devolve. `tests/todos.sh` verde duas vezes.
