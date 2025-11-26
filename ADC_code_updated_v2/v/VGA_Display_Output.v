// ****************************************************
// Module: VGA_Display_Output
// Functionality:
// 1. Receives current VGA coordinates (X, Y) from VGA_Ctrl.
// 2. Checks system enable (iRST_N) for standby mode.
// 3. Resizes the live video area (starts at Y=100) for a text header.
// 4. Outputs pixel colors (oVGA_R/G/B) to be fed into VGA_Ctrl's input.
// ****************************************************

module VGA_Display_Output (
    input               iCLK,
    input               iRST_N,           // System Enable (Gated_Enable_Main)
    input       [10: 0] iVGA_X,           // Horizontal Coordinate (0-639)
    input       [10: 0] iVGA_Y,           // Vertical Coordinate (0-479)
    
    // Video Read Interface (Placeholder for connection to SDRAM read module)
    output      [ 9: 0] oVideo_Read_X,    // The X coordinate to read from SDRAM (0-639)
    output      [ 9: 0] oVideo_Read_Y,    // The Y coordinate to read from SDRAM (0-479, scaled)
    input       [ 9: 0] iVideo_R_SDRAM,   // Incoming Red data from video buffer
    input       [ 9: 0] iVideo_G_SDRAM,   // Incoming Green data from video buffer
    input       [ 9: 0] iVideo_B_SDRAM,   // Incoming Blue data from video buffer
    
    // Final RGB output to VGA_Ctrl (iRed, iGreen, iBlue inputs)
    output  reg [ 9: 0] oVGA_R,
    output  reg [ 9: 0] oVGA_G,
    output  reg [ 9: 0] oVGA_B
);

// --- PARAMETERS ---
// Standard 640x480 resolution
parameter H_ACT_MAX  = 639;
parameter V_ACT_MAX  = 479;

// Text header area will be 100 lines high. Video starts at Y=100.
parameter HEADER_HEIGHT = 100;
parameter VIDEO_START_Y = HEADER_HEIGHT;

// --- INTERNAL SIGNALS ---
// The actual coordinates needed to read the video buffer (offset by HEADER_HEIGHT)
reg [10:0] Video_X_Offset;
reg [10:0] Video_Y_Offset;

// Define the boundaries for the resized video
// Note: Coordinates from VGA_Ctrl include blanking; we only care about active area (640x480).
wire X_Active = (iVGA_X < H_ACT_MAX + 1);
wire Y_Active = (iVGA_Y < V_ACT_MAX + 1);

wire Video_Area_Active = X_Active && Y_Active && (iVGA_Y >= VIDEO_START_Y);


// =================================================================
// 1. COORDINATE OFFSET CALCULATION
// Used to address the SDRAM buffer correctly
// =================================================================

always @(posedge iCLK) begin
    if (Video_Area_Active) begin
        // Calculate the new Y coordinate (Y - 100)
        Video_Y_Offset <= iVGA_Y - VIDEO_START_Y;
        Video_X_Offset <= iVGA_X; // X coordinate remains the same
    end else begin
        Video_Y_Offset <= 10'd0; 
        Video_X_Offset <= 10'd0;
    end
end

// Output the scaled 10-bit coordinates to the SDRAM reader module
assign oVideo_Read_X = Video_X_Offset[9:0]; // Assuming video buffer is 640 wide
assign oVideo_Read_Y = Video_Y_Offset[9:0]; // Assuming video buffer is 480 high (scaled)


// =================================================================
// 2. PIXEL OUTPUT (Color MUX)
// =================================================================

always @* begin
    // Default output color (used for blanking areas outside 640x480)
    oVGA_R = 10'h000; 
    oVGA_G = 10'h000; 
    oVGA_B = 10'h000;

    // Check System Enable (If system is disabled, output a solid gray standby screen)
    if (!iRST_N) begin
        if (X_Active && Y_Active) begin
            // Solid Gray Standby Screen (e.g., 25% brightness)
            oVGA_R = 10'h100; oVGA_G = 10'h100; oVGA_B = 10'h100; 
        end
    end 
    // If system is enabled, check coordinates
    else begin 
        if (Video_Area_Active) begin
            // 2A. VIDEO AREA: Output the live video data from SDRAM
            oVGA_R = iVideo_R_SDRAM;
            oVGA_G = iVideo_G_SDRAM;
            oVGA_B = iVideo_B_SDRAM;
        end 
        else if (X_Active && Y_Active && iVGA_Y < VIDEO_START_Y) begin
            // 2B. HEADER/TEXT AREA (Y < 100): Draw the custom graphics
            
            // Background Color: Dark Blue
            oVGA_R = 10'h000; oVGA_G = 10'h000; oVGA_B = 10'h240; 

            // Simple white box placeholder for text (simulating "LIVE FEED ACTIVE")
            if (iVGA_Y >= 35 && iVGA_Y <= 65 && iVGA_X >= 150 && iVGA_X <= 489) begin
                 oVGA_R = 10'h3FF; oVGA_G = 10'h3FF; oVGA_B = 10'h3FF; // White "Text" Box (Full brightness)
            end
        end
        // All other coordinates (VGA blanking intervals) remain black (default)
    end
end

endmodule