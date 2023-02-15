; the size of the game screen in characters
%define GHEIGHT 18
%define GWIDTH 22

segment .data
		;this file contains a list of all the game boards,
		;and is used to dynamically fill boardArray
	gameBoards			db "boards/boards.txt",0
	menuBoard			db "menu.txt",0
	menuBoard2			db "menu2.txt",0
		;these are the color codes used for various symbols
	playerColor			db	27,"[38;5;173m",0	
	helpStrColor		db	27,"[38;5;247m",0
	resetColor			db	27,"[0m",0
		;these colors are part of colorCodeArray
	keyColor			db	27,"[38;5;220m",0
	rockColor			db	27,"[38;5;94m",0
	pressPlateColor		db	27,"[1;48;5;240;38;5;248m",0
	leverColor			db	27,"[38;5;69m",0
	pressDoorColor		db	27,"[38;5;242m",0
	stairsColor			db	27,"[38;5;124m",0
	buttonColor			db	27,"[38;5;14m",0
	activeBColor		db	27,"[38;5;13m",0
	gemColor			db	27,"[38;5;9m",0
	menuOptColor		db	27,"[38;5;240m",0
	colorCodeArray		dd 	wallColor, keyColor, rockColor, pressPlateColor, \
							leverColor, pressDoorColor, stairsColor, buttonColor, \
							activeBColor, gemColor, menuOptColor
		;used for the board render
	boardFormat			db "%s",0
		; used to change the terminal mode
	mode_r				db "r",0
		; ANSI escape sequence to clear/refresh the screen
	clear_screen_code	db	27,"[2J",27,"[H",27,"[0m",0
		; things the program will print
	hintBlank			db 10,10,10,10,10,0
		;displays num keys
	win_str				db	27,"[2J",27,"[H", "Level complete!",13,10,0
	waitStr				db	"Press Enter to continue.",13,10,0
		;all the possible characters that can be displayed on the game board
		;used to determine interactions between the rock and player chars
	coordString			db	"%d %d",0

segment .bss
		; this array stores the current rendered gameboard (HxW)
	board		resb	396
		;this array is used to store door characters when they are opened
	doorLayer	resb	396
		;same as the door layer, but for floor objects, like water and plates
	floorLayer	resb	396
		; these variables store the current player position
	xpos		resd	1
	ypos		resd	1
		;These variables store various data for rendering
	colorCode	resd	1
	plateCol	resd	1
	displayHint	resd	1
	gameEnd		resd	1
	menuEnd		resd	1
	frameBuffer	resb	1536
	lastColor	resd	1
		;This array stores the hint string read in from the board file.
	hintStr		resb	384
		;This array stores the names of all the game boards, and is
		;filled in loadBoards
	boardArray	resb	2200
	spacePressed resd	1
		;stores the main menu
	mainMenu	resb	1001
	mainMenu2	resb	1001

	wallColor	resb	14

segment .text

	global	main
	extern	raw_mode_on
	extern 	raw_mode_off
	extern	system
	extern	getchar
	extern	printf
	extern	fopen
	extern	fread
	extern	fgetc
	extern	fgets
	extern	fscanf
	extern	fclose
	extern 	sleep
	extern	strlen

main:
	push	ebp
	mov		ebp, esp
			; put the terminal in raw mode so the game works nicely
		call	raw_mode_on
			;populate boardArray with all the game boards
			;serves the same purpose as the boards array did
		call	loadBoards
		push	mainMenu
		push	menuBoard
		call	loadMenu
		add		esp, 4
		push	mainMenu2
		push	menuBoard2
		call	loadMenu
		add		esp, 4
		push	11
		push	14
		push	mainMenu
		call	menuLoop
		add		esp, 12
			; restore old terminal functionality
		call raw_mode_off
	mov		eax, 0
	mov		esp, ebp
	pop		ebp
	ret

