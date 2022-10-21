segment .data
    raw_mode_on_cmd		db "stty raw -echo",0
	raw_mode_off_cmd	db "stty -raw echo",0
segment .text
    global  raw_mode_on
    global  raw_mode_off
    
    extern  system

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