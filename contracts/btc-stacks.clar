;; Bitcoin-Stacks Bridge Contract
;; Enables secure cross-chain transfers between Bitcoin and Stacks networks

;; Define trait for future token compatibility
(define-trait bridgeable-token-trait
    (
        (transfer (uint principal principal) (response bool uint))
        (get-balance (principal) (response uint uint))
    )
)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-INVALID-AMOUNT (err u1001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1002))
(define-constant ERR-INVALID-BRIDGE-STATUS (err u1003))
(define-constant ERR-INVALID-SIGNATURE (err u1004))
(define-constant ERR-ALREADY-PROCESSED (err u1005))
(define-constant ERR-BRIDGE-PAUSED (err u1006))
(define-constant ERR-INVALID-VALIDATOR-ADDRESS (err u1007))
(define-constant ERR-INVALID-RECIPIENT-ADDRESS (err u1008))
(define-constant ERR-INVALID-BTC-ADDRESS (err u1009))
(define-constant ERR-INVALID-TX-HASH (err u1010))
(define-constant ERR-INVALID-SIGNATURE-FORMAT (err u1011))


;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MIN-DEPOSIT-AMOUNT u100000) ;; 0.001 BTC in sats
(define-constant MAX-DEPOSIT-AMOUNT u1000000000) ;; 10 BTC in sats
(define-constant REQUIRED-CONFIRMATIONS u6)

;; Data variables
(define-data-var bridge-paused bool false)
(define-data-var total-bridged-amount uint u0)
(define-data-var last-processed-height uint u0)

;; Data maps
(define-map deposits 
    { tx-hash: (buff 32) }
    {
        amount: uint,
        recipient: principal,
        processed: bool,
        confirmations: uint,
        timestamp: uint,
        btc-sender: (buff 33)
    }
)

(define-map validators principal bool)
(define-map validator-signatures
    { tx-hash: (buff 32), validator: principal }
    { signature: (buff 65), timestamp: uint }
)

(define-map bridge-balances principal uint)

;; Read-only functions
(define-read-only (get-deposit (tx-hash (buff 32)))
    (map-get? deposits {tx-hash: tx-hash})
)

(define-read-only (get-bridge-status)
    (var-get bridge-paused)
)

(define-read-only (get-validator-status (validator principal))
    (default-to false (map-get? validators validator))
)

(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? bridge-balances user))
)

(define-read-only (verify-signature (tx-hash (buff 32)) (validator principal) (signature (buff 65)))
    (let (
        (stored-sig (map-get? validator-signatures {tx-hash: tx-hash, validator: validator}))
    )
        (and 
            (is-some stored-sig)
            (is-eq signature (get signature (unwrap-panic stored-sig)))
        )
    )
)

;; Private functions

;; Helper functions for input validation
(define-private (is-valid-principal (address principal))
    (and 
        (is-ok (principal-destruct? address))
        (not (is-eq address CONTRACT-OWNER))  ;; Prevent targeting contract owner
        (not (is-eq address (as-contract tx-sender)))  ;; Prevent targeting contract itself
    )
)

(define-private (is-valid-btc-address (btc-addr (buff 33)))
    (and
        (is-eq (len btc-addr) u33)  ;; Check length is exactly 33 bytes
        (not (is-eq btc-addr 0x000000000000000000000000000000000000000000000000000000000000000000))  ;; Not zero address
        ;; Add additional BTC address format validation if needed
        true
    )
)

(define-private (is-valid-tx-hash (tx-hash (buff 32)))
    (and
        (is-eq (len tx-hash) u32)  ;; Verify length is exactly 32 bytes
        (not (is-eq tx-hash 0x0000000000000000000000000000000000000000000000000000000000000000))  ;; Not zero hash
        true
    )
)

(define-private (is-valid-signature (signature (buff 65)))
    (and
        (is-eq (len signature) u65)  ;; Verify length is exactly 65 bytes
        (not (is-eq signature 0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000))  ;; Not zero signature
        ;; Add additional signature format validation if needed
        true
    )
)

(define-private (validate-deposit-amount (amount uint))
    (and 
        (>= amount MIN-DEPOSIT-AMOUNT)
        (<= amount MAX-DEPOSIT-AMOUNT)
    )
)

(define-private (update-deposit-confirmations (tx-hash (buff 32)) (new-confirmations uint))
    (let (
        (deposit (unwrap! (map-get? deposits {tx-hash: tx-hash}) ERR-INVALID-BRIDGE-STATUS))
    )
        (map-set deposits
            {tx-hash: tx-hash}
            (merge deposit {confirmations: new-confirmations})
        )
        (ok true)
    )
)

;; Public functions
(define-public (initialize-bridge)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set bridge-paused false)
        (ok true)
    )
)

(define-public (pause-bridge)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set bridge-paused true)
        (ok true)
    )
)

