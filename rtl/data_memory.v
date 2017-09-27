`timescale 1ns / 1ps

module data_memory(
input wire clk,                  // All synchronous elements, including memories, should have a clock signal
input wire [16:0] addr,          // Memory Address
input wire [31:0] write_data,    // Memory Address Contents
input wire memwrite, memread,
output reg [31:0] read_data      // Output of Memory Address Contents
);

reg [8:0] MEMO[0:65536];  // 65536 (2^16) words of 8-bit memory
wire [7:0] word0;
wire [7:0] word1;
wire [7:0] word2;
wire [7:0] word3;

integer i;
assign word0 = write_data[31:24];
assign word1 = write_data[23:16];
assign word2 = write_data[15:8];
assign word3 = write_data[7:0];

//implement code to fill memory initially here

always @(posedge clk) begin
  if (memwrite == 1'b1) begin
    MEMO[addr] <= word0;
    MEMO[addr+1] <= word1;
    MEMO[addr+2] <= word2;
    MEMO[addr+3] <= word3;
  end
  // Use memread to indicate a valid address is on the line and read the memory into a register at that address when memread is asserted
  if (memread == 1'b1) begin
    assign read_data = {MEMO[addr],MEMO[addr+1],MEMO[addr+2],MEMO[addr+3]};
  end
 end
 endmodule
