/*
* Created           : cheng liu
* Date              : 2016-05-16
*
* Description:
* 
* One bank of input_fm, and it accommodates a few input feacture maps of different channels.
* As the input_fm_bank will be definitely written sequentially, its write address can be 
* generated automatically. While the read is different, thus the read address is exposed to external logic.
* 
* Instance example
module input_fm_bank #(
    .AW (), 
    .DW (),
    .Tm (),
    .Tr (),
    .Tc (),
    .X () 
) input_fm_bank_inst (
    .rd_data (),
    .rd_addr (),
    .wr_data (),
    .wr_addr (),
    .wr_ena (),

    .clk (),
    .rst ()
);

*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module input_fm_bank #(
    parameter AW = 16,  // input_fm bank address width
    parameter DW = 32,  // data width

    parameter Tm = 16,  // input_fm tile size of input channel
    parameter Tr = 64,  // input_fm tile size of row
    parameter Tc = 16,  // input_fm tile size of col
    parameter X = 4     // # of input_fm bank
)(
    output  [DW-1: 0]                  rd_data,
    input   [AW-1: 0]                  rd_addr,
                                       
    input   [DW-1: 0]                  wr_data,
    input                              wr_ena,
    input                              conv_tile_reset,

    input                              clk,
    input                              rst
);
    localparam BANK_CAPACITY = (Tm/X) * Tr * Tc; // # of words

    wire    [AW-1: 0]                  wr_addr;
    reg     [DW-1: 0]                  wr_data_reg;
    reg                                wr_ena_reg;

    always@(posedge clk) begin
        wr_data_reg <= wr_data;
        wr_ena_reg <= wr_ena;
    end

    counter #(
        .CW (AW),
        .MAX (BANK_CAPACITY)
    ) counter (
        .ena     (wr_ena),
        .cnt     (wr_addr),
        .done    (),
        .syn_rst (conv_tile_reset),

        .clk     (clk),
        .rst     (rst)
    );

    // Input_fm Bank
    dp_ram_bhm #(
        .AW (AW),
        .DW (DW),
        .NUM (BANK_CAPACITY)
    ) dp_ram_bhm_inst (
        .clock     (clk),
        .data      (wr_data_reg),
        .rdaddress (rd_addr),
        .wraddress (wr_addr),
        .wren      (wr_ena_reg),
        .q         (rd_data)
    );     

endmodule
