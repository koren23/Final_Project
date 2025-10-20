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
    if (strlen(msg) < 16) {
        xil_printf("Error: Message too short. Must be at least 16 characters.\n");
        return;
    }

    u32 currtime = 0, imptime = 0, latval = 0, longval = 0;

    currtime = (msg[0] << 24) | (msg[1] << 16) | (msg[2] << 8) | msg[3];
    imptime = (msg[4] << 24) | (msg[5] << 16) | (msg[6] << 8) | msg[7];
    latval   = (msg[8] << 24) | (msg[9] << 16) | (msg[10] << 8) | msg[11];
    longval  = (msg[12] << 24) | (msg[13] << 16) | (msg[14] << 8) | msg[15];

    XGpio_DiscreteWrite(&gpio, 1, 0x1);
    XGpio_DiscreteWrite(&gpio, 2, currtime);
    xil_printf("Current time:\t%02X %02X %02X %02X\n", (u8_t)msg[0], (u8_t)msg[1], (u8_t)msg[2], (u8_t)msg[3]);
    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x2);
    XGpio_DiscreteWrite(&gpio, 2, imptime);
    xil_printf("Impact time:\t%02X %02X %02X %02X\n", (u8_t)msg[4], (u8_t)msg[5], (u8_t)msg[6], (u8_t)msg[7]);
    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x3);
    XGpio_DiscreteWrite(&gpio, 2, latval);
    xil_printf("Latitude:\t%02X %02X %02X %02X\n", (u8_t)msg[8], (u8_t)msg[9], (u8_t)msg[10], (u8_t)msg[11]);
    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x4);
    XGpio_DiscreteWrite(&gpio, 2, longval);
    xil_printf("Longitude:\t%02X %02X %02X %02X\n", (u8_t)msg[12], (u8_t)msg[13], (u8_t)msg[14], (u8_t)msg[15]);
    usleep(10);

    xil_printf("Data uploaded to PL ^_^\n");
    usleep(10);

    // clear valid flag
    XGpio_DiscreteWrite(&gpio, 1, 0);
    xil_printf("Flag cleared\n");
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
        xil_printf("Received from %d.%d.%d.%d:%d ->", ip4_addr1(addr), ip4_addr2(addr), ip4_addr3(addr), ip4_addr4(addr), port);
        for (size_t i = 0; i < len; i++) {
            xil_printf(" %02X", (u8_t)msg[i]);
        }
        xil_printf("\n");

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

    XGpio_Initialize(&gpio, XPAR_XGPIO_0_BASEADDR);
    XGpio_SetDataDirection(&gpio, 1, 0x00);
    XGpio_SetDataDirection(&gpio, 2, 0x00);
    xil_printf("GPIOs initialized\n");
}


int main() {
    general_initialization();
    
    udp_receiver_init();

    while (1) {
        xemacif_input(&server_netif);
    }
    return 0;
}
