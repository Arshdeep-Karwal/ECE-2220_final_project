module VGA_overlay (
    input               iCLK,
    input               iRST_N,
    input               iVideo_On,
	 
	 // Control Signals
    input       [10:0]  iVga_x,
    input       [10:0]  iVga_y,
	 
	 // VIDEO FEED RGB
    input       [9:0]   iRed,
    input       [9:0]   iGreen,
    input       [9:0]   iBlue,

    output reg  [9:0]   oRed,
    output reg  [9:0]   oGreen,
    output reg  [9:0]   oBlue
);

	// ==============================
	// VIDEO FEED REGION
	// ==============================
	parameter WIDTH 	 			= 600;
	parameter HEIGHT   			= 480 - VIDEO_Y0;
	parameter VIDEO_X0 			= (640 - WIDTH) / 2;	// X starting position
	parameter VIDEO_Y0 			= 100;						// Y starting position

	wire video_region  			= (iVga_x >= VIDEO_X0 & iVga_x < (VIDEO_X0 + WIDTH) &
											iVga_y >= VIDEO_Y0 & iVga_y < (VIDEO_Y0 + HEIGHT));
					 
	// ==============================
	// COLOR HEXADECIMAL
	// ==============================
	parameter BLACK 				= 10'h000;
	parameter RED   				= 10'hF00;
	parameter GREEN 				= 10'h0F0;


	// ==============================
	// LETTERS OUTPUT 
	// ==============================
	// VIDEO ON ("ARMED")
	parameter CHAR_WIDTH 		= 16;  
	parameter CHAR_HEIGHT 		= 32; 
	parameter VIDEO_OFF_LEN 	= 5;

	parameter [10:0] TEXT_X0  	= (640 - (VIDEO_ON_LEN * CHAR_WIDTH)) / 2;	// Centered Horizontally
	parameter [10:0] TEXT_Y0  	= 60;

	// VIDEO OFF ("INTRUDER")
	parameter CHAR_WIDTH2 		= 32;  
	parameter CHAR_HEIGHT2 		= 64; 
	parameter VIDEO_ON_LEN  	= 8;

	parameter [10:0] TEXT_X02 	= (640 - (VIDEO_OFF_LEN * CHAR_WIDTH2)) / 2; // Centered Horizontally
	parameter [10:0] TEXT_Y02 	= (480 - (CHAR_HEIGHT2)) / 2;						// Centered Vertically



	// =====================================
	// Determine if pixel is in text region
	// =====================================
	wire in_text_on  				= (iVga_x >= TEXT_X0  && iVga_x < TEXT_X0 + (VIDEO_ON_LEN  * CHAR_WIDTH)) &&
										  (iVga_y >= TEXT_Y0  && iVga_y < TEXT_Y0  + CHAR_HEIGHT);

	wire in_text_off 				= (iVga_x >= TEXT_X02 && iVga_x < (TEXT_X02 + (VIDEO_OFF_LEN * CHAR_WIDTH2))) &&
										  (iVga_y >= TEXT_Y02 && iVga_y < (TEXT_Y02 + CHAR_HEIGHT2));


	 // Video ON (Displays a 16 x 32 output text "INTRUDER")
	 wire [3:0] char_x_full 	= (iVga_x - TEXT_X0)  % CHAR_WIDTH;
	 wire [4:0] char_y_full 	= (iVga_y - TEXT_Y0)  % CHAR_HEIGHT;

	// Finds in ASCII ROM by ignoring LSB
	 wire [2:0] char_x_low 		= char_x_full[3:1]; 
	 wire [3:0] char_y_low 		= char_y_full[4:1]; 

	 
	 // Character index is based on the 16-pixel width
	 wire [2:0] char_idx 		= (iVga_x - TEXT_X0) / CHAR_WIDTH;
		 
	 
	 
	 // Video ON (Displays a 32 x 64 output text "ARMED")
	 wire [4:0] char_x_full2 	= (iVga_x - TEXT_X02)  % CHAR_WIDTH2;
    wire [5:0] char_y_full2 	= (iVga_y - TEXT_Y02) % CHAR_HEIGHT2;

    // Finds in ASCII ROM by ignoring 2 of the most LSB
    wire [2:0] char_x_low2 	= char_x_full2[4:2];
    wire [3:0] char_y_low2 	= char_y_full2[5:2]; 

    // Character index is based on the 32-pixel width
    wire [2:0] char_idx2 		= (iVga_x - TEXT_X02) / CHAR_WIDTH2;

	 
	 
	 
    // ===========================================
    // Select ASCII code for current character
    // ===========================================
    reg [6:0] ascii_code;	// Video ON
	 reg [6:0] ascii_code2;	// Video OFF
	 
    always @* begin
		// Default spaces to clear registers
		ascii_code 	= 7'h20;
		ascii_code2 = 7'h20;
		
		  // Video OFF and ON uses case statements to give the ascii code of the Letters corresponding to the index
        if(iVideo_On && in_text_on) begin
            case(char_idx)
                0: ascii_code = "I";
                1: ascii_code = "N";
                2: ascii_code = "T";
                3: ascii_code = "R";
                4: ascii_code = "U";
                5: ascii_code = "D";
                6: ascii_code = "E";
                7: ascii_code = "R";
                default: ascii_code = 7'h20;
            endcase
        end
        else if(!iVideo_On && in_text_off) begin
            case(char_idx2)
                0: ascii_code2 = "A";
                1: ascii_code2 = "R";
                2: ascii_code2 = "M";
                3: ascii_code2 = "E";
                4: ascii_code2 = "D";
                default: ascii_code2 = 7'h20;
            endcase
        end
    end

    // ================================
    // ASCII ROM address and output
    // ================================
    wire [10:0] rom_addr 	= {ascii_code, char_y_low};
	 wire [10:0] rom_addr2 	= {ascii_code2, char_y_low2}; 
    wire [7:0]  rom_out;
	 wire [7:0]  rom_out2;
	 
	 // Calls the Ascii ROM file based on the address obtained for both Video ON and OFF
    ascii_rom (
					.addr(rom_addr),
					.data(rom_out)	// Data for each row
    );
	 
	 ascii_rom (
					.addr(rom_addr2),
					.data(rom_out2)
    );
	 
	 // Determines where the pixel should be on based on the ROM and text regions (for both Video ON and OFF)
    wire pixel_on 	= iVideo_On 	&&		in_text_on 		&&  rom_out[7 - char_x_low]; 
	 wire pixel_on2 	= !iVideo_On 	&&		in_text_off 	&&  rom_out2[7 - char_x_low2];

    // ==========================
    // VGA Output to VGA_Ctrl.v
    // ==========================
    always @(posedge iCLK) begin
	 
		  // Turns off VGA output if hard reset is pressed
        if (!iRST_N) begin
            oRed   <= 0;
            oGreen <= 0;
            oBlue  <= 0;
        end 
		  
		  else begin
		  
				// ALARM NOT TRIGGERED - Text only ("ARMED")
            if (!iVideo_On) begin
				
					 // Determines output pixel by pixel
                if (pixel_on2) begin
                    oRed   <= 0;
                    oGreen <= GREEN;	// Only Green data
                    oBlue  <= 0;
                end 
					
					 // Background
					 else begin
                    oRed   <= BLACK;
                    oGreen <= BLACK;
                    oBlue  <= BLACK;
                end
            end 
				
				else begin
                // ALARM TRIGGERED - Text ("INTRUDER")
                if (pixel_on) begin
                    oRed   <= RED;	// Only Red data
                    oGreen <= 0;
                    oBlue  <= 0;
						  
					 // DISPLAY VIDEO FEED IN REGION
                end else if (video_region) begin
                    oRed   <= iRed;
                    oGreen <= iGreen;
                    oBlue  <= iBlue;
						  
					 // Background
                end else begin
							oRed <= BLACK;
							oGreen <= BLACK;
							oBlue <= BLACK;
					 end
            end
        end
    end
endmodule