loadBoards:
	push	ebp
	mov		ebp, esp
		sub		esp, 8
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
			push	23
			push	edx
			call	fgets
			add		esp, 12
				;replace the new line with a null byte
			mov		ecx, DWORD [ebp - 8]
			mov		BYTE [boardArray + ecx + 21], 0
		add		DWORD [ebp - 8], 22
		jmp		topReadLoop
		endReadLoop:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

loadMenu:
	push	ebp
	mov		ebp, esp
		sub		esp, 8
			;open the file
		push	mode_r
		push	DWORD [ebp + 8]
		call	fopen
		add		esp, 8
			;free up eax
		mov		DWORD[ebp - 4], eax
			;initialize the indexer
		mov		DWORD [ebp - 8], 0
		mov		ebx, DWORD [ebp + 12]
		topMenuLoop:
		mov		ecx, DWORD [ebp - 8]
		lea		edx, [ebx + ecx]
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

;has the arguments of height, width, character array
;[ebp + 8], [ebp + 12], [ebp + 16]
render:
	push	ebp
	mov		ebp, esp
			; two local ints, for two loop counters
			; ebp-4, ebp-8
		sub		esp, 8
			; clear the screen
		push	clear_screen_code
		call	printf
		add		esp, 4
			;if rendering game board, display hint text
		mov		ebx, DWORD [ebp + 16]
		cmp		ebx, board
		jne		renMenu
				;add color
			push	helpStrColor
			call	printf
			add		esp, 4
				; print the help information if it needs to be
			cmp		DWORD [displayHint], 0
			je		noHint
				lea		ecx, [hintStr]
				push	ecx
				call	printf
				add		esp, 4
				mov		DWORD [displayHint], 0
				jmp		hintShown
			noHint:
					;if displayHint is 0, just display blank space
				push	hintBlank
				call	printf
				add		esp, 4
			hintShown:
		renMenu:
		mov		DWORD [lastColor], 100
			;initialize frame buffer index
		mov		ecx, 0
			; outside loop by height
			; i.e. for(c=0; c<height; c++)
		mov		DWORD [ebp - 4], 0
		mov		DWORD [ebp - 8], 0
		y_loop_start:
		mov		eax, DWORD [ebp + 8]
		cmp		DWORD [ebp - 4], eax
		je		y_loop_end
				;if width counter == width, print new line and carriage return
			mov		eax, DWORD [ebp + 12]
			cmp		DWORD [ebp - 8], eax
			jne 		countWidth
				mov		DWORD [ebp - 8], 0
					; write a carriage return (necessary when in raw mode)
				mov		BYTE [frameBuffer + ecx], 0x0d
				inc		ecx
					; write a newline
				mov		BYTE [frameBuffer + ecx], 10
				inc		ecx
				jmp		y_loop_start
			countWidth:
					;retrieve the next board character to be printed
					; check if (xpos,ypos)=(x,y)
					;save the value of eax
				mov		edi, DWORD [ebp - 4]
				mov		eax, DWORD [ypos]
				mul		DWORD [ebp + 12]
				add		eax, DWORD [xpos]
				cmp		eax, DWORD [ebp - 4]
				jne		print_board
					cmp		ebx, mainMenu2
					je		menuPrint
					cmp		ebx, mainMenu
					jne		printPlayer
					menuPrint:
							;if printing the menu, do this
						lea		eax, [menuOptColor]
						mov		DWORD [lastColor], 10
						mov		DWORD [colorCode], 10
						push	'>'
						jmp		playerFound
					printPlayer:
							;if printing game board, do this
						lea		eax, [playerColor]
						mov		DWORD [lastColor], 99
						push	'O'
					playerFound:
						;add the respective color code to the frame buffer
					mov		esi, 0
					selectColorLoop:
					cmp		BYTE [eax + esi], 0
					je		endSelectColorLoop
						mov		dl, BYTE [eax + esi]
						mov		BYTE [frameBuffer + ecx], dl
						inc		ecx
					inc		esi
					jmp		selectColorLoop
					endSelectColorLoop:
						;pop off the character pushed to the stack earlier,
						;then add it to the frame buffer
					pop		edx
					mov		BYTE [frameBuffer + ecx], dl
					inc		ecx
					jmp		print_end
				print_board:
				mov		dl, BYTE [ebx + edi]
					;render the character
				push	ebx
				cmp		ebx, mainMenu2
				je		isMenuRender
				cmp		ebx, mainMenu
				jne		isGameRender
				isMenuRender:
						;if rendering menu, do this
					call	mcharRender
					pop		ebx
					jmp		print_end
				isGameRender:
						;if rendering game board, do this	
					call	charRender
					pop		ebx
					jmp		print_end
				print_end:
					;if printing the menu, and if a menu option was just printed,
					;ensure that the rest of the option is the same color
				cmp		ebx, mainMenu2
				je		mprint_start
				cmp		ebx, mainMenu
				jne		mprint_end
				mprint_start:		
					cmp		DWORD [colorCode], 10
					jne		notOpt
						push	ebx
						add		ebx, edi
						mov		esi, 0
						SkipLoopTop:
						cmp		BYTE [ebx + esi + 1], ' '
						je		skipLoopEnd
							mov		dl, BYTE [ebx + esi + 1]
							mov		BYTE [frameBuffer + ecx], dl
							inc		ecx
							inc		DWORD [ebp - 8]
							inc		DWORD [ebp - 4]
						inc		esi
						jmp		SkipLoopTop
						skipLoopEnd:
						pop		ebx
					notOpt:
				mprint_end:
				cmp		DWORD [plateCol], 1
				jne		nPlateGem
					testes:
					mov		esi, 0
					resetColorLoop:
					cmp		BYTE [resetColor + esi],0
					je		endResetColorLoop
						mov		al, BYTE [resetColor + esi]
						mov		BYTE [frameBuffer + ecx], al
						inc		ecx
					inc		esi
					jmp		resetColorLoop
					endResetColorLoop:
					mov		DWORD [colorCode], 101
					mov		DWORD [plateCol], 0
				nPlateGem:
				inc		DWORD [ebp - 8]
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

