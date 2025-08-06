breed [farmers farmer]
breed [contractors contractor]
breed [commission-agents commission-agent]
breed [wholesalers wholesaler]
breed [retailers retailer]

globals [
  season
  Year
  ;; Food loss tracking
  data-log-file
  total-food-loss
  pre-harvest-loss
  post-harvest-loss
  total-preharvest-loss
  total-postharvest-loss

  ;; Financial tracking
  total-profit
  market-price

  export-price

  ;; Environmental factors
  climate-shock-active?
  pest-outbreak-active?

  ;; Adaptation metrics
  quality-improvement-rate
  tech-adoption-rate

  ;; Default loss rates
  transport-loss
  storage-loss
  unsold-inventory

  ;; Demand-supply based prices
  market-demand
  base-price

  ;; Storage and season tracking
  storage-available?         ;; Determines if storage is available
  current-season-multiplier  ;; Track season effect
  current-quality-bonus      ;; Track quality effect

  ;; Commission and bidding
  commission-rate            ;; Commission rate for agents
  bidding-active?            ;; Track if bidding is happening
 ; season-length              ;; Length of the current season in ticks
  current-season             ;; Track the current season (e.g., 1, 2, 3, ...)

  ;; Contract-related
 ; contract-active?           ;; Track if contracts are active for farmers
  current-contractor         ;; Track the contractor assigned to a farmer
  transactions-this-tick

]

directed-link-breed [transactions transaction]  ; Shows flow of goods
farmers-own[ farmer-type
  next-action-tick
  season-count
  planned-adoption-year
  last-season-profit
  last-season-loss
  last-season-inventory
  tech-adopted?
  sold-amount
 last-sold-amount

]
contractors-own [

   last-season-profit
  min-profit-margin
  contract-active?
  next-action-tick
  action-interval
  actions-this-season
  postharvest-tech-adopted?
  inventory-cost-per-unit

]
wholesalers-own [
  last-season-profit
  markup
  next-action-tick
  action-interval
  actions-this-season
  postharvest-tech-adopted?
  inventory-cost-per-unit
  consecutive-negative-profit

]
retailers-own [

last-season-profit
dynamic-sort-rate
 markup

]
turtles-own [
  ; Core attributes
    profit
  inventory
  quality
  last-tick-profit

  ; Farmer-specific
  farm-size
  farmer-preharvest-loss
  risk-tolerance
  production-cost
  under-contract?

  ; Business agents
  operating-cost
  capital-available
    ;unsold-inventory
]

;contractors-own [contract-active?]
links-own [
  transaction-volume
  transaction-value
  duration
]

; ======================
; SETUP PROCEDURES
; ======================

to setup

  clear-all
  set-default-shape farmers "person"
  set-default-shape contractors "truck"
  set-default-shape commission-agents "circle"
  set-default-shape wholesalers "car"
  set-default-shape retailers "house"

  ; Initialize globals
   random-seed 12345
  set year 1
  set base-price 40
  set market-demand 2400  ;; or any baseline number you want
  set market-price 10
  set export-price 15
  set quality-improvement-rate 0.5
  set tech-adoption-rate 0.1
  set transport-loss 1 ; 1.5
  set storage-loss 1 ;2
  set climate-shock-active? false
  set pest-outbreak-active? false
  set total-preharvest-loss 0
  set total-postharvest-loss 0
  set storage-available? true ;; can be set as false, depending on the scenario
  set storage-available? true
  set unsold-inventory 0 ;; Initialize unsold inventory
  ;; Create all farmers first
 ;; 1. Create all farmers, set farm-size
create-farmers 50 [
  setup-farmer
      set farm-size random-normal 70 40
      if farm-size < 10 [ set farm-size 10 ]
      if farm-size > 200 [ set farm-size 200 ]]

; 2. Assign types for ALL farmers at once
assign-farmer-types

;; 3. Now set type-dependent attributes
ask farmers [
  if farmer-type = "L" [
    set production-cost random-normal 10 1.5
    set quality random-normal 60 5
    set tech-adopted? false
  ]
  if farmer-type = "M" [
    set production-cost random-normal 13 2
    set quality random-normal 45 7
  ]
  if farmer-type = "S" [
    set production-cost random-normal 16 2.5
    set quality random-normal 35 8
  ]
  set quality max list 0 quality
]

  create-contractors 15 [ setup-contractor ]
  create-commission-agents 5 [ setup-commission-agent ]
  create-wholesalers 10 [ setup-wholesaler ]
  create-retailers 20 [ setup-retailer ]
  ;; Force all ?-adopted? variables to be boolean
  ask farmers [ set tech-adopted? (tech-adopted? = true) ]
  ask contractors [ set postharvest-tech-adopted? (postharvest-tech-adopted? = true) ]
  ask wholesalers [ set postharvest-tech-adopted? (postharvest-tech-adopted? = true) ]


  setup-transaction-network
  let farmer-list shuffle (list farmers)
 let n length farmer-list
  let n1 round (n * 0.10)
  let n2 round (n * 0.20)
  let n3 round (n * 0.40)
  let n4 n - (n1 + n2 + n3)

  foreach (sublist farmer-list 0 n1) [ f -> ask f [ set planned-adoption-year 1 ] ]
  foreach (sublist farmer-list n1 (n1 + n2)) [ f -> ask f [ set planned-adoption-year 2 ] ]
  foreach (sublist farmer-list (n1 + n2) (n1 + n2 + n3)) [ f -> ask f [ set planned-adoption-year 3 ] ]
  foreach (sublist farmer-list (n1 + n2 + n3) n) [ f -> ask f [ set planned-adoption-year 999 ] ]  ;; laggards
 set data-log-file (word "mango_output_log.csv")
  ;file-delete data-log-file ;; removes old file if it exists
  reset-ticks
  update-display

end

to setup-farmer
  set under-contract? false
  set risk-tolerance random-float 1.0
  set profit 0
  ;set quality 0
  set quality 40
  set inventory 0
  set farmer-preharvest-loss 0
  set next-action-tick random 10
  set season-count 0
  set label ""
end


to assign-farmer-types
  ;; Sort farmers by descending farm-size
  let farmer-list sort-by [[a b] -> [farm-size] of a > [farm-size] of b] farmers
  let n length farmer-list
  let nL max list 1 round (n * 0.10)
  let nM max list 1 round (n * 0.30)
  let i 0

  while [i < nL] [
    ask (item i farmer-list) [
      set farmer-type "L"
      set label "L"
    ]
    set i i + 1
  ]
  while [i < (nL + nM)] [
    ask (item i farmer-list) [
      set farmer-type "M"
      set label "M"
    ]
    set i i + 1
  ]
  while [i < n] [
    ask (item i farmer-list) [
      set farmer-type "S"
      set label "S"
    ]
    set i i + 1
  ]
  print (word
    "All Farmers: " n
    " | Large: " count farmers with [farmer-type = "L"]
    " | Medium: " count farmers with [farmer-type = "M"]
    " | Small: " count farmers with [farmer-type = "S"])
end
to setup-contractor
  setxy (random 15 - 7) (random-ycor)
  set color blue
  ;; Inventory: higher average, moderate variance for stability
  set inventory max list 400 (random-normal 650 80) ; typical: 650±80, min 400
  ;; Capital: enough to buy at least 2× starting inventory at market price + buffer
  set capital-available max list 80000 (random-normal (2 * inventory * market-price + 15000) (inventory * market-price * 0.2))
  set operating-cost random-normal 300 50
  let initial_inventory_cost inventory * market-price
  set capital-available capital-available - initial_inventory_cost
  set profit 0
  set postharvest-tech-adopted? (random-float 1 < (capital-available / 100000))
  set contract-active? false
  set action-interval 1 + random 3 ; 1, 2, or 3
  set next-action-tick random action-interval
  set actions-this-season 0
  set last-season-profit 0
  set min-profit-margin 0.05 ;0.1;
  set quality random-normal 61 7
  set inventory-cost-per-unit 0
end

to setup-wholesaler
  setxy random-xcor (random 10 - 5)
  set color orange
  ;; Inventory: higher average, moderate variance for stability
  set inventory max list 600 (random-normal 900 120) ; typical: 900±120, min 600
  ;; Capital: enough to buy at least 2× starting inventory at market price + buffer
  ;set capital-available max list 160000 (random-normal (2 * inventory * market-price + 12000) (inventory * market-price * 0.2))
  set capital-available max list 400000 (random-normal (5 * inventory * market-price + 40000) (inventory * market-price * 0.2))
  set operating-cost random-normal 200 40
  let initial_inventory_cost inventory * market-price
  set capital-available capital-available - initial_inventory_cost
  set profit 0
  set quality random-normal 60 10
  set postharvest-tech-adopted? (random-float 1 < (capital-available / 100000))
  set action-interval 1 + random 9
  set next-action-tick random 10
  set actions-this-season 0
  set last-season-profit 0
  set markup 0.5
  set inventory-cost-per-unit 0
end

to setup-retailer
  setxy random-xcor (max-pycor - random 10)
  set shape "house"
  set size 1.5
  set color yellow
  set label "R"
  set label-color black
  ;; Inventory: higher average, moderate variance for stability
  set inventory max list 50 (random-normal 120 20) ; typical: 120±20, min 50
  ;; Capital: enough to buy at least 2× starting inventory at market price + buffer
  set capital-available max list 12000 (random-normal (2 * inventory * market-price + 4000) (inventory * market-price * 0.2))
  set operating-cost random-normal 70 20
  let initial_inventory_cost inventory * market-price
  set capital-available capital-available - initial_inventory_cost
  set profit 0
  set quality max list 0 (random-normal 50 15)
  set last-season-profit 0
  set markup 0.5
