library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity bcontroller is
    Port (
        ADCFLAGIN   : in  std_logic;
        ADCDATAIN   : in  std_logic_VECTOR(7 downto 0);
        ADCFLAGOUT  : out std_logic;
    
        clk     : in  std_logic;
        loopout : out std_logic_vector(7 downto 0);

        weout   : out std_logic;
        din     : in  std_logic_vector(31 downto 0);
        dout    : out std_logic_vector(31 downto 0);
        addrout : out std_logic_vector(31 downto 0);
        
        uwbtx_f : out std_logic_vector(2 downto 0);
        uwbtx_d : out std_logic_vector(31 downto 0);
        uwb_in  : in  std_logic;
        
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
            return_nxtnflag,
            wait_flagdrop,
            
            send_read_data_command,
            read_data,
            uwb_flag_state,
            nextion,
            tempIDLE
            
            
            
        );
signal state : state_type := read_flag;
signal temp_flag : std_logic_vector(2 downto 0) := (others => '0');
signal loop_counter : integer range 0 to 255 :=36;
signal tempcommand : std_logic_vector (287 downto 0) :="111111111111111111111111011000100110000101110100011101000110010101110010011110010010111001110100011110000111010000111101001000100000000000000000011101100010001011111111111111111111111101101100011011110110011101101111001011100111000001101001011000110011110100000000111111111111111111111111";
    -- binary for 0xFFFFFFbattery.txt="0x0000v"0xFFFFFFlogo.pic=0x000xFFFFFF
signal scaled_value : integer range 0 to 255;
signal tens         : integer range 0 to 9;
signal ones         : integer range 0 to 9;
begin

process(clk)

begin
    if rising_edge(clk) then
        case state is
               
            when read_flag => -- read flag gpio
                nextion_f <= '0';
                ADCFLAGOUT <= '1';
                if gpio_in = "000" then
                    uwbtx_f <= "000";
                    temp_flag <= (others => '0');
                    state <= wait_for_adc_data;
                else -- NOT idle
                    gpio_out <= "00";
                    state <= send_read_data_command;
                    temp_flag <= gpio_in; -- save the flag in buffer
                end if;


--------------------------------------------------------------------------------------
            when wait_for_adc_data => -- wait for adc to return value
                ADCFLAGOUT <= '1';
                if ADCFLAGIN = '1' then
                    state <= return_adc_data;
                    scaled_value <= (to_integer(unsigned(ADCDATAIN)) * 42) / 256;
                    tens <= scaled_value / 10;
                    ones <= scaled_value mod 10; 
                    tempcommand(159 downto 152) <= std_logic_vector(to_unsigned(tens + 48, 8));
                    tempcommand(151 downto 144) <= std_logic_vector(to_unsigned(ones + 48, 8));
                    ADCFLAGOUT <= '0';
                    if (to_integer(unsigned(ADCDATAIN)) * 42) / 256 >= 11 then
                        tempcommand(31 downto 24) <= "00110100";
                    elsif (to_integer(unsigned(ADCDATAIN)) * 42) / 256 >= 9 then
                        tempcommand(31 downto 24) <= "00110101";
                    elsif (to_integer(unsigned(ADCDATAIN)) * 42) / 256 >= 7 then
                        tempcommand(31 downto 24) <= "00110110";
                    else
                        tempcommand(31 downto 24) <= "00110111";
                    end if;
                end if;
                
            when return_adc_data => -- write adc value to nextion
                if gpio_in /= "111" then
                    if loop_counter > 0 then
                        state <= return_nxtnflag;
                        nextion_f <= '1';
                        nextion_d <= tempcommand(7+loop_counter*8 downto 0+loop_counter*8);
                        loop_counter <= loop_counter - 1;
                    else
                        state <= read_flag;
                        loop_counter <= 35;
                    end if;
                else
                    state <= send_read_data_command;
                    temp_flag <= gpio_in;
                    loop_counter <= 35;
                end if;
                
                
            when return_nxtnflag =>
                if nextiondone = '1' then
                    nextion_f <= '0';
                    state   <= wait_flagdrop;
                end if;
                
            when wait_flagdrop =>
                if nextiondone = '0' then
                    state   <= wait_for_adc_data;
                end if;
            
                
-----------------------------------------------------------------------------------
            when send_read_data_command =>
                weout   <= '0';
                addrout <= x"00000000";
                state <= read_data;
                
            when read_data =>
                state <= read_flag;
                if temp_flag = "111" then -- nextion data
                    nextion_f <= '1';
                    nextion_d <= din(7 downto 0);
                    state <= nextion;
                else
                    state <= uwb_flag_state;
                    uwbtx_d <= din;
                end if;
                
            when uwb_flag_state =>
                uwbtx_f <= temp_flag; -- 1 2 for time data 3 radius 4 5 for location (uwb flags)
                if uwb_in = '1' then
                    state <= read_flag;
                    gpio_out <= "01"; -- uwb confirm
                end if;
                
            when nextion =>
                if nextiondone = '1' then -- nextion done 
                    gpio_out <= "10"; -- nextion done
                    if gpio_in =  "000" then
                        state <= read_flag;
                    else 
                        state <= tempIDLE;
                    end if;
                end if;
            
            when tempIDLE =>
                nextion_f <= '0';
                if gpio_in = "000" then
                    temp_flag <= (others => '0');
                    state <= wait_for_adc_data;
                else -- NOT idle
                    state <= send_read_data_command;
                    temp_flag <= gpio_in; -- save the flag in buffer
                end if;
                         
        end case;
        
        loopout <= std_logic_vector(to_unsigned((loop_counter),loopout'length));
    end if;
end process;

end Behavioral;

--gpioIN:
--000   idle
--001   current time
--010   impact time
--011   radius
--100   latitude
--101   longitude
--110   temp IDLE for nextion commands
--111   nextion command

--gpioOUT:
--00    idle
--01    uwb confirm
--10    nextion page map
--01
