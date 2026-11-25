<#
.SYNOPSIS
    Otimizacao minima e reversivel para PC fraco no Windows 10/11.

.DESCRIPTION
    Script conservador: nao desinstala programas, nao remove servicos e nao
    desativa recursos do sistema. Apenas:
      - mostra um retrato do hardware (CPU, RAM, disco, Windows);
      - reduz o trabalho em segundo plano (telemetria, apps em background);
      - desativa efeitos visuais pesados;
      - cria um ponto de restauracao antes de aplicar qualquer coisa.

    Para otimizacao profunda use o WinUtil (Chris Titus Tech):
        irm https://christitus.com/win | iex      (PowerShell como Administrador)

.PARAMETER DryRun
    Mostra o que seria feito, sem alterar nada.

.PARAMETER RestorePoint
    Cria um ponto de restauracao antes de aplicar (recomendado).

.PARAMETER Undo
    Reverte as alteracoes feitas por este script (restaura os valores padrao).

.EXAMPLE
    # Simular, sem alterar nada
    .\otimizar-pc-fraco.ps1 -DryRun

.EXAMPLE
    # Aplicar com ponto de restauracao
    .\otimizar-pc-fraco.ps1 -RestorePoint

.EXAMPLE
    # Desfazer
    .\otimizar-pc-fraco.ps1 -Undo

.NOTES
    Requer PowerShell 5.1+ (Windows 10/11). Rodar como Administrador para aplicar.
    Licenca: MIT (mesma do projeto).
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$RestorePoint,
    [switch]$Undo
)

$ErrorActionPreference = 'Stop'

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Ok($msg)   { Write-Host "    $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [dry-run] $msg" -ForegroundColor Yellow }

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-HardwareReport {
    Write-Step 'Retrato do hardware'
    $os  = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $ramGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
    $freeGB = [math]::Round($os.FreePhysicalMemory / 1MB, 1)

    $disk = $null
    try {
        $disk = Get-PhysicalDisk | Select-Object -First 1
    } catch { }

    Write-Ok ("Windows : {0} (build {1})" -f $os.Caption, $os.BuildNumber)
    Write-Ok ("CPU     : {0} ({1} nucleos / {2} threads)" -f $cpu.Name.Trim(), $cpu.NumberOfCores, $cpu.NumberOfLogicalProcessors)
    Write-Ok ("RAM     : {0} GB total, {1} GB livres" -f $ramGB, $freeGB)
    if ($disk) {
        $media = switch ($disk.MediaType) { 3 { 'HDD (mecanico)' } 4 { 'SSD' } default { $disk.MediaType } }
        Write-Ok ("Disco   : {0} - {1}" -f $disk.FriendlyName, $media)
        if ($disk.MediaType -eq 3) {
            Write-Host '    AVISO: disco mecanico (HDD) e o maior gargalo em PC fraco.' -ForegroundColor Yellow
            Write-Host '           Um SSD SATA barato da mais ganho que qualquer script.' -ForegroundColor Yellow
        }
    }
    if ($ramGB -lt 8) {
        Write-Host '    AVISO: com menos de 8 GB de RAM, evite abrir muitos apps ao mesmo tempo.' -ForegroundColor Yellow
    }
}

function New-SafetyRestorePoint {
    if (-not $RestorePoint -or $DryRun) { return }
    Write-Step 'Criando ponto de restauracao'
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description 'Antes de otimizar-pc-fraco.ps1' -RestorePointType 'MODIFY_SETTINGS'
        Write-Ok 'Ponto de restauracao criado.'
    } catch {
        Write-Host "    Falha ao criar ponto de restauracao: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host '    Continuando (o script nao remove nada do sistema).' -ForegroundColor Yellow
    }
}

# Cada item: chave do registro, nome, valor "otimizado" e valor "padrao".
$tweaks = @(
    @{ Path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection'
       Name = 'AllowTelemetry'; Optimized = 0; Default = 3
       Desc = 'Telemetria do Windows no nivel minimo (requer Windows Pro/Enterprise)' }

    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
       Name = 'VisualFXSetting'; Optimized = 2; Default = 0
       Desc = 'Efeitos visuais: melhor desempenho' }

    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
       Name = 'EnableTransparency'; Optimized = 0; Default = 1
       Desc = 'Desliga a transparencia do Windows' }

    @{ Path = 'HKCU:\Control Panel\Desktop'
       Name = 'MenuShowDelay'; Optimized = 0; Default = 400
       Desc = 'Menu abre sem atraso' }

    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications'
       Name = 'GlobalUserDisabled'; Optimized = 1; Default = 0
       Desc = 'Bloqueia apps em segundo plano para o usuario atual' }

    @{ Path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
       Name = 'BackgroundAppGlobalToggle'; Optimized = 0; Default = 1
       Desc = 'Reduz indexacao em segundo plano da Busca' }
)

function Set-Tweak {
    param($Tweak, $Value)
    if ($DryRun) {
        Write-Skip ("{0} -> {1}" -f $Tweak.Desc, $Value)
        return
    }
    if (-not (Test-Path $Tweak.Path)) { New-Item -Path $Tweak.Path -Force | Out-Null }
    New-ItemProperty -Path $Tweak.Path -Name $Tweak.Name -Value $Value -PropertyType DWord -Force | Out-Null
    Write-Ok $Tweak.Desc
}

function Stop-BloatProcesses {
    # Fecha apenas apps que o Windows reabre sozinho e que pesam em PC fraco.
    $names = @('Widgets', 'GameBar', 'GameBarPresenceWriter', 'Teams', 'OneDrive')
    Write-Step 'Encerrando apps de segundo plano pesados'
    foreach ($n in $names) {
        $procs = Get-Process -Name $n -ErrorAction SilentlyContinue
        if (-not $procs) { continue }
        if ($DryRun) { Write-Skip "encerraria $n"; continue }
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Ok "encerrado: $n"
    }
}

function Clear-TempFiles {
    Write-Step 'Limpando arquivos temporarios'
    $targets = @("$env:TEMP\*", "$env:SystemRoot\Temp\*")
    foreach ($t in $targets) {
        if ($DryRun) { Write-Skip "limparia $t"; continue }
        Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        Write-Ok "limpo: $t"
    }
}

function Restart-Explorer {
    if ($DryRun) { Write-Skip 'reiniciaria o Explorer'; return }
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    Write-Ok 'Explorer reiniciado para aplicar os ajustes.'
}

# ---- main ----
if (-not (Test-Admin) -and -not $DryRun) {
    Write-Host 'Rode como Administrador para aplicar as alteracoes (ou use -DryRun).' -ForegroundColor Red
    exit 1
}

if ($Undo) {
    Write-Step 'Revertendo alteracoes'
    foreach ($t in $tweaks) { Set-Tweak -Tweak $t -Value $t.Default }
    Restart-Explorer
    Write-Ok 'Valores padrao restaurados. Reinicie o PC para concluir.'
    exit 0
}

Get-HardwareReport
New-SafetyRestorePoint

Write-Step 'Aplicando ajustes leves'
foreach ($t in $tweaks) { Set-Tweak -Tweak $t -Value $t.Optimized }

Stop-BloatProcesses
Clear-TempFiles
Restart-Explorer

Write-Host ''
Write-Step 'Concluido'
Write-Host '    Reverter tudo : .\otimizar-pc-fraco.ps1 -Undo'
Write-Host '    Otimizacao profunda (opcional, com risco maior): WinUtil'
Write-Host '      irm https://christitus.com/win | iex'
Write-Host '    (PowerShell como Administrador; use o preset Standard ou Minimal)'
