            PAGE 0          ; suppress page headings in ASW listing file
            
;--------------------------------------------------------------------------------------------
; enter a set allophones to be spoken by the SP0256 as a word. this program expects input in 
; the form of 3 character allophones ('PA1', 'NN2', 'KK2', etc). for 2 character allophones 
; ('AY', 'OW', 'MM', etc.)  enter a 'Space' as the third character. once all allophones have
; been entered, press 'Enter'.
;
; use the AS Macroassembler to assemble the program and produce a hex format object file. load the 
; program by using the monitor's Intel hex download function. run the program by using the monitor's
; Call subroutine function. the starting adddress is 4200H. control X exits the program and returns
; the monitor. 
;--------------------------------------------------------------------------------------------            

            cpu tms70C00    ; TMS7000 family

            include functions.inc
            
; registers...
texthi      equ R123                         ; used by the text print function
textlo      equ R124                         ; used by the text print function
index       equ R100                         ; index to the allophones table
counter     equ R101                         ; counter used by the divide function
divisorMSB  equ R102                         ; MSB of the divisor
divisorLSB  equ R103                         ; LSB of the divisor
bufflen     equ R104                         ; number of characters entered into the buffer

; I/O ports...
IOCNT0      equ P0                           ; I/O Control register 0

; functions in exception EPROM...
prndec8     equ 5717H                        ; prints the unsigned 8 bit binary number in A as three decimal digits.
return      equ 5743H                        ; prints (to the serial port) CR (0DH)
space       equ 574BH                        ; prints (to the serial port) space (20H)
hexbyte     equ 5763H                        ; prints the contents of A as a 2 digit hex number
binary      equ 5775H                        ; prints the contents of A as eight binary digits
charavail   equ 5799H                        ; sets carry flag if there is a character available in RXBUF
getchar     equ 57A0H                        ; wait for a character from the serial port, return it in A
putchar     equ 57B7H                        ; transmit the character in A through the serial port.
get2hex     equ 57F0H                        ; returns with two hex digits 00-FF from the serial port in A.
get4hex     equ 5819H                        ; returns with four hex digits 0000-FFFF from the serial port in registers A (MSB) and B (LSB).
toupper     equ 589BH                        ; converts the ASCII code in A to uppercase
putstr      equ 58A6H                        ; transmit a null terminated string pointed to by registers texthi (MSB) and textlo (LSB)

            org 4200H                        ; RAM

            push ST                          ; save registers
            push A
            push B
            
            mov %hi(text),texthi
            mov %lo(text),textlo
            call @putstr                     ; print instructions
            
loop1:      mov %'>',A
            call @putchar                    ; prompt for input
loop2:      clr B                            ; first character
loop3:      call @getchar

            cmp %18H,A                       ; is this character control X?
            jne loop4
            br @exit                         ; return to monitor
            
loop4:      cmp %1BH,A                       ; is this character 'escape'?
            jne loop5
            call @return
            jmp loop1                        ; abandon the input and restart
            
loop5:      cmp %0DH,A                       ; is this character 'enter'?
            jne loop6
            br @speak                        ; speak the allophones if 'enter'

loop6:      cmp %20H,A                       ; is this character 'space'?
            jne loop7
            cmp %2,B                         ; is this the third character?
            jeq loop10                       ; jump the third character is 'space'
            jmp loop3                        ; else, go back for another character. 'space' is not allowed for 1st or 2nd characters
            
; this character is neither 'escape', 'enter' nor 'space'            
loop7:      call @toupper                    ; convert the character to uppercase
            cmp %'[',A
            jhs loop3                        ; go back if this character is above 'Z'
            cmp %2,B
            jeq loop8                        ; jump if this is the third character
; this is the first or second character...            
            cmp %'A',A
            jl loop3                         ; jump if this character is below 'A'            
            jmp loop9                        ; go print it and store it in the buffer

; this is the third character...            
loop8:      cmp %'1',A
            jl loop3                         ; jump if the third character below is '0' or below
            cmp %'6',A
            jhs loop3                        ; jump if the third character is '6' or above
            call @putchar                    ; else, the third character is 1-5. print it
            sta @buffer(B)                   ; and save it in the buffer
            inc B                            ; increment the pointer
            jmp loop10                       ; go print a space after the third character
            
