# Compactação de `Downloads` — o que foi feito

Nada foi apagado. Arquivos e pastas pesados/antigos foram **movidos para dentro de ZIPs**
em `Downloads\_arquivo\AAAAMM\`, com o mês da última modificação.

## Resultado

| Origem | Tamanho original | Virou | Resultado |
|---|---|---|---|
| `portugues fgv - parte 2\` (123 arquivos) | 11.527 MB | `_arquivo\202404\portugues fgv - parte 2.zip` | 11.002 MB |
| `ListagemListaEspera_2019-1.csv` | 482 MB | `_arquivo\202501\ListagemListaEspera_2019-1.zip` | 95 MB |
| `ListagemListaEspera_2019-1 (1).csv` | 482 MB | `_arquivo\202504\ListagemListaEspera_2019-1 (1).zip` | 95 MB |
| `Gitz_World_Champion_30.12.2021.exe` | 477 MB | `_arquivo\202205\Gitz_World_Champion_30.12.2021.zip` | 477 MB (já comprimido) |

**Economia total: ~1,3 GB** e, principalmente, 11,5 GB de 123 arquivos soltos
viraram **um único arquivo** — menos entradas para o índice do NTFS em um HDD.

Cada ZIP foi validado antes de o original ser removido: o número de entradas
confere com o número de arquivos de origem (123 de 123 no maior).

## O que ficou de fora, de propósito

- **`old_chrome\` (15,7 GB)** — 9 arquivos que já são ZIPs; re-zipar não ganha nada.
- **`Telegram Desktop\` (6,1 GB)** — 2205 arquivos, a maioria MP4 (não comprime) e ainda
  é a pasta de trabalho do Telegram.
- **`Downloads.rar` (6,1 GB)** e outros `.zip`/`.rar`/`.mp4` — já comprimidos.
- **Pastas de estudo pequenas** (Direito, Contabilidade, Auditoria…): 5–50 MB cada.
  Entraram no plano, mas o lote de 2 GB por execução parou na pasta grande.

## Como continuar

```powershell
# ver o que falta
.\scripts\win\compactar-downloads.ps1 -WhatIf

# compactar o proximo lote (ate 2 GB de origem por execucao)
.\scripts\win\compactar-downloads.ps1 -Go
```

## Por que o script mudou no meio do caminho

`Compress-Archive` **trava** com pastas de ~11 GB: medido em 3 GB de RAM e 0 s de I/O,
com o ZIP em 0 bytes depois de 14 minutos. A versão final usa
`System.IO.Compression.ZipFile.CreateFromDirectory` (streaming, 69 MB de RAM),
grava em lotes de 2 GB e guarda o progresso em `_arquivo\_estado.json`.
