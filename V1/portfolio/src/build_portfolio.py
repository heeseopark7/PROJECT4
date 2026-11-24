#!/usr/bin/env python3
"""Build the FE and BE portfolios from the original single portfolio PDF.
FE = new cover + original pages 2-12 (+ appendix S1, S2); BE = new cover + original 13-22 (+ appendix D, E).
Pages 7 and 13 are rewritten, pages 8, 12, 14-16, 18, 19 are patched, the code/script captures on
pages 4, 5, 8 are covered by text excerpts read from the V1/TOP files (no screenshots), and the
appendices are taken verbatim from the same files. All other images are left as in the original.

usage: python3 build_portfolio.py <V1/TOP dir> <original pdf> <output dir> <work dir>
needs: pypdf, pypdfium2, node + playwright (chromium)
"""
import html, pathlib, subprocess, sys
import pypdf, pypdfium2

TOP, ORIG, OUTDIR, WORK = map(pathlib.Path, sys.argv[1:5])
PROJ = "Park Heeseo_project"
SRC = pathlib.Path(__file__).resolve().parent
FONTS = (SRC / "fonts").as_uri()
WORK.mkdir(parents=True, exist_ok=True)
W_PT, H_PT = 594.96, 841.92          # page size of the original

# ---------------------------------------------------------------- style
CSS = f"""
@font-face {{ font-family: Pret; src: url({FONTS}/Pretendard-Regular.woff2); font-weight: 400; }}
@font-face {{ font-family: Pret; src: url({FONTS}/Pretendard-SemiBold.woff2); font-weight: 600; }}
@font-face {{ font-family: Pret; src: url({FONTS}/Pretendard-Bold.woff2); font-weight: 700; }}
@font-face {{ font-family: JBM; src: url({FONTS}/jetbrains-mono-latin-400-normal.woff2); font-weight: 400; }}
@font-face {{ font-family: JBM; src: url({FONTS}/jetbrains-mono-latin-700-normal.woff2); font-weight: 700; }}
:root {{ --ink:#14202a; --muted:#56636b; --teal:#0a5f5a; --teal2:#0a7a74; --tealbg:#e3f2f0;
        --line:#c5d0d5; --th:#e9eef0; --codebg:#eef2f3; --org:#a8510a; --orgbg:#fdf1e4; }}
* {{ box-sizing: border-box; }}
html, body {{ margin:0; padding:0; background: transparent; }}
body {{ font-variant-ligatures: none; font-feature-settings: 'liga' 0, 'calt' 0; font-family: Pret, sans-serif; color: var(--ink); font-size: 9.6pt; line-height: 1.6;
        -webkit-font-smoothing: antialiased; letter-spacing: -0.1pt; }}
code, .mono {{ font-family: JBM, Pret, monospace; font-size: 0.86em; background: var(--codebg);
        padding: 0.5pt 3pt; border-radius: 2pt; letter-spacing: 0; }}
.page {{ width: {W_PT}pt; height: {H_PT}pt; position: relative; overflow: hidden;
         padding: 40pt 36.5pt 30pt 36.75pt; background: #fff; page-break-after: always; }}
.bar {{ background: var(--teal); color:#fff; font-weight:700; font-size: 14pt; padding: 7pt 9pt;
        border-radius: 3pt; margin: 0 0 12pt; letter-spacing: -0.2pt; }}
h3 {{ color: var(--teal); font-size: 11.2pt; font-weight: 700; margin: 12pt 0 7pt;
      padding-bottom: 3pt; border-bottom: 1.3pt solid var(--teal); }}
p {{ margin: 0 0 7pt; }}
table {{ width:100%; border-collapse: collapse; font-size: 8.6pt; line-height: 1.5; margin: 0 0 8pt; }}
th, td {{ border: 0.75pt solid var(--line); padding: 3.2pt 5pt; text-align:left; vertical-align: top; }}
th {{ background: var(--th); font-weight: 700; }}
td code {{ font-size: 0.9em; }}
.num {{ text-align:right; font-family: JBM, monospace; white-space: nowrap; }}
.note {{ background: var(--tealbg); border-left: 2.5pt solid var(--teal2); padding: 6pt 9pt; font-size: 8.8pt; margin: 0 0 8pt; }}
.chk {{ background: var(--orgbg); border: 0.75pt dashed var(--org); padding: 6pt 9pt; font-size: 8.8pt; margin: 0 0 8pt; }}
.chk b.l {{ color: var(--org); }}
.note b.l {{ color: var(--teal); }}
pre.code {{ font-family: JBM, Pret, monospace; font-size: 6.9pt; line-height: 1.42; background: #f4f6f7;
            border: 0.75pt solid var(--line); border-top: none; margin: 0 0 10pt; padding: 5pt 7pt;
            white-space: pre-wrap; word-break: break-all; letter-spacing: 0; }}
.fh {{ display:flex; justify-content: space-between; background: var(--teal); color:#fff;
       font-family: JBM, Pret, monospace; font-size: 7.4pt; padding: 2.5pt 7pt; border-radius: 2.5pt 2.5pt 0 0; letter-spacing:0; }}
.fn {{ font-size: 8pt; color: var(--muted); margin: -6pt 0 10pt; }}
.cap {{ font-size: 8.4pt; color: var(--muted); }}
.ov {{ position:absolute; }}
.cbox {{ position:absolute; background:#f7f9fa; border:0.6pt solid var(--line); display:flex; flex-direction:column; overflow:hidden; }}
.cbox .ch {{ background: var(--teal); color:#fff; font-family: JBM, Pret, monospace; font-size:5.6pt; padding:1.2pt 4pt; letter-spacing:0; white-space:nowrap; overflow:hidden; }}
.cbox pre {{ margin:0; padding:3pt 4pt; flex:1; overflow:hidden; font-family: JBM, monospace; white-space: pre; line-height:1.3; color:#1b2731; letter-spacing:0; }}
.cbox .cm {{ color:#5c7a78; }}
.p13 table {{ font-size: 8.1pt; line-height: 1.42; margin-bottom: 6pt; }}
.p13 th, .p13 td {{ padding: 2.4pt 5pt; }}
.p13 h3 {{ margin: 9pt 0 5pt; }}
.p13 .note, .p13 .chk {{ padding: 4.5pt 9pt; margin-bottom: 6pt; }}
"""