end


to setup-commission-agent
  set color gray
  set capital-available max list 5000 (random-normal 8000 2000)
  set operating-cost random-normal 120 30
  set profit 0
  set commission-rate random-normal 0.1 0.02
end


to setup-transaction-network
  ask farmers [
    if (inventory > 0) and (random-float 1.0 < (0.4 + (risk-tolerance * 0.3))) [
      ;; Calculate minimum viable deal size (5 units or 5% of inventory, whichever is larger)
      let min-deal-size 5
      let relative-deal inventory * (0.05 + (risk-tolerance * 0.05))
      let deal-size max (list min-deal-size relative-deal)

      ;; Ensure deal doesn't exceed farmer's inventory
      set deal-size min (list deal-size inventory)

      ;; Find contractors who:
      ;; 1. Can afford the deal (with 10% buffer)
      ;; 2. Have available capacity (<5 existing links)
      ;; 3. Are actively contracting
      let suitable-contractors contractors with [
        (capital-available >= (deal-size * market-price * 1.1)) and
        (count my-in-links < 5) and
        contract-active?
      ]

      if any? suitable-contractors [
        ;; Prefer contractors with more capital and fewer existing connections
        let chosen-contractor max-one-of suitable-contractors [
          capital-available - (count my-in-links * 1000)
        ]

        create-transaction-to chosen-contractor [
          set transaction-volume deal-size
          set transaction-value deal-size * market-price
          set duration random 4 + 2
          set color green
        ]

        ;; Immediate partial payment (30% advance)
        ask chosen-contractor [
          set capital-available capital-available - (deal-size * market-price * 0.3)
        ]
ask self [
  set capital-available capital-available + (deal-size * market-price * 0.3)
]
        print (word "Established contract: Farmer " who " -> Contractor " [who] of chosen-contractor
               " for " deal-size " units at " market-price " each")
      ]
    ]
  ]
end

; ======================
; MAIN LOOP
; ======================

