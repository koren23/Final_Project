#include "xparameters.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "sleep.h"
#include <stdio.h>
#include <stdint.h> 
#include <time.h>
#include <math.h>
#include "lwip/init.h"
#include "lwip/udp.h"
#include "lwip/ip_addr.h"
#include "lwip/pbuf.h"
#include "netif/xadapter.h"



#define LISTEN_PORT 12345 // (can be changed)
#define BRAM_START   0x40000000 
#define BRAM_END     0x4000000F // (actual addr goes to 0x40000FFF)
#define BRAM_WORDS   ((BRAM_END - BRAM_START + 1) / 4) // (Bytes num)/(Bytes per Word)
#define GPIO_OUTPUT_CHANNEL 1
#define GPIO_INPUT_CHANNEL  2

#define MAP_PIXEL_X_MIN 29 
#define MAP_PIXEL_X_MAX 322
#define MAP_PIXEL_Y_MIN 29 
#define MAP_PIXEL_Y_MAX 446
#define MAP_LAT_MIN_DEG 29.475544 
#define MAP_LAT_MAX_DEG 33.364086
#define MAP_LON_MIN_DEG 33.738858
#define MAP_LON_MAX_DEG 36.086421
#define MAP_VERTICAL_METERS   432000.0
#define MAP_HORIZONTAL_METERS 218000.0



volatile uint32_t *bram = (uint32_t *)BRAM_START;
uint32_t previous[BRAM_WORDS]; 
XGpio Gpio;
struct udp_pcb *receiver_pcb; // udp_pcb contains port num, local_ip etc                  
struct netif server_netif; // netif contains  ip subnet gateway mac etc
u8_t mac_address[6] = {0x00, 0x18, 0x3E, 0x04, 0x81, 0xD6};



volatile void nextion_sender(char str[]) { 
    int len = strlen(str);
    for(int i=0;i<len;i++){
        bram[0]=str[i];
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x3); // Nextion start flag
        XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0); // Idle flag
        while(XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL) != 0x2){ // Nextion Done flag
            xil_printf("Bit %d of %s failed, current value is %d\n",i, str, XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL));
            usleep(1000000);
        }
        usleep(300);
    }
}



void drawPixel(int pixelX, int pixelY) {
    if(pixelX < MAP_PIXEL_X_MIN || pixelX > MAP_PIXEL_X_MAX) return;
    if(pixelY < MAP_PIXEL_Y_MIN || pixelY > MAP_PIXEL_Y_MAX) return;

    char commandBuffer[32];
    sprintf(commandBuffer, "cirs %d,%d,1,RED", pixelX, pixelY);
    nextion_sender(commandBuffer);
    nextion_sender("\xFF\xFF\xFF");
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
        if (decisionParameter < 0)
            decisionParameter += (2 * currentYOffset) + 1;
        else {
            currentXOffset--;
            decisionParameter += (2 * (currentYOffset - currentXOffset)) + 1;
        }
    }
}



void format_timestamp(int32_t timestamp, char *buffer, size_t buffer_size) { 
    time_t raw_time = (time_t)(long)timestamp;
    raw_time += 2 * 3600;
    struct tm *tm_info = gmtime(&raw_time); 
    int year   = tm_info->tm_year + 1900; //counts time since 1900
    int month  = tm_info->tm_mon + 1;
    int day    = tm_info->tm_mday;
    int hour   = tm_info->tm_hour;
    int minute = tm_info->tm_min;
    int second = tm_info->tm_sec;

    snprintf(buffer, buffer_size, "%02d/%02d/%04d %02d:%02d:%02d", day, month, year, hour, minute, second);
}



