#include <pic18_chip_select.inc>
#include <xc.inc>

;*************************EXTERNAL SUBROUTINES WE USE******************************************
extrn	lcd_setup ;from LCD	
extrn	writeA, writeB, writeC, writeD ;from LCD_write	  
extrn	blinky_siren_loop, delay, timer_1_slow_clock, tone_at_res, lower_tone, make_portH_digital ;from alarm
extrn	readloop, keypad_press_noise, prepare_CCP4_for_PWM, read_num, kp_setup ; from keypad
extrn	ranger_set_up, ranger_reading, disable_interrupts, silent_PWM, INTOSC_set_up_2Mhz, find_time_difference ;from sensors
    
;************************* NAMED FILE REGISTERS*************************************************
delay_reg		    EQU		0x01	;used in delay loop
another_delay_reg	    EQU		0x02	;used in shorter, 'another delay' loop
rising_time_low		    EQU		0x03	;stores least significant byte of time rising edge of captured pulse
rising_time_high	    EQU		0x04	;stores most significant byte of time rising edge of captured pulse
falling_time_low	    EQU		0x05	;stores least significant byte of time falling edge of captured pulse
falling_time_high	    EQU		0x06	;stores most significant byte of time fallingedge of captured pulse
capture_indicator	    EQU		0x07	;register which when clear, indicates a capture has occured
pulse_length_low	    EQU		0x08	;contains LSbyte of falling_time - rising_time
pulse_length_high	    EQU		0x09	;contains MSbyte of falling_time - rising_time
no_ones_here_width_low	    EQU		0xA	;stores LSbyte of iniital reading pulse width
no_ones_here_width_high     EQU		0xB	;stores MSbyte of initial reading pulse width
time_difference_low	    EQU		0xC	;stored LSbyte of difference between intiial reading and PIR triggred pulse
time_difference_high	    EQU		0xD	;stored MSbyte of difference between intiial reading and PIR triggred pulse
CCP7_interrupt_counter	    EQU		0xE	;increments every time a Capture interrupt flag 
timer_overflow_count	    EQU		0xF	;counts the number of times the timer 1 has overflowed for 30s counter
rowp			    EQU		0x10	;1 byte reserved for row pressed
colp			    EQU		0x11	;1 byte reserved for column pressed
num1			    EQU		0x12	;1 byte reserved for first keycode number
num2			    EQU		0x13	;1 byte reserved for second keycode number 
num3			    EQU		0x14	;1 byte reserved for third keycode number 
num4			    EQU		0x15	;1 byte reserved for fourth keycode number 
nump			    EQU		0x16	;1 byte reserved for number pressed
tries			    EQU		0x17	;1 byte reserved for keycode attempts
correct			    EQU		0x18	;1 byte reserved for # of correct keys pressed
zero			    EQU		0x19	;1 byte reserved for 0
pressed_number		    EQU		0x1C	;stores value of the button number that hs just been pressed

	
psect	code, abs
    
;**************************** RESET VECTOR ********************************************
reset_vector:	
    org 0x0
    goto	start

;**************************** INTERRUPT SERVICE ROUTINE *********************************
interrupt_service_routine: 
    org 0x0008

check_CCP7IF:
    btfsc	PIR4, 4, A	    ;is the CCP7 flag clear? if so then check timer for overflow.
    goto	clear_CCP7_flag	    ;if CCP7IF flag is set then capture has occured! 

check_TMR1IF:
    btfsc	PIR1, 0, A	    ; is timer interrupt flag clear? if not then clear it
    goto	clear_TMR1IF

clear_TMR1IF:
    bcf	    PIR1, 0, A		    ;clear tbe timer1 interrupt flag
    incf    timer_overflow_count, A
    movlw   0x3c
    cpfsgt  timer_overflow_count, A
    retfie			    ;return from interrupt routine and re-enable global interrupts    
    goto   slow_timer_off

