/*
* Created           : cheng liu
* Date              : 2016-05-17
* Email             : st.liucheng@gmail.com
*
* Description:
* 
* It basically divides the convolution into three different levels.
* In the first layer (kernel), 2D convolution over X * Tr * Tc is done.
*
* In the second layer (slice), it repeats the first layer 
* until all the input channels in the tile is convolved (iteration_num = Tm/X).
* 
* In the third layer (block), it repeats the second layer 
* untill all the output channels in the tile is convolved (Tn/Y). 
* 
* Finally, the computing starts when all the input are ready, so there is no 
* stll during the computing stage.
*
* Instance example
*
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module conv_ctrl_path #(
    parameter AW = 16,
    parameter CW = 16,
    parameter DW = 32,

    parameter K = 3,
    parameter S = 1,

    parameter Tn = 16,
    parameter Tm = 16,
    parameter Tr = 64,
    parameter Tc = 16,

    parameter X = 4,
    parameter Y = 4,

    parameter FP_MUL_DELAY = 11,
    parameter FP_ADD_DELAY = 14,
    parameter FP_ACCUM_DELAY = 9

)(
    input                              conv_computing_start,
    output                             conv_computing_done,
    output                             kernel_start,
    input                              conv_tile_reset,

    output reg [AW-1: 0]               in_fm_rd_addr,
    output reg [AW-1: 0]               weight_rd_addr,
    output reg [AW-1: 0]               out_fm_rd_addr,
    output  [AW-1: 0]                  out_fm_wr_addr,
    output                             out_fm_wr_ena,

    input                              clk,
    input                              rst
);
    // # of computing cycles
    localparam KERNEL_SIZE = K * K; 
    localparam SLICE_SIZE = Tr * Tc;
    localparam OUT_FM_SIZE = SLICE_SIZE * (Tn/Y);
    localparam ROW_OP_NUM = ((Tc+S-K)/S) * KERNEL_SIZE;
    localparam SLICE_OP_NUM = ((Tr+S-K)/S) * ((Tc+S-K)/S) * KERNEL_SIZE; 
    localparam BLOCK_OP_NUM = SLICE_OP_NUM * (Tm/X);
    localparam TILE_OP_NUM = BLOCK_OP_NUM * (Tn/Y);
    localparam OUT_RD_TO_OUT_WR = FP_ADD_DELAY + 2;
    localparam IN_TO_OUT_RD = FP_MUL_DELAY + 2 * FP_ADD_DELAY + FP_ACCUM_DELAY + K * K - 1;
    localparam DONE_DELAY = IN_TO_OUT_RD + 1;

    reg                                conv_computing_start_reg;
    wire                               conv_computing_start_edge;
    reg                                conv_on_going_tmp;
    wire                               conv_on_going;
    wire                               kernel_done;
    wire                               row_done;
    wire                               slice_done;
    wire                               block_done;
    wire                               out_fm_rd_ena;
    wire                               out_slice_done;
    wire                               out_block_done;
    wire                               out_row_done;

    reg     [CW-1: 0]                  row;
    reg     [CW-1: 0]                  col;
    reg     [7: 0]                     i;
    reg     [7: 0]                     j;
    reg     [CW-1: 0]                  slice_id;
    reg     [CW-1: 0]                  block_id;
    reg     [CW-1: 0]                  out_block_id;

    // The counter can be smaller by creating nested counters, but the dependence makes the debugging slightly difficult.
    // Nested counters will be used when the basic convolution functionality is achived.
    counter #(
        .CW (DW),
        .MAX (ROW_OP_NUM)
    ) row_counter (
        .ena     (conv_on_going),
        .cnt     (),
        .done    (row_done),
        .syn_rst (conv_tile_reset),

        .clk     (clk),
        .rst     (rst)
    );
    
    counter #(
        .CW (DW),
        .MAX (TILE_OP_NUM)
    ) tile_counter (
        .ena     (conv_on_going),
        .cnt     (),
        .done    (conv_computing_done),
        .syn_rst (conv_tile_reset),

        .clk     (clk),
        .rst     (rst)
    );

    counter #(
        .CW (DW),
        .MAX (BLOCK_OP_NUM)
    ) block_counter (
        .ena     (conv_on_going),
        .cnt     (),
        .done    (block_done),
        .syn_rst (conv_tile_reset),

        .clk     (clk),
        .rst     (rst)
    );
    
    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            block_id <= 0;
        end
        else if(block_done == 1'b1 && conv_computing_done == 1'b0) begin
            block_id <= block_id + 1;
        end
        else if(conv_computing_done == 1'b1) begin
            block_id <= 0;
        end
    end

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            col <= 0;
        end
        else if((kernel_done == 1'b1) && (col < Tc - K)) begin
            col <= col + S;
        end
        else if ((kernel_done == 1'b1) && (col == Tc - K)) begin
            col <= 0;
        end
    end

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            row <= 0;
        end
        else if(row_done == 1'b1 && slice_done == 1'b0 && block_done == 1'b0) begin
            row <= row + S;
        end
        else if (row_done == 1'b1 && slice_done == 1'b1 && block_done == 1'b0) begin
            row <= row + K;
        end
        else if(block_done == 1'b1) begin
            row <= 0;
        end
    end

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            j <= K;
        end
        else if (j == K && conv_on_going == 1'b1 && conv_tile_reset == 1'b0) begin
            j <= 0;
        end
        else if(conv_on_going == 1'b1 && j < K - 1 && conv_tile_reset == 1'b0) begin
            j <= j + 1;
        end
        else if(conv_on_going == 1'b1 && j == K - 1 && conv_tile_reset == 1'b0) begin
            j <= 0;
        end
        else if(conv_tile_reset == 1'b1) begin
            j <= K;
        end
    end

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            i <= K;
        end
        else if (i == K && conv_on_going == 1'b1 && conv_tile_reset == 1'b0) begin
            i <= 0;
        end
        else if(j == K - 1 && i < K - 1 && conv_tile_reset == 1'b0) begin
            i <= i + 1;
        end
        else if(j == K - 1 && i == K - 1 && conv_tile_reset == 1'b0) begin
            i <= 0;
        end
        else if(conv_tile_reset == 1'b1) begin
            i <= K;
        end
    end

    counter #(
        .CW (8),
        .MAX (KERNEL_SIZE)
    ) kernel_counter (
        .ena      (conv_on_going),
        .cnt      (),
        .done     (kernel_done),
        .syn_rst  (conv_tile_reset),

        .clk      (clk),
        .rst      (rst)
    );


    always@(posedge clk) begin
        conv_computing_start_reg <= conv_computing_start;
    end

    assign conv_computing_start_edge = conv_computing_start && (~conv_computing_start_reg);
    assign kernel_start = (i == 0) && (j == 0) && (conv_on_going == 1'b1);

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            conv_on_going_tmp <= 1'b0;
        end
        else if(conv_computing_start_edge == 1'b1) begin
            conv_on_going_tmp <= 1'b1;
        end
        else if(conv_computing_done == 1'b1) begin
            conv_on_going_tmp <= 1'b0;
        end
    end

    assign conv_on_going = (conv_on_going_tmp == 1'b1) && (conv_computing_done == 1'b0);

    counter #(
        .CW (DW),
        .MAX (SLICE_OP_NUM)
    ) slice_counter (
        .ena     (conv_on_going),
        .cnt     (),
        .done    (slice_done),
        .syn_rst (conv_tile_reset),

        .clk     (clk),
        .rst     (rst)
    );

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            slice_id <= 0;
        end
        else if((slice_done == 1'b1) && (conv_computing_done == 1'b0)) begin
            slice_id <= slice_id + 1;
        end
        else if(conv_computing_done == 1'b1) begin
            slice_id <= 0;
        end
    end

    // Calculate input_fm buffer read address
    // The address calculation can be further optimized through a numer of methods such as pipelining and constant optimization
    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            in_fm_rd_addr <= 0;
        end
        else begin
            in_fm_rd_addr <= (row + i) * Tc + (col + j);
        end
    end

    // calculate weight buffer read address
    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            weight_rd_addr <= 0;
        end
        else begin
            weight_rd_addr <= slice_id * KERNEL_SIZE + i * K + j;
        end
    end

    // Calculate out_fm read and write addresses.
    // As the read and write are done sequentially, the addresses are essentially obtained from a counter.  
    sig_delay # (
        .D (IN_TO_OUT_RD)
    ) sig_delay0 (
        .sig_in  (kernel_start),
        .sig_out (out_fm_rd_ena),

        .clk     (clk),
        .rst     (rst)
    );

    sig_delay # (
        .D (OUT_RD_TO_OUT_WR + 1)
    ) sig_delay1 (
        .sig_in  (out_fm_rd_ena),
        .sig_out (out_fm_wr_ena),

        .clk     (clk),
        .rst     (rst)
    );

    sig_delay # (
        .D (DONE_DELAY)
    ) sig_delay2 (
        .sig_in  (slice_done),
        .sig_out (out_slice_done),

        .clk     (clk),
        .rst     (rst)
    );

    sig_delay # (
        .D (DONE_DELAY)
    ) sig_delay3 (
        .sig_in  (block_done),
        .sig_out (out_block_done),

        .clk     (clk),
        .rst     (rst)
    );    

    sig_delay # (
        .D (DONE_DELAY)
    ) sig_delay4 (
        .sig_in  (row_done),
        .sig_out (out_row_done),

        .clk     (clk),
        .rst     (rst)
    );   

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            out_block_id <= 0;
        end
        else if (out_block_done == 1'b1 && out_block_id < (Tn/Y - 1)) begin
            out_block_id <= out_block_id + 1;
        end
        else if (out_block_done == 1'b1 && out_block_id == (Tn/Y - 1)) begin
            out_block_id <= 0;
        end
    end

    // The address generation can be further optimized.
    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            out_fm_rd_addr <= OUT_FM_SIZE;
        end
        else if (out_fm_rd_ena == 1'b1 && out_fm_rd_addr == OUT_FM_SIZE) begin
            out_fm_rd_addr <= 0;
        end
        else if(out_fm_rd_ena == 1'b1 && out_row_done == 1'b0 && out_slice_done == 1'b0 && out_block_done == 1'b0) begin
            out_fm_rd_addr <= out_fm_rd_addr + 1;
        end
        else if (out_fm_rd_ena == 1'b1 && out_row_done == 1'b1 && out_slice_done == 1'b0 && out_block_done == 1'b0) begin
            out_fm_rd_addr <= out_fm_rd_addr + K;
        end
        else if(out_fm_rd_ena == 1'b1 && out_slice_done == 1'b1 && out_block_done == 1'b0) begin
            out_fm_rd_addr <= out_block_id * SLICE_SIZE;
        end
        else if(out_fm_rd_ena == 1'b1 && out_slice_done == 1'b1 && out_block_done == 1'b1) begin
            out_fm_rd_addr <= (out_block_id + 1) * SLICE_SIZE;
        end        
        else if(out_block_done == 1'b1 && out_block_id == (Tn/Y - 1)) begin
            out_fm_rd_addr <= OUT_FM_SIZE;
        end
    end

    data_delay #(
        .D (OUT_RD_TO_OUT_WR),
        .DW (AW)
    ) data_delay0 (
        .data_in  (out_fm_rd_addr),
        .data_out (out_fm_wr_addr),

        .clk      (clk)
    );

endmodule
