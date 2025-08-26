#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
#include "sleep.h"


void transmitdata(u32 data){
    XGpio gpio;

	XGpio_Initialize(&gpio,XPAR_XGPIO_0_BASEADDR); // initialize from xparameters.h
	XGpio_SetDataDirection(&gpio, 1, 0x00);
    XGpio_SetDataDirection(&gpio, 2, 0x00);

    XGpio_DiscreteWrite(&gpio, 2, 1);
    XGpio_DiscreteWrite(&gpio, 1, data);
    usleep(1);
    XGpio_DiscreteWrite(&gpio, 2, 0);
    xil_printf("%d",data);
    
}

int main(void){
    u32 data = 0xAA;
    transmitdata(data);
}
