; fpga-material.asm — minimal material evaluation kernel for fpga-lisp ISA 1.1
; Input: R0 = list of piece symbols (e.g., (wp bp wp))
; Output: R15 = fixnum material sum (centipawns)
; Only handles wp=100 and bp=-100 for this minimal kernel
;
; Registers:
;   R0 = input list (list of piece symbols)
;   R1 = accumulator (starts at 0)
;   R2 = current piece (CAR)
;   R3 = tag / comparison result
;   R4 = 'wp symbol (loaded via LOADSYM)
;   R5 = 100 (fixnum, loaded via LOADI)
;   R6 = 'bp symbol (loaded via LOADSYM)
;   R11 = NIL (initialized to NIL)
;   R15 = value register (result)

; Boot initialization via extended header:
; R0 = input list (provided by test harness)
; R1 = 0 (accumulator)
; R4 = 'wp symbol (id from symbol table)
; R5 = 100 (fixnum)
; R6 = 'bp symbol (id from symbol table)
; R11 = NIL

.include "fpga/asm/constants.inc"

; ---------------------------------------------------------------------
; Program start
; ---------------------------------------------------------------------

LOOP_START:
  ; Check if list is NIL: get tag of R0
  ; GETTAG R3, R0  (MOV with rs2=1)
  MOV R3, R0, 1
  LOADI R2, 3
  EQ R3, R3, R2
  JF DONE, R3

  ; R0 is a cons cell, get CAR (piece symbol)
  CAR R2, R0

  ; Compare piece with 'wp (in R4 - loaded via LOADSYM at boot)
  EQ R3, R2, R4
  JF CHECK_BP, R3

  ; Is wp: add 100 (R5)
  ADD R1, R1, R5
  JMP NEXT_PIECE

CHECK_BP:
  ; Compare piece with 'bp
  EQ R3, R2, R6
  JF NEXT_PIECE, R3

  ; Is bp: add -100 (subtract R5)
  SUB R1, R1, R5

NEXT_PIECE:
  ; Move to rest of list
  CDR R0, R0
  JMP LOOP_START

DONE:
  ; Result in R1, move to R15 (value register)
  MOV R15, R1
  HALT