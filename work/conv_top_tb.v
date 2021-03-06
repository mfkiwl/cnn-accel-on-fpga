/*
* Created           : cheng liu
* Date              : 2016-05-28
*
* Description:
* This module assumes all the input/output data are stored in RAM blocks. 
* It schedules the input/output data with the granularity of a tile. Meanwhile 
* it automatically fill zeros when the remaining input/output can't fit into 
* a tile.
* 
*
* Instance example:
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on


module conv_top_tb; 

    parameter AW = 32;
    parameter DW = 32;
    parameter CW = 32;

    parameter N = 16;
    parameter M = 16;
    parameter R = 32;
    parameter C = 16;
    parameter Tn = 8;
    parameter Tm = 8;
    parameter Tr = 16;
    parameter Tc = 8;
    parameter S = 1;
    parameter K = 3;
    parameter X = 4;
    parameter Y = 4;
    parameter FP_MUL_DELAY = 11;
    parameter FP_ADD_DELAY = 14;
    parameter FP_ACCUM_DELAY = 9;
    
    localparam CLK_PERIOD = 10;
    localparam tile_n_num = ceil(N, Tn);
    localparam tile_m_num = ceil(M, Tm);
    localparam tile_row_kernel_num = (Tr + S - K)/S;
    localparam tile_col_kernel_num = (Tc + S - K)/S;
    localparam row_kernel_num = (R + S - K)/S;
    localparam col_kernel_num = (C + S - K)/S;
    localparam tile_row_num = ceil(row_kernel_num, tile_row_kernel_num);
    localparam tile_col_num = ceil(col_kernel_num, tile_col_kernel_num);
    localparam tile_num = tile_n_num * tile_m_num * tile_row_num * tile_col_num;
    localparam in_fm_size = M * R * C;
    localparam weight_size = N * M * K * K;
    localparam out_fm_size = N * R * C;

    // note that y != 0 x > 0, y > 0
    function integer ceil(input integer x, input integer y);
        integer val;
        begin
            val = y;
            ceil = 1;
            while(val < x) begin
                ceil = ceil + 1;
                val = ceil * y;
            end
        end
    endfunction

    reg                                conv_start;
    wire                               conv_done;

    wire                               conv_tile_start;
    wire                               conv_tile_done;

    wire                     [AW-1: 0] in_fm_rd_addr;
    wire                     [AW-1: 0] weight_rd_addr;
    wire                     [AW-1: 0] out_fm_rd_addr;

    reg                      [DW-1: 0] in_fm_rd_data;
    reg                      [DW-1: 0] weight_rd_data;
    reg                      [DW-1: 0] out_fm_rd_data;

    wire                     [AW-1: 0] out_fm_wr_addr;
    wire                     [DW-1: 0] out_fm_wr_data;
    wire                               out_fm_wr_ena;

    wire                               conv_on_going;
    reg                                conv_on_going_tmp;

    reg                                clk;
    reg                                rst;

    wire                     [AW-1: 0] tile_base_n;
    wire                     [AW-1: 0] tile_base_m;
    wire                     [AW-1: 0] tile_base_row;
    wire                     [AW-1: 0] tile_base_col;

    reg                                new_conv_tile_start;

    reg                      [DW-1: 0] in_fm_mem [0: in_fm_size - 1];
    reg                      [DW-1: 0] weight_mem [0: weight_size - 1];
    reg                      [DW-1: 0] out_fm_mem [0: out_fm_size - 1];
    
    wire                               conv_clean; // set counters to initial states
    reg                      [DW-1: 0] timer;
    
    always@(posedge clk or posedge rst) begin
      if(rst == 1'b1) begin
        timer <= 0;
      end
      else begin
        timer <= timer + 1;
      end
    end
    
    assign conv_clean = conv_done;   

    integer file0;   
    initial begin
      file0 = $fopen("out_fm_rd.txt","w");
      while(1) begin
        @(timer);
        if(timer > 32'hf45d && timer < 32'hF85E) begin
          $fwrite(file0,"%H\n",out_fm_rd_data); 
        end
      end
      $fclose(file0);
    end

    integer file1;
    initial begin
      file1 = $fopen("in_fm_rd.txt","w");
      while(1) begin
        @(timer);
        if(timer > 32'hf45d && timer < 32'hF85E) begin
          $fwrite(file1,"%H\n",in_fm_rd_data); 
        end
      end
      $fclose(file1);
    end

    integer file2; 
    initial begin
      file2 = $fopen("weight_rd.txt","w");
      while(1) begin
        @(timer);
        if(timer > 32'hf45d && timer < 32'hF69E) begin
          $fwrite(file2,"%H\n",weight_rd_data); 
        end
      end
      $fclose(file2);
    end
    
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

    // Generate conv start signal
    initial begin
        conv_start = 1'b0;
        repeat (20) begin
            @(posedge clk);
        end
        conv_start = 1'b1;
        @(posedge clk)
        conv_start = 1'b0;
    end

    // Initialize the outside memory and read the result after computing 
    initial begin
        $readmemh("in_fm.txt", in_fm_mem, 0, in_fm_size - 1);
        $readmemh("weight.txt", weight_mem, 0, weight_size - 1);
        $readmemh("out_fm_init.txt", out_fm_mem, 0, out_fm_size - 1);

        repeat (240000) begin
            @(posedge clk);
        end
        $writememh("out_fm_result.txt", out_fm_mem, 0, out_fm_size - 1);
        $stop(2);
    end

    // outside memory simulation model
    reg                      [DW-1: 0] in_fm_rd_data_tmp;
    reg                      [DW-1: 0] weight_rd_data_tmp;
    reg                      [DW-1: 0] out_fm_rd_data_tmp;

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

    // Tile module
    conv_tile #(
        .CW (CW),
        .AW (AW),
        .DW (DW),
        .N (N),
        .M (M),
        .R (R),
        .C (C),
        .Tn (Tn),
        .Tm (Tm),
        .Tr (Tr),
        .Tc (Tc),
        .S (S),
        .K (K),
        .X (X),
        .Y (Y),
        .FP_MUL_DELAY (FP_MUL_DELAY),
        .FP_ADD_DELAY (FP_ADD_DELAY),
        .FP_ACCUM_DELAY (FP_ACCUM_DELAY)
        
    ) conv_tile (
        .conv_tile_start (conv_tile_start),
        .conv_tile_done (conv_tile_done),
        
        .in_fm_rd_addr (in_fm_rd_addr),
        .weight_rd_addr (weight_rd_addr),
        .out_fm_rd_addr (out_fm_rd_addr),

        .in_fm_rd_data (in_fm_rd_data),
        .weight_rd_data (weight_rd_data),
        .out_fm_rd_data (out_fm_rd_data),

        .out_fm_wr_addr (out_fm_wr_addr),
        .out_fm_wr_data (out_fm_wr_data),
        .out_fm_wr_ena (out_fm_wr_ena),

        .tile_base_n (tile_base_n),
        .tile_base_m (tile_base_m),
        .tile_base_row (tile_base_row),
        .tile_base_col (tile_base_col),

        .clk (clk),
        .rst (rst)
    );

    gen_tile_cord #(
        .AW (AW),
        .N (N),
        .M (M),
        .R (R),
        .C (C),
        .Tn (Tn),
        .Tm (Tm),
        .Tr (Tr),
        .Tc (Tc),
        .K (K),
        .S (S)
    ) gen_tile_cord (
        .conv_tile_done (conv_tile_done),

        .tile_base_n (tile_base_n),
        .tile_base_m (tile_base_m),
        .tile_base_row (tile_base_row),
        .tile_base_col (tile_base_col),

        .clk (clk),
        .rst (rst)
    );

    always@(posedge clk or posedge rst) begin
        if(rst == 1'b1) begin
            conv_on_going_tmp <= 1'b0;
        end
        else if(conv_start == 1'b1) begin
            conv_on_going_tmp <= 1'b1;
        end
        else if(conv_done == 1'b1) begin
            conv_on_going_tmp <= 1'b0;
        end
    end
    assign conv_on_going = (conv_on_going_tmp == 1'b1) && (conv_done == 1'b0);

    counter #(
        .CW (AW),
        .MAX (tile_num)
    ) counter (
        .ena (conv_tile_done),
        .cnt (),
        .done (conv_done),
        .clean (conv_clean),

        .clk (clk),
        .rst (rst)
    );
    
    reg                                conv_start_reg;
    wire                               conv_start_edge;
    always@(posedge clk) begin
        conv_start_reg <= conv_start;
        new_conv_tile_start <= conv_tile_done;
    end

    assign conv_start_edge = conv_start && (~conv_start_reg);
    assign conv_tile_start = (conv_start_edge == 1'b1) || 
                             ((new_conv_tile_start == 1'b1) && (conv_done == 1'b0));


endmodule