def doc(body, extra_css=""):
    return f'<!doctype html><html lang="ko"><head><meta charset="utf-8"><style>{CSS}{extra_css}</style></head><body>{body}</body></html>'

def src(rel):
    return (TOP / rel).read_text(errors="replace").rstrip("\n")

def code_file(rel, note=None):
    t = src(rel)
    n = t.count("\n") + 1
    nt = f'<div class="fn" style="margin:3pt 0 4pt">{note}</div>' if note else ""
    return (f'<div style="break-inside: avoid-page; break-after: auto"></div>'
            f'<div class="fh"><span>{PROJ}/TOP/{rel}</span><span>{n} lines</span></div>'
            f'<pre class="code">{html.escape(t)}</pre>{nt}')

def lines(rel, a, b):
    return "\n".join(src(rel).split("\n")[a - 1:b])

def render(html_text, name, margin=None):
    h = WORK / f"{name}.html"; out = WORK / f"{name}.pdf"
    h.write_text(html_text)
    m = margin or {"top": "0", "bottom": "0", "left": "0", "right": "0"}
    js = WORK / "render.js"
    js.write_text("""const { chromium } = require('playwright');
(async () => { const [src, out, m] = process.argv.slice(2); const mm = JSON.parse(m);
  const b = await chromium.launch(); const p = await b.newPage();
  await p.goto('file://' + src, { waitUntil: 'networkidle' }); await p.evaluate(() => document.fonts.ready); await p.evaluate(() => window.fitAll && window.fitAll());
  await p.pdf({ path: out, width: '%.2fpx', height: '%.2fpx', printBackground: true, margin: mm });
  await b.close(); })();""" % (W_PT*4/3, H_PT*4/3))
    import json
    subprocess.run(["node", str(js), str(h), str(out), json.dumps(m)], check=True)
    return pypdf.PdfReader(str(out))

orig = pypdf.PdfReader(str(ORIG))

def find_page(path, needle):
    d = pypdfium2.PdfDocument(str(path))
    for i in range(len(d)):
        if needle in d[i].get_textpage().get_text_range():
            return i
    raise SystemExit(f"not found: {needle}")

M = {"top": "53.33px", "bottom": "45.33px", "left": "49px", "right": "48.67px"}

# ---------------------------------------------------------------- page 1 (cover)
def tile(v, cap):
    return (f'<td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">{v}</div>'
            f'<div class="cap">{cap}</div></td>')

def cover(part, part_ko, lead, tiles, rows, flow):
    tr = "".join(f'<tr><td>{a}</td><td>{b}</td></tr>' for a, b in rows)
    return f"""
<div class="page" style="padding-top:120pt">
 <div class="mono" style="background:none;padding:0;color:var(--teal);font-size:7.8pt">{part} Portfolio</div>
 <div style="font-size:27pt;font-weight:700;margin:6pt 0 0;letter-spacing:-0.6pt">{PROJ}</div>
 <div style="font-size:13pt;font-weight:600;color:var(--teal);margin:0 0 8pt">MCU RTL to GDSII · {part_ko}</div>
 <table style="font-size:9.6pt;margin:4pt 0 10pt">{"".join(f'<tr><th style="width:17%;background:#f2f5f6">{k}</th><td>{v}</td></tr>' for k, v in lead)}</table>
 <table style="table-layout:fixed;margin:6pt 0 16pt"><tr>{"".join(tile(*t) for t in tiles)}</tr></table>
 <h3 style="margin-top:0">구성</h3>
 <table><tr><th>항목</th><th style="width:9%">쪽</th></tr>{tr}</table>
</div>"""

SPEC = [("Design", "MCU: 단일 사이클 MIPS CPU · APB 브리지 · UART · SPI Master/Slave"),
        ("Clock", "10 ns (100 MHz)"), ("Process", "GPDK045")]

# ---------------------------------------------------------------- page 7 
sec7 = f"""
<div class="bar">3. Synthesis</div>
<h3>(i) Synthesis Run Script</h3>
{code_file("3_SYN/run_synthesis")}
{code_file("3_SYN/script/syn_mcu_pad_top.tcl")}
"""

