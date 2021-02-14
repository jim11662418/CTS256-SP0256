;user defined parameters table (0FFH means no change)
parameters: db 0FFH         ;number of bytes of 50% external buffer (MSB)
            db 0FFH         ;number of bytes of 50% external buffer (LSB)
            db 0FFH         ;number of bytes of 12.5% external buffer (MSB)
            db 0FFH         ;number of bytes of 12.5% external buffer (LSB)
            db 0FFH         ;external RAM start address (MSB)
            db 0FFH         ;external RAM start address (LSB)
            db 0FFH         ;external RAM end address-100H (MSB)
            db 0FFH         ;external RAM end address-100H (LSB)
            db 0FFH         ;external RAM start address-1 (MSB)
            db 0FFH         ;external RAM start address-1 (LSB)
            db 0FFH         ;external RAM end address-FFH (MSB)
            db 0FFH         ;external RAM end address-FFH (LSB)
            db 0FFH         ;external RAM end address+1 (MSB)
            db 0FFH         ;external RAM end address+1 (LSB)
            db 0FFH         ;address of SP0256A ALD (MSB)
            db 0FFH         ;address of SP0256A ALD (LSB)
            db 0FFH         ;address of 74LS374 parallel port latch (MSB)
            db 0FFH         ;address of 74LS374 parallel port latch (LSB)
            db 0FFH         ;not user definable
            db 0FFH         ;total number of bytes in input buffer (MSB)
            db 0FFH         ;total number of bytes in input buffer (LSB)
            db 0FFH         ;not user definable
            db 0FFH         ;not user definable
            db 0FFH         ;serial port mode register value
            db 0FFH         ;serial port control register value
            db 0FFH         ;serial port timer data register value

;register addresses for user defined parameters above
addresses:  db 01EH         ;address of number of bytes of 50% external buffer (MSB) parameter - index 00
            db 01FH         ;address of number of bytes of 50% external buffer (LSB) parameter - index 01
            db 020H         ;address of number of bytes of 12.5% external buffer (MSB) parameter - index 02
            db 021H         ;address of number of bytes of 12.5% external buffer (LSB parameter - index 03
            db 028H         ;address of external RAM start address (MSB) parameter - index 04
            db 029H         ;address of external RAM start address (LSB) parameter - index 05
            db 024H         ;address of external RAM end address-100H (MSB) parameter - index 06
            db 025H         ;address of external RAM end address-100H (LSB) parameter - index 07
            db 022H         ;address of external RAM start address-1 (MSB) parameter - index 08
            db 023H         ;address of external RAM start address-1 (LSB) parameter - index 09
            db 02AH         ;address of external RAM end address-FFH (MSB) parameter - index 0A
            db 02BH         ;address of external RAM end address-FFH (LSB)  parameter - index 0B
            db 026H         ;address of external RAM end address+1 (MSB) parameter - index 0C
            db 027H         ;address of external RAM end address+1 (LSB) parameter - index 0D
            db 02CH         ;address of address decode of SP0256A ALD (MSB) parameter - index 0E
            db 02DH         ;address of address decode of SP0256A ALD (LSB) parameter - index 0F
            db 02EH         ;address of address decode of 74LS374 parallel port latch (MSB) parameter - index 10
            db 02FH         ;address of address decode of 74LS374 parallel port latch (LSB) parameter - index 11
            db 032H         ;not user definable - index 12
            db 033H         ;address of total number of bytes in input buffer (MSB) parameter - index 13
            db 034H         ;address of total number of bytes in input buffer (LSB) parameter - index 14
            db 035H         ;not user definable - index 15
            db 036H         ;not user definable -index 16

exceptword: jmp exception

; user defined parameters initialization routine            
newparams:  add %02,R49
            call @0F143H
            
            clr B                   ;B serves as the index into the tables
            lda @parameters(B)      ;load the MSB of the parameter from the table
            cmp %0FFH,A             ;is the value from the table FFH?
            jeq init4               ;skip initialization if parameter is FFH
            push A                  ;else, save the MSB value from the parameters pable
            lda @addresses(B)       ;load corresponding value from addresses table
            clr R18                 ;R18 id the MSB of the address 
            mov A,R19               ;move the address into R19
            pop A                   ;restore the parameter value
            sta *R19                ;store the parameter at the address in R18,R19 (register file indirect addressing)
init3:      inc B                   ;increment index to point to next parameter
            lda @parameters(B)      ;load LSB of the parameter from the table
            cmp %0FFH,A             ;is the value from the table FFH?
            jeq init4               ;skip initialization if parameter is FFH
            push A                  ;else, save the LSB value from the parameters pable
            lda @addresses(B)       ;load corresponding value from addresses table
            clr R18                 ;R18 is the MSB of the address
            mov A,R19               ;move the LSB of the address from the addresses table
            pop A                   ;restore A
            sta *R19                ;store the parameter
init4:      cmp %16H,B              ;is the index pointing to the last parameter?
            jne init3               ;go back for the next parameter if not at the end
            inc B                   ;else, increment the index
            lda @parameters(B)      ;load the serial port mode register parameter
            cmp %0FFH,A             ;is the value from the table FFH?
            jeq init5               ;skip serial port initialization if parameter is FFH

;serial port initialization            
            movp %40H,SCTL0         ;reset the serial port
            movp A,SMODE            ;configure serial port mode
            movp %15H,SCTL0         ;reset error flags, enable receive, enable transmit
            inc B
            lda @parameters(B)      ;serial port control register parameter
            movp A,SCTL1            ;configure serial port control
            inc B
            lda @parameters(B)      ;serial port timer data register parameter
            movp A,T3DATA           ;configure serial port timer data
            
init5:      movd R41,F1LO
            movd R43,F2LO
            mov %20H,A
            sta *F1LO
            call 0F72BH
            sta *F1LO
            eint                    ;enable interrupts
            movd F2LO,R2LO
            movd F1LO,R25
