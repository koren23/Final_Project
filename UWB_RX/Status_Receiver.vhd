library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity status_receiver is
    Port (
            spiclk   : in    STD_LOGIC;
            ready    : in    STD_LOGIC;
            valid    : out   STD_LOGIC;
            looprepeat   : out    STD_LOGIC;
            miso     : in    STD_LOGIC);
end status_receiver;

architecture Behavioral of status_receiver is
    signal  active          :   boolean                 :=false;
    signal  ready_prev      :   std_logic               :='0';
    signal  bit_cnt         :   integer range 0 to 31   :=0;
    signal data             :   std_logic_vector(31 downto 0) := (others => '0');
begin
    process(spiclk)
    begin
        if rising_edge(spiclk) then
            valid <= '0';
            looprepeat <='0';
            if ready = '1' and ready_prev = '0' then
                active <= true;
            end if;
            ready_prev <= ready;
            
            if active then
                if bit_cnt = 31 then
                    bit_cnt <= 0;
                    active <= false;
                    if data(8) = '1' then
                        valid <= '1';
                    else
                        looprepeat <= '1';
                    end if;
                else
                    data(31 - bit_cnt) <= miso;
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;
