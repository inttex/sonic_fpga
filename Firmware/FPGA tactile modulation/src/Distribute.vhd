library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.ALL;

entity Distribute is
    port (
		  CLK : in  STD_LOGIC;
		  
		  byte_in : in  STD_LOGIC := '0';
		  q_in : in STD_LOGIC_VECTOR (7 downto 0);
		  
		  swap_out : out  STD_LOGIC := '0';
		  set_out : out STD_LOGIC := '0';
		  data_out: out STD_LOGIC_VECTOR (7 downto 0); 
		  address : out std_logic_vector(7 downto 0); --256 addresses
		  
		  ampModStep : out std_logic_vector(4 downto 0); --256 addresses
		  
		  debug_swap : out STD_LOGIC := '0'
	 );
end Distribute;

architecture Behavioral of Distribute is

type T_PHASE_CORRECTION is array (0 to 255) of integer range 0 to 32;
	constant PHASE_CORRECTION : T_PHASE_CORRECTION := (23,11,13,11,26,28,26,26,11,12,13,26,28,11,12,12,10,27,27,27,27,12,12,13,26,26,27,25,11,12,11,30,12,11,10,25,14,10,11,27,28,28,28,10,10,11,30,28,11,30,28,28,30,12,12,28,28,26,26,26,28,13,29,27,29,28,27,11,29,30,10,29,30,28,28,12,12,13,10,29,12,27,28,10,11,27,13,14,11,27,26,25,12,28,12,31,27,12,28,28,12,13,11,13,29,28,12,27,11,11,0,10,29,12,12,28,28,28,29,11,12,28,29,10,11,12,11,11,13,12,11,10,27,11,11,29,28,27,12,10,29,28,28,27,12,27,12,11,28,27,11,27,12,29,12,26,27,11,12,27,12,12,28,27,11,10,13,12,10,28,13,11,11,28,30,12,29,29,13,12,11,12,12,27,29,28,11,28,11,12,28,28,29,12,27,10,27,12,12,13,11,27,29,25,11,11,11,26,11,11,30,9,27,29,26,11,10,14,13,11,26,10,10,27,11,28,29,9,10,28,11,10,27,10,13,10,27,29,11,11,28,28,26,25,26,26,28,27,12,27,12,26,26,12,27,26);
		--0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
	 signal s_ByteCounter : integer range 0 to 256 := 0;
	  
	 signal s_data_out : STD_LOGIC_VECTOR (7 downto 0) := (others => '0');
	 signal s_address : std_logic_vector(7 downto 0) := (others => '0');
	 signal s_swap_out :  STD_LOGIC := '0';
	 signal s_set_out : STD_LOGIC := '0';
	 signal s_ampModStep : std_logic_vector(4 downto 0) := "01010";
	 signal s_debug_swap : STD_LOGIC := '0';
begin
    Distribute: process (clk) begin
        if (rising_edge(clk)) then
				if (byte_in = '1') then --a byte of data is ready
					
					if (q_in = "11111110") then --254 is start phases
						s_ByteCounter <= 0;
						s_swap_out <= '0';
						s_set_out <= '0';
					elsif (q_in = "11111101") then --253 is swap
						s_debug_swap <= not s_debug_swap;
						s_set_out <= '0';
						s_swap_out <= '1';
						s_ByteCounter <= 0;
				   elsif (q_in(7 downto 5) = "101") then -- "101XXXXX" is step set
						s_ampModStep <= q_in(4 downto 0);
					else -- any other byte is for the delay lines. 
						--s_data_out <= q_in;
						s_address <= std_logic_vector(to_unsigned(s_ByteCounter, 8));
						s_swap_out <= '0';
						s_set_out <= '1';
						s_ByteCounter <= s_ByteCounter + 1;
						
						if (q_in = "00100000") then
							-- Java sends 32 for OFF (phase value 32)
							-- This will never match counter 0-31, so emitter stays OFF
							s_data_out <= q_in; -- 32 represents "off" so no phase correction
						else
							-- Java sends phase 0-15 (16 divisions)
							-- Add phase correction and mask to 6 bits (0-63)
							-- AllChannels takes bits(5:0) directly now (no bit shift)
							-- Values 0-31 will match counter (emitter ON), 32-63 will not match (emitter OFF)
							s_data_out <= std_logic_vector( to_unsigned( to_integer(unsigned(q_in)) + PHASE_CORRECTION(s_ByteCounter), 8 ) ) and "00111111";
						end if;
						
					end if;
				else
					s_swap_out <= '0';
					s_set_out <= '0';
				end if;
				
				
		  end if;
 end process;
 debug_swap <= s_debug_swap;
 data_out <= s_data_out;
 address <= s_address;
 swap_out <= s_swap_out;
 set_out <= s_set_out;
 ampModStep <= s_ampModStep;
 
end Behavioral;
