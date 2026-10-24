# Migração do painel: de antes (P97) para o painel novo (P98)

Gerada por `tests/migracao-do-painel.py` a partir do código: as chaves e as ações do `app/servidor.py`, e o lugar de cada uma no `app/pagina/lugares.js`. Não edite à mão; rode o teste com `--escrever`.


## Chaves do esquema (122)

| chave | antes | agora | nome na tela |
|---|---|---|---|
| `FLAVOR` | Cor e tela | Tema › Temas | Variante |
| `PACK` | Cor e tela | Tema › Temas | Tema |
| `WALLPAPER_DRACULA_REPO` | Cor e tela | Ajustes › Papel de parede › Mais ajustes | Acervo do Dracula |
| `WALLPAPER_DRACULA_COMMIT` | Cor e tela | Ajustes › Papel de parede › Mais ajustes | Versão do acervo |
| `ACCENT` | Cor e tela | Tema › Cor de destaque | Cor de destaque |
| `MODO` | Cor e tela | Tema › Claro ou escuro | Claro ou escuro |
| `JANELAS_TILING` | Cor e tela | Ajustes › Janelas e tela › Janelas | Lado a lado |
| `JANELAS_TILING_ESCOPO` | Cor e tela | Ajustes › Janelas e tela › Janelas | Vale para |
| `ESCALA_TELA` | Cor e tela | Ajustes › Janelas e tela › Tela | Tamanho de tudo |
| `CURSOR` | Cor e tela | Ajustes › Janelas e tela › Tela | Ponteiro |
| `CURSOR_VERSAO` | Cor e tela | Ajustes › Janelas e tela › Mais ajustes | Versão do ponteiro |
| `AREAS_NOMES` | Áreas de trabalho | Ajustes › Janelas e tela › Áreas de trabalho | Nomes |
| `AREAS_FOLGA` | Áreas de trabalho | Ajustes › Janelas e tela › Mais ajustes | Folga no nome |
| `AREAS_ENCAIXE` | Áreas de trabalho | Ajustes › Janelas e tela › Áreas de trabalho | Encaixe por área |
| `LOGO` | Logo do sistema | Ajustes › Mascote › Na dock | Mascote |
| `LOGO_ROTACAO` | Logo do sistema | Ajustes › Mascote › Na dock | Girar sozinho |
| `LOGO_MODO` | Logo do sistema | Ajustes › Mascote › Na dock | Como escolhe |
| `LOGO_DIA` | Logo do sistema | Ajustes › Mascote › Na dock | De dia |
| `LOGO_NOITE` | Logo do sistema | Ajustes › Mascote › Na dock | De noite |
| `LOGO_RECICLAR` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Recarregar na virada |
| `LOGO_INTERVALO` | Logo do sistema | Ajustes › Mascote › Na dock | Gira a cada |
| `NOME_TEMA_ICONES` | Ícones | Criar tema › Ícones › Mais ajustes | Nome do tema |
| `ICONES_RESGATADOS` | Ícones | Criar tema › Ícones › Mais ajustes | Ícones resgatados |
| `ICONES_DRACULA` | Ícones | Criar tema › Ícones › Mais ajustes | Desenhos do pack |
| `ICONES_LOGO_HEFESTO` | Ícones | Criar tema › Ícones › Mais ajustes | Logo do Hefesto |
| `ICONES_PASTAS` | Ícones | Criar tema › Ícones | Cor das pastas |
| `ICONES_FLAVOR` | Ícones | Criar tema › Ícones › Mais ajustes | Variante dos ícones |
| `ICONES_COR_MARCA` | Ícones | Criar tema › Ícones › Mais ajustes | Cor da marca |
| `PASTAS_XDG` | Ícones | Criar tema › Ícones › Mais ajustes | Pastas especiais |
| `FORMA_PAINEL_SOLTO` | Painel e dock | Ajustes › Painel e dock › Forma | Solta da borda |
| `FORMA_DOCK_SOLTO` | Painel e dock | Ajustes › Painel e dock › Forma | Solta da borda |
| `FORMA_PAINEL_ILHA` | Painel e dock | Ajustes › Painel e dock › Forma | Em pastilha |
| `FORMA_DOCK_ILHA` | Painel e dock | Ajustes › Painel e dock › Forma | Em pastilha |
| `FORMA_MARGEM_PAINEL` | Painel e dock | Ajustes › Painel e dock › Forma | Distância da borda |
| `FORMA_MARGEM_DOCK` | Painel e dock | Ajustes › Painel e dock › Forma | Distância da borda |
| `FORMA_RAIO_PAINEL` | Painel e dock | Ajustes › Painel e dock › Forma | Cantos |
| `FORMA_RAIO_DOCK` | Painel e dock | Ajustes › Painel e dock › Forma | Cantos |
| `FORMA_ESPACO_PAINEL` | Painel e dock | Ajustes › Painel e dock › Forma | Espaço entre ícones |
| `FORMA_ESPACO_DOCK` | Painel e dock | Ajustes › Painel e dock › Forma | Espaço entre ícones |
| `FORMA_RECHEIO_PAINEL` | Painel e dock | Ajustes › Painel e dock › Mais ajustes | Folga interna |
| `FORMA_RECHEIO_DOCK` | Painel e dock | Ajustes › Painel e dock › Mais ajustes | Folga interna |
| `FORMA_CENTRO_PAINEL` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Meio |
| `FORMA_CENTRO_DOCK` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Meio |
| `FORMA_ALA_INICIAL_PAINEL` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Ponta esquerda |
| `FORMA_ALA_FINAL_PAINEL` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Ponta direita |
| `FORMA_ALA_INICIAL_DOCK` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Ponta esquerda |
| `FORMA_ALA_FINAL_DOCK` | Painel e dock | Ajustes › Painel e dock › Tamanho dos ícones | Ponta direita |
| `VIDRO_AO_MAXIMIZAR` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Vidro ao maximizar |
| `VIDRO_OPACIDADE_PAINEL` | Painel e dock | Ajustes › Painel e dock › Forma | Vidro |
| `VIDRO_OPACIDADE_DOCK` | Painel e dock | Ajustes › Painel e dock › Forma | Vidro |
| `RELOGIO_SEGUNDOS` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Segundos no relógio |
| `MIDIA` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Música tocando |
| `MIDIA_LARGURA` | Painel e dock | Ajustes › Painel e dock › Mais ajustes | Largura da música |
| `MIDIA_COR_ALBUM` | Painel e dock | Ajustes › Painel e dock › Mais ajustes | Cor da capa |
| `MIDIA_CAPA` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Capa do disco |
| `MIDIA_FONTE` | Painel e dock | Ajustes › Painel e dock › Mais ajustes | Letra da música |
| `MIDIA_COR_TITULO` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Cor da música |
| `MIDIA_COR_ARTISTA` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Cor da banda |
| `MIDIA_CONTROLES` | Painel e dock | Ajustes › Painel e dock › Barra de cima | Tocar e pular |
| `WALLPAPER_BASE` | Papel de parede | Ajustes › Papel de parede › Mais ajustes | Pasta do carrossel |
| `WALLPAPER_INTERVALO` | Papel de parede | Ajustes › Papel de parede › Troca | A cada |
| `WALLPAPER_FIXO_TTL` | Papel de parede | Ajustes › Papel de parede › Mais ajustes | Escolhida dura |
| `WALLPAPER_ORDEM` | Papel de parede | Ajustes › Papel de parede › Troca | Ordem |
| `WALLPAPER_AJUSTE` | Papel de parede | Ajustes › Papel de parede › Troca | Encaixe |
| `WALLPAPER_FONTES_PERMITIDAS` | Papel de parede | Ajustes › Papel de parede › Mais ajustes | Pastas suas |
| `WALLPAPER_NOTIFICAR` | Papel de parede | Ajustes › Papel de parede › Troca | Avisar a troca |
| `FILES_MENU` | Papel de parede | Ajustes › Papel de parede › Troca | Botão direito |
| `FILES_MENU_AUTOBUILD` | Papel de parede | Ajustes › Papel de parede › Mais ajustes | Menu se reconstrói |
| `NOITE_INICIO` | Dia e noite | Ajustes › Dia e noite › Noite | Começa |
| `NOITE_FIM` | Dia e noite | Ajustes › Dia e noite › Noite | Termina |
| `MODO_AUTO_CLARO_DE` | Dia e noite | Ajustes › Dia e noite › Claro e escuro | Escuro termina |
| `MODO_AUTO_CLARO_ATE` | Dia e noite | Ajustes › Dia e noite › Claro e escuro | Escuro começa |
| `WALLPAPER_NOITE` | Dia e noite | Ajustes › Dia e noite › Papel da noite | Imagens escuras |
| `WALLPAPER_NOITE_INICIO` | Dia e noite | Ajustes › Dia e noite › Papel da noite | Começa |
| `WALLPAPER_NOITE_FIM` | Dia e noite | Ajustes › Dia e noite › Papel da noite | Termina |
| `WALLPAPER_LIMIAR_LUZ` | Dia e noite | Ajustes › Dia e noite › Papel da noite | Quão escura |
| `LEITURA_AGENDA` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Tela quente |
| `LEITURA_HORARIO_INICIO` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Começa |
| `LEITURA_HORARIO_FIM` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Termina |
| `LEITURA_TEMPERATURA` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Quão quente |
| `LEITURA_TEXTURA` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Textura de papel |
| `LEITURA_RAMPA_MIN` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Entrar devagar |
| `LEITURA_APPLET` | Modo de leitura | Ajustes › Dia e noite › Tela quente | Botão na barra |
| `TERMINAL_ESQUEMA` | Terminal | Ajustes › Terminal › Cores | Cores do tema |
| `TERMINAL_CURSOR` | Terminal | Ajustes › Terminal › Cores | Cor do cursor |
| `PROMPT_STARSHIP` | Terminal | Ajustes › Terminal › Linha de comando | Linha colorida |
| `FASTFETCH_LOGO` | Logo do sistema | Ajustes › Mascote › No terminal | Ao abrir |
| `FASTFETCH_LOGO_GATO` | Logo do sistema | Ajustes › Mascote › No terminal | Fixo |
| `FASTFETCH_LOGO_MODO` | Logo do sistema | Ajustes › Mascote › No terminal | Qual |
| `FASTFETCH_LOGO_DIA` | Logo do sistema | Ajustes › Mascote › No terminal | De dia |
| `FASTFETCH_LOGO_NOITE` | Logo do sistema | Ajustes › Mascote › No terminal | De noite |
| `FASTFETCH_LOGO_COLUNAS` | Logo do sistema | Ajustes › Mascote › No terminal | Tamanho |
| `FASTFETCH_LOGO_LINHAS` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Altura do desenho |
| `FASTFETCH_LOGO_QUEBRAS` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Linhas antes |
| `FASTFETCH_LOGO_ALINHAR` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Texto ao lado |
| `FASTFETCH_TITULO` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Linha de cima |
| `FASTFETCH_LOGO_RECUO` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Espaço ao lado |
| `FASTFETCH_LOGO_CELULA` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Proporção da letra |
| `FASTFETCH_LOGO_BLOCOS` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Detalhe |
| `FASTFETCH_LOGO_CONF` | Logo do sistema | Ajustes › Mascote › Mais ajustes | Corrigir o Fastfetch |
| `APPS_ATIVOS` | Lançadores e jogos | Ajustes › Programas › Recebem o tema | Programas |
| `SPOTIFY_MARKETPLACE` | Lançadores e jogos | Ajustes › Programas › Lançador | Loja do Spotify |
| `LANCADOR_SISTEMA` | Lançadores e jogos | Ajustes › Programas › Lançador | Arrumar o lançador |
| `LANCADOR_OCULTAR` | Lançadores e jogos | Ajustes › Programas › Lançador | Escondidos |
| `AUTOSTART_BLOQUEADOS` | Lançadores e jogos | Ajustes › Programas › Ao ligar | Não abrem sozinhos |
| `PONTE_ROOT` | Manutenção | Cuidar › Sozinho | Consertos de sistema |
| `AUTO_REPARO` | Manutenção | Cuidar › Sozinho | Conferir todo dia |
| `AUTO_REPARO_NOTIFICAR` | Manutenção | Cuidar › Sozinho | Avisar o conserto |
| `ASSETS_VIGIA` | Manutenção | Cuidar › Sozinho | Mascote novo entra |
| `ASSETS_VIGIA_NOTIFICAR` | Manutenção | Cuidar › Sozinho | Avisar o mascote |
| `FLATPAK_VIGIA` | Manutenção | Cuidar › Sozinho | Ícones após atualizar |
| `FLATPAK_VIGIA_NOTIFICAR` | Manutenção | Cuidar › Sozinho | Avisar os ícones |
| `STEAM_VIGIA` | Manutenção | Cuidar › Sozinho | Jogo desinstalado sai |
| `HEROIC_VIGIA` | Manutenção | Cuidar › Sozinho | Jogo do Heroic |
| `BACKUPS_MANTIDOS` | Manutenção | Cuidar › Registro | Cópias guardadas |
| `LOG_NIVEL` | Manutenção | Cuidar › Registro | Quanto fala |
| `SOM` | Manutenção | Criar tema › Sons | Som do volume |
| `SOM_FUNDAMENTAL` | Manutenção | Criar tema › Sons | Primeira nota |
| `SOM_HARMONICO` | Manutenção | Criar tema › Sons | Segunda nota |
| `SOM_PESO_FUNDAMENTAL` | Manutenção | Criar tema › Sons › Mais ajustes | Peso da primeira |
| `SOM_PESO_HARMONICO` | Manutenção | Criar tema › Sons › Mais ajustes | Peso da segunda |
| `SOM_DECAIMENTO` | Manutenção | Criar tema › Sons | Duração |

