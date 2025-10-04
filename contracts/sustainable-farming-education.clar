;; title: sustainable-farming-education
;; version: 1.0.0
;; summary: Share organic farming techniques, pest management, and sustainable gardening practices
;; description: A comprehensive knowledge-sharing platform for sustainable farming education,
;;              featuring peer-to-peer learning, expert advice, and community-driven content.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-CONTENT-NOT-FOUND (err u404))
(define-constant ERR-INVALID-RATING (err u400))
(define-constant ERR-ALREADY-RATED (err u409))
(define-constant ERR-INVALID-CATEGORY (err u410))
(define-constant ERR-CONTENT-TOO-LONG (err u411))
(define-constant ERR-EXPERT-NOT-FOUND (err u412))

;; Content categories
(define-constant CATEGORY-ORGANIC-TECHNIQUES u1)
(define-constant CATEGORY-PEST-MANAGEMENT u2)
(define-constant CATEGORY-SOIL-HEALTH u3)
(define-constant CATEGORY-WATER-MANAGEMENT u4)
(define-constant CATEGORY-COMPANION-PLANTING u5)
(define-constant CATEGORY-COMPOSTING u6)
(define-constant CATEGORY-SEASONAL-PLANNING u7)
(define-constant CATEGORY-DISEASE-PREVENTION u8)

;; Content types
(define-constant TYPE-ARTICLE u1)
(define-constant TYPE-VIDEO u2)
(define-constant TYPE-INFOGRAPHIC u3)
(define-constant TYPE-GUIDE u4)
(define-constant TYPE-TIP u5)
(define-constant TYPE-QUESTION u6)
(define-constant TYPE-ANSWER u7)

;; data vars
(define-data-var next-content-id uint u1)
(define-data-var next-expert-id uint u1)
(define-data-var total-content-items uint u0)
(define-data-var total-experts uint u0)
(define-data-var total-ratings uint u0)

;; data maps
;; Educational content storage
(define-map educational-content
  uint ;; content-id
  {
    title: (string-ascii 100),
    author: principal,
    category: uint,
    content-type: uint,
    content-hash: (string-ascii 64), ;; IPFS hash
    description: (string-ascii 300),
    tags: (list 10 (string-ascii 30)),
    difficulty-level: uint, ;; 1=beginner, 2=intermediate, 3=advanced
    estimated-time: uint,   ;; minutes to complete
    created-at: uint,
    updated-at: uint,
    view-count: uint,
    average-rating: uint,
    total-ratings: uint,
    verified: bool
  }
)

;; Content ratings and reviews
(define-map content-ratings
  {content-id: uint, user: principal}
  {
    rating: uint,        ;; 1-5 stars
    review: (string-ascii 500),
    helpful-votes: uint,
    created-at: uint,
    verified-user: bool
  }
)

;; Expert profiles
(define-map farming-experts
  uint ;; expert-id
  {
    user: principal,
    name: (string-ascii 50),
    specializations: (list 5 uint), ;; category specializations
    bio: (string-ascii 300),
    experience-years: uint,
    certifications: (list 5 (string-ascii 50)),
    verified-expert: bool,
    content-contributed: uint,
    average-rating: uint,
    total-consultations: uint,
    availability: bool
  }
)

;; Knowledge base categories and subcategories
(define-map knowledge-categories
  uint ;; category-id
  {
    name: (string-ascii 50),
    description: (string-ascii 200),
    parent-category: (optional uint),
    content-count: uint,
    moderators: (list 3 principal),
    featured-content: (list 5 uint)
  }
)

;; User learning progress
(define-map user-progress
  principal
  {
    completed-content: (list 50 uint),
    bookmarked-content: (list 20 uint),
    expertise-areas: (list 5 uint),
    learning-streak: uint,
    total-time-spent: uint,
    achievements: (list 10 (string-ascii 30)),
    contribution-score: uint,
    last-active: uint
  }
)

