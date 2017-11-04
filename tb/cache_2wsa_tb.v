`timescale 1ns / 100ps
module cache_2wsa_tb;

	// Inputs
	reg clock;
	reg reset;
	reg [15:0] addr_cpu;
	reg read_cpu_enable;
	reg write_cpu_enable;
	reg ready_memory;

	// Outputs
	wire [15:0] addr_mem;
	wire read_mem_enable;
	wire write_mem_enable;
	wire stall_cpu;
	wire [13:0] read_tag_cache_0;
	wire [13:0] read_tag_cache_1;
	wire hit;
	wire hit_cache_0;
	wire hit_cache_1;
	wire valid;
	wire valid_bit_cache_0;
	wire valid_bit_cache_1;
	wire dirty;
	wire dirty_bit_cache_0;
	wire dirty_bit_cache_1;
	wire [10:0] tagdata;
	wire [2:0] index;
	wire [1:0] bytsel;
	// Bidirs
	wire [7:0] data_cpu;
	wire [7:0] data_mem;
	
	reg [7:0] dcpu;
	reg [7:0] wcpu;
	reg [7:0] dmem;
	reg [7:0] wmem;
	
	cache_controller uut (
		.clock(clock), 
		.reset(reset), 
		.data_cpu(data_cpu), 
		.data_mem(data_mem), 
		.addr_cpu(addr_cpu), 
		.addr_mem(addr_mem), 
		.read_cpu_enable(read_cpu_enable), 
		.write_cpu_enable(write_cpu_enable), 
		.read_mem_enable(read_mem_enable), 
		.write_mem_enable(write_mem_enable),
		.read_tag_cache_0(read_tag_cache_0),
		.read_tag_cache_1(read_tag_cache_1),
		.hit(hit),
		.hit_cache_0(hit_cache_0),
		.hit_cache_1(hit_cache_1),
		.valid(valid),
		.valid_bit_cache_0(valid_bit_cache_0),
		.valid_bit_cache_1(valid_bit_cache_1),
		.dirty(dirty),
		.dirty_bit_cache_0(dirty_bit_cache_0),
		.dirty_bit_cache_1(dirty_bit_cache_1),
		.tagdata(tagdata),
		.index(index),
		.bytsel(bytsel),
		.stall_cpu(stall_cpu), 
		.ready_memory(ready_memory)
	);

	assign data_cpu = write_cpu_enable? wcpu : 8'dZ;
	assign data_mem = !write_mem_enable? dmem : 8'dZ;

	initial begin
	clock = 1'd0;
	forever
	#10 clock = ~clock;
	end
	
	task delay;
	begin
	@(negedge clock);
	end
	endtask		
		
	
	initial begin
		// Initialize Inputs
		reset = 0;
		addr_cpu = 0;
		read_cpu_enable = 0;
		write_cpu_enable = 0;
		ready_memory = 1;
		wcpu = 0;
		
		repeat(4)
		delay;
		
		reset = 1;
		
		delay;
		delay;
		// Simple Read from location
		read_cpu_enable = 1'd1;
		addr_cpu = 16'b0000_0000_1001_0011;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd1;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd0;
		delay;
		delay;
		// Simple Read to same location
		write_cpu_enable = 1'd1;
		wcpu = 8'h23;
		addr_cpu = 16'b0000_0000_1001_0011;
		delay;
		delay;
		write_cpu_enable = 1'd0;
		delay;
		delay;

		read_cpu_enable = 1'd1;
		addr_cpu = 16'b0000_0000_1001_0011;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd1;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd0;
		delay;
		
		// Simple Read Miss with dirty bit 0 policy check, reads data from Main Memory
		
		delay;
		read_cpu_enable = 1'd1;
		addr_cpu = 16'b1100_0000_1000_1011;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd1;
		dcpu = data_cpu;
		@(posedge read_mem_enable);
		ready_memory = 0;
		repeat(4)
		delay;
		
		ready_memory = 1;
		
		delay;
		
		dmem = 8'h11;
		
		delay;
		
		dmem = 8'h22;
		
		delay;
		
		dmem = 8'h33;
		
		delay;
		
		dmem = 8'h44;
		
		delay;
		
		delay;
		
		delay;
		
		delay;
		
		read_cpu_enable = 1'd0;
		
		// Simple Read Miss Eviction Policy Test
		
		delay;
		read_cpu_enable = 1'd1;
		addr_cpu = 16'b1100_0001_0001_1111;
		dcpu = data_cpu;
		delay;
		read_cpu_enable = 1'd1;
		dcpu = data_cpu;
		@(posedge write_mem_enable);
		ready_memory = 0;
		repeat(4)
		delay;
		
		ready_memory = 1;
		
		@(posedge read_mem_enable);
		ready_memory = 0;
		repeat(4)
		delay;
		
		ready_memory = 1;
		
		delay;
		
		dmem = 8'hAA;
		
		delay;
		
		dmem = 8'hBB;
		
		delay;
		
		dmem = 8'hCC;
		
		delay;
		
		dmem = 8'hDD;
		
		delay;
		
		delay;
		
		delay;
		
		delay;
		
		read_cpu_enable = 1'd0;
		
		repeat(10)
		delay;
		
		
		#100 $finish;

	end
      
endmodule

