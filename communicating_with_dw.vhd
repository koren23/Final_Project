library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity transmitter is
    generic (
        read_id_reg : STD_LOGIC_VECTOR(7 downto 0)  :="00001111"
    );
    Port (
        MISO        : in  STD_LOGIC;
        MOSI        : out STD_LOGIC;
        CSn         : out STD_LOGIC;
        SPICLOCK    : out STD_LOGIC;                         -- SPI clock (10 MHz)
        
        CLOCK       : in  STD_LOGIC;                        -- 100MHz system clock
        BUTTON      : in  STD_LOGIC;                        -- start button (trigger)
        DOUT        : out STD_LOGIC_VECTOR(39 downto 0)    -- data received from dw1000
    );
end transmitter;

architecture Behavioral of transmitter is
-- state machine
    type state_type is (
        IDLE,            -- wait for button
        DELAY,           -- delay
        SEND_BYTE,       -- send 1 byte
        RECEIVE,
        DONE
    );
    signal state          : state_type := IDLE;
    
    
    signal clock_counter  : integer range 0 to 9            := 0;       -- divide 100 MHz by 10 = 10 MHz
    signal bit_count      : integer range 0 to 255          :=0;
    signal current_byte   : std_logic_vector(7 downto 0)    := (others => '0' );
    signal data_vector    : std_logic_vector(39 downto 0)   := (others => '0' );
-- signals for delay    
    signal delay_counter : integer := 0;
    signal delay_target  : integer := 0;
    signal return_state  : state_type := IDLE;
    signal resetMOSI     : boolean    := false;
    
    signal loop_check          : boolean :=false; -- used to create a delay when cs=1
    
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
        case state is
         ------------------------------------ 
            when IDLE =>            -- cs=1 until button pressed then mosi=reg(msb), go to delay 3clks
                CSn <= '1';
                if BUTTON = '1' then
                    CSn <= '0';
                    MOSI <= read_id_reg(7); -- send last bit
                    
                    resetMOSI <= false;
                    current_byte <= read_id_reg;
                    delay_target <= 3; -- call delay func
                    return_state <= SEND_BYTE;
                    state <= DELAY;
                end if;
        ------------------------------------
            when DELAY =>           -- call delay function check if counter reached limit, return to next state.
                if resetMOSI <= true then
                    MOSI <= '0';
                else
                    resetMOSI <= true;
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
                    return_state <= RECEIVE;
                    data_vector <= (others => '0' );
                end if;
        ------------------------------------
             when RECEIVE =>
                if bit_count < 32 then
                    if clock_counter = 0 then --  rising edge clock
                        SPICLOCK <= '1';
                        data_vector(31 - bit_count) <= MISO;    -- enter data to vector
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
                end if;
        ------------------------------------
            
        end case;
        end if;
        

    end process;

end Behavioral;


--  when reading a reg it goes
--  idle => delay => send_byte => delay => receive => delay
--  when writing data to a reg its
--  idle => delay => (send byte => delay)x5 => delay
