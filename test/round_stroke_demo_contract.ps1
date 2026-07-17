$ErrorActionPreference = 'Stop'

$main = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\main.c3')

function Require-Match([string]$Text, [string]$Pattern, [string]$Name) {
	if ($Text -notmatch $Pattern) { throw "Missing contract: $Name" }
}

Require-Match $main 'nvgCreateGl3\(glbackend::ANTIALIAS\);' 'demo uses antialiasing without stencil strokes'
Require-Match $main 'vg\.strokeWidth\(2\.0f\);\s*vg\.lineCap\(LineCap\.ROUND\);' 'thin round-cap demo stroke'
Require-Match $main 'vg\.strokeWidth\(12\.0f\);\s*vg\.lineJoin\(LineJoin\.ROUND\);' 'thick round-join demo stroke'
Require-Match $main 'vg\.moveTo\(930\.0f, 430\.0f\);\s*vg\.lineTo\(950\.0f, 470\.0f\);\s*vg\.lineTo\(910\.0f, 490\.0f\);' 'acute left round join demo stroke'
Require-Match $main 'vg\.moveTo\(930\.0f, 540\.0f\);\s*vg\.lineTo\(950\.0f, 510\.0f\);\s*vg\.lineTo\(910\.0f, 510\.0f\);' 'obtuse right round join demo stroke'
