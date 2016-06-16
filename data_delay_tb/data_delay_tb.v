// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module data_delay_tb;
  parameter DW = 32;

  reg clk;
  reg [DW-1: 0] data_in;
  wire[DW-1: 0] data_out;
  
  always #10 clk = ~clk;
  
  initial begin
    clk = 0;
    data_in = 0;
    @(posedge clk)
    data_in = 1;
    @(posedge clk)
    data_in = 2;
    @(posedge clk)
    data_in = 3;
    repeat (5) begin
      @(posedge clk);
    end
    $stop(2);
  end


 data_delay #(
     .D (1),
     .DW (DW)
 ) data_delay_inst (
     .data_in (data_in),
     .data_out (data_out),

     .clk (clk)
 );
 
 endmodule