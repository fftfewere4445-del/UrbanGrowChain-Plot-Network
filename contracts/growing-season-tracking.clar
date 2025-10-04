;; title: growing-season-tracking
;; version: 1.0.0
;; summary: Track planting schedules, growth progress, and harvest yields across community gardens
;; description: Comprehensive system for monitoring plant growth cycles, scheduling activities,
;;              and tracking harvest yields with automated progress updates.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-PLANT-NOT-FOUND (err u404))
(define-constant ERR-INVALID-STAGE (err u400))
(define-constant ERR-ALREADY-PLANTED (err u409))
(define-constant ERR-NOT-READY-FOR-HARVEST (err u410))
(define-constant ERR-INVALID-YIELD (err u411))
(define-constant ERR-SEASON-NOT-FOUND (err u412))

;; Growth stage constants
(define-constant STAGE-PLANTED u1)
(define-constant STAGE-GERMINATED u2)
(define-constant STAGE-SEEDLING u3)
(define-constant STAGE-VEGETATIVE u4)
(define-constant STAGE-FLOWERING u5)
(define-constant STAGE-FRUITING u6)
(define-constant STAGE-MATURE u7)
(define-constant STAGE-HARVESTED u8)

;; data vars
(define-data-var next-planting-id uint u1)
(define-data-var current-growing-season uint u1)
(define-data-var total-plantings uint u0)
(define-data-var total-yield-recorded uint u0)

;; data maps
;; Plant varieties and their characteristics
(define-map plant-varieties
  (string-ascii 50) ;; variety name
  {
    growing-days: uint,         ;; days from planting to harvest
    optimal-temperature: uint,   ;; optimal temperature in celsius
    water-frequency: uint,       ;; watering frequency in days
    expected-yield: uint,        ;; expected yield per plant
    seasonal-preference: uint,   ;; preferred season (1=spring, 2=summer, 3=fall, 4=winter)
    companion-plants: (list 5 (string-ascii 50))
  }
)

;; Individual plantings tracking
(define-map plantings
  uint ;; planting-id
  {
    plot-id: uint,
    user: principal,
    variety: (string-ascii 50),
    planting-date: uint,
    current-stage: uint,
    last-updated: uint,
    expected-harvest: uint,
    actual-harvest: uint,
    yield-amount: uint,
    health-score: uint,
    notes: (string-ascii 200)
  }
)

;; Growth progress tracking
(define-map growth-progress
  {planting-id: uint, stage: uint}
  {
    stage-date: uint,
    health-assessment: uint, ;; 1-10 scale
    size-measurement: uint,  ;; in centimeters
    photo-hash: (optional (string-ascii 64)), ;; IPFS hash for photos
    observer: principal,
    environmental-notes: (string-ascii 150)
  }
)

;; Harvest records
(define-map harvest-records
  uint ;; planting-id
  {
    harvest-date: uint,
    quantity: uint,
    quality-score: uint, ;; 1-10 scale
    weight: uint,        ;; in grams
    market-value: uint,  ;; estimated value in cents
    distribution: (string-ascii 100), ;; where the harvest went
    harvester: principal
  }
)

;; Seasonal planning
(define-map seasonal-plans
  {user: principal, season: uint}
  {
    planned-varieties: (list 10 (string-ascii 50)),
    total-plots: uint,
    expected-yield: uint,
    planting-schedule: (list 20 uint), ;; block heights for planned activities
    goals: (string-ascii 200),
    budget: uint
  }
)

;; Weather and environmental data
(define-map environmental-data
  uint ;; stacks-block-height (daily records)
  {
    temperature-high: uint,
    temperature-low: uint,
    rainfall: uint,        ;; millimeters
    humidity: uint,        ;; percentage
    pest-reports: (list 5 (string-ascii 50)),
    disease-reports: (list 5 (string-ascii 50))
  }
)

;; Community statistics
(define-map season-statistics
  uint ;; season
  {
    total-plantings: uint,
    total-harvest: uint,
    varieties-grown: uint,
    average-yield: uint,
    most-successful-variety: (string-ascii 50),
    community-health-score: uint
  }
)

;; private functions
(define-private (calculate-days-difference (start-block uint) (end-block uint))
  ;; Simplified: assuming 144 blocks per day (10-minute block times)
  (/ (- end-block start-block) u144)
)

