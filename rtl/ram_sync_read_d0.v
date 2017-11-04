
module ram_sync_read_d0(
				input 	clock,			
				input 	[AWIDTH-1:0] addr,	
				input 	[DWIDTH-1:0] din,	
				input 	we,			
				output  	[DWIDTH-1:0] dout	
				);


parameter AWIDTH = 3;		
parameter DWIDTH = 32;		
localparam DEPTH  = 1 << AWIDTH;


reg [DWIDTH-1:0] mem_array [0:DEPTH-1];

initial
begin
	$readmemb("dram0.txt", mem_array);
end


reg [AWIDTH-1:0] rd_addr;

always@(posedge clock)
begin
	if(we)
		mem_array[addr] <= din;	

rd_addr <= addr;		
end

assign dout = mem_array[rd_addr];

endmodule
