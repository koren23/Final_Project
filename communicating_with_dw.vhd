library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity test_octet_id is
    Port (
        MISO    : in STD_LOGIC;        -- SPI Data from DW1000
        CLK     : in STD_LOGIC;        -- System Clock 20MHZ
        BTN     : in STD_LOGIC;        -- Start button
        LED     : out STD_LOGIC_VECTOR(1 DOWNTO 0);       -- LED indicator
        CS      : out STD_LOGIC;       -- SPI Chip Select
        MOSI    : out STD_LOGIC;        -- SPI Data to DW1000
        DATA_VECTOR : out std_logic_vector(39 downto 0)
    );
end test_octet_id;

architecture Behavioral of test_octet_id is

    type state_type is (IDLE, READ_ID, RECEIVE_DATA0, WRITE_BUFFER, SEND_FRAME_CONTROL, READ_FRAME_CONTROL, RECEIVE_DATA1, DONE);
    signal state       : state_type := IDLE;

    signal bit_cnt     : integer range 0 to 47 := 0;
    signal data        : std_logic_vector(39 downto 0) :=(others => '0');
    
    constant id_read              : std_logic_vector(7 downto 0) := "00000000";
    
    constant buffer_write         : std_logic_vector(15 downto 0) := "1000100101011010";
    
    constant frame_control_write  : std_logic_vector(47 downto 0) := "100010000000001101000000000000100000000000000000"; 
    constant frame_control_read   : std_logic_vector(7 downto 0) := "00001000";


begin

 
    process(CLK)
    begin
        if rising_edge(CLK) then
            case state is
                when IDLE =>
                    LED <= "00";
                    CS  <= '1';
                    MOSI <= '1';
                    bit_cnt <= 0;
                    if BTN = '1' then
                        state <= READ_ID;
                        LED <= "11";
                    end if;
                 
                when READ_ID =>
                    LED <= "00";
                    CS  <= '0';
                    MOSI <= id_read(7 - bit_cnt); 
                    if bit_cnt = 7 then
                        bit_cnt <= 0;
                        state <= RECEIVE_DATA0;
                        LED <= "11";
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;
                
                when RECEIVE_DATA0 =>
                    LED <= "00";
                    MOSI <= '0';
                    if bit_cnt = 31 then
                        state <= SEND_FRAME_CONTROL; -- skipped buffer to test code
                        bit_cnt <= 0;
                        LED <= "11";
                        data_vector <= (others => '0');
                        data_vector <= data;
                    else
                        bit_cnt <= bit_cnt + 1;
                        data(31 - bit_cnt) <= MISO;
                    end if; 
               
                when SEND_FRAME_CONTROL =>
                    LED <= "00";
                    MOSI <= frame_control_write(47 - bit_cnt);
                    if bit_cnt = 47 then
                        bit_cnt <= 0;
                        state <= READ_FRAME_CONTROL;
                        LED <= "11";
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;

                when READ_FRAME_CONTROL =>
                    LED <= "00";
                    MOSI <= frame_control_read(7 - bit_cnt); 
                    if bit_cnt = 7 then
                        bit_cnt <= 0;
                        state <= RECEIVE_DATA1;
                        LED <= "11";
                    else
                        bit_cnt <= bit_cnt + 1;
                    end if;

                when RECEIVE_DATA1 =>
                    LED <= "00";
                    MOSI <= '0';
                    if bit_cnt = 39 then
                        CS  <= '1';
                        bit_cnt <= 0;
                        data_vector <= (others => '0');
                        data_vector <= data;
                        state <= DONE;
                        LED <= "11";
                    else
                        bit_cnt <= bit_cnt + 1;
                        data(47 - bit_cnt) <= MISO;
                    end if;
                    
                when DONE =>
                    LED <= "00";
                    CS  <= '1';
                    
                when others =>
                    state <= IDLE;
            end case;
        end if;
    end process;

end Behavioral;
