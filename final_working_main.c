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
#include "xgpio.h"
#include <math.h>

#define LISTEN_PORT 12345 // port chosen - needs to be changed
#define BUFFER_SIZE 4096 // log max size
#define Max_Size_Per_Message 256 // log max size per message
#define BRAM_START   0x40000000 // start address of bram
#define BRAM_END     0x4000000F // end address of bram (i set it so i only see the first words)
#define BRAM_WORDS   ((BRAM_END - BRAM_START + 1) / 4) // (number of bytes in bram)/(number of bytes per word)
#define GPIO_OUTPUT_CHANNEL 1
#define GPIO_INPUT_CHANNEL  2
#define PIXEL_X_MIN 29
#define PIXEL_X_MAX 322
#define PIXEL_Y_MIN 29
#define PIXEL_Y_MAX 446
#define LAT_MIN 29.475544
#define LAT_MAX 33.364086
#define LON_MIN 33.738858
#define LON_MAX 36.086421
#define VERTICAL_METERS   432000.0
#define HORIZONTAL_METERS 218000.0

volatile uint32_t *bram = (uint32_t *)BRAM_START; // declare bram pointer to the memory address (bram start) volatile means it wont cache it bcs it changes
uint32_t previous[BRAM_WORDS]; // previous is an array that saves the bram values
XGpio Gpio;
struct udp_pcb *receiver_pcb; // receiver_pcb points to a udp_pcb - contains port num local-ip
                        // it points to a callback function that activates when receiving data                    
struct netif server_netif; // server_netif points to netif (contains  ip subnet gateway mac etc)
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6}; // artyz7-10 mac address

volatile void nextion_send(char str[]) {
    int len = strlen(str);
    for(int i=0;i<len;i++){
        bram[0]=str[i];
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x3);
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0);
        while(XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL) != 0x2){
            xil_printf("Bit %d of %s failed, current value is %d\n",i, str, XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL));
            usleep(1000000);
        }
        usleep(300);
    }
}
void drawPixel(int pixelX, int pixelY) {
    if(pixelX < PIXEL_X_MIN || pixelX > PIXEL_X_MAX) return;
    if(pixelY < PIXEL_Y_MIN || pixelY > PIXEL_Y_MAX) return;

    char commandBuffer[32];
    sprintf(commandBuffer, "cirs %d,%d,1,RED", pixelX, pixelY);
    nextion_send(commandBuffer);
    nextion_send("\xFF\xFF\xFF");
}
void drawCircle(int centerX, int centerY, int circleRadius) {
    int currentXOffset = circleRadius;
    int currentYOffset = 0;
    int decisionParameter = 1 - circleRadius;

    while (currentXOffset >= currentYOffset) {
        drawPixel(centerX + currentXOffset, centerY + currentYOffset);
        drawPixel(centerX + currentYOffset, centerY + currentXOffset);
        drawPixel(centerX - currentYOffset, centerY + currentXOffset);
        drawPixel(centerX - currentXOffset, centerY + currentYOffset);
        drawPixel(centerX - currentXOffset, centerY - currentYOffset);
        drawPixel(centerX - currentYOffset, centerY - currentXOffset);
        drawPixel(centerX + currentYOffset, centerY - currentXOffset);
        drawPixel(centerX + currentXOffset, centerY - currentYOffset);

        currentYOffset++;
        if (decisionParameter < 0){
            decisionParameter += (2 * currentYOffset) + 1;
        }
        else{
            currentXOffset--;
            decisionParameter += (2 * (currentYOffset - currentXOffset)) + 1;
        }
    }
}
void print_ip(const char *msg, ip_addr_t *ip) { // gets called in general_initialization
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip), 
                                       ip4_addr3(ip), ip4_addr4(ip));
}



void format_timestamp(int32_t timestamp, char *buffer, size_t buffer_size) { // convert unix data to time
    // called in pl_transmitter
    time_t raw_time = (time_t)(long)timestamp; // converts the value of timestamp to long and to time_t (for gmtime)
    raw_time += 2 * 3600;

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

void nextion_sender(char str[]){
    int len = strlen(str);
    for(int i=0;i<len;i++){
        bram[0]=str[i];
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x3);
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0);
        while(XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL) != 0x2){
            xil_printf("Bit %d of %s failed, current value is %d\n",i, str, XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL));
            usleep(1000000);
        }
        usleep(300);
    }
}

