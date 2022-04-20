            PAGE 0          ;suppress page headings in ASW listing file
; exception EPROM for General Instrument CTS256A-AL2 text-to-speech processor
;
; Syntax is for the Macro Assembler AS V1.42 http://john.ccac.rwth-aachen.de:8000/as/
;
; after a reset, the CTS256 looks for user input from the serial port 
; (9600 bps, 7 data bits, no parity, 2 stop bits) to implement a primitive sort of monitor.
;
; the following monitor commands are supported:
; C - Call subroutine
; D - Display memory
; E - Examine/modify RAM
; F - Fill external RAM
; H - download Intel Hex file
; J - Jump to address
; P - display peripheral memory
; R - display Register file
; S - display Status register
; ESCAPE exits monitor to Text-to-Speech function

            cpu tms70C00    ;TMS7000 family
            
            include allophones.inc
            include functions.inc
            
;addresses within the text-to-speech code in the masked ROM...            
AUDIBLE     equ 0F1ACH
GISPEECH    equ 0F3E7H
SAVE        equ 0F1E2H
ESCAPE      equ 0F1F0H

;registers used by the text-to-speech code in the masked ROM...
F1HI        equ R2
F1LO        equ R3
R1HI        equ R4
R1LO        equ R5
F2LO        equ R7
R2LO        equ R9
F2          equ R11
BUFBVALU    equ R50
WORDCNTH    equ R56
WORDCNTL    equ R57

;registers used by "usercode"
suppress    equ R100                ;suppress leading zeros flag for decimal print function
count       equ R111                ;used by decimal print function
statusreg   equ R112                ;saved copy of status register
errorcount  equ R114                ;checksum error count for hex download function
recordlen   equ R115                ;record length for hex download function
checksum    equ R116                ;checksum for hex download function
spoken      equ R117                ;flag to indicate that the initial test phrase has been spoken
addresshi   equ R118                ;high byte of address pointer
addresslo   equ R119                ;low byte of address pointer
lengthhi    equ R120                ;high byte of length for fill function
lengthlo    equ R121                ;low byte of length for fill function
bytecounter equ R122                ;counter used by hex input function
texthi      equ R123                ;high byte of pointer to text to be printed
textlo      equ R124                ;high byte of pointer to text to be printed
loopcounthi equ R125                ;high byte of the loop counter for flashing LED
loopcountlo equ R126                ;low byte of the loop counter for flashing LED

;I/O ports...
IOCNT0      equ P0                  ;I/O Control register 0
T1DATA      equ P2                  ;Timer 1 Data
T1CTL       equ P3                  ;Timer 1 Control
APORT       equ P4                  ;Port A
ADDR        equ P5                  ;Port A Data Direction Register
BPORT       equ P6                  ;Port B
IOCNT1      equ P16                 ;I/O Control register 1
SMODE       equ P17                 ;1st write - Serial port Mode
SSTAT       equ P17                 ;read - Serial port Status
SCTL0       equ P17                 ;write - Serial port Control 0
T2DATA      equ P18                 ;Timer 2 Data
T2CTL       equ P19                 ;Timer 2 Control
T3DATA      equ P20                 ;Timer 3 Data
SCTL1       equ P21                 ;Serial Control register 1
RXBUF       equ P22                 ;serial Receive Buffer
TXBUF       equ P23                 ;serial Transmit Buffer

BIT0        equ 00000001B           ;bit constants to make code more readable
BIT1        equ 00000010B
BIT2        equ 00000100B
BIT3        equ 00001000B
BIT4        equ 00010000B
BIT5        equ 00100000B
BIT6        equ 01000000B
BIT7        equ 10000000B 

            org 5000H                       ;expansion EPROM starts here
           
            db 080H,048H,028H,058H,085H     ;exception EPROM identification sequence
            
            jmp newparams                   ;initialize new parameters in EPROM
            jmp exceptword                  ;EPROM exception word routine
            
            include parameters.inc          ;user defined parameters and parameter initialization routine
            
            br @EPROM                       ;address of replacement Main Control Program in EPROM 

            include exceptions.inc          ;exception words and exception word routine

;-----------this initiation code is run once upon reset-----------

EPROM:      btjzp %BIT0,BPORT,monitor  ;execute monitor if jumper grounding PB0 is closed on start-up
            br @loopexit            ; else, directly go to text-to-speech function     
            
