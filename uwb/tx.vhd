library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmitter is
    Port (
        MISO        : in  STD_LOGIC;
        MOSI        : out STD_LOGIC;
        CSn         : out STD_LOGIC;
        CURRENT_READ: out STD_LOGIC;
        SPICLOCK    : out STD_LOGIC;                         -- SPI clock (20 MHz)
        CLOCK       : in  STD_LOGIC;                        -- 100MHz system clock
        CLOCK_COUNT : out STD_LOGIC_VECTOR(2 downto 0);
        bit_count_out : out STD_LOGIC_VECTOR(5 downto 0);
        loop_count_out : out STD_LOGIC_VECTOR(2 downto 0);
        BUTTON      : in  STD_LOGIC;                        -- start button (trigger)
        DOUT        : out STD_LOGIC_VECTOR(39 downto 0)    -- data received from dw1000
        
        
    );
end transmitter;

architecture Behavioral of transmitter is
    type state_type is (
        IDLE,                   -- wait for flag
        SEND,            -- send command
        DELAY,                  -- 1 bit delay
        RECEIVE,         -- read 32 bits of data
        UPDATE,          -- update values and delay
        DONE                    -- finished equivalent of   while(1);
    );

    signal state          : state_type := IDLE;
    signal clock_counter  : integer range 0 to 4            := 0;       -- divide 100 MHz by 5 = 20 MHz
    signal CLOCK_reg      : std_logic                       := '0';
    signal bit_count      : integer range 0 to 255          :=0;
    signal data_vector    : std_logic_vector(39 downto 0)   := (others => '0' );
    signal loop_count     : integer range 0 to 6            :=0;

    constant read_id         : std_logic_vector(7 downto 0)  := "00000000";
    constant read_status_reg : std_logic_vector(7 downto 0)  := "00001111";
    constant write_buffer    : std_logic_vector(15 downto 0) := "1000100101011010"; -- data is 01011010 0x5A
    constant write_fctrl     : std_logic_vector(47 downto 0) := "100010000000001101000000000000100000000000000000"; -- 6.8MBPS 64MHZ
    constant read_fctrl      : std_logic_vector(7 downto 0)  := "00001000";
    constant write_sysctrl   : std_logic_vector(39 downto 0) := "0000110100000010000000000000000000000000";
    
    
    
begin

    process (CLOCK)
    begin
        CLOCK_COUNT <= std_logic_vector(to_unsigned(clock_counter, CLOCK_COUNT'length));
        SPICLOCK <= CLOCK_reg;
        loop_count_out <= std_logic_vector(to_unsigned(loop_count, loop_count_out'length));
        bit_count_out <= std_logic_vector(to_unsigned(bit_count, bit_count_out'length));
        
        if rising_edge(CLOCK) then
            if clock_counter = 4 then
                clock_counter <= 0;
            else
                clock_counter <= clock_counter + 1;
            end if;
            if clock_counter < 2 then
                CLOCK_reg <= '0';   -- SPI clock low for first half
            else
                CLOCK_reg <= '1';   -- SPI clock high for second half
            end if;



            if clock_counter = 0 then -- 20mhz falling edge used for launching data
            
                if state = IDLE then
                     CSn <= '1';
                     if BUTTON = '1' then
                        state <= SEND;
                        loop_count <= 0;
                     end if;
                        
                        
                elsif state = SEND then
                    CSn <= '0';
                    case loop_count is
                        when 0 =>
                            MOSI <= read_id(7 - bit_count);
                            if bit_count < 7 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= DELAY;
                            end if;
                        when 1 =>
                            MOSI <= read_status_reg(7 - bit_count);
                            if bit_count < 7 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= DELAY;
                            end if;
                        when 2 =>
                            MOSI <= write_buffer(15 - bit_count);
                            if bit_count < 15 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 3 =>
                            MOSI <= write_fctrl(47 - bit_count);
                            if bit_count < 47 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 4 =>
                            MOSI <= read_fctrl(7 - bit_count);
                            if bit_count < 7 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= DELAY;
                            end if;
                        when 5 =>
                            MOSI <= write_sysctrl(39 - bit_count);
                            if bit_count < 39 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 6 =>
                            MOSI <= read_status_reg(7 - bit_count);
                            if bit_count < 7 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= DELAY;
                            end if;
                    end case;
                end if;
            elsif clock_counter = 2 then -- 20mhz rising edge used for sampeling data
            
                if state = DELAY then
                    bit_count <= 0;
                    state <= RECEIVE;
                    
                    
                elsif state = RECEIVE then
                    data_vector(39 - bit_count) <= MISO;
                    CURRENT_READ                <= MISO;
                    case loop_count is
                        when 0 =>
                            if bit_count < 32 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 1 =>
                            if bit_count < 39 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 4 =>
                            if bit_count < 39 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when 6 =>
                            if bit_count < 39 then
                                bit_count <= bit_count + 1;
                            else
                                bit_count <= 0;
                                state <= UPDATE;
                            end if;
                        when others =>
                            bit_count <= 0;
                            state <= UPDATE;
                    end case;
                
                
                elsif state = UPDATE then
                    DOUT <= data_vector;
                    CSn <= '1';
                    if bit_count < 7 then
                        bit_count <= bit_count + 1;
                    else
                        bit_count <= 0;
                        state <= SEND;
                        if loop_count < 6 then
                            loop_count <= loop_count + 1;
                        else
                            state <= DONE;
                        end if;
                    end if;    
                end if;
            end if;
            
        end if;
        

    end process;

end Behavioral;

--      states of loop_count are
--        0 Read  ID              0x00 
--        1 Read  STATUS          0x0F
--        2 Write BUFFER          0x09
--        3 Write FRAME_CONTROL   0x08
--        4 Read  FRAME_CONTROL   0x08
--        5 Write SYSTEM_CONTROL  0x0D
--        6 Read  STATUS          0x0F
