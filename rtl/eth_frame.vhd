library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- will be running on the same clock as PHY to simplify design

entity eth_frame is
    generic(
        DATA_LENGTH : integer range 0 to 1500 := 20
    );
    port(
        tx_clk  : in std_logic; 
        i_en    : in std_logic; -- enable pin to trigger eth transmission
        o_data  : out std_logic_vector(7 downto 0)
    );
end entity;

architecture behavioural of eth_frame is
    type state_t is (IDLE, PREAMBLE, SFD, DEST_ADDR, SRC_ADDR,
                    LENGTH, DATA, CRC);
    signal state : state_t := IDLE;
    signal sig_data : std_logic_vector(7 downto 0) := x"00";
    signal preamble_count : integer range 0 to 5 := 0;
    signal dest_count : integer range 0 to 6 := 0;
    signal src_count : integer range 0 to 6 := 0;
    signal length_count : integer range 0 to 2 := 0;
    signal data_count : integer range 0 to 20 := 0;
    -- CRC signals
    signal sig_crc : std_logic_vector(31 downto 0) := (others => '1');
    signal sig_running_crc : std_logic_vector(31 downto 0) := (others => '1'); -- to probe the var
    -- function to calculate CRC
    function crc32_update(
        crc     : std_logic_vector(31 downto 0);
        data    : std_logic_vector(7 downto 0)
    ) return std_logic_vector is
        constant POLY   : std_logic_vector(31 downto 0) := x"EDB88320";
        variable c      : std_logic_vector(31 downto 0) := crc;
        variable b      : std_logic_vector(7 downto 0) := data;
        variable fb     : std_logic; -- feedback bit
    begin
        for i in 0 to 7 loop
            fb := c(0) xor b(i);        -- feedback bit is the xor of lsb of crc and data bit
            c := '0' & c(31 downto 1);  -- shift right
            if fb = '1' then
                c := c xor POLY;
            end if;
        end loop;
        return c;
    end function;
begin
    frame_gen: process(tx_clk)
        variable var_data : std_logic_vector(7 downto 0) := x"00";
        variable var_crc : std_logic_vector(31 downto 0) := (others => '1');
    begin
        if rising_edge(tx_clk) then
            case(state) is
                when IDLE =>
                    -- if enable pin high then start sending preamble immediately
                    -- preamble is always alternating 0s and 1s
                    if (i_en = '1') then
                        state       <= PREAMBLE;
                        var_data    := "10101010";
                    end if;
                
                when PREAMBLE =>
                    -- at this stage already one bytes from preamble are on their
                    -- way out or already transmitted (first through the combinational
                    -- logic at the very end and the second in the IDLE stage)
                    -- so only 6 bytes left to send
                    if preamble_count < 5 then
                        var_data := "10101010";
                        preamble_count <= preamble_count + 1;
                    else
                        -- this would be the last preamble byte left
                        var_data := "10101010";
                        state <= SFD;
                    end if;
                
                when SFD =>
                    -- SFD is always 10101011
                    var_data := "10101011";
                    state <= DEST_ADDR;
                
                when DEST_ADDR =>
                    -- hardcoded MAC address
                    -- 6 bytes long
                    if dest_count < 5 then
                        var_data := "11000011";
                        dest_count <= dest_count + 1;
                    else
                        var_data := "11000011";
                        state <= SRC_ADDR;
                    end if;
                
                when SRC_ADDR =>
                    -- again hardcoded MAC address
                    -- again 6 bytes long (LSB of first byte must be 0)
                    if src_count < 5 then
                        var_data := "01000010";
                        src_count <= src_count + 1;
                    else
                        var_data := "01000010";
                        state <= LENGTH;
                    end if;
                
                when LENGTH =>
                    -- length of payload/data 
                    -- harcoded to 20 bytes
                    if length_count < 1 then
                        var_data := "00010100";
                        length_count <= length_count + 1;
                    else
                        var_data := "00000000";
                        state <= DATA;
                    end if;
                
                when DATA =>
                    if data_count < DATA_LENGTH - 1 then
                        var_data := "10000001";
                        data_count <= data_count + 1;
                    else
                        var_data := "10000001";
                        state <= CRC;
                    end if;
                
                when CRC =>
                    state <= IDLE;
                    sig_crc <= not var_crc;
                when others =>
                    state <= IDLE;
                    
            end case;
            
            if state /= PREAMBLE and state /= SFD and state /= CRC and state /= IDLE then
              var_crc := crc32_update(var_crc, var_data);  -- byte-wise LFSR function, LSB-first
            end if;
            
            sig_running_crc <= var_crc;
            sig_data <= var_data;
        end if;
    end process;
    -- this logic is used to prevent one cycle latency from when 
    -- the enable is triggered
    o_data <= sig_data;
end behavioural;