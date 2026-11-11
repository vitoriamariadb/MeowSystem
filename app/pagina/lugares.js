"use strict";

const PORTAS = [
  { id: "tema", nome: "Tema", icone: "tema" },
  { id: "criar", nome: "Personalizar", icone: "criar" },
  { id: "ajustes", nome: "Ajustes", icone: "ajustes" },
  { id: "cuidar", nome: "Manutenção", icone: "cuidar" },
  { id: "extensoes", nome: "Extensões", icone: "grade" },
  { id: "modificacoes", nome: "Modificações", icone: "pincel" },
];

const LUGAR_TEMA = {
  packs: [
    { c: "PACK", r: "Tema" },
    { c: "FLAVOR", r: "Variante" },
    { a: "pack_usar", r: "Aplicar tema", b: "Aplicar tema" },
    { a: "pack_remover", r: "Remover", b: "Remover" },
    { g: "pack-importar", r: "Abrir um tema", b: "Abrir um tema" },
  ],
  blocos: [
    { titulo: "Cor de destaque", linhas: [{ c: "ACCENT", r: "Cor de destaque" }] },
    { titulo: "Claro ou escuro", linhas: [{ c: "MODO", r: "Claro ou escuro" }] },
  ],
};

const PASSOS = [
  { id: "cores", nome: "Cores",
    linhas: [{ g: "tema-criar", r: "Guardar o tema", b: "Guardar" }] },
  { id: "icones", nome: "Ícones",
    linhas: [
      { e: "apps", r: "Aplicativos" },
      { g: "app-icone", r: "Ícone do aplicativo", b: "Usar" },
      { g: "app-desenho", r: "Gerar ícone", b: "Usar" },
      { g: "glifos", r: "Desenhos do acervo" },
      { g: "acervo:icone", r: "Trazer .svg", b: "Trazer .svg" },
      { c: "ICONES_PASTAS", r: "Cor das pastas", bloco: "Pastas" },
      { c: "PASTAS_XDG", r: "Pastas especiais", bloco: "Pastas" },
      { c: "ICONES_FLAVOR", r: "Variante dos ícones", bloco: "Cores" },
      { c: "ICONES_COR_MARCA", r: "Cor da marca", bloco: "Cores" },
      { e: "autorais", r: "Desenhos do pack", bloco: "Desenhos do tema" },
      { g: "autorais", r: "Desenhos autorais", b: "Salvar", bloco: "Desenhos do tema" },
    ] },
  { id: "papel", nome: "Papel de parede",
    linhas: [
      { e: "galeria", r: "Imagens" },
      { g: "acervo:parede", r: "Trazer imagens", b: "Trazer imagens" },
      { a: "wallpaper_usar", r: "Usar agora", b: "Usar" },
      { a: "wallpaper_dia", r: "De dia", b: "Dia" },
      { a: "wallpaper_noite", r: "De noite", b: "Noite" },
      { a: "wallpaper_lado_auto", r: "Separar tons de cores", b: "Separar tons de cores" },
      { a: "wallpaper_banir", r: "Apagar", b: "Apagar" },
    ] },
  { id: "sons", nome: "Sons",
    linhas: [
      { c: "SOM", r: "Som do volume" },
      { c: "SOM_FUNDAMENTAL", r: "Primeira nota" },
      { c: "SOM_HARMONICO", r: "Segunda nota" },
      { c: "SOM_DECAIMENTO", r: "Duração do som" },
      { c: "SOM_PESO_FUNDAMENTAL", r: "Volume da nota 1" },
      { c: "SOM_PESO_HARMONICO", r: "Volume da nota 2" },
    ] },
  { id: "mandar", nome: "Usar e compartilhar",
    linhas: [
      { g: "pack-exportar", r: "Baixar o tema", b: "Baixar o tema" },
      { a: "pack_usar", r: "Aplicar tema", b: "Aplicar tema" },
    ] },
];

