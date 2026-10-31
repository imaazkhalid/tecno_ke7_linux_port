# Standalone Makefile for ccci_util_lib.ko on Linux 6.18

MODULE_NAME := ccci_util_lib
obj-m := $(MODULE_NAME).o

$(MODULE_NAME)-y := ccci_util_lib_fo.o \
                    ccci_util_lib_load_img.o \
                    ccci_util_lib_sys.o \
                    ccci_private_log.o \
                    ccci_util_lib_time.o \
                    ccci_util_lib_main.o \
                    ccci_util_ld_md_errno.o \
                    ccci_util_broadcast.o \
                    ccci_util_pin_broadcast.o \
                    ccci_util_sib.o \
                    ccci_util_md_rat.o

ccflags-y += -I$(src) \
             -I$(src)/../include \
             -I$(src)/../include/mt-plat \
             -Wno-error \
             -Wno-unused-function \
             -Wno-declaration-after-statement \
             -Wno-discarded-qualifiers

all:
	make -C $(KDIR) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(PWD) modules

clean:
	make -C $(KDIR) ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(PWD) clean
