library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_rx_tx_Controller is
    generic (
        pha_value : std_logic :='0';
        pol_value : std_logic :='0';
        TFLEN       : std_logic_vector(7 downto 0) :="00000011"; -- number of bytes plus 2
        data_count  : integer := 1

    );
    Port (
        clk             : in    std_logic;
        cs_out          : out   std_logic; -- 0 means start exchange
        pha_out         : out   std_logic;
        pol_out         : out   std_logic;
        
        tx_valid_out    : out   std_logic;
        tx_ready_in     : in    std_logic;
        dout            : out   std_logic_vector(7 downto 0); -- data to transmit
        
        rx_ready_in     : in    std_logic;
        rx_valid_out    : out    std_logic;
        -- rx data isnt defined yet might go thru here might go straight to nextion / maybe log idk
        
        start_in        : in    std_logic;
        dineth          : in    std_logic_vector(7 downto 0)
    );
end SPI_rx_tx_Controller;

architecture Behavioral of SPI_rx_tx_Controller is

signal start_prev     : std_logic :='0'; -- used for rising edge of start_in
signal active         : boolean :=false;
constant array_length : integer := data_count + 11; 
signal loop_counter   : integer range 0 to array_length + 1 :=0; -- used for trasmittion 
type tx_arrayt is array (0 to array_length) of std_logic_vector(7 downto 0); -- array of all the register data need to send 
signal tx_array : tx_arrayt := ("11001001", "00000000", "00000000", "10001000", TFLEN , "00000000", "00000000", "00000000", "10001101", "00000010", "00000000",  "00000000", "00000000");
begin
    process(clk)
        begin
        pha_out <= pha_value;
        pol_out <= pol_value; -- based on generic vals
        dout <= (others => '0'); -- reset for dout
        if rising_edge(clk) then
            if start_in = '1' and start_prev = '0' then -- if rising edge of start_in
                active <= true;
                tx_array(2) <= dineth; -- insert data into array
                cs_out <= '0'; -- start exchange
            end if;
            start_prev <= start_in; -- update prev
            
            if active = true then
                if loop_counter = data_count + 1 then
                    loop_counter <= 0;
                    tx_valid_out <= '0';
                    active <= false;
                    rx_valid_out <= '1';
                else
                    dout <= tx_array(loop_counter);
                    tx_valid_out <= '1';
                    if tx_ready_in = '1' then
                        loop_counter <= loop_counter + 1;
                    end if;
                end if;
            end if;
            
            if rx_ready_in = '1' then
                cs_out <= '1';
                tx_valid_out <= '0';
                rx_valid_out <= '0';
            end if;
            
        end if;
    end process; 
end Behavioral;
