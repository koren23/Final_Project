#include "lwip/init.h"
#include "lwip/udp.h"
#include "lwip/ip_addr.h"
#include "lwip/netif.h"
#include "netif/xadapter.h"
#include "xparameters.h"

#define UDP_SERVER_PORT 12345 // can be changed to any port

void udp_receive_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p,  
const ip_addr_t *addr, u16_t port) {
    if (p != NULL) { // function is called when a UDP packet is received
        pbuf_free(p);
    }
}

int main() {
    struct netif server_netif;
    struct udp_pcb *udp_pcb; // initialize lwIP stack

    lwip_init(); // declare network interface

    if (xemac_add(&server_netif, NULL, NULL, NULL, NULL, XPAR_XEMACPS_0_BASEADDR) == NULL) { // adds the ethernet interface
        return -1;
    }

    netif_set_default(&server_netif); // sets this interface as the default and activates it
    netif_set_up(&server_netif);

    udp_pcb = udp_new(); // creates a new UDP control block.
    if (!udp_pcb) { 
        return -1;
    }

    if (udp_bind(udp_pcb, IP_ADDR_ANY, UDP_SERVER_PORT) != ERR_OK) { 
        udp_remove(udp_pcb); // binds the UDP PCB to any IP address and the defined port
        return -1; // can be edited to be the other way around if needed
    }

    udp_recv(udp_pcb, udp_receive_callback, NULL);


    while(1) {
        xemacif_input(&server_netif);
    }

    return 0;
}
