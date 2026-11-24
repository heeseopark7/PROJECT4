#!/usr/bin/env python3
"""Revise MCU_V1_portfolio.pdf: replace pages 1, 7, 13, patch pages 8, 12, 14-16, 18, 19,
and append appendix S1-S4 (full scripts, SDC, MMMC) taken verbatim from V1/TOP.

usage: python3 build_rev.py <V1/TOP dir> <original pdf> <output pdf> <work dir>
needs: pypdf, pypdfium2, node + playwright (chromium)
"""
import html, pathlib, subprocess, sys
import pypdf, pypdfium2

TOP, ORIG, OUT, WORK = map(pathlib.Path, sys.argv[1:5])
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
body {{ font-family: Pret, sans-serif; color: var(--ink); font-size: 9.6pt; line-height: 1.6;
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
            f'<div class="fh"><span>V1/TOP/{rel}</span><span>{n} lines</span></div>'
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
  await p.goto('file://' + src, { waitUntil: 'networkidle' }); await p.evaluate(() => document.fonts.ready);
  await p.pdf({ path: out, width: '%.2fpx', height: '%.2fpx', printBackground: true, margin: mm });
  await b.close(); })();""" % (W_PT*4/3, H_PT*4/3))
    import json
    subprocess.run(["node", str(js), str(h), str(out), json.dumps(m)], check=True)
    return pypdf.PdfReader(str(out))

# ---------------------------------------------------------------- appendix (rendered first: page numbers go into the TOC)
appx = f"""
<div class="bar">부록 S1 · 합성 실행 스크립트 원문 (3-c-i)</div>
<p>10 ns 최종 합성(11/19 00:16~00:21, <code>3_SYN/log/all.log</code>)에 쓴 파일을 그대로 옮겼다. <code>3_SYN</code>에서 <code>./run_synthesis</code>를 실행하면 Genus가 <code>syn_mcu_pad_top.tcl</code>을 처음부터 끝까지 실행한다.
같은 폴더의 <code>syn_mcu_pad_top_mmmc.tcl</code>은 다른 설계용 수업 템플릿으로, 실행에 쓰지 않았다.</p>
{code_file("3_SYN/run_synthesis")}
{code_file("3_SYN/script/syn_mcu_pad_top.tcl")}
<div style="break-before: page"></div>
<div class="bar">부록 S2 · 10 ns 최종 SDC 원문 (3-c-ii)</div>
<p>합성 스크립트가 <code>source -verbose ./cons/mcu_pad_top.sdc</code>로 읽는다. 10 ns 최종 합성과 P&amp;R에 들어간 상태 그대로다.
입력 구동은 <code>set_driving_cell PADDI</code>가 켜져 있고 <code>set_input_transition 0.1</code>은 주석이다(2.5 ns 실험의 수정은 이 파일에 들어가지 않았다).
파일 위쪽 주석("instead of the PADDI cell")은 2.5 ns 실험 때의 설명으로, 실제로 켜진 줄과 맞지 않는다.</p>
{code_file("3_SYN/cons/mcu_pad_top.sdc")}
{code_file("3_SYN/cons/dont_use_45nm.tcl", "SDC 바로 뒤에 source한다. 지연, 홀드, 타이, 스캔 플립플롭 셀을 합성에서 쓰지 않게 막는다.")}
<div style="break-before: page"></div>
<div class="bar">부록 S3 · APR 스크립트 원문 (4-a)</div>
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
<div class="bar">부록 S4 · Import 설정 원문 (4-b)</div>
<p><code>0_InitDesign.tcl</code>의 <code>init_mmmc_file</code>이다. setup은 FUNC_SS_WORST, hold는 FUNC_FF_BEST로 본다. 첫 실행 로그(<code>5_PNR/innovus.log</code>)에서 아래 파일을 모두 읽은 것을 확인했다.</p>
{code_file("5_PNR/mcu_pad_top.mmmc.view")}
{code_file("5_PNR/add_pad", "P&amp;R에 넣은 넷리스트는 11/10 합성 출력의 endmodule 앞에 이 전원 패드 16개를 붙인 파일이다. 현재 3_SYN/mapped의 넷리스트(11/19 재합성)에는 이 16줄이 없으므로, 0_InitDesign.tcl을 다시 돌릴 때는 다시 붙여야 한다.")}
"""
appx_pdf = render(doc(appx, "body{background:#fff}"), "appendix",
                  {"top": "53.33px", "bottom": "45.33px", "left": "49px", "right": "48.67px"})
orig = pypdf.PdfReader(str(ORIG))
N0 = len(orig.pages)

def find_page(reader_path, needle):
    d = pypdfium2.PdfDocument(str(reader_path))
    for i in range(len(d)):
        if needle in d[i].get_textpage().get_text_range():
            return i
    raise SystemExit(f"not found: {needle}")

ap = WORK / "appendix.pdf"
S = {k: N0 + 1 + find_page(ap, t) for k, t in
     {"S1": "부록 S1", "S2": "부록 S2", "S3": "부록 S3", "S4": "부록 S4"}.items()}

# ---------------------------------------------------------------- page 1 (cover)
cover = f"""
<div class="page" style="padding-top:120pt">
 <div class="mono" style="background:none;padding:0;color:var(--teal);font-size:7.8pt">Physical Implementation 포트폴리오 · V1 (패드 포함 mcu_pad_top)</div>
 <div style="font-size:27pt;font-weight:700;margin:6pt 0 6pt;letter-spacing:-0.6pt">MCU RTL to GDS2</div>
 <p style="font-size:11.8pt;line-height:1.65;color:#3f4b52">단일 사이클 MIPS CPU, APB 브리지, UART, SPI 마스터/슬레이브를 담은 MCU를 RTL 시뮬레이션부터 합성, 등가성 검사, P&amp;R, STA, post-layout 시뮬레이션까지 진행해 GDS2를 만든 기록이다. 클럭 10 ns(100 MHz) 기준, 공정은 GPDK045.</p>
 <div class="note" style="font-size:9pt">RTL은 Claude의 도움을 받아 작성했고 코드 구조는 설명할 수 있는 수준으로 이해했다. RTL 시뮬레이션, 합성, P&amp;R은 직접 수행했다.</div>
 <table style="table-layout:fixed;margin:6pt 0 16pt"><tr>
  <td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">10 ns</div><div class="cap">최종 클럭 (100 MHz)</div></td>
  <td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">+0.441 / +0.053 ns</div><div class="cap">postRoute setup / hold WNS</div></td>
  <td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">0 viol.</div><div class="cap">verify_drc, verifyConnectivity (필러 후)</div></td>
  <td style="padding:8pt 9pt"><div class="mono" style="background:none;padding:0;font-size:12pt;font-weight:700">PASS</div><div class="cap">RTL·pre·post 시뮬, 등가성 2회</div></td>
 </tr></table>
 <h3 style="margin-top:0">구성</h3>
 <table>
  <tr><th style="width:17%">Part</th><th>항목</th><th style="width:9%">쪽</th></tr>
  <tr><td rowspan="4">FE</td><td>3-a 설계 논리 다이어그램과 스펙</td><td>2</td></tr>
  <tr><td>3-b 기능 시뮬레이션 (파형)</td><td>6</td></tr>
  <tr><td>3-c 합성 (실행 스크립트, 제약, setup 타이밍 리포트)</td><td>7</td></tr>
  <tr><td>3-d Pre-layout 시뮬레이션 (3-b와 동일 검증, 타이밍으로 생긴 차이)</td><td>11</td></tr>
  <tr><td rowspan="7">BE</td><td>4-a APR 전 과정 스크립트 · 4-b Import 파일 정리</td><td>13</td></tr>
  <tr><td>4-c 단계별 캡처 (고대비, 음영 반전)</td><td>14</td></tr>
  <tr><td>4-d NanoRoute 후 타이밍 리포트 (Setup + Hold)</td><td>17</td></tr>
  <tr><td>4-e STA 전후의 Hold 타이밍 변화와 버퍼 삽입 (삽입 셀 개수)</td><td>17</td></tr>
  <tr><td>4-f ECO 수행 과정</td><td>19</td></tr>
  <tr><td>4-g 최종 타이밍 리포트 (Setup + Hold)</td><td>19</td></tr>
  <tr><td>(4-a 원문 부록 S3, 4-b 원문 부록 S4)</td><td>{S['S3']}</td></tr>
  <tr><td rowspan="5">부록</td><td>A~C post-layout 시뮬레이션, 등가성 검사, 한계</td><td>21</td></tr>
  <tr><td>S1 합성 실행 스크립트 원문 (run_synthesis, syn_mcu_pad_top.tcl)</td><td>{S['S1']}</td></tr>
  <tr><td>S2 10 ns 최종 SDC 원문 (mcu_pad_top.sdc, dont_use_45nm.tcl)</td><td>{S['S2']}</td></tr>
  <tr><td>S3 APR 스크립트 원문 (0_InitDesign.tcl ~ 5_ChipFinish.tcl, init.io)</td><td>{S['S3']}</td></tr>
  <tr><td>S4 Import 설정 원문 (mcu_pad_top.mmmc.view, add_pad)</td><td>{S['S4']}</td></tr>
 </table>
 <p style="font-size:10.6pt;color:#3f4b52;margin-top:10pt">플로우: xrun(RTL 시뮬) → Genus(합성) → Conformal(RTL↔합성) → xrun(pre-layout) → Innovus(P&amp;R) → Conformal(합성↔PnR) → Tempus(STA) → xrun(post-layout, worst/best).</p>
