; ============================================================
; P0NG  --  highscore.asm
; 10-entry high-score table (3-char name + BCD score), sorted
; descending, plus the on-screen name-entry mini state machine.
; ============================================================

HISCORE_PROMPT: DB "NEW HIGH SCORE - ENTER NAME:",0

; ---- CMP3_GT: HL=ptr1(3 bytes,+0=low..+2=high), DE=ptr2(same layout)
; -> A=1 if val(HL) > val(DE), else A=0. Leaves HL/DE unchanged. ------
CMP3_GT:
        PUSH    HL
        PUSH    DE
        INC     HL
        INC     HL
        INC     DE
        INC     DE
        LD      A,(DE)
        LD      B,A
        LD      A,(HL)
        CP      B
        JR      C,C3_NO
        JR      NZ,C3_YES
        DEC     HL
        DEC     DE
        LD      A,(DE)
        LD      B,A
        LD      A,(HL)
        CP      B
        JR      C,C3_NO
        JR      NZ,C3_YES
        DEC     HL
        DEC     DE
        LD      A,(DE)
        LD      B,A
        LD      A,(HL)
        CP      B
        JR      C,C3_NO
        JR      NZ,C3_YES
C3_NO:
        POP     DE
        POP     HL
        XOR     A
        RET
C3_YES:
        POP     DE
        POP     HL
        LD      A,1
        RET

; ---- HISCORE_INIT: fill the table with placeholder "---" 000000 -----
HISCORE_INIT:
        LD      IX,HISCORE_TBL
        LD      B,HISCORE_ENTRIES
HI_LOOP:
        LD      (IX+0),'-'
        LD      (IX+1),'-'
        LD      (IX+2),'-'
        LD      (IX+3),0
        LD      (IX+4),0
        LD      (IX+5),0
        PUSH    BC
        PUSH    IX
        POP     HL
        LD      DE,HISCORE_STRIDE
        ADD     HL,DE
        PUSH    HL
        POP     IX
        POP     BC
        DJNZ    HI_LOOP
        RET

; ---- HISCORE_QUALIFIES: -> A=1 if SCORE_BCD beats the lowest entry --
HISCORE_QUALIFIES:
        LD      HL,SCORE_BCD
        LD      DE,HISCORE_TBL+((HISCORE_ENTRIES-1)*HISCORE_STRIDE)+3
        JP      CMP3_GT

