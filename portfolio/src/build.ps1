$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$base   = 'C:\Users\user\AppData\Local\Temp\claude\0e20b44bd2e8ba0b\fec71128-77cb-41a7-8266-151bef26b879\scratchpad'
$assets = 'C:\Users\user\Downloads\PROJECT4\portfolio\assets'
$out    = 'C:\Users\user\Downloads\PROJECT4\portfolio\MCU_RTL_to_GDS2_portfolio.pptx'
$json   = [IO.File]::ReadAllText("$base\deck.json", [Text.Encoding]::UTF8) | ConvertFrom-Json
$FONT = 'Malgun Gothic'

function RGBc([string]$hex){ $r=[Convert]::ToInt32($hex.Substring(0,2),16); $g=[Convert]::ToInt32($hex.Substring(2,2),16); $b=[Convert]::ToInt32($hex.Substring(4,2),16); return ($r + 256*$g + 65536*$b) }
$ACC='0A7A74'; $DARK='0B1F26'; $FG='13202A'; $MUT='5A6B76'; $BG='F3F6F7'; $LINE='D5DDE1'; $WARN='A8510A'

function SetFont($tr,[double]$size,[bool]$bold,[string]$hex){
  $tr.Font.Name=$FONT; $tr.Font.NameFarEast=$FONT; $tr.Font.Size=$size; $tr.Font.Bold=[int]($(if($bold){-1}else{0})); $tr.Font.Color.RGB=(RGBc $hex)
}
function AddText($s,$x,$y,$w,$h,[string]$text,[double]$size,[bool]$bold,[string]$hex,[string]$al){
  $sh=$s.Shapes.AddTextbox(1,$x,$y,$w,$h)
  $tf=$sh.TextFrame; $tf.WordWrap=-1; $tf.AutoSize=0; $tf.MarginLeft=0;$tf.MarginRight=0;$tf.MarginTop=0;$tf.MarginBottom=0
  $sh.Height=$h
  $tr=$tf.TextRange; $tr.Text=($text -replace "`n","`r")
  SetFont $tr $size $bold $hex
  if($al -eq 'c'){$tr.ParagraphFormat.Alignment=2}elseif($al -eq 'r'){$tr.ParagraphFormat.Alignment=3}else{$tr.ParagraphFormat.Alignment=1}
  if($tr.Paragraphs().Count -gt 1 -and -not $bold){ $tr.Paragraphs(1).Font.Bold=-1; $tr.Paragraphs(1).ParagraphFormat.SpaceAfter=3 }
  return $sh
}
function AddBullets($s,$e){
  $items=@($e.items); $plain=@(); foreach($it in $items){ $plain += ($it -replace '\|\|','') }
  $sh=$s.Shapes.AddTextbox(1,$e.x,$e.y,$e.w,$e.h)
  $tf=$sh.TextFrame; $tf.WordWrap=-1; $tf.AutoSize=0; $tf.MarginLeft=0;$tf.MarginRight=0;$tf.MarginTop=0;$tf.MarginBottom=0
  $sh.Height=$e.h
  $tr=$tf.TextRange; $tr.Text=($plain -join "`r")
  SetFont $tr $e.s $false $FG
  $tr.ParagraphFormat.Alignment=1
  $tr.ParagraphFormat.SpaceAfter=[double]$e.s*0.55; $tr.ParagraphFormat.SpaceWithin=1.05
  $tr.ParagraphFormat.Bullet.Visible=-1; $tr.ParagraphFormat.Bullet.Character=8226; $tr.ParagraphFormat.Bullet.Font.Color.RGB=(RGBc $ACC)
  $tf.Ruler.Levels(1).FirstMargin=0; $tf.Ruler.Levels(1).LeftMargin=[double]$e.s*1.1
  for($i=0;$i -lt $items.Count;$i++){
    $idx=$items[$i].IndexOf('||')
    if($idx -gt 0){ $p=$tr.Paragraphs($i+1); $c=$p.Characters(1,$idx); $c.Font.Bold=-1; $c.Font.Color.RGB=(RGBc $DARK) }
  }
  return $sh
}
function AddImg($s,$e){
  $f=$e.f; if($f -notmatch ':'){ $f="$assets\$f.jpg" }
  $im=[Drawing.Image]::FromFile($f); $iw=$im.Width; $ih=$im.Height; $im.Dispose()
  $k=[Math]::Min($e.w/$iw,$e.h/$ih); $w=$iw*$k; $h=$ih*$k
  $x=$e.x+($e.w-$w)/2; $y=$e.y+($e.h-$h)/2
  $p=$s.Shapes.AddPicture($f,0,-1,$x,$y,$w,$h)
  $p.Line.Visible=-1; $p.Line.ForeColor.RGB=(RGBc $LINE); $p.Line.Weight=0.75
  $p.AlternativeText=[string]$e.alt
  return $p
}
function AddStat($s,$e){
  $sh=$s.Shapes.AddShape(1,$e.x,$e.y,$e.w,$e.h)
  $sh.Fill.ForeColor.RGB=(RGBc 'FFFFFF'); $sh.Line.ForeColor.RGB=(RGBc $LINE); $sh.Line.Weight=0.75; $sh.Shadow.Visible=0
  $tf=$sh.TextFrame; $tf.WordWrap=-1; $tf.MarginLeft=14;$tf.MarginRight=10;$tf.MarginTop=8;$tf.MarginBottom=8; $tf.VerticalAnchor=3
  $tr=$tf.TextRange; $tr.Text=($e.v + "`r" + $e.l)
  SetFont $tr 13 $false $MUT; $tr.ParagraphFormat.Alignment=1
  $p1=$tr.Paragraphs(1); $p1.Font.Size=26; $p1.Font.Bold=-1; $p1.Font.Color.RGB=(RGBc $ACC)
  return $sh
}
function AddCard($s,$e){
  $sh=$s.Shapes.AddShape(1,$e.x,$e.y,$e.w,$e.h)
  $col=$LINE; $hc=$DARK; if($e.redo){ $col=$WARN; $hc=$WARN }
  $sh.Fill.ForeColor.RGB=(RGBc 'FFFFFF'); $sh.Line.ForeColor.RGB=(RGBc $col); $sh.Line.Weight=$(if($e.redo){1.5}else{0.75}); $sh.Shadow.Visible=0
  $tf=$sh.TextFrame; $tf.WordWrap=-1; $tf.MarginLeft=18;$tf.MarginRight=10; $tf.VerticalAnchor=3
  $tr=$tf.TextRange; $tr.Text=($e.head + "`r" + $e.sub)
  SetFont $tr 14 $false $MUT; $tr.ParagraphFormat.Alignment=1
  $p1=$tr.Paragraphs(1); $p1.Font.Size=20; $p1.Font.Bold=-1; $p1.Font.Color.RGB=(RGBc $hc); $p1.ParagraphFormat.SpaceAfter=4
  return $sh
}
function AddTable($s,$e){
  $rows=@($e.rows); $nr=$rows.Count; $nc=@($e.cols).Count
  $sh=$s.Shapes.AddTable($nr,$nc,$e.x,$e.y,$e.w,[double]($nr*28))
  $t=$sh.Table
  for($c=1;$c -le $nc;$c++){ $t.Columns($c).Width=[double]$e.cols[$c-1] }
  $hl=@(); if($e.hl){ $hl=@($e.hl) }
  for($r=1;$r -le $nr;$r++){
    $row=@($rows[$r-1])
    for($c=1;$c -le $nc;$c++){
      $cell=$t.Cell($r,$c); $tr=$cell.Shape.TextFrame.TextRange
      $tr.Text=[string]$row[$c-1]
      $cell.Shape.TextFrame.MarginTop=4; $cell.Shape.TextFrame.MarginBottom=4; $cell.Shape.TextFrame.MarginLeft=10; $cell.Shape.TextFrame.MarginRight=10
      $cell.Shape.TextFrame.VerticalAnchor=3
      $al=$e.al[$c-1]
      if($al -eq 'r'){$tr.ParagraphFormat.Alignment=3}else{$tr.ParagraphFormat.Alignment=1}
      if($r -eq 1){
        SetFont $tr ([double]$e.s-1) $true 'FFFFFF'; $cell.Shape.Fill.ForeColor.RGB=(RGBc $ACC)
      } else {
        $hc=$FG; if($hl -contains ($r-1)){ $hc=$WARN }
        SetFont $tr $e.s $false $hc
        if($r % 2 -eq 0){ $cell.Shape.Fill.ForeColor.RGB=(RGBc 'FFFFFF') } else { $cell.Shape.Fill.ForeColor.RGB=(RGBc 'EAF0F2') }
      }
      $b=$cell.Borders(3); $b.Visible=-1; $b.ForeColor.RGB=(RGBc $LINE); $b.Weight=0.75
    }
  }
  return $sh
}

