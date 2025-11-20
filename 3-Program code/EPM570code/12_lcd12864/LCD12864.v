// ------------------------------------------------------------
//  Module     : LCD12864.v
//  Project    : FPGA Module for LCD12864 Display
//  Board      : EPM240 / EPM570 (и подобные, с тактовой частотой ~50 МГц)
//  Created By : kontakts.ru
//  Description: This module is designed to interface with an LCD12864 display.
//    На дисплее LCD12864
//    
//    Our FPGA
//    EDA NIOS II
//    SOPC
//    FPGA A 
//
//    Репозиторий проекта:
//      https://github.com/AIDevelopersMonster/CPLD_EPM240_570
//
//    Плейлист FPGA / CPLD (YouTube):
//      https://www.youtube.com/playlist?list=PLVoFIRfTAAI7-d_Yk6bNVnj4atUdMxvT5
//
//
// ------------------------------------------------------------

/*
  Дополнительное описание (на русском):

  Данный модуль управляет индикатором LCD12864 в текстовом режиме.
  На дисплей выводится текст:

      Our FPGA
      EDA NIOS II
      SOPC
      FPGA A

  Работа строится на конечном автомате (state machine), который:
    - сначала инициализирует LCD (последовательность команд),
    - затем по символу отправляет ASCII-коды букв,
    - задаёт адрес начала строки перед выводом соответствующей строки.
*/

module LCD12864 (clk, rs, rw, en,dat);  
input clk;                  // Входной тактовый сигнал (например, 50 МГц)
output [7:0] dat;           // 8-битная шина данных к LCD
output rs, rw, en;          // Управляющие сигналы к LCD: RS, RW, EN
//tri en;                   // Тристейт для EN (не используется в данной реализации)

// Внутренние регистры для управления LCD
reg e;                      // Дополнительный флаг для формирования сигнала EN
reg [7:0] dat;              // Регистр для данных, которые уходят на шину dat[7:0]
reg rs;                     // Регистр выбора типа передаваемой информации: 0 — команда, 1 — данные (ASCII)
reg [15:0] counter;         // Счетчик для деления частоты (формирование более медленного такта clkr)
reg [5:0] current,next;     // current — текущее состояние автомата, next — следующее состояние
reg clkr;                   // Замедленный тактовый сигнал для автомата состояний
reg [1:0] cnt;              // Счетчик повторов цикла (для состояния nul)

// Состояния инициализации LCD (последовательность команд)
parameter  set0 = 6'h0;     // Команда инициализации (функциональная установка)
parameter  set1 = 6'h1;     // Включение дисплея, курсора и т.п.
parameter  set2 = 6'h2;     // Режим ввода (сдвиг курсора)
parameter  set3 = 6'h3;     // Очистка дисплея

// Состояния вывода данных (символов)
parameter  set4 = 6'h4;     // Установка адреса начала второй строки
parameter  set5 = 6'h5;     // Установка адреса третьей строки
parameter  set6 = 6'h6;     // Установка адреса четвертой строки  

parameter  dat0  = 6'h7;    // Символы первой строки "Our FPGA"
parameter  dat1  = 6'h8; 
parameter  dat2  = 6'h9; 
parameter  dat3  = 6'hA; 
parameter  dat4  = 6'hB; 
parameter  dat5  = 6'hC;
parameter  dat6  = 6'hD; 
parameter  dat7  = 6'hE; 
parameter  dat8  = 6'hF; 
parameter  dat9  = 6'h10;

parameter  dat10 = 6'h12;   // Продолжение — вторая строка "EDA NIOS II"
parameter  dat11 = 6'h13; 
parameter  dat12 = 6'h14; 
parameter  dat13 = 6'h15; 
parameter  dat14 = 6'h16; 
parameter  dat15 = 6'h17;
parameter  dat16 = 6'h18; 
parameter  dat17 = 6'h19; 
parameter  dat18 = 6'h1A; 
parameter  dat19 = 6'h1B;   // Третья строка "SOPC"
parameter  dat20 = 6'h1C;
parameter  dat21 = 6'h1D; 
parameter  dat22 = 6'h1E; 
parameter  dat23 = 6'h1F;   // Четвёртая строка "FPGA"
parameter  dat24 = 6'h20; 
parameter  dat25 = 6'h21; 
parameter  dat26 = 6'h22;     

parameter  nul  = 6'hF1;    // Конечное состояние — удержание/повтор вывода

