/*
  Модуль: lcd
  Назначение: управление индикатором LCD12864 в текстовом режиме (HD44780-совместимом).

  На дисплей выводится текст:

      Lycee Free EDA
      NIOS II
      SOPC
      FPGA

  Работа строится на конечном автомате (state machine):
    - set0..set3  — инициализация дисплея,
    - dat0..dat11 — первая строка,
    - set4+dat12..dat18 — вторая строка,
    - set5+dat19..dat22 — третья строка,
    - set6+dat23..dat26 — четвертая строка,
    - nul — завершение/повторение цикла.
*/

module lcd (clk, rs, rw, en,dat);  
input clk;                    // Входной тактовый сигнал (обычно ~50 МГц)
 output [7:0] dat;            // 8-битная шина данных к LCD
 output  rs,rw,en;            // Управляющие сигналы: RS (команда/данные), RW (чтение/запись), EN (Enable)
 //tri en;                    // Можно было бы сделать EN трёхстабильным (не используется)

 reg e;                       // Дополнительный флаг для формирования EN (используется в состоянии nul)
 reg [7:0] dat;               // Регистр с данными, которые уходят на вывод dat[7:0]
 reg rs;                      // Регистр выбора режима: 0 — команда, 1 — данные (ASCII символ)
 reg  [15:0] counter;         // Счётчик для деления частоты входного clk и получения медленного clkr
 reg [5:0] current,next;      // current — текущее состояние автомата, next — следующее состояние
 reg clkr;                    // Замедленный тактовый сигнал для автомата состояний
 reg [1:0] cnt;               // Счётчик повторов цикла вывода (используется в nul)

 // Блок параметров — коды состояний конечного автомата
 parameter  set0=6'h0;        // Начальная команда инициализации
 parameter  set1=6'h1;        // Следующий шаг инициализации
 parameter  set2=6'h2;        // Настройка режима ввода
 parameter  set3=6'h3;        // Очистка дисплея
 parameter  set4=6'h4;        // Установка адреса второй строки
 parameter  set5=6'h5;        // Установка адреса третьей строки
 parameter  set6=6'h6;        // Установка адреса четвертой строки  

 parameter  dat0=6'h7;        // Состояния вывода символов первой строки
 parameter  dat1=6'h8; 
 parameter  dat2=6'h9; 
 parameter  dat3=6'hA; 
 parameter  dat4=6'hB; 
 parameter  dat5=6'hC;
 parameter  dat6=6'hD; 
 parameter  dat7=6'hE; 
 parameter  dat8=6'hF; 
 parameter  dat9=6'h10;

 parameter  dat10=6'h12;      // Переход ко второй строке / продолжение текста
 parameter  dat11=6'h13; 
 parameter  dat12=6'h14; 
 parameter  dat13=6'h15; 
 parameter  dat14=6'h16; 
 parameter  dat15=6'h17;
 parameter  dat16=6'h18; 
 parameter  dat17=6'h19; 
 parameter  dat18=6'h1A; 
 parameter  dat19=6'h1B; 
 parameter  dat20=6'h1C;
 parameter  dat21=6'h1D; 
 parameter  dat22=6'h1E; 
 parameter  dat23=6'h1F; 
 parameter  dat24=6'h20; 
 parameter  dat25=6'h21; 
 parameter  dat26=6'h22;     
  
 parameter  nul=6'hF1;        // Завершающее состояние — останов/повтор

