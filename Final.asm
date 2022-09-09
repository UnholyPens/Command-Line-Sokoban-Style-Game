	; how to represent everything
%define WALL_CHAR 'T'
%define PLAYER_CHAR 'O'
%define	KEY_DOOR_CHAR 'A'
%define	KEY_CHAR 'K'
%define	ROCK_CHAR1 'B'
%define	ROCK_CHAR2 'p'
%define PRESS_CHAR 'P'
%define PRESS_DOOR_CHAR1 '|'
%define	PRESS_DOOR_CHAR2 '\'
%define LEVER_CHAR1 'L'
%define	LEVER_CHAR2 'l'
%define	LEVER_DOOR_CHAR1 '_'
%define	LEVER_DOOR_CHAR2 'j'
%define EMPTY_CHAR ' '
; the size of the game screen in characters
%define HEIGHT 14
%define WIDTH 34
	; the player starting position.
	; top left is considered (0,0)
%define STARTX 1
%define STARTY 1
	; these keys do things
%define HELPCHAR 'h'
%define EXITCHAR 'x'
%define UPCHAR 'w'
%define LEFTCHAR 'a'
%define DOWNCHAR 's'
%define RIGHTCHAR 'd'

segment .data

		; used to fopen() the board file defined above
	board1_file			db "board2.txt",0
	board2_file			db "board.txt",0
	board3_file			db "board3.txt",0
	boards				dd board1_file,board2_file,board3_file
		;these are the color codes used for various symbols
	playerColor			db	27,"[38;5;173m",0	
	helpStrColor		db	27,"[38;5;247m",0
	resetColor			db	27,"[0m",0
		;these colors are part of colorCodeArray
	wallColor			db	27,"[38;5;22m",0
	keyColor			db	27,"[38;5;220m",0
	rockColor			db	27,"[38;5;94m",0
	pressPlateColor		db	27,"[38;5;240m",0
	leverColor			db	27,"[38;5;69m",0
	pressDoorColor		db	27,"[38;5;242m",0
	stairsColor			db	27,"[38;5;124m",0
	colorCodeArray		dd 	wallColor, keyColor, rockColor, pressPlateColor, leverColor, pressDoorColor, stairsColor
		;used for the board render
	boardFormat			db "%s",0
		; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0
		; ANSI escape sequence to clear/refresh the screen
	clear_screen_code	db	27,"[2J",27,"[H",0
		; things the program will print
	help_str			db 13,10,"Controls: ", \
							UPCHAR,"=UP / ", \
							LEFTCHAR,"=LEFT / ", \
							DOWNCHAR,"=DOWN / ", \
							RIGHTCHAR,"=RIGHT / ", \
							HELPCHAR,"=HINT / ", \
							EXITCHAR,"=EXIT", \
							13,10,10,0
		;displays num keys
	key_str				db	"Num keys: %d",10,13,0
	win_str				db	"You win!",13,10,0
		;all the possible characters that can be displayed on the game board
		;used to determine interactions between the rock and player chars
	possChars			db	"pTSBPA|LKlj \_",0

segment .bss

		; this array stores the current rendered gameboard (HxW)
	board		resb	(HEIGHT * WIDTH)
		; these variables store the current player position
	xpos		resd	1
	ypos		resd	1
		;These variables store various data for rendering
	colorCode	resd	1
	leverDoors	resd	1
	plateDoors	resd	1
	hasKey		resd	1
	gameEnd		resd	1
	currentBoard	resd	1
	frameBuffer	resd	102400
		;this array tells the checkChar function what the character in front is
	checkArr	resb	256
	rockArr		resb	256

segment .text

	global	main
	global  raw_mode_on
	global  raw_mode_off
	global  init_board
	global  render

	extern	system
	extern	putchar
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fclose
	extern 	sleep

