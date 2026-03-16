#Requires -Version 5.1
<#
.SYNOPSIS
    Reorganiza o conteudo da pasta ENSINO para dentro de "Ensino Reformulacao",
    organizando arquivos e pastas por ano de forma segura.

.DESCRIPTION
    Analisa tudo que esta dentro de ENSINO mas fora de "Ensino Reformulacao",
    detecta o ano de cada item (pelo nome do arquivo, nome da pasta, caminho ou
    data de modificacao) e move para a subpasta de ano correta dentro de
    "Ensino Reformulacao". Suporta modo dry-run (simulacao) e modo real.

.PARAMETER RaizEnsino
    Caminho completo da pasta ENSINO.
    Padrao: d:\usuarios\fisio06\Desktop\FISIO2013\ENSINO

.PARAMETER DryRun
    Se presente, apenas simula as acoes sem mover nada.

.PARAMETER LogPath
    Caminho do arquivo de log. Padrao: mesmo diretorio do script, reorganizacao_YYYY-MM-DD.log

.EXAMPLE
    .\reorganizar-ensino.ps1 -DryRun
    Executa em modo simulacao usando o caminho padrao.

.EXAMPLE
    .\reorganizar-ensino.ps1
    Executa em modo real usando o caminho padrao.

.EXAMPLE
    .\reorganizar-ensino.ps1 -RaizEnsino "C:\MinhaPasta\ENSINO" -DryRun
    Executa em modo simulacao com caminho personalizado.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$RaizEnsino = 'd:\usuarios\fisio06\Desktop\FISIO2013\ENSINO',
    [switch]$DryRun,
    [string]$LogPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURACOES
# ─────────────────────────────────────────────────────────────────────────────
$PASTA_DESTINO_NOME   = 'Ensino Reformulacao'
$PASTA_TRIAGEM_NOME   = '_TRIAGEM_SEM_ANO'
$PASTA_IMPORTADOS     = '_IMPORTADOS_AUTO'
$ANO_MIN              = 2000
$ANO_MAX              = [datetime]::Now.Year + 1

# Mapa de palavras-chave para categorias (chave = regex, valor = nome da pasta)
$MAPA_CATEGORIAS = [ordered]@{
    'cadastr'           = 'Cadastramento'
    'historico|historicos|historico_' = 'Historicos'
    'processo.?seletivo|selecao|selecção' = 'Processo Seletivo'
    'prova|provas|gabarito|gabaritos' = 'Provas e Gabaritos'
    'divulg'            = 'Divulgacao'
    'foto|fotos|imagem|imagens|img' = 'Fotos e Imagens'
    'formul'            = 'Formularios'
    'planilha|xlsx|xls' = 'Planilhas'
    'atalho|lnk'        = 'Atalhos'
    'setup|install|installer' = 'Instaladores'
}

