; the size of the game screen in characters
%define GHEIGHT 16
%define GWIDTH 20

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
	coordString			db	"%d %d",0

segment .bss

		; this array stores the current rendered gameboard (HxW)
	board		resb	320
		;this array is used to store door characters when they are opened
	doorLayer	resb	320
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
	frameBuffer	resb	1536
		;this array tells the checkChar function what the character in front is
	lastColor	resd	1
		;This array stores the hint string read in from the board file.
	hintStr		resb	384
		;This array stores the names of all the game boards, and is dynamically
		;filled in loadBoards
	boardArray	resb	2100
	spacePressed resd	1
		;stores the main menu
	mainMenu	resb	1536
	mainMenu2	resb	1536

segment .text

	global	main
	global  init_board
	global  render

	extern	raw_mode_on
	extern 	raw_mode_off

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
		add		DWORD [ebp - 8], 50
		jmp		topMenuLoop
		endMenuLoop:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4

		push	mode_r
		push	menuBoard2
		call	fopen
		add		esp, 8
			;free up eax
		mov		DWORD[ebp - 4], eax
			;initialize the indexer
		mov		DWORD [ebp - 8], 0
		topMenuLoop2:
		mov		ecx, DWORD [ebp - 8]
		lea		edx, [mainMenu2 + ecx]
		cmp		eax, 0xffffffff
		je		endMenuLoop2
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
		jmp		topMenuLoop2
		endMenuLoop2:
			;close the file
		push	DWORD [ebp - 4]
		call	fclose
		add		esp, 4
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
			push	21
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
				jmp		minputFound
			menuLeft:
				dec		DWORD [xpos]
				jmp		minputFound
			menuDown:
				inc		DWORD [ypos]
				jmp		minputFound
			menuRight:
				inc		DWORD [xpos]
				jmp		minputFound
			menuSpace:
				jmp		minputFound
			minputFound:
				;save user input
			mov		ebx, eax

			mov		ecx, 0
			mov		eax, 50
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
			
			push	ebx
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

render:
	;has the arguments of character array, width, height
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
				; print the help information
			cmp		DWORD [displayHint], 0
			je		noHint
				push	hintNL
				call	printf
				add		esp, 4
					;after printing the spacer, print the hint text
				mov		esi, 0
				hintLoopTop:
				cmp		esi, 384
				je		hintLoopDone
					lea		ecx, [hintStr + esi]
					push	ecx
					call	printf
					add		esp, 4
					push	hintCarriage
					call	printf
					add		esp, 4
				add		esi, 128
				jmp		hintLoopTop
				hintLoopDone:
					;print another spacer
				push	hintNL
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
				;Print the key string
			push	DWORD[hasKey]
			push	key_str
			call	printf
			add		esp, 8
		renMenu:
		mov		DWORD [lastColor], 100
			;initialize frame buffer index
		mov		ecx, 0
			; outside loop by height
			; i.e. for(c=0; c<height; c++)
		mov		DWORD [ebp - 4], 0
		y_loop_start:
		mov		eax, DWORD [ebp + 8]
		cmp		DWORD [ebp - 4], eax
		je		y_loop_end
				; inside loop by width
				; i.e. for(c=0; c<width; c++)
			mov		DWORD [ebp - 8], 0
			x_loop_start:
			mov		eax, DWORD [ebp + 12]
			cmp		DWORD [ebp - 8], eax
			je 		x_loop_end
					;retrieve the next board character to be printed
				mul		DWORD [ebp - 4]
				add		eax, DWORD [ebp - 8]
				mov		dl, BYTE [ebx + eax]
					; check if (xpos,ypos)=(x,y)
					;save the value of eax
				push	eax
				mov		eax, DWORD [xpos]
				cmp		eax, DWORD [ebp - 8]
				jne		print_board
				mov		eax, DWORD [ypos]
				cmp		eax, DWORD [ebp - 4]
				jne		print_board
						;retrieve eax
					pop		eax
					cmp		ebx, mainMenu2
					je		menuPrint
					cmp		ebx, mainMenu
					jne		printPlayer
					menuPrint:
							;if printing the menu, do this
						lea		edi, [pressPlateColor]
						mov		DWORD [lastColor], 3
						mov		DWORD [colorCode], 3
						push	'>'
						jmp		somewhere
					printPlayer:
							;if printing game board, do this
						lea		edi, [playerColor]
						mov		DWORD [lastColor], 99
						push	'O'
						jmp		somewhere
					somewhere:
						;add the respective color code to the frame buffer
					mov		esi, 0
					selectColorLoop:
					cmp		BYTE [edi + esi], 0
					je		endSelectColorLoop
						mov		dl, BYTE [edi + esi]
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
				pop		eax
				fwag:
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
				je		fuck
				cmp		ebx, mainMenu
				jne		mprint_end
				fuck:	
					push	ebx
					add		ebx, eax
					cmp		DWORD [colorCode], 3
					jne		notOpt
						mov		esi, 0
						SkipLoopTop:
						cmp		BYTE [ebx + esi + 1], ' '
						je		skipLoopEnd
							mov		dl, BYTE [ebx + esi + 1]
							mov		BYTE [frameBuffer + ecx], dl
							inc		ecx
							inc		DWORD [ebp - 8]
						inc		esi
						jmp		SkipLoopTop
						skipLoopEnd:
					notOpt:
					pop		ebx
				mprint_end:	
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

