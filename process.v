`timescale 1ns / 1ps

module process(
	input clk,				// clock 
	input [23:0] in_pix,	// valoarea pixelului de pe pozitia [in_row, in_col] din imaginea de intrare (R 23:16; G 15:8; B 7:0)
	output reg[5:0] row, col, 	// selecteaza un rand si o coloana din imagine
	output reg out_we, 			// activeaza scrierea pentru imaginea de iesire (write enable)
	output reg[23:0] out_pix,	// valoarea pixelului care va fi scrisa in imaginea de iesire pe pozitia [out_row, out_col] (R 23:16; G 15:8; B 7:0)
	output reg mirror_done,		// semnaleaza terminarea actiunii de oglindire (activ pe 1)
	output reg gray_done,		// semnaleaza terminarea actiunii de transformare in grayscale (activ pe 1)
	output reg filter_done);	// semnaleaza terminarea actiunii de aplicare a filtrului de sharpness (activ pe 1)

// TODO add your finite state machines here

`define INIT                     0   // Aici initializam starile de care vom avea nevoie pentru prelucrarea imaginii
`define MIRROR_1                 1
`define MIRROR_2                 2
`define MIRROR_3 						3
`define MIRROR_FINISH 				4
`define GRAYSCALE_1 					5
`define GRAYSCALE_2 					6
`define GRAYSCALE_3 					7
`define GRAYSCALE_FINISH 			8
`define SHARPEN_1 					9
`define SHARPEN_2 					10
`define SHARPEN_TOP_LEFT			11
`define SHARPEN_TOP					12
`define SHARPEN_TOP_RIGHT			13
`define SHARPEN_LEFT					14
`define SHARPEN_RIGHT				15
`define SHARPEN_BOT_LEFT			16
`define SHARPEN_BOT					17
`define SHARPEN_BOT_RIGHT			18
`define SHARPEN_MID					19
`define SHARPEN_3 					20
`define SHARPEN_FINISH 				21
`define SHARPEN_1_2					22
`define CACHE_1_1						23
`define CACHE_1_2						24
`define CACHE_3_1						25
`define CACHE_3_2						26
`define SHARPEN_1_1_1           	27
`define SHARPEN_1_1_2           	28

