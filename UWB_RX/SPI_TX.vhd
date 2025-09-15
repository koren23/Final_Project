    library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
    
    entity SPI_Transmitter is
        generic(
            data_length        : integer := 1
        );
        port(
            clk                : in		std_logic; -- 100MHZ
            mosi_out           : out 	std_logic; -- byte to send
            ready_in           : in  	std_logic; -- handshake with rx 
            valid_out          : out 	std_logic;
            rx_data            : in 	std_logic_vector(7 downto 0);
            rx_data_count      : out 	std_logic_vector(7 downto 0);
            rx_current_count   : in 	std_logic_vector(7 downto 0);
			button	   		   : in		std_logic
        );
    end SPI_Transmitter;
    
     architecture Behavioral of SPI_Transmitter is
				type states is (startbutton,config, waitstatus, readlength, readdata, clear);
        signal currentstate       : states                            :=	startbutton;
        signal clock_counter      : integer range 0 to 4              :=	0; -- dividing 100MHZ to 20MHZ
        signal bit_counter        : integer range 0 to 7              :=	0; -- counter inside byte
        signal byte_counter       : integer range 0 to 6              :=	0; -- counter between bytes
        signal ready_prev         : std_logic                         :=	'0';
        signal active             : boolean                           :=	false; -- used to save rising edge value
        signal movestateflag      : boolean                           :=	false; -- to only move state when finished receiving data
        signal frame_length       : integer range 0 to 128            :=	0;
        signal button_prev		  : std_logic						  :=	'0';
        signal reversed_data      : std_logic_vector(7 downto 0);
        
        	type variablesizedarray is array (0 to data_length) of std_logic_vector(7 downto 0);
		signal data_array : variablesizedarray;
		
        	type array6bytes is array (0 to 5) of std_logic_vector(7 downto 0);
        signal config_commands : array6bytes    := (
                "10001101", -- write operation (SYS_CTRL)
                "00000000", -- Sub-address
                "00000000", -- 
                "00000000", -- 
                "00000001", -- RXENAB bit
                "00000000" -- 
        );
        
		signal readstatus 		  : std_logic_vector(7 downto 0) 	  :=	"00001111";
        signal readlen			  : std_logic_vector(7 downto 0) 	  :=	"00010000";
        signal readdatacommand	  : std_logic_vector(7 downto 0)	  :=	"00010001";
		
        signal clear_commands : array6bytes      := (
                "10001111", --  Write to 0x0F
                "11111111", -- 
                "11111111", -- 
                "11110111", -- 
                "11111111", -- 
                "00000111"  -- 
        );
        
        
        
    begin
        process(clk)
        begin
            if rising_edge(clk) then
 --    clock divider 100MHZ to 20MHZ          
                if clock_counter = 4 then -- work 1/5 of the 100mhz clock supplied = 20mhz
                    clock_counter <= 0;
                    
                    
                     case currentstate is
						when startbutton => -- on button rising edge go to config
							if button = '1' and button_prev = '0' then
								currentstate <= config;
							end if;
							button_prev <= button; -- update signal
							
							
                        when config => -- recv 5 bytes for SYS_CTRL register
                            if bit_counter = 0 then -- loop for 8 bits
                                mosi_out <= config_commands(byte_counter)(7);
                                bit_counter <= 1;
                            elsif bit_counter < 7 then
                                mosi_out <= config_commands(byte_counter)(7 - bit_counter);
                                bit_counter <= bit_counter + 1;
                            else
                                mosi_out <= config_commands(byte_counter)(0);
                                bit_counter <= 0;
                                byte_counter <= byte_counter + 1;
                                if byte_counter = 6 then -- loops for 6 bytes
                                    byte_counter <= 0;
                                    currentstate <= waitstatus;
                                end if;
                            end if;               
                    
                    
                        when waitstatus => -- 0x0F read SYS_STATUS expect 5 bytes
                                           -- check if 2nd byte has bit 7 set RXFCG
                            if ready_in = '1' and ready_prev = '0' then -- rising edge receiver handshake
                                active <= true;
                            end if;
                            
                            if active then
                                if to_integer(unsigned(rx_current_count)) = 4 then
                                    valid_out <= '0';
                                    active <= false;
                                    if movestateflag then --if theres data move on
                                        currentstate <= readlength;
                                        movestateflag <= false;
                                    end if;
                                elsif to_integer(unsigned(rx_current_count)) = 3 then -- check for data status
                                    if rx_data(1) = '1' then
                                        movestateflag <= true;
                                    end if;
                                end if;
                            else -- keep sending byte till active
                                if bit_counter = 0 then
                                    mosi_out <= readstatus(7);
                                    bit_counter <= 1;
                                elsif bit_counter < 7 then
                                    mosi_out <= readstatus(7 - bit_counter);
                                    bit_counter <= bit_counter + 1;
                                else
                                    mosi_out <= readstatus(0);
                                    bit_counter <= 0;
                                    valid_out <= '1';
                                    rx_data_count <= "00000101";
                                end if;
                            end if;
                            
                            
                        when readlength => -- 0x10 read RX_FINFO expect 4 bytes
                                           -- bits 0-6 of 1st byte are the frame length
                            if ready_in = '1' and ready_prev = '0' then -- rising edge receiver handshake
                                active <= true;
                            end if;
                            
                            if active then
                                for i in 0 to 7 loop
                                    reversed_data(i) <= rx_data(7 - i);
                                end loop;
                                if to_integer(unsigned(rx_current_count)) = 0 then
                                    valid_out <= '0';
                                    active <= false;
                                    currentstate <= readdata;
                                elsif to_integer(unsigned(rx_current_count)) = 3 then
                                    
                                    frame_length <= to_integer(unsigned(reversed_data(6 downto 0)));
                                end if;
                            else
                                if bit_counter = 0 then -- loop till active
                                    mosi_out <= readlen(7);
                                    bit_counter <= 1;
                                elsif bit_counter < 7 then
                                    mosi_out <= readlen(7 - bit_counter);
                                    bit_counter <= bit_counter + 1;
                                else
                                    mosi_out <= readlen(7 - bit_counter);
                                    bit_counter <= 0;
                                    valid_out <= '1';
                                    rx_data_count <= "00000100"; -- expect 4 bytes
                                end if;
                            end if;
                        
                        
                        when readdata => -- 0x11 read  RX_BUFFER expect X amount of bytes based on te result of readlength
                            if ready_in = '1' and ready_prev = '0' then
                                active <= true;
                            end if;
                            
                            if active then
                                for i in 0 to 7 loop
                                    reversed_data(i) <= rx_data(7 - i);
                                end loop;
                                if to_integer(unsigned(rx_current_count)) = frame_length then
                                    valid_out <= '0';
                                    active <= false;
                                    currentstate <= clear;
                                elsif to_integer(unsigned(rx_current_count)) < frame_length - 2 then
                                    data_array(to_integer(unsigned(rx_current_count))) <= reversed_data;
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
									rx_data_count <= std_logic_vector(to_unsigned(frame_length, 8));
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
                                if byte_counter = 6 then
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
