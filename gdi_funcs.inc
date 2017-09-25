.code

; ------------------------------------------------------------------------
;	PaintImage
; ------------------------------------------------------------------------

PaintImage proc hWin :HWND
	local ps			:PAINTSTRUCT
	local bm			:BITMAP

	local hdc			:HDC
	local memHdc		:HDC

	local rect			:RECT
	local	image		:HBITMAP

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

TransformImageGreen proc hWin 	:HWND
	local hdc		:HDC
	local lpBits		:LPBYTE

	push esi
	push edi

	mov hdc, rv(CreateCompatibleDC, NULL)

	mov lpBits, rv(GlobalAlloc, GMEM_FIXED, bmiInfoHeader.biSizeImage)

	invoke GetDIBits, hdc, hFileImage, 0, bmiInfoHeader.biHeight, lpBits, addr bmiInfoHeader, DIB_RGB_COLORS

	mov ecx, -24
	mov edx, bmiInfoHeader.biSizeImage
	mov esi, [lpBits]
	loopBegin:
		add ecx, 48
		cmp ecx, edx
		ja	loopEnd

		sub ecx, 8
		movq mm0, [esi + ecx]
		movq mm1, QWORD PTR [firstMask]
		pand mm1, mm0
		paddusb mm0, mm1
		movq [esi + ecx], mm0

		sub ecx, 8
		movq mm0, [esi + ecx]
		movq mm1, QWORD PTR [secondMask]
		pand mm1, mm0
		paddusb mm0, mm1
		movq [esi + ecx], mm0

		sub ecx, 8
		movq mm0, [esi + ecx]
		movq mm1, QWORD PTR [thirdMask]
		pand mm1, mm0
		paddusb mm0, mm1
		movq [esi + ecx], mm0

		jmp loopBegin
	loopEnd:

	sub ecx, 24
	inc esi
	mov di, 2
	xor eax, eax

	finalLoopBegin:
		add ecx, 3
		cmp ecx, edx
		ja finalLoopEnd

		mov al, BYTE PTR[esi + ecx]
		mul di
		jb finalLoopWriteMem	;If result is bigger than 0xFF
		xor eax, eax
		mov al, 0ffh

	finalLoopWriteMem:
		mov BYTE PTR[esi + ecx], al

		jmp finalLoopBegin
	finalLoopEnd:

	invoke SetDIBits, hdc, hFileImage, 0, bmiInfoHeader.biHeight, lpBits, addr bmiInfoHeader, DIB_RGB_COLORS

	invoke GlobalFree, lpBits

	invoke RedrawWindow, hWin, NULL, NULL, RDW_INVALIDATE or RDW_INTERNALPAINT

	pop edi
	pop esi

	ret
TransformImageGreen endp
