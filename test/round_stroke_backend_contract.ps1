$ErrorActionPreference = 'Stop'

$context = Get-Content -Raw "$PSScriptRoot/../src/microvg/context.c3"
$path = Get-Content -Raw "$PSScriptRoot/../src/microvg/path.c3"
$backend = Get-Content -Raw "$PSScriptRoot/../src/backend/gl_backend.c3"
$fragment = Get-Content -Raw "$PSScriptRoot/../src/backend/shaders/fill.frag.glsl"

function Require-Match([string]$Text, [string]$Pattern, [string]$Name) {
	if ($Text -notmatch $Pattern) { throw "Missing contract: $Name" }
}

Require-Match $context 'fn int nvgCurveDivs\(float r, float arc, float tol\)' 'adaptive curve division helper'
Require-Match $context 'nvgCurveDivs\(w, PI, self\.tessTol\)' 'stroke uses tessellation tolerance'
Require-Match $context 'fn Vertex\* nvgRoundJoin\(' 'round join strip generator'
Require-Match $context 'fn Vertex\* nvgRoundCapStart\(' 'round cap start strip generator'
Require-Match $context 'fn Vertex\* nvgRoundCapEnd\(' 'round cap end strip generator'
Require-Match $context 'dst = nvgRoundJoin\(dst, p0, p1, w, w, u0, u1, ncap, aa\);' 'round joins enter stroke strip'
Require-Match $context 'dst = nvgRoundCapStart\(dst, p0, dx, dy, w, ncap, aa, u0, u1\);' 'round start cap enters stroke strip'
Require-Match $context 'dst = nvgRoundCapEnd\(dst, p1, dx, dy, w, ncap, aa, u0, u1\);' 'round end cap enters stroke strip'
if ($context -match 'SDF_|sdfRound|roundStroke') { throw 'SDF round stroke ownership remains in context' }
if ($path -match 'roundStroke|strokeData') { throw 'SDF path storage remains' }
if ($backend -match 'roundStroke') { throw 'SDF round range remains' }
if ($fragment -match 'fjoin|fstroke|roundStrokeCoverage|bodyStrokeCoverage') { throw 'analytic round coverage remains' }
Require-Match $fragment '#ifdef EDGE_AA\s*float strokeMask\(' 'standard NanoVG stroke mask'
