#include "xparameters.h"
#include "xil_printf.h"
#include <stdio.h>
#include <stdint.h>
#include "sleep.h"
#include <time.h>
#include "lwip/udp.h"
#include "lwip/init.h"
#include "lwip/ip_addr.h"
#include "lwip/pbuf.h"
#include "netif/xadapter.h"

#define LISTEN_PORT 12345 // port chosen - needs to be changed
#define BUFFER_SIZE 4096 // log max size
#define Max_Size_Per_Message 256 // log max size per message
#define BRAM_START   0x40000000 // start address of bram
#define BRAM_END     0x4000000F // end address of bram (i set it so i only see the first words)
#define BRAM_WORDS   ((BRAM_END - BRAM_START + 1) / 4) // (number of bytes in bram)/(number of bytes per word)

volatile uint32_t *bram = (uint32_t *)BRAM_START; // declare bram pointer to the memory address (bram start) volatile means it wont cache it bcs it changes
uint32_t previous[BRAM_WORDS]; // previous is an array that saves the bram values

struct udp_pcb *receiver_pcb; // receiver_pcb points to a udp_pcb - contains port num local-ip
                        // it points to a callback function that activates when receiving data
                        
struct netif server_netif; // server_netif points to netif (contains  ip subnet gateway mac etc)
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6}; // artyz7-10 mac address
static char message_buffer[BUFFER_SIZE] = {0};
char tempstring[Max_Size_Per_Message] = {0};



void print_ip(const char *msg, ip_addr_t *ip) { // gets called in general_initialization
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip), 
                                       ip4_addr3(ip), ip4_addr4(ip));
}



void format_timestamp(u32 timestamp, char *buffer, size_t buffer_size) { // convert unix data to time
    // called in pl_transmitter
    time_t raw_time = (time_t)(long)timestamp; // converts the value of timestamp to long and to time_t (for gmtime)
    struct tm *tm_info = gmtime(&raw_time); // converts unix time to a struct (tm)

    int year   = tm_info->tm_year + 1900; //time_t counts time since 1900
    int month  = tm_info->tm_mon + 1; // counts from 0 so i added 1
    int day    = tm_info->tm_mday;
    int hour   = tm_info->tm_hour;
    int minute = tm_info->tm_min;
    int second = tm_info->tm_sec;
    snprintf(buffer, buffer_size, "%02d/%02d/%04d %02d:%02d:%02d",
             day, month, year, hour, minute, second);
}



void pl_transmitter(char msg[256]){ // called in udp_receive_callback
    u32 currtime, imptime, latval, longval; // save data from msg to u32

    //split msg to currtime imptime latval and longval
    memcpy(&currtime, msg, 4);
    memcpy(&imptime, msg + 4, 4);
    memcpy(&latval, msg + 8, 4);
    memcpy(&longval, msg + 12, 4);

    char currstr[32];
    format_timestamp(currtime, currstr, sizeof(currstr));// convert unix to display time
    xil_printf("curt.txt=\"%s\"%c%c%c",currstr,0xFF,0xFF,0xFF); // change to different uart

    char impstr[32];
    format_timestamp(imptime, impstr, sizeof(impstr));// convert unix to display time
    xil_printf("impt.txt=\"%s\"%c%c%c",impstr,0xFF,0xFF,0xFF); // change to different uart
    
    xil_printf("landmark.txt=\"(%d.%03d,%d.%03d)\"%c%c%c", latval / 1000, latval % 1000,longval / 1000, longval % 1000,0xFF, 0xFF, 0xFF);  // change to different uart

    bram[1] = 0x00000001;
    bram[0] = currtime;
    xil_printf("Current time:\t%u\n", currtime);

    usleep(10);

    bram[1] = 0x00000002;
    bram[0] = imptime;
    xil_printf("Impact time:\t%u\n", imptime);

    usleep(10);

    for (int i = 0; i < BRAM_WORDS; i++) { // reset bram
        bram[i] = 0x00000000;
    }
    bram[1] = 0x00000006; // send command to ADC
    while(bram[1] != 6); // ADC done
    usleep(10);
    u32 radius;
    for (int i = 0; i < BRAM_WORDS; i++) {
        if(i == 3){ // loops around first 4 bram words
            radius = bram[3];
        }
        xil_printf("%d :\t%u\n", i, bram[i]); // number 3 shouldnt work bcs of the timing in PL
    }
	for (int i = 0; i < BRAM_WORDS; i++) { // reset bram
        bram[i] = 0x00000000;
    }

    usleep(10);

    bram[1] = 0x00000003;
    bram[0] = radius;
    xil_printf("Radius:\t%u\n", radius);
    xil_printf("radius.txt=\"%d\"%c%c%c",radius,0xFF,0xFF,0xFF); // change to different uart
    
    usleep(10);

    bram[1] = 0x00000004;
    bram[0] = latval;
    xil_printf("Latitude:\t%.3f\n", (double)latval / 1000);
    
    usleep(10);

    bram[1] = 0x00000004;
    bram[0] = longval;
    xil_printf("Longitude:\t%.3f\n", (double)longval / 1000);

    usleep(10);

    xil_printf("Data uploaded to PL ^_^\n");

    usleep(10);
    // clear valid flag

    xil_printf("Flag clear\n");
    
}

