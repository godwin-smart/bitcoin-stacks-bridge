;; Bitcoin-Stacks Bridge Contract
;; Enables secure cross-chain transfers between Bitcoin and Stacks networks

(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1002))
(define-constant ERR-INVALID-BRIDGE-STATUS (err u1003))
(define-constant ERR-INVALID-SIGNATURE (err u1004))
(define-constant ERR-ALREADY-PROCESSED (err u1005))
(define-constant ERR-BRIDGE-PAUSED (err u1006))

;; Constants
(define-constant BRIDGE-ADMIN (as-contract tx-sender))
(define-constant MIN-DEPOSIT-AMOUNT u100000) ;; 0.001 BTC in sats
(define-constant MAX-DEPOSIT-AMOUNT u1000000000) ;; 10 BTC in sats
(define-constant REQUIRED_CONFIRMATIONS u6)