(define-private (is-ready-for-next-stage (planting-id uint))
  (match (map-get? plantings planting-id)
    planting-data
    (let (
      (variety (get variety planting-data))
      (current-stage (get current-stage planting-data))
      (planting-date (get planting-date planting-data))
      (days-since-planting (calculate-days-difference planting-date stacks-block-height))
    )
      (match (map-get? plant-varieties variety)
        variety-data
        (let (
          (expected-days (/ (get growing-days variety-data) u7)) ;; rough stage duration
        )
          (>= days-since-planting expected-days)
        )
        false
      )
    )
    false
  )
)

(define-private (update-season-statistics (season uint) (variety (string-ascii 50)) (yield uint))
  (let (
    (current-stats (default-to 
      {total-plantings: u0, total-harvest: u0, varieties-grown: u0, average-yield: u0, 
       most-successful-variety: "", community-health-score: u0}
      (map-get? season-statistics season)))
  )
    (map-set season-statistics season
      {
        total-plantings: (+ (get total-plantings current-stats) u1),
        total-harvest: (+ (get total-harvest current-stats) yield),
        varieties-grown: (+ (get varieties-grown current-stats) u1),
        average-yield: (/ (+ (get total-harvest current-stats) yield) 
                         (+ (get total-plantings current-stats) u1)),
        most-successful-variety: variety,
        community-health-score: (get community-health-score current-stats)
      }
    )
  )
)

(define-private (calculate-health-score (stage uint) (measurements (list 10 uint)))
  ;; Simplified health calculation based on growth measurements
  (fold + measurements u0)
)

;; public functions