# ---------------------------------------------------------------- page 13 (4-a, 4-b)
sec13 = f"""
<div class="p13">
<div class="bar">1. APR 전 과정 Script</div>
 <table>
  <tr><th style="width:27%">스크립트</th><th style="width:20%">DB (입력 → 출력)</th><th>주요 명령</th></tr>
  <tr><td><code>0_InitDesign.tcl</code><br><code>init.io</code></td><td>넷리스트 → InitDesign</td><td><code>init_design</code>, <code>checkDesign</code>, <code>floorPlan -r 1 0.6 352×4</code>, 전원 패드 <code>placeInstance</code>, <code>addIoFiller</code>, <code>timeDesign -prePlace</code></td></tr>
  <tr><td><code>1_PowerPlan.tcl</code></td><td>InitDesign → PowerPlan</td><td><code>globalNetConnect</code>, <code>addRing</code> 2중(offset 5 / 200, Metal10/11), <code>sroute</code>(corePin, padPin), <code>addStripe</code> 3회, <code>verify_drc</code>, <code>verifyConnectivity</code></td></tr>
  <tr><td><code>2_PlaceOpt.tcl</code></td><td>PowerPlan → PlaceOpt</td><td><code>place_design</code>, <code>checkPlace</code>, <code>earlyGlobalRoute</code>, <code>place_opt_design</code>, <code>timeDesign -preCTS</code></td></tr>
  <tr><td><code>3_PostCTSopt.tcl</code></td><td>PlaceOpt → PostCTSopt</td><td><code>target_skew 0.01</code>, <code>ccopt_design</code>, <code>set_propagated_clock</code>, <code>optDesign -postCTS</code> (+ <code>-hold</code>)</td></tr>
  <tr><td><code>4_RouteDesign_</code><br><code>PowerAnalysis.tcl</code></td><td>PostCTSopt → RouteDesign</td><td>NanoRoute <code>routeDesign -globalDetail</code>, <code>optDesign -postRoute -drv/-setup/-hold</code>(bcwc), <code>extractRC</code>, <code>report_power</code></td></tr>
  <tr><td><code>5_ChipFinish.tcl</code></td><td>RouteDesign → ChipFinish</td><td><code>addFiller</code>, <code>verify_drc</code>, <code>verifyConnectivity</code>, <code>saveNetlist</code>, <code>write_sdf</code>, <code>writeTimingCon</code>, <code>streamOut</code></td></tr>
 </table>
</div>
{code_file("5_PNR/0_InitDesign.tcl")}
{code_file("5_PNR/init.io")}
{code_file("5_PNR/1_PowerPlan.tcl")}
{code_file("5_PNR/2_PlaceOpt.tcl")}
{code_file("5_PNR/3_PostCTSopt.tcl")}
{code_file("5_PNR/4_RouteDesign_PowerAnalysis.tcl")}
{code_file("5_PNR/5_ChipFinish.tcl")}
<div style="break-before: page"></div>
<div class="p13">
<div class="bar">2. Import 파일 정리</div>
 <table>
  <tr><th style="width:17%">종류</th><th style="width:47%">파일</th><th>출처 / 비고</th></tr>
  <tr><td>넷리스트</td><td><code>../3_SYN/mapped/mcu_pad_top_syn_final.v</code></td><td>Genus 10 ns 출력(11/10) + 전원 패드 16개(<code>add_pad</code>)</td></tr>
  <tr><td>타이밍 제약</td><td><code>../3_SYN/mapped/mcu_pad_top_syn_final.sdc</code></td><td>Genus <code>write_sdc</code> 출력, 10 ns. 입력 구동은 <code>set_driving_cell PADDI</code></td></tr>
  <tr><td>IO 배치</td><td><code>init.io</code></td><td>48슬롯, 코너 셀 4개. 표 <code>IO_Cell_Map_mcu_pad_top.xlsx</code> 기준으로 작성</td></tr>
  <tr><td>타이밍 lib (SS)</td><td><code>slow_vdd1v0_basicCells.lib</code>, <code>slow_vdd1v0_multibitsDFF.lib</code>, <code>pads_SS_s1vg.lib</code></td><td>setup, FUNC_SS_WORST (0.9 V, 125°C)</td></tr>
  <tr><td>타이밍 lib (FF)</td><td><code>fast_vdd1v0_basicCells.lib</code>, <code>fast_vdd1v0_multibitsDFF.lib</code>, <code>pads_FF_s1vg.lib</code></td><td>hold, FUNC_FF_BEST (1.1 V, 0°C)</td></tr>
  <tr><td>LEF</td><td><code>gsclib045_tech.lef</code>(gsclib045_tech/lef), <code>gsclib045_macro.lef</code>, <code>gsclib045_multibitsDFF.lef</code>, <code>giolib045_modify.lef</code></td><td>GPDK045 gsclib045 v4.4, giolib045 v3.5</td></tr>
  <tr><td>RC</td><td><code>gpdk045.tch</code>(gsclib045/qrc/qx) + cap table <code>…typical.capTbl</code></td><td>rc_corner BEST(T 0), WORST(T 125)</td></tr>
  <tr><td>View</td><td>constraint_mode FUNC, view FUNC_SS_WORST / FUNC_FF_BEST</td><td><code>mcu_pad_top.mmmc.view</code></td></tr>
 </table>
</div>
{code_file("5_PNR/mcu_pad_top.mmmc.view")}
{code_file("5_PNR/add_pad")}
"""

# ---------------------------------------------------------------- page 6 (3-b): rebuilt without the full-run
# waveform (the 1200x171 capture is too low-res to read); the UART and SPI zooms stay
from PIL import Image, ImageDraw
def orig_img(pg, name):
    return [i for i in orig.pages[pg - 1].images if i.name == name][0].image.convert("RGB")
