.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Maxim Francesco-Snake",0
area_width EQU 600
area_height EQU 600
area DD 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

snakex DD 100,110,120,130,140,150, 100 dup(0)
snakey DD 100,100,100,100,100,100, 100 dup(0)
lungime DD 6
buffer DD 0
patru DD 4
appleX DD 200
appleY DD 250
const DD 50
zece DD 10

symbol_width EQU 10
symbol_height EQU 20
include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	cmp byte ptr [esi], 2
	je simbol_pixel_rosu
	cmp byte ptr [esi], 3
	je simbol_pixel_verde
	cmp byte ptr [esi], 4
	je simbol_pixel_albastru
	
	mov dword ptr [edi], 255
	jmp simbol_pixel_next
	
simbol_pixel_rosu:
	mov dword ptr [edi], 0FF0000h
	jmp simbol_pixel_next
	
simbol_pixel_albastru:
	mov dword ptr [edi], 00000FFh
	jmp simbol_pixel_next
	
simbol_pixel_verde:
	mov dword ptr [edi], 000FF00h
	jmp simbol_pixel_next
	
simbol_pixel_alb:
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
	
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 3 ;daca e 3 atunci s-a apasat o tasta
	jz evt_click
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	jmp afisare_litere
	
evt_click: ;aici se ajunge daca s-a apasat o tasta
	mov eax,[ebp+arg2] ; in ebp+arg2 avem ascii-ul tastei apasate
stanga: ;iar de aici in jos vedem daca tasta apasata e W,A,S,D
	cmp eax,041h ;->DACA E A atunci punem buffer pe 0,la noi bufferul e directia de mers a sarpelui
	jne dreapta ;daca nu e A mergem mai departe si verificam daca e D,S,W
	mov buffer,0 ;0->stanga,1->dreapta,2->jos,3->sus pentru buffer
	jmp evt_timer
dreapta:
	cmp eax,044h
	jne jos
	mov buffer,1
	jmp evt_timer
jos:
	cmp eax,053h
	jne sus
	mov buffer,2
	jmp evt_timer
sus:
	cmp eax,057h
	jne evt_timer
	mov buffer,3
	jmp evt_timer
	
	
evt_timer: ;aici se verifica la fiecare frame daca capul sarpelui loveste marul
	mov ebx,appleX ;daca capul sarpelui are coordonatele egale cu marul atunci l-a lovit
	cmp [snakex],ebx
	jne next
	mov ebx,appleY
	cmp [snakey],ebx
	jne next
	;aici ajunge daca l-a lovit
	rdtsc ;si generam un nou mar prima data cu rdtsc care pune o valoare random in EAx
	mov edx,0 
	div const ;IMPARTIM cu 60 deci restul care va fi in edx (vezi in laborator) va fi intre 0-59
	mov eax,0
	mov eax,edx ;mutam restul in eax
	mul zece ;inmultim cu 10 si acum avem o valoare intre 0-590 care va fi x -UL MARULUI 
	add eax,zece ;am adunat cu 10 in caz de ar fi 0 
	mov appleX,eax ;actualizam X-ul marului 
	rdtsc ;analog pentru Y-ul marului 
	mov edx,0
	div const
	mov eax,0
	mov eax,edx
	mul zece
	add eax,zece
	mov appleY,eax
	;0-200,450
	;450, 0-200
	;300-590,300
primul: ;aici verific sa nu se genereze marul intr-un perete , are 2,3 scapari dar nu stiu exact cum se repara
	cmp appleX,200
	jg doilea
	cmp appleY,450
	je evt_timer
doilea:
	cmp appleX,450
	jne treilea
	cmp appleY,200
	jg treilea
	jmp evt_timer
treilea:
	cmp appleX,300
	jl next10
	cmp appleY,300
	je evt_timer
next10:
	
marire_snake: ;aici maresc snake-ul ,el are pentru x si y 2 vectori,maresc lungimea vectorului si pun pe 
;ultima pozitie inca "un patrat"
	lea esi, snakex
	lea edi, snakey
	
	mov eax,lungime
	dec eax
	mul patru
	add esi, eax
	add edi, eax
	
	mov ebx, [esi]
	add ebx,10
	mov [esi + 4], ebx
	mov ebx,[edi]
	mov [edi + 4],ebx
	
	inc lungime
	