const AJUSTES = [
  { id: "painel", nome: "Barra e dock", icone: "painel",
    cabeca: [{ a: "painel_reciclar", r: "Reiniciar a barra", b: "Reiniciar a barra" }],
    blocos: [
      { titulo: "Forma", colunas: ["Barra de cima", "Dock"], linhas: [
        { c: ["FORMA_PAINEL_SOLTO", "FORMA_DOCK_SOLTO"], r: "Flutuante" },
        { c: ["FORMA_PAINEL_ILHA", "FORMA_DOCK_ILHA"], r: "Formato pílula" },
        { c: ["FORMA_MARGEM_PAINEL", "FORMA_MARGEM_DOCK"], r: "Distância da borda" },
        { c: ["FORMA_RAIO_PAINEL", "FORMA_RAIO_DOCK"], r: "Cantos" },
        { c: ["FORMA_ESPACO_PAINEL", "FORMA_ESPACO_DOCK"], r: "Espaço entre ícones" },
        { c: ["FORMA_RECHEIO_PAINEL", "FORMA_RECHEIO_DOCK"], r: "Margem interna" },
        { c: ["VIDRO_OPACIDADE_PAINEL", "VIDRO_OPACIDADE_DOCK"], r: "Transparência" },
      ] },
      { titulo: "Tamanho dos ícones", colunas: ["Barra de cima", "Dock"], linhas: [
        { c: ["FORMA_ALA_INICIAL_PAINEL", "FORMA_ALA_INICIAL_DOCK"], r: "Ponta esquerda" },
        { c: ["FORMA_CENTRO_PAINEL", "FORMA_CENTRO_DOCK"], r: "Meio" },
        { c: ["FORMA_ALA_FINAL_PAINEL", "FORMA_ALA_FINAL_DOCK"], r: "Ponta direita" },
      ] },
      { titulo: "Barra de cima", linhas: [
        { c: "RELOGIO_SEGUNDOS", r: "Segundos no relógio" },
        { c: "VIDRO_AO_MAXIMIZAR", r: "Vidro ao maximizar" },
        { c: "MIDIA", r: "Música tocando" },
        { c: "MIDIA_COR_TITULO", r: "Cor da música", sub: true },
        { c: "MIDIA_COR_ARTISTA", r: "Cor da banda", sub: true },
        { c: "MIDIA_CAPA", r: "Capa do disco", sub: true },
        { c: "MIDIA_CONTROLES", r: "Tocar e pular", sub: true },
        { c: "MIDIA_LARGURA", r: "Largura da música", sub: true },
        { c: "MIDIA_FONTE", r: "Letra da música", sub: true },
        { c: "MIDIA_COR_ALBUM", r: "Cor da capa", sub: true },
      ] },
      { titulo: "Conferir", linhas: [
        { a: "painel_estado", r: "Estado atual", b: "Ver" },
        { a: "painel_teto", r: "Arredondamento máximo", b: "Ver" },
      ] },
    ] },
  { id: "janelas", nome: "Janelas e tela", icone: "janelas",
    blocos: [
      { titulo: "Janelas", linhas: [
        { c: "JANELAS_TILING", r: "Lado a lado" },
        { c: "JANELAS_TILING_ESCOPO", r: "Vale para", sub: true },
      ] },
      { titulo: "Tela", linhas: [
        { c: "ESCALA_TELA", r: "Escala da tela" },
        { c: "GPU_COMPOSITOR", r: "GPU do compositor" },
        { c: "CURSOR", r: "Ponteiro", larga: true },
        { c: "CURSOR_VERSAO", r: "Versão do ponteiro", sub: true },
        { g: "acervo:cursor", r: "Trazer ponteiro", b: "Trazer .zip" },
      ] },
      { titulo: "Áreas de trabalho", linhas: [
        { c: "AREAS_MODO", r: "Layout da tela" },
        { c: "AREAS_NOMES", r: "Nomes", larga: true },
        { c: "AREAS_ENCAIXE", r: "Lado a lado por área", larga: true },
        { c: "AREAS_FOLGA", r: "Espaço em volta do nome" },
        { a: "areas_aplicar", r: "Salvar as áreas", b: "Salvar" },
        { a: "areas_alfinetar_primeira", r: "Fixar a primeira área", b: "Fixar" },
        { a: "areas_desalfinetar", r: "Remover uma área", b: "Remover" },
        { a: "areas_reverter", r: "Desfazer as áreas", b: "Desfazer" },
        { a: "areas_ver", r: "Áreas agora", b: "Ver" },
      ] },
    ] },
  { id: "papel", nome: "Papel de parede", icone: "imagem",
    cabeca: [{ a: "wallpaper_proximo", r: "Próxima imagem", b: "Próxima imagem" }],
    blocos: [
      { titulo: "Imagens", linhas: [
        { a: "wallpaper_anterior", r: "Imagem anterior", b: "Anterior" },
        { a: "wallpaper_carrossel", r: "Girar", b: "Girar" },
        { a: "wallpaper", r: "Carrossel de Imagens", b: "Ver" },
        { a: "wallpaper_aplicar", r: "Regras do carrossel", b: "Reaplicar" },
      ] },
      { titulo: "Troca", linhas: [
        { c: "WALLPAPER_INTERVALO", r: "A cada" },
        { c: "WALLPAPER_ORDEM", r: "Ordem" },
        { c: "WALLPAPER_AJUSTE", r: "Ajuste da imagem" },
        { c: "WALLPAPER_NOTIFICAR", r: "Avisar a troca" },
        { c: "WALLPAPER_FIXO_TTL", r: "Escolhida dura" },
        { c: "FILES_MENU", r: "Menu do Arquivos" },
        { c: "FILES_MENU_AUTOBUILD", r: "Recompilar automaticamente", sub: true },
        { a: "files_menu", r: "Menu agora", b: "Ver" },
      ] },
      { titulo: "Pastas", linhas: [
        { c: "WALLPAPER_BASE", r: "Pasta do carrossel" },
        { c: "WALLPAPER_FONTES_PERMITIDAS", r: "Seus papéis de parede" },
        { c: "WALLPAPER_DRACULA_REPO", r: "Acervo do Dracula" },
        { c: "WALLPAPER_DRACULA_COMMIT", r: "Versão do acervo", sub: true },
      ] },
    ] },
  { id: "mascote", nome: "Mascote", icone: "gato",
    blocos: [
      { titulo: "Na dock", linhas: [
        { c: "LOGO", r: "Mascote", larga: true },
        { g: "acervo:gato", r: "Trazer .svg", b: "Trazer .svg" },
        { c: "LOGO_MODO", r: "Como escolhe" },
        { c: "LOGO_DIA", r: "De dia", sub: true },
        { c: "LOGO_NOITE", r: "De noite", sub: true },
        { c: "LOGO_INTERVALO", r: "Troca a cada", sub: true },
        { c: "LOGO_ROTACAO", r: "Trocar sozinho", sub: true },
        { a: "logo_trocar", r: "", n: "Aplicar o mascote", b: "Aplicar" },
        { c: "LOGO_RECICLAR", r: "Trocar na virada do dia", sub: true },
        { a: "logo_girar", r: "Próximo mascote", b: "Girar" },
        { a: "logo_listar", r: "Mascote agora", b: "Ver" },
      ] },
      { titulo: "No terminal", linhas: [
        { c: "FASTFETCH_LOGO", r: "Ao abrir" },
        { c: "FASTFETCH_LOGO_MODO", r: "Qual mascote", sub: true },
        { c: "FASTFETCH_LOGO_GATO", r: "Fixo", sub: true },
        { c: "FASTFETCH_LOGO_DIA", r: "De dia", sub: true },
        { c: "FASTFETCH_LOGO_NOITE", r: "De noite", sub: true },
        { c: "FASTFETCH_LOGO_COLUNAS", r: "Tamanho", sub: true },
        { c: "FASTFETCH_LOGO_LINHAS", r: "Altura do desenho", sub: true },
        { c: "FASTFETCH_LOGO_QUEBRAS", r: "Linhas em branco acima", sub: true },
        { c: "FASTFETCH_LOGO_ALINHAR", r: "Texto ao lado", sub: true },
        { c: "FASTFETCH_TITULO", r: "Título", sub: true },
        { c: "FASTFETCH_LOGO_RECUO", r: "Recuo do texto", sub: true },
        { c: "FASTFETCH_LOGO_CELULA", r: "Proporção da letra", sub: true },
        { c: "FASTFETCH_LOGO_BLOCOS", r: "Nível de detalhe", sub: true },
        { c: "FASTFETCH_LOGO_CONF", r: "Consertar o Fastfetch", sub: true },
      ] },
      { titulo: "No programa", linhas: [
        { c: "LOGO_PROGRAMA", r: "Logo do programa", larga: true },
      ] },
    ] },
  { id: "dia-e-noite", nome: "Dia e noite", icone: "lua",
    blocos: [
      { titulo: "Noite", noite: true, linhas: [
        { c: "NOITE_INICIO", r: "Começa" },
        { c: "NOITE_FIM", r: "Termina" },
      ] },
      { titulo: "Claro e escuro", linhas: [
        { c: "MODO_AUTO_CLARO_ATE", r: "Escuro começa" },
        { c: "MODO_AUTO_CLARO_DE", r: "Escuro termina" },
      ] },
      { titulo: "Modo de leitura", leitura: true, linhas: [
        { c: "LEITURA_AGENDA", r: "Ligar no horário" },
        { c: "LEITURA_TEMPERATURA", r: "Temperatura da cor", sub: true },
        { c: "LEITURA_TEXTURA", r: "Textura de papel", sub: true },
        { c: "LEITURA_RAMPA_MIN", r: "Transição gradual", sub: true },
        { c: "LEITURA_HORARIO_INICIO", r: "Começa", sub: true },
        { c: "LEITURA_HORARIO_FIM", r: "Termina", sub: true },
        { c: "LEITURA_APPLET", r: "Botão na barra" },
        { a: "leitura_aplicar", r: "Ligar o modo de leitura agora", b: "Aplicar" },
        { a: "leitura_remover", r: "Desligar agora", b: "Desligar" },
        { a: "leitura", r: "Leitura agora", b: "Ver" },
      ] },
      { titulo: "Papel da noite", linhas: [
        { c: "WALLPAPER_NOITE", r: "Imagens escuras" },
        { c: "WALLPAPER_LIMIAR_LUZ", r: "Quão escura", sub: true },
        { c: "WALLPAPER_NOITE_INICIO", r: "Começa", sub: true },
        { c: "WALLPAPER_NOITE_FIM", r: "Termina", sub: true },
      ] },
    ] },
  { id: "programas", nome: "Programas", icone: "grade",
    blocos: [
      { titulo: "Lançador", linhas: [
        { c: "LANCADOR_SISTEMA", r: "Organizar o lançador" },
        { c: "LANCADOR_OCULTAR", r: "Apps escondidos", larga: true },
      ] },
      { titulo: "Jogos", jogos: true, linhas: [
        { e: "jogos", r: "Jogos" },
        { g: "jogo-fora", r: "No lançador" },
        { a: "jogos_aplicar", r: "Organizar os jogos", b: "Organizar" },
        { a: "jogos_heroic_aplicar", r: "Jogos do Heroic", b: "Aplicar" },
        { a: "jogos_heroic_por", r: "Adicionar jogo", b: "Adicionar jogo" },
        { a: "jogos_heroic_tirar", r: "Remover jogo", b: "Remover jogo" },
        { a: "jogos", r: "Conferir jogos", b: "Ver" },
        { a: "jogos_heroic", r: "Conferir Heroic", b: "Ver" },
      ] },
      { titulo: "Ao iniciar", linhas: [
        { c: "AUTOSTART_BLOQUEADOS", r: "Bloquear ao iniciar", larga: true },
      ] },
    ] },
];

