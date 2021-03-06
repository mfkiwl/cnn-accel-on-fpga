/*
* Created           : cheng liu
* Date              : 2016-05-18
*
* Description:
* 
* test convolution core logic assuming a single tile of data
* 
* 
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on


module conv_tb;
    parameter AW = 32;
    parameter DW = 32;
    parameter N = 16;
    parameter M = 16;
    parameter R = 32;
    parameter C = 16;
    parameter Tn = 8;
    parameter Tm = 8;
    parameter Tr = 16;
    parameter Tc = 8;
    parameter K = 3;
    parameter X = 4;
    parameter Y = 4;
    parameter ACC_DELAY = 9;
    parameter DIV_DELAY = 20;
    parameter CLK_PERIOD = 10;
    parameter FP_MUL_DELAY = 11;
    parameter FP_ADD_DELAY = 14;
    parameter FP_ACCUM_DELAY = 9;

    localparam in_fm_size = Tm * Tr * Tc;
    localparam weight_size = Tn * Tm * K * K;
    localparam out_fm_size = Tn * Tr * Tc;
    localparam tmp = in_fm_size > out_fm_size ? in_fm_size : out_fm_size;
    localparam max_data_size = weight_size > tmp ? weight_size : tmp;
    localparam last_load_sel = (in_fm_size >= out_fm_size && in_fm_size >= weight_size) ? 2'b01 :
                               (weight_size >= in_fm_size && weight_size >= out_fm_size) ? 2'b10 : 2'b00;
    
    reg                       clk;
    reg                       rst;

    reg             [DW-1: 0] in_fm_mem[0: in_fm_size - 1];
    reg             [DW-1: 0] weight_mem[0: weight_size - 1];
    reg             [DW-1: 0] out_fm_mem[0: out_fm_size - 1];

    wire            [DW-1: 0] in_fm_rd_addr;
    wire            [DW-1: 0] weight_rd_addr;
    wire            [DW-1: 0] out_fm_rd_addr;
    wire            [DW-1: 0] out_fm_wr_addr;

    reg             [DW-1: 0] in_fm_rd_data;
    reg             [DW-1: 0] weight_rd_data;
    reg             [DW-1: 0] out_fm_rd_data;
    reg             [DW-1: 0] in_fm_rd_data_tmp;
    reg             [DW-1: 0] weight_rd_data_tmp;
    reg             [DW-1: 0] out_fm_rd_data_tmp;

    wire            [DW-1: 0] out_fm_wr_data;
    wire                      out_fm_wr_ena;

    reg                       conv_tile_start;
    wire                      conv_tile_done;
    wire                      in_fm_load_start;
    wire                      in_fm_load_done;
    wire                      weight_load_start;
    wire                      weight_load_done;
    wire                      out_fm_load_start;
    wire                      out_fm_load_done;
    wire                      conv_tile_load_done;
    
    wire                      conv_tile_computing_start;
    wire                      conv_tile_computing_done;

    wire                      conv_store_to_fifo_start;
    wire                      conv_store_to_fifo_done;


    wire            [DW-1: 0] in_fm_fifo_data_from_mem;
    wire            [DW-1: 0] weight_fifo_data_from_mem;
    wire            [DW-1: 0] out_fm_ld_fifo_data_from_mem;
    wire            [DW-1: 0] out_fm_st_fifo_data_to_mem;
    
    wire                      in_fm_fifo_push;
    wire                      in_fm_fifo_almost_full;
    wire                      weight_fifo_push;
    wire                      weight_fifo_almost_full;
    wire                      out_fm_ld_fifo_push;
    wire                      out_fm_ld_fifo_almost_full;
    wire                      out_fm_st_fifo_pop;
    wire                      out_fm_st_fifo_empty;
    wire                      conv_tile_store_start;
    wire                      conv_tile_store_done;    

    // clock and reset signal
    always #(CLK_PERIOD/2) clk = ~clk;
    initial begin
        clk = 0;
        rst = 1;

        repeat (10) begin
            @(posedge clk);
        end
        rst = 0;
    end

    // Initialize the outside memory and read the result after computing 
    initial begin
        $readmemh("in_fm_tile_0_0_0_6.txt", in_fm_mem, 0, in_fm_size - 1);
        $readmemh("weight_tile_0_0_0_6.txt", weight_mem, 0, weight_size - 1);
        $readmemh("out_fm_init_tile_0_0_0_6.txt", out_fm_mem, 0, out_fm_size - 1);

        repeat (10000) begin
            @(posedge clk);
        end
        $writememh("out_fm_result_tile.txt", out_fm_mem, 0, out_fm_size - 1);
        $stop(2);
    end

    // outside memory simulation model
    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            in_fm_rd_data_tmp <= 0;
            weight_rd_data_tmp <= 0;

            out_fm_rd_data_tmp <= 0;
            in_fm_rd_data <= 0;

            weight_rd_data <= 0;
            out_fm_rd_data <= 0;
        end
        else begin
            in_fm_rd_data_tmp <= in_fm_mem[in_fm_rd_addr];
            in_fm_rd_data <= in_fm_rd_data_tmp;

            weight_rd_data_tmp <= weight_mem[weight_rd_addr];
            weight_rd_data <= weight_rd_data_tmp;

            out_fm_rd_data_tmp <= out_fm_mem[out_fm_rd_addr];
            out_fm_rd_data <= out_fm_rd_data_tmp;
        end
    end

    always@(posedge clk) begin
        if(out_fm_wr_ena == 1'b1) begin
            out_fm_mem[out_fm_wr_addr] <= out_fm_wr_data;
        end
    end

    // Generate conv start signal
    initial begin
        conv_tile_start = 1'b0;
        repeat (20) begin
            @(posedge clk);
        end
        conv_tile_start = 1'b1;
        @(posedge clk)
        conv_tile_start = 1'b0;
    end
    
    // Store starts 100 cycles after the computing process.
    sig_delay #(
        .D (120)
    ) sig_delay (
        .sig_in (conv_tile_computing_done),
        .sig_out (conv_store_to_fifo_start),
        
        .clk (clk),
        .rst (rst)
    );

    // The three input data start loading at the same time.
    // The load process completes when the last input data is loaded.
    ram_to_fifo #(
        .CW (DW),
        .AW (DW),
        .DW (DW),
        .DATA_SIZE (in_fm_size)
    ) in_fm_ram_to_fifo (
        .start (in_fm_load_start),
        .done (in_fm_load_done),

        .fifo_push (in_fm_fifo_push),
        .fifo_almost_full (in_fm_fifo_almost_full),
        .data_to_fifo (in_fm_fifo_data_from_mem),

        .ram_addr (in_fm_rd_addr),
        .data_from_ram (in_fm_rd_data),

        .clk (clk),
        .rst (rst)
    );

    ram_to_fifo #(
        .CW (DW),
        .AW (DW),
        .DW (DW),
        .DATA_SIZE (weight_size)
    ) weight_ram_to_fifo (
        .start (weight_load_start),
        .done (weight_load_done),

        .fifo_push (weight_fifo_push),
        .fifo_almost_full (weight_fifo_almost_full),
        .data_to_fifo (weight_fifo_data_from_mem),

        .ram_addr (weight_rd_addr),
        .data_from_ram (weight_rd_data),

        .clk (clk),
        .rst (rst)
    );
    
    ram_to_fifo #(
        .CW (DW),
        .AW (DW),
        .DW (DW),
        .DATA_SIZE (out_fm_size)
    ) out_fm_to_fifo (
        .start (out_fm_load_start),
        .done (out_fm_load_done),

        .fifo_push (out_fm_ld_fifo_push),
        .fifo_almost_full (out_fm_ld_fifo_almost_full),
        .data_to_fifo (out_fm_ld_fifo_data_from_mem),

        .ram_addr (out_fm_rd_addr),
        .data_from_ram (out_fm_rd_data),

        .clk (clk),
        .rst (rst)
    );

    fifo_to_ram #(
        .CW (DW),
        .AW (DW),
        .DW (DW),
        .DATA_SIZE (out_fm_size)
    ) fifo_to_out_fm_ram(
        .start (conv_tile_store_start),
        .done (conv_tile_store_done),

        .fifo_pop (out_fm_st_fifo_pop),
        .fifo_empty (out_fm_st_fifo_empty),
        .data_from_fifo (out_fm_st_fifo_data_to_mem),

        .ram_wena (out_fm_wr_ena),
        .ram_addr (out_fm_wr_addr),
        .data_to_ram (out_fm_wr_data),

        .clk (clk),
        .rst (rst)
    );

    assign in_fm_load_start = conv_tile_start;
    assign weight_load_start = conv_tile_start;
    assign out_fm_load_start = conv_tile_start;
    assign conv_tile_load_done = last_load_sel == 2'b01 ? in_fm_load_done :
                                 last_load_sel == 2'b10 ? weight_load_done : out_fm_load_done;

    assign conv_tile_store_start = conv_store_to_fifo_start;
    assign conv_tile_computing_start = conv_tile_load_done;
    assign conv_tile_done = conv_tile_store_done;

    conv_core #(

        .AW (DW),  // input_fm bank address width
        .DW (DW),  // data width
        .Tn (Tn),  // output_fm tile size on output channel dimension
        .Tm (Tm),  // input_fm tile size on input channel dimension
        .Tr (Tr),  // input_fm tile size on feature row dimension
        .Tc (Tc),  // input_fm tile size on feature column dimension
        .K (K),    // kernel scale
        .X (X),    // # of parallel input_fm port
        .Y (Y),    // # of parallel output_fm port
        .FP_MUL_DELAY (FP_MUL_DELAY), // multiplication delay
        .FP_ADD_DELAY (FP_ADD_DELAY), // addition delay
        .FP_ACCUM_DELAY (FP_ACCUM_DELAY) // accumulation delay
    ) conv_core (
        .conv_start (conv_tile_start), 
        .conv_store_to_fifo_done (conv_store_to_fifo_done),
        .conv_store_to_fifo_start (conv_store_to_fifo_start),
        .conv_computing_done (conv_tile_computing_done),

        // port to or from outside memory through FIFO
        .in_fm_fifo_data_from_mem (in_fm_fifo_data_from_mem),
        .in_fm_fifo_push (in_fm_fifo_push),
        .in_fm_fifo_almost_full (in_fm_fifo_almost_full),

        .weight_fifo_data_from_mem (weight_fifo_data_from_mem),
        .weight_fifo_push (weight_fifo_push),
        .weight_fifo_almost_full (weight_fifo_almost_full),

        .out_fm_ld_fifo_data_from_mem (out_fm_ld_fifo_data_from_mem),
        .out_fm_ld_fifo_push (out_fm_ld_fifo_push),
        .out_fm_ld_fifo_almost_full (out_fm_ld_fifo_almost_full),

        .out_fm_st_fifo_data_to_mem (out_fm_st_fifo_data_to_mem),
        .out_fm_st_fifo_empty (out_fm_st_fifo_empty),
        .out_fm_st_fifo_pop (out_fm_st_fifo_pop),

        // system clock
        .clk (clk),
        .rst (rst)
    );

endmodule