// defined in udp_receiver_init in udp_recv() as a callblack function
void udp_receive_callback(void *arg, // a value i can set so itll send it back when called - not used
                          struct udp_pcb *pcb, // contains the lwip state for this udp - isnt used cos not replying
                          struct pbuf *p, // struct used to store network packet in memory
                          const ip_addr_t *addr, // sender address
                          u16_t port) {
    // unused
    (void)arg;
    (void)pcb;

    if (p != NULL) {// if p !=NULL then theres data available
        char msg[256] = {0};
        // if length of the pbuffer data is bigger than 255 it sets it as 255 to avoid overflow
        size_t len = (p->len < sizeof(msg) - 1) ? p->len : sizeof(msg) - 1; 

        memcpy(msg, p->payload, len); // copies len bytes from pbuff to msg
        msg[len] = '\0'; // sets a null terminator
        xil_printf("Received from %d.%d.%d.%d:%d -> %s\n", ip4_addr1(addr), ip4_addr2(addr), 
                                                         ip4_addr3(addr), ip4_addr4(addr), port, msg);
        pl_transmitter(msg);
        pbuf_free(p); // frees the pbuffer
    }
}

void udp_receiver_init(){// called in main
    receiver_pcb = udp_new();// creates a struct (receiver_pcb) with ip port and callback func
    if (!receiver_pcb) {
        xil_printf("Failed to create receiver PCB\n");
        return;
    }

    err_t err = udp_bind(receiver_pcb, IP_ADDR_ANY, LISTEN_PORT);  // udp_bind() makes receiver pcb listen 
                                                                   // to this port on selected ip (any)
    // err_t is a lwip error type
    if (err != ERR_OK) {
        xil_printf("UDP bind failed with error %d\n", err);
        return;
    }

    udp_recv(receiver_pcb, udp_receive_callback, NULL); // udp_recv calls udp_receive_callback
                                                        // with all its parameters from receiver_pcb

    xil_printf("UDP receiver initialized on port %d\n", LISTEN_PORT);
}

void general_initialization() {
    ip_addr_t ipaddr, netmask, gw; // declaration of 3 variables ... ip_addr_t is a struct from lwIP
    xil_printf("Starting lwIP UDP Receiver Example\n");

    IP4_ADDR(&ipaddr, 169, 254, 87, 100);    // board IP address
    IP4_ADDR(&netmask, 255, 255, 0, 0);  // subnet mask
    IP4_ADDR(&gw, 0, 0, 0, 0);             // gateway address
    lwip_init(); // lwIP function that initializes (resets internal data timers and protocols)
    struct netif *netif = &server_netif; // pointer to the global server_netif
                // will hold all information about the board network interface

    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) {// adds an ethernet mac interface to lwip
        xil_printf("Error adding network interface\n");
        return;
    }
    netif_set_default(netif); // sets netif as the default network interface
    netif_set_up(netif); // marks the network interface as active
    xil_printf("Link is %s", netif_is_link_up(netif) ? "up\n" : "down\n");
    print_ip("Board IP", &ipaddr);

    		
}

void init_bram() { // saves the bram values and prints them
    xil_printf("=== Initial BRAM contents (%d words) ===\n", BRAM_WORDS);

    for (int i = 0; i < BRAM_WORDS; i++) {
        previous[i] = bram[i];
        xil_printf("0x%08X : 0x%08X\n",
               (unsigned int)(BRAM_START + i * 4),
               previous[i]);
    }
} 

int main() {
    init_bram();
    general_initialization();
    xil_printf("General Initialization function done\n");

    udp_receiver_init();
    xil_printf("UDP Receiver Initalization function done\n");

    while (1) {
        xemacif_input(&server_netif);// checks for packets, puts it in pbuf and passes it down to netif
    }
    return 0;
}




    