mcharRender:
	push	ebp
	mov		ebp, esp
			mov		DWORD [colorCode], 101
			cmp		BYTE [ebx + edi], ' '
			je		mSpace
			cmp		BYTE [ebx + edi], '-'
			je		isBorder
			cmp		BYTE [ebx + edi], '|'
			je		isBorder
			cmp		BYTE [ebx + edi], ')'
			je		menuOpt
			jmp		notBorder
			mSpace:
				jmp		mAddChar
			isBorder:	
				mov		DWORD [colorCode], 4
				jmp		foundBorder
			menuOpt:
				mov		DWORD [colorCode], 10
				mov		dl, ' '
				jmp		foundBorder
			notBorder:
			mov		DWORD [colorCode], 7
			foundBorder:
			call	colorFunc
			mAddChar:
						;load the displayed character into the frame buffer
			mov		BYTE [frameBuffer + ecx], dl
			inc		ecx
	mov		esp, ebp
	pop		ebp
	ret

charRender:
	push	ebp
	mov		ebp, esp
			;compare the current byte to the various game objects, then
			;change the symbol and color accordingly
		cmp		BYTE [floorLayer + edi], 'W'
		je		rFWater
		cmp		BYTE [floorLayer + edi], 'P'
		je		rFPlate
		jmp		notFloor
		rFWater:
			mov		DWORD [colorCode], 4
			mov		dl, 'W'
			jmp		rDefault
		rFPlate:
			mov		DWORD [colorCode], 3
			mov		DWORD [plateCol], 1
			mov		dl, 'P'
			call	colorFunc
		notFloor:
		
		cmp		BYTE [ebx + edi], 'T'
		je		rWall
		cmp		BYTE [ebx + edi], ' '
		je		rSpace
		cmp		BYTE [ebx + edi], '-'
		je		rSpace
		cmp		BYTE [ebx + edi], '|'
		je		rSpace
		cmp		BYTE [ebx + edi], 'K'
		je		rKey
		cmp		BYTE [ebx + edi], 'R'
		je		rRock
		cmp		BYTE [ebx + edi], 'L'
		je		rLever
		cmp		BYTE [ebx + edi], 'l'
		je		rLever
		cmp		BYTE [ebx + edi], 'B'
		je		rButton
		cmp		BYTE [ebx + edi], 'b'
		je		rButton
		cmp		BYTE [ebx + edi], 'G'
		je		rGem
		cmp		BYTE [ebx + edi], 'S'
		je		rStairs
		cmp		BYTE [ebx + edi], '_'
		je		rDoor
		cmp		BYTE [ebx + edi], '!'
		je		rDoor
		cmp		BYTE [ebx + edi], '%'
		je		rDoor
		cmp		BYTE [ebx + edi], '*'
		je		rDoor
		cmp		BYTE [ebx + edi], '^'
		je		rDoor
		jmp		rDefault
		rWall:
			mov		DWORD [colorCode], 0
			jmp		rDefault
		rSpace:
			cmp		BYTE [floorLayer + edi], 'P'
			je		addChar
			cmp		BYTE [doorLayer + edi], 0
			je		isSpace
				push	DWORD [doorLayer + edi]
				jmp		isDoor
			isSpace:
			mov		dl, ' '
			jmp		addChar
		rKey:
			mov		DWORD [colorCode], 1
			jmp		rDefault
		rRock:
			mov		DWORD [colorCode], 2
			mov		dl, 'R'
			jmp		rDefault
		rLever:
			mov		DWORD [colorCode], 4
			jmp		rDefault
		rButton:
			mov		DWORD [colorCode], 7
			jmp		rDefault
		rGem:
			mov		DWORD [colorCode], 9
			mov		dl, 'G'
			jmp		rDefault
		rStairs:
			mov		DWORD [colorCode], 6
			jmp		rDefault
		rDoor:
			push	DWORD [ebx + edi]
			isDoor:
			mov		DWORd [colorCode], 5
			cmp		BYTE [ebp - 4], '!'
			je		notPDoor
			mov		DWORD [colorCode], 7
			cmp		BYTE [ebp - 4], '%'
			je		notBDoor
			mov		DWORD [colorCode], 8
			cmp		BYTE [ebp - 4], '*'
			je		notGBDoor
			mov		DWORD [colorCode], 9
			cmp		BYTE [ebp - 4], '^'
			je		notGDoor
			jmp		defaultDoor
			notPDoor:
				push	'P'
				jmp		doorPushed
			notBDoor:
				push	'b'
				jmp		doorPushed
			notGBDoor:
				push	'b'
				jmp		doorPushed
			notGDoor:
				push	'G'
				jmp		doorPushed
			defaultDoor:
				push	'l'
			doorPushed:			
				call	searchObject
				add		esp, 8
		rDefault:
		call	colorFunc
		addChar:
			;load the displayed character into the frame buffer
		mov		BYTE [frameBuffer + ecx], dl
		inc		ecx
	mov		esp, ebp
	pop		ebp
	ret

