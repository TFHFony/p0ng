; ============================================================
; P0NG  --  pong.asm
; Playfield, paddles, ball physics, computer opponent, serve
; ============================================================

MSG_GETREADY:   DB "GET READY",0
MSG_POINT:      DB "POINT!",0
MSG_P1PT:       DB "PLAYER 1 SCORES",0
MSG_P2PT:       DB "PLAYER 2 SCORES",0
MSG_P1WIN:      DB "PLAYER 1 WINS!",0
MSG_P2WIN:      DB "PLAYER 2 WINS!",0
MSG_FIRST:      DB "FIRST TO 7",0

; hit offset on the paddle (0=top .. 4=bottom) -> BDY, BSTEEP
ANGLE_TBL:
        DB      $FF,1           ; 0: up, steep
        DB      $FF,0           ; 1: up, shallow
        DB      0,0             ; 2: centre (unused - keeps incoming angle)
        DB      1,0             ; 3: down, shallow
        DB      1,1             ; 4: down, steep

; ---- CLEAR_MSG: blank the bottom message row ---------------------------
CLEAR_MSG:
        LD      HL,NAMTBL+(MSG_ROW*SCR_COLS)
        LD      BC,SCR_COLS
        LD      A,T_SPACE
        JP      FILVRM

; ---- DRAW_FIELD: top/bottom boundary lines + dashed centre net ----------
DRAW_FIELD:
        LD      HL,NAMTBL+(WALL_TOP_ROW*SCR_COLS)
        LD      BC,SCR_COLS
        LD      A,T_WALL_H
        CALL    FILVRM
        LD      HL,NAMTBL+(WALL_BOT_ROW*SCR_COLS)
        LD      BC,SCR_COLS
        LD      A,T_WALL_H
        CALL    FILVRM
        LD      B,FIELD_TOP
DF_NET:
        LD      C,NET_COL
        LD      A,T_NET
        PUSH    BC
        CALL    PUT_TILE
        POP     BC
        INC     B
        LD      A,B
        CP      FIELD_BOT+1
        JR      NZ,DF_NET
        RET

; ---- DRAW_PADDLE: A=tile, B=top row, C=column (clobbers B,D,E,HL) -------
DRAW_PADDLE:
        LD      D,PAD_H
        LD      E,A
DP_LOOP:
        PUSH    DE
        PUSH    BC
        LD      A,E
        CALL    PUT_TILE
        POP     BC
        POP     DE
        INC     B
        DEC     D
        JR      NZ,DP_LOOP
        RET

; ---- PADDLE_MOVE: C=column, HL=&top-row variable, A=+1/$FF delta.
; Caller has already checked the bounds. ---------------------------------
PADDLE_MOVE:
        PUSH    AF
        LD      B,(HL)
        PUSH    BC
        PUSH    HL
        LD      A,T_SPACE
        CALL    DRAW_PADDLE             ; erase at the old position
        POP     HL
        POP     BC
        POP     AF
        ADD     A,B
        LD      (HL),A
        LD      B,A
        LD      A,T_PAD
        JP      DRAW_PADDLE

DRAW_PADDLES:
        LD      A,(P_Y)
        LD      B,A
        LD      C,PAD_L_COL
        LD      A,T_PAD
        CALL    DRAW_PADDLE
        LD      A,(C_Y)
        LD      B,A
        LD      C,PAD_R_COL
        LD      A,T_PAD
        JP      DRAW_PADDLE

ERASE_PADDLES:
        LD      A,(P_Y)
        LD      B,A
        LD      C,PAD_L_COL
        LD      A,T_SPACE
        CALL    DRAW_PADDLE
        LD      A,(C_Y)
        LD      B,A
        LD      C,PAD_R_COL
        LD      A,T_SPACE
        JP      DRAW_PADDLE

; ---- ball drawing -----------------------------------------------------
BALL_DRAW:
        LD      A,(BY)
        LD      B,A
        LD      A,(BX)
        LD      C,A
        LD      A,T_BALL
        JP      PUT_TILE

