from vunit import VUnit


def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv()

# Create library 'lib'
lib = vu.add_library("lib")

# Add all files ending in .vhd in current working directory to library
lib.add_source_files("./*.vhd")
lib.add_source_files("../src/gowin_rpll/gowin_rpll.v", file_type="systemverilog")
lib.add_source_files("../src/psram_controller.vhd")
lib.add_source_files("../src/psram_test_top.v", file_type="systemverilog")
lib.add_source_files("../src/uart_tx.v", file_type="systemverilog")
lib.add_source_files("../src/uart_tx.v", file_type="systemverilog")
lib.add_source_files("../library/3rdparty/inifineon/s27kl0642/s27kl0642.v", file_type="verilog")
lib.add_source_files("C:/Gowin/Gowin_V1.9.8.09_Education/IDE/simlib/gw1n/prim_sim.v", file_type="systemverilog")
#lib.add_source_files("C:/Gowin/Gowin_V1.9.8.09_Education/IDE/simlib/gw1n/prim_tsim.v", file_type="systemverilog")

tb = lib.test_bench("test_tb")

cfg = tb.add_config("latency_4", generics=dict( \
	LATENCY = 4, \
	FREQ = 96000000 \
	))

cfg2 = tb.add_config("latency_3", generics=dict( \
	LATENCY = 3, \
	FREQ  = 81000000 \
	))

# Run vunit function
vu.main()