monitor:    push ST             
            pop statusreg           ;save the status register for display later
            andp %0FEH,IOCNT1       ;disable interrupt 4 (serial interrupt)
            clr spoken              ;clear flag indicating test phrase has been spoken
            mov %hi(bannertxt),texthi
            mov %lo(bannertxt),textlo
            call putstr
            jmp loop1
            
loop:       call return             ;start on a new line
loop1:      mov %hi(menutxt),texthi ;texthi and textlo point to the menu text
            mov %lo(menutxt),textlo
            call putstr             ;display the menu
loop4:      call return
            mov %'>',A
            call putchar            ;monitor prompt
            call putchar
            call getchar            ;wait for a character from RXBUF
            call toupper            ;convert to upper case
            call return             ;start on a new line
            
            cmp %'D',A              ;is it 'D'?
            jne loop5
            call display            ;memory display
            jmp loop4               ;go back for another character
            
loop5:      cmp %'F',A              ;is it 'F'?
            jne loop6
            call fill               ;memory fill function
            jmp loop4               ;go back for another character
            
loop6:      cmp %'R',A              ;is it 'R'?
            jne loop7
            call registers          ;registers display function
            jmp loop4               ;go back for another character
            
loop7:      cmp %'P',A              ;is it 'P'?
            jne loop8
            call peripheral         ;new line
            jmp loop4               ;go back for another character
            
loop8:      cmp %'S',A              ;is it 'S'?
            jne loop9
            call status             ;status register display function
            pop ST                  ;restore the status register
            jmp loop4               ;go back for another character
            
loop9:      cmp %'E',A              ;is it 'E'?
            jne loop10
            call examine            ;examine/modify memory function
            jmp  loop4              ;go back for another character
            
loop10:     cmp %'C',A
            jne loop11
            call callsub            ;call subroutine function
            jmp loop4
            
loop11:     cmp %'H',A
            jne loop12
            call download           ;hex download function
            jmp loop4     

loop12:     cmp %'J',A
            jne loop13  
            br jump                 ;jump to address function

loop13:     cmp %':',A
            jne loop14
            mov %0,errorcount       ;clear checksum error count
            call dnload3            ;hex download function
            br loop4                 
            
loop14:     cmp %1BH,A              ;is it escape?
            jeq loopexit            ;exit the loop by jumping to the text-to-speech routine
            br  loop                ;go back for another character   
            
loopexit:   orp %01,IOCNT1          ;enable interrupt 4 (serial interrupt)
            call @AUDIBLE            
            jmp ANYSTART  
;-----------end of initialization code-----------            

SPEAK:      btjo %01H,F2,ANYSTART
            and %0EFH,F2
CRWAIT:     btjz %10H,F2,CRWAIT
ANYSTART:   cmp F1LO,R1LO
            jne HOLEWORD
            cmp F1HI,R1HI
            jne HOLEWORD
            br @usercode
            
HOLEWORD:   cmp %00,WORDCNTH
            jne BFULTEST
            cmp %00,WORDCNTL
            jeq HOLEWORD
            
BFULTEST:   btjz %BIT3,F2,PROCESS
LOCKUP:     cmp %01,BUFBVALU
            jne BFULHOLD
            br @ESCAPE
            
BFULHOLD    btjo %BIT3,F2,BFULHOLD
PROCESS:    call @GISPEECH
MAINROUT:   cmp F2LO,R2LO
            jeq ANYSTART
            orp %BIT0,IOCNT0        ;enable INT1 (LRQ from SP0256)
            jmp ANYSTART

;-----------user code here is executed when CTS256 is idle-----------
;flash the green LED connected to B2 (pin 5) every 4096 times through this loop (at about 3Hz)       
usercode:   cmp %0A5H,spoken        ;has the test phrase already been spoken?
            jne testphrase          ;no, go load and speak "ready for input"
            inc loopcountlo         ;increment the low byte of the loop counter
            jnc exit                ;exit if incrementing the low byte of the loop counter has not rolled over to zero
            inc loopcounthi         ;increment the high byte of the loop counter
            jnz exit                ;exit if incrementing the high byte of the loop counter has not rolled over to zero
            
;both the high and low bytes of the loop counter have rolled over to zero 
            mov %0F0H,loopcounthi   ;pre-set the high byte of the loop counter (loop counter starts at 0F000H, counts to 10000)
            xorp %BIT2,BPORT        ;toggle the green LED
exit:       jmp ANYSTART            ;jump to the main control program
            
