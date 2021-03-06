/*
* Created           : cheng liu
* Date              : 2016-05-18
*
* Description:
* 
* out_fm memory, and it accommodates a few output feacture maps of different channels.
* 
* Instance example
output_fm #(
    .AW (), 
    .DW (),
    .Tn (),
    .Tr (),
    .Tc (),
    .Y () 
) output_fm_inst (
    .out_fm_st_fifo_data (),
    .out_fm_st_fifo_push (),
    .out_fm_st_fifo_almost_full (),

    .out_fm_ld_fifo_pop (),
    .out_fm_ld_fifo_data (),
    .out_fm_ld_fifo_empty (),
    
    .inter_rd_data0 (),
    .inter_rd_addr0 (),
    
    .inter_wr_data0 (),
    .inter_wr_addr0 (),
    .inter_wr_ena0 (),
    
    .inter_rd_data1 (),
    .inter_rd_addr1 (),
    
    .inter_wr_data1 (),
    .inter_wr_addr1 (),
    .inter_wr_ena1 (),
    
    .inter_rd_data2 (),
    .inter_rd_addr2 (),
    
    .inter_wr_data2 (),
    .inter_wr_addr2 (),
    .inter_wr_ena2 (),
    
    .inter_rd_data3 (),
    .inter_rd_addr3 (),
    
    .inter_wr_data3 (),
    .inter_wr_addr3 (),
    .inter_wr_ena3 (),
    
    .out_fm_ld_start (),
    .out_fm_ld_done (),
    
    .out_fm_st_start (),
    .out_fm_st_done (),
    
    .clk (),
    .rst ()
);
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module output_fm #(
    parameter AW = 16,  // input_fm bank address width
    parameter DW = 32,  // data width
    parameter Tn = 16,  // output_fm tile size of input channel
    parameter Tr = 64,  // output_fm tile size of row
    parameter Tc = 16,  // output_fm tile size of col
    parameter Y = 4     // # of out_fm bank
)(
    // port to conv memory access interface
    output  [DW-1: 0]                  out_fm_st_fifo_data,
    output                             out_fm_st_fifo_push,
    input                              out_fm_st_fifo_almost_full,
                                       
    output                             out_fm_ld_fifo_pop,
    input   [DW-1: 0]                  out_fm_ld_fifo_data,
    input                              out_fm_ld_fifo_empty,

    // port to internal computing logic
    output  [DW-1: 0]                  inter_rd_data0,
    input   [AW-1: 0]                  inter_rd_addr0,
                                       
    input   [DW-1: 0]                  inter_wr_data0,
    input   [AW-1: 0]                  inter_wr_addr0,
    input                              inter_wr_ena0,
                                       
    output  [DW-1: 0]                  inter_rd_data1,
    input   [AW-1: 0]                  inter_rd_addr1,
                                       
    input   [DW-1: 0]                  inter_wr_data1,
    input   [AW-1: 0]                  inter_wr_addr1,
    input                              inter_wr_ena1,
                                       
    output  [DW-1: 0]                  inter_rd_data2,
    input   [AW-1: 0]                  inter_rd_addr2,
                                       
    input   [DW-1: 0]                  inter_wr_data2,
    input   [AW-1: 0]                  inter_wr_addr2,
    input                              inter_wr_ena2,
                                       
    output  [DW-1: 0]                  inter_rd_data3,
    input   [AW-1: 0]                  inter_rd_addr3,
                                       
    input   [DW-1: 0]                  inter_wr_data3,
    input   [AW-1: 0]                  inter_wr_addr3,
    input                              inter_wr_ena3,

    // Control status
    input                              out_fm_ld_start,
    output                             out_fm_ld_done,

    input                              out_fm_st_start,
    output                             out_fm_st_done,
    
    input                              conv_computing_start,
    input                              conv_tile_reset,

    input                              clk,
    input                              rst
);

   localparam SLICE_SIZE = Tr * Tc;
   localparam OUT_FM_SIZE = Tn * Tr * Tc;

   reg                                 out_fm_ld_on_going;
   reg                                 out_fm_st_on_going;
   reg      [3: 0]                     out_lane_ld_sel;
   reg      [3: 0]                     out_lane_st_sel;
   wire     [3: 0]                     out_lane_st_sel_d3;
   wire                                slice_ld_done;
   wire                                slice_st_done;
                                       
   wire                                rd_ena0;
   wire                                rd_ena1;
   wire                                rd_ena2;
   wire                                rd_ena3;
                                       
   wire                                wr_ena0;
   wire                                wr_ena1;
   wire                                wr_ena2;
   wire                                wr_ena3;
                                       
   wire                                out_fm_st_fifo_push_tmp;
   wire                                out_fm_ld_fifo_pop_tmp;
   reg                                 out_fm_st_fifo_push_reg;
   reg                                 out_fm_ld_fifo_pop_reg;

   wire     [DW-1: 0]                  rd_data0;
   wire     [DW-1: 0]                  rd_data1;
   wire     [DW-1: 0]                  rd_data2;
   wire     [DW-1: 0]                  rd_data3;
                                       
   reg                                 computing_on_going;
   
   //-------------------------------------------------------------
   // Load data from out_fm_ld_fifo
   //-------------------------------------------------------------
   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           computing_on_going <= 1'b0;
       end
       else if(out_fm_ld_start == 1'b1 || out_fm_st_start == 1'b1) begin
           computing_on_going <= 1'b0;
       end
       else if(conv_computing_start == 1'b1) begin
           computing_on_going <= 1'b1;
       end
   end

   counter #(
       .CW (DW),
       .MAX (OUT_FM_SIZE)
   ) out_fm_ld_counter (
       .ena     (out_fm_ld_fifo_pop_tmp),
       .cnt     (),
       .done    (out_fm_ld_done),
       .syn_rst (conv_tile_reset),

       .clk     (clk),
       .rst     (rst)
   );
   
   counter #(
       .CW (AW),
       .MAX (SLICE_SIZE)
   ) slice_ld_counter (
       .ena     (out_fm_ld_fifo_pop_tmp),
       .cnt     (),
       .done    (slice_ld_done),
       .syn_rst (conv_tile_reset),

       .clk     (clk),
       .rst     (rst)
   );   
   
   assign out_fm_ld_fifo_pop_tmp = (out_fm_ld_fifo_empty == 1'b0) && 
                                   (out_fm_ld_on_going == 1'b1) && 
                                   (out_fm_ld_done == 1'b0);
   
   always@(posedge clk) begin
       out_fm_ld_fifo_pop_reg <= out_fm_ld_fifo_pop_tmp;
   end
   
   assign out_fm_ld_fifo_pop = out_fm_ld_fifo_pop_tmp;
         
   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           out_fm_ld_on_going <= 1'b0;
       end
       else if(out_fm_ld_start == 1'b1) begin
           out_fm_ld_on_going <= 1'b1;
       end
       else if(out_fm_ld_done == 1'b1) begin
           out_fm_ld_on_going <= 1'b0;
       end
   end

   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           out_lane_ld_sel <= 4'b0001;
       end
       else if(slice_ld_done == 1'b1) begin
           out_lane_ld_sel <= {out_lane_ld_sel[2: 0], out_lane_ld_sel[3]};
       end
   end
      
   assign wr_ena0 = out_lane_ld_sel[0] && out_fm_ld_fifo_pop_reg;
   assign wr_ena1 = out_lane_ld_sel[1] && out_fm_ld_fifo_pop_reg;
   assign wr_ena2 = out_lane_ld_sel[2] && out_fm_ld_fifo_pop_reg;
   assign wr_ena3 = out_lane_ld_sel[3] && out_fm_ld_fifo_pop_reg;
   
   //-------------------------------------------------------------
   // Store data to out_fm_st_fifo
   //-------------------------------------------------------------
   counter #(
       .CW (AW),
       .MAX (SLICE_SIZE)
   ) slice_st_counter (
       .ena     (out_fm_st_fifo_push_tmp),
       .cnt     (),
       .done    (slice_st_done),
       .syn_rst (conv_tile_reset),

       .clk     (clk),
       .rst     (rst)
   );
   
   counter #(
       .CW (DW),
       .MAX (OUT_FM_SIZE)
   ) out_fm_st_counter (
       .ena     (out_fm_st_fifo_push_tmp),
       .cnt     (),
       .done    (out_fm_st_done),
       .syn_rst (conv_tile_reset),

       .clk     (clk),
       .rst     (rst)
   );
   
   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           out_fm_st_on_going <= 1'b0;
       end
       else if(out_fm_st_start == 1'b1) begin
           out_fm_st_on_going <= 1'b1;
       end
       else if(out_fm_st_done == 1'b1) begin
           out_fm_st_on_going <= 1'b0;
       end
   end
      
   assign out_fm_st_fifo_push_tmp = (out_fm_st_fifo_almost_full == 1'b0) && 
                                    (out_fm_st_on_going == 1'b1) && 
                                    (out_fm_st_done == 1'b0);
   always@(posedge clk) begin
       out_fm_st_fifo_push_reg <= out_fm_st_fifo_push_tmp;
   end
   
   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           out_lane_st_sel <= 4'b0001;
       end
       else if(slice_st_done == 1'b1) begin
           out_lane_st_sel <= {out_lane_st_sel[2: 0], out_lane_st_sel[3]};
       end
   end
   
   sig_delay #(
       .D (4)
   ) sig_delay2 (
       .sig_in  (out_fm_st_fifo_push_tmp),
       .sig_out (out_fm_st_fifo_push),

       .clk     (clk),
       .rst     (rst)
   );
   
   assign rd_ena0 = out_lane_st_sel[0] && out_fm_st_fifo_push_reg;
   assign rd_ena1 = out_lane_st_sel[1] && out_fm_st_fifo_push_reg;
   assign rd_ena2 = out_lane_st_sel[2] && out_fm_st_fifo_push_reg;
   assign rd_ena3 = out_lane_st_sel[3] && out_fm_st_fifo_push_reg;
   

   data_delay #(
       .D (3),
       .DW (4)
   ) data_delay0 (
       .data_in  (out_lane_st_sel),
       .data_out (out_lane_st_sel_d3),

       .clk      (clk)
   );

   assign out_fm_st_fifo_data = out_lane_st_sel_d3 == 4'b0001 ? rd_data0 :
                                out_lane_st_sel_d3 == 4'b0010 ? rd_data1 :
                                out_lane_st_sel_d3 == 4'b0100 ? rd_data2 : rd_data3;   
   

    // output_fm Bank
    output_fm_bank #(
        .AW (AW), 
        .DW (DW),
        .Tn (Tn),
        .Tr (Tr),
        .Tc (Tc),
        .Y (Y) 
    ) output_fm_bank0 (
        .rd_data            (rd_data0),
        .rd_ena             (rd_ena0),
        .wr_data            (out_fm_ld_fifo_data),
        .wr_ena             (wr_ena0),

        .inter_rd_data      (inter_rd_data0),
        .inter_rd_addr      (inter_rd_addr0),
        .inter_wr_data      (inter_wr_data0),
        .inter_wr_addr      (inter_wr_addr0),
        .inter_wr_ena       (inter_wr_ena0),

        .computing_on_going (computing_on_going),
        .conv_tile_reset    (conv_tile_reset),

        .clk                (clk),
        .rst                (rst)
    );

    output_fm_bank #(
        .AW (AW), 
        .DW (DW),
        .Tn (Tn),
        .Tr (Tr),
        .Tc (Tc),
        .Y (Y) 
    ) output_fm_bank1 (
        .rd_data            (rd_data1),
        .rd_ena             (rd_ena1),
        .wr_data            (out_fm_ld_fifo_data),
        .wr_ena             (wr_ena1),
        .conv_tile_reset    (conv_tile_reset),        

        .inter_rd_data      (inter_rd_data1),
        .inter_rd_addr      (inter_rd_addr1),
        .inter_wr_data      (inter_wr_data1),
        .inter_wr_addr      (inter_wr_addr1),
        .inter_wr_ena       (inter_wr_ena1),

        .computing_on_going (computing_on_going),

        .clk                (clk),
        .rst                (rst)
    );

    output_fm_bank #(
        .AW (AW), 
        .DW (DW),
        .Tn (Tn),
        .Tr (Tr),
        .Tc (Tc),
        .Y (Y) 
    ) output_fm_bank2 (
        .rd_data            (rd_data2),
        .rd_ena             (rd_ena2),
        .wr_data            (out_fm_ld_fifo_data),
        .wr_ena             (wr_ena2),
        .conv_tile_reset    (conv_tile_reset),        

        .inter_rd_data      (inter_rd_data2),
        .inter_rd_addr      (inter_rd_addr2),
        .inter_wr_data      (inter_wr_data2),
        .inter_wr_addr      (inter_wr_addr2),
        .inter_wr_ena       (inter_wr_ena2),

        .computing_on_going (computing_on_going),

        .clk                (clk),
        .rst                (rst)
    );

    output_fm_bank #(
        .AW (AW), 
        .DW (DW),
        .Tn (Tn),
        .Tr (Tr),
        .Tc (Tc),
        .Y (Y) 
    ) output_fm_bank3 (
        .rd_data            (rd_data3),
        .rd_ena             (rd_ena3),
        .wr_data            (out_fm_ld_fifo_data),
        .wr_ena             (wr_ena3),
        .conv_tile_reset    (conv_tile_reset),        

        .inter_rd_data      (inter_rd_data3),
        .inter_rd_addr      (inter_rd_addr3),
        .inter_wr_data      (inter_wr_data3),
        .inter_wr_addr      (inter_wr_addr3),
        .inter_wr_ena       (inter_wr_ena3),

        .computing_on_going (computing_on_going),

        .clk                (clk),
        .rst                (rst)
    );

endmodule
