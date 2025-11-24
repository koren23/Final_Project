#include "xparameters.h"
#include "xil_printf.h"
#include "lwip/udp.h"
#include "lwip/init.h"
#include "lwip/ip_addr.h"
#include "lwip/pbuf.h"
#include "netif/xadapter.h"
#include "xgpio.h"
#include "sleep.h"
#include <time.h>
#include "xil_printf.h"

#define LISTEN_PORT 12345 // port chosen - needs to be changed


// global variables
XGpio gpio; // gpio points to the XGpio struct supplied by xilinx (containts base address pins state configs(input or output) etc)
struct udp_pcb *receiver_pcb; // receiver_pcb points to a udp_pcb - contains port num local-ip
                        // it points to a callback function that activates when receiving data

struct netif server_netif; // server_netif points to netif (contains  ip subnet gateway mac etc)
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6}; // artyz7-10 mac address

void print_ip(const char *msg, ip_addr_t *ip) {
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

void pl_transmitter(char msg[256]){
    u32 currtime, imptime, latval, longval;
    for (int i = 0; msg[i] != '\0'; i++) {
        if(i<32){currtime = (u32)msg[i];} 
        else if(i<64){imptime = (u32)msg[i-32];}
        else if(i<96){latval = (u32)msg[i-64];}
        else if(i<128){longval = (u32)msg[i-96];}
    }

    long currtimelong = (long) currtime;
    time_t curr_raw = (time_t)currtimelong;
    struct tm *curr_tm = gmtime(&curr_raw);
    int curr_year   = curr_tm->tm_year + 1900;
    int curr_month  = curr_tm->tm_mon + 1;
    int curr_day    = curr_tm->tm_mday;
    int curr_hour   = curr_tm->tm_hour;
    int curr_minute = curr_tm->tm_min;
    int curr_second = curr_tm->tm_sec;
    char currstr[32];
    snprintf(currstr, sizeof(currstr),
            "%02d/%02d/%04d %02d:%02d:%02d",
            curr_day, curr_month, curr_year, curr_hour, curr_minute, curr_second);

    long imptimelong = (long) imptime;
    time_t imp_raw = (time_t)imptimelong;
    struct tm *imp_tm = gmtime(&imp_raw);
    int imp_year   = imp_tm->tm_year + 1900;
    int imp_month  = imp_tm->tm_mon + 1;
    int imp_day    = imp_tm->tm_mday;
    int imp_hour   = imp_tm->tm_hour;
    int imp_minute = imp_tm->tm_min;
    int imp_second = imp_tm->tm_sec;
    char impstr[32];
    snprintf(impstr, sizeof(impstr),
            "%02d/%02d/%04d %02d:%02d:%02d",
            imp_day, imp_month, imp_year, imp_hour, imp_minute, imp_second);

    xil_printf("page 0%c",0xFFFFFF);
    xil_printf("impt.txt=\"%s\"%c",impstr,0xFFFFFF);
    xil_printf("curt.txt=\"%s\"%c",currstr,0xFFFFFF);
    xil_printf("landmark.txt=\"(%.3f,%.3f)\"",(double)latval / 1000 , (double)longval / 1000 ,0xFFFFFF);
    
    XGpio_DiscreteWrite(&gpio, 1, 0x1);
    XGpio_DiscreteWrite(&gpio, 2, currtime);
    xil_printf("Current time:\t%u\n", currtime);
    usleep(10);
    XGpio_DiscreteWrite(&gpio, 1, 0x2);
    XGpio_DiscreteWrite(&gpio, 2, imptime);
    xil_printf("Impact time:\t%u\n", imptime);
    usleep(10);
    XGpio_DiscreteWrite(&gpio, 1, 0x4);
    XGpio_DiscreteWrite(&gpio, 2, latval);
    xil_printf("Latitude:\t%.3f\n", (double)latval / 1000);
    usleep(10);
    XGpio_DiscreteWrite(&gpio, 1, 0x5);
    XGpio_DiscreteWrite(&gpio, 2, longval);
    xil_printf("Longitude:\t%.3f\n", (double)longval / 1000);
    usleep(10);
    xil_printf("Data uploaded to PL ^_^");
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
