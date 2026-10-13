; ============================================================
; P0NG  --  equ.asm
; BIOS routines, VDP registers, RAM layout, tile codes, constants
; ============================================================

; ---- BIOS entry points (Main-ROM, all MSX1) ----
INITXT      EQU $006C       ; init SCREEN 0 / WIDTH 40
WRTVDP      EQU $0047       ; B=value, C=register -> write VDP register
WRTVRM      EQU $004D       ; HL=vaddr, A=byte -> write
SETWRT      EQU $0053       ; HL=vaddr -> setup VDP for sequential write
FILVRM      EQU $0056       ; HL=vaddr, BC=len, A=value -> fill VRAM
LDIRVM      EQU $005C       ; HL=src(RAM), DE=vaddr, BC=len -> RAM to VRAM
GICINI      EQU $0090       ; init PSG
WRTPSG      EQU $0093       ; A=register, E=value -> write PSG register

VDP_DATA    EQU $98         ; VDP data port
VDP_CMD     EQU $99         ; VDP command/status port

; ---- BIOS system variables we read (auto-refreshed by BIOS each VBlank) ----
NEWKEY      EQU $FBE5       ; 11-byte debounced key matrix table, row N at NEWKEY+N
JIFFY       EQU $FC9E       ; 16-bit VBlank counter, incremented by BIOS
CLIKSW      EQU $F3DB       ; keyclick switch: 0=off, nonzero=on

; ---- Keyboard matrix row 8 (cursors + space), bit=0 means pressed ----
KEYROW_CURSOR EQU 8
KB_UP       EQU %00100000
KB_DOWN     EQU %01000000
KB_SPACE    EQU %00000001

; ============================================================
; Screen layout (SCREEN 0, WIDTH 40, 24 rows)
; ============================================================
SCR_COLS    EQU 40
SCR_ROWS    EQU 24
HUD_ROW     EQU 0            ; score / high score / level / lives
WALL_TOP_ROW EQU 1           ; top boundary line
FIELD_TOP   EQU 2            ; first playable row
FIELD_BOT   EQU 21           ; last playable row
WALL_BOT_ROW EQU 22          ; bottom boundary line
MSG_ROW     EQU 23           ; bottom message/prompt row

NAMTBL      EQU $0000        ; text name table base (set by INITXT)
PATGEN      EQU $0800        ; pattern generator table base (set by INITXT)

; ============================================================
; Tile codes
; ============================================================
T_SPACE     EQU 32
T_WALL_H    EQU 23           ; built-in horizontal line (verified in c0man)

; custom tiles (codes 1-4 are otherwise-unused control-picture slots)
T_RING      EQU 1            ; the "0" of P0NG (same oval as c0man's 0)
T_BALL      EQU 2
T_PAD       EQU 3            ; one row of paddle, stacks seamlessly
T_NET       EQU 4            ; dashed centre line

; ============================================================
; Playfield geometry
; ============================================================
PAD_L_COL   EQU 2            ; player paddle column
PAD_R_COL   EQU 37           ; computer paddle column
NET_COL     EQU 19
PAD_H       EQU 5            ; paddle height in rows
PAD_MAXTOP  EQU FIELD_BOT-PAD_H+1
PAD_MID     EQU 9            ; centred paddle top row
WINS_PER_LEVEL EQU 3         ; points won to advance a level

; ============================================================
; Game states
; ============================================================
GS_INTRO    EQU 0
GS_TITLE    EQU 1
GS_PLAYING  EQU 2
GS_POINT    EQU 3            ; short pause after a point / a lost life
GS_GAMEOVER EQU 4
GS_HISCORE  EQU 5
GS_LEVELINTRO EQU 6
GS_SERVE    EQU 7            ; "GET READY", ball waiting at the centre

; ============================================================
; RAM layout (system RAM, plain EQU literals - no ORG)
; ============================================================
P_Y         EQU $E000        ; player paddle top row
C_Y         EQU $E001        ; computer paddle top row
BX          EQU $E002        ; ball column
BY          EQU $E003        ; ball row
BDX         EQU $E004        ; +1 / $FF
BDY         EQU $E005        ; +1 / 0 / $FF
BSTEEP      EQU $E006        ; 1 = vertical step every move, 0 = every other move
BTOG        EQU $E007        ; shallow-angle toggle
BTMR        EQU $E008        ; frames until the next ball step
BSPD        EQU $E009        ; frames per ball step (lower = faster)
CPU_SPD     EQU $E00A        ; frames per computer paddle step
CPU_TMR     EQU $E00B
CPU_ERR     EQU $E00C        ; signed aiming error for this serve
PAD_TMR     EQU $E00D        ; player paddle repeat delay
WINS        EQU $E00E        ; points won on this level
SERVE_DIR   EQU $E00F        ; toggles every serve

SCORE_BCD   EQU $E010        ; 3 bytes packed BCD (6 digits)
LIVES       EQU $E013
LEVEL       EQU $E014
GAME_STATE  EQU $E015
RNG_SEED    EQU $E016
INPUT_ROW8  EQU $E017
DYING_TIMER EQU $E018        ; shared pause timer (point / serve / gameover)

SND_TIMER   EQU $E019
SND_VOL     EQU $E01A
SND_HIT     EQU 0
SND_WALL    EQU 1
SND_SCORE   EQU 2
SND_LIFE    EQU 3
SND_GAMEOVER EQU 4

INTRO_ROW   EQU $E01B
INTRO_TIMER EQU $E01C
INTRO_PHASE EQU $E01D

TXT_BUF     EQU $E020        ; 16 bytes, shared scratch text buffer
NAME_BUF    EQU $E030        ; 3 bytes
NAME_LEN    EQU $E033
HDL_IDX     EQU $E034
PREV_ROW2   EQU $E035
PREV_ROW3   EQU $E036
PREV_ROW4   EQU $E037
PREV_ROW5   EQU $E038
PREV_ROW7   EQU $E039
RNK_E2      EQU $E03A
RNK_E3      EQU $E03B
RNK_E4      EQU $E03C
RNK_E5      EQU $E03D
RNK_E7      EQU $E03E
HINS_IDX    EQU $E03F
HSHIFT_I    EQU $E040
DLV_COUNT   EQU $E041
DLV_IDX     EQU $E042
MODE        EQU $E043        ; 0 = 1 player vs computer, 1 = 2 players
SC1         EQU $E044        ; 2-player points, left player
SC2         EQU $E045        ; 2-player points, right player
PAD_TMR2    EQU $E046        ; right paddle repeat delay (2-player)
WIN_SCORE   EQU 7            ; points to win a 2-player match

; ---- high score table: 10 x (3 name + 3 BCD score) ----
HISCORE_TBL EQU $E100        ; 60 bytes
HISCORE_ENTRIES EQU 10
HISCORE_STRIDE EQU 6

STACK_TOP   EQU $F380
