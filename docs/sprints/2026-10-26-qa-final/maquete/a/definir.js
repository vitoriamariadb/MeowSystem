const TAMANHO = { XS: 2.6, S: 3.05, M: 3.5, L: 3.95, XL: 4.4 };
const PX = 0.12;
const PADRAO = {
  FORMA_DOCK_SOLTO: "sim", FORMA_MARGEM_PAINEL: "", FORMA_RAIO_PAINEL: "", FORMA_RAIO_DOCK: "",
  FORMA_ESPACO_PAINEL: "", FORMA_ESPACO_DOCK: "", VIDRO_OPACIDADE_PAINEL: "", FORMA_ALA_INICIAL_DOCK: "M",
  RELOGIO_SEGUNDOS: "nao",
};
const VAR_PX = {
  FORMA_MARGEM_PAINEL: "--p-margem-painel", FORMA_MARGEM_DOCK: "--p-margem-dock",
  FORMA_RAIO_PAINEL: "--p-raio-painel", FORMA_RAIO_DOCK: "--p-raio-dock",
  FORMA_ESPACO_PAINEL: "--p-espaco-painel", FORMA_ESPACO_DOCK: "--p-espaco-dock",
  FORMA_RECHEIO_PAINEL: "--p-recheio-painel", FORMA_RECHEIO_DOCK: "--p-recheio-dock",
};
const VAR_TAM = {
  FORMA_ALA_INICIAL_PAINEL: "--p-b-ini", FORMA_CENTRO_PAINEL: "--p-b-centro", FORMA_ALA_FINAL_PAINEL: "--p-b-fim",
  FORMA_ALA_INICIAL_DOCK: "--p-ala-ini", FORMA_CENTRO_DOCK: "--p-centro", FORMA_ALA_FINAL_DOCK: "--p-ala-fim",
};
const DADO = {
  FORMA_PAINEL_SOLTO: "solto-painel", FORMA_DOCK_SOLTO: "solto-dock", FORMA_PAINEL_ILHA: "ilha-painel",
  FORMA_DOCK_ILHA: "ilha-dock", RELOGIO_SEGUNDOS: "segundos", MIDIA: "musica", MIDIA_CAPA: "capa",
  MIDIA_CONTROLES: "tocar", JANELAS_TILING: "tiling", TERMINAL_ESQUEMA: "esquema", PROMPT_STARSHIP: "prompt",
  FASTFETCH_LOGO: "ff",
};
const MARGEM_DE = { FORMA_PAINEL_SOLTO: "FORMA_MARGEM_PAINEL", FORMA_DOCK_SOLTO: "FORMA_MARGEM_DOCK" };
const PONTEIRO = {
  "catppuccin-mocha-light": "var(--text)", "catppuccin-mocha-dark": "var(--crust)",
  "catppuccin-mocha-mauve": "var(--mauve)", "catppuccin-mocha-pink": "var(--pink)",
};
const PAREDES = ["svg/parede-eclipse.svg", "svg/parede-velas.svg", "svg/parede-rosacea.svg"];
const INSTALADOS = [
  ["firefox", "Firefox", "firefox"], ["com.brave.Browser", "Brave", "com.brave.Browser"], ["google-chrome", "Google Chrome", "google-chrome"],
  ["obsidian", "Obsidian", "obsidian"], ["code", "Visual Studio Code", "vscode"], ["steam", "Steam", "steam"],
  ["thunderbird", "Thunderbird", "thunderbird"], ["org.kde.krita", "Krita", "krita"], ["org.gimp.GIMP", "GIMP", "org.gimp.GIMP"],
  ["org.videolan.VLC", "VLC", "org.videolan.VLC"], ["org.qbittorrent.qBittorrent", "qBittorrent", "org.qbittorrent.qBittorrent"],
  ["com.spotify.Client", "Spotify", "com.spotify.Client"], ["com.discordapp.Discord", "Discord", "com.discordapp.Discord"],
  ["org.telegram.desktop", "Telegram", "org.telegram.desktop"], ["com.obsproject.Studio", "OBS Studio", "com.obsproject.Studio"],
  ["com.heroicgameslauncher.hgl", "Heroic", "com.heroicgameslauncher.hgl"], ["org.onlyoffice.desktopeditors", "ONLYOFFICE", "org.onlyoffice.desktopeditors"],
  ["org.gnome.Calculator", "Calculadora", "org.gnome.Calculator"], ["net.lutris.Lutris", "Lutris", "net.lutris.Lutris"],
  ["com.github.tchx84.Flatseal", "Flatseal", "com.github.tchx84.Flatseal"], ["com.system76.CosmicFiles", "Arquivos", "files"],
  ["com.system76.CosmicTerm", "Terminal", "terminal"], ["com.system76.CosmicSettings", "Configurações", "settings"],
  ["vim", "Vim", ""], ["debian-xterm", "XTerm", ""], ["debian-uxterm", "UXTerm", ""], ["qt5ct", "Qt5 Settings", ""], ["qt6ct", "Qt6 Settings", ""],
  ["display-im6.q16", "ImageMagick", ""], ["info", "Info", ""], ["im-config", "Método de entrada", ""], ["ibus-setup", "IBus", ""],
  ["org.gnome.font-viewer", "Fontes", ""], ["gnome-language-selector", "Idiomas", ""], ["system-config-printer", "Impressoras", ""],
  ["org.gnome.eog", "Visualizador de imagens", ""], ["org.gnome.Evince", "Visualizador de documentos", ""], ["org.gnome.baobab", "Uso do disco", ""],
  ["org.gnome.PowerStats", "Estatísticas de energia", ""], ["org.gnome.seahorse.Application", "Senhas e chaves", ""],
  ["org.gnome.DiskUtility", "Discos", ""], ["simple-scan", "Digitalizador", ""], ["yelp", "Ajuda", ""], ["gucharmap", "Mapa de caracteres", ""],
  ["nm-connection-editor", "Conexões de rede", ""], ["repoman", "Repoman", ""], ["com.system76.Popsicle", "Popsicle", ""], ["gparted", "GParted", ""],
  ["nvidia-settings", "NVIDIA X Server Settings", ""], ["syncthing-start", "Iniciar o Syncthing", ""], ["syncthing-ui", "Syncthing", ""],
  ["syncthing", "Syncthing", ""], ["solaar", "Solaar", ""], ["blueman-manager", "Bluetooth", ""], ["pavucontrol", "Controle de volume", ""],
];

