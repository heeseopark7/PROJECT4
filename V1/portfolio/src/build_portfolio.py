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

# ---------------------------------------------------------------- appendix (rendered first: page numbers go into the TOC)
appx_fe = f"""
<div class="bar">부록 S1 · 합성 실행 스크립트 원문 (3-c-i)</div>
<p>10 ns 최종 합성(11/19 00:16~00:21, <code>3_SYN/log/all.log</code>)에 쓴 파일을 그대로 옮겼다. <code>3_SYN</code>에서 <code>./run_synthesis</code>를 실행하면 Genus가 <code>syn_mcu_pad_top.tcl</code>을 처음부터 끝까지 실행한다.
같은 폴더의 <code>syn_mcu_pad_top_mmmc.tcl</code>은 다른 설계용 수업 템플릿으로, 실행에 쓰지 않았다.</p>
{code_file("3_SYN/run_synthesis")}
{code_file("3_SYN/script/syn_mcu_pad_top.tcl")}
<div style="break-before: page"></div>
<div class="bar">부록 S2 · 10 ns 최종 SDC 원문 (3-c-ii)</div>
<p>합성 스크립트가 <code>source -verbose ./cons/mcu_pad_top.sdc</code>로 읽는다. 10 ns 최종 합성과 P&amp;R에 들어간 상태 그대로다.
입력 구동은 <code>set_driving_cell PADDI</code>로 칩 입력을 PADDI 패드 셀이 구동한다고 가정하고, 출력 부하는 <code>PADDO/A</code> 입력 용량으로 둔다. 64~66행 위의 주석("instead of the PADDI cell")은 실제로 켜진 줄과 맞지 않는 남은 주석이다.</p>
{code_file("3_SYN/cons/mcu_pad_top.sdc")}
{code_file("3_SYN/cons/dont_use_45nm.tcl", "SDC 바로 뒤에 source한다. 지연, 홀드, 타이, 스캔 플립플롭 셀을 합성에서 쓰지 않게 막는다.")}
"""
appx_be = f"""
<div class="bar">부록 D · APR 스크립트 원문 (4-a)</div>
<p>Innovus 22.17-s086_1에서 단계별로 실행했다. 각 스크립트는 앞 단계 DB를 <code>restoreDesign</code>으로 열고 <code>saveDesign</code>으로 다음 DB를 남긴다.
실행 기록(<code>innovus.cmd*</code>)과 대조해 일치함을 확인했다. 실행 뒤 바뀐 곳은 3_PostCTSopt.tcl의 <code>file mkdir snap</code> 삭제와 5_ChipFinish.tcl의 <code>saveNetlist -flat</code>에서 <code>-flat</code> 제거(post-layout 시뮬 SDF 적용 문제 해결, 부록 A) 두 곳이다.</p>
{code_file("5_PNR/0_InitDesign.tcl")}
{code_file("5_PNR/init.io", "0_InitDesign.tcl의 init_io_file. 변마다 12슬롯, 48슬롯 패드 링과 코너 셀 4개의 위치를 정한다.")}
{code_file("5_PNR/1_PowerPlan.tcl")}
{code_file("5_PNR/2_PlaceOpt.tcl")}
{code_file("5_PNR/3_PostCTSopt.tcl")}
{code_file("5_PNR/4_RouteDesign_PowerAnalysis.tcl")}
{code_file("5_PNR/5_ChipFinish.tcl")}
<div style="break-before: page"></div>
<div class="bar">부록 E · Import 설정 원문 (4-b)</div>
<p><code>0_InitDesign.tcl</code>의 <code>init_mmmc_file</code>이다. setup은 FUNC_SS_WORST, hold는 FUNC_FF_BEST로 본다. 첫 실행 로그(<code>5_PNR/innovus.log</code>)에서 아래 파일을 모두 읽은 것을 확인했다.</p>
{code_file("5_PNR/mcu_pad_top.mmmc.view")}
{code_file("5_PNR/add_pad", "P&amp;R에 넣은 넷리스트는 11/10 합성 출력의 endmodule 앞에 이 전원 패드 16개를 붙인 파일이다. 현재 3_SYN/mapped의 넷리스트(11/19 재합성)에는 이 16줄이 없으므로, 0_InitDesign.tcl을 다시 돌릴 때는 다시 붙여야 한다.")}
"""
orig = pypdf.PdfReader(str(ORIG))
FE_ORIG = list(range(2, 13))     # original pages in the FE book (after its cover)
BE_ORIG = list(range(13, 23))    # original pages in the BE book

def find_page(path, needle):
    d = pypdfium2.PdfDocument(str(path))
    for i in range(len(d)):
        if needle in d[i].get_textpage().get_text_range():
            return i
    raise SystemExit(f"not found: {needle}")

M = {"top": "53.33px", "bottom": "45.33px", "left": "49px", "right": "48.67px"}
afe = render(doc(appx_fe, "body{background:#fff}"), "appendix_fe", M)
abe = render(doc(appx_be, "body{background:#fff}"), "appendix_be", M)
FE0 = 1 + len(FE_ORIG)
BE0 = 1 + len(BE_ORIG)
S = {"S1": FE0 + 1 + find_page(WORK / "appendix_fe.pdf", "부록 S1"),
     "S2": FE0 + 1 + find_page(WORK / "appendix_fe.pdf", "부록 S2"),
     "D": BE0 + 1 + find_page(WORK / "appendix_be.pdf", "부록 D"),
     "E": BE0 + 1 + find_page(WORK / "appendix_be.pdf", "부록 E")}
