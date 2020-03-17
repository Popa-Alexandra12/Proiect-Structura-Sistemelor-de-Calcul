----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11/18/2019 08:39:34 AM
-- Design Name: 
-- Module Name: project_module - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity project_module is
  Port (btn_u : in  STD_LOGIC;
        clk_i : in  STD_LOGIC;
        rst_i : in STD_LOGIC;
        uart_txd : out  STD_LOGIC;
        pmodbt_rst : out  STD_LOGIC;
        pmodbt_cts : out  STD_LOGIC;
        pdm_m_clk_o : out std_logic;
        pdm_m_data_i : in  std_logic;
        pdm_lrsel_o : out std_logic);
end project_module;

architecture Behavioral of project_module is
signal en_des : STD_LOGIC := '0';
signal done_des : STD_LOGIC := '0';
signal data_des : STD_LOGIC_VECTOR(15 downto 0) := "0000000000000000";
signal btnu_int : std_logic;
constant SECONDS_TO_RECORD    : integer := 4; 
constant PDM_FREQ_HZ          : integer := 1024000; 
constant SYS_clk_FREQ_MHZ     : integer := 100;
constant NR_OF_BITS           : integer := 16;
constant NR_SAMPLES_TO_REC    : integer := (((SECONDS_TO_RECORD*PDM_FREQ_HZ)/NR_OF_BITS) - 1);
type state_type is (stIdle, stRecord, stInter, stSend);
signal state : state_type;
signal next_state : state_type;
signal addr : STD_LOGIC_VECTOR(17 downto 0) := (others => '0'); 
signal write_en_mem : STD_LOGIC := '0';
signal data_o_mem : STD_LOGIC_VECTOR(15 downto 0) := (others => '0'); 
signal cntRecSamples : INTEGER := 0;
signal done_des_dly : STD_LOGIC := '0';
signal send_uart : STD_LOGIC := '0';
signal ready : STD_LOGIC := '0';
signal done_ser : STD_LOGIC := '0';
signal done_ser_dly : STD_LOGIC := '0';
signal cntSentSamples : INTEGER := 0;
signal addr_record : STD_LOGIC_VECTOR(17 downto 0) := (others => '0'); 
signal addr_send : STD_LOGIC_VECTOR(17 downto 0) := (others => '0');
signal half : STD_LOGIC := '0';
signal data_half_to_send : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
begin
------------------------------------------------------------------------
-- Debouncer
------------------------------------------------------------------------
    debouncer_start_record : entity WORK.Dbncr 
           generic map(
              NR_OF_CLKS           => 4095)
           port map(
              clk_i                => clk_i,
              sig_i                => btn_u,
              pls_o                => btnu_int);
------------------------------------------------------------------------
-- Deserializer
------------------------------------------------------------------------
    pdm_des : entity WORK.PdmDes 
           generic map(
              C_NR_OF_BITS         => NR_OF_BITS,
              C_SYS_CLK_FREQ_MHZ   => SYS_CLK_FREQ_MHZ,
              C_PDM_FREQ_HZ        => PDM_FREQ_HZ)
           port map(
              clk_i                => clk_i,
              en_i                 => en_des,
              done_o               => done_des,
              data_o               => data_des,
              pdm_m_clk_o          => pdm_m_clk_o,
              pdm_m_data_i         => pdm_m_data_i,
              pdm_lrsel_o          => pdm_lrsel_o);

    process(clk_i)
    begin
       if rising_edge(clk_i) then
          if state = stRecord then
             if done_des = '1' then
                cntRecSamples <= cntRecSamples + 1;
             end if;
             if done_des_dly = '1' then
                addr_record <= addr_record + 1;
             end if;
          else
             cntRecSamples <= 0;
             addr_record <= (others => '0');
          end if;
          done_des_dly <= done_des;
       end if;
    end process;   
------------------------------------------------------------------------
-- Memory
------------------------------------------------------------------------
    ram_memory : entity WORK.memory
            port map (
                clk      => clk_i,
                addr     => addr,
                data     => data_des,
                memWrite => write_en_mem,
                data_o   => data_o_mem);
------------------------------------------------------------------------
--  FSM
------------------------------------------------------------------------
    SYNC_PROC: process(clk_i)
    begin
       if rising_edge(clk_i) then
           if rst_i = '1' then
               state <= stIdle;
           else
               state <= next_state;
           end if;        
       end if;
    end process;
     
    NEXT_STATE_DECODE: process(state, btnu_int, cntRecSamples, cntSentSamples)
    begin
       next_state <= state;
       case (state) is
          when stIdle =>
             if btnu_int = '1' then
                next_state <= stRecord;
             end if;
          when stRecord =>
             if cntRecSamples = NR_SAMPLES_TO_REC then
                next_state <= stInter;
             end if;
          when stInter =>
             next_state <= stSend;
          when stSend =>
             if btnu_int = '1' then
                next_state <= stIdle;
             elsif cntSentSamples = NR_SAMPLES_TO_REC then 
                next_state <= stIdle;
             end if;
          when others =>
             next_state <= stIdle;
       end case;
    end process;
    
   --Decode Outputs from the State Machine
   OUTPUT_DECODE: process(clk_i)
   begin
      if rising_edge(clk_i) then
         case (state) is
            when stIdle =>
               send_uart    <= '0';
               en_des       <= '0';
               addr         <= (others => '0');
               write_en_mem <= '0';
            when stRecord =>
               addr         <= addr_record;
               en_des       <= '1';
               write_en_mem <= '1';
            when stInter =>
               en_des       <= '0';
               write_en_mem <= '0';
            when stSend =>
               addr         <= addr_send;
               if half = '0' then
                   data_half_to_send <= data_o_mem(15 downto 8);
               else
                   data_half_to_send <= data_o_mem(7 downto 0);
               end if;
               if cntSentSamples = NR_SAMPLES_TO_REC then
                   send_uart <= '0';
               else
                   send_uart <= ready; 
               end if;            
            when others => 
               send_uart    <= '0';
               en_des       <= '0';
               addr         <= (others => '0');
               write_en_mem <= '0';
         end case;
      end if;
   end process;
------------------------------------------------------------------------
--  UART_TX_CTRL
------------------------------------------------------------------------   
   uart : entity WORK.UART_TX_CTRL 
        port map (
            SEND    => send_uart,
            DATA    => data_half_to_send,   
            CLK     => clk_i,
            READY   => ready,
            UART_TX => uart_txd,
            DONE    => done_ser);
            
   -- count the sent samples
   process(clk_i)
   begin
      if rising_edge(clk_i) then
         if state = stSend then
            if done_ser = '1' then
               half <= not half;
            end if;
            if done_ser_dly = '1' then
               if half='0' then
                   addr_send <= addr_send + 1;
                   cntSentSamples <= cntSentSamples + 1; 
               end if;
            end if;
         else
            cntSentSamples <= 0;
            addr_send <= (others => '0');
         end if;
         done_ser_dly <= done_ser;
      end if;
   end process;
   
   pmodbt_rst <= '1';
   pmodbt_cts <= '0';
end Behavioral;
