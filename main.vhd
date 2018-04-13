library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library machxo3lf;
use machxo3lf.all;

--All input and output ports of the FPGA
entity main is
   --input ende
  port(
    --from detector
    INPUT   : in  std_logic_vector(3 downto 0);

    --other features on the board
    SWITCH  : in  std_logic_vector(3 downto 0);
    LED     : out std_logic_vector(7 downto 0);
    BTN   	: in  std_logic;                             --button input
    
    
    --to PC
    UART_TX : out std_logic;
    UART_RX : in  std_logic
    );
end entity;



architecture functionality of main is

  signal clock        : std_logic;
  signal uart_rx_data : std_logic_vector(31 downto 0);
  signal uart_addr    : std_logic_vector(7 downto 0);
  signal bus_read     : std_logic := '0';
  signal bus_write    : std_logic := '0';
  signal usb_send     : std_logic; 
  signal usb_data     : std_logic_vector(31 downto 0);
  signal testreg      : std_logic_vector(31 downto 0);
  signal usb_busy     : std_logic;
  signal timer        : unsigned(31 downto 0);

  
  component OSCH
    generic (NOM_FREQ: string := "33.25");  --MHz 
    port (
      STDBY :IN std_logic;
      OSC   :OUT std_logic;
      SEDSTDBY :OUT std_logic
      );
  end component;


begin

---------------------------------------------------------------------------
-- Some basic function for the LED
-- LED are ON when '0' and OFF when '1'
---------------------------------------------------------------------------
-- LED <= not SWITCH  &   SWITCH;

-- spielerei_eins : process(SWITCH,BTN)
--    begin
--    
--     if SWITCH(0) = '1' xor BTN ='1' then
--        LED(7 downto 0) <= x"00";
-- --        elsif BTN ='1' then
-- --         LED(7 downto 0) <= x"ff";
--            else 
--            LED(7 downto 0) <=  x"ff";
--    end if;
-- end process;

-- spielerei_zwei : process(SWITCH,BTN)
--     begin
--     
--     if BTN='0' then
--       LED <=  SWITCH  &   SWITCH;
--       else
--       LED <= x"00";
--     end if;
-- end process;
--   

   
   
  

  
  
---------------------------------------------------------------------------
-- Example: Send state of switches once per second
---------------------------------------------------------------------------
-- PROC_SENDER : process begin
--   wait until rising_edge(clock);
--   --default values
--   usb_send <= '0';
-- 
--   if timer = x"01fb5ad0" then --33,250,000 in hexadecimal
--     if usb_busy = '0' then
--       usb_send <= '1';
--       usb_data <= x"5000000" & SWITCH; 
--       timer    <= x"00000000";
--     end if;  
--   else
--     timer <= timer + 1;
--   end if;
--  end process;
-- 
-- ---------------------------------------------------------------------------
-- -- Clock Source (an internal oscillator)
-- ---------------------------------------------------------------------------
clk_source: OSCH
  generic map ( 
    NOM_FREQ => "33.25"   -- Frequenz in MHz
    )
  port map (
    STDBY    => '0',
    OSC      => clock,
    SEDSTDBY => open
  );


  Randomizer : entity work.CTS_TRG_PSEUDORAND_PULSER 
  
   port map (
      clk_in       => clock,
      threshold_in => X"000003E8",            --Schwellenwert in Hex aktuell 1000
      trigger_out  => LED(0)
   );

  
  
-- ---------------------------------------------------------------------------
-- -- UART, the serial data communication to the PC
-- ---------------------------------------------------------------------------
-- THE_UART : entity work.uart_sctrl
--   port map(
--     CLK     => clock,
--     UART_RX => UART_RX,
--     UART_TX => UART_TX,
--     
--     DATA_OUT  => uart_rx_data,
--     ADDR_OUT  => uart_addr,       
--     WRITE_OUT => bus_write,
--     READ_OUT  => bus_read,
--     
--     BUSY_OUT  => usb_busy,
--     SEND_IN   => usb_send,
--     DATA_IN   => usb_data
--     );
-- 
--     
--     
-- ---------------------------------------------------------------------------    
-- -- one dummy register that can be written from PC sending "W10xxxxxxxx"
-- ---------------------------------------------------------------------------
-- PROC_REGS : process begin
--   wait until rising_edge(clock);
--   if bus_write = '1' then
--     case uart_addr is
--       when x"10" => testreg <= uart_rx_data;
--     end case;
--   end if;
-- end process;



end architecture;