bp = lambda k: k - 11            # original page k -> page number in the BE book

# ---------------------------------------------------------------- page 1 (cover)
def tile(v, cap):
    return (f'<td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">{v}</div>'
            f'<div class="cap">{cap}</div></td>')

def cover(part, part_ko, lead, tiles, rows, flow):
    tr = "".join(f'<tr><td>{a}</td><td>{b}</td></tr>' for a, b in rows)
    return f"""
<div class="page" style="padding-top:120pt">
 <div class="mono" style="background:none;padding:0;color:var(--teal);font-size:7.8pt">Physical Implementation 포트폴리오</div>
 <div style="font-size:27pt;font-weight:700;margin:6pt 0 0;letter-spacing:-0.6pt">{PROJ}</div>
 <div style="font-size:13pt;font-weight:600;color:var(--teal);margin:0 0 8pt">MCU RTL to GDS2 · {part_ko}</div>
 <p style="font-size:11.4pt;line-height:1.65;color:#3f4b52">{lead}</p>
 <div class="note" style="font-size:9pt">RTL은 Claude의 도움을 받아 작성했고 코드 구조는 설명할 수 있는 수준으로 이해했다. RTL 시뮬레이션, 합성, P&amp;R은 직접 수행했다.</div>
 <table style="table-layout:fixed;margin:6pt 0 16pt"><tr>{"".join(tile(*t) for t in tiles)}</tr></table>
 <h3 style="margin-top:0">구성</h3>
 <table><tr><th>항목</th><th style="width:9%">쪽</th></tr>{tr}</table>
 <p style="font-size:10.4pt;color:#3f4b52;margin-top:10pt">{flow}</p>
</div>"""

LEAD = ("단일 사이클 MIPS CPU, APB 브리지, UART, SPI 마스터/슬레이브를 담은 MCU를 RTL 시뮬레이션부터 합성, 등가성 검사, "
        "P&amp;R, STA, post-layout 시뮬레이션까지 진행해 GDS2를 만든 기록이다. 클럭 10 ns(100 MHz) 기준, 공정은 GPDK045. ")
cover_fe = cover("Front-End", "Front-End",
    LEAD + "이 권은 설계 스펙부터 합성, 등가성 검사, pre-layout 시뮬레이션까지(가이드라인 3)를 다룬다. P&amp;R 이후는 BE 포트폴리오에 있다.",
    [("10 ns", "최종 클럭 (100 MHz)"), ("+2.3 ps", "10 ns 합성 slack (TNS 0)"),
     ("PASS", "Conformal RTL ↔ 합성"), ("PASS", "RTL · pre-layout 시뮬")],
    [("3-a 설계 논리 다이어그램과 스펙", 2), ("3-b 기능 시뮬레이션 (파형)", 6),
     ("3-c 합성 (실행 스크립트, 제약, setup 타이밍 리포트)", 7),
     ("3-d Pre-layout 시뮬레이션 (3-b와 동일 검증, 타이밍으로 생긴 차이)", 11),
     ("부록 S1 합성 실행 스크립트 원문 (run_synthesis, syn_mcu_pad_top.tcl)", S["S1"]),
     ("부록 S2 10 ns 최종 SDC 원문 (mcu_pad_top.sdc, dont_use_45nm.tcl)", S["S2"])],
    "FE 플로우: xrun(RTL 시뮬) → Genus(합성) → Conformal(RTL↔합성) → xrun(pre-layout, 합성 SDF).")
cover_be = cover("Back-End", "Back-End",
    LEAD + "이 권은 P&amp;R부터 STA, post-layout 시뮬레이션까지(가이드라인 4)를 다룬다. 입력은 FE 포트폴리오의 10 ns 합성 넷리스트와 SDC다.",
    [("+0.441 / +0.053 ns", "postRoute setup / hold WNS"), ("0 viol.", "verify_drc, verifyConnectivity (필러 후)"),
     ("176 / 706", "삽입 셀: 클럭 트리 / 최적화"), ("PASS", "post-layout 시뮬, 합성↔PnR 등가성")],
    [("4-a APR 전 과정 스크립트 · 4-b Import 파일 정리", bp(13)), ("4-c 단계별 캡처 (고대비, 음영 반전)", bp(14)),
     ("4-d NanoRoute 후 타이밍 리포트 (Setup + Hold)", bp(17)),
     ("4-e STA 전후의 Hold 타이밍 변화와 버퍼 삽입 (삽입 셀 개수)", bp(17)),
     ("4-f ECO 수행 과정", bp(19)), ("4-g 최종 타이밍 리포트 (Setup + Hold)", bp(19)),
     ("부록 A~C post-layout 시뮬레이션, 등가성 검사, 한계", bp(21)),
     ("부록 D APR 스크립트 원문 (0_InitDesign.tcl ~ 5_ChipFinish.tcl, init.io)", S["D"]),
     ("부록 E Import 설정 원문 (mcu_pad_top.mmmc.view, add_pad)", S["E"])],
    "BE 플로우: Innovus(P&amp;R) → Conformal(합성↔PnR) → Tempus(STA) → xrun(post-layout, worst/best).")