mcharRender:
	push	ebp
	mov		ebp, esp
			mov		DWORD [colorCode], 101
			cmp		BYTE [ebx + eax], ' '
			je		mSpace
			cmp		BYTE [ebx + eax], '-'
			je		isBorder
			cmp		BYTE [ebx + eax], '|'
			je		isBorder
			cmp		BYTE [ebx + eax], ')'
			je		menuOpt
			jmp		notBorder
			mSpace:
				jmp		mAddChar
			isBorder:	
				mov		DWORD [colorCode], 4
				jmp		foundBorder
			menuOpt:
				mov		DWORD [colorCode], 3
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

checkCharMenu:
	push	ebp
	mov		ebp, esp	
		mov		ebx, DWORD [ebp + 8]
		
		cmp		DWORD [xpos], esi
		jne		checkMove
		cmp		DWORD [ypos], edi
		jne		checkMove
			cmp		ebx, mainMenu
			jne		notMain1
				cmp		DWORD [xpos], 30
				jne		notClose
						;if close selected, exit screen
					inc		DWORD [menuEnd]
					jmp		moveCursor
				notClose:
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
				jmp		checkMove
			notMain1:
				cmp		DWORD [ypos], 18
				jne		rawr
						;if cancel selected, exit screen
					inc		DWORD [menuEnd]
					jmp		moveCursor
				rawr:
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
				waiting:
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
			je		bottomRee
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
		je		bottomRee
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
		bottomRee:
		mov		DWORD [xpos], esi
		mov		DWORD [ypos], edi
		moveCursor:
	mov		esp, ebp
	pop		ebp
	ret

gameloop:
	push	ebp
	mov		ebp, esp
		GOHERE:
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
		mov		DWORD [leverDoors], 0
		mov		DWORD [hasKey], 0
		mov		DWORD [gameEnd], 0
		game_loop:
			cmp		DWORD [gameEnd], 1
			je		game_loop_end	
				; draw the game board
			push	board
			push	GWIDTH
			push	GHEIGHT
			call	render
			add		esp, 12
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
				jmp		GOHERE
			inputFound:
				;save user input
			mov		ebx, eax
				; take the potential new pos for the player, and see if it's valid
				; (W * y) + x = pos
			mov		ecx, 0
			mov		eax, GWIDTH
			mul		DWORD [ypos]
			add		eax, DWORD [xpos]
			mov		cl, BYTE [board + eax]
				;call checkCharTest, passing it the current board index
			push	DWORD [ebp + 12]
			call	checkCharTest
			add		esp, 4
				;If the level was completed, proceed to the next one
			cmp		edx, DWORD [ebp + 12]
			je		notComplete
				cmp		edx, 10
				jne		newLevel
					inc		DWORd [ebp + 8]
					mov		DWORD [ebp + 12], 0
					jmp		GOHERE
				newLevel:
					inc		DWORD [ebp + 12]
					jmp		GOHERE
			notComplete:
		jmp		game_loop
		game_loop_end:
	mov		esp, ebp
	pop		ebp
	ret

