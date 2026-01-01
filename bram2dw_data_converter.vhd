library IEEE;
use IEEE.STD_LOGIC_1164.ALL;


entity converter is
    Port ( clk : in STD_LOGIC;
           din : in STD_LOGIC_VECTOR (31 downto 0);
           flagin : in STD_LOGIC_VECTOR(2 downto 0);
           flagout : out STD_LOGIC;
           dout : out STD_LOGIC_VECTOR (151 downto 0));
end converter;

architecture Behavioral of converter is
    signal temp : std_logic_vector(151 downto 0) := (others => '0');
begin
    process(clk)
    begin
        if rising_edge(clk) then
            case flagin is
                when "000" =>
                    temp <= (others => '0');
                    flagout <= '0';
                    
                when "001" =>
                    temp(151 downto 120) <= din;
                    flagout <= '0';
                    
                when "010" =>
                    temp(119 downto 88) <= din;
                    flagout <= '0';
                
                when "011" =>
                    temp(87 downto 64) <= din(23 downto 0);
                    flagout <= '0';
                    
                when "100" =>
                    temp(63 downto 32) <= din;
                    flagout <= '0';
                    
                when "101" =>
                    temp(31 downto 0) <= din;
                    dout <= temp;
                    flagout <= '1';
                    
                when "110" =>
                
                when "111" =>
            
            end case;
        end if;
    end process;
end Behavioral;
