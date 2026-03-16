@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>&1
cd /d "%~dp0"

cls
echo.
echo ============================================================
echo      REORGANIZACAO DA PASTA ENSINO - Ensino Reformulacao
echo ============================================================
echo.
echo  Este script ira analisar e reorganizar os arquivos e pastas
echo  da pasta ENSINO para dentro de "Ensino Reformulacao".
echo.
echo  MODOS DE USO:
echo    [1] Simulacao  (DRY-RUN) - apenas mostra o que SERIA feito
echo    [2] Execucao real        - MOVE os arquivos de verdade
echo    [3] Sair
echo.
set /p MODO="  Digite 1, 2 ou 3 e pressione ENTER: "

if "%MODO%"=="3" (
    echo.
    echo  Operacao cancelada pelo usuario.
    echo.
    goto :FIM
)

if "%MODO%"=="1" (
    set "PS_EXTRA=-DryRun"
    echo.
    echo  ^>^> Modo SIMULACAO selecionado. Nenhum arquivo sera movido. ^<^
    echo.
) else if "%MODO%"=="2" (
    set "PS_EXTRA="
    echo.
    echo  *** ATENCAO: Os arquivos SERAO MOVIDOS. ***
    echo.
    set /p CONFIRMA="  Confirma a execucao real? (S para continuar, qualquer tecla para cancelar): "
    if /i not "%CONFIRMA%"=="S" (
        echo.
        echo  Execucao cancelada.
        echo.
        goto :FIM
    )
) else (
    echo.
    echo  Opcao invalida. Por favor, execute novamente e escolha 1, 2 ou 3.
    echo.
    goto :FIM
)

set "ESTRUTURA_PATH=%~dp0..\estrutura_ensino.txt"
if not exist "%ESTRUTURA_PATH%" set "ESTRUTURA_PATH=%~dp0estrutura_ensino.txt"

set "RAIZ_SUGERIDA="
if exist "%ESTRUTURA_PATH%" call :SUGERIR_RAIZ "%ESTRUTURA_PATH%"

if defined RAIZ_SUGERIDA (
    echo  Caminho sugerido pelo estrutura_ensino.txt:
    echo    %RAIZ_SUGERIDA%
    echo.
)

set "RAIZ_ENSINO="
set /p RAIZ_ENSINO="  Digite o caminho da pasta ENSINO (ENTER para usar o sugerido): "
if not defined RAIZ_ENSINO set "RAIZ_ENSINO=%RAIZ_SUGERIDA%"

if not defined RAIZ_ENSINO (
    echo.
    echo  [ERRO] Caminho da pasta ENSINO nao informado.
    echo.
    goto :FIM_ERRO
)

if not exist "%RAIZ_ENSINO%\" (
    echo.
    echo  [ERRO] Pasta ENSINO nao encontrada:
    echo         "%RAIZ_ENSINO%"
    echo.
    goto :FIM_ERRO
)

echo.
echo ============================================================
echo  Iniciando reorganizacao...
echo ============================================================
echo  Pasta ENSINO: %RAIZ_ENSINO%
if exist "%ESTRUTURA_PATH%" echo  Estrutura    : %ESTRUTURA_PATH%
echo.

set "PS_TMP=%TEMP%\reorganizar_ensino_%RANDOM%%RANDOM%.ps1"
call :EXTRAIR_PS "%PS_TMP%"
if errorlevel 1 goto :FIM_ERRO

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_TMP%" -RaizEnsino "%RAIZ_ENSINO%" -EstruturaPath "%ESTRUTURA_PATH%" %PS_EXTRA%
set "PS_EXIT=%ERRORLEVEL%"
del /q "%PS_TMP%" >nul 2>&1

if not "%PS_EXIT%"=="0" (
    echo.
    echo ============================================================
    echo  [ERRO] A reorganizacao terminou com falha.
    echo  Verifique as mensagens acima e o arquivo de log gerado.
    echo ============================================================
    echo.
    goto :FIM_ERRO
)

