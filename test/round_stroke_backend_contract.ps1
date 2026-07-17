$ErrorActionPreference = 'Stop'

$backend = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\backend\gl_backend.c3')
$context = Get-Content -Raw (Join-Path $PSScriptRoot '..\src\microvg\context.c3')
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
Require-Match $context '\*dst = \{ x, y, inner_radius, outer_radius \};' 'round vertices encode analytic radii in texture coordinates'
Require-Match $fragment 'fstroke\.w > 0\.5' 'explicit round stroke mode'
Require-Match $fragment 'float bodyStrokeCoverage\(' 'body coverage helper'
Require-Match $fragment 'float roundStrokeCoverage\(' 'round coverage helper'
Require-Match $fragment '(?s)#ifdef EDGE_AA\s*float bodyStrokeCoverage\(\).*?\}\s*#endif\s*float roundStrokeCoverage\(' 'round coverage is available without edge AA'
Require-Match $fragment 'float inner = ftcoord\.x;' 'round coverage reads analytic inner radius'
Require-Match $fragment 'float outer = ftcoord\.y;' 'round coverage reads analytic outer radius'
Require-Match $fragment 'if \(outer <= inner\) return 1\.0 - step\(outer, dist\);' 'round coverage uses hard radius when AA span is zero'
Require-Match $fragment 'float scissorCoverage\(' 'scissor coverage helper'
Require-Match $fragment 'vec4 paintColor\(' 'shared paint helper'
if ($fragment -match 'ftcoord\.y > 1\.5') { throw 'Legacy round-stroke mode convention remains' }
if ($fragment -match 'fstroke\.z <= 0\.0') { throw 'Legacy zero-AA proxy coverage remains' }

$mainMatch = [regex]::Match($fragment, '(?s)void main\(void\) \{.*?\n\}')
if (!$mainMatch.Success) { throw 'Missing fragment main function' }
$main = $mainMatch.Value
Require-Match $main '(?s)float strokeCoverage = 1\.0;\s*if \(fstroke\.w > 0\.5\) \{\s*strokeCoverage = roundStrokeCoverage\(\);\s*\}\s*#ifdef EDGE_AA.*?#endif\s*if \(type == 0 \|\| type == 1\) result \*= strokeCoverage;' 'round coverage applies independently of edge AA'

$strokeMatch = [regex]::Match($backend, '(?s)fn void GlContext\.stroke\(&self, GlCall\* call\) \{.*?(?=\nfn void GlContext\.triangles)')
if (!$strokeMatch.Success) { throw 'Missing stroke execution path' }
$stroke = $strokeMatch.Value
$stencilStart = $stroke.IndexOf("`tif (self.flags & STENCIL_STROKES) {")
$defaultStart = $stroke.IndexOf("`telse {", $stencilStart)
$defaultEnd = $stroke.IndexOf("`n`t}`n`n`tgl::enable", $defaultStart)
if ($stencilStart -lt 0 -or $defaultStart -lt 0 -or $defaultEnd -lt 0) { throw 'Missing stroke execution branch boundary' }
$stencilStroke = $stroke.Substring($stencilStart, $defaultStart - $stencilStart)
$defaultStroke = $stroke.Substring($defaultStart, $defaultEnd - $defaultStart)
$roundDraw = 'gl::drawArrays\(GL_TRIANGLES, paths\[i\]\.roundStrokeOffset, paths\[i\]\.roundStrokeCount\);'
Require-Match $defaultStroke "(?s)GL_TRIANGLE_STRIP.*?$roundDraw" 'round triangles immediately follow each default body range'
$stencilCleanup = $stencilStroke.IndexOf('gl::disable(GL_STENCIL_TEST);')
if ($stencilCleanup -lt 0) { throw 'Stencil cleanup is missing' }
if ($stencilStroke.Substring(0, $stencilCleanup) -match $roundDraw) { throw 'Round triangles must not be added to stencil passes' }
Require-Match $stencilStroke.Substring($stencilCleanup) "(?s)gl::disable\(GL_STENCIL_TEST\);.*?self\.setUniforms\(call\.uniformOffset, call\.image\);.*?$roundDraw" 'round triangles render after stencil cleanup'
if (([regex]::Matches($defaultStroke, $roundDraw)).Count -ne 1) { throw 'Default stroke path must draw each round range once' }
if (([regex]::Matches($stencilStroke, $roundDraw)).Count -ne 1) { throw 'Stencil stroke path must draw each round range once after cleanup' }
if (([regex]::Matches($stroke, $roundDraw)).Count -ne 2) { throw 'Stroke execution must contain exactly one round draw per runtime branch' }
