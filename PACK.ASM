ideal
p386
model small, pascal
locals
warn
smart

stack 1024

udataseg
Buf1 db 512 dup(?)
Buf2 db 512 dup(?)
ends

const
Data1 db 20 dup(0)
Data1Bytes = offset $ - offset Data1

Data2 db 5 dup(0), 5 dup(1, 2), 5 dup(0)
Data2Bytes = offset $ - offset Data2
ends

codeseg
proc PackBits
arg @@Src:far ptr byte, @@Dst:far ptr byte, @@SrcBytes:word
uses si, di, ds
        lds si, [@@Src]
        les di, [@@Dst]
        mov cx, [@@SrcBytes]
        cld
        push bp
        mov bp, offset @@Repeat
@@Loop:
        or cx, cx
        jz @@Exit
;
; Get first byte
;
        mov ah, [ds:si]
        inc si
        dec cx
        mov dx, 1
;
; Find longest run of matching bytes
;
@@FindMatchingLoop:
        cmp [ds:si], ah
        jne @@Found
        inc si
        inc dx
        dec cx
        jnz @@FindMatchingLoop
@@Found:
;
; Execute next state
;
@@NextState:
        jmp bp

@@EncodeMaxRepeat:        
        mov al, -(128 - 1)
        stosw
        sub dx, 128
@@Repeat:
        cmp dx, 128
        jae @@EncodeMaxRepeat
        cmp dx, 1
        je @@GoLiteral
        jb @@Loop
        mov al, dl
        dec al
        stosw
        jmp @@Loop
        
@@GoLiteral:
        mov bp, offset @@Literal
        cmp [byte es:di - 2], -(2 - 1)
        jne @@EncodeNewLiteral
        cmp [byte es:bx], 128 - 2 - 1
        jae @@StartNewLiteral
        add [byte es:bx], 2
        mov al, [es:di - 1]
        mov [es:di - 2], al
        jmp @@ExpandLiteral
@@StartNewLiteral:
        lea bx, [di - 2]
        mov [byte es:bx], 3 - 1
        mov al, [es:bx + 1]
        stosw
        jmp @@Loop
@@EncodeNewLiteral:
        mov bx, di
        sub al, al
        stosw
        jmp @@Loop

@@Literal:
        cmp dx, 1
        jbe @@ExpandLiteral
        mov bp, offset @@Repeat
        jmp bp
        
@@ExpandLiteral:
        cmp [byte es:bx], 128 - 1       ; literal run is full?
        je  @@EncodeNewLiteral
        inc [byte es:bx]
        mov al, ah
        stosb
        jmp @@Loop
        
@@Exit:
        pop bp
        sub di, [word low @@Dst]
        mov ax, di
        ret
endp


proc UnPackBits
arg @@Src:far ptr byte, @@Dst:far ptr byte, @@SrcBytes:word
uses si, di, ds
        lds si, [@@Src]
        les di, [@@Dst]
        mov dx, [@@SrcBytes]
        cld
@@Loop:
        or dx, dx
        jz @@Exit
;
; Get first byte
;
        lodsb
        dec dx
        or al, al
        js @@Repeat
;
; Expand literal
;
        cbw
        inc ax
        mov cx, ax
        sub dx, ax
        rep movsb
        jmp @@Loop
;
; Expand repeat
;
@@Repeat:
        neg al
        cbw
        inc ax
        mov cx, ax
        lodsb
        dec dx
        rep stosb
        jmp @@Loop
        
@@Exit:
        sub di, [word low @@Dst]
        mov ax, di
        ret
endp

proc Main far
        startupcode

irp c,<1,2>
        call PackBits, ds offset Data&c, ds offset Buf1, Data&c&Bytes
        call UnPackBits, ds offset Buf1, ds offset Buf2, ax
        cmp ax, Data&c&Bytes
        jne @@BadPack
        lea si, [Buf1]
        lea di, [Buf2]
        push ds
        pop es
        mov cx, ax
        repz cmpsb
        jnz @@BadPack
endm

        mov al, 0
        jmp @@Exit
@@BadPack:
        mov al, 1
@@Exit:        
        exitcode
endp

ends
end

