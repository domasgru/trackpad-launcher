#!/usr/bin/env node
// Splits the gesture illustrations exported from Figma into what the app ships:
//   assets/illustration-surface.png  the shared paper card (texture, rounded corners, inner shadows) at 3x
//   assets/<name>.svg                the marks alone, thumb top-left (right hand)
//   assets/<name>-inverse.svg        the same marks mirrored, thumb top-right (left hand)
// Each export embeds the same 10 MB texture and draws the card with SVG filters, which NSImage's SVG support does
// not render; baking the card once in Chromium keeps the design's look and leaves the marks as small vectors.
//
// Usage: node Scripts/illustrations.mjs <directory of Figma SVG exports>
// Needs Playwright with a Chromium (`npm i -g playwright`).
import { readFileSync, writeFileSync } from 'node:fs'
import { join, dirname } from 'node:path'
import { fileURLToPath } from 'node:url'
import { createRequire } from 'node:module'
import { execSync } from 'node:child_process'

const names = ['gesture-1', 'gesture-2', 'gesture-3', 'gesture-4', 'gesture-5', 'swipe', 'window-swipe', 'thumb-tap']
const scale = 3

const source = process.argv[2]
if (!source) {
  console.error('usage: node Scripts/illustrations.mjs <directory of Figma SVG exports>')
  process.exit(1)
}
const assets = join(dirname(fileURLToPath(import.meta.url)), '..', 'assets')

/// The bounding box of a path drawn as four arcs: its control points sit on the box's edges.
function ellipseOf(d) {
  const numbers = d.match(/-?\d*\.?\d+(?:e-?\d+)?/g).map(Number)
  const xs = numbers.filter((_, i) => i % 2 === 0)
  const ys = numbers.filter((_, i) => i % 2 === 1)
  const [minX, maxX, minY, maxY] = [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys)]
  return { cx: (minX + maxX) / 2, cy: (minY + maxY) / 2, rx: (maxX - minX) / 2, ry: (maxY - minY) / 2 }
}

const round = n => Number(n.toFixed(5))

/// The marks inside the export's filtered group. Figma writes an inside stroke as a centred 1 pt stroke masked by
/// its own shape; that is a 0.5 pt stroke on an ellipse 0.25 pt smaller, which NSImage draws without masks. A filled
/// dot's own inside stroke lies within its fill and is dropped.
function marks(svg) {
  const group = svg.match(/<g filter="[^"]*">([\s\S]*?)<\/g>\s*<defs>/)[1]
  const defs = Object.fromEntries([...svg.matchAll(/<path id="([^"]+)" d="([^"]+)"\/>/g)].map(m => [m[1], m[2]]))
  const out = []
  for (const line of group.replace(/<mask[\s\S]*?<\/mask>/g, '').split('\n').map(l => l.trim())) {
    if (!line || line.startsWith('<rect')) continue
    let m
    if (line.startsWith('<ellipse')) {
      out.push(line)
    } else if ((m = line.match(/^<path d="([^"]+)" stroke="black" mask="url\(#[^)]+\)"\/>$/))) {
      if (Object.values(defs).includes(m[1])) continue
      const e = ellipseOf(m[1])
      out.push(`<ellipse cx="${round(e.cx)}" cy="${round(e.cy)}" rx="${round(e.rx - 0.25)}" ry="${round(e.ry - 0.25)}" stroke="black" stroke-width="0.5"/>`)
    } else if ((m = line.match(/^<use xlink:href="#([^"]+)" fill="black"\/>$/))) {
      const e = ellipseOf(defs[m[1]])
      out.push(`<ellipse cx="${round(e.cx)}" cy="${round(e.cy)}" rx="${round(e.rx)}" ry="${round(e.ry)}" fill="black"/>`)
    } else if (line.startsWith('<path') && !line.includes('mask=')) {
      out.push(line)
    } else {
      throw new Error(`unexpected element: ${line}`)
    }
  }
  return out
}

const document = (body, transform) =>
  [
    '<svg width="45" height="28" viewBox="0 0 45 28" fill="none" xmlns="http://www.w3.org/2000/svg">',
    transform ? `<g transform="${transform}">` : null,
    ...body,
    transform ? '</g>' : null,
    '</svg>',
    '',
  ]
    .filter(line => line !== null)
    .join('\n')

/// The export with every mark removed: the card alone, with its texture and filter.
const surfaceOnly = svg => svg.replace(/(<rect [^>]*\/>)[\s\S]*?(<\/g>\s*<defs>)/, '$1\n$2')

const exports = Object.fromEntries(names.map(name => [name, readFileSync(join(source, `${name}.svg`), 'utf8')]))
for (const [name, svg] of Object.entries(exports)) {
  const body = marks(svg)
  writeFileSync(join(assets, `${name}.svg`), document(body))
  writeFileSync(join(assets, `${name}-inverse.svg`), document(body, 'matrix(-1 0 0 1 45 0)'))
}

const require = createRequire(join(execSync('npm root -g').toString().trim(), 'playwright', 'package.json'))
const { chromium } = require('playwright')
const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: 45, height: 28 }, deviceScaleFactor: scale })
await page.setContent(
  `<style>html,body{margin:0;background:transparent}</style>${surfaceOnly(exports['gesture-1']).replace(/<\?xml[^>]*>/, '')}`)
await page.locator('svg').screenshot({ path: join(assets, 'illustration-surface.png'), omitBackground: true })
await browser.close()
