savedcmd_.module-common.o := aarch64-linux-gnu-gcc -Wp,-MMD,./..module-common.o.d -nostdinc -I~/tecno_ke7_linux_port/linux/arch/arm64/include -I~/tecno_ke7_linux_port/linux/arch/arm64/include/generated -I~/tecno_ke7_linux_port/linux/include -I~/tecno_ke7_linux_port/linux/include -I~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi -I~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi -I~/tecno_ke7_linux_port/linux/include/uapi -I~/tecno_ke7_linux_port/linux/include/generated/uapi -include ~/tecno_ke7_linux_port/linux/include/linux/compiler-version.h -include ~/tecno_ke7_linux_port/linux/include/linux/kconfig.h -include ~/tecno_ke7_linux_port/linux/include/linux/compiler_types.h -D__KERNEL__ -mlittle-endian -DKASAN_SHADOW_SCALE_SHIFT= -std=gnu11 -fshort-wchar -funsigned-char -fno-common -fno-PIE -fno-strict-aliasing -mgeneral-regs-only -DCONFIG_CC_HAS_K_CONSTRAINT=1 -Wno-psabi -mabi=lp64 -fno-asynchronous-unwind-tables -fno-unwind-tables -mbranch-protection=none -Wa,-march=armv8.5-a -DARM64_ASM_ARCH='"armv8.5-a"' -DKASAN_SHADOW_SCALE_SHIFT= -fno-delete-null-pointer-checks -O2 -fno-allow-store-data-races -fstack-protector-strong -fno-omit-frame-pointer -fno-optimize-sibling-calls -ftrivial-auto-var-init=zero -fzero-init-padding-bits=all -fno-stack-clash-protection -fmin-function-alignment=4 -fstrict-flex-arrays=3 -fno-strict-overflow -fno-stack-check -fconserve-stack -fno-builtin-wcslen -Wall -Wextra -Wundef -Werror=implicit-function-declaration -Werror=implicit-int -Werror=return-type -Werror=strict-prototypes -Wno-format-security -Wno-trigraphs -Wno-frame-address -Wno-address-of-packed-member -Wmissing-declarations -Wmissing-prototypes -Wframe-larger-than=2048 -Wno-main -Wno-dangling-pointer -Wvla-larger-than=1 -Wno-pointer-sign -Wcast-function-type -Wno-unterminated-string-initialization -Wno-array-bounds -Wno-stringop-overflow -Wno-alloc-size-larger-than -Wimplicit-fallthrough=5 -Werror=date-time -Werror=incompatible-pointer-types -Werror=designated-init -Wenum-conversion -Wunused -Wno-unused-but-set-variable -Wno-unused-const-variable -Wno-packed-not-aligned -Wno-format-overflow -Wno-format-truncation -Wno-stringop-truncation -Wno-override-init -Wno-missing-field-initializers -Wno-type-limits -Wno-shift-negative-value -Wno-maybe-uninitialized -Wno-sign-compare -Wno-unused-parameter -g -gdwarf-5 -fno-var-tracking -femit-struct-debug-baseonly -gz=zstd -DGCC_PLUGINS -mstack-protector-guard=sysreg -mstack-protector-guard-reg=sp_el0 -mstack-protector-guard-offset=1184  -DMODULE  -DKBUILD_BASENAME='".module_common"' -DKBUILD_MODNAME='".module_common.o"' -D__KBUILD_MODNAME=kmod_.module_common.o -c -o .module-common.o ~/tecno_ke7_linux_port/linux/scripts/module-common.c  

source_.module-common.o := ~/tecno_ke7_linux_port/linux/scripts/module-common.c

