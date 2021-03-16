#lang turnstile/quicklang

(provide Int Bool Unit → #%type
         λ unit ascribe if succ pred iszero define vals
         (rename-out [typed-datum #%datum] [typed-app #%app]))

(define-base-types Int Bool Unit)
(define-type-constructor → #:arity = 2)

(define-typed-variable unit '() ⇒ Unit)

(define-typerule (define x:id e) ≫
  ---------
  [≻ (define-typed-variable x e)])

(define-primop succ add1 : (→ Int Int))
(define-primop pred sub1 : (→ Int Int))
(define-primop iszero zero? : (→ Int Bool))

;; bidirectional rules --------------------------------------------------------
;; in a typechecker, we want two operations, ie two types rules:
;; compute (=>): Env TypedTerm -> RunTerm Type
;; check (<=): Env TypedTerm Type -> RunTerm Bool

;; ----------------------------------------------------------------------------
;; λ rule

;; type rule from p103:
;; T-Abs
;;   Γ,x:T1 ⊢ e : T2
;; ---------------------
;; Γ ⊢ λx:T1.e : T1 → T2

;; type rule, split as 2 bidirectional rules:
;; T-Abs (compute)
;;   Γ,x:T1 ⊢ e ⇒ T2
;; ---------------------
;; Γ ⊢ λx:T1.e ⇒ T1 → T2

;; T-Abs (check)
;;   Γ,x:T1 ⊢ e ⇐ T2
;; ---------------------
;; Γ ⊢ λx.e ⇐ T1 → T2

;; check rule with type annotations:
;; T-Abs (check2) (λ still has type annotation)
;; Γ,x:T1 ⊢ e ⇐ T2
;;  T1 = T3
;; ---------------------
;; Γ ⊢ λx:T3.e ⇐ T1 → T2

;; bidirectional rules: with added rewrite, to specify runtime behavior
;; T-Abs (compute + rewrite)
;;   Γ, x ≫ x- : T1 ⊢ e ≫ e- ⇒ T2
;; ---------------------
;; Γ ⊢ λx:T1.e ≫ (λ- (x-) e-) ⇒ T1 → T2

;; T-Abs (check + rewrite)
;;   Γ, x ≫ e- : T1 ⊢ e ≫ e- ⇐ T2
;; ---------------------
;; Γ ⊢ λx.e ≫ (λ- (x-) e-) ⇐ T1 → T2

;; check and rewrite rules, converted to Turnstile syntax --------------

(define-typerule λ
  ;; T-Abs (compute + rewrite)
  [(λ [x:id : T1] e) ≫
   [[x ≫ x- : T1] ⊢ e ≫ e- ⇒ T2]
   ---------------------
   [⊢ (λ- (x-) e-) ⇒ (→ T1 T2)]]
  ;; T-Abs (check + rewrite)
  [(λ x:id e) ⇐ (~→ T1 T2) ≫
   [[x ≫ x- : T1] ⊢ e ≫ e- ⇐ T2]
   ---------------------
   [⊢ (λ- (x-) e-)]])

#;(define-typerule (+ e1 e2) ≫
  [⊢ e1 ≫ e1- ⇐ Int]
  [⊢ e2 ≫ e2- ⇐ Int]
  ----------------
  [⊢ (+- e1- e2-) ⇒ Int])

;; ascribe rule (p122)
(define-typerule (ascribe e (~datum as) τ) ≫
  [⊢ e ≫ e- ⇐ τ]
  --------
  [⊢ e- ⇒ τ])

;; Turnstile default check rule -----------------------------------------------
;; Γ ⊢ e ⇒ T2
;; T1 = T2
;; ----------
;; Γ ⊢ e ⇐ T1

;; other rules ----------------------------------------------------------------

;; this is a "compute" rule
#;(define-typerule (λ [x : T1] e) ≫
  [[x ≫ x- : T1] ⊢ e ≫ e- ⇒ T2]
-------------------
 [⊢ (λ- (x-) e-) ⇒  (→ T1 T2)])

(provide (rename-out [typed-quote quote]))
(define-typerule typed-quote
  [(_ ()) ≫
   ------
   [⊢ (quote- ()) ⇒ Unit]]
  [x ≫
   ---
   [#:error (type-error #:src #'x #:msg "Only empty quote supported")]])

(define-typerule typed-datum
  [(_ . n:integer) ≫
   ------------
   [⊢ (#%datum- . n) ⇒ Int]]
  [(_ . b:boolean) ≫
   ------------
   [⊢ (#%datum- . b) ⇒ Bool]]
  [(_ . x) ≫
   ------------
   [#:error (type-error #:src #'x #:msg "Unsupported literal: ~v" #'x)]])

(define-typerule (typed-app e1 e2) ≫
  [⊢ e1 ≫ e1- ⇒ (~→ T1 T2)]
  [⊢ e2 ≫ e2- ⇐ T1]
  ---------
  [⊢ (#%app- e1- e2-) ⇒ T2])

(define-typerule if
  [(_ cond thn els) ≫
   [⊢ cond ≫ cond- ⇐ Bool]
   [⊢ thn ≫ thn- ⇒ T1]
   [⊢ els ≫ els- ⇒ T2]
   [T1 τ= T2]
   ------------------------
   [⊢ (if- cond- thn- els-) ⇒ T1]]
  [(_ cond thn els) ⇐ τ_expected ≫
   [⊢ cond ≫ cond- ⇐ Bool]
   [⊢ thn ≫ thn- ⇐ τ_expected]
   [⊢ els ≫ els- ⇐ τ_expected]
   ---------------------------
   [⊢ (if- cond- thn- els-)]])

;; NOTE: Chapter 11 material starts here --------------------

#;(define-typerule (begin2 e1 e2) ≫
  [⊢ e1 ≫ e1- ⇐ Unit]
  [⊢ e2 ≫ e2- ⇒ T2]
  ------------------
  [⊢ (begin- e1- e2-) ⇒ T2])

(define-typerule (begin2-again e1 e2) ≫
  [⊢ e2 ≫ e2- ⇒ T2]
  --------
  [≻ ((λ [x : Unit] e2) e1)])

;; ;; this is a "check" rule
;; (define-typerule Γ ⊢ (λ [x : T1] t2) <=  T1 → T2
;; Γ, x:T1 ⊢ t2 <= T2
;; -------------------
;; )

;  (λ [x : Int] x)

;; ----------------------------------------------------------------------
;; Pairs
;; terms:
;; - (pair x y)
;; - (fst p)
;; - (snd p)
;;
;; types:
;; - (Pair X Y)

(provide pair fst snd Pair)

(define-type-constructor Pair #:arity = 2)

(define-typerule (pair e1 e2) ≫
  [⊢ e1 ≫ e1- ⇒ t1]
  [⊢ e2 ≫ e2- ⇒ t2]
  -----------------
  [⊢ (cons- e1- e2-) ⇒ (Pair t1 t2)])

(define-typerule (fst p) ≫
  [⊢ p ≫ p- ⇒ (~Pair t1 _)]
  ----------------------
  [⊢ (car- p-) ⇒ t1])

(define-typerule (snd p) ≫
  [⊢ p ≫ p- ⇒ (~Pair _ t2)]
  ----------------------
  [⊢ (cdr- p-) ⇒ t2])

;; ----------------------------------------------------------------------------
;; Tuples
;; terms:
;; - (tup x ...)
;; - (proj t i)

;; types:
;; - (× X ...)

(provide × (rename-out [× Tup]) tup proj)

(define-type-constructor × #:arity >= 0)

(define-typerule (tup e ...) ≫
  [⊢ e ≫ e- ⇒ τ] ...
  ------------------
  [⊢ (list- e- ...) ⇒ (× τ ...)])

;; raw macro version of tup:
#;(define-syntax (tup stx)
  (syntax-parse stx
    [(_ e ...)
     #:with [(e- τ) ...] (stx-map infer+erase #'(e ...))
     (assign-type #'(#%app- list- e- ...) #'(× τ ...))]))

;; NOTE: this used by proj for rec below
(define-typerule tup-proj
  ;; tup proj ----------------------------------------
  #;[(proj e i:nat) ≫ ; literal index, do bounds check
   [⊢ e ≫ e- ⇒ (~× τ ...)]
   #:fail-unless (< (stx-e #'i) (stx-length #'(τ ...)))
                 (format "given index, ~a, exceeds size of tuple, ~a"
                         (stx-e #'i) (stx->datum #'e))
  ----------------------
  [⊢ (list-ref- e- 'i) ⇒ #,(stx-list-ref #'(τ ...) (stx-e #'i))]]
  [(proj e i:nat) ≫ ; literal index, do pat-based bounds check
   [⊢ e ≫ e- ⇒ (~and (~× τ ...)
                     (~fail #:unless (< (stx-e #'i) (stx-length #'(τ ...)))
                            (format "given index, ~a, exceeds size of tuple, ~a"
                                    (stx-e #'i) (stx->datum #'e))))]
  ----------------------
;  [⊢ (list-ref- e- 'i) ⇒ #,(stx-list-ref #'(τ ...) (stx-e #'i))]]
  [⊢ (#%app- list-ref- e- 'i) ⇒ ($ref (τ ...) i)]]
  ;; expr index???
  ;; - neg or out of bounds index produces runtime err
  ;; - can't actually compute type statically!
  ;; - pattern matching better than proj?
#;  [(proj e i) ≫ 
   [⊢ i ≫ i- ⇐ Int]
   [⊢ e ≫ e- ⇒ (~× τ ...)]
   ----------------------
   [⊢ (list-ref- e- i-) ⇒ ???]])

;; ----------------------------------------------------------------------------
;; Records
;; terms:
;; - (rec x ...)
;; - extends (proj t id)

;; types:
;; - (rec (id = X) ...)

(provide Rec rec)

(begin-for-syntax
  (define-syntax-class fld
    (pattern [name:id (~datum =) v]))
  (define-splicing-syntax-class flds
    (pattern (~seq f:fld ...)
             #:fail-when (check-duplicate-identifier (stx->list #'(f.name ...)))
             (format "Given duplicate label: ~a"
                     (stx->datum
                      (check-duplicate-identifier
                       (stx->list #'(f.name ...)))))
             #:with (name ...) #'(f.name ...)
             ;; readability hack: enables using this stx class for both terms/tys
             #:with (e ...) #'(f.v ...)
             #:with (τ ...) #'(f.v ...)
             #:with (pat ...) #'(f.v ...))))


;; Rec type
;; Example use: (Rec (x = Int) (y = Bool)) --------------------

;; this doesnt work, because we want non s-expr syntax
;;(define-type-constructor Rec ...)

(struct Rec-internal () #:omit-define-syntaxes)

;; try 1: no stx class, uses symbolic Rec
#;(define-typerule (Rec [name:id (~datum =) τ] ...) ≫
  #:fail-when (check-duplicate-identifier (stx->list #'(name ...)))
              (format "Given duplicate label: ~a"
                      (stx->datum
                       (check-duplicate-identifier (stx->list #'(name ...)))))
  [⊢ τ ≫ τ- ⇐ :: #%type] ...
  ----------------
  ;; TODO: use a literal id instead of 'Rec
  ;; - otherwise, someone could create a fake Rec type
    [⊢ (list- 'Rec ['name τ-] ...) ⇒ :: #%type])

;; try 2: with stx class, uses symbolic Rec
#;(define-typerule (Rec fs:flds) ≫
  [⊢ fs.τ ≫ τ- ⇐ :: #%type] ...
  ----------------
  ;; TODO: use a literal id instead of 'Rec
  ;; - otherwise, someone could create a fake Rec type
    [⊢ (list- 'Rec ['fs.name τ-] ...) ⇒ :: #%type])

;; try 3: with stx class, use Rec-internal
;; Rec-internal only defined to enable ~literal matching
(define-typerule (Rec fs:flds) ≫
  [⊢ fs.τ ≫ τ- ⇐ :: #%type] ...
  ----------------
  [⊢ (Rec-internal ['fs.name τ-] ...) ⇒ :: #%type])

(begin-for-syntax
  ;; ~Rec pattern for Rec type
  
  ;; try 1: uses 'Rec
  #;(define-syntax ~Rec
    (pattern-expander
     (syntax-parser
       [(_ [name:id (~datum =) τ] ooo)
        #'((~literal #%plain-app)
           (~literal list-)
           ((~literal quote) Rec) ;; TODO: make this a literal id
           ((~literal #%plain-app) ((~literal quote) name) τ) ooo)])))

  ;; try 2: uses Rec-internal; adds lookup-embedded pattern
  (define-syntax ~Rec
    (pattern-expander
     (syntax-parser
       ;; just match on Rec type (assumes ellipses in patter)
       [(_ [name:id (~datum =) τ] (~literal ...))
        #'((~literal #%plain-app)
           (~literal Rec-internal)
           ((~literal #%plain-app) ((~literal quote) name) τ) (... ...))]
       ;; match *and* lookup label; err if lookup fails
       [(_ (~literal ...) [l:id (~datum =) τl] (~literal ...))
        #'(~and entire-rec-ty
                (~parse
                 ((~literal #%plain-app)
                  (~literal Rec-internal)
                  ((~literal #%plain-app) ((~literal quote) name) τ) (... ...))
                 #'entire-rec-ty)
                (~fail
                 #:unless (member (stx-e #'l) (stx->datum #'(name (... ...))))
                          (syntax-parse ; resugar τs for nicer err msg
                              (stx-map (current-resugar) #'(τ (... ...)))
                            [(ty (... ...))
                             (format "non-existent label ~a in record: ~a\n"
                                     (stx-e #'l)
                                     (stx->datum
                                      #'(Rec [name = ty] (... ...))))]))
                (~parse τl (cadr (stx-assoc #'l #'([name τ](... ...))))))]))))

;; try 1: no stx class; explicit err msg
#;(define-typerule (rec [name:id (~datum =) e] ...) ≫
  #:fail-when (check-duplicate-identifier (stx->list #'(name ...)))
              (format "Given duplicate label: ~a"
                      (stx->datum
                       (check-duplicate-identifier (stx->list #'(name ...)))))
  [⊢ e ≫ e- ⇒ τ] ...
  ------------------
  [⊢ (#%app- list- (#%app- cons- 'name e-) ...) ⇒ (Rec (name = τ) ...)])

;; try 2: use flds stx class, which handles err checks
(define-typerule (rec fs:flds) ≫
  [⊢ fs.e ≫ e- ⇒ τ] ...
  ------------------
  [⊢ (list- (cons- 'fs.name e-) ...) ⇒ (Rec [fs.name = τ] ...)])

;; handles both tuples and records
(define-typerule proj
  ;; record proj ----------------------------------------
  ;; try 1: explicit err msg and syntax-unquote
#;  [(proj e l:id) ≫
   [⊢ e ≫ e- ⇒ (~Rec [x = τ] ...)]
   #:fail-unless (member (stx-e #'l) (stx->datum #'(x ...)))
                 (format "non-existent label ~a in record: ~a"
                         (stx-e #'l)
                         (stx->datum #'e))
   ----------------------
   [⊢ (#%app- cdr- (#%app- assoc- 'l e-))
      ⇒ #,(cadr (stx-assoc #'l #'([x τ] ...)))]]
  ;; try 2: use $lookup stx-metafn (err msg not great)
  #;[(proj e l:id) ≫
   [⊢ e ≫ e- ⇒ (~Rec [x = τ] ...)]
   ----------------------
   [⊢ (#%app- cdr- (#%app- assoc- 'l e-)) ⇒ ($lookup l [x τ] ...)]]
  ;; try 3: embed lookup into ~Rec pattern (err msg good again)
  [(proj e l:id) ≫
   [⊢ e ≫ e- ⇒ (~Rec ... [l = τ] ...)]
   ----------------------
   [⊢ (cdr- (assoc- 'l e-)) ⇒ τ]]
  ;; tup proj ----------------------------------------
  [(proj e i:nat) ≫
   -----------
   [≻ (tup-proj e i)]])

(define-typerule (vals rec) ≫
  [⊢ rec ≫ rec- ⇒ (~Rec [l = τ] ...)]
  ------------------------------------
  [⊢ (list- (cdr- (assoc- 'l rec-)) ...) ⇒ (× τ ...)])

;; sums -----------------------------------------------------------------------
;; Terms:
;; - inl
;; - inr
;; - case
;; Types:
;; - Sum2

;; Notes:
;; - types often add complexity to the language
;;   - language is expanded with new (redundant) terms, eg case
;;   - terms tagged with extra layer; must be injected/extracted before use
;;   - still need runtime dispatch!

(provide Sum2 inl inr case)

(define-type-constructor Sum2 #:arity = 2)

(struct inl- (val))
(struct inr- (val))

;; declarative type rules insufficient here;
;; need explicit annotations or type inference
(define-typerule (inl e) ⇐ (~Sum2 τ1 τ2) ≫
  [⊢ e ≫ e- ⇐ τ1]
  ------------
  [⊢ (inl- e-) ⇒ (Sum2 τ1 τ2)])

(define-typerule (inr e) ⇐ (~Sum2 τ1 τ2) ≫
  [⊢ e ≫ e- ⇐ τ2]
  ------------
  [⊢ (inr- e-) ⇒ (Sum2 τ1 τ2)])

(require (only-in racket/match [match match-]))
(define-typerule (case e (~datum of)
                  [(~datum inl) x:id (~datum =>) e1]
                  [(~datum inr) y:id (~datum =>) e2]) ≫
  [⊢ e ≫ e- ⇒ (~Sum2 τ1 τ2)]
  [[x ≫ x- : τ1] ⊢ e1 ≫ e1- ⇒ τ]
  [[y ≫ y- : τ2] ⊢ e2 ≫ e2- ⇐ τ]
  ---------------------------
  [⊢ (match- e-
      [(inl- x-) e1-]
      [(inr- y-) e2-]) ⇒ τ]
  #;  [⊢ (if- (inl-? e-)
          (let- ([x- (inl--val e-)]) e1-)
          (let- ([y- (inr--val e-)]) e2-)) ⇒ τ])

(provide typed-match)
(define-typerule typed-match
  [(_ ([x:id e] [pat e-next] ...) b) ≫
   [⊢ e ≫ e- ⇒ τ]
   [[x ≫ x- : τ] ⊢ (typed-match ([pat e-next] ...) b) ≫ rest- ⇒ τ-out]
   ---------------------------------
   [⊢ (let- ([x- e-]) rest-) ⇒ τ-out]]
  [(_ ([[x:id ...] e] [pat e-next] ...) b) ≫
   [⊢ e ≫ e- ⇒ (~× τ-tup ... ~!)]
   #:fail-unless (= (stx-length #'(x ...)) (stx-length #'(τ-tup ...)))
   (format "~a pattern variables does not match ~a values in tuple" (stx-length #'(x ...)) (stx-length #'(τ-tup ...)))
   [[x ≫ x- : τ-tup] ... ⊢ (typed-match ([pat e-next] ...) b) ≫ rest- ⇒ τ-out]
   -----------------------------------------
   [⊢ (match- e- [(list x- ...) rest-]) ⇒ τ-out]]
  [(_ ([(fs:flds) (~and e (~parse (rec [l (~datum =) e-val] ...) #'e))] [pat e-next] ...) b) ≫
   [⊢ e ≫ e- ⇒ (~and τ-rec (~parse (~Rec [_ = τ-label] ...) #'τ-rec))]
   -----------------------------------------------------------------
   [≻ (typed-match ([fs.pat ($lookup fs.name [l e-val] ...)] ... [pat e-next] ...) b)]]
  [(_ () b) ≫
   [⊢ b ≫ b- ⇒ τ]
   ---------------
   [⊢ b- ⇒ τ]])

;;-------------- recursion -----------------------
;; f: (τ-in -> τ-out) -> τ-in -> τ-out
#;(define Y-
  (#%app-
   (λ- (z) (λ- (f) (λ- (x) (#%app- (#%app- (#%app- z z) f) x))))
   (λ- (z) (λ- (f) (λ- (x) (#%app- (#%app- (#%app- z z) f) x))))))

#;(define-typerule (fix f) ≫
  [⊢ f ≫ f- ⇒ (~→ (~and τ-in:type (~parse (~→ _ _) τ-in)) τ-out)] ;; TODO make sure τ is a function
  [τ-in τ= τ-out]
  ----------------------
  [⊢ (Y- f-) ⇒ τ-out])

#;(define-typerule (letrec (x f) b) ≫
  ----------------------
  [≻ ((λ x b) (fix f))])