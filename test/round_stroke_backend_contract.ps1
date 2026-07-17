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
