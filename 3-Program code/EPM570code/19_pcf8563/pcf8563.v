

module pcf8563(sysclk,reset,sda,scl,dig_data,seg_data);

input sysclk,reset;
inout sda,scl;
output[3:0] dig_data;
output[7:0] seg_data;

reg sda,scl;
reg[7:0] seg_data;
reg[3:0] dig_data;

reg clock,shift_clk;
reg[3:0] code_led ;
reg[8:1] reg_led_second,reg_led_minute;
reg[5:0] current_state;


//╢и╥х╫┤╠м╗·╡─╕ў╫╙╫┤╠мг╗
parameter prepare=0;
parameter start=1;
parameter transmit_slave_address=2;
parameter check_ack1=3;
parameter transmit_sub_address=4;
parameter check_ack2=5;
parameter transmit_data=6;
parameter check_ack3=7;
parameter transmit_data1=8;
parameter transmit_data2=9;
parameter check_ack4=10;
parameter check_ack44=11;
parameter start1=12;
parameter start2=13;
parameter transmit_slave_address1=14;
parameter transmit_slave_address2=15;
parameter transmit_sub_address1=16;
parameter check_ack5=17;
parameter check_ack6=18;
parameter check_ack7=19;
parameter read_data1=20;
parameter stop=21;

//╢и╥х╨┼║┼г╗
reg[8:1] slave_address1=8'b10100010,
         sub_address1=8'b00000000,
         data1=8'b00000000,
         slave_address2=8'b10100011,
         sub_address2=8'b00000010;
reg[1:0] cnt;
reg[3:0] cnt1 = 8;
reg[5:0] count1;
reg[13:0] count;
reg[13:0] cnt2;
reg[1:0] cnt3;

always@(posedge sysclk)  //╜°│╠1гм╖╓╞╡╡├╡╜f╬к4khz╡─╩▒╓╙╨┼║┼
begin
   if (reset==0) count<=0;
   else 
       begin
       count<=count+1;
       if (count<6500)  clock<=1;
       else if (count<12500) clock<=0;           
       else count<=0;            //frequency:4kHz 
       end
end 

always@(posedge clock) //╜°│╠2гм╫┤╠м╗·╡─╫к╗╗
begin
if (reset==0)     
    begin 
	count1<=0;
	cnt<=0;
	cnt1<=8;
	sda<=1;
	scl<=1;
	slave_address1<=8'b10100010;
	slave_address2<=8'b10100011;
	sub_address1<=8'b00000000; 
	sub_address2<=8'b00000010;
	current_state<=prepare;
	data1<=8'b00000000;  
	reg_led_minute<=8'b00000000;
	reg_led_second<=8'b00000000;
	end
