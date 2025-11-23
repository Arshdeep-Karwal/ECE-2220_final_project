
//	****************************************************
//
//  Project for testing IR break beam sensor
//
//	****************************************************


	module break ( clk, rst_n, sense, LED0, LED9);
	
		input 					   clk						;	//	50 MHz system clock
		input							rst_n						;	// System reset set to SW[0] - PIN_AB30 - SW[0]=1 to run 
		input							sense						;	//	Can be any GPIO pin - for this project set to PIN_AA12 PIN 40 on GPIO
		
		output	reg				LED0 						;	// LEDR[0] - 1st LED to show LEDR[0] is off for reset, on if running
		output	reg				LED9 						;	// LEDR[9] - last LED which changes state on/off when an object detected.
		
					wire 				slow_clk 				;	//	slowed down clock to about 50 Hz or 20 ms
					reg 				sense_hold				;	//	holds the previosu stated of the count - sensed or not sensed
					
				
//	******************************************************************************************************************************

					
		always @(posedge clk )		 							//	block to detect reset and manage reset LED
			begin

				if ( !rst_n )										// If reset is asserted when SW[0]=0
					begin
						LED0 <= 0								;	// SW[0]=0 ... reset asserted
					end
				
				else
					begin
						LED0 <= 1								;	// SW[0]=1 ... "RUN" - reset NOT asserted
					end
			end
			
		SlowClock U1 (clk, slow_clk)						;


		always @ (posedge slow_clk)	
			begin
				if ( !rst_n ) begin
					
					LED9 <= 0								;	// if reset, turn off object detect
					sense_hold <= 1'b1					;
					
				end else begin
					if ( sense_hold != sense) begin		//	check if "sense" state has changed		
						sense_hold <= sense	;	//	change current sense state
						LED9 <= ~LED9			;	// compliment LED   - changes state
					end 	
				end		
			end
			
		endmodule
		
	
//	**********************************************************************************************
	
//	**************************** Slow clock generator module *************************************	
	
	module SlowClock(clk, slow_clk)					;
	
		input					clk							;	// 50 MHz clock system clock
		output	reg 		slow_clk						;	// 1  Hz  slow clock 25_000_000 ~ 1 sec

					reg 		clk_1Hz = 1'b0				;	//	Reset slow clock to "0"
					reg 		[27:0] counter = 0		;	// 27 bit register to be able to count to 25,000,000
		
					integer	clk_count = 50_000	;	// NEW VALUE
		
		
		always@(posedge clk)
			begin
				counter <= counter + 1					;	// Increment counter
//				if ( counter >= 2)
				if ( counter >= clk_count )		
					begin
						counter <= 0						;	// If counter reaches 50,000,000 / 25,000,000 = 2 edges per period. 
						slow_clk <= ~slow_clk			;	//	Complimrnt the 1 Hz clock
					end
			end

	endmodule
	
	
//	*********************  END --- Slow clock generator module ***********************************	
