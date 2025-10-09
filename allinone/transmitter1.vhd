library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
entity transmitter1 is
  Port (
        clk             :   in  std_logic;
        status_ready    :   in  std_logic;
        status_repeat   :   in  std_logic;
        buffer_ready    :   in  std_logic;
        buffer_valid    :   out std_logic;
        mosi            :   out std_logic;
        status_valid    :   out std_logic;
        spiclk          :   in std_logic;
        tx_cs           :   out std_logic);
end transmitter1;

architecture Behavioral of transmitter1 is
    constant configval      :       std_logic_vector(39 downto 0)   :="1010011100110001001110110000000001101011";
    constant enableval      :       std_logic_vector(39 downto 0)   :="1000110100000000000000000000000100000000";
    constant checkstatus    :       std_logic_vector(7 downto 0)    :="00001111";
    constant readbuffer     :       std_logic_vector(7 downto 0)    :="00010001";
    
    signal spiclk_prev      :       std_logic               :='0';
    signal bit_cnt          :       integer range 0 to 39   :=0;
    
        type states is (config, enable, status, framebuffer);
    signal state            :       states                  :=config;
   


begin
    process(clk)
    begin
        if rising_edge(clk) then
            if spiclk_prev = '0' and spiclk = '1' then -- rising edge of 2.5MHZ clk
                case state is
                    when config =>
                        if bit_cnt = 39 then -- stop at bit 39
                            mosi <= configval(0);
                            bit_cnt <= 0;
                            tx_cs <= '1';
                            state <= enable;
                        elsif bit_cnt = 0 then
                            tx_cs <= '0';
                            mosi <= configval(39);
                            bit_cnt <= 1;
                        else
                            mosi <= configval(39 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                    
                    when enable =>
                        if bit_cnt = 39 then -- stop at bit 39
                            mosi <= enableval(0);
                            bit_cnt <= 0;
                            tx_cs <= '1';
                            state <= status;
                        elsif bit_cnt = 0 then
                            tx_cs <= '0';
                            mosi <= enableval(39);
                            bit_cnt <= 1;
                        else
                            mosi <= enableval(39 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                        
                    when status =>
                        if bit_cnt = 7 then -- stop at bit 7
                            mosi <= checkstatus(0);
                            status_valid <= '1';
                            if status_ready = '1' then
                                bit_cnt <= 0;
                                status_valid <= '0';
                                tx_cs <= '1';
                                state <= framebuffer;
                            end if;
                            if status_repeat = '1' then
                                bit_cnt <= 0;
                            end if;
                        elsif bit_cnt = 0 then
                            tx_cs <= '0';
                            mosi <= checkstatus(7);
                            bit_cnt <= 1;
                        else
                            mosi <= checkstatus(7 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                        
                    when framebuffer =>
                        if bit_cnt = 7 then -- stop at bit 7
                            mosi <= readbuffer(0);
                            buffer_valid <= '1';
                            if buffer_ready = '1' then
                                bit_cnt <= 0;
                                buffer_valid <= '0';
                                tx_cs <= '1';
                                state <= status;
                            end if;
                        elsif bit_cnt = 0 then
                            tx_cs <= '0';
                            mosi <= readbuffer(7);
                            bit_cnt <= 1;
                        else
                            mosi <= readbuffer(7 - bit_cnt);
                            bit_cnt <= bit_cnt + 1;
                        end if;
                        
                end case;
            end if;
            spiclk_prev <= spiclk;
        end if;
    end process;
end Behavioral;