echo.
echo ============================================================
echo  Reorganizacao concluida com sucesso!
echo  Verifique o arquivo de log gerado na pasta scripts\.
echo ============================================================
echo.
goto :FIM

:SUGERIR_RAIZ
set "ARQ_ESTRUTURA=%~1"
for /f "usebackq delims=" %%L in (`findstr /R /C:"^[A-Za-z]:\\.*" "%ARQ_ESTRUTURA%"`) do (
    set "RAIZ_SUGERIDA=%%L"
    goto :EOF
)
goto :EOF

:EXTRAIR_PS
setlocal DisableDelayedExpansion
set "PS_DEST=%~1"
break > "%PS_DEST%" || (endlocal & exit /b 1)
set "COPIAR_PS="
for /f "usebackq delims=" %%L in ("%~f0") do (
    if defined COPIAR_PS >> "%PS_DEST%" echo(%%L
    if "%%L"==":__POWERSHELL__" set "COPIAR_PS=1"
)
endlocal & exit /b 0

:FIM_ERRO
echo.
pause
exit /b 1

:FIM
echo.
pause
exit /b 0

:__POWERSHELL__
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [string]$RaizEnsino,

    [string]$EstruturaPath = '',

    [switch]$DryRun,

    [string]$LogPath = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PASTA_DESTINO_NOME = 'Ensino Reformulacao'
$PASTA_TRIAGEM_NOME = '_TRIAGEM_SEM_ANO'
$PASTA_IMPORTADOS = '_IMPORTADOS_AUTO'
$ANO_MIN = 2000
$ANO_MAX = [datetime]::Now.Year + 1

$MAPA_CATEGORIAS = [ordered]@{
    'cadastr' = 'Cadastramento'
    'historico|historicos|historico_' = 'Historicos'
    'processo.?seletivo|selecao|selecção' = 'Processo Seletivo'
    'prova|provas|gabarito|gabaritos' = 'Provas e Gabaritos'
    'divulg' = 'Divulgacao'
    'foto|fotos|imagem|imagens|img' = 'Fotos e Imagens'
    'formul' = 'Formularios'
    'planilha|xlsx|xls' = 'Planilhas'
    'atalho|lnk' = 'Atalhos'
    'setup|install|installer' = 'Instaladores'
}

if ($LogPath -eq '') {
    $dataStr = (Get-Date -Format 'yyyy-MM-dd')
    $LogPath = Join-Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) "reorganizacao_$dataStr.log"
}

function Write-Log {
    param([string]$Msg, [string]$Level = 'INFO')
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$ts][$Level] $Msg"
    Add-Content -LiteralPath $LogPath -Value $line -Encoding UTF8
    switch ($Level) {
        'ERRO' { Write-Host $line -ForegroundColor Red }
        'AVISO' { Write-Host $line -ForegroundColor Yellow }
        'OK' { Write-Host $line -ForegroundColor Green }
        'SIM' { Write-Host $line -ForegroundColor Cyan }
        default { Write-Host $line }
    }
}