; erasing restores the net if the ball was sitting on it
BALL_ERASE:
        LD      A,(BY)
        LD      B,A
        LD      A,(BX)
        LD      C,A
        CP      NET_COL
        LD      A,T_SPACE
        JP      NZ,PUT_TILE
        LD      A,T_NET
        JP      PUT_TILE

; ============================================================
; LEVEL_START: fresh field + full HUD redraw, then serve
; ============================================================
LEVEL_START:
        CALL    CLEAR_SCREEN
        CALL    DRAW_FIELD
        LD      A,(MODE)
        OR      A
        JR      NZ,LS_2P
        CALL    HUD_INIT
        CALL    DRAW_SCORE
        CALL    DRAW_HIGHSCORE
        CALL    DRAW_LEVEL
        CALL    DRAW_LIVES
        JR      SERVE_INIT
LS_2P:
        CALL    DRAW_2P_HUD
        ; fall through

; ---- SERVE_INIT: centre the paddles, put a new ball in the middle,
; flip serve direction, enter GS_SERVE -----------------------------------
SERVE_INIT:
        CALL    ERASE_PADDLES
        LD      A,PAD_MID
        LD      (P_Y),A
        LD      (C_Y),A
        CALL    DRAW_PADDLES

        LD      A,(SERVE_DIR)
        NEG
        LD      (SERVE_DIR),A
        LD      (BDX),A
        LD      B,20
        CP      1
        JR      Z,SI_COL
        LD      B,19
SI_COL:
        LD      A,B
        LD      (BX),A

        CALL    RANDOM
        AND     7
        ADD     A,6
        LD      (BY),A                  ; row 6..13

        CALL    RANDOM
        AND     3
        LD      B,0
        CP      1
        JR      NZ,SI_NOTUP
        LD      B,$FF
SI_NOTUP:
        CP      2
        JR      NZ,SI_DY
        LD      B,1
SI_DY:
        LD      A,B
        LD      (BDY),A
        CALL    RANDOM
        AND     1
        LD      (BSTEEP),A
        XOR     A
        LD      (BTOG),A
        LD      (PAD_TMR),A

        ; computer aiming error: wide early on (it sometimes whiffs),
        ; tighter from level 6
        CALL    RANDOM
        LD      B,A
        LD      A,(LEVEL)
        CP      6
        LD      A,B
        JR      NC,SI_ERR_SMALL
        AND     7
        SUB     3                       ; -3..+4
        JR      SI_ERR_SET
SI_ERR_SMALL:
        AND     3
        DEC     A                       ; -1..+2
SI_ERR_SET:
        LD      (CPU_ERR),A

        LD      A,(BSPD)
        LD      (BTMR),A
        LD      A,(CPU_SPD)
        LD      (CPU_TMR),A

        CALL    BALL_DRAW
        CALL    CLEAR_MSG
        LD      HL,MSG_GETREADY
        LD      B,MSG_ROW
        LD      C,15
        CALL    PRINT_AT

        LD      A,50
        LD      (DYING_TIMER),A
        LD      A,GS_SERVE
        LD      (GAME_STATE),A
        RET

; ============================================================
; GS_SERVE - ball waits in the centre, player may already move
; ============================================================
SERVE_UPDATE:
        CALL    PLAYER_UPDATE
        LD      A,(DYING_TIMER)
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ
        CALL    CLEAR_MSG
        LD      A,GS_PLAYING
        LD      (GAME_STATE),A
        RET

; ============================================================
; GS_PLAYING
; ============================================================
PLAYING_UPDATE:
        CALL    PLAYER_UPDATE
        LD      A,(MODE)
        OR      A
        CALL    Z,CPU_UPDATE
        JP      BALL_UPDATE

; ---- PLAYER_UPDATE: one row per 3 frames per paddle.
; 1 player : left paddle on the cursor keys.
; 2 players: left paddle on Q/A, right paddle on the cursor keys. ----------
PLAYER_UPDATE:
        LD      A,(PAD_TMR)
        OR      A
        JR      Z,PL_READY
        DEC     A
        LD      (PAD_TMR),A
        JR      PL_RIGHT
