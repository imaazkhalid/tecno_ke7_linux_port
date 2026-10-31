/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Copyright (c) 2019 MediaTek Inc.
 */

#ifndef _MEMORY_AMMS_H_
#define _MEMORY_AMMS_H_

#include <linux/types.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/slab.h>

static inline void *vmap_reserved_mem(phys_addr_t start, phys_addr_t size, pgprot_t prot)
{
	long i;
	long page_count;
	unsigned long pfn;
	void *vaddr = NULL;
	phys_addr_t addr = start;
	struct page **pages;

	page_count = DIV_ROUND_UP(size, PAGE_SIZE);
	pages = kmalloc_array(page_count, sizeof(struct page *), GFP_KERNEL);
	if (!pages)
		return NULL;

	for (i = 0; i < page_count; i++) {
		pfn = __phys_to_pfn(addr);
		pages[i] = pfn_to_page(pfn);
		addr += PAGE_SIZE;
	}

	vaddr = vmap(pages, page_count, VM_MAP, prot);
	kfree(pages);
	return vaddr;
}

static inline int free_reserved_memory(phys_addr_t start_phys, phys_addr_t end_phys)
{
	return 0;
}

#endif /* end of _MEMORY_AMMS_H_ */