to go
  set transactions-this-tick 0

  ;; 1. Year/Season change and contract reset (every 30 ticks)
  if (ticks mod 30 = 0) and (ticks > 0) [
    set year year + 1
    print (word "New Year Started: Year " year)
    form-contracts
    ask contractors [ set actions-this-season 0 ]
    ask wholesalers [ set actions-this-season 0 ]
  ]

  ;; 2. Farmers: act only in their own season schedule, and only in window [0,9] of the season
  ask farmers [
    if (ticks = next-action-tick) and ((ticks mod 30) < 10) [
      farmer-decisions
      ;; Schedule next action for this farmer in window [0,9] of the NEXT season
      let base (ticks - (ticks mod 30)) + 30  ;; start of next season
      set next-action-tick base + random 10
      set season-count season-count + 1
    ]
  ]

  ;; 2b. End-of-window cleanup for farmers: after tick 10, forcibly reset inventory and contracts
  if (ticks mod 30) = 10 [
    ask farmers [
      set inventory 0
      set under-contract? false
      set current-contractor nobody
      if inventory < 0 [ set inventory 0 ]
    ]
  ]

  update-season

  ;; 3. Market updates every tick
  update-market-conditions

  ;; 4. Occasional market price boom (every 60 ticks, random chance)
  if (ticks mod 60 = 0) and (random-float 1 < 0.25) [
    set market-price market-price * (1.2 + random-float 0.1)
    print " Price boom! Market price temporarily surged!"
  ]

  ;; 5. Occasional market demand surge (every 45 ticks, random chance)
  if (ticks mod 45 = 0) and (random-float 1 < 0.3) [
    set market-demand market-demand * (1.15 + random-float 0.15)
    print " Demand surge: Market demand temporarily increased!"
  ]

  ;; 6. Environmental shocks (climate & pest), toggled every 10 ticks
  ifelse (ticks mod 10) < 5 [
    set climate-shock-active? true
    set pest-outbreak-active? true
  ] [
    set climate-shock-active? false
    set pest-outbreak-active? false
  ]
  if climate-shock-active? [
    ask wholesalers [ set operating-cost operating-cost * (1 + random-float 0.05) ]
    ask contractors [ set operating-cost operating-cost * (1 + random-float 0.05) ]
  ]
  if pest-outbreak-active? [
    ask wholesalers [ set operating-cost operating-cost * (1 + random-float 0.05) ]
    ask contractors [ set operating-cost operating-cost * (1 + random-float 0.05) ]
  ]

  ;; 7. Recalculate food losses each tick
  calculate-food-loss

  ;; 8. Contractors and wholesalers act every tick on their own schedule
  ask contractors [
    if (ticks = next-action-tick) [
      contractor-decisions
      set next-action-tick ticks + action-interval
      set actions-this-season actions-this-season + 1
    ]
  ]
  ask wholesalers [
    if (ticks = next-action-tick) [
      wholesaler-decisions
      set next-action-tick ticks + action-interval
      set actions-this-season actions-this-season + 1
    ]
  ]

  ;; 9. Retailers act every tick
  ask retailers [ retailer-decisions ]

  ;; 11. Peer learning for wholesalers/contractors
  if (ticks mod 60 = 0) [
    ask wholesalers [
      let peer one-of other wholesalers
      if peer != nobody [
        set markup ([markup] of peer) + random-normal 0 0.03
      ]
    ]
    ask contractors [
      let peer one-of other contractors
      if peer != nobody [
        set min-profit-margin ([min-profit-margin] of peer) + random-normal 0 0.01
      ]
    ]
  ]

  ;; 12. Occasional random cost spike for wholesalers
  if (ticks mod 75 = 0) and (random-float 1 < 0.2) [
    ask one-of wholesalers [ set operating-cost operating-cost * 1.2 ]
    print " Surprise cost increase for one wholesaler!"
  ]

  ;; 13. Update global metrics and process transactions
  update-transactions
  set total-profit sum [profit] of turtles
  set unsold-inventory sum [inventory] of turtles with [inventory > 0]

  ;; 14. Debug summary
  debug-summary
  ask farmers [
    print (word "FARMER " who " inventory: " inventory " capital: " capital-available)
  ]
  ask contractors [
    print (word "CONTRACTOR " who " inventory: " inventory " capital: " capital-available)
  ]
  ask wholesalers [
    print (word "WHOLESALER " who " inventory: " inventory " capital: " capital-available)
  ]
  ask retailers [
    print (word "RETAILER " who " inventory: " inventory " capital: " capital-available)
  ]
  if transactions-this-tick = 0 [
    show (word "Tick " ticks " -- no transactions")
  ]

  log-state
  temp-debug
  show (word "Tick finished: " ticks)
  show (word "Tick " ticks " complete. Transactions: " transactions-this-tick)
  log-global-stats
  log-all-agent-data
  tick
  update-display
  updateplots
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Farmer Decision Logic: Ensures Contracts Are Always Formed
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to farmer-decisions
  ;; --- Initialize key variables for this tick/season ---
  let production 0
  let transaction-revenue 0
  let total-production-cost 0
  let total-storage-cost 0
  let total-spoilage-loss 0

  ;; --- Act only if in first 10 ticks of the season ---
  if not ((ticks mod 30) < 10) [ stop ]

  ;; --- UPDATE PRODUCTION COST (ONCE PER SEASON) ---
  if farmer-type = "L" [ set production-cost random-normal 12 1.5 ]
  if farmer-type = "M" [ set production-cost random-normal 14 2 ]
  if farmer-type = "S" [ set production-cost random-normal 13 2.5 ]
  if tech-adopted? [
    set production-cost production-cost + 2
  ]
  ifelse quality < 50 [
    set production-cost production-cost + (quality * 0.005)
  ][
    set production-cost production-cost - ((quality - 50) * 0.01)
  ]
  set production-cost max list 1 (min list production-cost 35)
  if quality < 40 [
    set quality quality + 2
  ]

  ;; --- TECHNOLOGY ADOPTION: For S and M only ---
  let nearby-farmers farmers-on patches in-radius 5
  if member? farmer-type ["S" "M"] [
    ;; 1. Scheduled (staged) adoption
    if (year = planned-adoption-year) and (tech-adopted? = false) [
      set tech-adopted? true
      let adoption-bonus scheduled-adoption-bonus planned-adoption-year
      set quality quality + adoption-bonus * (1 - (quality / 120))
      print (word "Farmer " who " adopted via scheduled plan in year " year)
    ]
    ;; 2. Peer/cluster effect
    if (planned-adoption-year > year) and (tech-adopted? = false) [
      if any? nearby-farmers with [tech-adopted? = true] [
        if random-float 1 < 0.3 [
          set tech-adopted? true
          set quality quality + (10 + random 6) * (1 - (quality / 120))
          print (word "Farmer " who " adopted via peer effect in year " year)
        ]
      ]
    ]
    ;; 3. Catch-up effect
    if (planned-adoption-year > year) and (tech-adopted? = false) [
      let adopter-nearby count (nearby-farmers with [tech-adopted? = true])
      let total-nearby count nearby-farmers
      if total-nearby > 0 [
        let adoption-rate adopter-nearby / total-nearby
        if (adoption-rate > 0.6) and (random-float 1 < 0.5) [
          set tech-adopted? true
          set quality quality + (5 + random 3) * (1 - (quality / 120))
          print (word "Farmer " who " adopted via catch-up effect in year " year)
        ]
      ]
    ]
  ]

  ;; --- PRIVATE INNOVATION: every 5 years, progressive M farmers ---
  if (year mod 5 = 0) and (farmer-type = "M") and (tech-adopted? = true) and (risk-tolerance > 0.6) [
    set quality min list (quality + 20) 120
    print (word "Farmer " who " introduced a private variety in year " year)
  ]
  ;; --- Minimalist peer imitation: learn from richer neighbor ---
  let rich-peer max-one-of nearby-farmers [last-season-profit]
  if (rich-peer != nobody) and ([last-season-profit] of rich-peer > last-season-profit) [
    set quality quality + 2  ;; imitate better practices
  ]
  ;; --- RISK TOLERANCE ADJUSTMENT BASED ON PROFIT ---
  ifelse last-season-profit < profit [
    set risk-tolerance min list 1 (risk-tolerance + 0.1)
  ][
    set risk-tolerance max list 0 (risk-tolerance - 0.1)
  ]

  set under-contract? false

  ;; --- PRODUCTION LOGIC (all produce sold on-tree) ---
  let base-yield (ifelse-value (farmer-type = "L") [1.5] [ifelse-value (farmer-type = "M") [1.2] [0.9]])
  let yield-shock (ifelse-value (farmer-type = "S") [random-normal 0 0.04] [random-normal 0 0.01])
  let season-progress (ticks mod 30) / 30
  let supply-multiplier exp(-((season-progress - 0.5) ^ 2) / (2 * 0.4 ^ 2))
  let max-production farm-size * (base-yield + (min list 0.5 (quality / 1200)) + yield-shock) * supply-multiplier

  let produced max list 0 (min list max-production (market-demand / count farmers))
  let pre-loss 0
  if climate-shock-active? or pest-outbreak-active? [
    let tech-multiplier ifelse-value (tech-adopted? = true) [0.4] [1.0]
    let type-multiplier ifelse-value (farmer-type = "L") [ 1.0 ] [ ifelse-value (farmer-type = "M") [ 1.1 + random-float 0.1 ] [ 1.3 + random-float 0.15 ] ]
    let base-loss farm-size * (0.10 + random-float 0.06) * type-multiplier * tech-multiplier
    let risk-factor risk-tolerance * 0.5
    let quality-factor (1 - (quality / 100)) * 0.3
    let raw-pre-loss base-loss * (1 + risk-factor + quality-factor)
    set pre-loss min list raw-pre-loss (produced * 0.05)
  ]
  set sold-amount max list 0 (produced - pre-loss)
  set inventory sold-amount
  ;; Ensure never negative inventory
  if inventory < 0 [ set inventory 0 ]

  ;; --- CONTRACT LOGIC (staggered, probabilistic, per farmer) ---
  let contract-chance 1
  if farmer-type = "L" [ set contract-chance 0.95 ]
  if farmer-type = "M" [ set contract-chance 0.65 ]
  if farmer-type = "S" [ set contract-chance 0.35 ]
  if last-season-profit < 0 [ set contract-chance contract-chance + 0.1 ]
  set contract-chance min list 1 contract-chance

  if (not under-contract?) and (sold-amount > 0) and (random-float 1 < contract-chance) [
    let possible-contractors contractors with [capital-available > 0]
    if any? possible-contractors [
      let chosen-contractor max-one-of possible-contractors [capital-available]
      let max-affordable ([capital-available] of chosen-contractor) / market-price
      let transfer-amount min list sold-amount max-affordable
      if transfer-amount > 0 [
        ask chosen-contractor [
          set inventory inventory + transfer-amount
          set capital-available capital-available - (transfer-amount * market-price)
        ]
        set profit profit + (transfer-amount * market-price)
        ifelse transfer-amount < sold-amount [
          set farmer-preharvest-loss farmer-preharvest-loss + (sold-amount - transfer-amount)
          set inventory max list 0 (sold-amount - transfer-amount)
        ] [
          set inventory 0
        ]
        set under-contract? true
        set current-contractor chosen-contractor
      ]
    ]
  ]

  ;; --- RANDOM SEASONAL SHOCK (bad luck) ---
  if random-float 1 < (ifelse-value (farmer-type = "S") [0.18] [0.06]) [
    let shock-loss random-normal 100 50
    set profit profit - shock-loss
  ]
  ;; --- SMALL and Medium FARMER WINDFALL CHANCE ---
  if (member? farmer-type ["S" "M"]) [
    if (farmer-type = "S") and (random-float 1 < 0.07) [
      let windfall random-normal 100 30
      set profit profit + windfall
    ]
    if (farmer-type = "M") and (random-float 1 < 0.04) [
      let windfall random-normal 70 20
      set profit profit + windfall
    ]
  ]

  ;; --- STATE UPDATE ---
  set color scale-color green quality 40 90
  set last-season-profit profit
  set last-season-loss farmer-preharvest-loss
  set last-season-inventory inventory
  set last-sold-amount sold-amount
  set season-count season-count + 1
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Contractor Decision Logic: Ensures Contracts Are Always Accepted
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to contractor-decisions
  ;; === 1. SEASONAL LEARNING & ADAPTATION (every 30 ticks) ===
  if ticks mod 30 = 0 [
    let margin-change 0.02
    let mutation random-normal 0 0.005
    if profit < last-season-profit [
      set min-profit-margin max list 0.05 (min-profit-margin - margin-change + mutation)
      set operating-cost max list 1 (operating-cost * (0.97 + random-normal 0 0.01))
      set action-interval max list 1 (action-interval - 1)
    ]
    if profit > last-season-profit [
      set min-profit-margin min list 0.3 (min-profit-margin + margin-change + mutation)
      set capital-available capital-available + (profit * (0.2 + random-normal 0 0.01))
    ]
    ;; Downstream pain adaptation
    let wholesaler-count count wholesalers
    let retailer-count count retailers
    let wholesalers-profit ifelse-value (wholesaler-count > 0) [mean [profit] of wholesalers] [0]
    let retailers-profit ifelse-value (retailer-count > 0) [mean [profit] of retailers] [0]
    if (wholesalers-profit < 100) or (retailers-profit < 100) [
      set min-profit-margin max list 0.08 (min-profit-margin - 0.02)
    ]
    ;; Social learning
    if random-float 1 < 0.15 [
      let peer one-of other contractors
      if peer != nobody [
        set min-profit-margin ([min-profit-margin] of peer) + random-normal 0 0.005
      ]
    ]
    ;; Occasional random reset
    if random-float 1 < 0.02 [
      set min-profit-margin 0.08 + random-float 0.15
    ]
    ;; Enforce margin bounds
    set min-profit-margin min list 0.2 (max list 0.05 min-profit-margin)
    set last-season-profit profit
  ]

  ;; === 2. IMPROVED POSTHARVEST TECH ADOPTION (with rate tweaks) ===
  if not postharvest-tech-adopted? [
    let techadoption-rate 0.1  ;; Higher base rate (was 0.05)
    let peer-influence mean [postharvest-tech-adopted?] of other contractors

    let adoption-probability techadoption-rate + (capital-available / 70000) + (0.2 * peer-influence)
    if random-float 1 < adoption-probability [
      set postharvest-tech-adopted? true
    ]
  ]

  ;; === 3. MICRO-ADJUST MARGIN EVERY TICK ===
  ifelse profit < last-tick-profit [
    set min-profit-margin max list 0.05 (min-profit-margin - 0.002)
  ]  [
    set min-profit-margin min list 0.2 (min-profit-margin + 0.002)
  ]

  ;; === 4. HOLDING COST AND SPOILAGE (every tick) ===
  let holding-cost inventory * 0.02
  set capital-available capital-available - holding-cost
  let handling-loss-rate ifelse-value (postharvest-tech-adopted? = true) [0.003] [0.006]
  let handling-loss inventory * handling-loss-rate
  let storage-loss-rate ifelse-value (postharvest-tech-adopted? = true) [0.003] [0.007]
  let storage-losses inventory * storage-loss-rate
  let spoilage-rate 0.03
  let pest-loss ifelse-value pest-outbreak-active? [inventory * 0.1] [0]
  let climate-loss ifelse-value climate-shock-active? [inventory * 0.05] [0]
  let loss handling-loss + storage-losses + (inventory * spoilage-rate) + pest-loss + climate-loss
  set inventory max list 0 (inventory - loss)

  ;; === 5. BUY FROM FARMERS ONLY DURING INITIAL 5 TICKS OF SEASON ===
if (ticks mod 30 < 10) [
  let available-farmers shuffle (list farmers with [inventory > 0])
  let remaining-capital capital-available

foreach available-farmers [ f ->
  let farmer-stock [inventory] of f
  let max-affordable remaining-capital / market-price
  let to-buy min (list farmer-stock max-affordable)

  if to-buy > 0 [
    ask f [
      set inventory inventory - to-buy
      if inventory < 0 [ set inventory 0 ]
      set capital-available capital-available + (to-buy * market-price)
    ]
    set inventory inventory + to-buy
    set capital-available capital-available - (to-buy * market-price)
    set remaining-capital remaining-capital - (to-buy * market-price)
  ]
]
]
  ;; === 6. SELL TO WHOLESALERS (even batches per tick over season) ===
let available-wholesalers wholesalers with [capital-available > 0]
if any? available-wholesalers and (inventory > 0) [
  let ticks-left-in-season (30 - (ticks mod 30))
  let batch-size max list 1 (inventory / ticks-left-in-season)
  let chosen-wholesaler max-one-of available-wholesalers [capital-available]
  let unit-sale-price (market-price + (market-price * min-profit-margin))
  let max-affordable ([capital-available] of chosen-wholesaler) / unit-sale-price
  let transfer-amount min (list batch-size max-affordable inventory)

  if (transfer-amount > 0) [
    ask chosen-wholesaler [
      set inventory inventory + transfer-amount
      set capital-available capital-available - (transfer-amount * unit-sale-price)
      if capital-available < 0 [ set capital-available 0 ]
    ]
    set capital-available capital-available + (transfer-amount * unit-sale-price)
    set profit profit + (transfer-amount * (market-price * min-profit-margin))
    set inventory inventory - transfer-amount
    if inventory < 0 [ set inventory 0 ]
  ]
]
  if inventory < 0 [ print (word "Contractor " who " negative inventory! Fix logic!") ]
