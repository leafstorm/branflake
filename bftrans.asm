;--------------------------------------------------------------------------
;
;   BFTRANS.ASM
;
;   This file contains the core of the Branflake compiler.
;   It translates a file from Branflake to assembler, for use with MASM
;   or similar assemblers.
;
;   Usage: bftrans < SOURCE.bf > SOURCE.asm
;
;   This program is only intended to be used as a standalone executable.
;   It can be integrated into a larger workflow with a batch file like
;   BFML.BAT, which uses MASM.
;
;   For a description of the Branflake language, see the included
;   README.md file.
;
;   (C) 2013, Matthew Frazier <leafstormrush@gmail.com>
;   Released under the terms of the MIT/X11 license,
;   see the LICENSE file for details.
;
;--------------------------------------------------------------------------

            .model small                ; 64k data, 64k code.
            .8086                       ; 8086 instructions only.
            .stack 256                  ; 256-byte stack.
            include bfio.inc            ; Load definitions from BFIO.

;--------------------------------------------------------------------------
            .data
;--------------------------------------------------------------------------
;   Instruction constants
;   The "C" constants contain the ASCII values for the instructions.
;   The "I" constants contain jump table offsets.
;--------------------------------------------------------------------------
INONE       equ 0

CNEXT       equ '>'
INEXT       equ 2

CPREV       equ '<'
IPREV       equ 4

CINC        equ '+'
IINC        equ 6

CDEC        equ '-'
IDEC        equ 8

CSKIP       equ '['
ISKIP       equ 10

CLOOP       equ ']'
ILOOP       equ 12

CWRITE      equ '.'
IWRITE      equ 14

CREAD       equ ','
IREAD       equ 16

IEOF        equ 18

;--------------------------------------------------------------------------
;   Instruction translation table
;   This translates ASCII instructions into their equivalents.
;--------------------------------------------------------------------------
insttable   db 26 dup (INONE)               ; 0-25 are nothing.
            db IEOF                         ; 26: End of file.
            db 16 dup (INONE)               ; 27-42 are also nothing.
            db IINC, IREAD, IDEC, IWRITE    ; 43-46: + , - .
            db 13 dup (INONE)               ; 47-59 are still nothing.
            db IPREV, INONE, INEXT          ; 60-62: < = >
            db 28 dup (INONE)               ; 63-90 are still nothing.
            db ISKIP, INONE, ILOOP          ; 91-93: [ \ ]
            db 162 dup (INONE)              ; Pad the table to 255 bytes.

;--------------------------------------------------------------------------
;   Structural assembly templates
;--------------------------------------------------------------------------
headerasm   db "; Generated by Branflake", NL
            db ".model small", NL       ; 64K data and code for programs.
            db ".8086", NL              ; Programs use only 8068 instructions.
            db ".stack 256", NL, NL, Z  ; They don't actually need a stack,
                                        ; but I'm not sure if it is optional.

dsasm       db ".data", NL              ; Reserves the entire data segment.
            db "bfmemory db 0FFFFh dup (0)", NL, NL, Z

csasm       db ".code", NL              ; Generated at start of code.
            db "bfstart:", NL
            db "    mov ax, @data", NL
            db "    mov ds, ax", NL
            db "    mov bx, offset bfmemory", NL, Z

csendasm    db "bfend:", NL             ; Generated at end of code.
            db "    mov ax, 4C00h", NL  ; Exits to DOS successfully.
            db "    int 21h", NL        ; (ah = 4C: exit)
            db "end bfstart", NL, Z     ; Sets the program's start label.

;--------------------------------------------------------------------------
;   Instruction assembly templates
;--------------------------------------------------------------------------
nextasm     db "    inc bx", NL, Z      ; Generated for >
prevasm     db "    dec bx", NL, Z      ; Generated for <

incasm      db "    inc byte ptr [bx]", NL, Z   ; Generated for +
decasm      db "    dec byte ptr [bx]", NL, Z   ; Generated for -


skipasm1    db "    cmp byte ptr [bx], 0", NL   ; Generated for [, looks like:
            db "    je bfclose", Z              ;       cmp [byte ptr bx], 0
skipasm2    db NL                               ;       je bfclose3000
            db "bfopen", Z                      ;   bfopen3000:
skipasm3    db ":", NL, Z

skipasm     dw skipasm1, NUMBER, skipasm2, NUMBER, skipasm3, ENDMSG


loopasm1    db "    cmp byte ptr [bx], 0", NL   ; Generated for ], looks like:
            db "    jne bfopen", Z              ;       cmp [bx], 0
loopasm2    db NL                               ;       jne bfopen3000
            db "bfclose", Z                     ;   bfclose3000:
loopasm3    db ":", NL, Z

loopasm     dw loopasm1, NUMBER, loopasm2, NUMBER, loopasm3, ENDMSG


writeasm    db "    mov ah, 2", NL      ; Generated for .
            db "    mov dl, [bx]", NL
            db "    int 21h", NL, Z