menuLoop:
	push	ebp
	mov		ebp, esp

		push	DWORD [ebp + 12]
		pop		DWORD [xpos]
		push	DWORD [ebp + 16]
		pop		DWORD [ypos]
		mov		DWORD [menuEnd], 0
		menu_loop:
			cmp		DWORD [menuEnd], 1
			je		menu_loop_end
				; draw the game board
			push	DWORD [ebp + 8]
			push	50
			push	1050
			call	render
			add		esp, 12
				; get an action from the user
			call	getchar
				; store the current position
				; we will test if the new position is legal
				; if not, we will restore these
			mov		esi, DWORD [xpos]
			mov		edi, DWORD [ypos]
				; check where to move the player based on input
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

			push	eax
			
			mov		ecx, 0
			mov		eax, 50
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
			
			push	DWORD [ebp + 8]
			call	checkCharMenu
			add		esp, 8

		jmp		menu_loop
		menu_loop_end:
		mov		DWORD [menuEnd], 0
		push	clear_screen_code
		call	printf
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

checkCharMenu:
	push	ebp
	mov		ebp, esp	
		mov		ebx, DWORD [ebp + 8]
		
		cmp		DWORD [ebp + 12], ' '
		jne		checkMove
			cmp		ebx, mainMenu
			jne		notMain1
				cmp		DWORD [xpos], 14
				jne		notGame
						;save cursor position
					push	DWORD [xpos]
					push	DWORD [ypos]
						;enter the level select screen
					push	8
					push	5
					push	mainMenu2
					call 	menuLoop
					add		esp, 12
						;retrieve cursor position
					pop		DWORD [ypos]
					pop		DWOrD [xpos]
					jmp		moveCursor
				notGame:
						;if close selected, exit screen
					inc		DWORD [menuEnd]
					jmp		moveCursor
				notClose:
				jmp		checkMove
			notMain1:
				cmp		DWORD [ypos], 18
				jne		cancelOpt
						;if cancel selected, exit screen
					inc		DWORD [menuEnd]
					jmp		moveCursor
				cancelOpt:
						;save cursor location for when gameloop ends
					push	DWORD [xpos]
					push	DWORD [ypos]
						;using the cursor location, determine both the level offset 
						;and the world offset within boardArray					
					sub		DWORD [ypos], 8
					mov		eax, DWORD [xpos]
					sub		eax, 5
					mov		ecx, 4
					div		ecx
						;call gameloop
					push	DWORD [ypos]
					push	eax
					call	gameloop
					add		esp, 8
						;retrieve cursor location
					pop		DWORD [ypos]
					pop		DWORD [xpos]
						;reset game state
					mov		DWORD [gameEnd], 0
					jmp		moveCursor
				jmp		checkMove
		checkMove:
		mov		edx, 0
			;get cursor offset
		add		ebx, eax
			;If moving up or down, seek through the arry appropriately to find 
			;an acceptable cursor location
		cmp		DWORD [ebp + 12], 'w'
		je		walkBackTop
		cmp		DWORD [ebp + 12], 's'
		jne		notUpDown
		walkBackTop:
				;seek eiither left or right edge, depending on whether
				;up or down was inputed.
			seekEdge:
			cmp		BYTE [ebx + edx], '|'
			je		seekEdgeBottom
				cmp		BYTE [ebx + edx], ')'
				jne		seekEdgeOpt
					add		DWORD [xpos], edx
					jmp		moveCursor
				seekEdgeOpt:
			cmp		DWORD [ebp + 12], 's'
			jne		seekEdgeRight
				dec		edx
				jmp		seekEdge
			seekEdgeRight:
				inc		edx
				jmp		seekEdge
			seekEdgeBottom:
				;seek null at beginning or end of array, edpending on whether 
				;up or down was inputed.
			mov		edx, 0
			seekEnd:
			cmp		BYTE [ebx + edx], 0
			je		seekComplete
				cmp		BYTE [ebx + edx], ')'
				jne		seekEndOpt
					add		DWORD [xpos], edx
					jmp		moveCursor
				seekEndOpt:
			cmp		DWORD [ebp + 12], 's'
			jne		seekLeft
				inc		edx
				jmp		seekEnd
			seekLeft:
				dec		edx
				jmp		seekEnd
			seekEndBottom:
		notUpDown:
			;if a or d is pressed, scan in the appropriate direction for a wall
			;if not found, check to see if it's a menu opt. if it isn't, keep checking
		cmp		BYTE [ebx + edx], '|'
		je		seekComplete
			cmp		BYTE [ebx + edx], ')'
			jne		notOption
				add		DWORD [xpos], edx
				jmp		moveCursor
			notOption:
		cmp		DWORD [ebp + 12], 'a'
		je		mvLeft
			inc		edx
			jmp		notUpDown
		mvLeft:
			dec		edx
			jmp		notUpDown
		seekComplete:
		mov		DWORD [xpos], esi
		mov		DWORD [ypos], edi
		moveCursor:
	mov		esp, ebp
	pop		ebp
	ret