void pl_transmitter(char msg[256]) {
    int32_t currtime, imptime;
    int32_t latval, longval; 
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

    char currstr[32];
    format_timestamp(currtime, currstr, sizeof(currstr));
    char impstr[32];
    format_timestamp(imptime, impstr, sizeof(impstr));

    usleep(10);
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x1);
    bram[0] = currtime;
    xil_printf("Current time:\t%s\n", currstr);     

    usleep(10);
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x2);
    bram[0] = imptime;
    xil_printf("Impact time:\t%s\n", impstr);

    usleep(10);
    for (int i = 0; i < BRAM_WORDS; i++) 
        bram[i] = 0x00000000;
    u32 radius;
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x6); // ADC START
    while(XGpio_DiscreteRead(&Gpio, GPIO_INPUT_CHANNEL) != 0x1); // ADC done
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0);
    for (int i = 0; i < BRAM_WORDS; i++) {
        previous[i] = bram[i];
        if(i==1)
            radius = previous[i];
    }

    usleep(10);
	for (int i = 0; i < BRAM_WORDS; i++)
        bram[i] = 0x00000000;
    xil_printf("Radius:\t%u\n", radius);

    usleep(10);
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x4);
    bram[0] = latval;
    double latitudeDegrees = (double)latval * 180.0 / 2147483647.0; // 2147483647 = 2^31 - 1

    while(latitudeDegrees > 90){latitudeDegrees = latitudeDegrees - 180;} 
    while(latitudeDegrees < - 90){latitudeDegrees = latitudeDegrees + 180;}
    int numlat = (int)latitudeDegrees;
    int declat = (int)(fabs(latitudeDegrees - numlat) * 1000);
    xil_printf("latitude value: %d.%03d\n", numlat, declat);
    
    usleep(10);
    XGpio_DiscreteWrite(&Gpio, GPIO_OUTPUT_CHANNEL, 0x5);
    bram[0] = longval;
    double longitudeDegrees = (double)longval * 180.0 / 2147483647.0; // 2147483647 = 2^31 - 1

    while(longitudeDegrees > 180){longitudeDegrees = longitudeDegrees - 180;}
    while(longitudeDegrees < 0){longitudeDegrees = longitudeDegrees + 180;}
    u32 numlong = (int)longitudeDegrees;
    u32 declong = (int)(fabs(longitudeDegrees - numlong) * 1000);
    xil_printf("longitude value: %d.%d\n",numlong,declong);

    usleep(10);
    nextion_sender("\xFF\xFF\xFF");
    nextion_sender("page 0");
    nextion_sender("\xFF\xFF\xFF");
    usleep(300);

    char nxtn_curt[] = "curt.txt=\"";
    nextion_sender(nxtn_curt);
    nextion_sender(currstr);
    nextion_sender("\"\xFF\xFF\xFF");
    usleep(300);

    char nxtn_impt[] = "impt.txt=\"";
    nextion_sender(nxtn_impt);
    nextion_sender(impstr);
    nextion_sender("\"\xFF\xFF\xFF");
    usleep(300);

    char nxtn_radius[] = "radius.txt=\"";
    char radiusvalue[255]; 
    sprintf(radiusvalue, "%u", radius);
    nextion_sender(nxtn_radius);
    nextion_sender(radiusvalue);
    nextion_sender("\"\xFF\xFF\xFF");
    usleep(300);

    char nxtn_location[] = "landmark.txt=\"";
    char latbuffer[255]; 
    char longbuffer[255]; 
    sprintf(latbuffer, "%d.%03d", numlat, declat);
    sprintf(longbuffer, "%d.%d", numlong, declong);
    nextion_sender("\xFF\xFF\xFF");
    nextion_sender(nxtn_location);
    nextion_sender(latbuffer);
    nextion_sender(",");
    nextion_sender(longbuffer);
    nextion_sender("\"\xFF\xFF\xFF");

    float mapWidth  = MAP_PIXEL_X_MAX - MAP_PIXEL_X_MIN; 
    float mapHeight = MAP_PIXEL_Y_MAX - MAP_PIXEL_Y_MIN;
    float target_lon = numlong + 0.001 * declong;
    float target_lat = numlat + 0.001 * declat;
    int pixelX = MAP_PIXEL_X_MIN + (int)(mapWidth  * (target_lon - MAP_LON_MIN_DEG) / (MAP_LON_MAX_DEG - MAP_LON_MIN_DEG));
    int pixelY = MAP_PIXEL_Y_MIN + (int)(mapHeight * (MAP_LAT_MAX_DEG - target_lat) / (MAP_LAT_MAX_DEG - MAP_LAT_MIN_DEG));
    float radius_pixels = radius * 0.5 * ((mapHeight / MAP_VERTICAL_METERS) + (mapWidth / MAP_HORIZONTAL_METERS)); // average of ratios
    int radiusfinal = (int)radius_pixels;

    xil_printf("Pixel coordinates: X=%d Y=%d, Radius=%d\n", pixelX, pixelY, radiusfinal);
    char commandBuffer[32];
    if(pixelX >= MAP_PIXEL_X_MIN && pixelX <= MAP_PIXEL_X_MAX && pixelY >= MAP_PIXEL_Y_MIN && pixelY <= MAP_PIXEL_Y_MAX) {
        sprintf(commandBuffer, "cirs %d,%d,5,BLACK", pixelX, pixelY);
        nextion_sender(commandBuffer);
        nextion_sender("\xFF\xFF\xFF");
    }
    drawCircle(pixelX, pixelY, radiusfinal);
    xil_printf("Data uploaded to PL ^_^\n");
}



