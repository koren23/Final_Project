    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    
    entity SPI_Transmitter is
        generic (
            TFLEN       : std_logic_vector(7 downto 0) :="00000011"; -- number of bytes plus 2
            data_count  : integer := 1
    
        );
        port(
            clk                : in  std_logic; -- 100MHZ
            mosi_out           : out std_logic; -- byte to send
            ready_in           : in  std_logic;  -- handshake with CTRL
            valid_out          : out std_logic;
            din                : in  std_logic_vector(7 downto 0) -- data
        );
    end SPI_Transmitter;
    
    architecture Behavioral of SPI_Transmitter is
        signal data_buffer        : std_logic_vector(7 downto 0)      := (others => '0'); -- buffer for transmittion
        signal active             : boolean                           := false; -- true when sending data
        signal ready_prev         : std_logic                         := '0'; -- previous state of ready
        signal clock_counter      : integer range 0 to 5              := 0; -- dividing 100MHZ to 20MHZ
        constant array_length     : integer                           := data_count + 12; 
        signal bit_counter        : integer range 0 to 8              :=0; -- counter inside byte
        signal byte_counter       : integer range 0 to array_length   :=0; -- counter between bytes
        signal current_byte       : std_logic_vector(7 downto 0)      := (others => '0');
        type tx_arrayt is array (0 to array_length - 1) of std_logic_vector(7 downto 0); -- array of all the register data need to send 
        signal tx_array : tx_arrayt  := ("11001001", "00000000", "00000000", "10001000", TFLEN , "00000000", "00000000", "00000000", "10001101", "00000010", "00000000",  "00000000", "00000000");
    
    begin
        process(clk)
            begin
            if rising_edge(clk) then
                valid_out <= '0';
    --     on ready rising edge active <= true (stays true until is done transmitting)        
                if ready_in = '1' and ready_prev = '0' then
                    active <= true;
                    tx_array(2) <= din; -- insert data into array
                end if;
                ready_prev <= ready_in; -- save prev value
    
     --    clock divider 100MHZ to 20MHZ           
                if clock_counter = 5 then
                    clock_counter <= 0;
                    if active = true then         
                        if byte_counter < array_length + 1 then -- to tell what byte im sending
                            current_byte <= tx_array(byte_counter);
                            if bit_counter < 8 then -- to tell what bit of that byte to send
                                mosi_out <= current_byte(bit_counter);
                                bit_counter <= bit_counter + 1;    
                            else
                                byte_counter <= byte_counter + 1;
                            end if;
                        else -- reset everything and end transmittion
                            active <= false;
                            valid_out <= '1';
                            bit_counter <= 0;
                            byte_counter <= 0;
                        end if;
                    end if;
                else
                    clock_counter <= clock_counter + 1;
                end if;
                
            end if;
        end process;
    end Behavioral;