next: ;aici verfic daca loveste vreun perete 
	cmp [snakex],10 ;stanga
	jl you_lose
	cmp [snakex],580 ;dreapta 
	jg you_lose
	cmp [snakey],20 ; sus
	jl you_lose
	cmp [snakey],579 ;jos
	jg you_lose
	;0-200,450 asta e cel de pe orizontala etc
	cmp [snakey],450 
	jne next5
	cmp [snakex],200
	jg next5
	jmp you_lose
	
	
next5:
;0-200,450
	;450, 0-200
	;300-590,300
	
	cmp [snakex],450
	jne next6
	cmp [snakey],200
	jl you_lose
	
	
next6:

	cmp [snakey],300
	jne next7
	cmp [snakex],300
	jl next7
	jmp you_lose
	
next7:
	
;aici e actualizarea sarpelui 
;la fiecare frame "shiftam" vectorul pana la primul element o sa vezi imd
;gen daca inainte vectorul x era 100->110->120->130
;dupa shiftare avem 100->100->110->120
;practic urmam toate valorile din vector dupa cap-ul lui
	mov eax,0
	mov eax,lungime
	mul patru
	sub eax,4
	bucla1:
	mov ebx,[snakex-4+eax]
	mov [snakex+eax],ebx
	mov ebx,[snakey-4+eax]
	mov [snakey+eax],ebx
	sub eax,4
	cmp eax,0
	jne bucla1
	
;aici vedem in ce directie merge si vedem ce operatie facem
mergi_stanga:
	cmp buffer,0 ;deci daca e in stanga scadem "capul sarpelui"/prima valoare cu 10
	jne mergi_drepta
	sub [snakex],10 ;deci din vectorul 100->100->110->120 acum avem 90->100->110,120,deci s-a dus la stanga
	jmp afisare_litere
mergi_drepta: ;analog pentru toate cazurile
	cmp buffer,1
	jne mergi_jos
	add [snakex],10
	jmp afisare_litere
mergi_jos:
	cmp buffer,2
	jne mergi_sus
	add [snakey],10
	jmp afisare_litere
mergi_sus:
	cmp buffer,3
	jne afisare_litere
	sub [snakey],10
	jmp afisare_litere
	inc counter
		
afisare_litere:


;--------------------------------
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 0
	push area
	call memset
	add esp, 12
;------------------------partea asta redeseneaza la fiecare frame tot jocul 	
	make_text_macro 'M',area,appleX,appleY	;aici se afiseaza marul 
	jmp wq
	you_lose: ;mai sus cand verificam daca loveste vreun perete ii dadeam jump aici
	mov buffer,10 ;->mutam in buffer 10 deci sarpele nu se mai misca (valori pentru care se misca:0,1,2,3)
	make_text_macro 'L',area,300,50 ;mesaj LOse
	make_text_macro '0',area,310,50
	make_text_macro 'S',area,320,50
	make_text_macro 'E',area,330,50
	mov eax,[ebp+arg2] ;aici verificam daca playerul apasa Q ->QUIT
	cmp eax,051h
	je quit
	cmp eax,052h ;aici verificam daca playerul apasa R->RESET
	jne q 
	mov [snakex],100 ;daca apasa R restauram valorile si luam jocul de la capat
	mov [snakex+4],110 ;aici cand dau reset pun un sarpe de lungime 3
	mov [snakex+8],120
	mov [snakey],100
	mov [snakey+4],100
	mov [snakey+8],100
	mov lungime,3
	mov buffer,0
	mov appleX,100
	mov appleY,150
	jmp afisare_litere
	q:
	wq:
	
	;de aici in jos sunt desenati peretii
	mov ecx,580
	bucla3:
	make_text_macro 'O',area,0,ecx
	loop bucla3
	
	mov ecx,580
	bucla4:
	make_text_macro 'O',area,590,ecx
	loop bucla4
	
	mov ecx,580
	bucla5:
	make_text_macro 'O',area,ecx,0
	loop bucla5
	
	mov ecx,580
	bucla6:
	make_text_macro 'O',area,ecx,580
	loop bucla6
	mov ecx,200
	bucla7:
	make_text_macro 'O',area,ecx,450
	loop bucla7
	mov ecx,200
	bucla8:
	make_text_macro 'O',area,450,ecx
	loop bucla8
	
	mov ecx,590
	bucla9:
	make_text_macro 'O',area,ecx,300
	cmp ecx,300
	jl afara
	loop bucla9
	afara:
	
	
	
;afisare	sarpe
	mov ecx,0
	mov ecx,lungime
	mov ebx,0
	bucla:
	make_text_macro 'I',area,[snakex+ebx],[snakey+ebx]
	add ebx,4
	loop bucla


final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	quit:
	push 0
	call exit
end start