;------------------------------------------------------------------------            
;load and speak the phrase: 'ready for input'                            
;------------------------------------------------------------------------
testphrase: clr B                   ;zero B to be used as index
testphrase1:lda @testtxt(B)         ;load the character indexed by B
            jz testphrase2          ;jump if zero (zero indicates end of string)
            btjzp %BIT0,SSTAT,$     ;wait here until TXBUF is ready for a character
            movp A,TXBUF            ;load the transmit buffer with the character    
            btjzp %BIT2,SSTAT,$     ;wait here until the transmitter is empty
            call @SAVE              ;save the character in A in the speech input buffer
            inc B                   ;increment the index to point to the next character
            jmp testphrase1         ;go back for the next character

testphrase2:mov %0A5H,spoken        ;'A5H' indicates that the test phrase has been spoken
            br @SPEAK               ;branch to the text-to-speech routine in masked ROM
            
testtxt:    db "Ready for input.",0DH,0  

;------------------------------------------------------------------------        
; prints (to the serial port) the unsigned 8 bit binary number in A as 
; three decimal digits. leading zeros are suppressed.
;------------------------------------------------------------------------        
prndec8:    push A                  ;save the number
            mov %0,suppress         ;suppress zero flag (0 means suppress leading zeros)
            mov %100,B              ;power of 10, starts as 100
prndec8a:   mov %'0'-1,count        ;counter (starts at 1 less than ASCII zero)
prndec8b:   inc count
            sub B,A                 ;subtract power of 10
            jc prndec8b             ;go back for another subtraction if the difference is still positive
            add B,A                 ;else , add back the power of 10
            push A
            mov count,A
            cmp %'0',A
            jne prndec8c
            cmp %0,suppress
            jeq prndec8d
prndec8c:   call putchar            ; print the (hindreds or tens) digit
            mov %0FFH,suppress      ;now that we've printed a digit, set the flag
prndec8d:   pop A
            sub %90,B               ;reduce power of ten from 100 to 10
            jc prndec8a             ;jump if the tens digit is not yet done
            add %30H,A              ;else, convert the ones digit to ASCII
            call putchar            ;print the ones digit
            pop A
            rets                     

;------------------------------------------------------------------------
; prints (to the serial port) carriage return (0DH)
;------------------------------------------------------------------------
return:     push A
            mov %0DH,A
            call putchar            
            pop A
            rets
            
;------------------------------------------------------------------------
; prints (to the serial port) space (20H)
;------------------------------------------------------------------------
space:      push A
            mov %' ',A
            call putchar            
            pop A
            rets
            
;------------------------------------------------------------------------
; prints (to the serial port) the byte in A as an ASCII character if >1FH A <80H, else prints '.'
;------------------------------------------------------------------------
ascii:      push A
            cmp %80H,A
            jhs ascii1              ;jump if A is 80H or higher
            cmp %20H,A
            jhs ascii2              ;jump if the character in A is 20H or higher
ascii1:     mov %'.',A
ascii2:     call putchar
            pop A
            rets            

;------------------------------------------------------------------------
; prints (to the serial port) the contents of A as a 2 digit hex number
;------------------------------------------------------------------------
hexbyte:    push A
            push A
            swap A                  ;swap nibbles to print most significant digit first
            call hex2asc            ;convert the digit to ASCII
            call putchar            
            pop A                   ;restore the original contents of A
            call hex2asc            ;convert the digit to ASCII
            call putchar            
            pop A
            rets
            
;------------------------------------------------------------------------
; prints (to the serial port) the contents of A as eight binary digits
;------------------------------------------------------------------------
binary:     mov %10000000B,B
binary0:    push A
            btjz B,A,binary1
            mov %'1',A
            jmp binary2
binary1:    mov %'0',A
binary2:    call putchar
            pop A
            rrc B
            jnc binary0
            rets
            

;------------------------------------------------------------------------
; converts the lower nibble in A into an ASCII character returned in A
;------------------------------------------------------------------------
hex2asc:    and %0FH,A
            push A
            clrc                ;clear the carry bit
            sbb %9,A            ;subtract 9 from the nibble in A
            jl  hex2asc1        ;jump if A is 0-9
            pop A               ;else, A is A-F
            add %7,A            ;add 7 to convert A-F
            jmp hex2asc2
hex2asc1:   pop A
hex2asc2:   add %30H,A          ;convert to ASCII number
            rets    
            
;------------------------------------------------------------------------
; sets carry flag if there is a character available in RXBUF
;------------------------------------------------------------------------            
charavail:  clrc
            btjzp %BIT1,SSTAT,charavail1
            setc