;; Community questions and answers
(define-map community-qa
  uint ;; question-id
  {
    question: (string-ascii 500),
    asker: principal,
    category: uint,
    tags: (list 5 (string-ascii 30)),
    created-at: uint,
    answer-count: uint,
    best-answer: (optional uint),
    upvotes: uint,
    status: uint ;; 1=open, 2=answered, 3=closed
  }
)

(define-map qa-answers
  {question-id: uint, answer-id: uint}
  {
    answer: (string-ascii 1000),
    answerer: principal,
    created-at: uint,
    upvotes: uint,
    expert-verified: bool,
    helpful-count: uint
  }
)

;; Learning paths and courses
(define-map learning-paths
  uint ;; path-id
  {
    title: (string-ascii 100),
    description: (string-ascii 300),
    creator: principal,
    content-sequence: (list 20 uint),
    difficulty: uint,
    estimated-hours: uint,
    prerequisites: (list 5 uint),
    completion-reward: uint,
    enrolled-users: uint,
    completion-rate: uint
  }
)

;; Seasonal farming calendar
(define-map seasonal-calendar
  {season: uint, week: uint}
  {
    recommended-activities: (list 5 (string-ascii 100)),
    plant-varieties: (list 10 (string-ascii 30)),
    maintenance-tasks: (list 5 (string-ascii 100)),
    common-issues: (list 3 (string-ascii 100)),
    expert-tips: (list 3 uint) ;; content-ids
  }
)

;; private functions
(define-private (calculate-average-rating (content-id uint) (new-rating uint))
  (match (map-get? educational-content content-id)
    content-data
    (let (
      (current-avg (get average-rating content-data))
      (content-total-ratings (get total-ratings content-data))
      (new-total (+ content-total-ratings u1))
    )
      (/ (+ (* current-avg content-total-ratings) new-rating) new-total)
    )
    new-rating
  )
)

(define-private (update-user-progress (user principal) (content-id uint))
  (let (
    (current-progress (default-to
      {completed-content: (list), bookmarked-content: (list), expertise-areas: (list),
       learning-streak: u0, total-time-spent: u0, achievements: (list),
       contribution-score: u0, last-active: u0}
      (map-get? user-progress user)))
  )
    (map-set user-progress user
      (merge current-progress
        {
          completed-content: (unwrap! (as-max-len? (append (get completed-content current-progress) content-id) u50) (get completed-content current-progress)),
          last-active: stacks-block-height
        }
      )
    )
  )
)

(define-private (verify-expert-credentials (expert-id uint))
  ;; Simplified verification - in production would check external credentials
  true
)

(define-private (calculate-contribution-score (user principal))
  (let (
    (user-data (default-to
      {completed-content: (list), bookmarked-content: (list), expertise-areas: (list),
       learning-streak: u0, total-time-spent: u0, achievements: (list),
       contribution-score: u0, last-active: u0}
      (map-get? user-progress user)))
  )
    ;; Simple scoring based on activity
    (+ (len (get completed-content user-data))
       (get learning-streak user-data)
       (len (get achievements user-data)))
  )
)

;; public functions

;; Submit educational content
(define-public (submit-content
  (title (string-ascii 100))
  (category uint)
  (content-type uint)
  (content-hash (string-ascii 64))
  (description (string-ascii 300))
  (tags (list 10 (string-ascii 30)))
  (difficulty uint)
  (estimated-time uint))
  
  (let (
    (content-id (var-get next-content-id))
  )
    (if (and (>= category CATEGORY-ORGANIC-TECHNIQUES)
             (<= category CATEGORY-DISEASE-PREVENTION)
             (>= content-type TYPE-ARTICLE)
             (<= content-type TYPE-ANSWER))
      (begin
        (map-set educational-content content-id
          {
            title: title,
            author: tx-sender,
            category: category,
            content-type: content-type,
            content-hash: content-hash,
            description: description,
            tags: tags,
            difficulty-level: difficulty,
            estimated-time: estimated-time,
            created-at: stacks-block-height,
            updated-at: stacks-block-height,
            view-count: u0,
            average-rating: u0,
            total-ratings: u0,
            verified: false
          }
        )
        (var-set next-content-id (+ content-id u1))
        (var-set total-content-items (+ (var-get total-content-items) u1))
        ;; Update user contribution score
        (let (
          (user-data (default-to
            {completed-content: (list), bookmarked-content: (list), expertise-areas: (list),
             learning-streak: u0, total-time-spent: u0, achievements: (list),
             contribution-score: u0, last-active: u0}
            (map-get? user-progress tx-sender)))
        )
          (map-set user-progress tx-sender
            (merge user-data
              {
                contribution-score: (+ (get contribution-score user-data) u10),
                last-active: stacks-block-height
              }
            )
          )
        )
        (ok content-id)
      )
      ERR-INVALID-CATEGORY
    )
  )
)

