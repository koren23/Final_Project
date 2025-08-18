library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_Transmitter is
    port(
--              ports for both transmitting and receiving
        clk                : in  std_logic;
        cs_out             : out std_logic;
        pol_out            : out std_logic;
        pha_out            : out std_logic;
--              ports for transmitting
        mosi_out           : out std_logic;
        start_sending_in   : in  std_logic;
        data_in            : in  std_logic_vector(7 downto 0); -- data coming from ethernet
--              ports for receiving
        miso_in            : in  std_logic;
        data_out           : out std_logic_vector(7 downto 0); -- feedback data to LOG  
        data_received_flag : out std_logic
    );
end SPI_Transmitter;

architecture Behavioral of SPI_Transmitter is
--          signals for transmitting
    type send_states_type is(reset_tx, send); -- states of sending
    signal statetx            : send_states_type                  := reset_tx;
    signal data_send_counter  : integer range 0 to 7              :=0; -- counter for data receiving loop
    signal output_data_buffer : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer tp save data before sending
    signal active             : boolean                           := false;
    
    type recv_states_type is(reset_rx, recv); -- states of receiving
    signal staterx            : recv_states_type                  := reset_rx;
    signal data_recv_counter  : integer range 0 to 7              :=0; -- counter for data receiving loop
    signal input_data_buffer  : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer to save data from feedback
    signal receiving_data     : boolean                           := false; -- flag saying MOSI is dont sending and is looking fr feedback
    
begin
    process(clk)
        begin
        if rising_edge(clk) then
            pha_out <= '0';
            pol_out <= '0';
            data_received_flag <= '0'; -- done sending flag activated for one clock pulse
        
            if start_sending_in = '1' then
                active <= true;
            end if;
        
            if receiving_data then
                case staterx is
                    when reset_rx =>
                        data_recv_counter <= 0;
                        staterx <= recv;
                        
                    when recv =>
                        if data_recv_counter = 8 then
                            receiving_data <= false;
                            data_out <= input_data_buffer;
                            data_received_flag <= '1';
                            cs_out <= '1';
                            staterx <= reset_rx;
                        else 
                            input_data_buffer(data_recv_counter) <= miso_in;
                            data_recv_counter <= data_recv_counter + 1;
                        end if;
                    
                end case;
            end if;    
    
            if active then                
                case statetx is
                    when reset_tx =>
                        cs_out <= '0'; -- starts exchanging with dw1000 
                        output_data_buffer <= data_in; -- save data in buffer so it wont change while sending
                        data_send_counter <= 0; -- reset the bit location counter
                        statetx <= send; -- move to the next state
                        
                    when send =>
                        if data_send_counter = 8 then -- done sending data
                            statetx <= reset_tx;
                            receiving_data <= true;
                        else   
                            mosi_out <= output_data_buffer(data_send_counter);
                            data_send_counter <= data_send_counter + 1;
                        end if;
                    
                end case;
    
            end if;        
        
            
            
            
        end if;
    end process;
end Behavioral;