charavail1: rets

;------------------------------------------------------------------------
; wait for a character from the serial port, return it in A
; flash the green LED anout 3Hz
;------------------------------------------------------------------------            
getchar:    btjzp %BIT1,SSTAT,getchar1;jump if RXBUF is empty
            movp RXBUF,A            ;else, retrieve the character from RXBUF
            rets

getchar1:   inc loopcountlo         ;increment the low byte of the loop counter
            jnz getchar             ;go back if incrementing the low byte of the loop counter has not rolled over to zero
            inc loopcounthi         ;increment the high byte of the loop counter
            jnz getchar             ;go back if incrementing the high byte of the loop counter has not rolled over to zero
            
            ;both the high and low bytes of the loop counter have rolled over to zero 
            mov %0B0H,loopcounthi   ;pre-set the high byte of the loop counter (loop counter starts at 0E000H, counts to 10000)
            xorp %BIT2,BPORT        ;toggle the green LED connected to PB2 (pin 5)
            jmp getchar             ;go back and check if a character is available at the serial port

;------------------------------------------------------------------------
; transmit the character in A through the serial port. 
;------------------------------------------------------------------------            
putchar:    btjzp %BIT0,SSTAT,$     ;wait here until TXBUF is ready for a character
            movp A,TXBUF            ;transmit it
            btjzp %BIT2,SSTAT,$     ;wait here until the transmitter is empty
            rets
            
;------------------------------------------------------------------------
; get one hex digit 0-F from the serial port into A. echo the character.
; returns with carry set for escape, space, enter and backspace
;------------------------------------------------------------------------            
get1hex:    call getchar            ;get a character from the serial port
            cmp %08H,A              ;backspace?
            jeq get1hex2            ;return with carry set if backspace
            cmp %0DH,A              ;enter?
            jeq get1hex2            ;return with carry set if enter
            cmp %1BH,A              ;escape?
            jeq get1hex2            ;return with carry set if escape
            cmp %20H,A              ;space?
            jeq get1hex2            ;return with carry set if space
            call toupper            ;convert a-f to A-F            
            cmp %41H,A
            jl get1hex1             ;jump if 41H is lower than A (A is equal or greater than 41H)
            sub %07,A
get1hex1:   sub %30H,A
            cmp %10H,A
            jhs get1hex
            push A
            call hex2asc
            call putchar
            pop A
            clrc
            rets
            
get1hex2:   setc                    ;return with carry set for escape, enter, space and backspace
            rets                            
            
;------------------------------------------------------------------------
; returns with two hex digits 00-FF from the serial port in A.
; carry set if Escape key
;------------------------------------------------------------------------ 
;-----------first digit
get2hex:    call get1hex            ;get the first hex digit
            jc get2hex6
            mov A,B                 ;save the first hex digit in B
;-----------second digit            
get2hex1:   call get1hex            ;get the second hex digit
            jnc get2hex4            ;jump if not escape, enter, space or backspace
            cmp %08H,A              ;is it backspace?
            jne get2hex2
            call putchar
            jmp get2hex             ;go back for first digit
get2hex2:   cmp %0DH,A              ;is it enter?
            jne get2hex3
            mov B,A                 ;recall the first digit from B
            jmp get2hex5            ;return with carry cleared and first digit in A
            
get2hex3:   cmp %1BH,A              ;is it escape?
            jeq get2hex6            ;exit with carry set
            jmp get2hex1            ;else go back for the second hex digit
            
get2hex4:   swap B                  ;swap the nibbles of the first hex digit
            and %0F0H,B             ;mask out the lower 4 bits
            or B,A                  ;combine the two hex digits
get2hex5:   clrc
            rets                    ;return with carry cleared and two digits in A

get2hex6:   setc                    ;return with carry set if escape
            rets
             
;------------------------------------------------------------------------
; returns with four hex digits 0000-FFFF from the serial port in registers A (MSB) and B (LSB).
; carry set if Escape key.
;------------------------------------------------------------------------
;-----------first digit
get4hex:    call get1hex            ;get the first digit
            jc get4hex18            ;jump if enter, escape, space or backspace
            push A                  ;save the first digit on the stack

;-----------second digit
get4hex2:   call get1hex            ;get the second digit
            jnc get4hex5
            cmp %08H,A              ;is it backspace?
            jne get4hex3
            call putchar            ;print the backspace
            pop A
            jmp get4hex             ;go back for the first digit