const previas = () => $$(".previa");
const emTodas = (f) => previas().forEach(f);

function rotuloDe(controle) {
  const linha = controle.closest(".linha");
  const rot = $(".rot > span", linha).textContent;
  const ctl = controle.closest(".ctl");
  return ctl && ctl.dataset.coluna ? `${rot} (${ctl.dataset.coluna})` : rot;
}
function valorDe(controle) {
  if (controle.classList.contains("chave")) return controle.getAttribute("aria-checked") === "true" ? "sim" : "nao";
  if (controle.classList.contains("seg") || controle.classList.contains("cores") || controle.classList.contains("escolhas")) {
    const b = $("[aria-pressed='true']", controle);
    return b ? b.dataset.valor : "";
  }
  if (controle.type === "range") return controle.closest(".faixa").hasAttribute("data-vazio") ? "" : controle.value;
  return controle.value;
}
function textoDe(controle) {
  if (controle.classList.contains("chave")) return controle.getAttribute("aria-checked") === "true" ? "Sim" : "Não";
  if (controle.classList.contains("seg") || controle.classList.contains("escolhas")) {
    const b = $("[aria-pressed='true']", controle);
    return b ? b.textContent.trim() : "Auto";
  }
  if (controle.classList.contains("cores")) return valorDe(controle) || "Auto";
  if (controle.type === "range") return $("output", controle.closest(".faixa")).textContent;
  return controle.value || "Auto";
}
function marcarPadrao(controle) {
  const k = controle.dataset.chave;
  const b = controle.closest(".ctl") && $(`.padrao[data-padrao="${k}"]`, controle.closest(".ctl"));
  if (!b) return;
  const p = k in PADRAO ? PADRAO[k] : controle.dataset.inicial;
  b.hidden = valorDe(controle) === p;
  const linha = controle.closest(".linha");
  linha.classList.toggle("mudou", $$(".padrao", linha).some((x) => !x.hidden));
}