## Ações do servidor (67)

| ação | antes | agora | nome na tela |
|---|---|---|---|
| `pack_usar` | Instalação · «Usar este pack» | Criar tema › Mandar; Tema › Temas | Vestir |
| `pack_remover` | Instalação · «Remover este pack» | Tema › Temas | Remover |
| `instalar` | Instalação · «Instalar tudo» | Cuidar › Instalar de novo | Instalar tudo |
| `som_ouvir` | Manutenção · «Ouvir o som» | Criar tema › Sons | Ouvir o instalado |
| `som_aplicar` | Manutenção · «Regravar o som» | Criar tema › Sons | Regravar o som |
| `doctor` | Instalação · «Conferir a máquina» | Cuidar › Estado | Conferir |
| `doctor_consertar` | Instalação · «Conferir e consertar» | Cuidar › Estado | Conferir e consertar |
| `status` | Instalação · «O que está no ar agora» | Tema › Mais ajustes | No ar agora |
| `desinstalar` | Instalação · «Desinstalar o MeowSystem» | Cuidar › Zona de perigo | Desinstalar |
| `log` | Instalação · «As últimas 50 linhas do registro» | Cuidar › Registro | Registro |
| `sistema_ver` | Atualização · «O que a atualização mudaria» | Cuidar › Atualizar | O que muda |
| `sistema_atualizar` | Atualização · «Atualizar a máquina inteira» | Cuidar › Atualizar | Atualizar a máquina |
| `sistema_limpar` | Atualização · «Limpar o que sobrou» | Cuidar › Atualizar | Limpar |
| `tema` | Cor e tela · «Temas prontos nesta máquina» | Tema › Mais ajustes | Temas prontos |
| `tema_aplicar` | Cor e tela · «Trocar de tema» | Tema › Mais ajustes | Tema pronto |
| `tema_modo` | Cor e tela · «Passar para claro ou escuro» | Tema › Mais ajustes | Modo agora |
| `restaurar` | Instalação · «Restaurar» | Cuidar › Mais ajustes | Restaurar |
| `desfazer` | Instalação · «Voltar ao tema de antes» | Cuidar › Zona de perigo | Tema de antes |
| `icones` | Ícones · «Tema de ícones instalado» | Criar tema › Ícones › Mais ajustes | Tema instalado |
| `icones_reconstruir` | Ícones · «Reconstruir o tema de ícones» | Criar tema › Ícones › Mais ajustes | Reconstruir os ícones |
| `icones_traco` | Ícones · «Pôr os desenhos em traço na tela» | Criar tema › Ícones › Mais ajustes | Desenhos em traço |
| `icones_pack` | Ícones · «Pôr os desenhos do pack na tela» | Criar tema › Ícones › Mais ajustes | Desenhos do pack |
| `logo_listar` | Logo do sistema · «Qual mascote está no ar, e por quê» | Ajustes › Mascote › Mais ajustes | Mascote agora |
| `logo_trocar` | Logo do sistema · «Pôr um mascote no dock» | Ajustes › Mascote › Na dock | Pôr agora |
| `logo_girar` | Logo do sistema · «Passar ao próximo mascote» | Ajustes › Mascote › Na dock | Próximo mascote |
| `wallpaper` | Papel de parede · «O carrossel agora» | Ajustes › Papel de parede › Mais ajustes | Carrossel agora |
| `wallpaper_proximo` | Papel de parede · «Próxima imagem» | Ajustes › Papel de parede | Próxima imagem |
| `wallpaper_anterior` | Papel de parede · «Imagem anterior» | Ajustes › Papel de parede › Imagens | Imagem anterior |
| `wallpaper_carrossel` | Papel de parede · «Voltar a girar» | Ajustes › Papel de parede › Imagens | Voltar a girar |
| `wallpaper_aplicar` | Papel de parede · «Reaplicar as regras do carrossel» | Ajustes › Papel de parede › Mais ajustes | Regras do carrossel |
| `wallpaper_banir` | Papel de parede · «Tirar esta imagem do carrossel» | Criar tema › Papel de parede | Tirar do carrossel |
| `wallpaper_usar` | Papel de parede · «Usar esta imagem agora» | Criar tema › Papel de parede | Usar agora |
| `wallpaper_permitir` | Papel de parede · «Manter a imagem que eu pus» | Cuidar › Pendências | Imagem que você pôs |
| `wallpaper_dispensar` | Papel de parede · «Deixar assim» | Cuidar › Pendências | Imagem que você pôs |
| `wallpaper_favoritar` | Papel de parede · «Guardar nas favoritas» | Criar tema › Papel de parede | Favorita |
| `wallpaper_desfavoritar` | Papel de parede · «Tirar das favoritas» | Criar tema › Papel de parede | Tirar das favoritas |
| `wallpaper_dia` | Papel de parede · «Guardar esta imagem para o dia» | Criar tema › Papel de parede | De dia |
| `wallpaper_noite` | Papel de parede · «Guardar esta imagem para a noite» | Criar tema › Papel de parede | De noite |
| `wallpaper_lado_auto` | Papel de parede · «Deixar a medição decidir» | Criar tema › Papel de parede | Medir a luz |
| `areas_ver` | Áreas de trabalho · «As áreas de agora» | Ajustes › Janelas e tela › Mais ajustes | Áreas agora |
| `areas_aplicar` | Áreas de trabalho · «Gravar as áreas» | Ajustes › Janelas e tela › Áreas de trabalho | Gravar as áreas |
| `areas_alfinetar_primeira` | Áreas de trabalho · «Criar a primeira área» | Ajustes › Janelas e tela › Áreas de trabalho | Primeira área |
| `areas_reverter` | Áreas de trabalho · «Voltar as áreas de antes» | Ajustes › Janelas e tela › Áreas de trabalho | Áreas de antes |
| `areas_desalfinetar` | Áreas de trabalho · «Tirar uma área» | Ajustes › Janelas e tela › Áreas de trabalho | Tirar uma área |
| `wallpaper_desbanir` | Papel de parede · «Devolver uma imagem tirada» | Criar tema › Papel de parede | Devolver ao carrossel |
| `wallpaper_semear` | Papel de parede · «Baixar a coleção curada» | Ajustes › Papel de parede › Imagens | Coleção do tema |
| `painel_estado` | Painel e dock · «Como estão o painel e a dock» | Ajustes › Painel e dock › Mais ajustes | Estado atual |
| `painel_teto` | Painel e dock · «Até quanto o canto pode arredondar» | Ajustes › Painel e dock › Mais ajustes | Teto dos cantos |
| `painel_reciclar` | Painel e dock · «Recarregar o painel» | Ajustes › Painel e dock | Recarregar o painel |
| `prompt_instalar_starship` | Terminal · «Instalar o starship» | Ajustes › Terminal › Linha de comando | Starship |
| `leitura` | Modo de leitura · «Modo de leitura agora» | Ajustes › Dia e noite › Mais ajustes | Tela quente agora |
| `leitura_aplicar` | Modo de leitura · «Aplicar o degrau desta hora» | Ajustes › Dia e noite › Tela quente | Esquentar agora |
| `leitura_remover` | Modo de leitura · «Desligar o modo de leitura» | Ajustes › Dia e noite › Tela quente | Desligar agora |
| `files_menu` | Papel de parede · «Menu da área de trabalho» | Ajustes › Papel de parede › Mais ajustes | Menu agora |
| `files_menu_build` | Papel de parede · «Construir o menu da área de trabalho» | Ajustes › Papel de parede › Mais ajustes | Construir o menu |
| `apps` | Lançadores e jogos · «Quais programas estão vestidos» | Ajustes › Programas › Recebem o tema | Conferir |
| `apps_aplicar` | Lançadores e jogos · «Vestir os programas agora» | Ajustes › Programas › Recebem o tema | Vestir agora |
| `apps_tema_do_pack` | Lançadores e jogos · «Trocar pelo tema do pack» | Cuidar › Pendências | Tema de um programa |
| `apps_manter_o_meu` | Lançadores e jogos · «Manter o meu tema» | Cuidar › Pendências | Tema de um programa |
| `vscode_instalar_extensao` | Lançadores e jogos · «Instalar a extensão do VS Code» | Cuidar › Pendências | Extensão do VS Code |
| `spotify_baixar_tema` | Lançadores e jogos · «Baixar o tema do Spotify» | Ajustes › Programas › Lançador | Tema do Spotify |
| `jogos` | Lançadores e jogos · «Ver o que mudaria nos jogos» | Ajustes › Programas › Mais ajustes | Conferir jogos |
| `jogos_aplicar` | Lançadores e jogos · «Arrumar os jogos no lançador» | Ajustes › Programas › Jogos | Arrumar os jogos |
| `jogos_heroic` | Lançadores e jogos · «Ver o que mudaria nos jogos do Heroic» | Ajustes › Programas › Mais ajustes | Conferir Heroic |
| `jogos_heroic_aplicar` | Lançadores e jogos · «Pôr os jogos do Heroic no lançador» | Ajustes › Programas › Jogos | Jogos do Heroic |
| `jogos_heroic_tirar` | Lançadores e jogos · «Tirar o jogo do Heroic do lançador» | Ajustes › Programas › Jogos | Tirar um jogo |
| `jogos_heroic_por` | Lançadores e jogos · «Pôr o jogo do Heroic no lançador» | Ajustes › Programas › Jogos | Pôr um jogo |