get4hex3:   cmp %0DH,A              ;is it enter?
            jne get4hex4
            mov %00,A
            pop B                   ;recall the first digit from the stack
            clrc
            rets
            
get4hex4:   cmp %1BH,A              ;is it escape?
            jeq get4hex17           ;return with carry set if escape
            jmp get4hex2            ;else go back for the second digit
            
get4hex5:   pop B                   ;recall the first digit from the stack
            swap B                  ;swap the nibbles of the first digit
            and %0F0H,B             ;mask out the lower 4 bits
            or B,A                  ;combine the first digit in B with the second digit in A
            push A                  ;save the most significant byte on the stack

;-----------third digit
get4hex6:   call get1hex            ;get the third digit
            jnc get4hex9
            cmp %08H,A              ;backspace?
            jne get4hex7
            call putchar            ;print the backspace
            pop A                   ;recall the first byte from the stack
            swap A                  ;swap the nibbles
            and %0FH,A              ;mask out the second digit
            push A                  ;save the first byte on the stack
            jmp get4hex2            ;go back for the second digit
get4hex7:   cmp %0DH,A              ;enter?
            jne get4hex8
            mov %00,A
            pop B                   ;recall the first byte from the stack
            clrc
            rets                    ;return with the first two digits in B and carry clear
get4hex8:   cmp %1BH,A              ;escape
            jeq get4hex17
            jmp get4hex6            ;go back for the third digit
get4hex9:   push A                  ;save the third digit on the stack

;-----------fourth digit
get4hex10:  call get1hex            ;get the fourth digit
            jnc get4hex16
            cmp %08H,A              ;backspace?
            jne get4hex11
            call putchar            ;print the backspace
            pop A
            jmp get4hex6            ;go back for the third digit
            
get4hex11:  cmp %0DH,A              ;enter?
            jne get4hex15
            pop B                   ;third digit in B
            pop A                   ;most significant byte in A
            mov %4,bytecounter
            
get4hex12:  clrc
            rrc A
            rrc B
            jnc get4hex13
            or %00001000B,B
get4hex13:  djnz bytecounter,get4hex12
            clrc
            rets
            
get4hex15:  cmp %1BH,A              ;escape?
            jne get4hex10           ;go back for the fourth cdigit if not escape
            pop B
            jmp get4hex17           ;exit with carry set
            
get4hex16:  pop B                   ;recall the third digit from the stack
            swap B                  ;swap nibbles
            and %0F0H,B             ;mask out the lower 4 bits
            or B,A                  ;combine the third and fourth digits to form the least significant byte
            mov A,B                 ;move the least significant byte into B
            pop A                   ;recall the most significant byte from the stack
            clrc 
            rets                    ;return with MSB in A, LSB in B and carry cleared
            
get4hex17:  pop B
get4hex18:  setc                    ;return with carry set if escape
            rets
           
;------------------------------------------------------------------------                
; converts the ASCII code in A to uppercase, if it is lowercase
;------------------------------------------------------------------------
toupper:    cmp %'a',A              ;'a' or 61H
            jl toupper1             ;jump if the character in A is less than 61H
            cmp %'{',A              ;'{' or 7BH
            jhs toupper1            ;jump if the character in A is greater than 7AH
            sub %20H,A              ;the ASCII character is 'a'-'z', subtract 20H to conver to upper case
toupper1:	rets                            

;------------------------------------------------------------------------
; transmit a null terminated string pointed to by registers texthi (MSB) and textlo (LSB)
;------------------------------------------------------------------------            
putstr:     lda *textlo             ;retrieve the character at the address
            jeq putstr1             ;zero means end of string
            call putchar            ;else, print it
            inc textlo              ;increment pointer to next character
            jnc putstr              ;carry set if FF rolls over to 00
            inc texthi
            jmp putstr
putstr1:    rets    

;------------------------------------------------------------------------
; ;status register display
;------------------------------------------------------------------------
status:     call return             
            mov %hi(flagstxt),texthi
            mov %lo(flagstxt),textlo
            call putstr            
            mov statusreg,A         ;retrieve the status register saved earlier
            call binary             ;print the status register (now in A) as binary
            call return
            rets
            
;------------------------------------------------------------------------
; fill external RAM with value
;------------------------------------------------------------------------
fill:       call return             ;start on a new line
            mov %hi(addresstxt),texthi
            mov %lo(addresstxt),textlo
            call putstr             ;prompt for the staring address
            call get4hex
            jnc fill3               ;jump if a valid hex address
            rets                    ;else return if enter,escape, space or backspace
            
