
;; title: asset-control
;; version:
;; summary:
;; description:
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_ALREADY_SIGNED (err u101))
(define-constant ERR_NOT_ENOUGH_SIGNATURES (err u102))
(define-constant ERR_INVALID_PROPOSAL (err u103))
(define-constant ERR_PROPOSAL_EXPIRED (err u104))
(define-constant ERR_PROPOSAL_ALREADY_EXECUTED (err u105))
(define-constant ERR_PROPOSAL_NOT_FOUND (err u106))
(define-constant ERR_INVALID_THRESHOLD (err u107))
(define-constant ERR_OWNER_ALREADY_EXISTS (err u108))
(define-constant ERR_OWNER_NOT_FOUND (err u109))
(define-constant ERR_CANNOT_REMOVE_LAST_OWNER (err u110))

(define-data-var proposal-nonce uint u0)
(define-data-var signature-threshold uint u2)

(define-map owners principal bool)
(define-map proposals
  { proposal-id: uint }
  {
    creator: principal,
    receiver: principal,
    amount: uint,
    description: (string-ascii 256),
    expiration: uint,
    executed: bool
  }
)

(define-map signatures
  { proposal-id: uint, signer: principal }
  { signed: bool }
)

(define-map proposal-signature-count
  { proposal-id: uint }
  { count: uint }
)

(define-read-only (get-signature-threshold)
  (var-get signature-threshold)
)

(define-read-only (is-owner (address principal))
  (default-to false (map-get? owners address))
)

(define-read-only (get-proposal (proposal-id uint))
  (map-get? proposals { proposal-id: proposal-id })
)

(define-read-only (get-proposal-signature-count (proposal-id uint))
  (default-to { count: u0 } (map-get? proposal-signature-count { proposal-id: proposal-id }))
)

(define-read-only (has-signed (proposal-id uint) (signer principal))
  (default-to false (get signed (map-get? signatures { proposal-id: proposal-id, signer: signer })))
)

(define-read-only (get-proposal-nonce)
  (var-get proposal-nonce)
)

(define-public (add-owner (new-owner principal))
  (begin
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (is-owner new-owner)) ERR_OWNER_ALREADY_EXISTS)
    (map-set owners new-owner true)
    (ok true)
  )
)

;; (define-public (remove-owner (owner principal))
;;   (begin
;;     (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
;;     (asserts! (is-owner owner) ERR_OWNER_NOT_FOUND)
;;     (let ((owner-count (len (get-owner-list))))
;;       (asserts! (> owner-count u1) ERR_CANNOT_REMOVE_LAST_OWNER)
;;       (map-delete owners owner)
;;       (ok true)
;;     )
;;   )
;; )

;; (define-read-only (get-owner-list)
;;   (fold check-owner (map-to-list owners) (list))
;; )

(define-private (check-owner (entry {key: principal, value: bool}) (result (list 100 principal)))
  (if (get value entry)
    (unwrap-panic (as-max-len? (append result (get key entry)) u100))
    result
  )
)

(define-private (count-owners (owner principal) (count uint))
  (+ count u1)
)

;; (define-public (set-threshold (new-threshold uint))
;;   (begin
;;     (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
;;     (asserts! (> new-threshold u0) ERR_INVALID_THRESHOLD)
;;     (let ((owner-count (fold count-owners (map-keys owners) u0)))
;;       (asserts! (<= new-threshold owner-count) ERR_INVALID_THRESHOLD)
;;       (var-set signature-threshold new-threshold)
;;       (ok true)
;;     )
;;   )
;; )

(define-public (create-proposal (receiver principal) (amount uint) (description (string-ascii 256)) (expiration uint))
  (let ((proposal-id (var-get proposal-nonce)))
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (>= expiration stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (map-set proposals
      { proposal-id: proposal-id }
      {
        creator: tx-sender,
        receiver: receiver,
        amount: amount,
        description: description,
        expiration: expiration,
        executed: false
      }
    )
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: u0 }
    )
    (var-set proposal-nonce (+ proposal-id u1))
    (ok proposal-id)
  )
)

(define-public (sign-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (has-signed proposal-id tx-sender)) ERR_ALREADY_SIGNED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    
    (map-set signatures
      { proposal-id: proposal-id, signer: tx-sender }
      { signed: true }
    )
    
    (map-set proposal-signature-count
      { proposal-id: proposal-id }
      { count: (+ (get count signature-count) u1) }
    )
    
    (ok true)
  )
)

(define-public (execute-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
    (signature-count (get-proposal-signature-count proposal-id))
  )
    (asserts! (is-owner tx-sender) ERR_UNAUTHORIZED)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (>= (get expiration proposal) stacks-block-height) ERR_PROPOSAL_EXPIRED)
    (asserts! (>= (get count signature-count) (var-get signature-threshold)) ERR_NOT_ENOUGH_SIGNATURES)
    
    (map-set proposals
      { proposal-id: proposal-id }
      (merge proposal { executed: true })
    )
    
    (as-contract (stx-transfer? (get amount proposal) tx-sender (get receiver proposal)))
  )
)

(define-public (initialize (initial-owners (list 3 principal)) (threshold uint))
  (begin
    (asserts! (is-eq (len initial-owners) u3) ERR_INVALID_THRESHOLD)
    (asserts! (> threshold u0) ERR_INVALID_THRESHOLD)
    (asserts! (<= threshold u3) ERR_INVALID_THRESHOLD)
    
    (map-set owners (unwrap-panic (element-at initial-owners u0)) true)
    (map-set owners (unwrap-panic (element-at initial-owners u1)) true)
    (map-set owners (unwrap-panic (element-at initial-owners u2)) true)
    
    (var-set signature-threshold threshold)
    (ok true)
  )
)



(define-constant ERR_NOT_PROPOSAL_CREATOR (err u111))
(define-constant ERR_PROPOSAL_CANCELLED (err u112))

(define-map cancelled-proposals
  { proposal-id: uint }
  { cancelled: bool }
)

(define-read-only (is-proposal-cancelled (proposal-id uint))
  (default-to false (get cancelled (map-get? cancelled-proposals { proposal-id: proposal-id })))
)

(define-public (cancel-proposal (proposal-id uint))
  (let (
    (proposal (unwrap! (get-proposal proposal-id) ERR_PROPOSAL_NOT_FOUND))
  )
    (asserts! (is-eq tx-sender (get creator proposal)) ERR_NOT_PROPOSAL_CREATOR)
    (asserts! (not (get executed proposal)) ERR_PROPOSAL_ALREADY_EXECUTED)
    (asserts! (not (is-proposal-cancelled proposal-id)) ERR_PROPOSAL_CANCELLED)
    
    (map-set cancelled-proposals
      { proposal-id: proposal-id }
      { cancelled: true }
    )
    (ok true)
  )
)



(define-map owner-proposals
  { owner: principal }
  { proposal-ids: (list 50 uint) }
)

(define-read-only (get-owner-proposals (owner principal))
  (default-to { proposal-ids: (list) } (map-get? owner-proposals { owner: owner }))
)

(define-private (add-to-owner-history (owner principal) (proposal-id uint))
  (let (
    (current-history (get-owner-proposals owner))
  )
    (map-set owner-proposals
      { owner: owner }
      { proposal-ids: (unwrap-panic (as-max-len? (append (get proposal-ids current-history) proposal-id) u50)) }
    )
  )
)