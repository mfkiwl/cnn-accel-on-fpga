// megafunction wizard: %ALTERA_FP_ACC_CUSTOM v15.1%
// GENERATION: XML
// facc.v

// Generated using ACDS version 15.1 185

`timescale 1 ps / 1 ps
module facc (
		input  wire        clk,    //    clk.clk
		input  wire        areset, // areset.reset
		input  wire [31:0] x,      //      x.x
		input  wire        n,      //      n.n
		output wire [31:0] r,      //      r.r
		output wire        xo,     //     xo.xo
		output wire        xu,     //     xu.xu
		output wire        ao      //     ao.ao
	);

	facc_0002 facc_inst (
		.clk    (clk),    //    clk.clk
		.areset (areset), // areset.reset
		.x      (x),      //      x.x
		.n      (n),      //      n.n
		.r      (r),      //      r.r
		.xo     (xo),     //     xo.xo
		.xu     (xu),     //     xu.xu
		.ao     (ao)      //     ao.ao
	);

endmodule
// Retrieval info: <?xml version="1.0"?>
//<!--
//	Generated by Altera MegaWizard Launcher Utility version 1.0
//	************************************************************
//	THIS IS A WIZARD-GENERATED FILE. DO NOT EDIT THIS FILE!
//	************************************************************
//	Copyright (C) 1991-2016 Altera Corporation
//	Any megafunction design, and related net list (encrypted or decrypted),
//	support information, device programming or simulation file, and any other
//	associated documentation or information provided by Altera or a partner
//	under Altera's Megafunction Partnership Program may be used only to
//	program PLD devices (but not masked PLD devices) from Altera.  Any other
//	use of such megafunction design, net list, support information, device
//	programming or simulation file, or any other related documentation or
//	information is prohibited for any other purpose, including, but not
//	limited to modification, reverse engineering, de-compiling, or use with
//	any other silicon devices, unless such use is explicitly licensed under
//	a separate agreement with Altera or a megafunction partner.  Title to
//	the intellectual property, including patents, copyrights, trademarks,
//	trade secrets, or maskworks, embodied in any such megafunction design,
//	net list, support information, device programming or simulation file, or
//	any other related documentation or information provided by Altera or a
//	megafunction partner, remains with Altera, the megafunction partner, or
//	their respective licensors.  No other licenses, including any licenses
//	needed under any third party's intellectual property, are provided herein.
//-->
// Retrieval info: <instance entity-name="altera_fp_acc_custom" version="15.1" >
// Retrieval info: 	<generic name="fp_format" value="single" />
// Retrieval info: 	<generic name="frequency" value="200" />
// Retrieval info: 	<generic name="gen_enable" value="false" />
// Retrieval info: 	<generic name="MSBA" value="20" />
// Retrieval info: 	<generic name="maxMSBX" value="12" />
// Retrieval info: 	<generic name="LSBA" value="-26" />
// Retrieval info: 	<generic name="selected_device_family" value="Cyclone V" />
// Retrieval info: 	<generic name="selected_device_speedgrade" value="7" />
// Retrieval info: </instance>
// IPFS_FILES : facc.vo
// RELATED_FILES: facc.v, dspba_library_package.vhd, dspba_library.vhd, facc_0002.vhd
