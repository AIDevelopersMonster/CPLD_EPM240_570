`timescale 1ns / 1ps

//A Single line comment in Verilog starts with 
// Multiline comments start with /* and end with */

/*
  Module     : my_uart_tx.v
  Created By : kontakts.ru
  Create on  : 20-11-2025
  Board      : EPM240 / EPM570 CPLD Development Board

  Description:
    UART-передатчик (TX) для отправки одного байта данных.
    Принимает байт rx_data и импульс rx_int (флаг "данные готовы"),
    формирует стартовый бит, 8 бит данных и стоповый бит
    и выдаёт всё это в линию rs232_tx с использованием такта clk_bps.

    Логика:
      – pos_rx_int фиксирует фронт сигнала rx_int.
      – При фронте rx_int данные копируются в tx_data.
      – Сигнал bps_start запускает генерацию clk_bps в модуле speed_select.
      – По каждому импульсу clk_bps счётчик num выбирает,
        какой бит отправлять (старт, data[0..7], стоп).

    Репозиторий проекта:
      https://github.com/AIDevelopersMonster/CPLD_EPM240_570

    Плейлист FPGA / CPLD (YouTube):
      https://www.youtube.com/playlist?list=PLVoFIRfTAAI7-d_Yk6bNVnj4atUdMxvT5
*/

module my_uart_tx(clk,rst_n,clk_bps,rx_data,rx_int,rs232_tx,bps_start);

// ---------------------------------------------------------
// Входы/выходы модуля 
// ---------------------------------------------------------

input clk;           // Тактовый сигнал 50 МГц (основной clock проекта)
input rst_n;         // Асинхронный сброс, активный низкий уровень (0 = reset)
input clk_bps;       // Тактовый импульс скорости UART (baud rate), генерируется speed_select
input [7:0] rx_data; // Входные данные (байт), который нужно отправить через UART
input rx_int;        // Флаг "данные готовы": 1 = можно начинать передачу байта
output rs232_tx;     // Выход UART TX — последовательные данные в линию RS232/TTL
output bps_start;    // Стартовый импульс для speed_select, двигает генерацию clk_bps

//---------------------------------------------------------

//---------------------------------------------------------
// Захват фронта rx_int (синхронизация и подавление дребезга)
//---------------------------------------------------------
reg rx_int0, rx_int1, rx_int2;  // Регистрируем rx_int в три такта для выделения фронта
wire pos_rx_int;                // Флаг фронта (положительного перепада) rx_int

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        rx_int0 <= 1'b0;
        rx_int1 <= 1'b0;
        rx_int2 <= 1'b0;
    end
    else begin
        rx_int0 <= rx_int;
        rx_int1 <= rx_int0;
        rx_int2 <= rx_int1;
    end
end

// pos_rx_int становится '1' на один такт при фронте rx_int
assign pos_rx_int = rx_int1 & ~rx_int2;

//---------------------------------------------------------
// Регистр данных для передачи
//---------------------------------------------------------
reg [7:0] tx_data;  // В этом регистре хранится байт, который отправляем

//---------------------------------------------------------
// Управление запуском передачи и формированием bps_start
//---------------------------------------------------------
reg bps_start_r;   // Внутренний регистр сигнала bps_start
reg tx_en;         // Флаг "передача активна"
reg [3:0] num;     // Счётчик бит (0..11)

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bps_start_r <= 1'bz;    // При сбросе — в высокоомное состояние (как в исходнике)
        tx_en       <= 1'b0;    // Передатчик выключен
        tx_data     <= 8'd0;    // Данные обнуляем
    end
    else if (pos_rx_int) begin
        // При фронте rx_int считаем, что есть новый байт для отправки
        bps_start_r <= 1'b1;      // Запрос на запуск генерации clk_bps
        tx_data     <= rx_data;   // Копируем входные данные в регистр передачи
        tx_en       <= 1'b1;      // Включаем режим передачи
    end
    else if (num == 4'd11) begin
        // Когда передача завершена (все биты пройдены), отключаем запуск
        bps_start_r <= 1'b0;
        tx_en       <= 1'b0;
    end
end

assign bps_start = bps_start_r;

//---------------------------------------------------------
// Формирование выходного сигнала UART (rs232_tx)
// Структура кадра: стартовый бит (0), 8 бит данных, стоповый бит (1)
//---------------------------------------------------------
reg rs232_tx_r;    // Регистровый выход TX

always @ (posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        num        <= 4'd0;
        rs232_tx_r <= 1'b1;   // Линия UART в пассивном состоянии — лог.1
    end
    else if (tx_en) begin
        if (clk_bps) begin    // На каждый импульс clk_bps продвигаем отправку
            num <= num + 1'b1;
            case (num)
                4'd0: rs232_tx_r <= 1'b0;        // Стартовый бит (0)
                4'd1: rs232_tx_r <= tx_data[0];  // Бит 0
                4'd2: rs232_tx_r <= tx_data[1];  // Бит 1
                4'd3: rs232_tx_r <= tx_data[2];  // Бит 2
                4'd4: rs232_tx_r <= tx_data[3];  // Бит 3
                4'd5: rs232_tx_r <= tx_data[4];  // Бит 4
                4'd6: rs232_tx_r <= tx_data[5];  // Бит 5
                4'd7: rs232_tx_r <= tx_data[6];  // Бит 6
                4'd8: rs232_tx_r <= tx_data[7];  // Бит 7
                4'd9: rs232_tx_r <= 1'b1;        // Стоповый бит (1)
                default: rs232_tx_r <= 1'b1;     // Остальное время — линия в '1'
            endcase
        end
        else if (num == 4'd11) begin
            // После завершения передачи сбрасываем счётчик
            num <= 4'd0;
        end
    end
end

assign rs232_tx = rs232_tx_r;

endmodule
