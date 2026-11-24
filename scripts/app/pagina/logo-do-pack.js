const LOGO_DO_PACK = { versao: "" };

function logoDoCartao(p) {
  const img = elemento("img", { class: "logo", src: p.capa, alt: "" });
  if (!p.pessoal) return img;
  return elemento("button", { type: "button", class: "logo-trocar", controle: "pack:" + p.id + ":logo",
    "aria-label": "Trocar a logo", dica: "Trocar a logo", onclick: () => abrirLogoDoPack(p) },
  [img, icone("pincel", "i selo-pincel")]);
}

function dialogoLogoDoPack() {
  let d = document.getElementById("logo-do-pack");
  if (d) return d;
  d = elemento("dialog", { id: "logo-do-pack", class: "logo-do-pack", "aria-labelledby": "logo-do-pack-t" }, [
    elemento("div", { class: "dentro" }, [
      elemento("h2", { id: "logo-do-pack-t", texto: "Logo" }),
      elemento("div", { id: "logo-do-pack-grade", class: "escolhas", role: "group", "aria-label": "Logos" }),
      elemento("p", { class: "oficina-erro", id: "logo-do-pack-queixa", role: "alert" }),
      elemento("div", { class: "acoes" }, [
        elemento("button", { class: "bt leve", type: "button", controle: "logo-do-pack:fechar", texto: "Fechar",
          onclick: () => d.close() }),
      ]),
    ]),
  ]);
  document.body.append(d);
  return d;
}

async function gravarLogoDoPack(p, corpo) {
  const d = dialogoLogoDoPack();
  const queixa = $("#logo-do-pack-queixa");
  queixa.textContent = "";
  d.dataset.passo = "gravando";
  const r = await api("/api/logo-do-pack", { method: "POST", body: JSON.stringify({ pack: p.id, ...corpo }) });
  delete d.dataset.passo;
  if (r.erro) { queixa.textContent = maiuscula(r.erro); return; }
  d.close();
  await Promise.all([recarregarPacks(), recarregarEsquema()]);
  LOGO_DO_PACK.versao = String(Date.now());
  const versao = "?v=" + LOGO_DO_PACK.versao;
  const marca = document.querySelector("#topo .marca img");
  if (marca) marca.src = "/logo.svg" + versao;
  const aba = document.querySelector("link[rel=icon]");
  if (aba) aba.href = "/logo.svg" + versao;
  render();
}

function botaoArquivoDeLogo(p) {
  const campo = elemento("input", { type: "file", accept: ".svg,.png,image/svg+xml,image/png", hidden: true,
    "data-logo-arquivo": p.id });
  const b = elemento("button", { type: "button", class: "escolha trazer", controle: "logo-do-pack:arquivo",
    onclick: () => campo.click() }, [icone("mais"), elemento("span", { texto: "Abrir um arquivo" })]);
  campo.addEventListener("change", async () => {
    const arq = campo.files && campo.files[0];
    campo.value = "";
    if (!arq) return;
    try {
      await gravarLogoDoPack(p, { de: "arquivo", nome: arq.name, conteudo: await lerComoBase64(arq) });
    } catch (e) {
      $("#logo-do-pack-queixa").textContent = maiuscula(String(e.message || e));
    }
  });
  return elemento("span", { style: "display:contents" }, [b, campo]);
}

async function abrirLogoDoPack(p) {
  const d = dialogoLogoDoPack();
  const r = await api("/api/logo-do-pack?pack=" + encodeURIComponent(p.id));
  if (r.erro) { torrada(r.erro, "erro"); return; }
  $("#logo-do-pack-queixa").textContent = "";
  $("#logo-do-pack-t").textContent = p.nome;
  $("#logo-do-pack-grade").replaceChildren(
    ...r.opcoes.map((o) => elemento("button", {
      type: "button", class: "escolha", "aria-pressed": String(o.chave === r.atual),
      controle: "logo-do-pack:" + o.chave, onclick: () => gravarLogoDoPack(p, { de: o.de, id: o.id }),
    }, [elemento("img", { src: o.url, alt: "" }), elemento("span", { texto: o.rotulo })])),
    botaoArquivoDeLogo(p));
  d.showModal();
}
