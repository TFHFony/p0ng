; ============================================================
; P0NG  --  main.asm
; MSX1 ROM header, boot init, frame sync, game state dispatch
; ============================================================

    ORG $4000
    DB  "AB"
    DW  INIT
    DW  0,0,0,0,0,0

    INCLUDE "equ.asm"

; ============================================================
INIT:
        DI
        LD      SP,STACK_TOP
        CALL    INITXT                  ; SCREEN 0, WIDTH 40

        XOR     A
        LD      (CLIKSW),A              ; keyclick off

        LD      B,$21                   ; COLOR 2,1,1 (fg green, bg/border black)
        LD      C,7
        CALL    WRTVDP

        LD      A,1
        LD      (RNG_SEED),A
        CALL    LOAD_CHARSET
        CALL    HISCORE_INIT
        CALL    SOUND_INIT

        EI                              ; keeps the BIOS keyboard scan (NEWKEY) alive

        LD      A,GS_INTRO
        LD      (GAME_STATE),A
        CALL    INTRO_INIT

; ---- MAIN_LOOP: one iteration per VBlank -----------------------------
MAIN_LOOP:
        CALL    WAIT_VBLANK
        CALL    SOUND_UPDATE            ; every frame, in every state
        LD      A,(GAME_STATE)

        CP      GS_INTRO
        JR      NZ,ML_1
        CALL    INTRO_UPDATE
        JR      MAIN_LOOP
ML_1:
        CP      GS_TITLE
        JR      NZ,ML_2
        CALL    TITLE_UPDATE
        JR      MAIN_LOOP
ML_2:
        CP      GS_PLAYING
        JR      NZ,ML_3
        CALL    PLAYING_UPDATE
        JR      MAIN_LOOP
ML_3:
        CP      GS_SERVE
        JR      NZ,ML_4
        CALL    SERVE_UPDATE
        JR      MAIN_LOOP
ML_4:
        CP      GS_POINT
        JR      NZ,ML_5
        CALL    POINT_UPDATE
        JR      MAIN_LOOP
ML_5:
        CP      GS_LEVELINTRO
        JR      NZ,ML_6
        CALL    LEVELINTRO_UPDATE
        JR      MAIN_LOOP
ML_6:
        CP      GS_GAMEOVER
        JR      NZ,ML_7
        CALL    GAMEOVER_UPDATE
        JR      MAIN_LOOP
ML_7:
        CP      GS_HISCORE
        JR      NZ,MAIN_LOOP
        CALL    HISCORE_ENTRY_UPDATE
        JR      MAIN_LOOP

; ============================================================
; GS_LEVELINTRO - brief "LEVEL XX" screen shown between levels
; ============================================================
LEVELINTRO_TEXT: DB "LEVEL ",0

LEVELINTRO_INIT:
        CALL    CLEAR_SCREEN
        LD      HL,LEVELINTRO_TEXT
        LD      B,11
        LD      C,16
        CALL    PRINT_AT

        LD      A,(LEVEL)
        LD      B,0
LI_TENS:
        CP      10
        JR      C,LI_DONE
        SUB     10
        INC     B
        JR      LI_TENS
LI_DONE:
        LD      C,A
        LD      A,B
        ADD     A,'0'
        LD      (TXT_BUF+0),A
        LD      A,C
        ADD     A,'0'
        LD      (TXT_BUF+1),A
        XOR     A
        LD      (TXT_BUF+2),A
        LD      HL,TXT_BUF
        LD      B,11
        LD      C,22
        CALL    PRINT_AT

        LD      A,90
        LD      (DYING_TIMER),A
        RET

LEVELINTRO_UPDATE:
        LD      A,(DYING_TIMER)
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ
        JP      LEVEL_START             ; ends in GS_SERVE

; ============================================================
; GS_GAMEOVER
; ============================================================
GAMEOVER_TEXT: DB "GAME OVER",0

GAMEOVER_UPDATE:
        LD      A,(DYING_TIMER)
        OR      A
        JR      NZ,GO_TICK
        LD      A,90
        LD      (DYING_TIMER),A
        CALL    CLEAR_MSG
        LD      A,(MODE)
        OR      A
        JR      NZ,GO_WINNER
        LD      HL,GAMEOVER_TEXT
        LD      B,MSG_ROW
        LD      C,15
        JP      PRINT_AT
GO_WINNER:
        LD      A,(SC1)
        CP      WIN_SCORE
        LD      HL,MSG_P1WIN
        JR      Z,GO_WPRINT
        LD      HL,MSG_P2WIN
GO_WPRINT:
        LD      B,MSG_ROW
        LD      C,13
        JP      PRINT_AT
GO_TICK:
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ

        LD      A,(MODE)
        OR      A
        JR      NZ,GO_NOTQUALIFY        ; no high scores in 2-player
        CALL    HISCORE_QUALIFIES
        OR      A
        JR      Z,GO_NOTQUALIFY
        LD      A,GS_HISCORE
        LD      (GAME_STATE),A
        JP      HISCORE_ENTRY_INIT
GO_NOTQUALIFY:
        LD      A,GS_TITLE
        LD      (GAME_STATE),A
        JP      TITLE_INIT

; ============================================================
; module includes
; ============================================================
    INCLUDE "vdp.asm"
    INCLUDE "charset.asm"
    INCLUDE "input.asm"
    INCLUDE "pong.asm"
    INCLUDE "score.asm"
    INCLUDE "highscore.asm"
    INCLUDE "sound.asm"
    INCLUDE "intro.asm"

    DEFS $8000-$,0
