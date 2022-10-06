; the size of the game screen in characters
%define HEIGHT 16
%define WIDTH 20

segment .data

		;this file contains a list of all the game boards,
		;and is used to dynamically fill boardArray
	gameBoards			db "boards/boards.txt",0
	menuBoard			db "menu.txt",0
		;these are the color codes used for various symbols
	playerColor			db	27,"[38;5;173m",0	
	helpStrColor		db	27,"[38;5;247m",0
	resetColor			db	27,"[0m",0
		;these colors are part of colorCodeArray
	plateUnderGem		db	27,"[1;48;5;249;38;5;9m",0
	wallColor			db	27,"[38;5;22m",0
	keyColor			db	27,"[38;5;220m",0
	rockColor			db	27,"[38;5;94m",0
	pressPlateColor		db	27,"[38;5;240m",0
	leverColor			db	27,"[38;5;69m",0
	pressDoorColor		db	27,"[38;5;242m",0
	stairsColor			db	27,"[38;5;124m",0
	buttonColor			db	27,"[38;5;14m",0
	activeBColor		db	27,"[38;5;1m",0
	gemColor			db	27,"[38;5;9m",0
	colorCodeArray		dd 	wallColor, keyColor, rockColor, pressPlateColor, \
							leverColor, pressDoorColor, stairsColor, buttonColor, \
							activeBColor, gemColor, plateUnderGem
		;used for the board render
	boardFormat			db "%s",0
		; used to change the terminal mode
	mode_r				db "r",0
	raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0
		; ANSI escape sequence to clear/refresh the screen
	clear_screen_code	db	27,"[2J",27,"[H",27,"[0m",0
		; things the program will print
	help_str			db 13,10,"Controls: w=UP / a=LEFT / s=DOWN / d=RIGHT / h=HINT / x=EXIT",13,10,0
	hintCarriage		db 13,0
	hintBlank			db 10,10,10,10,10,0
	hintNL				db 10,0
		;displays num keys
	key_str				db	"Num keys: %d",10,13,0
	win_str				db	27,"[2J",27,"[H", "You win!",13,10,0
		;all the possible characters that can be displayed on the game board
		;used to determine interactions between the rock and player chars
	possChars			db	"pTSRPA|LKl _Bb%Gg^*",0
	coordString			db	"%d %d",0

segment .bss

		; this array stores the current rendered gameboard (HxW)
	board		resb	(HEIGHT * WIDTH)
		;this array is used to store door characters when they are opened
	doorLayer	resb	(HEIGHT * WIDTH)
		; these variables store the current player position
	xpos		resd	1
	ypos		resd	1
		;These variables store various data for rendering
	colorCode	resd	1
	leverDoors	resd	1
	displayHint	resd	1
	hasKey		resd	1
	gameEnd		resd	1
	menuEnd		resd	1
	currentBoard	resd	1
	frameBuffer	resd	102400
		;this array tells the checkChar function what the character in front is
	lastChar	resb	1
	checkArr	resb	256
	rockArr		resb	256
		;This array stores the hint string read in from the board file.
	hintStr		resb	384
		;This array stores the names of all the game boards, and is dynamically
		;filled in loadBoards
	boardArray	resb	200
	STARTX		resd	1
	STARTY		resd	1
	menuX		resd	1
	menuY		resd	1
	spacePressed resd	1
		;stores the main menu
	mainMenu	resb	2048

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
	extern	fgets
	extern	fscanf
	extern	fclose
	extern 	sleep

main:
	push	ebp
	mov		ebp, esp
			; put the terminal in raw mode so the game works nicely
		call	raw_mode_on
			;populate boardArray with all the game boards
			;serves the same purpose as the boards array did
		call	loadBoards
		call	loadMenu
		call	menuLoop
			; restore old terminal functionality
		call raw_mode_off
	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