main:
	push	ebp
	mov		ebp, esp
			; put the terminal in raw mode so the game works nicely
		call	raw_mode_on
			; read the game board file into the global variable
		mov		DWORD [currentBoard], 0
		GOHERE:
			;display the initial board, or update it to the next one
		mov		eax, DWORD [currentBoard]
		push	DWORD [boards + eax * 4]
		call	init_board
			;initialize the checkArr and rockArr arrays with all the possible board characters
			;these arrays are used later on for managing the interactions between the player and rock
			;objects with the rest of the game board
		call	init_arrs
			; set the player at the proper start position
		mov		DWORD [xpos], STARTX
		mov		DWORD [ypos], STARTY
		mov		DWORD [leverDoors], 0
		mov		DWORD [plateDoors], 0
		mov		DWORD [hasKey], 0
		mov		DWORd [gameEnd], 0
			; the game happens in this loop
			; the steps are...
			;   1. render (draw) the current board
			;   2. get a character from the user
			;	3. store current xpos,ypos in esi,edi
			;	4. update xpos,ypos based on character from user
			;	5. check what's in the buffer (board) at new xpos,ypos
			;	6. if it's a wall, reset xpos,ypos to saved esi,edi
			;	7. otherwise, just continue! (xpos,ypos are ok)
		game_loop:
			cmp		DWORD [gameEnd], 1
			je		game_loop_end	
				; draw the game board
			call	render
				; get an action from the user
			call	getchar
				; store the current position
				; we will test if the new position is legal
				; if not, we will restore these
			mov		esi, DWORD [xpos]
			mov		edi, DWORD [ypos]
				; choose what to do
				;If exitchar, close the game
			cmp		eax, EXITCHAR
			jne		contGame
				inc		DWORD [gameEnd]
				jmp		game_loop
			contGame:
				;check where to move the player based on input
			cmp		eax, UPCHAR
			je 		moveUp
			cmp		eax, LEFTCHAR
			je		moveLeft
			cmp		eax, DOWNCHAR
			je		moveDown
			cmp		eax, RIGHTCHAR	
			je		moveRight
			jmp		inputFound
			moveUp:
				dec		DWORD [ypos]
				jmp		inputFound
			moveLeft:
				dec		DWORD [xpos]
				jmp		inputFound
			moveDown:
				inc		DWORD [ypos]
				jmp		inputFound
			moveRight:
				inc		DWORD [xpos]
				jmp		inputFound
			inputFound:
				;save user input
			mov		ebx, eax
				; take the potential new pos for the player, and see if it's valid
				; (W * y) + x = pos
			mov		ecx, 0
			mov		eax, WIDTH
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
			mov		cl, BYTE [board + eax]	
			call	checkCharTest
		jmp		game_loop
		game_loop_end:
			; restore old terminal functionality
		call raw_mode_off
	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

checkCharTest:
	push	ebp
	mov		ebp, esp
		cmp		BYTE [checkArr + ecx], 120
		je		pBlocked
		cmp		BYTE [checkArr + ecx], 66
		je		pRock
		cmp		BYTE [checkArr + ecx], 112
		je		pRock
		jmp		checkDone
		pBlocked:
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
			jmp 	checkDone
		pRock:
			call	pushRock
		checkDone:
	mov		esp, ebp
	pop		ebp
	ret