if capital-available < 0 [ print (word "Contractor " who " negative capital! Fix logic!") ]

  ;; === 7. END OF SEASON: Spoil all unsold inventory ===
  if ((ticks + 1) mod 30 = 0) [
    set inventory 0
  ]

  ;; === 8. Record last-tick-profit for next tick's margin adaptation ===
  if ((ticks + 1) mod 30 = 0) [
  set profit profit - (inventory * spoilage-rate * market-price) ;; or a % of inventory value
  set inventory 0
  ]
  set last-tick-profit profit
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; wholesaler-decisions;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to wholesaler-decisions
  ask wholesalers [
    ;; --- LEARNING/ADAPTATION BLOCK (every 30 ticks/season) ---
    if ticks mod 30 = 0 [
      let mutation random-normal 0 0.02
      let median-retailer-profit median [profit] of retailers

      if profit < last-season-profit [
        set markup min list 0.4 (markup + 0.05 + mutation)
        set operating-cost max list 1 (operating-cost * (0.98 + random-normal 0 0.01))
      ]
      if profit > last-season-profit [
        set markup max list 0.05 (markup - 0.03 + mutation)
        set capital-available capital-available + profit * (0.2 + random-normal 0 0.02)
      ]

      if median-retailer-profit < 0 [
        let min-sustainable-markup (operating-cost / (market-price + 0.001))
        set markup max list min-sustainable-markup (markup - 0.07)
      ]
      if inventory > (market-demand * 0.3) [
        set markup max list 0.05 (markup - 0.07)
      ]
      if inventory > (market-demand * 0.8) [
        set markup max list 0.05 (markup - 0.05)
      ]
      ifelse profit < 0 [
        set consecutive-negative-profit consecutive-negative-profit + 1
      ] [
        set consecutive-negative-profit 0
      ]
      if consecutive-negative-profit > 2 [
        set markup 0.1
        set consecutive-negative-profit 0
      ]
      if random-float 1 < 0.15 [
        let peer one-of other wholesalers
        if peer != nobody [
          set markup ([markup] of peer) + random-normal 0 0.03
        ]
      ]
      if random-float 1 < 0.02 [
        set markup 0.4 + random-float 0.2
      ]
      set markup min list 0.4 (max list 0.05 markup)
      set last-season-profit profit
    ]

    ;; --- TECHNOLOGY ADOPTION FOR SPOILAGE REDUCTION ---
    if not postharvest-tech-adopted? [
      let tech-adoptionrate 0.08
      let peer-influence mean [postharvest-tech-adopted?] of other wholesalers
      let adoption-probability tech-adoptionrate + (capital-available / 80000) + (0.2 * peer-influence)
      if random-float 1 < adoption-probability [
        set postharvest-tech-adopted? true
      ]
    ]

    ;; --- SPOILAGE ADJUSTMENT (lower for tech adopters) ---
    let spoilage-rate ifelse-value (postharvest-tech-adopted?) [
      ifelse-value (ticks < 60) [0.01] [0.025]
    ] [
      ifelse-value (ticks < 60) [0.02] [0.05]
    ]
    set inventory inventory * (1 - spoilage-rate)

    ;; --- GRADUAL PURCHASE FROM CONTRACTORS ---
    let target-inventory market-demand * 0.7
    if inventory < target-inventory [
      let potential-contractors contractors with [inventory > 0]
      let batch-size max list 1 ((target-inventory - inventory) / (30 - (ticks mod 30)))
      foreach shuffle (list potential-contractors) [ c ->
        let contractor-inventory [inventory] of c
        let to-buy min list batch-size contractor-inventory
        let deal-value to-buy * market-price
        if (to-buy > 0) and (capital-available >= deal-value) [
          ask c [
            set inventory inventory - to-buy
            set profit profit + deal-value
          ]
          set inventory inventory + to-buy
          set profit profit - deal-value
          set capital-available capital-available - deal-value
        ]
      ]
    ]

    ;; --- SELL TO RETAILERS ---

  let retailer-count count retailers
  if retailer-count > 0 [

    let restock-threshold (market-demand / retailer-count) * 0.5

    let potential-retailers retailers with [
      inventory < restock-threshold and capital-available > (market-price * 1.1)
    ]

    foreach shuffle sort potential-retailers [ r ->

      let wholesaler-inventory inventory
      let demand-per-retailer (market-demand / retailer-count) * 1.2

      ;; Ensure min gets two numbers, then wrap in list for max
        let raw-deal-volume min (list wholesaler-inventory demand-per-retailer)

      let deal-volume max (list 1 raw-deal-volume)

      ;; Calculate pricing
      let min-sale-price-per-unit ((operating-cost / (deal-volume + 1)) * 1.05) + market-price
      let market-adjusted-price market-price * (1 + markup)
      let selling-price max (list min-sale-price-per-unit market-adjusted-price)

      ;; Get retailer's capital
      let r-capital [capital-available] of r
      let max-affordable (r-capital / selling-price)

      ;; Determine how much can actually be sold
      let final-volume max (list 0 (min (list deal-volume max-affordable wholesaler-inventory)))
      let deal-value final-volume * selling-price

      ;; Proceed with transaction if possible
      if final-volume > 0 [

        ;; Wholesaler updates
        set inventory inventory - final-volume
        set profit profit + deal-value

        ;; Retailer updates inside ASK
        ask r [
          set inventory inventory + final-volume
          set profit profit - deal-value
          set capital-available capital-available - deal-value
          if capital-available < 0 [ set capital-available 0 ]
        ]

        ;; Optional debug message
        show (word "✅ Transaction: wholesaler " who
                   " → retailer " [who] of r
                   " | Volume: " final-volume
                   " | Price: " selling-price)
      ]
    ]
  ]



    ;; --- DYNAMIC OPERATING COSTS ---
    set operating-cost (inventory * 0.005) + (profit * 0.01) ; adjust as needed

    ;; --- PROFIT SMOOTHING (faster recovery) ---
    set profit (profit * 0.9) + (last-season-profit * 0.1)

    set last-tick-profit profit

    ;; Adaptive markup every tick
  ;; --- SMART MARKUP ADAPTATION BLOCK ---

let min-sustainable-markup ((operating-cost / (max list 1 market-price)) + 0.01)
let max-markup 0.4  ;; adjust this ceiling as you see fit

;; Example: adapt markup based on profit change
ifelse profit < last-tick-profit [
  set markup max list min-sustainable-markup (markup - 0.002)
] [
  set markup min list max-markup (markup + 0.002)
]

;; Example: adapt markup if retailers are struggling
if median [profit] of retailers < 0 [
  set markup max list min-sustainable-markup (markup - 0.07)
]

;; Example: adapt markup if overstocked
if inventory > (market-demand * 0.3) [
  set markup max list min-sustainable-markup (markup - 0.07)
]
if inventory > (market-demand * 0.8)  [
  set markup max list min-sustainable-markup (markup - 0.05)
]

;; Example: peer imitation, always bounded
if random-float 1 < 0.15 [
  let peer one-of other wholesalers
  if peer != nobody [
    let candidate-markup ([markup] of peer) + random-normal 0 0.03
set markup min list max-markup (max list min-sustainable-markup candidate-markup)
  ]
]

;; Example: rare random markup jump, always bounded
if random-float 1 < 0.02 [
  set markup max list min-sustainable-markup (min list (0.4 + random-float 0.2) max-markup)
]

;; FINAL ENFORCEMENT: keep markup between min and max
set markup min list max-markup (max list min-sustainable-markup markup)
    ; penalty for unsold stocks
    if ((ticks + 1) mod 30 = 0) [
  set profit profit - (inventory * spoilage-rate * market-price) ;; or a % of inventory value
  set inventory 0
]
  ]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; retailer-decisions;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to retailer-decisions
  ask retailers [
    ;; --- Parameters & Demand Estimation ---
    let base-discount-factor 0.5
    let retailer-count count retailers
    let expected-demand 0
    if retailer-count > 0 [
      set expected-demand (market-demand / retailer-count) * (1 + random-normal 0 0.08)
    ]

    ;; --- Track PRE-purchase state ---
    let inventory-before inventory
    let profit-before profit
    let capital-before capital-available

    ;; --- Buy from wholesalers: only what you expect to sell ---
    let purchase-price-per-unit 0
    let bought 0
    if any? wholesalers with [inventory > 0] [
      let chosen-wholesaler max-one-of wholesalers with [inventory > 0] [inventory]
      let price ([market-price] of chosen-wholesaler) * (1 + [markup] of chosen-wholesaler)
      let max-affordable min (list expected-demand (capital-available / price) ([inventory] of chosen-wholesaler))
      if max-affordable > 0 [
        set bought max-affordable
        set purchase-price-per-unit price
        set capital-available capital-available - (bought * price)
        set profit profit - (bought * price)
        set inventory inventory + bought
        ask chosen-wholesaler [
          set inventory inventory - bought
          set profit profit + (bought * price)
        ]
      ]
    ]

    ;; --- Sorting: now split **total inventory** into grades ---
    let grade-b inventory * dynamic-sort-rate
    let grade-a inventory - grade-b

    ;; --- Sell to consumers from total inventory (robust logic) ---
    let sales-a min list grade-a expected-demand
    let leftover-demand max list 0 (expected-demand - sales-a)
    let sales-b min list grade-b leftover-demand

    let selling-price-per-unit market-price * (1 + markup)
    let revenue (sales-a * selling-price-per-unit) + (sales-b * selling-price-per-unit * base-discount-factor)

    set profit profit + revenue
    set capital-available capital-available + revenue
    set inventory inventory - (sales-a + sales-b)

    ;; --- Discard unsold mangoes at loss ---
    let unsold-a grade-a - sales-a
    let unsold-b grade-b - sales-b
    if (unsold-a + unsold-b) > 0 [
      set profit profit - ((unsold-a + unsold-b) * market-price)
      set inventory inventory - (unsold-a + unsold-b)
    ]

    ;; --- Fixed cost ---
    set profit profit - 2

    ;; --- Track POST-sales state & print ---
    let inventory-after inventory
    let profit-after profit
    let capital-after capital-available
    let amount-sold sales-a + sales-b

    print (word
      "Retailer " who
      " | Bought: " bought " @ " purchase-price-per-unit
      " | Sold: " amount-sold " @ " selling-price-per-unit
      " | Expected Demand: " expected-demand
      " | Inventory before: " inventory-before " after: " inventory
      " | Profit before: " profit-before " after: " profit
      " | Capital before: " capital-before " after: " capital-available)

    ;; --- Learning/Adaptation ---
    if profit < last-tick-profit [
      set markup max list 0.1 (markup - 0.05)
      set dynamic-sort-rate max list 0.1 (dynamic-sort-rate - 0.01)
    ]
    if profit > last-tick-profit [
      set markup min list 1.0 (markup + 0.05)
      set dynamic-sort-rate min list 0.5 (dynamic-sort-rate + 0.01)
    ]
    set last-tick-profit profit

    ;; --- Optional: Bankruptcy/cash injection ---
    if capital-available < 0 [
      set capital-available capital-available + (market-price * 80)
      set profit profit - 200
    ]
  ]