reg[5:0] next_row, next_col;            	// Variabile pentru a parcurge secvential matricea imaginii
reg[4:0] state = `INIT , next_state;		// Variabile care definesc starea in care ne vom afla
reg[23:0] pixel_1, pixel_2;					// Variabile pentru a cache-ui pixelii pentru oglindirea imaginii
reg[7:0] gray_pixel;								// Variabila pentru a memora datele prelucrate pentru grayscale
reg[23:0] sharp_pix;								// Variabila folosita pentru calcularea pixelului filtrat
reg[7:0] cache1[0:63];							// Vector cache destinat memorarii randului de pe coloana curenta
reg[7:0] cache2[0:63];							// Vector cache destinat memorarii randului de pe coloana anterioara
reg[7:0] cache3[0:63];							// Vector cache destinat memorarii randului de pe coloana urmatoare
reg cache_middle, cache_right;				// Semafoare ce ajuta la trecerea in starea de cache-uire
integer i, j;

// Partea secventiala
always @(posedge clk) begin         
	state <= next_state;
	row <= next_row;
	col <= next_col;
end
	
// Partea combinationala
always @(*) begin

	case(state)
		`INIT: begin           			// Stare initiala in care vom initializa variabilele pe o valoare default
			next_row = 0;
			next_col = 0;
			mirror_done = 0;
			gray_done = 0;
			filter_done = 0;
			out_we = 0;
			next_state = `MIRROR_1;
			end
	
		`MIRROR_1: begin					// Inceputul primului task
			pixel_1 = in_pix; 			// citim primul pixelul de pe pozitia initiala
			next_row = 63 - row; 		// dupa care ne mutam pe pozitia oglindita
			next_state = `MIRROR_2;
			end
		`MIRROR_2: begin
			pixel_2 = in_pix; 			// memoram al doilea pixel de pe pozitia oglindita
			out_pix = pixel_1; 			// scriem primul pixel (care vine de pe pozitia initiala) pe pozitia oglindita
			out_we = 1;
			next_row = 63 - row;			// ne intoarcem pe pozitia initiala
			next_state = `MIRROR_3;
			end
		`MIRROR_3:begin
			out_pix = pixel_2;			//  scriem al doilea pixel (care vine de pe pozitia oglindita) pe pozitia initiala
			out_we = 1;
			if(row < 31) begin			// de aici incepe partea de incrementare
				next_row = row + 1;
				next_state = `MIRROR_1;
				end
			else if (row == 31 && col < 63) begin
				next_row = 0;
				next_col = col + 1;
				next_state = `MIRROR_1;
				end
			else if (row == 31 && col == 63) begin
				next_state = `MIRROR_FINISH;
				end
			end
		`MIRROR_FINISH: begin				// Terminarea primului task
			out_we = 0;
			mirror_done = 1; 
			next_state = `GRAYSCALE_1;
			end
		`GRAYSCALE_1: begin              // Inceputul taskului 2, reinitializam linia si coloana
			next_row = 0;
			next_col = 0;
			next_state = `GRAYSCALE_2;
			end
		`GRAYSCALE_2: begin																			// Cautam MIN si MAX si calculam media acestora
			if((in_pix[23:16] >= in_pix[15:8] && in_pix[15:8] >= in_pix [7:0]) || 
			(in_pix[23:16] <= in_pix[15:8] && in_pix[15:8] <= in_pix[7:0])) begin // daca R>G>B sau R<G<B => G = (R + B) / 2;
				gray_pixel = (in_pix[23:16] + in_pix[7:0]) / 2;
				end
			else if ((in_pix[23:16] >= in_pix[7:0] && in_pix[7:0] >= in_pix[15:8]) || 
			(in_pix[23:16] <= in_pix[7:0] && in_pix[7:0] <= in_pix[15:8])) begin // daca R>B>G sau R<B<G => G = (R + G) / 2;
				gray_pixel = (in_pix[15:8] + in_pix[23:16]) / 2;
				end
			else if ((in_pix[7:0] >= in_pix[23:16] && in_pix[23:16] >= in_pix[15:8]) ||
			(in_pix[7:0] <= in_pix[23:16] && in_pix[23:16] <= in_pix[15:8])) begin // daca B>R>G sau B<R<G => G = (B + G) / 2 ;
				gray_pixel = (in_pix[7:0] + in_pix[15:8]) / 2;
				end
				next_state = `GRAYSCALE_3;
			end
		`GRAYSCALE_3: begin
				out_pix[15:8] = gray_pixel;               // Scriem canalul G calculat anterior, iar canalele R si B primesc valoarea 0
				out_pix[23:16] = 0;
				out_pix[7:0] = 0;
				out_we = 1;
				if(row < 63) begin                        // de aici incepe partea de incrementare
					next_row = row + 1;
					next_state = `GRAYSCALE_2;
				end
				else if (row == 63 && col < 63) begin
					next_row = 0;
					next_col = col + 1;
					next_state = `GRAYSCALE_2;
					end
				else if (row == 63 && col == 63) begin
					next_state = `GRAYSCALE_FINISH;
				end
			end
		`GRAYSCALE_FINISH: begin							// Terminarea taskului 2
			out_we = 0;
			gray_done = 1;
			next_state = `SHARPEN_1;
			end
		`SHARPEN_1: begin										// Inceputul taskului 3, reinitializam linia si coloana		
			next_row = 0;
			next_col = 0;
			cache_middle = 0;
			cache_right = 0;
			for(i = 0; i <= 63; i = i + 1) begin
				cache2[i] = 0;
				cache1[i] = 0;
				cache3[i] = 0;
				end
			next_state = `SHARPEN_1_2;
			end
		`SHARPEN_1_1_1: begin										// Cand ne mutam pe alta coloana vectorul curent devine vector anterior
			for(i = 0; i <= 63; i = i + 1) begin
				cache2[i] = cache1[i];
				end
			next_state = `SHARPEN_1_1_2;
			end
		`SHARPEN_1_1_2: begin										// Iar vectorul urmator devine vectorul curent
			for(j = 0; j <= 63; j = j + 1) begin
					cache1[j] = cache3[j];
					end
			next_state = `SHARPEN_1_2;
			end
		`SHARPEN_1_2: begin											// Starea de unde incepem cache-uirea coloanelor vecine pixelului curent
			if(cache_middle == 0) begin							// Cache-uirea coloanei 0
				i = 0;
				next_state = `CACHE_1_1;
				end
			else if(cache_right == 0 && col != 63) begin		// Cache-uirea coloanei urmatoare
				i = 0;
				next_col = col + 1;
				next_state = `CACHE_3_1;
				end
			else begin
				next_state = `SHARPEN_2;
				end
			end	
		`CACHE_1_1: begin											
					cache1[i] = in_pix[15:8];
					j = i + 1;
					next_row = row + 1;
					next_state = `CACHE_1_2;
					end
		`CACHE_1_2: begin												// CACHE_1_1 si CACHE_1_2 sar de la unul la altul pana am ajung la ultima linie
				cache1[j] = in_pix[15:8];
				i = j + 1;
				if(row == 63) begin
					next_row = 0;
					cache_middle = 1;
					next_state = `SHARPEN_1_2;
					end
				else begin 
					next_row = row + 1;
					next_state = `CACHE_1_1;
					end
				end
		`CACHE_3_1: begin												// Acelasi lucru pentru CACHE_3_1 si CACHE_3_2
					cache3[i] = in_pix[15:8];
					j = i + 1;
					next_row = row + 1;
					next_state = `CACHE_3_2;
					end
		`CACHE_3_2: begin
				cache3[j] = in_pix[15:8];
				i = j + 1;
				if(row == 63) begin
					next_row = 0;
					next_col = col - 1;
					cache_right = 1;
					next_state = `SHARPEN_1_2;
					end
				else begin
					next_row = row + 1;
					next_state = `CACHE_3_1;
					end
				end
		`SHARPEN_2: begin												// Starea in care verificam daca pixelul se afla la marginile matricei
			if (row == 0 && col == 0) begin
				next_state = `SHARPEN_TOP_LEFT;
				end
			else if (row == 0 && col != 0) begin
				next_state = `SHARPEN_TOP;
				end
			else if (row == 0 && col == 63) begin
				next_state = `SHARPEN_TOP_RIGHT;
				end
			else if (row != 0 && col == 0) begin
				next_state = `SHARPEN_LEFT;
				end
			else if (row != 0 && col == 63) begin
				next_state = `SHARPEN_RIGHT;
				end
			else if (row == 63 && col == 0) begin
				next_state = `SHARPEN_BOT_LEFT;
				end
			else if (row == 63 && col != 0) begin
				next_state = `SHARPEN_BOT;
				end
			else if (row == 63 && col == 63) begin
				next_state = `SHARPEN_BOT_RIGHT;
				end
			else begin
				next_state = `SHARPEN_MID;
				end
			end
		`SHARPEN_TOP_LEFT: begin																			// De aici avem stari in care calculam pixelul filtrat
			sharp_pix = cache1[row] * 9 - cache1[row+1] - cache3[row] - cache3[row+1];		// in functie de pozitia acestuia in matrice
			next_state = `SHARPEN_3;
			end
		`SHARPEN_TOP: begin
			sharp_pix = cache1[row] * 9 - cache2[row] - cache2[row+1] - cache1[row] -cache3[row] - cache3[row+1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_TOP_RIGHT: begin
			sharp_pix = cache1[row] * 9 - cache1[row+1] -cache2[row] - cache2[row+1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_LEFT: begin
			sharp_pix = cache1[row] * 9 - cache1[row-1] - cache1[row+1] - cache3[row-1] - cache3[row] - cache3[row+1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_RIGHT: begin
			sharp_pix = cache1[row] * 9 - cache1[row-1] - cache1[row+1] - cache2[row-1] - cache2[row] - cache2[row+1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_BOT_LEFT: begin
			sharp_pix = cache1[row] * 9 - cache1[row-1] - cache3[row] - cache3[row-1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_BOT: begin
			sharp_pix = cache1[row] * 9 - cache2[row] - cache2[row-1] - cache1[row-1] -cache3[row] - cache3[row-1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_BOT_RIGHT: begin
			sharp_pix = cache1[row] * 9 - cache1[row-1] -cache2[row] - cache2[row-1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_MID: begin
			sharp_pix = cache1[row] * 9 - cache1[row-1] - cache1[row+1] - cache2[row-1] - cache2[row] - cache2[row+1] 
							- cache3[row-1] - cache3[row] - cache3[row+1];
			next_state = `SHARPEN_3;
			end
		`SHARPEN_3: begin									// Starea in care scriem pixelul filtrat obtinut anterior
			if(sharp_pix < 0) begin
				out_pix[15:8] = 0;
				end
			else if (sharp_pix > 255) begin
				out_pix[15:8] = 255;
				end
			else begin
				out_pix[15:8] = sharp_pix[7:0];
				end
			out_we = 1;
			if(row < 63) begin							// De aici incepe partea de incrementare
				next_row = row + 1;
				next_state = `SHARPEN_2;
				end
			else if (row == 63 && col < 63) begin
				next_row = 0;
				cache_right = 0;
				next_col = col + 1;
				next_state = `SHARPEN_1_1_1;
				end
			else if (row == 63 && col == 63) begin
				next_state = `SHARPEN_FINISH;
				end
			end
		`SHARPEN_FINISH: begin							// Terminarea taskului 3
				filter_done = 1;
				out_we = 0;
				next_state = `SHARPEN_FINISH;
				end
			
		default : begin
			next_state = `INIT;
			end
		
	endcase
end

endmodule
