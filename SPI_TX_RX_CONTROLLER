library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity SPI_rx_tx_Controller is
    generic (
        pha_value : std_logic :='0';
        pol_value : std_logic :='0';
        
        TXFCTRL1    : std_logic_vector(7 downto 0) :="11001000"; -- write + subindex + register ID
        TXFCTRL2    : std_logic_vector(7 downto 0) :="00000000";
        TFLEN       : std_logic_vector(6 downto 0) :="000011"; -- number of bytes plus 2
        TFLE        : std_logic_vector(2 downto 0) :="000"; -- extra 3 bits for TFLEN (unused unless databyteamount > 125)
        R           : std_logic_vector(2 downto 0) :="000"; -- reserved
        TXBR        : std_logic_vector(1 downto 0) :="10"; -- bitrate 00 110kbps 01 850kbps or 10 6.8mbps
        TR          : std_logic                    :='0'; -- ranging
        
        TXBUFFER1   : std_logic_vector(7 downto 0) :="11001001";
        TXBUFFERSUB : std_logic_vector(14 downto 0) :="000000000000000";
        EXTADDR     : std_logic                    :='1';
        
        SYSCTRL1    : std_logic_vector(7 downto 0) :="11011000";
        SYSCTRL2    : std_logic_vector(7 downto 0) :="00000000";
        SYSCTRL3    : std_logic_vector(7 downto 0) :="01000000";
        
        data_count  : integer := 1;

		byte_data   : std_logic_vector(7 downto 0) := "11111111"
    );
    Port (
        clk             : in    std_logic;
        cs_out          : out   std_logic;
        pha_out         : out   std_logic;
        pol_out         : out   std_logic;
        
        rx_valid_out    : out   std_logic;
        rx_ready_in     : in    std_logic;
        din             : in    std_logic_vector(7 downto 0);
        
        tx_valid_out    : out   std_logic;
        tx_ready_in     : in    std_logic;
        dout            : out   std_logic_vector(7 downto 0);
        
        start_in        : in    std_logic
    );
end SPI_rx_tx_Controller;

architecture Behavioral of SPI_rx_tx_Controller is
signal txfctrl_settings      : std_logic_vector(15 downto 0);

signal start_prev : std_logic :='0';
signal txactive     : boolean := false;
signal recv_activated : boolean := false;

signal loop_countertx   : integer range 0 to 1024 :=0;
signal loop_counterrx   : integer range 0 to 1024 :=0;
constant array_length : integer := data_count + 10;
type arraytype is array (0 to data_count + 9) of std_logic_vector(7 downto 0);
signal tx_array : arraytype := (TXBUFFER1, "00000000", "00000000", byte_data, TXFCTRL1, TXFCTRL2, "00000000", "00000000", SYSCTRL1, SYSCTRL2, SYSCTRL3);
signal rx_array : arraytype := (others <= '0');

begin
    process(clk)
        begin
        pha_out <= pha_value;
        pol_out <= pol_value;
        
        txfctrl_settings <= TFLEN & TFLE & R & TXBR & TR;
        tx_array(6) <= txfctrl_settings(7 downto 0);
        tx_array(7) <= txfctrl_settings(15 downto 8);
        tx_array(1) <= EXTADDR & TXBUFFERSUB(6 downto 0);
        tx_array(2) <= TXBUFFERSUB(14 downto 7);
		
        if rising_edge(clk) then
            if start_in = '1' and start_prev = '0' then
                txactive <= true;
            end if;
			start_prev <= start_in;
            if txactive = true then
                if loop_countertx = 10 + data_count then
                    loop_countertx <= 0;
					txactive <= false;
					recv_activated <= true;
                else
                    dout <= tx_array(loop_countertx);
                    tx_valid_out <= '1';
                    if tx_ready_in = '1' then
						tx_valid_out <= '0';
                        loop_countertx <= loop_countertx + 1;
                    end if;
				end if;
			end if;
			

			if recv_activated then
				if loop_counterrx = 10 + data_count + 1 then
					loop_counterrx <= 0;
					recv_activated <= false;
				elsif loop_counterrx = 0 then
					rx_valid_out <= '1';
				else
					rx_array(loop_counterrx) <= din;
					if rx_ready_in = '1' then
						rx_valid_out <= '0';
						loop_counterrx <= loop_counterrx + 1;
					end if;
				end if;
			end if;
			
        end if;
    end process; 
end Behavioral;