clear_CCP7_flag:
    clrf    capture_indicator, A
    incf    CCP7_interrupt_counter, A
    bcf	    PIR4,4, A		    ;clear the CCPR7 interrupt flag immediately  
    retfie

slow_timer_off:
    bcf	    T1CON, 0, A		    ; turn off timer
    bcf	    PIE1, 0, A		    ;disables timer 1 interrupts
    goto    police
    
  
;********************** ARMING THE SYSTEM ***************************************************
start:
    set_oscillator:
	call    INTOSC_set_up_2Mhz  ;set internal oscillator to run at 2MHz 

    is_the_system_armed:	
	    make_portH_digitalSD:
	    call    make_portH_digital ;this sets all of PORTH as digital inputs
	    bsf	    TRISH,0 , A		;make H0 an output

	polling_for_arming:
		btfss	PORTH, 0, A		; has switch at H0 been turned on?
		bra	polling_for_arming	; No. keep checking
	
;********************** INTRUDER DETECTION PHASE ******************************************  
checking_for_human: 

    no_one_around_ranger_reading:
	call    ranger_set_up	; ranger set up required before we 
	call	ranger_reading ;this initial reading is what ranger reads with no motion detected 
	movff	pulse_length_low, no_ones_here_width_low ; this saves result of intial reading to a register we can compare to later
	movff	pulse_length_high, no_ones_here_width_high

	
    PIR_check: 
	PIR_on:
	    bsf		TRISG, 0, A ;make pin RG0 input pin for PIR signal, which is high when motion detected for xx seconds
	scanning:
	    call	delay	    ;insertting small delay between repetitions of 'if' questions prevents sending double trigger pulses when voltage is detected
	    btfss	PORTG, 0, A ;is voltage at pin G0 zero? if so, keep scanning. If not, something moved, triggering signal on PIR. proceed to check ranger
	    bra		scanning    ;go back to scanning

   
    ranger_check:		
		    
	bcf	PORTG, 0, A	    ;clear PORTG<0> incase it;s been set previously
	bcf	TRISG, 0, A	    ;set RG0 as input pin
	
	call	ranger_set_up	    ;set up ranger, primed to capture first rising edge of echo pulse
	call	ranger_reading	    ;take a 'PIR triggered' reading from the ranger - after inital 4us pulse 
    
	compare_no_one_around_to_ranger_check:	    ;if motion sensor triggered ranger check pulse is longer than 
						    ; no_ones_here pulse. This would suggests there is still no one present (diffrence is due to ranger reading errors)
						    ;we return to PIR check. If it's shorter, there could be someone there,
						    ;we see how much shorter, if less than error of ranger readings - return to PIR check.
						    ;if significantly shorter, goto 20s count down timer and set up LED and keypad.	   
						    ;we return to PIR check. If it's shorter, there could be someone there,
    
	    which_is_bigger:			    ;we first check if the hgh byte of the no ones_here width is longer than triggred pulse width		   
		movf    no_ones_here_width_high, W, A  ;if so then go straight to subtraction to find the total time difference between the two pulse lengths	
		Cpfslt  pulse_length_high, A	    ;if not, got to check if they are equal
		goto    check_if_equal
		goto    do_the_subtraction
	
	    check_if_equal:			    ;if high bytes are the same, go to compare the length of lower bytes
		cpfseq  pulse_length_high, A	    ;if the high bytes aren't equal, then it must be that no_ones here width is marginnaly shorter than triggered pulse
		goto    PIR_check		    ;this will be due to error fluctuations in ranger reading of same distance, so return to PIR check to poll for PIR detection
	    
	    check_lower_byte:
		movf    no_ones_here_width_low, W , A	;this compares length of lower bytes, if no_one pulse is shorter than triggred, go to PIR cehck
		Cpfslt  pulse_length_low, A		; if we find that triggered pulse is shorter than no_one_width, the go on to the subtraction
		goto    PIR_check
		goto    do_the_subtraction
    
	    do_the_subtraction:				;here we subtract the triggered pulse length from the ehco pulse width when no_one is there
		call find_time_difference
	   
	is_time_difference_significant:			;here we deduce whether or not the difference in time in ranger pulse is due to statistical fluctutaions or the presence of an intruder   
	    movlw	0xF				;this is standard deviation in ranger readings after measuring 1000 pulses with no obstructing object.
	    CPFSGT	time_difference_low, A		;compare time diffference to W, if it's smnot significant, go back to PIR poll. I
	    goto	reset_time_difference_registers	;if not deemed significant we go back to PIR_check
	    goto	end_of_sensors			;if it is significant, then something that moves is close! intruder detection phase is complete

	reset_time_difference_registers:
	    clrf    time_difference_high,A	;before we return to PIR_check, we reset all the tmeporary data storing registers to zero
	    clrf    time_difference_low, A
	    clrf    pulse_length_high, A
	    clrf    pulse_length_high, A	    
	    goto    PIR_check
		   
