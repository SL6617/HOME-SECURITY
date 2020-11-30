#include <xc.inc>

global  ranger_set_up, ranger_reading, disable_interrupts, silent_PWM, INTOSC_set_up_2Mhz, find_time_difference
psect data
 
delay_reg		EQU	0x01
another_delay_reg	EQU	0x02
rising_time_low		EQU	0x03
rising_time_high	EQU	0x04
falling_time_low	EQU	0x05
falling_time_high	EQU	0x06
capture_indicator	EQU	0x07
pulse_length_low	EQU	0x08
pulse_length_high	EQU	0x09
no_ones_here_width_low	EQU	0xA
no_ones_here_width_high	EQU	0xB
time_difference_low     EQU	0xC
time_difference_high	EQU	0xD	
CCP7_interrupt_counter	EQU	0xE
timer_overflow_count	EQU	0xF

psect sensor_code, class=CODE
	
ranger_set_up:  
    call disable_interrupts   
    clear_data_registers:	    ;clears all registers from data of previous pusle measurements     
	clrf rising_time_low, A		
	clrf rising_time_high, A	
	clrf falling_time_low, A	
	clrf falling_time_high, A	
	clrf pulse_length_low, A	
	clrf pulse_length_high, A	
    set_ranger_initial_pulse_output_pin:
	bcf	TRISG, 1, A	;sets G1 as output so we can send wake up pulse to ranger    
    cature_indication_reg_set_up: ;this register gets cleared when an interrupt happens and clear everywhere else, to prevent retfie returning to a never ending loop
	setf    capture_indicator, A
    timer_1_capture_setup:   
	clrf    TMR1L, A	;clear the timer registers to make sure we count from zero
	clrf    TMR1H, A    
	movlw   0b01000000 
	movwf   T1CON, A ;configure timer 1:
			;bit 0 cleared means timer off
			;bit 1 cleared means TMR1 is read/written in two 8 bit operations
			;bit 2 cleared doesn;t matter eaither way as we run timer from internal oscillator 
			;bit 3 cleared means seondary oscillator is disabled -> we run from internal oscillator
			;bit <5,4> as 00 means that no prescaler (i.e. 1:1 - timer incrememnts every clock cycle)
			;bit <7,6> as 01 means increment timer every clock cycle, so freqeucy = fosc = 2MHz   
    configure_rising:
    	make_RH6_input_for_CCP7_capture:
	    bsf	    TRISH, 6, A
	    clrf    CCPR7H, A ; clear data registers of the CCP5 module 
	    clrf    CCPR7L, A    
    clear_flags:
	bcf PIR1, 0, A ;clear TMR1IF and CCP5IF before enabling interrupts, good practice to do so.
	bcf PIR4, 4, A
    enable_interrupts: ;enable all interrupts 
	    bsf	PIE4, 4, A ;sets the CCP5IE 'interrupt enabled' so that CCPR5IF can be set when capture occurs
	    bsf	PIE1,0,A ; sets the timer 1 global nterrupt enable bit TMR1IE, which is flagged when timer overflows 
	    bsf	INTCON, 6, A ;sets the enable all peripheral interrupts
	    bsf	INTCON, 7, A ; enables all global interrupts
	    bcf INTCON, 3, A; disable port B mismatch interrupt, thi
    
return

