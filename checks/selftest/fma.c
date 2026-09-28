/* checks/selftest: with -mfpu=vfpv4 GCC uses a fused multiply-add here,
   which check-fpu.sh must report (VFPv3 machines don't have it). */
float madd (float a, float b, float c) { return a * b + c; }
