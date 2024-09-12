
.def temp=R16 ; register used to store temporary information or numbers
.def phase=R17 ; register used to hold what phase of the game is currently active, such as pre-game, during game, and post-game
.def total=R18 ; register used to store the current total/sum of previous numbers
.def score=R19 ; contains the players score
.def state=R20 ; holds the state of the first push-button, either pressed or unpressed, in order to prevent multiple pushes per number
.def amountShown=R21 ; counter to keep track of the amount of numbers that have been shown
.def randomNumber=R22 ; register that stores the number that has been randomly(pseudo-randomly) generated
.def numberDisplayed=R23 ; regiser that is used to store what number should be displayed on the 7-digit display
.def currentPortB=r24 ; register that stires the current value of portB
.def currentPortD=r25 ; register that stires the current value of port
; after all the definable registers were used, i resorted to using the default names, however, to keep track of what each is referring to, for my, and my markers convenience I have indicated what each is used for commented below:
;r26=randomNumber
;r27=divisor
;r28=CurrentTimerValue
;r29=digitCounter
;r30=firstDigit
;r31=secondDigit

; following lines have been used to set variabled names for the bytes needed to be outputted to each port to represent each digit, split into its Higher and Lower nibble.
.set zeroH=0b0111_0000
.set zeroL=0b0000_0111
.set oneH=0b0001_0000
.set oneL=0b0000_0001
.set twoH=0b1011_0000
.set twoL=0b0000_0110
.set threeH=0b1011_0000
.set threeL=0b0000_0011
.set fourH=0b1101_0000
.set fourL=0b0000_0001
.set fiveH=0b1110_0000
.set fiveL=0b0000_0011
.set sixH=0b1110_0000
.set sixL=0b0000_0111
.set sevenH=0b0011_0000
.set sevenL=0b0000_0001
.set eightH=0b1111_0000
.set eightL=0b0000_0111
.set nineH=0b1111_0000
.set nineL=0b0000_0001

.set preGame=0
.set inGame=2
.set postGame=3
.set divisor=3

.set toggle_oc1a=1<<com1a0
.set countToClear=1<<wgm12
.set preScale=(1<<CS12)|(1<<CS10)
.set timerA=(1<<OCIE1A)

.set interupt0 = (1<<INT0)
.set trigger0 = (1<<ISC01)|(1<<ISC00)
.set interupt1 = (1<<INT1)
.set trigger1=(1<<ISC11)|(1<<ISC10)
.set interuptsOff=0b00000000
.set green = (1<<PB3)
.set red = (1<<PB4)


; the following block is in order to set up the interupt vector table, so that when an interupt is triggered, it sends the program counter to the correct location in memory
.org 0x0000
jmp start
.org 0x0002
jmp button
.org 0x0004
jmp secondButton
.org 0x0016
jmp tick

start: ; the start method is used as an initialization of all important registers and data memory that will be used throughout the program and need to be setup when the device is turned on
	clr temp
	clr phase

	sts OCR1AH, temp
	sts OCR1AL, temp
	sts TIMSK1, temp
	sts TCCR1B, temp
	sts TCNT1H, temp
	sts TCNT1L, temp

	; initialize the interupts in order to respond to the push-buttons
	ldi temp, interupt0|interupt1
	OUT EIMSK, temp
	ldi temp, trigger0|trigger1
	sts EICRA, temp

	ldi r27,1
	ldi r22,0
	
	; set the data direction registers to either input or output as desired
	ldi temp, 0b11111111
	OUT DDRB, temp
	ldi temp, 0b11110011
	OUT DDRD, temp
	ldi temp, 0b11111111
	out ddrc, temp

	sei
	; enable interupts
	rjmp loop ; advance to the main loop of the game
	
begin: ; the 'begin' method is called at the beginning of every game -triggered by the push buttons- and sets up the relevant timers, registers, and equipment-such as the 7-digit display
	cli 

	cpi r27, 1
	breq defaultDivisor
	cpi r22, 0
	breq defaultSpeed
	cpi r27, 10
	brsh defaultDivisor
	cpi r22, 5
	brsh defaultSpeed
	
	; set the timers to count, which is equivalent to 1,2,3,4 seconds on a 16 mHz microprocessor
	
	rcall changeSpeed

	; enable timer A for timer 1
	ldi temp, timerA
	sts TIMSK1, temp
	
	; set the prescale of the timer to 1024, and set the counter to count-to-clear mode, which will thus reset the counter
	ldi temp, preScale|countToClear
	sts TCCR1B, temp


	; set the following registers to their required settings, mostly to 0, however, state and phase need to be set to 1
	ldi temp,0
	ldi total, 0
	ldi score,0
	ldi amountShown,0
	;ldi randomNumber,0
	ldi numberDisplayed,0
	ldi state, 1
	ldi phase, inGame
	ldi r31, 0

	
	;flash a blank display before the game starts
	rcall showBlank

	sei
	ret
	rjmp loop
	reti