$app=New-Object -ComObject PowerPoint.Application
$pres=$app.Presentations.Add(-1)
$pres.PageSetup.SlideWidth=960; $pres.PageSetup.SlideHeight=540
$n=0
foreach($sd in $json.slides){
  $n++
  $s=$pres.Slides.Add($n,11)  # title only
  $s.FollowMasterBackground=0
  if($sd.kind -eq 'title'){ $s.Background.Fill.ForeColor.RGB=(RGBc $DARK) } else { $s.Background.Fill.ForeColor.RGB=(RGBc $BG) }
  $ttl=$s.Shapes.Title
  if($sd.kind -eq 'title'){
    $ttl.Left=60;$ttl.Top=155;$ttl.Width=840;$ttl.Height=80
    $ttl.TextFrame.MarginLeft=0;$ttl.TextFrame.MarginTop=0;$ttl.TextFrame.MarginBottom=0;$ttl.TextFrame.WordWrap=-1;$ttl.TextFrame.AutoSize=0;$ttl.TextFrame.VerticalAnchor=1
    $ttl.TextFrame.TextRange.Text='MCU RTL to GDS2'
    SetFont $ttl.TextFrame.TextRange 54 $true 'FFFFFF'
    $ttl.TextFrame.TextRange.ParagraphFormat.Alignment=1
  } else {
    $tc=$ACC; if($sd.redo){ $tc=$WARN }
    $tg=AddText $s 40 22 880 18 ([string]$sd.tag) 12 $true $tc 'l'; $tg.Name='tag'
    $ttl.Left=40;$ttl.Top=42;$ttl.Width=880;$ttl.Height=44
    $ttl.TextFrame.MarginLeft=0;$ttl.TextFrame.MarginTop=0;$ttl.TextFrame.MarginBottom=0;$ttl.TextFrame.WordWrap=-1;$ttl.TextFrame.AutoSize=0;$ttl.TextFrame.VerticalAnchor=1
    $ttl.TextFrame.TextRange.Text=[string]$sd.title
    SetFont $ttl.TextFrame.TextRange 26 $true $DARK
    $ttl.TextFrame.TextRange.ParagraphFormat.Alignment=1
  }
  foreach($e in $sd.els){
    switch($e.t){
      'text' { $null=AddText $s $e.x $e.y $e.w $e.h ([string]$e.text) ([double]$e.s) ([bool]$e.b) ([string]$e.c) ([string]$e.a) }
      'bul'  { $null=AddBullets $s $e }
      'img'  { $null=AddImg $s $e }
      'stat' { $null=AddStat $s $e }
      'card' { $null=AddCard $s $e }
      'tbl'  { $null=AddTable $s $e }
    }
  }
}
if(Test-Path $out){ Remove-Item $out -Force }
$pres.SaveAs($out)
$exp="$base\png"; if(Test-Path $exp){ Remove-Item $exp -Recurse -Force }; New-Item -ItemType Directory $exp | Out-Null
$pres.Export($exp,'PNG',1280,720)
$cnt=$pres.Slides.Count
$pres.Close(); $app.Quit()
"slides: $cnt"