function Normalize-Texto {
    param([string]$Texto)
    if ([string]::IsNullOrWhiteSpace($Texto)) { return '' }

    $normalizado = $Texto.Normalize([Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder

    foreach ($ch in $normalizado.ToCharArray()) {
        if ([Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }

    return $sb.ToString().Normalize([Text.NormalizationForm]::FormC).ToLowerInvariant()
}

function Get-CategoriasDoArquivoEstrutura {
    param([string]$CaminhoEstrutura)

    $categorias = New-Object System.Collections.Generic.HashSet[string] ([System.StringComparer]::OrdinalIgnoreCase)
    if (-not (Test-Path -LiteralPath $CaminhoEstrutura -PathType Leaf)) {
        return @()
    }

    $categoriasBase = @(
        'Cadastramento',
        'Historicos',
        'Processo Seletivo',
        'Provas e Gabaritos',
        'Divulgacao',
        'Fotos e Imagens',
        'Formularios',
        'Planilhas',
        'Atalhos',
        'Instaladores'
    )

    foreach ($cat in $categoriasBase) { [void]$categorias.Add($cat) }

    try {
        $linhas = Get-Content -LiteralPath $CaminhoEstrutura -Encoding UTF8 -ErrorAction Stop
        foreach ($linha in $linhas) {
            if ($linha -notmatch '\+---(.+)$') { continue }
            $nomePasta = $Matches[1].Trim()
            if ($nomePasta.Length -lt 4) { continue }
            if ($nomePasta -match '^\d{4}(\D|$)') { continue }

            foreach ($catBase in $categoriasBase) {
                $catNorm = Normalize-Texto $catBase
                $nomeNorm = Normalize-Texto $nomePasta
                if ($nomeNorm -like "*$catNorm*") {
                    [void]$categorias.Add($nomePasta)
                    break
                }
            }
        }
    }
    catch {
        Write-Log "Aviso ao ler estrutura_ensino.txt: $_" 'AVISO'
    }

    return @($categorias)
}

$CATEGORIAS_ESTRUTURA = Get-CategoriasDoArquivoEstrutura -CaminhoEstrutura $EstruturaPath

function Get-AnoPorTexto {
    param([string]$Texto)
    $matches = [regex]::Matches($Texto, '\b(2\d{3})\b')
    foreach ($m in $matches) {
        $a = [int]$m.Value
        if ($a -ge $ANO_MIN -and $a -le $ANO_MAX) { return $a }
    }
    return $null
}

function Get-AnoItem {
    param([System.IO.FileSystemInfo]$Item)

    $ano = Get-AnoPorTexto -Texto $Item.Name
    if ($null -ne $ano) { return $ano }

    $parentPath = Split-Path -Path $Item.FullName -Parent
    if (-not [string]::IsNullOrWhiteSpace($parentPath)) {
        $parentName = Split-Path -Path $parentPath -Leaf
        $ano = Get-AnoPorTexto -Texto $parentName
        if ($null -ne $ano) { return $ano }
    }

    $basePath = if ($Item -is [System.IO.DirectoryInfo]) { $Item.FullName } else { $Item.DirectoryName }
    $ano = Get-AnoPorTexto -Texto $basePath
    if ($null -ne $ano) { return $ano }

    $modYear = $Item.LastWriteTime.Year
    if ($modYear -ge $ANO_MIN -and $modYear -le $ANO_MAX) { return $modYear }

    return $null
}

function Get-Categoria {
    param([string]$Nome)

    $nomeLower = $Nome.ToLowerInvariant()
    foreach ($padrao in $MAPA_CATEGORIAS.Keys) {
        if ($nomeLower -match $padrao) {
            return $MAPA_CATEGORIAS[$padrao]
        }
    }

    $nomeNorm = Normalize-Texto $Nome
    foreach ($categoriaEstrutura in $CATEGORIAS_ESTRUTURA) {
        $categoriaNorm = Normalize-Texto $categoriaEstrutura
        if ($categoriaNorm.Length -ge 4 -and $nomeNorm -like "*$categoriaNorm*") {
            return $categoriaEstrutura
        }
    }

    return $null
}

function Get-DestinoSemColisao {
    param([string]$Destino, [bool]$EhArquivo)

    if (-not (Test-Path -LiteralPath $Destino)) { return $Destino }

    $dir = Split-Path -Path $Destino -Parent
    $base = Split-Path -Path $Destino -Leaf

    if ($EhArquivo) {
        $ext = [System.IO.Path]::GetExtension($base)
        $stem = [System.IO.Path]::GetFileNameWithoutExtension($base)
        $i = 1
        do {
            $novo = Join-Path $dir "${stem}__DUP_${i}${ext}"
            $i++
        } while (Test-Path -LiteralPath $novo)
        return $novo
    }

    $i = 1
    do {
        $novo = Join-Path $dir "${base}__DUP_${i}"
        $i++
    } while (Test-Path -LiteralPath $novo)
    return $novo
}

function Ensure-Dir {
    param([string]$Caminho)
    if (-not (Test-Path -LiteralPath $Caminho)) {
        if ($DryRun) {
            Write-Log "[SIMUL] Criaria pasta: $Caminho" 'SIM'
        }
        else {
            New-Item -ItemType Directory -Path $Caminho -Force | Out-Null
            Write-Log "Pasta criada: $Caminho" 'OK'
        }
    }
}

function Move-ItemSeguro {
    param(
        [string]$Origem,
        [string]$PastaDestino,
        [bool]$EhArquivo
    )

    $nomeBase = Split-Path -Path $Origem -Leaf
    $destinoFinal = Get-DestinoSemColisao -Destino (Join-Path $PastaDestino $nomeBase) -EhArquivo $EhArquivo

    if ($DryRun) {
        Write-Log "[SIMUL] Moveria: '$Origem'  ->  '$destinoFinal'" 'SIM'
    }
    else {
        try {
            Ensure-Dir -Caminho $PastaDestino
            Move-Item -LiteralPath $Origem -Destination $destinoFinal -Force
            Write-Log "Movido: '$Origem'  ->  '$destinoFinal'" 'OK'
        }
        catch {
            Write-Log "FALHA ao mover '$Origem': $_" 'ERRO'
        }
    }
}

function Get-PastaDestinoArquivo {
    param(
        [System.IO.FileInfo]$Arquivo,
        [string]$PastaReformulacao,
        [string]$NomePastaOrigem
    )

    $ano = Get-AnoItem -Item $Arquivo

    if ($null -eq $ano) {
        return Join-Path $PastaReformulacao $PASTA_TRIAGEM_NOME
    }

    $categoria = Get-Categoria -Nome $Arquivo.Name
    if ($null -ne $categoria) {
        return Join-Path $PastaReformulacao "$ano\$categoria"
    }

    $subpasta = if ($NomePastaOrigem -ne '') { $NomePastaOrigem } else { 'Arquivos_Soltos' }
    return Join-Path $PastaReformulacao "$ano\${PASTA_IMPORTADOS}\$subpasta"
}

function Invoke-ProcessarPasta {
    param(
        [System.IO.DirectoryInfo]$Pasta,
        [string]$PastaReformulacao
    )

    Write-Log "Analisando pasta: '$($Pasta.FullName)'"

    $arquivos = @(Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -File -ErrorAction SilentlyContinue)
    if ($arquivos.Count -eq 0) {
        Write-Log "  Pasta vazia, ignorando: '$($Pasta.FullName)'" 'AVISO'
        return
    }

    $contagemAnos = @{}
    foreach ($arq in $arquivos) {
        $a = Get-AnoItem -Item $arq
        $chave = if ($null -eq $a) { 'SEM_ANO' } else { "$a" }
        if (-not $contagemAnos.ContainsKey($chave)) { $contagemAnos[$chave] = 0 }
        $contagemAnos[$chave]++
    }

    $totalArquivos = $arquivos.Count
    $anoMajoritario = $null
    $maxContagem = 0

    foreach ($chave in $contagemAnos.Keys) {
        if ($chave -ne 'SEM_ANO' -and $contagemAnos[$chave] -gt $maxContagem) {
            $maxContagem = $contagemAnos[$chave]
            $anoMajoritario = [int]$chave
        }
    }

    $percentual = if ($totalArquivos -gt 0 -and $null -ne $anoMajoritario) {
        [math]::Round(($maxContagem / $totalArquivos) * 100, 1)
    }
    else { 0 }

    Write-Log "  Total arquivos: $totalArquivos | Ano majoritario: $anoMajoritario ($percentual%)"

    if ($null -ne $anoMajoritario -and $percentual -ge 80) {
        Write-Log "  -> Movendo pasta inteira para ano $anoMajoritario" 'OK'
        $destinoPasta = Join-Path $PastaReformulacao "$anoMajoritario\${PASTA_IMPORTADOS}\$($Pasta.Name)"
        Ensure-Dir -Caminho (Split-Path $destinoPasta -Parent)
        Move-ItemSeguro -Origem $Pasta.FullName -PastaDestino (Split-Path $destinoPasta -Parent) -EhArquivo $false
    }
    else {
        Write-Log '  -> Anos mistos, processando arquivo a arquivo'
        foreach ($arq in $arquivos) {
            $pastaDestArq = Get-PastaDestinoArquivo -Arquivo $arq -PastaReformulacao $PastaReformulacao -NomePastaOrigem $Pasta.Name
            Ensure-Dir -Caminho $pastaDestArq
            Move-ItemSeguro -Origem $arq.FullName -PastaDestino $pastaDestArq -EhArquivo $true
        }

        if (-not $DryRun) {
            $restantes = @(Get-ChildItem -LiteralPath $Pasta.FullName -Recurse -ErrorAction SilentlyContinue)
            if ($restantes.Count -eq 0) {
                try {
                    Remove-Item -LiteralPath $Pasta.FullName -Recurse -Force
                    Write-Log "  Pasta de origem removida (vazia): '$($Pasta.FullName)'" 'OK'
                }
                catch {
                    Write-Log "  Nao foi possivel remover pasta vazia '$($Pasta.FullName)': $_" 'AVISO'
                }
            }
        }
    }
}

function Invoke-ProcessarArquivoSolto {
    param(
        [System.IO.FileInfo]$Arquivo,
        [string]$PastaReformulacao
    )

    Write-Log "Arquivo solto: '$($Arquivo.FullName)'"
    $pastaDestArq = Get-PastaDestinoArquivo -Arquivo $Arquivo -PastaReformulacao $PastaReformulacao -NomePastaOrigem ''
    Ensure-Dir -Caminho $pastaDestArq
    Move-ItemSeguro -Origem $Arquivo.FullName -PastaDestino $pastaDestArq -EhArquivo $true
}

function Main {
    $inicio = Get-Date

    Write-Log ('=' * 70)
    if ($DryRun) {
        Write-Log '  MODO SIMULACAO (DRY-RUN) - Nenhum arquivo sera movido' 'AVISO'
    }
    else {
        Write-Log '  MODO REAL - Arquivos SERAO movidos' 'AVISO'
    }
    Write-Log "  Raiz ENSINO   : $RaizEnsino"
    if ($EstruturaPath -ne '') { Write-Log "  Estrutura TXT : $EstruturaPath" }
    Write-Log "  Log           : $LogPath"
    Write-Log ('=' * 70)

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

    $itensRaiz = @(Get-ChildItem -LiteralPath $RaizEnsino -ErrorAction SilentlyContinue)

    $totalPastas = 0
    $totalArquivos = 0

    foreach ($item in $itensRaiz) {
        if ($item.Name -ieq $PASTA_DESTINO_NOME) {
            Write-Log "Ignorando (eh a pasta de destino): '$($item.FullName)'"
            continue
        }
        if ($item.FullName -ieq $LogPath) {
            continue
        }

        if ($item -is [System.IO.DirectoryInfo]) {
            $totalPastas++
            try {
                Invoke-ProcessarPasta -Pasta $item -PastaReformulacao $pastaReformulacao
            }
            catch {
                Write-Log "ERRO ao processar pasta '$($item.FullName)': $_" 'ERRO'
            }
        }
        elseif ($item -is [System.IO.FileInfo]) {
            $totalArquivos++
            try {
                Invoke-ProcessarArquivoSolto -Arquivo $item -PastaReformulacao $pastaReformulacao
            }
            catch {
                Write-Log "ERRO ao processar arquivo '$($item.FullName)': $_" 'ERRO'
            }
        }
    }

    $duracao = (Get-Date) - $inicio
    Write-Log ''
    Write-Log ('=' * 70)
    Write-Log "CONCLUIDO em $([math]::Round($duracao.TotalSeconds, 1))s"
    Write-Log "Pastas processadas : $totalPastas"
    Write-Log "Arquivos soltos    : $totalArquivos"
    if ($DryRun) {
        Write-Log 'NENHUMA alteracao foi feita (modo simulacao).' 'AVISO'
        Write-Log 'Para executar de verdade, rode sem o modo simulacao.' 'AVISO'
    }
    Write-Log ('=' * 70)
}

try {
    $null = New-Item -ItemType File -Path $LogPath -Force -ErrorAction SilentlyContinue
}
catch {
}

Main
