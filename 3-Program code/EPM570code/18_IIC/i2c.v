/*
  Module     : i2c.v
  Device     : AT24C08 (I2C EEPROM) + CPLD EPM240/EPM570
  Created By : kontakts.ru
  Project    : CPLD_EPM240_570

  Description:
    Контроллер I2C для работы с EEPROM AT24C08.

    Функционал демо:
    - На вход data_in[3:0] подаётся значение с переключателей (DIP/ползунки).
    - При нажатии кнопки wr_input (K1, активный ноль) значение записывается
      в фиксированный адрес EEPROM (регистр addr).
    - При нажатии rd_input (K2, активный ноль) выполняется чтение из того же
      адреса EEPROM, а прочитанные данные выводятся на светодиоды leddata[3:0].
    - Интерфейс I2C реализован "вручную" (bit-banging):
        * делитель тактовой частоты для формирования SCL;
        * формирование старт/стоп-условий, передачи байта и ACK;
        * последовательные состояния для записи и чтения.

  Ports:
    input  clk      – системный тактовый сигнал (например, 50 МГц);
    input  rst      – асинхронный сброс (активный 0);
    input  [3:0] data_in  – данные с переключателей для записи в EEPROM;
    input  wr_input – команда записи (кнопка K1, активный 0);
    input  rd_input – команда чтения (кнопка K2, активный 0);
    inout  sda      – линия данных I2C;
    output scl      – линия тактов I2C;
    output [3:0] leddata – младшие биты прочитанного байта (индикация на LED).

  Use:
    1) Выставить значение на переключателях data_in[3:0].
    2) Нажать K1 (wr_input) – значение запишется в EEPROM по адресу addr.
    3) Нажать K2 (rd_input) – значение прочитается и появится на leddata[3:0].

  Repo:
    https://github.com/AIDevelopersMonster/CPLD_EPM240_570

  YouTube playlist (FPGA / CPLD):
    https://www.youtube.com/playlist?list=PLVoFIRfTAAI7-d_Yk6bNVnj4atUdMxvT5
*/



module i2c(clk,rst,data_in,scl,sda,wr_input,rd_input,leddata);

input clk,rst;
output scl;  // линия тактов I2C (SCL)
inout  sda;  // линия данных I2C (SDA)
input[3:0] data_in;   // данные с переключателей для записи в EEPROM
input wr_input;       // сигнал запроса записи (кнопка, активный 0)
input rd_input;       // сигнал запроса чтения (кнопка, активный 0)

output[3:0] leddata;  // выход на светодиоды
reg[3:0] leddata;


reg scl;  // регистр для формирования сигнала SCL

reg[4:0] led_buf;      // буфер для индикации (в данном коде не используется по назначению)
reg[11:0] cnt_scan;    // счётчик (также не используется далее)
reg sda_buf;           // внутренний буфер значения SDA
reg link;              // флаг управления линией SDA (1 – вывод, 0 – Z)
reg phase0,phase1,phase2,phase3; // четыре фазы одного периода SCL, такт делится на 4 подфазы
// phase0 – момент выборки / граница,
// phase1 – середина высокого уровня SCL,
// phase2 – спуск (переход SCL в 0),
// phase3 – середина низкого уровня SCL
reg[7:0] clk_div;      // делитель частоты для формирования SCL
reg[1:0] main_state;   // верхний уровень автомата (режим ожидание/запись/чтение)
reg[2:0] i2c_state;    // состояние I2C-подпроцесса (инициализация, отправка адреса и т.п.)
reg[3:0] inner_state;  // внутреннее состояние, побитовое (start, first..eighth, ack, stop)
reg[19:0] cnt_delay;   // счётчик задержки между операциями записи/чтения
reg start_delaycnt;    // разрешение работы счётчика задержки
reg[7:0] writeData_reg,readData_reg; // writeData_reg – байт для записи в EEPROM, readData_reg – принятый байт
reg[7:0] addr;         // адрес байта в EEPROM

