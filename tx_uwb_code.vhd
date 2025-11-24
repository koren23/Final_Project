library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmitter is
    Port (
        MISO        : in  STD_LOGIC;
        MOSI        : out STD_LOGIC;
        CSn         : out STD_LOGIC;
        SPICLOCK    : out STD_LOGIC;                         -- SPI clock (10 MHz)
        LED         : out STD_LOGIC;                         -- indicates data transmitted
        CLOCK       : in  STD_LOGIC;                         -- 100MHz system clock
        START       : in  STD_LOGIC_vector(2 downto 0);      -- starts tx
        DOUT        : out STD_LOGIC_VECTOR(39 downto 0);     -- data received from dw1000 SPI
        DIN         : in  STD_LOGIC_VECTOR(31 downto 0)      -- data to transmit
    );
end transmitter;

architecture Behavioral of transmitter is
-- state machine
    type state_type is (
        IDLE,
        DELAY,           -- delay
        SEND_BYTE,       -- send 8 bits
        RECEIVE,         -- receive 32 bits
        DONE,            -- update init_count
        WAIT_FOR_START, -- done initializing if start - send data
        WRITE_TO_BUFFER  -- save data to buffer data array
    );
    signal state          : state_type := IDLE;
    
    -- signals for delay    
    signal delay_counter  : integer := 0;
    signal delay_target   : integer := 0;
    signal return_state   : state_type := IDLE;

    -- counters    
    signal clock_counter  : integer range 0 to 9            := 0;       -- divide 100 MHz by 10 = 10 MHz
    signal bit_count      : integer range 0 to 255          :=0;
    signal current_byte   : std_logic_vector(7 downto 0)    := (others => '0' );
    signal init_count     : integer range 0 to 15           :=0;
    signal write_loop_cnt : integer range 0 to 255          :=0;
    signal buffer_counter : integer range 0 to 20           :=0;
    
    -- booleans
    signal resetMOSI      : boolean    := false;
    signal loop_check     : boolean :=false; -- used to create a delay when cs=1
    signal write          : boolean :=false;
    
    -- data vectors and arrays
    signal din_temp       : std_logic_vector(151 downto 0)  := (others => '0' );
    signal data_vector    : std_logic_vector(39 downto 0)   := (others => '0' );
    type twobyte_array is array (0 to 1) of std_logic_vector(7 downto 0);
    type threebyte_array is array (0 to 2) of std_logic_vector(7 downto 0);
    type fourbyte_array is array (0 to 3) of std_logic_vector(7 downto 0);
    type fivebyte_array is array (0 to 4) of std_logic_vector(7 downto 0);
    type sixbyte_array is array (0 to 5) of std_logic_vector(7 downto 0);
    type twentybyte_array is array (0 to 19) of std_logic_vector(7 downto 0);
    constant    read_id_reg      : STD_LOGIC_VECTOR(7 downto 0) :="00000000";
    constant    read_status_reg  : STD_LOGIC_VECTOR(7 downto 0) :="00001111";
    constant    AGC_TUNE1        : fourbyte_array               := ("11100011", "00000100", "01110000", "10001000");
    constant    AGC_TUNE2        : sixbyte_array                := ("11100011", "00001100", "00000111", "10101001", "00000010", "00100101");
    constant    DRX_TUNE2        : sixbyte_array                := ("11100111", "00001000", "01010010", "00000000", "00011010", "00110011");
    constant    LDE_CFG2         : fivebyte_array               := ("11101110", "10000110", "00110000", "00000111", "00010110");
    constant    write_power_ctrl : sixbyte_array                := ("11011110", "00000000", "01001000", "00101000", "00001000", "00001110");
    constant    RF_TXCTRL        : sixbyte_array                := ("11101000", "00001100", "11100011", "00111111", "00011110", "00000000");
    constant    TC_PGDELAY       : threebyte_array              := ("11101010", "00001011", "11000000");
    constant    FS_PLLTUNE       : threebyte_array              := ("11101011", "00001011", "10111110");                                                             
    signal      write_buffer_reg : twentybyte_array             := ("10001001", "00000000", "00000000", "00000000", "00000000", 
                                                                    "00000000", "00000000", "00000000", "00000000", "00000000", 
                                                                    "00000000", "00000000", "00000000", "00000000", "00000000", 
                                                                    "00000000", "00000000", "00000000", "00000000", "00000000");                                            
    constant    write_fctrl      : fivebyte_array               := ("10001000", "00010101", "01000000", "00010101", "00000000");
    constant    write_sysctrl    : fivebyte_array               := ("10001101", "00000010", "00000000", "00000000", "00000000");
    constant    clear_status_reg : sixbyte_array                := ("10001111", "11110000", "00000000", "00000000", "00000000", "00000000");
    
    function delay_done( -- checked when delay to know if delay = done
        counter : integer;
        target  : integer
    ) return boolean is
    begin
        return (counter >= target);
    end function;
    
