#!/usr/bin/env node
import fs from "fs";

const MIN_LENGTH = 400;

const [,, filePath, kmom] = process.argv;

if (!filePath || !kmom) {
  console.error("❌ Användning: node dbw-check-report-text.js <report.html> <kmomNN>");
  process.exit(1);
}

if (!fs.existsSync(filePath)) {
  console.log(`❌ Hittar inte ${filePath}.`);
  process.exit(1);
}

const html = fs.readFileSync(filePath, "utf-8");

const sectionPattern = new RegExp(`<section[^>]*\\bid=["']${kmom}["'][^>]*>([\\s\\S]*?)<\\/section>`, "i");
const match = html.match(sectionPattern);

if (!match) {
  console.log(`❌ Hittar ingen <section id="${kmom}"> i ${filePath}. Döp inte om eller ta bort sektionen, den behövs för den automatiska kontrollen.`);
  process.exit(1);
}

const text = match[1]
  .replace(/<h[1-6][^>]*>[\s\S]*?<\/h[1-6]>/gi, " ")
  .replace(/<[^>]+>/g, " ")
  .replace(/&nbsp;/gi, " ")
  .replace(/&[a-z]+;|&#\d+;/gi, " ")
  .replace(/\s+/g, " ")
  .trim();

if (text.length < MIN_LENGTH) {
  console.log(`❌ Redovisningstexten för ${kmom} är för kort (${text.length} tecken, minst ${MIN_LENGTH} krävs). Fyll i en riktig reflektion i <section id="${kmom}"> i ${filePath}.`);
  process.exit(1);
}

console.log(`✅ Redovisningstexten för ${kmom} finns och är ${text.length} tecken lång.`);
process.exit(0);
