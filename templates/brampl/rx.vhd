library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity recv is
    Port ( 
        clk       : in  STD_LOGIC;
        bram_data : in  STD_LOGIC_VECTOR(31 downto 0); -- corrected width
        data      : in  STD_LOGIC_VECTOR(31 downto 0);
        addrb     : out STD_LOGIC_VECTOR(31 downto 0);
        enb       : out STD_LOGIC;
        web       : out STD_LOGIC_VECTOR(3 downto 0);
        led       : out STD_LOGIC
    );
end recv;

architecture Behavioral of recv is
    signal addr : unsigned(31 downto 0) := (others => '0');
begin

    process(clk)
    begin
        if rising_edge(clk) then
            enb <= '1';
            web <= "0000";
            addrb <= std_logic_vector(addr);
            if bram_data = data then
                led <= '1';
            else
                led <= '0';
            end if;
        end if;
    end process;

end Behavioral;