</div>"""

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
 초기 캡처의 <code>LIB_LIST {{fast_… slow_… pads_SS_…}}</code> 줄은 처음 작성한 버전이다. 11/10, 11/13, 11/19 합성 로그 모두 위의 slow 단일 코너 목록으로 실행되었다.</div>
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
 <div class="note"><b class="l">원문 수록.</b> 6개 스크립트와 init.io 원문은 부록 S3(p.{S['S3']})에 있다. 실행 기록(<code>innovus.cmd*</code>)과 대조해 floorplan 값, 패드 좌표, 링 offset, CTS 목표 스큐, postRoute 분석 모드가 일치함을 확인했다.</div>
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
  <tr><td>View</td><td>constraint_mode FUNC, view FUNC_SS_WORST / FUNC_FF_BEST</td><td><code>mcu_pad_top.mmmc.view</code>(부록 S4)</td></tr>
 </table>
 <div class="chk"><b class="l">합성과 대조.</b> 타이밍 lib(slow 3종)는 합성과 같다. 다른 점: IO LEF가 합성은 <code>giolib045.lef</code>, P&amp;R은 <code>giolib045_modify.lef</code>. P&amp;R에만 <code>gsclib045_multibitsDFF.lef</code>와 cap table이 있다. tech LEF와 QRC는 파일명이 같고 폴더만 다르다.</div>
</div>"""

