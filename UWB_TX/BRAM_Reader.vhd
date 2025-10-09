library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bram_reader is
    Port ( clk       : in STD_LOGIC;
           start     : in STD_LOGIC;
           dout   : out STD_LOGIC_VECTOR (151 downto 0);
           addra     : out STD_LOGIC_VECTOR (31 downto 0);
           din      : in STD_LOGIC_VECTOR (31 downto 0);
           wea       : out STD_LOGIC;
           rst       : out STD_LOGIC;
           valid     : out STD_LOGIC;
           ena       : out STD_LOGIC);
end bram_reader;

architecture Behavioral of bram_reader is
    signal start_prev     :       std_logic                      :='0'; 
    signal active         :       boolean                        :=false;
    signal bramdata       :       std_logic_vector(151 downto 0) := (others => '0');
    signal cnt            :       integer range 0 to 10          := 0;
    signal loopcnt        :       integer range 0 to 31          := 0;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if start = '1' and start_prev = '0' then
                active <= true;
                cnt <= 0;
                ena <= '1';
            end if;
            start_prev <= start;
            rst <= '1';
            wea <= '0';
            valid <= '0';
            
            if active then
            
                if cnt = 0 then
                    cnt <= 1;
                    
                elsif cnt = 1 then
                    addra <= "00000000000000000000000000000000";
                    if loopcnt < 31 then
                        bramdata(loopcnt) <= din(loopcnt);
                        loopcnt <= loopcnt +1;
                    else
                        bramdata(loopcnt) <= din(loopcnt);
                        loopcnt <= 0;
                        cnt <= 2;
                    end if;
                    
                elsif cnt = 2 then
                    cnt <= 3;
                    
                elsif cnt = 3 then
                    addra <= "00000000000000000000000000000001";
                    if loopcnt < 31 then
                        bramdata(loopcnt + 32) <= din(loopcnt);
                        loopcnt <= loopcnt +1;
                    else
                        bramdata(loopcnt + 32) <= din(loopcnt);
                        loopcnt <= 0;
                        cnt <= 4;
                    end if;
                    
                elsif cnt = 4 then
                    cnt <= 5;
                    
                elsif cnt = 5 then
                    addra <= "00000000000000000000000000000010";
                    if loopcnt < 31 then
                        bramdata(loopcnt + 64) <= din(loopcnt);
                        loopcnt <= loopcnt +1;
                    else
                        bramdata(loopcnt + 64) <= din(loopcnt);
                        loopcnt <= 0;
                        cnt <= 6;
                    end if;
                    
                elsif cnt = 6 then
                    cnt <= 7;
                    
                elsif cnt = 7 then
                    addra <= "00000000000000000000000000000011";
                    if loopcnt < 31 then
                        bramdata(loopcnt + 96) <= din(loopcnt);
                        loopcnt <= loopcnt +1;
                    else
                        bramdata(loopcnt + 96) <= din(loopcnt);
                        loopcnt <= 0;
                        cnt <= 8;
                    end if;
                    
                elsif cnt = 8 then
                    cnt <= 9;
                    
                elsif cnt = 9 then
                    addra <= "00000000000000000000000000000100";
                    if loopcnt < 23 then
                        bramdata(loopcnt + 128) <= din(loopcnt);
                        loopcnt <= loopcnt +1;
                    else
                        bramdata(loopcnt + 128) <= din(loopcnt);
                        loopcnt <= 0;
                        cnt <= 0;
                        ena <= '0';
                        valid <= '1';
                        dout <= bramdata;
                        active <= false;
                    end if;
                end if;
                
                

            end if;            
        end if;
    end process;
    

end Behavioral;