PL_READY:
        LD      A,(MODE)
        OR      A
        JR      NZ,PL_KEYS
        CALL    DIR_CURSOR
        JR      PL_GO
PL_KEYS:
        CALL    DIR_QA
PL_GO:
        OR      A
        JR      Z,PL_RIGHT
        LD      C,PAD_L_COL
        LD      HL,P_Y
        LD      DE,PAD_TMR
        CALL    PAD_CTRL
PL_RIGHT:
        LD      A,(MODE)
        OR      A
        RET     Z
        LD      A,(PAD_TMR2)
        OR      A
        JR      Z,PR_READY
        DEC     A
        LD      (PAD_TMR2),A
        RET
PR_READY:
        CALL    DIR_CURSOR
        OR      A
        RET     Z
        LD      C,PAD_R_COL
        LD      HL,C_Y
        LD      DE,PAD_TMR2
        JP      PAD_CTRL

; ---- DIR_CURSOR: A = $FF (up) / 1 (down) / 0 from the cursor keys ----
DIR_CURSOR:
        CALL    READ_ROW8
        LD      A,(INPUT_ROW8)
        CPL
        LD      B,A
        BIT     5,B
        LD      A,$FF
        RET     NZ
        BIT     6,B
        LD      A,1
        RET     NZ
        XOR     A
        RET

; ---- DIR_QA: same, from Q (up) and A (down) ---------------------------
DIR_QA:
        LD      A,(NEWKEY+4)
        BIT     6,A                     ; Q (active low)
        JR      NZ,DQ_A
        LD      A,$FF
        RET
DQ_A:
        LD      A,(NEWKEY+2)
        BIT     6,A                     ; A
        JR      NZ,DQ_NONE
        LD      A,1
        RET
DQ_NONE:
        XOR     A
        RET

; ---- PAD_CTRL: A=$FF/1 direction, C=column, HL=&top-row var,
; DE=&repeat timer. Checks the bounds, moves one row, arms the timer. ----
PAD_CTRL:
        LD      B,A
        LD      A,(HL)
        BIT     7,B
        JR      NZ,PC_UP
        CP      PAD_MAXTOP
        RET     NC
        JR      PC_GO
PC_UP:
        CP      FIELD_TOP+1
        RET     C
PC_GO:
        LD      A,2
        LD      (DE),A
        LD      A,B
        JP      PADDLE_MOVE

; ---- DRAW_2P_HUD: "P1 n   FIRST TO 7   P2 n" -------------------------
DRAW_2P_HUD:
        LD      A,'P'
        LD      (TXT_BUF),A
        LD      A,'1'
        LD      (TXT_BUF+1),A
        LD      A,' '
        LD      (TXT_BUF+2),A
        LD      A,(SC1)
        ADD     A,'0'
        LD      (TXT_BUF+3),A
        XOR     A
        LD      (TXT_BUF+4),A
        LD      HL,TXT_BUF
        LD      B,HUD_ROW
        LD      C,0
        CALL    PRINT_AT
        LD      A,'2'
        LD      (TXT_BUF+1),A
        LD      A,(SC2)
        ADD     A,'0'
        LD      (TXT_BUF+3),A
        LD      HL,TXT_BUF
        LD      B,HUD_ROW
        LD      C,36
        CALL    PRINT_AT
        LD      HL,MSG_FIRST
        LD      B,HUD_ROW
        LD      C,15
        JP      PRINT_AT

; ---- CPU_UPDATE: tracks the incoming ball at a limited speed, drifts
; back to the middle while the ball is heading away ----------------------
CPU_UPDATE:
        LD      A,(CPU_TMR)
        DEC     A
        LD      (CPU_TMR),A
        RET     NZ
        LD      A,(CPU_SPD)
        LD      (CPU_TMR),A

        LD      A,(BDX)
        CP      1
        LD      A,PAD_MID
        JR      NZ,CU_HAVE              ; ball moving away -> go to centre
        LD      A,(BY)
        LD      B,A
        LD      A,(CPU_ERR)
        ADD     A,B
        SUB     2                       ; wanted top row = BY - 2 + error
        BIT     7,A
        JR      Z,CU_POS
        LD      A,FIELD_TOP
