`timescale 1ns / 1ps


module SevenSegmentDisplay(
	input 			       CLK,
	input       [3:0]	   DIGIT1, DIGIT2, DIGIT3, DIGIT4,
	input				   DOT_IN,
    output reg	[3:0]	   SEG_SELECT_OUT,
    output reg  [7:0]      HEX_OUT
);


	reg [2:0] SEG_SELECT_IN= 0;
	reg [3:0] BIN_IN = 0;
	reg [19:0] counter = 0;



		 //Multiplexing the BIN IN

	always@(posedge CLK)
	begin
		 if (SEG_SELECT_IN== 0)
			  begin
					if (counter == 200000)
						 begin
							  SEG_SELECT_IN= 1;
						 end
					else
						 begin
						 counter = counter + 1;
						 BIN_IN = DIGIT1;
						 end
			  end
		 else if (SEG_SELECT_IN== 1)
			  begin
					if (counter == 400000)
						 begin
							  SEG_SELECT_IN= 2;
						 end
					else
						 begin
							  counter = counter + 1;
							  BIN_IN = DIGIT2;
						 end
			  end
		 else if (SEG_SELECT_IN== 2)
			  begin
					if (counter == 600000)
						 begin
							  SEG_SELECT_IN= 3;
						 end
					else
						 begin
							  counter = counter + 1;
							  BIN_IN = DIGIT3;
						 end
			  end
		 else if (SEG_SELECT_IN== 3)
			  begin
					if (counter == 800000)
						 begin
							  SEG_SELECT_IN= 0;
							  counter = 0;
						 end 
					else
						 begin
							  counter = counter + 1;
							  BIN_IN = DIGIT4;
						 end
			  end 
	end


	always@(BIN_IN) begin
        case(BIN_IN)
            4'b0000:    HEX_OUT[6:0] <= 7'b1000000; // 0
            4'b0001:    HEX_OUT[6:0] <= 7'b1111001; // 1
            4'b0010:    HEX_OUT[6:0] <= 7'b0100100; // 2
            4'b0011:    HEX_OUT[6:0] <= 7'b0110000; // 3
            
            4'b0100:    HEX_OUT[6:0] <= 7'b0011001; // 4
            4'b0101:    HEX_OUT[6:0] <= 7'b0010010; // 5
            4'b0110:    HEX_OUT[6:0] <= 7'b0000010; // 6
            4'b0111:    HEX_OUT[6:0] <= 7'b1111000; // 7
            
            4'b1000:    HEX_OUT[6:0] <= 7'b0000000; // 8
            4'b1001:    HEX_OUT[6:0] <= 7'b0011000; // 9
            4'b1010:    HEX_OUT[6:0] <= 7'b0001000; // A
            4'b1011:    HEX_OUT[6:0] <= 7'b0000011; // B
            
            4'b1100:    HEX_OUT[6:0] <= 7'b1000110; // C
            4'b1101:    HEX_OUT[6:0] <= 7'b0100001; // D
            4'b1110:    HEX_OUT[6:0] <= 7'b0000110; // E
            4'b1111:    HEX_OUT[6:0] <= 7'b0001110; // F
            
            default:    HEX_OUT[6:0] <= 7'b1111111; // off
        endcase
    end
    
    always@(DOT_IN) begin
        HEX_OUT[7] <= ~DOT_IN;
    end
    
    always@(SEG_SELECT_IN) begin
        case(SEG_SELECT_IN)
            2'b00:        SEG_SELECT_OUT <= 4'b1110; // rightmost
            2'b01:        SEG_SELECT_OUT <= 4'b1101;
            2'b10:        SEG_SELECT_OUT <= 4'b1011;
            2'b11:        SEG_SELECT_OUT <= 4'b0111; // leftmost
            default:    SEG_SELECT_OUT <= 4'b1111; // all off
        endcase
    end
endmodule
