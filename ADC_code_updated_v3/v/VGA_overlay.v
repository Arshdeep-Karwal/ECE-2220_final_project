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
	parameter TEXT_COLOR 		= 10'h3FF;	// WHITE
	parameter BACKGROUND_COLOR = 10'h000;	// BLACK
	parameter TEXT_RED 			= 10'hF00;
	parameter TEXT_GREEN			= 10'h0F0;
	
	// TEXT
	parameter TEXT_HEIGHT 		= 64;
	parameter TEXT_WIDTH 		= 320;
	
	parameter TEXT_Y0          = 25;
	parameter TEXT_X0 			= (640 - TEXT_WIDTH) / 2;
	
	wire text_region 				= (iVga_x >= TEXT_X0 & iVga_x < (TEXT_X0 + TEXT_WIDTH) &
											iVga_y >= TEXT_Y0 & iVga_y < (TEXT_Y0 + TEXT_HEIGHT)); // Placement of text
	
	// TEXT - VIDEO OFF
	parameter TEXT_HEIGHT2     = 96;
	parameter TEXT_WIDTH2		= 400;
	
	parameter TEXT_X02			= (640 - TEXT_WIDTH2) / 2;
	parameter TEXT_Y02			= (480 - TEXT_HEIGHT2) / 2;
	
	wire text_region2 			= (iVga_x >= TEXT_X02 & iVga_x < (TEXT_X02 + TEXT_WIDTH2) &
											iVga_y >= TEXT_Y02 & iVga_y < (TEXT_Y02 + TEXT_HEIGHT2));
	
	
	// TEXT FONTS (ASCII)
	parameter CHAR_WIDTH = 8;
	parameter CHAR_HEIGHT = 16;
	
	parameter COLS1 = TEXT_WIDTH / CHAR_WIDTH;
	parameter ROWS1 = TEXT_HEIGHT / CHAR_HEIGHT;
	
	parameter COLS2 = TEXT_WIDTH2 / CHAR_WIDTH;
	parameter ROWS2 = TEXT_HEIGHT2 / CHAR_HEIGHT;
	

	// TEXT BUFFERS 
	reg [7:0] text1 [0:ROWS1-1][0:COLS1-1];
	reg [7:0] text2 [0:ROWS2-1][0:COLS2-1];

	// GET ASCII CODES
	integer ri, cj;
   initial begin
        // VIDEO ON
		for (ri=0; ri<ROWS1; ri = ri+1)
			 for (cj=0; cj<COLS1; cj = cj+1)
				text1[ri][cj] = 8'h20;
			 
	text1[2][15] = "I";
	text1[2][16] = "N";
	text1[2][17] = "T";
	text1[2][18] = "R";
	text1[2][19] = "U";
	text1[2][20] = "D";
	text1[2][21] = "E";
	text1[2][22] = "R";

		 // VIDEO OFF
		 for (ri=0; ri<ROWS2; ri = ri+1)
			 for (cj=0; cj<COLS2; cj = cj+1)
				text2[ri][cj] = 8'h20;

	text2[3][21] = "A";
	text2[2][22] = "R";
	text2[2][23] = "M";
	text2[2][24] = "E";
	text2[2][25] = "D";
    end
	
	// CHARACTER COORDINATES
	// Region1 relative coords
	wire [10:0] rel_x1 = iVga_x - TEXT_X0; // starts at text region starts
	wire [10:0] rel_y1 = iVga_y - TEXT_Y0;
	
	wire [5:0]  col1 = rel_x1 / CHAR_WIDTH;    // 0..39
	wire [4:0]  row1 = rel_y1 / CHAR_HEIGHT;    // 0..3
	wire [2:0]  char_x1 = rel_x1 % CHAR_WIDTH; // 0..7
	wire [3:0]  char_y1 = rel_y1 % CHAR_HEIGHT; // 0..15

	// Region2 relative coords
	wire [10:0] rel_x2 = iVga_x - TEXT_X02;
	wire [10:0] rel_y2 = iVga_y - TEXT_Y02;
	
	wire [6:0]  col2 = rel_x2 / CHAR_WIDTH;    // 0..49
	wire [4:0]  row2 = rel_y2 / CHAR_HEIGHT;    // 0..4
	wire [2:0]  char_x2 = rel_x2 % CHAR_WIDTH;
	wire [3:0]  char_y2 = rel_y2 % CHAR_HEIGHT;

	// DETERMINES IF THE CURRENT PIXEL IS INSIDE TEXT REGION, FIND ASCII CODE IF IT IS
	wire valid1 = (row1 < ROWS1 && col1 < COLS1);
	wire valid2 = (row2 < ROWS2 && col2 < COLS2);
	
	wire [7:0] ascii1 = (text_region & valid1)  ? text1[row1][col1] : 8'h20;
	wire [7:0] ascii2 = (text_region2 & valid2) ? text2[row2][col2] : 8'h20;

	
	
	// FIX CLOCK DELAY FOR ASCII
	 reg [7:0] ascii1_s1, ascii2_s1;
    reg [3:0] char_y1_s1, char_y2_s1;
    reg [2:0] char_x1_s1, char_x2_s1;
    reg       in1_s1, in2_s1;
    
    // Stage 2 registers: capture rom_data outputs and delayed char_x, and region flags
    reg [7:0] rom_data1_s2;
    reg [7:0] rom_data2_s2;
    reg [2:0] char_x1_s2, char_x2_s2;
    reg       in1_s2, in2_s2;

    // rom addr wires (connected to ascii/char_y stage1 regs)
    wire [10:0] rom_addr1 = { ascii1_s1, char_y1_s1 };
    wire [10:0] rom_addr2 = { ascii2_s1, char_y2_s1 };

    // instantiate ascii_rom for both regions
    wire [7:0] rom_out1;
    wire [7:0] rom_out2;

 
    // pipeline and sampling
    always @(posedge iCLK or negedge iRST_N) begin
        if (!iRST_N) begin
            // clear stage1
            ascii1_s1   <= 8'h20;
            ascii2_s1   <= 8'h20;
            char_y1_s1  <= 4'd0;
            char_y2_s1  <= 4'd0;
            char_x1_s1  <= 3'd0;
            char_x2_s1  <= 3'd0;
            in1_s1      <= 1'b0;
            in2_s1      <= 1'b0;

            // clear stage2
            rom_data1_s2 <= 8'h00;
            rom_data2_s2 <= 8'h00;
            char_x1_s2   <= 3'd0;
            char_x2_s2   <= 3'd0;
            in1_s2       <= 1'b0;
            in2_s2       <= 1'b0;
        end else begin
            // Stage1: present current combinational ascii and row to rom inputs
            ascii1_s1  <= ascii1;
            ascii2_s1  <= ascii2;
            char_y1_s1 <= char_y1;
            char_y2_s1 <= char_y2;
            char_x1_s1 <= char_x1;
            char_x2_s1 <= char_x2;
            in1_s1     <= text_region;
            in2_s1     <= text_region2;

            // Stage2: capture rom outputs (these correspond to stage1 addr after ascii_rom internal register)
            rom_data1_s2 <= rom_out1;
            rom_data2_s2 <= rom_out2;
            char_x1_s2   <= char_x1_s1;
            char_x2_s2   <= char_x2_s1;
            in1_s2       <= in1_s1;
            in2_s2       <= in2_s1;
        end
    end

	    ascii_rom ascii_rom_1 (
        .clk(iCLK),
        .addr(rom_addr1),
        .data(rom_out1)
    );

    ascii_rom ascii_rom_2 (
        .clk(iCLK),
        .addr(rom_addr2),
        .data(rom_out2)
    );
	 
    // pixel bits (derived from ROM data and char_x delayed)
