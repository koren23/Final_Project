    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    
    entity SPI_Transmitter is
        port(
            clk                : in  std_logic; -- 100MHZ
            mosi_out           : out std_logic; -- byte to send
            ready_in           : in  std_logic;  -- handshake
            valid_out          : out std_logic;
            din                : in  std_logic_vector(7 downto 0); -- data
            cs1                : out std_logic
        );
    end SPI_Transmitter;
    
    architecture Behavioral of SPI_Transmitter is
        signal active             : boolean                           := false; -- true when sending data
        signal ready_prev         : std_logic                         := '0'; -- previous state of ready
        signal clock_counter      : integer range 0 to 4              := 0; -- dividing 100MHZ to 20MHZ
        signal bit_counter        : integer range 0 to 7              :=0; -- counter inside byte
        signal byte_counter       : integer range 0 to 13             :=0; -- counter between bytes
        type tx_arrayt is array (0 to 14) of std_logic_vector(7 downto 0); -- array of all the register data need to send 
        signal tx_array : tx_arrayt  := ( -- 7 being msb 
        "11001001", --  7 write 6 sub address included 5-0 address of TX_BUFFER register
        "00000000", -- start at the beginning of the buffer
        "00000000", -- data     edited in process
            
        "11001000", -- write, sub-address included, reg = 0x08 (TX_FCTRL)
        "00000000", -- sub-address = 0
        "00000011", -- frame length = 3 bytes
        "00000000", -- default TX settings
        "00000010", -- enable 64 MHz SPI (required)
        "00000000", -- no extended frame
            
        "11001101", -- Write, sub-address included, reg = 0x0D (SYS_CTRL)
        "00000000", -- Sub-address = 0
        "00000010", -- Set TXSTRT bit
        "00000000", -- reserved
        "00000000", -- reserved
        "00000000");-- reserved
    
    begin
        process(clk)
            begin
            if rising_edge(clk) then
    --     on ready rising edge active <= true (stays until done transmitting)        
                if ready_in = '1' and ready_prev = '0' then
                    active <= true;
                    tx_array(2) <= din; -- insert data into array
                    bit_counter <= 0;
                    byte_counter <= 0;
                end if;
                ready_prev <= ready_in; -- save prev value
                
     --    clock divider 100MHZ to 20MHZ          
                if clock_counter = 4 then
                    clock_counter <= 0;
                    if active then
                        cs1 <= '0';
                        if bit_counter = 0 then
                            mosi_out <= tx_array(byte_counter)(7);
                            bit_counter <= 1;
                        elsif bit_counter < 7 then
                            mosi_out <= tx_array(byte_counter)(7 - bit_counter);
                            bit_counter <= bit_counter + 1;
                        else
                            mosi_out <= tx_array(byte_counter)(7 - bit_counter);
                            bit_counter <= 0;
                            byte_counter <= byte_counter + 1;
                            if byte_counter = 12 then
                                active <= false;
                                valid_out <= '1';
                                byte_counter <= 0;
                            end if;
                        end if;               
                    end if;
                 else
                    cs1 <= '1';
                    valid_out <= '0';
                    clock_counter <= clock_counter + 1;
                end if;
                
                
                
            end if;
        end process;
    end Behavioral;
