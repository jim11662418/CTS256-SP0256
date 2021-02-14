exception:  jmp except   ;jump to exception word routine
            
            ; alphabetized exception word index
index:      dw A_words  ;MSB,LSB of pointer to exception words beginning with "A"
            dw B_words  ;MSB,LSB of pointer to exception words beginning with "B"
            dw C_words  ;MSB,LSB of pointer to exception words beginning with "C"
            dw D_words  ;MSB,LSB of pointer to exception words beginning with "D"
            dw E_words  ;MSB,LSB of pointer to exception words beginning with "E"
            dw F_words  ;MSB,LSB of pointer to exception words beginning with "F"
            dw G_words  ;MSB,LSB of pointer to exception words beginning with "G"
            dw H_words  ;MSB,LSB of pointer to exception words beginning with "H"
            dw I_words  ;MSB,LSB of pointer to exception words beginning with "I"
            dw J_words  ;MSB,LSB of pointer to exception words beginning with "J"
            dw K_words  ;MSB,LSB of pointer to exception words beginning with "K"
            dw L_words  ;MSB,LSB of pointer to exception words beginning with "L"
            dw M_words  ;MSB,LSB of pointer to exception words beginning with "M"
            dw N_words  ;MSB,LSB of pointer to exception words beginning with "N"
            dw O_words  ;MSB,LSB of pointer to exception words beginning with "O"
            dw P_words  ;MSB,LSB of pointer to exception words beginning with "P"
            dw Q_words  ;MSB,LSB of pointer to exception words beginning with "Q"
            dw R_words  ;MSB,LSB of pointer to exception words beginning with "R"
            dw S_words  ;MSB,LSB of pointer to exception words beginning with "S"
            dw T_words  ;MSB,LSB of pointer to exception words beginning with "T"
            dw U_words  ;MSB,LSB of pointer to exception words beginning with "U"
            dw V_words  ;MSB,LSB of pointer to exception words beginning with "V"
            dw W_words  ;MSB,LSB of pointer to exception words beginning with "W"
            dw X_words  ;MSB,LSB of pointer to exception words beginning with "X"
            dw Y_words  ;MSB,LSB of pointer to exception words beginning with "Y"
            dw Z_words  ;MSB,LSB of pointer to exception words beginning with "Z"
            dw Numbers  ;MSB,LSB of pointer to number or punctuation exception words
            
            ; exception word routine
except:     push F1HI
            push F1LO                                                              
            movd F1LO,R17
            call @0F74BH
            call @0F70FH
            btjz %01,R10,except1
            or %080H,F2
            jmp except2
except1:    and %7FH,F2
except2:    call 0F3AFH
            btjo %20H,R10,except3
            mov %52,B
            lda @index(B)
            mov A,R20
            lda @index+1(B)
            mov A,R21
            jmp except4
except3:    clr B
            sub %41H,A
            mpy %02,A
            lda @index(B)
            mov A,R20
            lda @index+1(B)
            mov A,R21
except4:    mov %01,B
            call 0F488H
except4a:   call 0F4C2H
            btjo %10H,R10,except6
            cmp %0FFH,A
            jz except8
            movd R17,R29
            and %0BFH,R10
            call 0F564H
            btjo %10H,R10,except6
            call 0F47EH
            or %40H,R10
            call 0F564H
            btjo %10H,R10,except7
            add R55,R52
            adc %00,R51
            clr R55
            and %0FDH,F2
            mov %02,B
            call 0F488H
            call 0F49EH
            movd R15,F1LO
            movd F1LO,R17
            call 0F74BH
            btjz %80H,F2,except5
            decd WORDCNTL
            call 0F347H
            pop B                  
            pop B
            br @0F136H
except5:    pop B 
            pop B
            br @0F3F4H
except6:    inc R21
            jnc except6a
            inc R20
except6a:   mov %02,B
except6b:   call 0F488H
            mov %01,R55
            and %0FDH,F2
            jmp except4a
except7:    mov %03,B
            jmp except6b
except8:    pop F1LO
            pop F1HI
            clr R55
            and %0FDH,F2
            br @0F3EEH
            
            db  0FFH
            
            ; encoded exception words
A_words:    db  13H,'L'+20H,'E'-20H,'X'+60H,013H    ;ALEX
            db  AW+40H,PA3,LL,EH,KK1,SS,SS+80H
            db  0FFH    ;end of A words