end
; =========
; MARKET DYNAMICS
; ======================
to update-market-conditions
  ;; Determine Season or Off-Season
  let season-length 30
  let current-tick ticks mod (season-length + 10)


  ;; === Seasonal Multiplier ===
  let season-progress (current-tick / season-length)
; U-shape: lowest at middle, higher at ends (use a wide Gaussian or quadratic)
let u_shape 1 + 0.5 * (abs(season-progress - 0.5) / 0.5)
set current-season-multiplier u_shape + random-normal 0 0.05

  ;; === Quality Adjustment ===
  let farmers-with-inventory farmers with [inventory > 0]
  set current-quality-bonus ifelse-value (any? farmers-with-inventory) [
    1 + ((mean [quality] of farmers-with-inventory) - 60) / 100
  ][
    1.0
  ]

  ;; === Supply-Demand Adjustment ===
  let total-supply sum [inventory] of turtles with [breed != farmers]
  let total-demand market-demand
  let supply-demand-ratio ifelse-value (total-supply > 0) [
    max list 0.2 (min list 6.0 (total-demand / total-supply))
  ][
    6.0
  ]

  ;; === Adjust Market Demand ===
let price-elasticity -0.5
;; Adjust the multiplier to match  supply scale.
;; For your case, since total supply is often 20,000+, use 20000 as multiplier.
set market-demand max list 2000 (min list 40000 (20000 * (market-price / 20) ^ (price-elasticity * 0.5)))
set market-demand market-demand * (1 + random-normal 0 0.05)

  ;; === Dynamic Base Price ===
  set base-price max list 10 (min list 100 (base-price * (1 + random-float 0.02 - 0.01)))

  ;; === Calculate Final Market Price ===
 ; set market-price base-price * current-season-multiplier * current-quality-bonus * (0.5 + supply-demand-ratio * 0.5)
  set market-price base-price * current-season-multiplier * current-quality-bonus * (1 + 0.2 * (supply-demand-ratio - 1)); gentler chnage in the price
 set market-price max list 15 (min list 150 market-price); (floor 15,  Cieling 150)
 ;;;;Depression based on over-supply
  let totalsupply sum [inventory] of turtles with [breed != farmers]
 let totaldemand market-demand
  let oversupply-factor ifelse-value (total-supply > total-demand) [
  (total-demand / total-supply) ^ 0.25
][
  1
]


  ;; === Debugging Information ===
  print (word "DEBUG: Base Price: " base-price)
  print (word "DEBUG: Season Multiplier: " current-season-multiplier)
  print (word "DEBUG: Quality Bonus: " current-quality-bonus)
  print (word "DEBUG: Total Supply: " total-supply)
  print (word "DEBUG: Total Demand: " total-demand)
  print (word "DEBUG: Supply-Demand Ratio: " supply-demand-ratio)
  print (word "DEBUG: Updated Market Price: " market-price)
end
; ======================
; FOOD LOSS
; ======================
to calculate-food-loss
  ;; === Compute Pre-Harvest Loss Dynamically ===
  ifelse climate-shock-active? [
    ;; Calculate pre-harvest loss for each farmer dynamically
    ask farmers [
      if random-float 1 < 0.5 [
        ;; Loss depends on farm size, risk tolerance, and quality
        let tech-multiplier ifelse-value (tech-adopted? = true) [0.6] [1.0] ; 20% reduction if adopted
        let type-multiplier
            ifelse-value (farmer-type = "L") [ 1.0 ]
                                       [ ifelse-value (farmer-type = "M") [ 1.4 + random-float 0.2 ]
                                            [ 1.8 + random-float 0.3 ]
                                                                       ]
        let base-loss farm-size * (0.06 + random-float 0.02) * type-multiplier * tech-multiplier
        let risk-factor risk-tolerance * 0.5  ;; High risk-tolerant farmers suffer more losses
        let quality-factor (1 - (quality / 100)) * 0.2  ;; Lower quality increases losses
        let total-loss base-loss * (1 + risk-factor + quality-factor)
        set farmer-preharvest-loss total-loss
        set inventory max list 0 (inventory - total-loss)  ;; Reduce inventory
      ]
    ]
    set total-preharvest-loss sum [farmer-preharvest-loss] of farmers
    print (word "Tick: " ticks " | Total Pre-Harvest Loss (Climate Shock Active): " total-preharvest-loss)
  ] [
    if ticks mod 30 = 0 [
      let season-factor 1 + (ticks / 3000)  ; Gradually increases spoilage every 600 ticks
      ask farmers [
        set farmer-preharvest-loss farmer-preharvest-loss * season-factor
      ]
      set total-preharvest-loss sum [farmer-preharvest-loss] of farmers
      print (word "Tick: " ticks " | No Climate Shock — Pre-Harvest Loss Decaying: " total-preharvest-loss)
    ]
  ]

  ;; === Compute Post-Harvest Loss Dynamically ===

  let contractor-loss 0
  ask contractors [
  ;; Handling loss: less than 1% of inventory, lower if tech adopted
  let handling-loss-rate ifelse-value (postharvest-tech-adopted? = true) [0.003] [0.006]  ; 0.3%-0.6%
  let handling-loss inventory * handling-loss-rate

  ;; Minimal storage/transport loss (optional, e.g., 0.2%)
  let storage-loss-rate 0.002
  let storage-losses inventory * storage-loss-rate

  ;; Losses due to shocks (very small, e.g., 1%)
  let shock-loss (ifelse-value pest-outbreak-active? [inventory * 0.01] [0]) +
                 (ifelse-value climate-shock-active? [inventory * 0.01] [0])

  let loss handling-loss + storage-losses + shock-loss

  set inventory max list 0 (inventory - loss)
  set contractor-loss contractor-loss + loss
]

print (word "Tick: " ticks " | Contractor Loss: " contractor-loss)

  let wholesaler-loss 0
ask wholesalers [
  ;; Minimal storage loss, dynamic if tech is adopted
  let storage-loss-rate ifelse-value (postharvest-tech-adopted? = true) [0.003] [0.007]  ; 0.3% or 0.7%
  let storages-loss inventory * storage-loss-rate

  ;; Shocks, still possible but small
  let shock-loss (ifelse-value pest-outbreak-active? [inventory * 0.01] [0]) +
                 (ifelse-value climate-shock-active? [inventory * 0.01] [0])

  ;; Holding cost for keeping inventory (e.g., 0.5% per tick)
  let holding-cost inventory * 0.005
  set capital-available capital-available - holding-cost

  let loss storages-loss + shock-loss
  set inventory max list 0 (inventory - loss)
  set wholesaler-loss wholesaler-loss + loss
]
print (word "Tick: " ticks " | Wholesaler Loss: " wholesaler-loss)

  let retailer-loss 0
ask retailers [
  ;; Minimal handling loss (e.g., 0.5%)
  let handling-loss inventory * 0.005

  ;; Spoilage loss (dynamic, depends on quality)
  let spoilage-rate (1 - (quality / 100)) * 0.01
  let spoilage-loss inventory * spoilage-rate

  ;; Pest and climate shocks (if not handled upstream)
  let shock-loss (ifelse-value pest-outbreak-active? [inventory * 0.01] [0]) +
                 (ifelse-value climate-shock-active? [inventory * 0.005] [0])

  ;; Remove all losses from current inventory
  let total-loss handling-loss + spoilage-loss + shock-loss
  set inventory max list 0 (inventory - total-loss)
  set retailer-loss retailer-loss + total-loss
]
print (word "Tick: " ticks " | Retailer Loss: " retailer-loss)

  ;; === Update Global Loss Values ===
  set total-postharvest-loss contractor-loss + wholesaler-loss + retailer-loss
  set total-food-loss total-preharvest-loss + total-postharvest-loss

  ;; === Debugging Outputs ===
  print (word "Tick: " ticks " | Total Pre-Harvest Loss: " total-preharvest-loss)
  print (word "Tick: " ticks " | Total Post-Harvest Loss: " total-postharvest-loss)
  print (word "Tick: " ticks " | Total Food Loss: " total-food-loss)
