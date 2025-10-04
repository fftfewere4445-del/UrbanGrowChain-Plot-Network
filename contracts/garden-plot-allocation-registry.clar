;; title: garden-plot-allocation-registry
;; version: 1.0.0
;; summary: Allocate urban garden plots fairly with waiting lists and seasonal usage tracking
;; description: A comprehensive system for managing urban garden plot allocation with transparent waiting lists, 
;;              seasonal tracking, and fair distribution algorithms.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-PLOT-NOT-FOUND (err u404))
(define-constant ERR-PLOT-ALREADY-ALLOCATED (err u409))
(define-constant ERR-INVALID-SEASON (err u400))
(define-constant ERR-ALREADY-ON-WAITLIST (err u410))
(define-constant ERR-NOT-ON-WAITLIST (err u411))
(define-constant ERR-PLOT-NOT-ALLOCATED (err u412))
(define-constant MAX-PLOTS u100)
(define-constant SEASONS-PER-YEAR u4)

;; data vars
(define-data-var next-plot-id uint u1)
(define-data-var current-season uint u1)
(define-data-var total-plots uint u0)
(define-data-var waiting-list-size uint u0)

;; data maps
;; Plot information
(define-map plots
  uint ;; plot-id
  {
    size: uint,           ;; plot size in square meters
    location: (string-ascii 100),
    soil-type: (string-ascii 50),
    allocated: bool,
    current-user: (optional principal),
    season-allocated: uint,
    total-harvests: uint,
    last-activity: uint
  }
)

;; User allocations
(define-map user-plots
  principal ;; user
  {
    current-plot: (optional uint),
    total-seasons: uint,
    total-harvests: uint,
    reputation-score: uint,
    last-allocation: uint
  }
)

;; Waiting list
(define-map waiting-list
  uint ;; position
  {
    user: principal,
    requested-size: uint,
    priority-score: uint,
    join-time: uint
  }
)

;; Plot history tracking
(define-map plot-history
  {plot-id: uint, season: uint}
  {
    user: principal,
    start-block: uint,
    end-block: uint,
    harvest-count: uint,
    maintenance-score: uint
  }
)

;; Season statistics
(define-map season-stats
  uint ;; season
  {
    total-allocated: uint,
    total-harvests: uint,
    average-yield: uint,
    active-users: uint
  }
)

;; private functions
(define-private (calculate-priority-score (user principal))
  (let (
    (user-data (default-to {current-plot: none, total-seasons: u0, total-harvests: u0, reputation-score: u0, last-allocation: u0}
                           (map-get? user-plots user)))
  )
    (+ (get total-seasons user-data)
       (/ (get total-harvests user-data) u2)
       (get reputation-score user-data))
  )
)

(define-private (find-best-plot (min-size uint))
  (let (
    (plot-id u1) ;; simplified - in production would iterate through available plots
  )
    (if (is-some (get-plot-info plot-id))
      (some plot-id)
      none
    )
  )
)

(define-private (update-season-stats (season uint) (allocated-count uint) (harvest-count uint))
  (let (
    (current-stats (default-to {total-allocated: u0, total-harvests: u0, average-yield: u0, active-users: u0}
                               (map-get? season-stats season)))
  )
    (map-set season-stats season
      {
        total-allocated: (+ (get total-allocated current-stats) allocated-count),
        total-harvests: (+ (get total-harvests current-stats) harvest-count),
        average-yield: u0, ;; simplified calculation
        active-users: (+ (get active-users current-stats) u1)
      }
    )
  )
)

(define-private (remove-from-waiting-list (position uint))
  (begin
    (map-delete waiting-list position)
    (var-set waiting-list-size (- (var-get waiting-list-size) u1))
    true
  )
)

(define-private (check-waiting-list (position uint) (result (optional uint)))
  (if (is-some result)
    result
    (match (map-get? waiting-list position)
      entry (if (is-eq (get user entry) tx-sender) (some position) none)
      none
    )
  )
)

;; public functions

;; Create a new garden plot
(define-public (create-plot (size uint) (location (string-ascii 100)) (soil-type (string-ascii 50)))
  (let (
    (plot-id (var-get next-plot-id))
  )
    (if (is-eq tx-sender CONTRACT-OWNER)
      (begin
        (map-set plots plot-id
          {
            size: size,
            location: location,
            soil-type: soil-type,
            allocated: false,
            current-user: none,
            season-allocated: u0,
            total-harvests: u0,
            last-activity: stacks-stacks-block-height
          }
        )
        (var-set next-plot-id (+ plot-id u1))
        (var-set total-plots (+ (var-get total-plots) u1))
        (ok plot-id)
      )
      ERR-UNAUTHORIZED
    )
  )
)