orig_img(6, "X30.jpg").save(WORK / "wave_full.png")
orig_img(6, "X31.jpg").save(WORK / "wave_uart.png"); orig_img(6, "X32.jpg").save(WORK / "wave_spi.png")
fig = lambda f: f'<img src="{(WORK / f).as_uri()}" style="width:100%;display:block;border:0.6pt solid var(--line)">'
p6 = f"""
<div class="page">
 <div class="bar">2. Function Simulation</div>
 <p style="font-size:10pt">자기검증 테스트벤치(<code>tb_mcu_top</code>)가 RAM 4곳, UARTTXD 프레임과 데이터, SPI 8클럭과 MOSI/MISO 바이트, 종료 pc를 기대값과 비교한다. APB 접근마다 stall 1클럭 뒤 penable 1클럭이 나오고 둘이 겹치지 않는지도 검사한다. 시뮬레이터는 xrun이다.</p>
 {fig("wave_full.png")}
 <p class="cap" style="margin:3pt 0 10pt">RTL 시뮬레이션 전체 파형. 8645 ns에 pc=0xAC로 종료하고 RAM[0..3]이 55, 65, 60, 165(0x37, 0x41, 0x3C, 0xA5)로 채워지며 err=0이다.</p>
 {fig("wave_uart.png")}
 <p class="cap" style="margin:3pt 0 10pt">UART 송신 확대. 루프백 모드에서 'A'(0x41)를 8N1로 송신한다. start bit(low) 뒤 LSB first로 1,0,0,0,0,0,1,0이 나가고 stop bit(high)로 끝난다. 비트당 640 ns다.</p>
 {fig("wave_spi.png")}
 <p class="cap" style="margin:3pt 0 10pt">SPI 전송 확대. 모드 0에서 master가 0xA5를 보내고 slave가 0x3C로 응답한다. SCLK 주기 160 ns, 상승 에지에서 8비트를 샘플한다.</p>
 <table style="font-size:9pt">
  <tr><th>검사 항목</th><th>기대값</th><th>결과</th></tr>
  <tr><td>RAM[0] / [1] / [2] / [3]</td><td>0x37 / 0x41 / 0x3C / 0xA5</td><td style="color:#1f7a3f;font-weight:700">일치</td></tr>
  <tr><td>UARTTXD 프레임, 데이터</td><td>1개, 0x41</td><td style="color:#1f7a3f;font-weight:700">일치</td></tr>
  <tr><td>SPI SCLK 상승 에지, MOSI, MISO</td><td>8개, 0xA5, 0x3C</td><td style="color:#1f7a3f;font-weight:700">일치</td></tr>
  <tr><td>APB stall / penable 횟수</td><td>같은 횟수(204), 겹침 없음</td><td style="color:#1f7a3f;font-weight:700">일치</td></tr>
  <tr><td>종료 pc, 시각, 오류</td><td>0xAC, 8645 ns, err=0</td><td style="color:#1f7a3f;font-weight:700">PASS tb_mcu_top</td></tr>
 </table>
</div>"""

import re as _re
def hl(t):
    out = []
    for ln in html.escape(t).split("\n"):
        i = ln.find("//")
        m = i if i >= 0 else (ln.find("#") if ln.lstrip().startswith("#") else -1)
        if m >= 0:
            ln = ln[:m] + '<span class="cm">' + ln[m:] + "</span>"
        out.append(ln)
    return "\n".join(out)

FIT = """<script>window.fitAll = () => { document.querySelectorAll('pre.fit').forEach(el => {
  let f = 7.2; el.style.fontSize = f + 'pt';
  while ((el.scrollHeight > el.clientHeight + 0.5 || el.scrollWidth > el.clientWidth + 0.5) && f > 2.5) { f -= 0.1; el.style.fontSize = f.toFixed(2) + 'pt'; }
}); };</script>"""

def fbox(h, title, text, wrap=False):
    ws = ' style="white-space:pre-wrap;word-break:break-all"' if wrap else ""
    return (f'<div class="cbox" style="position:relative;left:auto;top:auto;width:100%;height:{h}pt;margin-bottom:3pt">'
            f'<div class="ch">{html.escape(title)}</div><pre class="fit"{ws}>{hl(text)}</pre></div>')
sec8 = f"""
<h3 style="margin-top:0">(ii) Constraint</h3>
{code_file("3_SYN/cons/mcu_pad_top.sdc")}
{code_file("3_SYN/cons/dont_use_45nm.tcl")}
"""
p9 = f"""
<div class="page">
 <h3 style="margin-top:0">(iii) Timing Report (Setup)</h3>
 <p>클럭 10 ns(100 MHz)를 목표로 합성했다. 이 넷리스트가 P&amp;R 입력이다.</p>
 <table style="font-size:8.8pt">
  <tr><th>클럭</th><th>Critical slack</th><th>TNS / 위반 경로</th><th>인스턴스 (순차 / 조합)</th><th>코어 면적</th><th>칩 셀 면적</th></tr>
  <tr><td class="num" style="text-align:left">10 ns</td><td class="num">+2.3 ps</td><td class="num">0 / 0</td><td class="num">5,256 (1,816 / 3,440)</td><td class="num">21,856 µm²</td><td class="num">237,856 µm²</td></tr>
 </table>
 {fbox(505, "07_MAIN_CLOCK_post_syn_opt.rpt · 11~94행 (Path 1, 10 ns)", lines("3_SYN/report/07_MAIN_CLOCK_post_syn_opt.rpt", 11, 94))}
 <p class="cap" style="margin:2pt 0 0"><b style="color:var(--ink)">10 ns 최악 setup 경로.</b> <code>r_pc_reg_4</code>에서 명령어 ROM, CPU 디코드와 가산기, 주소 디코드를 지나 UART 블록의 <code>r_count_reg_4/D</code>까지 데이터 경로 9,789 ps, slack +2 ps(MET).</p>
 <table style="font-size:8.8pt;margin-top:8pt">
  <tr><th style="width:30%">Required Time</th><th>계산 (ps)</th></tr>
  <tr><td>캡처 클럭 도착</td><td class="num" style="text-align:left">10,000 (주기) + 200 (source latency) + 200 (network latency) = 10,400</td></tr>
  <tr><td>Required Time</td><td class="num" style="text-align:left">10,400 − 109 (setup) − 100 (uncertainty) = 10,191</td></tr>
  <tr><td>Arrival Time</td><td class="num" style="text-align:left">400 (launch 클럭) + 9,789 (data path) = 10,189</td></tr>
  <tr><td>Slack</td><td class="num" style="text-align:left">10,191 − 10,189 = +2 (MET)</td></tr>
 </table>
</div>"""
p10 = f"""
<div class="page">
 {fbox(420, "19_mcu_pad_top_SYN_qor.rpt · 10~51행", lines("3_SYN/report/19_mcu_pad_top_SYN_qor.rpt", 10, 51))}
 <p class="cap"><b style="color:var(--ink)">10 ns 합성 QoR.</b> Critical path slack +2.3 ps, TNS 0, 위반 경로 0. 인스턴스 5,256개(순차 1,816, 조합 3,440), 셀 면적 237,855 µm².</p>
 <ul style="font-size:10pt;margin:6pt 0 10pt">
  <li>최악 경로는 PC 레지스터 → 명령어 ROM → CPU 디코드 → 32비트 가산기 → 주소 디코드 → UART 블록으로 이어지는, 단일 사이클 구조의 가장 긴 조합 경로다.</li>
  <li>slack이 +2.3 ps로 거의 0인 것은 여유가 없는 것이 아니라, 10 ns 제약을 맞추는 선에서 툴이 남는 시간을 면적 최적화에 쓴 결과로 보인다.</li>
 </ul>
</div>"""

