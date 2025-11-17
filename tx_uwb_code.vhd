library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmitter is
    Port (
        MISO        : in  STD_LOGIC;
        MOSI        : out STD_LOGIC;
        CSn         : out STD_LOGIC;
        SPICLOCK    : out STD_LOGIC;                         -- SPI clock (10 MHz)
        LED         : out STD_LOGIC;
        CLOCK       : in  STD_LOGIC;                         -- 100MHz system clock
        BUTTON      : in  STD_LOGIC;                         -- start button (trigger)
        DOUT        : out STD_LOGIC_VECTOR(39 downto 0)      -- data received from dw1000
    );
end transmitter;

architecture Behavioral of transmitter is
-- state machine
    type state_type is (
        IDLE,            -- wait for button
        DELAY,           -- delay
        SEND_BYTE,       -- send 1 byte
        RECEIVE,
        DONE,
        WAIT_FOR_BUTTON
    );
    signal state          : state_type := IDLE;
    
    -- signals for delay    
    signal delay_counter  : integer := 0;
    signal delay_target   : integer := 0;
    signal return_state   : state_type := IDLE;
    
    signal clock_counter  : integer range 0 to 9            := 0;       -- divide 100 MHz by 10 = 10 MHz
    signal bit_count      : integer range 0 to 255          :=0;
    signal current_byte   : std_logic_vector(7 downto 0)    := (others => '0' );
    signal init_count     : integer range 0 to 7            :=0;
    signal write_loop_cnt : integer range 0 to 5            :=0;
    
    signal data_vector    : std_logic_vector(39 downto 0)   := (others => '0' );
    signal resetMOSI      : boolean    := false;
    signal loop_check     : boolean :=false; -- used to create a delay when cs=1
    signal write          : boolean :=false;
    
    type twobyte_array is array (0 to 1) of std_logic_vector(7 downto 0);
    type fivebyte_array is array (0 to 4) of std_logic_vector(7 downto 0);
    type sixbyte_array is array (0 to 5) of std_logic_vector(7 downto 0);
    constant    read_id_reg      : STD_LOGIC_VECTOR(7 downto 0)  :="00000000";
    constant    read_status_reg  : STD_LOGIC_VECTOR(7 downto 0)  :="00001111";
    constant    write_buffer_reg : twobyte_array   := ("10001001", "01011010");
    constant    write_fctrl      : fivebyte_array := ("10001000", "00000011", "01000000", "00000010", "00000000");
    constant    write_sysctrl    : fivebyte_array := ("10001101", "00000010", "00000000", "00000000", "00000000");
    constant    clear_status_reg : sixbyte_array := ("10001111", "11110000", "00000000", "00000000", "00000000", "00000000");

    function delay_done(
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
            case init_count is
                when 0 =>
                    current_byte <= read_id_reg;
                    write <= false;
                when 1 => 
                    current_byte <= read_status_reg;
                    write <= false;
                when 2 =>
                    current_byte <= write_buffer_reg(write_loop_cnt);
                    write <= true;
                when 3 =>
                    current_byte <= write_fctrl(write_loop_cnt);
                    write <= true;
                when 4 =>
                    current_byte <= write_sysctrl(write_loop_cnt);
                    write <= true;
                when 5 =>
                    current_byte <= read_status_reg;
                    write <= false;
                when 6 =>
                    current_byte <= clear_status_reg(write_loop_cnt);
                    write <= true;
                when 7 =>
                    current_byte <= read_status_reg;
                    write <= false;
            end case;
             ------------------------------------  
            case state is
             ------------------------------------ 
                when IDLE =>            -- cs=1 until button pressed then mosi=reg(msb), go to delay 3clks
                    CSn <= '1';
                    LED <= '0';
                    if BUTTON = '1' then
                        CSn <= '0';
                        init_count <= 0;
                        MOSI <= current_byte(7); -- send last bit
                        resetMOSI <= false;
                        
                        delay_target <= 3; -- call delay func
                        return_state <= SEND_BYTE;
                        state <= DELAY;
                    end if;
            ------------------------------------
                when DELAY =>           -- call delay function check if counter reached limit, return to next state.
                    if resetMOSI <= false then
                        MOSI <= '0';
                        resetMOSI <= true;
                    else
                        MOSI <= current_byte(7);
                    end if;
                    if delay_done(delay_counter, delay_target) then
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
                            case init_count is
                                when 2 =>
                                    if write_loop_cnt = 1 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 3 =>
                                    if write_loop_cnt = 4 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 4 =>
                                    if write_loop_cnt = 4 then
                                        write_loop_cnt <= 0;
                                        return_state <= DONE;
                                    end if;
                                when 6 =>
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
                        if init_count < 5 then
                            init_count <= init_count + 1;
                        else
                            if init_count = 5 then
                                if data_vector = "1111001000000000100000000000001000000000" then -- 0xf200800200     data is transmitted
                                    LED <= '1';
                                    init_count <= init_count + 1;
                                end if;
                            elsif init_count = 6 then
                                init_count <= init_count + 1;
                            elsif init_count = 7 then
--                                state <= WAIT_FOR_BUTTON;
--                                init_count <= 0;
                            end if;
                            
                        end if;
                    end if;
            ------------------------------------
                when WAIT_FOR_BUTTON =>
                    if BUTTON = '0' then
                        state <= idle;
                        init_count <= 0;
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
