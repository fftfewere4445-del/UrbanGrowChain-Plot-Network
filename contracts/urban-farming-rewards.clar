;; title: urban-farming-rewards
;; version: 1.0.0
;; summary: Token rewards for productive gardening, knowledge sharing, and community harvest contributions
;; description: A comprehensive token-based reward system that incentivizes productive gardening,
;;              knowledge sharing, community contributions, and sustainable farming practices.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-TRANSFER-FAILED (err u403))
(define-constant ERR-USER-NOT-FOUND (err u404))
(define-constant ERR-REWARD-ALREADY-CLAIMED (err u409))
(define-constant ERR-INVALID-ACTIVITY (err u410))
(define-constant ERR-COOLDOWN-ACTIVE (err u411))

;; Reward multipliers and amounts
(define-constant REWARD-PLANTING u10)
(define-constant REWARD-HARVEST u50)
(define-constant REWARD-KNOWLEDGE-SHARE u25)
(define-constant REWARD-COMMUNITY-HELP u15)
(define-constant REWARD-MILESTONE u100)
(define-constant REWARD-SEASONAL-BONUS u200)

;; Activity types
(define-constant ACTIVITY-PLANTING u1)
(define-constant ACTIVITY-HARVESTING u2)
(define-constant ACTIVITY-MAINTENANCE u3)
(define-constant ACTIVITY-KNOWLEDGE-SHARING u4)
(define-constant ACTIVITY-COMMUNITY-HELP u5)
(define-constant ACTIVITY-TEACHING u6)
(define-constant ACTIVITY-MENTORING u7)

;; Achievement levels
(define-constant LEVEL-NOVICE u1)
(define-constant LEVEL-GARDENER u2)
(define-constant LEVEL-EXPERT u3)
(define-constant LEVEL-MASTER u4)
(define-constant LEVEL-GURU u5)

;; Token properties
(define-constant TOKEN-NAME "UrbanGrow Token")
(define-constant TOKEN-SYMBOL "UGT")
(define-constant TOKEN-DECIMALS u6)
(define-constant TOTAL-SUPPLY u1000000000000) ;; 1 million tokens with 6 decimals

;; data vars
(define-data-var total-supply uint TOTAL-SUPPLY)
(define-data-var total-distributed uint u0)
(define-data-var next-reward-id uint u1)
(define-data-var reward-pool uint TOTAL-SUPPLY)
(define-data-var daily-reward-limit uint u10000) ;; 10,000 tokens per day
(define-data-var current-day uint u1)
(define-data-var daily-distributed uint u0)

;; data maps
;; User token balances
(define-map token-balances
  principal
  uint
)

;; User reward information
(define-map user-rewards
  principal
  {
    total-earned: uint,
    total-claimed: uint,
    pending-rewards: uint,
    last-claim: uint,
    activity-streak: uint,
    level: uint,
    experience-points: uint,
    multiplier: uint, ;; bonus multiplier based on level/achievements
    referral-bonus: uint
  }
)

;; Activity tracking for rewards
(define-map activity-rewards
  {user: principal, activity-type: uint, timestamp: uint}
  {
    reward-amount: uint,
    claimed: bool,
    verification-required: bool,
    verifier: (optional principal),
    bonus-multiplier: uint,
    season: uint
  }
)

;; Leaderboard and rankings
(define-map leaderboard
  uint ;; rank position
  {
    user: principal,
    total-score: uint,
    season-score: uint,
    achievements: (list 10 (string-ascii 30)),
    badge-count: uint,
    last-updated: uint
  }
)

;; Community challenges and competitions
(define-map community-challenges
  uint ;; challenge-id
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    start-block: uint,
    end-block: uint,
    reward-pool: uint,
    participants: (list 50 principal),
    winner: (optional principal),
    completion-criteria: (string-ascii 200),
    challenge-type: uint,
    status: uint ;; 1=active, 2=completed, 3=cancelled
  }
)

;; Milestone achievements
(define-map user-milestones
  {user: principal, milestone: (string-ascii 50)}
  {
    achieved: bool,
    achievement-date: uint,
    reward-claimed: bool,
    reward-amount: uint,
    verification-required: bool
  }
)

;; Referral system
(define-map referral-system
  principal ;; referrer
  {
    referred-users: (list 20 principal),
    total-referrals: uint,
    referral-rewards: uint,
    bonus-tier: uint
  }
)

