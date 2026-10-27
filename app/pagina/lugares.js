"use strict";

const PORTAS = [
  { id: "tema", nome: "Tema", icone: "tema" },
  { id: "criar", nome: "Personalizar", icone: "criar" },
  { id: "ajustes", nome: "Definir", icone: "ajustes" },
  { id: "cuidar", nome: "Manter", icone: "cuidar" },
  { id: "extensoes", nome: "Extensões", icone: "grade" },
];

const LUGAR_TEMA = {
  packs: [
    { c: "PACK", r: "Tema" },
    { c: "FLAVOR", r: "Variante" },
    { a: "pack_usar", r: "Vestir", b: "Vestir" },
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
      { a: "wallpaper_favoritar", r: "Favorita", b: "Favorita" },
      { a: "wallpaper_desfavoritar", r: "Tirar das favoritas", b: "Favorita" },
      { a: "wallpaper_dia", r: "De dia", b: "Dia" },
      { a: "wallpaper_noite", r: "De noite", b: "Noite" },
      { a: "wallpaper_lado_auto", r: "Medir a luz", b: "Medir" },
      { a: "wallpaper_banir", r: "Tirar do carrossel", b: "Tirar" },
      { a: "wallpaper_desbanir", r: "Devolver ao carrossel", b: "Devolver" },
    ] },
  { id: "sons", nome: "Sons",
    linhas: [
      { c: "SOM", r: "Som do volume" },
      { c: "SOM_FUNDAMENTAL", r: "Primeira nota" },
      { c: "SOM_HARMONICO", r: "Segunda nota" },
      { c: "SOM_DECAIMENTO", r: "Duração" },
      { c: "SOM_PESO_FUNDAMENTAL", r: "Peso da primeira" },
      { c: "SOM_PESO_HARMONICO", r: "Peso da segunda" },
      { a: "som_ouvir", r: "Ouvir o instalado", b: "Ouvir" },
      { a: "som_aplicar", r: "Regravar o som", b: "Regravar" },
    ] },
  { id: "mandar", nome: "Mandar",
    linhas: [
      { g: "pack-exportar", r: "Baixar o tema", b: "Baixar o tema" },
      { a: "pack_usar", r: "Vestir", b: "Vestir" },
    ] },
];

