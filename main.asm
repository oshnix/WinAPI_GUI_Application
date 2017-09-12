; #########################################################################

	.386
	.model flat, stdcall
	option casemap :none

; #########################################################################

	include /masm32/include/windows.inc
	include /masm32/macros/macros.asm
	include /masm32/include/user32.inc
	include /masm32/include/kernel32.inc
	include /masm32/include/gdi32.inc
	include	/masm32/include/comdlg32.inc

	includelib /masm32/lib/user32.lib
	includelib /masm32/lib/gdi32.lib
	includelib /masm32/lib/kernel32.lib
	includelib /masm32/lib/comdlg32.lib

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
	;ID сообщений для WM_COMMAND
	IDM_FILE_OPEN			equ 1
	IDM_FILE_SAVE			equ 2
	IDM_IMAGE_TRANSFORM		equ 3
	;макс длина имени файла
	maxsize       			equ 256
	;Фильтры для файлов
    FilterString			db	"All Files",0,"*.*",0
							db	"BMP Files",0,"*.bmp", 0,0



; #########################################################################

.data
	szClassName		db "BasicWindow", 0
	szWindowTitle	db "ImageTransformer", 0
	menuOpen		db "&Open", 0
	menuFile		db "&File", 0
	hInstance		dd ?
	lpszCmdLine		dd ?
	pbmi			BITMAPINFO <>
	hWnd			HWND ?
	hFileImage		HBITMAP 0
	ofn				OPENFILENAME <>	; структура для открытия файла
	buffer			db  maxsize dup(0)  ;буфер имени файла

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
;  AddMenus
; ------------------------------------------------------------------------

AddMenus proc hWin :HWND
	local hMenubar  :HMENU
	local hMenu     :HMENU

	mov hMenubar, rv(CreateMenu)
	mov hMenu, rv(CreateMenu)

	invoke AppendMenuA, hMenu, MF_STRING, IDM_FILE_OPEN, chr$("&Open")
	invoke AppendMenuA, hMenu, MF_STRING, IDM_FILE_SAVE, chr$("&Save")
	invoke AppendMenuA, hMenu, MF_SEPARATOR, 0, NULL
	invoke AppendMenuA, hMenu, MF_STRING, IDM_IMAGE_TRANSFORM, chr$("&Transform")
	invoke AppendMenuA, hMenubar, MF_POPUP, hMenu, chr$("&File")
	invoke SetMenu, hWin, hMenubar

	ret
AddMenus endp

; ------------------------------------------------------------------------
;	PaintImage
; ------------------------------------------------------------------------

PaintImage proc hWin :HWND
	local ps			:PAINTSTRUCT
	local bm			:BITMAP

	local hdc					:HDC
	local memHdc			:HDC

	local rect				:RECT
	local	image				:HBITMAP

	mov hdc, rv(BeginPaint, hWin, addr ps)
	mov memHdc, rv(CreateCompatibleDC, hdc)

	invoke GetClientRect, hWin, addr rect

	mov image, rv(SelectObject, memHdc, hFileImage)
	invoke GetObject, hFileImage, sizeof bm, addr bm

	invoke SetStretchBltMode, hdc, HALFTONE

	mov eax, rect.right
	sub eax, rect.left

	mov ecx, rect.bottom
	sub ecx, rect.top

	invoke StretchBlt, hdc, 0, 0,	eax, ecx, memHdc, 0, 0, bm.bmWidth, bm.bmHeight, SRCCOPY

	invoke SelectObject, memHdc, image
	invoke DeleteDC, memHdc

	invoke EndPaint, hWin, addr ps

	ret
PaintImage endp

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
;	TransformImage
;		change hFileImage and delete green and red chanels
; ------------------------------------------------------------------------

TransformImage proc hWin :HWND
	local	bm			:BITMAP
	local rect		:RECT
	local memHdc1	:HDC
	local memHdc2	:HDC
	local image		:HBITMAP

	mov memHdc1, rv(CreateCompatibleDC, NULL)
	mov memHdc2, rv(CreateCompatibleDC, NULL)

	invoke CreateSolidBrush, 00ff0000h
	invoke SelectObject, memHdc1, eax

	invoke SelectObject, memHdc1, hFileImage
	invoke SelectObject, memHdc2, hFileImage
	invoke GetObject, hFileImage, sizeof bm, addr bm

	invoke BitBlt, memHdc1, 0, 0,  bm.bmWidth, bm.bmHeight, memHdc1, 0, 0, MERGECOPY

	invoke DeleteDC, memHdc1
	invoke DeleteDC, memHdc2

	invoke RedrawWindow, hWin, NULL, NULL, RDW_INVALIDATE or RDW_INTERNALPAINT

	ret