const LUGAR_CUIDAR = {
  estado: [
    { a: "doctor_consertar", r: "Reativar permissão de sistema", b: "Reativar permissão de sistema" },
    { a: "doctor", r: "Verificar o sistema", b: "Verificar o sistema" },
  ],
  cartoes: [
    { id: "outro", titulo: "Exportar", icone: "computador", linhas: [
      { g: "exportar-conf", r: "Exportar ajustes", b: "Exportar ajustes" },
      { g: "importar", r: "Importar ajustes", b: "Importar ajustes" },
    ] },
    { id: "atualizar", titulo: "Atualizar", icone: "girar", linhas: [
      { a: "sistema_atualizar", r: "Atualizar a máquina", b: "Atualizar" },
      { a: "sistema_ver", r: "O que muda", b: "Ver" },
      { a: "sistema_limpar", r: "Limpar", b: "Limpar" },
    ] },
    { id: "instalar", titulo: "Reinstalar o MeowSystem", icone: "baixar", linhas: [
      { a: "instalar", r: "Reinstalar o MeowSystem", b: "Reinstalar" },
    ] },
  ],
  blocos: [
    { titulo: "Manutenção automática", linhas: [
      { c: "AUTO_REPARO", r: "Rotina" },
      { c: "AUTO_REPARO_NOTIFICAR", r: "Avisar quando consertar", sub: true },
      { c: "VIZINHOS_DESATIVAR", r: "Desligar o que conflita", sub: true },
      { c: "ASSETS_VIGIA", r: "Mascote novo entra" },
      { c: "ASSETS_VIGIA_NOTIFICAR", r: "Avisar o mascote", sub: true },
      { c: "FLATPAK_VIGIA", r: "Refazer ícones após atualizar" },
      { c: "FLATPAK_VIGIA_NOTIFICAR", r: "Avisar os ícones", sub: true },
      { c: "STEAM_VIGIA", r: "Remover jogos desinstalados" },
      { c: "HEROIC_VIGIA", r: "Jogo do Heroic" },
      { c: "PONTE_ROOT", r: "Permissão de sistema" },
      { c: "BACKUPS_MANTIDOS", r: "Backups guardados" },
    ] },
  ],
  maquina: [
    { c: "NOME_TEMA_ICONES", r: "Nome do tema" },
    { a: "icones", r: "Tema instalado", b: "Ver" },
    { c: "ICONES_DRACULA", r: "Ícones do tema" },
    { a: "icones_traco", r: "Ícones em traço", b: "Aplicar" },
    { a: "icones_pack", r: "Desenhos do pack", b: "Aplicar" },
    { c: "ICONES_LOGO_HEFESTO", r: "Logo do Hefesto" },
    { c: "ICONES_RESGATADOS", r: "Ícones resgatados" },
    { g: "acervo:tema-icones", r: "Tema de ícones", b: "Trazer .zip" },
    { a: "icones_reconstruir", r: "Refazer os ícones", b: "Refazer" },
  ],
  perigo: [
    { a: "restaurar", r: "Restaurar", b: "Restaurar" },
    { a: "desfazer", r: "Voltar ao tema original", b: "Voltar ao tema original" },
    { a: "desinstalar", r: "Desinstalar", b: "Desinstalar" },
    { a: "desinstalar_guardando", r: "Desinstalar mantendo os backups", b: "Desinstalar" },
  ],
};