function aplicar(k, v) {
  if (k in DADO) emTodas((p) => { p.dataset[DADO[k].replace(/-(\w)/g, (_, c) => c.toUpperCase())] = v; });
  if (k in VAR_PX) emTodas((p) => (v === "" ? p.style.removeProperty(VAR_PX[k]) : p.style.setProperty(VAR_PX[k], `${v * PX}cqi`)));
  if (k in VAR_TAM) emTodas((p) => p.style.setProperty(VAR_TAM[k], `${TAMANHO[v] || 3.5}cqi`));
  if (k.startsWith("VIDRO_OPACIDADE_")) {
    const nome = k.endsWith("PAINEL") ? "--p-vidro-painel" : "--p-vidro-dock";
    emTodas((p) => (v === "" ? p.style.removeProperty(nome) : p.style.setProperty(nome, `${Math.round(v * 100)}%`)));
  }
  if (k in MARGEM_DE) {
    const faixa = $(`input[data-chave="${MARGEM_DE[k]}"]`);
    if (faixa) {
      faixa.disabled = v !== "sim";
      faixa.closest(".ctl").classList.toggle("desligado", v !== "sim");
    }
  }
  if (k === "MIDIA_COR_TITULO") emTodas((p) => p.style.setProperty("--p-musica-titulo", `var(--${v})`));
  if (k === "MIDIA_COR_ARTISTA") emTodas((p) => p.style.setProperty("--p-musica-artista", `var(--${v})`));
  if (k === "MIDIA_COR_ALBUM") emTodas((p) => (v ? p.style.setProperty("--p-musica-capa", `var(--${v})`) : p.style.removeProperty("--p-musica-capa")));
  if (k === "MIDIA_LARGURA") emTodas((p) => (v === "" ? p.style.removeProperty("--p-musica-largura") : p.style.setProperty("--p-musica-largura", `${v / 19.2}cqi`)));
  if (k === "MIDIA_FONTE") emTodas((p) => (v === "" ? p.style.removeProperty("--p-musica-letra") : p.style.setProperty("--p-musica-letra", `${v / 19.2 * 0.7}cqi`)));
  if (k === "CURSOR") emTodas((p) => p.style.setProperty("--p-ponteiro", PONTEIRO[v]));
  if (k === "TERMINAL_CURSOR") emTodas((p) => (v === "port" ? p.style.setProperty("--p-cursor", "var(--text)") : p.style.removeProperty("--p-cursor")));
  if (k === "LOGO") emTodas((p) => { for (const g of $$(".p-dock .gato", p)) g.src = `svg/${v}.svg`; espelharTerminal(); });
  if (k === "FASTFETCH_LOGO_MODO" || k === "FASTFETCH_LOGO_GATO") espelharTerminal();
  if (k === "WALLPAPER_AJUSTE") emTodas((p) => { const im = $(".parede", p); if (im) im.className = "parede" + (v === "preencher" ? "" : " " + v); });
  if (k === "LEITURA_TEMPERATURA") emTodas((p) => { const q = $(".quente", p); if (q) q.style.opacity = Math.min((6500 - v) / 6500 * 0.6, 0.45).toFixed(3); });
  if (k === "LEITURA_TEXTURA") emTodas((p) => { const t = $(".papel", p); if (t) t.style.opacity = v; });
  if (k === "LEITURA_AGENDA") regua("Modo de leitura", null, null, v === "sim");
  if (k === "WALLPAPER_NOITE") regua("Papel da noite", null, null, v === "sim");
  if (/HORARIO_INICIO|HORARIO_FIM/.test(k)) regua("Modo de leitura", $("[data-chave='LEITURA_HORARIO_INICIO']").value, $("[data-chave='LEITURA_HORARIO_FIM']").value);
  if (/^WALLPAPER_NOITE_(INICIO|FIM)$/.test(k)) regua("Papel da noite", $("[data-chave='WALLPAPER_NOITE_INICIO']").value, $("[data-chave='WALLPAPER_NOITE_FIM']").value);
  if (/^NOITE_(INICIO|FIM)$/.test(k)) regua("Mascote", $("[data-chave='NOITE_INICIO']").value, $("[data-chave='NOITE_FIM']").value);
}
function espelharTerminal() {
  const modo = valorDe($("[data-chave='FASTFETCH_LOGO_MODO']"));
  const gato = modo === "fixo" ? $("[data-chave='FASTFETCH_LOGO_GATO']").value : valorDe($(".escolhas[data-chave='LOGO']"));
  for (const i of $$(".p-term .gato-ff img")) i.src = `svg/${gato}.svg`;
  for (const k of ["FASTFETCH_LOGO_GATO"]) $(`[data-chave='${k}']`).closest(".linha").classList.toggle("dominada", modo !== "fixo");
}
function regua(nome, ini, fim, ligada) {
  const fila = $(`[data-regua="${nome}"] .barra-hora`);
  if (!fila) return;
  if (ini !== null && ini !== undefined) {
    const h = (s) => { const [a, b] = s.split(":").map(Number); return a + b / 60; };
    const a = h(ini), b = h(fim);
    const partes = a > b ? [[a, 24], [0, b]] : [[a, b]];
    const liga = $("span", fila) ? $("span", fila).classList.contains("ligada") : true;
    fila.replaceChildren(...partes.map(([x, y]) => {
      const s = document.createElement("span");
      s.style.left = `${x / 24 * 100}%`;
      s.style.width = `${(y - x) / 24 * 100}%`;
      if (liga) s.className = "ligada";
      return s;
    }));
  }
  if (ligada !== null && ligada !== undefined) for (const s of $$("span", fila)) s.classList.toggle("ligada", ligada);
}