begin

    process (CLOCK)
    begin
    
        if rising_edge(CLOCK) then
             ------------------------------------ 
            case init_count is -- give current_byte a value based on init_count and set write value
                when 0 =>
                    current_byte <= read_id_reg;
                    write <= false;
                when 1 => 
                    current_byte <= read_status_reg;
                    write <= false;
                when 2 =>
                    current_byte <= AGC_TUNE1(write_loop_cnt);
                    write <= true;
                when 3 =>
                    current_byte <= AGC_TUNE2(write_loop_cnt);
                    write <= true;
                when 4 =>
                    current_byte <= DRX_TUNE2(write_loop_cnt);
                    write <= true;
                when 5 =>
                    current_byte <= LDE_CFG2(write_loop_cnt);
                    write <= true;
                when 6 =>
                    current_byte <= write_power_ctrl(write_loop_cnt);
                    write <= true;
                when 7 =>
                    current_byte <= RF_TXCTRL(write_loop_cnt);
                    write <= true;
                when 8 =>
                    current_byte <= TC_PGDELAY(write_loop_cnt);
                    write <= true;
                when 9 =>
                    current_byte <= FS_PLLTUNE(write_loop_cnt);
                    write <= true;

                    
                -- start transmittion
                when 10 =>
                    current_byte <= write_buffer_reg(write_loop_cnt);
                    write <= true;
                when 11 =>
                    current_byte <= write_fctrl(write_loop_cnt);
                    write <= true;
                when 12 =>
                    current_byte <= write_sysctrl(write_loop_cnt);
                    write <= true;
                when 13 => -- loops around until flag is right
                    current_byte <= read_status_reg;
                    write <= false;
                when 14 =>
                    current_byte <= clear_status_reg(write_loop_cnt);
                    write <= true;
                when 15 =>
                    current_byte <= read_status_reg;
                    write <= false;
                
            end case;
             ------------------------------------  
            case state is
             ------------------------------------ 
                when IDLE =>         
                    LED <= '0';
                        CSn <= '0';
                        resetMOSI <= false;
                        init_count <= 0;
                        MOSI <= current_byte(7); -- send last bit
                        
                        delay_target <= 3; -- call delay func
                        return_state <= SEND_BYTE;
                        state <= DELAY;
            ------------------------------------
                when DELAY =>
                    if resetMOSI <= false then
                        MOSI <= '0';
                        resetMOSI <= true;
                    else
                        MOSI <= current_byte(7);
                    end if;
                    if delay_done(delay_counter, delay_target) then -- call delay func
                        delay_counter <= 0;
                        state <= return_state;
                    else
                        delay_counter <= delay_counter + 1;
                    end if;
            ------------------------------------ 
                when SEND_BYTE =>
                    if bit_count < 8 then
                        if clock_counter = 0 then --  rising edge clock
                            SPICLOCK <= '1';
                        elsif clock_counter = 4 then -- falling edge clock
                            SPICLOCK <= '0';
                            MOSI <= current_byte(6 - bit_count);
                        elsif clock_counter = 9 then
                            bit_count <= bit_count + 1;
                        end if;
                        clock_counter <= clock_counter + 1;    
                        if clock_counter = 9 then -- reset counter
                            clock_counter <= 0;
                        end if;
                    else
                        bit_count <= 0; -- reset counters
                        clock_counter <= 0;
                        
                        -- go to delay 4clks then receive
                        delay_target <= 4;
                        state <= DELAY;
                        SPICLOCK <= '0';
                        if write = false then
                            return_state <= RECEIVE;
                        else
                            write_loop_cnt <= write_loop_cnt + 1;
                            return_state <= SEND_BYTE;
                            case init_count is -- set loop count for transmittion
                                when 2 =>
                                    if write_loop_cnt = 3 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 3 =>
                                    if write_loop_cnt = 5 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 4 =>
                                    if write_loop_cnt = 5 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 5 =>
                                    if write_loop_cnt = 4 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 6 =>
                                    if write_loop_cnt = 5 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 7 =>
                                    if write_loop_cnt = 5 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 8 =>
                                    if write_loop_cnt = 2 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 9 =>
                                    if write_loop_cnt = 2 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 10 =>
                                    if write_loop_cnt = 19 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 11 =>
                                    if write_loop_cnt = 4 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 12 =>
                                    if write_loop_cnt = 4 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 14 =>
                                    if write_loop_cnt = 5 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when others =>
                                
                            end case;
                        end if;
                        data_vector <= (others => '0' );
                    end if;
            ------------------------------------
                 when RECEIVE =>
                    if bit_count < 32 then
                        if clock_counter = 0 then --  rising edge clock
                            SPICLOCK <= '1';
                            data_vector(39 - bit_count) <= MISO;    -- enter data to vector
                        elsif clock_counter = 4 then -- falling edge clock
                            SPICLOCK <= '0';
                        elsif clock_counter = 9 then
                            bit_count <= bit_count + 1;
                        end if;
                        clock_counter <= clock_counter + 1;    
                        if clock_counter = 9 then -- reset counter
                            clock_counter <= 0;
                        end if;
                    else
                        bit_count <= 0; -- reset counters
                        clock_counter <= 0;
                        SPICLOCK <= '0';
                        dout <= data_vector;
                        -- go to delay 4clks then receive
                        delay_target <= 4;
                        state <= DELAY;
                        return_state <= DONE;
                    end if;
            ------------------------------------
                when DONE => -- go to delay once then back to operation
                    if loop_check = false then -- start a loop
                        CSn <= '1';
                        delay_target <= 4;
                        state <= DELAY;
                        return_state <= DONE;
                        loop_check <= true;
                    else            -- go to delay => send_byte, etc
                        CSn <= '0';
                        loop_check <= false; 
                        delay_target <= 3; -- call delay func
                        return_state <= SEND_BYTE;
                        state <= DELAY;
                        write_loop_cnt <= 0;
                        if init_count < 10 then
                            if init_count = 9 then
                                return_state <= WAIT_FOR_START;
                            end if;
                            init_count <= init_count + 1;
                            
                        else
                            if init_count = 13 then
                                if data_vector = "1111001000000000100000000000001000000000" then -- 0xf200800200     data is transmitted
                                    LED <= '1';
