library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity uart_trans is
--   generic(
--     CLK_DIV : integer
--     );
  port(
    CLK_DIV    : in integer;
    CLK        : in std_logic;
    RST        : in std_logic;
    
    DATA_IN    : in  std_logic_vector(7 downto 0);
    SEND       : in  std_logic;
    READY      : out std_logic;
    
    TX         : out std_logic;
    DEBUG      : out std_logic_vector(3 downto 0)
    
    );
end entity;



architecture uart_trans_arch of uart_trans is



signal clk_div_counter: unsigned(15 downto 0) := x"0000";
signal symbol_start_pulse : std_logic := '0';
signal symbol_counter: unsigned(3 downto 0) := x"0";

type state_type is (idle,transmitting);
signal state: state_type := idle;

-- MSB is the stopbit, LSB is the start bit, both are never changed
signal tx_shift_register: std_logic_vector(9 downto 0) := "1000000000"; 
signal symbol: std_logic := '1';
signal ready_sig: std_logic := '1';
signal rst_clk_div_counter : std_logic;


begin
----------------------------
-- debug
----------------------------

DEBUG(0) <= symbol_start_pulse;
DEBUG(1) <= '0';
DEBUG(2) <= ready_sig;
DEBUG(3) <= '0';

----------------------------
-- Inputs
----------------------------
--   sync_input : process begin
--     wait until rising_edge(CLK);
--     synced_send <= SEND;
--   end process;
-- hard wired stuff

----------------------------
-- Outputs
----------------------------
  sync_output : process begin
    wait until rising_edge(CLK);
    TX <= symbol;
  end process;
  
  READY <= ready_sig and not SEND;
  
----------------------------
-- Generate Serial Clock
----------------------------
  clock_division : process begin
    wait until rising_edge(CLK);
    -- scaling down the main clock to the desired baudrate
    if clk_div_counter = to_unsigned(CLK_DIV,16)-1 then
      clk_div_counter <= x"0000";
    else
      clk_div_counter <= clk_div_counter + 1;
    end if;

    
    if clk_div_counter = x"0000" then
      symbol_start_pulse <= '1';
    else 
      symbol_start_pulse <= '0';
    end if;
    if (RST or rst_clk_div_counter) = '1' then
      clk_div_counter <= x"0000";
    end if;
    
  end process;   
  
----------------------------
-- State Machine of the Transmitter
----------------------------

  state_machine : process begin
    wait until rising_edge(CLK);
    --  state machine rules:
    rst_clk_div_counter <= '0';
    
    case state is
      when idle =>
        if SEND = '1' then
          state <= transmitting;
          symbol_counter <= x"0";
          -- capture the byte at the parallel input
          tx_shift_register(8 downto 1) <= DATA_IN;
          ready_sig <= '0';
        end if;
      
      when transmitting =>
        if symbol_start_pulse = '1' then
          if symbol_counter <= 9 then -- transmission process
            symbol <= tx_shift_register(to_integer(symbol_counter));
            symbol_counter <= symbol_counter + 1;
          end if;
          
        end if;
        if symbol_counter = 10 then -- pulse #10 (1 start, 8 data, 1 stop) has been sent
          --, time to go to idle mode again
          -- pull the tx line high again, actually obsolete, because stop bit is 1
          symbol <= '1';
          ready_sig <= '1';
          state <= idle;
        end if;
    
    end case; 
    
    -- reset clock divider counters when reset signal is on 
    if RST = '1' then
      state <= idle;
      ready_sig <= '1';
      symbol <= '1';
    end if;

  end process;



end architecture;

