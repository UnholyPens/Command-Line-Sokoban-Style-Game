segment .data
		;this file contains a list of all the game boards,
		;and is used to dynamically fill boardList
	gameBoards			db "boards/boards.txt",0
		;these two files make up the two menu screens
	menuBoard			db "menu.txt",0
	levSelBoard			db "menu2.txt",0
		;these are the color codes used for various symbols
		;these colors are also part of colorCodeArray
	playerColor			db	27,"[38;5;173m",0
	helpStrColor		db	27,"[38;5;247m",0
	resetColor			db	27,"[0m",0
	keyColor			db	27,"[38;5;220m",0
	rockColor			db	27,"[38;5;94m",0
	rock2Color			db	27,"[38;5;7m",0
	pressColor			db	27,"[1;48;5;240;38;5;248m",0
	leverColor			db	27,"[38;5;69m",0
	pressDoorColor		db	27,"[38;5;242m",0
	stairsColor			db	27,"[38;5;124m",0
	buttonColor			db	27,"[38;5;14m",0
	activeBColor		db	27,"[38;5;13m",0
	gemColor			db	27,"[38;5;9m",0
	menuOptColor		db	27,"[38;5;240m",0
	colorCodeArray		dd 	wallColor,    keyColor,       rockColor,   pressColor, \
							leverColor,   pressDoorColor, stairsColor, buttonColor, \
							activeBColor, gemColor,       menuOptColor,wallColor2, \
							playerColor,  rock2Color
		;used for the board render
	boardFormat			db "%s",0
		;used as the format string for reading from files
	mode_r				db "r",0
		;ANSI escape sequence to clear/refresh the screen
	clear_screen_code	db	27,"[2J",27,"[H",27,"[0m",0
		;the blank space that gets pinted when the hint is not displayed
	hintBlank			db 10,10,10,10,10,0
		;displayed when a level is completed
	win_str				db	27,"[2J",27,"[H", "Level complete!",13,10,0
	waitStr				db	"Press Enter to continue.",13,10,0
		;this is where the coordinates loaded from a board file are stored
	coordString			db	"%d %d",0

segment .bss
		; this array stores the current rendered gameboard (HxW)
	board		resb	432
		;this array is used for changing states of doors
	doorLayer	resb	432
		;same as the door layer, but for floor objects, like water and plates
	floorLayer	resb	432
		;these variables store the current player position
	xpos		resd	1
	ypos		resd	1
		;used for navigating the menu screens
	foundOpt	resd	1
		;used for looking into colorCodeArray
	colorCode	resd	1
		;used for reseting color codes
	resColor	resd	1
		;used for displaying the hint text
	displayHint	resd	1
		;used for exiting to menu
	gameEnd		resd	1
		;used for exiting the game
	menuEnd		resd	1
		;used for resetting the game
	resetVar	resd	1
		;used for when the undo button is pressed
	undoPressed	resd	1
		;used for printing the final string to the screen
	frameBuffer	resb	2000
		;used for various color interactions
	lastColor	resd	1
		;used for the undo function
	inputCount	resd	1
	inputArray	resb	1000
		;This array stores the hint string read in from the board file.
	hintStr		resb	384
		;This array stores the names of all the game boards, and is
		;filled in the loadBoards function
	boardList	resb	2201
		;stores the main menu(s)
	mainMenu	resb	1041
	levelSelect	resb	1041
		;stores the color codes for the wall colors
	wallColor	resb	16
	wallColor2	resb	16
		;used for determining the color of the various game characters
	colorArray	resb	128
segment .text
	global	main
	extern	raw_mode_on
	extern 	raw_mode_off
	extern	system
	extern	getchar
	extern	printf
	extern	fopen
	extern	fgetc
	extern	fgets
	extern	fscanf
	extern	fclose
	extern 	sleep
	extern	strlen

main:
	push	ebp
	mov		ebp, esp
		call	colorFill
			; put the terminal in raw mode so the game works nicely
		call	raw_mode_on
			;populate boardList with all the game boards
		call	loadBoards
			;
		push	mainMenu
		push	menuBoard
		call	init_menuBoard
		add		esp, 8
			;
		push	levelSelect
		push	levSelBoard
		call	init_menuBoard
		add		esp, 8
			;
		push	11
		push	14
		push	mainMenu
		call	menuCycle
		add		esp, 12
			; restore old terminal functionality
		call raw_mode_off
	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

