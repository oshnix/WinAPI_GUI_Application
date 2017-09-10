; #########################################################################

	.386
	.model flat, stdcall
	option casemap :none

; #########################################################################

	include  /masm32/include/windows.inc
	include /masm32/include/user32.inc
	include /masm32/include/kernel32.inc

	includelib /masm32/lib/user32.lib
	includelib /masm32/lib/kernel32.lib

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

	.data

		hInstance 		dd ?
		lpszCmdLine		dd ?

; #########################################################################

	.code

start:

	invoke 	GetModuleHandle, NULL
	mov	hInstance, eax

	invoke	GetCommandLine
	mov	lpszCmdLine, eax

	invoke 	WinMain, hInstance, NULL, lpszCmdLine, SW_SHOWDEFAULT
	invoke	ExitProcess, eax


; ------------------------------------------------------------------------
; WinMain
;
; Main program execution entry point
; ------------------------------------------------------------------------
WinMain proc 	hInst 		:dword,
		hPrevInst 	:dword,
		szCmdLine 	:dword,
		nShowCmd 	:dword

	local 	wc 	:WNDCLASSEX
	local 	msg 	:MSG
	local 	hWnd 	:HWND

	szText	szClassName, "BasicWindow"
	szText	szWindowTitle, "First Window"

	mov	wc.cbSize, sizeof WNDCLASSEX
	mov	wc.style, CS_HREDRAW or CS_VREDRAW or CS_BYTEALIGNWINDOW
	mov 	wc.lpfnWndProc, WndProc
	mov 	wc.cbClsExtra, NULL
	mov	wc.cbWndExtra, NULL

	push	hInst
	pop 	wc.hInstance

	mov	wc.hbrBackground, COLOR_BTNFACE + 1
	mov	wc.lpszMenuName, NULL
	mov 	wc.lpszClassName, offset szClassName

	invoke	LoadIcon, hInst, IDI_APPLICATION
	mov	wc.hIcon, eax
	mov	wc.hIconSm, eax

	invoke	LoadCursor, hInst, IDC_ARROW
	mov	wc.hCursor, eax

	invoke	RegisterClassEx, addr wc

	invoke	CreateWindowEx, WS_EX_APPWINDOW, addr szClassName, addr szWindowTitle,
				WS_OVERLAPPEDWINDOW,
				CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
				NULL, NULL, hInst, NULL

	mov	hWnd, eax

	invoke	ShowWindow, hWnd, nShowCmd
	invoke	UpdateWindow, hWnd

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
; WndProc
;
; Handles all of the messages sent to the window
; ------------------------------------------------------------------------
WndProc proc 	hWin 	:dword,
		uMsg 	:dword,
		wParam 	:dword,
		lParam 	:dword

	.if uMsg == WM_DESTROY

		invoke 	PostQuitMessage, 0

		xor	eax, eax
		ret

	.endif

	invoke	DefWindowProc, hWin, uMsg, wParam, lParam

	ret

WndProc endp

end start
