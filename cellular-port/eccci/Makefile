MODULE_NAME := ccci
obj-m := $(MODULE_NAME).o

$(MODULE_NAME)-y := ccci_core.o \
                    ccci_bm.o \
                    ccci_modem.o \
                    modem_sys1.o \
                    ccci_rtc.o \
                    ccci_md_clk.o \
                    hif/ccci_hif.o \
                    hif/ccci_ringbuf.o \
                    hif/ccci_debug_info.o \
                    hif/ccci_hif_ccif.o \
                    hif/ccci_hif_cldma.o \
                    hif/ccci_cldma_plat.o \
                    port/port_cfg.o \
                    port/port_char.o \
                    port/port_ctlmsg.o \
                    port/port_ipc.o \
                    port/port_net.o \
                    port/port_poller.o \
                    port/port_misc.o \
                    port/port_proxy.o \
                    port/port_udc.o \
                    port/port_rpc.o \
                    port/port_smem.o \
                    port/port_sysmsg.o \
                    port/ccci_swtp.o \
                    fsm/ccci_fsm.o \
                    fsm/ccci_fsm_ioctl.o \
                    fsm/ccci_fsm_monitor.o \
                    fsm/ccci_fsm_poller.o \
                    fsm/ccci_fsm_scp.o \
                    fsm/ccci_fsm_ee.o \
                    fsm/ccci_fsm_sys.o \
                    fsm/mdee_dumper_v1.o \
                    fsm/mdee_dumper_v2.o \
                    fsm/mdee_dumper_v3.o \
                    udc/udc.o \
                    ../ccmni/ccmni.o \
                    mt6768/ccci_platform.o \
                    mt6768/md_sys1_platform.o \
                    mt6768/ccci_stubs.o

ccflags-y += -I$(src) \
             -I$(src)/inc \
             -I$(src)/port \
             -I$(src)/hif \
             -I$(src)/fsm \
             -I$(src)/udc \
             -I$(src)/udc/udc_lib_inc \
             -I$(src)/mt6768 \
             -I$(src)/../include \
             -I$(src)/../include/mt-plat \
             -I$(src)/../ccci_util \
             -I$(src)/../ccmni \
             -I$(src)/../scp/include \
             -I$(src)/../memory-amms \
             -DCONFIG_MTK_ECCCI_CLDMA \
             -DCONFIG_MTK_MD1_SUPPORT=9 \
             -DCCCI_KMODULE_ENABLE \
             -DMTK_PLATFORM_MT6768 \
             -DMD_GENERATION=6293 \
             -Wno-error \
             -Wno-unused-function \
             -Wno-declaration-after-statement \
             -Wno-discarded-qualifiers

KBUILD_EXTRA_SYMBOLS := $(src)/../ccci_util/Module.symvers

all:
	make -C ~/tecno_ke7_linux_port/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(PWD) modules

clean:
	make -C ~/tecno_ke7_linux_port/linux ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- M=$(PWD) clean
