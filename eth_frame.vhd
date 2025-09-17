library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- will be running on the same clock as PHY to simplify design

entity eth_frame is
    port(
        tx_clk  : in std_logic; 
        i_en    : in std_logic; -- enable pin to trigger eth transmission
        o_data  : out std_logic_vector(7 downto 0)
    )
end entity;

architecture behavioural of eth_frame is
    type state_t is (IDLE, PREAMBLE, SFD, DEST_ADDR, SRC_ADDR,
                    LENGTH, DATA, CRC);
    signal state : state_t := IDLE;
    signal sig_data : std_logic_vector(7 downto 0) := x"00";
    signal preamble_count : integer range 0 to 5 := "0";
    signal dest_count : integer range 0 to 6 := "0";
    signal src_count : integer range 0 to 6 := "0";
    signal length_count : integer range 0 to 2 := "0";
    signal data_count : integer range 0 to 20 := "0";
begin
    process(tx_clk)
    begin
        case(state) is
            when IDLE =>
                -- if enable pin high then start sending preamble immediately
                -- preamble is always alternating 0s and 1s
                if (i_en) then
                    state       <= PREAMBLE;
                    sig_data    <= "10101010"
                end if;
            
            when PREAMBLE =>
                -- at this stage already 2 bytes from preamble are on their
                -- way out or already transmitted (first through the combinational
                -- logic at the very end and the second in the IDLE stage)
                -- so only 5 bytes left to send
                if preamble_count < 4 then
                    sig_data <= "10101010";
                    preamble_count = preamble_count + 1;
                else
                    -- this would be the last preamble byte left
                    sig_data <= "10101010";
                    state <= SFD;
                end if;
            
            when SFD =>
                -- SFD is always 10101011
                sig_data <= "10101011";
                state <= DEST_ADDR;
            
            when DEST_ADDR =>
                -- hardcoded MAC address
                -- 6 bytes long
                if dest_count < 5 then
                    sig_data <= "11000011";
                    dest_count <= dest_count + 1;
                else
                    sig_data <= "11000011";
                    state <= SRC_ADDR;
                end if;
            
            when SRC_ADDR =>
                -- again hardcoded MAC address
                -- again 6 bytes long (LSB of first byte must be 0)
                if src_count < 5 then
                    sig_data <= "01000010";
                    src_count <= dest_count + 1;
                else
                    sig_data <= "01000010";
                    state <= LENGTH;
                end if;
            
            when LENGTH =>
                -- length of payload/data 
                -- harcoded to 20 bytes
                if length_count < 1 then
                    sig_data <= "00010100";
                    length_count <= length_count + 1;
                else
                    sig_data <= "00000000";
                    state <= DATA;
                end if;
            
            when DATA =>
                -- hardcoded 20 bytes of data
                if data_count < 19 then
                    sig_data <= "10000001";
                    data_count <= data_count + 1;
                else
                    sig_data <= "10000001";
                    state <= CRC;
                end if;
            
            when CRC =>
                
        end case;
    end process;
    -- this logic is used to prevent one cycle latency from when 
    -- the enable is triggered
    o_data <= "10101010" when state == IDLE and i_en = '1' else
                sig_data;
end behavioural;