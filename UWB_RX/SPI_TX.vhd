    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    
    entity SPI_Transmitter is
        generic(
            data_length        : integer := 1
        );
        port(
            clk                : in  std_logic; -- 100MHZ
            mosi_out           : out std_logic; -- byte to send
            ready_in           : in  std_logic; -- handshake with rx 
            valid_out          : out std_logic;
            rx_data            : in std_logic_vector(7 downto 0);
            rx_data_count      : out std_logic_vector(7 downto 0);
            rx_current_count   : in std_logic_vector(7 downto 0)
        );
    end SPI_Transmitter;
    
    architecture Behavioral of SPI_Transmitter is
        type states is (config, waitstatus, readlength, readdata, clear);
        signal currentstate       : states                            := config;
        signal clock_counter      : integer range 0 to 4              := 0; -- dividing 100MHZ to 20MHZ
        signal bit_counter        : integer range 0 to 7              :=0; -- counter inside byte
        signal byte_counter       : integer range 0 to 6              :=0; -- counter between bytes
        signal ready_prev         : std_logic                         := '0';
        signal active             : boolean                           :=false; -- used to save rising edge value
        signal movestateflag      : boolean                           :=false; -- to only move state when finished receiving data
        signal frame_length       : integer range 0 to 128            :=0;
        type variablesizedarray is array (0 to data_length) of std_logic_vector(7 downto 0);
        signal data_array : variablesizedarray;
        type array5bytes is array (0 to 4) of std_logic_vector(7 downto 0);
        type array6bytes is array (0 to 5) of std_logic_vector(7 downto 0);
        signal config_commands : array5bytes    := (
                "10001101", -- 
                "00000001", -- 
                "00000000", -- 
                "00000000", -- 
                "00000000" -- 
        );
        signal clear_commands : array6bytes      := (
                "10001111", -- 
                "10000000", -- 
                "00000000", -- 
                "00000000", -- 
                "00000000", -- 
                "00000000"  -- 
        );
        signal readstatus : std_logic_vector(7 downto 0) := "00001111";
        signal readlen : std_logic_vector(7 downto 0) := "00010000";
        signal readdatacommand : std_logic_vector(7 downto 0) := "00010001";
		
        
    begin
        process(clk)
        begin
            if rising_edge(clk) then
            
 --    clock divider 100MHZ to 20MHZ          
                if clock_counter = 4 then
                    clock_counter <= 0; 
                    
                    
                     case currentstate is
                        when config => -- 5 bytes for SYS_CTRL register
                            if bit_counter = 0 then
                                mosi_out <= config_commands(byte_counter)(7);
                                bit_counter <= 1;
                            elsif bit_counter < 7 then
                                mosi_out <= config_commands(byte_counter)(7 - bit_counter);
                                bit_counter <= bit_counter + 1;
                            else
                                mosi_out <= config_commands(byte_counter)(7 - bit_counter);
                                bit_counter <= 0;
                                byte_counter <= byte_counter + 1;
                                if byte_counter = 4 then
                                    byte_counter <= 0;
                                    currentstate <= waitstatus;
                                end if;
                            end if;               
                    
                    
                        when waitstatus => -- 0x0F read SYS_STATUS expect 5 bytes
                                           -- check if 2nd byte has bit 7 set RXFCG
                            if ready_in = '1' and ready_prev = '0' then
                                active <= true;
                            end if;
                            
                            if active then
                                if to_integer(unsigned(rx_current_count)) = 4 then
                                    valid_out <= '0';
                                    active <= false;
                                    if movestateflag then
                                        currentstate <= readlength;
                                        movestateflag <= false;
                                    end if;
                                elsif to_integer(unsigned(rx_current_count)) = 2 then
                                    if rx_data(6) = '1' then
                                        movestateflag <= true;
                                    end if;
                                end if;
                            else
                                if bit_counter = 0 then
                                    mosi_out <= readstatus(7);
                                    bit_counter <= 1;
                                elsif bit_counter < 7 then
                                    mosi_out <= readstatus(7 - bit_counter);
                                    bit_counter <= bit_counter + 1;
                                else
                                    mosi_out <= readstatus(7 - bit_counter);
                                    bit_counter <= 0;
                                    valid_out <= '1';
                                    rx_data_count <= "00000101";
                                end if;
                            end if;
                            
                            
                        when readlength => -- 0x10 read RX_FINFO expect 4 bytes
                                           -- bits 0-6 of 1st byte are the frame length
                            if ready_in = '1' and ready_prev = '0' then
                                active <= true;
                            end if;
                            
                            if active then
                                if to_integer(unsigned(rx_current_count)) = 3 then
                                    valid_out <= '0';
                                    active <= false;
                                    currentstate <= readdata;
                                elsif to_integer(unsigned(rx_current_count)) = 0 then
                                    frame_length <= to_integer(unsigned(rx_data(6 downto 0)));
                                end if;
                            else
                                if bit_counter = 0 then
                                    mosi_out <= readlen(7);
                                    bit_counter <= 1;
                                elsif bit_counter < 7 then
                                    mosi_out <= readlen(7 - bit_counter);
                                    bit_counter <= bit_counter + 1;
                                else
                                    mosi_out <= readlen(7 - bit_counter);
                                    bit_counter <= 0;
                                    valid_out <= '1';
                                    rx_data_count <= "00000100";
                                end if;
                            end if;
                        
                        
                        when readdata => -- 0x11 read  RX_BUFFER expect X amount of bytes based on te result of readlength
                            if ready_in = '1' and ready_prev = '0' then
                                active <= true;
                            end if;
                            
                            if active then
                                if to_integer(unsigned(rx_current_count)) = frame_length - 1 then
                                    valid_out <= '0';
                                    active <= false;
                                        currentstate <= clear;
                                elsif receiver_counter < frame_length - 3 then
                                    data_array(to_integer(unsigned(rx_current_count))) <= rx_data;
                                end if;
                            else
                                if bit_counter = 0 then
                                    mosi_out <= readdatacommand(7);
                                    bit_counter <= 1;
                                elsif bit_counter < 7 then
                                    mosi_out <= readdatacommand(7 - bit_counter);
                                    bit_counter <= bit_counter + 1;
                                else
                                    mosi_out <= readdatacommand(7 - bit_counter);
                                    bit_counter <= 0;
                                    valid_out <= '1';
									rx_data_count <= std_logic_vector(to_unsigned(frame_length, 8))(7 downto 0);
                                end if;
                            end if;
                    
                    
                        when clear => -- 6 bytes to SYS_STATUS register
							if bit_counter = 0 then
                                mosi_out <= clear_commands(byte_counter)(7);
                                bit_counter <= 1;
                            elsif bit_counter < 7 then
                                mosi_out <= clear_commands(byte_counter)(7 - bit_counter);
                                bit_counter <= bit_counter + 1;
                            else
                                mosi_out <= clear_commands(byte_counter)(7 - bit_counter);
                                bit_counter <= 0;
                                byte_counter <= byte_counter + 1;
                                if byte_counter = 4 then
                                    byte_counter <= 0;
                                    currentstate <= waitstatus;
                                end if;
                            end if;  
                    
                    end case;
                    
                 else
                    clock_counter <= clock_counter + 1;
                end if;
                
                
                ready_prev <= ready_in;
            end if;
        end process;
    end Behavioral;
