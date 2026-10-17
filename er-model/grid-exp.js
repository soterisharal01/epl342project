const { instance } = require('@viz-js/viz');
const { gridLayout } = require('./layout-grid.js');
const { score } = require('./layout-exp.js');
const opts = JSON.parse(process.argv[2] || '[{}]');
instance().then(viz => {
  for (const o of opts) {
    const t = Date.now();
    const r = gridLayout(viz, { ...o, attrSize: name => ({ w: Math.max(76, name.length * 6.5 + 30), h: 36 }) });
    console.log(JSON.stringify(o), JSON.stringify(r.grid), 'cost', r.cost.toFixed(1), JSON.stringify(score(r.pins)), ((Date.now() - t) / 1000).toFixed(1) + 's');
  }
});
