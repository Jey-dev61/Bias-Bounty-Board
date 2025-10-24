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

;; Function 1: Cancel bounty (only by creator if not claimed)
(define-public (cancel-bounty (bounty-id uint))
    (let
        ((bounty (unwrap! (map-get? bounties bounty-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator bounty)) err-not-authorized)
        (asserts! (not (get claimed bounty)) err-already-verified)
        (try! (as-contract (stx-transfer? (get bounty-amount bounty) tx-sender (get creator bounty))))
        (map-set bounties bounty-id (merge bounty {active: false}))
        (ok true)
    )
)

;; Function 2: Update bounty amount (increase only)
(define-public (increase-bounty-amount (bounty-id uint) (additional-amount uint))
    (let
        ((bounty (unwrap! (map-get? bounties bounty-id) err-not-found)))
        (asserts! (is-eq tx-sender (get creator bounty)) err-not-authorized)
        (asserts! (get active bounty) err-not-found)
        (asserts! (>= additional-amount u100000) err-insufficient-bounty)
        (try! (stx-transfer? additional-amount tx-sender (as-contract tx-sender)))
        (map-set bounties bounty-id 
            (merge bounty {bounty-amount: (+ (get bounty-amount bounty) additional-amount)}))
        (ok true)
    )
)

;; Function 3: Get total number of reports for a bounty
(define-read-only (get-bounty-report-count (bounty-id uint))
    (let
        ((total-reports (var-get report-id-nonce)))
        (ok (fold count-reports-for-bounty (list total-reports) bounty-id))
    )
)

;; Function 4: Get report vote ratio
(define-read-only (get-report-vote-ratio (report-id uint))
    (let
        ((report (unwrap! (map-get? reports report-id) err-not-found))
         (total-votes (+ (get votes-for report) (get votes-against report))))
        (if (> total-votes u0)
            (ok (/ (* (get votes-for report) u100) total-votes))
            (ok u0)
        )
    )
)

;; Function 5: Check if bounty is claimable (has valid reports)
(define-read-only (is-bounty-claimable (bounty-id uint))
    (let
        ((bounty (unwrap! (map-get? bounties bounty-id) err-not-found)))
        (ok (and (get active bounty) (not (get claimed bounty))))
    )
)

;; Function 6: Withdraw report (by reporter before verification)
(define-public (withdraw-report (report-id uint))
    (let
        ((report (unwrap! (map-get? reports report-id) err-not-found)))
        (asserts! (is-eq tx-sender (get reporter report)) err-not-authorized)
        (asserts! (not (get verified report)) err-already-verified)
        (asserts! (is-eq (get votes-for report) u0) err-not-authorized)
        (map-delete reports report-id)
        (ok true)
    )
)

;; Function 7: Get all active bounties count
(define-read-only (get-active-bounty-count)
    (ok (var-get bounty-id-nonce))
)

;; Function 8: Get report details with bounty info
(define-read-only (get-report-with-bounty (report-id uint))
    (let
        ((report (unwrap! (map-get? reports report-id) err-not-found))
         (bounty (unwrap! (map-get? bounties (get bounty-id report)) err-not-found)))
        (ok {
            report: report,
            bounty-amount: (get bounty-amount bounty),
            model-name: (get model-name bounty)
        })
    )
)

;; Function 9: Bulk vote verification check
(define-read-only (check-multiple-votes (report-id uint) (voters (list 10 principal)))
    (ok (map check-voter-status (list {rid: report-id, voter: (unwrap-panic (element-at voters u0))}
                                       {rid: report-id, voter: (unwrap-panic (element-at voters u1))})))
)

;; Function 10: Get total bounty pool value
(define-read-only (get-total-bounty-pool)
    (ok (stx-get-balance (as-contract tx-sender)))
)

;; Helper function for vote checking
(define-private (check-voter-status (input {rid: uint, voter: principal}))
    (has-voted-on-report (get rid input) (get voter input))
)

;; Helper function for counting reports
(define-private (count-reports-for-bounty (report-id uint) (target-bounty-id uint))
    (let
        ((report-opt (map-get? reports report-id)))
        (if (is-some report-opt)
            (if (is-eq (get bounty-id (unwrap-panic report-opt)) target-bounty-id)
                u1
                u0
            )
            u0
        )
    )
)