parameter div_parameter=100; // коэффициент деления частоты для формирования SCL

parameter start   = 4'b0000,  // стартовое под-состояние (формирование START)
		  first   = 4'b0001,  // передача/приём 1-го бита
		  second  = 4'b0010,  // 2-го
		  third   = 4'b0011,  // 3-го
		  fourth  = 4'b0100,  // 4-го
		  fifth   = 4'b0101,  // 5-го
		  sixth   = 4'b0110,  // 6-го
		  seventh = 4'b0111,  // 7-го
		  eighth  = 4'b1000,  // 8-го
		  ack     = 4'b1001,  // такт подтверждения ACK
		  stop    = 4'b1010;  // формирование STOP
		
parameter ini       = 3'b000,  // начальная инициализация / START + адрес устройства
		  sendaddr  = 3'b001,  // передача адреса байта в EEPROM
		  write_data= 3'b010,  // передача байта данных (режим записи)
		  read_data = 3'b011,  // приём байта данных (режим чтения)
		  read_ini  = 6'b100;  // подготовка к чтению (повторный START и т.д.)

// Управление линией SDA: если link = 1, выводим sda_buf; если 0 — отпускаем в Z (open-drain)
assign sda=(link)? sda_buf:1'bz;

// Счётчик задержки между операциями (например, выдержка после записи EEPROM)
always@(posedge clk or negedge rst)
begin
	if(!rst)
		cnt_delay<=0;
	else begin
		if(start_delaycnt) begin
			if(cnt_delay!=20'd800000)
				cnt_delay<=cnt_delay+1;  // инкремент, пока не достигнем заданного значения
			else
				cnt_delay<=0;           // по достижении верхнего предела – сброс
		 end
	 end
end

// Формирование четырёх фаз такта SCL на основе делителя clk_div
always@(posedge clk or negedge rst)
begin
	if(!rst) begin
		clk_div<=0;
		phase0<=0;
		phase1<=0;
		phase2<=0;
		phase3<=0;
	 end
	else begin
		// счётчик делителя
		if(clk_div!=div_parameter-1)
			clk_div<=clk_div+1;
		else
			clk_div<=0;
		
		// генерация коротких импульсов phase0..phase3 в нужные моменты счёта
		if(phase0)
			phase0<=0;	
		else if(clk_div==99) 
			phase0<=1;
		if(phase1)
			phase1<=0;
		else if(clk_div==24)
			phase1<=1;
		if(phase2)
			phase2<=0;
		else if(clk_div==49)
			phase2<=1;
		if(phase3)
			phase3<=0;
		else if(clk_div==74)
			phase3<=1;
	 end
end


/////////////////////////// EEPROM — основной автомат /////////////////////////
// Основной автомат управления EEPROM по I2C
always@(posedge clk or negedge rst)
begin
	if(!rst) begin
		start_delaycnt<=0;       // счётчик задержки выключен
		main_state<=2'b00;       // начальное состояние: ожидание
		i2c_state<=ini;          // начальное состояние I2C
		inner_state<=start;      // начальное под-состояние (формирование START)
		scl<=1;                  // линия SCL в высоком уровне (шина свободна)
		sda_buf<=1;              // SDA в '1' (pull-up)
		link<=0;                 // линия SDA отпущена (Z)
		writeData_reg<=5;        // дефолтное значение для записи
		readData_reg<=0;         // регистр чтения обнулён
		addr<=10;                // фиксированный адрес ячейки EEPROM
	 end
	else begin
		case(main_state)
			2'b00: begin  // ожидание команды записи/чтения
				writeData_reg<=data_in; // обновляем данные для записи из переключателей
				scl<=1;                 // удерживаем SCL в '1' (шина свободна)
				sda_buf<=1;             // SDA = 1
				link<=0;                // линия SDA в Z
				inner_state<=start;     // под-состояние – START
				i2c_state<=ini;         // состояние I2C – инициализация
				// Запуск счётчика задержки при нажатии wr_input или rd_input (активный 0)
				if((cnt_delay==0)&&(!wr_input||!rd_input))
						start_delaycnt<=1;  // включаем счётчик задержки
				else if(cnt_delay==20'd800000) begin
						start_delaycnt<=0;  // по истечении задержки останавливаем счётчик
						if(!wr_input)       // если активен вход записи
							main_state<=2'b01; // переходим в режим записи
						else if(!rd_input)   // если активен вход чтения
							main_state<=2'b10; // переходим в режим чтения
				 end
			 end
			2'b01: begin  // цикл записи данных в EEPROM
				// Формирование SCL по фазам
				if(phase0)
					scl<=1;
				else if(phase2)
					scl<=0;
			
				case(i2c_state)
					ini: begin   // начальная посылка START + адрес устройства (режим записи)
						case(inner_state)
							start: begin
								// НАЧАЛО: при phase1 опускаем SDA при высоком SCL — формируем START
								if(phase1) begin
									link<=1;    // начинаем управлять SDA из CPLD
									sda_buf<=0; // SDA=0 (START)
								 end
								// После формирования START переходим к передаче первого бита адреса устройства
								if(phase3&&link) begin
									inner_state<=first;
									sda_buf<=1; // готовим следующий уровень SDA
									link<=1;
								 end
							 end
							first: 
								if(phase3) begin
									sda_buf<=0;  // бит адреса
									link<=1;
									inner_state<=second;
								 end
							second:
								if(phase3) begin
									sda_buf<=1;  // следующий бит адреса
									link<=1;
									inner_state<=third;
								 end
							third:
								if(phase3) begin
									sda_buf<=0;
									link<=1;
									inner_state<=fourth;
								 end
							fourth:
								if(phase3) begin
									sda_buf<=0;
									link<=1;
									inner_state<=fifth;
								 end
							fifth:
								if(phase3) begin
									sda_buf<=0;
									link<=1;
									inner_state<=sixth;
								 end
							sixth:
								if(phase3) begin
									sda_buf<=0;
									link<=1;
									inner_state<=seventh;
								 end
							seventh:
								if(phase3) begin
									sda_buf<=0;
									link<=1;
									inner_state<=eighth;
								 end
							eighth:
								if(phase3) begin
									link<=0;        // отпускаем SDA, чтобы EEPROM могла выдать ACK
									inner_state<=ack;
								 end
							ack: begin
								// Считываем ACK от EEPROM
								if(phase0) 
									sda_buf<=sda;  // выборка значения SDA
								if(phase1) begin
									if(sda_buf==1) // если нет ACK (SDA=1), возвращаемся в ожидание
										main_state<=3'b000;
								 end
								// Если всё нормально, переходим к передаче адреса ячейки памяти
								if(phase3) begin
									link<=1;
									sda_buf<=addr[7];   // старший бит адреса байта
									inner_state<=first;
									i2c_state<=sendaddr;
								 end
							 end
						 endcase
					 end
					sendaddr: begin  // передача адреса байта в EEPROM
						case(inner_state)
							first: 
								if(phase3) begin
									link<=1;
									sda_buf<=addr[6];
									inner_state<=second;
								 end
							second:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[5];
									inner_state<=third;
								 end
							third:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[4];
									inner_state<=fourth;
								 end
							fourth:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[3];
									inner_state<=fifth;
								 end
							fifth:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[2];
									inner_state<=sixth;
								 end
							sixth:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[1];
									inner_state<=seventh;
								 end
							seventh:
								if(phase3) begin
									link<=1;
									sda_buf<=addr[0];
									inner_state<=eighth;
								 end
							eighth:
								if(phase3) begin
									link<=0;          // отпускаем SDA для ACK
									inner_state<=ack;
								 end
							ack: begin
								if(phase0) 
									sda_buf<=sda;    // выборка ACK
								if(phase1) begin
									if(sda_buf==1)  // если ACK нет – выходим в ожидание
										main_state<=3'b000;
								 end
								// ACK получен – переходим к передаче данных
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[7]; // старший бит данных
									inner_state<=first;
									i2c_state<=write_data;
								 end
							 end
						 endcase
					 end
					write_data: begin // побитовая передача байта данных в EEPROM
						case(inner_state)
							first: 
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[6]; // следующий бит данных
									inner_state<=second;
								 end
							second:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[5];
									inner_state<=third;
								 end
							third:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[4];
									inner_state<=fourth;
								 end
							fourth:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[3];
									inner_state<=fifth;
								 end
							fifth:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[2];
									inner_state<=sixth;
								 end
							sixth:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[1];
									inner_state<=seventh;
								 end
							seventh:
								if(phase3) begin
									link<=1;
									sda_buf<=writeData_reg[0]; // младший бит данных
									inner_state<=eighth;
								 end
							eighth:
								if(phase3) begin
									link<=0;          // отпускаем SDA для ACK
									inner_state<=ack;
								 end
							ack: begin
								if(phase0) 
									sda_buf<=sda;    // считываем ACK
								if(phase1) begin
									if(sda_buf==1)   // если ACK нет – выходим в ожидание
										main_state<=2'b00;
								 end
								else if(phase3) begin
									// Формируем STOP: SDA = 0 при низком SCL, затем поднимаем в 1
									link<=1;
									sda_buf<=0;
									inner_state<=stop;
								 end
							 end
							stop: begin
								if(phase1)
									sda_buf<=1;      // SDA=1 при высоком SCL → STOP
								if(phase3) 
									main_state<=2'b00; // возвр. в режим ожидания
							 end
						 endcase
					 end
					default:
						main_state<=2'b00;  // защита по умолчанию
				 endcase
			 end
			2'b10: begin  // цикл чтения из EEPROM
				// Формирование SCL по фазам
				if(phase0)
					scl<=1;
				else if(phase2)
					scl<=0;
					
				case(i2c_state)
				ini: begin   // инициализация: START + адрес устройства (режим записи, чтобы задать адрес ячейки)
					case(inner_state)
						start: begin
							if(phase1) begin
								link<=1;
								sda_buf<=0;  // формируем START
							 end
							if(phase3&&link) begin
								inner_state<=first;
								sda_buf<=1;
								link<=1;
							 end
						 end
						first: 
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=second;
							 end
						second:
							if(phase3) begin
								sda_buf<=1;
								link<=1;
								inner_state<=third;
							 end
						third:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=fourth;
							 end
						fourth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=fifth;
							 end
						fifth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=sixth;
							 end
						sixth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=seventh;
							 end
						seventh:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=eighth;
							 end
						eighth:
							if(phase3) begin
								link<=0;        // отпускаем SDA для ACK
								inner_state<=ack;
							 end
						ack: begin
							if(phase0) 
								sda_buf<=sda;   // считываем ACK
							if(phase1) begin
								if(sda_buf==1)  // при отсутствии ACK выходим в ожидание
									main_state<=2'b00;
							 end
							if(phase3) begin
								// после ACK переходим к передаче адреса ячейки
								link<=1;
								sda_buf<=addr[7];
								inner_state<=first;
								i2c_state<=sendaddr;
							end
						 end
					endcase
				end
				sendaddr: begin  // отправка адреса байта для чтения
					case(inner_state)
						first: 
							if(phase3) begin
								link<=1;
								sda_buf<=addr[6];
								inner_state<=second;
							 end
						second:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[5];
								inner_state<=third;
							 end
						third:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[4];
								inner_state<=fourth;
							 end
						fourth:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[3];
								inner_state<=fifth;
							 end
						fifth:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[2];
								inner_state<=sixth;
							 end
						sixth:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[1];
								inner_state<=seventh;
							 end
						seventh:
							if(phase3) begin
								link<=1;
								sda_buf<=addr[0];
								inner_state<=eighth;
							 end
						eighth:
							if(phase3) begin
								link<=0;        // ждём ACK
								inner_state<=ack;
							 end
						ack: begin
							if(phase0) 
								sda_buf<=sda;   // выборка ACK
							if(phase1) begin
								if(sda_buf==1)  // нет ACK – выходим в ожидание
									main_state<=2'b00;
							 end
							if(phase3) begin
								// После задания адреса ячейки – повторный START и переход в режим чтения
								link<=1;
								sda_buf<=1;     // подготовка SDA
								inner_state<=start;
								i2c_state<=read_ini;
							 end
						 end
					 endcase
				 end
				read_ini: begin  // формирование повторного START и адреса устройства в режиме чтения
					case(inner_state)
						start: begin
							if(phase1) begin
								link<=1;
								sda_buf<=0;  // повторный START
							 end
							if(phase3&&link) begin
								inner_state<=first;
								sda_buf<=1;
								link<=1;
							 end
						 end
						first: 
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=second;
							 end
						second:
							if(phase3) begin
								sda_buf<=1;
								link<=1;
								inner_state<=third;
							 end
						third:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=fourth;
							 end
						fourth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=fifth;
							 end
						fifth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=sixth;
							 end
						sixth:
							if(phase3) begin
								sda_buf<=0;
								link<=1;
								inner_state<=seventh;
							end
						seventh:
							if(phase3) begin
								sda_buf<=1;  // бит R/W = 1 (чтение)
								link<=1;
								inner_state<=eighth;
							 end
						eighth:
							if(phase3) begin
								link<=0;      // отпускаем SDA для ACK
								inner_state<=ack;
							 end
						ack: begin
							if(phase0) 
								sda_buf<=sda;  // считываем ACK
							if(phase1) begin
								if(sda_buf==1)  // если нет ACK – выходим
									main_state<=2'b00;
							 end
							if(phase3) begin
								// Переход к приёму данных
								link<=0;       // SDA в Z, EEPROM ведёт линию
								inner_state<=first;
								i2c_state<=read_data;
							 end
						 end
					endcase
				end
				read_data: begin  // побитовый приём байта данных из EEPROM
					case(inner_state)
						first: begin
							if(phase0)
								sda_buf<=sda; // выборка линии SDA
							if(phase1) begin
								// сдвиг регистра и приём бита
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=second; // переход к следующему биту
						 end
						second: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=third;
						 end
						third: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=fourth;							
						 end
						fourth: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=fifth;							
						 end
						fifth: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=sixth;							
						 end
						sixth: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=seventh;								
						 end
						seventh: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda;
							 end
							if(phase3)
								inner_state<=eighth;								
						 end
						eighth: begin
							if(phase0)
								sda_buf<=sda;
							if(phase1) begin
								readData_reg[7:1]<=readData_reg[6:0];
								readData_reg[0]<=sda; // приём последнего (8-го) бита
							 end
							if(phase3) 
								inner_state<=ack; // переходим к формированию ACK
						 end
						ack: begin
							if(phase3) begin
								// формируем ACK: драйвер SDA включен, на линию выдаётся 0
								link<=1;
								sda_buf<=0;
								inner_state<=stop;
							 end
						 end
						stop: begin
							// формирование STOP: SDA поднимается в 1 при высоком SCL
							if(phase1) 
								sda_buf<=1;
							if(phase3) 
								main_state<=2'b00; // завершили чтение, вернулись в ожидание
						 end
					 endcase
				 end
			 endcase
		end
	 endcase
 end
end
				
/////////////////////////// led — индикация данных ///////////////////////////					
// Блок индикации на светодиодах:
// сюда выводится readData_reg (прочитанные из EEPROM данные)
always@(writeData_reg or readData_reg)
begin
			leddata=readData_reg;  // отображаем содержимое регистра readData_reg на leddata[3:0]
end


endmodule 
