library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_Transmitter is
    port(
        clk                : in  std_logic; -- 100MHZ
        cs_out             : out std_logic; -- drop to 0 to start exchange
        pol_out            : out std_logic; -- always 0
        pha_out            : out std_logic; -- always 0
        mosi_out           : out std_logic; -- byte to send
        btn                : in  std_logic; -- button pressed = start sending
        led                : out std_logic  -- led to test code
    );
end SPI_Transmitter;

architecture Behavioral of SPI_Transmitter is
    signal send_counter       : integer range 0 to 9              :=0; -- counter for data sending loop
    signal data_buffer        : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer for transmittion
    signal active             : boolean                           := false; -- true when sending data
    signal btn_prev           : std_logic                         := '0'; -- previous state of button
    signal clock_counter      : integer range 0 to 5              := 0; -- dividing 100MHZ to 20MHZ
begin
    pha_out <= '0';
    pol_out <= '0';
    process(clk)
        begin
        if rising_edge(clk) then
        
--     on button rising edge active <= true (stays true until is done transmitting)        
            if btn = '1' and btn_prev = '0' then
                active <= true;
                data_buffer <= "11111111";
            end if;
            btn_prev <= btn; -- save prev value
            
            
        
 --    clock divider 100MHZ to 20MHZ           
            if clock_counter = 5 then
                clock_counter <= 0;
                
                if active = true then       
                    cs_out <= '0';     
                    
--          byte send counter logic
                    if send_counter >= 8 then
                        mosi_out <= '0';
                        active <= false;
                        send_counter <= 0;
                    else
                        mosi_out <= data_buffer(7 - send_counter); -- MSB to LSB
                        send_counter <= send_counter + 1;
                    end if;
                else
                    cs_out <= '1';
                end if;

            else
                clock_counter <= clock_counter + 1;
            end if;
        end if;
    end process;
end Behavioral;