# ---------------------------------------------------------------- page 7 (3-c-i)
syn_excerpt = lines("3_SYN/script/syn_mcu_pad_top.tcl", 25, 36)
syn_flow = "\n".join([
    lines("3_SYN/script/syn_mcu_pad_top.tcl", 73, 75), "...",
    lines("3_SYN/script/syn_mcu_pad_top.tcl", 87, 87), lines("3_SYN/script/syn_mcu_pad_top.tcl", 89, 89), "...",
    lines("3_SYN/script/syn_mcu_pad_top.tcl", 107, 108), "...",
    "syn_generic\nsyn_map\nsyn_opt", "...",
    lines("3_SYN/script/syn_mcu_pad_top.tcl", 212, 215)])
p7 = f"""
<div class="page">
 <div class="bar">FE · 3-c 합성 (Genus, GPDK045 slow 코너)</div>
 <h3>(i) 합성 실행 스크립트</h3>
 <p>합성은 <code>3_SYN</code> 폴더에서 <code>./run_synthesis</code>로 실행했다. 이 csh 래퍼가 <code>genus -f ./script/syn_mcu_pad_top.tcl -log ./log/all.log</code>를 부르고 시작·종료 시각을 <code>cds_syn_runtime</code>에 남긴다.
 라이브러리는 slow 코너만 읽는다: 표준 셀 <code>slow_vdd1v0_basicCells.lib</code>, <code>slow_vdd1v0_multibitsDFF.lib</code>와 패드 <code>pads_SS_s1vg.lib</code>. hold용 fast 라이브러리는 P&amp;R의 MMMC에서 따로 읽는다.</p>
 <table>
  <tr><th style="width:12%">단계</th><th style="width:44%">스크립트 안의 명령</th><th>산출물</th></tr>
  <tr><td>설정</td><td><code>read_libs</code>, <code>read_physical -lef</code>, <code>read_qrc</code>, effort high ×3</td><td>slow 단일 코너 라이브러리, LEF, QRC</td></tr>
  <tr><td>로드</td><td><code>read_hdl</code>(RTL 21개), <code>elaborate</code>, <code>uniquify</code>, <code>check_design</code></td><td><code>00_check_design.rpt</code></td></tr>
  <tr><td>제약</td><td><code>source cons/mcu_pad_top.sdc</code>, <code>dont_use_45nm.tcl</code></td><td><code>01_check_timing_intent</code>, <code>02_report_port</code></td></tr>
  <tr><td>합성</td><td><code>syn_generic</code> → <code>syn_map</code> → <code>syn_opt</code></td><td><code>03~07</code> 리포트, <code>syn_map.db</code>, <code>syn_opt.db</code></td></tr>
  <tr><td>리포트</td><td><code>report_area</code>, <code>report_qor</code>, <code>report_timing -nworst 100</code> 등 13종</td><td><code>08~20</code> 리포트</td></tr>
  <tr><td>출력</td><td><code>write_design</code>, <code>write_hdl</code>, <code>write_sdc</code>, <code>write_sdf</code></td><td><code>mcu_pad_top_syn_final.v / .sdc</code>, <code>_delays.sdf</code></td></tr>
 </table>
 <div class="fh"><span>syn_mcu_pad_top.tcl · 설정부 (25~36행)</span><span>10 ns 최종 실행본</span></div>
 <pre class="code">{html.escape(syn_excerpt)}</pre>
 <div class="fh"><span>syn_mcu_pad_top.tcl · 흐름 요약 (발췌)</span><span>233 lines</span></div>
 <pre class="code">{html.escape(syn_flow)}</pre>
 <div class="note"><b class="l">원문 수록.</b> 스크립트 전문(233줄)과 <code>run_synthesis</code>는 부록 S1(p.{S['S1']})에 그대로 실었다. 10 ns 최종 실행 기록은 <code>log/all.log</code>(11/19 00:16~00:21)이고, 결과는 00~20번 리포트로 남겼다.
</div>
</div>"""

