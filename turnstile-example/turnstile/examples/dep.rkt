#lang turnstile/base
(require (for-meta 2 racket/base syntax/parse))

(begin-for-syntax
  (current-use-stop-list? #f))

; Π  λ ≻ ⊢ ≫ ⇒ ∧ (bidir ⇒ ⇐)

(provide * Π → ∀ λ #%app ann define define-type-alias
         #%module-begin #%top-interaction require)

#;(begin-for-syntax
  (define old-ty= (current-type=?))
  (current-type=?
   (λ (t1 t2 env1 env2)
     (displayln (stx->datum t1))
     (displayln (stx->datum t2))
     (old-ty= t1 t2 env1 env2))))

(define-internal-type-constructor →)
(define-internal-binding-type ∀)
(define-syntax *
  (make-variable-like-transformer
   (assign-type #'#%type #'#%type)))
;; TODO: how to do Type : Type
(define-typed-syntax (Π ([X:id (~datum :) τ_in] ...) τ_out) ≫
  [[X ≫ X- : τ_in] ... ⊢ [τ_out ≫ τ_out- ⇒ _][τ_in ≫ τ_in- ⇒ _] ...]
  -------
  [⊢ (∀- (X- ...) (→- τ_in- ... τ_out-)) ⇒ #,(expand/df #'*)])
;; abbrevs for Π
(define-simple-macro (→ τ_in ... τ_out)
  #:with (X ...) (generate-temporaries #'(τ_in ...))
  (Π ([X : τ_in] ...) τ_out))
(define-simple-macro (∀ (X ...)  τ)
  (Π ([X : *] ...) τ))
;; ~Π pattern expander
(begin-for-syntax
  (define-syntax ~Π
    (pattern-expander
     (syntax-parser
       [(_ ([x:id : τ_in] ... (~and (~literal ...) ooo)) τ_out)
        #'(~∀ (x ... ooo) (~→ τ_in ... ooo τ_out))]
       [(_ ([x:id : τ_in] ...)  τ_out)
        #'(~∀ (x ...) (~→ τ_in ... τ_out))]))))

;; TODO: add case with expected type + annotations
;; - check that annotations match expected types
(define-typed-syntax λ
  [(_ ([x:id : τ_in] ...) e) ≫
   [[x ≫ x- : τ_in] ... ⊢ [e ≫ e- ⇒ τ_out][τ_in ≫ τ_in- ⇒ _] ...]
   -------
   [⊢ (#%plain-lambda- (x- ...) e-) ⇒ (Π ([x- : τ_in-] ...) τ_out)]]
  [(_ (y:id ...) e) ⇐ (~Π ([x:id : τ_in] ...) τ_out) ≫
   [[x ≫ x- : τ_in] ... ⊢ #,(substs #'(x ...) #'(y ...) #'e) ≫ e- ⇐ τ_out]
   ---------
   [⊢ (#%plain-lambda- (x- ...) e-)]])

;; TODO: do beta on terms?
(define-typed-syntax #%app
  [(_ e_fn e_arg ...) ≫ ; apply lambda
   [⊢ e_fn ≫ (_ (x ...) e ~!) ⇒ (~Π ([X : τ_in] ...) τ_out)]
   #:fail-unless (stx-length=? #'[τ_in ...] #'[e_arg ...])
                 (num-args-fail-msg #'e_fn #'[τ_in ...] #'[e_arg ...])
   [⊢ e_arg ≫ e_arg- ⇐ τ_in] ...
   --------
   [⊢ #,(substs #'(e_arg- ...) #'(x ...) #'e) ⇒
      #,(substs #'(e_arg- ...) #'(X ...) #'τ_out)]]
  [(_ e_fn e_arg ... ~!) ≫ ; apply var
   [⊢ e_fn ≫ e_fn- ⇒ (~Π ([X : τ_in] ...) τ_out)]
   #:fail-unless (stx-length=? #'[τ_in ...] #'[e_arg ...])
                 (num-args-fail-msg #'e_fn #'[τ_in ...] #'[e_arg ...])
   [⊢ e_arg ≫ e_arg- ⇐ τ_in] ...
   --------
   [⊢ (#%plain-app- e_fn- e_arg- ...) ⇒
      #,(substs #'(e_arg- ...) #'(X ...) #'τ_out)]])

(define-typed-syntax (ann e (~datum :) τ) ≫
  [⊢ e ≫ e- ⇐ τ]
  --------
  [⊢ e- ⇒ τ])

(define-syntax define-type-alias
  (syntax-parser
    [(_ alias:id τ);τ:any-type)
     #'(define-syntax- alias
         (make-variable-like-transformer #'τ))]
    #;[(_ (f:id x:id ...) ty)
     #'(define-syntax- (f stx)
         (syntax-parse stx
           [(_ x ...)
            #:with τ:any-type #'ty
            #'τ.norm]))]))

(define-typed-syntax define
  #;[(_ x:id (~datum :) τ:type e:expr) ≫
   ;[⊢ e ≫ e- ⇐ τ.norm]
   #:with y (generate-temporary #'x)
   --------
   [≻ (begin-
        (define-syntax x (make-rename-transformer (⊢ y : τ.norm)))
        (define- y (ann e : τ.norm)))]]
  [(_ x:id e) ≫
   ;This won't work with mutually recursive definitions
   [⊢ e ≫ e- ⇒ _]
   #:with y (generate-temporary #'x)
   #:with y+props (transfer-props #'e- #'y #:except '(origin))
   --------
   [≻ (begin-
        (define-syntax x (make-rename-transformer #'y+props))
        (define- y e-))]]
  #;[(_ (f [x (~datum :) ty] ... (~or (~datum →) (~datum ->)) ty_out) e ...+) ≫
   #:with f- (add-orig (generate-temporary #'f) #'f)
   --------
   [≻ (begin-
        (define-syntax- f
          (make-rename-transformer (⊢ f- : (→ ty ... ty_out))))
        (define- f-
          (stlc+lit:λ ([x : ty] ...)
            (stlc+lit:ann (begin e ...) : ty_out))))]])