function gravouSe(controle, de) {
  const para = textoDe(controle);
  marcarPadrao(controle);
  if (de !== para) anotar(rotuloDe(controle), de, para);
}
function faixaMove(input) {
  const f = input.closest(".faixa");
  f.removeAttribute("data-vazio");
  const p = (input.value - input.min) / (input.max - input.min) * 100;
  input.style.setProperty("--p", `${p}%`);
  const casas = Number(input.step) < 1 ? 2 : 0;
  $("output", f).textContent = `${Number(input.value).toFixed(casas)}${input.dataset.unidade || ""}`;
  aplicar(input.dataset.chave, input.value);
}
function voltarAoPadrao(botao) {
  const k = botao.dataset.padrao;
  const ctl = botao.closest(".ctl");
  const controle = $(`[data-chave="${k}"]`, ctl);
  if (!controle) return;
  const de = textoDe(controle);
  const p = k in PADRAO ? PADRAO[k] : controle.dataset.inicial;
  if (controle.classList.contains("chave")) controle.setAttribute("aria-checked", String(p === "sim"));
  else if (controle.type === "range") {
    const f = controle.closest(".faixa");
    if (p === "") {
      f.setAttribute("data-vazio", "");
      controle.value = controle.min;
      controle.style.setProperty("--p", "0%");
      $("output", f).textContent = "Auto";
    } else { controle.value = p; faixaMove(controle); }
  } else if (controle.matches(".seg, .cores, .escolhas")) for (const b of $$("[aria-pressed]", controle)) b.setAttribute("aria-pressed", String(b.dataset.valor === p));
  else controle.value = p;
  aplicar(k, valorDe(controle));
  gravouSe(controle, de);
}

