; ============================================================
; P0NG  --  charset.asm
; Custom 8x8 character bitmaps (only the top 6 bits of each row
; byte are visible in SCREEN 0 WIDTH 40 - the bottom 2 bits are
; the inter-character gap and are always left clear).
; Order here must match LOAD_CHARSET in vdp.asm (codes 1..4).
; ============================================================

CHARSET_DATA:
; --- T_RING: the oval "0", one row taller than c0man's so it matches the caps ---
        DB      %00000000
        DB      %01110000
        DB      %10001000
        DB      %10001000
        DB      %10001000
        DB      %10001000
        DB      %10001000
        DB      %01110000

; --- T_BALL ---
        DB      %00000000
        DB      %00000000
        DB      %00110000
        DB      %01111000
        DB      %01111000
        DB      %00110000
        DB      %00000000
        DB      %00000000

; --- T_PAD: full-height bar, stacks into a solid paddle ---
        DB      %01111000
        DB      %01111000
        DB      %01111000
        DB      %01111000
        DB      %01111000
        DB      %01111000
        DB      %01111000
        DB      %01111000

; --- T_NET: dash, half a cell tall ---
        DB      %00110000
        DB      %00110000
        DB      %00110000
        DB      %00110000
        DB      %00000000
        DB      %00000000
        DB      %00000000
        DB      %00000000
