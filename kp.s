#include <xc.inc>

extrn	UART_Setup, UART_Transmit_Message  ; external subroutines
extrn	LCD_Setup, LCD_Write_Message
extrn	LCD_Setup_Bottom, LCD_delay_x4us
extrn	LCD_Setup_Top, LCD_delay_ms

psect	udata_acs   ; reserve data space in access ram  
rowp:	ds 1	;1 byte reserved for row pressed
colp:	ds 1	;1 byte reserved for column pressed
num1:	ds 1	;1 byte reserved for first keycode number
num2:	ds 1	;1 byte reserved for second keycode number 
num3:	ds 1	;1 byte reserved for third keycode number 
num4:	ds 1	;1 byte reserved for fourth keycode number 
nump:	ds 1	;1 byte reserved for number pressed
tries:	ds 1	;1 byte reserved for keycode attempts
    
psect	code, abs	
rst: 	org 0x0
 	goto	setup

kp_setup:
	;sets up PORTE pull ups
	banksel	PADCFG1 ; PADCFG1 is not in Access Bank
	bsf	REPU ; PortE pull-ups on
	clrf	LATE
	movlw	00101000B	;sets preset keycode
	movwf	num1, A
	movlw	01000010B
	movwf	num2, A
	movlw	00010010B
	movwf	num3, A
	movlw	00100100B
	movwf	num4, A
	clrf	nump
	clrf	tries
	movlw	20		; wait 80us - for keypad pins
	call	LCD_delay_x4us
	return

read_num:
	movlw	0x0f	;rows set high
	movwf	TRISE
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movff	PORTE, rowp
	btg rowp, 0, 0
	btg rowp, 1, 0
	btg rowp, 2, 0
	btg rowp, 3, 0

	movlw	11110000B	;cols set high
	movwf	TRISE
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	movff	PORTE, colp
	btg colp, 0, 0
	btg colp, 1, 0
	btg colp, 2, 0
	btg colp, 3, 0
	return

num_save:
	call	read_num
	movf	rowp, 0
	addwf	colp, 0	    ;rowp added to colp. result in W
	return
	
main:
	call	num_save
	cpfseq	num1, 0
	bsf	nump, 0, 0  ;will set a bit if it's not equal to saved number
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	call	num_save
	cpfseq	num2, 0
	bsf	nump, 1, 0
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	call	num_save
	cpfseq	num3, 0
	bsf	nump, 2, 0
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	call	num_save
	cpfseq	num4, 0
	bsf	nump, 3, 0
	movlw	10		; wait 40us
	call	LCD_delay_x4us
	
	;if pressed number doesnt match preset keycode (2975), second message will b writte on LCD
	
	movlw	0x0
	cpfseq	nump, 0
	call	writeB
	incf	tries, 1, 0 ;tries incremented. result in tries
	movlw	0x3
	cpfslt	tries
	call	writeC
	return


