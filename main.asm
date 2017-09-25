; #########################################################################

	.686
	.model flat, stdcall
	option casemap :none

; #########################################################################
	include project.inc
; #########################################################################
	include gdi_funcs.inc
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
WinMain proc hInst	:dword,
		hPrevInst	:dword,
		szCmdLine	:dword,
		nShowCmd	:dword

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
;	AddMenus
;		Uses Global hMenuEdit
; ------------------------------------------------------------------------

AddMenus proc hWin :HWND
	local hMenubar	:HMENU
	local hMenuFile	:HMENU
	local hMenuEdit	:HMENU

	mov hMenubar, rv(CreateMenu)
	mov hMenuFile, rv(CreateMenu)
	mov hMenuEdit, rv(CreateMenu)

	invoke AppendMenuA, hMenuFile, MF_STRING, IDM_FILE_OPEN, chr$("&Open")
	invoke AppendMenuA, hMenuFile, MF_STRING, IDM_FILE_SAVE, chr$("&Save")

	invoke AppendMenuA, hMenuEdit, MF_STRING, IDM_IMAGE_TRANSFORM, chr$("&Transform 1")
	invoke AppendMenuA, hMenuEdit, MF_STRING, IDM_IMAGE_MUL_GREEN, chr$("&Transform 2")
	invoke AppendMenuA, hMenuEdit, MF_STRING, IDM_TRANSORM_MEASURE, chr$("&Debug and measure")

	invoke AppendMenuA, hMenubar, MF_POPUP, hMenuFile, chr$("&File")
	invoke AppendMenuA, hMenubar, MF_POPUP, hMenuEdit, chr$("&Edit")
	invoke SetMenu, hWin, hMenubar

	ret
AddMenus endp

; ------------------------------------------------------------------------
;  	OpenFileStructCreate
; ------------------------------------------------------------------------
OpenFileStructCreate proc hWin	:HWND

	mov ofn.lStructSize, sizeof ofn
	mov eax, hWin
	mov ofn.hWndOwner, eax
	mov eax, hInstance
	mov ofn.hInstance, eax
	mov ofn.lpstrFilter, offset FilterString
	mov ofn.nFilterIndex, 2
	mov ofn.lpstrFile, offset buffer
	mov ofn.nMaxFile, maxsize

	ret
OpenFileStructCreate endp


; ------------------------------------------------------------------------
;  OpenFileDialogue
; ------------------------------------------------------------------------

OpenFileDialogue proc hWin :HWND

	mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER

	invoke GetOpenFileName, addr ofn
	.if eax != 0
		mov hFileImage, rv(LoadImage, NULL, ofn.lpstrFile, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE or LR_DEFAULTSIZE)
		mov hFile, rv(OpenFile, ofn.lpstrFile, addr opfilestruc, OF_READ)
		invoke ReadFile, hFile, addr bmiFileHeader, sizeof BITMAPFILEHEADER, NULL, NULL
		invoke ReadFile, hFile, addr bmiInfoHeader, sizeof BITMAPINFOHEADER, NULL, NULL
		invoke CloseHandle, hFile
		invoke RedrawWindow, hWin, NULL, NULL, RDW_INVALIDATE or RDW_INTERNALPAINT
	.endif

	ret
OpenFileDialogue endp

; ------------------------------------------------------------------------
;  	CreateBitmapInfoStruct
; ------------------------------------------------------------------------
CreateBMPFile proc hWin		:HWND,
			infoHeader		:BITMAPINFOHEADER,
			fileHeader		:BITMAPFILEHEADER,
			pszFile			:LPTSTR,
			hdc				:HDC,
			hBmp			:HBITMAP

	local hf		:HANDLE
	local lpBits	:LPBYTE
	local dwTmp		:DWORD

	mov lpBits, rv(GlobalAlloc, GMEM_FIXED, infoHeader.biSizeImage)

	invoke GetDIBits, hdc, hBmp, 0, infoHeader.biHeight, lpBits, addr infoHeader, DIB_RGB_COLORS

	mov hf, rv(CreateFile, pszFile, GENERIC_READ or GENERIC_WRITE,0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL)

	invoke WriteFile, hf, addr fileHeader, sizeof fileHeader, addr dwTmp, NULL
	invoke WriteFile, hf, addr infoHeader, sizeof infoHeader, addr dwTmp, NULL

	mov ecx, infoHeader.biSizeImage

	invoke WriteFile, hf, lpBits, ecx, addr dwTmp, NULL
	invoke CloseHandle, hf
	invoke GlobalFree, lpBits

	ret
CreateBMPFile endp


; ------------------------------------------------------------------------
;  	SaveFileDialogue
; ------------------------------------------------------------------------
SaveFileDialogue proc hWin	:HWND

	local hdc	:HDC

	mov hdc, rv(CreateCompatibleDC, NULL)

	mov ofn.Flags, OFN_HIDEREADONLY or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER
	invoke GetSaveFileName, addr ofn
	.if eax != 0
		invoke CreateBMPFile, hWin, bmiInfoHeader, bmiFileHeader, ofn.lpstrFile, hdc, hFileImage
	.endif

	ret
SaveFileDialogue endp

; ------------------------------------------------------------------------
; 	WndProc
;		Handles all of the messages sent to the window
; ------------------------------------------------------------------------
WndProc proc hWin 	:HWND,
		uMsg 	:dword,
		wParam 	:dword,
		lParam 	:dword

	.if uMsg == WM_CREATE
		invoke AddMenus, hWin
		invoke OpenFileStructCreate, hWin

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
		.elseif eax == IDM_IMAGE_TRANSFORM
			invoke TransformImage, hWin
		.elseif eax == IDM_TRANSORM_MEASURE
			mov eax, hFileImage
			.if eax != 0
				invoke DebugAndMeasureTransform, hWin
			.endif
		.elseif eax == IDM_IMAGE_MUL_GREEN
			mov eax, hFileImage
			.if eax != 0
				invoke TransformImageGreen, hWin
			.endif
		.elseif eax == IDM_FILE_SAVE
			mov eax, hFileImage
			.if eax != 0
				invoke SaveFileDialogue, hWin
			.endif
		.endif
	.endif

	invoke	DefWindowProc, hWin, uMsg, wParam, lParam

	ret
WndProc endp

end start
