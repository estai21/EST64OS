[ORG 0x00]
[BITS 16]

SECTION .text

jmp 0x07C0:START

; boot loader 제외한 EST64 OS 이미지 크기 1024 sectors
TOTALSECTORCOUNT: dw 1024

; 코드 영역
START:
	; BIOS loads boot loader in 0x07C0
	mov ax, 0x07C0
	mov ds, ax
	; Setting 0xB800 in video memory register
	mov aX, 0xB800
	mov es, ax
	; SS = 0x0000
	mov ax, 0x0000
	mov ss, ax
	; SP = BP = 0xFFFE
	mov sp, 0xFFFE
	mov bp, 0xFFFE

; clear screen & 문자 속성값을 녹색으로 설정
	mov si, 0
.SCREENCLEARLOOP:
	mov byte[es:si], 0
	mov byte[es:si+1], 0x0A
	add si, 2
	cmp si, 80*25*2
	jl  .SCREENCLEARLOOP

; 화면 상단에 시작 메시지 출력
	push MESSAGE1
	push 0				; 화면 y 좌표 0
	push 0				; 화면 x 좌표 0
	call PRINTMESSAGE
	add sp, 6			; 삽입한 파라미터 제거

; OS 이미지를 로딩한다는 메시지 출력
	push IMAGELOADINGMESSAGE
	push 1				; 화면 y 좌표 1
	push 0				; 화면 x 좌표 0
	call PRINTMESSAGE
	add sp, 6

; 디스크에서 OS 이미지 로딩

; 디스크를 읽기 전에 먼저 리셋
RESETDISK:
; BIOS Reset Function 호출
	mov ax, 0			; for reset, AH = 0
	mov dl, 0			; num of drive (0=floppy)
	int 0x13
	jc  HANDLEDISKERROR	; 에러 발생 시 CF(Carry Flag)=1

; 디스크에서 섹터를 읽음
	mov si, 0x1000	; 디스크 내용을 메모리에 복사할 주소(ES:BX)를 0x10000으로 설정
	mov es, si
	mov bx, 0x0000	; ES:BX = 0x1000:0000 = 0x10000
	mov di, word[TOTALSECTORCOUNT]

READDATA:
; 모든 섹터를 다 읽었는지 확인
	cmp di, 0
	je  READEND
	sub di, 0x1

; BIOS Read Function 호출
	mov ah, 0x02 		; for read, AH = 2
	mov al, 0x1		; 읽을 섹터 수 1
	mov ch, byte[TRACKNUMBER]
	mov cl, byte[SECTORNUMBER]
	mov dh, byte[HEADNUMBER]
	mov dl, 0x00
	int 0x13
	jc  HANDLEDISKERROR

; 복사할 주소와 트랙, 섹터, 헤드 주소 계산
	add si, 0x0020	; 512(0x200)byte 만큼 ES 증가
	mov es, si			; ES:BX = 0x1020:0000 = 0x10200

; 한 섹터를 읽었으므로 섹터번호를 증가시키고 마지막 섹터(18)까지 읽었는지 판단
	mov al, byte[SECTORNUMBER]	; 섹터번호를 AL에 설정
	add al, 0x01					; 섹터번호를 1 증가
	mov byte[SECTORNUMBER], al
	cmp al, 19
	jl  READDATA

; 마지막 섹터까지 읽었으면(섹터넘버=19) 헤드를 토글(0<->1)
	xor byte[HEADNUMBER], 0x01
	mov byte[SECTORNUMBER], 0x01; 섹터번호를 다시 1로 설정

; 만약 헤드가 1->0 으로 바뀌었으면 양쪽 헤드 다 읽을 것이므로 트랙번호를 1 증가
	cmp byte[HEADNUMBER], 0x00
	jne READDATA
	add byte[TRACKNUMBER], 0x01
	jmp READDATA
READEND:

; OS이미지 로드가 완료되었다는 메시지 출력
	push LOADINGCOMPLETEMESSAGE
	push 1				; 화면 y 좌표 1
	push 20			; 화면 x 좌표 20
	call PRINTMESSAGE
	add sp, 6			; 삽입한 파라미터 제거

; 로딩한 가상 OS 이미지 실행
	jmp 0x1000:0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; functions
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
HANDLEDISKERROR:
	push DISKERRORMESSAGE
	push 1				; 화면 y 좌표 1
	push 20			; 화면 x 좌표 20
	call PRINTMESSAGE

	jmp $				; 현재 위치에서 무한루프 실

; PARAM : x좌표, y좌표, 문자열
PRINTMESSAGE:
	push bp
	mov  bp, sp

	push es
	push si
	push di
	push ax
	push cx
	push dx
	; ES에 비디오메모리 시작 주소 설정
	mov ax, 0xB800
	mov es, ax
	; y좌표를 이용하여 라인 어드레스를 구함
	mov ax, word[bp+6]
	mov si, 160			; 한 라인의 수 80*2byte = 160
	mul si					; ax=ax*si
	mov di, ax
	; x좌표를 이용하여 라인 어드레스를 구함
	mov ax, word[bp+4]
	mov si, 2				; 한 문자는 2 byte
	mul si					; ax=ax*si
	add di, ax				; y*160 + x*2
	; 출력할 문자열 주소
	mov si, word[bp+8]

.MESSAGELOOP:
	mov cl, byte[si]
	cmp cl, 0
	je  .MESSAGEEND
	mov byte[es:di], cl	; if cl!=0, print cl in es:di
	add si, 1				; 출력할 다음 문자열로 이동
	add di, 2				; 메모리에서는 2byte(문자,속) 이동
	jmp .MESSAGELOOP
.MESSAGEEND:
	pop dx
	pop cx
	pop ax
	pop di
	pop si
	pop es
	pop bp
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; messages & data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MESSAGE1: 					db 'EST64 OS Boot Loader Start!', 0
DISKERRORMESSAGE:			db 'Disk Error !', 0
IMAGELOADINGMESSAGE:		db 'OS Image Loading...', 0
LOADINGCOMPLETEMESSAGE:	db 'Complete !', 0

SECTORNUMBER:				db 0x02 ; OS 이미지가 시작하는 섹터 번호
HEADNUMBER:				db 0x00 ; OS 이미지가 시작하는 헤드 번호
TRACKNUMBER:				db 0x00 ; OS 이미지가 시작하는 트 번호

times 510 - ($ - $$)	db 0x00

db 0x55
db 0xAA	; dw 0xAA55