end_of_sensors:
    call disable_interrupts			;disable interrupts before entering next phase
    
;**************************** SETUP FOR ENABLE / DISABLE ALARM PHASE ************************************************
change_oscillator_to_standard_4MHz:	;LCD requires very specific delays, previous code written with 4MHz clock with PLL enabled (clock frequency 16Mhz) so must change to this
	bsf	OSCTUNE, 6, A	;enable PLL multiplies fosc by4	
	movlw   0b11010100	;configure oscialltor for LCD setup:
	movwf   OSCCON, A	;bits <1,0> 00 means chosen oscillator is as default - HF- intosc with PLL disabled
				;bit 2 set means HF-INTOSC frequency is stable 
				;bit 3 cleared means seondary oscillator is disabled -> we run from default oscillator of fosc so fine
				;bit <6,5,4> as 101 means 4MHz frequency oscillation 
				;bit 7 set means device enters idle when sleep executed   

thirty_seconds_to_disable_alarm: ; 30 second count down timer to give user the chance to disable system before alarm goes off
	call	timer_1_slow_clock

LED_and_keypad_setup: 
	call	lcd_setup	 ;run lcd setup code
	call	kp_setup	 ;run key pad setup code
	clrf	tries, A		 ;tries keeps track of # attempts at pin person has made - if tries exceed three then alarm will set off straight away
	clrf	pressed_number, A	 ;pressed_number records the assigned number on a button when it has been pressed. We clear initially.

turn_timer1_on:
	bsf	T1CON, 0, A	    ;timer should start counting from 0 to FFFF, it will stop after 60 repetitions of this i.e. 30s 
	
main:	
 	clrf	nump, A	    ; clear register that increments number of times buttons have been pushed - every 4 button pushes is a pin attempt.
    have_we_had_less_than_three_tries:
	    movlw	0x03
	    cpfslt	tries, A	    
	    no:
		goto	police ; 3 or more tries mean alarm goes off immediately
	    yes:
		movlw	0x0	  ;if not greater than three, is this the first, second or third try?
		cpfseq	tries, A
		goto	between_1_and_3_tries 
		call	writeA			;if first attempt, LCD reads ' ENTER 4 DIGIT KEYCODE '
		goto	check1			;then goes to check1, to check whether first pressed button is correct
	 between_1_and_3_tries:
		call	writeB			;if second or third attempt, LCD reads ' INCORRECT - TRY AGAIN '
		goto	check1			;then go to check1, to check whether first pressed button is correct
		
	

check1:				    ;checks if the first pressed button matches  correct key-code i.e. is pressed_number eight?
	call	delay		    ; this delay helps to prevent double pressing by mistake
	call	readloop	    ; readloop returns the number associated with the button that has been pressed
	movf	pressed_number, W, A   ; move this pressed_number into W
	cpfseq	num1, A		    ; compares pressed number in W with 1st number in correct keycode (num1 = 8)
	goto	incorrect	    ;if wrong, go to incorrect
	goto	check2		    ;if match then correct so far! proceed to check2
				   
