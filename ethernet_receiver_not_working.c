#include "xparameters.h"
#include "xil_printf.h"

#include "lwip/udp.h" // lwIP UDP API definitions
#include "lwip/init.h" // lwIP stack initialization
#include "lwip/ip_addr.h" // IP address structure and helpers
#include "lwip/pbuf.h" // packet buffer structure
#include "netif/xadapter.h" // ethernet adapter ethernet for lwIP

#define LISTEN_PORT 12345 // port number to listen for incoming UDP packets

// global UDP protocol control block for receiving data
struct udp_pcb *receiver_pcb;

// network interface structure => represents the ethernet interface
struct netif server_netif;

// MAC address of the board => located behind the board
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6};

// utility functiomn to print an IP address with a label
void print_ip(const char *msg, ip_addr_t *ip) {
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

// callback function triggered when UDP packet arrives => extracts the message from the pbuffer
void udp_receive_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p, const ip_addr_t *addr, u16_t port) {
    (void)arg;
    (void)pcb;

    if (p != NULL) {
        char msg[256] = {0}; // buffer to store received message
        size_t len = (p->len < sizeof(msg) - 1) ? p->len : sizeof(msg) - 1;

        // copy payload to buffer and null-terminate
        memcpy(msg, p->payload, len);
        msg[len] = '\0';

        // print source IP, port, message received.
        xil_printf("Received from %d.%d.%d.%d:%d -> %s\n", ip4_addr1(addr), ip4_addr2(addr), ip4_addr3(addr), ip4_addr4(addr), port, msg);

        // free the received packet buffer
        pbuf_free(p);
    }
}

// initialize the UDP receiver by creating a PCB and binding it to the listen port => sets the callback function for received packets
void udp_receiver_init(){
    receiver_pcb = udp_new(); // create new UDP PCB
    if (!receiver_pcb) {
        xil_printf("Failed to create receiver PCB\n");
        return;
    }

    // bind PCB to all IP addresses on the specified port
    err_t err = udp_bind(receiver_pcb, IP_ADDR_ANY, LISTEN_PORT);
    if (err != ERR_OK) {
        xil_printf("UDP bind failed with error %d\n", err);
        return;
    }

    // register callback function to handle incoming UDP packets
    udp_recv(receiver_pcb, udp_receive_callback, NULL);
    xil_printf("UDP receiver initialized on port %d\n", LISTEN_PORT);
}

// intializes the network interface stetsup lwIP stack and continuously processes incoming ethernet frames
int main() {
    ip_addr_t ipaddr, netmask, gw; // local IP configuration tothe board

    xil_printf("Starting lwIP UDP Receiver Example\n");

    IP4_ADDR(&ipaddr, 192, 168, 0, 27); // board IP address
    IP4_ADDR(&netmask, 255, 255, 255, 0); // subnet mask
    IP4_ADDR(&gw, 0, 0, 0, 0); // gateway address

    // initialize lwIP stack
    lwip_init();

    struct netif *netif = &server_netif;

    // add and intialize ethernet interface
    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) {
        xil_printf("Error adding network interface\n");
        return -1;
    }

    // set the interface as default and bring it up
    netif_set_default(netif);
    netif_set_up(netif);

    // check link status and print result
    xil_printf("Link is %s\n", netif_is_link_up(netif) ? "up" : "down");

    // print board IP address
    print_ip("Board IP", &ipaddr);

    //initialize UDP receiver (bind and set callback)
    udp_receiver_init();

    // handle incoming ethernet frames
    while (1) {
        xemacif_input(netif); // poll for incoming packets
    }

    return 0;
}
