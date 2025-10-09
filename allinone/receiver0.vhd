library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity receiver0 is
  Port (
        clkspi  :   in  std_logic;
        miso    :   in  std_logic;
        ready   :   in  std_logic;
        repeat0  :   out std_logic;
        valid   :   out std_logic);
        
end receiver0;

architecture Behavioral of receiver0 is
signal ready_prev   :   std_logic               :='0';
signal active       :   boolean                 :=false;
signal bit_cnt      :   integer range 0 to 31   :=0;
    type arrayt is array (0 to 31) of std_logic;
signal data         :   arrayt                  := (others => '0');
begin
    process(clkspi)
    begin
        if rising_edge(clkspi) then
            if ready = '1' and ready_prev = '0' then
                active <= true;
            end if;
            ready_prev <= ready;
            
            if active then
                if bit_cnt = 31 then
                    bit_cnt <= 0;
                    active <= false;
                    if data(7) = '0' then
                        valid <= '1';
                    else
                        repeat0 <= '1';
                    end if;
                else
                    data(bit_cnt) <= miso;
                    bit_cnt <= bit_cnt + 1;
                    
                end if;
            end if;
            valid <= '0';
            repeat0 <='0';
            
        
        end if;
    end process;
end Behavioral;