end
; ======================
; VISUALIZATION
; ======================

to update-display
  ;; Season indicator (background color)
  let month (ticks mod 12)
  ifelse (month >= 3 and month <= 8) [
    ask patches [ set pcolor scale-color green month 3 8 ]  ; Green during season
  ][
    ask patches [ set pcolor gray ]  ; Gray off-season
  ]
  ask farmers [
    set size 0.3 + (farm-size / 150)
    set color scale-color yellow quality 40 90  ; Yellow = mango color
    set label ifelse-value ((ticks mod 12) >= 3 and (ticks mod 12) <= 8)
      [ "🍏" ]  ; Mango emoji during season
      [ "" ]
  ]

  ask turtles with [breed != farmers] [
    set color scale-color blue profit -1000 10000
  ]


  ask transactions [
    set thickness 0.1 + (transaction-volume / 200)
    set color scale-color red duration 1 6
  ]


  ;;;spoilage indication;;;
  ask contractors with [inventory > 0] [
    set shape "truck"
    set color scale-color red (inventory * (transport-loss / 100)) 0 50
  ]

  ask wholesalers with [inventory > 0] [
    set color scale-color orange (inventory * (storage-loss / 100)) 0 50
  ]
set-current-plot "Profit by Agent Type"
;;; Plotting profits bt breed;;;;;

set-current-plot-pen "Contractors"
plot mean [profit] of contractors

set-current-plot-pen "Commission Agents"
plot mean [profit] of commission-agents

set-current-plot-pen "Wholesalers"
plot mean [profit] of wholesalers

set-current-plot-pen "Retailers"
plot mean [profit] of retailers
 ;;;;;

 set-current-plot "Quality vs Profit of farmers"
set-current-plot-pen "default"
ask farmers with [quality > 0 and profit != 0] [
  plotxy quality profit
]
set-current-plot "Shocks Over Time"
set-current-plot-pen "Climate Shock"
plot (ifelse-value climate-shock-active? [1] [0])
set-current-plot-pen "Pest Shock"
plot (ifelse-value pest-outbreak-active? [1] [0])

set-current-plot "Shocks Over Time"
ifelse climate-shock-active? [ plot 1 ] [ plot 0 ]
plot (ifelse-value pest-outbreak-active? [1] [0])

 ;; Plot farm size vs pre-harvest loss
  set-current-plot "Farm Size vs Pre-Harvest Loss"  ;; Switch to the correct plot
  clear-plot  ;; Clear the plot for new data

  ;; Create a temporary pen for the scatter plot
  create-temporary-plot-pen "dot-pen"  ;; Name the pen
  set-plot-pen-mode 1  ;; Set to "dot" mode (0 = line, 1 = dot, 2 = bar)

  ;; Plot each farmer's data
  ask farmers [
    plotxy farm-size farmer-preharvest-loss
  ]
end

; ======================
; UTILITY
; ======================

to check-environmental-risks

  set climate-shock-active? (random-float 1.0 < climate-shock-probability)
  set pest-outbreak-active? (random-float 1.0 < pest-outbreak-probability)

  ;; Debugging Output
  print (word "Climate Shock Active? " climate-shock-active?)
  print (word "Pest Outbreak Active? " pest-outbreak-active?)

end


to maintain-contracts
  ; Just a placeholder for now
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;; Contract-formation;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;
to form-contracts
  ask farmers [
    ;; Only form contracts at the start of the season
    if (ticks mod 30 = 0) [
      let contract-amount sold-amount
      ;; Use actual inventory
      while [contract-amount > 0 and inventory > 0] [
        let potential-contractors contractors with [capital-available > 0 and count my-in-links < 5]
        if not any? potential-contractors [
          set farmer-preharvest-loss farmer-preharvest-loss + contract-amount
          show (word "Farmer " who " could not sell " contract-amount " units due to contractor cash limit.")
          stop
        ]
        let chosen-contractor max-one-of potential-contractors [capital-available]
        let max-affordable ([capital-available] of chosen-contractor) / market-price
        let actual-amount min (list contract-amount max-affordable inventory)
        if actual-amount < 1 [
          set farmer-preharvest-loss farmer-preharvest-loss + contract-amount
          show (word "Farmer " who " could not sell " contract-amount " units due to contractor cash limit or no inventory.")
          stop
        ]
        ;; Create the contract:
        create-transaction-to chosen-contractor [
          set transaction-volume actual-amount
          set transaction-value actual-amount * market-price
          set duration 30
        ]
        set transactions-this-tick transactions-this-tick + 1
        set under-contract? true
        set current-contractor chosen-contractor
        set profit profit + (actual-amount * market-price)
        set inventory inventory - actual-amount
        if inventory < 0 [ set inventory 0 ] ;; Clamp, just in case
        ask chosen-contractor [
          set capital-available capital-available - (actual-amount * market-price)
        ]
        show (word "Farmer " who " formed a contract with Contractor " [who] of chosen-contractor
                   " for " actual-amount " units and upfront payment of "
                   (actual-amount * market-price))
        set contract-amount contract-amount - actual-amount
      ]
    ]
  ]
end

to update-transactions
  let transaction-count 0
  let invalid-transaction-count 0

ask transactions [
  set duration duration - 1
  if duration <= 0 [
    let seller end1
    let buyer end2
    let volume transaction-volume
    let value transaction-value
    let seller-inv [inventory] of seller
    let buyer-cap [capital-available] of buyer

    ;; Enforce farmer window: skip if seller is farmer and outside first 10 ticks
      if ([breed] of seller = farmers) and ((ticks mod 30) >= 10) [
          set invalid-transaction-count invalid-transaction-count + 1
      print (word "❌ Transaction skipped: Farmer not in active window. Tick: " ticks)
      die
      stop
    ]

    ;; Guard: skip if seller has no inventory
    if seller-inv <= 0 [
      set invalid-transaction-count invalid-transaction-count + 1
      print (word "❌ Transaction failed: Seller Inventory - " seller-inv ", Buyer Capital - " buyer-cap)
      die
      stop
    ]

    ;; Always use real current inventory/capital for this transaction
    let final-volume min (list volume seller-inv (buyer-cap / market-price))
    ifelse final-volume > 0 [
      let final-value final-volume * market-price
      print (word "✅ Transaction: Seller " [who] of seller " to Buyer " [who] of buyer " | Volume: " final-volume " | Value: " final-value)
      ask seller [
        set inventory inventory - final-volume
        if inventory < 0 [ set inventory 0 ]
        let cost-per-unit ifelse-value (breed = farmers) [production-cost] [inventory-cost-per-unit]
        set profit profit + (final-value - (final-volume * cost-per-unit))
      ]
      ask buyer [
        set inventory inventory + final-volume
        set profit profit - final-value
        set capital-available max list 0 (capital-available - final-value)
      ]
      set transaction-count transaction-count + 1
    ] [
      set invalid-transaction-count invalid-transaction-count + 1
      print (word "❌ Transaction failed: Not enough inventory or capital.")
    ]
    die
  ]
]
end
;;;;;;;;;;;;;;;;;;;;;;;;
to apply-pest-losses;;;;;
  ;; Farmers: Pre-harvest pest losses are already calculated in `calculate-food-loss`

  ;; Contractors: Pest spoilage (10%)
  ask contractors [
    let pest-loss inventory * 0.1
    set inventory max list 0 (inventory - pest-loss)
    print (word "Contractor " who ": Pest Loss = " pest-loss)
  ]

  ;; Wholesalers: Pest spoilage (5%)
  ask wholesalers [
    let pest-loss inventory * 0.05
    set inventory max list 0 (inventory - pest-loss)
    print (word "Wholesaler " who ": Pest Loss = " pest-loss)
  ]

  ;; Retailers: Pest spoilage (5%)
  ask retailers [
    let pest-loss inventory * 0.05
    set inventory max list 0 (inventory - pest-loss)
    print (word "Retailer " who ": Pest Loss = " pest-loss)
  ]
end


 to updateplots
  ;; ===== 1. QUALITY PLOTS =====
  set-current-plot "Quality Distribution"
  set-current-plot-pen "quality-histogram"
  set-plot-pen-interval 5
  let qualified-farmers farmers with [quality > 0]
  if any? qualified-farmers [
    histogram [quality] of qualified-farmers
  ]

  set-current-plot "Mean Quality Over Time"

set-current-plot-pen "Mean Quality"
if any? farmers with [quality > 0] [
  plot mean [quality] of farmers with [quality > 0]
]

set-current-plot-pen "Large Farmers"
if any? farmers with [farmer-type = "L" and quality > 0] [
  plot mean [quality] of farmers with [farmer-type = "L" and quality > 0]
]

set-current-plot-pen "Small Farmers"
if any? farmers with [farmer-type = "S" and quality > 0] [
  plot mean [quality] of farmers with [farmer-type = "S" and quality > 0]
]

  ;; ===== 2. SHOCK INDICATORS =====
  set-current-plot "Shocks Over Time"

set-current-plot-pen "Climate Shock"
plot (ifelse-value climate-shock-active? [1] [0])