void udp_receive_callback(void *arg, struct udp_pcb *pcb, struct pbuf *p, const ip_addr_t *addr, u16_t port) {
    (void)arg;
    (void)pcb;

    if (p != NULL) {
        char msg[256] = {0}; 
        size_t len;
        if (p->len < sizeof(msg) - 1)
            len = p->len;
        else
            len = sizeof(msg) - 1;

        memcpy(msg, p->payload, len);
        msg[len] = '\0';
        xil_printf("Received from %d.%d.%d.%d:%d -> %s\n", ip4_addr1(addr), ip4_addr2(addr), 
                                                           ip4_addr3(addr), ip4_addr4(addr), port, msg);
        pl_transmitter(msg);
        pbuf_free(p);
    }
}



void udp_receiver_init() {
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



void print_ip(const char *msg, ip_addr_t *ip) {
    xil_printf("%s: %d.%d.%d.%d\n", msg, ip4_addr1(ip), ip4_addr2(ip),ip4_addr3(ip), ip4_addr4(ip));
}



void general_initialization() {
    ip_addr_t ipaddr, netmask, gw;
    xil_printf("Starting lwIP UDP Receiver Example\n");

    IP4_ADDR(&ipaddr, 169, 254, 87, 100);
    IP4_ADDR(&netmask, 255, 255, 0, 0);
    IP4_ADDR(&gw, 0, 0, 0, 0);
    lwip_init(); 
    struct netif *netif = &server_netif;

    if (!xemac_add(netif, &ipaddr, &netmask, &gw, mac_address, 0xe000b000)) {
        xil_printf("Error adding network interface\n");
        return;
    }

    netif_set_default(netif);
    netif_set_up(netif);
    xil_printf("Link is %s", netif_is_link_up(netif) ? "up\n" : "down\n");
    print_ip("Board IP", &ipaddr);

    XGpio_Initialize(&Gpio, 0);
    XGpio_SetDataDirection(&Gpio, GPIO_OUTPUT_CHANNEL, 0x0);
    XGpio_SetDataDirection(&Gpio, GPIO_INPUT_CHANNEL,  0xFFFFFFFF);
    xil_printf("GPIOs initialized\n");
    		
}



void init_bram() {
    xil_printf("=== Initial BRAM contents (%d words) ===\n", BRAM_WORDS);
    for (int i = 0; i < BRAM_WORDS; i++) {
        previous[i] = bram[i];
        xil_printf("0x%08X : 0x%08X\n", (unsigned int)(BRAM_START + i * 4),previous[i]);
    }
} 



int main() {
    init_bram();
    general_initialization();
    xil_printf("General Initialization function done\n");

    udp_receiver_init();
    xil_printf("UDP Receiver Initalization function done\n");

    while (1) {
        xemacif_input(&server_netif);
    }
    return 0;
}
