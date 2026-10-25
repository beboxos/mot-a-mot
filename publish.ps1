# Prepare le site GitHub Pages de Mot a Mot a partir de la derniere version (index-vX.Y.html).
param(
    [string]$Game,
    [switch]$Push
)
$ErrorActionPreference = 'Stop'
$web = $PSScriptRoot

if (-not $Game) {
    $Game = Get-ChildItem (Join-Path $web '..') -Filter 'index-v*.html' |
        Sort-Object { [version](($_.BaseName -replace '^index-v', '') + '.0') } |
        Select-Object -Last 1 | ForEach-Object FullName
}
$html = Get-Content -Raw -Encoding UTF8 $Game
$m = [regex]::Match($html, "GAME_VERSION = '([^']+)'")
if (-not $m.Success) { throw "GAME_VERSION introuvable dans $Game" }
$version = $m.Groups[1].Value

$pwaHead = @'
<link rel="manifest" href="manifest.webmanifest">
<link rel="apple-touch-icon" href="icon-180.png">
<link rel="icon" type="image/png" sizes="192x192" href="icon-192.png">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
<meta name="apple-mobile-web-app-title" content="Mot a Mot">
'@
$swScript = @'
<script>
  if ('serviceWorker' in navigator && location.protocol === 'https:') {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
</script>
'@
if ($html -notmatch '</head>' -or $html -notmatch '</body>') { throw "Structure HTML inattendue dans $Game" }
$html = $html.Replace('</head>', $pwaHead + '</head>').Replace('</body>', $swScript + '</body>')
$utf8 = New-Object Text.UTF8Encoding($false)
[IO.File]::WriteAllText((Join-Path $web 'index.html'), $html, $utf8)
[IO.File]::WriteAllText((Join-Path $web '.nojekyll'), '', $utf8)

$sw = [IO.File]::ReadAllText((Join-Path $web 'sw.js'), [Text.Encoding]::UTF8)
$sw = [regex]::Replace($sw, "const CACHE = 'motamot-[^']*';", "const CACHE = 'motamot-$version';")
[IO.File]::WriteAllText((Join-Path $web 'sw.js'), $sw, $utf8)

[IO.File]::WriteAllText((Join-Path $web 'version.json'), "{ `"version`": `"$version`" }`n", $utf8)

Write-Host "Site prepare : version $version (depuis $Game)"

if ($Push) {
    Push-Location $web
    try {
        git add -A
        git commit -m "Mot a Mot v$version"
        git push
    } finally { Pop-Location }
}
