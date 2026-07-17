$ErrorActionPreference = 'Stop'

$main = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\main.c3')

function Require-Match([string]$Text, [string]$Pattern, [string]$Name) {
	if ($Text -notmatch $Pattern) { throw "Missing contract: $Name" }
}

Require-Match $main 'nvgCreateGl3\(glbackend::ANTIALIAS\);' 'demo uses antialiasing without stencil strokes'
Require-Match $main 'vg\.strokeWidth\(2\.0f\);\s*vg\.lineCap\(LineCap\.ROUND\);' 'thin round-cap demo stroke'

function Float-Pattern([double]$Value) {
	return ([string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:0.0}', $Value)).Replace('.', '\.')
}

function Require-RoundJoin([double[]]$Points, [string]$Color, [string]$Name, [bool]$Acute, [bool]$Left) {
	$ax = Float-Pattern $Points[0]; $ay = Float-Pattern $Points[1]
	$bx = Float-Pattern $Points[2]; $by = Float-Pattern $Points[3]
	$cx = Float-Pattern $Points[4]; $cy = Float-Pattern $Points[5]
	$colorPattern = $Color.Replace(', ', ',\s*')
	$pattern = "(?s)vg\.beginPath\(\);\s*vg\.moveTo\($ax" + "f, $ay" + "f\);\s*vg\.lineTo\($bx" + "f, $by" + "f\);\s*vg\.lineTo\($cx" + "f, $cy" + "f\);\s*vg\.strokeColor\(microvg::rgba\($colorPattern\)\);\s*vg\.strokeWidth\(12\.0f\);\s*vg\.lineJoin\(LineJoin\.ROUND\);\s*vg\.lineCap\(LineCap\.ROUND\);\s*vg\.stroke\(\);"
	Require-Match $main $pattern "$Name round-join demo stroke and style"

	$prevX = $Points[2] - $Points[0]; $prevY = $Points[3] - $Points[1]
	$nextX = $Points[4] - $Points[2]; $nextY = $Points[5] - $Points[3]
	$dot = -$prevX * $nextX - $prevY * $nextY
	$engineCross = $nextX * $prevY - $prevX * $nextY
	if ($Acute -and $dot -le 0) { throw "$Name join is not acute" }
	if (!$Acute -and $dot -ge 0) { throw "$Name join is not obtuse" }
	if ($Left -and $engineCross -le 0) { throw "$Name join is not left-turning in the renderer" }
	if (!$Left -and $engineCross -ge 0) { throw "$Name join is not right-turning in the renderer" }
}

Require-RoundJoin @(930.0, 430.0, 950.0, 470.0, 980.0, 450.0) '255, 180, 0, 255' 'acute left' $true $true
Require-RoundJoin @(930.0, 540.0, 950.0, 510.0, 980.0, 520.0) '0, 220, 255, 255' 'obtuse right' $false $false
