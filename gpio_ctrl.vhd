library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity ps_pl_transfer is
    Port ( clk       : in  STD_LOGIC;
           valid_out : out STD_LOGIC;
           data_out  : out STD_LOGIC_VECTOR (7 downto 0);
           ready_in  : in STD_LOGIC;
           data_in   : in STD_LOGIC_VECTOR (7 downto 0));
end ps_pl_transfer;

architecture Behavioral of ps_pl_transfer is
signal ready_prev   : std_logic := '0';
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if ready_in = '1' and ready_prev = '0' then
                data_out <= data_in;
                valid_out <= '1';
            else
                valid_out <= '0';
            end if;
            ready_prev <= ready_in;

        end if;
    end process;
end Behavioral;