; ---- HISCORE_INSERT: insert SCORE_BCD/NAME_BUF into the sorted table.
; Two phases: (1) find the insertion index by comparing against every
; entry from the top down - including entry[0], which a previous
; version skipped, so any qualifying score was always forced into
; rank #1 regardless of whether it actually beat the current best;
; (2) shift entries at/below that index down one slot (from the
; bottom up, so nothing is overwritten before it's copied) and write
; the new entry into the vacated slot. PRECONDITION: caller already
; verified HISCORE_QUALIFIES=1, so phase 1 is guaranteed to stop at
; or before the last entry.
HISCORE_INSERT:
        LD      IX,HISCORE_TBL
        XOR     A
        LD      (HINS_IDX),A
HFIND_LOOP:
        PUSH    IX
        POP     DE
        INC     DE
        INC     DE
        INC     DE                      ; DE -> entry[idx].score
        LD      HL,SCORE_BCD
        CALL    CMP3_GT                 ; A=1 if SCORE_BCD > entry[idx]
        OR      A
        JR      NZ,HFIND_DONE           ; found the insertion index

        LD      A,(HINS_IDX)
        INC     A
        LD      (HINS_IDX),A
        PUSH    IX
        POP     HL
        LD      DE,HISCORE_STRIDE
        ADD     HL,DE
        PUSH    HL
        POP     IX
        JR      HFIND_LOOP
HFIND_DONE:

        ; shift entries[idx..ENTRIES-2] down into [idx+1..ENTRIES-1],
        ; processing from the bottom (ENTRIES-2) up to idx so each
        ; write lands in an already-copied-out slot
        LD      A,HISCORE_ENTRIES-2
        LD      (HSHIFT_I),A
HSHIFT_LOOP:
        LD      A,(HSHIFT_I)
        INC     A
        JR      Z,HSHIFT_DONE           ; i underflowed past 0 - done
        DEC     A
        LD      HL,HINS_IDX
        CP      (HL)
        JR      C,HSHIFT_DONE           ; i < idx - done

        ; src = HISCORE_TBL + i*HISCORE_STRIDE, dst = src+HISCORE_STRIDE
        LD      L,A
        LD      H,0
        ADD     HL,HL                   ; *2
        LD      D,H
        LD      E,L
        ADD     HL,HL                   ; *4
        ADD     HL,DE                   ; *6
        LD      DE,HISCORE_TBL
        ADD     HL,DE                   ; HL = &entry[i] (src)
        PUSH    HL
        LD      DE,HISCORE_STRIDE
        ADD     HL,DE                   ; HL = &entry[i+1] (dst)
        EX      DE,HL                   ; DE = dst
        POP     HL                      ; HL = src
        PUSH    BC
        LD      BC,HISCORE_STRIDE
        LDIR
        POP     BC

        LD      A,(HSHIFT_I)
        DEC     A
        LD      (HSHIFT_I),A
        JR      HSHIFT_LOOP
HSHIFT_DONE:
        ; write the new entry at HISCORE_TBL + idx*HISCORE_STRIDE
        LD      A,(HINS_IDX)
        LD      L,A
        LD      H,0
        ADD     HL,HL
        LD      D,H
        LD      E,L
        ADD     HL,HL
        ADD     HL,DE
        LD      DE,HISCORE_TBL
        ADD     HL,DE
        PUSH    HL
        POP     IX
HINS_WRITE:
        LD      A,(NAME_BUF+0)
        LD      (IX+0),A
        LD      A,(NAME_BUF+1)
        LD      (IX+1),A
        LD      A,(NAME_BUF+2)
        LD      (IX+2),A
        LD      A,(SCORE_BCD+0)
        LD      (IX+3),A
        LD      A,(SCORE_BCD+1)
        LD      (IX+4),A
        LD      A,(SCORE_BCD+2)
        LD      (IX+5),A
        RET

; ---- HISCORE_DRAW_LIST: renders all 10 entries starting at row 8 ----
HISCORE_DRAW_LIST:
        XOR     A
        LD      (HDL_IDX),A
        LD      IX,HISCORE_TBL
HDL_LOOP:
        LD      A,(HDL_IDX)
        CP      HISCORE_ENTRIES
        RET     Z

        LD      A,(HDL_IDX)
        CP      9
        JR      Z,HDL_RANK10
        LD      A,' '
        LD      (TXT_BUF+0),A
        LD      A,(HDL_IDX)
        ADD     A,'1'
        LD      (TXT_BUF+1),A
        JR      HDL_RANKDONE
HDL_RANK10:
        LD      A,'1'
        LD      (TXT_BUF+0),A
        LD      A,'0'
        LD      (TXT_BUF+1),A
HDL_RANKDONE:
        LD      A,'.'
        LD      (TXT_BUF+2),A
        LD      A,' '
        LD      (TXT_BUF+3),A
        LD      A,(IX+0)
        LD      (TXT_BUF+4),A
        LD      A,(IX+1)
        LD      (TXT_BUF+5),A
        LD      A,(IX+2)
        LD      (TXT_BUF+6),A
        LD      A,' '
        LD      (TXT_BUF+7),A

        PUSH    IX
        POP     HL
        LD      DE,3
        ADD     HL,DE
        LD      DE,TXT_BUF+8
        CALL    BCD3_TO_ASCII
        XOR     A
        LD      (TXT_BUF+14),A

        LD      HL,TXT_BUF
        LD      A,(HDL_IDX)
        ADD     A,8
        LD      B,A
        LD      C,10
        CALL    PRINT_AT

        PUSH    IX
        POP     HL
        LD      DE,HISCORE_STRIDE
        ADD     HL,DE
        PUSH    HL
        POP     IX

        LD      A,(HDL_IDX)
        INC     A
        LD      (HDL_IDX),A
        JR      HDL_LOOP

; ============================================================
; Name entry mini state machine (active during GS_HISCORE)
; ============================================================

; ---- HISCORE_ENTRY_INIT: call once when entering GS_HISCORE ---------
HISCORE_ENTRY_INIT:
        CALL    CLEAR_SCREEN
        CALL    READ_NAME_KEY_INIT
        XOR     A
        LD      (NAME_LEN),A
        LD      HL,HISCORE_PROMPT
        LD      B,MSG_ROW-1
        LD      C,5
        CALL    PRINT_AT
        JP      HISCORE_DRAW_NAME

; ---- HISCORE_DRAW_NAME: redraw the typed-so-far name w/ '_' filler --
HISCORE_DRAW_NAME:
        LD      A,'_'
        LD      (TXT_BUF+0),A
        LD      (TXT_BUF+1),A
        LD      (TXT_BUF+2),A
        XOR     A
        LD      (TXT_BUF+3),A
        LD      A,(NAME_LEN)
        OR      A
        JR      Z,HDN_GO
        LD      B,A
        LD      HL,NAME_BUF
        LD      DE,TXT_BUF
HDN_COPY:
        LD      A,(HL)
        LD      (DE),A
        INC     HL
        INC     DE
        DJNZ    HDN_COPY
HDN_GO:
        LD      HL,TXT_BUF
        LD      B,MSG_ROW
        LD      C,18
        JP      PRINT_AT

; ---- HISCORE_ENTRY_UPDATE: call once per frame during GS_HISCORE ----
; Reads via READ_NAME_KEY (raw keyboard matrix), which only ever
; returns 'A'-'Z' (already uppercase), 13, 8, or 0.
HISCORE_ENTRY_UPDATE:
        CALL    READ_NAME_KEY
        OR      A
        RET     Z
        CP      13
        JP      Z,HEU_ENTER
        CP      8
        JR      Z,HEU_BACK
HEU_ADDCHAR:
        PUSH    AF                      ; save the pressed character FIRST -
                                         ; the NAME_LEN checks below clobber A
        LD      HL,NAME_LEN
        LD      B,(HL)
        LD      A,B
        CP      3
        JR      NC,HEU_ADDCHAR_FULL
        LD      HL,NAME_BUF
        LD      D,0
        LD      E,B
        ADD     HL,DE
        POP     AF                      ; restore the actual character
        LD      (HL),A
        LD      A,B
        INC     A
        LD      (NAME_LEN),A
        JP      HISCORE_DRAW_NAME
HEU_ADDCHAR_FULL:
        POP     AF                      ; balance the stack, character discarded
        JR      HEU_DONE
HEU_BACK:
        LD      A,(NAME_LEN)
        OR      A
        JR      Z,HEU_DONE
        DEC     A
        LD      (NAME_LEN),A
        JP      HISCORE_DRAW_NAME
HEU_ENTER:
        LD      A,(NAME_LEN)
        OR      A
        JR      Z,HEU_DONE
        CALL    HISCORE_INSERT
        LD      A,GS_TITLE
        LD      (GAME_STATE),A
        JP      TITLE_INIT
HEU_DONE:
        RET
