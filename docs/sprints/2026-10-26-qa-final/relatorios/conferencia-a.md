# Conferência A: P109, P110 e P111

Branch `conferencia/a`, nascida de `integracao/qa-final` (63ee3497).

## O que conferi
- As provas das três `## Execução`, rodadas de novo: `chave-etapa.sh`, `convergencia.sh`, `jogos-heroic.sh`,
  `um-cartao-por-jogo.sh`, `grava-ao-soltar.py`, `app.sh`, `app-navegador.py`, `app-layout.py`,
  `app-uso-real.py`, `migracao-do-painel.py`, `pack.sh` e `restaurar.sh`.
- As portas como usuária, em Playwright headless com HOME temporário, a 1920x1080 e a 1280x800:
  - as portas dizem Tema · Personalizar · Definir · Manter · Extensões;
  - nenhuma das 15 rotas tem «Mais ajustes» nem rola de lado;
  - em cada seção do Definir, cabeçalho (0), abas (64) e prévia ficam à vista depois de rolar até o fim, e Programas não tem prévia;
  - a aba Tema não tem «Ver» nem «No ar agora» e tem «Criar o meu tema»;
  - o Manter tem «Conferir» e, sem a ponte, «Consertar a ponte», sem «Conferir e consertar»; nos cartões, o desenho fica à esquerda do título;
  - em Dia e noite está o bloco «Modo de leitura»;
  - o diálogo do «Instalar tudo» cabe na tela;
  - na barra, o slider não grava no `input` e grava uma vez no `change`; a barra mostra «1 mudança · Desfazer», sem Aplicar e sem «Ver sem mudar», e o «Desfazer» de uma linha devolve o valor.
  - Manter, a barra e o Definir batem com a maquete A.
- A regressão entre sprints: as linhas que cada sprint pôs ou tirou em `app.js`, `paginas.js`, `lugares.js`,
  `mesa.js`, `servidor.py`, `estilo.css`, `index.html` e `install.sh`, comparadas com a integração. O que sumiu
  foi trocado de propósito no merge, como `leitura-applet`, que virou `extensao-leitura`, ou refeito por outra
  sprint, como a prévia do modo de leitura, que hoje passa por `quente`/`textura`.

## O que corrigi
| commit | o quê |
|---|---|
| 01305433 | `aplicar-ajuste` ganha nome de assunto: «Ajuste pendente» (`app.sh` 12c) |
| f95fa9d3 | tabela chave-etapa: `MIDIA` e `LEITURA_APPLET` vão para `extensoes`; entram `EXTENSOES` (`extensoes,extensoes_tema`) e `BUILDS_AO_ENTRAR` (`-`, porque quem o lê é o `meow-builds-login.service`) |
| 42d9cc66 | `app-uso-real.py` volta ao corte de 72 px. Com 72 px ele passa, porque cada rota abre no topo e nada rola por baixo das abas. O corte de 120 px deixava sem conferência a primeira fila de controles das páginas sem abas. |
| 993c1f9e | causa do timeout do `app-navegador.py`. A P109 fez o `/api/criar` esperar o aplicador, e a P113 pôs um `/api/criar` (sons) no «Guardar». Com um ajuste aplicando em segundo plano, o «Guardar» ficava preso até 300 s. Agora o `/api/criar` só espera quando mexe no pack que está no ar. |
| deefd625 | o «Baixar o tema» clicado com um «Guardar» ainda em voo reimportava o pack, e o servidor recusava com «já existe». Agora ele espera o mesmo «Guardar». |
| af889f61 | os dois vermelhos a mais do `restaurar.sh`. O primeiro era `aplicar`: a ação interna passava o `install.sh` inteiro por `/api/rodar`, sem confirmação e sem Restaurar, e se declarava «só lê». O segundo, `som_aplicar`, era efeito do primeiro: o tema de som já estava no lugar. Agora a ação interna só roda pelo aplicador. |

## Placar
Último `./tests/todos.sh`: 102 testes, 96 verdes, 0 pulados, 6 vermelhos. Nenhum vermelho é desta área:
- `decisoes.sh`: aceito (GPU fora da RTX e shim do compositor; é o estado da máquina);
- `restaurar.sh`: aceito, só `pack_usar` e `desinstalar` (arquivos do VS Code);
- `readme.sh`: se regenera no merge;
- `app-layout.py` (a ficha do ícone), `app-completo.py` (`criar/sons`) e `extensoes-pagina.py`: são do conferente B.

## Visto e deixado para o conferente B
- O `extensoes.css` redefine `.abas-ajustes` para a página inteira. As abas globais do Definir ganham margem
  negativa: começam em x = -56 e ficam mais largas que a janela (2032 px a 1920). O B já tira essas regras na
  worktree dele.
- A página Extensões cria um segundo `id="abas"` dentro do `#conteudo`.

## Anotado para depois (fora do pedido)
- `scripts/som.sh` guarda a pasta do tema de som antes de comparar. Com tudo no lugar, o «Regravar o som»
  deixa um «Restaurar» vazio. O defeito já existia no dev.

## Para conferir com a mão
1. Definir › Painel e dock: arraste um slider e solte; a barra diz «1 mudança» e o «Desfazer» devolve o valor.
2. Troque a variante do tema e, enquanto ela aplica, vá a Personalizar › Guardar e depois Mandar › Baixar: o arquivo baixa.
3. Manter a 1280: o «Instalar» do cartão «Instalar de novo» fica baixo, como na maquete; veja se agrada.
4. Tema a 1280: em «Claro ou escuro», o «Automático» quebra para a segunda linha.