const LUGAR_EXTENSOES = {
  applets: [
    { a: "extensao_instalar", r: "Instalar" },
    { a: "extensao_instalar_repo", r: "Instalar do repositório" },
    { a: "extensao_atualizar", r: "Atualizar" },
    { a: "extensao_atualizar_repo", r: "Atualizar do repositório" },
    { a: "extensao_refazer", r: "Recompilar" },
    { a: "extensao_remover", r: "Remover" },
    { a: "extensao_por_no_painel", r: "Adicionar à barra" },
    { a: "extensao_trocar", r: "Trocar" },
    { a: "extensao_reiniciar_painel", r: "Reiniciar a barra" },
    { c: "EXTENSOES", r: "Extensões instaladas" },
  ],
  builds: [
    { a: "builds_refazer_tudo", r: "Recompilar tudo" },
    { c: "BUILDS_AO_ENTRAR", r: "Recompilar ao entrar" },
    { c: "COMPOSITOR", r: "Compositor" },
    { c: "GRAFICOS", r: "Compartilhar tela" },
  ],
  espaco: [
    { a: "espaco_liberar", r: "Apagar arquivos recriáveis" },
  ],
};

const LUGAR_MODIFICACOES = {
  cabeca: [
    { a: "apps", r: "Conferir", b: "Conferir" },
    { a: "apps_aplicar", r: "Aplicar em todos", b: "Aplicar em todos" },
  ],
  cartao: [
    { c: "APPS_ATIVOS", r: "Tema" },
    { a: "modificacao_aplicar", r: "Aplicar" },
    { a: "modificacao_reverter", r: "Remover o tema" },
    { a: "modificacao_corrigir", r: "Aplicar a correção" },
    { c: "FLATPAK_CORRECOES", r: "Correções do Flatpak" },
    { a: "vscode_instalar_extensao", r: "Extensão do pack", b: "Instalar" },
    { a: "spicetify_instalar", r: "Tema no Spotify", b: "Baixar o spicetify" },
  ],
  chaves: [
    { c: "SPOTIFY_MARKETPLACE", r: "Loja do Spotify", cartao: "spotify", bloco: "Spotify" },
    { c: "DISCORD_VENCORD", r: "Vencord no Discord", cartao: "discord", bloco: "Discord" },
  ],
  detalhes: [
    { id: "terminal", nome: "Terminal", icone: "terminal",
      blocos: [
        { titulo: "Cores", linhas: [
          { c: "TERMINAL_ESQUEMA", r: "Cores do tema" },
          { c: "TERMINAL_CURSOR", r: "Cor do cursor" },
        ] },
        { titulo: "Linha de comando", linhas: [
          { c: "PROMPT_STARSHIP", r: "Linha colorida" },
        ] },
        { titulo: "Fonte", linhas: [
          { g: "acervo:fonte", r: "Fonte do terminal", b: "Trazer fonte" },
        ] },
      ] },
  ],
};