menuLoop:
	push	ebp
	mov		ebp, esp

		mov		eax, 14
		mov		DWORD [menuX], eax
		mov		eax, 11
		mov		DWORD [menuY], eax
		mov		DWORD [menuEnd], 0

		menu_loop:
			cmp		DWORD [menuEnd], 1
			je		menu_loop_end
	;			; draw the game board
			call	renderMenu
				; get an action from the user
			call	getchar
	;			; store the current position
	;			; we will test if the new position is legal
	;			; if not, we will restore these
			mov		esi, DWORD [menuX]
			mov		edi, DWORD [menuY]
	;			; choose what to do
	;			; check where to move the player based on input
			cmp		eax, 'w'
			je 		menuUp
			cmp		eax, 'a'
			je		menuLeft
			cmp		eax, 's'
			je		menuDown
			cmp		eax, 'd'	
			je		menuRight
			cmp		eax, 0x20
			je		menuSpace
			jmp		menu_loop
			menuUp:
				dec		DWORD [menuY]
				jmp		minputFound
			menuLeft:
				sub		DWORD [menuX], 16
				jmp		minputFound
			menuDown:
				inc		DWORD [menuY]
				jmp		minputFound
			menuRight:
				add		DWORD [menuX], 16
				jmp		minputFound
			menuSpace:
				jmp		minputFound
			minputFound:
				;save user input
			mov		ebx, eax

			mov		ecx, 0
			mov		eax, 50
			mul		DWORD [menuY]
			add		eax, DWORD [menuX]
			call	checkCharMenu

		jmp		menu_loop
		menu_loop_end:
	mov		esp, ebp
	pop		ebp
	ret

checkCharMenu:
	push	ebp
	mov		ebp, esp
		cmp		DWORD [menuX], esi
		jne		checkMove
		cmp		DWORD [menuY], edi
		jne		checkMove
			cmp		DWORD [menuX], 30
			jne		notClose
				inc		DWORD [menuEnd]
				jmp		moveCursor
			notClose:
			cmp		DWORD [menuX], 14
			jne		notGame
				call 	gameloop
				jmp		moveCursor
			notGame:
		checkMove:
		cmp		BYTE [mainMenu + eax], '-'
		jne		noMoveCursor
			jmp		moveCursor
		noMoveCursor:
		mov		DWORD [menuX], esi
		mov		DWORD [menuY], edi
		moveCursor:
	mov		esp, ebp
	pop		ebp
	ret

gameloop:
	push	ebp
	mov		ebp, esp
		GOHERE:
			;if the previous board was the last one, close the game
		mov		eax, 19
		mul		DWORD [currentBoard]
		cmp		BYTE [boardArray + eax], 0
		jne		validBoard
			inc		DWORD[gameEnd]
			jmp		game_loop
		validBoard:
			;display the initial board, or update it to the next one
		mov		eax, 19
		mul		DWORD [currentBoard]
		lea		ecx, [boardArray + eax]
		push	ecx
		call	init_board
		add		esp, 4
			;initialize the checkArr and rockArr arrays with all the possible board characters
			;these arrays are used later on for managing the interactions between the player and rock
			;objects with the rest of the game board
		call	init_arrs
			; set the player at the proper start position
		mov		eax, DWORD [STARTX]
		mov		DWORD [xpos], eax
		mov		eax, DWORD [STARTY]
		mov		DWORD [ypos], eax
		mov		DWORD [displayHint], 1
		mov		DWORD [leverDoors], 0
		mov		DWORD [hasKey], 0
		mov		DWORD [gameEnd], 0
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
			mov		DWORD [displayHint], 0
				; get an action from the user
			testing2:
			call	getchar
				; store the current position
				; we will test if the new position is legal
				; if not, we will restore these
			mov		esi, DWORD [xpos]
			mov		edi, DWORD [ypos]
				; choose what to do
				;If 'x', close the game
			cmp		eax, 'x'
			jne		contGame
				inc		DWORD [gameEnd]
				jmp		game_loop
			contGame:
				;check where to move the player based on input
			cmp		eax, 'w'
			je 		moveUp
			cmp		eax, 'a'
			je		moveLeft
			cmp		eax, 's'
			je		moveDown
			cmp		eax, 'd'	
			je		moveRight
			cmp		eax, 'h'
			je		showHint
			cmp		eax, 127
			je		resetBoard
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
			showHint:
				mov		DWORD [displayHint], 1
				jmp		inputFound
			resetBoard:
				jmp		validBoard
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

			cmp		DWORD[currentBoard], edx
			jne		GOHERE

		jmp		game_loop
		game_loop_end:

	mov		esp, ebp
	pop		ebp
	ret

