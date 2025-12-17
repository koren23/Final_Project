library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
entity main is
    Port ( clk : in STD_LOGIC; -- 100MHZ
           btn : in STD_LOGIC; -- btn for start (will be replaced with flag or whatever)
           rd : out STD_LOGIC; -- io9
           intr : in STD_LOGIC; -- io8
           cs : out STD_LOGIC; -- io11
           wr : out STD_LOGIC; -- io10
           counterout : out STD_LOGIC_VECTOR(8 downto 0); -- counter signal for debug
           MA : out STD_LOGIC_VECTOR(3 downto 0); -- write MA address
           D1 : in STD_LOGIC_VECTOR(3 downto 0); -- io7-4
           D0 : in STD_LOGIC_VECTOR(3 downto 0); -- io3-0
           DataBusOut : out STD_LOGIC_VECTOR(23 downto 0); -- output of bus
           data_ready : out STD_LOGIC
           );
end main;

architecture Behavioral of main is
 type state_type is (
        idle, 
        start_conv,
        wait_for_intr,
        read_data
    );
signal state          : state_type := idle;
signal counter : integer range 0 to 1024 :=0;
signal MAenable : std_logic :='0'; -- 0 is Z 1 writes data
signal intrval : std_logic; -- saves first value of intr
begin
    MA <= "0100" when MAenable = '1' else (others => 'Z');
    process(clk)
    begin
        if rising_edge(clk) then
            case state is

                when idle =>
                    data_ready <= '0';
                    if btn = '1' then
                        MAenable <= '0'; -- MA is 'Z'
                        state <= start_conv;
                        counter <= 0;
                        intrval <= intr; -- save intr value
                    else    -- everything is reset
                        wr <= '1';
                        rd <= '1';
                        cs <= '1';
                        counter <= 0;
                    end if;
                    
                when start_conv =>
                    if intr = '0' OR intrval = '1' then -- if intr isnt reset yet 
                        if counter = 0 then -- drop CS
                            cs <= '0';
                        elsif counter = 1 then -- drop WR
                            wr <= '0';
                            intrval <= '0'; -- so it goes to the else
                        end if;
                    else -- if intr is reset
                        MAenable <= '1'; -- write MA data
                        if counter = 151 then
                            wr <= '1'; -- rise WR
                        elsif counter = 152 then -- rise CS
                            cs <= '1';
                        end if;
                    end if;
                    if counter < 153 then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= wait_for_intr;
                    end if;
                    
                    
                when wait_for_intr =>
                    MAenable <= '0'; -- maake MA 'z'
                    if intr = '0' then -- intr drop - bus is ready
                        state <= read_data;
                    end if;

                when read_data =>
                    if intr = '0' then -- if intr is down
                        if counter = 0 then -- drop CS
                            cs <= '0';  
                        elsif counter = 1 then -- drop RD
                            rd <= '0';
                        end if;
                    else -- if intr is up
                        if counter = 151 then
                            rd <= '1'; -- rise RD
                            DataBusOut <= std_logic_vector(to_unsigned(to_integer(unsigned(D0 & D1)) * 5e6 / 256,DataBusOut'length));  -- in uV
                            -- convert D0&D1 to integer multiply by 5e6/256 which results w voltage , convert it to stdlogic
                            data_ready <= '1';
                        elsif counter = 152 then
                            cs <= '1'; -- rise CS
                        end if;
                    end if;
                    
                    if counter < 153 then
                        counter <= counter + 1;
                    else
                        if btn = '0' then -- wait for btn reset
                            state <= idle;
                            counter <= 0;
                        end if; 
                    end if;         
            end case;
            counterout <= std_logic_vector(to_unsigned(counter, counterout'length));
        end if;
    end process;

end Behavioral;
