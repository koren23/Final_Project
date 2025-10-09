#include "xil_printf.h"
#include "xparameters.h"


#define TEST_PATTERN 0xA5A5A5A5
#define NUM_WORDS 16  // number of 32-bit words to test

int main(void)
{
    volatile unsigned int *bram_ptr = (unsigned int *)XPAR_AXI_BRAM_CTRL_0_BASEADDR;
    unsigned int i;
    unsigned int read_val;
    int errors = 0;

    // --- Write to BRAM ---
    for (i = 0; i < NUM_WORDS; i++) {
        bram_ptr[i] = TEST_PATTERN + i;  // write incremental pattern
    }

    // --- Read back from BRAM ---
    for (i = 0; i < NUM_WORDS; i++) {
        read_val = bram_ptr[i];
        if (read_val != (TEST_PATTERN + i)) {
            xil_printf("Error at index %d: wrote 0x%08X, read 0x%08X\r\n",
                   i, TEST_PATTERN + i, read_val);
            errors++;
        }
    }

    if (errors == 0)
        xil_printf("BRAM Test PASSED!\r\n");
    else
        xil_printf("BRAM Test FAILED with %d errors\r\n", errors);
}
