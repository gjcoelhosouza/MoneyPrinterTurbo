# PC fraco no Windows: qual otimizador usar

Comparação rápida das opções mais citadas pela comunidade e o que este repositório
usa como padrão.

| Projeto | O que é | Risco | Indicado para |
|---|---|---|---|
| [ChrisTitusTech/winutil](https://github.com/ChrisTitusTech/winutil) | Utility em PowerShell (MIT), debloat, tweaks, instala apps via WinGet | Baixo (mostra o que faz, tem presets e reversão) | **Padrão recomendado** para qualquer PC |
| [raphael-c-martins/Otimizador-Windows-10-11](https://github.com/raphael-c-martins/Otimizador-Windows-10-11) | App C#/.NET (MIT), foco em privacidade e bloqueio de IA | Médio (executável) | Quem quer bloquear Copilot/IA e prefere GUI |
| [AFaustini/OtimizeWindows](https://github.com/AFaustini/OtimizeWindows) | Um `.bat` simples, editável | Médio (tudo ou nada, sem reversão) | Quem quer ler cada linha antes |
| [terremoth/pc-carroca](https://github.com/terremoth/pc-carroca) | Guia de hardware/software leve | Nenhum (só leitura) | Hardware muito antigo, RAM < 4 GB |

## Veredito

**WinUtil** ganha: código aberto, mantido, mostra exatamente cada tweak, tem presets
(`Standard`, `Minimal`, `Advanced`) e desfaz alterações. O `pc-carroca` é leitura
obrigatória antes de gastar em hardware.

## Uso do WinUtil

PowerShell **como Administrador**:

```powershell
irm https://christitus.com/win | iex
```

Para aplicar sem clicar em nada:

```powershell
& ([ScriptBlock]::Create((irm https://christitus.com/win))) -Preset Standard
```

Abas úteis: **Install** (desinstalar apps inúteis), **Tweaks** (telemetria, serviços),
**Config** (reparos), **Updates** (desativar updates automáticos só se souber o que faz).

## Script mínimo deste repositório

`scripts/win/otimizar-pc-fraco.ps1` faz o essencial, sem remover nada do sistema:
mostra o hardware, reduz telemetria/segundo plano, desliga efeitos visuais, limpa
temporários e tem `-Undo`.

```powershell
# simular (não altera nada)
.\scripts\win\otimizar-pc-fraco.ps1 -DryRun

# aplicar com ponto de restauração
.\scripts\win\otimizar-pc-fraco.ps1 -RestorePoint

# reverter
.\scripts\win\otimizar-pc-fraco.ps1 -Undo
```

## Ordem que dá mais resultado em PC fraco

1. **SSD** (se ainda for HDD) — maior ganho de todos, maior que qualquer script.
2. **RAM**: 4 GB → 8 GB se possível; senão, evite muitos apps abertos.
3. Rodar o script acima (`-DryRun` primeiro).
4. WinUtil com preset `Standard`.
5. Desligar inicialização automática de apps pesados (Gerenciador de Tarefas → Inicializar).
6. Só então pensar em trocar de sistema (Linux leve) — ver `pc-carroca`.

## Cuidados

- Crie um ponto de restauração antes (o script faz com `-RestorePoint`).
- Prefira repositórios com script legível; evite `.exe` de contas novas.
- Não desative Windows Update nem Defender em máquina de uso diário.
