library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity Nextion is
    port (
        clk      : in std_logic;
        tx       : out std_logic;
        flag     : in std_logic;
        databyte : in std_logic_vector(7 downto 0);
        flagout  : out std_logic
    );
end Nextion;

architecture Behavioral of Nextion is
    type statetype is (idle, start, data, stop);
    signal state              : statetype                    := idle;
    signal counter            : integer range 0 to 2047      := 0;
    signal tempbyte           : std_logic_vector(7 downto 0):= (others => '0');
    signal bit_counting_value : integer                      := 100e6/115200;
    signal bit_number         : integer range 0 to 7         := 0;
    signal flag_prev          : std_logic                    := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            case state is
            
                when idle =>
                    flagout <= '0';
                    if flag = '1' and flag_prev = '0' then
                        tempbyte <= databyte;
                        state <= start;
                    else
                        tx <= '1';
                    end if;                    
                    flag_prev <= flag;
                    
                when start =>
                        state <= data;
                        Bit_number <= 0;
                        counter <= 0;
                        tx <= '0';
                   
                when data =>
                     if counter = bit_counting_value then
                        tx <= tempbyte(bit_number);
                        counter <= 0;
                        if bit_number = 7 then
                            state <= stop;
                        else
                            bit_number <= bit_number + 1;
                        end if;
                    else
                        counter <= counter + 1;
                    end if;
                    
                    
                when stop =>
                
                    if counter = 2*bit_counting_value then
                        state <= idle;
                        flagout <= '1';
                        counter <= 0;
                    else
                        counter <= counter +1;
                    end if;
                    if counter >= bit_counting_value then
                        tx <= '1';
                    end if;

            end case;
        end if;
    end process;
end Behavioral;