readasm     db "    mov ah, 8", NL          ; Generated for ,
            db "    int 21h", NL            ; Uses "read without echo:"
            db "    mov [bx], al", NL, Z    ; "read with echo" doesn't
                                            ; work under DOSBox.

;--------------------------------------------------------------------------
;   Jump tables
;--------------------------------------------------------------------------
gentable    dw generate                 ; gentable is for generating each
            dw gennext                  ; instruction. The offsets into
            dw genprev                  ; this table correspond to the
            dw geninc                   ; IWHATEVER constants.
            dw gendec
            dw genskip
            dw genloop
            dw genwrite
            dw genread
            dw genfooter


;--------------------------------------------------------------------------
;   Main program section.
;--------------------------------------------------------------------------
            .code
;--------------------------------------------------------------------------
bfinit:     mov ax, @data               ; Establish addressability for the
            mov ds, ax                  ; data segment.

;----------------------------------------
;   Write the program headers.
;----------------------------------------
genheader:  mov ah, 9
            mov dx, offset headerasm
            int 21h
            mov ah, 9
            mov dx, offset dsasm
            int 21h
            mov ah, 9
            mov dx, offset csasm
            int 21h

;----------------------------------------
;   Call each individual character.
;   (Later this will use a jump table.)
;----------------------------------------
generate:   mov bx, 0                   ; Clear the bx register for jumps.
            call inputread              ; Load the next character into dl.
            mov bl, dl                  ; Move it into bx to use the table.

            mov bl, [insttable + bx]    ; Convert the ASCII to an ICODE.
            jmp [gentable + bx]         ; Jump to the appropriate branch.

;----------------------------------------
;   Code for program generation.
;----------------------------------------
gennext:    mov ah, 9
            mov dx, offset nextasm
            int 21h
            jmp generate

genprev:    mov ah, 9
            mov dx, offset prevasm
            int 21h
            jmp generate

geninc:     mov ah, 9
            mov dx, offset incasm
            int 21h
            jmp generate

gendec:     mov ah, 9
            mov dx, offset decasm
            int 21h
            jmp generate

genskip:    call bracketopen            ; Get this bracket's number.
            push cx                     ; Use cx as a message argument.
            push cx                     ; Twice.
            mov bx, offset skipasm      ; Load the message template.
            call outputfmt              ; Write the code.
            jmp generate

genloop:    call bracketclose           ; Get this bracket's number.
            push cx                     ; Use cx as a message argument.
            push cx                     ; Twice.
            mov bx, offset loopasm      ; Load the message template.
            call outputfmt              ; Write the code.
            jmp generate

genwrite:   mov ah, 9
            mov dx, offset writeasm
            int 21h
            jmp generate

genread:    mov ah, 9
            mov dx, offset readasm
            int 21h
            jmp generate

;----------------------------------------
;   Write the program footer.
;----------------------------------------
genfooter:  call bracketclear           ; Make sure our stack is empty.
            mov ah, 9
            mov dx, offset csendasm
            int 21h

bfexit:     mov ax, 4C00h               ; ah = 4C: exit to DOS
            int 21h                     ; Exit program with status 0 (OK).

bfexiterr:  mov ax, 4C01h               ; ah = 4C: exit to DOS
            int 21h                     ; Exit program with status 1 (error).



;--------------------------------------------------------------------------
;   Bracket stack. Holds the locations of open brackets encountered while
;   assembling.
;
;   Each stack element is a bracket number, a line number, and a column
;   number, in sequence.
;--------------------------------------------------------------------------
            .data
;--------------------------------------------------------------------------
bracketmax  equ 255                     ; The maximum bracket nesting level.
bracketmaxsp equ (bracketmax * 6)       ; The maximum bracket offset.

bracketno   equ 0                       ; Offset of bracket number in record.
bracketline equ 2                       ; Offset of line number in record.
bracketcol  equ 4                       ; Offset of column number in record.

bracketnext dw 0                        ; The number of the next bracket.
brackets    dw bracketmax dup (0, 0, 0) ; The actual bracket stack.
bracketsp   dw 0                        ; Offset to right above the top
                                        ; of the bracket stack.

;--------------------------------------------------------------------------
;   Error messages
;--------------------------------------------------------------------------
bracketlimit1 db ".ERR <Program bracket limit of 65,535"
              db " exceeded at line ", Z
bracketlimit2 db " column ", Z
bracketlimit3 db ">", NL, "END", NL, EOF, Z

bracketlimit dw bracketlimit1, NUMBER, bracketlimit2, NUMBER, bracketlimit3
             dw ENDMSG


bracketfull1 db ".ERR <Nested bracket limit of &bracketmax&"
             db " exceeded at line ", Z
bracketfull2 db " column ", Z
bracketfull3 db ">", NL, "END", NL, EOF, Z

bracketfull dw bracketfull1, NUMBER, bracketfull2, NUMBER, bracketfull3
            dw ENDMSG


bracketempty1 db ".ERR <Extra ] at line ", Z
bracketempty2 db " column ", Z
bracketempty3 db ">", NL, "END", NL, EOF, Z

