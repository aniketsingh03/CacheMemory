
module cache_controller(
	input			clock,		//Clock input same as CPU and Memory controller
	input			reset,	//Reset Signal Input

	inout	[DATAWIDTH-1:0]	data_cpu,	//Data bus from CPU
	inout	[DATAWIDTH-1:0]	data_mem,	//Data bus to Main Memory
	
	input	[AWIDTH-1:0]	addr_cpu,	//Address bus from CPU
	output	reg[AWIDTH-1:0]	addr_mem,	//Address bus to Main Memory

	input			read_cpu_enable,		//Read signal from CPU
	input			write_cpu_enable,		//WRITE signal from CPU
   input hit,
	input hit_cache_0,
	input hit_cache_1,
	input valid,
	input valid_bit_cache_0,
	input valid_bit_cache_1,
	input dirty,
	input dirty_bit_cache_0,
	input dirty_bit_cache_1,
	output	reg		read_mem_enable,		//Read signal to Main Memory
	output	reg		write_mem_enable,		//Write signal to Main Memory
	input [13:0] read_tag_cache_0,
	input [10:0] tagdata,
	input [2:0] index,
	input [1:0] bytsel,
	input [13:0] read_tag_cache_1,
	output	reg		stall_cpu,	//Stall Signal to CPU, to halt the CPU while undergoing any other operation
	input			ready_memory	//Ready signal from Main memory, to know the status of memory

);

// Parameters

parameter AWIDTH		= 16;	
parameter DATAWIDTH		= 8;	
parameter CACHELINES		= 16;
parameter BLOCKSIZE		= 4;
parameter NUMOFSETS		= 8;
parameter VALIDBIT		= 1;
parameter DIRTYBIT		= 1;
parameter USEDBIT		= 1;
parameter TAGWIDTH		= 11;

// State Machine Parameters

localparam	IDLE		= 3'd0,	
		READ		= 3'd1,
		WRITE		= 3'd2,
		READMM		= 3'd3,
		WAITFORMM	= 3'd4,
		UPDATEMM	= 3'd5,
		UPDATECACHE	= 3'd6;

// Internal Wires and Registers

wire	[10:0]	tagdata;
wire	[2:0]	index;
wire	[1:0]	bytsel;
reg	[DATAWIDTH-1:0] read_data_1_byte;
reg	[DATAWIDTH-1:0] write_data_1_byte;
reg	[DATAWIDTH-1:0] write_mem_1_byte;
reg	[(DATAWIDTH*BLOCKSIZE)-1:0] read_mem_4_byte;
reg	[(DATAWIDTH*BLOCKSIZE)-1:0] write_mem_4_byte;	

reg	rdwr; 
reg	write_enable_data_ram_0;	
reg	write_enable_data_ram_1;	
reg	write_enable_tag_ram_0;	
reg	write_enable_tag_ram_1;	
reg	[3:0] count;	//To count byte transfer between Cache and memory during read and write memory operation, used as shift register.

//reg	update_flag; 
wire	hit;
wire	hit_cache_0;
wire	hit_cache_1;

wire	valid;
wire	valid_bit_cache_0;
wire	valid_bit_cache_1;

wire	used_bit_cache_0;
wire	used_bit_cache_1;

wire	dirty;
wire	dirty_bit_cache_0;
wire	dirty_bit_cache_1;

wire	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0]	read_tag_cache_0; //14-bits
wire	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0]	read_tag_cache_1;


wire	[(DATAWIDTH*BLOCKSIZE)-1:0] read_data_cache_0;	
wire	[(DATAWIDTH*BLOCKSIZE)-1:0] read_data_cache_1;

wire	[DATAWIDTH-1:0]		 byte_cache_0;
wire	[DATAWIDTH-1:0]		 byte_cache_1;

reg	[(DATAWIDTH*BLOCKSIZE)-1:0] read_data_register;
reg	[(DATAWIDTH*BLOCKSIZE)-1:0] write_data_register;
reg	[(DATAWIDTH*BLOCKSIZE)-1:0] stread_data_cache_0;
reg	[(DATAWIDTH*BLOCKSIZE)-1:0] stread_data_cache_1;
reg	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0] write_tag_cache_0;
reg	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0] write_tag_cache_1;
reg	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0] stread_tag_cache_0;
reg	[(VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH-1):0] stread_tag_cache_1;
reg	[AWIDTH-1:0]		 addrlatch;
reg	update_flag; // Internal flag, SET when enters Update MM state. It is used to make reuse of WAITFORMM state for both READMM and UPDATEMM 			//states

// State Variables
reg [2:0] state;



assign tagdata = (state == IDLE) ? addr_cpu[15:5] : addrlatch[15:5];
assign index   = (state == IDLE) ? addr_cpu[4:2] : addrlatch[4:2];
assign bytsel  = (state == IDLE) ? addr_cpu[1:0] : addrlatch[1:0];