;; Seasonal bonuses
(define-map seasonal-bonuses
  {user: principal, season: uint}
  {
    base-multiplier: uint,
    consistency-bonus: uint,
    community-bonus: uint,
    innovation-bonus: uint,
    total-bonus: uint,
    claimed: bool
  }
)

;; Token allowances for third-party transfers
(define-map token-allowances
  {owner: principal, spender: principal}
  uint
)

;; Reward history for transparency
(define-map reward-history
  uint ;; reward-id
  {
    recipient: principal,
    amount: uint,
    reward-type: uint,
    activity-description: (string-ascii 150),
    timestamp: uint,
    transaction-hash: (optional (buff 32))
  }
)

;; private functions
(define-private (calculate-level-multiplier (level uint))
  (if (is-eq level LEVEL-NOVICE)
    u100  ;; 1x multiplier
    (if (is-eq level LEVEL-GARDENER)
      u125  ;; 1.25x multiplier
      (if (is-eq level LEVEL-EXPERT)
        u150  ;; 1.5x multiplier
        (if (is-eq level LEVEL-MASTER)
          u200  ;; 2x multiplier
          u300  ;; 3x multiplier for GURU
        )
      )
    )
  )
)

(define-private (update-user-level (user principal))
  (let (
    (user-data (default-to
      {total-earned: u0, total-claimed: u0, pending-rewards: u0, last-claim: u0,
       activity-streak: u0, level: LEVEL-NOVICE, experience-points: u0, multiplier: u100, referral-bonus: u0}
      (map-get? user-rewards user)))
    (xp (get experience-points user-data))
  )
    (let (
      (new-level 
        (if (>= xp u10000)
          LEVEL-GURU
          (if (>= xp u5000)
            LEVEL-MASTER
            (if (>= xp u2000)
              LEVEL-EXPERT
              (if (>= xp u500)
                LEVEL-GARDENER
                LEVEL-NOVICE
              )
            )
          )
        )
      )
    )
      (map-set user-rewards user
        (merge user-data 
          {
            level: new-level,
            multiplier: (calculate-level-multiplier new-level)
          }
        )
      )
    )
  )
)

(define-private (distribute-tokens (recipient principal) (amount uint))
  (let (
    (current-balance (default-to u0 (map-get? token-balances recipient)))
    (new-balance (+ current-balance amount))
  )
    (if (> amount (var-get reward-pool))
      ERR-INSUFFICIENT-BALANCE
      (begin
        (map-set token-balances recipient new-balance)
        (var-set reward-pool (- (var-get reward-pool) amount))
        (var-set total-distributed (+ (var-get total-distributed) amount))
        (ok amount)
      )
    )
  )
)

(define-private (calculate-daily-limit-remaining)
  (let (
    (current-block-day (/ stacks-block-height u144)) ;; assuming 144 blocks per day
  )
    (if (> current-block-day (var-get current-day))
      (begin
        (var-set current-day current-block-day)
        (var-set daily-distributed u0)
        (var-get daily-reward-limit)
      )
      (- (var-get daily-reward-limit) (var-get daily-distributed))
    )
  )
)

(define-private (record-reward-transaction (recipient principal) (amount uint) (reward-type uint) (description (string-ascii 150)))
  (let (
    (reward-id (var-get next-reward-id))
  )
    (map-set reward-history reward-id
      {
        recipient: recipient,
        amount: amount,
        reward-type: reward-type,
        activity-description: description,
        timestamp: stacks-block-height,
        transaction-hash: none
      }
    )
    (var-set next-reward-id (+ reward-id u1))
  )
)

;; public functions