beginJump: ; method to branch to begin method due to branch out of range error
	rjmp begin

defaultDivisor: ; method that sets the default divisor to 3 if the player does not choose a divisor for themself
	ldi r27,3
	rjmp begin
defaultSpeed: ; method that sets the default speed to 3 if the player does not choose a speed for themself
	ldi r22,3
	rjmp begin

changeSpeed: ; method that sets the speed of the game based on the user input
	cpi r22, 1 
	breq speed_1
	cpi r22, 2
	breq speed_2
	cpi r22, 3
	breq speed_3
	cpi r22, 4
	breq speed_4
	ret


; next 4 functions adjust the timer to count to a specific value corresponding to a specific time period and therefore, speed.
speed_1:
	ldi temp, 0x3D
	sts OCR1AH, temp
	ldi temp, 0x09
	sts OCR1AL, temp
	ret
speed_2:
	ldi temp, 0x7A
	sts OCR1AH, temp
	ldi temp, 0x12
	sts OCR1AL, temp
	ret
speed_3:
	ldi temp, 0xB7
	sts OCR1AH, temp
	ldi temp, 0x1B
	sts OCR1AL, temp
	ret
speed_4:
	ldi temp, 0xF4
	sts OCR1AH, temp
	ldi temp, 0x24
	sts OCR1AL, temp
	ret
	

button:	; method that is called whenever the first push-button interupt is triggered, this button is used to start the game as well as select a number, when the total is divisible by the required divisor
	ldi r26,0 ; reset the random number generator seed
	cpi state, 1 ; if the button has already been pushed for the current number, ignore the button press and return to the loop, this is to avoid button debouncing
	breq loop
	inc state ; otherwise set the state to show that the button has been pressed on the current number
	cpi phase, inGame
	breq check ; if the game is still in the playing phase, check if the sum is divisible by the divisor
	inc phase
	rcall showBlank
	cpi phase, inGame
	breq beginJump
	
	reti 

secondButton: ; method that is called whenever the second push-button interupt is triggered, this button is used to cycle through numbers before a game starts to enable a player to choose a divisor for the game, as well as skip a number once the game has started to speed up the game and allow the player to answer more numbers
	ldi state, 0
	cpi phase, postGame
	brsh rechooseDivisor ; if the previous game has ended, skip to rechoose a new divisor and therefore start a new game
	cpi phase, inGame
	breq skip ; if one is still 'inGame' I.E: they are busy playing, the button press will be used to skip the current number
	; if it is neither 'postGame' or 'inGame' it is pre-game and thus the divisor is being set
	cpi phase, 1
	breq incrementDivisor
	inc r22
	mov numberDisplayed, r22
	rcall showNumber
	
	reti

incrementDivisor:
	ldi amountShown,0 ;reset the amountShown so as to reset the time of the next game
	inc r27 ; increase the divisor by one, each press
	mov numberDisplayed, r27 ; update the display to show the divisor
	rcall showNumber
	reti
rechooseDivisor: ; used for games following the first game, to enable the player to choose a new divisor to play the next game instance with and tell the device that they desire to start a new game, sending it into the 'pre-game' phase
	ldi phase, 0;preGame ; increase the phase of the game to enable one to choose the next divisor
	rjmp secondButton

tick: ; method that is called whenever the timer0 interupt is called, most commonly used to show the next number once 3 seconds has passed, but is also used to flash the games result for 2 seconds between its digits and the blank display
	cpi phase, postGame ; if the game is in the 'postGame' phase, the tick method needs to call the 'resultTickjump' method 
	brsh resultTickjump
	cpi phase, inGame;preGame ; if the timer interupt is triggered during the pre-game, no effect is needed and the game returns to the main loop
	brlo loop
	ldi state, 0 ; the state of the push-button is set to zero when the new number is about to be shown, to enable the player to answer for the upcoming number
	cpi amountShown,60 ; checks whether the 60 second game time is finished
	brsh resultJump ; if it is, then it must branch to show the result/score of the game

	add amountShown, r22; otherwise increment the time by 3, to represent the 3 seconds that each timer interupt is triggered

	rcall rng ; call the random number generator to generate a the next number that will be used 
	add total, numberDisplayed ; add the new number to the sum of the previous numbers
	rcall distract
	rcall showNumber ; display the number
	reti
	ret
