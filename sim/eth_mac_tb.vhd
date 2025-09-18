library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;


entity eth_mac_tb is
end eth_mac_tb;

architecture Behavioral of eth_mac_tb is
    component eth_frame is
        generic(
            DATA_LENGTH : integer range 0 to 1500 := 20
        );
        port(
            tx_clk  : in std_logic := '0'; 
            i_en    : in std_logic := '0'; -- enable pin to trigger eth transmission
            o_data  : out std_logic_vector(7 downto 0)
        );
    end component;
    -- signals
    signal tx_clk   : std_logic := '1';
    signal i_en     : std_logic := '0';
    signal o_data   : std_logic_vector(7 downto 0);
begin
    eth_frame_instance : entity work.eth_frame
    port map (
        tx_clk => tx_clk,
        i_en   => i_en,
        o_data => o_data
    );
    
    process
    begin
        tx_clk <= not tx_clk;
        wait for 40ns;
    end process;
    
    process
    begin
        wait for 40ns;
        i_en <= '1';
    end process;
end Behavioral;