;associates a color code with each of the possible game board elements
colorFill:
	push	ebp
	mov		ebp, esp
		mov		BYTE [colorArray + 'T'], '0' ;wall character
		mov		BYTE [colorArray + '-'], 4   ;horizonatl line in menu
		mov		BYTE [colorArray + '|'], 4   ;vertical line in menu
		mov		BYTE [colorArray + 'R'], 2   ;normal rocks
		mov		BYTE [colorArray + 'I'], 13  ;light rocks
		mov		BYTE [colorArray + 'i'], 13  ;light rock on plate
		mov		BYTE [colorArray + 'P'], 3   ;plate
		mov		BYTE [colorArray + '^'], 9   ;gem door
		mov		BYTE [colorArray + '&'], 9   ;plate door with gem
		mov		BYTE [colorArray + '%'], 7   ;button door
		mov		BYTE [colorArray + '!'], 5   ;plate door
		mov		BYTE [colorArray + '*'], 8   ;grey button door
		mov		BYTE [colorArray + ')'], 10  ;menu option character
		mov		BYTE [colorArray + 'S'], 6   ;stairs
		mov		BYTE [colorArray + 'W'], 4   ;water
		mov		BYTE [colorArray + 'O'], 11  ;player character
		mov		BYTE [colorArray + 'B'], 7   ;active button
		mov		BYTE [colorArray + 'b'], 7   ;inactive button
		mov		BYTE [colorArray + 'G'], 9   ;gem
		mov		BYTE [colorArray + 'g'], 9   ;gem on plate
		mov		BYTE [colorArray + 'K'], 1   ;key
		mov		BYTE [colorArray + 'L'], 4   ;active lever
		mov		BYTE [colorArray + 'l'], 4   ;inactive lever
		mov		BYTE [colorArray + 'h'], 9   ;gem on water
	mov		esp, ebp
	pop		ebp
	ret

;takes the game board file locations stored in gameBoards, 
;and stores them indiviudually into boardList
loadBoards:
	push	ebp
	mov		ebp, esp
			;create 1 local variable
		sub		esp, 4
			;open the gameBoards file
		push	mode_r
		push	gameBoards
		call	fopen
		add		esp, 8
			;store file pointer in local variable
		mov		DWORD[ebp - 4], eax
			;initialize the indexer
		mov		esi, 0
		ldBoardsLoop:
		lea		edx, [boardList + esi]
		cmp		eax, 0
		je		endBoardsLoop
				;read the line from file gameBoards into boardList
			push	DWORD [ebp - 4] ;gameBoards
			push	23 				;size
			push	edx 			;boardList
			call	fgets
			add		esp, 12
				;replace the new line with a null byte
			mov		BYTE [boardList + esi + 21], 0
		add		esi, 22
		jmp		ldBoardsLoop
		endBoardsLoop:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

;
init_menuBoard:
	push	ebp
	mov		ebp, esp
		sub		esp, 4
			;open the file
		push	mode_r
		push	DWORD [ebp + 8]
		call	fopen
		add		esp, 8
			;store file pointer in local variable
		mov		DWORD[ebp - 4], eax
			;call readDisplay to populate mainMenu/levelSelect
		push	51 				 ;inc value
		push	52 				 ;fgets buffer
		push	DWORD [ebp + 12] ;array
		push	DWORD [ebp - 4]  ;file handle
		call	readDisplay
		add		esp, 16
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

;has four arguments, file handle, array, fgets buffer, increment value
;reads in the game board
readDisplay:
	push	ebp
	mov		ebp, esp
		mov		ebx, DWORD [ebp + 12]
		mov		esi, 0
		topDisplayLoop:
			lea		edx, [ebx + esi] ;load the address of the respective array into edx
			push	DWORD [ebp + 8]  ;file handle
			push	DWORD [ebp + 16] ;fgets buffer
			push	edx 			 ;array
			call	fgets
			add		esp, 12
			cmp		eax, 0
			je		bottomDisplay
				add		esi, DWORD [ebp + 20] ;inc value
				mov		BYTE [ebx + esi], 13 ;replace null with carriage return
		inc		esi
		jmp		topDisplayLoop
		bottomDisplay:
		mov		BYTE [ebx + esi - 2], 10
	mov		esp, ebp
	pop		ebp
	ret

