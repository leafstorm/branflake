;--------------------------------------------------------------------------
;
;   BFIO.INC
;
;   This is the header file for BFIO.ASM.
;
;   (C) 2013, Matthew Frazier <leafstormrush@gmail.com>
;   Released under the terms of the MIT/X11 license,
;   see the LICENSE file for details.
;
;--------------------------------------------------------------------------
;   Constant definitions
;--------------------------------------------------------------------------
CR          equ 13                      ; ASCII carriage return.
LF          equ 10                      ; ASCII line feed.
NL          equ CR, LF                  ; DOS newline sequence.
EOF         equ 1Ah                     ; DOS end of file.
Z           equ '$'                     ; DOS end of string. "Z" for "zero."

NUMBER      equ 0FFFEh                  ; Used by outputfmt to know when
                                        ; to write a number.
ENDMSG      equ 0FFFFh                  ; Used by outputfmt to know when
                                        ; to stop writing.

;--------------------------------------------------------------------------
;   Input routines and variables
;--------------------------------------------------------------------------
            externdef inputchar:word
            externdef inputline:word
            externdef inputcol:word

            externdef inputread:proc

;--------------------------------------------------------------------------
;   Output routines and variables
;--------------------------------------------------------------------------
            externdef outputfmt:proc
            externdef outputdec:proc
