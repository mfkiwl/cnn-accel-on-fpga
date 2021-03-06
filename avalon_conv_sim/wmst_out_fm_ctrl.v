/*
* Created           : Cheng Liu
* Date              : 2016-04-25
*
* Description:
* Set softmax basic design parameters and expose information to upper mmodules
softmax_config #(
    .AW (),  // Internal memory address width
    .DW (),  // Internal data width
    .CW ()    // maxium number of configuration paramters is (2^CW).
)softmax_config(
    .config_ena (),
    .config_addr (),
    .config_wdata (),
    .config_rdata (),
    
    .config_done (),       // configuration is done. (orginal name: param_ena)
    .param_raddr (),
    .param_waddr (),
    .param_iolen (),
    .task_done (), // computing task is done. (original name: flag_over)
    
    .rst (),
    .clk ()
);

*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on

module wmst_out_fm_ctrl #(
    parameter AW = 12,  // Internal memory address width
    parameter CW = 16,
    parameter DW = 32,  // Internal data width
    parameter N = 32,
    parameter M = 32,
    parameter R = 64,
    parameter C = 32,
    parameter Tn = 16,
    parameter Tm = 16,
    parameter Tr = 64,
    parameter Tc = 16,
    parameter S = 1,
    parameter K = 3
)(
    input                              store_start,
    output reg                         store_done,
  
    output                    [DW-1:0] param_waddr, // aligned by byte
    output reg                [AW-1:0] param_iolen, // aligned by word

    input                              store_trans_done,        // computing task is done. (original name: flag_over)
    output reg                         store_trans_start,
    input                              store_fifo_empty,

    input                    [CW-1: 0] tile_base_n,
    input                    [CW-1: 0] tile_base_row,
    input                    [CW-1: 0] tile_base_col,
    
    input                              rst,
    input                              clk
);

    localparam WMST_IDLE = 3'b000;
    localparam WMST_CONFIG = 3'b001; // Immediately ready for write transmission
    localparam WMST_WAIT = 3'b010; // wait for either no-empty store fifo or available avalon response
    localparam WMST_TRANS = 3'b011; // start data transmission
    localparam WMST_DONE = 3'b111; // complete the data transmiossion
    localparam out_fm_base = 0;

    reg                        [2: 0] wmst_status;
    wire                              is_last_trans_pulse;
    reg                               is_last_trans;
    wire                    [DW-1: 0] base_addr;
    wire                              row_burst_ena;
    wire                    [CW-1: 0] tn;
    wire                    [CW-1: 0] tr;

always@(posedge clk or posedge rst) begin
    if(rst == 1'b1) begin
        is_last_trans <= 1'b0;
    end
    else if(is_last_trans_pulse == 1'b1) begin
        is_last_trans <= 1'b1;
    end
    else if(store_done == 1'b1) begin
        is_last_trans <= 1'b0;
    end

end

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            wmst_status <= WMST_IDLE;
        end
        else if(store_done == 1'b1) begin
            wmst_status <= WMST_IDLE;
        end
        else if (wmst_status == WMST_IDLE && store_start == 1'b1 && store_fifo_empty == 1'b0) begin
            wmst_status <= WMST_CONFIG;
        end
        else if (wmst_status == WMST_IDLE && store_start == 1'b1 && store_fifo_empty == 1'b1) begin
            wmst_status <= WMST_WAIT;
        end
        else if (wmst_status == WMST_WAIT && store_fifo_empty == 1'b0) begin
            wmst_status <= WMST_CONFIG;
        end
        else if (wmst_status == WMST_CONFIG) begin
            wmst_status <= WMST_TRANS;
        end
        else if(wmst_status == WMST_TRANS && store_trans_done == 1'b1) begin
            wmst_status <= WMST_DONE;
        end
        else if(wmst_status == WMST_DONE && is_last_trans == 1'b0 && store_fifo_empty == 1'b0) begin
            wmst_status <= WMST_CONFIG;
        end
        else if(wmst_status == WMST_DONE && is_last_trans == 1'b0 && store_fifo_empty == 1'b1) begin
            wmst_status <= WMST_WAIT;
        end
        else if(wmst_status == WMST_DONE && is_last_trans == 1'b1) begin
            wmst_status <= WMST_IDLE;
        end
    end

nest2_counter #(
    .CW (CW),
    .n1_max (Tn),
    .n0_max (Tr)
) nest2_counter(
    .ena (row_burst_ena),
    .clean (store_done), // When the whole tile is stored, the counter will be reset.

    .cnt0 (tr),
    .cnt1 (tn),

    .done (is_last_trans_pulse), 
    
    .clk (clk),
    .rst (rst)
);
assign row_burst_ena = wmst_status == WMST_CONFIG; // it is one cycle ahead of load_trans_start
assign base_addr = out_fm_base + (tile_base_n + tn) * R * C + (tile_base_row + tr) * C + tile_base_col;
assign param_waddr = (base_addr << 2);

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            param_iolen <= 0;
        end
        else if(wmst_status == WMST_CONFIG) begin
            param_iolen <= Tc;
        end
    end    

   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           store_done <= 1'b0;
       end
       else if(wmst_status == WMST_DONE && is_last_trans == 1'b1) begin
           store_done <= 1'b1;
       end
       else begin
           store_done <= 1'b0;
       end
   end

   always@(posedge clk or posedge rst) begin
       if(rst == 1'b1) begin
           store_trans_start <= 1'b0;
       end
       else if(wmst_status == WMST_CONFIG) begin
           store_trans_start <= 1'b1;
       end
       else begin
           store_trans_start <= 1'b0;
       end
   end

endmodule
