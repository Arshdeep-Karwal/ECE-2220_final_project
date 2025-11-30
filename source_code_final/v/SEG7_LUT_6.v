module SEG7_LUT_6 (oSEG0, oSEG1, oSEG2, iDIG );
	
	input	   [11:0] iDIG;					// Switches Input
	output	[6:0]	 oSEG0,oSEG1,oSEG2;	// Output to 7-Segment Displays

	// Converts switches input to hexadecimal by splitting into 4 bits each for 1 segment
	SEG7_LUT	u0	(oSEG0,iDIG[3:0]);
	SEG7_LUT	u1	(oSEG1,iDIG[7:4]);
	SEG7_LUT	u2	(oSEG2,iDIG[11:8]);

endmodule