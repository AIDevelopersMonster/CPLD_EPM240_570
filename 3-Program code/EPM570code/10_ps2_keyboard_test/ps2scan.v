`timescale 1ns / 1ps

module ps2scan(clk,rst_n,ps2k_clk,ps2k_data,ps2_byte,ps2_state);

// Входы модуля:
//   clk      – системная частота (50 МГц)
//   rst_n    – общий сброс (активный ноль)
//   ps2k_clk – тактовый сигнал интерфейса PS/2 от клавиатуры
//   ps2k_data– линия данных интерфейса PS/2
// Выходы:
//   ps2_byte  – принятый байт (ASCII-код буквы A–Z)
//   ps2_state – флаг «новый символ от клавиатуры»
input clk;		// системная частота 50 МГц
input rst_n;	// сигнал сброса, активный низкий уровень
input ps2k_clk;	// тактовый сигнал от PS/2 клавиатуры
input ps2k_data;		// линия данных PS/2
output[7:0] ps2_byte;	// 1 байт данных, результат обработки (ASCII)
output ps2_state;		// 1 — есть новое нажатие клавиши

//------------------------------------------
// Синхронизация ps2k_clk и выделение отрицательного фронта
//------------------------------------------
reg ps2k_clk_r0,ps2k_clk_r1,ps2k_clk_r2;	// регистры для фиксации состояния ps2k_clk

//wire pos_ps2k_clk; 	// положительный фронт ps2k_clk (не используется)
wire neg_ps2k_clk;	// отрицательный фронт ps2k_clk

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
			ps2k_clk_r0 <= 1'b0;
			ps2k_clk_r1 <= 1'b0;
			ps2k_clk_r2 <= 1'b0;
		end
	else begin								// синхронизация ps2k_clk в такт clk
			ps2k_clk_r0 <= ps2k_clk;
			ps2k_clk_r1 <= ps2k_clk_r0;
			ps2k_clk_r2 <= ps2k_clk_r1;
		end
end

assign neg_ps2k_clk = ~ps2k_clk_r1 & ps2k_clk_r2;	// формирование импульса на отрицательном фронте ps2k_clk

//------------------------------------------
// Приём кадра PS/2: старт + 8 бит данных + бит чётности + стоп
//------------------------------------------
reg[7:0] ps2_byte_r;		// здесь будет храниться принятый scan-код PS/2 (1 байт)
reg[7:0] temp_data;			// временный регистр для текущего принимаемого байта
reg[3:0] num;				// счётчик бит в кадре PS/2

always @ (posedge clk or negedge rst_n) begin
	if(!rst_n) begin
			num <= 4'd0;
			temp_data <= 8'd0;
		end
	else if(neg_ps2k_clk) begin	// срабатываем на каждый отрицательный фронт ps2k_clk
			case (num)
				4'd0:	num <= num+1'b1;               // стартовый бит (игнорируем)
				4'd1:	begin
							num <= num+1'b1;
							temp_data[0] <= ps2k_data;	// bit0 (младший бит данных)
						end
				4'd2:	begin
							num <= num+1'b1;
							temp_data[1] <= ps2k_data;	// bit1
						end
				4'd3:	begin
							num <= num+1'b1;
							temp_data[2] <= ps2k_data;	// bit2
						end
				4'd4:	begin
							num <= num+1'b1;
							temp_data[3] <= ps2k_data;	// bit3
						end
				4'd5:	begin
							num <= num+1'b1;
							temp_data[4] <= ps2k_data;	// bit4
						end
				4'd6:	begin
							num <= num+1'b1;
							temp_data[5] <= ps2k_data;	// bit5
						end
				4'd7:	begin
							num <= num+1'b1;
							temp_data[6] <= ps2k_data;	// bit6
						end
				4'd8:	begin
							num <= num+1'b1;
							temp_data[7] <= ps2k_data;	// bit7 (старший бит данных)
						end
				4'd9:	begin
							num <= num+1'b1;	// бит чётности — контролируется, но здесь не используется
						end
				4'd10: begin
							num <= 4'd0;	// стоп-бит, кадр завершён, счётчик обнуляем
						end
				default: ;
				endcase
		end	
end

//------------------------------------------
// Обработка спецкода F0 (отпускание клавиши) и формирование флага состояния
//------------------------------------------
reg key_f0;		// флаг: 1 — только что пришёл код 8'hf0 (отпускание клавиши)
reg ps2_state_r;	// внутренний флаг: 1 — есть новое нажатие клавиши

always @ (posedge clk or negedge rst_n) begin	// логика обработки только для 1-байтных кодов
	if(!rst_n) begin
			key_f0 <= 1'b0;
			ps2_state_r <= 1'b0;
		end
	else if(num==4'd10) begin	// сюда попадаем после приёма полного байта в temp_data
			if(temp_data == 8'hf0) key_f0 <= 1'b1;   // код 0xF0 — отпускание клавиши
			else begin
					if(!key_f0) begin	// если до этого не было F0 — это нажатие
							ps2_state_r <= 1'b1;           // есть новый символ
							ps2_byte_r <= temp_data;	// сохраняем принятый scan-код
						end
					else begin
							ps2_state_r <= 1'b0;           // после F0 — отпускание, флаг сбрасываем
							key_f0 <= 1'b0;                // сбрасываем признак F0
						end
				end
		end
end

//------------------------------------------
// Таблица соответствия: scan-код PS/2 → ASCII (только буквы A–Z)
//------------------------------------------
reg[7:0] ps2_asci;	// соответствующий ASCII-код символа

always @ (ps2_byte_r) begin
	case (ps2_byte_r)		// переводим scan-код в ASCII, здесь описаны только буквы
		8'h15: ps2_asci <= 8'h51;	// Q
		8'h1d: ps2_asci <= 8'h57;	// W
		8'h24: ps2_asci <= 8'h45;	// E
		8'h2d: ps2_asci <= 8'h52;	// R
		8'h2c: ps2_asci <= 8'h54;	// T
		8'h35: ps2_asci <= 8'h59;	// Y
		8'h3c: ps2_asci <= 8'h55;	// U
		8'h43: ps2_asci <= 8'h49;	// I
		8'h44: ps2_asci <= 8'h4f;	// O
		8'h4d: ps2_asci <= 8'h50;	// P				  	
		8'h1c: ps2_asci <= 8'h41;	// A
		8'h1b: ps2_asci <= 8'h53;	// S
		8'h23: ps2_asci <= 8'h44;	// D
		8'h2b: ps2_asci <= 8'h46;	// F
		8'h34: ps2_asci <= 8'h47;	// G
		8'h33: ps2_asci <= 8'h48;	// H
		8'h3b: ps2_asci <= 8'h4a;	// J
		8'h42: ps2_asci <= 8'h4b;	// K
		8'h4b: ps2_asci <= 8'h4c;	// L
		8'h1a: ps2_asci <= 8'h5a;	// Z
		8'h22: ps2_asci <= 8'h58;	// X
		8'h21: ps2_asci <= 8'h43;	// C
		8'h2a: ps2_asci <= 8'h56;	// V
		8'h32: ps2_asci <= 8'h42;	// B
		8'h31: ps2_asci <= 8'h4e;	// N
		8'h3a: ps2_asci <= 8'h4d;	// M
		default: ;                  // другие коды здесь не обрабатываются
		endcase
end

// На выход отдаем ASCII-код символа и флаг «есть новый символ»
assign ps2_byte = ps2_asci;	 
assign ps2_state = ps2_state_r;

endmodule
