;; Automobile Insurance Claims
;; A smart contract for processing and verifying insurance claims

;; Data maps
(define-map policies
  { policy-id: (string-ascii 20) }
  {
    owner: principal,
    vehicle-vin: (string-ascii 17),
    coverage-type: (string-ascii 50),
    coverage-limit: uint,
    deductible: uint,
    start-date: uint,
    end-date: uint,
    status: (string-ascii 10)
  }
)

(define-map claims
  { claim-id: (string-ascii 20) }
  {
    policy-id: (string-ascii 20),
    claimant: principal,
    incident-date: uint,
    description: (string-ascii 500),
    amount: uint,
    status: (string-ascii 20),
    evidence-hash: (buff 32),
    adjuster: (optional principal),
    resolution-date: (optional uint)
  }
)

(define-map insurers
  { insurer: principal }
  {
    name: (string-ascii 100),
    active: bool,
    registration-date: uint
  }
)

(define-map adjusters
  { adjuster: principal }
  {
    insurer: principal,
    active: bool,
    registration-date: uint
  }
)

;; Variables
(define-data-var admin principal tx-sender)
(define-data-var claim-counter uint u0)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-POLICY-EXISTS (err u101))
(define-constant ERR-POLICY-NOT-FOUND (err u102))
(define-constant ERR-NOT-OWNER (err u103))
(define-constant ERR-NOT-INSURER (err u104))
(define-constant ERR-NOT-ADJUSTER (err u105))
(define-constant ERR-CLAIM-NOT-FOUND (err u106))
(define-constant ERR-INVALID-STATUS (err u107))
(define-constant ERR-POLICY-EXPIRED (err u108))
(define-constant ERR-INVALID-INPUT (err u109))
(define-constant ERR-INVALID-DATE (err u110))

;; Validation helper functions
(define-private (validate-string-not-empty (input (string-ascii 500)))
  (not (is-eq input ""))
)

(define-private (validate-date (date uint))
  (< u0 date)
)

(define-private (validate-amount (amount uint))
  (< u0 amount)
)

(define-private (validate-buff-not-empty (buffer (buff 32)))
  (not (is-eq buffer 0x))
)

(define-private (validate-principal (user principal))
  ;; Principals are already validated by the Clarity type system
  ;; This is just a placeholder function to make the validation explicit
  true
)

;; Admin functions
(define-public (set-admin (new-admin principal))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-principal new-admin) ERR-INVALID-INPUT)
    (ok (var-set admin new-admin))
  )
)

;; Insurer registration with timestamp parameter
(define-public (register-insurer (name (string-ascii 100)) (timestamp uint))
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-AUTHORIZED)
    (asserts! (validate-string-not-empty name) ERR-INVALID-INPUT)
    (asserts! (validate-date timestamp) ERR-INVALID-DATE)
    
    (map-set insurers
      { insurer: tx-sender }
      {
        name: name,
        active: true,
        registration-date: timestamp
      }
    )
    (ok true)
  )
)

;; Adjuster registration with timestamp parameter
(define-public (register-adjuster (adjuster principal) (timestamp uint))
  (let (
    (insurer (unwrap! (map-get? insurers { insurer: tx-sender }) ERR-NOT-INSURER))
  )
    (asserts! (validate-principal adjuster) ERR-INVALID-INPUT)
    (asserts! (validate-date timestamp) ERR-INVALID-DATE)
    (map-set adjusters
      { adjuster: adjuster }
      {
        insurer: tx-sender,
        active: true,
        registration-date: timestamp
      }
    )
    (ok true)
  )
)

;; Policy creation
(define-public (create-policy
    (policy-id (string-ascii 20))
    (vehicle-vin (string-ascii 17))
    (coverage-type (string-ascii 50))
    (coverage-limit uint)
    (deductible uint)
    (start-date uint)
    (end-date uint)
  )
  (let ((insurer (unwrap! (map-get? insurers { insurer: tx-sender }) ERR-NOT-INSURER)))
    (asserts! (validate-string-not-empty policy-id) ERR-INVALID-INPUT)
    (asserts! (validate-string-not-empty vehicle-vin) ERR-INVALID-INPUT)
    (asserts! (validate-string-not-empty coverage-type) ERR-INVALID-INPUT)
    (asserts! (validate-amount coverage-limit) ERR-INVALID-INPUT)
    (asserts! (validate-amount deductible) ERR-INVALID-INPUT)
    (asserts! (validate-date start-date) ERR-INVALID-DATE)
    (asserts! (validate-date end-date) ERR-INVALID-DATE)
    (asserts! (< start-date end-date) ERR-INVALID-DATE)
    (asserts! (is-none (map-get? policies { policy-id: policy-id })) ERR-POLICY-EXISTS)
    
    (map-set policies
      { policy-id: policy-id }
      {
        owner: tx-sender,
        vehicle-vin: vehicle-vin,
        coverage-type: coverage-type,
        coverage-limit: coverage-limit,
        deductible: deductible,
        start-date: start-date,
        end-date: end-date,
        status: "active"
      }
    )
    
    (ok true)
  )
)