for nm in ("X55.png", "X56.png", "X57.png"):
    orig_img(11, nm).save(WORK / f"pre_{nm}")
_t = (TOP / "2_SIM/PRE/sdf_gate.log").read_text(errors="replace").split("\n")
_un = [l for l in _t if "Unable to annotate" in l]
_sg = (lines("2_SIM/PRE/sdf_gate.log", 1, 12) +
       f"\n\n# 같은 파일 집계\n'Unable to annotate'      : {len(_un)}건"
       f"\n그중 REMOVAL이 아닌 항목    : {sum('REMOVAL' not in l for l in _un)}건"
       f"\n에러(*E,)                  : {sum('*E,' in l for l in _t)}건")
p11 = f"""
<div class="page">
 <div class="bar">4. Pre-layout Simulation</div>
 <p style="font-size:10pt">합성 넷리스트(<code>mcu_pad_top_syn_final.v</code>)에 합성이 만든 SDF를 최대 지연(MAXIMUM) 기준으로 걸고, Function Simulation과 같은 테스트벤치로 검증했다. RAM과 pc 같은 내부 신호는 칩 핀에서 보이지 않으므로 칩 핀에서 볼 수 있는 항목(UART 프레임, SPI 바이트)만 검사한다. 내부 신호 검사는 RTL 시뮬레이션에서만 수행한다.</p>
 {fig("pre_X55.png")}
 <p class="cap" style="margin:3pt 0 9pt">Pre-layout 시뮬레이션 전체 파형(칩 핀 신호). UART 루프백 송신(0x41)과 SPI 전송(MOSI 0xA5, MISO 0x3C)이 Function Simulation 파형과 같은 순서로 나타나고 err=0이다. 첫 UARTTXD 하강은 RTL(525 ns)보다 1.773 ns 늦은 526.773 ns다(Baseline 마커).</p>
 <div style="display:flex;gap:9pt">
  <div style="flex:1;min-width:0">{fig("pre_X56.png")}<p class="cap" style="margin-top:3pt">UART 송신 확대. RTL과 같은 프레임(start 뒤 1,0,0,0,0,0,1,0, stop)이고 에지만 하강 +1.773 ns, 상승 +1.958 ns 늦다. 프레임 길이는 5760.185 ns다.</p></div>
  <div style="flex:1;min-width:0">{fig("pre_X57.png")}<p class="cap" style="margin-top:3pt">SPI 전송 확대. 8번째 SCLK 상승에서 mosi_byte=0xA5, miso_byte=0x3C가 완성된다. SCLK 상승이 RTL보다 1.392 ns 늦고 7주기 간격은 1.12 µs로 같다.</p></div>
 </div>
 <div style="display:flex;gap:9pt;margin-top:4pt">
  <div style="flex:1;min-width:0">{fbox(150, "2_SIM/PRE/pre_sim.log · 2364~2378행", lines("2_SIM/PRE/pre_sim.log", 2364, 2378))}
   <p class="cap">시뮬레이션 로그. UARTTXD 프레임 1개, 데이터 0x41, SCLK 상승 에지 8개, MOSI 0xA5, MISO 0x3C가 모두 ok이고 <code>PASS tb_mcu_top</code>으로 8645 ns에 종료했다.</p></div>
  <div style="flex:1;min-width:0">{fbox(150, "2_SIM/PRE/sdf_gate.log · 1~12행 + 집계", _sg)}
   <p class="cap">SDF 적용 로그(<code>sdf_gate.log</code>). 적용되지 않은 488건은 모두 비동기 리셋 플립플롭의 REMOVAL 검사이고 에러는 0건이다.</p></div>
 </div>
</div>"""

p19 = f"""
<div class="page">
 <div class="bar">6. 최종 타이밍 리포트 (Setup + Hold)</div>
 <p>최종 sign-off는 Tempus의 배선 후 STA다. Innovus postRoute 결과(setup +0.441 ns, hold +0.053 ns)와 정확히 일치한다.</p>
 {fbox(630, "tempus.log2 · report_timing -late, setup 최악 경로 (252~328행)", lines("5_PNR/tempus.log2", 252, 328))}
 <p class="cap"><b style="color:var(--ink)">Setup 최악 경로</b> (FUNC_SS_WORST, 클럭 10 ns): <code>r_pc_reg_7</code>에서 UART TX FIFO의 쓰기 enable(<code>uut5/uut2/r_mem_reg_13_3/E</code>)까지 약 50개 셀. Arrival 9.599 ns, Required 10.040 ns(10.000 − setup 0.203 − uncertainty 0.100 + 캡처 클럭 지연 0.343), slack +0.441 ns (MET).</p>
</div>"""
p20 = f"""
<div class="page">
 {fbox(230, "tempus.log2 · report_timing -early, hold 최악 경로 (330~351행)", lines("5_PNR/tempus.log2", 330, 351))}
 <p class="cap"><b style="color:var(--ink)">Hold 최악 경로</b> (FUNC_FF_BEST): SPI 슬레이브 2-FF 동기화기의 <code>r_mosi_s_reg_0</code>에서 <code>r_mosi_s_reg_1</code>로 가는 직결 경로. 도착 0.259 ns(CK→Q 0.057 + 클럭 지연 0.202), 요구 0.206 ns, slack +0.053 ns(MET).</p>
 <table style="font-size:9.2pt;margin-top:8pt">
  <tr><th style="width:20%">항목</th><th>Setup (SS_WORST)</th><th style="width:30%">Hold (FF_BEST)</th></tr>
  <tr><td>WNS</td><td class="num">+0.441 ns</td><td class="num">+0.053 ns</td></tr>
  <tr><td>TNS / 위반 경로</td><td class="num">0 / 0</td><td class="num">0 / 0</td></tr>
  <tr><td>분석 커버리지</td><td class="num">3,144 / 3,144 Met</td><td class="num">3,144 / 3,144 Met</td></tr>
  <tr><td>최악 경로</td><td>PC → ROM → CPU 가산기 → 주소 디코드 → UART FIFO enable</td><td>SPI 슬레이브 동기화기 FF 직결</td></tr>
  <tr><td>DRC / 연결성</td><td colspan="2" class="num">0 viol. / 0 viol. (필러 삽입 후)</td></tr>
 </table>
 <ul style="font-size:10pt">
  <li>setup 최악 경로는 합성 때부터 보이던 PC → ROM → CPU 가산기 → 주소 디코드 → FIFO enable 경로이고 배선 후에도 그대로 최악이다.</li>
  <li>hold +53 ps는 얇아 보이지만 플립플롭끼리 직결된 경로의 구조적 최소값(CK→Q 0.057 ns에서 hold 시간 0.004 ns를 뺀 값)에 가깝다.</li>
 </ul>
</div>"""

