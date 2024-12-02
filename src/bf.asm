; Brainf*ck

.include "src/mos_api.inc"

.assume adl=1
.org $040000

        jp start

; memory map
tape:           .equ    $050000                  ; tape start
tapeend:        .equ    $057fff                  ; tape end

input_file:     .equ    $060000                 ; mem location of input file

; MOS header
.align 64
.db "MOS", 0, 1

        ; BC    Data Pointer
        ; DE    Input Pointer
        ; HL    scratch pointer
start:
        push af                         ; save all registers
        push bc
        push de
        push ix
        push iy
        ld (stack_ptr), sp              ; save the stack pointer

        ; display the banner
        ld hl, banner
        call print

        ; Initialise
        call clear_tape                 ; Zero out the tape memory block

        ld bc, tape                     ; Setup the tape pointer
        ld de, input_file               ; set the input pointer at start of file

next_input:
        ld a, (de)                      ; read tape into A
        cp $ff
        jp z, exit_loop                 ; We've hit $FF, end program
        cp '>'
        jp z, inc_pointer
        cp '<'
        jp z, dec_pointer
        cp '+'
        jp z, inc_value
        cp '-'
        jp z, dec_value
        cp '.'
        jp z, print_value
        cp ','
        jp z, input_value
        cp '['
        jp z, open_bracket
        cp ']'
        jp z, close_bracket

        inc de

        jp next_input

exit_loop:

        ld sp, (stack_ptr)              ; restore the stack pointer
        pop iy                          ; restore all registers
        pop ix
        pop de
        pop bc
        pop af

        ld hl, 0                        ; return code 0
        ret

;--------------------------------------------------
; brainf*ck commands
;--------------------------------------------------

;--------------------------------------------------
; > inc tape pointer
;--------------------------------------------------
inc_pointer:
        inc bc                          ; inc the tape pointer
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; < dec tape pointer
;--------------------------------------------------
dec_pointer:
        dec bc                          ; dec the tape pointer
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; + inc value at tape pointer
;--------------------------------------------------
inc_value:
        ld a, (bc)                      ; load tape value into a
        inc a                           ; inc
        ld (bc), a                      ; store back into tape
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; - dec value at tape pointer
;--------------------------------------------------
dec_value:
        ld a, (bc)                      ; load tape value into a
        dec a                           ; dec
        ld (bc), a                      ; store back into tape
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; . output content
;--------------------------------------------------
print_value:
        ld a, (bc)                      ; load tape value into a
        rst.lil $10                     ; print
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; , input content
;--------------------------------------------------
input_value:
        ld a, $00
        MOSCALL mos_getkey
        or a
        jp z, input_value               ; Ignore any zero inputs (SHIFT, CTRL)
        ld (bc), a                      ; store to tape
        inc de                          ; inc the input pointer
        jp next_input

;--------------------------------------------------
; [ start loop
;--------------------------------------------------
open_bracket:
        ld a, (bc)                      ; load tape value to a
        cp 0
        jp z, @skip_loop                ; if zero, skip till next ']'
        push de                         ; save next location on stack
        inc de
        jp next_input

@skip_loop:                             ; skip till next ']'
        inc de
        ld a, (de)
        cp ']'
        jp nz, @skip_loop
        inc de

@done_loop:
        inc de
        jp next_input

;--------------------------------------------------
; ] end loop
;--------------------------------------------------
close_bracket:
        ld a, (bc)                      ; load tape value to a
        cp 0
        jp nz, @loopback                ; non-zero - loopback to prev [
        inc de                          ; next instruction
        jp next_input

@loopback:
        pop de
        jp next_input

; Helper functions

;--------------------------------------------------
; clear_tape - sets the 'tape' memory to all zero
;--------------------------------------------------
clear_tape:
        push hl                         ; save registers
        push bc
        push de

        ld hl, tape                     ; Start of tape block
        ld (hl), $00                    ; Set tape location #0 to $00

        push hl                         ; DE = HL + 1
        pop de
        inc de

        ld bc, $007fff                  ; zero out 32k

        ldir

        pop de                          ; restore registers
        pop bc
        pop hl
        ret

;--------------------------------------------------
; print - outputs a stream of bytes pointed to by
; HL, until HL = 0
; Input: HL
;--------------------------------------------------
print:
        ld a, (hl)                      ; Get first character
        or a                            ; Is it $00?
        ret z                           ; Return on 0 terminator
        rst.lil $10                     ; Print it
        inc hl                          ; Next character
        jp print                        ; Loop back

;--------------------------------------------------
; Data storage
;--------------------------------------------------
stack_ptr:
        .dw24 $000000
banner:
        .asciz "Brainf*ck 0.1 - Phil Howlett\r\n"
