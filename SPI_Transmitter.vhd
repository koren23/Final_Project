library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_rx_tx_Controller is
    generic (
-- spi phase and polarity
        pha_value : std_logic :='0';
        pol_value : std_logic :='0'

    );
    Port (
        clk             : in    std_logic;
-- spi outputs
        cs_out          : out   std_logic; -- 0 means start exchange
        pha_out         : out   std_logic;
        pol_out         : out   std_logic;
-- tx ports
        tx_valid_out    : out   std_logic;
        tx_ready_in     : in    std_logic;
        dout            : out   std_logic_vector(7 downto 0); -- data to transmit
-- rx handshake
        rx_ready_in     : in    std_logic;
        rx_valid_out    : out    std_logic;
-- prev code ports        
        start_in        : in    std_logic;
        dineth          : in    std_logic_vector(7 downto 0)
    );
end SPI_rx_tx_Controller;

architecture Behavioral of SPI_rx_tx_Controller is
signal start_prev     : std_logic :='0'; -- used for rising edge of start_in
signal active         : boolean :=false;
begin
    process(clk)
        begin
        pha_out <= pha_value;
        pol_out <= pol_value; -- based on generic vals
        dout <= (others => '0'); -- reset for dout
        if rising_edge(clk) then
            if start_in = '1' and start_prev = '0' then -- if rising edge of start_in
                active <= true; -- start working
                cs_out <= '0'; -- start exchange
                dout <= dineth; -- send data to tx
            end if;
            start_prev <= start_in; -- update prev
            
            if active = true then -- start transmitting
                if tx_ready_in = '1' then -- if done transmitting
                    tx_valid_out <= '0'; -- stop handshake
                    active <= false;
                    rx_valid_out <= '1'; -- start receiving
                else
                    tx_valid_out <= '1'; -- start handshake
                end if;
            end if;
            
            if rx_ready_in = '1' then -- finished receiving
                cs_out <= '1'; -- stop exchange
                rx_valid_out <= '0'; -- stop receiving
            end if;
            
        end if;
    end process; 
end Behavioral;
