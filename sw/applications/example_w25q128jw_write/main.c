/**
 * @file main.c
 * @brief Example application for W25Q128JW flash write test.
 *
 * This application demonstrates writing data to the W25Q128JW flash memory
 * then reading it back and verifying the contents match the original data.
 *
 * Test parameters:
 * - Transfer size: 4100 bytes (spanning over 2 sectors) (write operation is word precise)
 */

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include "memory.h"

#include "core_v_mini_mcu.h"
#include "x-heep.h"

#include "w25q128jw_controller.h"
#include "data.h"
#include "w25q128jw.h"
#include "dma.h"

/* Write operation flags */
#define FLAG_SW    (1)       /* Software write (default HW) */
#define FLAG_INT   (1 << 1)  /* Interrupt-driven write (default no interrupts) */
#define FLAG_QUAD  (1 << 2)  /* Quad SPI mode (default single mode) */

#define STOP_ON_FAILURE 1    /* Stop on first failure (1) or run all tests (0) */

/* By default, printfs are activated for FPGA and disabled for simulation. */
#define PRINTF_IN_FPGA  1
#define PRINTF_IN_SIM   1

#if TARGET_SIM && PRINTF_IN_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#elif PRINTF_IN_FPGA && !TARGET_SIM
    #define PRINTF(fmt, ...)    printf(fmt, ## __VA_ARGS__)
#else
    #define PRINTF(...)
#endif

//
// ISR
//
void handler_irq_w25q128jw_controller(uint32_t id) {
    // Set the done flag
    w25q128jw_controller_set_done_flag();

    // Clear the interrupt status register (interrupt handled)
    w25q128jw_controller_clear_status_register();
}

/**
 * @param sram_src: SRAM pointer
 * @param flash_dst: Flash pointer
 * @param len: number of bytes to write
 * @param flags: write operation flags (e.g., FLAG_SW, FLAG_INT, FLAG_QUAD)
 */
static int do_write(
    const void *sram_src, void *flash_dst, uint32_t len, uint32_t flags
) {
    w25q_error_codes_t status = FLASH_OK;

    if (flags & FLAG_SW) {
        // Software write (standard speed, no interrupts, with DMA)
        status = w25q128jw_erase_and_write_standard_dma((uint32_t)(uintptr_t)flash_dst, (void *)sram_src, len);
        return (status == FLASH_OK) ? 0 : 1;
    } else {
        // Hardware write (using the controller)
        uint32_t interrupts = (flags & FLAG_INT)  ? 1U : 0U;
        uint32_t quad       = (flags & FLAG_QUAD) ? 1U : 0U;

        w25q128jw_controller_write((void *)flash_dst, (void *)sram_src, len, interrupts, quad);
        return 0;
    }
}

/**
 * @brief Trusted read from the FLASH device.
 *
 * It uses the SW library, assumed to be correct, to read back the data from flash for verification.
 * @param flash_src: Flash pointer
 * @param sram_dst: SRAM pointer
 * @param len: number of bytes to read
 * @return 0 if the read is successful, 1 otherwise.
 */
static int safe_read(
    const void *flash_src, void *sram_dst, uint32_t len
) {
    w25q_error_codes_t status = FLASH_OK;

    // Use the standard read with DMA for safe read back (verification)
    status = w25q128jw_read_standard_dma((uint32_t)(uintptr_t)flash_src, (void *)sram_dst, len, 0, 0);
    return (status == FLASH_OK) ? 0 : 1;
}

static int compare_buffers(const void *expected, const void *actual, uint32_t len) {
    const uint8_t *expected_bytes = (const uint8_t *)(void *)expected;
    const uint8_t *actual_bytes   = (const uint8_t *)(void *)actual;

    for (uint32_t i = 0; i < len; ++i) {
        if (expected_bytes[i] != actual_bytes[i]) {
            PRINTF("Mismatch at %d: expected 0x%x, got 0x%x\n", i, expected_bytes[i], actual_bytes[i]);
            return 1;
        }
    }

    return 0;
}

/**
 * @param name: test case name for logging
 * @param src_base: base pointer for source data (SRAM)
 * @param dst_base: base pointer for destination data (Flash)
 * @param expected_base: base pointer for expected data (SRAM)
 * @param read_back: base pointer for read back data (SRAM)
 * @param offset: offset in bytes to apply to the base pointers for this test case
 * @param len: number of bytes to write/read
 * @param flags: write operation flags (e.g., FLAG_SW, FLAG_INT, FLAG_QUAD)
 */
