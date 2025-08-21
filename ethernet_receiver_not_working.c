#include "xparameters.h"
#include "xil_printf.h"
#include "lwip/init.h"
#include "lwip/netif.h"
#include "lwip/udp.h"
#include "netif/xadapter.h"
#include "xemacps.h"

static struct netif server_netif;
struct netif *echo_netif;

void udp_receive_callback(void *arg, struct udp_pcb *pcb,
                          struct pbuf *p, const ip_addr_t *addr, u16_t port) {
    if (p != NULL) {
        xil_printf("Received %d bytes from %s:%d\n", p->len, ipaddr_ntoa(addr), port);
        xil_printf("Data: %.*s\n", p->len, (char *)p->payload);
        pbuf_free(p);
    }
}

int main() {
    ip_addr_t ipaddr, netmask, gw;
    u8_t mac_address[] = {0x00, 0x0A, 0x35, 0x00, 0x01, 0x02};

    XEmacPs_Config *emac_config;
    XEmacPs emac;

    lwip_init();

    IP4_ADDR(&ipaddr, 192, 168, 1, 10);
    IP4_ADDR(&netmask, 255, 255, 255, 0);
    IP4_ADDR(&gw, 192, 168, 1, 1);

    emac_config = XEmacPs_LookupConfig(0);
    if (emac_config == NULL) {
        xil_printf("EMAC config failed\n");
        return -1;
    }

    if (XEmacPs_CfgInitialize(&emac, emac_config, emac_config->BaseAddress) != XST_SUCCESS) {
        xil_printf("EMAC init failed\n");
        return -1;
    }

    echo_netif = &server_netif;
    if (!xemac_add(echo_netif, &ipaddr, &netmask, &gw, mac_address, emac_config->BaseAddress)) {
        xil_printf("xemac_add failed\n");
        return -1;
    }

    netif_set_default(echo_netif);
    netif_set_up(echo_netif);
    netif_set_link_up(echo_netif);

    xil_printf("Network up with IP: %s\n", ipaddr_ntoa(&ipaddr));
    struct udp_pcb *pcb;
    pcb = udp_new();
    if (!pcb) {
        xil_printf("UDP PCB create failed\n");
        return -1;
    }

    if (udp_bind(pcb, IP_ADDR_ANY, 12345) != ERR_OK) {
        xil_printf("UDP bind failed\n");
        return -1;
    }

    udp_recv(pcb, udp_receive_callback, NULL);
    xil_printf("Listening for UDP packets on port 12345...\n");

    while (1) {
        xemacif_input(echo_netif);
    }

    return 0;
}