loop: ; the main loop of the game, it is used to keep the system idle and wait for interupts to occur, as well as play an important role in generating the random numbers of the game
	nop
	sei 
	inc r26 ; increment the rng seed 
	cpi r26,8 ; ensure that the seed is between 0-8
	brne loop ; if it is branch back to loop
	ldi r26, 0 ; otherwise set the seed to 0 and then go back to loop
	rjmp loop 

check: ; method that checks whether the current total of the numbers shown is a multiple of the chosen divisor, and branches depending on if it is in order to adjust the score, it also clears the total before the next number is shown
	cpi total, 0 ; if the total is 0, then it is divisible 
	breq divisible
	cpi total,0
	brmi notDivisible ; if the total is less than zero than it is not divisible
	mov temp, r27 ; load the divisor into the temporary register
	sub total, temp ; subtract the divisor from the total and recheck the new total
	rjmp check

resultTickJump: ;branch used because relative branch out of reach
	rjmp resultTick

skip: ; method that is triggered when the second button is pressed during the game, indicating that the player wants to 'skip' to the next number
	lds temp, tcnt1l
	lds r28, tcnt1h ; load in the current value of the timer(high byte) to r28, to estimate the time has occured since the number was displayed
	cpi r28, 0x10
	brlo debounce
	cpi r28, 0x3d ; compare if it has been one second
	brlo skip_2s ; if it has been one second, then the game needs to adjust the time by a 2 seconds correction
	cpi r28, 0x7a ;compare if it has been 2 seconds
	brlo skip_1s ; if it has been two seconds, then the game needs to adjust the time by a 1 second correction 
	cpi r28, 0xf4
	brlo skip_0s
	rjmp reset_timer ;then reset the number so that the next number is also displayed for 3 full seconds

debounce:
	reti

reset_timer: ; resets the current counter in the timer, so that the next number after the skip is still displayed for the correct 3 seconds
	ldi temp, 0
	sts tcnt1h, temp
	ldi temp, 0
	sts tcnt1l, temp
	rjmp tick

skip_2s: ; triggered when one skips a number with ~ 2 seconds before the next number was intended to be shown, in order to adjust the game to run for the required 60 seconds
	sub amountShown, r22
	inc amountShown
	
	rjmp reset_timer

skip_1s: ; triggered when one skips a number with ~ 1 seconds before the next number was intended to be shown, in order to adjust the game to run for the required 60 seconds
	sub amountShown, r22
	inc amountShown
	inc amountShown
	rjmp reset_timer

skip_0s:
	sub amountShown, r22
	inc amountShown
	inc amountShown
	inc amountShown
	rjmp reset_timer
resultJump:
	rjmp result
divisible: ; called when the 'check' method has concluded that the total is divisible by the divisor, the score is thus incremented and the green LED is lit to indicate a correct answer
	inc score 
	clr total
	mov temp, currentPortB
	ori temp,green
	out portb, temp
	rjmp loop

notDivisible:  ; called when the 'check' method has concluded that the total is  NOT divisible by the divisor, it then minuses two from the score, unless that would result in a negative score, in that case a score of 0 is set
	clr total
	mov temp, currentPortB
	ori temp,red
	out portb, temp
	subi score,2
	cpi score, 0
	brpl loop 
	ldi score, 0 ; if the score would be a negative, load a 0 as the score, since the score cannot be negative
	rjmp loop
	
result:  ; 'result' is called when the game has finished and the resulting score needs to be shown, the push-button interupts are temporarily disabled, the timer is changed to count to 2 seconds in order to display the result correctly and it is checked whether the result is single or double digits
	cli
	rcall showBlank ; clear the display
	mov r30, score ; store the score of the game in r30
	ldi temp, interuptsOff ; temporarily disable the push-button interupts
	out eimsk, temp

	inc phase ; increment the phase of the game
	ldi phase, postGame
	ldi r18,1 ; 

	;change the timer to count to 2 seconds rather than the original chosen seconds during the game
	ldi temp, 0x7A 
	sts OCR1AH, temp
	ldi temp, 0x12
	sts OCR1AL, temp

	;compare the score, if it is greater than 10, branch to double digit, otherwise branch to single digit
	cpi score, 10
	brlo singleDigitResult
	rjmp doubleDigitResult

