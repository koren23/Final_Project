library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity trans is
    Port ( 
        clk       : in  STD_LOGIC;
        data      : in  STD_LOGIC_VECTOR (31 downto 0);
        addra     : out STD_LOGIC_VECTOR (31 downto 0);
        bram_data : out STD_LOGIC_VECTOR (31 downto 0);
        ena       : out STD_LOGIC;
        wea       : out STD_LOGIC_VECTOR (3 downto 0)
    );
end trans;

architecture Behavioral of trans is
    signal addr : unsigned(31 downto 0) := (others => '0');
    signal activity     : boolean               := true;
begin

    process(clk)
    begin
        if rising_edge(clk) then
            if activity then
                ena       <= '1';
                wea       <= "1111";
                addra     <= std_logic_vector(addr);
                bram_data <= data;
                activity <= false;
            else
                ena <= '0';
                wea <= (others => '0');
            end if;
        end if;
    end process;

end Behavioral;
