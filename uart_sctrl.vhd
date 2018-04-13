library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_sctrl is
  generic(
    CLOCK_SPEED : integer := 33250000
    );
  port(
    CLK     : in  std_logic;
    RESET   : in  std_logic := '0';
    
    --the connection to the PC
    UART_RX : in  std_logic;
    UART_TX : out std_logic;
    
    --in case you want to send information from PC to the FPGA - ignore these ports if not
    DATA_OUT  : out std_logic_vector(31 downto 0);
    ADDR_OUT  : out std_logic_vector(7 downto 0);
    WRITE_OUT : out std_logic;
    READ_OUT  : out std_logic;

    --assign data and put a short '1' to ready_in to start send a data word
    DATA_IN   : in  std_logic_vector(31 downto 0) := (others => '0');
    SEND_IN   : in  std_logic := '0';
    BUSY_OUT  : out std_logic
    );
end entity;


architecture uart_sctrl_arch of uart_sctrl is

constant CLK_DIV : integer := CLOCK_SPEED/115200;

signal rx_data   : std_logic_vector(7 downto 0);
signal tx_data   : std_logic_vector(7 downto 0);
signal rx_ready  : std_logic;
signal tx_send   : std_logic;
signal tx_ready  : std_logic;
signal bytecount : integer range 0 to 15;
type   rx_state_t is (IDLE,START,START2,DO_COMMAND);
type   tx_state_t is (DO_READ,SEND_BYTE1,SEND_BYTE2,SEND_BYTE3,SEND_TERM,SEND_FINISH);
signal state     : rx_state_t;
signal txstate   : tx_state_t;
signal addr_data : std_logic_vector(39 downto 0);

signal txtimer   : unsigned(25 downto 0) := (others => '0');
signal txdata    : std_logic_vector(31 downto 0);
signal txbytecount : integer range 0 to 15;

signal timer     : unsigned(25 downto 0) := (others => '0');
signal timeout   : std_logic := '0';
signal cmd_wr    : std_logic := '0';
signal cmd_rd    : std_logic := '0';

begin


THE_RX : entity work.uart_rec
  port map(
    CLK_DIV      => CLK_DIV,
    CLK          => CLK,
    RST          => RESET,
    RX           => UART_RX,
    DATA_OUT     => rx_data,
    DATA_WAITING => rx_ready
    );

THE_TX : entity work.uart_trans
  port map(
    CLK_DIV      => CLK_DIV,
    CLK          => CLK,
    RST          => RESET,
    DATA_IN      => tx_data,
    SEND         => tx_send,
    READY        => tx_ready,
    TX           => UART_TX
    );
    
PROC_RX : process 
  variable tmp,tmp2 : unsigned(7 downto 0);
begin
  wait until rising_edge(CLK);
  READ_OUT  <= '0';
  WRITE_OUT <= '0';
  timer     <= timer + 1;
  case state is
    when IDLE =>
      cmd_rd <= '0';
      cmd_wr <= '0';
      bytecount  <= 9;
      timer  <= (others => '0');
      if rx_ready = '1' then
        state <= START;
        if rx_data = x"52" then
          cmd_rd <= '1';
        elsif rx_data = x"57" then
          cmd_wr <= '1';
        end if;
      end if;

    when START =>
      if rx_ready = '1' then
        if rx_data >= x"40" then  
          tmp2 := unsigned(rx_data) + x"09";
        else
          tmp2 := unsigned(rx_data);
        end if;
        state <= START2;
      end if;      
        
    when START2 =>    
      addr_data(bytecount*4+3 downto bytecount*4) <= std_logic_vector(tmp2(3 downto 0));
      if (bytecount = 0 and cmd_wr = '1') or (bytecount = 8 and cmd_rd = '1') then
        state <= DO_COMMAND;
      else
        bytecount <= bytecount - 1;
        state <= START;
      end if;
      
    when DO_COMMAND =>
      WRITE_OUT <= cmd_wr;
      READ_OUT  <= cmd_rd;
      DATA_OUT  <= addr_data(31 downto 0);
      ADDR_OUT  <= addr_data(39 downto 32);
      state <= IDLE;
  end case;

  if RESET = '1' or timeout = '1' then
    state <= IDLE;
    timer <= (others => '0');
  end if;
end process;


PROC_TX : process 
  variable tmp,tmp2 : unsigned(7 downto 0);
begin
  wait until rising_edge(CLK);
  tx_send   <= '0';
  case txstate is
    when DO_READ =>
      if SEND_IN = '1' then
        txdata(31 downto 0) <= DATA_IN;
        tx_send <= '1';
        tx_data <= x"52";
        txstate   <= SEND_BYTE1;
        txbytecount <= 7;
      end if;

    when SEND_BYTE1 =>
      tmp := x"0" & unsigned(txdata(txbytecount*4+3 downto txbytecount*4));
      txstate <= SEND_BYTE2;
      
    when SEND_BYTE2 =>     
      if tmp > x"09" then
        tmp := tmp + x"41" - x"0a";
      else
        tmp := tmp + x"30";
      end if;     
      txstate <= SEND_BYTE3;
    
    
    when SEND_BYTE3 =>
      
      if tx_ready = '1' then
        tx_data <= std_logic_vector(tmp);
        tx_send <= '1';
        if txbytecount = 0 then
          txstate <= SEND_TERM;
        else
          txbytecount <= txbytecount - 1;
          txstate <= SEND_BYTE1;
        end if;      
      end if;

      
      
    when SEND_TERM=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= x"0a";
        txstate   <= SEND_FINISH;
      end if;
    when SEND_FINISH=>
      if tx_ready = '1' then
        tx_send <= '1';
        tx_data <= x"0d";
        txstate   <= DO_READ;
      end if;
        
  end case;

  if RESET = '1' then
    txstate <= DO_READ;
  end if;
end process;

timeout <= timer(25);

BUSY_OUT <= '0' when txstate = DO_READ else '1';

end architecture;