ranger_reading: ;send out initial pulse, returns with length of echo pulse saved to 0x08 and 0x09
	initial_pulse: ; ultrasonic ranger wakes up by being triggerd by short pulse in range 2 - 5 us 	    
	    bsf PORTG, 1, A ;on and off of PORTG creates output square pulse period 1/(fosc = 2E6) * (no. clock cycles = 8) ~ 4us long 
	    bcf PORTG,1,A
	    bsf	TRISG, 1, A ;sets G1 as input for ranger 
	enable_CCP7: ;do this and turn timer on during the hold off time between inital pulse and triggering of ranging rising edge
	    movlw   0b00000101 ; configure capture mode:
				;bits <3,2,1,0> as 0101 means capture on every rising edge
	    movwf   CCP7CON, A	; bits 4,5,6,7 not relevant for capture mode	
	timer_on:
	    bsf	    T1CON, 0, A ; turns on timer TMR1ON = bit  0
	capturing: ;wait here for first, rising edge interrupt (setting CCPR5IF) which will send us to interrupt service routine
	    TSTFSZ  capture_indicator, A ;is caputre indicator is clear -> capture hence interrupt has just occured, move on to save the data of CCPR5 
	    goto    capturing ; if capture hasn't just occured, keep scanning until one does	
	saving_data:	   
	    rising_or_falling:		
		btfsc	CCP7CON, 0, A	    ; is this capture the rising, or falling edge? If falling --> CCP7CON<0> = 0, if rising then this is set
		goto	save_CCPR5_rising   ; hence if set, rising and go to save CCPR7 into rising data registers
		goto	save_CCPR5_falling  ; if clear then save CCPR7 registers into falling data registers
	    save_CCPR5_rising:
		setf	capture_indicator, A   ;reset the capture indicator register as holding 0xFF ready for next capture 
		movf	CCPR7L, W, A	    ;save low byte of CCPR7 captured timer data to rising_low reg - otherwise this will be overwritten when falling capture occurs
		movwf	rising_time_low, A    
		movf	CCPR7H, W, A	    ;save high byte of CCPR7 to rising_high_reg
		movwf	rising_time_high, A
	    configure_falling:	
		movlw	0b00000100  ;reconfigure CCP7CON to now detect falling edge of pulse
		movwf	CCP7CON, A	    ;falling if CCP7CON<3:0> = 0100
		goto	capturing   ;return to capturing loop, waiting for falling edge to occur
	    save_CCPR5_falling:		
		movf	CCPR7L, W , A  ;save low byte of CCPR7 captured timer data to falling_low reg
		movwf	falling_time_low, A
		movf	CCPR7H, W, A  ;save high byte of CCPR7 to falling_reg_high
		movwf	falling_time_high,A	
	timer_off_and_reset:    
	    bcf T1CON, 0, A	    ;turn off timer 1, pulse has been fully measured
	    clrf CCP7CON, A	    ;clear CCP7CON to disable Capture mode of CCP7
	measure_pulse_width:		    ;subtract falling pulse length from rising pulse time to get length of 'on time' of pulse					    ;must do high and low bytes separately as 16 bit numbers are saved in two 8 bit registers
	    movf	rising_time_low, W, A  ;subtract low bits first as carry bits may be required
	    subwf	falling_time_low, W, A
	    btfss	STATUS, 0, A	    ;bit 0 is bcarry bit, if this is clear then we should account for this by decreasing falling time_hgih by 1
	    decf	falling_time_high, F, A
	    movwf	pulse_length_low, A    ; save calculated falling_low - rising_low = pulse_length_low --> new register
	    movf	rising_time_high, W, A
	    subwf	falling_time_high, W,A
	    movwf	pulse_length_high, A   ; save calculated falling_high - rising_high = pulse_length_high --> new register
	  
return



disable_interrupts: ;enable all interrupts 
	    bcf	PIE4, 4, A ;sets the CCP5IE 'interrupt enabled' so that CCPR5IF can be set when capture occurs
	    bcf	PIE1,0,A ; sets the timer 1 global nterrupt enable bit TMR1IE, which is flagged when timer overflows 
	    bcf	INTCON, 6, A ;sets the enable all peripheral interrupts
	    bcf	INTCON, 7, A ; enables all global interrupts
	    bcf INTCON, 3, A; disable port B mismatch interrupt, this is annoying
	    return

silent_PWM: 
    clrf   PR2, A
    clrf   CCP4CON, A			;before 0xB5	;0xB5 = 10110101, 8 msb of PWM duy cycle
    clrf   CCPR4L, A	
    clrf   T2CON, A   
    return


	


INTOSC_set_up_2Mhz:
    bcf	    OSCTUNE, 6, A ;disable PLL to times frequency by 4
    
    movlw   0b11000100; configures internal oscillator:
    movwf   OSCCON, A	;bits <1,0> 00 means chosen oscillator is as default - HF- intosc with PLL disabled
			;bit 2 set means HF-INTOSC frequency is stable 
			;bit 3 cleared means seondary oscillator is disabled -> we run from default oscillator of fosc so fine
			;bit <6,5,4> as 100 means 2MHz freuency oscillation 
			;bit 7 set means device enters idle when sleep executed
    return
    
		
find_time_difference:
		movf	pulse_length_low, W, A
		subwf	no_ones_here_width_low, W, A
		btfss	STATUS, 0, A ;bit 0 is carry bit
		decf	no_ones_here_width_high, F, A
		movwf	time_difference_low, A
		movf	pulse_length_high, W,A
		subwf	no_ones_here_width_high, W,A
		movwf	time_difference_high, A
		return

	   