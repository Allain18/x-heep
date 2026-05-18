/*
 * Simple test for OBI -> W25Q128JW register bridge
 *
 * This program writes and reads a few controller registers via the
 * memory-mapped flash OBI window. Adjust `W25Q_BASE` if your map differs.
 */

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include "core_v_mini_mcu.h"
#include "x-heep.h"
#include "w25q128jw.h"



/* By default, PRINTFs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

int32_t __attribute__((section(".xheep_data_flash_only"))) __attribute__ ((aligned (16))) flash_buffer_test1[4] = {
0xDEADBEEFu, 0xCAFEBABEu, 0xFEEDFACEu, 0xBAADF00Du
};


int main(void)
{
    uint32_t v;
    uintptr_t base = 0x40000000; // Base address for memory-mapped SPI flash

    uint32_t data_read_back[4] = {0};

    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_test1 = heep_get_flash_address_offset(flash_buffer_test1);

    uintptr_t offset = (uintptr_t)flash_ptr_test1;
    volatile uint32_t *ptr = (uint32_t *)(base + offset);
    // uint32_t *ptr = (uint32_ts *)(base);


    PRINTF("%p\n", flash_ptr_test1); //e940
    PRINTF("%p\n", flash_buffer_test1);
    PRINTF("0x%x\n", base);
    PRINTF("%p\n", ptr);

    PRINTF("Read test values...\n");

    
    uint32_t flash_addr = (uint32_t)flash_ptr_test1;
    for(int i=0; i < 4; i++)
    {
        w25q128jw_read_standard(flash_addr+4*i, data_read_back, 4);
        PRINTF("0x%x\n", data_read_back[0]);
    }

    for(int i = 0; i < 4; i++) {
        // v = flash_ptr_test1[i];
        v = ptr[i];
        PRINTF("0x%08x\n", v);
    }
    // for(int i = 0; i < 4; i++) {
    //     v = ptr[-i];
    //     PRINTF("0x%08x\n", v);
    // }
    return 0;
}
