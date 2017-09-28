`timescale 1ns / 1ps

module cache_1_data(
				input 	clock,			
				input 	[AWIDTH-1:0] addr,	
				input 	[DWIDTH-1:0] data_in,	
				input 	write_enable,			
				output  [DWIDTH-1:0] data_out	
				
		   );



parameter AWIDTH = 3;		
parameter DWIDTH = 32;	

localparam DEPTH  = 1 << AWIDTH;

reg [DWIDTH-1:0] mem_array [0:DEPTH-1];


initial
begin
	$readmemb("data_cache_1.txt", mem_array);
end

reg [AWIDTH-1:0] rd_addr;

always@(posedge clock)
begin
	if(write_enable)
		mem_array[addr] <= data_in;	

rd_addr <= addr;		
end

assign data_out = mem_array[rd_addr];

endmodule