// Делитель частоты: из быстрого clk формируется более медленный clkr
always @(posedge clk)         
 begin 
  counter=counter+1;          // Инкремент счётчика
  if(counter==16'h000f)       // При достижении порогового значения
  clkr=~clkr;                 // инвертируем clkr → получаем медленный такт для автомата
end 

// Основной автомат состояний, работающий на замедленном такте clkr
always @(posedge clkr) 
begin 
 current=next;                // Переход в следующее состояние
  case(current) 
    // --- Инициализация LCD ---
    set0:   begin  rs<=0; dat<=8'h30; next<=set1; end  // Команда: функциональная установка (8-битный интерфейс и т.п.)
    set1:   begin  rs<=0; dat<=8'h0c; next<=set2; end  // Команда: включить дисплей, выключить курсор
    set2:   begin  rs<=0; dat<=8'h6; next<=set3; end   // Команда: режим ввода, инкремент адреса
    set3:   begin  rs<=0; dat<=8'h1; next<=dat0; end   // Команда: очистка дисплея, далее — вывод текста

    // --- Первая строка: "Lycee Free EDA" (начало "Lyc Free EDA" в коде) ---
    dat0:   begin  rs<=1; dat<="L"; next<=dat1; end //ПФКѕµЪТ»РР  // 'L'
    dat1:   begin  rs<=1; dat<="y"; next<=dat2; end               // 'y'
    dat2:   begin  rs<=1; dat<="c"; next<=dat3; end               // 'c'
    dat3:   begin  rs<=1; dat<=" ";next<=dat4; end                // пробел
    dat4:   begin  rs<=1; dat<="F"; next<=dat5; end               // 'F'
    dat5:   begin  rs<=1; dat<="r"; next<=dat6; end               // 'r'
    dat6:   begin  rs<=1; dat<="e"; next<=dat7; end               // 'e'
    dat7:   begin  rs<=1; dat<="e";next<=dat8; end                // 'e'
    dat8:   begin  rs<=1; dat<=" "; next<=dat9; end               // пробел
    dat9:   begin  rs<=1; dat<="E";next<= dat10 ; end             // 'E'
    dat10:   begin  rs<=1; dat<="D"; next<=dat11; end             // 'D'
    dat11:   begin  rs<=1; dat<="A"; next<=set4; end              // 'A' → "Lyc Free EDA"

    // --- Установка адреса второй строки ---
    set4:   begin  rs<=0; dat<=8'h90; next<=dat12; end //ПФКѕµЪ¶юРР  // Установка адреса начала второй строки

    // --- Вторая строка: "NIOS II" ---
    dat12:   begin  rs<=1; dat<="N"; next<=dat13; end             // 'N'
    dat13:   begin  rs<=1; dat<="I";next<=dat14; end              // 'I'
    dat14:   begin  rs<=1; dat<="O"; next<=dat15; end             // 'O'
    dat15:   begin  rs<=1; dat<="S"; next<=dat16; end             // 'S'
    dat16:   begin  rs<=1; dat<=" "; next<=dat17; end             // пробел
    dat17:   begin  rs<=1; dat<="I"; next<=dat18; end             // 'I'
    dat18:   begin  rs<=1; dat<="I"; next<=set5; end              // 'I' → "NIOS II"

    // --- Установка адреса третьей строки ---
    set5:   begin  rs<=0; dat<=8'h88; next<=dat19; end //ПФКѕµЪИэРР  // Установка адреса начала третьей строки

    // --- Третья строка: "SOPC" ---
    dat19:   begin  rs<=1; dat<="S"; next<=dat20; end             // 'S'
    dat20:   begin  rs<=1; dat<="O"; next<=dat21; end             // 'O'
    dat21:   begin  rs<=1; dat<="P"; next<=dat22; end             // 'P'
    dat22:   begin  rs<=1; dat<="C"; next<=set6 ; end             // 'C' → "SOPC"

    // --- Установка адреса четвёртой строки ---
    set6:   begin  rs<=0; dat<=8'h98; next<=dat23; end //ПФКѕµЪЛДРР  // Установка адреса начала четвертой строки

    // --- Четвёртая строка: "FPGA" ---
    dat23:   begin  rs<=1; dat<="F"; next<=dat24; end             // 'F'
    dat24:   begin  rs<=1; dat<="P"; next<=dat25; end             // 'P'
    dat25:   begin  rs<=1; dat<="G"; next<=dat26; end             // 'G'
    dat26:   begin  rs<=1; dat<="A"; next<=nul;   end             // 'A' → "FPGA"

     // --- Завершение цикла и логика повторения ---
     nul:   begin rs<=0;  dat<=8'h00;                    // °СТєѕ§µДE ЅЕ А­ёЯ  // «пустая» команда / удержание
              if(cnt!=2'h2)                               // Если ещё не достигли заданного числа повторов
                  begin  
                       e<=0;next<=set0;cnt<=cnt+1;        // Повторяем цикл с инициализации
                  end  
                   else  
                     begin next<=nul; e<=1;               // Остаёмся в nul, EN формируется с учётом e
                    end    
              end 
   default:   next=set0;                                  // Защита: при любом неизвестном состоянии → в начало
    endcase 
 end 

// Формирование выходных сигналов
assign en=clkr|e;     // EN активен, когда либо clkr=1, либо e=1
assign rw=0;          // Всегда режим записи (RW=0), чтение с LCD не используется
endmodule  
