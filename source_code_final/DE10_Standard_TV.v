// ============================================================================
//		*** SEE COPYRIGHT DISCLAIMER AT END OF FILE ***
//	============================================================================
//		
//		ECE 2220 - DIGITAL LOGIC SYSTEMS
//		SUBMITTED TO: Dr. Douglas A. Buchanan
// 	UNIVERSITY OF MANITOBA
//	
//		Design and Implementation of an Alarm System 
//		with Video Surveillance using Verilog HDL on an FPGA
//
//		TEAM #20
//			Arshdeep Karwal
//			Dev Patel
//			Gundeep Sidhu
//			Matthew Readman


module DE10_Standard_TV(

      ///////// CLOCK /////////
      input              CLOCK_50,

      ///////// KEY /////////
      input    [ 3: 0]   KEY,

      ///////// SW /////////
      input    [ 9: 0]   SW,

      ///////// LED /////////
      output   [ 9: 0]   LEDR,

      /////// 7-SEGMENT ///////
      output   [ 6: 0]   HEX0,
      output   [ 6: 0]   HEX1,
      output   [ 6: 0]   HEX2,

      ///////// SDRAM /////////
      output             DRAM_CLK,
      output             DRAM_CKE,
      output   [12: 0]   DRAM_ADDR,
      output   [ 1: 0]   DRAM_BA,
      inout    [15: 0]   DRAM_DQ,
      output             DRAM_LDQM,
      output             DRAM_UDQM,
      output             DRAM_CS_N,
      output             DRAM_WE_N,
      output             DRAM_CAS_N,
      output             DRAM_RAS_N,

      ///////// VIDEO-IN /////////
      input              TD_CLK27,
      input              TD_HS,
      input              TD_VS,
      input    [ 7: 0]   TD_DATA,
      output             TD_RESET_N,

      ///////// VGA /////////
      output             VGA_CLK,
      output             VGA_HS,
      output             VGA_VS,
      output   [ 7: 0]   VGA_R,
      output   [ 7: 0]   VGA_G,
      output   [ 7: 0]   VGA_B,
      output             VGA_BLANK_N,
      output             VGA_SYNC_N,


      ///////// I2C Video-In /////////
      output             FPGA_I2C_SCLK,
      inout              FPGA_I2C_SDAT,


      ///////// IR //////////
      input              SENSE,
		
		/////// BUZZER ////////
		output 				 BUZZER
);


//=======================================================
//  REG/WIRE declarations
//=======================================================

reg 			 Video_On;								// MAIN REGISTER FOR CONTROL LOGIC
wire 			 Gated_Enable_Main;					// Delay logic for main video input
wire 			 Gated_Enable_SDRAM;					// Delay logic for SDRAM

reg 	[9:0]  SHUTDOWN_CODE = 10'b1111111111; // DEFAULT IS ALL SWITCHES "ON"		
wire 			 Hex_Match;								// Passcode detect

reg 			 sense_hold;	// Current state of IR Sensor
reg 			 ledON;			// Shows IR Sensor works


//  For ITU-R 656 Decoder
//=======================================================
wire	[15:0] YCbCr;
wire	[9:0]	 TV_X;
wire			 TV_DVAL;


//  For VGA Overlay and Controller
//=======================================================

// OVERLAY
wire	[9:0]	 mRed;
wire	[9:0]	 mGreen;
wire	[9:0]	 mBlue;

// CONTROLLER
wire [9:0] 	final_r;
wire [9:0] 	final_g;
wire [9:0] 	final_b;

wire [9:0] 	vga_r10;
wire [9:0] 	vga_g10;
wire [9:0] 	vga_b10;

wire [10:0] VGA_X;
wire [10:0] VGA_Y;
wire  		VGA_Read;	//	VGA data request
wire			m1VGA_Read;	//	Read odd field
wire			m2VGA_Read;	//	Read even field


//  For YUV 4:2:2 to YUV 4:4:4
//=======================================================
wire	[7:0]	 mY;
wire	[7:0]	 mCb;
wire	[7:0]	 mCr;


