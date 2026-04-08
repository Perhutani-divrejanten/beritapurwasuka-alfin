$ErrorActionPreference = 'Stop'

$workspace = $PSScriptRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Read-Utf8 {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Utf8 {
    param([string]$Path, [string]$Content)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Normalize-Text {
    param([string]$Content)

    $Content = $Content.Replace([char]0x201C, '"').Replace([char]0x201D, '"')
    $Content = $Content.Replace([char]0x2018, "'").Replace([char]0x2019, "'")
    $Content = $Content.Replace([char]0x2013, '-').Replace([char]0x2014, '-')
    $Content = $Content.Replace([char]0x00A0, ' ').Replace([char]0xFFFD, ' ')
    return $Content
}

function Apply-Map {
    param(
        [string]$Content,
        [hashtable]$Map
    )

    foreach ($key in $Map.Keys) {
        $Content = $Content -replace [regex]::Escape($key), $Map[$key]
    }

    return $Content
}

$summary = [ordered]@{
    main_pages = 0
    article_pages = 0
    css = 0
    package = 0
    docs = 0
}

$baseReplacements = [ordered]@{
    ('Indonesia' + ' Daily') = 'berita purwasuka'
    ('Indonesia' + 'Daily') = 'beritapurwasuka'
    ('Warta' + ' Janten') = 'berita purwasuka'
    ('Warta' + 'Janten') = 'beritapurwasuka'
    ('Berita' + ' Purwasuka') = 'berita purwasuka'
    (('Warta' + 'Janten33') + '@gmail.com') = 'beritapurwasuka@gmail.com'
    (('Warta' + 'Janten') + '@gmail.com') = 'beritapurwasuka@gmail.com'
    (('indonesia' + 'daily') + '@gmail.com') = 'beritapurwasuka@gmail.com'
    ('../img/' + 'logo' + '.png') = '../img/favicon.ico'
    ('img/' + 'logo' + '.png') = 'img/favicon.ico'
    ('logo' + '.png') = 'favicon.ico'
}

$themeReplacements = [ordered]@{
    '#065F46' = '#92400E'
    '#022C22' = '#3B1F07'
    '#1E3A5F' = '#6B3D51'
    '#FFCC00' = '#92400E'
    '#FC0' = '#92400E'
    '#1E2024' = '#3B1F07'
    '#31404B' = '#6B3D51'
    '#b38f00' = '#6B3D51'
    'rgb(6, 95, 70)' = 'rgb(146, 64, 14)'
    'rgb(2, 44, 34)' = 'rgb(59, 31, 7)'
    'rgb(30, 58, 95)' = 'rgb(107, 61, 81)'
}

$logoMarkup = '<span style="display:inline-flex; align-items:baseline; gap:4px; line-height:1;"><span style="font-weight:700; color:#92400E; font-size:24px; letter-spacing:-0.5px;">BERITA</span><span style="color:#6B3D51; font-weight:500; font-size:16px; letter-spacing:0.8px;">PURWASUKA</span></span>'

Write-Host '=== Rebrand berita purwasuka dimulai ==='

$articlesPath = Join-Path $workspace 'articles.json'
$backupPath = Join-Path $workspace 'articles.json.bak'
if (Test-Path $articlesPath) {
    Copy-Item -Path $articlesPath -Destination $backupPath -Force
    Write-Host "Backup articles.json -> articles.json.bak"
}

# HTML pages - sesuai permintaan menggunakan Get-ChildItem -Recurse -Include *.html | ForEach-Object {...}
Get-ChildItem -Path $workspace -Recurse -Include *.html -File |
    Where-Object { $_.FullName -notmatch '\\node_modules\\' } |
    ForEach-Object {
        $file = $_
        $content = Read-Utf8 $file.FullName
        $original = $content

        $content = Normalize-Text $content
        $content = Apply-Map -Content $content -Map $baseReplacements
        $content = Apply-Map -Content $content -Map $themeReplacements

        $content = [regex]::Replace(
            $content,
            '<a([^>]*class="navbar-brand[^"]*"[^>]*)>\s*.*?\s*</a>',
            ('<a$1>' + $logoMarkup + '</a>'),
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline
        )

        $content = [regex]::Replace(
            $content,
            '(?i)<img([^>]*?)src="(?:\.\./)?img/fav(?:icon)?\.ico"([^>]*?)alt="[^"]*"([^>]*?)>',
            '<span class="sr-only">beritapurwasuka</span>'
        )

        $content = $content -replace '>\s*berita purwasuka\s*<', '>berita purwasuka<'

        if ($content -ne $original) {
            Write-Utf8 -Path $file.FullName -Content $content
            if ($file.FullName -match '\\article\\') {
                $summary.article_pages++
            } else {
                $summary.main_pages++
            }
        }
    }

# CSS theme updates
Get-ChildItem -Path (Join-Path $workspace 'css') -Recurse -Include *.css -File | ForEach-Object {
    $file = $_
    $content = Read-Utf8 $file.FullName
    $original = $content

    $content = Normalize-Text $content
    $content = Apply-Map -Content $content -Map $themeReplacements
    $content = $content -replace '--primary:\s*#[0-9A-Fa-f]{3,6};', '--primary: #92400E;'
    $content = $content -replace '--dark:\s*#[0-9A-Fa-f]{3,6};', '--dark: #3B1F07;'
    $content = $content -replace '--secondary:\s*#[0-9A-Fa-f]{3,6};', '--secondary: #6B3D51;'

    if ($content -ne $original) {
        Write-Utf8 -Path $file.FullName -Content $content
        $summary.css++
    }
}

# Package metadata
$packageFiles = @(
    (Join-Path $workspace 'package.json'),
    (Join-Path $workspace 'package-lock.json'),
    (Join-Path $workspace 'tools\package.json'),
    (Join-Path $workspace 'tools\package-lock.json')
) | Where-Object { Test-Path $_ }

foreach ($filePath in $packageFiles) {
    $content = Read-Utf8 $filePath
    $original = $content
    $content = Normalize-Text $content
    $content = Apply-Map -Content $content -Map $baseReplacements
    $content = $content -replace '"name"\s*:\s*"[^"]+"', '"name": "beritapurwasuka"'

    if ($filePath -match 'tools\\package\.json$|tools\\package-lock\.json$') {
        $content = $content -replace '"name"\s*:\s*"[^"]+"', '"name": "beritapurwasuka-article-generator"'
        $content = $content -replace 'Generator artikel otomatis dari Google Sheets untuk [^"]+', 'Generator artikel otomatis dari Google Sheets untuk berita purwasuka'
    }

    if ($content -ne $original) {
        Write-Utf8 -Path $filePath -Content $content
        $summary.package++
    }
}

# Documentation / config / scripts
Get-ChildItem -Path $workspace -Recurse -Include *.md,*.toml,*.txt,*.js,*.ps1 -File |
    Where-Object { $_.FullName -notmatch '\\node_modules\\' -and $_.Name -ne 'rebrand-to-berita-purwasuka.ps1' } |
    ForEach-Object {
        $file = $_
        $content = Read-Utf8 $file.FullName
        $original = $content

        $content = Normalize-Text $content
        $content = Apply-Map -Content $content -Map $baseReplacements
        $content = Apply-Map -Content $content -Map $themeReplacements

        if ($file.Name -eq 'generate.js') {
            $content = $content -replace "return 'img/favicon.ico';", "return 'img/news-800x500-1.jpg';"
            $content = $content -replace "src\.includes\('favicon\.ico'\)", "src.includes('site-brand')"
            $legacyHandleJson = '"' + ('warta' + 'janten') + '"'
            $content = $content -replace [regex]::Escape($legacyHandleJson), '"beritapurwasuka"'
            $content = $content -replace [regex]::Escape(('Warta' + ' Janten Team')), 'berita purwasuka Team'
        }

        if ($content -ne $original) {
            Write-Utf8 -Path $file.FullName -Content $content
            if ($file.Extension -in '.md', '.toml', '.txt') {
                $summary.docs++
            }
        }
    }

Write-Host ''
Write-Host 'Jumlah file yang diubah:'
Write-Host ("- main pages    : {0}" -f $summary.main_pages)
Write-Host ("- article pages : {0}" -f $summary.article_pages)
Write-Host ("- css           : {0}" -f $summary.css)
Write-Host ("- package       : {0}" -f $summary.package)
Write-Host ("- docs          : {0}" -f $summary.docs)
Write-Host ''
Write-Host 'Rebrand berita purwasuka selesai ✅'
