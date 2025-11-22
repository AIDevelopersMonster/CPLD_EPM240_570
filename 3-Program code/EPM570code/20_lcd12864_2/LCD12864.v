module LCD12864 (
    input clk,         // 50 МГц от CPLD/FPGA
    output [7:0] dat,  // 8-битная шина данных
    output rs,         // 0 = команда, 1 = данные
    output rw,         // 0 = запись в LCD
    output en          // строб записи
);

// =========================
// ВНУТРЕННИЕ РЕГИСТРЫ
// =========================
reg [7:0] dat_r;
reg rs_r;
reg en_r;

assign dat = dat_r;
assign rs  = rs_r;
assign rw  = 1'b0;     // всегда запись
assign en  = en_r;

// Делитель частоты для формирования разрешающего сигнала EN
reg [15:0] cnt;
reg clk_div;

always @(posedge clk) begin
    cnt <= cnt + 1;
    if (cnt == 16'h0FFF) begin
        cnt <= 0;
        clk_div <= ~clk_div;
    end
end

// =========================
// СОСТОЯНИЯ FSM
// =========================
reg [7:0] state;

localparam S_INIT0 = 0,
           S_INIT1 = 1,
           S_INIT2 = 2,
           S_INIT3 = 3,

           S_SET_LINE2 = 4,

           S_PRINT0 = 10,
           S_PRINT1 = 11,
           S_PRINT2 = 12,
           S_PRINT3 = 13,
           S_PRINT4 = 14,
           S_PRINT5 = 15,
           S_PRINT6 = 16,
           S_PRINT7 = 17,

           S_PRINT10 = 20,
           S_PRINT11 = 21,
           S_PRINT12 = 22,
           S_PRINT13 = 23,
           S_PRINT14 = 24,
           S_PRINT15 = 25,
           S_PRINT16 = 26,
           S_PRINT17 = 27,

           S_END = 255;


// =========================
// ОСНОВНОЙ FSM
// =========================
always @(posedge clk_div) begin
    case(state)

    // ------------------------
    // ИНИЦИАЛИЗАЦИЯ LCD12864
    // ------------------------
    S_INIT0: begin
        rs_r  <= 0;
        dat_r <= 8'h30;     // 8-битный режим
        en_r  <= 1;
        state <= S_INIT1;
    end

    S_INIT1: begin
        rs_r  <= 0;
        dat_r <= 8'h0C;     // дисплей включён, курсор выкл
        en_r  <= 1;
        state <= S_INIT2;
    end

    S_INIT2: begin
        rs_r  <= 0;
        dat_r <= 8'h06;     // автопереход вправо
        en_r  <= 1;
        state <= S_INIT3;
    end

    S_INIT3: begin
        rs_r  <= 0;
        dat_r <= 8'h01;     // очистка экрана
        en_r  <= 1;
        state <= S_PRINT0;
    end


    // ------------------------
    // ПЕЧАТЬ СТРОКА 1 — «СТАРТ FPGA»
    // Псевдо-ASCII, чтобы LCD отобразил похожие буквы
    // ------------------------
    S_PRINT0: begin rs_r<=1; dat_r<="S"; state<=S_PRINT1; end // С
    S_PRINT1: begin rs_r<=1; dat_r<="T"; state<=S_PRINT2; end // Т
    S_PRINT2: begin rs_r<=1; dat_r<="A"; state<=S_PRINT3; end // А
    S_PRINT3: begin rs_r<=1; dat_r<="R"; state<=S_PRINT4; end // Р
    S_PRINT4: begin rs_r<=1; dat_r<="T"; state<=S_PRINT5; end // Т

    S_PRINT5: begin rs_r<=1; dat_r<=" "; state<=S_PRINT6; end
    S_PRINT6: begin rs_r<=1; dat_r<="F"; state<=S_PRINT7; end
    S_PRINT7: begin rs_r<=1; dat_r<="P"; state<=S_PRINT10; end
    S_PRINT10:begin rs_r<=1; dat_r<="G"; state<=S_SET_LINE2; end
    S_SET_LINE2: begin
        rs_r  <= 0;
        dat_r <= 8'h90;     // адрес второй строки
        state <= S_PRINT11;
    end

    // ------------------------
    // ПЕЧАТЬ СТРОКА 2 — «ПРИВЕТ 12864»
    // ------------------------
    S_PRINT11: begin rs_r<=1; dat_r<="P"; state<=S_PRINT12; end // П
    S_PRINT12: begin rs_r<=1; dat_r<="R"; state<=S_PRINT13; end // Р
    S_PRINT13: begin rs_r<=1; dat_r<="E"; state<=S_PRINT14; end // Е
    S_PRINT14: begin rs_r<=1; dat_r<="B"; state<=S_PRINT15; end // В
    S_PRINT15: begin rs_r<=1; dat_r<="E"; state<=S_PRINT16; end // Е
    S_PRINT16: begin rs_r<=1; dat_r<="T"; state<=S_PRINT17; end // Т

    S_PRINT17: begin rs_r<=1; dat_r<=" "; state<=S_PRINT15+10; end
    S_PRINT15+10: begin rs_r<=1; dat_r<="1"; state<=S_PRINT15+11; end
    S_PRINT15+11: begin rs_r<=1; dat_r<="2"; state<=S_PRINT15+12; end
    S_PRINT15+12: begin rs_r<=1; dat_r<="8"; state<=S_PRINT15+13; end
    S_PRINT15+13: begin rs_r<=1; dat_r<="6"; state<=S_PRINT15+14; end
    S_PRINT15+14: begin rs_r<=1; dat_r<="4"; state<=S_END; end

    // ------------------------
    // КОНЕЦ FSM
    // ------------------------
    S_END: begin
        en_r <= 0;
        state <= S_END;
    end

    default: state <= S_INIT0;
    endcase
end

endmodule