deps_.module-common.o := \
    $(wildcard include/config/UNWINDER_ORC) \
    $(wildcard include/config/MITIGATION_RETPOLINE) \
  ~/tecno_ke7_linux_port/linux/include/linux/compiler-version.h \
    $(wildcard include/config/CC_VERSION_TEXT) \
  ~/tecno_ke7_linux_port/linux/include/generated/gcc-plugins.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kconfig.h \
    $(wildcard include/config/CPU_BIG_ENDIAN) \
    $(wildcard include/config/BOOGER) \
    $(wildcard include/config/FOO) \
  ~/tecno_ke7_linux_port/linux/include/linux/compiler_types.h \
    $(wildcard include/config/DEBUG_INFO_BTF) \
    $(wildcard include/config/PAHOLE_HAS_BTF_TAG) \
    $(wildcard include/config/FUNCTION_ALIGNMENT) \
    $(wildcard include/config/CC_HAS_SANE_FUNCTION_ALIGNMENT) \
    $(wildcard include/config/X86_64) \
    $(wildcard include/config/ARM64) \
    $(wildcard include/config/LD_DEAD_CODE_DATA_ELIMINATION) \
    $(wildcard include/config/LTO_CLANG) \
    $(wildcard include/config/HAVE_ARCH_COMPILER_H) \
    $(wildcard include/config/CC_HAS_ASSUME) \
    $(wildcard include/config/CC_HAS_COUNTED_BY) \
    $(wildcard include/config/CC_HAS_MULTIDIMENSIONAL_NONSTRING) \
    $(wildcard include/config/UBSAN_INTEGER_WRAP) \
    $(wildcard include/config/CFI) \
    $(wildcard include/config/ARCH_USES_CFI_GENERIC_LLVM_PASS) \
    $(wildcard include/config/CC_HAS_ASM_INLINE) \
  ~/tecno_ke7_linux_port/linux/include/linux/compiler_attributes.h \
  ~/tecno_ke7_linux_port/linux/include/linux/compiler-gcc.h \
    $(wildcard include/config/ARCH_USE_BUILTIN_BSWAP) \
    $(wildcard include/config/SHADOW_CALL_STACK) \
    $(wildcard include/config/KCOV) \
    $(wildcard include/config/CC_HAS_TYPEOF_UNQUAL) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/compiler.h \
    $(wildcard include/config/ARM64_PTR_AUTH_KERNEL) \
    $(wildcard include/config/ARM64_PTR_AUTH) \
    $(wildcard include/config/BUILTIN_RETURN_ADDRESS_STRIPS_PAC) \
  ~/tecno_ke7_linux_port/linux/include/linux/module.h \
    $(wildcard include/config/MODULES) \
    $(wildcard include/config/SYSFS) \
    $(wildcard include/config/MODULES_TREE_LOOKUP) \
    $(wildcard include/config/LIVEPATCH) \
    $(wildcard include/config/STACKTRACE_BUILD_ID) \
    $(wildcard include/config/ARCH_USES_CFI_TRAPS) \
    $(wildcard include/config/MODULE_SIG) \
    $(wildcard include/config/GENERIC_BUG) \
    $(wildcard include/config/KALLSYMS) \
    $(wildcard include/config/SMP) \
    $(wildcard include/config/TRACEPOINTS) \
    $(wildcard include/config/TREE_SRCU) \
    $(wildcard include/config/BPF_EVENTS) \
    $(wildcard include/config/DEBUG_INFO_BTF_MODULES) \
    $(wildcard include/config/JUMP_LABEL) \
    $(wildcard include/config/TRACING) \
    $(wildcard include/config/EVENT_TRACING) \
    $(wildcard include/config/DYNAMIC_FTRACE) \
    $(wildcard include/config/KPROBES) \
    $(wildcard include/config/HAVE_STATIC_CALL_INLINE) \
    $(wildcard include/config/KUNIT) \
    $(wildcard include/config/PRINTK_INDEX) \
    $(wildcard include/config/MODULE_UNLOAD) \
    $(wildcard include/config/CONSTRUCTORS) \
    $(wildcard include/config/FUNCTION_ERROR_INJECTION) \
    $(wildcard include/config/DYNAMIC_DEBUG_CORE) \
  ~/tecno_ke7_linux_port/linux/include/linux/list.h \
    $(wildcard include/config/LIST_HARDENED) \
    $(wildcard include/config/DEBUG_LIST) \
  ~/tecno_ke7_linux_port/linux/include/linux/container_of.h \
  ~/tecno_ke7_linux_port/linux/include/linux/build_bug.h \
  ~/tecno_ke7_linux_port/linux/include/linux/compiler.h \
    $(wildcard include/config/TRACE_BRANCH_PROFILING) \
    $(wildcard include/config/PROFILE_ALL_BRANCHES) \
    $(wildcard include/config/OBJTOOL) \
    $(wildcard include/config/64BIT) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/rwonce.h \
    $(wildcard include/config/LTO) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/rwonce.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kasan-checks.h \
    $(wildcard include/config/KASAN_GENERIC) \
    $(wildcard include/config/KASAN_SW_TAGS) \
  ~/tecno_ke7_linux_port/linux/include/linux/types.h \
    $(wildcard include/config/HAVE_UID16) \
    $(wildcard include/config/UID16) \
    $(wildcard include/config/ARCH_DMA_ADDR_T_64BIT) \
    $(wildcard include/config/PHYS_ADDR_T_64BIT) \
    $(wildcard include/config/ARCH_32BIT_USTAT_F_TINODE) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/types.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/types.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/types.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/int-ll64.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/int-ll64.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/bitsperlong.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitsperlong.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/bitsperlong.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/posix_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/stddef.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/stddef.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/posix_types.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/posix_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kcsan-checks.h \
    $(wildcard include/config/KCSAN) \
    $(wildcard include/config/KCSAN_WEAK_MEMORY) \
    $(wildcard include/config/KCSAN_IGNORE_ATOMICS) \
  ~/tecno_ke7_linux_port/linux/include/linux/poison.h \
    $(wildcard include/config/ILLEGAL_POINTER_VALUE) \
  ~/tecno_ke7_linux_port/linux/include/linux/const.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/const.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/const.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/barrier.h \
    $(wildcard include/config/ARM64_PSEUDO_NMI) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/alternative-macros.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/bits.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/cpucaps.h \
    $(wildcard include/config/ARM64_PAN) \
    $(wildcard include/config/ARM64_EPAN) \
    $(wildcard include/config/ARM64_SVE) \
    $(wildcard include/config/ARM64_SME) \
    $(wildcard include/config/ARM64_CNP) \
    $(wildcard include/config/ARM64_MTE) \
    $(wildcard include/config/ARM64_BTI) \
    $(wildcard include/config/ARM64_TLB_RANGE) \
    $(wildcard include/config/ARM64_POE) \
    $(wildcard include/config/ARM64_GCS) \
    $(wildcard include/config/ARM64_HAFT) \
    $(wildcard include/config/UNMAP_KERNEL_AT_EL0) \
    $(wildcard include/config/ARM64_ERRATUM_843419) \
    $(wildcard include/config/ARM64_ERRATUM_1742098) \
    $(wildcard include/config/ARM64_ERRATUM_2645198) \
    $(wildcard include/config/ARM64_ERRATUM_2658417) \
    $(wildcard include/config/CAVIUM_ERRATUM_23154) \
    $(wildcard include/config/NVIDIA_CARMEL_CNP_ERRATUM) \
    $(wildcard include/config/ARM64_WORKAROUND_REPEAT_TLBI) \
    $(wildcard include/config/ARM64_ERRATUM_3194386) \
    $(wildcard include/config/HW_PERF_EVENTS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/cpucap-defs.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/insn-def.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/brk-imm.h \
  ~/tecno_ke7_linux_port/linux/include/linux/stringify.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/barrier.h \
  ~/tecno_ke7_linux_port/linux/include/linux/stat.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/stat.h \
    $(wildcard include/config/COMPAT) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/stat.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/stat.h \
  ~/tecno_ke7_linux_port/linux/include/linux/time.h \
    $(wildcard include/config/POSIX_TIMERS) \
  ~/tecno_ke7_linux_port/linux/include/linux/cache.h \
    $(wildcard include/config/ARCH_HAS_CACHE_LINE_SIZE) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/kernel.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/sysinfo.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/cache.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/cache.h \
    $(wildcard include/config/KASAN_HW_TAGS) \
  ~/tecno_ke7_linux_port/linux/include/linux/bitops.h \
  ~/tecno_ke7_linux_port/linux/include/linux/bits.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/bits.h \
  ~/tecno_ke7_linux_port/linux/include/linux/overflow.h \
  ~/tecno_ke7_linux_port/linux/include/linux/limits.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/limits.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/limits.h \
  ~/tecno_ke7_linux_port/linux/include/linux/typecheck.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/generic-non-atomic.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/bitops.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/builtin-__ffs.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/builtin-ffs.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/builtin-__fls.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/builtin-fls.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/ffz.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/fls64.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/sched.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/hweight.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/arch_hweight.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/const_hweight.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/atomic.h \
  ~/tecno_ke7_linux_port/linux/include/linux/atomic.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/atomic.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/cmpxchg.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/lse.h \
    $(wildcard include/config/ARM64_LSE_ATOMICS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/atomic_ll_sc.h \
    $(wildcard include/config/CC_HAS_K_CONSTRAINT) \
  ~/tecno_ke7_linux_port/linux/include/linux/export.h \
    $(wildcard include/config/MODVERSIONS) \
    $(wildcard include/config/GENDWARFKSYMS) \
  ~/tecno_ke7_linux_port/linux/include/linux/linkage.h \
    $(wildcard include/config/ARCH_USE_SYM_ANNOTATIONS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/linkage.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/alternative.h \
  ~/tecno_ke7_linux_port/linux/include/linux/init.h \
    $(wildcard include/config/MEMORY_HOTPLUG) \
    $(wildcard include/config/HAVE_ARCH_PREL32_RELOCATIONS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/atomic_lse.h \
  ~/tecno_ke7_linux_port/linux/include/linux/atomic/atomic-arch-fallback.h \
    $(wildcard include/config/GENERIC_ATOMIC64) \
  ~/tecno_ke7_linux_port/linux/include/linux/atomic/atomic-long.h \
  ~/tecno_ke7_linux_port/linux/include/linux/atomic/atomic-instrumented.h \
  ~/tecno_ke7_linux_port/linux/include/linux/instrumented.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kmsan-checks.h \
    $(wildcard include/config/KMSAN) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/instrumented-atomic.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/lock.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/instrumented-lock.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/non-atomic.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/non-instrumented-non-atomic.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/le.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/byteorder.h \
  ~/tecno_ke7_linux_port/linux/include/linux/byteorder/little_endian.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/byteorder/little_endian.h \
  ~/tecno_ke7_linux_port/linux/include/linux/swab.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/swab.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/swab.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/swab.h \
  ~/tecno_ke7_linux_port/linux/include/linux/byteorder/generic.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bitops/ext2-atomic-setbit.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kasan-enabled.h \
    $(wildcard include/config/ARCH_DEFER_KASAN) \
    $(wildcard include/config/KASAN) \
  ~/tecno_ke7_linux_port/linux/include/linux/static_key.h \
  ~/tecno_ke7_linux_port/linux/include/linux/jump_label.h \
    $(wildcard include/config/HAVE_ARCH_JUMP_LABEL_RELATIVE) \
  ~/tecno_ke7_linux_port/linux/include/linux/cleanup.h \
  ~/tecno_ke7_linux_port/linux/include/linux/err.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/errno.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/errno.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/errno-base.h \
  ~/tecno_ke7_linux_port/linux/include/linux/args.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/jump_label.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/insn.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/cputype.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/sysreg.h \
    $(wildcard include/config/BROKEN_GAS_INST) \
    $(wildcard include/config/ARM64_PA_BITS_52) \
    $(wildcard include/config/ARM64_4K_PAGES) \
    $(wildcard include/config/ARM64_16K_PAGES) \
    $(wildcard include/config/ARM64_64K_PAGES) \
    $(wildcard include/config/AMPERE_ERRATUM_AC04_CPU_23) \
  ~/tecno_ke7_linux_port/linux/include/linux/kasan-tags.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/gpr-num.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/sysreg-defs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/bitfield.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/mte-def.h \
  ~/tecno_ke7_linux_port/linux/include/linux/math64.h \
    $(wildcard include/config/ARCH_SUPPORTS_INT128) \
  ~/tecno_ke7_linux_port/linux/include/linux/math.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/div64.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/div64.h \
    $(wildcard include/config/CC_OPTIMIZE_FOR_PERFORMANCE) \
  ~/tecno_ke7_linux_port/linux/include/vdso/math64.h \
  ~/tecno_ke7_linux_port/linux/include/linux/time64.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/time64.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/time.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/time_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/time32.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timex.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/timex.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/param.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/param.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/param.h \
    $(wildcard include/config/HZ) \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/param.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/timex.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/arch_timer.h \
    $(wildcard include/config/ARM_ARCH_TIMER_OOL_WORKAROUND) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/hwcap.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/hwcap.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/cpufeature.h \
    $(wildcard include/config/ARM64_SW_TTBR0_PAN) \
    $(wildcard include/config/ARM64_DEBUG_PRIORITY_MASKING) \
    $(wildcard include/config/ARM64_BTI_KERNEL) \
    $(wildcard include/config/ARM64_PA_BITS) \
    $(wildcard include/config/ARM64_HW_AFDBM) \
    $(wildcard include/config/ARM64_AMU_EXTN) \
    $(wildcard include/config/ARM64_LPA2) \
  ~/tecno_ke7_linux_port/linux/include/linux/bug.h \
    $(wildcard include/config/PRINTK) \
    $(wildcard include/config/BUG_ON_DATA_CORRUPTION) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/bug.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/asm-bug.h \
    $(wildcard include/config/DEBUG_BUGVERBOSE) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/bug.h \
    $(wildcard include/config/BUG) \
    $(wildcard include/config/GENERIC_BUG_RELATIVE_POINTERS) \
  ~/tecno_ke7_linux_port/linux/include/linux/instrumentation.h \
    $(wildcard include/config/NOINSTR_VALIDATION) \
  ~/tecno_ke7_linux_port/linux/include/linux/once_lite.h \
  ~/tecno_ke7_linux_port/linux/include/linux/panic.h \
    $(wildcard include/config/PANIC_TIMEOUT) \
  ~/tecno_ke7_linux_port/linux/include/linux/stdarg.h \
  ~/tecno_ke7_linux_port/linux/include/linux/printk.h \
    $(wildcard include/config/MESSAGE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_DEFAULT) \
    $(wildcard include/config/CONSOLE_LOGLEVEL_QUIET) \
    $(wildcard include/config/EARLY_PRINTK) \
    $(wildcard include/config/DYNAMIC_DEBUG) \
  ~/tecno_ke7_linux_port/linux/include/linux/kern_levels.h \
  ~/tecno_ke7_linux_port/linux/include/linux/ratelimit_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/spinlock_types_raw.h \
    $(wildcard include/config/DEBUG_SPINLOCK) \
    $(wildcard include/config/DEBUG_LOCK_ALLOC) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/spinlock_types.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/qspinlock_types.h \
    $(wildcard include/config/NR_CPUS) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/qrwlock_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/lockdep_types.h \
    $(wildcard include/config/PROVE_RAW_LOCK_NESTING) \
    $(wildcard include/config/LOCKDEP) \
    $(wildcard include/config/LOCK_STAT) \
  ~/tecno_ke7_linux_port/linux/include/linux/kernel.h \
    $(wildcard include/config/PREEMPT_VOLUNTARY_BUILD) \
    $(wildcard include/config/PREEMPT_DYNAMIC) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_CALL) \
    $(wildcard include/config/HAVE_PREEMPT_DYNAMIC_KEY) \
    $(wildcard include/config/PREEMPT_) \
    $(wildcard include/config/DEBUG_ATOMIC_SLEEP) \
    $(wildcard include/config/MMU) \
    $(wildcard include/config/PROVE_LOCKING) \
  ~/tecno_ke7_linux_port/linux/include/linux/align.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/align.h \
  ~/tecno_ke7_linux_port/linux/include/linux/array_size.h \
  ~/tecno_ke7_linux_port/linux/include/linux/hex.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kstrtox.h \
  ~/tecno_ke7_linux_port/linux/include/linux/log2.h \
    $(wildcard include/config/ARCH_HAS_ILOG2_U32) \
    $(wildcard include/config/ARCH_HAS_ILOG2_U64) \
  ~/tecno_ke7_linux_port/linux/include/linux/minmax.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sprintf.h \
  ~/tecno_ke7_linux_port/linux/include/linux/static_call_types.h \
    $(wildcard include/config/HAVE_STATIC_CALL) \
  ~/tecno_ke7_linux_port/linux/include/linux/instruction_pointer.h \
  ~/tecno_ke7_linux_port/linux/include/linux/util_macros.h \
    $(wildcard include/config/FOO_SUSPEND) \
  ~/tecno_ke7_linux_port/linux/include/linux/wordpart.h \
  ~/tecno_ke7_linux_port/linux/include/linux/cpumask.h \
    $(wildcard include/config/FORCE_NR_CPUS) \
    $(wildcard include/config/HOTPLUG_CPU) \
    $(wildcard include/config/DEBUG_PER_CPU_MAPS) \
    $(wildcard include/config/CPUMASK_OFFSTACK) \
  ~/tecno_ke7_linux_port/linux/include/linux/bitmap.h \
  ~/tecno_ke7_linux_port/linux/include/linux/errno.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/errno.h \
  ~/tecno_ke7_linux_port/linux/include/linux/find.h \
  ~/tecno_ke7_linux_port/linux/include/linux/string.h \
    $(wildcard include/config/BINARY_PRINTF) \
    $(wildcard include/config/FORTIFY_SOURCE) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/string.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/string.h \
    $(wildcard include/config/ARCH_HAS_UACCESS_FLUSHCACHE) \
  ~/tecno_ke7_linux_port/linux/include/linux/bitmap-str.h \
  ~/tecno_ke7_linux_port/linux/include/linux/cpumask_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/threads.h \
    $(wildcard include/config/BASE_SMALL) \
  ~/tecno_ke7_linux_port/linux/include/linux/gfp_types.h \
    $(wildcard include/config/SLAB_OBJ_EXT) \
  ~/tecno_ke7_linux_port/linux/include/linux/numa.h \
    $(wildcard include/config/NUMA_KEEP_MEMINFO) \
    $(wildcard include/config/NUMA) \
    $(wildcard include/config/HAVE_ARCH_NODE_DEV_GROUP) \
  ~/tecno_ke7_linux_port/linux/include/linux/nodemask.h \
    $(wildcard include/config/HIGHMEM) \
  ~/tecno_ke7_linux_port/linux/include/linux/nodemask_types.h \
    $(wildcard include/config/NODES_SHIFT) \
  ~/tecno_ke7_linux_port/linux/include/linux/random.h \
    $(wildcard include/config/VMGENID) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/random.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/ioctl.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/ioctl.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/ioctl.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/ioctl.h \
  ~/tecno_ke7_linux_port/linux/include/linux/irqnr.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/irqnr.h \
  ~/tecno_ke7_linux_port/linux/include/linux/percpu.h \
    $(wildcard include/config/RANDOM_KMALLOC_CACHES) \
    $(wildcard include/config/PAGE_SIZE_4KB) \
    $(wildcard include/config/NEED_PER_CPU_PAGE_FIRST_CHUNK) \
    $(wildcard include/config/HAVE_SETUP_PER_CPU_AREA) \
  ~/tecno_ke7_linux_port/linux/include/linux/alloc_tag.h \
    $(wildcard include/config/MEM_ALLOC_PROFILING_DEBUG) \
    $(wildcard include/config/MEM_ALLOC_PROFILING) \
    $(wildcard include/config/ARCH_MODULE_NEEDS_WEAK_PER_CPU) \
    $(wildcard include/config/MEM_ALLOC_PROFILING_ENABLED_BY_DEFAULT) \
  ~/tecno_ke7_linux_port/linux/include/linux/codetag.h \
    $(wildcard include/config/CODE_TAGGING) \
  ~/tecno_ke7_linux_port/linux/include/linux/preempt.h \
    $(wildcard include/config/PREEMPT_RT) \
    $(wildcard include/config/PREEMPT_COUNT) \
    $(wildcard include/config/DEBUG_PREEMPT) \
    $(wildcard include/config/TRACE_PREEMPT_TOGGLE) \
    $(wildcard include/config/PREEMPTION) \
    $(wildcard include/config/PREEMPT_NOTIFIERS) \
    $(wildcard include/config/PREEMPT_NONE) \
    $(wildcard include/config/PREEMPT_VOLUNTARY) \
    $(wildcard include/config/PREEMPT) \
    $(wildcard include/config/PREEMPT_LAZY) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/preempt.h \
  ~/tecno_ke7_linux_port/linux/include/linux/thread_info.h \
    $(wildcard include/config/THREAD_INFO_IN_TASK) \
    $(wildcard include/config/GENERIC_ENTRY) \
    $(wildcard include/config/ARCH_HAS_PREEMPT_LAZY) \
    $(wildcard include/config/HAVE_ARCH_WITHIN_STACK_FRAMES) \
    $(wildcard include/config/SH) \
  ~/tecno_ke7_linux_port/linux/include/linux/restart_block.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/current.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/thread_info.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/memory.h \
    $(wildcard include/config/ARM64_VA_BITS) \
    $(wildcard include/config/KASAN_SHADOW_OFFSET) \
    $(wildcard include/config/RANDOMIZE_BASE) \
    $(wildcard include/config/DEBUG_VIRTUAL) \
    $(wildcard include/config/EFI) \
    $(wildcard include/config/ARM_GIC_V3_ITS) \
  ~/tecno_ke7_linux_port/linux/include/linux/sizes.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/page-def.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/page.h \
    $(wildcard include/config/PAGE_SHIFT) \
  ~/tecno_ke7_linux_port/linux/include/linux/mmdebug.h \
    $(wildcard include/config/DEBUG_VM) \
    $(wildcard include/config/DEBUG_VM_IRQSOFF) \
    $(wildcard include/config/DEBUG_VM_PGFLAGS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/boot.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/sections.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/sections.h \
    $(wildcard include/config/HAVE_FUNCTION_DESCRIPTORS) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/memory_model.h \
    $(wildcard include/config/FLATMEM) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP) \
    $(wildcard include/config/SPARSEMEM) \
  ~/tecno_ke7_linux_port/linux/include/linux/pfn.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/stack_pointer.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/percpu.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/percpu.h \
  ~/tecno_ke7_linux_port/linux/include/linux/percpu-defs.h \
    $(wildcard include/config/DEBUG_FORCE_WEAK_PER_CPU) \
    $(wildcard include/config/AMD_MEM_ENCRYPT) \
  ~/tecno_ke7_linux_port/linux/include/linux/smp.h \
    $(wildcard include/config/UP_LATE_INIT) \
    $(wildcard include/config/CSD_LOCK_WAIT_DEBUG) \
  ~/tecno_ke7_linux_port/linux/include/linux/smp_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/llist.h \
    $(wildcard include/config/ARCH_HAVE_NMI_SAFE_CMPXCHG) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/smp.h \
    $(wildcard include/config/ARM64_ACPI_PARKING_PROTOCOL) \
  ~/tecno_ke7_linux_port/linux/include/linux/irqflags.h \
    $(wildcard include/config/TRACE_IRQFLAGS) \
    $(wildcard include/config/IRQSOFF_TRACER) \
    $(wildcard include/config/PREEMPT_TRACER) \
    $(wildcard include/config/DEBUG_IRQFLAGS) \
    $(wildcard include/config/TRACE_IRQFLAGS_SUPPORT) \
  ~/tecno_ke7_linux_port/linux/include/linux/irqflags_types.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/irqflags.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/ptrace.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/ptrace.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/sve_context.h \
  ~/tecno_ke7_linux_port/linux/include/linux/irqchip/arm-gic-v3-prio.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/stacktrace/frame.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched.h \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_NATIVE) \
    $(wildcard include/config/SCHED_INFO) \
    $(wildcard include/config/SCHEDSTATS) \
    $(wildcard include/config/SCHED_CORE) \
    $(wildcard include/config/FAIR_GROUP_SCHED) \
    $(wildcard include/config/RT_GROUP_SCHED) \
    $(wildcard include/config/RT_MUTEXES) \
    $(wildcard include/config/UCLAMP_TASK) \
    $(wildcard include/config/UCLAMP_BUCKETS_COUNT) \
    $(wildcard include/config/KMAP_LOCAL) \
    $(wildcard include/config/SCHED_CLASS_EXT) \
    $(wildcard include/config/CGROUP_SCHED) \
    $(wildcard include/config/CFS_BANDWIDTH) \
    $(wildcard include/config/BLK_DEV_IO_TRACE) \
    $(wildcard include/config/PREEMPT_RCU) \
    $(wildcard include/config/TASKS_RCU) \
    $(wildcard include/config/TASKS_TRACE_RCU) \
    $(wildcard include/config/MEMCG_V1) \
    $(wildcard include/config/LRU_GEN) \
    $(wildcard include/config/COMPAT_BRK) \
    $(wildcard include/config/CGROUPS) \
    $(wildcard include/config/BLK_CGROUP) \
    $(wildcard include/config/PSI) \
    $(wildcard include/config/PAGE_OWNER) \
    $(wildcard include/config/EVENTFD) \
    $(wildcard include/config/ARCH_HAS_CPU_PASID) \
    $(wildcard include/config/X86_BUS_LOCK_DETECT) \
    $(wildcard include/config/TASK_DELAY_ACCT) \
    $(wildcard include/config/STACKPROTECTOR) \
    $(wildcard include/config/ARCH_HAS_SCALED_CPUTIME) \
    $(wildcard include/config/VIRT_CPU_ACCOUNTING_GEN) \
    $(wildcard include/config/NO_HZ_FULL) \
    $(wildcard include/config/POSIX_CPUTIMERS) \
    $(wildcard include/config/POSIX_CPU_TIMERS_TASK_WORK) \
    $(wildcard include/config/KEYS) \
    $(wildcard include/config/SYSVIPC) \
    $(wildcard include/config/DETECT_HUNG_TASK) \
    $(wildcard include/config/IO_URING) \
    $(wildcard include/config/AUDIT) \
    $(wildcard include/config/AUDITSYSCALL) \
    $(wildcard include/config/DETECT_HUNG_TASK_BLOCKER) \
    $(wildcard include/config/UBSAN) \
    $(wildcard include/config/UBSAN_TRAP) \
    $(wildcard include/config/COMPACTION) \
    $(wildcard include/config/TASK_XACCT) \
    $(wildcard include/config/CPUSETS) \
    $(wildcard include/config/X86_CPU_RESCTRL) \
    $(wildcard include/config/FUTEX) \
    $(wildcard include/config/PERF_EVENTS) \
    $(wildcard include/config/NUMA_BALANCING) \
    $(wildcard include/config/RSEQ) \
    $(wildcard include/config/DEBUG_RSEQ) \
    $(wildcard include/config/SCHED_MM_CID) \
    $(wildcard include/config/FAULT_INJECTION) \
    $(wildcard include/config/LATENCYTOP) \
    $(wildcard include/config/FUNCTION_GRAPH_TRACER) \
    $(wildcard include/config/MEMCG) \
    $(wildcard include/config/UPROBES) \
    $(wildcard include/config/BCACHE) \
    $(wildcard include/config/VMAP_STACK) \
    $(wildcard include/config/SECURITY) \
    $(wildcard include/config/BPF_SYSCALL) \
    $(wildcard include/config/KSTACK_ERASE) \
    $(wildcard include/config/KSTACK_ERASE_METRICS) \
    $(wildcard include/config/X86_MCE) \
    $(wildcard include/config/KRETPROBES) \
    $(wildcard include/config/RETHOOK) \
    $(wildcard include/config/ARCH_HAS_PARANOID_L1D_FLUSH) \
    $(wildcard include/config/RV) \
    $(wildcard include/config/RV_PER_TASK_MONITORS) \
    $(wildcard include/config/USER_EVENTS) \
    $(wildcard include/config/UNWIND_USER) \
    $(wildcard include/config/SCHED_PROXY_EXEC) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/sched.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/processor.h \
    $(wildcard include/config/KUSER_HELPERS) \
    $(wildcard include/config/ARM64_FORCE_52BIT) \
    $(wildcard include/config/HAVE_HW_BREAKPOINT) \
    $(wildcard include/config/ARM64_TAGGED_ADDR_ABI) \
  ~/tecno_ke7_linux_port/linux/include/vdso/processor.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/vdso/processor.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/hw_breakpoint.h \
    $(wildcard include/config/CPU_PM) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/virt.h \
    $(wildcard include/config/KVM) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/kasan.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/mte-kasan.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/pgtable-types.h \
    $(wildcard include/config/PGTABLE_LEVELS) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/pgtable-nop4d.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/pgtable-hwdef.h \
    $(wildcard include/config/ARM64_CONT_PTE_SHIFT) \
    $(wildcard include/config/ARM64_CONT_PMD_SHIFT) \
    $(wildcard include/config/ARM64_VA_BITS_52) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/pointer_auth.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/prctl.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/spectre.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/fpsimd.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/sigcontext.h \
  ~/tecno_ke7_linux_port/linux/include/linux/pid_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sem_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/shm.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/page.h \
  ~/tecno_ke7_linux_port/linux/include/linux/personality.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/personality.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/getorder.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/shmparam.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/shmparam.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kmsan_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mutex_types.h \
    $(wildcard include/config/MUTEX_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_MUTEXES) \
  ~/tecno_ke7_linux_port/linux/include/linux/osq_lock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/spinlock_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rwlock_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/plist_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/hrtimer_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timerqueue_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rbtree_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timer_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/seccomp_types.h \
    $(wildcard include/config/SECCOMP) \
  ~/tecno_ke7_linux_port/linux/include/linux/refcount_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/resource.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/resource.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/resource.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/resource.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/resource.h \
  ~/tecno_ke7_linux_port/linux/include/linux/latencytop.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/prio.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/signal_types.h \
    $(wildcard include/config/OLD_SIGACTION) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/signal.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/signal.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/signal.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/signal.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/signal.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/signal-defs.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/uapi/asm/siginfo.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/siginfo.h \
  ~/tecno_ke7_linux_port/linux/include/linux/spinlock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/bottom_half.h \
  ~/tecno_ke7_linux_port/linux/include/linux/lockdep.h \
    $(wildcard include/config/DEBUG_LOCKING_API_SELFTESTS) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/mmiowb.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/mmiowb.h \
    $(wildcard include/config/MMIOWB) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/spinlock.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/qspinlock.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/qspinlock.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/qrwlock.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/qrwlock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rwlock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/spinlock_api_smp.h \
    $(wildcard include/config/INLINE_SPIN_LOCK) \
    $(wildcard include/config/INLINE_SPIN_LOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK) \
    $(wildcard include/config/INLINE_SPIN_TRYLOCK_BH) \
    $(wildcard include/config/UNINLINE_SPIN_UNLOCK) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_BH) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_SPIN_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/GENERIC_LOCKBREAK) \
  ~/tecno_ke7_linux_port/linux/include/linux/rwlock_api_smp.h \
    $(wildcard include/config/INLINE_READ_LOCK) \
    $(wildcard include/config/INLINE_WRITE_LOCK) \
    $(wildcard include/config/INLINE_READ_LOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_LOCK_BH) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_WRITE_LOCK_IRQSAVE) \
    $(wildcard include/config/INLINE_READ_TRYLOCK) \
    $(wildcard include/config/INLINE_WRITE_TRYLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK) \
    $(wildcard include/config/INLINE_READ_UNLOCK_BH) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_BH) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQ) \
    $(wildcard include/config/INLINE_READ_UNLOCK_IRQRESTORE) \
    $(wildcard include/config/INLINE_WRITE_UNLOCK_IRQRESTORE) \
  ~/tecno_ke7_linux_port/linux/include/linux/syscall_user_dispatch_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mm_types_task.h \
    $(wildcard include/config/ARCH_WANT_BATCHED_UNMAP_TLB_FLUSH) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/tlbbatch.h \
  ~/tecno_ke7_linux_port/linux/include/linux/netdevice_xmit.h \
    $(wildcard include/config/NET_EGRESS) \
    $(wildcard include/config/NET_ACT_MIRRED) \
    $(wildcard include/config/NF_DUP_NETDEV) \
  ~/tecno_ke7_linux_port/linux/include/linux/task_io_accounting.h \
    $(wildcard include/config/TASK_IO_ACCOUNTING) \
  ~/tecno_ke7_linux_port/linux/include/linux/posix-timers_types.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/rseq.h \
  ~/tecno_ke7_linux_port/linux/include/linux/seqlock_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kcsan.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rv.h \
    $(wildcard include/config/RV_LTL_MONITOR) \
    $(wildcard include/config/RV_REACTORS) \
  ~/tecno_ke7_linux_port/linux/include/linux/uidgid_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/tracepoint-defs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/unwind_deferred_types.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/kmap_size.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/kmap_size.h \
    $(wildcard include/config/DEBUG_KMAP_LOCAL) \
  ~/tecno_ke7_linux_port/linux/include/generated/rq-offsets.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/ext.h \
    $(wildcard include/config/EXT_GROUP_SCHED) \
  ~/tecno_ke7_linux_port/linux/include/clocksource/arm_arch_timer.h \
    $(wildcard include/config/ARM_ARCH_TIMER) \
  ~/tecno_ke7_linux_port/linux/include/linux/timecounter.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/timex.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/time32.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/time.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/compat.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/compat.h \
    $(wildcard include/config/COMPAT_FOR_U64_ALIGNMENT) \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/task_stack.h \
    $(wildcard include/config/STACK_GROWSUP) \
    $(wildcard include/config/DEBUG_STACK_USAGE) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/magic.h \
  ~/tecno_ke7_linux_port/linux/include/linux/refcount.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kasan.h \
    $(wildcard include/config/KASAN_STACK) \
    $(wildcard include/config/KASAN_VMALLOC) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/stat.h \
  ~/tecno_ke7_linux_port/linux/include/linux/uidgid.h \
    $(wildcard include/config/MULTIUSER) \
    $(wildcard include/config/USER_NS) \
  ~/tecno_ke7_linux_port/linux/include/linux/highuid.h \
  ~/tecno_ke7_linux_port/linux/include/linux/buildid.h \
    $(wildcard include/config/VMCORE_INFO) \
  ~/tecno_ke7_linux_port/linux/include/linux/kmod.h \
  ~/tecno_ke7_linux_port/linux/include/linux/umh.h \
  ~/tecno_ke7_linux_port/linux/include/linux/gfp.h \
    $(wildcard include/config/ZONE_DMA) \
    $(wildcard include/config/ZONE_DMA32) \
    $(wildcard include/config/ZONE_DEVICE) \
    $(wildcard include/config/CONTIG_ALLOC) \
  ~/tecno_ke7_linux_port/linux/include/linux/mmzone.h \
    $(wildcard include/config/ARCH_FORCE_MAX_ORDER) \
    $(wildcard include/config/PAGE_BLOCK_MAX_ORDER) \
    $(wildcard include/config/CMA) \
    $(wildcard include/config/MEMORY_ISOLATION) \
    $(wildcard include/config/ZSMALLOC) \
    $(wildcard include/config/UNACCEPTED_MEMORY) \
    $(wildcard include/config/IOMMU_SUPPORT) \
    $(wildcard include/config/SWAP) \
    $(wildcard include/config/HUGETLB_PAGE) \
    $(wildcard include/config/TRANSPARENT_HUGEPAGE) \
    $(wildcard include/config/LRU_GEN_STATS) \
    $(wildcard include/config/LRU_GEN_WALKS_MMU) \
    $(wildcard include/config/MEMORY_FAILURE) \
    $(wildcard include/config/PAGE_EXTENSION) \
    $(wildcard include/config/DEFERRED_STRUCT_PAGE_INIT) \
    $(wildcard include/config/HAVE_MEMORYLESS_NODES) \
    $(wildcard include/config/SPARSEMEM_EXTREME) \
    $(wildcard include/config/SPARSEMEM_VMEMMAP_PREINIT) \
    $(wildcard include/config/HAVE_ARCH_PFN_VALID) \
  ~/tecno_ke7_linux_port/linux/include/linux/list_nulls.h \
  ~/tecno_ke7_linux_port/linux/include/linux/wait.h \
  ~/tecno_ke7_linux_port/linux/include/linux/seqlock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mutex.h \
  ~/tecno_ke7_linux_port/linux/include/linux/debug_locks.h \
  ~/tecno_ke7_linux_port/linux/include/linux/pageblock-flags.h \
    $(wildcard include/config/HUGETLB_PAGE_SIZE_VARIABLE) \
  ~/tecno_ke7_linux_port/linux/include/linux/page-flags-layout.h \
  ~/tecno_ke7_linux_port/linux/include/generated/bounds.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/sparsemem.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/pgtable-prot.h \
    $(wildcard include/config/HAVE_ARCH_USERFAULTFD_WP) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/rsi.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/rsi_cmds.h \
  ~/tecno_ke7_linux_port/linux/include/linux/arm-smccc.h \
    $(wildcard include/config/HAVE_ARM_SMCCC) \
    $(wildcard include/config/ARM) \
  ~/tecno_ke7_linux_port/linux/include/linux/uuid.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/rsi_smc.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mm_types.h \
    $(wildcard include/config/HAVE_ALIGNED_STRUCT_PAGE) \
    $(wildcard include/config/HUGETLB_PMD_PAGE_TABLE_SHARING) \
    $(wildcard include/config/SLAB_FREELIST_HARDENED) \
    $(wildcard include/config/USERFAULTFD) \
    $(wildcard include/config/ANON_VMA_NAME) \
    $(wildcard include/config/PER_VMA_LOCK) \
    $(wildcard include/config/HAVE_ARCH_COMPAT_MMAP_BASES) \
    $(wildcard include/config/MEMBARRIER) \
    $(wildcard include/config/FUTEX_PRIVATE_HASH) \
    $(wildcard include/config/ARCH_HAS_ELF_CORE_EFLAGS) \
    $(wildcard include/config/AIO) \
    $(wildcard include/config/MMU_NOTIFIER) \
    $(wildcard include/config/SPLIT_PMD_PTLOCKS) \
    $(wildcard include/config/IOMMU_MM_DATA) \
    $(wildcard include/config/KSM) \
    $(wildcard include/config/MM_ID) \
    $(wildcard include/config/CORE_DUMP_DEFAULT_ELF_HEADERS) \
  ~/tecno_ke7_linux_port/linux/include/linux/auxvec.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/auxvec.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/auxvec.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kref.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rbtree.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rcupdate.h \
    $(wildcard include/config/TINY_RCU) \
    $(wildcard include/config/RCU_STRICT_GRACE_PERIOD) \
    $(wildcard include/config/RCU_LAZY) \
    $(wildcard include/config/RCU_STALL_COMMON) \
    $(wildcard include/config/VIRT_XFER_TO_GUEST_WORK) \
    $(wildcard include/config/RCU_NOCB_CPU) \
    $(wildcard include/config/TASKS_RCU_GENERIC) \
    $(wildcard include/config/TASKS_RUDE_RCU) \
    $(wildcard include/config/TREE_RCU) \
    $(wildcard include/config/DEBUG_OBJECTS_RCU_HEAD) \
    $(wildcard include/config/PROVE_RCU) \
    $(wildcard include/config/ARCH_WEAK_RELEASE_ACQUIRE) \
  ~/tecno_ke7_linux_port/linux/include/linux/context_tracking_irq.h \
    $(wildcard include/config/CONTEXT_TRACKING_IDLE) \
  ~/tecno_ke7_linux_port/linux/include/linux/rcutree.h \
  ~/tecno_ke7_linux_port/linux/include/linux/maple_tree.h \
    $(wildcard include/config/MAPLE_RCU_DISABLED) \
    $(wildcard include/config/DEBUG_MAPLE_TREE) \
  ~/tecno_ke7_linux_port/linux/include/linux/rwsem.h \
    $(wildcard include/config/RWSEM_SPIN_ON_OWNER) \
    $(wildcard include/config/DEBUG_RWSEMS) \
  ~/tecno_ke7_linux_port/linux/include/linux/completion.h \
  ~/tecno_ke7_linux_port/linux/include/linux/swait.h \
  ~/tecno_ke7_linux_port/linux/include/linux/uprobes.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timer.h \
    $(wildcard include/config/DEBUG_OBJECTS_TIMERS) \
  ~/tecno_ke7_linux_port/linux/include/linux/ktime.h \
  ~/tecno_ke7_linux_port/linux/include/linux/jiffies.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/jiffies.h \
  ~/tecno_ke7_linux_port/linux/include/generated/timeconst.h \
  ~/tecno_ke7_linux_port/linux/include/vdso/ktime.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timekeeping.h \
    $(wildcard include/config/POSIX_AUX_CLOCKS) \
    $(wildcard include/config/GENERIC_CMOS_UPDATE) \
  ~/tecno_ke7_linux_port/linux/include/linux/clocksource_ids.h \
  ~/tecno_ke7_linux_port/linux/include/linux/debugobjects.h \
    $(wildcard include/config/DEBUG_OBJECTS) \
    $(wildcard include/config/DEBUG_OBJECTS_FREE) \
  ~/tecno_ke7_linux_port/linux/include/linux/workqueue.h \
    $(wildcard include/config/DEBUG_OBJECTS_WORK) \
    $(wildcard include/config/FREEZER) \
    $(wildcard include/config/WQ_WATCHDOG) \
  ~/tecno_ke7_linux_port/linux/include/linux/workqueue_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/percpu_counter.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/mmu.h \
    $(wildcard include/config/ARM64_E0PD) \
  ~/tecno_ke7_linux_port/linux/include/linux/page-flags.h \
    $(wildcard include/config/PAGE_IDLE_FLAG) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_2) \
    $(wildcard include/config/ARCH_USES_PG_ARCH_3) \
    $(wildcard include/config/MIGRATION) \
    $(wildcard include/config/HUGETLB_PAGE_OPTIMIZE_VMEMMAP) \
    $(wildcard include/config/DEBUG_KMAP_LOCAL_FORCE_MAP) \
  ~/tecno_ke7_linux_port/linux/include/linux/local_lock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/local_lock_internal.h \
  ~/tecno_ke7_linux_port/linux/include/linux/zswap.h \
    $(wildcard include/config/ZSWAP) \
  ~/tecno_ke7_linux_port/linux/include/linux/memory_hotplug.h \
    $(wildcard include/config/ARCH_HAS_ADD_PAGES) \
    $(wildcard include/config/MEMORY_HOTREMOVE) \
  ~/tecno_ke7_linux_port/linux/include/linux/notifier.h \
  ~/tecno_ke7_linux_port/linux/include/linux/srcu.h \
    $(wildcard include/config/TINY_SRCU) \
    $(wildcard include/config/NEED_SRCU_NMI_SAFE) \
  ~/tecno_ke7_linux_port/linux/include/linux/rcu_segcblist.h \
  ~/tecno_ke7_linux_port/linux/include/linux/srcutree.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rcu_node_tree.h \
    $(wildcard include/config/RCU_FANOUT) \
    $(wildcard include/config/RCU_FANOUT_LEAF) \
  ~/tecno_ke7_linux_port/linux/include/linux/topology.h \
    $(wildcard include/config/USE_PERCPU_NUMA_NODE_ID) \
    $(wildcard include/config/SCHED_SMT) \
    $(wildcard include/config/GENERIC_ARCH_TOPOLOGY) \
  ~/tecno_ke7_linux_port/linux/include/linux/arch_topology.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/topology.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/topology.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sysctl.h \
    $(wildcard include/config/SYSCTL) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/sysctl.h \
  ~/tecno_ke7_linux_port/linux/include/linux/elf.h \
    $(wildcard include/config/ARCH_HAVE_EXTRA_ELF_NOTES) \
    $(wildcard include/config/ARCH_USE_GNU_PROPERTY) \
    $(wildcard include/config/ARCH_HAVE_ELF_PROT) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/elf.h \
    $(wildcard include/config/COMPAT_VDSO) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/generated/asm/user.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/user.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/elf.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/elf-em.h \
  ~/tecno_ke7_linux_port/linux/include/linux/fs.h \
    $(wildcard include/config/FANOTIFY_ACCESS_PERMISSIONS) \
    $(wildcard include/config/READ_ONLY_THP_FOR_FS) \
    $(wildcard include/config/FS_POSIX_ACL) \
    $(wildcard include/config/CGROUP_WRITEBACK) \
    $(wildcard include/config/IMA) \
    $(wildcard include/config/FILE_LOCKING) \
    $(wildcard include/config/FSNOTIFY) \
    $(wildcard include/config/EPOLL) \
    $(wildcard include/config/UNICODE) \
    $(wildcard include/config/FS_ENCRYPTION) \
    $(wildcard include/config/FS_VERITY) \
    $(wildcard include/config/QUOTA) \
    $(wildcard include/config/FS_DAX) \
    $(wildcard include/config/BLOCK) \
  ~/tecno_ke7_linux_port/linux/include/linux/vfsdebug.h \
    $(wildcard include/config/DEBUG_VFS) \
  ~/tecno_ke7_linux_port/linux/include/linux/wait_bit.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kdev_t.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/kdev_t.h \
  ~/tecno_ke7_linux_port/linux/include/linux/dcache.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rculist.h \
    $(wildcard include/config/PROVE_RCU_LIST) \
  ~/tecno_ke7_linux_port/linux/include/linux/rculist_bl.h \
  ~/tecno_ke7_linux_port/linux/include/linux/list_bl.h \
  ~/tecno_ke7_linux_port/linux/include/linux/bit_spinlock.h \
  ~/tecno_ke7_linux_port/linux/include/linux/lockref.h \
    $(wildcard include/config/ARCH_USE_CMPXCHG_LOCKREF) \
  ~/tecno_ke7_linux_port/linux/include/linux/stringhash.h \
    $(wildcard include/config/DCACHE_WORD_ACCESS) \
  ~/tecno_ke7_linux_port/linux/include/linux/hash.h \
    $(wildcard include/config/HAVE_ARCH_HASH) \
  ~/tecno_ke7_linux_port/linux/include/linux/path.h \
  ~/tecno_ke7_linux_port/linux/include/linux/list_lru.h \
  ~/tecno_ke7_linux_port/linux/include/linux/shrinker.h \
    $(wildcard include/config/SHRINKER_DEBUG) \
  ~/tecno_ke7_linux_port/linux/include/linux/xarray.h \
    $(wildcard include/config/XARRAY_MULTI) \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/mm.h \
    $(wildcard include/config/MMU_LAZY_TLB_REFCOUNT) \
    $(wildcard include/config/ARCH_HAS_MEMBARRIER_CALLBACKS) \
    $(wildcard include/config/ARCH_HAS_SYNC_CORE_BEFORE_USERMODE) \
  ~/tecno_ke7_linux_port/linux/include/linux/sync_core.h \
    $(wildcard include/config/ARCH_HAS_PREPARE_SYNC_CORE_CMD) \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/coredump.h \
  ~/tecno_ke7_linux_port/linux/include/linux/radix-tree.h \
  ~/tecno_ke7_linux_port/linux/include/linux/pid.h \
  ~/tecno_ke7_linux_port/linux/include/linux/capability.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/capability.h \
  ~/tecno_ke7_linux_port/linux/include/linux/semaphore.h \
  ~/tecno_ke7_linux_port/linux/include/linux/fcntl.h \
    $(wildcard include/config/ARCH_32BIT_OFF_T) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/fcntl.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/uapi/asm/fcntl.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/asm-generic/fcntl.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/openat2.h \
  ~/tecno_ke7_linux_port/linux/include/linux/migrate_mode.h \
  ~/tecno_ke7_linux_port/linux/include/linux/percpu-rwsem.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rcuwait.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/signal.h \
    $(wildcard include/config/SCHED_AUTOGROUP) \
    $(wildcard include/config/BSD_PROCESS_ACCT) \
    $(wildcard include/config/TASKSTATS) \
  ~/tecno_ke7_linux_port/linux/include/linux/signal.h \
    $(wildcard include/config/DYNAMIC_SIGFRAME) \
    $(wildcard include/config/PROC_FS) \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/jobctl.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/task.h \
    $(wildcard include/config/HAVE_EXIT_THREAD) \
    $(wildcard include/config/ARCH_WANTS_DYNAMIC_TASK_STRUCT) \
    $(wildcard include/config/HAVE_ARCH_THREAD_STRUCT_WHITELIST) \
  ~/tecno_ke7_linux_port/linux/include/linux/uaccess.h \
    $(wildcard include/config/ARCH_HAS_SUBPAGE_FAULTS) \
    $(wildcard include/config/HARDENED_USERCOPY) \
  ~/tecno_ke7_linux_port/linux/include/linux/fault-inject-usercopy.h \
    $(wildcard include/config/FAULT_INJECTION_USERCOPY) \
  ~/tecno_ke7_linux_port/linux/include/linux/nospec.h \
  ~/tecno_ke7_linux_port/linux/include/linux/ucopysize.h \
    $(wildcard include/config/HARDENED_USERCOPY_DEFAULT_ON) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/uaccess.h \
    $(wildcard include/config/CC_HAS_ASM_GOTO_OUTPUT) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/kernel-pgtable.h \
    $(wildcard include/config/RELOCATABLE) \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/asm-extable.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/mte.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/extable.h \
    $(wildcard include/config/BPF_JIT) \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/access_ok.h \
    $(wildcard include/config/ALTERNATE_USER_ADDRESS_SPACE) \
  ~/tecno_ke7_linux_port/linux/include/linux/cred.h \
  ~/tecno_ke7_linux_port/linux/include/linux/key.h \
    $(wildcard include/config/KEY_NOTIFICATIONS) \
    $(wildcard include/config/NET) \
  ~/tecno_ke7_linux_port/linux/include/linux/assoc_array.h \
    $(wildcard include/config/ASSOCIATIVE_ARRAY) \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/user.h \
    $(wildcard include/config/VFIO_PCI_ZDEV_KVM) \
    $(wildcard include/config/IOMMUFD) \
    $(wildcard include/config/WATCH_QUEUE) \
  ~/tecno_ke7_linux_port/linux/include/linux/ratelimit.h \
  ~/tecno_ke7_linux_port/linux/include/linux/posix-timers.h \
  ~/tecno_ke7_linux_port/linux/include/linux/alarmtimer.h \
    $(wildcard include/config/RTC_CLASS) \
  ~/tecno_ke7_linux_port/linux/include/linux/hrtimer.h \
    $(wildcard include/config/HIGH_RES_TIMERS) \
    $(wildcard include/config/TIME_LOW_RES) \
    $(wildcard include/config/TIMERFD) \
  ~/tecno_ke7_linux_port/linux/include/linux/hrtimer_defs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/timerqueue.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rcuref.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rcu_sync.h \
  ~/tecno_ke7_linux_port/linux/include/linux/delayed_call.h \
  ~/tecno_ke7_linux_port/linux/include/linux/errseq.h \
  ~/tecno_ke7_linux_port/linux/include/linux/ioprio.h \
  ~/tecno_ke7_linux_port/linux/include/linux/sched/rt.h \
  ~/tecno_ke7_linux_port/linux/include/linux/iocontext.h \
    $(wildcard include/config/BLK_ICQ) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/ioprio.h \
  ~/tecno_ke7_linux_port/linux/include/linux/fs_types.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mount.h \
  ~/tecno_ke7_linux_port/linux/include/linux/mnt_idmapping.h \
  ~/tecno_ke7_linux_port/linux/include/linux/slab.h \
    $(wildcard include/config/FAILSLAB) \
    $(wildcard include/config/KFENCE) \
    $(wildcard include/config/SLUB_TINY) \
    $(wildcard include/config/SLUB_DEBUG) \
    $(wildcard include/config/SLAB_BUCKETS) \
    $(wildcard include/config/KVFREE_RCU_BATCHED) \
  ~/tecno_ke7_linux_port/linux/include/linux/percpu-refcount.h \
  ~/tecno_ke7_linux_port/linux/include/linux/rw_hint.h \
  ~/tecno_ke7_linux_port/linux/include/linux/file_ref.h \
  ~/tecno_ke7_linux_port/linux/include/linux/unicode.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/fs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/quota.h \
    $(wildcard include/config/QUOTA_NETLINK_INTERFACE) \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/dqblk_xfs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/dqblk_v1.h \
  ~/tecno_ke7_linux_port/linux/include/linux/dqblk_v2.h \
  ~/tecno_ke7_linux_port/linux/include/linux/dqblk_qtree.h \
  ~/tecno_ke7_linux_port/linux/include/linux/projid.h \
  ~/tecno_ke7_linux_port/linux/include/uapi/linux/quota.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kobject.h \
    $(wildcard include/config/UEVENT_HELPER) \
    $(wildcard include/config/DEBUG_KOBJECT_RELEASE) \
  ~/tecno_ke7_linux_port/linux/include/linux/sysfs.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kernfs.h \
    $(wildcard include/config/KERNFS) \
  ~/tecno_ke7_linux_port/linux/include/linux/idr.h \
  ~/tecno_ke7_linux_port/linux/include/linux/kobject_ns.h \
  ~/tecno_ke7_linux_port/linux/include/linux/moduleparam.h \
    $(wildcard include/config/ALPHA) \
    $(wildcard include/config/PPC64) \
  ~/tecno_ke7_linux_port/linux/include/linux/rbtree_latch.h \
  ~/tecno_ke7_linux_port/linux/include/linux/error-injection.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/error-injection.h \
  ~/tecno_ke7_linux_port/linux/include/linux/dynamic_debug.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/module.h \
  ~/tecno_ke7_linux_port/linux/include/asm-generic/module.h \
    $(wildcard include/config/HAVE_MOD_ARCH_SPECIFIC) \
  ~/tecno_ke7_linux_port/linux/include/linux/build-salt.h \
    $(wildcard include/config/BUILD_SALT) \
  ~/tecno_ke7_linux_port/linux/include/linux/elfnote.h \
  ~/tecno_ke7_linux_port/linux/include/linux/elfnote-lto.h \
  ~/tecno_ke7_linux_port/linux/include/linux/vermagic.h \
    $(wildcard include/config/PREEMPT_BUILD) \
  ~/tecno_ke7_linux_port/linux/include/generated/utsrelease.h \
  ~/tecno_ke7_linux_port/linux/arch/arm64/include/asm/vermagic.h \

.module-common.o: $(deps_.module-common.o)

$(deps_.module-common.o):
