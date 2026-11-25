$ErrorActionPreference = 'Stop'
# Compacta (zip) pastas/arquivos grandes e antigos de Downloads, EM LOTES PEQUENOS,
# usando a API .NET direto (Compress-Archive estoura a memoria com 11 GB).
#
# -WhatIf : mostra o plano
# -Go     : executa o proximo lote (ate $MaxMB de origem por execucao)
# Nada e apagado: o original so sai depois de o ZIP abrir e ter o mesmo numero de arquivos.

$DryRun = ($args -contains '-WhatIf')
$MaxMB  = 2000          # limite de origem por execucao (evita travar o PC)
$CUTOFF = (Get-Date).AddYears(-1)
$dl   = "$env:USERPROFILE\Downloads"
$dest = Join-Path $dl '_arquivo'
$state = Join-Path $dest '_estado.json'

Add-Type -AssemblyName System.IO.Compression.FileSystem

# Pastas/arquivos que valem compactar (ja comprimidos ficam de fora)
$skipExt = @('.zip','.rar','.7z','.mp4','.mp3','.jpg','.jpeg','.png','.gz','.apk','.img','.iso','.mkv','.avi','.msi')

function Get-ItemSizeMB($item) {
    if ($item.PSIsContainer) {
        return [math]::Round((Get-ChildItem $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
               Measure-Object Length -Sum).Sum / 1MB)
    }
    return [math]::Round($item.Length / 1MB)
}

$cands = @()
$cands += Get-ChildItem $dl -File -Force |
    Where-Object { $_.LastWriteTime -lt $CUTOFF -and $skipExt -notcontains $_.Extension.ToLower() -and $_.Length -ge 300MB }
$cands += Get-ChildItem $dl -Directory -Force |
    Where-Object { $_.Name -notin @('_arquivo','old_chrome') -and $_.LastWriteTime -lt $CUTOFF }

$done = @{}
if (Test-Path $state) { (Get-Content $state -Raw | ConvertFrom-Json).done | ForEach-Object { $done[$_] = $true } }

$todo = $cands | Where-Object { -not $done[$_.Name] } | Sort-Object { Get-ItemSizeMB $_ } -Descending

if (-not $todo) { "Nada pendente. Tudo ja compactado."; exit 0 }

"=== Pendentes ==="
foreach ($t in $todo) { "  {0,-45} {1,7} MB  {2:yyyy-MM-dd}" -f $t.Name, (Get-ItemSizeMB $t), $t.LastWriteTime }
if ($DryRun) { "`n[dry-run] nada alterado."; exit 0 }

New-Item -ItemType Directory -Path $dest -Force | Out-Null
$loteMB = 0
foreach ($item in $todo) {
    $mb = Get-ItemSizeMB $item
    if ($loteMB + $mb -gt $MaxMB -and $loteMB -gt 0) { "`nLote cheio (~$loteMB MB). Rode de novo para continuar."; break }
    $loteMB += $mb

    $bucket = Join-Path $dest $item.LastWriteTime.ToString('yyyyMM')
    New-Item -ItemType Directory -Path $bucket -Force | Out-Null
    $zipPath = Join-Path $bucket ($item.Name + '.zip')
    $i = 1
    while (Test-Path $zipPath) { $zipPath = Join-Path $bucket ("{0} ({1}).zip" -f $item.Name, $i); $i++ }

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        "zipando {0} ({1} MB)..." -f $item.Name, $mb
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $item.FullName, $zipPath, [System.IO.Compression.CompressionLevel]::Fastest, $true)
        $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)

        # Confere antes de remover o original
        $srcCount = if ($item.PSIsContainer) { (Get-ChildItem $item.FullName -Recurse -Force -File | Measure-Object).Count } else { 1 }
        $z = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
        $entries = ($z.Entries | Where-Object { $_.Name -ne '' }).Count
        $z.Dispose()
        if ($entries -lt $srcCount) { throw "ZIP incompleto: $entries de $srcCount arquivos" }

        Remove-Item -LiteralPath $item.FullName -Recurse -Force
        "  OK {0} -> {1} ({2} MB, economizou {3} MB, {4} min)" -f $item.Name, (Split-Path $zipPath -Leaf), $zipMB, ($mb - $zipMB), [math]::Round($sw.Elapsed.TotalMinutes,1)
        $done[$item.Name] = $true
        @{ done = @($done.Keys) } | ConvertTo-Json | Set-Content $state -Encoding UTF8
    } catch {
        "  FALHOU {0}: {1} (original mantido)" -f $item.Name, $_.Exception.Message
    }
}

"`nDownloads: {0} GB | C: livre: {1} GB" -f `
    [math]::Round((Get-ChildItem $dl -Recurse -Force -File | Measure-Object Length -Sum).Sum/1GB,1), `
    [math]::Round((Get-PSDrive C).Free/1GB,1)