TransformImage endp
; ------------------------------------------------------------------------
;  OpenFileDialogue
; ------------------------------------------------------------------------

OpenFileDialogue proc hWin :HWND

	mov ofn.Flags, OFN_FILEMUSTEXIST or OFN_PATHMUSTEXIST or OFN_LONGNAMES or OFN_EXPLORER

	invoke GetOpenFileName, addr ofn
	.if eax != 0
		mov hFileImage, rv(LoadImage, NULL, ofn.lpstrFile, IMAGE_BITMAP, 0, 0, LR_LOADFROMFILE)
		invoke RedrawWindow, hWin, NULL, NULL, RDW_INVALIDATE or RDW_INTERNALPAINT
	.endif

	ret
OpenFileDialogue endp

; ------------------------------------------------------------------------
;  	CreateBitmapInfoStruct
; ------------------------------------------------------------------------
CreateBitmapInfoStruct proc	hWin	:HWND,
		hBmp	:HBITMAP

	local bmp		:BITMAP
	local cBitCount	:word

	invoke GetObject, hBmp, sizeof bmp, addr bmp

	mov ax, bmp.bmPlanes
	mul bmp.bmBitsPixel
	mov cBitCount, ax

	.if ax <= 24
		mov cBitCount, 24
	.else
		mov cBitCount, 32
	.endif

	mov pbmi.bmiHeader.biSize, sizeof BITMAPINFOHEADER

	mov eax, bmp.bmHeight
	mov pbmi.bmiHeader.biHeight, eax

	mov ax, bmp.bmPlanes
	mov pbmi.bmiHeader.biPlanes, ax

	mov ax, bmp.bmBitsPixel
	mov pbmi.bmiHeader.biBitCount, ax

	mov pbmi.bmiHeader.biCompression, BI_RGB

	mov eax, bmp.bmWidth
	mov pbmi.bmiHeader.biWidth, eax

	mul cBitCount
	add eax, 31

	mov ecx, 31
	not ecx

	and eax, ecx
	mov ecx, 8
	div ecx
	mov ecx, pbmi.bmiHeader.biHeight
	mul ecx
	mov pbmi.bmiHeader.biSizeImage, eax

	mov pbmi.bmiHeader.biClrImportant, 0

	ret
CreateBitmapInfoStruct endp

; ------------------------------------------------------------------------
;  	CreateBitmapInfoStruct
; ------------------------------------------------------------------------
CreateBMPFile proc hWin		:HWND,
			pszFile			:LPTSTR,
			hBmp			:HBITMAP,
			hdc				:HDC

	local hdr 		:BITMAPFILEHEADER
	local hf		:HANDLE
	local cb		:DWORD
	local lpBits	:LPBYTE
	local dwTmp		:DWORD


	mov lpBits, rv(GlobalAlloc, GMEM_FIXED, pbmi.bmiHeader.biSizeImage)

	invoke GetDIBits, hdc, hBmp, 0, pbmi.bmiHeader.biHeight, lpBits, addr pbmi, DIB_RGB_COLORS

	mov hf, rv(CreateFile, pszFile, GENERIC_READ or GENERIC_WRITE,0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL)

	mov hdr.bfType, 4d42h
	mov eax, sizeof RGBQUAD
	mul pbmi.bmiHeader.biClrUsed
	add eax, pbmi.bmiHeader.biSize
	add eax, sizeof BITMAPFILEHEADER
	mov ecx, eax
	add eax, pbmi.bmiHeader.biSizeImage
	mov hdr.bfSize, eax

	mov hdr.bfReserved1, 0
	mov hdr.bfReserved2, 0

	mov hdr.bfOffBits, ecx

	invoke WriteFile, hf, addr hdr, sizeof BITMAPFILEHEADER, addr dwTmp, NULL
	mov ecx, sizeof RGBQUAD
	mul pbmi.bmiHeader.biClrUsed
	add ecx, sizeof BITMAPINFOHEADER

	invoke WriteFile, hf, addr pbmi.bmiHeader, ecx, addr dwTmp, NULL
	mov eax, pbmi.bmiHeader.biSizeImage
	mov cb, eax

	invoke WriteFile, hf, lpBits, cb, addr dwTmp, NULL
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
		invoke CreateBitmapInfoStruct, hWin, hFileImage
		invoke CreateBMPFile, hWin, ofn.lpstrFile, hFileImage, hdc
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
