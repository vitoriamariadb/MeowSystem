# Maquete final do painel (2 Opus, antes dos 6 Sonnet)

A maquete é o contrato visual da leva: os Sonnet das sprints P109-P114 copiam a marcação e as classes
dela e só ligam o comportamento. Quem usa aprova a maquete antes de qualquer Sonnet começar.

## Divisão
| Opus | worktree / branch | telas |
|---|---|---|
| A | `../MeowSystem-maquete-a` / `maquete/a` | moldura (cabeçalho, portas Tema · Personalizar · Definir · Manter · Extensões, abas da seção em barra horizontal ACIMA da prévia, prévia fixa, barra «N mudanças · Desfazer», modal do «Instalar tudo»), Tema, Definir (todas as seções, Dia e noite com Modo de leitura, Programas sem prévia, Lançador com sugestão em Escondidos), Manter |
| B | `../MeowSystem-maquete-b` / `maquete/b` | Personalizar (Cores, Papel, Ícones com abas Apps/Sistema/Biblioteca e oficina de desenho; gerador MeowSystem traço Arcticons e gerador Dracula círculo+glifo; Sons com a lista dos sons do sistema, quando toca, ouvir e trocar; sino do volume; Mandar), Extensões (cartões dos 5 applets, bloco Builds, Adicionar repositório) |

## Regras
- HTML estático, abre com `file://`, sem rede. Arquivos em `maquete/a/` ou `maquete/b/`; uma página
  por porta (`tema.html`, `definir.html`… ) ligadas entre si pelo cabeçalho.
- Usa o `app/pagina/estilo.css` real (copiado para a pasta; mudanças nele são parte da maquete e
  ficam num `estilo.css` da maquete) e as classes que o painel já tem. Classe nova só quando não
  existe uma. JS só para trocar estado de demonstração (abrir modal, trocar aba, simular arrastar).
- Dados reais: nomes de apps, ícones e cores lidos de `packs/meowsystem/` e `packs/dracula/` (SVG
  copiados para a pasta da maquete). Nada de lorem ipsum.
- Cada tela mostra os estados: normal, vazio, carregando, erro, e o da ponte que falta quando cabe.
- Interface mostra, não explica: nome curto, ícone, controle, prévia; frase de explicação vira dica.
- Larguras: 1920x1080, 1550x860, 1500x900, 1280x800. Nada estoura o pai (`scrollWidth > clientWidth`);
  cabeçalho, abas e prévia continuam visíveis rolando até o fim.
- `CONTRATO.md` da sua pasta: para cada elemento de tela, o id/classe, o item do relatório
  (Q1-xx, Q2-xx, Q3-xx) e a sprint (P109-P114) que o liga.
- Capturas Playwright headless das quatro larguras em `maquete/<a|b>/capturas/` (fora do git).
