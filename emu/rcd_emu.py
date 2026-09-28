"""Run RISC OS machine code (module code, assembler routines) in the Unicorn
ARM emulator, with the SWIs it calls faked in Python.

    from rcd_emu import Machine, load_object
    code, syms = load_object("out/routine.o")      # .text and its symbols
    m = Machine()
    m.load(0x10000, code)
    m.on_swi(0x42, lambda m, r: r.__setitem__(0, 1234))   # OS_ReadMonotonicTime
    regs, cpsr = m.call(0x10000 + syms["my_routine"], r0=5)

Needs the Python module unicorn (pip install unicorn) and the cross
toolchain's nm/objcopy ($RISCOS_TOOLCHAIN). Based on riscos-unixlib's
tests/emu/ticker_test.py.

The memory map is small and flat: code wherever you load it, a stack below
STACK, and a bump allocator for RMA claims (OS_Module 6) from RMA.
"""
import os
import subprocess
import tempfile

from unicorn import Uc, UcError, UC_ARCH_ARM, UC_MODE_ARM, UC_HOOK_INTR
from unicorn import arm_const as A

REGS = [A.UC_ARM_REG_R0, A.UC_ARM_REG_R1, A.UC_ARM_REG_R2, A.UC_ARM_REG_R3,
        A.UC_ARM_REG_R4, A.UC_ARM_REG_R5, A.UC_ARM_REG_R6, A.UC_ARM_REG_R7,
        A.UC_ARM_REG_R8, A.UC_ARM_REG_R9, A.UC_ARM_REG_R10, A.UC_ARM_REG_R11,
        A.UC_ARM_REG_R12]
NFLAG, ZFLAG, CFLAG, VFLAG = 1 << 31, 1 << 30, 1 << 29, 1 << 28
XBIT = 0x20000

RET = 0xFFF0        # return address: emulation stops there
RAM_SIZE = 0x200000
RMA = 0x100000      # OS_Module 6 claims come from here
STACK = 0x0F0000    # full descending, grows down from here
ERRORS = 0x1F0000   # error blocks returned by fake SWIs

TOOL = os.path.join(os.environ.get("RISCOS_TOOLCHAIN", os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "toolchain", "env")),
    "bin", "arm-riscos-gnueabihf-")


def load_object(obj):
    """(bytes of .text, {function symbol: offset in .text}) of an object file."""
    out = subprocess.run([TOOL + "nm", obj], check=True, capture_output=True,
                         text=True).stdout
    syms = {}
    for line in out.splitlines():
        parts = line.split()
        if len(parts) == 3 and parts[1] in "tT":
            syms[parts[2]] = int(parts[0], 16)
    with tempfile.NamedTemporaryFile() as f:
        subprocess.run([TOOL + "objcopy", "-O", "binary", "-j", ".text", obj, f.name],
                       check=True)
        return open(f.name, "rb").read(), syms


class Machine:
    def __init__(self):
        self.mu = Uc(UC_ARCH_ARM, UC_MODE_ARM)
        self.mu.mem_map(0, RAM_SIZE)
        self.mu.mem_write(RET, b"\xfe\xff\xff\xea")       # B .
        self.handlers = {}
        self.swis = []          # (number without X bit, [r0..r9]) per call
        self.alloc = RMA
        self.errors = ERRORS
        self.mu.hook_add(UC_HOOK_INTR, self._swi)

    # -- memory
    def load(self, addr, data):
        self.mu.mem_write(addr, bytes(data))

    def w(self, addr, val):
        self.mu.mem_write(addr, (val & 0xFFFFFFFF).to_bytes(4, "little"))

    def r(self, addr):
        return int.from_bytes(self.mu.mem_read(addr, 4), "little")

    def string(self, addr, limit=256):
        b = bytes(self.mu.mem_read(addr, limit))
        return b.split(b"\0", 1)[0].decode("latin-1")

    def claim(self, size, fill=b"\xaa"):
        """RMA-style block, garbage-filled so fields left unset show up."""
        addr = self.alloc
        self.mu.mem_write(addr, fill * size)
        self.alloc += (size + 15) & ~15
        return addr

    def error(self, num, msg):
        """An error block in memory, for a SWI handler to return."""
        addr = self.errors
        self.w(addr, num)
        self.mu.mem_write(addr + 4, msg.encode("latin-1") + b"\0")
        self.errors += (4 + len(msg) + 1 + 3) & ~3
        return addr

    # -- SWIs
    def on_swi(self, number, fn):
        """fn(machine, r) with r = [r0..r9], a list it may change. Return
        None, or an error block address (see error()) to set V and R0."""
        self.handlers[number & ~XBIT] = fn

    def _swi(self, mu, intno, _):
        pc = mu.reg_read(A.UC_ARM_REG_PC)
        num = int.from_bytes(mu.mem_read(pc - 4, 4), "little") & 0xFFFFFF
        r = [mu.reg_read(x) for x in REGS[:10]]
        self.swis.append((num & ~XBIT, list(r)))
        cpsr = mu.reg_read(A.UC_ARM_REG_CPSR) & ~VFLAG
        fn = self.handlers.get(num & ~XBIT)
        if fn is None and (num & ~XBIT) == 0x1E and r[0] == 6:     # OS_Module claim
            r[2] = self.claim(r[3])
            err = None
        elif fn is None:
            mu.emu_stop()
            raise RuntimeError("unexpected SWI &%X at &%X" % (num, pc - 4))
        else:
            err = fn(self, r)
        if err is not None:
            if not num & XBIT:
                mu.emu_stop()
                raise RuntimeError("error from non-X SWI &%X: %s" % (num, self.string(err + 4)))
            r[0] = err
            cpsr |= VFLAG
        for x, v in zip(REGS[:10], r):
            mu.reg_write(x, v & 0xFFFFFFFF)
        mu.reg_write(A.UC_ARM_REG_CPSR, cpsr)

    def called(self, number):
        return [r for n, r in self.swis if n == number & ~XBIT]

    # -- running code
    def call(self, addr, flags=0, max_insns=100000, **regs):
        """Call addr (lr = RET, sp = STACK) with registers r0=..r12=.
        Returns ([r0..r12], cpsr). Raises if the code doesn't return."""
        self.swis = []
        mu = self.mu
        for i, x in enumerate(REGS):
            mu.reg_write(x, regs.get("r%d" % i, 0x11110000 + i))
        mu.reg_write(A.UC_ARM_REG_SP, STACK)
        mu.reg_write(A.UC_ARM_REG_LR, RET)
        cpsr = (mu.reg_read(A.UC_ARM_REG_CPSR) & 0x0FFFFFFF) | flags
        mu.reg_write(A.UC_ARM_REG_CPSR, cpsr)
        mu.emu_start(addr, RET, count=max_insns)
        pc = mu.reg_read(A.UC_ARM_REG_PC)
        if pc != RET:
            raise RuntimeError("routine at &%X didn't return (pc &%X)" % (addr, pc))
        if mu.reg_read(A.UC_ARM_REG_SP) != STACK:
            raise RuntimeError("routine at &%X left the stack unbalanced" % addr)
        return [mu.reg_read(x) for x in REGS], mu.reg_read(A.UC_ARM_REG_CPSR)


class Checks:
    """check(cond, what) counting, like the C tests."""
    def __init__(self, name):
        self.name, self.n, self.fails = name, 0, 0

    def __call__(self, cond, what):
        self.n += 1
        if not cond:
            self.fails += 1
            print("FAIL:", what)

    def done(self):
        print("%s: %d checks, %d failed" % (self.name, self.n, self.fails))
        return 1 if self.fails else 0
