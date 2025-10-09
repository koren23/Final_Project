library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity transmitter is
  Port (
        clk             :   in      std_logic; -- 100MHZ
        ready           :   in      std_logic;
        repeat0         :   in      std_logic;
        start           :   in      std_logic;
        gpio            :   in      std_logic_vector(151 downto 0);
        valid           :   out     std_logic;
        mosi            :   out     std_logic;
        tx_cs           :   out     std_logic; -- byte to send
        bramready       :   in      std_logic;
        spiclk          :   out     std_logic); -- 2.5MHZ
end transmitter;

architecture Behavioral of transmitter is
    constant    txfctrl_data        :   std_logic_vector(39 downto 0)    :="1000100000000000000000100100000010011010";
    constant    tx_buffer_write     :   std_logic_vector(7 downto 0)     :="10001001";
    constant    sys_ctrl            :   std_logic_vector(39 downto 0)    :="1000110100000000000000000000000000000010";
    constant    readstatus          :   std_logic_vector(7 downto 0)     :="00001111";
    
    signal clockcounter     :       integer range 0 to 19   :=0; 
    signal spiclk_toggle    :       std_logic               :='0';
    signal spiclk_prev      :       std_logic               :='0';
    signal active           :       boolean                 :=false; -- for states
    signal bit_cnt          :       integer range 0 to 39   :=0;
    signal repeat_cnt       :       integer range 0 to 1    :=0; -- for receiver

        type states is (txfctrl, callbuffer, timeimp, impact, radiu, latit, longit, txstart, receiver);
    signal state            :       states                  :=txfctrl;
begin
    process(clk)
    begin
        if rising_edge(clk) then
            spiclk_prev <= spiclk_toggle;
            if clockcounter = 19 then -- clock divider 100 to 2.5MHZ
                clockcounter <= 0;
                spiclk_toggle <= not spiclk_toggle;
                spiclk <= spiclk_toggle;
            else
                clockcounter <= clockcounter + 1;
            end if;
            
            if spiclk_prev = '0' and spiclk_toggle = '1' then -- rising edge of 2.5MHZ clk
                case state is
                    when txfctrl =>
                        if bit_cnt = 39 then -- stop at bit 39
                            mosi <= txfctrl_data(39 - bit_cnt);
                            bit_cnt <= 0;
                            tx_cs <= '1';
                            state <= callbuffer;
                        elsif bit_cnt = 0 then
                            tx_cs <= '0';
                            mosi <= txfctrl_data(39);
                            bit_cnt <= 1;
                        else
                            mosi <= txfctrl_data(39 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;

                            
                        
                    when callbuffer => -- send 0x89 write to buffer command
                        if start = '1' then
                            active <= true;
                            bit_cnt <= 0;
                            tx_cs <= '0'; -- start exchange
                        else
                            tx_cs <= '1'; -- do NOT exchange
                        end if;
                        
                        if active then
                            if bit_cnt = 7 then -- stop at bit 7
                                mosi <= tx_buffer_write(0);
                                bit_cnt <= 0;
                                state <= timeimp;
                                active <= false;
                            elsif bit_cnt = 0 then
                                tx_cs <= '0'; -- start exchange
                                mosi <= tx_buffer_write(7);
                                bit_cnt <= 1;
                            else
                                mosi <= tx_buffer_write(7 - bit_cnt);
                                bit_cnt <= bit_cnt + 1;
                            end if;
                        end if;  


                    when timeimp =>
                        if bit_cnt = 31 then -- stop at bit 31
                            mosi <= gpio(0);
                            bit_cnt <= 0;
                            state <= impact;
                        else
                            mosi <= gpio(31 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                        
                    when impact =>
                        if bit_cnt = 31 then -- stop at bit 31
                            mosi <= gpio(32);
                            bit_cnt <= 0;
                            state <= radiu;
                        else
                            mosi <= gpio(31 - bit_cnt + 32);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    
                    when radiu =>
                        if bit_cnt = 23 then -- stop at bit 23
                            mosi <= gpio(64);
                            bit_cnt <= 0;
                            state <= latit;
                        else
                            mosi <= gpio(23 - bit_cnt + 64);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                        
                    when latit =>
                        if bit_cnt = 31 then -- stop at bit 31
                            mosi <= gpio(88);
                            bit_cnt <= 0;
                            state <= longit;
                        else
                            mosi <= gpio(31 - bit_cnt +88);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    
                    when longit =>
                        if bit_cnt = 31 then -- stop at bit 31
                            mosi <= gpio(120);
                            bit_cnt <= 0;
                            tx_cs <= '1'; -- stop exchange
                            state <= txstart;
                        else
                            mosi <= gpio(31 - bit_cnt + 120);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                
                    when txstart =>
                        if bit_cnt = 39 then -- stop at bit 39
                            mosi <= sys_ctrl(0);
                            bit_cnt <= 0;
                            state <= receiver;
                            tx_cs <= '1';
                        elsif bit_cnt = 0 then
                            tx_cs <= '0'; -- start exchange
                            mosi <= sys_ctrl(39);
                            bit_cnt <= 1;
                        else
                            mosi <= sys_ctrl(39 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                              
                    when receiver =>
                        if repeat_cnt = 0 then
                            if bit_cnt = 7 then -- stop at bit 7
                                mosi <= readstatus(0);
                                bit_cnt <= 0;
                                state <= receiver;
                            elsif bit_cnt = 0 then
                                tx_cs <= '0'; -- start exchange
                                mosi <= readstatus(7);
                                bit_cnt <= 1;
                            else
                                mosi <= readstatus(7 - bit_cnt);
                                bit_cnt <= bit_cnt + 1;
                            end if;
                            repeat_cnt <= 1;
                            valid <= '1';
                        end if;    
                        
                        if ready = '1' then -- if ready move on
                            valid <= '0';
                            state <= callbuffer;
                            tx_cs <= '1';
                        end if;
                        if repeat0 = '1' then -- check status again
                            valid <= '0';
                            repeat_cnt <= 0;
                        end if;
                        
                            
                        
                    
                end case;
                
            end if;
            
        end if;
    end process;

end Behavioral;
