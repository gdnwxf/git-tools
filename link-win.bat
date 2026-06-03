@echo off
setlocal EnableExtensions

for %%I in ("%~dp0.") do set "SCRIPT_DIR=%%~fI"
set "TOOLS_DIR=%USERPROFILE%\tools"

if not exist "%TOOLS_DIR%" (
  mkdir "%TOOLS_DIR%" || (
    echo 错误: 无法创建目录 "%TOOLS_DIR%"
    exit /b 1
  )
)

call :link_one gam
if errorlevel 1 exit /b 1
call :link_one gt
if errorlevel 1 exit /b 1
call :link_one merge
if errorlevel 1 exit /b 1
call :link_one mr
if errorlevel 1 exit /b 1
call :link_one cmpr
if errorlevel 1 exit /b 1

echo 完成: 已更新 "%TOOLS_DIR%" 下的工具链接
exit /b 0

:link_one
set "NAME=%~1"
set "SOURCE=%SCRIPT_DIR%\%NAME%"
set "TARGET=%TOOLS_DIR%\%NAME%"

if not exist "%SOURCE%" (
  echo 错误: 未找到源文件 "%SOURCE%"
  exit /b 1
)

if exist "%TARGET%\NUL" (
  echo 已存在，跳过: "%TARGET%"
  exit /b 0
)

if exist "%TARGET%" (
  echo 已存在，跳过: "%TARGET%"
  exit /b 0
)

mklink "%TARGET%" "%SOURCE%" >nul
if errorlevel 1 (
  echo 错误: 创建链接失败 "%TARGET%" -> "%SOURCE%"
  exit /b 1
)

echo 已链接: "%TARGET%" -> "%SOURCE%"
exit /b 0