loop9:      call @putchar                    ; print the character
            sta @buffer(B)                   ; save it in the buffer
            inc B                            ; increment the pointer
            jmp loop3                        ; go back for the next character
            
; the third character has been entered, or the second character followed by 'space'            
loop10:     call @space                      ; print ' '
            mov B,bufflen                    ; save the number of characters entered by the user  
            
; search for the allophone string entered by the user ('buffer') in a table of allophones ('allophones')
; if found, 'index' points to the first character of the allophone found in the table.
; if not found, 'index' is zero and the allophone address for PA1 (00H) will be used.
; adapted from code on page 9-52 of the 'TMS7000 Family Data Manual'.
search:     mov %tablelength+1,index         ; length of the table of allophones in bytes
search1:    mov bufflen,B                    ; reset string pointer
search2:    xchb index                       ; B now contains the pointer to the allophone table, 'index' contains the pointer to the buffer                    
            dec B                            ; next character
            jz notfound                      ; jump if reached the end (actually the beginning) of the table
            lda @allophones-1(B)             ; get the character from the allophone table  
            xchb index                       ; B now contains the pointer to the buffer, 'index' contains the pointer to the allophone table
            cmpa @buffer-1(B)                ; compare the character from the allophone table in B to the character in the buffer
            jne search1                      ; if the characters don't match, go back to reset pointer
            djnz B,search2                   ; characters match, decrement pointer to try next character
            
; the allophone string was found in the table. subtract one and divide by 3 to convert the index to an allophone address            
match:      clr divisorMSB                   ; zero the MSB of the dividend
            dec index                        ; subtract 1 from the index
            mov index,divisorLSB             ; string the index as the LSB of the dividend
            mov %3,B                         ; 3 as divisor (divide by 3)
            call @divide                     ; divide string index by 3 to get the allophone address
            mov divisorLSB,A                 ; divisorLSB now contains the allophone address
            
store:      decd R54                         ; decrement buffer space available count    
            sta *R9                          ; save the allophone address in the output buffer
            add %01H,R9                      ; increment the LSB of the output write pointer
            adc %00H,R8                      ; increment the MSB of the output write pointer
            br @loop2                        ; go back for the next string input

; the allophone string was not found in the table. use allophone address '00' (PA1)      
notfound:   clr A                            ; if a match is not found, store PA1 in the buffer
            jmp store
            
; 'enter' has been pressed. store the allophone address for 'PA1' in the output buffer to end the word.
; enable Interrupt 1 to allow the SP0256 to speak the allophones in the output buffer.
speak:      clr A                            ; store PA1 in the buffer at the end of the word
            decd R54                         ; decrement buffer space available count    
            sta *R9                          ; save the allophone address in the output buffer
            add %01H,R9                      ; increment the LSB of the output write pointer
            adc %00H,R8                      ; increment the MSB of the output write pointer
            orp %01H,IOCNT0		            ; enable INT1 to allow the SP0256 to pronounce the allophones
            call @return                     ; new line
            br @loop1                        ; go back for a new string of allophones

; return to the monitor            
exit:       pop B                            ; restore registers
            pop A
            pop ST
            rets

; divide a 16 bit dividend in divisorMSB, divisorLSB by an 8 bit divisor in B. returns a 16 bit
; quotient in divisorMSB, divisorLSB and an 8 bit remainder in A. All numbers are unsigned positive numbers.
; adapted from code on page 9-56 of the 'TMS7000 Family Data Manual'.   
divide:     mov %16,counter                  ; set loop counter to 16 (8+8)
            clr A                            ; initialize result register
divide1:    rlc divisorLSB                   ; multiply dividend by 2
            rlc divisorMSB
            rlc A
            jnc divide2
            sub B,A
            setc
            jmp divide3
            
divide2:    cmp B,A                          ; is msb of dividend > divisor
            jnc divide3
            sub B,A                          ; if so dividend=dividend-divisor. c=l gets folded into next rotate
