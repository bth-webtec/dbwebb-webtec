#!/usr/bin/env node
//
// Sync the VERSION exported by bin/dbw-webtec.bash with the version in
// package.json, so `npm version <bump>` can never drift from the version
// the CLI itself reports.
//

import { readFileSync, writeFileSync } from 'node:fs'

const pkg = JSON.parse(readFileSync(new URL('../package.json', import.meta.url)))
const version = pkg.version

const target = new URL('../bin/dbw-webtec.bash', import.meta.url)
const content = readFileSync(target, 'utf8')
const updated = content.replace(/export VERSION="[^"]*"/, `export VERSION="${version}"`)

if (updated === content) {
  console.error('Could not find "export VERSION=" line in bin/dbw-webtec.bash')
  process.exit(1)
}

writeFileSync(target, updated)
console.log(`bin/dbw-webtec.bash VERSION synced to ${version}`)
