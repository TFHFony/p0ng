; ============================================================
; P0NG  --  sound.asm
; Minimal one-shot PSG bleeps (channel A only): paddle hit, wall,
; point scored, life-lost, game-over. Non-blocking - SOUND_UPDATE
; is called once per frame from the main loop and silences the
; channel when the current bleep's duration runs out.
; ============================================================

; each entry: periodLo, periodHi, duration(frames), volume(0-15)
SOUND_TBL:
        DB      60,0,4,12       ; SND_HIT
        DB      110,0,3,10      ; SND_WALL
        DB      30,0,8,12       ; SND_SCORE
        DB      200,1,20,14     ; SND_LIFE
        DB      240,2,40,14     ; SND_GAMEOVER

SOUND_INIT:
        CALL    GICINI
        XOR     A
        LD      (SND_TIMER),A
        LD      A,7
        LD      E,$BE           ; mixer: channel-A tone only, everything else off;
                                 ; bit7=1/bit6=0 keeps I/O port A as INPUT and port
                                 ; B as OUTPUT (the standard MSX-safe direction -
                                 ; forcing port A to output, as $FE did, risks a
                                 ; real hardware conflict with joystick/keyboard
                                 ; wiring on that port)
        CALL    WRTPSG
        LD      A,8
        LD      E,0
        JP      WRTPSG

; ---- SOUND_PLAY: A = SND_xxx id -------------------------------------
SOUND_PLAY:
        LD      L,A
        LD      H,0
        ADD     HL,HL
        ADD     HL,HL
        LD      DE,SOUND_TBL
        ADD     HL,DE

        LD      A,(HL)
        LD      B,A             ; periodLo
        INC     HL
        LD      A,(HL)
        LD      C,A             ; periodHi
        INC     HL
        LD      A,(HL)
        LD      (SND_TIMER),A
        INC     HL
        LD      A,(HL)
        LD      (SND_VOL),A

        LD      A,0
        LD      E,B
        CALL    WRTPSG
        LD      A,1
        LD      E,C
        CALL    WRTPSG
        LD      A,(SND_VOL)
        LD      E,A
        LD      A,8
        JP      WRTPSG

; ---- SOUND_UPDATE: call once per frame -------------------------------
SOUND_UPDATE:
        LD      A,(SND_TIMER)
        OR      A
        RET     Z
        DEC     A
        LD      (SND_TIMER),A
        RET     NZ
        LD      A,8
        LD      E,0
        JP      WRTPSG
