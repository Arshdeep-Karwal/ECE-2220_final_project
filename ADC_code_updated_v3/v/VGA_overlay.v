module VGA_overlay (
		input					iCLK,
		input					iRST_N,
		input 				iVideo_On,
		
		input 	  [10:0]	iVga_x,
		input		  [10:0]	iVga_y,
		
		input		  [9:0]  iRed,
		input 	  [9:0]  iGreen,
		input		  [9:0]  iBlue,
		
		output reg [9:0]  oRed,
		output reg [9:0]  oGreen,
		output reg [9:0]  oBlue		
		);
		
	// COLOR
	parameter TEXT_COLOR 		= 10'h3FF;
	parameter BACKGROUND_COLOR = 10'h000;
	
	// TEXT
	parameter TEXT_HEIGHT 		= 64;
	parameter TEXT_WIDTH 		= 320;
	
	parameter TEXT_Y0          = 25;
	parameter TEXT_X0 			= (640 - TEXT_WIDTH) / 2;
	
	wire text_region 				= (iVga_x >= TEXT_X0 & iVga_x < (TEXT_X0 + TEXT_WIDTH) &
											iVga_y >= TEXT_Y0 & iVga_y < (TEXT_Y0 + TEXT_HEIGHT)); // Placement of text
	
	// TEXT - VIDEO OFF
	parameter TEXT_HEIGHT2     = 80;
	parameter TEXT_WIDTH2		= 400;
	
	parameter TEXT_X02			= (640 - TEXT_WIDTH2) / 2;
	parameter TEXT_Y02			= (480 - TEXT_HEIGHT2) / 2;
	
	wire text_region2 			= (iVga_x >= TEXT_X02 & iVga_x < (TEXT_X02 + TEXT_WIDTH2) &
											iVga_y >= TEXT_Y02 & iVga_y < (TEXT_Y02 + TEXT_HEIGHT2));
	
	
	// VIDEO REGION
	parameter WIDTH 	 = 550;
	parameter HEIGHT   = 380;
	parameter VIDEO_X0 = (640 - WIDTH) / 2;
	parameter VIDEO_Y0 = TEXT_Y0 + TEXT_HEIGHT + 50;	// 20 px below text
	
	wire video_region  = (iVga_x >= VIDEO_X0 & iVga_x < (VIDEO_X0 + WIDTH) &
								 iVga_y >= VIDEO_Y0 & iVga_y < (VIDEO_Y0 + HEIGHT));
								 
								 
	// CAM SCALING
	wire [9:0] cam_x = (iVga_x - VIDEO_X0) * 2;
	wire [9:0] cam_y = (iVga_y - VIDEO_Y0) * 2;
	
	// OUTPUT 
	
	always @ (posedge iCLK) begin
		if (!iRST_N) begin
			oRed 	 <= 0;
			oGreen <= 0;
			oBlue  <= 0;
		
		end else begin	
			if (!iVideo_On) begin
				// TEXT ONLY
				
				if (text_region2) begin
					oRed	 <= TEXT_COLOR;
					oGreen <= TEXT_COLOR;
					oBlue  <= TEXT_COLOR;
				
				end else begin
					oRed	 <= BACKGROUND_COLOR;
					oGreen <= BACKGROUND_COLOR;
					oBlue  <= BACKGROUND_COLOR;
				end
			end
		
			else begin
				// VIDEO FEED IS ON 
				if (text_region) begin
					oRed   <= TEXT_COLOR;
					oGreen <= TEXT_COLOR;
					oBlue  <= TEXT_COLOR;
				end
				else if (video_region) begin
					oRed   <= iRed;
					oGreen <= iGreen;
					oBlue  <= iBlue;
				end
				else begin
					oRed	 <= BACKGROUND_COLOR;
					oGreen <= BACKGROUND_COLOR;
					oBlue  <= BACKGROUND_COLOR;
				end
			end
		end
	end
	
endmodule 
	