function sugestoes(input) {
  const caixa = input.closest(".fichas");
  const lista = input.nextElementSibling;
  const q = input.value.trim().toLowerCase();
  input.removeAttribute("aria-invalid");
  const ja = new Set($$(".ficha", caixa).map((f) => f.dataset.id));
  const achou = q ? INSTALADOS.filter(([id, nome]) => !ja.has(id) && (id.toLowerCase().includes(q) || nome.toLowerCase().includes(q))).slice(0, 8) : [];
  lista.replaceChildren(...achou.map(([id, nome, ic], i) => {
    const o = document.createElement("div");
    o.setAttribute("role", "option");
    o.setAttribute("aria-selected", String(i === 0));
    o.dataset.id = id;
    o.innerHTML = ic ? `<img src="svg/app-${ic}.svg" alt="">` : `<span class="lugar-letra" aria-hidden="true">${nome[0]}</span>`;
    o.append(nome);
    const s = document.createElement("small");
    s.textContent = id;
    o.append(s);
    o.addEventListener("mousedown", (e) => { e.preventDefault(); porFicha(input, id, nome); });
    return o;
  }));
  lista.hidden = !achou.length;
  input.setAttribute("aria-expanded", String(!!achou.length));
}
function porFicha(input, id, nome) {
  const caixa = input.closest(".fichas");
  const f = document.createElement("span");
  f.className = "ficha";
  f.dataset.id = id;
  f.title = id;
  f.textContent = nome;
  const x = document.createElement("button");
  x.type = "button";
  x.setAttribute("aria-label", "Tirar " + nome);
  x.innerHTML = '<svg class="i" viewBox="0 0 24 24" aria-hidden="true"><path d="M18 6 6 18M6 6l12 12"/></svg>';
  f.append(x);
  input.closest(".nova-ficha").before(f);
  input.value = "";
  sugestoes(input);
  anotar(rotuloDe(input), "", "+ " + nome);
}

function irPara(id) {
  const secoes = $$(".secao");
  if (!secoes.some((s) => s.id === "secao-" + id)) id = "painel";
  for (const s of secoes) s.hidden = s.id !== "secao-" + id;
  scrollTo(0, 0);
  for (const a of $$("#abas a")) {
    if (a.getAttribute("href") === "#" + id) a.setAttribute("aria-current", "page");
    else a.removeAttribute("aria-current");
  }
  for (const b of $$("#abas [data-secao]")) b.hidden = b.dataset.secao !== id;
  document.title = "MeowSystem · " + $(`#t-${id}`).textContent;
}
function rota() {
  irPara(location.hash.slice(1).split("&")[0]);
}

function trocarParede(passo) {
  const im = $("#previa-papel .parede");
  const i = PAREDES.indexOf(im.getAttribute("src"));
  const n = (i + passo + PAREDES.length) % PAREDES.length;
  usarParede(PAREDES[n]);
}
function usarParede(src) {
  $("#previa-papel .parede").src = src;
  for (const f of $$(".galeria figure")) f.setAttribute("aria-pressed", String(f.dataset.parede === src));
}