# ---------------------------------------------------------------- page 13 (4-a, 4-b)
p13 = f"""
<div class="page p13">
 <div class="bar">BE · 4-a APR 전 과정 스크립트 · 4-b Import 파일 정리</div>
 <h3>4-a 스크립트 구성</h3>
 <p>P&amp;R은 Innovus에서 단계별 Tcl 스크립트로 진행했다. 각 단계는 앞 DB를 <code>restoreDesign</code>으로 열고, 끝에서 <code>saveDesign</code>으로 저장한 뒤 타이밍, DRC, 연결성을 확인했다.</p>
 <table>
  <tr><th style="width:27%">스크립트</th><th style="width:20%">DB (입력 → 출력)</th><th>주요 명령</th></tr>
  <tr><td><code>0_InitDesign.tcl</code><br><code>init.io</code></td><td>넷리스트 → InitDesign</td><td><code>init_design</code>, <code>checkDesign</code>, <code>floorPlan -r 1 0.6 352×4</code>, 전원 패드 <code>placeInstance</code>, <code>addIoFiller</code>, <code>timeDesign -prePlace</code></td></tr>
  <tr><td><code>1_PowerPlan.tcl</code></td><td>InitDesign → PowerPlan</td><td><code>globalNetConnect</code>, <code>addRing</code> 2중(offset 5 / 200, Metal10/11), <code>sroute</code>(corePin, padPin), <code>addStripe</code> 3회, <code>verify_drc</code>, <code>verifyConnectivity</code></td></tr>
  <tr><td><code>2_PlaceOpt.tcl</code></td><td>PowerPlan → PlaceOpt</td><td><code>place_design</code>, <code>checkPlace</code>, <code>earlyGlobalRoute</code>, <code>place_opt_design</code>, <code>timeDesign -preCTS</code></td></tr>
  <tr><td><code>3_PostCTSopt.tcl</code></td><td>PlaceOpt → PostCTSopt</td><td><code>target_skew 0.01</code>, <code>ccopt_design</code>, <code>set_propagated_clock</code>, <code>optDesign -postCTS</code> (+ <code>-hold</code>)</td></tr>
  <tr><td><code>4_RouteDesign_</code><br><code>PowerAnalysis.tcl</code></td><td>PostCTSopt → RouteDesign</td><td>NanoRoute <code>routeDesign -globalDetail</code>, <code>optDesign -postRoute -drv/-setup/-hold</code>(bcwc), <code>extractRC</code>, <code>report_power</code></td></tr>
  <tr><td><code>5_ChipFinish.tcl</code></td><td>RouteDesign → ChipFinish</td><td><code>addFiller</code>, <code>verify_drc</code>, <code>verifyConnectivity</code>, <code>saveNetlist</code>, <code>write_sdf</code>, <code>writeTimingCon</code>, <code>streamOut</code></td></tr>
 </table>
 <div class="note"><b class="l">원문 수록.</b> 6개 스크립트와 init.io 원문은 부록 D(p.{S['D']})에 있다. 실행 기록(<code>innovus.cmd*</code>)과 대조해 floorplan 값, 패드 좌표, 링 offset, CTS 목표 스큐, postRoute 분석 모드가 일치함을 확인했다.</div>
 <h3>4-b Import 파일 (init 단계에서 실제로 읽은 파일, <code>innovus.log</code> 기준)</h3>
 <table>
  <tr><th style="width:17%">종류</th><th style="width:47%">파일</th><th>출처 / 비고</th></tr>
  <tr><td>넷리스트</td><td><code>../3_SYN/mapped/mcu_pad_top_syn_final.v</code></td><td>Genus 10 ns 출력(11/10) + 전원 패드 16개(<code>add_pad</code>)</td></tr>
  <tr><td>타이밍 제약</td><td><code>../3_SYN/mapped/mcu_pad_top_syn_final.sdc</code></td><td>Genus <code>write_sdc</code> 출력, 10 ns. 입력 구동은 <code>set_driving_cell PADDI</code></td></tr>
  <tr><td>IO 배치</td><td><code>init.io</code></td><td>48슬롯, 코너 셀 4개. 표 <code>IO_Cell_Map_mcu_pad_top.xlsx</code> 기준으로 작성</td></tr>
  <tr><td>타이밍 lib (SS)</td><td><code>slow_vdd1v0_basicCells.lib</code>, <code>slow_vdd1v0_multibitsDFF.lib</code>, <code>pads_SS_s1vg.lib</code></td><td>setup, FUNC_SS_WORST (0.9 V, 125°C)</td></tr>
  <tr><td>타이밍 lib (FF)</td><td><code>fast_vdd1v0_basicCells.lib</code>, <code>fast_vdd1v0_multibitsDFF.lib</code>, <code>pads_FF_s1vg.lib</code></td><td>hold, FUNC_FF_BEST (1.1 V, 0°C)</td></tr>
  <tr><td>LEF</td><td><code>gsclib045_tech.lef</code>(gsclib045_tech/lef), <code>gsclib045_macro.lef</code>, <code>gsclib045_multibitsDFF.lef</code>, <code>giolib045_modify.lef</code></td><td>GPDK045 gsclib045 v4.4, giolib045 v3.5</td></tr>
  <tr><td>RC</td><td><code>gpdk045.tch</code>(gsclib045/qrc/qx) + cap table <code>…typical.capTbl</code></td><td>rc_corner BEST(T 0), WORST(T 125)</td></tr>
  <tr><td>View</td><td>constraint_mode FUNC, view FUNC_SS_WORST / FUNC_FF_BEST</td><td><code>mcu_pad_top.mmmc.view</code>(부록 E)</td></tr>
 </table>
 <div class="chk"><b class="l">합성과 대조.</b> 타이밍 lib(slow 3종)는 합성과 같다. 다른 점: IO LEF가 합성은 <code>giolib045.lef</code>, P&amp;R은 <code>giolib045_modify.lef</code>. P&amp;R에만 <code>gsclib045_multibitsDFF.lef</code>와 cap table이 있다. tech LEF와 QRC는 파일명이 같고 폴더만 다르다.</div>
</div>"""

# ---------------------------------------------------------------- page 6 (3-b): rebuilt so the full-run waveform
# can be shown with its middle cut out (the original 1200x171 capture is too wide to read at page width)
from PIL import Image, ImageDraw
def orig_img(pg, name):
    return [i for i in orig.pages[pg - 1].images if i.name == name][0].image.convert("RGB")
