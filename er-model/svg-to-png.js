// Renders an SVG to PNG with Playwright's Chromium: node svg-to-png.js in.svg out.png [scale]
// Used for mdms-er-card.png: node erdplus-preview.js --card && node svg-to-png.js mdms-er-card.svg mdms-er-card.png 2
const fs = require('fs');
let chromium;
try { ({ chromium } = require('playwright')); } catch { ({ chromium } = require(require('child_process').execSync('npm root -g').toString().trim() + '/playwright')); }
(async () => {
  const [svg, out, scale = '2'] = process.argv.slice(2);
  const s = fs.readFileSync(svg, 'utf8');
  const w = +s.match(/width="(\d+)"/)[1], h = +s.match(/height="(\d+)"/)[1];
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: +scale });
  await page.setContent(`<body style="margin:0">${s}</body>`);
  await page.screenshot({ path: out, fullPage: true });
  await browser.close();
})();
