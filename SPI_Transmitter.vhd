library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_Transmitter is
    port(
        clk                : in  std_logic; -- 100MHZ
        mosi_out           : out std_logic; -- byte to send
        ready_in           : in  std_logic; 
        valid_out          : out std_logic;
        din                : in  std_logic_vector(7 downto 0)
    );
end SPI_Transmitter;

architecture Behavioral of SPI_Transmitter is
    signal send_counter       : integer range 0 to 9              :=0;
    signal data_buffer        : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer for transmittion
    signal active             : boolean                           := false; -- true when sending data
    signal ready_prev         : std_logic                         := '0'; -- previous state of ready can be removed later
    signal clock_counter      : integer range 0 to 5              := 0; -- dividing 100MHZ to 20MHZ
begin
    process(clk)
        begin
        if rising_edge(clk) then
            valid_out <= '0';
--     on ready rising edge active <= true (stays true until is done transmitting)        
            if ready_in = '1' and ready_prev = '0' then
                active <= true;
                data_buffer <= din;
            end if;
            ready_prev <= ready_in; -- save prev value
            
            
        
 --    clock divider 100MHZ to 20MHZ           
            if clock_counter = 5 then
                clock_counter <= 0;
                
                if active = true then         
                  
--          byte send counter logic
                    if send_counter >= 8 then
                        mosi_out <= '0';
                        active <= false;
                        send_counter <= 0;
                        valid_out <= '1';
                    else
                        mosi_out <= data_buffer(7 - send_counter); -- MSB to LSB
                        send_counter <= send_counter + 1;
                    end if;
                end if;

            else
                clock_counter <= clock_counter + 1;
            end if;
        end if;
    end process;
end Behavioral;
