; #########################################################################

	.686
	.model flat, stdcall
	option casemap :none

; #########################################################################

	include /masm32/include/windows.inc
	include	/masm32/macros/macros.asm
	include	/masm32/include/user32.inc
	include	/masm32/include/kernel32.inc
	include	/masm32/include/gdi32.inc
	include	/masm32/include/gdiplus.inc
	include	/masm32/include/comdlg32.inc

	includelib /masm32/lib/user32.lib
	includelib /masm32/lib/gdi32.lib
	includelib /masm32/lib/gdiplus.lib
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
	IDM_TRANSORM_MEASURE	equ 4
	IDM_IMAGE_MUL_GREEN		equ 5
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
	cm				dd	25 dup(0.0)
	colorMatrix		REAL4  1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f
	bmiInfoHeader	BITMAPINFOHEADER <>
	bmiFileHeader	BITMAPFILEHEADER <>
	opfilestruc		OFSTRUCT <>
	hFile			HANDLE ?
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
;	TransformImageByPixel
;		change hFileImage and delete green and red chanels
; ------------------------------------------------------------------------
TransformImageByPixel proc hdc	:HDC,
			xSize				:LONG,
			ySize				:LONG

	local xcounter	:DWORD
	local ycounter	:DWORD

	mov ycounter, 0
	externalForBegin:
		mov eax, ycounter
		inc eax
		mov ycounter, eax
		cmp eax, ySize
		ja externalForEnd
		mov xcounter, 0
		innerForBegin:
			mov eax, xcounter
			inc eax
			mov xcounter, eax
			cmp eax, xSize
			ja innerForEnd
			invoke GetPixel, hdc, xcounter, ycounter
			and eax, 00ff0000h
			invoke SetPixel, hdc, xcounter, ycounter, eax
			jmp innerForBegin
		innerForEnd:
		jmp externalForBegin
	externalForEnd:

	ret
TransformImageByPixel endp

; ------------------------------------------------------------------------
;	DebugAndMeasureTransform
; ------------------------------------------------------------------------
DebugAndMeasureTransform proc hWin	:HWND

	local memHdc1	:HDC
	local memHdc2	:HDC
	local fPart		:dword
	local sPart		:dword
	local xPix		:dword
	local yPix		:dword

	mov memHdc1, rv(CreateCompatibleDC, NULL)
	invoke SelectObject, memHdc1, hFileImage

	mov xPix, 2200
	mov yPix, 2200

	loopBegin:
		mov eax, xPix
		sub eax, 200
		mov xPix, eax

		mov ecx, yPix
		sub ecx, 200
		mov yPix, 200

		cmp eax, 0
		jbe loopEnd

			mov memHdc2, rv(CreateCompatibleDC, NULL)

			invoke CreateSolidBrush, 00ff0000h
			invoke SelectObject, memHdc2, eax

			invoke BitBlt, memHdc2, 0, 0, eax, ecx, memHdc1, 0, 0, SRCCOPY

			rdtsc
			mov fPart, edx
			mov sPart, eax
			invoke BitBlt, memHdc2, 0, 0,  xPix, yPix, memHdc2, 0, 0, MERGECOPY
			rdtsc
			sub edx, fPart
			sub eax, sPart
			nop	;First debug point

			rdtsc
			mov fPart, edx
			mov sPart, eax
			invoke TransformImageByPixel, memHdc2, xPix, yPix
			rdtsc
			sub edx, fPart
			sub eax, sPart
			nop	;Second debug point

			invoke DeleteDC, memHdc2

		jmp loopBegin
	loopEnd:

	invoke DeleteDC, memHdc1

	ret
DebugAndMeasureTransform endp

; ------------------------------------------------------------------------
;	TransformImage
;		change hFileImage and delete green and red chanels
; ------------------------------------------------------------------------

TransformImage proc hWin :HWND

	local bm		:BITMAP
	local rect		:RECT
	local memHdc1	:HDC

	mov memHdc1, rv(CreateCompatibleDC, NULL)

	invoke CreateSolidBrush, 00ff0000h
	invoke SelectObject, memHdc1, eax

	invoke SelectObject, memHdc1, hFileImage
	invoke GetObject, hFileImage, sizeof bm, addr bm

	invoke BitBlt, memHdc1, 0, 0,  bm.bmWidth, bm.bmHeight, memHdc1, 0, 0, MERGECOPY

	invoke DeleteDC, memHdc1

	invoke RedrawWindow, hWin, NULL, NULL, RDW_INVALIDATE or RDW_INTERNALPAINT

	ret
TransformImage endp

; ------------------------------------------------------------------------
;	TransformImageGreen
;		change hFileImage and multiple green channel
; -----------------------------------------------------------------------

TransformImageGreen proc hWin :HWND

	local hdc					:HDC
	local sourceImageGraphic	:dword
	local imageAttributes		:dword
	local graphics				:dword

	mov hdc, rv(CreateCompatibleDC, NULL)
	invoke SelectObject, hdc, hFileImage
	invoke GdipCreateFromHDC, hdc, addr graphics

	invoke GdipCreateBitmapFromHBITMAP, hFileImage, NULL, addr sourceImageGraphic
	invoke GdipCreateImageAttributes, addr imageAttributes

	invoke GdipSetImageAttributesColorMatrix, imageAttributes, ColorAdjustTypeDefault, TRUE, addr cm, NULL, ColorMatrixFlagsDefault
	invoke GdipDrawImage, graphics, sourceImageGraphic, 0, 0

	invoke GdipCreateHBITMAPFromBitmap, sourceImageGraphic, addr hFileImage, NULL
	ret
TransformImageGreen endp

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