fill3:      mov A,addresshi         ;MSB of address
            mov B,addresslo         ;LSB of address
            mov %09,A
            call putchar            ;tab
            mov %hi(lengthtxt),texthi
            mov %lo(lengthtxt),textlo
            call putstr             ;prompt for the length
            call get4hex
            jnc fill4               ;jump if a valid 4 digit hex length
            rets                    ;else return if enter,escape, space or backspace
            
fill4:      mov A,lengthhi          ;MSB of length
            mov B,lengthlo          ;LSB of length
            call space
            mov %09,A               ;tab
            call putchar
            mov %hi(valuetxt),texthi
            mov %lo(valuetxt),textlo
            call putstr             ;prompt for the fill byte    
            call get2hex            
            jnc fill5               ;jump if a valid hex byte
            rets                    ;else return if enter,escape, space or backspace

fill5:      push A                  ;save the fill byte in A
            call return             ;start on a new line
            pop A                   ;restore the fill byte
fill6:      sta *addresslo          ;store the fill byte at the address
            dec lengthlo            ;decrement least significant byte of length
            jnz fill7               ;jumo if the least significant byte of length has not rolled over from FFH to zero
            dec lengthhi            ;decrement the most significant byte of length
            cmp %0FFH,lengthhi      ;has the most significant byte of length rolled over from zero?
            jnz fill7               ;no, increment the address
            rets                    ;return when length is zero
            
fill7:      inc addresslo           ;next address
            jnc fill6
            inc addresshi
            jmp fill6

;------------------------------------------------------------------------
; display contents of one page of external RAM pointed to by registers 
; addresshi and addresslo in both hex and ASCII
;------------------------------------------------------------------------
display:    call return             ;start on a new line
            mov %hi(addresstxt),texthi
            mov %lo(addresstxt),textlo
            call putstr             ;prompt for 4 digit address
            call get4hex            ;get 4 digit hex address
            jnc display1            ;jump if a valid 4 digit hex address
            jmp display6            ;else return if enter,escape, space or backspace

display1:   call return             ;start on a new line
            mov A,addresshi         ;MSB of starting address
            mov B,addresslo         ;LSB of starting address
            and %0F0H,addresslo     ;mask least significant bits
display2:   call return             ;start on a new line
            mov %20H,A
            call putchar            ;print a space
            call putchar            ;print another space
            mov %hi(columnstxt),texthi
            mov %lo(columnstxt),textlo
            call putstr             ;print column headingsprompt for 4 digit address
            
display3:   mov addresshi,A
            call hexbyte            ;print the MSB of the address
            mov addresslo,A
            call hexbyte            ;print the LSB of the address
            call space
            push addresslo          ;save the address LSB for the ASCII display later

display4:   lda *addresslo          ;retrieve the byte at the address
            call hexbyte            ;print the hex value of the byte at the address
            call space
            inc addresslo           ;next address
            mov addresslo,A
            and %0FH,A
            jnz display4
            
            call space
            pop addresslo
display5:   lda *addresslo
            call ascii
            inc addresslo
            mov addresslo,A
            and %0FH,A
            jnz display5
            
            call return
            cmp %0,addresslo
            jne display3
            call return
            mov %hi(pressspctxt),texthi
            mov %lo(pressspctxt),textlo
            call putstr
            call getchar
            cmp %20H,A
            jne display6
            call return
            inc addresshi
            jmp display2
            
display6:   call return            
            rets

;------------------------------------------------------------------------
; call a subroutine, return to monitor
;------------------------------------------------------------------------
callsub:    call return             ;start on a new line
            mov %hi(addresstxt),texthi
            mov %lo(addresstxt),textlo
            call putstr             ;prompt for 4 digit address
            call get4hex            ;get 4 digit hex address
            jc callsub1             ;jump if not a valid 4 digit hex address
            mov A,addresshi
            mov B,addresslo
            call return
            call *addresslo
            call return
callsub1:   rets

;------------------------------------------------------------------------
; jump to a memory address
;------------------------------------------------------------------------
jump:       call return             ;start on a new line
            mov %hi(addresstxt),texthi
            mov %lo(addresstxt),textlo
            call putstr             ;prompt for 4 digit address
            call get4hex            ;get 4 digit hex address
            jnc jump1               ;jump if a valid 4 digit hex address
            rets
            
jump1:      mov A,addresshi
            mov B,addresslo
            call return
            br *addresslo           ;jump to address in addresslo, addresshi
            