;; Award tokens for farming activities
(define-public (award-activity-tokens (user principal) (activity-type uint) (base-amount uint) (description (string-ascii 150)))
  (let (
    (user-data (default-to
      {total-earned: u0, total-claimed: u0, pending-rewards: u0, last-claim: u0,
       activity-streak: u0, level: LEVEL-NOVICE, experience-points: u0, multiplier: u100, referral-bonus: u0}
      (map-get? user-rewards user)))
    (multiplier (get multiplier user-data))
    (final-amount (/ (* base-amount multiplier) u100))
    (daily-remaining (calculate-daily-limit-remaining))
  )
    (if (and (is-eq tx-sender CONTRACT-OWNER)
             (>= activity-type ACTIVITY-PLANTING)
             (<= activity-type ACTIVITY-MENTORING)
             (>= final-amount u1)
             (>= daily-remaining final-amount))
      (begin
        ;; Distribute tokens
        (unwrap! (distribute-tokens user final-amount) ERR-TRANSFER-FAILED)
        ;; Update user reward data
        (map-set user-rewards user
          (merge user-data
            {
              total-earned: (+ (get total-earned user-data) final-amount),
              pending-rewards: (+ (get pending-rewards user-data) final-amount),
              experience-points: (+ (get experience-points user-data) (/ final-amount u10)),
              activity-streak: (+ (get activity-streak user-data) u1)
            }
          )
        )
        ;; Update daily distributed amount
        (var-set daily-distributed (+ (var-get daily-distributed) final-amount))
        ;; Record activity reward
        (map-set activity-rewards {user: user, activity-type: activity-type, timestamp: stacks-block-height}
          {
            reward-amount: final-amount,
            claimed: false,
            verification-required: false,
            verifier: none,
            bonus-multiplier: multiplier,
            season: u1
          }
        )
        ;; Update user level
        (update-user-level user)
        ;; Record transaction
        (record-reward-transaction user final-amount activity-type description)
        (ok final-amount)
      )
      ERR-INVALID-ACTIVITY
    )
  )
)

;; Transfer tokens between users
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (let (
    (sender-balance (default-to u0 (map-get? token-balances sender)))
  )
    (if (and (is-eq tx-sender sender)
             (>= sender-balance amount)
             (> amount u0))
      (let (
        (recipient-balance (default-to u0 (map-get? token-balances recipient)))
      )
        (map-set token-balances sender (- sender-balance amount))
        (map-set token-balances recipient (+ recipient-balance amount))
        (ok true)
      )
      ERR-INSUFFICIENT-BALANCE
    )
  )
)

;; Claim pending rewards
(define-public (claim-rewards)
  (let (
    (user-data (unwrap! (map-get? user-rewards tx-sender) ERR-USER-NOT-FOUND))
    (pending (get pending-rewards user-data))
  )
    (if (> pending u0)
      (begin
        (map-set user-rewards tx-sender
          (merge user-data
            {
              pending-rewards: u0,
              total-claimed: (+ (get total-claimed user-data) pending),
              last-claim: stacks-block-height
            }
          )
        )
        (ok pending)
      )
      (ok u0)
    )
  )
)

;; Create community challenge
(define-public (create-challenge 
  (title (string-ascii 100))
  (description (string-ascii 300))
  (duration uint)
  (reward-pool uint)
  (criteria (string-ascii 200))
  (challenge-type uint))
  
  (if (is-eq tx-sender CONTRACT-OWNER)
    (let (
      (challenge-id (var-get next-reward-id))
    )
      (map-set community-challenges challenge-id
        {
          title: title,
          description: description,
          start-block: stacks-block-height,
          end-block: (+ stacks-block-height duration),
          reward-pool: reward-pool,
          participants: (list),
          winner: none,
          completion-criteria: criteria,
          challenge-type: challenge-type,
          status: u1
        }
      )
      (var-set next-reward-id (+ challenge-id u1))
      (ok challenge-id)
    )
    ERR-UNAUTHORIZED
  )
)

;; Join community challenge
(define-public (join-challenge (challenge-id uint))
  (match (map-get? community-challenges challenge-id)
    challenge-data
    (if (and (is-eq (get status challenge-data) u1)
             (< stacks-block-height (get end-block challenge-data)))
      (let (
        (current-participants (get participants challenge-data))
      )
        (map-set community-challenges challenge-id
          (merge challenge-data
            {
              participants: (unwrap! (as-max-len? (append current-participants tx-sender) u50) current-participants)
            }
          )
        )
        (ok true)
      )
      ERR-INVALID-ACTIVITY
    )
    ERR-USER-NOT-FOUND
  )
)

