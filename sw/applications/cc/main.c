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
    uint32_t v32;
    uint16_t v16;
    uint8_t v8;
    uintptr_t base = 0x40000000; // Base address for memory-mapped SPI flash

    uint32_t data_read_back[4] = {0x9, 0x21, 0x43, 0x65};

    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_test1 = heep_get_flash_address_offset(flash_buffer_test1);

    uintptr_t offset = (uintptr_t)flash_ptr_test1;
    volatile uint8_t *ptr8 = (uint8_t *)(base + offset);
    volatile uint16_t *ptr16 = (uint16_t *)(base + offset);
    volatile uint32_t *ptr32 = (uint32_t *)(base + offset);

    uint32_t flash_addr = (uint32_t)flash_ptr_test1;


    PRINTF("Write flash with controller...\n");
    w25q128jw_controller_write((void*)flash_addr, (void*)data_read_back, 16, 0);
    while(!w25q128jw_controller_is_ready_polling());

    w25q128jw_set_buffer();
    PRINTF("Write obi word...\n");
    ptr32[0] = 0x12345678u;


    PRINTF("Read obi words...\n");
    for(int i = 0; i < 4; i++) {
        v32 = ptr32[i];
        PRINTF("0x%x\n", v32);
    }

    PRINTF("Read obi short...\n");
    for(int i = 0; i < 8; i++) {
        v16 = ptr16[i];
        PRINTF("0x%x\n", v16);
    }

    PRINTF("Read obi bytes...\n");
    for(int i = 0; i < 16; i++) {
        v8 = ptr8[i];
        PRINTF("0x%x\n", v8);
    }

    return 0;
}
