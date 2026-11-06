#!/usr/bin/env bash
set -uo pipefail
RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
NODE="$(command -v node || true)"
[ -n "$NODE" ] || { printf 'pulado: sem node\n'; exit 3; }
"$NODE" - "$RAIZ/app/pagina/paginas.js" <<'JS'
"use strict";
const fs = require("fs"), vm = require("vm");
const src = fs.readFileSync(process.argv[2], "utf8");
const pega = (nome) => {
  const i = src.indexOf("function " + nome + "(");
  if (i < 0) { console.error("FALHOU: não achei " + nome); process.exit(1); }
  let n = 0;
  for (let k = src.indexOf("{", i); k < src.length; k++) {
    if (src[k] === "{") n++;
    if (src[k] === "}" && --n === 0) return src.slice(i, k + 1);
  }
};
let modo = "novo";
const rascunho = { pack: "meu", base: { pack: "meowsystem", flavor: "mocha" } };
const ctx = { modoDoRascunho: () => modo, rascunho: () => rascunho, vinteSeis: () => ({ base: "#000" }) };
vm.createContext(ctx);
for (const f of ["chaveDoAcervo", "chaveDaPrevia"]) vm.runInContext(pega(f), ctx);
const falhas = [];
for (const f of ["chaveDoAcervo", "chaveDaPrevia"]) {
  modo = "novo";
  const novo = ctx[f]();
  const repetida = ctx[f]();
  modo = "aprimorar";
  const aprimorar = ctx[f]();
  if (novo !== repetida) falhas.push(f + ": a mesma entrada deu chaves diferentes");
  if (novo === aprimorar) falhas.push(f + ": criar e aprimorar com o mesmo tema dão a mesma chave, e o acervo velho vale pro modo errado");
}
if (falhas.length) { console.error("FALHOU:\n  " + falhas.join("\n  ")); process.exit(1); }
console.log("ok: a chave do acervo e a da prévia mudam com o modo (criar ou aprimorar) e não mudam sem ele");
JS