//    wire pixel1 = (text_region) ? rom_out1[7 - char_x1_s2] : 1'b0;
//    wire pixel2 = (in2_s2) ? rom_out2[7 - char_x2_s2] : 1'b0;
		wire pixel1 = rom_out1[char_x1_s2];
		wire pixel2 = rom_out2[char_x2_s2];
	
	// VIDEO REGION
	parameter WIDTH 	 = 550;
	parameter HEIGHT   = 380;
	parameter VIDEO_X0 = (640 - WIDTH) / 2;
	parameter VIDEO_Y0 = TEXT_Y0 + TEXT_HEIGHT + 50;	// 20 px below text
	
	wire video_region  = (iVga_x >= VIDEO_X0 & iVga_x < (VIDEO_X0 + WIDTH) &
								 iVga_y >= VIDEO_Y0 & iVga_y < (VIDEO_Y0 + HEIGHT));
								 
								 
	// CAM SCALING
//	wire [9:0] cam_x = (iVga_x - VIDEO_X0) * 2;
//	wire [9:0] cam_y = (iVga_y - VIDEO_Y0) * 2;
	
	// OUTPUT 
	
	always @ (posedge iCLK) begin
		if (!iRST_N) begin
			oRed 	 <= 0;
			oGreen <= 0;
			oBlue  <= 0;
		
		end else begin	
			if (!iVideo_On) begin
				// TEXT ONLY
				
				if (text_region & pixel2) begin
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
				if (text_region2 & pixel1) begin
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