function pagina() {
  for (const c of $$("[data-chave]")) c.dataset.inicial = valorDe(c);
  window.addEventListener("hashchange", rota);
  rota();
  document.addEventListener("click", (e) => {
    const sw = e.target.closest(".chave[data-chave]");
    if (sw && !sw.disabled) {
      const de = textoDe(sw);
      if (sw.dataset.chave === "LANCADOR_SISTEMA" && document.body.dataset.estado === "sem-ponte") { semPonte(); return; }
      sw.setAttribute("aria-checked", String(sw.getAttribute("aria-checked") !== "true"));
      aplicar(sw.dataset.chave, valorDe(sw));
      gravouSe(sw, de);
      return;
    }
    const op = e.target.closest(".seg[data-chave] button, .cores[data-chave] button, .escolhas[data-chave] button.escolha:not(.trazer)");
    if (op) {
      const grupo = op.parentElement.closest("[data-chave]");
      const de = textoDe(grupo);
      for (const b of $$("[aria-pressed]", grupo)) b.setAttribute("aria-pressed", String(b === op));
      aplicar(grupo.dataset.chave, op.dataset.valor);
      gravouSe(grupo, de);
      return;
    }
    const pd = e.target.closest(".padrao");
    if (pd) { voltarAoPadrao(pd); return; }
    const tira = e.target.closest(".ficha button");
    if (tira) {
      const f = tira.closest(".ficha");
      const input = $(".ficha-nova", f.closest(".fichas"));
      anotar(rotuloDe(input || f), f.firstChild.textContent, "−");
      f.remove();
      return;
    }
    const fig = e.target.closest(".galeria figure");
    if (fig && !e.target.closest(".estrela")) { usarParede(fig.dataset.parede); anotar("Papel de parede", "", fig.querySelector("small").textContent); return; }
    const est = e.target.closest(".estrela");
    if (est) { est.setAttribute("aria-pressed", String(est.getAttribute("aria-pressed") !== "true")); return; }
    const rap = e.target.closest("[data-rapida]");
    if (rap) {
      if (rap.dataset.rapida === "proxima") trocarParede(1);
      if (rap.dataset.rapida === "anterior") trocarParede(-1);
      if (rap.dataset.rapida === "girar") trocarParede(1);
      torrada(rap.textContent.trim(), "ok");
    }
  });
  for (const r of $$("input[type=range][data-chave]")) {
    let antes = textoDe(r);
    r.addEventListener("pointerdown", () => { antes = textoDe(r); });
    r.addEventListener("input", () => faixaMove(r));
    r.addEventListener("change", () => { gravouSe(r, antes); antes = textoDe(r); });
  }
  for (const c of $$("select[data-chave], input.campo[data-chave], .area input")) {
    let antes = c.value;
    c.addEventListener("focus", () => { antes = c.value; });
    c.addEventListener("change", () => {
      if (c.dataset.chave) aplicar(c.dataset.chave, c.value);
      if (c.dataset.chave) marcarPadrao(c);
      anotar(c.closest(".linha") ? rotuloDe(c) : c.getAttribute("aria-label"), antes || "Auto", c.value || "Auto");
      antes = c.value;
    });
  }
  for (const i of $$(".ficha-nova[role=combobox]")) {
    i.addEventListener("input", () => sugestoes(i));
    i.addEventListener("blur", () => { i.nextElementSibling.hidden = true; i.setAttribute("aria-expanded", "false"); });
    i.addEventListener("keydown", (e) => {
      const ops = $$("[role=option]", i.nextElementSibling);
      const at = ops.findIndex((o) => o.getAttribute("aria-selected") === "true");
      if (e.key === "ArrowDown" || e.key === "ArrowUp") {
        e.preventDefault();
        const n = (at + (e.key === "ArrowDown" ? 1 : -1) + ops.length) % ops.length;
        ops.forEach((o, j) => o.setAttribute("aria-selected", String(j === n)));
      }
      if (e.key === "Enter") {
        e.preventDefault();
        const q = i.value.trim();
        const exato = INSTALADOS.find(([id]) => id === q);
        if (at >= 0 && ops[at]) { const id = ops[at].dataset.id; porFicha(i, id, INSTALADOS.find((x) => x[0] === id)[1]); }
        else if (exato) porFicha(i, exato[0], exato[1]);
        else if (q) i.setAttribute("aria-invalid", "true");
      }
    });
  }
}
