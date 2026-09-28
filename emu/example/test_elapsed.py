#!/usr/bin/env python3
"""Run emu/example/elapsed.s in the Unicorn emulator with a fake
OS_ReadMonotonicTime: the result, the error path, preserved registers.
   emu/example/test_elapsed.py OBJECT.o"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from rcd_emu import Machine, Checks, load_object, VFLAG  # noqa: E402

OS_ReadMonotonicTime = 0x42
check = Checks("emu example (elapsed.s)")
code, syms = load_object(sys.argv[1])
m = Machine()
BASE = 0x8000
m.load(BASE, code)
entry = BASE + syms["elapsed"]

now = [5000]
m.on_swi(OS_ReadMonotonicTime, lambda mach, r: r.__setitem__(0, now[0]))
regs, cpsr = m.call(entry, r0=1200, r4=0x4444, r7=0x7777)
check(regs[0] == 3800, "5000 - 1200 = 3800")
check(not cpsr & VFLAG, "V clear on success")
check(regs[4] == 0x4444 and regs[7] == 0x7777, "R4 and R7 preserved")
check(len(m.called(OS_ReadMonotonicTime)) == 1, "one SWI call")

now[0] = 10
regs, cpsr = m.call(entry, r0=0xFFFFFFF0)
check(regs[0] == 26, "the monotonic clock wrapping round")

err = m.error(0x1E6, "Clock stopped")
m.on_swi(OS_ReadMonotonicTime, lambda mach, r: err)
regs, cpsr = m.call(entry, r0=0, r4=0x4444)
check(cpsr & VFLAG, "V set on an error")
check(regs[0] == err and m.string(regs[0] + 4) == "Clock stopped", "R0 = the error block")
check(regs[4] == 0x4444, "R4 restored on the error path")
sys.exit(check.done())