;; File claim
(define-public (file-claim
    (policy-id (string-ascii 20))
    (incident-date uint)
    (description (string-ascii 500))
    (amount uint)
    (evidence-hash (buff 32))
    (claim-id (string-ascii 20))
  )
  (let (
    (policy (unwrap! (map-get? policies { policy-id: policy-id }) ERR-POLICY-NOT-FOUND))
  )
    (asserts! (validate-string-not-empty policy-id) ERR-INVALID-INPUT)
    (asserts! (validate-string-not-empty claim-id) ERR-INVALID-INPUT)
    (asserts! (validate-string-not-empty description) ERR-INVALID-INPUT)
    (asserts! (validate-date incident-date) ERR-INVALID-DATE)
    (asserts! (validate-amount amount) ERR-INVALID-INPUT)
    (asserts! (validate-buff-not-empty evidence-hash) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status policy) "active") ERR-INVALID-STATUS)
    (asserts! (<= (get start-date policy) incident-date) ERR-INVALID-STATUS)
    (asserts! (>= (get end-date policy) incident-date) ERR-POLICY-EXPIRED)
    
    (map-set claims
      { claim-id: claim-id }
      {
        policy-id: policy-id,
        claimant: tx-sender,
        incident-date: incident-date,
        description: description,
        amount: amount,
        status: "pending",
        evidence-hash: evidence-hash,
        adjuster: none,
        resolution-date: none
      }
    )
    
    (var-set claim-counter (+ (var-get claim-counter) u1))
    
    (ok true)
  )
)

;; Assign adjuster
(define-public (assign-adjuster
    (claim-id (string-ascii 20))
    (adjuster-principal principal)
  )
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (policy (unwrap! (map-get? policies { policy-id: (get policy-id claim) }) ERR-POLICY-NOT-FOUND))
    (adjuster-info (unwrap! (map-get? adjusters { adjuster: adjuster-principal }) ERR-NOT-ADJUSTER))
  )
    (asserts! (validate-string-not-empty claim-id) ERR-INVALID-INPUT)
    (asserts! (validate-principal adjuster-principal) ERR-INVALID-INPUT)
    (asserts! (is-eq (get owner policy) tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get status claim) "pending") ERR-INVALID-STATUS)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        adjuster: (some adjuster-principal),
        status: "reviewing"
      })
    )
    
    (ok true)
  )
)

;; Process claim with timestamp parameter
(define-public (process-claim
    (claim-id (string-ascii 20))
    (approved bool)
    (approved-amount uint)
    (timestamp uint)
  )
  (let (
    (claim (unwrap! (map-get? claims { claim-id: claim-id }) ERR-CLAIM-NOT-FOUND))
    (adjuster-info (unwrap! (map-get? adjusters { adjuster: tx-sender }) ERR-NOT-ADJUSTER))
  )
    (asserts! (validate-string-not-empty claim-id) ERR-INVALID-INPUT)
    (asserts! (validate-date timestamp) ERR-INVALID-DATE)
    (asserts! (validate-amount approved-amount) ERR-INVALID-INPUT)
    (asserts! (is-eq (get status claim) "reviewing") ERR-INVALID-STATUS)
    (asserts! (is-some (get adjuster claim)) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (default-to tx-sender (get adjuster claim)) tx-sender) ERR-NOT-AUTHORIZED)
    
    (map-set claims
      { claim-id: claim-id }
      (merge claim { 
        status: (if approved "approved" "rejected"),
        amount: (if approved approved-amount (get amount claim)),
        resolution-date: (some timestamp)
      })
    )
    
    (ok true)
  )
)

;; Read-only functions
(define-read-only (get-policy (policy-id (string-ascii 20)))
  (map-get? policies { policy-id: policy-id })
)

(define-read-only (get-claim (claim-id (string-ascii 20)))
  (map-get? claims { claim-id: claim-id })
)

(define-read-only (get-insurer (insurer principal))
  (map-get? insurers { insurer: insurer })
)

(define-read-only (get-adjuster (adjuster principal))
  (map-get? adjusters { adjuster: adjuster })
)