;; Register a new plant variety
(define-public (register-plant-variety 
  (variety (string-ascii 50))
  (growing-days uint)
  (optimal-temp uint)
  (water-freq uint)
  (expected-yield uint)
  (season-pref uint)
  (companions (list 5 (string-ascii 50))))
  
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (map-set plant-varieties variety
        {
          growing-days: growing-days,
          optimal-temperature: optimal-temp,
          water-frequency: water-freq,
          expected-yield: expected-yield,
          seasonal-preference: season-pref,
          companion-plants: companions
        }
      )
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Plant a new crop
(define-public (plant-crop 
  (plot-id uint) 
  (variety (string-ascii 50)) 
  (notes (string-ascii 200)))
  
  (let (
    (planting-id (var-get next-planting-id))
    (current-season (var-get current-growing-season))
  )
    (match (map-get? plant-varieties variety)
      variety-data
      (begin
        (map-set plantings planting-id
          {
            plot-id: plot-id,
            user: tx-sender,
            variety: variety,
            planting-date: stacks-block-height,
            current-stage: STAGE-PLANTED,
            last-updated: stacks-block-height,
            expected-harvest: (+ stacks-block-height (* (get growing-days variety-data) u144)),
            actual-harvest: u0,
            yield-amount: u0,
            health-score: u10, ;; start with perfect health
            notes: notes
          }
        )
        ;; Record initial growth progress
        (map-set growth-progress {planting-id: planting-id, stage: STAGE-PLANTED}
          {
            stage-date: stacks-block-height,
            health-assessment: u10,
            size-measurement: u0,
            photo-hash: none,
            observer: tx-sender,
            environmental-notes: notes
          }
        )
        (var-set next-planting-id (+ planting-id u1))
        (var-set total-plantings (+ (var-get total-plantings) u1))
        (ok planting-id)
      )
      ERR-PLANT-NOT-FOUND
    )
  )
)

;; Update growth stage
(define-public (update-growth-stage 
  (planting-id uint) 
  (new-stage uint) 
  (health-score uint) 
  (size uint)
  (notes (string-ascii 150)))
  
  (let (
    (planting-data (unwrap! (map-get? plantings planting-id) ERR-PLANT-NOT-FOUND))
  )
    (if (and (is-eq tx-sender (get user planting-data))
             (> new-stage (get current-stage planting-data))
             (<= new-stage STAGE-HARVESTED))
      (begin
        ;; Update planting record
        (map-set plantings planting-id
          (merge planting-data
            {
              current-stage: new-stage,
              last-updated: stacks-block-height,
              health-score: health-score
            }
          )
        )
        ;; Record growth progress
        (map-set growth-progress {planting-id: planting-id, stage: new-stage}
          {
            stage-date: stacks-block-height,
            health-assessment: health-score,
            size-measurement: size,
            photo-hash: none,
            observer: tx-sender,
            environmental-notes: notes
          }
        )
        (ok true)
      )
      ERR-INVALID-STAGE
    )
  )
)

;; Record harvest
(define-public (record-harvest-yield
  (planting-id uint)
  (quantity uint)
  (quality uint)
  (weight uint)
  (market-value uint)
  (distribution (string-ascii 100)))
  
  (let (
    (planting-data (unwrap! (map-get? plantings planting-id) ERR-PLANT-NOT-FOUND))
    (current-season (var-get current-growing-season))
  )
    (if (and (is-eq tx-sender (get user planting-data))
             (>= (get current-stage planting-data) STAGE-MATURE))
      (begin
        ;; Update planting record
        (map-set plantings planting-id
          (merge planting-data
            {
              current-stage: STAGE-HARVESTED,
              actual-harvest: stacks-block-height,
              yield-amount: quantity,
              last-updated: stacks-block-height
            }
          )
        )
        ;; Record harvest details
        (map-set harvest-records planting-id
          {
            harvest-date: stacks-block-height,
            quantity: quantity,
            quality-score: quality,
            weight: weight,
            market-value: market-value,
            distribution: distribution,
            harvester: tx-sender
          }
        )
        ;; Update season statistics
        (update-season-statistics current-season (get variety planting-data) quantity)
        (var-set total-yield-recorded (+ (var-get total-yield-recorded) quantity))
        (ok true)
      )
      ERR-NOT-READY-FOR-HARVEST
    )
  )
)

;; Create seasonal plan
(define-public (create-seasonal-plan
  (season uint)
  (planned-varieties (list 10 (string-ascii 50)))
  (total-plots uint)
  (expected-yield uint)
  (goals (string-ascii 200))
  (budget uint))
  
  (begin
    (map-set seasonal-plans {user: tx-sender, season: season}
      {
        planned-varieties: planned-varieties,
        total-plots: total-plots,
        expected-yield: expected-yield,
        planting-schedule: (list),
        goals: goals,
        budget: budget
      }
    )
    (ok true)
  )
)

;; Record environmental data (admin only)
(define-public (record-environmental-data
  (temp-high uint)
  (temp-low uint)
  (rainfall uint)
  (humidity uint)
  (pests (list 5 (string-ascii 50)))
  (diseases (list 5 (string-ascii 50))))
  
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (map-set environmental-data stacks-block-height
        {
          temperature-high: temp-high,
          temperature-low: temp-low,
          rainfall: rainfall,
          humidity: humidity,
          pest-reports: pests,
          disease-reports: diseases
        }
      )
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Update growing season
(define-public (update-growing-season (new-season uint))
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (var-set current-growing-season new-season)
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; Add photo to growth progress
(define-public (add-growth-photo (planting-id uint) (stage uint) (photo-hash (string-ascii 64)))
  (let (
    (planting-data (unwrap! (map-get? plantings planting-id) ERR-PLANT-NOT-FOUND))
    (progress-key {planting-id: planting-id, stage: stage})
  )
    (if (is-eq tx-sender (get user planting-data))
      (match (map-get? growth-progress progress-key)
        progress-data
        (begin
          (map-set growth-progress progress-key
            (merge progress-data {photo-hash: (some photo-hash)})
          )
          (ok true)
        )
        ERR-INVALID-STAGE
      )
      ERR-UNAUTHORIZED
    )
  )
)

;; read only functions

;; Get plant variety information
(define-read-only (get-plant-variety (variety (string-ascii 50)))
  (map-get? plant-varieties variety)
)

;; Get planting information
(define-read-only (get-planting-info (planting-id uint))
  (map-get? plantings planting-id)
)

;; Get growth progress for specific stage
(define-read-only (get-growth-progress (planting-id uint) (stage uint))
  (map-get? growth-progress {planting-id: planting-id, stage: stage})
)

;; Get harvest record
(define-read-only (get-harvest-record (planting-id uint))
  (map-get? harvest-records planting-id)
)

;; Get seasonal plan
(define-read-only (get-seasonal-plan (user principal) (season uint))
  (map-get? seasonal-plans {user: user, season: season})
)

;; Get environmental data
(define-read-only (get-environmental-data (block-height-param uint))
  (map-get? environmental-data block-height-param)
)

;; Get season statistics
(define-read-only (get-season-statistics (season uint))
  (map-get? season-statistics season)
)

;; Get current growing season
(define-read-only (get-current-growing-season)
  (var-get current-growing-season)
)

;; Get total plantings
(define-read-only (get-total-plantings)
  (var-get total-plantings)
)

;; Get total yield recorded
(define-read-only (get-total-yield-recorded)
  (var-get total-yield-recorded)
)

;; Check if planting is ready for harvest
(define-read-only (is-ready-for-harvest (planting-id uint))
  (match (map-get? plantings planting-id)
    planting-data
    (>= (get current-stage planting-data) STAGE-MATURE)
    false
  )
)