set-current-plot-pen "Pest Shock"
plot (ifelse-value pest-outbreak-active? [1] [0])

  set-current-plot "Profit Inequality"
  set-current-plot-pen "Farmer Profit Std Dev"
  let farmers-with-profit farmers with [is-number? profit]
  if count farmers-with-profit > 1 [
    plot standard-deviation [profit] of farmers-with-profit
  ]



  ;; ===== FOOD LOSS TRACKING =====
  set-current-plot "Pre-Harvest Loss Over Time"
  set-current-plot-pen "Pre-harvest Loss"
  plot total-preharvest-loss

  set-current-plot "Post-harvest Loss Over Time"
  set-current-plot-pen "Post-harvest Loss"
  plot total-postharvest-loss

  set-current-plot "Total Food Loss"
  set-current-plot-pen "Total Loss"
  plot total-food-loss



    ;; ===== 5. PRICE COMPONENTS =====
  set-current-plot "Price Components"
  set-current-plot-pen "Season Multiplier"
  plot current-season-multiplier

  set-current-plot-pen "Quality Bonus"
  plot current-quality-bonus

  set-current-plot-pen "Market Price"
  plot market-price

  ;; ===== 6. AGENT-TYPE PROFITS (FIXED) =====
  set-current-plot "Profit by Agent Type"

    ;; Contractors
  set-current-plot-pen "Contractors"
  let contractor-agents contractors with [is-number? profit]
  if any? contractor-agents [ plot mean [profit] of contractor-agents ]

  ;; Commission Agents
  set-current-plot-pen "Commission Agents"
  let commissionagents commission-agents with [is-number? profit]
  if any? commission-agents [ plot mean [profit] of commission-agents ]

  ;; Wholesalers;;
  set-current-plot-pen "Wholesalers"
  let wholesaler-agents wholesalers with [is-number? profit]
  if any? wholesaler-agents [ plot mean [profit] of wholesaler-agents ]

  ;; Retailers;;
  set-current-plot-pen "Retailers"
  let retailer-agents retailers with [is-number? profit]
  if any? retailer-agents [ plot mean [profit] of retailer-agents ]


set-current-plot "Farm Size vs Pre-Harvest Loss"
create-temporary-plot-pen "dot-pen"
set-plot-pen-mode 1  ;; dot mode
ask farmers [
  plotxy farm-size farmer-preharvest-loss
]
 set-current-plot "Farmer Profit Extended"

; All Farmers
set-current-plot-pen "All Farmers"
let farmer-agents farmers with [is-number? profit]
if any? farmer-agents [ plot mean [profit] of farmer-agents ]
show (word "All Farmers: " count farmer-agents)

; Large Farmers
set-current-plot-pen "Large Farmers"
 let large-farmers farmers with [farmer-type = "L" and is-number? profit]
if any? large-farmers [ plot mean [profit] of large-farmers ]
show (word "Large Farmers: " count large-farmers)

  ; Medium Farmers
 set-current-plot-pen  "Medium farmers"
let Medium-farmers farmers with [farmer-type = "M" and is-number? profit]
if any? Medium-farmers[ plot mean [profit] of Medium-farmers ]
show (word "Small Farmers: " count Medium-farmers)

; Small Farmers
set-current-plot-pen "Small Farmers"
let small-farmers farmers with [farmer-type = "S" and is-number? profit]
if any? small-farmers [ plot mean [profit] of small-farmers ]
show (word "Small Farmers: " count small-farmers)

tick

end
to to-check
  show (word "Total Unsold Inventory: " unsold-inventory)
  show (word "Total Farmer Profit: " sum [profit] of farmers)
  show (word "Total Contractor Profit: " sum [profit] of contractors)
  show (word "Total Retailer Profit: " sum [profit] of retailers)
  show (word "Total Farmer Inventory: " sum [inventory] of farmers)
  show (word "Total Contractor Inventory: " sum [inventory] of contractors)
  show (word "Total Retailer Inventory: " sum [inventory] of retailers)

  show (word "Total wholesaler Profit: " sum [profit] of wholesalers)
  show (word "Total wholesaler Inventory: " sum [inventory] of wholesalers)
  show (word "Market Price: " market-price)
  show (word "Market Demand: " market-demand)
  show (word "Contractor Capital: " sum [capital-available] of contractors)

end
to-report scheduled-adoption-bonus [planned-year]

  if planned-year = 1 [ report 20 + random 5 ]
  if planned-year = 2 [ report 15 + random 5 ]
  if planned-year = 3 [ report 10 + random 3 ]
  if planned-year >= 4 [ report 8 + random 3 ]
end


 to debug-summary
  if ticks mod 30 = 0 [
    print (word "======== SEASON SUMMARY (Year: " year " Tick: " ticks ") ========")
    print (word "Mean Farmer Profit: " mean [profit] of farmers)
    print (word "Mean Farmer Cost: " mean [production-cost] of farmers)
    print (word "Mean Farmer Quality: " mean [quality] of farmers)
    print (word "Mean Farmer Inventory: " mean [inventory] of farmers)
    print (word "Mean Market Price: " market-price)
    print (word "Total Pre-Harvest Loss: " total-preharvest-loss)
    print (word "Total Post-Harvest Loss: " total-postharvest-loss)
    print (word "Total Food Loss: " total-food-loss)
    print (word "Total Profit (all agents): " total-profit)
    print (word "Unsold Inventory: " unsold-inventory)
    print (word "Total Farmer inventory: " sum [inventory] of farmers)
print (word "Total Contractor inventory: " sum [inventory] of contractors)
print (word "Total Wholesaler inventory: " sum [inventory] of wholesalers)
print (word "Total Retailer inventory: " sum [inventory] of retailers)
    print (word "==============================================")
  ]
end

to end-season
  ;; Reset contracts, inventory, and profit for all agents
  ask farmers [
    set under-contract? false
    set inventory 0
  ;  set profit 0
  ]
  ask contractors [


    set inventory 0
   ; set profit 0
  ]
  ask wholesalers [
    set inventory 0
   ; set profit 0
  ]
  ask retailers [
    set inventory 0
    ;set profit 0
  ]

end
to log-state
  show (word "Tick: " ticks)
  show (word "Farmers with inventory: " count farmers with [inventory > 0])
  show (word "Contractors with inventory: " count contractors with [inventory > 0])
  show (word "Retailers ready to buy: " count retailers with [capital-available > 0 and inventory < 10])
  show (word "Farmers acting this tick: " count farmers with [next-action-tick = ticks])
show (word "Contractors acting this tick: " count contractors with [next-action-tick = ticks])
show (word "Wholesalers acting this tick: " count wholesalers with [next-action-tick = ticks])
show (word "Retailers buying this tick: " count retailers with [inventory < 10 and capital-available > 0])

end
to temp-debug

  if (ticks = 5 or ticks = 15 or ticks = 30) [
  show (word "===== INVENTORY SNAPSHOT AT TICK " ticks " =====")

  ;; Farmers
  ask farmers [
    show (word "👨‍🌾 Farmer " who " | Inventory: " inventory " | Capital: " capital-available)
  ]

  ;; Contractors
  ask contractors [
    show (word "🚚 Contractor " who " | Inventory: " inventory " | Capital: " capital-available)
  ]

  ;; Retailers
  ask retailers [
    show (word "🏪 Retailer " who " | Inventory: " inventory " | Capital: " capital-available)
  ]

  show "========================================"
]
end

to log-all-agent-data
  file-open data-log-file
  ;; Write header if it's the first tick
  if ticks = 0 [
    file-print "tick,season,agent-type,who,profit,last-season-profit,last-tick-profit,inventory,capital-available,operating-cost,production-cost,quality,tech-adopted,postharvest-tech-adopted,markup,min-profit-margin,farmer-type,farm-size,risk-tolerance,sold-amount,last-sold-amount,farmer-preharvest-loss,under-contract,planned-adoption-year,actions-this-season,consecutive-negative-profit"
  ]

  ;; Farmers
  ask farmers [
    file-print (word
      ticks "," year ",farmer," who "," profit "," last-season-profit "," last-tick-profit "," inventory "," capital-available "," operating-cost "," production-cost "," quality ","
      tech-adopted? ",,"     ;; postharvest-tech-adopted, markup, min-profit-margin (not used for farmers)
      "," farmer-type "," farm-size "," risk-tolerance "," sold-amount "," last-sold-amount "," farmer-preharvest-loss "," under-contract? "," planned-adoption-year ",,") ;; actions-this-season, consecutive-negative-profit not used
  ]

  ;; Contractors
  ask contractors [
  file-print (word
    ticks "," year ",contractor," who "," profit "," last-season-profit "," last-tick-profit "," inventory "," capital-available "," operating-cost ",,"
    quality "," postharvest-tech-adopted? ",,,"
    min-profit-margin ",,,," ;; markup column is left blank
    actions-this-season ",,")
]
  ;; Wholesalers
  ask wholesalers [
  file-print (word
    ticks "," year ",wholesaler," who "," profit "," last-season-profit "," last-tick-profit "," inventory "," capital-available "," operating-cost ",,"
    quality "," postharvest-tech-adopted? ","
    markup ",,,,"        ;; min-profit-margin and other farmer fields left blank
    ",," actions-this-season "," consecutive-negative-profit)
]

  ;; Retailers
  ask retailers [
    file-print (word
      ticks "," year ",retailer," who "," profit "," last-season-profit "," last-tick-profit "," inventory "," capital-available "," operating-cost ",,"
      quality ",,,"
      markup ",,,,,,,,") ;; Only markup used for retailers, other columns are blank for CSV alignment
  ]

  ;; Commission Agents
  ask commission-agents [
    file-print (word
      ticks "," year ",commission-agent," who "," profit ",,,," capital-available "," operating-cost ",,,,,,,,,,,,,,,") ;; Only relevant fields filled, the rest are blanks for alignment
  ]

  file-close
end

to log-global-stats
  file-open "mango_global_summary.csv"
  if ticks = 0 [
    file-print "tick,season,total-food-loss,total-profit,market-price,market-demand,unsold-inventory"
  ]
  file-print (word ticks "," year "," total-food-loss "," total-profit "," market-price "," market-demand "," unsold-inventory)
  file-close