void pl_transmitter(char msg[256]){ // called in udp_receive_callback
    int32_t currtime, imptime;
    int32_t latval, longval; 
    
    //split msg to currtime imptime latval and longval
    memcpy(&currtime, msg, 4);
    memcpy(&imptime, msg + 4, 4);
    memcpy(&latval, msg + 8, 4);
    memcpy(&longval, msg + 12, 4);
    
    xil_printf("dec current time before reversing bytes %d\n",currtime);
    xil_printf("dec impact time before reversing bytes %d\n",imptime);
    
    latval = ntohl(latval);
    longval = ntohl(longval);
    currtime = ((currtime & 0xFF) << 24) | ((currtime & 0xFF00) << 8) | ((currtime & 0xFF0000) >> 8) | ((currtime >> 24) & 0xFF);
    imptime = ((imptime & 0xFF) << 24) | ((imptime & 0xFF00) << 8) | ((imptime & 0xFF0000) >> 8) | ((imptime >> 24) & 0xFF);
    xil_printf("current time post transformation %d\n",currtime);
    xil_printf("impact timepost transformation %d\n",imptime);

    char bytesFF[] = { 0xFF, 0xFF, 0xFF, '\0' };
    char endquote[] = "\"";

    

    usleep(10);

    char currstr[32];
    format_timestamp(currtime, currstr, sizeof(currstr));// convert unix to display time

    char impstr[32];
    format_timestamp(imptime, impstr, sizeof(impstr));// convert unix to display time

    xil_printf("cur2 %d\n",currstr);
    xil_printf("imp2 %d\n",impstr);

    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x1);
    bram[0] = currtime;
    xil_printf("Current time:\t%s\n", currstr);     

    usleep(10);

    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x2);
    bram[0] = imptime;
    xil_printf("Impact time:\t%s\n", impstr);

    usleep(10);

    for (int i = 0; i < BRAM_WORDS; i++) { // reset bram
        bram[i] = 0x00000000;
    }
    u32 radius;
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x6); // send command to ADC
    while(XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL) != 0x1); // ADC done
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0);
    for (int i = 0; i < BRAM_WORDS; i++) {
        previous[i] = bram[i];
        if(i==1){
            radius = previous[i];
            xil_printf("radius read from bram: %d\n", previous[i]);
        }
    }
    usleep(10);
	for (int i = 0; i < BRAM_WORDS; i++) { // reset bram
        bram[i] = 0x00000000;
    }
    xil_printf("Radius:\t%u\n", radius);

    usleep(10);

    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x4);
    bram[0] = latval;
    double latitudeDegrees = (double)latval * 180.0 / 2147483647.0;
    while(latitudeDegrees > 90){latitudeDegrees = latitudeDegrees - 180;}
    while(latitudeDegrees < - 90){latitudeDegrees = latitudeDegrees + 180;}
    int numlat = (int)latitudeDegrees;
    int declat = (int)(fabs(latitudeDegrees - numlat) * 1000);
    xil_printf("latitude value: %d.%03d\n", numlat, declat);
    
    usleep(10);

    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x5);
    bram[0] = longval;
    double longitudeDegrees = (double)longval * 180.0 / 2147483647.0;
    while(longitudeDegrees > 180){longitudeDegrees = longitudeDegrees - 180;}
    while(longitudeDegrees < 0){longitudeDegrees = longitudeDegrees + 180;}
    u32 numlong = (int)longitudeDegrees;
    u32 declong = (int)(fabs(longitudeDegrees - numlong) * 1000);
    xil_printf("longitude value: %d.%d\n",numlong,declong);

    usleep(10);

    char page0[] = "page 0";
    nextion_sender(bytesFF);
    nextion_sender(page0);
    nextion_sender(bytesFF);
    usleep(300);
    char nxtn_curt[] = "curt.txt=\"";
    nextion_sender(bytesFF);
    nextion_sender(nxtn_curt);
    nextion_sender(currstr);
    nextion_sender(endquote);
    nextion_sender(bytesFF);
    usleep(300);
    char nxtn_impt[] = "impt.txt=\"";
    nextion_sender(bytesFF);
    nextion_sender(nxtn_impt);
    nextion_sender(impstr);
    nextion_sender(endquote);
    nextion_sender(bytesFF);
    usleep(300);
    char nxtn_radius[] = "radius.txt=\"";
    char radiusvalue[255]; 
    sprintf(radiusvalue, "%u", radius);
    nextion_sender(bytesFF);
    nextion_sender(nxtn_radius);
    nextion_sender(radiusvalue);
    nextion_sender(endquote);
    nextion_sender(bytesFF);
    usleep(300);
    char nxtn_location[] = "landmark.txt=\"";
    char comma[] = ",";
    char latbuffer[255]; 
    char longbuffer[255]; 
    sprintf(latbuffer, "%d.%03d", numlat, declat);
    sprintf(longbuffer, "%d.%d", numlong, declong);
    nextion_sender(bytesFF);
    nextion_sender(nxtn_location);
    nextion_sender(latbuffer);
    nextion_sender(comma);
    nextion_sender(longbuffer);
    nextion_sender(endquote);
    nextion_sender(bytesFF);

    float mapWidth  = PIXEL_X_MAX - PIXEL_X_MIN; 
    float mapHeight = PIXEL_Y_MAX - PIXEL_Y_MIN;
    float target_lon = numlong + 0.001 * declong;
    float target_lat = numlat + 0.001 * declat;
    int pixelX = PIXEL_X_MIN + (int)(mapWidth  * (target_lon - LON_MIN) / (LON_MAX - LON_MIN));
    int pixelY = PIXEL_Y_MIN + (int)(mapHeight * (LAT_MAX - target_lat) / (LAT_MAX - LAT_MIN));
    float radius_pixels = radius * 0.5 * ((mapHeight / VERTICAL_METERS) + (mapWidth / HORIZONTAL_METERS));
    int radiusfinal = (int)radius_pixels;
    xil_printf("Pixel coordinates: X=%d Y=%d, Radius=%d\n", pixelX, pixelY, radiusfinal);
    char commandBuffer[32];
    if(pixelX >= PIXEL_X_MIN && pixelX <= PIXEL_X_MAX &&
       pixelY >= PIXEL_Y_MIN && pixelY <= PIXEL_Y_MAX)
    {
        sprintf(commandBuffer, "cirs %d,%d,5,BLACK", pixelX, pixelY);
        nextion_send(commandBuffer);
        nextion_send("\xFF\xFF\xFF");
    }
    drawCircle(pixelX, pixelY, radiusfinal);
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

    XGpio_Initialize(&Gpio, 0);
    XGpio_SetDataDirection(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0); // all outputs
    XGpio_SetDataDirection(&Gpio, GPIO_INPUT_CHANNEL,  0xFFFFFFFF); // all inputs
    xil_printf("GPIOs initialized\n");
    		
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