new_pages = render(doc(cover + p7 + p13), "newpages")
assert len(new_pages.pages) == 3, f"new pages overflowed: {len(new_pages.pages)}"

# ---------------------------------------------------------------- overlays
def white(x, y, w, h):
    return f'<div class="ov" style="left:{x}pt;top:{y}pt;width:{w}pt;height:{h}pt;background:#fff"></div>'

def head(y, txt, code):
    return (white(36, y - 3, 380, 16.5) +
            f'<div class="ov" style="left:37.3pt;top:{y - 2.6}pt;font-size:12.4pt;font-weight:700;line-height:1.2">{txt} '
            f'(<code style="font-size:10pt;font-weight:400">{code}</code>)</div>')

L, Wd = 36.75, 521.75
OV = {}
OV[8] = (f'<div class="ov note" style="left:{L}pt;top:768pt;width:{Wd}pt;font-size:8.6pt">'
         f'<b class="l">10 ns 최종 SDC는 다르다.</b> 위 <code>set_input_transition 0.1</code> 수정은 2.5 ns 실험에서만 썼다. 10 ns 최종 합성과 P&amp;R에 들어간 SDC는 <code>set_driving_cell PADDI</code>를 그대로 두었다 '
         f'(<code>log/all.log</code> 607행, <code>02_report_port.rpt</code>의 입력 드라이버가 모두 <code>PADDI/Y</code>). 10 ns SDC 전문은 부록 S2(p.{S["S2"]}).</div>')
OV[12] = (white(36, 354, 523.5, 60.5) +
          f'<div class="ov" style="left:{L}pt;top:355pt;width:{Wd}pt">'
          f'<div class="chk"><b class="l">확인 필요</b> 문서 5의 확대 파형 캡션은 하강 지연을 약 1.15 ns로, 본문 측정은 +1.773 ns로 적었다. 본문은 +1.773 ns를 썼고 확대 파형 캡처는 넣지 않았다.</div>'
          f'<div class="note"><b class="l">확인 완료: 사용한 넷리스트.</b> 3-c의 등가성 검사(Conformal 1)와 이 pre-layout 시뮬레이션은 모두 <b>10 ns 넷리스트</b>로 수행했다. '
          f'넷리스트 3행이 <code>Generated on: Nov 10 2026 00:24:47</code>이고 그 합성 로그의 SDC가 <code>set CLK_PERIOD 10</code>이다. pre-sim은 11/10 01:21, EC는 11/10에 실행했다. '
          f'5 ns 넷리스트는 11/13에 생성되어 두 검증에 쓰이지 않았다. 11/19 10 ns 재합성본은 생성 시각 한 줄만 다르고 내용이 같다.</div></div>')
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

order = sorted(OV)
ov_html = "".join(f'<div class="page" style="background:transparent;padding:0">{OV[k]}</div>' for k in order)
ov_pdf = render(doc(ov_html), "overlays")
assert len(ov_pdf.pages) == len(order)

# ---------------------------------------------------------------- merge
w = pypdf.PdfWriter()
repl = {1: 0, 7: 1, 13: 2}
for i in range(1, N0 + 1):
    if i in repl:
        pg = new_pages.pages[repl[i]]
    else:
        pg = orig.pages[i - 1]
        if i in OV:
            pg.merge_page(ov_pdf.pages[order.index(i)])
    w.add_page(pg)
for pg in appx_pdf.pages:
    w.add_page(pg)
w.add_metadata({"/Title": "MCU_V1_portfolio"})
with open(OUT, "wb") as f:
    w.write(f)
print("pages:", len(w.pages), "appendix starts:", S)
