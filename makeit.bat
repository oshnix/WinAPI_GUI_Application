@echo off

    if exist "main.obj" del "main.obj"
    if exist "main.exe" del "main.exe"

    \masm32\BIN\Ml.exe /c /coff "main.asm"
    if errorlevel 1 goto errasm

    \masm32\BIN\Link.exe /SUBSYSTEM:WINDOWS "main.obj"
    if errorlevel 1 goto errlink
    dir "main.*"
    goto TheEnd

  :errlink
    echo _
    echo Link error
    goto TheEnd

  :errasm
    echo _
    echo Assembly Error
    goto TheEnd

  :TheEnd

pause
