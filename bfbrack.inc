;--------------------------------------------------------------------------
;
;   BFBRACK.INC
;
;   This contains the sections of BFTRANS that deal with the bracket stack.
;   (This is enough code that I feel it justifies its own file.)
;
;   The bracket stack is a stack that keeps track of how many brackets have
;   been encountered so far while assembling the code.
;
;   (C) 2013, Matthew Frazier <leafstormrush@gmail.com>
;   Released under the terms of the MIT/X11 license,
;   see the LICENSE file for details.
;
;--------------------------------------------------------------------------
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
bracketlimit1 db "Program bracket limit of 65,535 exceeded at line ", Z
bracketlimit2 db " column ", Z

bracketlimit dw errstartasm, bracketlimit1, NUMBER, bracketlimit2, NUMBER
             dw errendasm, ENDMSG


bracketfull1 db "Nested bracket limit of &bracketmax& exceeded at line ", Z
bracketfull2 db " column ", Z

bracketfull dw errstartasm, bracketfull1, NUMBER, bracketfull2, NUMBER
            dw errendasm, ENDMSG


bracketempty1 db "Extra ] at line ", Z
bracketempty2 db " column ", Z

bracketempty dw errstartasm, bracketempty1, NUMBER, bracketempty2, NUMBER
             dw errendasm, ENDMSG


bracketleft1 db "Bracket at line ", Z
bracketleft2 db " column ", Z
bracketleft3 db " was never closed", Z

bracketleft dw errstartasm, bracketleft1, NUMBER, bracketleft2, NUMBER
            dw bracketleft3, errendasm, ENDMSG

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

