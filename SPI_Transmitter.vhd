    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    
    entity SPI_Transmitter is
        port(
            clk                : in  std_logic; -- 100MHZ
            mosi_out           : out std_logic; -- byte to send
            ready_in           : in  std_logic;  -- handshake with CTRL
            valid_out          : out std_logic;
            bytedone           : out std_logic
--            din                : in  std_logic_vector(7 downto 0) -- data
        );
    end SPI_Transmitter;
    
    architecture Behavioral of SPI_Transmitter is
        signal data_buffer        : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer for transmittion
        signal active             : boolean                           := false; -- true when sending data
        signal ready_prev         : std_logic                         := '0'; -- previous state of ready
        signal clock_counter      : integer range 0 to 4              := 0; -- dividing 100MHZ to 20MHZ
        signal bit_counter        : integer range 0 to 8              :=0; -- counter inside byte
        signal byte_counter       : integer range 0 to 13             :=0; -- counter between bytes
        signal current_byte       : std_logic_vector(7 downto 0)      := (others => '0');
        type tx_arrayt is array (0 to 12) of std_logic_vector(7 downto 0); -- array of all the register data need to send 
        signal tx_array : tx_arrayt  := ("11001001", "00000000", "00000000", "10001000","00000011", -- last one here is TFLEN aka length + 2 
        "00000000", "00000000", "00000000", "10001101", "00000010", "00000000",  "00000000", "00000000");
    
    begin
        process(clk)
            begin
            
            if rising_edge(clk) then
    --     on ready rising edge active <= true (stays true until is done transmitting)        
                if ready_in = '1' and ready_prev = '0' then
                    active <= true;
                    tx_array(2) <= "10100101"; -- insert data into array
                    bit_counter <= 0;
                    byte_counter <= 0;
                end if;
                ready_prev <= ready_in; -- save prev value
                
     --    clock divider 100MHZ to 20MHZ          
                if clock_counter = 4 then
                    clock_counter <= 0;
                    if active then
                        if bit_counter = 0 then
                            current_byte <= tx_array(byte_counter);
                            mosi_out <= current_byte(7 - bit_counter);
                            bit_counter <= 1;
                        elsif bit_counter < 8 then
                            
                            mosi_out <= current_byte(7 - bit_counter);
                            bit_counter <= bit_counter + 1;
                        else
                            
                            bit_counter <= 0;
                            byte_counter <= byte_counter + 1;
                            bytedone <= '1';
                            if byte_counter = 12 then
                                active <= false;
                                valid_out <= '1';
                                byte_counter <= 0;
                            end if;
                        end if;               
                    end if;
                 else
                    valid_out <= '0';
                    clock_counter <= clock_counter + 1;
                    bytedone <= '0';
                end if;
                
            end if;
        end process;
    end Behavioral;