gameloop:
	push	ebp
	mov		ebp, esp
		resetGame:
		mov		eax, 220
		mul		DWORD [ebp + 8]
		mov		ebx, eax
		mov		eax, 22
		mul		DWORD [ebp + 12]
		add		eax, ebx
			;if the previous board was the last one, close the game
		cmp		BYTE [boardArray + eax], 0
		jne		validBoard
			inc		DWORD[gameEnd]
			jmp		game_loop
		validBoard:
			;display the initial board, or update it to the next one
		lea		ecx, [boardArray + eax]
		push	ecx
		call	init_board
		add		esp, 4
			;call	init_arrs
		mov		DWORD [displayHint], 1
		mov		DWORD [gameEnd], 0
		game_loop:
			cmp		DWORD [gameEnd], 1
			je		game_loop_end	
				; draw the game board
			push	board
			push	GWIDTH
			push	396
			call	render
			add		esp, 12
				; get an action from the user
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
			resetBoard:
				jmp		resetGame
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
			mov		ecx, eax
				; take the potential new pos for the player, and see if it's valid
				; (W * y) + x = pos
			mov		eax, GWIDTH
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
				;call checkCharTest, passing it the current board index
			push	DWORD [ebp + 12]
			call	checkCharTest
			pop		DWORD [ebp + 12]
				;If the level was completed, proceed to the next one
			cmp		ebx, DWORD [ebp + 12]
			je		notComplete
				cmp		DWORD [ebp + 12], 10
				jne		newLevel
					inc		DWORD [ebp + 8]
					mov		DWORD [ebp + 12], 0
					jmp		resetGame
				newLevel:
					;inc		DWORD [ebp + 12]
					jmp		resetGame
			notComplete:
		jmp		game_loop
		game_loop_end:
	mov		esp, ebp
	pop		ebp
	ret