loadMenu:
	push	ebp
	mov		ebp, esp
		sub		esp, 8
			;open the file
		push	mode_r
		push	menuBoard
		call	fopen
		add		esp, 8
			;free up eax
		mov		DWORD[ebp - 4], eax
			;initialize the indexer
		mov		DWORD [ebp - 8], 0
		topMenuLoop:
		mov		ecx, DWORD [ebp - 8]
		lea		edx, [mainMenu + ecx]
		cmp		eax, 0xffffffff
		je		endMenuLoop
				;read the line into boardArray
			push	DWORD [ebp - 4]
			push	51
			push	edx
			call	fgets
			add		esp, 12
				; slurp up the newline
			push	DWORD [ebp - 4]
			call	fgetc
			add		esp, 4
				;replace the new line with a null byte
		;	mov		ecx, DWORD [ebp - 8]
		;	mov		BYTE [mainMenu + ecx + 50], 0
		add		DWORD [ebp - 8], 50
		jmp		topMenuLoop
		endMenuLoop:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

renderMenu:
	push	ebp
	mov		ebp, esp
			; two ints, two for loop counters
			; ebp-4, ebp-8
		sub		esp, 8

		push	clear_screen_code
		call	printf
		add		esp, 4
			;initialize frame buffer index
		mov		ecx, 0
			; outside loop by height
			; i.e. for(c=0; c<height; c++)
		mov		DWORD [ebp - 4], 0
		my_loop_start:
		cmp		DWORD [ebp - 4], 21
		je		my_loop_end
				; inside loop by width
				; i.e. for(c=0; c<width; c++)
			mov		DWORD [ebp - 8], 0
			mx_loop_start:
			cmp		DWORD [ebp - 8], 50
			je 		mx_loop_end
					; check if (xpos,ypos)=(x,y)
				mov		eax, DWORD [menuX]
				cmp		eax, DWORD [ebp - 8]
				jne		mprint_board
				mov		eax, DWORD [menuY]
				cmp		eax, DWORD [ebp - 4]
				jne		mprint_board

					mov		BYTE [frameBuffer + ecx], '>'
					inc		ecx

					jmp		mprint_end
				mprint_board:
				mov		eax, DWORD [ebp - 4]
				mov		ebx, 50
				mul		ebx
				add		eax, DWORD [ebp - 8]
				mov		ebx, 0
				mov		bl, BYTE [mainMenu + eax]
				mov		BYTE [frameBuffer + ecx], bl
				inc		ecx
				mprint_end:
			inc		DWORD [ebp - 8]
			jmp		mx_loop_start
			mx_loop_end:
				; write a carriage return (necessary when in raw mode)
			mov		BYTE [frameBuffer + ecx], 0x0d
			inc		ecx
				; write a newline
			mov		BYTE [frameBuffer + ecx], 10
			inc		ecx
		inc		DWORD [ebp - 4]
		jmp		my_loop_start
		my_loop_end:

		push	frameBuffer
		push	boardFormat
		call	printf
		add		esp, 8
	mov		esp, ebp
	pop		ebp
	ret
checkCharTest:
	push	ebp
	mov		ebp, esp
		mov		edx, DWORD[currentBoard]
		cmp		BYTE [checkArr + ecx], ' '
		je		checkDone
		cmp		BYTE [checkArr + ecx], 'R'
		je		pRock
		cmp		BYTE [checkArr + ecx], 'P'
		je		checkDone
		cmp		BYTE [checkArr + ecx], 'L'
		je		pLever
		cmp		BYTE [checkArr + ecx], 'S'
		je		pStairs
		cmp		BYTE [checkArr + ecx], 'K'
		je		pKey
		cmp		BYTE [checkArr + ecx], 'B'
		je		pButton
		cmp		BYTE [checkArr + ecx], 'G'
		je		pGem
		jmp		pDefault
		pRock:
			call	pushRock
			jmp		checkDone
		pLever:
			cmp	DWORD [leverDoors], 0
			jne		isActive
				mov		DWORD [leverDoors], 1
				jmp		pDefault
			isActive:
			mov		DWORD [leverDoors], 0
			jmp		pDefault
		pStairs:
				; clear the screen and print winstr
			push	win_str
			call	printf
			add		esp, 4
				;hold that on the screen
			push	2
			call	sleep
			add		esp, 4
				;inc the board counter
			inc		DWORD [currentBoard]
			jmp		checkDone
		pKey:
			cmp		BYTE [board + eax], 'K'
			jne		notKey
				mov		BYTE [board + eax], ' '
				inc		DWORD [hasKey]
				jmp		checkDone
			notKey:
			cmp		DWORD [hasKey], 0
			je		noKeys
				mov		BYTE [board + eax], ' '
				dec		DWORD [hasKey]
			noKeys:
			jmp		pDefault
		pButton:
			cmp		BYTE [board + eax], 'B'
			jne		notButt
				mov		BYTE [board + eax], 'b'
				jmp		pDefault
			notButt:
			mov		BYTE [board + eax], 'B'
			jmp		pDefault
		pGem:
			cmp		BYTE [board + eax], 'g'
			jne		notPlateGem
				mov		BYTE [board + eax], 'P'
				jmp		checkDone
			notPlateGem:
			mov		BYTE [board + eax], ' '
			jmp		checkDone
		pDefault:
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
		checkDone:
	mov		esp, ebp
	pop		ebp
	ret

