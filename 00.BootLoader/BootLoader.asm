[ORG 0x00]
[BITS 16]

SECTION .text

mov ax, 0xB800
mov ds, ax

; 암묵적으로 'DS':offset 사용
mov byte[0x00], 'M'	; 'M' in DS:0x0000
mov byte[0x01], 0x0A	; 0x0A in DS:0x0001

jmp $					; 아직 더 이상 로드할 이미지가 없으므로 임시로 여기서 무한루프

; 0 padding for boot loader(512byte)
times 510 - ($ - $$)	db 0x00

; signature for boot loader ( dw 0xAA55 )
db 0x55
db 0xAA
