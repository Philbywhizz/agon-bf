; ProjectName

.assume adl=1
.org $040000

        jp start

; MOS header
.align 64
.db "MOS", 0, 1

start:
        push af
        push bc
        push de
        push ix
        push iy

        pop iy
        pop ix
        pop de
        pop bc
        pop af

        ld hl, 0
        ret
        