pushRock:
	push	ebp
	mov		ebp, esp
			;Check which direction the rock is moving
		cmp		ebx, 'w'
		je		nextDir1
		cmp		ebx, 'a'
		je		nextDir2
		cmp		ebx, 's'
		je		nextDir3
		cmp		ebx, 'd'
		je		nextDir4
		jmp		rockend
			;Load the address of the next space in the array 
			;according to the direction the rock is moivng
		nextDir1:
			lea		ebx, [board + eax - WIDTH]
			jmp		moveRock
		nextDir2:
			lea		ebx, [board + eax - 1]
			jmp		moveRock
		nextDir3:
			lea		ebx, [board + eax + WIDTH]
			jmp		moveRock
		nextDir4:
			lea		ebx, [board + eax + 1]
			jmp		moveRock
		moveRock:
			;Check if the character the rock was pushed into is a valid move
			;if not, reset the position of the player
		mov		cl, BYTE [ebx]
		cmp		BYTE [rockArr + ecx], 'x'
		jne		pathBlocked
			cmp		BYTE [board + eax], 'p'
			je		onPlate
			mov		BYTE [board + eax], ' '
			jmp		mvNext
			onPlate:
				mov		BYTE [board + eax], 'P'
			mvNext:
			cmp		BYTE [ebx], 'P'
			je		plateNext
			mov		BYTE [ebx], 'R'
			jmp		rockend
			plateNext:
				mov		BYTE [ebx], 'p'
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

loadBoards:
	push	ebp
	mov		ebp, esp
		sub		esp, 8
			; initialize currentBoard
		mov		DWORD [currentBoard], 0
			;open the file
		push	mode_r
		push	gameBoards
		call	fopen
		add		esp, 8
			;free up eax
		mov		DWORD[ebp - 4], eax
			;initialize the indexer
		mov		DWORD [ebp - 8], 0
		topReadLoop:
		mov		ecx, DWORD [ebp - 8]
		lea		edx, [boardArray + ecx]
		cmp		eax, 0
		je		endReadLoop
				;read the line into boardArray
			push	DWORD [ebp - 4]
			push	20
			push	edx
			call	fgets
			add		esp, 12
				;replace the new line with a null byte
			mov		ecx, DWORD [ebp - 8]
			mov		BYTE [boardArray + ecx + 18], 0
		add		DWORD [ebp - 8], 19
		jmp		topReadLoop
		endReadLoop:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
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
			;load the player's starting position
		push	STARTY
		push	STARTX
		push	coordString
		push	DWORD [ebp - 4]
		call	fscanf
		add		esp, 16
			;eat the new line
		push	DWORD [ebp - 4]
		call	fgetc
		add		esp, 4
			;load in the hint string
		mov		ebx, 0
		topInitLoop:
		cmp		ebx, 384
		je		endInitLoop
			lea		eax, [hintStr + ebx]
			push	DWORD [ebp - 4]
			push	128
			push	eax
			call	fgets
			add		esp, 12
		add		ebx, 128
		jmp		topInitLoop
		endInitLoop:
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
			;populate the door layer
		mov		ebx, 0
		mov		edx, WIDTH*HEIGHT
		mov		edi, 0
		doorLoop:
		cmp		edi, edx
		je		endDoorCheck
			mov		bl, BYTE [board + edi]
			cmp		bl, '|'
			je		yesPDoor
			cmp		bl, '_'
			je		yesLDoor
			cmp		bl, '%'
			je		yesBDoor
			cmp		bl, '*'
			je		yesgBDoor
			mov		BYTE [doorLayer + edi], 0
			jmp		noDoor
			yesPDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noDoor
			yesLDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noDoor
			yesBDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noDoor
			yesgBDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noDoor
			noDoor:
		inc		edi
		jmp		doorLoop
		endDoorCheck:
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
			; clear the screen
		push	clear_screen_code
		call	printf
		add		esp, 4
			;add color
		push	helpStrColor
		call	printf
		add		esp, 4
			; print the help information
		cmp		DWORD [displayHint], 0
		je		noHint
			push	hintNL
			call	printf
			add		esp, 4
			
			mov		ebx, 0
			hintLoopTop:
			cmp		ebx, 384
			je		hintLoopDone
				lea		ecx, [hintStr + ebx]
				push	ecx
				call	printf
				add		esp, 4
				push	hintCarriage
				call	printf
				add		esp, 4
			add		ebx, 128
			jmp		hintLoopTop
			hintLoopDone:

			push	hintNL
			call	printf
			add		esp, 4
			jmp		hintShown
		noHint:
			push	hintBlank
			call	printf
			add		esp, 4
		hintShown:
			;Print the key string
		push	DWORD[hasKey]
		push	key_str
		call	printf
		add		esp, 8
			;initialize frame buffer index
		mov		ecx, 0
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
					lea		edi, [playerColor]
					cmp		BYTE [edi + esi],0
					je		endPlayerColorLoop
						mov		dl, BYTE [edi + esi]
						mov		BYTE [frameBuffer + ecx], dl
						inc		ecx
					inc		esi
					jmp		playerColorLoop
					endPlayerColorLoop:
						;then add the player character to the buffer
					mov		BYTE [frameBuffer + ecx], 'O'
					inc		ecx
						;update lastChar
					mov		BYTE [lastChar], 'O'
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

