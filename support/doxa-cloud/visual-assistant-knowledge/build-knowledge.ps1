param(
    [switch]$Check
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = (Resolve-Path (Join-Path $Here '..\..\..')).Path
$MirrorRoot = Join-Path $Here 'source-mirror'
$ManifestPath = Join-Path $Here 'source-mirror-manifest.json'
$CuratedPath = Join-Path $Here 'incumbent_knowledge.json'
$WorkerDir = (Resolve-Path (Join-Path $Here '..\visual-assistant-worker')).Path
$TemplatePath = Join-Path $WorkerDir 'worker.template.js'
$WorkerPath = Join-Path $WorkerDir 'worker.js'

$SourceFiles = @(
    'app/README.md',
    'app/packaging/RELEASE_NOTES.md',
    'app/src/main.cpp',
    'app/src/context_overlay.cpp',
    'app/src/context_overlay.h',
    'app/src/assistant_client.cpp',
    'app/src/assistant_client.h',
    'app/src/help_window.cpp',
    'app/src/help_window.h',
    'app/src/hint_window.cpp',
    'app/src/hint_window.h',
    'app/src/settings_store.cpp',
    'app/src/settings_store.h',
    'app/src/settings_window.cpp',
    'app/src/settings_window.h',
    'app/src/core/help_catalog.h',
    'app/src/core/settings_model.h',
    'app/src/core/view_controller.h',
    'app/src/core/viewport_policy.h',
    'app/src/core/locator_model.h',
    'app/src/core/poi_evidence.h',
    'app/src/tracking/uia_evidence_provider.h',
    'app/src/tracking/win32_evidence_provider.h',
    'docs/project/foundation/visual_adoption_and_contextual_assistance_spec.md'
)

$ChunkLines = 70
$OverlapLines = 10

function Get-Sha256Hex([byte[]]$Bytes) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        return (($sha.ComputeHash($Bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FileBytes([string]$Path) {
    return [System.IO.File]::ReadAllBytes($Path)
}

function Assert-SafeSource([string]$RelativePath) {
    if ($RelativePath.Contains('..') -or [System.IO.Path]::IsPathRooted($RelativePath)) {
        throw "Unsafe source path: $RelativePath"
    }
    if ($RelativePath -match '(?i)(cloud_config|\.env|secret|token|credential)') {
        throw "Source path rejected by mirror policy: $RelativePath"
    }
}

function Get-LivePath([string]$RelativePath) {
    return Join-Path $RepoRoot ($RelativePath -replace '/', '\')
}

function Get-MirrorPath([string]$RelativePath) {
    return Join-Path $MirrorRoot ($RelativePath -replace '/', '\')
}

function Write-Utf8NoBom([string]$Path, [string]$Text) {
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8NoBom)
}

function Build-Mirror {
    if (Test-Path $MirrorRoot) {
        Remove-Item -Recurse -Force $MirrorRoot
    }
    New-Item -ItemType Directory -Force -Path $MirrorRoot | Out-Null

    $entries = @()
    foreach ($rel in $SourceFiles) {
        Assert-SafeSource $rel
        $src = Get-LivePath $rel
        if (-not (Test-Path $src)) { throw "Missing source: $rel" }
        $bytes = Get-FileBytes $src
        $dest = Get-MirrorPath $rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        [System.IO.File]::WriteAllBytes($dest, $bytes)
        $entries += [ordered]@{
            path = $rel
            bytes = $bytes.Length
            sha256 = Get-Sha256Hex $bytes
        }
    }

    $digestText = (($entries | ForEach-Object { "$($_.path):$($_.sha256)" }) -join "`n")
    $manifest = [ordered]@{
        schema_version = '1'
        generated_utc = [DateTime]::UtcNow.ToString('o')
        source_tree_sha256 = Get-Sha256Hex ([Text.Encoding]::UTF8.GetBytes($digestText))
        files = $entries
    }
    Write-Utf8NoBom $ManifestPath (($manifest | ConvertTo-Json -Depth 8) + "`n")
    return $manifest
}

function New-MirrorChunks([string]$RelativePath) {
    $mirror = Get-MirrorPath $RelativePath
    $text = [System.IO.File]::ReadAllText($mirror, [Text.Encoding]::UTF8) -replace "`r`n", "`n" -replace "`r", "`n"
    $lines = @($text -split "`n", -1)
    $extension = [System.IO.Path]::GetExtension($RelativePath).ToLowerInvariant()
    if ($extension -in @('.cpp', '.h')) { $kind = 'visual-source' }
    elseif ($extension -eq '.md') { $kind = 'visual-doc' }
    else { $kind = 'visual-reference' }

    $chunks = @()
    $start = 0
    while ($start -lt $lines.Count) {
        $end = [Math]::Min($lines.Count, $start + $ChunkLines)
        $content = (($lines[$start..($end - 1)]) -join "`n").Trim()
        if ($content.Length -gt 0) {
            $lineStart = $start + 1
            $lineEnd = $end
            $slug = ($RelativePath -replace '[^a-zA-Z0-9]+', '-').Trim('-')
            $keywords = @($RelativePath -split '[\/._-]+' | Where-Object { $_ })
            $chunks += [ordered]@{
                id = "mirror-$slug-L$lineStart-L$lineEnd"
                kind = $kind
                product = 'Visual'
                title = "$RelativePath lines $lineStart-$lineEnd"
                source_url = "repo:$RelativePath#L$lineStart-L$lineEnd"
                source_name = "Read-only Visual source mirror: $RelativePath"
                source_date_note = 'Generated from the current canonical repository working tree'
                keywords = $keywords
                content = $content
            }
        }
        if ($end -ge $lines.Count) { break }
        $start = [Math]::Max($start + 1, $end - $OverlapLines)
    }
    return $chunks
}

function Build-KnowledgeChunks {
    $curated = Get-Content -Raw -Encoding UTF8 $CuratedPath | ConvertFrom-Json
    $chunks = New-Object System.Collections.ArrayList
    $ids = @{}
    foreach ($entry in $curated) {
        if (-not $entry.id -or -not $entry.title -or -not $entry.content) {
            throw 'Curated knowledge entry is missing id/title/content'
        }
        if ($ids.ContainsKey([string]$entry.id)) { throw "Duplicate knowledge id: $($entry.id)" }
        $ids[[string]$entry.id] = $true
        [void]$chunks.Add($entry)
    }
    foreach ($rel in $SourceFiles) {
        foreach ($chunk in @(New-MirrorChunks $rel)) {
            if ($ids.ContainsKey([string]$chunk.id)) { throw "Duplicate generated knowledge id: $($chunk.id)" }
            $ids[[string]$chunk.id] = $true
            [void]$chunks.Add($chunk)
        }
    }
    return $chunks.ToArray()
}

function Build-Worker($Manifest, $Chunks) {
    $template = [System.IO.File]::ReadAllText($TemplatePath, [Text.Encoding]::UTF8)
    $marker = '__VISUAL_KNOWLEDGE_BUNDLE__'
    if (-not $template.Contains($marker)) { throw "Worker template missing $marker" }

    $flatChunks = New-Object System.Collections.ArrayList
    foreach ($item in @($Chunks)) {
        if ($item -is [System.Array]) {
            foreach ($nested in $item) { [void]$flatChunks.Add($nested) }
        }
        else {
            [void]$flatChunks.Add($item)
        }
    }
    $flatArray = $flatChunks.ToArray()
    $bundle = [ordered]@{
        schema_version = '1'
        source_tree_sha256 = $Manifest.source_tree_sha256
        chunk_count = $flatArray.Count
        chunks = $flatArray
    }
    $json = $bundle | ConvertTo-Json -Depth 12 -Compress
    $output = $template.Replace($marker, $json)
    Write-Utf8NoBom $WorkerPath $output
}

function Check-Mirror {
    if (-not (Test-Path $ManifestPath)) { throw 'Source mirror manifest does not exist' }
    $manifest = Get-Content -Raw -Encoding UTF8 $ManifestPath | ConvertFrom-Json
    $failures = @()
    foreach ($entry in @($manifest.files)) {
        $live = Get-LivePath ([string]$entry.path)
        $mirror = Get-MirrorPath ([string]$entry.path)
        if (-not (Test-Path $live)) { $failures += "$($entry.path): live source missing" }
        elseif ((Get-Sha256Hex (Get-FileBytes $live)) -ne [string]$entry.sha256) { $failures += "$($entry.path): live source changed since mirror generation" }
        if (-not (Test-Path $mirror)) { $failures += "$($entry.path): mirror file missing" }
        elseif ((Get-Sha256Hex (Get-FileBytes $mirror)) -ne [string]$entry.sha256) { $failures += "$($entry.path): mirror content does not match manifest" }
    }
    if ($failures.Count -gt 0) { throw ("Knowledge mirror check failed:`n" + ($failures -join "`n")) }
    return $manifest
}

if ($Check) {
    $manifest = Check-Mirror
    Write-Output "Visual assistant source mirror OK: $(@($manifest.files).Count) files, $($manifest.source_tree_sha256)"
}
else {
    $manifest = Build-Mirror
    $chunks = Build-KnowledgeChunks
    Build-Worker $manifest $chunks
    Write-Output "Generated Visual assistant knowledge: $(@($manifest.files).Count) mirrored files, $($chunks.Count) chunks, $($manifest.source_tree_sha256)"
}