;; Allocate a plot to a user
(define-public (allocate-plot (plot-id uint) (user principal))
  (let (
    (plot-info (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-season (var-get current-season))
  )
    (if (and (is-eq tx-sender CONTRACT-OWNER)
             (not (get allocated plot-info)))
      (begin
        ;; Update plot information
        (map-set plots plot-id
          (merge plot-info
            {
              allocated: true,
              current-user: (some user),
              season-allocated: current-season,
              last-activity: stacks-stacks-block-height
            }
          )
        )
        ;; Update user information
        (let (
          (user-data (default-to {current-plot: none, total-seasons: u0, total-harvests: u0, reputation-score: u0, last-allocation: u0}
                                 (map-get? user-plots user)))
        )
          (map-set user-plots user
            (merge user-data
              {
                current-plot: (some plot-id),
                total-seasons: (+ (get total-seasons user-data) u1),
                last-allocation: current-season
              }
            )
          )
        )
        ;; Record plot history
        (map-set plot-history {plot-id: plot-id, season: current-season}
          {
            user: user,
            start-block: stacks-stacks-block-height,
            end-block: u0,
            harvest-count: u0,
            maintenance-score: u0
          }
        )
        ;; Update season statistics
        (update-season-stats current-season u1 u0)
        (ok true)
      )
      ERR-PLOT-ALREADY-ALLOCATED
    )
  )
)

;; Release a plot back to the system
(define-public (release-plot (plot-id uint))
  (let (
    (plot-info (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-user (unwrap! (get current-user plot-info) ERR-PLOT-NOT-ALLOCATED))
    (current-season (var-get current-season))
  )
    (if (or (is-eq tx-sender current-user)
            (is-eq tx-sender CONTRACT-OWNER))
      (begin
        ;; Update plot information
        (map-set plots plot-id
          (merge plot-info
            {
              allocated: false,
              current-user: none,
              last-activity: stacks-stacks-block-height
            }
          )
        )
        ;; Update user information
        (let (
          (user-data (unwrap! (map-get? user-plots current-user) ERR-PLOT-NOT-FOUND))
        )
          (map-set user-plots current-user
            (merge user-data
              {
                current-plot: none
              }
            )
          )
        )
        ;; Update plot history
        (map-set plot-history {plot-id: plot-id, season: (get season-allocated plot-info)}
          (merge
            (unwrap! (map-get? plot-history {plot-id: plot-id, season: (get season-allocated plot-info)})
                     {user: current-user, start-block: stacks-stacks-block-height, end-block: u0, harvest-count: u0, maintenance-score: u0})
            {end-block: stacks-stacks-block-height}
          )
        )
        (ok true)
      )
      ERR-UNAUTHORIZED
    )
  )
)

;; Join waiting list for plot allocation
(define-public (join-waiting-list (requested-size uint))
  (let (
    (user tx-sender)
    (position (+ (var-get waiting-list-size) u1))
    (priority (calculate-priority-score user))
  )
    ;; Check if user is already on waiting list
    (if (is-none (get-waiting-list-position user))
      (begin
        (map-set waiting-list position
          {
            user: user,
            requested-size: requested-size,
            priority-score: priority,
            join-time: stacks-stacks-block-height
          }
        )
        (var-set waiting-list-size position)
        (ok position)
      )
      ERR-ALREADY-ON-WAITLIST
    )
  )
)

;; Leave waiting list
(define-public (leave-waiting-list)
  (let (
    (user tx-sender)
    (position (unwrap! (get-waiting-list-position user) ERR-NOT-ON-WAITLIST))
  )
    (remove-from-waiting-list position)
    (ok true)
  )
)

;; Update season (admin only)
(define-public (update-season (new-season uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (var-set current-season new-season)
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Update user reputation score
(define-public (update-reputation (user principal) (score uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (let (
      (user-data (default-to {current-plot: none, total-seasons: u0, total-harvests: u0, reputation-score: u0, last-allocation: u0}
                             (map-get? user-plots user)))
    )
      (map-set user-plots user
        (merge user-data {reputation-score: score})
      )
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Record harvest activity
(define-public (record-harvest (plot-id uint))
  (let (
    (plot-info (unwrap! (map-get? plots plot-id) ERR-PLOT-NOT-FOUND))
    (current-user (unwrap! (get current-user plot-info) ERR-PLOT-NOT-ALLOCATED))
    (current-season (var-get current-season))
  )
    (if (is-eq tx-sender current-user)
      (begin
        ;; Update plot harvest count
        (map-set plots plot-id
          (merge plot-info
            {
              total-harvests: (+ (get total-harvests plot-info) u1),
              last-activity: stacks-stacks-block-height
            }
          )
        )
        ;; Update user harvest count
        (let (
          (user-data (unwrap! (map-get? user-plots current-user) ERR-PLOT-NOT-FOUND))
        )
          (map-set user-plots current-user
            (merge user-data
              {
                total-harvests: (+ (get total-harvests user-data) u1)
              }
            )
          )
        )
        ;; Update plot history
        (let (
          (history-key {plot-id: plot-id, season: (get season-allocated plot-info)})
          (history-data (unwrap! (map-get? plot-history history-key) ERR-PLOT-NOT-FOUND))
        )
          (map-set plot-history history-key
            (merge history-data
              {
                harvest-count: (+ (get harvest-count history-data) u1)
              }
            )
          )
        )
        ;; Update season statistics
        (update-season-stats current-season u0 u1)
        (ok true)
      )
      ERR-UNAUTHORIZED
    )
  )
)

;; read only functions

;; Get plot information
(define-read-only (get-plot-info (plot-id uint))
  (map-get? plots plot-id)
)

;; Get user information
(define-read-only (get-user-info (user principal))
  (map-get? user-plots user)
)

;; Get waiting list position for user
(define-read-only (get-waiting-list-position (user principal))
  (fold check-waiting-list (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) none) ;; simplified for demo
)

;; Get waiting list entry
(define-read-only (get-waiting-list-entry (position uint))
  (map-get? waiting-list position)
)

;; Get current season
(define-read-only (get-current-season)
  (var-get current-season)
)

;; Get total plots
(define-read-only (get-total-plots)
  (var-get total-plots)
)

;; Get plot history
(define-read-only (get-plot-history (plot-id uint) (season uint))
  (map-get? plot-history {plot-id: plot-id, season: season})
)

;; Get season statistics
(define-read-only (get-season-stats (season uint))
  (map-get? season-stats season)
)

;; Get waiting list size
(define-read-only (get-waiting-list-size)
  (var-get waiting-list-size)
)