check2:				    ;checks if the second pressed button matches correct key-code i.e. is pressed_number one?
	incf	nump, A		    ;post check1, button has been pressed once so increment nump (AKA number of presses) from 0 -> 1
	call	delay		    ; this delay helps to prevent double pressing by mistake
	call	readloop	    ; readloop returns the number associated with the button that has been pressed
	movf	pressed_number, W, A   ; move this pressed_number into W
	cpfseq	num2, A		    ; compares pressed number in W with 2nd number in correct keycode (num2 = 1)
	goto	incorrect	    ;if wrong, go to incorrect
	goto	check3		    ;if match then correct so far! proceed to check3
	
check3:				    ;checks if the third pressed button matches correct key-code i.e. is pressed_number three?
	incf	nump, A		    ;post check2, button has been pressed twice so increment nump (AKA number of presses) from 1 -> 2
	call	delay		    ; this delay helps to prevent double pressing by mistake
	call	readloop	    ; readloop returns the number associated with the button that has been pressed
	movf	pressed_number, W, A   ; move this pressed_number into W
	cpfseq	num3,A		    ; compares pressed number in W with 3rd number in correct keycode (num3 = 3)
	goto	incorrect	    ;if wrong, go to incorrect
	goto	check4		    ;if match then correct so far! proceed to check4

check4:				    ;checks if the fourth pressed button matches correct key-code i.e. is pressed_number five?
	incf	nump, A		    ;post check3, button has been pressed three times so increment nump (AKA number of presses) from 2 -> 3
	call	delay		    ; this delay helps to prevent double pressing by mistake
	call	readloop	    ; readloop returns the number associated with the button that has been pressed
	movf	pressed_number, W, A   ; move this pressed_number into W
	cpfseq	num4, A		    ; compares pressed number in W with 3rd number in correct keycode (num3 = 3)
	goto	incorrect	    ;if wrong, go to incorrect
	goto	disable_alarm	    ;if correct then key-code has been entred correctly - go and disable the alarm
	
incorrect:				;incorrect returns code back to main for next try if intruder has entered wrong number	
	incf	nump, 1, 0		;once wo
	movlw	0x04
	cpfseq	nump, A
	goto	more_presses_till_wrong
	goto	wrong_attempt_at_pin
	
	more_presses_till_wrong:	; this ensures that regardless whether intruder messed up on 1/2/3/4, they always press 4 times before next attempt
	    call	delay		; delay helps with double pressing errors
	    call	readloop	; enter loop to detect the number that has been pressed
	    call	keypad_press_noise ;makes noise beep when button has been pressed
	    incf	nump, A
	    movlw	0x04
	    cpfseq	nump, A
	    bra		more_presses_till_wrong ; keep repeating until 4 button presses has occured
	
	wrong_attempt_at_pin:
	    incf	tries, A
	    goto	main	
police:
	call	writeC
	goto	buzzer_and_lights

;************************ ALARM SYSTEM ****************************************************
buzzer_and_lights:
	clrf	TRISJ, A ;set portf as output, for LEDS to blink from	
    blinky_and_siren_set_up:  
	bcf	PORTG, 3,A
	bcf	PORTB, 6, A
	bcf	TRISG, 3, A ;sets pin G3 as output of PWM oscillation (as is standard)
	bsf	TRISB, 6, A ;sets RB6 as input for PWM oscillation which is connected to buzzer
	btfsc	PORTH, 0, A
	goto	loop_alarm
	goto	disable_alarm	
	loop_alarm:
	    call    blinky_siren_loop
	    
	
disable_alarm:			
	bcf	T1CON, 0, A	;turns off the timer
	call	silent_PWM	;mskes duty cycle of PWM 0 to stop oscillation
	call	writeD		;displays message 'calling the police'
	call	delay		;delay so message shows for longer
	goto	reset_system

reset_system:
	goto 0x0		;reset the system, must be rearmed before PIR check can commence again

  
    



	









