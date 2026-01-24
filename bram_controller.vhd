library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity bcontroller is
    Port (
        ADCFLAGIN   : in  std_logic;
        ADCDATAIN   : in  std_logic_VECTOR(23 downto 0);
        ADCFLAGOUT  : out std_logic;
    
        clk     : in  std_logic;

        weout   : out std_logic;
        din     : in  std_logic_vector(31 downto 0);
        dout    : out std_logic_vector(31 downto 0);
        addrout : out std_logic_vector(31 downto 0);
        
        uwbtx_f : out std_logic_vector(2 downto 0);
        uwbtx_d : out std_logic_vector(31 downto 0);
        
        nextion_f : out std_logic;
        nextion_d : out std_logic_vector(7 downto 0);
        nextiondone : in std_logic;
        
        gpio_in  : in  std_logic_vector(2 downto 0);
        gpio_out : out std_logic_vector(1 downto 0)
    );
end bcontroller;

architecture Behavioral of bcontroller is
type state_type is (
            read_flag,
            
            wait_for_adc_data,
            return_adc_data,
            return_adc_flag,
            
            send_read_data_command,
            read_data,
            
            nextion
            
            
            
        );
signal state : state_type := read_flag;
signal temp_data : std_logic_vector(23 downto 0) := (others => '0');
signal temp_flag : std_logic_vector(2 downto 0) := (others => '0');
begin

process(clk)

begin
    if rising_edge(clk) then
        case state is
               
            when read_flag => -- read flag gpio
                nextion_f <= '0';
                uwbtx_f <= "000";
                if gpio_in = "110" then -- no need to read data for adc
                    gpio_out <= "00";
                    state <= wait_for_adc_data; 
                    temp_data <= (others => '0');
                    ADCFLAGOUT <= '1'; -- activate adc
                elsif gpio_in = "000" then
                    temp_data <= (others => '0');
                else -- NOT idle and NOT adc
                    state <= send_read_data_command;
                    temp_flag <= gpio_in; -- save the flag in buffer
                end if;


--------------------------------------------------------------------------------------
            when wait_for_adc_data => -- wait for adc to return value
                if ADCFLAGIN = '1' then
                    temp_data <= ADCDATAIN;
                    state <= return_adc_data;
                    ADCFLAGOUT <= '0';
                end if;
                
            when return_adc_data => -- write adc value to bram
                weout   <= '1';
                addrout <= x"00000000";
                dout(31 downto 24) <= (others => '0');
                dout(23 downto 0) <= temp_data;
                state   <= return_adc_flag;
                
            when return_adc_flag =>
                gpio_out <= "01"; -- flag means adc done
                uwbtx_d <= din;
                uwbtx_f <= "011"; -- 3 in uwb code stands for radius
                state   <= read_flag;
-----------------------------------------------------------------------------------
            when send_read_data_command =>
                weout   <= '0';
                addrout <= x"00000000";
                state <= read_data;
                
            when read_data =>
                state <= read_flag;
                if temp_flag = "011" then -- nextion data
                    nextion_f <= '1';
                    nextion_d <= din(7 downto 0);
                    state <= nextion;
                else
                    uwbtx_f <= temp_data(2 downto 0); -- 1 2 for time data 4 5 for location (uwb flags)
                    uwbtx_d <= din;
                end if;
                
            when nextion =>
                if nextiondone = '1' then -- nextion done 
                    gpio_out <= "10"; -- nextion done
                    state <= read_flag;
                end if; 
                
        end case;
    end if;
end process;

end Behavioral;

--gpioIN:
--000   idle
--001   current time
--010   impact time
--011   nextion command
--100   latitude
--101   longitude
--110   activate adc
--111   

--gpioOUT:
--00    idle
--01    adc done
--10    nextion page map
