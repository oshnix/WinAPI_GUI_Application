; #########################################################################

	include /masm32/include/windows.inc
	include	/masm32/include/user32.inc
	include	/masm32/include/kernel32.inc
	include	/masm32/include/comdlg32.inc
	include	/masm32/macros/macros.asm
	include	/masm32/include/gdi32.inc

	includelib /masm32/lib/gdi32.lib
	includelib /masm32/lib/user32.lib
	includelib /masm32/lib/kernel32.lib
	includelib /masm32/lib/comdlg32.lib

; #########################################################################

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
		firstMask		db	0ffh, 0, 0, 0ffh, 0, 0, 0ffh, 0
		secondMask		db	0, 0, 0ffh, 0, 0, 0ffh, 0, 0
		thirdMask		db	0, 0ffh, 0, 0, 0ffh, 0, 0, 0ffh
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
