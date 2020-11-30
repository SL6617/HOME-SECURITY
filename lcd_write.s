
    #include <xc.inc>	

extrn	UART_Setup, UART_Transmit_Message  ; external subroutines
extrn	LCD_Setup, LCD_Write_Message	    ;from LCD.S
extrn	LCD_Setup_Bottom, LCD_delay_x4us
extrn	LCD_Setup_Top, LCD_delay_ms    
    
global	writeA, writeB, writeC, writeAa, writeAb, writeBa, writeBb, writeCa, writeCb, writeD, writeDa, writeDb        
    
psect	udata_acs   ; reserve data space in access ram
counter:    ds 1    ; reserve one byte for a counter variable
delay_count:ds 1    ; reserve one byte for counter in the delay routine

;saving message A 
psect	udata_bank1 ; reserve data anywhere in RAM (here at 0x100)
Aa_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data   
messAa:
    	db	' ','E','N','T','E','R',' ','4','-','D','I','G','I','T'
	messAa_l   EQU	15	; length of datA
	align	2
psect	udata_bank2 ; reserve data anywhere in RAM (here at 0x200)
Ab_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data    
messAb:
    	db	' ',' ',' ',' ','K','E','Y','C','O','D','E'
	messAb_l   EQU	12	; length of datA
	align	2
	
;saving message B 
psect	udata_bank3 ; reserve data anywhere in RAM (here at 0x300)
Ba_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data   
messBa:
    	db	' ',' ',' ','I','N','C','O','R','R','E','C','T'
	messBa_l   EQU	13	; length of datA
	align	2
psect	udata_bank4 ; reserve data anywhere in RAM (here at 0x400)
Bb_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data    
messBb:
    	db	' ',' ',' ','T','R','Y',' ','A','G','A','I','N'
	messBb_l   EQU	13	; length of datA
	align	2

;saving message C 
psect	udata_bank5 ; reserve data anywhere in RAM (here at 0x500)
Ca_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data   
messCa:
    	db	'*','*','*','*','C','A','L','L','I','N','G','*','*','*','*','*'
	messCa_l   EQU	17	; length of datA
	align	2
psect	udata_bank6 ; reserve data anywhere in RAM (here at 0x600)
Cb_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data    
messCb:
    	db	'*','*','*','T','H','E',' ','P','O','L','I','C','E','*','*','*'
	messCb_l   EQU	17	; length of datA
	align	2
    
;saving message D
psect	udata_bank7 ; reserve data anywhere in RAM (here at 0x700)
Da_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data   
messDa:
    	db	' ',' ',' ',' ',' ','W','E','L','C','O','M','E',' ',' ',' ',' '
	messDa_l   EQU	17	; length of datA
	align	2
psect	udata_bank8 ; reserve data anywhere in RAM (here at 0x800)
Db_array:    ds 0x80 ; reserve 128 bytes for message data
psect	data    
messDb:
    	db	' ',' ',' ',' ',' ',' ','H','O','M','E',' ',' ',' ',' ',' ',' '
	messDb_l   EQU	17	; length of datA
	align	2	
	
	
psect	lcd_write_code,class=CODE
    
writeA:	;writes 'keycode' message
	call	writeAa
	movlw	20		; wait 80us
	call	LCD_delay_x4us
	call	writeAb
	movlw	20		; wait 80us
	call	LCD_delay_x4us
	return	
	
writeB:	;writes 'incorrect' message
	call	writeBa
	movlw	20		; wait 80us
	call	LCD_delay_x4us
	call	writeBb
	return
	
writeC:	;writes 'police' message
	call	writeCa
	movlw	20		; wait 80us
	call	LCD_delay_x4us
	call	writeCb
	return

writeD:	;writes 'welcome home' message
	call	writeDa
	movlw	20		; wait 80us
	call	LCD_delay_x4us
	call	writeDb
	goto	$
	
writeAa:
	call	LCD_Setup_Top
	lfsr	0, Aa_array	; Load FSR0 with address in RAM	
	movlw	low highword(messAa)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messAa)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messAa)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messAa_l	; bytes to read
	movwf 	counter, A		; our counter register
loopAa: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopAa		; keep going until finished
		
	movlw	messAa_l	; output message to UART
	lfsr	2, Aa_array
	call	UART_Transmit_Message
	
	movlw	messAa_l	; output message to LCD
	lfsr	2, Aa_array
	call	LCD_Write_Message
	return