end
to update-season
  set season floor (ticks / 30) + 1
end
@#$#@#$#@
GRAPHICS-WINDOW
313
66
625
379
-1
-1
9.212121212121213
1
10
1
1
1
0
1
1
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
9
15
73
48
NIL
Setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
86
16
149
49
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
630
165
886
315
Total Food Loss
ticks
Volume
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total Loss" 1.0 0 -2674135 true "" ""

PLOT
630
12
881
162
Total Profit Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" "plot total-profit"
PENS
"total-profit" 1.0 0 -16777216 true "" ""

PLOT
887
13
1133
161
Market-price
NIL
NIL
0.0
10.0
0.0
60.0
true
false
"" ""
PENS
"market-price" 1.0 0 -16777216 true "" "plot market-price"

PLOT
893
165
1136
315
Quality Distribution
NIL
NIL
1.0
100.0
0.0
20.0
true
false
"" ""
PENS
"quality-histogram" 1.0 1 -7500403 true "" ""

PLOT
629
318
877
468
Mean Quality Over Time
ticks
Mean Quality
0.0
10.0
0.0
10.0
true
true
"" "\n\n\n"
PENS
"Mean Quality" 1.0 0 -16777216 true "" ""
"Large Farmers" 1.0 0 -14070903 true "" ""
"Small Farmers" 1.0 0 -2674135 true "" ""

MONITOR
1
64
156
109
Large farmers mean profit
mean [profit] of farmers with [farmer-type = \"L\"]
17
1
11

MONITOR
2
113
155
158
Small farmer profit
mean [profit] of farmers with [farmer-type = \"S\" and is-number? profit]
17
1
11

MONITOR
1
161
154
206
Large farmers mean quality
mean [quality] of farmers with [farmer-type = \"L\" and is-number? quality]
17
1
11

MONITOR
0
210
155
255
Small farmers mean quality
mean [quality] of farmers with [farmer-type = \"S\" and is-number? quality]
17
1
11

PLOT
885
314
1202
464
Profit by Agent Type
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Contractors" 1.0 0 -16777216 true "" ""
"Commission Agents" 1.0 0 -2674135 true "" ""
"Wholesalers" 1.0 0 -955883 true "" ""
"Retailers" 1.0 0 -13345367 true "" ""

PLOT
1139
164
1339
314
Quality vs Profit of farmers
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" ""

PLOT
1137
11
1337
161
Shocks Over Time
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Climate Shock" 1.0 0 -16777216 true "" ""
"Pest Shock" 1.0 0 -817084 true "" ""

PLOT
1449
319
1649
469
Farm Size vs Pre-Harvest Loss
Farm-Size
farmer-preharvest-loss
0.0
200.0
0.0
100.0
true
false
"" ""
PENS
"Farmers" 1.0 0 -16777216 true "" ""

PLOT
1343
10
1543
160
Profit Inequality
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Farmer Profit Std Dev" 1.0 0 -16777216 true "" ""

SLIDER
0
327
172
360
Preharvestloss
Preharvestloss
0
100
20.0
10
1
%
HORIZONTAL

SLIDER
0
364
172
397
postharvestloss
postharvestloss
0
100
10.0
1
1
%
HORIZONTAL

PLOT
1343
166
1543
316
Pre-Harvest Loss Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Pre-harvest Loss" 1.0 0 -955883 true "" ""

PLOT
1547
166
1747
316
Post-harvest Loss Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"Post-harvest Loss" 1.0 0 -16777216 true "" ""

PLOT
1558
10
1758
160
Price Components
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Season Multiplier" 1.0 0 -16777216 true "" ""
"Quality Bonus" 1.0 0 -7500403 true "" ""
"Market Price" 1.0 0 -2674135 true "" ""

SLIDER
5
404
195
437
climate-shock-probability
climate-shock-probability
0
1
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
4
435
199
468
pest-outbreak-probability
pest-outbreak-probability
0
1
0.05
.01
1
NIL
HORIZONTAL

MONITOR
192
454
288
499
Farmer 0 Profit
[profit] of farmer 0
17
1
11

MONITOR
294
454
414
499
contractor 0 capital
[capital-available] of contractor 0
17
1
11

MONITOR
417
454
503
499
Avg deal size
mean [transaction-volume] of transactions
17
1
11

MONITOR
507
454
564
499
NIL
Year
17
1
11

MONITOR
633
479
794
524
NIL
total-preharvest-loss
17
1
11

MONITOR
796
478
919
523
NIL
total-postharvest-loss
17
1
11

PLOT
1205
315
1440
465
Farmer Profit Extended
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"All Farmers" 1.0 0 -16777216 true "" ""
"Large Farmers" 1.0 0 -7500403 true "" ""
"Small Farmers" 1.0 0 -2674135 true "" ""
"Medium Farmers" 1.0 0 -13840069 true "" ""

MONITOR
0
248
152
293
Medium farmer profit
mean [profit] of farmers with [farmer-type = \"M\"]
17
1
11

MONITOR
0
287
151
332
Medium Farmer quality
mean [quality] of farmers with [farmer-type = \"M\" and is-number? quality]
17
1
11

MONITOR
921
476
1062
521
Wholesaler mean profit
mean [profit] of wholesalers
17
1
11

MONITOR
1062
476
1207
521
Wholesaler mean inventory
mean [inventory] of wholesalers
17
1
11

MONITOR
1210
477
1333
522
Retailer mean profit
mean [profit] of retailers
17
1
11

MONITOR
1336
476
1471
521
Unsold total inventory
sum [inventory] of turtles with [inventory > 0]
17
1
11

MONITOR
1473
475
1593
520
Agent bankruptcies
count turtles with [profit < 0]
17
1
11

MONITOR
1595
475
1722
520
Transactions per tick
transactions-this-tick
17
1
11

MONITOR
455
508
625
553
Inventory cost of Wholseller
mean [inventory-cost-per-unit] of wholesalers
17
1
11

MONITOR
269
508
448
553
NIL
mean [markup] of wholesalers
17
1
11

MONITOR
93
507
265
552
NIL
mean [inventory] of retailers
17
1
11

CHOOSER
162
63
309
108
farmer-acting-mode
farmer-acting-mode
["all-at-once"] ["staggered"]
1

@#$#@#$#@
# MANGO SUPPLY CHAIN MODEL

## PURPOSE
The model simulates a mango supply chain with multiple stakeholders (farmers, contractors, wholesalers, retailers) to:
- Analyze food loss at different stages (pre-harvest and post-harvest)
- Study profit distribution across supply chain actors
- Examine the impact of environmental shocks (climate, pests) on the system
- Explore market dynamics and price formation mechanisms

## HOW IT WORKS
The model follows these key rules:
1. **Farmers** produce mangoes based on farm size and quality, and can enter contracts with contractors
2. **Contractors** purchase from farmers and sell to wholesalers, managing capital and inventory
3. **Wholesalers** buy from contractors and sell to retailers, applying markups
4. **Retailers** sell to consumers, experiencing spoilage losses
5. **Market prices** fluctuate based on:
   - Seasonal effects (higher prices off-season)
   - Quality bonuses (better mangoes command higher prices)
   - Supply-demand balance
6. **Food loss** occurs at multiple stages:
   - Pre-harvest: Climate shocks and pest outbreaks reduce yields
   - Post-harvest: Transport and storage losses

## HOW TO USE IT
### Setup:
1. Click `setup` to initialize the model with default parameters
2. Adjust sliders if desired before setup

### Running:
1. Click `go` to run the simulation continuously
2. Use `go once` to advance one tick at a time

### Key Interface Controls:
- **Climate Shock Probability**: Adjusts likelihood of climate events
- **Pest Outbreak Probability**: Adjusts likelihood of pest events
- **Storage Available?**: Toggles whether storage facilities exist
- **Base Price**: Sets the starting market price

### Monitors:
- Track total profit, food loss, and market price in real-time
- View inventory levels by agent type

### Plots:
1. **Profit by Agent Type**: Shows earnings distribution
2. **Food Loss Over Time**: Tracks pre- and post-harvest losses
3. **Price Components**: Breaks down price factors
4. **Quality Distribution**: Shows mango quality range

## THINGS TO NOTICE
1. How small farmers (labeled "S") often struggle more than large farmers ("L")
2. The seasonal pattern in prices (every 30 ticks)
3. How environmental shocks immediately affect food loss metrics
4. The inventory buildup at different stages when market conditions change
5. How contract formation changes based on risk tolerance

## THINGS TO TRY
1. Turn off storage facilities and observe increased post-harvest losses
2. Run with frequent climate shocks to see impact on farmer profits
3. Adjust base price and watch how it affects entire supply chain
4. Compare runs with different numbers of contractors
5. Watch how quality affects prices in the "Price Components" plot

## EXTENDING THE MODEL
Possible enhancements:

1. Add consumer demand elasticity based on price changes
2. Implement learning behavior for agents over time

## NETLOGO FEATURES
Notable implementations:
1. Use of `directed-link-breed` for transactions between agents
2. Complex price calculation using multiple factors
3. Dynamic visualization with `scale-color` for agent states
4. Partial transaction handling when full conditions aren't met
5. Seasonal effects implemented through tick-modulo system

## RELATED MODELS
1. Supply Chain models in NetLogo Library
2. Agricultural Production models
3. Market Equilibrium models

## CREDITS AND REFERENCES
Developed forthe Project proposed by Dr. Anwar Shah and Dr. Nouman Ejaz
- Agricultural supply chain literature
- Food loss assessment methodologies
- Agent-based modeling of economic systems
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
