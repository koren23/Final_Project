library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity readbuffer is
    Port ( 
            spiclk   : in    STD_LOGIC;
            ready    : in    STD_LOGIC;
            valid    : out   STD_LOGIC;
            miso     : in    STD_LOGIC;
            data     : out   STD_LOGIC_VECTOR (151 downto 0));
end readbuffer;

architecture Behavioral of readbuffer is
    signal  active          :   boolean                 :=false;
    signal  ready_prev      :   std_logic               :='0';
    signal  bit_cnt         :   integer range 0 to 151  :=0;
    signal dataarr          :   std_logic_vector(151 downto 0) := (others => '0');
begin
    process(spiclk)
    begin
        if rising_edge(spiclk) then
            valid <= '0';
            if ready = '1' and ready_prev = '0' then
                active <= true;
            end if;
            ready_prev <= ready;
            
            if active then
                if bit_cnt = 151 then
                    dataarr(0) <= miso;
                    bit_cnt <= 0;
                    active <= false;
                    valid <= '1';
                    data <= dataarr;
                    
                else
                    dataarr(151 - bit_cnt) <= miso;
                    bit_cnt <= bit_cnt + 1;
                end if;
            end if;
        end if;
    end process;
end Behavioral;