def one(html_text, name):
    r = render(doc(html_text + FIT), name)
    assert len(r.pages) == 1, f"{name} overflowed: {len(r.pages)}"
    return r
SEC = {6: one(p6, "sec6"), 9: one(p9, "sec9"), 10: one(p10, "sec10"), 11: one(p11, "sec11"),
       19: one(p19, "sec19"), 20: one(p20, "sec20"),
       7: render(doc(sec7), "sec7", M), 8: render(doc(sec8), "sec8", M), 13: render(doc(sec13), "sec13", M)}
FE_SEQ = [2, 3, 4, 6, 7, 8, 9, 10, 11, 12]
BE_SEQ = [13, 14, 15, 16, 17, 18, 19, 20]
def start(seq, k):
    n = 2
    for j in seq:
        if j == k: return n
        n += len(SEC[j].pages) if j in SEC else 1
imp_pg = start(BE_SEQ, 13) + find_page(WORK / "sec13.pdf", "2. Import 파일 정리")
cover_fe = cover("Front-End", "Front-End",
    SPEC + [("Tool", "xrun · Genus"), ("Flow", "RTL → Function Simulation → Synthesis → Pre-layout Simulation")],
    [("10 ns", "최종 클럭 (100 MHz)"), ("+2.3 ps", "10 ns 합성 slack (TNS 0)"),
     ("PASS", "Function Simulation (RTL)"), ("PASS", "Pre-layout Simulation")],
    [("1. Design Logic Diagram", start(FE_SEQ, 2)), ("2. Function Simulation", start(FE_SEQ, 6)),
     ("3. Synthesis", start(FE_SEQ, 7)),
     ("4. Pre-layout Simulation", start(FE_SEQ, 11))],
    None)
cover_be = cover("Back-End", "Back-End",
    SPEC + [("Tool", "Innovus · Tempus"), ("Input", "Synthesis Netlist · SDC (10 ns)"),
            ("Flow", "Floorplan → Power Plan → Place → CTS → Route → Chip Finish → STA")],
    [("+0.441 / +0.053 ns", "postRoute setup / hold WNS"), ("0 viol.", "verify_drc, verifyConnectivity (필러 후)"),
     ("176 / 706", "삽입 셀: 클럭 트리 / 최적화"), ("3,144 Met", "Tempus setup·hold 검사, 위반 0")],
    [("1. APR 전 과정 Script", start(BE_SEQ, 13)), ("2. Import 파일 정리", imp_pg),
     ("3. 단계별 캡처", start(BE_SEQ, 14)),
     ("4. Nano Routing 후 타이밍 리포트 (Setup + Hold)", start(BE_SEQ, 17)),
     ("5. STA 전후의 Hold Timing 변화와 Buffer Insertion", start(BE_SEQ, 17)),
     ("6. 최종 타이밍 리포트 (Setup + Hold)", start(BE_SEQ, 19))],
    None)
COV = {"fe": one(cover_fe, "cover_fe"), "be": one(cover_be, "cover_be")}

# ---------------------------------------------------------------- overlays
def white(x, y, w, h):
    return f'<div class="ov" style="left:{x}pt;top:{y}pt;width:{w}pt;height:{h}pt;background:#fff"></div>'

def head(y, txt, code):
    return (white(36, y - 3, 523.5, 17.5) +
            f'<div class="ov" style="left:36.75pt;top:{y - 2.8}pt;width:521.75pt;color:#0a5f5a;font-size:11.2pt;font-weight:700;line-height:1.2;'
            f'padding-bottom:2pt;border-bottom:1.3pt solid #0a5f5a">{txt} '
            f'(<code style="font-size:9.4pt;font-weight:400">{code}</code>)</div>')

L, Wd = 36.75, 521.75
OV = {}
OV[12] = (white(36, 256.55, 523.5, 22) + white(36, 280, 523.5, 70) + white(36, 354, 523.5, 60.5) +
          f'<ul class="ov" style="left:{L}pt;top:283pt;width:{Wd}pt;margin:0;padding-left:15pt;font-size:10.3pt;line-height:1.6">'
          '<li>두 시뮬레이션의 결과 데이터와 순서는 같고, 에지 시각만 1~2 ns 뒤로 밀린다. 이 밀림이 합성 SDF에서 생긴 타이밍 차이의 전부다.</li>'
          '<li style="margin-top:3pt">pre-layout 시뮬은 클럭 트리와 실제 배선 지연이 없는 합성 시점의 지연이다.</li></ul>')