singleDigitResult: ; method that is called when the result of a game is a single digit
	ldi r29, 1 ; indicates the result is only 1 digit
	rjmp loop

doubleDigitResult: ; first method that is called when the result is double-digits
	mov temp, score ; store the score in the temporary register

doubleDigitResult2: ; determines what the first digit of the result 
	inc r31 ; increment the second digit
	subi temp, 10 ; subtract 10 from the score, representing the 10 that is now stored by raising the value of the 10's digit by 1
	cpi temp, 10 
	brsh doubleDigitResult2 ; if the number is 10, or higher, loop back to doubleDigitResult2
	inc phase ; otherwise go to the next phase of the game
	ldi r29, 2 ; indicate that there are two digits in the result
	rcall showBlank
	rjmp loop

resultTick: ; method that is called when the timer 'ticks' after the game has ended, that in turn cycles through flashing, an empty display, then the second digit-if there is one- and then the first digit
	ldi temp, 0b00000000 
	out portc, temp ; clear the decimal point on the display
	rcall showBlank
	cpi phase, 5 
	breq secondDigit ; if the phase of the game is in 4, then show the second digit of the result - the 10's digit
	cpi phase, 4 
	breq firstDigit ; else if it is the 3rd phase of the game, show the first digit of the result - the 1's column
	add phase, r29 ; if the game is still in the 'postGame' - so the player has not yet started the next game - add the amount of digits to phase, so that if it is 2 digits it will then repeat by showing first the second digit and then the first, and will otherwise just repeat by showing the only digit of the result
	rcall showBlank ; otherwise show a blank display
	rjmp end ; jump to end

end: ; method that is used at the end of each game, the push-button interupts are re-enabled for one to start a new game, the timer is reset- from 60s to 0s and is returned to the loop
	ldi temp, interupt0|interupt1 
	OUT EIMSK, temp ;re-enable the push-button interupts so that the player can begin the next game
	ldi amountShown, 0 ; restart the time of the game
	ldi r27,1 ; reset the divisor so that the player may choose a new divisor to play with
	ldi r22,0
	rjmp loop 

secondDigit: ; function that is used to output the neccessary outputs in order to display the second digit -as well as the green and red LEDs to show that the game is over.
	
	dec phase ; decrement the phase
	mov numberDisplayed, r31 ; r31 holds the number corresponding to the first digit, therefore it is moved into numberDisplayed
	rcall showNumber ; show the number
	mov temp, currentPortB ; load what is currently in portB to temporary register
	ori temp,green ; add the corresponding bit for the green LED
	ori temp,red ; add the corresponding bit for the red LED
	out portb, temp ; output the temporary register to portB, which will also light the green and red LED's
	subi score, 10 ;
	rjmp loop

firstDigit: ; function that is used to output the neccessary outputs in order to display the first digit -as well as the green and red LEDs to show that the game is over.
	dec phase ; decrement the phase
	mov numberDisplayed, score 
	rcall showNumber ; display the score on the display
	mov temp, currentPortB  ; load what is currently in portB to temporary register
	ori temp,green; add the corresponding bit for the green LED
	ori temp,red ; add the corresponding bit for the red LED
	out portb, temp ; output the temporary register to portB, which will also light the green and red LED's
	cpi r29, 2 
	breq undoScore ; if the result is a 2 digit number, undoScore is needed to do the correction of the score
	rjmp loop

undoScore: ; in order to undo the altering of score done in 'secondDigit' and to shine the decimal point, this is only called during the 'first digit' of a result that has 2 digits
	ldi temp, 0b00000001 
	out portc, temp ; display the decimal point on the display
	mov score, r30 ; store the score
	cpi r18, 1 
	breq initialResult
	rjmp loop
	
initialResult: ; method that is used to avoid a bug resulting when a 2 digit result was being shown
	dec r18
	rcall showBlank
	rjmp resultTick

showBlank: ; method that outputs a blank display 
	ldi currentPortD, 0b00000000
	out portd, currentPortD;green and red led
	ldi currentPortB, 0b00000000
	out portb, currentPortB
	ldi temp, 0
	out portc, temp
	ret
	reti
	