;------------------------------------------------------------------------
; display contents of the register file (00H-7FH) in both hex and ASCII
;------------------------------------------------------------------------
registers:  call return             ;start on a new line
            mov %00,addresshi       ;MSB of register file starting address
            mov %00,addresslo       ;LSB of register file starting address
            call return             ;start on a new line
            call space
            call space
            mov %hi(columnstxt),texthi
            mov %lo(columnstxt),textlo
            call putstr             ;print the column headings
            
registers1: mov addresshi,A
            call hexbyte            ;print the MSB of the register file address
            mov addresslo,A
            call hexbyte            ;print the LSB of the register file address
            call space
            push addresslo          ;save the address LSB for the ASCII display later

registers2: lda *addresslo          ;retrieve the byte at the address
            call hexbyte            ;print the hex value of the byte at the address
            call space
            inc addresslo           ;next address
            mov addresslo,A
            and %0FH,A
            jnz registers2
            
            call space
            pop addresslo
registers3: lda *addresslo
            call ascii
            inc addresslo
            mov addresslo,A
            and %0FH,A
            jnz registers3
            
            call return
            cmp %80H,addresslo
            jne registers1
            rets            
            
;------------------------------------------------------------------------
; display contents of the Peripheral file (0100H-0117H) in hex
;------------------------------------------------------------------------
peripheral: call return             ;start on a new line
            mov %hi(portstxt),texthi
            mov %lo(portstxt),textlo
            call putstr             ;print the column headings
            mov %01,addresshi       ;MSB of starting peripheral file address
            mov %00,addresslo       ;LSB of starting peripheral file address
            call oneline
            call return
            mov %10H,addresslo      ;LSB of next line of peripheral file addresses
            call oneline
            call return
            rets
            
oneline:    mov addresshi,A
            call hexbyte            ;print the MSB of the peripheral file address
            mov addresslo,A
            call hexbyte            ;print the LSB of the peripheral file address
            call space
oneline1:   cmp %01,addresslo       ;print spaces for "reserved" peripheral file address 0101
            jeq oneline4
            cmp %07,addresslo       ;print spaces for "reserved" peripheral file address 0107
            jeq oneline4
oneline2:   lda *addresslo          ;retrieve the byte at the peripheral file address
            call hexbyte            ;print the hex value of the byte
oneline3:   call space
            inc addresslo           ;next peripheral file address
            mov addresslo,A
            and %07H,A
            jnz oneline1
            rets
            
oneline4:   call space              ;print spaces for the "reserved" peripheral file addresses
            call space
            jmp oneline3
            
;------------------------------------------------------------------------
; examine/modify RAM contents
;------------------------------------------------------------------------            
examine:    call return
            mov %hi(addresstxt),texthi
            mov %lo(addresstxt),textlo
            call putstr             ;prompt for 4 digit RAM address
            call get4hex            ;get four digit hex address
            jnc examine1
examine0:   call return
            rets
            
examine1:   mov A,addresshi
            mov B,addresslo
examine2:   call return
            mov addresshi,A         ;print MSB of address
            call hexbyte
            mov addresslo,A         ;print LSB of address
            call hexbyte
            mov %hi(arrowtxt),texthi
            mov %lo(arrowtxt),textlo
            call putstr
            lda *addresslo
            call hexbyte
            mov %hi(newvaluetxt),texthi
            mov %lo(newvaluetxt),textlo
            call putstr
            call get2hex            ;get 2 hex digits
            jnc examine3
            cmp %20H,A
            jne examine0
            lda *addresslo
            call hexbyte            
examine3:   sta *addresslo          ;store the new value at the address
examine4:   inc addresslo
            jnc examine2
            inc addresshi
            jmp examine2

;------------------------------------------------------------------------
; Download Intel HEX file:
; A record (line of text) consists of six fields that appear in order from left to right:
;   1. Start code, one character, an ASCII colon ':'.
;   2. Byte count, two hex digits, indicating the number of bytes in the data field.
;   3. Address, four hex digits, representing the 16-bit beginning memory address offset of the data.
;   4. Record type, two hex digits (00=data, 01=end of file), defining the meaning of the data field.
;   5. Data, a sequence of n bytes of data, represented by 2n hex digits.
;   6. Checksum, two hex digits, a computed value (starting with the byte count) used to verify record data.
;------------------------------------------------------------------------   
; R115 holds the number of data bytes per line, R116 holds the computed checksum for the line,
; R114 holds the checksum error count.
; Note: when using Teraterm to "send" a hex file, make sure that Teraterm
; is configured for a transmit delay of 1 msec/char and 10 msec/line.
;------------------------------------------------------------------------
download:   call return
            mov %hi(dnloadtxt),texthi
            mov %lo(dnloadtxt),textlo
            call putstr
            mov %0,errorcount       ;initialize the checksum error count to zero