wf = orig_img(6, "X30.jpg")                        # 0 us at x~130, 1 us ~ 124 px
L_END, R_BEG, GAP = 380, 905, 16                   # keep 0~2.0 us and 6.3~8.65 us
left, right = wf.crop((0, 0, L_END, wf.height)), wf.crop((R_BEG, 0, wf.width, wf.height))
comp = Image.new("RGB", (left.width + GAP + right.width, wf.height), (255, 255, 255))
comp.paste(left, (0, 0)); comp.paste(right, (left.width + GAP, 0))
dr = ImageDraw.Draw(comp)
x0 = left.width
for y in range(0, wf.height, 8):                   # zig-zag break mark
    dr.line([(x0 + 3, y), (x0 + GAP - 3, y + 4)], fill=(120, 130, 140), width=1)
    dr.line([(x0 + GAP - 3, y + 4), (x0 + 3, y + 8)], fill=(120, 130, 140), width=1)
comp = comp.resize((comp.width * 4, comp.height * 4), Image.NEAREST)   # integer, no smoothing: keeps the original pixels
comp.save(WORK / "wave_full_cut.png")
orig_img(6, "X31.jpg").save(WORK / "wave_uart.png"); orig_img(6, "X32.jpg").save(WORK / "wave_spi.png")
fig = lambda f: f'<img src="{(WORK / f).as_uri()}" style="width:100%;display:block;border:0.6pt solid var(--line)">'
p6 = f"""
<div class="page">
 <div class="bar">FE · 3-b 기능 시뮬레이션 (Waveform) <span style="color:#9be3a1">PASS</span></div>
 <p style="font-size:10pt">자기검증 테스트벤치(<code>tb_mcu_top</code>)가 RAM 4곳, UARTTXD 프레임과 데이터, SPI 8클럭과 MOSI/MISO 바이트, 종료 pc를 기대값과 비교한다. APB 접근마다 stall 1클럭 뒤 penable 1클럭이 나오고 둘이 겹치지 않는지도 검사한다. 시뮬레이터는 xrun이다.</p>
 {fig("wave_full_cut.png")}
 <p class="cap" style="margin:3pt 0 10pt">RTL 시뮬레이션 전체 파형. 가운데 약 2.0~6.3 µs 구간(UART 프레임 중간 비트)은 잘라내고 앞뒤만 이어 붙였다(가운데 지그재그 선). 0.525 µs에 UARTTXD가 내려가 송신이 시작되고, 8645 ns에 pc=0xAC로 종료하며 RAM[0..3]이 55, 65, 60, 165(0x37, 0x41, 0x3C, 0xA5)로 채워지고 err=0이다.</p>
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
orig_img(10, "X50.jpg").save(WORK / "schematic.png")
p8 = f"""
<div class="page">
 <h3 style="margin-top:0">(ii) 제약 (SDC)</h3>
 <p>합성 스크립트가 <code>source -verbose ./cons/mcu_pad_top.sdc</code>로 읽는 10 ns 제약이다. 아래는 파일 19~99행(머리 주석 제외 전부)이다.</p>
 {fbox(520, f"{PROJ}/TOP/3_SYN/cons/mcu_pad_top.sdc · 19~99행", lines("3_SYN/cons/mcu_pad_top.sdc", 19, 99), wrap=True)}
 <p class="cap" style="margin:2pt 0 8pt">클럭 <code>MAIN_CLOCK</code> 10 ns(100 MHz), 소스·네트워크 latency 0.2 ns, setup uncertainty 0.1 ns, clock transition 0.1 ns, 입출력 지연(max 0.1 / min 0.01 ns), 동작 조건(slow: PVT_0P9V_125C, fast: PVT_1P1V_0C)과 신호 패드 15개의 <code>set_dont_touch</code>가 들어 있다.</p>
 <table style="font-size:8.8pt">
  <tr><th style="width:24%">항목</th><th>설정과 이유</th></tr>
  <tr><td>입력 구동</td><td><code>set_driving_cell -lib_cell PADDI -pin Y</code>: 칩 입력(clk 제외 6개)을 입력 패드 셀이 구동한다고 본다.</td></tr>
  <tr><td>출력 부하</td><td><code>set_load [load_of PADDO/A]</code>: 출력 8개가 출력 패드 셀 입력을 구동한다.</td></tr>
  <tr><td>패드 보호</td><td>신호 패드 15개 <code>set_dont_touch</code>로 합성이 패드 셀을 바꾸지 않게 한다.</td></tr>
  <tr><td>이상 네트워크</td><td><code>set_ideal_network</code> clk, clrn: 합성 단계에서는 버퍼링하지 않고 CTS와 P&amp;R에 맡긴다.</td></tr>
  <tr><td>dont_use</td><td><code>dont_use_45nm.tcl</code>: 지연·홀드·타이·스캔 플립플롭 셀을 합성에서 쓰지 않는다(부록 S2).</td></tr>
 </table>
