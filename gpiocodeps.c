#include "xparameters.h"
#include "xil_printf.h"
#include "lwip/udp.h" // lwIP UDP API definitions
#include "lwip/init.h" // lwIP stack initialization
#include "lwip/ip_addr.h" // IP address structure and helpers
#include "lwip/pbuf.h" // packet buffer structure
#include "netif/xadapter.h" // ethernet adapter ethernet for lwIP
#include "xgpio.h"
#include "sleep.h" 

#define LISTEN_PORT 12345 // port chosen 

XGpio gpio;

struct udp_pcb *receiver_pcb; // pointer to UDP control block used to manage and receive packets

struct netif server_netif; // variable type struct netif

u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6}; // artyz7-10 mac address

void print_ip(const char *msg, ip_addr_t *ip) {
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

void pl_transmitter(char msg[256]){
    
    XGpio_Initialize(&gpio, XPAR_GPIO0_BASEADDR);
	XGpio_SetDataDirection(&gpio, 1, 0x00);
    XGpio_SetDataDirection(&gpio, 2, 0x00);

     u32 value = (u32)atoi(msg);

    XGpio_DiscreteWrite(&gpio, 2, 1);
    XGpio_DiscreteWrite(&gpio, 1, value);
    usleep(1);
    XGpio_DiscreteWrite(&gpio, 2, 0);
    xil_printf("data uploaded to pl: %d\n",value);
}

void udp_receive_callback(void *arg, // a value i can set so itll send it back when called - not used
                          struct udp_pcb *pcb, // contains the lwip state for this udp - isnt used cos not replying
                          struct pbuf *p, const ip_addr_t *addr, // sender address
                          u16_t port) {
    (void)arg;
    (void)pcb;

    if (p != NULL) {
        char msg[256] = {0};
        // if length of the pbuffer data is bigger than 255 it sets it as 255 to avoid overflow
        size_t len = (p->len < sizeof(msg) - 1) ? p->len : sizeof(msg) - 1; 

        memcpy(msg, p->payload, len); // copies len bytes from pbuff to msg
        msg[len] = '\0'; // sets a null terminator
        xil_printf("Received from %d.%d.%d.%d:%d -> %s\n", ip4_addr1(addr), ip4_addr2(addr), ip4_addr3(addr), ip4_addr4(addr), port, msg);
        pl_transmitter(msg);
        pbuf_free(p); // frees the pbuffer
    }
}

void udp_receiver_init(){
    receiver_pcb = udp_new(); // creates a new UDP protocol control block
    if (!receiver_pcb) {
        xil_printf("Failed to create receiver PCB\n");
        return;
    }

    err_t err = udp_bind(receiver_pcb, IP_ADDR_ANY, LISTEN_PORT); // listens to new packets
    if (err != ERR_OK) {
        xil_printf("UDP bind failed with error %d\n", err);
        return;
    }

    udp_recv(receiver_pcb, udp_receive_callback, NULL); // udp_recv calls udp_receive_callback with all its parameters from receiver_pcb
    xil_printf("UDP receiver initialized on port %d\n", LISTEN_PORT);
}

void general_initialization() {
    ip_addr_t ipaddr, netmask, gw; // declaration of 3 variables ... ip_addr_t is a struct from lwIP
    xil_printf("Starting lwIP UDP Receiver Example\n");

    IP4_ADDR(&ipaddr, 192, 168, 0, 27);    // board IP address
    IP4_ADDR(&netmask, 255, 255, 255, 0);  // subnet mask
    IP4_ADDR(&gw, 0, 0, 0, 0);             // gateway address

    lwip_init(); // lwIP function that restarts everything there

    struct netif *netif = &server_netif; // pointer to the global server_netif

//  function the restarts the ethernet interface
//  using the pointer it transfers that data into server_netif
    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) {
        xil_printf("Error adding network interface\n");
        return;
    }

    netif_set_default(netif); // sets netif as the default network interface
    netif_set_up(netif); // marks the network interface as active

    xil_printf("Link is %s\n", netif_is_link_up(netif) ? "up" : "down");
    print_ip("Board IP", &ipaddr);
}


int main() {
    general_initialization();
    
    udp_receiver_init();

    while (1) {
        xemacif_input(&server_netif);
    }
    return 0;
}