;; Award milestone achievement
(define-public (award-milestone (user principal) (milestone (string-ascii 50)) (reward-amount uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (let (
      (milestone-key {user: user, milestone: milestone})
    )
      (if (is-none (map-get? user-milestones milestone-key))
        (begin
          (map-set user-milestones milestone-key
            {
              achieved: true,
              achievement-date: stacks-block-height,
              reward-claimed: false,
              reward-amount: reward-amount,
              verification-required: false
            }
          )
          (unwrap! (distribute-tokens user reward-amount) ERR-TRANSFER-FAILED)
          ;; Update user rewards
          (let (
            (user-data (default-to
              {total-earned: u0, total-claimed: u0, pending-rewards: u0, last-claim: u0,
               activity-streak: u0, level: LEVEL-NOVICE, experience-points: u0, multiplier: u100, referral-bonus: u0}
              (map-get? user-rewards user)))
          )
            (map-set user-rewards user
              (merge user-data
                {
                  total-earned: (+ (get total-earned user-data) reward-amount),
                  experience-points: (+ (get experience-points user-data) u100)
                }
              )
            )
          )
          (update-user-level user)
          (ok true)
        )
        ERR-REWARD-ALREADY-CLAIMED
      )
    )
    ERR-UNAUTHORIZED
  )
)

;; Process referral reward
(define-public (process-referral-reward (referrer principal) (new-user principal))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (let (
      (referral-data (default-to
        {referred-users: (list), total-referrals: u0, referral-rewards: u0, bonus-tier: u1}
        (map-get? referral-system referrer)))
      (referral-reward u50) ;; 50 tokens for referral
    )
      (map-set referral-system referrer
        (merge referral-data
          {
            referred-users: (unwrap! (as-max-len? (append (get referred-users referral-data) new-user) u20) (get referred-users referral-data)),
            total-referrals: (+ (get total-referrals referral-data) u1),
            referral-rewards: (+ (get referral-rewards referral-data) referral-reward)
          }
        )
      )
      (unwrap! (distribute-tokens referrer referral-reward) ERR-TRANSFER-FAILED)
      (ok referral-reward)
    )
    ERR-UNAUTHORIZED
  )
)

;; Update leaderboard
(define-public (update-leaderboard (user principal) (rank uint) (total-score uint) (season-score uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (map-set leaderboard rank
        {
          user: user,
          total-score: total-score,
          season-score: season-score,
          achievements: (list),
          badge-count: u0,
          last-updated: stacks-block-height
        }
      )
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Admin function to mint additional tokens
(define-public (mint-tokens (amount uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (var-set total-supply (+ (var-get total-supply) amount))
      (var-set reward-pool (+ (var-get reward-pool) amount))
      (ok amount)
    )
    ERR-UNAUTHORIZED
  )
)

;; read only functions

;; Get token balance
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? token-balances user))
)

;; Get user reward information
(define-read-only (get-user-reward-info (user principal))
  (map-get? user-rewards user)
)

;; Get activity reward details
(define-read-only (get-activity-reward (user principal) (activity-type uint) (timestamp uint))
  (map-get? activity-rewards {user: user, activity-type: activity-type, timestamp: timestamp})
)

;; Get leaderboard entry
(define-read-only (get-leaderboard-entry (rank uint))
  (map-get? leaderboard rank)
)

;; Get community challenge
(define-read-only (get-community-challenge (challenge-id uint))
  (map-get? community-challenges challenge-id)
)

;; Get milestone achievement
(define-read-only (get-milestone (user principal) (milestone (string-ascii 50)))
  (map-get? user-milestones {user: user, milestone: milestone})
)

;; Get referral information
(define-read-only (get-referral-info (user principal))
  (map-get? referral-system user)
)

;; Get seasonal bonus
(define-read-only (get-seasonal-bonus (user principal) (season uint))
  (map-get? seasonal-bonuses {user: user, season: season})
)

;; Get reward history
(define-read-only (get-reward-history (reward-id uint))
  (map-get? reward-history reward-id)
)

;; Get total supply
(define-read-only (get-total-supply)
  (var-get total-supply)
)

;; Get remaining reward pool
(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

;; Get total distributed tokens
(define-read-only (get-total-distributed)
  (var-get total-distributed)
)

;; Get daily reward limit
(define-read-only (get-daily-reward-limit)
  (var-get daily-reward-limit)
)

;; Get token allowance
(define-read-only (get-allowance (owner principal) (spender principal))
  (default-to u0 (map-get? token-allowances {owner: owner, spender: spender}))
)