--                                    init_count <= init_count + 1;
                                end if;
                            elsif init_count = 15 then
                                return_state <= WAIT_FOR_START;
                            else
                                init_count <= init_count + 1;
                            end if;
                            
                        end if;
                    end if;
            ------------------------------------
                when WAIT_FOR_START =>
                    CSn <= '1';
                    case START is
                        when "000" =>
                            state <= WRITE_TO_BUFFER;
                            buffer_counter <= 0;
                        when "001" => -- time now
                            DIN_TEMP(151 downto 120) <= din_temp;
                        when "010" => -- time of impact
                            DIN_TEMP(119 downto 88) <= din_temp;
                        when "011" => -- radius
                        
                        
                                -- not set yet
                                
                                
                        when "100" => -- latidue
                            DIN_TEMP(63 downto 32) <= din_temp;
                        when "101" => -- longitude
                            DIN_TEMP(31 downto 0) <= din_temp;
                    
                    end case;
            ------------------------------------
                when WRITE_TO_BUFFER =>
                    if buffer_counter = 19 then
                        init_count <= 10;
                        CSn <= '0';
                        MOSI <= current_byte(7); -- send last bit
                        resetMOSI <= false;
                        delay_target <= 3; -- call delay func
                        return_state <= SEND_BYTE;
                        state <= DELAY;
                        
                    else
                        write_buffer_reg(buffer_counter + 1) <= din_temp((8*(buffer_counter+1)) -1 downto 8*buffer_counter);
                        buffer_counter <= buffer_counter + 1;
                    end if;
            ------------------------------------
            end case;
        end if;
        

    end process;

end Behavioral;


--  when reading a reg it goes
--  delay => send_byte => delay => receive => delay
--  when writing data to a reg its
--  delay => (send byte => delay)x5 => delay
