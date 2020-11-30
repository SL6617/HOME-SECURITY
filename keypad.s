   #include <xc.inc>

extrn	delay, timer_1_slow_clock, tone_at_res, lower_tone
extrn	LCD_delay_x4us
    
    global	readloop, keypad_press_noise, prepare_CCP4_for_PWM, read_num, kp_setup

rowp			EQU	0x10	;1 byte reserved for row pressed
colp			EQU	0x11	;1 byte reserved for column pressed
num1			EQU	0x12	;1 byte reserved for first keycode number
num2			EQU	0x13	;1 byte reserved for second keycode number 
num3			EQU	0x14	;1 byte reserved for third keycode number 
num4			EQU	0x15	;1 byte reserved for fourth keycode number 
nump			EQU	0x16	;1 byte reserved for number pressed
tries			EQU	0x17	;1 byte reserved for keycode attempts
correct			EQU	0x18	;1 byte reserved for # of correct keys pressed
zero			EQU	0x19	;1 byte reserved for 0
pressed_number		EQU	0x1C

psect keypad_code, class = CODE

;**************************************************************************************
readloop:				; this is a polling loop to see if keypad has been pressed. 
		call	read_num	;read_num determines the number associated with button that has been pressed and saves it to the pressed number register
		movlw	0x0
		cpfsgt	pressed_number, A	    ; is pressed_number greater than zero?
		bra		readloop    ;if not, then no number has been saved i.e button was not pressed - repeat loop untill button has been pressed
		call	keypad_press_noise  ; if yes, then make keypad make indication tone
		return			    ; then return to check1/2/3 or incorrect

;***************************************************************************************
keypad_press_noise:
    	bcf	PORTG, 3,A
	bcf	PORTB, 6, A
	bcf	TRISG, 3, A ;sets pin G3 as output of PWM oscillation (as is standard)
	bsf	TRISB, 6, A ;sets RB6 as input for PWM oscillation which is connected to buzzer	
    prepare_CCP4_for_PWM:  
	clrf	CCP4CON, A ;when you change oscillator frequency, it's important to clear CCP4 register before resetting
	clrf	CCPR4L, A
	clrf	CCPR4H, A
	call	tone_at_res
	call	delay
	call	lower_tone
	call	delay
	clrf	CCP4CON, A
	bsf	TRISG, 3, A
return
;****************************************************************************************
read_num:   ;reads number pressed on keypad, saves 8-bit row+col into W
			    ;rows set high as inputs
	movlw	0b00001111
	movwf	TRISE, A
	movlw	0x10		; wait 40us
	call	LCD_delay_x4us
	movf	PORTE, W, A
	movwf	rowp, A
	btg	rowp, 0, 0
	btg	rowp, 1, 0
	btg	rowp, 2, 0
	btg	rowp, 3, 0
	
	movlw	0b11110000	;cols set high
	movwf	TRISE, A
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movf	PORTE,W, A
	movwf	colp, A
	btg	colp, 4, 0
	btg	colp, 5, 0
	btg	colp, 6, 0
	btg	colp, 7, 0
	
	movlw	0x00
	movf	rowp, W, A  ;row number moved to W
	addwf	colp, W, A  ;W added to col number. result in W
	
	movwf	pressed_number, A
	return
;******************************************************************************	
kp_setup:
	;sets up PORTE pull ups
	banksel	PADCFG1 ; PADCFG1 is not in Access Bank
	bsf	REPU ; PortE pull-ups on
	movlb	0x00 ; set BSR back to Bank 0
	clrf	LATE, A
	clrf	LATD, A
	clrf	TRISF, A
	;sets preset keycode
	movlw	01000010B	;#8
	movwf	num1, A
	movlw	10001000B	;#1
	movwf	num2, A
	movlw	00101000B	;#3
	movwf	num3, A
	movlw	01000100B	;#5
	movwf	num4, A
	clrf	nump, A
	clrf	tries, A
	clrf	rowp, A
	clrf	colp, A
	clrf	correct, A
	clrf	zero, A
	movlw	20		; wait 80us - for keypad pins
	call	LCD_delay_x4us
	return
	
	


