#!/usr/bin/env python3
"""Build V1 portfolio supplement (HTML -> PDF) from the real V1 source files."""
import html, sys, pathlib

TOP = pathlib.Path(sys.argv[1])          # .../V1/TOP
OUT = pathlib.Path(sys.argv[2])          # output html path

def code(rel, title=None, note=None):
    p = TOP / rel
    txt = p.read_text(errors="replace").rstrip("\n")
    n = txt.count("\n") + 1
    head = f'<div class="fh"><span class="fn">V1/TOP/{rel}</span><span class="ln">{n} lines</span></div>'
    nt = f'<p class="fnote">{note}</p>' if note else ""
    return f'<div class="file">{head}{nt}<pre>{html.escape(txt)}</pre></div>'

S = {}
for k, rel in {
    "run": "3_SYN/run_synthesis",
    "syn": "3_SYN/script/syn_mcu_pad_top.tcl",
    "sdc": "3_SYN/cons/mcu_pad_top.sdc",
    "dont": "3_SYN/cons/dont_use_45nm.tcl",
    "p0": "5_PNR/0_InitDesign.tcl",
    "io": "5_PNR/init.io",
    "p1": "5_PNR/1_PowerPlan.tcl",
    "p2": "5_PNR/2_PlaceOpt.tcl",
    "p3": "5_PNR/3_PostCTSopt.tcl",
    "p4": "5_PNR/4_RouteDesign_PowerAnalysis.tcl",
    "p5": "5_PNR/5_ChipFinish.tcl",
    "mmmc": "5_PNR/mcu_pad_top.mmmc.view",
    "pad": "5_PNR/add_pad",
}.items():
    S[k] = rel

