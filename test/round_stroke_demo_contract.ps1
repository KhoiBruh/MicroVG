$ErrorActionPreference = 'Stop'

$main = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\main.c3')

function Require-Match([string]$Text, [string]$Pattern, [string]$Name) {
	if ($Text -notmatch $Pattern) { throw "Missing contract: $Name" }
}

Require-Match $main 'nvgCreateGl3\(glbackend::ANTIALIAS\);' 'demo uses antialiasing without stencil strokes'
Require-Match $main 'vg\.strokeWidth\(2\.0f\);\s*vg\.lineCap\(LineCap\.ROUND\);' 'thin round-cap demo stroke'
Require-Match $main 'vg\.strokeWidth\(12\.0f\);\s*vg\.lineJoin\(LineJoin\.ROUND\);' 'thick round-join demo stroke'

$acuteA = @(930.0, 430.0); $acuteB = @(950.0, 470.0); $acuteC = @(920.0, 450.0)
$acuteDot = ($acuteA[0] - $acuteB[0]) * ($acuteC[0] - $acuteB[0]) + ($acuteA[1] - $acuteB[1]) * ($acuteC[1] - $acuteB[1])
$acuteCross = ($acuteB[0] - $acuteA[0]) * ($acuteC[1] - $acuteB[1]) - ($acuteB[1] - $acuteA[1]) * ($acuteC[0] - $acuteB[0])
if ($acuteDot -le 0 -or $acuteCross -le 0) { throw 'Acute left join contract is not acute and left-turning' }
Require-Match $main 'vg\.moveTo\(930\.0f, 430\.0f\);\s*vg\.lineTo\(950\.0f, 470\.0f\);\s*vg\.lineTo\(920\.0f, 450\.0f\);' 'acute left round join demo stroke'

$obtuseA = @(930.0, 540.0); $obtuseB = @(950.0, 510.0); $obtuseC = @(970.0, 470.0)
$obtuseDot = ($obtuseA[0] - $obtuseB[0]) * ($obtuseC[0] - $obtuseB[0]) + ($obtuseA[1] - $obtuseB[1]) * ($obtuseC[1] - $obtuseB[1])
$obtuseCross = ($obtuseB[0] - $obtuseA[0]) * ($obtuseC[1] - $obtuseB[1]) - ($obtuseB[1] - $obtuseA[1]) * ($obtuseC[0] - $obtuseB[0])
if ($obtuseDot -ge 0 -or $obtuseCross -ge 0) { throw 'Obtuse right join contract is not obtuse and right-turning' }
Require-Match $main 'vg\.moveTo\(930\.0f, 540\.0f\);\s*vg\.lineTo\(950\.0f, 510\.0f\);\s*vg\.lineTo\(970\.0f, 470\.0f\);' 'obtuse right round join demo stroke'