layerSwap:
	push 	ebp
	mov		ebp, esp
		mov		bl, BYTE [board + eax]
		mov		dl, BYTE [doorLayer + eax] 
		mov		BYTE [board + eax], dl
		mov		BYTE [doorLayer + eax], bl
	mov		esp, ebp
	pop 	ebp
	ret

charRender:
	push	ebp
	mov		ebp, esp
		mov		edx, 0
			;compare the current byte to the various game objects, then
			;change the symbol and color accordingly
		cmp		BYTE [checkArr + ebx], ' '
		je		rSpace
		cmp		BYTE [checkArr + ebx], 'x'
		je		rWall
		cmp		BYTE [checkArr + ebx], 'K'
		je		rKey
		cmp		BYTE [checkArr + ebx], 'R'
		je		rRock
		cmp		BYTE [checkArr + ebx], 'P'
		je		rPlate
		cmp		BYTE [checkArr + ebx], 'L'
		je		rLever
		cmp		BYTE [checkArr + ebx], '_'
		je		rLeverDoor
		cmp		BYTE [checkArr + ebx], '|'
		je		rPlateDoor
		cmp		BYTE [checkArr + ebx], 'S'
		je		rStairs
		cmp		BYTE [checkArr + ebx], 'B'
		je		rButton
		cmp		BYTE [checkArr + ebx], '%'
		je		rButtDoor
		cmp		BYTE [checkArr + ebx], '*'
		je		rGButtDoor
		cmp		BYTE [checkArr + ebx], 'G'
		je		rGem
		cmp		BYTE [checkArr + ebx], '^'
		je		rGem
		jmp		rDefault
		rSpace:
			cmp		BYTE [doorLayer + eax], '|'
			jne		notPlateDoor
				jmp		rPlateDoor
			notPlateDoor:
			cmp		BYTE [doorLayer + eax], '_'
			jne		notLeverDoor
				jmp		rLeverDoor
			notLeverDoor:
			cmp		BYTE [doorLayer + eax], '%'
			jne		notButtonDoor
				jmp		rButtDoor
			notButtonDoor:
			cmp		BYTE [doorLayer + eax], '*'
			jne		notGButtonDoor
				jmp		rGButtDoor
			notGButtonDoor:
			jmp		redundantColor
		rWall:
			mov		DWORD [colorCode], 0
			jmp		rDefault
		rKey:
			mov		DWORD [colorCode], 1
			cmp		bl, 'A'
			jne		rDefault
				mov		bl, '#'
				jmp		rDefault
		rRock:
			mov		DWORD [colorCode], 2
			mov		bl, 'R'
			jmp		rDefault
		rPlate:
			mov		DWORD [colorCode], 3
			jmp		rDefault
		rLever:
			mov		DWORD [colorCode], 4
			cmp	DWORD [leverDoors], 0
			jne		isActive2
				mov		BYTE [board + eax], 'L'
				mov		bl, 'L'
				jmp		rDefault
			isActive2:
			mov		BYTE [board + eax], 'l'
			mov		bl, 'l'
			jmp		rDefault
		rLeverDoor:
			mov		DWORD [colorCode], 4
			cmp		DWORD [leverDoors], 0
			je		lDoorOpen
				;if leverdoors is 1, open lever doors
				cmp		BYTE [board + eax], '_'
				jne		lDoorLayer	
					call	layerSwap
				lDoorLayer:
				mov		bl, ' '
				jmp		rDefault
			;if leverdoors is 0, close the lever doors
			lDoorOpen:
			cmp		BYTE [board + eax], '_'
			je		nlDoorLayer	
				call	layerSwap
			nlDoorLayer:
			mov		bl, '#'
			jmp		rDefault
		rPlateDoor:
			mov		DWORD [colorCode], 3
			mov		edi, 0
			plateLoop:
			cmp		edi, WIDTH*HEIGHT
			je		noPlates
				cmp		BYTE [board + edi], 'P'
				jne		checkPlates
					;if a plate is found, close the plate doors
					cmp		BYTE [board + eax], '|'
					je		npDoorLayer	
						call	layerSwap
					npDoorLayer:
					mov		bl, '#'
					jmp		rDefault
				checkPlates:
			inc		edi
			jmp		plateLoop
				;if no plates are found, open plate doors
			noPlates:
				cmp		BYTE [board + eax], '|'
				jne		pDoorLayer	
					call	layerSwap
				pDoorLayer:
				mov		bl, ' '
				jmp		rDefault
			;Button Door
		rButtDoor:
			mov		DWORD [colorCode], 7
			mov		edi, 0
				;check the board layer for an inactive button
			testLoop:
			cmp		edi, WIDTH*HEIGHT
			je		testPassed
				cmp		BYTE [board + edi], 'b'
				jne		checkActive
					;if a button is found, close the button doors
					cmp		BYTE [board + eax], '%'
					je		nbDoorLayer	
						call	layerSwap
					nbDoorLayer:
					mov		bl, '#'
					jmp		rDefault
				checkActive:
			inc		edi
			jmp		testLoop
				;if a button is not found, open the button doors
			testPassed:
				cmp		BYTE [board + eax], '%'
				jne		bDoorLayer	
					call	layerSwap
				bDoorLayer:
				mov		bl, ' '
				jmp		rDefault
			;Grey Button Door
		rGButtDoor:
			mov		DWORD [colorCode], 8
			mov		edx, WIDTH*HEIGHT
			mov		edi, 0
				;check the board layer for an inactive button
			gtestLoop:
			cmp		edi, edx
			je		gtestFailed
				cmp		BYTE [board + edi], 'b'
				jne		gcheckActive
					;if a button is found, open the grey doors
					cmp		BYTE [board + eax], '*'
					jne		gbDoorLayer	
						call	layerSwap
					gbDoorLayer:
					mov		bl, ' '
					jmp		rDefault
				gcheckActive:
			inc		edi
			jmp		gtestLoop
				;if a button is not found, close the grey doors
			gtestFailed:
				cmp		BYTE [board + eax], '*'
				je		ngbDoorLayer	
					call	layerSwap
				ngbDoorLayer:
				mov		bl, '#'
				jmp		rDefault
			;stairs
		rStairs:
			mov		DWORD [colorCode], 6
			jmp		rDefault
		rButton:
			mov		DWORD [colorCode], 7
			jmp		rDefault
		rGem:
			mov		DWORD [colorCode], 9
			cmp		bl, 'g'
			jne		notGemPlate
				mov		DWORD [colorCode], 10
				mov		bl, 'G'
				jmp		rDefault
			notGemPlate:
			cmp		bl, '^'
			jne		notGemDoor
				mov		edx, WIDTH*HEIGHT
				mov		edi, 0
				gemLoop:
				cmp		edi, edx
				je		noGems
					cmp		BYTE [board + edi], 'G'
					je		gemsFound
					cmp		BYTE [board + edi], 'g'
					jne		checkGem
						jmp		gemsFound
					checkGem:
				inc		edi
				jmp		gemLoop
				noGems:
				mov		BYTE [board + eax], ' '
				mov		bl, ' '
				jmp		rDefault
				gemsFound:
				mov		bl, '#'
				jmp		rDefault
			notGemDoor:
			jmp	rDefault
		rDefault:
			;use the num in colorCode to load the correct code into edi
		mov		esi, DWORD[colorCode]
		mov		edi, DWORD[colorCodeArray + esi * 4]
			;if the character being loaded into the frame buffer isn't the same as the last one,
			;load each of the bytes for the color code into the frame buffer until we reach a null byte
		cmp		BYTE [lastChar], bl
		je		redundantColor
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
		redundantColor:
			;load the displayed character into the frame buffer
		mov		BYTE [frameBuffer + ecx], bl
		inc		ecx
			;save the last char that was moved into the buffer 
			;to prevent redudant color codes from being printed
		cmp		BYTE [board + eax], 'g'
		jne		nPlateGem
			mov		edi, resetColor
			mov		esi, 0
			resetColorLoop:
			cmp		BYTE [edi + esi],0
			je		endResetColorLoop
				mov		dl, BYTE [edi + esi]
				mov		BYTE [frameBuffer + ecx], dl
				inc		ecx
			inc		esi
			jmp		resetColorLoop
			endResetColorLoop:
		nPlateGem:
		mov		BYTE [lastChar], bl
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
				;if the character has special interractions, make note of it
				;otherwise, make checkArr[pos] == 'X'
			mov		al, BYTE [possChars + esi]
				;is it a space?
			cmp		al, ' '
			je		iSpace
				;is it a rock?
			cmp		al, 'R'
			je		isRock
				;is it a rock on a plate?
			cmp		al, 'p'
			je		isRock
				;is it a plate?
			cmp		al, 'P'
			je		isPlate
				;is it a closed plate door?
			cmp		al, '|'
			je		isPlateDoor
				;is it a lever 1?
			cmp		al, 'L'
			je		isLever
				;is it a lever 2?
			cmp		al, 'l'
			je		isLever
				;is it stairs?
			cmp		al, 'S'
			je		isStairs
				;is it a key?
			cmp		al, 'K'
			je		isKey
				;is it a key door?
			cmp		al, 'A'
			je		isKey
				;is it a closed lever door?
			cmp		al, '_'
			je		isLDoor
				;is it a button?
			cmp		al, 'B'
			je		isButton
				;is it an active button?
			cmp		al, 'b'
			je		isButton
				;is it a closed button door?
			cmp		al, '%'
			je		isButtDoor
				;is it a gem?
			cmp		al, 'G'
			je		isGem
				;is it a gem on a plate?
			cmp		al, 'g'
			je		isGem
				;is it a gem door?
			cmp		al, '^'
			je		isGemDoor
				;is it a gButton door?
			cmp		al, '*'
			je		isgButtDoor
			jmp		defaultOpt
			iSpace:
				mov		BYTE [checkArr + eax], ' '
				mov		BYTE [rockArr + eax], 'x'
				jmp		charPut
			isRock:
				mov		BYTE [checkArr + eax], 'R'
				jmp		charPut
			isPlate:
				mov		BYTE [checkArr + eax], 'P'
				mov		BYTE [rockArr + eax], 'x'
				jmp		charPut
			isPlateDoor:
				mov		BYTE [checkArr + eax], '|'
				jmp		charPut
			isLever:
				mov		BYTE [checkArr + eax], 'L'
				jmp		charPut
			isStairs:
				mov		BYTE [checkArr + eax], 'S'
				jmp		charPut
			isKey:
				mov		BYTE [checkArr + eax], 'K'
				jmp		charPut
			isLDoor:
				mov		BYTE [checkArr + eax], '_'
				jmp		charPut
			isButton:
				mov		BYTE [checkArr + eax], 'B'
				jmp		charPut
			isButtDoor:
				mov		BYTE [checkArr + eax], '%'
				jmp		charPut
			isGem:
				mov		BYTE [checkArr + eax], 'G'
				jmp		charPut
			isGemDoor:
				mov		BYTE [checkArr + eax], '^'
				jmp		charPut
			isgButtDoor:
				mov		BYTE [checkArr + eax], '*'
				jmp		charPut
			defaultOpt:
				mov		BYTE [checkArr + eax], 'x'
			charPut:
		inc		esi
		jmp		arrLoop
		endArrLoop:
	mov		esp, ebp
	pop		ebp
	ret