writeAb:
	call	LCD_Setup_Bottom
	lfsr	0, Ab_array	; Load FSR0 with address in RAM	
	movlw	low highword(messAb)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messAb)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messAb)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messAb_l	; bytes to read
	movwf 	counter, A		; our counter register
loopAb: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopAb		; keep going until finished
		
	movlw	messAb_l	; output message to UART
	lfsr	2, Ab_array
	call	UART_Transmit_Message

	movlw	messAb_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Ab_array
	call	LCD_Write_Message
	return
	
writeBa:
	call	LCD_Setup_Top
	lfsr	0, Ba_array	; Load FSR0 with address in RAM	
	movlw	low highword(messBa)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messBa)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messBa)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messBa_l	; bytes to read
	movwf 	counter, A		; our counter register
loopBa: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopBa		; keep going until finished
		
	movlw	messBa_l	; output message to UART
	lfsr	2, Ba_array
	call	UART_Transmit_Message
	
	movlw	messBa_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Ba_array
	call	LCD_Write_Message
	return	
	
writeBb:
	call	LCD_Setup_Bottom
	lfsr	0, Bb_array	; Load FSR0 with address in RAM	
	movlw	low highword(messBb)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messBb)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messBb)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messBb_l	; bytes to read
	movwf 	counter, A		; our counter register
loopBb: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopBb		; keep going until finished
		
	movlw	messBb_l	; output message to UART
	lfsr	2, Bb_array
	call	UART_Transmit_Message

	movlw	messBb_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Bb_array
	call	LCD_Write_Message
	return	
	
writeCa:
	call	LCD_Setup_Top
	lfsr	0, Ca_array	; Load FSR0 with address in RAM	
	movlw	low highword(messCa)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messCa)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messCa)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messCa_l	; bytes to read
	movwf 	counter, A		; our counter register
loopCa: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopCa		; keep going until finished
		
	movlw	messCa_l	; output message to UART
	lfsr	2, Ca_array
	call	UART_Transmit_Message
	
	movlw	messCa_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Ca_array
	call	LCD_Write_Message
	return

writeCb:
	call	LCD_Setup_Bottom
	lfsr	0, Cb_array	; Load FSR0 with address in RAM	
	movlw	low highword(messCb)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messCb)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messCb)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messCb_l	; bytes to read
	movwf 	counter, A		; our counter register
loopCb: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopCb		; keep going until finished
		
	movlw	messCb_l	; output message to UART
	lfsr	2, Cb_array
	call	UART_Transmit_Message

	movlw	messCb_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Cb_array
	call	LCD_Write_Message
	return	

writeDa:
	call	LCD_Setup_Top
	lfsr	0, Da_array	; Load FSR0 with address in RAM	
	movlw	low highword(messDa)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messDa)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messDa)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messDa_l	; bytes to read
	movwf 	counter, A		; our counter register
loopDa: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopDa		; keep going until finished
		
	movlw	messDa_l	; output message to UART
	lfsr	2, Da_array
	call	UART_Transmit_Message
	
	movlw	messDa_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Da_array
	call	LCD_Write_Message
	return

writeDb:
	call	LCD_Setup_Bottom
	lfsr	0, Db_array	; Load FSR0 with address in RAM	
	movlw	low highword(messDb)	; address of data in PM
	movwf	TBLPTRU, A		; load upper bits to TBLPTRU
	movlw	high(messDb)	; address of data in PM
	movwf	TBLPTRH, A		; load high byte to TBLPTRH
	movlw	low(messDb)	; address of data in PM
	movwf	TBLPTRL, A		; load low byte to TBLPTRL
	movlw	messDb_l	; bytes to read
	movwf 	counter, A		; our counter register
loopDb: tblrd*+			; one byte from PM to TABLAT, increment TBLPRT
	movff	TABLAT, POSTINC0; move data from TABLAT to (FSR0), inc FSR0	
	decfsz	counter, A		; count down to zero
	bra	loopDb		; keep going until finished
		
	movlw	messDb_l	; output message to UART
	lfsr	2, Db_array
	call	UART_Transmit_Message

	movlw	messDb_l	; output message to LCD
	addlw	0xff		; don't send the final carriage return to LCD
	lfsr	2, Db_array
	call	LCD_Write_Message
	return	