@echo off
setlocal EnableExtensions

set "SCRIPT_DIR=%~dp0"
if "%SCRIPT_DIR:~-1%"=="\" set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
set "TOOLS_DIR=%USERPROFILE%\tools"

if not exist "%TOOLS_DIR%" (
  mkdir "%TOOLS_DIR%" || (
    echo error: cannot create directory "%TOOLS_DIR%"
    exit /b 1
  )
)

call :link_one git-auto-merge
if errorlevel 1 exit /b 1
call :link_one gt
if errorlevel 1 exit /b 1
call :link_one git-merge
if errorlevel 1 exit /b 1
call :link_one git-delete
if errorlevel 1 exit /b 1
call :link_one git-mr
if errorlevel 1 exit /b 1
call :link_one git-compare
if errorlevel 1 exit /b 1

echo done: tool links under "%TOOLS_DIR%" are ready
exit /b 0

:link_one
set "NAME=%~1"
set "SOURCE=%SCRIPT_DIR%\%NAME%"
set "TARGET=%TOOLS_DIR%\%NAME%"

if not exist "%SOURCE%" (
  echo error: missing source file "%SOURCE%"
  exit /b 1
)

if exist "%TARGET%\NUL" (
  echo exists, skip: "%TARGET%"
  exit /b 0
)

if exist "%TARGET%" (
  echo exists, skip: "%TARGET%"
  exit /b 0
)

mklink "%TARGET%" "%SOURCE%" >nul
if errorlevel 1 (
  echo error: failed to create link "%TARGET%" -^> "%SOURCE%"
  echo note: mklink may require Developer Mode or an elevated cmd session.
  exit /b 1
)

echo linked: "%TARGET%" -^> "%SOURCE%"
exit /b 0
