; ============================================================
; P0NG  --  input.asm
; Space reading for the title screen (cursor keys are read in pong.asm) (from the BIOS-maintained
; debounced NEWKEY table, refreshed every VBlank) and simple
; blocking text entry (BIOS CHGET) for the high-score name.
; ============================================================

; ---- IS_SPACE_DOWN: A=1/NZ if SPACE is currently held, A=0/Z if not
; (the raw matrix bit is active-LOW, this normalises the sense) -------
IS_SPACE_DOWN:
        CALL    READ_ROW8
        LD      A,(INPUT_ROW8)
        AND     KB_SPACE
        JR      Z,ISD_YES
        XOR     A
        RET
ISD_YES:
        LD      A,1
        RET

; ============================================================
; High-score name entry: reads letters/ENTER/BACKSPACE straight off
; the raw keyboard matrix (NEWKEY), the same proven mechanism the
; cursor keys use - the BIOS's higher-level keyboard *buffer*
; (CHGET/CHSNS) turned out not to deliver keys on this system.
; Rows: 2=A,B  3=C..J  4=K..R  5=S..Z  7=RET(bit7)/BS(bit5)
; ============================================================

; ---- READ_NAME_KEY_INIT: call once when the name-entry screen opens,
; so already-held keys don't register as an immediate press. ----------
READ_NAME_KEY_INIT:
        LD      A,(NEWKEY+2)
        LD      (PREV_ROW2),A
        LD      A,(NEWKEY+3)
        LD      (PREV_ROW3),A
        LD      A,(NEWKEY+4)
        LD      (PREV_ROW4),A
        LD      A,(NEWKEY+5)
        LD      (PREV_ROW5),A
        LD      A,(NEWKEY+7)
        LD      (PREV_ROW7),A
        RET

; ---- SCAN_ROW_EDGES: HL=&NEWKEY_row, DE=&PREV_row storage ->
; A = bitmask of bits that are newly pressed this frame (1=just
; pressed); also updates (DE) to this frame's raw value. --------------
SCAN_ROW_EDGES:
        LD      A,(DE)
        LD      B,A
        LD      A,(HL)
        LD      (DE),A
        CPL
        AND     B
        RET

; ---- FIND_LOWEST_BIT: A=nonzero bitmask -> A=index (0-7) of the
; lowest set bit. --------------------------------------------------
FIND_LOWEST_BIT:
        LD      B,0
FLB_LOOP:
        RRCA
        JR      C,FLB_DONE
        INC     B
        JR      FLB_LOOP
FLB_DONE:
        LD      A,B
        RET

; ---- READ_NAME_KEY: call once per frame -> A = 'A'-'Z' / 13(ENTER) /
; 8(BACKSPACE) / 0(nothing new this frame). Always uppercase, since
; that's inherent to the key position (no shift-state handling needed).
READ_NAME_KEY:
        LD      HL,NEWKEY+7
        LD      DE,PREV_ROW7
        CALL    SCAN_ROW_EDGES
        LD      (RNK_E7),A
        LD      HL,NEWKEY+2
        LD      DE,PREV_ROW2
        CALL    SCAN_ROW_EDGES
        LD      (RNK_E2),A
        LD      HL,NEWKEY+3
        LD      DE,PREV_ROW3
        CALL    SCAN_ROW_EDGES
        LD      (RNK_E3),A
        LD      HL,NEWKEY+4
        LD      DE,PREV_ROW4
        CALL    SCAN_ROW_EDGES
        LD      (RNK_E4),A
        LD      HL,NEWKEY+5
        LD      DE,PREV_ROW5
        CALL    SCAN_ROW_EDGES
        LD      (RNK_E5),A

        LD      A,(RNK_E7)
        BIT     7,A
        JR      Z,RNK_CHKBS
        LD      A,13
        RET
RNK_CHKBS:
        LD      A,(RNK_E7)
        BIT     5,A
        JR      Z,RNK_TRY2
        LD      A,8
        RET
RNK_TRY2:
        LD      A,(RNK_E2)
        AND     $C0
        JR      Z,RNK_TRY3
        CALL    FIND_LOWEST_BIT
        ADD     A,'A'-6
        RET
RNK_TRY3:
        LD      A,(RNK_E3)
        OR      A
        JR      Z,RNK_TRY4
        CALL    FIND_LOWEST_BIT
        ADD     A,'C'
        RET
RNK_TRY4:
        LD      A,(RNK_E4)
        OR      A
        JR      Z,RNK_TRY5
        CALL    FIND_LOWEST_BIT
        ADD     A,'K'
        RET
RNK_TRY5:
        LD      A,(RNK_E5)
        OR      A
        JR      Z,RNK_NONE
        CALL    FIND_LOWEST_BIT
        ADD     A,'S'
        RET
RNK_NONE:
        XOR     A
        RET
