library vunit_lib;
context vunit_lib.vunit_context;


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;
use std.textio.all;

library work;

entity test_tb is
	generic (
		runner_cfg : string;
		FREQ 	: in integer := 96000000;               -- Actual clk frequency, to time 150us initialization delay
		LATENCY : in integer := 4;                      -- tACC (Initial Latency) in W955D8MBYA datasheet:
		PHASE   : in real := 90.0						-- degrees of phase lag for clk_p
		);
end test_tb;

architecture rtl of test_tb is

    signal i_clk           : std_logic;
    signal i_clk_p         : std_logic;
    signal i_resetn        : std_logic;
    signal i_read          : std_logic;
    signal i_write         : std_logic;
    signal i_addr          : std_logic_vector(21 downto 0);
    signal i_din           : std_logic_vector(15 downto 0);
    signal i_byte_write    : std_logic;
    signal i_dout          : std_logic_vector(15 downto 0);
    signal i_busy          : std_logic;

	signal i_O_psram_ck			: std_logic_vector(1 downto 0);
	signal i_O_psram_ck_n		: std_logic_vector(1 downto 0);
	signal i_IO_psram_rwds		: std_logic_vector(1 downto 0);
	signal i_IO_psram_dq		: std_logic_vector(15 downto 0);
	signal i_O_psram_reset_n	: std_logic_vector(1 downto 0);
	signal i_O_psram_cs_n		: std_logic_vector(1 downto 0);

	signal i_GSRI				: std_logic;

	constant t_PER_lag : time := (1000000 us / FREQ) * (PHASE / 360.0);

begin
	p_clk:process
	constant PER2 : time := 500000 us / FREQ;
	begin
		i_clk <= '0';
		wait for PER2;
		i_clk <= '1';
		wait for PER2;
	end process;

	i_clk_p <= transport i_clk after t_PER_lag;

	p_main:process
	variable v_time:time;

	procedure DO_INIT is
	begin

		wait for 1 us;
		i_resetn <= '0';
		i_GSRI <= '0';
		i_read <= '0';
		i_write <= '0';
		i_addr <= (others => '0');
		i_din <= (others => '0');
		wait for 10 us;
		i_resetn <= '1';
		i_GSRI <= '1';
		wait until i_busy = '0';

	end procedure;

	procedure DO_WRITE_BYTE(address : integer; data : integer) is
	begin
		


		i_addr <= std_logic_vector(to_unsigned(address, i_addr'length));
		i_din <= std_logic_vector(to_unsigned(data, 8)) & std_logic_vector(to_unsigned(data, 8));
		i_read <= '0';
		i_write <= '1';
		i_byte_write <= '1';
		wait until rising_edge(i_clk) and i_busy = '0';
		i_write <= '0';
		wait until i_busy = '0';

	end procedure;

	procedure DO_READ_BYTE(address : integer; data : out integer) is
	begin
		
		i_addr <= std_logic_vector(to_unsigned(address, i_addr'length));
		i_read <= '1';
		i_write <= '0';
		i_byte_write <= '1';
		wait until rising_edge(i_clk) and i_busy = '0';
		i_read <= '0';
		wait until i_busy = '0';
		if to_unsigned(address,1) = "0" then
			data := to_integer(unsigned(i_dout(7 downto 0)));
		else
			data := to_integer(unsigned(i_dout(15 downto 8)));
		end if;

	end procedure;

	procedure DO_READ_BYTE_C(address : integer; expect_data : integer) is
	variable D:integer;
	begin
		DO_READ_BYTE(address, D);
		assert D = expect_data report "read address " & to_hstring(to_unsigned(address, 21)) & " returned " & to_hstring(to_unsigned(D, 8)) & " expected " & to_hstring(to_unsigned(expect_data, 8));
	end procedure;


	begin

		test_runner_setup(runner, runner_cfg);


		while test_suite loop

			if run("write then read") then

				DO_INIT;
				DO_WRITE_BYTE(16#100#, 16#A0#);
				DO_WRITE_BYTE(16#200#, 16#5A#);
				DO_READ_BYTE_C(16#100#, 16#A0#);
				DO_READ_BYTE_C(16#200#, 16#5A#);

				wait for 1 us;

			elsif run("long write then read") then

				DO_INIT;
				for i in 100 to 202 loop
					DO_WRITE_BYTE(i, i);
				end loop;

				wait for 1 us;

				for i in 100 to 200 loop
					DO_READ_BYTE_C(i,i);
				end loop;
	
				wait for 1 us;

			end if;

		end loop;

		wait for 3 us;

		test_runner_cleanup(runner); -- Simulation ends here
	end process;

	e_dut:entity work.PsramController
    generic map (
        FREQ          => FREQ,
        LATENCY       => LATENCY				-- 3 (max 83Mhz), 4 (max 104Mhz), 5 (max 133Mhz) or 6 (max 166Mhz)
        )
    port map (
        clk           => i_clk,
        clk_p         => i_clk_p,
        resetn        => i_resetn,
        read          => i_read,
        write         => i_write,
        addr          => i_addr,
        din           => i_din,
        byte_write    => i_byte_write,

        dout          => i_dout,
        busy          => i_busy,

        O_psram_ck		=> i_O_psram_ck,
        IO_psram_rwds	=> i_IO_psram_rwds,
        IO_psram_dq		=> i_IO_psram_dq,
        O_psram_cs_n	=> i_O_psram_cs_n
        );


	e_psram:entity work.s27kl0642
	port map (
    DQ7      => i_IO_psram_dq(7),
    DQ6      => i_IO_psram_dq(6),
    DQ5      => i_IO_psram_dq(5),
    DQ4      => i_IO_psram_dq(4),
    DQ3      => i_IO_psram_dq(3),
    DQ2      => i_IO_psram_dq(2),
    DQ1      => i_IO_psram_dq(1),
    DQ0      => i_IO_psram_dq(0),
    RWDS     => i_IO_psram_rwds(0),

    CSNeg    => i_O_psram_cs_n(0),
    CK       => i_O_psram_ck(0),
	CKn		 => i_O_psram_ck_n(0),
    RESETNeg => i_O_psram_reset_n(0)
    );

	GSR: entity work.GSR
	port map (
		GSRI => i_GSRI
		);

end rtl;