pushRock:
	push	ebp
	mov		ebp, esp
			;Check which direction the rock is moving
		cmp		ebx, UPCHAR
		je		nextDir1
		cmp		ebx, LEFTCHAR
		je		nextDir2
		cmp		ebx, DOWNCHAR
		je		nextDir3
		cmp		ebx, RIGHTCHAR
		je		nextDir4
		jmp		rockend
			;Load the address of the next space in the array 
			;according to the direction the rock is moivng
		nextDir1:
			lea		ebx, BYTE [board + eax - WIDTH]
			jmp		moveRock
		nextDir2:
			lea		ebx, BYTE [board + eax - 1]
			jmp		moveRock
		nextDir3:
			lea		ebx, BYTE [board + eax + WIDTH]
			jmp		moveRock
		nextDir4:
			lea		ebx, BYTE [board + eax + 1]
			jmp		moveRock
		moveRock:
			;Check if the character the rock was pushed into is a valid move
			;if not, reset the position of the player
		mov		cl, BYTE [ebx]
		cmp		BYTE [rockArr + ecx], 120
		jne		pathBlocked
				;if the rock is pushed onto a plate, open the plate doors
			cmp		BYTE [ebx], PRESS_CHAR
			jne		notOnPlate
				mov		DWORD [plateDoors], 1
				jmp		notOffPlate
			notOnPlate:
				;if the rock is pushed off of a plate, close the plate doors
			cmp		BYTE [board + eax], ROCK_CHAR2
			jne		notOffPlate
				mov		DWORD [plateDoors], 0
				mov		BYTE [board + eax], PRESS_CHAR
				jmp		movedOffPlate
			notOffPlate:
				;if rock wasn't on a plate and can move, replace it
				;with empty space
			mov		BYTE [board + eax], EMPTY_CHAR
			movedOffPlate:
				;if platedoors == 1, move boulder-on-plate into EBX, else
				;move boulder into EBX
			cmp		DWORD [plateDoors], 1
			jne		doorsClosed
				mov		BYTE [ebx], ROCK_CHAR2
				jmp		doorsOpen
			doorsClosed:
				mov		BYTE [ebx], ROCK_CHAR1
			doorsOpen:
			jmp		rockend
		pathBlocked:
		mov		DWORD [xpos], esi
		mov		DWORD [ypos], edi
		rockend:
	mov		esp, ebp
	pop		ebp
	ret

raw_mode_on:
	push	ebp
	mov		ebp, esp
		push	raw_mode_on_cmd
		call	system
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

raw_mode_off:
	push	ebp
	mov		ebp, esp
		push	raw_mode_off_cmd
		call	system
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

init_board:
	push	ebp
	mov		ebp, esp
			; FILE* and loop counter
			; ebp-4, ebp-8
		sub		esp, 8
			; open the file
		push	mode_r
		push	DWORD[ebp + 8]
		call	fopen
		add		esp, 8
		mov		DWORD [ebp - 4], eax
			; read the file data into the global buffer
			; line-by-line so we can ignore the newline characters
		mov		DWORD [ebp - 8], 0
		read_loop:
		cmp		DWORD [ebp - 8], HEIGHT
		je		read_loop_end
				; find the offset (WIDTH * counter)
			mov		eax, WIDTH
			mul		DWORD [ebp - 8]
			lea		ebx, [board + eax]
				; read the bytes into the buffer
			push	DWORD [ebp - 4]
			push	WIDTH
			push	1
			push	ebx
			call	fread
			add		esp, 16
				; slurp up the newline
			push	DWORD [ebp - 4]
			call	fgetc
			add		esp, 4
		inc		DWORD [ebp - 8]
		jmp		read_loop
		read_loop_end:
			; close the open file handle
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

