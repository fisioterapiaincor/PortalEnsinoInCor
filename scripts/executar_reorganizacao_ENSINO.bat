@echo off
REM ============================================================
REM  Reorganizacao da pasta ENSINO
REM  Executa o script PowerShell reorganizar-ensino.ps1
REM ============================================================
chcp 65001 >nul 2>&1
cd /d "%~dp0"

cls
echo.
echo ============================================================
echo      REORGANIZACAO DA PASTA ENSINO - Ensino Reformulacao
echo ============================================================
echo.
echo  Este script ira analisar e reorganizar os arquivos e pastas
echo  que estao dentro de ENSINO mas fora de "Ensino Reformulacao".
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
    set PS_EXTRA=-DryRun
    echo.
    echo  >> Modo SIMULACAO selecionado. Nenhum arquivo sera movido. <<
    echo.
) else if "%MODO%"=="2" (
    set PS_EXTRA=
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

echo.
echo ============================================================
echo  Verificando PowerShell...
echo ============================================================
echo.

powershell -Command "exit 0" >nul 2>&1
if errorlevel 1 (
    echo  [ERRO] PowerShell nao encontrado ou sem permissao de execucao.
    echo.
    echo  Certifique-se de que o PowerShell esta instalado e disponivel.
    echo.
    goto :FIM_ERRO
)

echo  [OK] PowerShell disponivel.
echo.
echo ============================================================
echo  Iniciando reorganizacao...
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0reorganizar-ensino.ps1" %PS_EXTRA%

if errorlevel 1 (
    echo.
    echo ============================================================
    echo  [ERRO] O script PowerShell terminou com erro.
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

:FIM_ERRO
echo.
pause
exit /b 1

:FIM
echo.
pause
exit /b 0
