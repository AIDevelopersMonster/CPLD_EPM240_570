`timescale 1ns / 1ps

//A Single line comment in Verilog starts with 
// Multiline comments start with /* and end with */

/*
  Module     : ps2_key.v
  Created By : kontakts.ru
  Create on  : 20-11-2025
  Board      : EPM570 CPLD Development Board

  Description:
    Верхний модуль проекта PS/2 → UART.
    Принимает скан-коды PS/2 клавиатуры (ps2k_clk, ps2k_data),
    декодирует их в модуле ps2scan,
    формирует скорость передачи в speed_select,
    и отправляет байты по UART через my_uart_tx.

    Использование:
      — Подключите PS/2 клавиатуру к плате.
      — Линию rs232_tx подключите к USB-UART преобразователю.
      — Откройте терминал (9600 бод 8N1 или выбранная скорость).
      — При нажатии клавиш будут выводиться PS/2 scan-коды.

    Репозиторий проекта:
      https://github.com/AIDevelopersMonster/CPLD_EPM240_570

    Плейлист FPGA / CPLD (YouTube):
      https://www.youtube.com/playlist?list=PLVoFIRfTAAI7-d_Yk6bNVnj4atUdMxvT5
*/

module ps2_key(
    input  clk,        // Тактовый сигнал платы (обычно 50 МГц)
    input  rst_n,      // Асинхронный сброс (активный низкий уровень)
    input  ps2k_clk,   // Линия тактирования PS/2 клавиатуры
    input  ps2k_data,  // Линия данных PS/2 клавиатуры
    output rs232_tx    // Линия передачи UART (RS232 / TTL-UART)
);

// ----------------------
// Внутренние сигналы
// ----------------------

// Принятый байт от клавиатуры (скан-код PS/2)
wire [7:0] ps2_byte;

// Флаг "данные готовы": высокий уровень, когда принят очередной байт
wire ps2_state;

// Сигнал запуска генерации тактовой частоты UART
wire bps_start;

// Тактовый сигнал скорости UART (baud rate)
wire clk_bps;

// ----------------------
// Модуль приёма PS/2
// ----------------------
ps2scan ps2scan_inst(
    .clk       (clk),
    .rst_n     (rst_n),
    .ps2k_clk  (ps2k_clk),
    .ps2k_data (ps2k_data),
    .ps2_byte  (ps2_byte),
    .ps2_state (ps2_state)
);

// ----------------------
// Модуль генерации скорости UART
// ----------------------
speed_select speed_select_inst(
    .clk       (clk),
    .rst_n     (rst_n),
    .bps_start (bps_start),
    .clk_bps   (clk_bps)
);

// ----------------------
// Модуль передачи UART
// ----------------------
my_uart_tx my_uart_tx_inst(
    .clk       (clk),
    .rst_n     (rst_n),
    .clk_bps   (clk_bps),
    .rx_data   (ps2_byte),
    .rx_int    (ps2_state),
    .rs232_tx  (rs232_tx),
    .bps_start (bps_start)
);

endmodule