</div>"""
p9 = f"""
<div class="page">
 <h3 style="margin-top:0">(iii) 타이밍 리포트 (Setup)</h3>
 <p>클럭 10 ns(100 MHz)를 목표로 합성했다. 이 넷리스트가 P&amp;R 입력이다.</p>
 <table style="font-size:8.8pt">
  <tr><th>클럭</th><th>Critical slack</th><th>TNS / 위반 경로</th><th>인스턴스 (순차 / 조합)</th><th>코어 면적</th><th>칩 셀 면적</th></tr>
  <tr><td class="num" style="text-align:left">10 ns</td><td class="num">+2.3 ps</td><td class="num">0 / 0</td><td class="num">5,256 (1,816 / 3,440)</td><td class="num">21,856 µm²</td><td class="num">237,856 µm²</td></tr>
 </table>
 {fbox(560, "07_MAIN_CLOCK_post_syn_opt.rpt · 11~94행 (Path 1, 10 ns)", lines("3_SYN/report/07_MAIN_CLOCK_post_syn_opt.rpt", 11, 94))}
 <p class="cap" style="margin:2pt 0 0"><b style="color:var(--ink)">10 ns 최악 setup 경로.</b> <code>r_pc_reg_4</code>에서 명령어 ROM, CPU 디코드와 가산기, 주소 디코드를 지나 UART 블록의 <code>r_count_reg_4/D</code>까지 데이터 경로 9,789 ps, slack +2 ps(MET).</p>
</div>"""
p10 = f"""
<div class="page">
 <div style="display:flex;gap:9pt">
  <div style="flex:1;min-width:0">{fbox(300, "19_mcu_pad_top_SYN_qor.rpt · 10~51행", lines("3_SYN/report/19_mcu_pad_top_SYN_qor.rpt", 10, 51))}
   <p class="cap"><b style="color:var(--ink)">10 ns 합성 QoR.</b> Critical path slack +2.3 ps, TNS 0, 위반 경로 0. 인스턴스 5,256개(순차 1,816, 조합 3,440), 셀 면적 237,855 µm².</p></div>
  <div style="flex:1;min-width:0">{fbox(300, "09_mcu_pad_top_SYN_area.rpt · 10~36행", lines("3_SYN/report/09_mcu_pad_top_SYN_area.rpt", 10, 36))}
   <p class="cap"><b style="color:var(--ink)">계층별 면적.</b> 코어 21,856 µm² 중 데이터 RAM 10,493, UART 5,157, CPU 4,279 µm². 나머지 약 216,000 µm²(칩 셀 면적의 약 91%)는 패드 15개다.</p></div>
 </div>
 <ul style="font-size:10pt;margin:4pt 0 10pt">
  <li>최악 경로는 PC 레지스터 → 명령어 ROM → CPU 디코드 → 32비트 가산기 → 주소 디코드 → UART 블록으로 이어지는, 단일 사이클 구조의 가장 긴 조합 경로다.</li>
  <li>slack이 +2.3 ps로 거의 0인 것은 여유가 없는 것이 아니라, 10 ns 제약을 맞추는 선에서 툴이 남는 시간을 면적 최적화에 쓴 결과로 보인다.</li>
  <li><code>check_design</code>에서 unresolved reference, undriven, multidriven이 모두 0이었고 합성은 에러 없이 끝났다.</li>
 </ul>
 <img src="{(WORK / "schematic.png").as_uri()}" style="width:62%;display:block;margin:0 auto;border:0.6pt solid var(--line)">
 <p class="cap" style="text-align:center;margin-top:3pt">합성 후 칩 레벨 스키매틱. 입력 PADDI 7개, 출력 PADDO 8개가 mcu_top을 감싼다. 디버그 출력 4개는 의도적으로 열려 있다.</p>