OV[14] = head(120.2, "① Init / Floorplan", "0_InitDesign.tcl + init.io") + head(430.9, "② Power plan", "1_PowerPlan.tcl")
OV[15] = head(43.7, "③ Place", "2_PlaceOpt.tcl") + head(454.9, "④ CTS", "3_PostCTSopt.tcl")
OV[16] = (head(43.9, "⑤ Route", "4_RouteDesign_PowerAnalysis.tcl") 
          + head(339.9, "⑥ Filler / 출력", "5_ChipFinish.tcl"))
OV[18] = (f'<div class="ov" style="left:{L}pt;top:512pt;width:{Wd}pt">'
          '<div style="font-weight:700;font-size:10pt;margin-bottom:4pt">삽입 셀 개수 (최종 P&amp;R 넷리스트 <code>mcu_pad_top.v</code>의 인스턴스 이름 기준)</div>'
          '<table><tr><th style="width:22%">종류</th><th>이름 접두어와 셀</th><th style="width:12%">개수</th></tr>'
          '<tr><td>클럭 트리 (CTS)</td><td><code>CTS_ccl_a</code> 148, <code>CTS_csf_buf</code> 14, <code>CTS_ccl_buf</code> 7, <code>CTS_cpc_drv</code> 7</td><td class="num">176</td></tr>'
          '<tr><td>최적화 버퍼</td><td><code>FE_OFC</code> BUF 296, CLKBUF 24</td><td class="num">320</td></tr>'
          '<tr><td>최적화 인버터</td><td><code>FE_OFC</code> INV 205, INVXL 132, CLKINV 43</td><td class="num">380</td></tr>'
          '<tr><td>기타 최적화</td><td><code>FE_PDC</code> BUF</td><td class="num">6</td></tr>'
          '<tr><td>Hold 지연 버퍼</td><td><code>FE_PHC</code> (hold fix 셀)</td><td class="num">0</td></tr>'
          '<tr><th colspan="2">합계</th><th class="num">882</th></tr></table>'
          '<div class="cap">CTS 176개는 단계별 캡처(CTS)의 클럭 버퍼 수와 같다. 최적화 셀 706개는 preCTS의 setup 위반과 max_tran 위반을 고치면서 들어왔다. hold를 맞추려는 셀은 없다.</div></div>')


def cbox(x, y, w, h, title, text, wrap=False):
    ws = ' style="white-space:pre-wrap;word-break:break-all"' if wrap else ""
    return (f'<div class="cbox" style="left:{x}pt;top:{y}pt;width:{w}pt;height:{h}pt">'
            f'<div class="ch">{html.escape(title)}</div><pre class="fit"{ws}>{hl(text)}</pre></div>')

def rl(rel, a, b):
    return f"{PROJ}/TOP/{rel} · {a}~{b}행", lines(rel, a, b)

def add(k, frag):
    OV[k] = OV.get(k, "") + frag


def lg(rel, *ranges, label=None):
    parts = [lines(rel, a, b) for a, b in ranges]
    rng = ", ".join(f"{a}~{b}" for a, b in ranges)
    return (label or f"{PROJ}/TOP/{rel} · {rng}행"), "\n...\n".join(parts)

# FE: 10 ns synthesis reports, Conformal log and pre-sim logs (files exist in the repo).
# The 2.5 ns reports (p10 top) are not in the repo and stay as captures; the schematic stays as is.



# BE: report/log captures replaced by excerpts of the logs they came from
add(17, cbox(37.5, 117.0, 255.8, 179.2, *lg("5_PNR/innovus.log10", (4871, 4899), label="innovus.log10 · timeDesign -postRoute (4871~4899행)")))
add(17, cbox(302.2, 117.0, 255.8, 111.0, *lg("5_PNR/innovus.log10", (4927, 4944), label="innovus.log10 · timeDesign -postRoute -hold (4927~4944행)")))
add(17, cbox(37.5, 642.8, 255.8, 114.0, *lg("5_PNR/tempus.log", (229, 229), (243, 250), label="tempus.log · check_timing (229, 243~250행)")))
add(17, cbox(302.2, 642.8, 255.8, 120.0, *lg("5_PNR/tempus.log", (281, 294), label="tempus.log · report_analysis_coverage (281~294행)")))
add(18, cbox(37.5, 40.5, 520.5, 227.2, *lg("5_PNR/tempus.log2", (330, 351), label="tempus.log2 · report_timing -early, hold 최악 경로 (330~351행)")))

add(2, white(289.0, 528.6, 11.5, 11.2) +
       '<div class="ov" style="left:289.2pt;top:528.2pt;font-size:9.1pt;line-height:1.2;letter-spacing:0">10</div>')
add(16, white(300, 149.3, 259, 84))
add(18, white(36, 435, 523.5, 49) +
    '<div class="ov" style="left:39pt;top:437pt;width:519pt;font-size:10.3pt;line-height:1.6;padding-left:11pt;text-indent:-11pt">'
    '•&nbsp; <b>최적화 버퍼</b>: setup 최악 경로에 <code>FE_OFC*</code> 이름의 버퍼·인버터가 다수 보인다(최종 타이밍 리포트의 setup 경로). 개수는 아래 표에 정리했다.</div>')

