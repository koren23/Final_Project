#include "xparameters.h"
#include "xparameters_ps.h"
#include "xil_printf.h"
#include "lwip/udp.h"
#include "lwip/init.h"
#include "lwip/ip_addr.h"
#include "lwip/pbuf.h"
#include "netif/xadapter.h"

#define LISTEN_PORT 5001

struct udp_pcb *receiver_pcb;
struct netif server_netif;

u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6};

void print_ip(const char *msg, ip_addr_t *ip)
{
    xil_printf("%s: %d.%d.%d.%d\n", msg,
               ip4_addr1(ip),
               ip4_addr2(ip),
               ip4_addr3(ip),
               ip4_addr4(ip));
}

void udp_receive_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p,
                          const ip_addr_t *addr, u16_t port)
{
    (void)arg;
    (void)pcb;

    if (p != NULL) {
        char msg[256] = {0};
        size_t len = (p->len < sizeof(msg) - 1) ? p->len : sizeof(msg) - 1;
        memcpy(msg, p->payload, len);
        msg[len] = '\0';

        xil_printf("Received from %d.%d.%d.%d:%d -> %s\n",
                   ip4_addr1(addr), ip4_addr2(addr), ip4_addr3(addr), ip4_addr4(addr),
                   port, msg);

        pbuf_free(p);
    }
}

void udp_receiver_init()
{
    receiver_pcb = udp_new();
    if (!receiver_pcb) {
        xil_printf("Failed to create receiver PCB\n");
        return;
    }

    err_t err = udp_bind(receiver_pcb, IP_ADDR_ANY, LISTEN_PORT);
    if (err != ERR_OK) {
        xil_printf("UDP bind failed with error %d\n", err);
        return;
    }

    udp_recv(receiver_pcb, udp_receive_callback, NULL);
    xil_printf("UDP receiver initialized on port %d\n", LISTEN_PORT);
}

int main()
{
    ip_addr_t ipaddr, netmask, gw;
    xil_printf("Starting lwIP UDP Receiver Example\n");

    IP4_ADDR(&ipaddr, 192, 168, 0, 20);
    IP4_ADDR(&netmask, 255, 255, 255, 0);
    IP4_ADDR(&gw, 192, 168, 0, 21);

    lwip_init();
    struct netif *netif = &server_netif;

    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) {
        xil_printf("Error adding network interface\n");
        return -1;
    }

    netif_set_default(netif);
    netif_set_up(netif);
    xil_printf("Link is %s\n", netif_is_link_up(netif) ? "up" : "down");

    print_ip("Board IP", &ipaddr);

    udp_receiver_init();

    while (1) {
        xemacif_input(netif);
    }

    return 0;
}
