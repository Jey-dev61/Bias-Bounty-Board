;; BiasBounty Board
;; Bounty platform for identifying and mitigating AI bias

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-submitted (err u202))
(define-constant err-insufficient-bounty (err u203))
(define-constant err-not-authorized (err u204))
(define-constant err-already-verified (err u205))

;; Data Variables
(define-data-var bounty-id-nonce uint u0)
(define-data-var report-id-nonce uint u0)

;; Data Maps
(define-map bounties
    uint
    {
        creator: principal,
        model-name: (string-ascii 100),
        bounty-amount: uint,
        description: (string-ascii 500),
        active: bool,
        claimed: bool
    }
)

(define-map reports
    uint
    {
        bounty-id: uint,
        reporter: principal,
        evidence: (string-ascii 500),
        votes-for: uint,
        votes-against: uint,
        verified: bool,
        timestamp: uint
    }
)

(define-map report-votes
    {report-id: uint, voter: principal}
    bool
)

;; Read-only functions
(define-read-only (get-bounty (bounty-id uint))
    (map-get? bounties bounty-id)
)

(define-read-only (get-report (report-id uint))
    (map-get? reports report-id)
)

(define-read-only (has-voted-on-report (report-id uint) (voter principal))
    (default-to false (map-get? report-votes {report-id: report-id, voter: voter}))
)

(define-read-only (get-next-bounty-id)
    (var-get bounty-id-nonce)
)

;; Public functions
;; #[allow(unchecked_data)]
(define-public (create-bounty (model-name (string-ascii 100)) (description (string-ascii 500)) (bounty-amount uint))
    (let
        ((new-id (var-get bounty-id-nonce)))
        (asserts! (>= bounty-amount u1000000) err-insufficient-bounty)
        (try! (stx-transfer? bounty-amount tx-sender (as-contract tx-sender)))
        (map-set bounties new-id
            {
                creator: tx-sender,
                model-name: model-name,
                bounty-amount: bounty-amount,
                description: description,
                active: true,
                claimed: false
            }
        )
        (var-set bounty-id-nonce (+ new-id u1))
        (ok new-id)
    )
)

;; #[allow(unchecked_data)]
(define-public (submit-report (bounty-id uint) (evidence (string-ascii 500)))
    (let
        ((bounty (unwrap! (map-get? bounties bounty-id) err-not-found))
         (new-report-id (var-get report-id-nonce)))
        (asserts! (get active bounty) err-not-found)
        (map-set reports new-report-id
            {
                bounty-id: bounty-id,
                reporter: tx-sender,
                evidence: evidence,
                votes-for: u0,
                votes-against: u0,
                verified: false,
                timestamp: stacks-block-height
            }
        )
        (var-set report-id-nonce (+ new-report-id u1))
        (ok new-report-id)
    )
)

(define-public (vote-on-report (report-id uint) (vote-for bool))
    (let
        ((report (unwrap! (map-get? reports report-id) err-not-found)))
        (asserts! (not (has-voted-on-report report-id tx-sender)) err-already-submitted)
        (asserts! (not (get verified report)) err-already-verified)
        (map-set report-votes {report-id: report-id, voter: tx-sender} true)
        (if vote-for
            (map-set reports report-id 
                (merge report {votes-for: (+ (get votes-for report) u1)}))
            (map-set reports report-id 
                (merge report {votes-against: (+ (get votes-against report) u1)}))
        )
        (ok true)
    )
)

(define-public (verify-and-pay-report (report-id uint))
    (let
        ((report (unwrap! (map-get? reports report-id) err-not-found))
         (bounty (unwrap! (map-get? bounties (get bounty-id report)) err-not-found)))
        (asserts! (is-eq tx-sender (get creator bounty)) err-not-authorized)
        (asserts! (not (get verified report)) err-already-verified)
        (asserts! (>= (get votes-for report) u3) err-not-authorized)
        (try! (as-contract (stx-transfer? (get bounty-amount bounty) tx-sender (get reporter report))))
        (map-set reports report-id (merge report {verified: true}))
        (map-set bounties (get bounty-id report) (merge bounty {claimed: true, active: false}))
        (ok true)
    )
)