body = f"""
<header class="cover">
  <div class="kicker">MCU RTL to GDS2 · V1 (패드 포함) · 포트폴리오 보완 자료</div>
  <h1>스크립트·제약·Import 원본 모음</h1>
  <p class="lead">본 포트폴리오(MCU_V1_portfolio.pdf)의 주황 박스 자리에 들어갈 원본을 V1 폴더에서 그대로 옮겼다.
  스크립트 본문은 손으로 옮겨 적지 않고 파일에서 자동으로 넣었다. 번호는 교수님 가이드라인(3. FE, 4. BE) 번호를 따른다.</p>

  <table class="map">
    <thead><tr><th>가이드라인</th><th>주황 박스</th><th>원본 파일</th><th>이 문서</th></tr></thead>
    <tbody>
      <tr><td>3-c-(i)</td><td>Synthesis Run Script 전체</td><td>3_SYN/run_synthesis, 3_SYN/script/syn_mcu_pad_top.tcl</td><td>1장</td></tr>
      <tr><td>3-c-(ii)</td><td>Constraint (10 ns 최종 SDC)</td><td>3_SYN/cons/mcu_pad_top.sdc, dont_use_45nm.tcl</td><td>2장</td></tr>
      <tr><td>4-a</td><td>APR 전과정 Script</td><td>5_PNR/0_InitDesign.tcl ~ 5_ChipFinish.tcl, init.io</td><td>3장</td></tr>
      <tr><td>4-b</td><td>Import 파일 정리</td><td>5_PNR/mcu_pad_top.mmmc.view, innovus.log (init)</td><td>4장</td></tr>
      <tr><td>확인 4, 5</td><td>10 ns SDC 출처, EC·pre-sim 넷리스트</td><td>git 이력, 로그 날짜, 넷리스트 비교</td><td>5장</td></tr>
    </tbody>
  </table>

  <div class="answers">
    <div class="ans"><div class="q">확인 4 · 10 ns 합성에 쓴 SDC</div>
      <p><b>3_SYN/cons/mcu_pad_top.sdc</b> 하나다. 지금 파일이 10 ns 최종본이고 2장에 전체를 실었다.
      단, 입력 구동은 <b>set_driving_cell PADDI가 켜져 있고 set_input_transition 0.1은 주석</b>이다.
      2.5 ns 때 고친 입력 구동(외부 기울기 0.1 ns)은 10 ns 합성 SDC에 들어가지 않았다. PDF의 "2.5 ns에서 고친 입력 구동" 박스는 10 ns 최종 SDC와 다르니 설명을 고쳐야 한다.</p></div>
    <div class="ans"><div class="q">확인 5 · Conformal 1과 pre-layout 시뮬 넷리스트</div>
      <p>둘 다 <b>10 ns 넷리스트</b>다 (11/10 00:24 Genus 출력). 5 ns 넷리스트(11/13 생성)로 돌린 EC·pre-sim 로그는 없다.
      11/19에 다시 합성한 10 ns 넷리스트는 11/10 넷리스트와 생성 시각 줄 하나만 다르고 내용이 같다.</p></div>
  </div>
</header>

<section>
  <h2><span class="num">1</span>Synthesis Run Script <small>가이드라인 3-c-(i)</small></h2>
  <p>실행은 <code>3_SYN</code>에서 <code>./run_synthesis</code> 한 번이다. Genus 22.17-s071_1이 <code>syn_mcu_pad_top.tcl</code>을 처음부터 끝까지 실행한다
  (라이브러리 읽기 → RTL 읽기, elaborate → SDC 적용 → syn_generic → syn_map → syn_opt → 리포트 00~20번 → 넷리스트·SDC·SDF 쓰기).
  10 ns 최종 실행 기록: <code>3_SYN/log/all.log</code>, 시작 11/19 00:16:22, 종료 00:21:07 (<code>cds_syn_runtime</code>).</p>
  <table class="kv">
    <tr><th>단계</th><th>스크립트 안 명령</th><th>산출물</th></tr>
    <tr><td>설정</td><td>read_libs, read_physical -lef, read_qrc</td><td>slow_vdd1v0 basic/multibitsDFF, pads_SS_s1vg</td></tr>
    <tr><td>로드</td><td>read_hdl, elaborate, uniquify, check_design</td><td>report/00_check_design.rpt</td></tr>
    <tr><td>제약</td><td>source cons/mcu_pad_top.sdc, dont_use_45nm.tcl</td><td>report/01_check_timing_intent.rpt, 02_report_port.rpt</td></tr>
    <tr><td>합성</td><td>syn_generic → syn_map → syn_opt (effort high)</td><td>report/03~07, mapped/syn_map.db, syn_opt.db</td></tr>
    <tr><td>리포트</td><td>report_area, report_qor, report_timing -nworst 100 등</td><td>report/08~20</td></tr>
    <tr><td>출력</td><td>write_design, write_hdl, write_sdc, write_sdf</td><td>mapped/mcu_pad_top_syn_final.v, .sdc, mcu_pad_top_delays.sdf</td></tr>
  </table>
  {code(S["run"])}
  {code(S["syn"], note="같은 폴더의 syn_mcu_pad_top_mmmc.tcl은 수업 템플릿(다른 설계용)이고 V1 실행에는 쓰지 않았다. run_synthesis와 log/all.cmd 모두 syn_mcu_pad_top.tcl만 부른다.")}
</section>

<section>
  <h2><span class="num">2</span>Constraint: 10 ns 최종 SDC <small>가이드라인 3-c-(ii)</small></h2>
  <p>합성 스크립트가 <code>source -verbose ./cons/mcu_pad_top.sdc</code>로 읽는다. 아래 파일이 11/19 10 ns 합성 때 쓰인 상태 그대로다
  (git: 11/19 00:21 커밋에서 <code>-period 5 → 10</code>, 04:30 커밋에서 주석 한 줄 오타만 수정).</p>
  <table class="kv">
    <tr><th>항목</th><th>값</th></tr>
    <tr><td>클럭</td><td>MAIN_CLOCK, clk 포트, 주기 10 ns (100 MHz)</td></tr>
    <tr><td>클럭 latency / uncertainty / transition</td><td>source 0.2 ns, network 0.2 ns / setup 0.1 ns / 0.1 ns</td></tr>
    <tr><td>입출력 지연</td><td>입력 max 0.1, min 0.01 ns / 출력 max 0.1, min −0.01 ns (clk 제외)</td></tr>
    <tr><td>입력 구동</td><td><b>set_driving_cell PADDI/Y</b> (clk 제외 입력 6개). set_input_transition 0.1은 주석</td></tr>
    <tr><td>출력 부하</td><td>load_of PADDO/A (0.003 pF)</td></tr>
    <tr><td>조건</td><td>max PVT_0P9V_125C (slow), min PVT_1P1V_0C (fast)</td></tr>
    <tr><td>기타</td><td>신호 패드 15개 set_dont_touch, clk·clrn set_ideal_network</td></tr>
  </table>
  <div class="warn"><b>주의 (PDF 수정 필요).</b> SDC 주석은 "PADDI 대신 외부 0.1 ns 기울기를 가정한다"고 쓰여 있지만 실제로 켜진 줄은 반대다.
  10 ns 합성이 PADDI 구동으로 돌았다는 근거: <code>log/all.log</code> 607행 <code>@file(mcu_pad_top.sdc) 64: set_driving_cell -lib_cell PADDI ...</code>,
  <code>report/02_report_port.rpt</code>의 입력 드라이버가 모두 <code>PADDI/Y</code>, <code>mapped/mcu_pad_top_syn_final.sdc</code>에 set_driving_cell 6줄, set_input_transition 0줄.
  git 이력 전체에서 V1 SDC의 set_input_transition이 켜진 적은 없다. 2.5 ns 수정본 SDC는 저장소에 남아 있지 않다.</div>
  {code(S["sdc"])}
  {code(S["dont"], note="합성 스크립트가 SDC 바로 뒤에 source한다. 지연·홀드·타이·스캔 플롭 셀을 합성에서 쓰지 않게 막는다.")}
</section>

<section>
  <h2><span class="num">3</span>APR 전과정 Script <small>가이드라인 4-a</small></h2>
  <p>Innovus 22.17-s086_1에서 단계별로 실행했다. 각 스크립트는 앞 단계 DB를 <code>restoreDesign</code>으로 열고, 끝에서 <code>saveDesign</code>으로 다음 단계 DB를 남긴다.
  포트폴리오 표에 적힌 이름(0.init.io.tcl, 1.tcl ~ 5.tcl)은 실제 파일명과 다르다. 실제 이름은 아래와 같다.</p>
  <table class="kv">
    <tr><th>단계</th><th>실제 파일</th><th>입력 DB → 출력 DB</th><th>주요 명령</th></tr>
    <tr><td>0</td><td>0_InitDesign.tcl (+ init.io)</td><td>넷리스트 → InitDesign.dat</td><td>init_design, checkDesign, floorPlan, placeInstance, addIoFiller, timeDesign -prePlace</td></tr>
    <tr><td>1</td><td>1_PowerPlan.tcl</td><td>InitDesign → PowerPlan.dat</td><td>globalNetConnect, addRing ×2, sroute (corePin, padPin), addStripe ×3, verify_drc, verifyConnectivity</td></tr>
    <tr><td>2</td><td>2_PlaceOpt.tcl</td><td>PowerPlan → PlaceOpt.dat</td><td>place_design, checkPlace, earlyGlobalRoute, place_opt_design, timeDesign -preCTS</td></tr>
    <tr><td>3</td><td>3_PostCTSopt.tcl</td><td>PlaceOpt → PostCTSopt.dat</td><td>create_ccopt_clock_tree_spec, ccopt_design, set_propagated_clock, optDesign -postCTS (-hold)</td></tr>
    <tr><td>4</td><td>4_RouteDesign_PowerAnalysis.tcl</td><td>PostCTSopt → RouteDesign.dat</td><td>routeDesign -globalDetail (NanoRoute), optDesign -postRoute -drv/-setup/-hold, extractRC, report_power</td></tr>
    <tr><td>5</td><td>5_ChipFinish.tcl</td><td>RouteDesign → ChipFinish.dat</td><td>addFiller, verify_drc, verifyConnectivity, saveNetlist, write_sdf, writeTimingCon, streamOut</td></tr>
  </table>
  <div class="note"><b>실행 기록과의 대조.</b> innovus.cmd(실행된 명령 기록)와 스크립트가 맞는지 확인했다.
  floorPlan <code>-r 1 0.6 352 352 352 352</code>, 전원 패드 좌표(pad29 1423.0 등), 바깥 링 offset 200(PowerPlan 저장 직전 실행 기준), CTS target_skew 0.01, postRoute bcwc가 모두 일치한다.
  실행 뒤에 바뀐 곳은 두 군데다: 3_PostCTSopt.tcl에서 <code>file mkdir snap</code> 한 줄 삭제(11/10 22:01), 5_ChipFinish.tcl에서 <code>saveNetlist -flat</code>의 <code>-flat</code> 제거(11/16, post-layout 시뮬의 SDF 인스턴스 이름을 맞추려고 계층 넷리스트로 다시 저장).
  같은 폴더의 all.tcl은 초기 통합본이라 좌표(1130)와 바깥 링 offset(150)이 최종과 다르다. 포트폴리오에는 쓰지 않는다.
  4_RouteDesign_PowerAnalysis_ECO.tcl, 6_ECO.tcl, tempus.tcl은 STA·ECO(가이드라인 4-e, 4-f)용이라 이 장에서 뺐다.</div>
  <h3>0. Init + Floorplan</h3>
  {code(S["p0"])}
  {code(S["io"], note="0_InitDesign.tcl의 init_io_file. 48슬롯 패드 링(변당 12슬롯)과 코너 셀 4개의 위치를 정한다.")}
  <h3>1. Power Plan</h3>
  {code(S["p1"])}
  <h3>2. Placement + Optimization</h3>
  {code(S["p2"])}
  <h3>3. CTS + Optimization</h3>
  {code(S["p3"])}
  <h3>4. Route (NanoRoute) + Power Analysis</h3>
  {code(S["p4"])}
  <h3>5. Chip Finish + Write Out</h3>
  {code(S["p5"])}
</section>

<section>
  <h2><span class="num">4</span>Import 파일 정리 <small>가이드라인 4-b</small></h2>
  <p>0_InitDesign.tcl의 <code>init_*</code> 변수가 Innovus에 넣은 파일 전부다. 아래 "실제로 읽은 파일"은 첫 실행 로그 <code>5_PNR/innovus.log</code>(11/10 02:13)에서 옮겼다.</p>
  <table class="kv imp">
    <tr><th>구분</th><th>init 변수</th><th>실제로 읽은 파일 (innovus.log 행)</th></tr>
    <tr><td>넷리스트</td><td>init_verilog</td><td>../3_SYN/mapped/mcu_pad_top_syn_final.v (232행). 11/10 00:24 Genus 10 ns 출력 + add_pad 전원 패드 16개를 끝에 붙인 것</td></tr>
    <tr><td>Top</td><td>init_top_cell</td><td>mcu_pad_top</td></tr>
    <tr><td>전원 넷</td><td>init_pwr_net / init_gnd_net</td><td>VDD / VSS</td></tr>
    <tr><td>IO</td><td>init_io_file</td><td>init.io (252행)</td></tr>
    <tr><td>LEF</td><td>init_lef_file</td><td>/GPDK045/digital/gsclib045_all_v4.4/gsclib045_tech/lef/gsclib045_tech.lef (37행)<br>
      /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_macro.lef (40행)<br>
      /GPDK045/digital/gsclib045_all_v4.4/gsclib045/lef/gsclib045_multibitsDFF.lef (42행)<br>
      /GPDK045/digital/giolib045_v3.5/lef/giolib045_modify.lef (92행)</td></tr>
    <tr><td>MMMC</td><td>init_mmmc_file</td><td>mcu_pad_top.mmmc.view (아래 전문)</td></tr>
    <tr><td>LIB (SS)</td><td>library_set SS_Max_0p90v_125c</td><td>gsclib045/timing/slow_vdd1v0_basicCells.lib (155행), slow_vdd1v0_multibitsDFF.lib (167행), giolib045_v3.5/timing/pads_SS_s1vg.lib (180행)</td></tr>
    <tr><td>LIB (FF)</td><td>library_set FF_Min_1p10v_0c</td><td>gsclib045/timing/fast_vdd1v0_basicCells.lib (182행), fast_vdd1v0_multibitsDFF.lib (185행), giolib045_v3.5/timing/pads_FF_s1vg.lib (188행)</td></tr>
    <tr><td>RC</td><td>rc_corner BEST (T 0), WORST (T 125)</td><td>cap_table: gsclib045_all_v4.4/captable/cln28hpl_1p10m+alrdl_5x2yu2yz_typical.capTbl (267, 271행)<br>
      qx_tech_file: gsclib045_all_v4.4/gsclib045/qrc/qx/gpdk045.tch (293, 310행)</td></tr>
    <tr><td>SDC</td><td>constraint_mode FUNC</td><td>../3_SYN/mapped/mcu_pad_top_syn_final.sdc (317행, 10 ns). 경고 3건: set_units 2건 무시, set_operating_conditions 미지원(delay corner로 대체)</td></tr>
    <tr><td>View</td><td>set_analysis_view</td><td>setup: FUNC_SS_WORST (SS + WORST) / hold: FUNC_FF_BEST (FF + BEST)</td></tr>
  </table>

  <h3>합성(Genus)과 PnR(Innovus) 라이브러리 대조</h3>
  <table class="kv">
    <tr><th>항목</th><th>합성 (syn_mcu_pad_top.tcl)</th><th>PnR (init / mmmc)</th><th>판정</th></tr>
    <tr><td>Timing lib (max)</td><td>slow_vdd1v0_basicCells, slow_vdd1v0_multibitsDFF, pads_SS_s1vg</td><td>SS 세트: 같은 3개</td><td class="ok">일치</td></tr>
    <tr><td>Timing lib (min)</td><td>없음 (slow 단일 코너)</td><td>FF 세트: fast_vdd1v0_basicCells, fast_vdd1v0_multibitsDFF, pads_FF_s1vg</td><td>PnR에만 있음 (hold용)</td></tr>
    <tr><td>Tech LEF</td><td>gsclib045_tech.lef (검색 경로 gsclib045/lef)</td><td>gsclib045<b>_tech</b>/lef/gsclib045_tech.lef</td><td class="chk">이름 같음, 폴더 다름</td></tr>
    <tr><td>Cell LEF</td><td>gsclib045_macro.lef</td><td>gsclib045_macro.lef + gsclib045_multibitsDFF.lef</td><td class="chk">PnR에 multibitsDFF LEF 추가</td></tr>
    <tr><td>IO LEF</td><td>giolib045.lef</td><td>giolib045<b>_modify</b>.lef</td><td class="chk">파일명 다름</td></tr>
    <tr><td>QRC tech</td><td>gsclib045<b>_tech</b>/qrc/qx/gpdk045.tch</td><td>gsclib045/qrc/qx/gpdk045.tch</td><td class="chk">이름 같음, 폴더 다름</td></tr>
    <tr><td>Cap table</td><td>없음</td><td>cln28hpl_1p10m+alrdl_5x2yu2yz_typical.capTbl</td><td>PnR에만 있음</td></tr>
  </table>
  <p class="small">Genus 로그는 LEF·QRC를 검색 경로로 찾기 때문에 전체 경로를 찍지 않는다. 위 "폴더 다름"은 스크립트에 적힌 검색 경로 기준이다. cap table 이름에 cln28hpl이 들어가 있지만 GPDK045 captable 폴더 안의 파일이고, 이번 작업에서 내용은 확인하지 않았다.</p>
  <div class="warn"><b>재현성 메모.</b> PnR에 들어간 넷리스트는 11/10 합성 출력 끝에 <code>5_PNR/add_pad</code>의 전원 패드 16개(PADVDD/PADVSS/PADVDDIOR/PADVSSIOR)를 붙인 파일이었다(git f6bb71b).
  지금 <code>3_SYN/mapped/mcu_pad_top_syn_final.v</code>는 11/19 재합성본이라 이 16줄이 없다. 0_InitDesign.tcl을 지금 그대로 다시 돌리려면 add_pad를 넷리스트 끝에 다시 붙여야 한다.</div>
  {code(S["mmmc"])}
  {code(S["pad"], note="넷리스트의 endmodule 앞에 붙인 전원 패드 16개. 변마다 VSSIOR, VDD, VSS, VDDIOR 하나씩이다.")}
</section>

<section>
  <h2><span class="num">5</span>확인 질문 답과 근거</h2>
  <h3>확인 4. 10 ns 합성에 쓴 SDC</h3>
  <ul>
    <li><b>파일:</b> <code>V1/TOP/3_SYN/cons/mcu_pad_top.sdc</code> (2장 전문). 따로 된 "10 ns용" 파일은 없다. 같은 파일의 주기만 바꿔 가며 썼다.</li>
    <li><b>주기 이력 (git):</b> 11/10 이전 <code>$CLK_PERIOD</code> 변수(합성 출력 SDC는 10.0) → 11/17 커밋 <code>-period 5</code> → 11/19 00:21 커밋 <code>-period 10</code>. 20 ns, 2.5 ns 때의 SDC는 저장소에 없다.</li>
    <li><b>입력 구동:</b> 10 ns 합성은 <code>set_driving_cell PADDI</code>로 돌았다. 2.5 ns에서 고친 <code>set_input_transition 0.1</code>은 적용되지 않았다 (2장 주의 박스).</li>
    <li><b>PnR 쪽 SDC:</b> Innovus는 <code>3_SYN/mapped/mcu_pad_top_syn_final.sdc</code>(Genus write_sdc 출력)를 읽었다. 저장된 PlaceOpt, PostCTSopt, RouteDesign, ChipFinish DB의 FUNC.sdc 모두 period 10.000000이고 set_driving_cell PADDI가 들어 있다.</li>
  </ul>
  <h3>확인 5. Conformal 1과 pre-layout 시뮬 넷리스트</h3>
  <table class="kv">
    <tr><th></th><th>Conformal 1 (RTL ↔ 합성)</th><th>Pre-layout 시뮬</th></tr>
    <tr><td>Revised / DUT</td><td><code>../3_SYN/mapped/mcu_pad_top_syn_final.v</code></td><td><code>2_SIM/PRE/mcu_pad_top_syn_final.v</code> (run_pre.tcl이 3_SYN/mapped에서 복사)</td></tr>
    <tr><td>실행 시점</td><td>11/10 (로그 커밋 1fe5089 "EC PNR done", 11/10 23:56). V1의 log/all.log와 같은 내용</td><td>11/10 01:21~01:37 (pre_sim.log TOOL 행)</td></tr>
    <tr><td>그때 넷리스트</td><td>11/10 00:24 생성본. 다음 넷리스트 변경은 11/17 커밋(5 ns)이라 그 사이 다른 넷리스트가 없다</td><td>파일 3행 "Generated on: Nov 10 2026 00:24:47"</td></tr>
    <tr><td>클럭</td><td colspan="2">10 ns. 같은 넷리스트를 읽은 Innovus init(11/10 02:13)의 SDC가 period 10이다</td></tr>
    <tr><td>결과</td><td>PASS, Equivalent 1,824 (출력 8 + 플립플롭 1,816)</td><td>PASS tb_mcu_top, 8645 ns 종료</td></tr>
  </table>
  <ul>
    <li>5 ns 넷리스트(Genus 11/13 01:36 생성, 11/17 커밋)로 돌린 Conformal이나 pre-sim 로그는 없다.</li>
    <li>11/19 10 ns 재합성 넷리스트(현재 3_SYN/mapped)와 11/10 넷리스트를 비교하면 3행(생성 시각) 한 줄만 다르다. SDF도 DATE 한 줄만 다르다. 그래서 "10 ns 재합성 넷리스트로 돌렸다"고 써도 내용상 틀리지 않지만, 실제로 실행한 날짜는 11/10이다.</li>
  </ul>
</section>
"""

