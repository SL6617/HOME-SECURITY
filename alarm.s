
#include <xc.inc>
    
global blinky_siren_loop, delay, timer_1_slow_clock, tone_at_res, lower_tone, make_portH_digital

delay_reg		EQU	0x01
another_delay_reg	EQU	0x02
timer_overflow_count	EQU	0xF
	
psect	alarm_code, class=CODE

;************************************************************
delay:
    reset_counter:
	setf	delay_reg, A
	count_down:
	    decfsz	delay_reg, 1, 0 
	    setf	another_delay_reg, A
	    call	another_delay
	    tstfsz	delay_reg, 0
	    bra		count_down
	    return

another_delay:
	decfsz	another_delay_reg, 1, 0
	bra     another_delay
	return

;***************************************************************
timer_1_slow_clock:
    clrf	TMR1L, A
    clrf	TMR1H, A	
    movlw	0b00110000 
    movwf	T1CON, A ;configure timer 1:
			;bit 0 cleared means timer off
			;bit 1 cleared means TMR1 is read/written in two 8 bit operations
			;bit 2 cleared doesn't matter either way as we run timer from internal oscillator 
			;bit 3 cleared means seondary oscillator is disabled -> we run from internal oscillator
			;bit <5,4> as 11 means  1:8 prescaler
			;bit <7,6> as 00 means increment timer every instruction cycle, so freqeucy = fosc/4  = 1Mhz
			;so timer overflow period is 1/1000000 x 0xFFFF x 8  ~ 0.52428s. After this time, a timer 1 interrupt overflow is set then serviced
			;we let this occur 60 times (i.e. 0x3C) before setting off the alarm. 
			; this gives timer count down of ~ 30s	
	clrf timer_overflow_count, A ; clear register that counts how many overflows have occured
    enable_slow_clock_interrupts:
	bsf	PIE1, 0, A  ;enable timer 1 overflow interrupt
	bsf	INTCON, 7, A ;enable all global interrupts
	bsf	INTCON, 6, A ; enable all peripheral interrupts
return

;*****************************************************************	
tone_at_res: ; plays long tone at 3.8khz as our alarm
    movlw	0b01000001 ;PR2 = 0x42 s
    movwf	PR2, A 		
    movlw	0b00111100 ;before 0x3c  ; 1111 selects PWM mode
    movwf	CCP4CON, A    
    movlw	0b00100000
    movwf	CCPR4L, A	
    movlw	0b00000101
    movwf	T2CON, A
    return 

;*********************************************************************
lower_tone: ; plays long tone at ~3khz as our alarm
    movlw   0b01010010	 ;before 0xFF
    movwf   PR2, A 		
    movlw   0b00011100 ;
    movwf   CCP4CON, A   
    movlw   0b00101001;before 0xB5	;0xB5 = 10110101, 8 msb of PWM duy cycle
    movwf   CCPR4L, A	
    movlw   0b00000101	
    movwf   T2CON, A    
    return 
;**********************************************************************
blinky_siren_loop:
    call    tone_at_res ;blare high note at 3.8kHz
    setf    LATJ, A
    call    delay
    call    lower_tone ;blare lower note at 3kHz
    clrf    LATJ, A
    call    delay
    return
;***********************************************************   
make_portH_digital:
    banksel	    ANCON2 ; Select bank with ANCON2 register
    movlw	    0Fh ; Configure PORTH as
    movwf	    ANCON2, A ; digital I/O
    movlw	    0Fh ; Configure PORTH as
    movwf	    ANCON1, A ; digital I/O
    return