else
	begin
    case(current_state)
	prepare: begin              //╫╝▒╕╫┤╠мгм╡╚╕ў╕Ў╞ў╝■╕┤╬╗
			 cnt<=cnt+1;       
             if (cnt==2) 
             begin 
             cnt<=0;
             current_state<=start;
             end
             else current_state<=prepare;
			 end
	start:  begin
            count1=count1+1;          //╞Ё╩╝╨┼║┼▓·╔·╫┤╠м
			case (count1)
			 1 :sda<=1;
			 2 :scl<=1;
			 3 :sda<=0;
			 4 :scl<=0;
			 5 :begin count1=0;current_state<=transmit_slave_address; end
			 default;
			endcase
			end	
	transmit_slave_address:             //╖в╦═╞ў╝■┤╙╡╪╓╖
             begin
             count1=count1+1;
             case (count1)
			 1 :sda<=slave_address1[cnt1]; //FROM 8BIT TO 1BIT slave_address1:="10100010";
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack1;
                 end
                 else current_state<=transmit_slave_address;
				end
			 default;
			 endcase
			 end
			 
	check_ack1:  begin              //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin count1=0;current_state<=transmit_sub_address; end
			 default;
			endcase
			end     
			
	transmit_sub_address:          //╖в╦═╞ў╝■╫╙╡╪╓╖
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=sub_address1[cnt1];
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack2;
                 end
                 else current_state<=transmit_sub_address;
				end
			 default;
			 endcase
			 end                      		 

 	check_ack2:  begin            //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin count1=0;current_state<=transmit_data; end
			 default;
			endcase
			end   
			
	transmit_data:        //╖в╦═╩¤╛▌
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=data1[cnt1];
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack3;
                 end
                 else current_state<=transmit_data;
				end
			 default;
			 endcase
			 end    
			 
 	check_ack3:  begin                //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin count1=0;current_state<=transmit_data1; end
			 default;
			endcase
			end   
			
	transmit_data1:            //╖в╦═╩¤╛▌
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=data1[cnt1];
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack4;
                 end
                 else current_state<=transmit_data1;
				end
			 default;
			 endcase
			 end    
			 
 	check_ack4:  begin            //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin count1=0;current_state<=transmit_data2; end
			 default;
			endcase
			end 
			
	transmit_data2:            //╖в╦═╩¤╛▌
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=data1[cnt1];
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack44;
                 end
                 else current_state<=transmit_data2;
				end
			 default;
			 endcase
			 end    
			 
 	check_ack44:  begin         //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 2 :scl<=1;
			 3 :scl<=0;
			 4 :begin count1=0;current_state<=start1; end
			 default;
			endcase
			end  
			
	start1:  begin           //╞Ё╩╝╨┼║┼▓·╔·╫┤╠м
            count1=count1+1;
			case (count1)
			 1 :sda<=1;
			 3 :scl<=1;
			 5 :sda<=0;
			 7 :scl<=0;
			 9 :begin count1=0;current_state<=transmit_slave_address1; end
			 default;
			endcase
			end
						
   transmit_slave_address1:   //╖в╦═╞ў╝■┤╙╡╪╓╖
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=slave_address1[cnt1];
			 3 :scl<=1;
			 6 :scl<=0;
			 8 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack5;
                 end
                 else current_state<=transmit_slave_address1;
				end
			 default;
			 endcase
			 end   
			  
 	check_ack5:  begin    //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 3 :sda<=0;
			 6 :scl<=1;
			 8 :scl<=0;
			 10 :begin count1=0;current_state<=transmit_sub_address1; end
			 default;
			endcase
			end  
				
    transmit_sub_address1:  //╖в╦═╞ў╝■╫╙╡╪╓╖
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=sub_address2[cnt1];
			 3 :scl<=1;
			 6 :scl<=0;
			 9 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack6;
                 end
                 else current_state<=transmit_sub_address1;
				end
			 default;
			 endcase
			 end   
			  
 	check_ack6:  begin  //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 3 :sda<=0;
			 6 :scl<=1;
			 8 :scl<=0;
			 10 :begin count1=0;current_state<=start2; end
			 default;
			endcase
			end  

	start2:  begin  //╓╪╨┬╞Ё╩╝╨┼║┼▓·╔·╫┤╠м
            count1=count1+1;
			case (count1)
			 1 :sda<=1;
			 3 :scl<=1;
			 6 :sda<=0;
			 8 :scl<=0;
			 10 :begin count1=0;current_state<=transmit_slave_address2; end
			 default;
			endcase
			end   

    transmit_slave_address2:  //╖в╦═╞ў╝■┤╙╡╪╓╖
			begin
            count1=count1+1;
			case (count1)
			 1 :sda<=slave_address2[cnt1];
			 3 :scl<=1;
			 6 :scl<=0;
			 8 :begin 
				 count1=0;
				 cnt1=cnt1-1; 
				 if (cnt1 ==0) 
				 begin
				 cnt1=8;
                 current_state<=check_ack7;
                 end
                 else current_state<=transmit_slave_address2;
				end
			 default;
			 endcase
			 end   
			 
 	check_ack7:  begin               //▓щ╤п╙ж┤Ё╨┼║┼
            count1=count1+1;
			case (count1)
			 3 :sda<=0;
			 6 :scl<=1;
			 8 :scl<=0;
			 10 :begin count1=0;current_state<=read_data1; end
			 default;
			endcase
			end  
 
  	read_data1:  begin                 //╢┴▓┘╫ў
            count1=count1+1;
			case (count1)
			 1 :sda<=1'bz;
			 4 :scl<=1;
			 8 :reg_led_second[cnt1]<=sda;
			 10 :scl<=0;
			 12 :
				begin 
				cnt1=cnt1-1;
				count1=0;
				if (cnt1==0) 
					begin
					cnt1=8; 
					current_state<=stop;
					end
				else current_state<=read_data1;
				end
			 default;
			endcase
			end 
			 
 	stop :  begin          //▓·╔·═г╓╣╨┼║┼
            count1=count1+1;
			case (count1)
			 1 :sda<=0;
			 3 :scl<=1;
			 10 :sda<=1;
			 15 :begin count1=0;current_state<=start1; end
			 default;
			endcase
			end  			
	                        		 
	endcase
	end
end   	                 		 

always@(posedge sysclk)         //╢п╠м╔и├ш─г┐щ
begin
   if (reset==0) cnt2<=0;
   else 
       begin
       cnt2<=cnt2+1;
       if (cnt2<10000)  shift_clk<=1;
       else if (cnt2<20000) shift_clk<=0;                 
       else cnt2<=0;
       end
end 
  
  
  
always@(posedge shift_clk)
begin
cnt3<=cnt3+1;
case (cnt3)
0: begin dig_data<=8'b11111110;code_led<={1'b0,reg_led_minute[7:5]}; end
1: begin dig_data<=8'b11111101;code_led<=reg_led_minute[4:1]; end
2: begin dig_data<=8'b11111011;code_led<={1'b0,reg_led_second[7:5]}; end
3: begin dig_data<=8'b11110111;code_led<=reg_led_second[4:1]; end
default; 
endcase
end    


always@(code_led) //╜л╜╙╩▄╡─╩¤╛▌╙├╩¤┬ы╣▄╧╘╩╛│Ў└┤
begin
      case (code_led)
		0:seg_data=8'b11000000;
		1:seg_data=8'b11111001;
		2:seg_data=8'b10100100;
		3:seg_data=8'b10110000;
		4:seg_data=8'b10011001;
		5:seg_data=8'b10010010;
		6:seg_data=8'b10000010;
		7:seg_data=8'b11111000;
		8:seg_data=8'b10000000;
		9:seg_data=8'b10010000;
		default:
			seg_data=8'b11111111;
	 endcase
end	

endmodule