CU_POS:
        CP      FIELD_TOP
        JR      NC,CU_LOK
        LD      A,FIELD_TOP
CU_LOK:
        CP      PAD_MAXTOP+1
        JR      C,CU_HAVE
        LD      A,PAD_MAXTOP
CU_HAVE:
        LD      B,A                     ; B = target top row
        LD      A,(C_Y)
        CP      B
        RET     Z
        JR      C,CU_DOWN
        LD      A,$FF
        JR      CU_MOVE
CU_DOWN:
        LD      A,1
CU_MOVE:
        LD      C,PAD_R_COL
        LD      HL,C_Y
        JP      PADDLE_MOVE

; ---- BALL_ANGLE: A = hit offset 0..4 -> new BDY/BSTEEP (clobbers HL,BC)
BALL_ANGLE:
        CP      2
        RET     Z                       ; centre hit keeps the incoming angle
        LD      L,A
        LD      H,0
        ADD     HL,HL
        LD      BC,ANGLE_TBL
        ADD     HL,BC
        LD      A,(HL)
        LD      (BDY),A
        INC     HL
        LD      A,(HL)
        LD      (BSTEEP),A
        RET

; ---- BALL_UPDATE: one step every BSPD frames ----------------------------
BALL_UPDATE:
        LD      A,(BTMR)
        DEC     A
        LD      (BTMR),A
        RET     NZ
        LD      A,(BSPD)
        LD      (BTMR),A

        CALL    BALL_ERASE

        ; ---- vertical: D = this step's dy ----
        LD      A,(BDY)
        LD      D,A
        OR      A
        JR      Z,BU_DYOK
        LD      A,(BSTEEP)
        OR      A
        JR      NZ,BU_DYOK
        LD      A,(BTOG)                ; shallow: only every other step
        XOR     1
        LD      (BTOG),A
        JR      NZ,BU_DYOK
        LD      D,0
BU_DYOK:
        LD      A,(BY)
        ADD     A,D
        LD      E,A                     ; E = new row
        CP      FIELD_TOP
        JR      C,BU_BOUNCE
        CP      FIELD_BOT+1
        JR      C,BU_YOK
BU_BOUNCE:
        LD      A,(BDY)
        NEG
        LD      (BDY),A
        LD      A,D
        NEG
        LD      D,A
        LD      A,(BY)
        ADD     A,D
        LD      E,A
        PUSH    DE
        LD      A,SND_WALL
        CALL    SOUND_PLAY
        POP     DE
BU_YOK:
        ; ---- horizontal: D = new column ----
        LD      A,(BX)
        LD      B,A
        LD      A,(BDX)
        ADD     A,B
        LD      D,A
        CP      PAD_L_COL
        JR      Z,BU_LEFTPAD
        CP      PAD_R_COL
        JR      Z,BU_RIGHTPAD
BU_MOVE:
        LD      A,E
        LD      (BY),A
        LD      A,D
        LD      (BX),A
        JP      BALL_DRAW

BU_LEFTPAD:
        LD      A,(P_Y)
        LD      B,A
        LD      A,E
        SUB     B                       ; hit offset on the paddle
        CP      PAD_H
        JR      NC,BU_LEFT_MISS         ; missed: ball is gone
        CALL    BALL_ANGLE
        LD      A,1
        LD      (BDX),A
        LD      A,(BX)
        INC     A
        LD      D,A                     ; bounce straight off the paddle
        LD      A,E
        LD      (BY),A
        LD      A,D
        LD      (BX),A
        CALL    BALL_DRAW
        LD      A,SND_HIT
        CALL    SOUND_PLAY
        LD      A,(MODE)
        OR      A
        RET     NZ                      ; no score for returns in 2-player
        LD      D,0
        LD      E,1
        JP      ADD_SCORE_BCD           ; +1 per return