;; Rate content
(define-public (rate-content (content-id uint) (rating uint) (review (string-ascii 500)))
  (let (
    (content-data (unwrap! (map-get? educational-content content-id) ERR-CONTENT-NOT-FOUND))
    (rating-key {content-id: content-id, user: tx-sender})
  )
    (if (and (>= rating u1) (<= rating u5))
      (if (is-none (map-get? content-ratings rating-key))
        (begin
          ;; Add new rating
          (map-set content-ratings rating-key
            {
              rating: rating,
              review: review,
              helpful-votes: u0,
              created-at: stacks-block-height,
              verified-user: true
            }
          )
          ;; Update content average rating
          (let (
            (new-avg (calculate-average-rating content-id rating))
            (new-total (+ (get total-ratings content-data) u1))
          )
            (map-set educational-content content-id
              (merge content-data
                {
                  average-rating: new-avg,
                  total-ratings: new-total
                }
              )
            )
          )
          (var-set total-ratings (+ (var-get total-ratings) u1))
          (ok true)
        )
        ERR-ALREADY-RATED
      )
      ERR-INVALID-RATING
    )
  )
)

;; Register as farming expert
(define-public (register-expert
  (name (string-ascii 50))
  (specializations (list 5 uint))
  (bio (string-ascii 300))
  (experience-years uint)
  (certifications (list 5 (string-ascii 50))))
  
  (let (
    (expert-id (var-get next-expert-id))
  )
    (begin
      (map-set farming-experts expert-id
        {
          user: tx-sender,
          name: name,
          specializations: specializations,
          bio: bio,
          experience-years: experience-years,
          certifications: certifications,
          verified-expert: false,
          content-contributed: u0,
          average-rating: u0,
          total-consultations: u0,
          availability: true
        }
      )
      (var-set next-expert-id (+ expert-id u1))
      (var-set total-experts (+ (var-get total-experts) u1))
      (ok expert-id)
    )
  )
)

;; Ask community question
(define-public (ask-question
  (question (string-ascii 500))
  (category uint)
  (tags (list 5 (string-ascii 30))))
  
  (let (
    (question-id (var-get next-content-id))
  )
    (begin
      (map-set community-qa question-id
        {
          question: question,
          asker: tx-sender,
          category: category,
          tags: tags,
          created-at: stacks-block-height,
          answer-count: u0,
          best-answer: none,
          upvotes: u0,
          status: u1 ;; open
        }
      )
      (var-set next-content-id (+ question-id u1))
      (ok question-id)
    )
  )
)

;; Answer community question
(define-public (answer-question
  (question-id uint)
  (answer (string-ascii 1000)))
  
  (let (
    (question-data (unwrap! (map-get? community-qa question-id) ERR-CONTENT-NOT-FOUND))
    (answer-id (+ (get answer-count question-data) u1))
  )
    (begin
      (map-set qa-answers {question-id: question-id, answer-id: answer-id}
        {
          answer: answer,
          answerer: tx-sender,
          created-at: stacks-block-height,
          upvotes: u0,
          expert-verified: false,
          helpful-count: u0
        }
      )
      ;; Update question answer count
      (map-set community-qa question-id
        (merge question-data
          {
            answer-count: answer-id,
            status: u2 ;; answered
          }
        )
      )
      (ok answer-id)
    )
  )
)