B_words:    db  0FFH    ;end of B words
C_words:    db  013H,'A'+20H,'P'+60H,'A'-20H    ;CAPA note: no ending '13H' since it's the first part of a word. i.e. 'capability' or 'capable'
            db  KK1+40H,EY,PP+80H
            db  0FFH    ;end of C words
D_words:    db  0FFH    ;end of D words
E_words:    db  013H,'L'+20H,'E'-20H,'A'-20H,'N'-20H,'E'-20H,'R'+60H,013H   ;ELEANER
            db  EH+40H,LL,PA4,EH,PA2,NN1,ER2+80H
            db  0FFH    ;end of E words
F_words:    db  0FFH    ;end of F words
G_words:    db  013H,'I'+20H+80H,013H   ;GI
            db  JH+40H,EH,NN1,ER1,EL,PA1,IH,NN1,SS,TT2,RR2,UW2,MM,EH,NN1,PA3,TT2+80H
            db  0FFH    ;end of G words
H_words:    db  0FFH    ;end of H words
I_words:    db  013H,'D'+20H+80H,013H   ;ID
            db  AY+40H,DD2,EH,NN1,PA3,TT2,IH,FF,IH,PA3,KK1,EY,SH,AX,NN1+80H ;identification
            db  013H,'S'+20H,'L'-20H,'E'+60H,013H   ;ISLE
            db  AY+40H,PA2,EL+80H
            db  013H,'S'+20H,'L'-20H,'A'-20H,'N'-20H,'D'+60H,013H   ;ISLAND   
            db  AY+40H,PA2,EL,AE,NN1,DD1+80H       
            db  0FFH    ;end of I words
J_words:    db  0FFH    ;end of J words
K_words:    db  0FFH    ;end of K words
L_words:    db  013H,'I'+20H,'V'-20H,'E'-20H,'D'+60H,013H   ;LIVED
            db  LL+40H,IH,VV,PA4,DD1+80H
            db  013H,'O'+20H,'O'-20H,'S'+60H,013H           ;LOOS
            db  LL+40H,UH,PA3,SS+80H            
            db  0FFH    ;end of L words
M_words:    db  0FFH    ;end of M words
N_words:    db  0FFH    ;end of N words
O_words:    db  0FFH    ;end of O words
P_words:    db  013H,'U'+20H,'R'-20H,'P'-20H,'O'-20H,'S'-20H,'E'+60H,013H ;PURPOSE
            db  PP+40H,ER1,PP,AX,SS,SS+80H
            db  0FFH    ;end of P words
Q_words:    db  0FFH    ;end of Q words
R_words:    db  0FFH    ;end of R words
S_words     db  0FFH    ;end of S words
T_words:    db  013H,'O'+20H,'T'-20H,'A'-20H,'L'+60H,013H   ;TOTAL
            db  TT2+40H,OW,TT1,PA1,AX,EL+80H
            db  0FFH    ;end of T words
U_words:    db  013H,'S'+20H,'E'-20H,'R'-20H,'I'-20H,'D'+60H,013H   ;USERID 
            db  YY1+40H,UW1,ZZ,ER1,PA1,AY,PA1,DD2,EH,NN1,PA3,TT2,IH,FF,IH,PA3,KK1,EY,SH,AX,NN1+80H  ;user identification
            db  0FFH    ;end of U words
V_words:    db  0FFH    ;end of V words
W_words:    db  013H,'E'+20H,APOSTROPHE-20H,'R'-20H,'E'+60H,013H  ;WE'RE
            db  WW+40H,IY,ER2+80H      
            db  0FFH    ;end of W words
X_words:    db  0FFH    ;end of X words
Y_words:    db  013H,'O'+20H,'U'-20H,APOSTROPHE-20H,'R'-20H,'E'+60H,013H  ;YOU'RE
            db  YY2=40H,OR+80H
            db  0FFH    ;end of Y words
Z_words:    db  0FFH    ;end of Z words
Numbers:    db  013H,0CFH,013H  ;<[/]<
            db  059H,03AH,001H,010H,007H,037H,037H,00CH,001H,00AH,000H,002H,02AH,01AH,00BH,001H,03FH,013H,000H,037H,037H,002H,009H,035H,002H,02AH,007H,00BH,000H
            db  02EH,00CH,01DH,000H,012H,00FH,000H,002H,00DH,00FH,002H,032H,000H,00FH,023H,000H,014H,000H,002H,02AH,013H,080H,0C6H,05AH,00BH,015H,080H
            db  0FFH    ;end of numbers and punctuation