bracketempty dw bracketempty1, NUMBER, bracketempty2, NUMBER, bracketempty3
             dw ENDMSG


bracketleft1 db ".ERR <Bracket at line ", Z
bracketleft2 db " column ", Z
bracketleft3 db " was never closed>", NL, "END", NL, EOF, Z

bracketleft dw bracketleft1, NUMBER, bracketleft2, NUMBER, bracketleft3
            dw ENDMSG

;--------------------------------------------------------------------------
            .code
;--------------------------------------------------------------------------
;   bracketopen subroutine:
;   Pushes a bracket onto the bracket stack.
;
;   Input:
;   None.
;
;   Output:
;   cx: The associated bracket number.
;   All other registers retain their original values.
;
;   Errors:
;   The program will terminate if the bracket stack is full.
;--------------------------------------------------------------------------
bracketopen:
            push bx                     ; bx: Bracket offset.
            push ax                     ; ax: Used temporarily for line, col.

            mov bx, [bracketsp]         ; Index the bracket stack.
            cmp bx, bracketmaxsp        ; Is the bracket stack full?
            jae bracketopen_full        ; If so, jump to the error routine.

            add [bracketnext], 1        ; Get the next bracket number.
            jc bracketopen_limit        ; Too many brackets? Error.
            mov cx, [bracketnext]       ; Load the bracket number into cx.

                                        ; Store the bracket number, line,
                                        ; and column on the bracket stack.
            mov [bx + brackets + bracketno], cx
            mov ax, [inputline]
            mov [bx + brackets + bracketline], ax
            mov ax, [inputcol]
            mov [bx + brackets + bracketcol], ax

            add [bracketsp], 6          ; Move the bracket stack up one.

            pop ax                      ; Pop ax and bx in reverse order.
            pop bx                      ; (cx stays.)
            ret                         ; Return to caller.

bracketopen_full:
            mov bx, offset bracketfull  ; Load the message into bx.
            jmp bracketerror            ; Exit with a "brackets full" error.

bracketopen_limit:
            mov bx, offset bracketlimit ; Load the message into bx.
            jmp bracketerror            ; Exit with a "too many brackets"
                                        ; error.


;--------------------------------------------------------------------------
;   bracketclose subroutine:
;   Pops a bracket from the bracket stack.
;
;   Input:
;   None.
;
;   Output:
;   cx: The associated bracket number.
;   All other registers retain their original values.
;
;   Errors:
;   The program will terminate if the bracket stack is empty.
;--------------------------------------------------------------------------
bracketclose:
            push bx                     ; bx: Bracket offset.

            cmp [bracketsp], 0          ; Did we already pop the last bracket?
            je bracketclose_empty       ; If so, jump to the error routine.

            sub [bracketsp], 6          ; Move the stack pointer down.
            mov bx, [bracketsp]         ; Index the current bracket record.
                                        ; Get the current bracket number.
            mov cx, [bx + brackets + bracketno]

            pop bx                      ; Pop bx. (cx stays.)
            ret                         ; Return to caller.

bracketclose_empty:
            mov bx, offset bracketempty ; Load the message into bx.
            jmp bracketerror            ; Exit with a "brackets empty" error.


;--------------------------------------------------------------------------
;   bracketclear subroutine:
;   Errors if the bracket step isn't empty.
;
;   Input:
;   None.
;
;   Output:
;   None. All registers retain their original values.
;
;   Errors:
;   The program will terminate if the bracket stack isn't empty.
;--------------------------------------------------------------------------
bracketclear:
            cmp [bracketsp], 0          ; Is the stack empty?
            jne bracketclear_left       ; If not, jump to the error routine.
            ret                         ; Otherwise, return to caller.

bracketclear_left:
            sub [bracketsp], 6          ; Address the last bracket on the
                                        ; stack.
            mov bx, [bracketsp]         ; We're going to exit, so who cares
                                        ; about saving registers?

            mov ax, [bx + brackets + bracketcol]
            push ax                     ; Push the column.
            mov ax, [bx + brackets + bracketline]
            push ax                     ; Push the line.
            mov bx, offset bracketleft  ; Load the message into bx.
            call outputfmt              ; Output the message.
            add sp, 4                   ; Clear out message arguments.
            jmp bfexiterr               ; Exit the program.


;--------------------------------------------------------------------------
;   bracketerror label:
;   Pushes the current column and line onto the stack, prints the error
;   message in bx, then exits the program.
;
;   Input:
;   bx: Offset of the error message. It should have two NUMBER placeholders,
;       for the line and column.
;
;   Output:
;   The program will terminate. As such, it doesn't matter what registers
;   we use here.
;--------------------------------------------------------------------------
bracketerror:
            mov ax, [inputcol]          ; Push the column and line
            push ax                     ; in reverse order from how they
            mov ax, [inputline]         ; will be displayed.
            push ax
            call outputfmt              ; Output the message.
            add sp, 4                   ; Clear out message arguments.
            jmp bfexiterr               ; Exit the program.



            end bfinit                  ; Begin execution at bfinit.