checkCharTest:
	push	ebp
	mov		ebp, esp
		mov		ebx, DWORD [ebp + 8]
		cmp		BYTE [board + eax], ' '
		je		checkDone
		cmp		BYTE [board + eax], 'R'
		je		pRock
		cmp		BYTE [board + eax], 'p'
		je		pRock
		cmp		BYTE [board + eax], 'P'
		je		checkDone
		cmp		BYTE [board + eax], 'L'
		je		pLever
		cmp		BYTE [board + eax], 'l'
		je		pLever
		cmp		BYTE [board + eax], 'S'
		je		pStairs
		cmp		BYTE [board + eax], 'K'
		je		pKey
		cmp		BYTE [board + eax], 'B'
		je		pButton
		cmp		BYTE [board + eax], 'b'
		je		pButton
		cmp		BYTE [board + eax], 'G'
		je		pGem
		cmp		BYTE [board + eax], 'g'
		jmp		pDefault
		pRock:
			call	pushRock
			jmp		checkDone
		pLever:
			cmp		BYTE [board + eax], 'L'
			jne		noLev
				mov		BYTE [board + eax], 'l'
				jmp		pDefault
			noLev:
			mov		BYTE [board + eax], 'L'
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
				;print the waitstr
			push	waitStr
			call	printf
			add		esp, 4
				;loop until enter is pressed
			kek:
			call	getchar
			cmp		eax, 13
			jne		kek
				;inc the board counter
			inc		DWORD [ebp + 8]
			jmp		checkDone
		pKey:
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
		cmp		ecx, 'w'
		je		nextDir1
		cmp		ecx, 'a'
		je		nextDir2
		cmp		ecx, 's'
		je		nextDir3
		cmp		ecx, 'd'
		je		nextDir4
		jmp		rockend
			;Load the address of the next space in the array 
			;according to the direction the rock is moivng
		nextDir1:
			lea		ecx, [board + eax - GWIDTH]
			jmp		moveRock
		nextDir2:
			lea		ecx, [board + eax - 1]
			jmp		moveRock
		nextDir3:
			lea		ecx, [board + eax + GWIDTH]
			jmp		moveRock
		nextDir4:
			lea		ecx, [board + eax + 1]
		moveRock:
			;Check if the character the rock was pushed into is a valid move
			;if not, reset the position of the player
		cmp		BYTE [ecx], ' '
		je		canMove
		cmp		BYTE [ecx], 'P'
		jne		pathBlocked
		canMove:
			cmp		BYTE [board + eax], 'p'
			je		onPlate
			mov		BYTE [board + eax], ' '
			jmp		mvNext
			onPlate:
				mov		BYTE [board + eax], 'P'
			mvNext:
			cmp		BYTE [ecx], 'P'
			je		plateNext
			mov		BYTE [ecx], 'R'
			jmp		rockend
			plateNext:
				mov		BYTE [ecx], 'p'
				jmp		rockend
		pathBlocked:
		mov		DWORD [xpos], esi
		mov		DWORD [ypos], edi
		rockend:
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
			;load in the color for the walls
		mov		BYTE [wallColor], 27
		lea		eax, [wallColor + 1]
		push	DWORD [ebp - 4]
		push	15
		push	eax
		call	fgets
		add		esp, 12
			;remove new line char
		lea		eax, [wallColor]
		push	eax
		call	strlen
		add		esp, 4
		mov		BYTE [wallColor + eax - 1], 0
			;load the player's starting position
		push	ypos
		push	xpos
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
		mov		esi, 0
		mov		BYTE [hintStr], 10
		inc		ebx
		topInitLoop:
		cmp		esi, 3
		je		endInitLoop
			lea		eax, [hintStr + ebx]
			push	DWORD [ebp - 4]
			push	128
			push	eax
			call	fgets
			add		esp, 12
				;get the next offset and put it in ebx
			push	eax
			call	strlen
			add		esp, 4
			add		ebx, eax
				;add a carriage return
			mov		BYTE [hintStr + ebx], 13
			inc		ebx
		inc		esi
		jmp		topInitLoop
		endInitLoop:
		mov		BYTE [hintStr + ebx], 10
		mov		BYTE [hintStr + ebx + 1], 0
			; read the file data into the global buffer
			; line-by-line so we can ignore the newline characters
		mov		DWORD [ebp - 8], 0
		read_loop:
		cmp		DWORD [ebp - 8], GHEIGHT
		je		read_loop_end
				; find the offset (GWIDTH * counter)
			mov		eax, GWIDTH
			mul		DWORD [ebp - 8]
			lea		ebx, [board + eax]
				; read the bytes into the buffer
			push	DWORD [ebp - 4]
			push	GWIDTH
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
			;populate the door and floor layer
		mov		edx, GWIDTH*GHEIGHT
		mov		edi, 0
		objLoop:
		cmp		edi, edx
		je		endObjCheck
			cmp		BYTE [board + edi], 'g'
			je		yesGemPlate
			cmp		BYTE [board + edi], 'P'
			je		yesPlate
			cmp		BYTE [board + edi], 'W'
			je		yesWater
			cmp		BYTE [board + edi], '!'
			je		yesPDoor
			cmp		BYTE [board + edi], '_'
			je		yesLDoor
			cmp		BYTE [board + edi], '%'
			je		yesBDoor
			cmp		BYTE [board + edi], '*'
			je		yesgBDoor
			cmp		BYTe [board + edi], '^'
			je		yesGDoor
			mov		BYTE [doorLayer + edi], 0
			mov		BYTE [floorLayer + edi], 0
			jmp		noObj
			yesGemPlate:
				mov		BYTE [board + edi], 'G'
				mov		BYTe [floorLayer + edi], 'P'
				jmp		noObj
			yesPlate:
				mov		BYTE [board + edi], ' '
				mov		BYTE [floorLayer + edi], 'P'
				jmp		noObj
			yesWater:
				mov		BYTE [board + edi], ' '
				mov		BYTE [floorLayer + edi], 'W'
				jmp		noObj
			yesPDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noObj
			yesLDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noObj
			yesBDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noObj
			yesgBDoor:
				mov		BYTE [doorLayer + edi], ' '
				jmp		noObj
			yesGDoor:
				mov		BYTE [doorLayer + edi], ' '
			noObj:
		inc		edi
		jmp		objLoop
		endObjCheck:
			; close the open file handle
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
	mov		esp, ebp
	pop		ebp
	ret