;has two arguments, xpos and ypos
;same as gameloop, just for the menu
menuCycle:
    push	ebp
	mov		ebp, esp
        push	DWORD [ebp + 12]
		pop		DWORD [xpos]
		push	DWORD [ebp + 16]
		pop		DWORD [ypos]
        menuLoop:
            cmp     DWORD [menuEnd], 1
                ;render the menu
            push    DWORD [ebp + 8] ; mainMenu
            push    52              ; width of board
            push    1050            ; total characters
            call    render
            add     esp, 12
                ;get action from user
            call    getchar
            push    eax
            	; store the current position
			mov		esi, DWORD [xpos]
			mov		edi, DWORD [ypos]
            	;based on input, change the cursor position
			cmp		eax, 'w'
			je 		menuUp
			cmp		eax, 'a'
			je		menuLeft
			cmp		eax, 's'
			je		menuDown
			cmp		eax, 'd'	
			je		menuRight
			cmp		eax, ' '
			je		menuSpace
			jmp		menu_loop
			menuUp:
				dec		DWORD [ypos]
				jmp		menuSpace
			menuLeft:
				dec		DWORD [xpos]
				jmp		menuSpace
			menuDown:
				inc		DWORD [ypos]
				jmp		menuSpace
			menuRight:
				inc		DWORD [xpos]
			menuSpace:
            mov		ecx, 0
			mov		eax, 52
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
				; check where to move the player based on input
			push	DWORD [ebp + 8]
			call	checkCharMenu
			add		esp, 8
        jmp     menuLoop    
        menu_loop_end:
        mov		DWORD [menuEnd], 0
        push	clear_screen_code
        call	printf
        add		esp, 4
    mov		esp, ebp
    pop		ebp
    ret

;has two arguments, saved user input, and the cursor location in the board
;determines what to do based on what the user inputed
checkCharMenu:
	push	ebp
	mov		ebp, esp
        mov     ebx, DWORD [ebp + 8]
        cmp		DWORD [ebp + 12], ' '
		jne		checkMove
                ;store cursor position for main menu
            push    DWORD [xpos]
            push    DWORD [ypos]
            cmp     ebx, mainMenu
            jne     notMainMenu
                cmp     DWORD [xpos], 14
                jne     notLevSelect
                    	;enter the level select screen
					push	8         ;starting y value
					push	5         ;starting x value
					push	levelSelect
					call 	menuLoop
					add		esp, 12
                closeMenu:
                    inc     DWORD [menuEnd]
                    jmp     checkComplete
            notMainMenu:
                cmp     DWORD [ypos], 18
                je      closeMenu
                        ;using the cursor location, determine both the level offset 
						;and the world offset within boardList					
					sub		DWORD [ypos], 8   ;subtract from ypos the height offset of levSelect,
					                          ;effectively obtaining the level id
					mov		eax, DWORD [xpos]
					sub		eax, 5            ;subtract from xpos the width offset of menu2
					mov		ecx, 4
					div		ecx               ;divide xpos by the offset between worlds,
					                          ;effectively obtaining the world id
						;call gameloop
					push	DWORD [ypos] ;level id
					push	eax          ;world id
					call	gameloop
					add		esp, 8
						;reset game state
					mov		DWORD [gameEnd], 0
            checkComplete:
                    ;retrieve the saved xpos and ypos
                pop		DWORD [ypos]
                pop		DWORD [xpos]
                jmp		moveCursor
        checkMove:
            	;get cursor offset
		add		ebx, eax
			
		push	DWORD [ebp + 12] ; saved user input
			;If moving up or down, seek through the arry appropriately to find 
			;an acceptable cursor location
		cmp		DWORD [ebp + 12], 'w'
		je		walkBackTop
		cmp		DWORD [ebp + 12], 's'
		jne		notUpDown
		walkBackTop:
				;seek eiither left or right edge, depending on whether up or down was inputed.
			push	'-'
			push	's'
			jmp		checkCursor
		notUpDown:
				;if a or d is pressed, scan in the appropriate direction
			push	'|'
			push	'd'
		checkCursor:
		call	walkFunc
		add		esp, 12
		cmp		DWORD [foundOpt], 1
		je		moveCursor
			mov		DWORD [xpos], esi
			mov		DWORD [ypos], edi
		moveCursor:
	mov		esp, ebp
	pop		ebp
	ret

;three arguments, character to compare to, character to look for, and user input
;walks through the menu board, until it either finds a stop or a viable option to move to
walkFunc:
	push	ebp
	mov		ebp, esp
		sub     esp, 4
        mov     DWORD [ebp - 4], eax
        mov     eax, DWORD [ebp + 12]
        mov     ecx, DWORD [ebp + 8]
        mov     DWORD [foundOpt], 0
		seekOpposite:
        mov     edx, 0
        topWalk:
        cmp     DWORD [foundOpt], 1
        je      secondComplete
        cmp		BYTE [ebx + edx], al
		je		firstComplete
            cmp		BYTE [ebx + edx], ')'
			jne		notOption
				testing:
				mov     eax, DWORD [ebp - 4]
                add     eax, edx
                mov		ecx, 52
				xor		edx, edx
				div     ecx
                mov     DWORD [ypos], eax
                mov     DWORD [xpos], edx
                inc     DWORD [foundOpt]
                jmp     topWalk
            notOption:
            cmp		ecx, DWORD [ebp + 16]
            jne		mvLeft
                inc		edx
                jmp		topWalk
            mvLeft:
                dec		edx
                jmp		topWalk
        firstComplete:
		mov		eax, '|'
		cmp     ecx, 'd'
		mov		ecx, 'd'
        jne     seekOpposite
        secondComplete:
	mov		esp, ebp
	pop		ebp
	ret

