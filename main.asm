; #########################################################################

	.386
	.model flat, stdcall
	option casemap :none

; #########################################################################

	include  /masm32/include/windows.inc
  include /masm32/macros/macros.asm
	include /masm32/include/user32.inc
	include /masm32/include/kernel32.inc
  include /masm32/include/gdi32.inc
  include		/masm32/include/comdlg32.inc

	includelib /masm32/lib/user32.lib
  includelib /masm32/lib/gdi32.lib
	includelib /masm32/lib/kernel32.lib
  includelib	/masm32/lib/comdlg32.lib

; #########################################################################

	szText macro name, text:vararg
		local 	lbl
		jmp	lbl
		name 	db text, 0
		lbl:
	endm

	WinMain proto :dword, :dword, :dword, :dword
	WndProc proto :dword, :dword, :dword, :dword

; #########################################################################

.const
    IDM_FILE_OPEN equ 1
    maxsize       equ 256
    memsize       equ 65535
    FilterString	db	"All Files",0,"*.*",0
		              db	"BMP Files",0,"*.bmp", 0,0 ;набор фильтров


; #########################################################################

.data
    szClassName   db "BasicWindow", 0
    szWindowTitle db "FirstWindow", 0
    menuOpen      db "&Open", 0
    menuFile      db "&File", 0
		hInstance 		dd ?
		lpszCmdLine		dd ?
    hWnd          HWND ?
    hFileImage    HBITMAP 0
    ofn		        OPENFILENAME <>	; структура для открытия файла
    buffer        db  maxsize dup(0)  ;буфер имени файла

; #########################################################################

.code

start:

	mov	hInstance, rv(GetModuleHandle, NULL)

	mov	lpszCmdLine, rv(GetCommandLine)

	invoke 	WinMain, hInstance, NULL, lpszCmdLine, SW_SHOWDEFAULT
	invoke	ExitProcess, eax


; ------------------------------------------------------------------------
; WinMain
;
; Main program execution entry point
; ------------------------------------------------------------------------
WinMain proc hInst 		  :dword,
		hPrevInst 	:dword,
		szCmdLine 	:dword,
		nShowCmd 	  :dword

	local 	wc 	:WNDCLASSEX
	local 	msg 	:MSG

  ;Заполнение структуры wc
	mov	wc.cbSize, sizeof WNDCLASSEX
	mov	wc.style, CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
	mov wc.lpfnWndProc, WndProc
	mov wc.cbClsExtra, NULL
	mov	wc.cbWndExtra, NULL

  push hInst
  pop wc.hInstance

	mov	wc.hbrBackground, COLOR_WINDOW + 1
	mov 	wc.lpszClassName, offset szClassName

	invoke	LoadIcon, hInst, IDI_APPLICATION
	mov	wc.hIcon, eax
	mov	wc.hIconSm, eax

	invoke	LoadCursor, hInst, IDC_ARROW
	mov	wc.hCursor, eax

	invoke	RegisterClassEx, addr wc  ;Регистрируем класс окна

  ;Создание основного окна
	invoke	CreateWindowEx, WS_EX_APPWINDOW, addr szClassName, addr szWindowTitle,
				WS_OVERLAPPEDWINDOW,
				CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
				NULL, NULL, hInst, NULL

	mov	hWnd, eax  ; сохранение handle окна

	invoke	ShowWindow, hWnd, nShowCmd  ;отображение окна
	invoke	UpdateWindow, hWnd          ;перерисовка окна

MessagePump:

	invoke 	GetMessage, addr msg, NULL, 0, 0

	cmp 	eax, 0
	je 	MessagePumpEnd

	invoke	TranslateMessage, addr msg
	invoke	DispatchMessage, addr msg

	jmp 	MessagePump

MessagePumpEnd:

	mov	eax, msg.wParam
	ret

WinMain endp

; ------------------------------------------------------------------------
;  AddMenus
; ------------------------------------------------------------------------

AddMenus proc hWin :HWND
    local hMenubar  :HMENU
    local hMenu     :HMENU

    mov hMenubar, rv(CreateMenu)
    mov hMenu, rv(CreateMenu)

    invoke AppendMenuA, hMenu, MF_STRING, IDM_FILE_OPEN, chr$("&Open")
    invoke AppendMenuA, hMenubar, MF_POPUP, hMenu, chr$("&File")
    invoke SetMenu, hWin, hMenubar

    ret
AddMenus endp

PaintImage proc hWin :HWND

    local rect  :RECT
    local hdc   :HDC
    local brush :HBRUSH

    mov hdc, rv(GetDC, hWin)
    mov brush, rv(CreatePatternBrush, hFileImage)

    invoke GetWindowRect, hWin, addr rect
    invoke FillRect, hdc, addr rect, brush
    invoke DeleteObject, brush
    invoke ReleaseDC, hWin, hdc

    ret
PaintImage endp


OpenFileDialogue proc hWin :HWND

    mov ofn.lStructSize, sizeof ofn
    mov eax, hWin
    mov ofn.hWndOwner, eax
    mov eax, hInstance
    mov ofn.hInstance, eax
    mov ofn.lpstrFilter, offset FilterString
    mov ofn.nFilterIndex, 2
    mov ofn.lpstrFile, offset buffer
    mov ofn.nMaxFile, maxsize
    mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER

    invoke GetOpenFileName, addr ofn
    .if eax != 0
      mov hFileImage, rv(LoadImage, NULL, ofn.lpstrFile, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE)
      invoke PaintImage, hWin
    .endif

    ret
OpenFileDialogue endp

; ------------------------------------------------------------------------
; WndProc
;
; Handles all of the messages sent to the window
; ------------------------------------------------------------------------
WndProc proc 	hWin 	:HWND,
		uMsg 	:dword,
		wParam 	:dword,
		lParam 	:dword

  .if uMsg == WM_CREATE
    invoke AddMenus, hWin

  .elseif uMsg == WM_PAINT
    mov eax, hFileImage
    .if eax != 0
      invoke PaintImage, hWin
    .endif

	.elseif uMsg == WM_DESTROY
		invoke 	PostQuitMessage, 0
		xor	eax, eax
		ret

  .elseif uMsg == WM_COMMAND
    mov eax, wParam
    .if eax == IDM_FILE_OPEN
        invoke OpenFileDialogue, hWin
    .endif
	.endif


	invoke	DefWindowProc, hWin, uMsg, wParam, lParam

	ret

WndProc endp

end start