const AJUSTES = [
  { id: "painel", nome: "Painel e dock", icone: "painel",
    cabeca: [{ a: "painel_reciclar", r: "Recarregar o painel", b: "Recarregar o painel" }],
    blocos: [
      { titulo: "Forma", colunas: ["Barra de cima", "Dock"], linhas: [
        { c: ["FORMA_PAINEL_SOLTO", "FORMA_DOCK_SOLTO"], r: "Solta da borda" },
        { c: ["FORMA_PAINEL_ILHA", "FORMA_DOCK_ILHA"], r: "Em pastilha" },
        { c: ["FORMA_MARGEM_PAINEL", "FORMA_MARGEM_DOCK"], r: "Distância da borda" },
        { c: ["FORMA_RAIO_PAINEL", "FORMA_RAIO_DOCK"], r: "Cantos" },
        { c: ["FORMA_ESPACO_PAINEL", "FORMA_ESPACO_DOCK"], r: "Espaço entre ícones" },
        { c: ["FORMA_RECHEIO_PAINEL", "FORMA_RECHEIO_DOCK"], r: "Folga interna" },
        { c: ["VIDRO_OPACIDADE_PAINEL", "VIDRO_OPACIDADE_DOCK"], r: "Vidro" },
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
        { a: "painel_teto", r: "Teto dos cantos", b: "Ver" },
      ] },
    ] },
  { id: "janelas", nome: "Janelas e tela", icone: "janelas",
    blocos: [
      { titulo: "Janelas", linhas: [
        { c: "JANELAS_TILING", r: "Lado a lado" },
        { c: "JANELAS_TILING_ESCOPO", r: "Vale para", sub: true },
      ] },
      { titulo: "Tela", linhas: [
        { c: "ESCALA_TELA", r: "Tamanho de tudo" },
        { c: "CURSOR", r: "Ponteiro", larga: true },
        { c: "CURSOR_VERSAO", r: "Versão do ponteiro", sub: true },
        { g: "acervo:cursor", r: "Trazer ponteiro", b: "Trazer .zip" },
      ] },
      { titulo: "Áreas de trabalho", linhas: [
        { c: "AREAS_NOMES", r: "Nomes", larga: true },
        { c: "AREAS_ENCAIXE", r: "Encaixe por área", larga: true },
        { c: "AREAS_FOLGA", r: "Folga no nome" },
        { a: "areas_aplicar", r: "Gravar as áreas", b: "Gravar" },
        { a: "areas_alfinetar_primeira", r: "Primeira área", b: "Criar" },
        { a: "areas_desalfinetar", r: "Tirar uma área", b: "Tirar" },
        { a: "areas_reverter", r: "Áreas de antes", b: "Voltar" },
        { a: "areas_ver", r: "Áreas agora", b: "Ver" },
      ] },
    ] },
  { id: "papel", nome: "Papel de parede", icone: "imagem",
    cabeca: [{ a: "wallpaper_proximo", r: "Próxima imagem", b: "Próxima imagem" }],
    blocos: [
      { titulo: "Imagens", linhas: [
        { a: "wallpaper_anterior", r: "Imagem anterior", b: "Anterior" },
        { a: "wallpaper_carrossel", r: "Voltar a girar", b: "Girar" },
        { a: "wallpaper", r: "Carrossel agora", b: "Ver" },
        { a: "wallpaper_aplicar", r: "Regras do carrossel", b: "Reaplicar" },
      ] },
      { titulo: "Troca", linhas: [
        { c: "WALLPAPER_INTERVALO", r: "A cada" },
        { c: "WALLPAPER_ORDEM", r: "Ordem" },
        { c: "WALLPAPER_AJUSTE", r: "Encaixe" },
        { c: "WALLPAPER_NOTIFICAR", r: "Avisar a troca" },
        { c: "WALLPAPER_FIXO_TTL", r: "Escolhida dura" },
        { c: "FILES_MENU", r: "Botão direito" },
        { c: "FILES_MENU_AUTOBUILD", r: "Menu se reconstrói", sub: true },
        { a: "files_menu", r: "Menu agora", b: "Ver" },
      ] },
      { titulo: "Pastas", linhas: [
        { c: "WALLPAPER_BASE", r: "Pasta do carrossel" },
        { c: "WALLPAPER_FONTES_PERMITIDAS", r: "Pastas suas" },
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
        { c: "LOGO_INTERVALO", r: "Gira a cada", sub: true },
        { c: "LOGO_ROTACAO", r: "Girar sozinho", sub: true },
        { a: "logo_trocar", r: "Pôr agora", b: "Pôr" },
        { c: "LOGO_RECICLAR", r: "Recarregar na virada", sub: true },
        { a: "logo_girar", r: "Próximo mascote", b: "Girar" },
        { a: "logo_listar", r: "Mascote agora", b: "Ver" },
      ] },
      { titulo: "No terminal", linhas: [
        { c: "FASTFETCH_LOGO", r: "Ao abrir" },
        { c: "FASTFETCH_LOGO_MODO", r: "Qual", sub: true },
        { c: "FASTFETCH_LOGO_GATO", r: "Fixo", sub: true },
        { c: "FASTFETCH_LOGO_DIA", r: "De dia", sub: true },
        { c: "FASTFETCH_LOGO_NOITE", r: "De noite", sub: true },
        { c: "FASTFETCH_LOGO_COLUNAS", r: "Tamanho", sub: true },
        { c: "FASTFETCH_LOGO_LINHAS", r: "Altura do desenho", sub: true },
        { c: "FASTFETCH_LOGO_QUEBRAS", r: "Linhas antes", sub: true },
        { c: "FASTFETCH_LOGO_ALINHAR", r: "Texto ao lado", sub: true },
        { c: "FASTFETCH_TITULO", r: "Linha de cima", sub: true },
        { c: "FASTFETCH_LOGO_RECUO", r: "Espaço ao lado", sub: true },
        { c: "FASTFETCH_LOGO_CELULA", r: "Proporção da letra", sub: true },
        { c: "FASTFETCH_LOGO_BLOCOS", r: "Detalhe", sub: true },
        { c: "FASTFETCH_LOGO_CONF", r: "Corrigir o Fastfetch", sub: true },
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
        { c: "LEITURA_TEMPERATURA", r: "Quão quente", sub: true },
        { c: "LEITURA_TEXTURA", r: "Textura de papel", sub: true },
        { c: "LEITURA_RAMPA_MIN", r: "Entrar devagar", sub: true },
        { c: "LEITURA_HORARIO_INICIO", r: "Começa", sub: true },
        { c: "LEITURA_HORARIO_FIM", r: "Termina", sub: true },
        { c: "LEITURA_APPLET", r: "Botão na barra" },
        { a: "leitura_aplicar", r: "Esquentar agora", b: "Aplicar" },
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
  { id: "programas", nome: "Programas", icone: "grade",
    blocos: [
      { titulo: "Recebem o tema", programas: true, linhas: [
        { c: "APPS_ATIVOS", r: "Programas" },
        { a: "apps_aplicar", r: "Vestir agora", b: "Vestir" },
        { a: "apps", r: "Conferir", b: "Conferir" },
      ] },
      { titulo: "Lançador", linhas: [
        { c: "LANCADOR_SISTEMA", r: "Arrumar o lançador" },
        { c: "LANCADOR_OCULTAR", r: "Escondidos", larga: true },
        { c: "SPOTIFY_MARKETPLACE", r: "Loja do Spotify" },
      ] },
      { titulo: "Jogos", jogos: true, linhas: [
        { e: "jogos", r: "Jogos" },
        { g: "jogo-fora", r: "No lançador" },
        { a: "jogos_aplicar", r: "Arrumar os jogos", b: "Arrumar" },
        { a: "jogos_heroic_aplicar", r: "Jogos do Heroic", b: "Pôr" },
        { a: "jogos_heroic_por", r: "Pôr um jogo", b: "Pôr" },
        { a: "jogos_heroic_tirar", r: "Tirar um jogo", b: "Tirar" },
        { a: "jogos", r: "Conferir jogos", b: "Ver" },
        { a: "jogos_heroic", r: "Conferir Heroic", b: "Ver" },
      ] },
      { titulo: "Ao ligar", linhas: [
        { c: "AUTOSTART_BLOQUEADOS", r: "Não abrem sozinhos", larga: true },
      ] },
    ] },
];

const LUGAR_CUIDAR = {
  estado: [
    { a: "doctor_consertar", r: "Consertar a ponte", b: "Consertar a ponte" },
    { a: "doctor", r: "Conferir", b: "Conferir" },
  ],
  pendencias: [
    { g: "pendencia-recusar", r: "Não perguntar mais", b: "Não, obrigado" },
    { a: "wallpaper_permitir", r: "Imagem que você pôs", b: "Manter" },
    { a: "wallpaper_dispensar", r: "Imagem que você pôs", b: "Deixar assim" },
    { a: "apps_tema_do_pack", r: "Tema de um programa", b: "Trocar" },
    { a: "apps_manter_o_meu", r: "Tema de um programa", b: "Manter" },
    { a: "vscode_instalar_extensao", r: "Extensão do VS Code", b: "Instalar" },
    { a: "extensao_refazer", r: "Build da casa", b: "Refazer" },
  ],
  cartoes: [
    { id: "outro", titulo: "Outro computador", icone: "computador", linhas: [
      { g: "exportar-conf", r: "Guardar ajustes", b: "Guardar ajustes" },
      { g: "importar", r: "Trazer ajustes", b: "Trazer ajustes" },
    ] },
    { id: "atualizar", titulo: "Atualizar", icone: "girar", linhas: [
      { a: "sistema_atualizar", r: "Atualizar a máquina", b: "Atualizar" },
      { a: "sistema_ver", r: "O que muda", b: "Ver" },
      { a: "sistema_limpar", r: "Limpar", b: "Limpar" },
    ] },
    { id: "instalar", titulo: "Instalar de novo", icone: "baixar", linhas: [
      { a: "instalar", r: "Instalar tudo", b: "Instalar" },
    ] },
  ],
  blocos: [
    { titulo: "Sozinho", linhas: [
      { c: "AUTO_REPARO", r: "Conferir todo dia" },
      { c: "AUTO_REPARO_NOTIFICAR", r: "Avisar o conserto", sub: true },
      { c: "VIZINHOS_DESATIVAR", r: "Desligar o repetido nos vizinhos", sub: true },
      { c: "ASSETS_VIGIA", r: "Mascote novo entra" },
      { c: "ASSETS_VIGIA_NOTIFICAR", r: "Avisar o mascote", sub: true },
      { c: "FLATPAK_VIGIA", r: "Ícones após atualizar" },
      { c: "FLATPAK_VIGIA_NOTIFICAR", r: "Avisar os ícones", sub: true },
      { c: "STEAM_VIGIA", r: "Jogo desinstalado sai" },
      { c: "HEROIC_VIGIA", r: "Jogo do Heroic" },
      { c: "PONTE_ROOT", r: "Consertos de sistema" },
    ] },
    { titulo: "Registro", linhas: [
      { c: "LOG_NIVEL", r: "Quanto fala" },
      { c: "BACKUPS_MANTIDOS", r: "Cópias guardadas" },
      { a: "log", r: "Registro", b: "Ver" },
    ] },
  ],
  maquina: [
    { c: "NOME_TEMA_ICONES", r: "Nome do tema" },
    { a: "icones", r: "Tema instalado", b: "Ver" },
    { c: "ICONES_DRACULA", r: "Desenhos" },
    { a: "icones_traco", r: "Desenhos em traço", b: "Aplicar" },
    { a: "icones_pack", r: "Desenhos do pack", b: "Aplicar" },
    { c: "ICONES_LOGO_HEFESTO", r: "Logo do Hefesto" },
    { c: "ICONES_RESGATADOS", r: "Ícones resgatados" },
    { g: "acervo:tema-icones", r: "Tema de ícones", b: "Trazer .zip" },
    { a: "icones_reconstruir", r: "Reconstruir os ícones", b: "Reconstruir" },
  ],
  perigo: [
    { a: "restaurar", r: "Restaurar", b: "Restaurar" },
    { a: "desfazer", r: "Tema de antes", b: "Voltar" },
    { a: "desinstalar", r: "Desinstalar", b: "Desinstalar" },
  ],
};

const LUGAR_EXTENSOES = {
  applets: [
    { a: "extensao_instalar", r: "Instalar" },
    { a: "extensao_instalar_repo", r: "Instalar do repositório" },
    { a: "extensao_atualizar", r: "Atualizar" },
    { a: "extensao_atualizar_repo", r: "Atualizar do repositório" },
    { a: "extensao_refazer", r: "Tentar de novo" },
    { a: "extensao_remover", r: "Remover" },
    { a: "extensao_por_no_painel", r: "Pôr no painel" },
    { a: "extensao_trocar", r: "Trocar" },
    { a: "extensao_reiniciar_painel", r: "Reiniciar o painel" },
    { c: "EXTENSOES", r: "Extensões instaladas" },
  ],
  builds: [
    { a: "builds_refazer_tudo", r: "Refazer tudo" },
    { c: "BUILDS_AO_ENTRAR", r: "Refazer ao entrar na sessão" },
    { c: "COMPOSITOR", r: "Compositor" },
  ],
};

const LUGAR_TOPO = [
  { g: "descartar", r: "Desfazer" },
  { g: "busca", r: "Procurar um ajuste" },
  { g: "creditos", r: "Créditos" },
  { g: "exportar-pagina", r: "Esta tela num arquivo" },
];
const LUGAR_JANELA = [
  { g: "parar", r: "Parar" },
  { g: "guardar-log", r: "Guardar" },
  { g: "ensaio-rodar", r: "Rodar de verdade" },
];

function inventarioDoPainel() {
  const saida = [];
  const pus = (l, porta, pagina, bloco) => {
    const base = { porta, pagina, bloco, rotulo: l.r };
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
  for (const l of LUGAR_CUIDAR.estado) pus(l, "cuidar", "Manter", "Estado");
  for (const l of LUGAR_CUIDAR.pendencias) pus(l, "cuidar", "Manter", "Pendências");
  for (const c of LUGAR_CUIDAR.cartoes) for (const l of c.linhas) pus(l, "cuidar", "Manter", c.titulo);
  for (const b of LUGAR_CUIDAR.blocos) for (const l of b.linhas) pus(l, "cuidar", "Manter", b.titulo);
  for (const l of LUGAR_CUIDAR.maquina) pus(l, "cuidar", "Manter", "Ícones da máquina");
  for (const l of LUGAR_CUIDAR.perigo) pus(l, "cuidar", "Manter", "Zona de perigo");
  for (const l of LUGAR_EXTENSOES.applets) pus(l, "extensoes", "Applets", "Applets");
  for (const l of LUGAR_EXTENSOES.builds) pus(l, "extensoes", "Builds", "Builds");
  for (const l of LUGAR_TOPO) pus(l, "topo", "Barra de cima", "Barra de cima");
  for (const l of LUGAR_JANELA) pus(l, "janela", "Janela do trabalho", "Janela do trabalho");
  return saida;
}

if (typeof module !== "undefined") {
  module.exports = { PORTAS, LUGAR_TEMA, PASSOS, AJUSTES, LUGAR_CUIDAR, LUGAR_EXTENSOES, LUGAR_TOPO, LUGAR_JANELA, inventarioDoPainel };
}