# BE p15 (4-c CTS): add the layout snapshot saved by 3_PostCTSopt.tcl (snap/3_cts.png),
# shade-inverted like the other GUI captures (luminance inverted, colour kept)
from PIL import ImageOps
_y, _cb, _cr = Image.open(TOP / "5_PNR/snap/3_cts.png").convert("RGB").convert("YCbCr").split()
Image.merge("YCbCr", (ImageOps.invert(_y), _cb, _cr)).convert("RGB").save(WORK / "cts_snap.png")
orig_img(15, "X77.png").save(WORK / "clock_tree.png")
add(15, white(35, 470, 263, 372) + white(299, 646, 262, 196) +
    f'<img class="ov" src="{(WORK / "cts_snap.png").as_uri()}" style="left:36.5pt;top:473.8pt;width:257.8pt;height:230.8pt;border:0.75pt solid #555">'
    '<div class="ov cap" style="left:37.3pt;top:707pt;width:256pt;font-size:8.4pt;line-height:1.55">CTS 후 레이아웃(<code>3_PostCTSopt.tcl</code>이 저장한 <code>snap/3_cts.png</code>, 음영 반전).</div>'
    '<div class="ov note" style="left:36.5pt;top:738pt;width:257.8pt;font-size:8.6pt;padding:5pt 8pt;line-height:1.55">스크립트의 목표 스큐(0.01 ns)는 맞추지 못했다. 0.165 ns는 10 ns 주기의 약 1.7%이고 setup, hold 모두 통과해 그대로 두었다.</div>'
    f'<img class="ov" src="{(WORK / "clock_tree.png").as_uri()}" style="left:301.2pt;top:650pt;width:257.5pt;border:0.75pt solid #555">'
    '<div class="ov cap" style="left:302pt;top:789pt;width:256pt;font-size:8.4pt;line-height:1.55">클럭 트리. 루트 <code>clk</code>에서 클럭 버퍼 176개가 플립플롭 1,816개(posedge 1,799, negedge 17)에 분배한다. 최대 leaf fanout 20.</div>')

# FE p4: RTL code excerpts are not in the guideline -> replaced by the embedded-program table (from old p5)
add(4, white(36, 284, 523.5, 540) +
    f'<div class="ov" style="left:{L}pt;top:288pt;width:{Wd}pt">'
    '<h3 style="margin-top:0">내장 프로그램 (RTL 시뮬레이션 실측)</h3>'
    '<table style="font-size:9pt"><tr><th style="width:24%">단계</th><th style="width:20%">시각</th><th>일어난 일</th></tr>'
    '<tr><td>① 1~10 합계</td><td class="num">0 ~ 355 ns</td><td>add, addi, bne 루프 10바퀴, RAM[0]=0x37(55)</td></tr>'
    '<tr><td>② UART 설정, 송신 요청</td><td class="num">395 ~ 495 ns</td><td>UARTIBRD=4, UARTCR=0x381, UARTDR=0x41</td></tr>'
    '<tr><td>③ 송신, 루프백 수신</td><td class="num">495 ~ 6685 ns</td><td>525 ns에 UARTTXD 하강, 수신 완료 후 RAM[1]=0x41</td></tr>'
    '<tr><td>④ SPI 설정</td><td class="num">6735 ~ 6855 ns</td><td>슬레이브 SSDR=0x3C, 마스터 SPDR=0xA5(전송 시작)</td></tr>'
    '<tr><td>⑤ SPI 전송</td><td class="num">6855 ~ 8365 ns</td><td>SCLK 8개(160 ns 주기), RAM[2]=0x3C</td></tr>'
    '<tr><td>⑥ 슬레이브 확인</td><td class="num">8365 ~ 8455 ns</td><td>받은 0xA5를 읽어 RAM[3]=0xA5, 이후 <code>j 0xAC</code>로 제자리 점프(종료)</td></tr></table>'
    '<p style="font-size:9.6pt">리셋 해제 후 pc=0xAC 도달까지 843클럭, APB 접근 204회(대부분 상태 레지스터 폴링)다. CPU가 하는 일의 대부분이 대기라서 합성과 P&amp;R에서는 프로그램 속도가 아니라 회로 전체의 가장 긴 경로가 중요하다.</p>'
    '</div>')

def rebar(y0, y1, txt):
    return (f'<div class="ov" style="left:36.75pt;top:{y0}pt;width:521.75pt;height:{y1-y0}pt;background:#0a5f5a;border-radius:3pt;'
            f'color:#fff;font-weight:700;font-size:14pt;line-height:{y1-y0}pt;padding-left:9pt;letter-spacing:-0.2pt">{txt}</div>')
add(2, rebar(40.0, 70.5, "1. Design Logic Diagram"))
add(12, white(36, 41, 420, 16) + '<div class="ov" style="left:37.5pt;top:41.5pt;color:#0a5f5a;font-weight:700;font-size:11.2pt">Function Simulation과 비교: 타이밍으로 생긴 차이</div>')
add(14, rebar(40.0, 70.5, "3. 단계별 캡처"))
add(17, rebar(40.0, 70.5, "4. Nano Routing 후 타이밍 리포트 (Setup + Hold)") + rebar(581.5, 612.0, "5. STA 전후의 Hold Timing 변화와 Buffer Insertion"))

order = sorted(OV)
ov_html = "".join(f'<div class="page" style="background:transparent;padding:0">{OV[k]}</div>' for k in order)

ov_pdf = render(doc(ov_html + FIT), "overlays")
assert len(ov_pdf.pages) == len(order)

# ---------------------------------------------------------------- merge
def book(cover, seq, out):
    w = pypdf.PdfWriter()
    w.add_page(cover.pages[0])
    for k in seq:
        if k in SEC:
            for pg in SEC[k].pages: w.add_page(pg)
            continue
        w.add_page(orig.pages[k - 1])
        if k in OV:
            w.pages[-1].merge_page(ov_pdf.pages[order.index(k)])
    w.add_metadata({"/Title": out.stem})
    with open(out, "wb") as f:
        w.write(f)
    return len(w.pages)

OUTDIR.mkdir(parents=True, exist_ok=True)
fe = OUTDIR / "Park_Heeseo_project_FE_portfolio.pdf"
be = OUTDIR / "Park_Heeseo_project_BE_portfolio.pdf"
print("FE pages", book(COV["fe"], FE_SEQ, fe), "BE pages", book(COV["be"], BE_SEQ, be))