divide3:    djnz counter,divide1             ; next bit, is the divide done?
            rlc divisorLSB                   ; finish the last rotate
            rlc divisorMSB             
            rets
            
allophones: db "PA1"                         ; 00H     pause       10ms
            db "PA2"                         ; 01H     pause       30ms
            db "PA3"                         ; 02H     pause       50ms
            db "PA4"                         ; 03H     pause      100ms
            db "PA5"                         ; 04H     pause      200ms
            db "OY",0                        ; 05H     bOY        290ms
            db "AY",0                        ; 06H     skY        170ms
            db "EH",0                        ; 07H     eND         50ms
            db "KK3"                         ; 08H     Comb        80ms
            db "PP",0                        ; 09H     Pow        150ms
            db "JH",0                        ; 0AH     dodGe      400ms
            db "NN1"                         ; 0BH     thiN       170ms
            db "IH",0                        ; 0CH     sIt         60ms
            db "TT2"                         ; 0DH     To         100ms
            db "RR1"                         ; 0EH     Rural      130ms
            db "AX",0                        ; 0FH     sUcceed     50ms  
            db "MM",0                        ; 10H     Milk       180ms
            db "TT1"                         ; 11H     parT        80ms
            db "DH1"                         ; 12H     THey       140ms
            db "IY",0                        ; 13H     sEE        170ms
            db "EY",0                        ; 14H     bEIge      200ms
            db "DD1"                         ; 15H     coulD       50ms
            db "UW1"                         ; 16H     tO          60ms
            db "AO",0                        ; 17H     OUght       70ms
            db "AA",0                        ; 18H     hOt         60ms
            db "YY2"                         ; 19H     Yes        130ms
            db "AE",0                        ; 1AH     hAt         80ms
            db "HH1"                         ; 1BH     He          90ms
            db "BB1"                         ; 1CH     Business    40ms
            db "TH",0                        ; 1DH     THin       130ms
            db "UH",0                        ; 1EH     bOOk        70ms
            db "UW2"                         ; 1FH     fOOd       170ms
            db "AW",0                        ; 20H     OUt        250ms
            db "DD2"                         ; 21H     Do          80ms
            db "GG3"                         ; 22H     wiG        120ms
            db "VV",0                        ; 23H     Vest       130ms
            db "GG1"                         ; 24H     Guest       80ms
            db "SH",0                        ; 25H     SHip       120ms
            db "ZH",0                        ; 26H     aZUre      130ms
            db "RR2"                         ; 27H     bRain       80ms
            db "FF",0                        ; 28H     Food       110ms
            db "KK2"                         ; 29H     sKy        140ms
            db "KK1"                         ; 2AH     Can"t      120ms
            db "ZZ",0                        ; 2BH     Zoo        150ms
            db "NG",0                        ; 2CH     aNchor     200ms
            db "LL",0                        ; 2DH     Lake        80ms
            db "WW",0                        ; 2EH     Wool       140ms
            db "XR",0                        ; 2FH     repaiR     250ms
            db "WH",0                        ; 30H     WHig       150ms
            db "YY1"                         ; 31H     Yes         90ms
            db "CH",0                        ; 32H     Church     150ms
            db "ER1"                         ; 33H     fIR        110ms
            db "ER2"                         ; 34H     fIR        210ms
            db "OW",0                        ; 35H     bEAU       170ms
            db "DH2"                         ; 36H     THey       180ms
            db "SS",0                        ; 37H     veST        60ms
            db "NN2"                         ; 38H     No         140ms
            db "HH2"                         ; 38H     Hoe        130ms
            db "OR",0                        ; 3AH     stORe      240ms
            db "AR",0                        ; 3BH     alARum     200ms
            db "YR",0                        ; 3CH     cleAR      250ms
            db "GG2"                         ; 3DH     Got         80ms
            db "EL",0                        ; 3EH     saddLE     140ms
            db "BB2"                         ; 3FH     Business    60ms

tablelength equ $-allophones

buffer:     ds 5  
            
text:       db "\rEnter allophones separated by spaces.\r"
            db "Press <ENTER> to speak. <ESC> cancels all input.\r"
            db "Control X to return to monitor.\r\r",0
            
            end