(define-public (resume-bridge)
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (var-get bridge-paused) ERR-INVALID-BRIDGE-STATUS)
        (var-set bridge-paused false)
        (ok true)
    )
)

;; Updated public functions with input validation

(define-public (add-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-principal validator) ERR-INVALID-VALIDATOR-ADDRESS)
        (map-set validators validator true)
        (ok true)
    )
)

(define-public (remove-validator (validator principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-principal validator) ERR-INVALID-VALIDATOR-ADDRESS)
        (map-set validators validator false)  ;; Use false instead of delete for audit trail
        (ok true)
    )
)

(define-public (initiate-deposit 
    (tx-hash (buff 32)) 
    (amount uint) 
    (recipient principal)
    (btc-sender (buff 33))
)
    (begin
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (validate-deposit-amount amount) ERR-INVALID-AMOUNT)
        (asserts! (unwrap! (map-get? validators tx-sender) ERR-NOT-AUTHORIZED) ERR-NOT-AUTHORIZED)
        (asserts! (is-valid-tx-hash tx-hash) ERR-INVALID-TX-HASH)
        (asserts! (is-none (map-get? deposits {tx-hash: tx-hash})) ERR-ALREADY-PROCESSED)
        (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT-ADDRESS)
        (asserts! (is-valid-btc-address btc-sender) ERR-INVALID-BTC-ADDRESS)
        
        (let
            ((validated-deposit {
                amount: amount,
                recipient: recipient,
                processed: false,
                confirmations: u0,
                timestamp: block-height,
                btc-sender: btc-sender
            }))
            
            (map-set deposits
                {tx-hash: tx-hash}
                validated-deposit
            )
            (ok true)
        )
    )
)

(define-public (confirm-deposit 
    (tx-hash (buff 32))
    (signature (buff 65))
)
    (let (
        (deposit (unwrap! (map-get? deposits {tx-hash: tx-hash}) ERR-INVALID-BRIDGE-STATUS))
        (is-validator (unwrap! (map-get? validators tx-sender) ERR-NOT-AUTHORIZED))
    )
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (is-valid-tx-hash tx-hash) ERR-INVALID-TX-HASH)
        (asserts! (is-valid-signature signature) ERR-INVALID-SIGNATURE-FORMAT)
        (asserts! (not (get processed deposit)) ERR-ALREADY-PROCESSED)
        (asserts! (>= (get confirmations deposit) REQUIRED-CONFIRMATIONS) ERR-INVALID-BRIDGE-STATUS)
        
        ;; Store validator signature with additional checks
        (asserts! 
            (is-none (map-get? validator-signatures {tx-hash: tx-hash, validator: tx-sender}))
            ERR-ALREADY-PROCESSED
        )
        
        (let
            ((validated-signature {
                signature: signature,
                timestamp: block-height
            }))
            
            (map-set validator-signatures
                {tx-hash: tx-hash, validator: tx-sender}
                validated-signature
            )
            
            ;; Update deposit status and bridge balances with safe arithmetic
            (map-set deposits
                {tx-hash: tx-hash}
                (merge deposit {processed: true})
            )
            
            (map-set bridge-balances
                (get recipient deposit)
                (+ (default-to u0 (map-get? bridge-balances (get recipient deposit))) 
                   (get amount deposit))
            )
            
            (var-set total-bridged-amount 
                (+ (var-get total-bridged-amount) (get amount deposit))
            )
            (ok true)
        )
    )
)


(define-public (withdraw 
    (amount uint)
    (btc-recipient (buff 34))
)
    (let (
        (current-balance (get-balance tx-sender))
    )
        (asserts! (not (var-get bridge-paused)) ERR-BRIDGE-PAUSED)
        (asserts! (>= current-balance amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (validate-deposit-amount amount) ERR-INVALID-AMOUNT)
        
        ;; Update user balance
        (map-set bridge-balances
            tx-sender
            (- current-balance amount)
        )
        
        ;; Emit withdrawal event for off-chain processing
        (print {
            type: "withdraw",
            sender: tx-sender,
            amount: amount,
            btc-recipient: btc-recipient,
            timestamp: block-height
        })
        
        (var-set total-bridged-amount (- (var-get total-bridged-amount) amount))
        (ok true)
    )
)

;; Emergency functions
(define-public (emergency-withdraw (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (>= (var-get total-bridged-amount) amount) ERR-INSUFFICIENT-BALANCE)
        (asserts! (is-valid-principal recipient) ERR-INVALID-RECIPIENT-ADDRESS)
        
        ;; Safe arithmetic for balance updates
        (let (
            (current-balance (default-to u0 (map-get? bridge-balances recipient)))
            (new-balance (+ current-balance amount))
        )
            (asserts! (> new-balance current-balance) ERR-INVALID-AMOUNT)  ;; Overflow check
            (map-set bridge-balances recipient new-balance)
            (ok true)
        )
    )
)