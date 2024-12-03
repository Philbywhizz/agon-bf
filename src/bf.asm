; Brainf*ck

.include "src/mos_api.inc"

.assume adl=1
.org $040000

        jp start                        ; Program entry point

; memory map
tape:           .equ    $050000         ; tape start
tapeend:        .equ    $057fff         ; tape end

input_file:     .equ    $060000         ; mem location of input file

; MOS header
.align 64
.db "MOS", 0, 1

; command line arguments data
app_name:       .asciz  "bf.bin"        ; Name of the executable (arg1)
max_args:       .equ    16              ; Max number of arguments in argv
arg_ptr:        .blkb   max_args * 3, 0 ; max 16 x 3 bytes per argument
num_args:       .db     0               ; number of arguments entered

        ; Registers used for the BF interpreter:
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

                                        ; Determine the commandline arguments
        ld ix, arg_ptr
        push ix
        call parse_params               ; Parse the arguments

        ld a, c                         ; C contains the number of arguments enters
        ld (num_args), a                ; store it
        pop ix                          ; IX: argv

        cp 2
        jp c, usage


        ld hl, (ix+3)                   ; assume filename in first parameter argv[1]
        ld de, input_file               ; where to store the file to
        ld bc, tapeend-tape             ; max file read size of the tape

        call clear_input                ; $ff out the input block
        MOSCALL mos_load                ; attempt to load the file into the input buffer

        call clear_tape                 ; Zero out the tape memory block

        or a                            ; Test for A=0
        jp nz, file_error               ; File error

        ld bc, tape                     ; Setup the tape pointer
        ld de, input_file               ; set the input pointer at start of file

next_input:
        ld a, (de)                      ; read tape into A
        cp $ff
        jp z, exit_prog                 ; We've hit $FF, end program
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

exit_prog:

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
        jr z, @skip_loop                ; if zero, skip till next ']'
        push de                         ; save next location on stack
        inc de
        jp next_input

@skip_loop:                             ; skip till next ']'
        inc de
        ld a, (de)
        cp ']'
        jr nz, @skip_loop
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
        jr nz, @loopback                ; non-zero - loopback to prev [
        inc de                          ; next instruction
        jp next_input

@loopback:
        pop de
        jp next_input

; Helper functions

;--------------------------------------------------
; clear_input - sets the 'input' memory to all $ff
;--------------------------------------------------
clear_input:
        push hl                         ; save registers
        push bc
        push de

        ld hl, input_file               ; Start of input block
        ld (hl), $ff                    ; Set input location #0 to $ff

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
; parse_params
; Parse the parameter string into a C style array
; Parameters:
; HL: Address of parameter string
; IX: Address of array pointer storage
; Returns:
;  C: Number of paramaters
;--------------------------------------------------
parse_params:
        ld bc, app_name
        ld (ix+0), bc                   ; argv[0]
        inc ix
        inc ix
        inc ix
        call skip_spaces                ; Skip HL past and leading spaces

        ld bc, 1                        ; C: argc = 1 - also clears top 16 bits in BCU
        ld b, max_args - 1              ; B: Maximum numer of arg_ptr

@parse_step2:
        push bc                         ; stack argc
        push hl                         ; start start address of token
        call get_token                  ; get the next token
        ld a, c                         ; A: length of the token in characters
        pop de                          ; Start address of token (was in HL)
        pop bc                          ; argc
        or a                            ; check for A=0 (no token found) OR at end of string
        ret z

        ld (ix+0), de                   ; Store the pointer to the token
        push hl
        pop de                          ; DE = HL
        call skip_spaces                ; and skip HL past any spaces onto the next character
        xor a
        ld (de), a                      ; zero-terminate the token
        inc ix
        inc ix
        inc ix                          ; advance to the next pointer position
        inc c                           ; Increment argc
        ld a, c                         ; check for C >= A
        cp b
        jr c, @parse_step2              ; and loop
        ret

;--------------------------------------------------
; skip_spaces
; skip the spaces in the paramater string
; Parameters:
; HL: Address of the parameter string
; Returns:
; HL: Address of the next non-space character
;  F: Z if at end of string, otherwise NZ if there are more tokens to be parsed
;--------------------------------------------------
skip_spaces:
        ld a, (hl)
        cp ' '
        ret nz
        inc hl
        jr skip_spaces

;--------------------------------------------------
; get_token
; Get the next token
; Parameters:
; HL: Address of parameter string
; Returns:
; HL: Address of first character after token
;  C: Length of token (in characters)
;--------------------------------------------------
get_token:
        ld c, 0                         ; Initialise length

@token_loop:
        ld a, (hl)                      ; Get the character from the parameter string
        or a                            ; Exit if 0 (end of parameter string in MOS)
        ret z
        cp 13                           ; Exit if CR (end of parameter string in BBC BASIC)
        ret z
        cp ' '                          ; Exit if space (end of token)
        ret z
        inc hl                          ; Advance to next character
        inc c                           ; Increment length
        jr @token_loop

;--------------------------------------------------
; file_error
; An error occured reading the input file
;--------------------------------------------------
file_error:
        ld hl, error_txt
        call print
        jp exit_prog

;--------------------------------------------------
; usage
; Simply display the usage details
;--------------------------------------------------
usage:
        ld hl, usage_txt
        call print
        jp exit_prog

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
        jr print                        ; Loop back

;--------------------------------------------------
; Data storage
;--------------------------------------------------
stack_ptr:
        .dw24 $000000
usage_txt:
        .ascii "Agon Brainf*ck interpreter v0.2 - Phil Howlett (@Philbywhizz)\r\n\r\n"
        .ascii "An esoteric programming language with only eight commands. It is\r\n"
        .ascii "designed to challenge and amuse programmers with its minimalistic and\r\n"
        .ascii "obfuscated syntax.\r\n"
        .ascii "\r\nUsage:\r\n"
        .ascii "    bf <sourcefile>\r\n\r\n"
        .db $00
error_txt:
        .ascii "Error reading file.\r\n"
        .db $00
