/*****************************
**�������ڣ�   2011.06.01**				version 1.0
 				
*******************************/

module led1(led);
	output[7:0] led;
	
	//assign led=8'b11111111;  //
	//assign led=8'b00000000;  //
	//assign led=8'b01010101;  //
   //assign led=8'b00000001;  //                    
	//assign led=8'b11111111;	//					  
	assign led[0]= 1'b1;       //
	assign led[1]= 1'b0; 
	assign led[2]= 1'b1; 
	assign led[3]= 1'b0; 
	assign led[4]= 1'b1; 
	assign led[5]= 1'b0; 
	assign led[6]= 1'b1; 
	assign led[7]= 1'b0; 
	
endmodule


/*

#--------------------LED----------------------#
set_location_assignment	PIN_67	    -to	led[1]
set_location_assignment	PIN_66	    -to	led[2]
set_location_assignment	PIN_61	    -to	led[3]
set_location_assignment	PIN_58	    -to	led[4]
set_location_assignment	PIN_57	    -to	led[5]
set_location_assignment	PIN_56	    -to	led[6]
set_location_assignment	PIN_55	    -to	led[7]
set_location_assignment	PIN_54	    -to	led[8]


*/


