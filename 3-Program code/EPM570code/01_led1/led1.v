/****************************************************
* Назначение файла: Пример управления светодиодами
* Модуль: led1
* Дата изменения: 2025.02.01
* Версия: 1.0.1
*
* Video:  
* GitHub: https://github.com/AIDevelopersMonster/CPLD_EPM240_570
*
* Описание:
*   Модуль выводит фиксированный шаблон на 8 светодиодов.
*   Каждый бит задаётся статически.
****************************************************/

module led1(led);

    // Выход: восемь линий управления светодиодами
    output [7:0] led;

     // Фиксированный шаблон включения светодиодов
    // Инверсная логика: 0 = включён, 1 = выключен

    assign led[0] = 1'b1; // LED1 — выключен
    assign led[1] = 1'b0; // LED2 — включён
    assign led[2] = 1'b1; // LED3 — выключен
    assign led[3] = 1'b0; // LED4 — включён
    assign led[4] = 1'b1; // LED5 — выключен
    assign led[5] = 1'b0; // LED6 — включён
    assign led[6] = 1'b1; // LED7 — выключен
    assign led[7] = 1'b0; // LED8 — включён

endmodule


/*  
#-------------------- Назначение выводов LED ----------------------#
set_location_assignment PIN_67 -to led[0]   # LED1
set_location_assignment PIN_66 -to led[1]   # LED2
set_location_assignment PIN_61 -to led[2]   # LED3
set_location_assignment PIN_58 -to led[3]   # LED4
set_location_assignment PIN_57 -to led[4]   # LED5
set_location_assignment PIN_56 -to led[5]   # LED6
set_location_assignment PIN_55 -to led[6]   # LED7
set_location_assignment PIN_54 -to led[7]   # LED8

*/