render:
	push	ebp
	mov		ebp, esp
			; two ints, two for loop counters
			; ebp-4, ebp-8
		sub		esp, 8
			;initialize frame buffer index
		mov		ecx, 0
			; clear the screen
		push	clear_screen_code
		call	printf
		add		esp, 4
			;add color
		push	helpStrColor
		call	printf
		add		esp, 4
			; print the help information
		push	help_str
		call	printf
		add		esp, 4
			;Print the key string
		push	DWORD[hasKey]
		push	key_str
		call	printf
		add		esp, 8
			; outside loop by height
			; i.e. for(c=0; c<height; c++)
		mov		DWORD [ebp - 4], 0
		y_loop_start:
		cmp		DWORD [ebp - 4], HEIGHT
		je		y_loop_end
				; inside loop by width
				; i.e. for(c=0; c<width; c++)
			mov		DWORD [ebp - 8], 0
			x_loop_start:
			cmp		DWORD [ebp - 8], WIDTH
			je 		x_loop_end
					; check if (xpos,ypos)=(x,y)
				mov		eax, DWORD [xpos]
				cmp		eax, DWORD [ebp - 8]
				jne		print_board
				mov		eax, DWORD [ypos]
				cmp		eax, DWORD [ebp - 4]
				jne		print_board
						; if both were equal, put the player into the frame buffer
						; first, add the player's color code to the buffer
					mov		esi, 0
					playerColorLoop:
					lea		edi, playerColor
					cmp		BYTE [edi + esi],0
					je		endPlayerColorLoop
						mov		dl, BYTE [edi + esi]
						mov		BYTE [frameBuffer + ecx], dl
						inc		ecx
					inc		esi
					jmp		playerColorLoop
					endPlayerColorLoop:
						;then add the player characer to the buffer
					mov		BYTE [frameBuffer + ecx], PLAYER_CHAR
					inc		ecx
					jmp		print_end
				print_board:
						; otherwise print whatever's in the buffer
					mov		eax, DWORD [ebp - 4]
					mov		ebx, WIDTH
					mul		ebx
					add		eax, DWORD [ebp - 8]
					mov		ebx, 0
					mov		bl, BYTE [board + eax]
						;render the character
					call	charRender
				print_end:
			inc		DWORD [ebp - 8]
			jmp		x_loop_start
			x_loop_end:
				; write a carriage return (necessary when in raw mode)
			mov		BYTE [frameBuffer + ecx], 0x0d
			inc		ecx
				; write a newline
			mov		BYTE [frameBuffer + ecx], 10
			inc		ecx
		inc		DWORD [ebp - 4]
		jmp		y_loop_start
		y_loop_end:
		push	frameBuffer
		push	boardFormat
		call	printf
		add		esp, 8
	mov		esp, ebp
	pop		ebp
	ret

