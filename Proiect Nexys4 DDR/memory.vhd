----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 12/12/2019 04:58:49 PM
-- Design Name: 
-- Module Name: memory - Behavioral
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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity memory is
    Port ( clk : in STD_LOGIC;
           addr : in STD_LOGIC_VECTOR(17 downto 0);
           data : in STD_LOGIC_VECTOR(15 downto 0);
           memWrite : in STD_LOGIC;
           data_o : out STD_LOGIC_VECTOR(15 downto 0)); 
end memory;

architecture Behavioral of memory is
type memorie is array(0 to 255999) of STD_LOGIC_VECTOR(15 downto 0); 
signal RAM : memorie := (others=> "0000000000000000");
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if addr < CONV_STD_LOGIC_VECTOR(256000,18) then
                data_o<=RAM(conv_integer(addr));
            else
                data_o<= (others =>'0');
            end if;
            if(memWrite='1') then
                if addr < CONV_STD_LOGIC_VECTOR(256000,18) then
                    RAM(conv_integer(addr))<=data;    
                end if;
            end if;    
        end if;
    end process; 
end Behavioral;
