# Script untuk mengganti logo image dengan text-based logo di semua HTML files

$WorkspaceRoot = "c:\KULIAH\MAGANG\Magang di Perhutani\berita purwasuka"
$htmlFiles = Get-ChildItem -Path $WorkspaceRoot -Recurse -Include "*.html" -File

$textBasedLogo = @"
<span style="display:inline-flex; align-items:baseline; gap:4px; line-height:1;"><span style="font-weight:700; color:#92400E; font-size:24px; letter-spacing:-0.5px;">BERITA</span><span style="color:#6B3D51; font-weight:500; font-size:16px; letter-spacing:0.8px;">PURWASUKA</span></span>
"@

$replaceCount = 0

foreach ($file in $htmlFiles) {
    try {
        $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
        $originalContent = $content
        
        # Replace legacy image-based logo with text-based logo in navbar-brand
        $legacyLogoName = 'logo' + '\.png'
        $pattern1 = '<img src="img/' + $legacyLogoName + '"[^>]*>'
        $pattern2 = '<img[^>]*src="img/' + $legacyLogoName + '"[^>]*>'

        $newContent = $content -replace $pattern1, $textBasedLogo
        $newContent = $newContent -replace $pattern2, $textBasedLogo

        # Also replace src="../img/..." for article pages
        $pattern3 = '<img[^>]*src="\.\.\/img\/' + $legacyLogoName + '"[^>]*>'
        $newContent = $newContent -replace $pattern3, $textBasedLogo
        
        if ($newContent -ne $content) {
            Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8 -NoNewline
            $replaceCount++
            Write-Host "Updated logo in: $($file.Name)"
        }
    } catch {
        Write-Host "Error processing $($file.FullName): $_" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Logo replacement complete!"
Write-Host "Total files updated: $replaceCount"
