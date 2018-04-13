library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;



entity uart_rec is
--   generic(
--     CLK_DIV : integer
--     );
  port(
    CLK_DIV        : in integer;
    CLK            : in std_logic;
    RST            : in std_logic;
    RX             : in std_logic;
    
    DATA_OUT       : out  std_logic_vector(7 downto 0);
    DATA_WAITING   : out std_logic;
    DEBUG          : out std_logic_vector(3 downto 0)
    );
end entity;



architecture uart_rec_arch of uart_rec is

signal clk_div_counter: unsigned(15 downto 0) := x"0000";
signal symbol_pulse : std_logic := '0';
signal symbol_counter: unsigned(3 downto 0) := x"0";

type state_type is (idle,receiving,update_parallel_output);
signal state: state_type := idle;

-- MSB is the stopbit, LSB is the start bit, both are never changed
signal rx_shift_register: std_logic_vector(9 downto 0); 
signal symbol : std_logic := '1';
signal data_waiting_sig: std_logic := '0';
signal current_data_out: std_logic_vector(7 downto 0) := "00000000";
signal symbol_start_pulse : std_logic := '0'; -- just debug
signal rst_clk_div_counter : std_logic;


begin
----------------------------
-- debug
----------------------------

DEBUG(0) <= symbol_start_pulse;
DEBUG(1) <= symbol_pulse;
DEBUG(2) <= data_waiting_sig;
DEBUG(3) <= '0';

----------------------------
-- Inputs
----------------------------
  sync_input : process begin
    wait until rising_edge(CLK);
    symbol <= RX;
  end process;
  
----------------------------
-- Outputs
----------------------------
  sync_output : process begin
    wait until rising_edge(CLK);
    DATA_WAITING <= data_waiting_sig;
    DATA_OUT <= current_data_out;
  end process;
 
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
    -- generates symbol_pulse, a signal that has 1 clock cycle pulses, one symbol duration period apart 
    -- in contrast to the transceiver module, the symbol pulse is generated in the middle of the
    -- symbol period
    --  if clk_div_counter = '0' & CLK_DIV(15 downto 1) then  -- CLK_DIV/2 by >> (right shifting)
    if clk_div_counter =  to_unsigned(CLK_DIV/2,16) then 
      symbol_pulse <= '1';
    else 
      symbol_pulse <= '0';
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
-- State Machine of the Receiver
----------------------------
  state_machine : process begin
    wait until rising_edge(CLK);
    data_waiting_sig <= '0';
    rst_clk_div_counter <= '0';

  --  state machine rules:
  case state is
    when idle =>

      if symbol = '0' then -- the start bit comes!
        state <= receiving;
        -- restart the divcounter
  --       clk_div_counter <= x"0000";
        rst_clk_div_counter<= '1';
        symbol_counter <= x"0";
        
      end if;
    
    when receiving =>
      if symbol_pulse = '1' then
        if symbol_counter <= 9 then -- reception process
          rx_shift_register(to_integer(symbol_counter)) <= symbol;
          symbol_counter <= symbol_counter + 1;
        end if;
        if symbol_counter = 9 then
          state <= update_parallel_output;
        end if;
        

      end if;
    when update_parallel_output =>
      state <= idle;
      -- check start and stop bit consistency
      -- (checking the start bit again seems a little obsolete)
      -- only if bit was received correctly output the data!
      if rx_shift_register(0) = '0' and rx_shift_register(9) = '1' then
        current_data_out <= rx_shift_register(8 downto 1);
        data_waiting_sig <= '1';
      end if;
      
  end case;
  
  -- reset clock divider counters when reset signal is on 
  if RST = '1' then
    symbol_counter <= x"0";
    data_waiting_sig <= '0';
    state <= idle;
  end if;
  
  end process;


end architecture;