checkCharTest:
	push	ebp
	mov		ebp, esp
		mov		edx, DWORD [ebp + 8]
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
			cmp	DWORD [leverDoors], 0
			jne		isActive
				mov		DWORD [leverDoors], 1
				jmp		pDefault
			isActive:
			mov		DWORD [leverDoors], 0
			jmp		pDefault
		pStairs:
			waow:
			push	edx
				; clear the screen and print winstr
			push	win_str
			call	printf
			add		esp, 4
				;hold that on the screen
			push	2
			call	sleep
			add		esp, 4
			pop		edx
				;inc the board counter
			inc		edx
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
			lea		ebx, [board + eax - GWIDTH]
			jmp		moveRock
		nextDir2:
			lea		ebx, [board + eax - 1]
			jmp		moveRock
		nextDir3:
			lea		ebx, [board + eax + GWIDTH]
			jmp		moveRock
		nextDir4:
			lea		ebx, [board + eax + 1]
			jmp		moveRock
		moveRock:
			;Check if the character the rock was pushed into is a valid move
			;if not, reset the position of the player
		cmp		BYTE [ebx], ' '
		je		canMove
		cmp		BYTE [ebx], 'P'
		jne		pathBlocked
		canMove:
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
			;populate the door layer
		mov		ebx, 0
		mov		edx, GWIDTH*GHEIGHT
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
		mov		ebx, 0
			;compare the current byte to the various game objects, then
			;change the symbol and color accordingly
		cmp		BYTE [board + eax], 'T'
		je		rWall
		cmp		BYTE [board + eax], ' '
		je		rSpace
		cmp		BYTE [board + eax], 'K'
		je		rKey
		cmp		BYTE [board + eax], 'R'
		je		rRock
		cmp		BYTE [board + eax], 'p'
		je		rRock
		cmp		BYTE [board + eax], 'P'
		je		rPlate
		cmp		BYTE [board + eax], 'L'
		je		rLever
		cmp		BYTE [board + eax], 'l'
		je		rLever
		cmp		BYTE [board + eax], 'S'
		je		rStairs
		cmp		BYTE [board + eax], 'B'
		je		rButton
		cmp		BYTE [board + eax], 'b'
		je		rButton
		cmp		BYTE [board + eax], '_'
		je		rLeverDoor
		cmp		BYTE [board + eax], '|'
		je		rDoor
		cmp		BYTE [board + eax], '%'
		je		rDoor
		cmp		BYTE [board + eax], '*'
		je		rDoor
		cmp		BYTE [board + eax], 'G'
		je		rGem
		cmp		BYTE [board + eax], 'g'
		je		rGem
		cmp		BYTE [board + eax], '^'
		je		rGem
		jmp		rDefault	
		rDoor:
			push	DWORD [board + eax]
			guesswhat:
			cmp		BYTE [ebp - 4], '|'
			jne		boop1
				push	'P'
				jmp		woop
			boop1:
				push	'b'
			woop:			
				call	searchObject
				add		esp, 8
			jmp		rDefault
		rSpace:
			cmp		BYTE [doorLayer + eax], 0
			je		isSpace
				notPlateDoor:
				cmp		BYTE [doorLayer + eax], '_'
				jne		notLeverDoor
					jmp		rLeverDoor
				notLeverDoor:
					push	DWORD [doorLayer + eax]
					jmp		guesswhat
			isSpace:
			jmp		addChar
		rWall:
			mov		DWORD [colorCode], 0
			jmp		rDefault
		rKey:
			mov		DWORD [colorCode], 1
			cmp		dl, 'A'
			jne		rDefault
				mov		dl, '#'
				jmp		rDefault
		rRock:
			mov		DWORD [colorCode], 2
			mov		dl, 'R'
			jmp		rDefault
		rPlate:
			mov		DWORD [colorCode], 3
			jmp		rDefault
		rLever:
			mov		DWORD [colorCode], 4
			cmp		DWORD [leverDoors], 0
			jne		isActive2
				mov		BYTE [board + eax], 'L'
				mov		dl, 'L'
				jmp		rDefault
			isActive2:
			mov		BYTE [board + eax], 'l'
			mov		dl, 'l'
			jmp		rDefault
		rLeverDoor:
			mov		DWORD [colorCode], 4
			cmp		DWORD [leverDoors], 0
			je		lDoorOpen
				;if leverdoors is 1, open lever doors
				cmp		BYTE [board + eax], '#'
				jne		lDoorLayer	
					call	layerSwap
				lDoorLayer:
				mov		dl, ' '
				jmp		rDefault
			;if leverdoors is 0, close the lever doors
			lDoorOpen:
			cmp		BYTE [board + eax], '_'
			je		nlDoorLayer	
				call	layerSwap
			nlDoorLayer:
			mov		dl, '#'
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
			cmp		dl, 'g'
			jne		notGemPlate
				mov		DWORD [colorCode], 10
				mov		dl, 'G'
				jmp		rDefault
			notGemPlate:
			cmp		dl, '^'
			jne		notGemDoor
				mov		ebx, 300
				mov		edi, 0
				gemLoop:
				cmp		edi, ebx
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
				mov		dl, ' '
				jmp		rDefault
				gemsFound:
				mov		dl, '#'
				jmp		rDefault
			notGemDoor:
			jmp	rDefault
		rDefault:
		call	colorFunc
		addChar:
			;load the displayed character into the frame buffer
		mov		BYTE [frameBuffer + ecx], dl
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
				mov		bl, BYTE [edi + esi]
				mov		BYTE [frameBuffer + ecx], bl
				inc		ecx
			inc		esi
			jmp		resetColorLoop
			endResetColorLoop:
		nPlateGem:
	mov		esp, ebp
	pop		ebp
	ret
	
