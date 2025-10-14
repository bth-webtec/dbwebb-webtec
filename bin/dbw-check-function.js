#!/usr/bin/env node
import fs from "fs";
//import acorn from "acorn";
import * as acorn from "acorn";

// Läs in argument
const [,, filePath, functionName] = process.argv;

if (!filePath || !functionName) {
  console.error("❌ Användning: node checkFunction.js <filväg> <funktionsnamn>");
  process.exit(1);
}

// Läs in filen
const code = fs.readFileSync(filePath, "utf-8");

// Parsa till AST
const ast = acorn.parse(code, { ecmaVersion: "latest", sourceType: "module" });

let found = false;

// Enkel rekursiv traversering av AST
function walk(node) {
  if (!node) return;

  // Kolla olika typer av deklarationer
  if (node.type === "FunctionDeclaration" && node.id?.name === functionName) {
    found = true;
  }

  if (node.type === "VariableDeclarator" && node.id.name === functionName) {
    found = true;
  }

  if (node.type === "Property" && node.key.name === functionName) {
    found = true;
  }

  if (node.type === "MethodDefinition" && node.key.name === functionName) {
    found = true;
  }

  // Gå igenom alla undernoder
  for (const key in node) {
    const val = node[key];
    if (Array.isArray(val)) val.forEach(walk);
    else if (val && typeof val === "object") walk(val);
  }
}

walk(ast);

if (found) {
  console.log(`✅ Funktionen '${functionName}()' hittad i ${filePath}`);
  process.exit(0);
} else {
  console.log(`❌ Funktionen '${functionName}()' saknas i ${filePath}`);
  process.exit(1);
}
