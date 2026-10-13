; ============================================================
; P0NG  --  intro.asm
; Boot animation (F O N Y scrolls up from the bottom to the
; middle of the screen), credits, and the title/welcome screen.
; ============================================================

INTRO_TARGET_ROW EQU 11

TITLE_TEXT:        DB "P",T_RING,"NG",0
PRESS_SPACE_TEXT:  DB "PRESS SPACE FOR 1 PLAYER",0
PRESS_2_TEXT:      DB "PRESS 2 FOR 2 PLAYERS",0
HELP_TEXT:         DB "1 PLAYER: CURSOR UP/DOWN",0
HELP2_TEXT:        DB "2 PLAYERS: Q/A AND CURSOR UP/DOWN",0
HISCORE_HDR_TEXT:  DB "HIGH SCORES",0

CREDIT_LINE1: DB "The File-Hunter",0
CREDIT_LINE2: DB "&",0
CREDIT_LINE3: DB "Claude",0
CREDIT_LINE4: DB "PRESENT:",0

INTRO_LETTERS: DB "F O N Y",0
INTRO_BLANKS:  DB "       ",0

; ---- INTRO_INIT: call once when entering GS_INTRO --------------------
INTRO_INIT:
        CALL    CLEAR_SCREEN
        LD      A,23
        LD      (INTRO_ROW),A
        XOR     A
        LD      (INTRO_TIMER),A
        LD      (INTRO_PHASE),A
        RET

; ---- INTRO_UPDATE: call once per frame during GS_INTRO ----------------
; Phases: 0=letters scrolling up, 1=held on screen (2s), 2=credits
; screen held (2s), then on to GS_TITLE.
INTRO_UPDATE:
        LD      A,(INTRO_PHASE)
        CP      1
        JR      Z,IU_HOLD_LOGO
        CP      2
        JR      Z,IU_HOLD_CREDITS

        LD      A,(INTRO_TIMER)
        INC     A
        LD      (INTRO_TIMER),A
        CP      3
        RET     NZ
        XOR     A
        LD      (INTRO_TIMER),A

        CALL    INTRO_ERASE_ROW
        LD      A,(INTRO_ROW)
        CP      INTRO_TARGET_ROW
        JR      Z,IU_REACHED
        DEC     A
        LD      (INTRO_ROW),A
        JP      INTRO_DRAW_ROW
IU_REACHED:
        CALL    INTRO_DRAW_ROW
        LD      A,1
        LD      (INTRO_PHASE),A
        XOR     A
        LD      (INTRO_TIMER),A
        RET
IU_HOLD_LOGO:
        LD      A,(INTRO_TIMER)
        INC     A
        LD      (INTRO_TIMER),A
        CP      120                     ; 2 seconds @ 60fps
        RET     C
        CALL    INTRO_SHOW_CREDITS
        LD      A,2
        LD      (INTRO_PHASE),A
        XOR     A
        LD      (INTRO_TIMER),A
        RET
IU_HOLD_CREDITS:
        LD      A,(INTRO_TIMER)
        INC     A
        LD      (INTRO_TIMER),A
        CP      120                     ; 2 seconds @ 60fps
        RET     C
        LD      A,GS_TITLE
        LD      (GAME_STATE),A
        JP      TITLE_INIT

; ---- INTRO_SHOW_CREDITS: clear the screen and print the 4 credit
; lines, each individually centered horizontally -----------------------
INTRO_SHOW_CREDITS:
        CALL    CLEAR_SCREEN
        LD      HL,CREDIT_LINE1
        LD      B,9
        LD      C,12
        CALL    PRINT_AT
        LD      HL,CREDIT_LINE2
        LD      B,10
        LD      C,19
        CALL    PRINT_AT
        LD      HL,CREDIT_LINE3
        LD      B,11
        LD      C,17
        CALL    PRINT_AT
        LD      HL,CREDIT_LINE4
        LD      B,13
        LD      C,16
        JP      PRINT_AT

; letters sit at columns 17/19/21/23 ("F O N Y"), only the row animates
INTRO_DRAW_ROW:
        LD      HL,INTRO_LETTERS
        JR      INTRO_PUT_ROW
INTRO_ERASE_ROW:
        LD      HL,INTRO_BLANKS
INTRO_PUT_ROW:
        LD      A,(INTRO_ROW)
        LD      B,A
        LD      C,17
        JP      PRINT_AT

; ============================================================
; Title / welcome screen
; ============================================================
TITLE_INIT:
        CALL    CLEAR_SCREEN
        LD      HL,TITLE_TEXT
        LD      B,3
        LD      C,18
        CALL    PRINT_AT
        LD      HL,HISCORE_HDR_TEXT
        LD      B,6
        LD      C,14
        CALL    PRINT_AT
        CALL    HISCORE_DRAW_LIST
        LD      HL,PRESS_SPACE_TEXT
        LD      B,19
        LD      C,8
        CALL    PRINT_AT
        LD      HL,PRESS_2_TEXT
        LD      B,20
        LD      C,8
        CALL    PRINT_AT
        LD      HL,HELP_TEXT
        LD      B,22
        LD      C,8
        CALL    PRINT_AT
        LD      HL,HELP2_TEXT
        LD      B,23
        LD      C,3
        JP      PRINT_AT

; ---- TITLE_UPDATE: call once per frame during GS_TITLE ----------------
TITLE_UPDATE:
        LD      A,(NEWKEY)              ; keyboard row 0: digits (active low)
        LD      C,A
        BIT     2,C                     ; "2" -> 2 players
        LD      B,1
        JR      Z,TU_START
        BIT     1,C                     ; "1" -> 1 player
        JR      Z,TU_ONE
        CALL    IS_SPACE_DOWN           ; SPACE -> 1 player
        OR      A
        RET     Z
TU_ONE:
        LD      B,0
TU_START:
        LD      A,B
        LD      (MODE),A
        LD      A,(JIFFY)               ; seed the RNG from the moment of the press
        LD      (RNG_SEED),A
        CALL    RESET_GAME_STATS
        JP      LEVEL_START             ; ends in GS_SERVE
