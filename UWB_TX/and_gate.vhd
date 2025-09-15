library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity and_gate is
    Port ( cs1       : in STD_LOGIC;
           cs2       : in STD_LOGIC;
           clk       : in STD_LOGIC;
           csout     : out STD_LOGIC);
end and_gate;

architecture Behavioral of and_gate is
begin
    process(clk)
        begin
        if rising_edge(clk) then
            csout <= cs1 AND cs2;
        end if;
    end process;    

end Behavioral;