const LUGAR_TOPO = [
  { g: "descartar", r: "Desfazer" },
  { g: "busca", r: "Buscar" },
  { g: "reiniciar-barra", r: "Reiniciar a barra" },
  { g: "parar", r: "Parar" },
];

function inventarioDoPainel() {
  const saida = [];
  const pus = (l, porta, pagina, bloco) => {
    const base = { porta, pagina, bloco, rotulo: l.r || l.n };
    if (l.c) for (const c of [].concat(l.c)) saida.push({ ...base, tipo: "chave", id: c });
    else if (l.a) saida.push({ ...base, tipo: "acao", id: l.a });
    else if (l.g) saida.push({ ...base, tipo: "gesto", id: l.g });
  };
  for (const l of LUGAR_TEMA.packs) pus(l, "tema", "Tema", "Temas");
  for (const b of LUGAR_TEMA.blocos) for (const l of b.linhas) pus(l, "tema", "Tema", b.titulo);
  for (const p of PASSOS) {
    for (const l of p.linhas) pus(l, "criar", p.nome, l.bloco || p.nome);
  }
  for (const p of AJUSTES) {
    for (const l of p.cabeca || []) pus(l, "ajustes", p.nome, p.nome);
    for (const b of p.blocos) for (const l of b.linhas) pus(l, "ajustes", p.nome, b.titulo);
  }
  for (const l of LUGAR_CUIDAR.estado) pus(l, "cuidar", "Manutenção", "Estado");
  for (const c of LUGAR_CUIDAR.cartoes) for (const l of c.linhas) pus(l, "cuidar", "Manutenção", c.titulo);
  for (const b of LUGAR_CUIDAR.blocos) for (const l of b.linhas) pus(l, "cuidar", "Manutenção", b.titulo);
  for (const l of LUGAR_CUIDAR.maquina) pus(l, "cuidar", "Manutenção", "Ícones da máquina");
  for (const l of LUGAR_CUIDAR.perigo) pus(l, "cuidar", "Manutenção", "Zona de perigo");
  for (const l of LUGAR_EXTENSOES.applets) pus(l, "extensoes", "Applets", "Applets");
  for (const l of LUGAR_EXTENSOES.builds) pus(l, "extensoes", "Builds", "Builds");
  for (const l of LUGAR_EXTENSOES.espaco) pus(l, "extensoes", "Espaço", "Espaço");
  for (const l of LUGAR_MODIFICACOES.cabeca) pus(l, "modificacoes", "", "");
  for (const l of LUGAR_MODIFICACOES.cartao) pus(l, "modificacoes", "", "");
  for (const l of LUGAR_MODIFICACOES.chaves) pus(l, "modificacoes", "", l.bloco);
  for (const d of LUGAR_MODIFICACOES.detalhes) for (const b of d.blocos) for (const l of b.linhas) pus(l, "modificacoes", d.nome, b.titulo);
  for (const l of LUGAR_TOPO) pus(l, "topo", "Barra de cima", "Barra de cima");
  return saida;
}

if (typeof module !== "undefined") {
  module.exports = { PORTAS, LUGAR_TEMA, PASSOS, AJUSTES, LUGAR_CUIDAR, LUGAR_EXTENSOES, LUGAR_MODIFICACOES, LUGAR_TOPO, inventarioDoPainel };
}