static int run_case(
    const char *name,
    const void *sram_source_base,
    const void *flash_dest_base,
    void *sram_read_back,
    const void *sram_expected_base,
    uint32_t offset,
    uint32_t len,
    uint32_t flags
) {
    void *src      = (void *)((char *)sram_source_base   + offset);
    void *dst      = (void *)((char *)flash_dest_base    + offset);
    void *expected = (void *)((char *)sram_expected_base + offset);

    memset((void *)sram_read_back, 0, len);

    PRINTF("%s: ", name);

    // Step 1: Write SRAM -> Flash
    if (do_write(src, dst, len, flags) != 0) {
        PRINTF("write operation failed\n");

        #if STOP_ON_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Step 2: Read back Flash -> SRAM (using safe read, assumed to work correctly)
    if (safe_read(dst, sram_read_back, len) != 0) {
        PRINTF("read back operation failed\n");

        #if STOP_ON_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    // Step 3: Compare read back data with expected data
    if (compare_buffers(expected, sram_read_back, len) != 0) {
        PRINTF("FAIL\n");

        #if STOP_ON_FAILURE
            exit(EXIT_FAILURE);
        #else
            return 1;
        #endif
    }

    PRINTF("PASS\n");
    return 0;
}

int main(void) {
    uint32_t errors = 0;
    const uint32_t two_sectors_bytes = 2U * SECTOR_SIZE_BYTES;

    // Random unaligned offset and length for testing reads
    const uint32_t unaligned_single_sector_offset_bytes = 43U;
    const uint32_t unaligned_cross_sector_offset_bytes = SECTOR_SIZE_BYTES - 37U;
    const uint32_t unaligned_length_bytes = 113U;

    // Initialize the DMA
    dma_init(NULL);
    // Pick the correct spi device based on simulation type
    spi_host_t* spi;
    spi = spi_flash;

    // Init SPI host and SPI<->Flash bridge parameters and Flash Power Up
    if (w25q128jw_init(spi) != FLASH_OK) return EXIT_FAILURE;

    int32_t* flash_ptr_buffer = heep_get_flash_address_offset(flash_buffer);
    const void *expected_base = (const void *)sram_source_pattern;

    PRINTF("Starting flash write tests\n");

    // Hardware Write, standard speed, DMA, no interrupt
    errors += run_case(
        "1) Hardware Write, standard speed, DMA, single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, SECTOR_SIZE_BYTES, 0U
    );
    errors += run_case(
        "2) Hardware Write, standard speed, DMA, two sectors",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, 0U
    );
    errors += run_case(
        "2) Hardware Write, standard speed, DMA, two sectors, 2nd time overwritting previous data",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, 0U
    );
    errors += run_case(
        "3) Hardware Write, standard speed, DMA, unaligned single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_single_sector_offset_bytes, unaligned_length_bytes, 0U
    );
    errors += run_case(
        "4) Hardware Write, standard speed, DMA, unaligned cross sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_cross_sector_offset_bytes, unaligned_length_bytes, 0U
    );

    // Hardware Write, standard speed, DMA, interrupt
    errors += run_case(
        "5) Hardware Write, standard speed, DMA, interrupt, single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, SECTOR_SIZE_BYTES, FLAG_INT
    );
    errors += run_case(
        "6) Hardware Write, standard speed, DMA, interrupt, two sectors",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_INT
    );
    errors += run_case(
        "6) Hardware Write, standard speed, DMA, interrupt, two sectors, 2nd time overwritting previous data",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_INT
    );
    errors += run_case(
        "7) Hardware Write, standard speed, DMA, interrupt, unaligned single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_single_sector_offset_bytes, unaligned_length_bytes, FLAG_INT
    );
    errors += run_case(
        "8) Hardware Write, standard speed, DMA, interrupt, unaligned cross sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_cross_sector_offset_bytes, unaligned_length_bytes, FLAG_INT
    );

    //goto end;

    // Hardware Write, quad speed, DMA, no interrupt
    errors += run_case(
        "9) Hardware Write, quad speed, DMA, single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, SECTOR_SIZE_BYTES, FLAG_QUAD
    );
    errors += run_case(
        "10) Hardware Write, quad speed, DMA, two sectors",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_QUAD
    );
    errors += run_case(
        "10) Hardware Write, quad speed, DMA, two sectors, 2nd time overwritting previous data",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_QUAD
    );
    errors += run_case(
        "11) Hardware Write, quad speed, DMA, unaligned single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_single_sector_offset_bytes, unaligned_length_bytes, FLAG_QUAD
    );
    errors += run_case(
        "12) Hardware Write, quad speed, DMA, unaligned cross sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_cross_sector_offset_bytes, unaligned_length_bytes, FLAG_QUAD
    );

    // Hardware Write, quad speed, DMA, interrupt
    errors += run_case(
        "13) Hardware Write, quad speed, DMA, interrupt, single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, SECTOR_SIZE_BYTES, FLAG_QUAD | FLAG_INT
    );
    errors += run_case(
        "14) Hardware Write, quad speed, DMA, interrupt, two sectors",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_QUAD | FLAG_INT
    );
    errors += run_case(
        "14) Hardware Write, quad speed, DMA, interrupt, two sectors, 2nd time overwritting previous data",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_QUAD | FLAG_INT
    );
    errors += run_case(
        "15) Hardware Write, quad speed, DMA, interrupt, unaligned single sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_single_sector_offset_bytes, unaligned_length_bytes, FLAG_QUAD | FLAG_INT
    );
    errors += run_case(
        "16) Hardware Write, quad speed, DMA, interrupt, unaligned cross sector",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        unaligned_cross_sector_offset_bytes, unaligned_length_bytes, FLAG_QUAD | FLAG_INT
    );

    // Final check: test that dma is still working
    errors += run_case(
        "17) Manual dma copy",
        sram_source_pattern, flash_ptr_buffer, sram_buffer, expected_base,
        0U, two_sectors_bytes, FLAG_SW
    );

end:
    PRINTF("\n--------TEST FINISHED--------\n");
    if (errors == 0) {
        PRINTF("All tests passed!\n");
        return EXIT_SUCCESS;
    } else {
        PRINTF("Some tests failed (%d).\n", errors);
        return EXIT_FAILURE;
    }
}
