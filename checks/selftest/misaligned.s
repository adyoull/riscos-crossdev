@ A word in byte-aligned .data, one byte in: data that would abort on a Pi
@ with alignment exceptions on (checks/check-data-align.py's selftest).
        .data
        .byte   1
        .global badword
        .type   badword, %object
        .size   badword, 4
badword:
        .word   5
        .section .note.GNU-stack,"",%progbits
