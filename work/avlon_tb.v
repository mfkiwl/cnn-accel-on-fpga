/*
* Created           : cheng liu
* Date              : 2016-04-26
*
* Description:
* 
* Verify the read master port and write master port 
* 
* 
*/

`timescale 1ns/1ns

module avlon_tb;

parameter CLOCK_PERIOD = 20;
parameter DATA_SIZE = 1024;

reg         clk = 0;
reg         rst = 0;
reg         softmax_core_done;

always # ( CLOCK_PERIOD / 2 ) clk = ~clk;

initial begin
    rst = 1;
    softmax_core_done = 0;
    # 60
    rst = 0; 
    # 4000
    softmax_core_done = 1; 
end

localparam AW = 12;
localparam DW = 32;
localparam CW = 6;
localparam XAW = 32;
localparam XDW = 128;
localparam WCNT =(XDW/DW);

wire  [R_PORT-1:0]        rmst_fixed_location;   // fixed_location
wire  [R_PORT*32-1:0]     rmst_read_base;        // read_base
wire  [R_PORT*32-1:0]     rmst_read_length;      // read_length
wire  [R_PORT-1:0]        rmst_go;               // go
wire  [R_PORT-1:0]        rmst_done;             // done
wire  [R_PORT-1:0]        rmst_user_read_buffer;      // read_buffer
wire  [R_PORT*128-1:0]    rmst_user_buffer_data;      // buffer_output_data
wire  [R_PORT-1:0]        rmst_user_data_available;   // data_available

wire  [W_PORT-1:0]        wmst_fixed_location;   // fixed_location
wire  [W_PORT*32-1:0]     wmst_write_base;       // write_base
wire  [W_PORT*32-1:0]     wmst_write_length;     // write_length
wire  [W_PORT-1:0]        wmst_go;               // go
wire  [W_PORT-1:0]        wmst_done;             // done
wire  [W_PORT-1:0]        wmst_user_write_buffer;// write_buffer
wire  [W_PORT*128-1:0]    wmst_user_write_data;  // buffer_input_data
wire  [W_PORT-1:0]        wmst_user_buffer_full;      

reg                       config_ena;
wire                      config_done;
reg             [CW-1: 0] config_addr;
reg             [DW-1: 0] config_wdata;
wire            [DW-1: 0] config_rdata;

wire            [DW-1: 0] param_raddr;
wire            [DW-1: 0] param_waddr;
wire            [AW-1: 0] param_iolen;
wire                      load_data_done;
wire                      store_data_done;

initial begin
    config_ena = 0;
    config_addr = 0;
    config_wdata = 0;
      
    repeat (5) begin
        @(posedge clk);
    end
    config_ena = 1;
    config_addr = 0;
    config_wdata = 0;
      
    @(posedge clk);
    config_ena = 1;
    config_addr = 1;
    config_wdata = 0;
    
    @(posedge clk);
    config_ena = 1;
    config_addr = 2;
    config_wdata = DATA_SIZE;
      
    @(posedge clk);
    config_ena = 1;
    config_addr = 'h20;
    config_wdata = 1;
    
    @(posedge clk);
    config_ena = 0;
    config_addr = 0;
    config_wdata = 0;
end

softmax_config #(
    .AW (AW),  // Internal memory address width
    .DW (DW),  // Internal data width
    .CW (CW)   // maxium number of configuration paramters is (2^CW).
)softmax_config(
    .config_ena (config_ena),
    .config_addr (config_addr),
    .config_wdata (config_wdata),
    .config_rdata (config_rdata),
    
    .config_done (config_done), // configuration is done. (orginal name: param_ena)
    .param_raddr (param_raddr),
    .param_waddr (param_waddr),
    .param_iolen (param_iolen),
    .softmax_core_done (softmax_core_done), // computing task is done. (original name: flag_over)
    
    .rst (rst),
    .clk (clk)
);

softmax_dp_mem #(
    .AW (AW),
    .DW (DW),
    .XAW (XAW),
    .XDW (XDW),
    .WCNT (WCNT),
    .DATA_SIZE (DATA_SIZE)
) softmax_dp_mem (
    .config_done     (config_done),
    .param_raddr    (param_raddr),
    .param_waddr    (param_waddr),
    .param_iolen    (param_iolen),

    .rmst_fixed_location   (rmst_fixed_location),
    .rmst_read_base        (rmst_read_base),
    .rmst_read_length      (rmst_read_length),
    .rmst_go               (rmst_go),
    .rmst_done             (rmst_done),
    .rmst_user_read_buffer (rmst_user_read_buffer),
    .rmst_user_buffer_data (rmst_user_buffer_data),
    .rmst_user_data_available (rmst_user_data_available),
    
    .wmst_fixed_location   (wmst_fixed_location),
    .wmst_write_base       (wmst_write_base),
    .wmst_write_length     (wmst_write_length),
    .wmst_go               (wmst_go),
    .wmst_done             (wmst_done),
    .wmst_user_write_buffer(wmst_user_write_buffer),
    .wmst_user_write_data  (wmst_user_write_data),
    .wmst_user_buffer_full (wmst_user_buffer_full),
    
    .load_data_done (load_data_done),
    .store_data_done (store_data_done),

    .clk(clk),
    .rst(rst)
);

avl_ram avl_ram (
		.avlon_slv_s0_waitrequest (),   //avlon_slv_s0.waitrequest
		.avlon_slv_s0_readdata (),      //.readdata
		.avlon_slv_s0_readdatavalid (), //.readdatavalid
		.avlon_slv_s0_response (),      //.response
		.avlon_slv_s0_burstcount (),    //.burstcount
		.avlon_slv_s0_writedata (),     //.writedata
		.avlon_slv_s0_address (),       //.address
		.avlon_slv_s0_write (),         //.write
		.avlon_slv_s0_read (),          //.read
		.avlon_slv_s0_byteenable (16'hFFFF), //.byteenable
		.avlon_slv_s0_debugaccess (1'b0),    //.debugaccess
		.clk_clk (clk),                      //clk.clk
		.reset_reset_n (!rst)                //reset.reset_n
	);


mem_top #(
    .R_PORT (R_PORT),
    .W_PORT (W_PORT)
) mem_model(
    .read_control_fixed_location (rmst_fixed_location),
    .read_control_read_base (rmst_read_base),
    .read_control_read_length (rmst_read_length),
    .read_control_go (rmst_go), 
    .read_control_done (rmst_done), 
    .read_user_read_buffer (rmst_user_read_buffer),
    .read_user_buffer_output_data (rmst_user_buffer_data),
    .read_user_data_available (rmst_user_data_available),

    .write_control_fixed_location (wmst_fixed_location),
    .write_control_write_base (wmst_write_base),
    .write_control_write_length (wmst_write_length),
    .write_control_go (wmst_go),
    .write_control_done (wmst_done), 
    .write_user_write_buffer (wmst_user_write_buffer),
    .write_user_buffer_input_data (wmst_user_write_data),
    .write_user_buffer_full (wmst_user_buffer_full), 
    
    .clk (clk),
    .rst (rst)
);

endmodule