css = """
@page { size: A4; }
:root { --ink:#1d2330; --muted:#5b6475; --line:#d9dde5; --accent:#c2550f; --accent-bg:#fff4ea; --code-bg:#f6f7f9; --ok:#1f7a3f; }
* { box-sizing: border-box; }
body { font-family: "WenQuanYi Zen Hei", "Noto Sans CJK KR", sans-serif; color: var(--ink); font-size: 9.6pt; line-height: 1.5; margin:0; background:#fff; }
h1 { font-size: 21pt; margin: 4px 0 8px; letter-spacing:-0.3px; }
h2 { font-size: 14.5pt; margin: 0 0 8px; padding-bottom: 5px; border-bottom: 2px solid var(--ink); }
h2 .num { display:inline-block; background: var(--ink); color:#fff; width: 22px; text-align:center; margin-right:8px; border-radius:3px; }
h2 small { font-size: 9pt; color: var(--accent); font-weight: normal; margin-left: 8px; }
h3 { font-size: 11pt; margin: 14px 0 6px; }
section { page-break-before: always; }
.kicker { color: var(--accent); font-size: 9pt; letter-spacing: .3px; }
.lead { color: var(--muted); margin: 0 0 14px; }
table { border-collapse: collapse; width: 100%; margin: 8px 0 12px; font-size: 8.8pt; }
th, td { border: 1px solid var(--line); padding: 4px 6px; text-align: left; vertical-align: top; }
th { background: #eef0f4; }
td.ok { color: var(--ok); font-weight: bold; }
td.chk { color: var(--accent); font-weight: bold; }
.imp td:nth-child(3) { word-break: break-all; }
code { font-family: "DejaVu Sans Mono", monospace; font-size: 8.4pt; background: var(--code-bg); padding: 0 3px; border-radius: 2px; word-break: break-all; }
.answers { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; margin-top: 6px; }
.ans { border: 1.5px solid var(--accent); background: var(--accent-bg); border-radius: 5px; padding: 8px 10px; }
.ans .q { font-weight: bold; color: var(--accent); margin-bottom: 4px; }
.ans p { margin: 0; }
.warn { border-left: 4px solid var(--accent); background: var(--accent-bg); padding: 7px 10px; margin: 8px 0 12px; font-size: 9pt; }
.note { border-left: 4px solid #8a94a8; background: #f3f5f8; padding: 7px 10px; margin: 8px 0 12px; font-size: 9pt; }
.small { font-size: 8.4pt; color: var(--muted); }
.file { border: 1px solid var(--line); border-radius: 4px; margin: 8px 0 12px; }
.fh { display:flex; justify-content: space-between; background: #2a3140; color: #fff; padding: 3px 8px; font-family: "DejaVu Sans Mono", monospace; font-size: 8pt; border-radius: 4px 4px 0 0; }
.fnote { margin: 0; padding: 4px 8px; font-size: 8.4pt; color: var(--muted); border-bottom: 1px solid var(--line); background:#fafbfc; }
pre { margin: 0; padding: 6px 8px; background: var(--code-bg); font-family: "DejaVu Sans Mono", monospace; font-size: 6.9pt; line-height: 1.38; white-space: pre-wrap; word-break: break-all; }
ul { margin: 4px 0 10px; padding-left: 18px; }
li { margin: 3px 0; }
"""

OUT.write_text(f"""<!doctype html><html lang="ko"><head><meta charset="utf-8">
<title>MCU V1 포트폴리오 보완 자료</title><style>{css}</style></head><body>{body}</body></html>""")
print("wrote", OUT)
