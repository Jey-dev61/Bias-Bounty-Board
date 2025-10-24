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
