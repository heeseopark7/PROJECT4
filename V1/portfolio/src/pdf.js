const { chromium } = require('playwright');
(async () => {
  const [src, out] = process.argv.slice(2);
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + src); 
  await p.pdf({ path: out, format: 'A4', printBackground: true,
    margin: { top: '13mm', bottom: '15mm', left: '12mm', right: '12mm' },
    displayHeaderFooter: true, headerTemplate: '<span></span>',
    footerTemplate: '<div style="font-size:7pt;width:100%;padding:0 12mm;color:#888;display:flex;justify-content:space-between"><span>MCU V1 포트폴리오 보완 자료</span><span><span class="pageNumber"></span> / <span class="totalPages"></span></span></div>' });
  await b.close();
})();