## Gestos da página (26)

| rota ou gesto | antes | agora | nome na tela |
|---|---|---|---|
| POST /api/salvar | Topo: Salvar e aplicar | Barra de cima | Aplicar |
| Descartar (só na página) | Topo: Descartar | Barra de cima | Desfazer |
| POST /api/salvar e /api/rodar com seco | Topo e caixa de confirmar: Ver sem mudar | Barra de cima | Ver sem mudar |
| Busca (só na página) | Topo: Buscar um ajuste ou uma ação | Barra de cima | Procurar um ajuste |
| GET /api/exportar/conf | Topo: Exportar › Meus ajustes | Cuidar › Outro computador | Guardar ajustes |
| GET /api/exportar/pagina | Topo: Exportar › Esta tela num arquivo | Barra de cima | Esta tela num arquivo |
| POST /api/importar | Topo: Importar | Cuidar › Outro computador | Trazer ajustes |
| Link do repositório | Menu: Créditos | Barra de cima | Créditos |
| POST /api/pack-importar | Início: Importar um pack | Tema › Temas | Abrir um tema |
| POST /api/pack-importar (CSV) | Início: pack de um .csv | Criar tema › Cores | Guardar o tema |
| GET /api/pack-exportar | Início: Exportar o pack | Criar tema › Mandar | Baixar o tema |
| POST /api/acervo tipo gato | Logo do sistema: Adicionar logo | Ajustes › Mascote › Na dock | Trazer .svg |
| POST /api/acervo tipo parede | Papel de parede: Adicionar imagem | Criar tema › Papel de parede | Trazer imagens |
| POST /api/acervo tipo icone | Ícones: Adicionar ícone | Criar tema › Ícones | Trazer .svg |
| POST /api/acervo tipo cursor | Cor e tela: Adicionar tema de ponteiro | Ajustes › Janelas e tela › Tela | Trazer ponteiro |
| POST /api/acervo tipo fonte | Terminal: Adicionar fonte | Ajustes › Terminal › Mais ajustes | Fonte do terminal |
| POST /api/acervo tipo tema-icones | Ícones: Adicionar tema de ícones | Criar tema › Ícones › Mais ajustes | Tema de ícones |
| POST /api/app-icone | Ícones: Usar este ícone, Levar para o pack, Desfazer | Criar tema › Ícones | Ícone do aplicativo |
| POST /api/app-desenho | Ícones: Gerar ícone (a oficina) | Criar tema › Ícones | Gerar ícone |
| GET /api/glifos | Ícones: Buscar desenho | Criar tema › Ícones | Desenhos do acervo |
| POST /api/autorais | Ícones: Desenhos autorais do pack | Criar tema › Ícones › Mais ajustes | Desenhos autorais |
| POST /api/jogo-fora | Lançadores e jogos: o jogo no lançador | Ajustes › Programas › Jogos | No lançador |
| POST /api/pendencia-recusar | Início: Não, obrigado | Cuidar › Pendências | Não perguntar mais |
| POST /api/parar | Janela do trabalho: Parar | Janela do trabalho | Parar |
| POST /api/guardar-log | Janela do trabalho: Guardar | Janela do trabalho | Guardar |
| Rodar de verdade (depois do ensaio) | Janela do trabalho: Rodar de verdade | Janela do trabalho | Rodar de verdade |

## Conta

- 122 chaves, 67 ações e 26 gestos; 0 linha(s) sem destino.