showNumber: ; method that is used to display a number - that is loaded into register 'numberDisplayed'- onto the 7-digit display
	; it checks what number is currently in 'numberDisplayed' and calls the required method that will output to the necessary pins in order to display the number 
	cpi numberDisplayed, 0
	breq showZero
	cpi numberDisplayed, 1
	breq showOne
	cpi numberDisplayed, 2
	breq showTwo
	cpi numberDisplayed, 3
	breq showThree
	cpi numberDisplayed, 4
	breq showFour
	cpi numberDisplayed, 5
	breq showFive
	cpi numberDisplayed, 6
	breq showSix
	cpi numberDisplayed, 7
	breq showSeven
	cpi numberDisplayed, 8
	breq showEight
	cpi numberDisplayed, 9
	breq showNine

showZero: ; used to output a zero to the 7-digit display
	ldi currentPortD, zeroH
	out portd, currentPortD
	ldi currentPortB, zeroL
	out portb, currentPortB
	ret
showOne:  ; used to output a one to the 7-digit display
	ldi currentPortD, oneH
	out portd, currentPortD
	ldi currentPortB, oneL
	out portb, currentPortB
	ret
showTwo:  ; used to output a two to the 7-digit display
	ldi currentPortD, twoH
	out portd, currentPortD
	ldi currentPortB, twoL
	out portb, currentPortB
	ret
showThree:  ; used to output a three to the 7-digit display
	ldi currentPortD, threeH
	out portd, currentPortD
	ldi currentPortB, threeL
	out portb, currentPortB
	ret
showFour:  ; used to output a four to the 7-digit display
	ldi currentPortD, fourH
	out portd, currentPortD
	ldi currentPortB, fourL
	out portb, currentPortB
	ret

showFive:  ; used to output a five to the 7-digit display
	ldi currentPortD, FiveH
	out portd, currentPortD
	ldi currentPortB, FiveL
	out portb, currentPortB
	ret
showSix:  ; used to output a six to the 7-digit display
	ldi currentPortD, sixH
	out portd, currentPortD
	ldi currentPortB, sixL
	out portb, currentPortB
	ret
showSeven:  ; used to output a seven to the 7-digit display
	ldi currentPortD, sevenH
	out portd, currentPortD
	ldi currentPortB, sevenL
	out portb, currentPortB
	ret
showEight:  ; used to output an eight to the 7-digit display
	ldi currentPortD, eightH
	out portd, currentPortD
	ldi currentPortB, eightL
	out portb, currentPortB
	ret
showNine:  ; used to output a nine to the 7-digit display
	ldi currentPortD, nineH
	out portd, currentPortD
	ldi currentPortB, nineL
	out portb, currentPortB
	ret


rng: ; funtion that generates a random number
	clr temp
	inc r26
	mov temp, r26
	mov numberDisplayed, temp
	ret

	; function that causes a distraction for the player to adjust to
distract:
; the rest of the function checks whether or not the current sum+1 is a prime number or not, if it is, a yellow LED is lit to distract the player
checkPrime: ; beginning of the method that checks for primes
	mov temp, total
	inc temp 
	push r27
	ldi r27, 2
primeCheck: ; if the sum+1 is divisble by the number, then it is not a prime, otherwise it will loop to try the next number
	cpi temp, 0
	breq notPrime
	cpi temp, 0
	brmi nextInt
	sub temp, r27
	rjmp primeCheck

nextInt: ; setup for the next integer to check if it divides the number, if the integer is equal to the total(would even be sufficient to check up to the square root of the total) and no divisor has been found, then it is a prime number
	inc r27
	cp r27, total
	breq isPrime
	mov temp, total
	inc temp
	rjmp primeCheck
isPrime: ; if it is prime light the yellow LED and return
	ldi temp, 0b00000010
	out portc, temp
	pop r27
	ret
notPrime: ; if it is not prime, turn the yellow LED off and return
	ldi temp, 0b00000000
	out portc, temp
	pop r27
	ret


/* extra random number generator
	mov temp, total 
	lds temp2, tcnt1l
	add temp, temp2 
	swap temp 
	cpi temp, 10
	brsh rand 
	mov numberDisplayed, temp
	ret
rand:
	subi temp, 10
	cpi temp, 10
	brsh rand
	mov numberDisplayed, temp
	ret
*/