//  For field select
//=======================================================
wire	[15:0] mYCbCr;
wire	[15:0] mYCbCr_d;
wire	[15:0] m1YCbCr;
wire	[15:0] m2YCbCr;
wire	[15:0] m3YCbCr;


//  For Delay Timer
//=======================================================
wire			 TD_Stable;

wire			 DLY0;
wire			 DLY1;
wire			 DLY2;

//	For Down Sample
//=======================================================
wire	[3:0]	 Remain;
wire	[9:0]	 Quotient;

wire			 mDVAL;

wire	[15:0] m4YCbCr;
wire	[15:0] m5YCbCr;
wire	[8:0]	 Tmp1,Tmp2;
wire	[7:0]	 Tmp3,Tmp4;

wire         NTSC;
wire         PAL;


//=============================================================================
// Structural and Combinational Logic
//=============================================================================

// Sets the passcode of the alarm system to the current state of the 10-bit switches input when KEY[1] is pressed
always @ (posedge CLOCK_50 or negedge KEY[1]) begin
	if (~KEY[1]) SHUTDOWN_CODE = SW;			
end


assign Hex_Match = (SW == SHUTDOWN_CODE);	// Determines if the current state of the switches matches the passcode
			
// MAIN LOGIC - Operates the alarm system based on the passcode and IR sensor input
always @ (posedge CLOCK_50 or negedge KEY[0]) begin
	
	// Resets the system if KEY[0] is pressed
	if (~KEY[0]) begin
		Video_On 			<= 1'b0;
		ledON 				<= 0;
		sense_hold			<= 1'b1;
	end
	else begin	
		
		ledON 				<= 1; // Displays alarm system ON
		
		// Alarm system is disarmed once the current state of the switches match the passcode
		if (Hex_Match) begin
			Video_On 		<= 1'b0;
		end
		
		// Alarm system triggers if the alarm is armed (switches are off) and the IR sensor detects beam break
		if (SW == 10'b0 & sense_hold != SENSE) begin	
			Video_On 		<= 1'b1;
			sense_hold 		<= SENSE;	// Changes the current state of the hold register
		end
	end
end


assign TD_RESET_N		=	1'b1; 	//	Turn On TV Decoder 
assign LEDR[0] 		= ledON;		// System Powered On
assign LEDR[1] 		= Video_On;	// Alarm triggered
assign BUZZER  		= Video_On; // Buzzer triggered

// VGA requests to read data
assign	m1VGA_Read	=	VGA_Y[0]		?	1'b0		:	VGA_Read;
assign	m2VGA_Read	=	VGA_Y[0]		?	VGA_Read	:	1'b0;
assign	mYCbCr_d		=  !VGA_Y[0]	?	m1YCbCr	:  m2YCbCr;
assign	mYCbCr		=	m5YCbCr;

// Format Conversion
assign	Tmp1			=	m4YCbCr[7:0]+mYCbCr_d[7:0];
assign	Tmp2			=	m4YCbCr[15:8]+mYCbCr_d[15:8];
assign	Tmp3			=	Tmp1[8:2]+m3YCbCr[7:1];
assign	Tmp4			=	Tmp2[8:2]+m3YCbCr[15:9];
assign	m5YCbCr		=	{Tmp4,Tmp3};

// Final 8-bit color values for VGA output
assign VGA_R 			= vga_r10[9:2];
assign VGA_G 			= vga_g10[9:2];
assign VGA_B 			= vga_b10[9:2];


//=======================================================
//  7 SEG PASSCODE
//=======================================================
SEG7_LUT_6 			u0	(	
							.oSEG0(HEX0),
							.oSEG1(HEX1),
							.oSEG2(HEX2),
							.iDIG(SW));
//=======================================================
//  TV DECODER ADV7180
//=======================================================						

//	Audio CODEC and video decoder setting (CONFIGURES CHIP)
I2C_AV_Config  	u1	(	//	Host Side
							.iCLK(CLOCK_50),
							.iRST_N(Video_On),	
							//	I2C Side
							.I2C_SCLK(FPGA_I2C_SCLK),
							.I2C_SDAT(FPGA_I2C_SDAT));	
						

//	TV Decoder Stable Check (LOCKED DETECTOR - CHECKS INSTABILITY
TD_Detect			u2	(	.oTD_Stable(TD_Stable),
							.oNTSC(NTSC),
							.oPAL(PAL),
							.iTD_VS(TD_VS),
							.iTD_HS(TD_HS),
							.iRST_N(KEY[0]));		

//	Reset Delay Timer
Reset_Delay			u3	(	.iCLK(CLOCK_50),
							.iRST(TD_Stable),
							.oRST_0(DLY0),
							.oRST_1(DLY1),
							.oRST_2(DLY2));
							


//	ITU-R 656 to YUV 4:2:2 (Extracts data from MAIN DATA STREAM CHIP)
ITU_656_Decoder	u4	(	//	TV Decoder Input
							.iTD_DATA(TD_DATA),
							//	Position Output
							.oTV_X(TV_X),
							//	YUV 4:2:2 Output
							.oYCbCr(YCbCr),
							.oDVAL(TV_DVAL),
							//	Control Signals
							.iSwap_CbCr(Quotient[0]),
							.iSkip(Remain==4'h0),
							.iRST_N(DLY1),
							.iCLK_27(~TD_CLK27)	);

//=======================================================
//  DOWNSAMPLING AND STORAGE OF FRAME BUFFER
//=======================================================						

//	For Down Sample 720 to 640
DIV 				   u5	(	
							.aclr(!DLY0),	
							.clock(TD_CLK27),
							.denom(4'h9),
							.numer(TV_X),
							.quotient(Quotient),
							.remain(Remain));

//	SDRAM frame buffer (MAIN STORAGE UNIT ACTS AS A FRAME BUFFER)
Sdram_Control_4Port	u6	(	//	HOST Side
							.REF_CLK(TD_CLK27),
							.CLK_18(AUD_CTRL_CLK),
						   .RESET_N(DLY0),					
							//	FIFO Write Side 1
						   .WR1_DATA(YCbCr),
							.WR1(TV_DVAL),
							.WR1_FULL(),
							.WR1_ADDR(0),
							.WR1_MAX_ADDR(NTSC ? 640*507 : 640*576),		//	525-18
							.WR1_LENGTH(9'h80),
							.WR1_LOAD(!DLY0),
							.WR1_CLK(TD_CLK27),
							//	FIFO Read Side 1
						   .RD1_DATA(m1YCbCr),
				        	.RD1(m1VGA_Read),
				        	.RD1_ADDR(NTSC ? 640*13 : 640*22),			//	Read odd field and bypess blanking
							.RD1_MAX_ADDR(NTSC ? 640*253 : 640*262),
							.RD1_LENGTH(9'h80),
				        	.RD1_LOAD(!DLY0),
							.RD1_CLK(TD_CLK27),
							//	FIFO Read Side 2
						    .RD2_DATA(m2YCbCr),
				        	.RD2(m2VGA_Read),
				        	.RD2_ADDR(NTSC ? 640*267 : 640*310),			//	Read even field and bypess blanking
							.RD2_MAX_ADDR(NTSC ? 640*507 : 640*550),
							.RD2_LENGTH(9'h80),
				        	.RD2_LOAD(!DLY0),
							.RD2_CLK(TD_CLK27),
							//	SDRAM Side
						   .SA(DRAM_ADDR),
						   .BA(DRAM_BA),
						   .CS_N(DRAM_CS_N),
						   .CKE(DRAM_CKE),
						   .RAS_N(DRAM_RAS_N),
				         .CAS_N(DRAM_CAS_N),
				         .WE_N(DRAM_WE_N),
						   .DQ(DRAM_DQ),
				         .DQM({DRAM_UDQM,DRAM_LDQM}),
							.SDR_CLK(DRAM_CLK)	);
							
//=======================================================
//  CONVERSION OF VIDEO FORMATS AND LINE BUFFERING
//=======================================================								

//	YUV 4:2:2 to YUV 4:4:4
YUV422_to_444		u7	(	//	YUV 4:2:2 Input
							.iYCbCr(mYCbCr),
							//	YUV	4:4:4 Output
							.oY(mY),
							.oCb(mCb),
							.oCr(mCr),
							//	Control Signals
							.iX(VGA_X-160),
							.iCLK(TD_CLK27),
							.iRST_N(DLY0));

//	YCbCr 8-bit to RGB-10 bit 
YCbCr2RGB 			u8	(	//	Output Side
							.Red(mRed),
							.Green(mGreen),
							.Blue(mBlue),
							.oDVAL(mDVAL),
							//	Input Side
							.iY(mY),
							.iCb(mCb),
							.iCr(mCr),
							.iDVAL(VGA_Read),
							//	Control Signal
							.iRESET(!DLY2),
							.iCLK(TD_CLK27));
							
//	Line buffer, delay one line
Line_Buffer 		u9 (
							.aclr(!DLY0),
							.clken(VGA_Read),
							.clock(TD_CLK27),
							.shiftin(mYCbCr_d),
							.shiftout(m3YCbCr));
							
// Second line buffer
Line_Buffer 		u10 (	
							.aclr(!DLY0),
							.clken(VGA_Read),
							.clock(TD_CLK27),
							.shiftin(m3YCbCr),
							.shiftout(m4YCbCr));
					


//=======================================================
//  VGA OUTPUT
//=======================================================	

VGA_overlay 		u11 (
							.iCLK(TD_CLK27),
							.iRST_N(DLY2),
							.iVideo_On(Video_On),
							 
							.iVga_x(VGA_X),
							.iVga_y(VGA_Y),
							 // Video feed RGB data
							.iRed(mRed),
							.iGreen(mGreen),
							.iBlue(mBlue),
							 // RGB output data for VGA_Ctrl
							.oRed(final_r),
							.oGreen(final_g),
							.oBlue(final_b));



VGA_Ctrl				u12 (	//	Host Side
							.iRed(final_r),
							.iGreen(final_g),
							.iBlue(final_b),
							.oCurrent_X(VGA_X),
							.oCurrent_Y(VGA_Y),
							.oRequest(VGA_Read),
							//	VGA Side
							.oVGA_R(vga_r10 ),
							.oVGA_G(vga_g10 ),
							.oVGA_B(vga_b10 ),
							.oVGA_HS(VGA_HS),
							.oVGA_VS(VGA_VS),
							.oVGA_SYNC(VGA_SYNC_N),
							.oVGA_BLANK(VGA_BLANK_N),
							.oVGA_CLOCK(VGA_CLK),
							//	Control Signal
							.iCLK(TD_CLK27),
							.iRST_N(DLY2)	);
endmodule

// ============================================================================
// Copyright (c) 2016 by Terasic Technologies Inc.
// ============================================================================
//
// Permission:
//
//   Terasic grants permission to use and modify this code for use
//   in synthesis for all Terasic Development Boards and Altera Development 
//   Kits made by Terasic.  Other use of this code, including the selling 
//   ,duplication, or modification of any portion is strictly prohibited.
//
// Disclaimer:
//
//   This VHDL/Verilog or C/C++ source code is intended as a design reference
//   which illustrates how these types of functions can be implemented.
//   It is the user's responsibility to verify their design for
//   consistency and functionality through the use of formal
//   verification methods.  Terasic provides no warranty regarding the use 
//   or functionality of this code.
//
// ============================================================================
//           
//  Terasic Technologies Inc
//  9F., No.176, Sec.2, Gongdao 5th Rd, East Dist, Hsinchu City, 30070. Taiwan
//  
//  
//                     web: http://www.terasic.com/  
//                     email: support@terasic.com
//
// ============================================================================
//Date:  Thu Nov  3 15:01:20 2016
// ============================================================================