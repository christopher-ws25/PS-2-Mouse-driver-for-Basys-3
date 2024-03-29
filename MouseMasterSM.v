`timescale 1ns / 1ps

module MouseMasterSM(
	input 			CLK,
	input 			RESET,
	//Transmitter Control
	output 			SEND_BYTE,
	output [7:0] 	BYTE_TO_SEND,
	input 			BYTE_SENT,
	//Receiver Control
	output 			READ_ENABLE,
	input [7:0] 	BYTE_READ,
	input [1:0] 	BYTE_ERROR_CODE,
	input 			BYTE_READY,
	//Data Registers
	output [7:0] 	MOUSE_DX,
	output [7:0] 	MOUSE_DY,
	output [7:0] 	MOUSE_STATUS,
	output 			SEND_INTERRUPT
);
	//////////////////////////////////////////////////////////////
	// Main state machine - There is a setup sequence
	//
	// 1) Send FF -- Reset command,
	// 2) Read FA -- Mouse Acknowledge,
	// 2) Read AA -- Self-Test Pass
	// 3) Read 00 -- Mouse ID
	// 4) Send F4 -- Start transmitting command,
	// 5) Read FA -- Mouse Acknowledge,
	//
	// If at any time this chain is broken, the SM will restart from
	// the beginning. Once it has finished the set-up sequence, the read enable flag
	// is raised.
	// The host is then ready to read mouse information 3 bytes at a time:
	// S1) Wait for first read, When it arrives, save it to Status. Goto S2.
	// S2) Wait for second read, When it arrives, save it to DX. Goto S3.
	// S3) Wait for third read, When it arrives, save it to DY. Goto S1.
	// Send interrupt.
	
	//State Control
	reg [3:0] 	Curr_State, Next_State;
	reg [23:0] 	Curr_Counter, Next_Counter;
	reg [25:0]	Curr_Timeout_Counter, Next_Timeout_Counter;

	//Transmitter Control
	reg 			Curr_SendByte, Next_SendByte;
	reg [7:0] 	Curr_ByteToSend, Next_ByteToSend;

	//Receiver Control
	reg 			Curr_ReadEnable, Next_ReadEnable;

	//Data Registers
	reg [7:0] 	Curr_Status, Next_Status;
	reg [7:0] 	Curr_Dx, Next_Dx;
	reg [7:0] 	Curr_Dy, Next_Dy;
	reg 			Curr_SendInterrupt, Next_SendInterrupt;

	//Sequential
	always@(posedge CLK)
		begin
			if(RESET)
				begin
					Curr_State 				<= 4'h0;
					Curr_Counter 			<= 0;
					Curr_SendByte 			<= 1'b0;
					Curr_ByteToSend 		<= 8'h00;
					Curr_ReadEnable 		<= 1'b0;
					Curr_Status 			<= 8'h00;
					Curr_Dx 					<= 8'h00;
					Curr_Dy 					<= 8'h00;
					Curr_SendInterrupt 	<= 1'b0;
					Curr_Timeout_Counter <= 0;
				end
			else 
				begin
					Curr_State 				<= Next_State;
					Curr_Counter 			<= Next_Counter;
					Curr_SendByte 			<= Next_SendByte;
					Curr_ByteToSend 		<= Next_ByteToSend;
					Curr_ReadEnable 		<= Next_ReadEnable;
					Curr_Status 			<= Next_Status;
					Curr_Dx 					<= Next_Dx;
					Curr_Dy 					<= Next_Dy;
					Curr_SendInterrupt 	<= Next_SendInterrupt;
					Curr_Timeout_Counter <= Next_Timeout_Counter;
				end
		end
	
	//Combinatorial
	always@* 
		begin
			Next_State 				= Curr_State;
			Next_Counter 			= Curr_Counter;
			Next_SendByte 			= 1'b0;
			Next_ByteToSend 		= Curr_ByteToSend;
			Next_ReadEnable 		= 1'b0;
			Next_Status 			= Curr_Status;
			Next_Dx 					= Curr_Dx;
			Next_Dy 					= Curr_Dy;
			Next_SendInterrupt 	= 1'b0;
			Next_Timeout_Counter = Curr_Timeout_Counter;
			
			case(Curr_State)
				//Initialise State - Wait here for 10ms before trying to initialise the mouse.
				0: 
					begin
						if(Curr_Counter == 5000000)
							begin // 1/100th sec at 50MHz clock
								Next_State 			= 1;
								Next_Counter 		= 0;
							end 
						else	
							Next_Counter 			= Curr_Counter + 1'b1;
					end
					//Start initialisation by sending FF
				1: 
					begin
						Next_State 					= 2;
						Next_SendByte 				= 1'b1;
						Next_ByteToSend 			= 8'hFF;
					end
				//Wait for confirmation of the byte being sent
				2: 
					begin
						if(BYTE_SENT)
							Next_State 				= 3;
					end
				//Wait for confirmation of a byte being received
				//If the byte is FA goto next state, else re-initialise.
				3: 
					begin
						if(BYTE_READY)
							begin
								if((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00))
									Next_State 		= 4;
								else
									Next_State 		= 0;
							end
						
						Next_ReadEnable 			= 1'b1;
					end
				//Wait for self-test pass confirmation
				//If the byte received is AA goto next state, else re-initialise
				4: 
					begin
						if(BYTE_READY) 
							begin
								if((BYTE_READ == 8'hAA) & (BYTE_ERROR_CODE == 2'b00))
									Next_State 		= 5;
								else
									Next_State 		= 0;
							end
							
						Next_ReadEnable 			= 1'b1;
					end
				//Wait for confirmation of a byte being received
				//If the byte is 00 goto next state (MOUSE ID) else re-initialise
				5: 
					begin
						if(BYTE_READY) 
							begin
								if((BYTE_READ == 8'h00) & (BYTE_ERROR_CODE == 2'b00))
									Next_State 		= 6;
								else
									Next_State 		= 0;
							end
						
						Next_ReadEnable = 1'b1;
					end
				//Send F4 - to start mouse transmit
				6: 
					begin
						Next_State 					= 7;
						Next_SendByte 				= 1'b1;
						Next_ByteToSend 			= 8'hF4;
					end
				//Wait for confirmation of the byte being sent
				7: if(BYTE_SENT) Next_State = 4'h8;
				//Wait for confirmation of a byte being received
				//If the byte is FA goto next state, else re-initialise
				8: 
					begin
						if(BYTE_READY) 
							begin
								if((BYTE_READ == 8'hFA) & (BYTE_ERROR_CODE == 2'b00))
									Next_State 		= 9;
								else
									Next_State 		= 0;
							end
						
						Next_ReadEnable 			= 1'b1;
					end
				///////////////////////////////////////////////////////////
				//At this point the SM has initialised the mouse.
				//Now we are constantly reading. If at any time
				//there is an error, we will re-initialise
				//the mouse - just in case.
				///////////////////////////////////////////////////////////
				//Wait for the confirmation of a byte being received.
				//This byte will be the first of three, the status byte.
				//If a byte arrives, but is corrupted, then we re-initialise
				

				9:
					begin
						if(BYTE_READY)
							begin
								if(BYTE_ERROR_CODE == 2'b00)
									begin
										Next_State 					= 10;
										Next_Status 				= BYTE_READ;
										Next_Timeout_Counter 	= 0;	
									end
								else
									Next_State 						= 0;					// actually reinit on corrupted byte
									Next_Timeout_Counter 		= 0;
							end
						else if(Curr_Timeout_Counter == 50000000)		// reset device every 1ms
							begin
								Next_Timeout_Counter 			= 0;			 
								Next_State							= 0;
							end
						else
							Next_Timeout_Counter = Curr_Timeout_Counter + 1;
						
						

						Next_ReadEnable 					= 1'b1;
					end
						
			//-------------------------------------------------------------------------------
            //Fill in this area
            //-------------------------------------------------------------------------------
				10:
					begin
						if(BYTE_READY)
							begin
								if(BYTE_ERROR_CODE == 2'b00)
									begin
										Next_State 			= 11;
										Next_Dx 				= BYTE_READ;
									end
								else
									Next_State 				= 0;
							end
							
						Next_ReadEnable 					= 1'b1;
					end
				//Wait for confirmation of a byte being received
				//This byte will be the third of three, the Dy byte.
				//-------------------------------------------------------------------------------
                //Fill in this area
                //-------------------------------------------------------------------------------
				11:
					begin
						if(BYTE_READY)
							begin
								if(BYTE_ERROR_CODE == 2'b00)
									begin
										Next_State 			= 12;
										Next_Dy 				= BYTE_READ;
									end
								else
									Next_State 				= 0;
							end
							
						Next_ReadEnable 					= 1'b1;
					end
				//Send Interrupt State
				12: begin
					Next_State 								= 9;
					Next_SendInterrupt 					= 1'b1;
				end
				//Default State
				default: begin
					Next_State 				= 4'h0;
					Next_Counter 			= 0;
					Next_SendByte 			= 1'b0;
					Next_ByteToSend 		= 8'hFF;
					Next_ReadEnable 		= 1'b0;
					Next_Status 			= 8'h00;
					Next_Dx 					= 8'h00;
					Next_Dy 					= 8'h00;
					Next_SendInterrupt 	= 1'b0;
				end
			endcase
		end
	
	///////////////////////////////////////////////////
	//Tie the SM signals to the IO
	//Transmitter
	assign SEND_BYTE 			= Curr_SendByte;
	assign BYTE_TO_SEND 		= Curr_ByteToSend;
	
	//Receiver
	assign READ_ENABLE 		= Curr_ReadEnable;
	
	//Output Mouse Data
	assign MOUSE_DX 			= Curr_Dx;
	assign MOUSE_DY 			= Curr_Dy;
	assign MOUSE_STATUS 		= Curr_Status;
	assign SEND_INTERRUPT 	= Curr_SendInterrupt;
endmodule