;; Bookmark content
(define-public (bookmark-content (content-id uint))
  (let (
    (content-data (unwrap! (map-get? educational-content content-id) ERR-CONTENT-NOT-FOUND))
    (user-data (default-to
      {completed-content: (list), bookmarked-content: (list), expertise-areas: (list),
       learning-streak: u0, total-time-spent: u0, achievements: (list),
       contribution-score: u0, last-active: u0}
      (map-get? user-progress tx-sender)))
  )
    (begin
      (map-set user-progress tx-sender
        (merge user-data
          {
            bookmarked-content: (unwrap! (as-max-len? (append (get bookmarked-content user-data) content-id) u20) (get bookmarked-content user-data)),
            last-active: stacks-block-height
          }
        )
      )
      (ok true)
    )
  )
)

;; Complete content (mark as read/watched)
(define-public (complete-content (content-id uint) (time-spent uint))
  (let (
    (content-data (unwrap! (map-get? educational-content content-id) ERR-CONTENT-NOT-FOUND))
  )
    (begin
      ;; Update content view count
      (map-set educational-content content-id
        (merge content-data
          {
            view-count: (+ (get view-count content-data) u1)
          }
        )
      )
      ;; Update user progress
      (update-user-progress tx-sender content-id)
      ;; Add time spent to user total
      (let (
        (user-data (unwrap! (map-get? user-progress tx-sender) ERR-CONTENT-NOT-FOUND))
      )
        (map-set user-progress tx-sender
          (merge user-data
            {
              total-time-spent: (+ (get total-time-spent user-data) time-spent)
            }
          )
        )
      )
      (ok true)
    )
  )
)

;; Verify content (admin/expert only)
(define-public (verify-content (content-id uint))
  (let (
    (content-data (unwrap! (map-get? educational-content content-id) ERR-CONTENT-NOT-FOUND))
  )
    (if (is-eq tx-sender CONTRACT-OWNER) ;; simplified - should check if user is expert
      (begin
        (map-set educational-content content-id
          (merge content-data {verified: true})
        )
        (ok true)
      )
      ERR-UNAUTHORIZED
    )
  )
)

;; Update seasonal calendar (admin only)
(define-public (update-seasonal-calendar
  (season uint)
  (week uint)
  (activities (list 5 (string-ascii 100)))
  (varieties (list 10 (string-ascii 30)))
  (tasks (list 5 (string-ascii 100)))
  (issues (list 3 (string-ascii 100)))
  (tips (list 3 uint)))
  
  (if (is-eq tx-sender CONTRACT-OWNER)
    (begin
      (map-set seasonal-calendar {season: season, week: week}
        {
          recommended-activities: activities,
          plant-varieties: varieties,
          maintenance-tasks: tasks,
          common-issues: issues,
          expert-tips: tips
        }
      )
      (ok true)
    )
    ERR-UNAUTHORIZED
  )
)

;; read only functions

;; Get content details
(define-read-only (get-content (content-id uint))
  (map-get? educational-content content-id)
)

;; Get content rating
(define-read-only (get-content-rating (content-id uint) (user principal))
  (map-get? content-ratings {content-id: content-id, user: user})
)

;; Get expert profile
(define-read-only (get-expert-profile (expert-id uint))
  (map-get? farming-experts expert-id)
)

;; Get user progress
(define-read-only (get-user-progress (user principal))
  (map-get? user-progress user)
)

;; Get community question
(define-read-only (get-question (question-id uint))
  (map-get? community-qa question-id)
)

;; Get question answer
(define-read-only (get-answer (question-id uint) (answer-id uint))
  (map-get? qa-answers {question-id: question-id, answer-id: answer-id})
)

;; Get seasonal calendar
(define-read-only (get-seasonal-calendar (season uint) (week uint))
  (map-get? seasonal-calendar {season: season, week: week})
)

;; Get learning path
(define-read-only (get-learning-path (path-id uint))
  (map-get? learning-paths path-id)
)

;; Get total content count
(define-read-only (get-total-content)
  (var-get total-content-items)
)

;; Get total experts count
(define-read-only (get-total-experts)
  (var-get total-experts)
)

;; Get total ratings count
(define-read-only (get-total-ratings)
  (var-get total-ratings)
)

