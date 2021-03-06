/*
* Created           : cheng liu
* Date              : 2016-05-18
*
* Description:
* 
* Conv memory interface, it load a tile of data from outside memory such as DDR for computing and stores result back to 
* outside memory when the computing is done. Essentially, it has a set of FIFOs to synchronize the conv_core and 
* outside memory.
* 
* Instance example
conv_mem_if #(
    .DW () 
) conv_mem_if_inst (
    // in_fm FIFO
    .in_fm_to_conv (),
    .in_fm_empty (),
    .in_fm_pop (),

    .in_fm_from_mem (),
    .in_fm_almost_full (),
    .in_fm_push (),

    // weight FIFO
    .weight_to_conv (),
    .weight_empty (),
    .weight_pop (),

    .weight_from_mem (),
    .weight_almost_full (),
    .weight_push (),

    // out_fm load FIFO
    .out_fm_ld_to_conv (),
    .out_fm_ld_empty (),
    .out_fm_ld_pop (),

    .out_fm_ld_from_mem (),
    .out_fm_ld_almost_full (),
    .out_fm_ld_push (),

    // out_fm store FIFO
    .out_fm_st_to_mem (),
    .out_fm_st_empty (),
    .out_fm_st_pop (),

    .out_fm_st_from_conv (),
    .out_fm_st_almost_full (),
    .out_fm_st_push (),

    .clk (),
    .rst ()
);

*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module conv_mem_if #(
    parameter DW = 32 
)(
    // in_fm FIFO
    output                   [DW-1: 0] in_fm_to_conv,
    output                             in_fm_empty,
    input                              in_fm_pop,

    input                    [DW-1: 0] in_fm_from_mem,
    output                             in_fm_almost_full,
    input                              in_fm_push,

    // weight FIFO
    output                   [DW-1: 0] weight_to_conv,
    output                             weight_empty,
    input                              weight_pop,

    input                    [DW-1: 0] weight_from_mem,
    output                             weight_almost_full,
    input                              weight_push,

    // out_fm load FIFO
    output                   [DW-1: 0] out_fm_ld_to_conv,
    output                             out_fm_ld_empty,
    input                              out_fm_ld_pop,

    input                    [DW-1: 0] out_fm_ld_from_mem,
    output                             out_fm_ld_almost_full,
    input                              out_fm_ld_push,

    // out_fm store FIFO
    output                   [DW-1: 0] out_fm_st_to_mem,
    output                             out_fm_st_empty,
    input                              out_fm_st_pop,

    input                    [DW-1: 0] out_fm_st_from_conv,
    output                             out_fm_st_almost_full,
    input                              out_fm_st_push,

    input                              clk,
    input                              rst
);

    fifo_32_256 in_fm_fifo(
	      .clock (clk),
	      .data (in_fm_from_mem),
	      .rdreq (in_fm_pop),
	      .wrreq (in_fm_push),
	      .almost_full (in_fm_almost_full),
	      .empty (in_fm_empty),
	      .full (),
	      .q (in_fm_to_conv)
	  );
	
	  fifo_32_256 weight_fifo(
	      .clock (clk),
	      .data (weight_from_mem),
	      .rdreq (weight_pop),
	      .wrreq (weight_push),
	      .almost_full (weight_almost_full),
	      .empty (weight_empty),
	      .full (),
	      .q (weight_to_conv)
	  );
	
	  fifo_32_256 out_fm_ld_fifo(
	      .clock (clk),
	      .data (out_fm_ld_from_mem),
	      .rdreq (out_fm_ld_pop),
	      .wrreq (out_fm_ld_push),
	      .almost_full (out_fm_ld_almost_full),
	      .empty (out_fm_ld_empty),
	      .full (),
	      .q (out_fm_ld_to_conv)
	  );
	
	  fifo_32_256 out_fm_st_fifo(
	      .clock (clk),
	      .data (out_fm_st_from_conv),
	      .rdreq (out_fm_st_pop),
	      .wrreq (out_fm_st_push),
	      .almost_full (out_fm_st_almost_full),
	      .empty (out_fm_st_empty),
	      .full (),
	      .q (out_fm_st_to_mem)
	  );
	

endmodule