</div>"""

new_pages = render(doc(cover_fe + p7 + cover_be + p13 + p6 + p8 + p9 + p10 + FIT), "newpages")
assert len(new_pages.pages) == 8, f"new pages overflowed: {len(new_pages.pages)}"

# ---------------------------------------------------------------- overlays
def white(x, y, w, h):
    return f'<div class="ov" style="left:{x}pt;top:{y}pt;width:{w}pt;height:{h}pt;background:#fff"></div>'

def head(y, txt, code):
    return (white(36, y - 3, 380, 16.5) +
            f'<div class="ov" style="left:37.3pt;top:{y - 2.6}pt;font-size:12.4pt;font-weight:700;line-height:1.2">{txt} '
            f'(<code style="font-size:10pt;font-weight:400">{code}</code>)</div>')

L, Wd = 36.75, 521.75
OV = {}
OV[12] = (white(36, 315.5, 523.5, 34) +
          f'<div class="ov" style="left:39pt;top:316.5pt;width:519pt;font-size:10.3pt;line-height:1.55;padding-left:11pt;text-indent:-11pt">'
          '•&nbsp; pre-layout 시뮬은 클럭 트리와 실제 배선 지연이 없는 합성 시점의 지연이다. 배선 후 지연(+3.46 ns worst)은 BE 포트폴리오 부록 A의 post-layout 시뮬에서 확인한다.</div>' +
          white(36, 354, 523.5, 60.5) +
          f'<div class="ov" style="left:{L}pt;top:355pt;width:{Wd}pt">'
          f'<div class="note"><b class="l">확인 완료: 하강 지연.</b> 첫 UARTTXD 하강 지연은 11쪽 UART 송신 확대 파형에서 측정한 <b>+1.773 ns</b>(RTL 525 ns → 526.773 ns)로 확정했다. 예전 메모의 약 1.15 ns는 잘못 적은 값이다.</div>'
          f'<div class="note"><b class="l">확인 완료: 사용한 넷리스트.</b> 3-c의 등가성 검사(Conformal 1)와 이 pre-layout 시뮬레이션은 모두 <b>10 ns 넷리스트</b>로 수행했다. '
          f'넷리스트 3행이 <code>Generated on: Nov 10 2026 00:24:47</code>이고 그 합성 로그의 SDC가 <code>set CLK_PERIOD 10</code>이다.</div></div>')
OV[14] = head(120.2, "① Init / Floorplan", "0_InitDesign.tcl + init.io") + head(430.9, "② Power plan", "1_PowerPlan.tcl")
OV[15] = head(43.7, "③ Place", "2_PlaceOpt.tcl") + head(454.9, "④ CTS", "3_PostCTSopt.tcl")
OV[16] = (head(43.9, "⑤ Route", "4_RouteDesign_PowerAnalysis.tcl") .replace("</code>)</div>", "</code>, NanoRoute)</div>")
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
          '<div class="cap">CTS 176개는 4-c의 클럭 버퍼 수와 같다. 최적화 셀 706개는 preCTS의 setup 위반과 max_tran 위반을 고치면서 들어왔다. hold를 맞추려는 셀은 없다.</div></div>')
OV[19] = (white(36, 373.5, 523.5, 40) +
          f'<div class="ov note" style="left:{L}pt;top:374.25pt;width:{Wd}pt;height:38.5pt;font-size:8.6pt;padding:5pt 9pt;line-height:1.55">'
          '<b>Hold 위반 없음.</b> post-layout STA에서 hold 위반이 0건(WNS +0.053 ns)이라 hold용 지연 버퍼(<code>FE_PHC</code>)는 0개이고 전후 비교는 필요하지 않았다. '
          '삽입 셀 개수는 앞 쪽 표(클럭 176, 최적화 706, 합계 882)에 정리했다.</div>')

def cbox(x, y, w, h, title, text, wrap=False):
    ws = ' style="white-space:pre-wrap;word-break:break-all"' if wrap else ""
    return (f'<div class="cbox" style="left:{x}pt;top:{y}pt;width:{w}pt;height:{h}pt">'
            f'<div class="ch">{html.escape(title)}</div><pre class="fit"{ws}>{hl(text)}</pre></div>')

def rl(rel, a, b):
    return f"{PROJ}/TOP/{rel} · {a}~{b}행", lines(rel, a, b)

def add(k, frag):
    OV[k] = OV.get(k, "") + frag

add(4, cbox(37.5, 315.8, 255.8, 198.8, *rl("1_RTL/mcu_pad_top.v", 119, 156)))
add(4, cbox(302.2, 315.8, 255.8, 62.2, *rl("1_RTL/mcu_top.v", 88, 97)))
add(4, cbox(37.5, 555.8, 255.8, 120.0, *rl("1_RTL/sccpu.v", 148, 170)))
add(4, cbox(302.2, 555.8, 255.8, 123.8, *rl("1_RTL/apb_bridge.v", 32, 56)))
add(5, cbox(37.5, 45.0, 255.8, 128.2, *rl("1_RTL/scdatamem.v", 28, 49)))
add(5, cbox(302.2, 45.0, 255.8, 68.2, *rl("1_RTL/scinstmem.v", 44, 55)))

def lg(rel, *ranges, label=None):
    parts = [lines(rel, a, b) for a, b in ranges]
    rng = ", ".join(f"{a}~{b}" for a, b in ranges)
    return (label or f"{PROJ}/TOP/{rel} · {rng}행"), "\n...\n".join(parts)

# FE: 10 ns synthesis reports, Conformal log and pre-sim logs (files exist in the repo).
# The 2.5 ns reports (p10 top) are not in the repo and stay as captures; the schematic stays as is.
add(11, cbox(37.5, 64.5, 255.8, 111.8, *lg("4_EC/log/all.log", (120, 138), label="4_EC/log/all.log · report verification (120~138행)")))
add(11, cbox(302.2, 64.5, 255.8, 126.0, *lg("4_EC/log/all.log", (139, 160), label="4_EC/log/all.log · report statistics (139~160행)")))
add(11, cbox(37.5, 545.2, 255.8, 117.0, *lg("2_SIM/PRE/pre_sim.log", (2364, 2378), label="2_SIM/PRE/pre_sim.log · 2364~2378행")))
_sg = lines("2_SIM/PRE/sdf_gate.log", 1, 12)
_t = (TOP / "2_SIM/PRE/sdf_gate.log").read_text(errors="replace").split("\n")
_un = [l for l in _t if "Unable to annotate" in l]
_sg += (f"\n\n# 같은 파일 집계\n'Unable to annotate'      : {len(_un)}건"
        f"\n그중 REMOVAL이 아닌 항목    : {sum('REMOVAL' not in l for l in _un)}건"
        f"\n에러(*E,)                  : {sum('*E,' in l for l in _t)}건")
add(11, cbox(302.2, 545.2, 255.8, 105.8, "2_SIM/PRE/sdf_gate.log · 1~12행 + 집계", _sg))

# Captures whose log files no longer exist (2.5 ns synthesis, flat-netlist post-sim): transcribed by hand
# from the original captures into src/transcribed/ and shown as text, labelled as such.
TR = pathlib.Path(__file__).resolve().parent / "transcribed"
def tr(name): return (TR / name).read_text().rstrip("\n")
add(21, cbox(37.5, 222.8, 255.8, 115.5, "수정 전(-flat 넷리스트) xmelab SDF 로그 · 원본 로그 없음, 당시 캡처에서 옮겨 적음", tr("post_sim_flat_sdf.txt"), wrap=True))

# BE: report/log captures replaced by excerpts of the logs they came from
add(17, cbox(37.5, 117.0, 255.8, 179.2, *lg("5_PNR/innovus.log10", (4871, 4899), label="innovus.log10 · timeDesign -postRoute (4871~4899행)")))
add(17, cbox(302.2, 117.0, 255.8, 111.0, *lg("5_PNR/innovus.log10", (4927, 4944), label="innovus.log10 · timeDesign -postRoute -hold (4927~4944행)")))
add(17, cbox(37.5, 642.8, 255.8, 114.0, *lg("5_PNR/tempus.log", (229, 229), (243, 250), label="tempus.log · check_timing (229, 243~250행)")))
add(17, cbox(302.2, 642.8, 255.8, 120.0, *lg("5_PNR/tempus.log", (281, 294), label="tempus.log · report_analysis_coverage (281~294행)")))
add(18, cbox(37.5, 40.5, 520.5, 227.2, *lg("5_PNR/tempus.log2", (330, 351), label="tempus.log2 · report_timing -early, hold 최악 경로 (330~351행)")))
add(20, cbox(162.8, 40.5, 270.0, 378.8, *lg("5_PNR/tempus.log2", (252, 328), label="tempus.log2 · report_timing -late, setup 최악 경로 (252~328행)")))
add(21, cbox(302.2, 222.8, 255.8, 48.0, *lg("2_SIM/POST/max/post_sim_max.log", (919, 927), label="post_sim_max.log · SDF statistics (919~927행)")))

add(2, white(289.0, 528.6, 11.5, 11.2) +
       '<div class="ov" style="left:289.2pt;top:528.2pt;font-size:9.1pt;line-height:1.2;letter-spacing:0">10</div>')
add(19, white(36, 501.5, 523.5, 172) +
    f'<div class="ov" style="left:{L}pt;top:503pt;width:{Wd}pt"><table style="font-size:8.9pt">'
    '<tr><th style="width:17%">단계</th><th style="width:25%">발견</th><th>조치</th><th style="width:22%">결과</th></tr>'
    '<tr><td>CTS 이후 최적화</td><td>preCTS −0.352 ns, max_tran 33 net</td><td>postCTS 최적화(버퍼 삽입, sizing)</td><td>setup +0.148 ns, max_tran 0</td></tr>'
    '<tr><td>post-layout 시뮬</td><td>PASS였지만 SDF 적용률 0.17%</td><td>PnR 넷리스트를 계층 구조로 저장(<code>-flat</code> 제거)</td><td>적용률 91.99%</td></tr>'
    '</table></div>')
add(20, white(36, 603, 523.5, 50.5) +
    '<div class="ov" style="left:39pt;top:605pt;width:519pt;font-size:10.3pt;line-height:1.6;padding-left:11pt;text-indent:-11pt">'
    '•&nbsp; setup 최악 경로는 합성 때부터 보이던 PC → ROM → CPU 가산기 → 주소 디코드 → FIFO enable 경로이고 배선 후에도 그대로 최악이다.</div>')
add(22, white(36, 73, 523.5, 33.5))

order = sorted(OV)
ov_html = "".join(f'<div class="page" style="background:transparent;padding:0">{OV[k]}</div>' for k in order)

ov_pdf = render(doc(ov_html + FIT), "overlays")
assert len(ov_pdf.pages) == len(order)

# ---------------------------------------------------------------- merge
def book(cover_idx, orig_pages, appx, out):
    w = pypdf.PdfWriter()
    w.add_page(new_pages.pages[cover_idx])
    for k in orig_pages:
        if k in (6, 8, 9, 10):
            w.add_page(new_pages.pages[{6: 4, 8: 5, 9: 6, 10: 7}[k]]); continue
        if k == 7:
            w.add_page(new_pages.pages[1]); continue
        if k == 13:
            w.add_page(new_pages.pages[3]); continue
        w.add_page(orig.pages[k - 1])
        pg = w.pages[-1]
        if k in OV:
            pg.merge_page(ov_pdf.pages[order.index(k)])
    for p in appx.pages:
        w.add_page(p)
    w.add_metadata({"/Title": out.stem})
    with open(out, "wb") as f:
        w.write(f)
    return len(w.pages)

OUTDIR.mkdir(parents=True, exist_ok=True)
fe = OUTDIR / "Park_Heeseo_project_FE_portfolio.pdf"
be = OUTDIR / "Park_Heeseo_project_BE_portfolio.pdf"
print("FE pages", book(0, FE_ORIG, afe, fe), "BE pages", book(2, BE_ORIG, abe, be), S)