;has two arguments -- 
;everything that happens while playing the game is in here
gameloop:
	push	ebp
	mov		ebp, esp
		sub		esp, 4
		resetGame:
		push	DWORD [ebp + 12]
		pop		DWORD [ebp - 4]
			;clear the input array
		xor		eax, eax
		mov		ecx, 1000
		lea		edi, [inputArray]
		cld
		rep		stosb
		mov		DWORD [inputCount], 0
			;initialize the game state based on the board file
		push	DWORD [ebp + 12]
		push	DWORD [ebp + 8]
		call	initGame
		add		esp, 8

		mov		DWORD [resetVar], 0
		game_loop:
			mov		DWORD [undoPressed], 0
				; draw the game board
			push	board
			push	24
			push	432
			call	render
			add		esp, 12
				; get an action from the user
			call	getchar
				;check where to move the player based on input
			push 	DWORD [ebp + 12]
			push	DWORD [ebp + 8]
			call	checkInput
			add		esp, 8

			cmp		DWORD [gameEnd], 1
			je		game_loop_end
			cmp		DWORD [resetVar], 1
			je		resetGame
			cmp		DWORD [undoPressed], 1
			je		game_loop
				mov		ecx, DWORD [inputCount]
				mov		BYTE [inputArray + ecx], al
				inc		DWORD [inputCount]
				mov		ecx, eax
					; take the potential new pos for the player, and see if it's valid
					; (W * y) + x = pos
				mov		eax, 24
				mul		DWORD [ypos]
				add		eax, DWORD [xpos]
					;call checkCharGame, passing it the current board index	
				push	DWORD [ebp + 12] ;current level
				call	checkCharGame
				pop		ebx ;current level
					;If the level was completed, proceed to the next one
				cmp		ebx, DWORD [ebp - 4]
				je		notComplete
					jmp		notSub
				notComplete:
		jmp		game_loop
		game_loop_end:
	mov		esp, ebp
	pop		ebp
	ret

checkInput:
	push	ebp
	mov		ebp, esp
		sub		esp, 4
			; store the current position
			; we will test if the new position is legal
			; if not, we will restore these
		mov		esi, DWORD [xpos]
		mov		edi, DWORD [ypos]
			; clear the hint display
		mov		DWORD [displayHint], 0

		cmp		eax, 'x'
		je		exitGame
		cmp		eax, '-'
		je		changeLevel
		cmp		eax, '='
		je		changeLevel
		cmp		eax, '/'
		je		undo
		cmp		eax, 127
		je		resetGame
		cmp		al, 'w'
		je 		moveUp
		cmp		al, 'a'
		je		moveLeft
		cmp		al, 's'
		je		moveDown
		cmp		al, 'd'	
		je		moveRight
		cmp		al, 'h'
		je		showHint
		jmp		inputFound
		exitGame:
			inc		DWORD [gameEnd]
			jmp		inputFound
		changeLevel:
			cmp		eax, '-'
			jne		notSub
				dec		DWORD [ebp + 12]
				cmp		DWORD [ebp + 12], 0
				jge		inputFound
					dec		DWORD [ebp + 8]
					mov		DWORD [ebp + 12], 9
					inc		resetVar
					jmp		inputFound
			notSub:
				inc		DWORD [ebp + 12]
				cmp		DWORD [ebp + 12], 9
				jle		inputFound
					inc		DWORD [ebp + 8]
					mov		DWORD [ebp + 12], 0
					inc		resetVar
					jmp		inputFound
		undo:
			inc		DWORD [undoPressed]
			cmp		DWORD [inputCount], 0
			je		inputFound
				mov		DWORD [ebp - 4], 0
				dec		DWORD [inputCount]
				
				push	DWORD [ebp + 12]
				push	DWORD [ebp + 8]
				call	initGame
				add		esp, 8
			
				undoLoop:
				xor		edx, edx
				mov		edx, DWORD [ebp - 4]
				cmp		edx, DWORD [inputCount]
				je		endUndoLoop
					xor		eax, eax
					mov		al, BYTE [inputArray + edx]
					call	checkInput
					mov		ecx, eax

					mov		eax, 24
					mul		DWORD [ypos]
					add		eax, DWORD [xpos]

					call	checkCharGame
				inc		DWORD [ebp - 4]
				jmp		undoLoop
				endUndoLoop:
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
		inputFound:
	mov		esp, ebp
	pop		ebp
	ret