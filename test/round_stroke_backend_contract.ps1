$ErrorActionPreference = 'Stop'

$backend = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\backend\gl_backend.c3')
$fragment = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\backend\shaders\fill.frag.glsl')

function Require-Match([string]$Text, [string]$Pattern, [string]$Name) {
	if ($Text -notmatch $Pattern) { throw "Missing contract: $Name" }
}

Require-Match $backend 'int roundStrokeOffset;\s*int roundStrokeCount;' 'round stroke range metadata'
Require-Match $backend 'count \+= paths\[i\]\.nroundStroke;' 'round vertices included in allocation count'
Require-Match $backend 'copy\.roundStrokeOffset = voff;\s*copy\.roundStrokeCount = path\.nroundStroke;' 'round range uses vertex offset'
Require-Match $backend 'mem::copy\(gl\.vertsBuf\.at\(voff\), path\.roundStroke, Vertex::size \* path\.nroundStroke\);' 'round vertices copied at range offset'
Require-Match $backend 'mem::copy\(gl\.strokeDataBuf\.at\(sdoff\), path\.roundStrokeData, \(sz\)16 \* path\.nroundStroke\);' 'round metadata copied at aligned data offset'
Require-Match $backend 'gl::drawArrays\(GL_TRIANGLES, paths\[i\]\.roundStrokeOffset, paths\[i\]\.roundStrokeCount\);' 'round ranges rendered as triangles'
Require-Match $fragment 'fstroke\.w > 0\.5' 'explicit round stroke mode'
Require-Match $fragment 'float bodyStrokeCoverage\(' 'body coverage helper'
Require-Match $fragment 'float roundStrokeCoverage\(' 'round coverage helper'
Require-Match $fragment 'float scissorCoverage\(' 'scissor coverage helper'
Require-Match $fragment 'vec4 paintColor\(' 'shared paint helper'
if ($fragment -match 'ftcoord\.y > 1\.5') { throw 'Legacy round-stroke mode convention remains' }

$strokeMatch = [regex]::Match($backend, '(?s)fn void GlContext\.stroke\(&self, GlCall\* call\) \{.*?(?=\nfn void GlContext\.triangles)')
if (!$strokeMatch.Success) { throw 'Missing stroke execution path' }
$stroke = $strokeMatch.Value
$defaultStart = $stroke.IndexOf("`telse {")
$defaultEnd = $stroke.IndexOf("`n`t}`n`n`tgl::enable", $defaultStart)
if ($defaultStart -lt 0 -or $defaultEnd -lt 0) { throw 'Round strokes must remain inside the default non-stencil path' }
$defaultStroke = $stroke.Substring($defaultStart, $defaultEnd - $defaultStart)
$roundDraw = 'gl::drawArrays\(GL_TRIANGLES, paths\[i\]\.roundStrokeOffset, paths\[i\]\.roundStrokeCount\);'
Require-Match $defaultStroke "(?s)GL_TRIANGLE_STRIP.*?$roundDraw" 'round triangles immediately follow each default body range'
if ($stroke.Substring(0, $defaultStart) -match $roundDraw) { throw 'Stencil stroke path must not render round triangles' }
if ($stroke.Substring($defaultEnd) -match $roundDraw) { throw 'Round triangles must not be rendered after the default path loop' }