searchObject:
	push	ebp
	mov		ebp, esp
		push	ecx
		push	ebx

		mov		ecx, DWORD [ebp + 8]
		mov		bl, BYTE [ebp + 12]
		mov		edi, 0
			;check the board layer for the repsective object
		testLoop:
		cmp		edi, 320
		je		testPassed
			cmp		BYTE [board + edi], cl
			jne		checkActive
				die:
				;if a button is found, close the button doors
				cmp		BYTE [board + eax], bl
				je		oohh
				cmp		bl, '*'
				je		booo
					whelp:	
					push	ebx
					call	layerSwap
					pop		ebx
					jmp		booo
				oohh:
				cmp		bl, '*'
				je		whelp
				booo:
				cmp		bl, '*'
				jne		notGrey1
					mov		dl, ' '
					jmp		wooooo
				notGrey1:	
					mov		dl, '#'
					jmp		wooooo
			checkActive:
		inc		edi
		jmp		testLoop
			;if a button is not found, open the button doors
		testPassed:
			cmp		BYTE [board + eax], bl
			jne		doorLayer1
				plswork2:
				push	ebx
				call	layerSwap
				pop		ebx
			doorLayer1:
			cmp		BYTE [doorLayer + eax], '*'
			je		plswork2
			cmp		bl, '*'
			jne		notGrey2
				mov		dl, '#'
				jmp		wooooo
			notGrey2:
				mov		dl, ' '
				jmp		wooooo
		wooooo:
		pop		ebx
		pop		ecx
	mov		esp, ebp
	pop		ebp
	ret

colorFunc:
	push	ebp
	mov		ebp, esp
		;use the num in colorCode to load the correct code into edi
		mov		esi, DWORD[colorCode]
		mov		edi, DWORD[colorCodeArray + esi * 4]
			;if the character being loaded into the frame buffer isn't the same as the last one,
			;load each of the bytes for the color code into the frame buffer until we reach a null byte
		cmp		DWORD [lastColor], esi
		je		redundantColor
			mov		esi, 0
			colorLoop:
			cmp		BYTE [edi + esi], 0
			je		endColorLoop
				mov		bl, BYTE [edi + esi]
				mov		BYTE [frameBuffer + ecx], bl
				inc		ecx
			inc		esi
			jmp		colorLoop
			endColorLoop:
			push	DWORD [colorCode]
			pop		DWORD [lastColor]
		redundantColor:
	mov		esp, ebp
	pop		ebp
	ret