# ─────────────────────────────────────────────────────────────────────────────
# LOG
# ─────────────────────────────────────────────────────────────────────────────
if ($LogPath -eq '') {
    $dataStr  = (Get-Date -Format 'yyyy-MM-dd')
    $LogPath  = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) `
                          "reorganizacao_$dataStr.log"
}

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $ts   = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Msg"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'ERRO'  { Write-Host $line -ForegroundColor Red }
        'AVISO' { Write-Host $line -ForegroundColor Yellow }
        'OK'    { Write-Host $line -ForegroundColor Green }
        'SIM'   { Write-Host $line -ForegroundColor Cyan }
        default { Write-Host $line }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# UTILITARIOS
# ─────────────────────────────────────────────────────────────────────────────
function Get-AnoPorTexto {
    <#
    Extrai o primeiro ano valido (ANO_MIN..ANO_MAX) de uma string.
    Retorna $null se nao encontrar.
    #>
    param([string]$Texto)
    $matches = [regex]::Matches($Texto, '\b(2\d{3})\b')
    foreach ($m in $matches) {
        $a = [int]$m.Value
        if ($a -ge $ANO_MIN -and $a -le $ANO_MAX) { return $a }
    }
    return $null
}

function Get-AnoItem {
    <#
    Detecta o ano de um FileSystemInfo com a seguinte prioridade:
      1) ano no nome do arquivo/pasta
      2) ano no nome da pasta pai imediata
      3) ano em qualquer parte do caminho completo
      4) ano da data de modificacao
    Retorna $null se nao conseguir determinar.
    #>
    param([System.IO.FileSystemInfo]$Item)

    # 1) Nome do proprio item
    $ano = Get-AnoPorTexto -Texto $Item.Name
    if ($null -ne $ano) { return $ano }

    # 2) Nome da pasta pai
    $pastaParent = $Item.Parent
    if ($null -ne $pastaParent) {
        $ano = Get-AnoPorTexto -Texto $pastaParent.Name
        if ($null -ne $ano) { return $ano }
    }

    # 3) Caminho completo (sem o nome do item para evitar duplicar)
    $ano = Get-AnoPorTexto -Texto ($Item.DirectoryName)
    if ($null -ne $ano) { return $ano }

    # 4) Data de modificacao
    $modYear = $Item.LastWriteTime.Year
    if ($modYear -ge $ANO_MIN -and $modYear -le $ANO_MAX) { return $modYear }

    return $null
}

function Get-AnoItemDir {
    <#
    Versao de Get-AnoItem para diretorios (usa .FullName em vez de .DirectoryName).
    #>
    param([System.IO.DirectoryInfo]$Dir)

    $ano = Get-AnoPorTexto -Texto $Dir.Name
    if ($null -ne $ano) { return $ano }

    $pastaParent = $Dir.Parent
    if ($null -ne $pastaParent) {
        $ano = Get-AnoPorTexto -Texto $pastaParent.Name
        if ($null -ne $ano) { return $ano }
    }

    $ano = Get-AnoPorTexto -Texto $Dir.FullName
    if ($null -ne $ano) { return $ano }

    $modYear = $Dir.LastWriteTime.Year
    if ($modYear -ge $ANO_MIN -and $modYear -le $ANO_MAX) { return $modYear }

    return $null
}

function Get-Categoria {
    <#
    Tenta inferir a categoria de um arquivo pelo nome ou extensao.
    Retorna $null se nao conseguir determinar com seguranca.
    #>
    param([string]$Nome)
    $nomeLower = $Nome.ToLower()
    foreach ($padrao in $MAPA_CATEGORIAS.Keys) {
        if ($nomeLower -match $padrao) {
            return $MAPA_CATEGORIAS[$padrao]
        }
    }
    return $null
}

function Get-DestineSemColisao {
    <#
    Retorna um caminho destino sem colisao. Se o destino ja existir,
    acrescenta __DUP_1, __DUP_2, ... antes da extensao (arquivos) ou no final (pastas).
    #>
    param([string]$Destino, [bool]$EhArquivo)

    if (-not (Test-Path -LiteralPath $Destino)) { return $Destino }

    $dir  = Split-Path -LiteralPath $Destino -Parent
    $base = Split-Path -LiteralPath $Destino -Leaf

    if ($EhArquivo) {
        $ext  = [System.IO.Path]::GetExtension($base)
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($base)
        $i    = 1
        do {
            $novo = Join-Path $dir "${stem}__DUP_${i}${ext}"
            $i++
        } while (Test-Path -LiteralPath $novo)
        return $novo
    } else {
        $i = 1
        do {
            $novo = Join-Path $dir "${base}__DUP_${i}"
            $i++
        } while (Test-Path -LiteralPath $novo)
        return $novo
    }
}

function Ensure-Dir {
    <#
    Cria o diretorio se nao existir. Respeita modo DryRun.
    #>
    param([string]$Caminho)
    if (-not (Test-Path -LiteralPath $Caminho)) {
        if ($DryRun) {
            Write-Log "[SIMUL] Criaria pasta: $Caminho" 'SIM'
        } else {
            New-Item -ItemType Directory -Path $Caminho -Force | Out-Null
            Write-Log "Pasta criada: $Caminho" 'OK'
        }
    }
}

function Move-ItemSeguro {
    <#
    Move um arquivo ou pasta de forma segura, tratando colisoes e modo DryRun.
    #>
    param(
        [string]$Origem,
        [string]$PastaDestino,
        [bool]$EhArquivo
    )

    $nomeBase = Split-Path -LiteralPath $Origem -Leaf
    $destinoFinal = Get-DestineSemColisao -Destino (Join-Path $PastaDestino $nomeBase) -EhArquivo $EhArquivo

    if ($DryRun) {
        Write-Log "[SIMUL] Moveria: '$Origem'  ->  '$destinoFinal'" 'SIM'
    } else {
        try {
            Ensure-Dir -Caminho $PastaDestino
            Move-Item -LiteralPath $Origem -Destination $destinoFinal -Force
            Write-Log "Movido: '$Origem'  ->  '$destinoFinal'" 'OK'
        } catch {
            Write-Log "FALHA ao mover '$Origem': $_" 'ERRO'
        }
    }
}

# ─────────────────────────────────────────────────────────────────────────────
# LOGICA PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────
function Get-PastaDestinoArquivo {
    <#
    Determina a pasta de destino de um arquivo dentro de "Ensino Reformulacao".
    Retorna o caminho completo da pasta de destino.
    #>
    param(
        [System.IO.FileInfo]$Arquivo,
        [string]$PastaReformulacao,
        [string]$NomePastaOrigem   # nome da pasta direta de onde o arquivo veio
    )

    $ano = Get-AnoItem -Item $Arquivo

    if ($null -eq $ano) {
        # Triagem
        $destino = Join-Path $PastaReformulacao $PASTA_TRIAGEM_NOME
        return $destino
    }

    # Tenta inferir categoria
    $categoria = Get-Categoria -Nome $Arquivo.Name
    if ($null -ne $categoria) {
        return Join-Path $PastaReformulacao "$ano\$categoria"
    }

    # Sem categoria segura: importados_auto / nome da pasta de origem
    $subpasta = if ($NomePastaOrigem -ne '') { $NomePastaOrigem } else { 'Arquivos_Soltos' }
    return Join-Path $PastaReformulacao "$ano\${PASTA_IMPORTADOS}\$subpasta"
}

function Invoke-ProcessarPasta {
    <#
    Processa uma pasta de origem (nao eh a Reformulacao nem descendente dela).
    Decide se move a pasta inteira ou arquivo por arquivo.
    #>
    param(
        [System.IO.DirectoryInfo]$Pasta,
        [string]$PastaReformulacao
    )

    Write-Log "Analisando pasta: '$($Pasta.FullName)'"

    # Coleta todos os arquivos recursivos da pasta
    $arquivos = @(Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -File -ErrorAction SilentlyContinue)

    if ($arquivos.Count -eq 0) {
        Write-Log "  Pasta vazia, ignorando: '$($Pasta.FullName)'" 'AVISO'
        return
    }

    # Conta anos dos arquivos
    $contagemAnos = @{}
    foreach ($arq in $arquivos) {
        $a = Get-AnoItem -Item $arq
        $chave = if ($null -eq $a) { 'SEM_ANO' } else { "$a" }
        if (-not $contagemAnos.ContainsKey($chave)) { $contagemAnos[$chave] = 0 }
        $contagemAnos[$chave]++
    }

    $totalArquivos  = $arquivos.Count
    $anoMajoritario = $null
    $maxContagem    = 0

    foreach ($chave in $contagemAnos.Keys) {
        if ($chave -ne 'SEM_ANO' -and $contagemAnos[$chave] -gt $maxContagem) {
            $maxContagem    = $contagemAnos[$chave]
            $anoMajoritario = [int]$chave
        }
    }

    $percentual = if ($totalArquivos -gt 0 -and $null -ne $anoMajoritario) {
        [math]::Round(($maxContagem / $totalArquivos) * 100, 1)
    } else { 0 }

    Write-Log "  Total arquivos: $totalArquivos | Ano majoritario: $anoMajoritario ($percentual%)"

    # Se 80%+ dos arquivos pertencem ao mesmo ano -> mover pasta inteira
    if ($null -ne $anoMajoritario -and $percentual -ge 80) {
        Write-Log "  -> Movendo pasta inteira para ano $anoMajoritario" 'OK'
        $destinoPasta = Join-Path $PastaReformulacao "$anoMajoritario\${PASTA_IMPORTADOS}\$($Pasta.Name)"
        Ensure-Dir -Caminho (Split-Path $destinoPasta -Parent)
        Move-ItemSeguro -Origem $Pasta.FullName -PastaDestino (Split-Path $destinoPasta -Parent) -EhArquivo $false
    } else {
        # Anos mistos: processar arquivo por arquivo
        Write-Log "  -> Anos mistos, processando arquivo a arquivo"
        foreach ($arq in $arquivos) {
            $pastaDestArq = Get-PastaDestinoArquivo -Arquivo $arq `
                                                    -PastaReformulacao $PastaReformulacao `
                                                    -NomePastaOrigem $Pasta.Name
            Ensure-Dir -Caminho $pastaDestArq
            Move-ItemSeguro -Origem $arq.FullName -PastaDestino $pastaDestArq -EhArquivo $true
        }
        # Remove pasta de origem se ficou vazia (e nao eh dry-run)
        if (-not $DryRun) {
            $restantes = @(Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -ErrorAction SilentlyContinue)
            if ($restantes.Count -eq 0) {
                try {
                    Remove-Item -LiteralPath $Pasta.FullName -Recurse -Force
                    Write-Log "  Pasta de origem removida (vazia): '$($Pasta.FullName)'" 'OK'
                } catch {
                    Write-Log "  Nao foi possivel remover pasta vazia '$($Pasta.FullName)': $_" 'AVISO'
                }
            }
        }
    }
}

function Invoke-ProcessarArquivoSolto {
    <#
    Processa um arquivo que esta diretamente na raiz de ENSINO (nao em subpasta).
    #>
    param(
        [System.IO.FileInfo]$Arquivo,
        [string]$PastaReformulacao
    )

    Write-Log "Arquivo solto: '$($Arquivo.FullName)'"
    $pastaDestArq = Get-PastaDestinoArquivo -Arquivo $Arquivo `
                                            -PastaReformulacao $PastaReformulacao `
                                            -NomePastaOrigem ''
    Ensure-Dir -Caminho $pastaDestArq
    Move-ItemSeguro -Origem $Arquivo.FullName -PastaDestino $pastaDestArq -EhArquivo $true
}

# ─────────────────────────────────────────────────────────────────────────────
# ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────
function Main {
    $inicio = Get-Date

    # Cabecalho
    Write-Log ('=' * 70)
    if ($DryRun) {
        Write-Log '  MODO SIMULACAO (DRY-RUN) - Nenhum arquivo sera movido' 'AVISO'
    } else {
        Write-Log '  MODO REAL - Arquivos SERAO movidos' 'AVISO'
    }
    Write-Log "  Raiz ENSINO   : $RaizEnsino"
    Write-Log "  Log           : $LogPath"
    Write-Log ('=' * 70)

    # Validacoes basicas
    if (-not (Test-Path -LiteralPath $RaizEnsino -PathType Container)) {
        Write-Log "ERRO: Pasta ENSINO nao encontrada: '$RaizEnsino'" 'ERRO'
        exit 1
    }

    $pastaReformulacao = Join-Path $RaizEnsino $PASTA_DESTINO_NOME
    if (-not (Test-Path -LiteralPath $pastaReformulacao -PathType Container)) {
        Write-Log "AVISO: Pasta '$PASTA_DESTINO_NOME' nao existe. Sera criada." 'AVISO'
        Ensure-Dir -Caminho $pastaReformulacao
    }

    Write-Log "Pasta destino : $pastaReformulacao"
    Write-Log ''

    # Lista itens diretamente na raiz de ENSINO (nao recursivo)
    $itensRaiz = @(Get-ChildItem -LiteralPath $RaizEnsino -ErrorAction SilentlyContinue)

    $totalPastas  = 0
    $totalArquivos = 0

    foreach ($item in $itensRaiz) {
        # Ignora a propria pasta "Ensino Reformulacao"
        if ($item.Name -ieq $PASTA_DESTINO_NOME) {
            Write-Log "Ignorando (eh a pasta de destino): '$($item.FullName)'"
            continue
        }
        # Ignora o proprio arquivo de log se estiver dentro de ENSINO
        if ($item.FullName -ieq $LogPath) {
            continue
        }

        if ($item -is [System.IO.DirectoryInfo]) {
            $totalPastas++
            try {
                Invoke-ProcessarPasta -Pasta $item -PastaReformulacao $pastaReformulacao
            } catch {
                Write-Log "ERRO ao processar pasta '$($item.FullName)': $_" 'ERRO'
            }
        } elseif ($item -is [System.IO.FileInfo]) {
            $totalArquivos++
            try {
                Invoke-ProcessarArquivoSolto -Arquivo $item -PastaReformulacao $pastaReformulacao
            } catch {
                Write-Log "ERRO ao processar arquivo '$($item.FullName)': $_" 'ERRO'
            }
        }
    }

    $duracao = (Get-Date) - $inicio
    Write-Log ''
    Write-Log ('=' * 70)
    Write-Log "CONCLUIDO em $([math]::Round($duracao.TotalSeconds,1))s"
    Write-Log "Pastas processadas : $totalPastas"
    Write-Log "Arquivos soltos    : $totalArquivos"
    if ($DryRun) {
        Write-Log 'NENHUMA alteracao foi feita (modo simulacao).' 'AVISO'
        Write-Log 'Para executar de verdade, rode sem o parametro -DryRun.' 'AVISO'
    }
    Write-Log ('=' * 70)
}

# Inicia o log (cria ou abre o arquivo)
try {
    $null = New-Item -ItemType File -Path $LogPath -Force -ErrorAction SilentlyContinue
} catch {
    # nao critico
}

Main
