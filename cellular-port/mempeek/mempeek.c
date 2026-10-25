// SPDX-License-Identifier: GPL-2.0
/*
 * mempeek - read the modem's reserved DRAM from the AP without rebooting.
 *
 * The md_resv region is normal RAM in the kernel's linear map (ioremap()
 * refuses it), so __va() is the correct accessor.  Parameters:
 *   addr=0x...   physical address
 *   len=0x...    bytes to dump (default 0x100)
 *   mode=0       hex dump
 *   mode=1       ASCII strings (>= 8 printable chars)
 *   mode=2       scan for a u32 (value=) inside [addr, addr+len)
 *   mode=3       CRC32 of [addr, addr+len)
 */
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/moduleparam.h>
#include <linux/types.h>
#include <linux/crc32.h>

static unsigned long addr = 0xae000000;
static unsigned int len = 0x100;
static unsigned int mode;
static unsigned int value;

module_param(addr, ulong, 0644);
module_param(len, uint, 0644);
module_param(mode, uint, 0644);
module_param(value, uint, 0644);
MODULE_PARM_DESC(addr, "physical address");
MODULE_PARM_DESC(len, "length in bytes");
MODULE_PARM_DESC(mode, "0=hex 1=ascii 2=scan");
MODULE_PARM_DESC(value, "u32 to scan for (mode=2)");

static int __init mempeek_init(void)
{
	const u8 *p = (const u8 *)__va((phys_addr_t)addr);
	unsigned int i;

	pr_info("mempeek: addr=%#lx len=%#x mode=%u\n", addr, len, mode);

	if (mode == 2) {
		const u32 *w = (const u32 *)p;
		unsigned int n = len / 4;
		int hits = 0;

		for (i = 0; i < n; i++) {
			if (w[i] == value) {
				pr_info("mempeek: %#lx -> %#lx (word %u)\n",
					value, addr + (unsigned long)i * 4, i);
				if (++hits >= 64)
					break;
			}
		}
		if (!hits)
			pr_info("mempeek: %#x not found in %u words\n",
				value, n);
		return 0;
	}

	if (mode == 3) {
		pr_info("mempeek: crc32(%#lx, %#x) = %#x\n", addr, len,
			crc32_le(~0, p, len) ^ ~0);
		return 0;
	}

	if (mode == 1) {
		unsigned int j = 0;

		while (j < len) {
			unsigned int k = 0;

			while (j + k < len && k < 200 && p[j + k] >= 0x20 &&
			       p[j + k] < 0x7f)
				k++;
			if (k >= 8) {
				char buf[201];

				memcpy(buf, p + j, k);
				buf[k] = 0;
				pr_info("mempeek: +%#x: %s\n", j, buf);
				j += k;
			} else {
				j++;
			}
		}
		return 0;
	}

	for (i = 0; i < len; i += 16) {
		const u32 *w = (const u32 *)(p + i);

		pr_info("mempeek %#lx: %08x %08x %08x %08x\n",
			addr + i, w[0], w[1], w[2], w[3]);
	}
	return 0;
}

static void __exit mempeek_exit(void)
{
}

module_init(mempeek_init);
module_exit(mempeek_exit);
MODULE_LICENSE("GPL");
MODULE_DESCRIPTION("peek at reserved RAM from the AP");