dnload1:    call getchar            ;get a character from the serial port
            cmp %':',A              ;start of record??
            jeq dnload3             ;continue
            cmp %1BH,A              ;escape?
            jne dnload1
            rets                    ;escape exits back to the main loop     

;start of record found...
dnload3:    call putchar            ;echo the start of record ':'
            call get2hex            ;get the record length
            mov A,recordlen         ;initialize the record length
            mov A,checksum          ;initialize the checksum
            cmp %0,A                ;is the record length zero? (last record)
            jeq dnload7             ;yes, go download the remainder of the last record
            
            call get2hex            ;get the address hi byte
            mov A,addresshi
            add checksum,A          ;add the computed checksum to the address hi byte
            mov A,checksum          ;save the sum in A as the new checksum
            
            call get2hex            ;get the address lo byte
            mov A,addresslo
            add checksum,A          ;add the computed checksum to the address low byte
            mov A,checksum          ;save the sum in A as the new checksum
            
            call get2hex            ;get the record type
            add checksum,A          ;add the computed checksum to the record type byte
            mov A,checksum          ;save the sum in A as the new checksum

;download and store data bytes...            
dnload4:    call get2hex            ;get a data byte
            sta *addresslo          ;store the data byte at the address
            inc addresslo           ;next address
            jnc dnload5
            inc addresshi
dnload5:    add checksum,A          ;add the computed checksum to the data byte
            mov A,checksum          ;save the sum in A as the new checksum
            dec recordlen           ;decrement the record length count
            jnz dnload4             ;if not zero, go back for another record data byte
            
            call get2hex            ;get the record's checksum
            add checksum,A          ;add the computed checksum to the record's checksum in A
            jz dnload6              ;zero means the checksum is correct
            inc errorcount          ;else increment checksum error count            
dnload6:    call getchar            ;get the carriage return at the end of the line
            call putchar            ;echo the carriage return at the end of the line
            jmp dnload1             ;go back for the next record
            
;last record            
dnload7:    call get2hex            ;get the last address hi byte
            call get2hex            ;get the last address lo byte
            call get2hex            ;get the last record type
            call get2hex            ;get the last checksum
            call getchar            ;get the last carriage return
            call putchar            ;echo the carriage return
            mov errorcount,A        ;get the error count into A
            jnz dnload8             ;jump if there are checksum errors
            mov %hi(noerrstxt),texthi
            mov %lo(noerrstxt),textlo
            call putstr
            jmp dnload9
            
dnload8:    call prndec8            ;print the error count
dnload9:    mov %hi(errorstxt),texthi
            mov %lo(errorstxt),textlo
            call putstr
            rets

flagstxt:   db "CNZI----",0DH,0  
bannertxt:  db 0DH,0AH,0AH
            db "CTS256A-AL2 Monitor Version 1.7",0DH
            db "Assembled ",DATE," at ",TIME,0DH,0                
menutxt:    db 0DH
            db "C - Call subroutine",0DH
            db "D - Display memory",0DH
            db "E - Examine/modify RAM",0DH            
            db "F - Fill external RAM",0DH
            db "H - download Intel Hex file",0DH
            db "J - Jump to address",0DH
            db "P - display Peripheral file",0DH            
            db "R - display Register file",0DH
            db "S - display Status register",0DH,0AH,0AH
            db "ESCAPE exits monitor to Text-to-Speech function.",0DH,0AH,0            
pressspctxt:db "Press Space key for next page...",0                
arrowtxt:   db " --> ",0
newvaluetxt:db " New value: ",0
addresstxt: db "Address: ",0     
lengthtxt:  db "Length: ",0
valuetxt:   db "Value: ",0    
columnstxt: db "   00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0D 0F",0DH,0  
portstxt:   db "     00 01 02 03 04 05 06 07",0DH,0  
dnloadtxt:  db "Waiting for HEX download...",0DH,0
noerrstxt:  db "No",0
errorstxt:  db " checksum errors.",0DH,0
copyright:  db "Copyright 2021 by Jim Loos",0DH,0 
            
            

