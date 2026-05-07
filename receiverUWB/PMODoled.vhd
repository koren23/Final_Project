library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity SPI_OLED is
    Port ( CLOCK : in STD_LOGIC;
           GPIO1 : in STD_LOGIC_VECTOR (2 downto 0);
           GPIO2 : in STD_LOGIC_VECTOR (1 downto 0);
           GPIO_DATA : in STD_LOGIC_VECTOR (7 downto 0);
           
           GPIO3 : out STD_LOGIC;
           
           RESET : out STD_LOGIC;
           VDDC : out STD_LOGIC;
           VBATC : out STD_LOGIC;
           DC : out STD_LOGIC;
           
           CS : out STD_LOGIC;
           MOSI : out STD_LOGIC;
           SCLK : out STD_LOGIC);
           
end SPI_OLED;
architecture Behavioral of SPI_OLED is
type state_type is (
            wait_for_start,
            send_data,
            wait_for_done);
signal state : state_type := wait_for_start;
signal temp_buffer : std_logic_vector(7 downto 0) :=(others => '0');
signal clock_divider : integer range 0 to 99 :=0;
signal bit_counter : integer range 0 to 7 :=0;
begin
    process(CLOCK)
    begin
        if rising_edge(CLOCK) then
            -- check constants
            RESET <= GPIO1(0);
            VDDC <= GPIO1(1);
            VBATC <= GPIO1(2);
            DC <= GPIO2(0);

            case state is
--------------------------------------------------
                when wait_for_start =>
                    GPIO3 <= '0';
                    CS <= '1';
                    SCLK <= '0';
                    MOSI <= GPIO_DATA(7);
                    bit_counter <= 0;
                    clock_divider <= 0;
                    if GPIO2(1) = '1' then
                        state <= send_data;
                        temp_buffer <= GPIO_DATA;
                    end if;
------------------------------------------------
                when send_data =>
                    cs <= '0';
                    if clock_divider < 49 then -- '0'
                        SCLK <= '0';
                        MOSI <= temp_buffer(7 - bit_counter);
                    else -- '1'
                        SCLK <= '1';
                    end if;
                    
                    if clock_divider = 99 then -- reset clock divider
                        if bit_counter = 7 then -- done sending byte
                            state <= wait_for_done;
                        end if;
                        bit_counter <= bit_counter + 1;
                        clock_divider <= 0;
                    else
                        clock_divider <= clock_divider + 1;
                    end if;
                    
                    
------------------------------------------------
                when wait_for_done =>  
                    GPIO3 <= '1';
                    cs <= '1';
                    SCLK <= '0';
                    if GPIO2(1) = '0' then
                        state <= wait_for_start;
                    end if; 
            end case;
        end if;
    end process;
end Behavioral;
--GPIO1(0) -> Reset
--GPIO1(1) -> VDDC
--GPIO1(2) -> VBATC

--GPIO2(0) -> D/C
--GPIO2(1) -> START
