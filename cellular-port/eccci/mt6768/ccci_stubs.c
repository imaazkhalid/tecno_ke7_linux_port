// SPDX-License-Identifier: GPL-2.0
#include <linux/types.h>
#include <linux/kernel.h>

int scp_A_register_notify(void *nb)
{
	return 0;
}

int scp_ipi_registration(int id, void *handler, const char *name)
{
	return 0;
}

bool spm_is_md1_sleep(void)
{
	return false;
}

void inject_pin_status_event(int pin_value, const char pin_name[])
{
}

void clk_buf_set_by_flightmode(bool is_flightmode_on)
{
}

int ccci_get_adc_val(void)
{
	return 0;
}

int ccci_get_adc_num(void)
{
	return 0;
}

unsigned int devapc_check_flag = 1;
