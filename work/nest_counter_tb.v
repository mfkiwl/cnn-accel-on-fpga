/*
* Created           : cheng liu
* Date              : 2016-05-19
*
* Description:
* Test the counter 
*
* 
*/

// synposys translate_off
`timescale 1ns/100ps
// synposys translate_on


module counter_tb;

    parameter CW = 16;
    parameter CLK_PERIOD = 10;

    reg                                clk;
    reg                                rst;
    reg                                ena;
    wire                     [CW-1: 0] cnt0;
    wire                     [CW-1: 0] cnt1;
    wire                     [CW-1: 0] cnt2;

    always #(CLK_PERIOD/2) clk = ~clk;
    
    initial begin
        clk = 0;
        rst = 1;

        repeat (10) begin
            @(posedge clk);
        end
        rst = 0;
    end

    initial begin
        ena = 0;
        
        repeat (10) begin
            @(posedge clk);
        end
        ena = 1;
        
        repeat (2) begin
            @(posedge clk);
        end
        ena = 0;
        
        repeat (1) begin
          @(posedge clk);
        end
        ena = 1;
        
        repeat (50) begin
          @(posedge clk);
        end
        ena = 0;
        
        repeat (10) begin
          @(posedge clk);
        end
        ena = 1;
        
        repeat (50) begin
          @(posedge clk);
        end
        ena = 0;
        
        $stop(2);
        
    end

    nest4_counter #(
        .CW (CW),
        .n0_max (4),
        .n1_max (2),
        .n2_max (2)
    ) nest4_counter (
        .ena (ena),
        .done (done),

        .cnt0 (cnt0),
        .cnt1 (cnt1),
        .cnt2 (cnt2),

        .clk (clk),
        .rst (rst)
    );

endmodule
