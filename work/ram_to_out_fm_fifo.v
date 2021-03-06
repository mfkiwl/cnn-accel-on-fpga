/*
* Created           : cheng liu
* Date              : 2016-06-01
*
* Description:
* 
* This module moves a specified tile of data from RAM to fifo when the 
* 'start' signal is asserted. 'done' signal will be asserted when the data 
* movement is completed.  
* 
* Assumption:
* Given read address, the data from RAM will be available 2 cycles later.
* The original input data is stored in in_fm[M][R][C] with row major order.
* Apparently, the data in the tile doesn't fit in a sequential address space. 
*
* Instance example
ram_to_out_fm_fifo #(
    .AW (AW),
    .DW (DW),
    .N (N),
    .R (R),
    .C (C),
    .Tn (Tn),
    .Tr (Tr),
    .Tc (Tc)

) ram_to_out_fm_fifo_inst (
    .start (),
    .done (),

    .fifo_push (),
    .fifo_almost_full (),
    .data_to_fifo (),

    .ram_addr (),
    .data_from_ram (),

    .tile_base_n (),
    .tile_base_row (),
    .tile_base_col (),

    .clk (),
    .rst ()
);
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module ram_to_out_fm_fifo #(

    parameter CW = 32,
    parameter AW = 32,
    parameter DW = 32,
    parameter N = 32,
    parameter R = 64,
    parameter C = 32,
    parameter Tn = 8,
    parameter Tr = 16,
    parameter Tc = 8

)(
    input                              start,
    output                             done,
    input                              conv_tile_clean,

    output                             fifo_push,
    input                              fifo_almost_full,
    output                   [DW-1: 0] data_to_fifo,

    output                   [AW-1: 0] ram_addr,
    input                    [DW-1: 0] data_from_ram,

    input                    [CW-1: 0] tile_base_n,
    input                    [CW-1: 0] tile_base_row,
    input                    [CW-1: 0] tile_base_col,

    input                              clk,
    input                              rst
);
    reg                                transfer_on_going_tmp;
    wire                               transfer_on_going;
    wire                               fifo_push_tmp;
    wire                     [AW-1: 0] logic_addr;
    wire                               is_addr_legal;
    wire                               is_data_legal;

    wire                     [CW-1: 0] tc;
    wire                     [CW-1: 0] tr;
    wire                     [CW-1: 0] tn;

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            transfer_on_going_tmp <= 1'b0;
        end
        else if(start == 1'b1) begin
            transfer_on_going_tmp <= 1'b1;
        end
        else if(done == 1'b1) begin
            transfer_on_going_tmp <= 1'b0;
        end
    end
    assign transfer_on_going = (transfer_on_going_tmp == 1'b1) && (done == 1'b0);

    assign data_to_fifo = is_data_legal ? data_from_ram : 0;

    assign fifo_push_tmp = (fifo_almost_full == 1'b0) && (transfer_on_going == 1'b1);

    sig_delay #(
        .D (3)
    ) sig_delay0 (
        .sig_in (fifo_push_tmp),
        .sig_out (fifo_push),

        .clk (clk),
        .rst (rst)
    );

    sig_delay #(
        .D (2)
    ) sig_delay1 (
        .sig_in (is_addr_legal),
        .sig_out (is_data_legal),

        .clk (clk),
        .rst (rst)
    );

    nest3_counter #(

        .CW (AW),
        .n0_max (Tc),
        .n1_max (Tr),
        .n2_max (Tn)

    ) nest3_counter_inst (
        .ena (fifo_push_tmp),
        .clean (conv_tile_clean),

        .cnt0 (tc),
        .cnt1 (tr),
        .cnt2 (tn),

        .done (done),

        .clk (clk),
        .rst (rst)
    );

    assign is_addr_legal = (tile_base_n + tn < N) && 
                           (tile_base_row + tr < R) && 
                           (tile_base_col + tc < C);

    assign logic_addr = (tile_base_n + tn) * R * C +
                        (tile_base_row + tr) * C + tile_base_col + tc;
                      
    assign ram_addr = logic_addr;


endmodule
