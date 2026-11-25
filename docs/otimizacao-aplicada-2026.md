# Otimização aplicada — 2026 (Windows 10 Pro, AMD A4-3300M, HDD)

Registro do que foi feito nesta máquina e de como reverter cada item.

## Antes x depois

| Item | Antes | Depois |
|---|---|---|
| RAM livre | 1,74 GB | ~2,2 GB |
| Espaço em `%TEMP%` | cheio | 8 GB liberados |
| Serviços | DiagTrack, dmwappushservice, WSearch ativos | desativados |
| Inicialização automática | 13 programas | 3 (AbacusBot, SecurityHealth, SynTPEnh) |
| VoiceStudio | 899 MB instalado | removido |
| ZIPs de estudo em `Downloads` | soltos na pasta | agrupados em `Downloads\old_chrome` |
| Plano de energia | Equilibrado | Alto desempenho |
| Desfragmentação | sem medida | medida por amostragem: baixa |

## O que foi feito, item por item

### 1. Espaço em disco
- 15,35 GB de ZIPs de material de estudo movidos para `Downloads\old_chrome`.
- VoiceStudio removido via desinstalador oficial (`/S`), saída 0.
- **72 GB continuam em `Downloads`** — decisão sua o que apagar.

### 2. Inicialização automática (desativados)
`OneDrive`, `OneDriveSetup` (x2), `SRecorder`, `Sideloadly Daemon`,
`GoogleChromeAutoLaunch`, `MicrosoftEdgeAutoLaunch`, `Assinador Serpro`,
`McAfee Security Scan Plus`, `pje-office`, tarefa `OneDrive Startup Task`.
**Mantidos:** AbacusBot, SecurityHealth, SynTPEnh (touchpad), Copilot.

### 3. Desinstalação
- `VoiceStudio 0.5.6` — 899 MB.
- **Copilot mantido**, como pedido.

### 4. Plano de energia
`Equilibrado` → `Alto desempenho` (GUID `470d9cb3-1525-4fd1-909b-29d8a51de367`).
Em notebook, volta a consumir mais bateria.

### 5. Desfragmentação
`defrag C: /A` e `defrag C: /O` **travam neste disco** (IDE, 5+ min sem I/O, 0s de CPU).
Em vez de insistir, a fragmentação foi medida por amostragem com `fsutil file queryextents`:

| Pasta | Arquivos | Fragmentos extras |
|---|---|---|
| `C:\Windows\System32` | 200 | **0** |
| `Downloads` | 200 | **6** |
| `AppData\Local` | 1 | 0 |

Ou seja: o disco **não está fragmentado de forma relevante** — a lentidão é do HDD em si,
não de fragmentação. A tarefa agendada `ScheduledDefrag` segue ativa e faz a manutenção
semanal sozinha.

## Como reverter

```powershell
# Inicialização
reg import "$env:USERPROFILE\Desktop\backup-startup-approved-user.reg"
reg import "$env:USERPROFILE\Desktop\backup-startup-approved-machine.reg"
Copy-Item "$env:USERPROFILE\Desktop\backup-startup-folder\*" "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\"
Rename-Item "$env:ProgramData\...\Startup\*.lnk.disabled" -NewName { $_.Name -replace '\.disabled$','' }

# Energia
powercfg /setactive SCHEME_BALANCED

# Script do projeto (registro + serviços)
.\scripts\win\otimizar-pc-fraco.ps1 -Undo
```

VoiceStudio não é revertido automaticamente: reinstale em
https://github.com/ruslanmv/VoiceStudio se precisar.
