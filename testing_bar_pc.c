#include "xparameters.h"
#include "xgpio.h"
#include "xil_printf.h"
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



// global variables
XGpio gpio; // gpio points to the XGpio struct supplied by xilinx 
            // (containts base address pins state configs(input or output) etc)

struct udp_pcb *receiver_pcb; // receiver_pcb points to a udp_pcb - contains port num local-ip
                        // it points to a callback function that activates when receiving data
                        
struct netif server_netif; // server_netif points to netif (contains  ip subnet gateway mac etc)
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6}; // artyz7-10 mac address
static char message_buffer[BUFFER_SIZE] = {0}; 
char tempstring[Max_Size_Per_Message] = {0}; 



void log_printer(const char *data_string){ // in charge of adding new data to previous and sending it in
                                           // the format of a nextion command for log
    char temp[Max_Size_Per_Message];
    snprintf(temp, sizeof(temp), "%s\r",data_string); // saves \r + string to temp
    size_t needed = strlen(temp); 
    size_t current = strlen(message_buffer);
    if (current + needed >= BUFFER_SIZE) {
        message_buffer[0] = '\0'; // check if theres room in buffer
    }  
    strncat(message_buffer, temp, BUFFER_SIZE - strlen(message_buffer) - 1);   // saves old and new data to one string
    xil_printf("log.txt=\"%s\"%c%c%c", message_buffer, 0xFF, 0xFF, 0xFF);  
} 



void print_ip(const char *msg, ip_addr_t *ip) { // gets called in general_initialization
    snprintf(tempstring, sizeof(tempstring), "%s: %d.%d.%d.%d", msg, 
                                                                ip4_addr1(ip), ip4_addr2(ip), 
                                                                ip4_addr3(ip), ip4_addr4(ip));
    log_printer(tempstring);
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

    xil_printf("page 0%c",0xFFFFFF); // go to page 0 - data page

    char currstr[32];
    format_timestamp(currtime, currstr, sizeof(currstr)); // convert unix to display time
    xil_printf("curt.txt=\"%s\"%c",currstr,0xFFFFFF);

    char impstr[32];
    format_timestamp(imptime, impstr, sizeof(impstr)); // convert unix to display time
    xil_printf("curt.txt=\"%s\"%c",impstr,0xFFFFFF);
    
    xil_printf("landmark.txt=\"(%.3f,%.3f)\"",(double)latval / 1000 , (double)longval / 1000 ,0xFFFFFF);
    
    XGpio_DiscreteWrite(&gpio, 1, 0x1); // flag 1
    XGpio_DiscreteWrite(&gpio, 2, currtime);
    snprintf(tempstring, sizeof(tempstring), "Current time:\t%u", currtime);
    log_printer(tempstring);

    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x2); // flag 2
    XGpio_DiscreteWrite(&gpio, 2, imptime);
    snprintf(tempstring, sizeof(tempstring), "Impact time:\t%u", imptime);
    log_printer(tempstring);

    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x4); // flag 4 (3 will be radius)
    XGpio_DiscreteWrite(&gpio, 2, latval);
    snprintf(tempstring, sizeof(tempstring), "Latitude:\t%.3f", (double)latval / 1000);
    log_printer(tempstring);
    
    usleep(10);

    XGpio_DiscreteWrite(&gpio, 1, 0x5); // flag 5
    XGpio_DiscreteWrite(&gpio, 2, longval);
    snprintf(tempstring, sizeof(tempstring), "Longitude:\t%.3f", (double)longval / 1000);
    log_printer(tempstring);

    usleep(10);

    log_printer("Data uploaded to PL ^_^");

    usleep(10);
    // clear valid flag
    XGpio_DiscreteWrite(&gpio, 1, 0); // clear flag (0)
    log_printer("Flag clear");
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

    if (p != NULL) { // if p !=NULL then theres data available
        char msg[256] = {0};

        // if length of the pbuffer data is bigger than 255 it sets it as 255 to avoid overflow
        size_t len = (p->len < sizeof(msg) - 1) ? p->len : sizeof(msg) - 1; 

        memcpy(msg, p->payload, len); // copies len bytes from pbuff to msg
        msg[len] = '\0'; // sets a null terminator
        snprintf(tempstring, sizeof(tempstring), "Received from %d.%d.%d.%d:%d -> %s", 
                                            ip4_addr1(addr), ip4_addr2(addr), ip4_addr3(addr), 
                                            ip4_addr4(addr), port, msg);
        log_printer(tempstring);
        pl_transmitter(msg);
        pbuf_free(p); // frees the pbuffer
    }
}



void udp_receiver_init(){ // called in main
    receiver_pcb = udp_new(); // creates a struct (receiver_pcb) with ip port and callback func
    if (!receiver_pcb) {
        log_printer("Failed to create receiver PCB");
        return;
    }

    err_t err = udp_bind(receiver_pcb, IP_ADDR_ANY, LISTEN_PORT); // udp_bind() makes receiver pcb listen 
                                                                  // to this port on selected ip (any)
    // err_t is a lwip error type
    if (err != ERR_OK) {
        snprintf(tempstring, sizeof(tempstring),"UDP bind failed with error %d", err);
        log_printer(tempstring);
        return;
    }

    udp_recv(receiver_pcb, udp_receive_callback, NULL); // udp_recv calls udp_receive_callback 
                                                        // with all its parameters from receiver_pcb
    snprintf(tempstring, sizeof(tempstring),"UDP receiver initialized on port %d", LISTEN_PORT);
    log_printer(tempstring);
}



void general_initialization() {
    ip_addr_t ipaddr, netmask, gw; // declaration of 3 variables - ip_addr_t is a struct from lwIP
    log_printer("Starting lwIP UDP Receiver Example");

    IP4_ADDR(&ipaddr, 192, 168, 0, 27);    // board IP address
    IP4_ADDR(&netmask, 255, 255, 255, 0);  // subnet mask
    IP4_ADDR(&gw, 0, 0, 0, 0);             // gateway address

    lwip_init(); // lwIP function that initializes (resets internal data timers and protocols)
    struct netif *netif = &server_netif; // pointer to the global server_netif
                                        // will hold all information about the board network interface

    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) { // adds an ethernet mac interface to lwip
        log_printer("Error adding network interface");
        return;
    }

    netif_set_default(netif); // sets netif as the default network interface
    netif_set_up(netif); // marks the network interface as active

    snprintf(tempstring, sizeof(tempstring),"Link is %s", netif_is_link_up(netif) ? "up" : "down");
    log_printer(tempstring);
    print_ip("Board IP", &ipaddr);

    // initialize gpios
    XGpio_Initialize(&gpio, XPAR_XGPIO_0_BASEADDR);
    XGpio_SetDataDirection(&gpio, 1, 0x00);
    XGpio_SetDataDirection(&gpio, 2, 0x00);
    log_printer("GPIOs initialized");
}



int main() {
    general_initialization();
    log_printer("General Initialization function done");

    udp_receiver_init();
    log_printer("UDP Receiver Initalization function done");

    while (1) {
        xemacif_input(&server_netif); // checks for packets, puts it in pbuf and passes it down to netif
    }
    return 0;
}