assign valid_bit_cache_0 = read_tag_cache_0[13];
assign valid_bit_cache_1 = read_tag_cache_1[13];
assign valid = valid_bit_cache_0 & valid_bit_cache_1;

assign used_bit_cache_0  =read_tag_cache_0[12];
assign used_bit_cache_1  =read_tag_cache_1[12];

assign dirty_bit_cache_0 = read_tag_cache_0[11];
assign dirty_bit_cache_1 = read_tag_cache_1[11];
assign dirty = dirty_bit_cache_0 | dirty_bit_cache_1;

assign hit_cache_0 = valid_bit_cache_0 & (tagdata == read_tag_cache_0[10:0]);
assign hit_cache_1 = valid_bit_cache_1 & (tagdata == read_tag_cache_1[10:0]);
assign hit = hit_cache_0 | hit_cache_1;

assign byte_cache_0 = (bytsel == 2'd0) ? read_data_cache_0[7:0] :((bytsel == 2'd1) ? read_data_cache_0[15:8] :((bytsel == 2'd2) ? read_data_cache_0[23:16] : read_data_cache_0[31:24]));
assign byte_cache_1 = (bytsel == 2'd0) ? read_data_cache_1[7:0] :((bytsel == 2'd1) ? read_data_cache_1[15:8] :((bytsel == 2'd2) ? read_data_cache_1[23:16] : read_data_cache_1[31:24]));

assign data_cpu = (!write_cpu_enable) ? read_data_1_byte : 8'dZ;
assign data_mem = write_mem_enable ? write_mem_1_byte  : 8'dZ;

// Cache Controller State Machine and Logic

always@(posedge clock or negedge reset)
begin
	if(!reset)
	begin
		addrlatch <= 'd0;
		addr_mem  <= 'd0;
		read_mem_enable	  <= 'd0;
		write_mem_enable	  <= 'd0;
		stall_cpu <= 'd0;
		state	  <= IDLE;
		read_data_1_byte<= 'd0;
		write_data_1_byte<= 'd0;
		write_mem_1_byte <= 'd0;
		read_mem_4_byte<= 'd0;
		write_mem_4_byte<= 'd0;
		write_data_register	  <= 'd0;
		write_tag_cache_0	  <= 'd0;
		write_tag_cache_1	  <= 'd0;
		write_enable_data_ram_0	  <= 1'd0;
		write_enable_data_ram_1	  <= 1'd0;
		write_enable_tag_ram_0	  <= 1'd0;
		write_enable_tag_ram_1	  <= 1'd0;
		rdwr	  <= 1'd1;
		stread_data_cache_0  <= 'd0;
		stread_data_cache_1  <= 'd0;
		stread_tag_cache_0   <= 'd0;
		stread_tag_cache_1	  <= 'd0;
		read_data_register	  <= 'd0;
		update_flag<= 1'd0;

	end
	else
	begin
		case(state)

			IDLE	:	begin
					
					addrlatch	<= addr_cpu;
					write_enable_data_ram_0	  <= 1'd0;
					write_enable_data_ram_1	  <= 1'd0;
					write_enable_tag_ram_0	  <= 1'd0;
					write_enable_tag_ram_1	  <= 1'd0;
					stall_cpu <= 1'd0;
					read_mem_enable	  <= 1'd0;
					write_mem_enable	  <= 1'd0;
					write_mem_1_byte <= 8'd0;
					read_mem_4_byte<= 'd0;
					write_data_register	  <= 'd0;
					write_tag_cache_0	  <= 'd0;
					write_tag_cache_1	  <= 'd0;
					update_flag<= 1'd0;

					if(read_cpu_enable)
					begin
						state	<= READ;
						rdwr	<= 1'd1;
					end
					else if(write_cpu_enable)
					begin
						state	<= WRITE;
						write_data_1_byte	<= data_cpu;
						rdwr	<= 1'd0;
					end
					else
						state	<= state;
					end

			READ	:	begin
					write_enable_data_ram_0 <= 1'd0;
					write_enable_data_ram_1 <= 1'd0;
					case(hit)
						1'd0:	begin
							stread_tag_cache_0	   <= read_tag_cache_0;
							stread_tag_cache_1	   <= read_tag_cache_1;
							stread_data_cache_0   <= read_data_cache_0;
							stread_data_cache_1   <= read_data_cache_1;
							stall_cpu  <= 1'd1;
							write_enable_tag_ram_0 <= 1'd0;
							write_enable_tag_ram_1 <= 1'd0;
							if(ready_memory)
								if(valid & dirty)
									state <= UPDATEMM;
								else
									state <= READMM;
							else
								state <= state;
							end

						1'd1:	begin
							state <= IDLE;
							write_enable_tag_ram_0 <= 1'd1;
							write_enable_tag_ram_1 <= 1'd1;
							stall_cpu  <= 1'd0;
								if(hit_cache_0)
								begin
									read_data_1_byte <= byte_cache_0;
									if(used_bit_cache_0)
										write_tag_cache_0 <= read_tag_cache_0;
									else
										write_tag_cache_0 <= {read_tag_cache_0[13],1'd1,read_tag_cache_0[11:0]};
									if(used_bit_cache_1)
										write_tag_cache_1 <= read_tag_cache_1;
									else
										write_tag_cache_1 <= {read_tag_cache_1[13],1'd1,read_tag_cache_1[11:0]};
								end
								else
								begin
									read_data_1_byte <= byte_cache_1;
									if(used_bit_cache_1)
										write_tag_cache_1 <= {read_tag_cache_1[13],1'd0,read_tag_cache_1[11:0]};
									else
										write_tag_cache_1 <= read_tag_cache_1;
									if(used_bit_cache_0)
										write_tag_cache_0 <= {read_tag_cache_0[13],1'd0,read_tag_cache_0[11:0]};
									else
										write_tag_cache_0 <= read_tag_cache_0;
								end
							end
					endcase
					end

			WRITE	:	begin
					
					case(hit)
						1'd0:	begin
							stread_tag_cache_0	   <= read_tag_cache_0;
							stread_tag_cache_1	   <= read_tag_cache_1;
							stread_data_cache_0   <= read_data_cache_0;
							stread_data_cache_1   <= read_data_cache_1;
							stall_cpu  <= 1'd1;
							if(ready_memory)
								if(valid & dirty)
									state <= UPDATEMM;
								else
									state <= READMM;
							else
								state <= state;

							end

						1'd1:	begin
							state <= IDLE;
							write_enable_tag_ram_0 		<= 1'd1;
							write_enable_tag_ram_1 		<= 1'd1;
							stall_cpu  <= 1'd0;
								if(hit_cache_0)
									begin
									write_enable_data_ram_0		<= 1'd1;
									case(bytsel)
										2'd0: write_data_register <= {read_data_cache_0[31:8],write_data_1_byte};
										2'd1: write_data_register <= {read_data_cache_0[31:16],write_data_1_byte,read_data_cache_0[7:0]};
										2'd2: write_data_register <= {read_data_cache_0[31:24],write_data_1_byte,read_data_cache_0[15:0]};
										2'd3: write_data_register <= {write_data_1_byte,read_data_cache_0[23:0]};
									endcase
									
									if(used_bit_cache_0)
										write_tag_cache_0 <= {read_tag_cache_0[13:12],1'd1,read_tag_cache_0[10:0]};
									else
										write_tag_cache_0 <= {read_tag_cache_0[13],1'd1,1'd1,read_tag_cache_0[10:0]};
									if(used_bit_cache_1)
										write_tag_cache_1 <= read_tag_cache_1;
									else
										write_tag_cache_1 <= {read_tag_cache_1[13],1'd1,read_tag_cache_1[11:0]};
									end
								else
									begin
									write_enable_data_ram_1		<= 1'd1;
									
									case(bytsel)
										2'd0: write_data_register <= {read_data_cache_1[31:8],write_data_1_byte};
										2'd1: write_data_register <= {read_data_cache_1[31:16],write_data_1_byte,read_data_cache_1[7:0]};
										2'd2: write_data_register <= {read_data_cache_1[31:24],write_data_1_byte,read_data_cache_1[15:0]};
										2'd3: write_data_register <= {write_data_1_byte,read_data_cache_1[23:0]};
									endcase
									
									if(used_bit_cache_1)
										write_tag_cache_1 <= {read_tag_cache_1[13],1'd0,1'd1,read_tag_cache_1[10:0]};
									else
										write_tag_cache_1 <= {read_tag_cache_1[13:12],1'd1,read_tag_cache_1[10:0]};
									
									if(used_bit_cache_0)
										write_tag_cache_0 <= {read_tag_cache_0[13],1'd0,read_tag_cache_0[11:0]};
									else
										write_tag_cache_0 <= read_tag_cache_0;
									end
							
							end
					endcase
					end
			
			READMM	:	begin
					addr_mem <= {addrlatch[15:2],2'd0};
					update_flag<= 1'd0;
						if(ready_memory)
						begin
							read_mem_enable <= 1'd1;
							state    <= WAITFORMM;		// code for the state is yet to be written
						end
						else
						begin
							read_mem_enable <= 1'd0;
							state  <= state;
						end
					end

			WAITFORMM :	begin
						if(ready_memory)
						begin
							if(update_flag)
							state <= READMM;
							else
							state <= UPDATECACHE;

							read_mem_enable <= 1'd0;
							write_mem_enable <= 1'd0;
						end
						else
						begin
							if(!rdwr)
							begin
								write_data_1_byte <= write_mem_4_byte[7:0];
								write_mem_4_byte<= {8'd0,write_mem_4_byte[31:8]};
							end
							state <= state;
						end
							
					end
			UPDATEMM :	begin
						update_flag<= 1'd1;
						if(used_bit_cache_0)
						begin
							addr_mem <= {stread_tag_cache_1[10:0],addrlatch[4:2],2'd0};
							write_mem_4_byte <= stread_data_cache_1;
						end
						else
						begin
							addr_mem <= {stread_tag_cache_0[10:0],addrlatch[4:2],2'd0};
							write_mem_4_byte <= stread_data_cache_0;
						end
						
						if(ready_memory)
						begin
							write_mem_enable <= 1'd1;
							state    <= WAITFORMM;		// code for the state is yet to be written
						end
						else
						begin
							write_mem_enable <= 1'd0;
							state  <= state;
						end
					end

			UPDATECACHE:	begin
						update_flag<= 1'd0;
						
						if(count!=4'b1111)
						begin
							read_mem_4_byte <= {data_mem,read_mem_4_byte[31:8]};
							count <= {1'd1,count[3:1]};
						end
						else
						begin
							write_data_register <= read_mem_4_byte;
							state <= IDLE;
						
							if(used_bit_cache_0)
							begin
								write_tag_cache_1 <= {1'd1,1'd0,1'd0,addrlatch[15:5]};
								write_tag_cache_0 <= {stread_tag_cache_0[13],1'd0,stread_tag_cache_0[11:0]};
								write_enable_data_ram_0   <= 1'd1;
								write_enable_data_ram_1   <= 1'd0;
								write_enable_tag_ram_0  <= 1'd1;
								write_enable_tag_ram_1  <= 1'd1;
							end
							else
							begin
								write_tag_cache_0 <= {1'd1,1'd1,1'd0,addrlatch[15:5]};
								write_tag_cache_1 <= {stread_tag_cache_1[13],1'd1,stread_tag_cache_1[11:0]};
								write_enable_data_ram_0   <= 1'd1;
								write_enable_data_ram_1   <= 1'd0;
								write_enable_tag_ram_0  <= 1'd1;
								write_enable_tag_ram_1  <= 1'd1;
							end
						end
						
					end
			default:	 begin
							addrlatch <= 'd0;
							addr_mem  <= 'd0;
							read_mem_enable	  <= 'd0;
							write_mem_enable	  <= 'd0;
							stall_cpu <= 'd0;
							state	  <= IDLE;
							read_data_1_byte<= 'd0;
							write_data_1_byte<= 'd0;
							write_mem_1_byte <= 'd0;
							read_mem_4_byte<= 'd0;
							write_mem_4_byte<= 'd0;
							write_data_register	  <= 'd0;
							write_tag_cache_0	  <= 'd0;
							write_tag_cache_1	  <= 'd0;
							write_enable_data_ram_0	  <= 1'd0;
							write_enable_data_ram_1	  <= 1'd0;
							write_enable_tag_ram_0	  <= 1'd0;
							write_enable_tag_ram_1	  <= 1'd0;
							rdwr	  <= 1'd1;
							stread_data_cache_0  <= 'd0;
							stread_data_cache_1  <= 'd0;
							stread_tag_cache_0   <= 'd0;
							stread_tag_cache_1	  <= 'd0;
							read_data_register	  <= 'd0;
							

					end
		endcase
	end
end


defparam tr0.AWIDTH = 3;
defparam tr0.DWIDTH = VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH; 

ram_sync_read_t0 tr0 (
			.clock(clock),
			.addr(index),
			.din(write_tag_cache_0),
			.we(write_enable_tag_ram_0),
			.dout(read_tag_cache_0)
			);


defparam tr1.AWIDTH = 3;
defparam tr1.DWIDTH = VALIDBIT+USEDBIT+DIRTYBIT+TAGWIDTH;

ram_sync_read_t1 tr1 (
			.clock(clock),
			.addr(index),
			.din(write_tag_cache_1),
			.we(write_enable_tag_ram_1),
			.dout(read_tag_cache_1)
			);


defparam dr0.AWIDTH = 3;
defparam dr0.DWIDTH = DATAWIDTH*BLOCKSIZE;

ram_sync_read_d0 dr0 (
			.clock(clock),
			.addr(index),
			.din(write_data_register),
			.we(write_enable_data_ram_0),
			.dout(read_data_cache_0)
			);


defparam dr1.AWIDTH = 3;
defparam dr1.DWIDTH = DATAWIDTH*BLOCKSIZE;

ram_sync_read_d1 dr1 (
			.clock(clock),
			.addr(index),
			.din(write_data_register),
			.we(write_enable_data_ram_1),
			.dout(read_data_cache_1)
			);
endmodule
