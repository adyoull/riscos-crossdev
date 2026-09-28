@ An assembler routine in the style of module code, for emu/example/test_elapsed.py.
@
@ elapsed: In:  R0 = an earlier OS_ReadMonotonicTime value
@          Out: R0 = centiseconds since then, V clear
@               or R0 = error block, V set (from XOS_ReadMonotonicTime)
@          R1-R12 preserved.

	.text
	.arm
	.global	elapsed
elapsed:
	stmfd	sp!, {r4, lr}
	mov	r4, r0
	swi	0x20042			@ XOS_ReadMonotonicTime
	ldmvsfd	sp!, {r4, pc}		@ error: return it with V set
	sub	r0, r0, r4
	ldmfd	sp!, {r4, pc}
