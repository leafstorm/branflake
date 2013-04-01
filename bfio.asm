;--------------------------------------------------------------------------
;
;   BFIO.ASM
;
;   This file contains subroutines integrated into BFTRANS for input and
;   output.
;
;   (C) 2013, Matthew Frazier <leafstormrush@gmail.com>
;   Released under the terms of the MIT/X11 license,
;   see the LICENSE file for details.
;
;--------------------------------------------------------------------------

            .model    small             ; 64K data, 64K code.
            .8086                       ; 8086 instructions only.
            include bfio.inc            ; Header with constant definitions.

;--------------------------------------------------------------------------
;   INPUT STREAM INFORMATION:
;   These variables are globally accessible.
;--------------------------------------------------------------------------
            .data
;--------------------------------------------------------------------------
inputchar   dw 0                        ; Absolute location of the last
                                        ; character read. Works for up to 64K.
inputline   dw 1                        ; Line number of last character read.
inputcol    dw 0                        ; Column number of last character read.


;--------------------------------------------------------------------------
;   inputread subroutine:
;   Reads the next character from standard input, and updates the
;   position variables.
;
;   Input:
;   None.
;
;   Output:
;   The character read is stored in the dl register.
;   All other registers retain their original values.
;--------------------------------------------------------------------------
            .code
;--------------------------------------------------------------------------
inputread:
            push ax                     ; Save ax on the stack.
            mov ah, 8                   ; ah = 8: read character to al.
            int 21h                     ; Invoke DOS to read the character.
            mov dl, al                  ; Move the character to dl.

            inc [inputchar]             ; Update the character counter.
            inc [inputcol]              ; Update the column counter.

            cmp dl, LF                  ; Was the character a linefeed?
            jne inputread_end           ; Skip to the end if not.
            inc [inputline]             ; Increment the line counter.
            mov [inputcol], 1           ; Reset the column counter.

inputread_end:
            pop ax                      ; Restore old value of ax.
            ret                         ; Return to caller.


;--------------------------------------------------------------------------
;   outputfmt subroutine:
;   Writes a series of strings and numbers to standard output.
;
;   Input:
;   bx: The offset to a message pattern. This is a list of words.
;       - ENDMSG means "stop here."
;       - NUMBER means "read the next number from the stack."
;         (Note that this won't actually affect the stack - you'll need to
;         clean up the stack after this subroutine returns.)
;       - Anything else means "print the $-terminated string at this offset."
;
;   Output:
;   None. All registers retain their original values.
;
;   Errors:
;   No error checking is done, so weird stuff will happen if invalid data
;   is provided.
;--------------------------------------------------------------------------
outputfmt:
            push bp                     ; bp: Stack pointer.
            mov bp, sp                  ; Make the stack addressable.
            add bp, 2                   ; Skip the bp we just pushed.
            push dx                     ; dx: Offset to message.
            push bx                     ; bx: Current item in output list.
            push ax                     ; ax: Overwritten a lot.

            jmp outputfmt_choose        ; Start out working with bx.

outputfmt_next:
            add bx, 2                   ; Move to the next word in bx.

outputfmt_choose:                       ; Handle the next item in bx.
            mov dx, [bx]                ; Load the next message item.
            cmp dx, ENDMSG              ; Is this the end of the message?
            je outputfmt_exit           ; If so, return to caller.
            cmp dx, NUMBER              ; Do we need to print a number?
            je outputfmt_number         ; If so, handle that case.

outputfmt_string:                       ; Otherwise, we just print a string.
            mov ah, 9                   ; ah = 2: output $-terminated string.
            int 21h                     ; Invoke DOS to write it out.
            jmp outputfmt_next          ; Jump back to the top.

outputfmt_number:
            add bp, 2                   ; Move to the next number on stack.
                                        ; (On the first loop, this will skip
                                        ; the return address.)
            mov ax, [bp]                ; Load it into ax for outputdec.
            call outputdec              ; Use outputdec to actually write it.
            jmp outputfmt_next          ; Jump back to the top.

outputfmt_exit:
            pop ax                      ; Pop ax, bx, dx, and bp in
            pop bx                      ; reverse order.
            pop dx
            pop bp
            ret                         ; Return to caller.


;--------------------------------------------------------------------------
;   outputdec subroutine:
;   Writes an unsigned word to standard output, in decimal format.
;
;   Input:
;   ax: The unsigned word to write.
;
;   Output:
;   None. All registers retain their original values.
;--------------------------------------------------------------------------
            .data
;--------------------------------------------------------------------------
outputdec_base dw 10                    ; The base to divide by.
;--------------------------------------------------------------------------
            .code
;--------------------------------------------------------------------------
outputdec:
            push dx                     ; dx: Divisor, and character to write.
            push cx                     ; cx: Number of digits to write.
            push ax                     ; ax: Quotient.
            mov cx, 1                   ; Initialize the counter.

outputdec_divloop:
            cmp ax, 10                  ; Are we on the last digit?
            jb outputdec_write          ; If so, skip to the write loop.

            mov dx, 0                   ; Set dx to 0 to prevent overflow.
            div [outputdec_base]        ; Divide ax by 10.
            push dx                     ; Store the remainder on the stack.
                                        ; We'll pop it when writing.
            inc cx                      ; Increase the digit counter.
            jmp outputdec_divloop       ; Process the quotient.

outputdec_write:
            push ax                     ; Push the last digit on the stack.
                                        ; This is slightly wasteful, but
                                        ; it makes the logic cleaner.
outputdec_writeloop:
            pop dx                      ; Pop the next digit to write.
            add dl, 30h                 ; Bring it to the correct range
                                        ; for ASCII digits.
            mov ah, 2                   ; ah = 2: write character in dl.
            int 21h                     ; Invoke DOS to write it out.
            loop outputdec_writeloop    ; Loop until all digits are written.

outputdec_exit:
            pop ax                      ; Pop ax, cx, and dx in reverse order.
            pop cx
            pop dx
            ret                         ; Return to caller.

            end