BU_LEFT_MISS:
        LD      A,(MODE)
        OR      A
        JP      Z,LOSE_LIFE             ; 1 player: life lost
        LD      A,2                     ; 2 players: right player scores
        JR      TWO_POINT

BU_RIGHTPAD:
        LD      A,(C_Y)
        LD      B,A
        LD      A,E
        SUB     B
        CP      PAD_H
        JR      NC,BU_RIGHT_MISS
        CALL    BALL_ANGLE
        LD      A,$FF
        LD      (BDX),A
        LD      A,(BX)
        DEC     A
        LD      D,A
        LD      A,E
        LD      (BY),A
        LD      A,D
        LD      (BX),A
        CALL    BALL_DRAW
        LD      A,SND_HIT
        JP      SOUND_PLAY

BU_RIGHT_MISS:
        LD      A,(MODE)
        OR      A
        LD      A,1                     ; 2 players: left player scores
        JR      NZ,TWO_POINT
BU_CPU_MISS:
        LD      A,SND_SCORE
        CALL    SOUND_PLAY
        LD      A,(WINS)
        INC     A
        LD      (WINS),A
        LD      A,60
        LD      (DYING_TIMER),A
        LD      A,GS_POINT
        LD      (GAME_STATE),A
        LD      HL,MSG_POINT
        LD      B,MSG_ROW
        LD      C,17
        CALL    PRINT_AT
        LD      D,0
        LD      E,$10
        JP      ADD_SCORE_BCD           ; +10 for winning the point

; ---- TWO_POINT: A = scoring player (1/2). Adds the point, speeds the
; ball up every 2nd point, then either a short GS_POINT pause or the
; end of the match (GAMEOVER_UPDATE prints the winner). ------------------
TWO_POINT:
        PUSH    AF
        LD      A,SND_SCORE
        CALL    SOUND_PLAY
        POP     AF
        PUSH    AF                      ; keep the scorer for the message
        CP      1
        LD      HL,SC1
        JR      Z,TP_ADD
        LD      HL,SC2
TP_ADD:
        INC     (HL)
        LD      A,(SC1)
        LD      HL,SC2
        ADD     A,(HL)
        AND     1
        JR      NZ,TP_NOSPEED
        LD      HL,LEVEL
        INC     (HL)
        CALL    BALL_FASTER
TP_NOSPEED:
        CALL    DRAW_2P_HUD
        POP     AF
        LD      E,A                     ; E = scorer (nothing below touches DE)
        LD      A,(SC1)
        CP      WIN_SCORE
        JR      Z,TP_WIN
        LD      A,(SC2)
        CP      WIN_SCORE
        JR      Z,TP_WIN
        LD      A,60
        LD      (DYING_TIMER),A
        LD      A,GS_POINT
        LD      (GAME_STATE),A
        LD      A,E
        CP      1
        LD      HL,MSG_P1PT
        JR      Z,TP_PRINT
        LD      HL,MSG_P2PT
TP_PRINT:
        LD      B,MSG_ROW
        LD      C,12
        JP      PRINT_AT
TP_WIN:
        XOR     A
        LD      (DYING_TIMER),A         ; GAMEOVER_UPDATE: 0 = fresh
        LD      A,GS_GAMEOVER
        LD      (GAME_STATE),A
        RET

; ============================================================
; GS_POINT - short pause after a point / lost life, then serve
; (or on to the next level after WINS_PER_LEVEL points)
; ============================================================
POINT_UPDATE:
        LD      A,(DYING_TIMER)
        DEC     A
        LD      (DYING_TIMER),A
        RET     NZ
        LD      A,(WINS)
        CP      WINS_PER_LEVEL
        JR      C,PT_SERVE
        XOR     A
        LD      (WINS),A
        CALL    NEXT_LEVEL
        LD      A,GS_LEVELINTRO
        LD      (GAME_STATE),A
        JP      LEVELINTRO_INIT
PT_SERVE:
        JP      SERVE_INIT