// Делитель частоты: на основе входного clk формируется более медленный clkr
always @(posedge clk)         
 begin 
  counter = counter + 1'b1;                // Инкремент счетчика
  if(counter == 16'h000f)                  // При достижении порога
    clkr = ~clkr;                          // инвертируем clkr — получаем более медленный сигнал
end 

// Основной автомат состояний, работающий на замедленном такте clkr
always @(posedge clkr) 
begin 
 current = next;                           // Переход в следующее состояние
  case(current) 
    // --- Блок инициализации LCD ---
    set0:   begin  
              rs  <= 0;                    // Режим команды
              dat <= 8'h30;                // Команда: функциональная установка (режим 8 бит и т.п.)
              next <= set1;                // Следующее состояние — set1
            end 

    set1:   begin  
              rs  <= 0;                    // Команда
              dat <= 8'h0c;                // Включение дисплея, без курсора
              next <= set2; 
            end 

    set2:   begin  
              rs  <= 0;                    // Команда
              dat <= 8'h06;                // Режим ввода: инкремент адреса, без сдвига дисплея
              next <= set3; 
            end 

    set3:   begin  
              rs  <= 0;                    // Команда
              dat <= 8'h01;                // Очистка дисплея
              next <= dat0;                // Переход к выводу первой строки
            end 

    // --- Первая строка: "Our FPGA" ---
    dat0:   begin  
              rs  <= 1;                    // Данные (ASCII)
              dat <= "O";                  // Символ 'O'
              next <= dat1; 
            end // ПФКѕµЪТ»РР

    dat1:   begin  
              rs  <= 1; 
              dat <= "u";                  // 'u'
              next <= dat2; 
            end 

    dat2:   begin  
              rs  <= 1; 
              dat <= "r";                  // 'r'
              next <= dat3; 
            end 

    dat3:   begin  
              rs  <= 1; 
              dat <= " ";                  // пробел
              next <= dat4; 
            end 

    dat4:   begin  
              rs  <= 1; 
              dat <= "F";                  // 'F'
              next <= dat5; 
            end 

    dat5:   begin  
              rs  <= 1; 
              dat <= "P";                  // 'P'
              next <= dat6; 
            end 

    dat6:   begin  
              rs  <= 1; 
              dat <= "G";                  // 'G'
              next <= dat7; 
            end 

    dat7:   begin  
              rs  <= 1; 
              dat <= "A";                  // 'A'
              next <= dat8; 
            end 

    dat8:   begin  
              rs  <= 1; 
              dat <= " ";                  // пробел (после "Our FPGA")
              next <= dat9; 
            end 

    dat9:   begin  
              rs  <= 1; 
              dat <= "E";                  // 'E'
              next <= dat10; 
            end 

    dat10:  begin  
              rs  <= 1; 
              dat <= "D";                  // 'D'
              next <= dat11; 
            end 

    dat11:  begin  
              rs  <= 1; 
              dat <= "A";                  // 'A' (заканчиваем "EDA")
              next <= set4;                // Переходим к установке адреса второй строки
            end 

    // --- Вторая строка: установка адреса и текст "NIOS II" ---
    set4:   begin  
              rs  <= 0; 
              dat <= 8'h90;                // Команда: установка адреса второй строки (зависит от контроллера)
              next <= dat12; 
            end // ПФКѕµЪ¶юРР

    dat12:  begin  
              rs  <= 1; 
              dat <= "N";                  // 'N'
              next <= dat13; 
            end 

    dat13:  begin  
              rs  <= 1; 
              dat <= "I";                  // 'I'
              next <= dat14; 
            end 

    dat14:  begin  
              rs  <= 1; 
              dat <= "O";                  // 'O'
              next <= dat15; 
            end 

    dat15:  begin  
              rs  <= 1; 
              dat <= "S";                  // 'S'
              next <= dat16; 
            end 

    dat16:  begin  
              rs  <= 1; 
              dat <= " ";                  // пробел
              next <= dat17; 
            end 

    dat17:  begin  
              rs  <= 1; 
              dat <= "I";                  // 'I'
              next <= dat18; 
            end 

    dat18:  begin  
              rs  <= 1; 
              dat <= "I";                  // 'I' (получаем "NIOS II")
              next <= set5;                // Переход к установке адреса третьей строки
            end 

    // --- Третья строка: установка адреса и текст "SOPC" ---
    set5:   begin  
              rs  <= 0; 
              dat <= 8'h88;                // Установка адреса начала третьей строки
              next <= dat19; 
            end // ПФКѕµЪИэРР

    dat19:  begin  
              rs  <= 1; 
              dat <= "S";                  // 'S'
              next <= dat20; 
            end 

    dat20:  begin  
              rs  <= 1; 
              dat <= "O";                  // 'O'
              next <= dat21; 
            end 

    dat21:  begin  
              rs  <= 1; 
              dat <= "P";                  // 'P'
              next <= dat22; 
            end 

    dat22:  begin  
              rs  <= 1; 
              dat <= "C";                  // 'C' (строка "SOPC")
              next <= set6;                // Переход к установке адреса четвертой строки
            end 

    // --- Четвёртая строка: установка адреса и текст "FPGA" ---
    set6:   begin  
              rs  <= 0; 
              dat <= 8'h98;                // Установка адреса начала четвертой строки
              next <= dat23; 
            end // ПФКѕµЪЛДРР

    dat23:  begin  
              rs  <= 1; 
              dat <= "F";                  // 'F'
              next <= dat24; 
            end 

    dat24:  begin  
              rs  <= 1; 
              dat <= "P";                  // 'P'
              next <= dat25; 
            end 

    dat25:  begin  
              rs  <= 1; 
              dat <= "G";                  // 'G'
              next <= dat26; 
            end 

    dat26:  begin  
              rs  <= 1; 
              dat <= "A";                  // 'A' (строка "FPGA")
              next <= nul;                 // Переход в завершающее состояние
            end 

    // --- Завершение цикла вывода ---
    nul:   begin 
              rs  <= 0;  
              dat <= 8'h00;                // Можно считать "пустой" командой / удержанием
              // °СТєѕ§µДE ЅЕ А­ёЯ (оригинальный комментарий)
              if(cnt != 2'h2)              // Если ещё не достигли нужного числа повторов
                  begin  
                       e   <= 0;           // EN формируется только от clkr (без e)
                       next <= set0;       // Повторить цикл с инициализации
                       cnt  <= cnt + 1'b1; // Увеличить счётчик повторов
                  end  
              else  
                  begin 
                       next <= nul;        // Остаёмся в состоянии nul (ничего не меняется)
                       e    <= 1;          // EN будет дополнительно зависеть от e
                  end    
            end 

   default:   next = set0;                 // Защита: при неизвестном состоянии — в начало
    endcase 
 end 

// Формирование выходных сигналов
assign en = clkr | e;   // Сигнал EN: логическое ИЛИ замедленного такта и флага e
assign rw = 0;          // Всегда режим записи (RW = 0), чтение не используется
endmodule  