charRender:
	push	ebp
	mov		ebp, esp
			;compare the current byte to the various game objects, then
			;change the symbol and color accordingly, if it's not a space
		cmp		bl, EMPTY_CHAR
		je		isSpace
				;wall
			cmp		bl, WALL_CHAR
			jne		noWall
				mov		DWORD [colorCode], 0
			noWall:
				;Key
			cmp		bl, KEY_CHAR
			jne		noKey
				mov		DWORD [colorCode], 1
			noKey:
				;key door
			cmp		bl, KEY_DOOR_CHAR
			jne		noKeyDoor
				mov		DWORD [colorCode], 1
				mov		bl, PRESS_DOOR_CHAR1
			noKeyDoor:
				;stairs
			cmp		bl, 'S'
			jne		notStairs
				mov		BYTE [colorCode], 6
			notStairs:
				;pressure plate
			cmp		bl, PRESS_CHAR
			je		isPressed
			cmp		bl, ROCK_CHAR1
			je		isPressed
			cmp		bl,	ROCK_CHAR2
			jne		not_pressed
			isPressed:
				cmp		bl,	PRESS_CHAR
				jne		notRock
					mov		DWORD [colorCode], 3
					jmp		not_pressed
				notRock:
				mov		DWORD [colorCode], 2
				mov		bl, 'B'
			not_pressed:
				;Lever
			cmp		bl, LEVER_CHAR1
			je		yesLever
			cmp		bl,	LEVER_CHAR2
			jne		noLever
			yesLever:
				mov		DWORD [colorCode], 4
			noLever:
				;Pressure plate door
			cmp		BYTE [board + eax], PRESS_DOOR_CHAR1
			je		isPressDoor
			cmp		BYTE [board + eax], PRESS_DOOR_CHAR2
			jne		notPressDoor
			isPressDoor:	
				cmp		DWORD [plateDoors], 1
				jne		pressNotOpen
					mov		BYTE [board + eax], PRESS_DOOR_CHAR2
					mov		bl, EMPTY_CHAR
					jmp		pressOpen
				pressNotOpen:
				cmp		DWORD [plateDoors], 0
				jne		pressOpen
					mov		BYTE [board + eax], PRESS_DOOR_CHAR1
					mov		bl, PRESS_DOOR_CHAR1
				pressOpen:
				mov		DWORD [colorCode], 5
			notPressDoor:
				;Lever door
			cmp		BYTE [board + eax], LEVER_DOOR_CHAR1
			je		isLeverDoor
			cmp		BYTE [board + eax], LEVER_DOOR_CHAR2
			jne		notLeverDoor
			isLeverDoor:
				cmp		DWORD [leverDoors], 1
				jne		leverNotOpen
					mov		BYTE [board + eax], LEVER_DOOR_CHAR2
					mov		bl, EMPTY_CHAR
					jmp		leverOpen
				leverNotOpen:
				cmp		DWORD [leverDoors], 0
				jne		leverOpen
					mov		BYTE [board + eax], LEVER_DOOR_CHAR1
					mov		bl, LEVER_DOOR_CHAR1
				leverOpen:
				mov		DWORD [colorCode], 4
			notLeverDoor:
				;use the num in colorCode to load the correct code into edi
			mov		esi, DWORD[colorCode]
			mov		edi, DWORD[colorCodeArray + esi * 4]
				;load each of the bytes for the color code into the frame buffer until we reach a null byte
			mov		esi, 0
			colorLoop:
			cmp		BYTE [edi + esi],0
			je		endColorLoop
				mov		dl, BYTE [edi + esi]
				mov		BYTE [frameBuffer + ecx], dl
				inc		ecx
			inc		esi
			jmp		colorLoop
			endColorLoop:
				;load the actual character into the frame buffer
			mov		BYTE [frameBuffer + ecx], bl
			inc		ecx
			jmp		done
		isSpace:
			;load the actual character into the frame buffer
		mov		BYTE [frameBuffer + ecx], bl
		inc		ecx
		done:
	mov		esp, ebp
	pop		ebp
	ret

init_arrs:
	push	ebp
	mov		ebp, esp
		mov		esi, 0
		mov		eax, 0
		arrLoop:
			;loop through the board characters, making note of every one we come across
		cmp		BYTE [possChars + esi], 0
		je		endArrLoop
				;compare the board location to a space, do stuff if it's not
			cmp		BYTE [possChars + esi], 32
			je		charSpace
					;if the character has special interractions, make note of it
					;otherwise, make checkArr[pos] == 'X'
				mov		al, BYTE [possChars + esi]
					;is it a B?
				cmp		BYTE [possChars + esi], 66
				je		isRock
					;is it a P?
				cmp		BYTE [possChars + esi], 80
				je		isPlate
					;is it a rock on a plate?
				cmp		BYTE [possChars + esi], 112
				je		isRock
				jmp		defaultOpt
				isRock:
					mov		BYTE [checkArr + eax], 66
					jmp		charSpace
				isPlate:
					mov		BYTE [checkArr + eax], 80
					jmp		charSpace
				defaultOpt:
				mov		BYTE [checkArr + eax], 120
			charSpace:
		inc		esi
		jmp		arrLoop
		endArrLoop:

		mov		esi, 0
		mov		eax, 0
		arrLoop2:
			;loop through the board characters, making note of every one we come across
		cmp		BYTE [possChars + esi], 0
		je		endArrLoop2
				;is it a valid place for the rock to move? 
				;if it is, put an X at the appropriate location in rockArr
			cmp		BYTE [possChars + esi], 32
			je		validChar
			cmp		BYTE [possChars + esi], 80
			je		validChar
			jmp		blocked
			validChar:
				mov		al, BYTE [possChars + esi]
				mov		BYTE [rockArr + eax], 120
			blocked:
		inc		esi
		jmp		arrLoop2
		endArrLoop2:
	mov		esp, ebp
	pop		ebp
	ret