library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_Receiver is
    port(
        clk                : in  std_logic; -- 100MHZ
        miso_in            : in std_logic; -- feedback from dw1000
        ready_in           : in  std_logic; 
        valid_out          : out std_logic;
        dout               : out std_logic_vector(7 downto 0);
        cs2                 : out std_logic
    );
end SPI_Receiver;

architecture Behavioral of SPI_Receiver is
    signal recv_counter       : integer range 0 to 8              :=0;
    signal data_buffer        : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer for receiving data
    signal active             : boolean                           := false; -- true when receiving data
    signal ready_prev         : std_logic                         := '0'; -- previous state of ready can be removed later
    signal clock_counter      : integer range 0 to 4              := 0; -- dividing 100MHZ to 20MHZ
begin
    process(clk)
        begin
        if rising_edge(clk) then
            valid_out <= '0';
--     on ready rising edge active <= true (stays true until is done receiving)        
            if ready_in = '1' and ready_prev = '0' then
                active <= true;
            end if;
            ready_prev <= ready_in; -- save prev value
            
 --    clock divider 100MHZ to 20MHZ           
            if clock_counter = 4 then
                clock_counter <= 0;
                
                if active = true then         
 --          byte recv counter logic
                    cs2 <= '0';
                    if recv_counter < 7 then
                        data_buffer(7 - recv_counter) <= miso_in; -- MSB to LSB
                        recv_counter <= recv_counter + 1;
                    else
                        data_buffer(7 - recv_counter) <= miso_in; -- MSB to LSB
                        recv_counter <= 0;
                        active <= false;
                        valid_out <= '1';
                        dout <= data_buffer;
                    end if;
                else
                    cs2 <= '1';
                end if;

            else
                clock_counter <= clock_counter + 1;
            end if;            
            
        end if;
    end process;    

end Behavioral;