layerSwap:
	push 	ebp
	mov		ebp, esp
		mov		cl, BYTE [board + edi]
		mov		dl, BYTE [doorLayer + edi] 
		mov		BYTE [board + edi], dl
		mov		BYTE [doorLayer + edi], cl
	mov		esp, ebp
	pop 	ebp
	ret
	
searchObject:
	push	ebp
	mov		ebp, esp
		push	ecx
		mov		edx, DWORD [ebp + 8]
		mov		al, BYTE [ebp + 12]
		mov		esi, 0
			;check the board layer for the repsective object
		searchLoop:
		cmp		esi, 396
		je		searchPassed
			cmp		BYTE [ebx + esi], 'R'
			je		notCovered
			cmp		BYTE [ebx + esi], 'G'
			je		notCovered
				cmp		BYTE [floorLayer + esi], dl
				jne		notCovered
					jmp		plateCovered
			notCovered:
			cmp		BYTE [ebx + esi], dl
			jne		checkActive
				plateCovered:
				cmp		BYTE [ebx + edi], '*'
				je		gDoor
				cmp		BYTE [ebx + edi], al
				je		noSwap
				cmp		al, '*'
				je		noSwap
				gDoor:
					call	layerSwap
				noSwap:
				cmp		al, '*'
				jne		notGrey1
					mov		dl, ' '
					jmp		endSearch
				notGrey1:	
					mov		dl, '#'
					jmp		endSearch
			checkActive:
		inc		esi
		jmp		searchLoop
			;if a button is not found, open the button doors
		searchPassed:
			cmp		BYTE [doorLayer + edi], '*'
			je		gDoor2
			cmp		BYTE [ebx + edi], al
			jne		doorLayer1
			cmp		al, '*'
			je		doorLayer1
				gDoor2:
				call	layerSwap
			doorLayer1:
			cmp		al, '*'
			jne		notGrey2
				mov		dl, '#'
				jmp		endSearch
			notGrey2:	
				mov		dl, ' '
		endSearch:
		pop		ecx
	mov		esp, ebp
	pop		ebp
	ret

colorFunc:	
	push	ebp
	mov		ebp, esp
		sub		esp, 4
		;use the num in colorCode to load the correct code into edi
		mov		esi, DWORD[colorCode]
			;if the character being loaded into the frame buffer isn't the same as the last one,
			;load each of the bytes for the color code into the frame buffer until we reach a null byte
		cmp		DWORD [lastColor], 3
		je		colorAnyway
		cmp		DWORD [lastColor], esi
		je		redundantColor
			colorAnyway:
			mov		esi, DWORD[colorCodeArray + esi * 4]
			mov		DWORD [ebp - 4], 0
			mov		eax, DWORD [ebp - 4]
			colorLoop:
			cmp		BYTE [esi + eax], 0
			je		endColorLoop
				mov		al, BYTE [esi + eax]
				mov		BYTE [frameBuffer + ecx], al
				inc		ecx
			inc		DWORD [ebp - 4]
			mov		eax, DWORD [ebp - 4]
			jmp		colorLoop
			endColorLoop:
			push	DWORD [colorCode]
			pop		DWORD [lastColor]
		redundantColor:
	mov		esp, ebp
	pop		ebp
	ret