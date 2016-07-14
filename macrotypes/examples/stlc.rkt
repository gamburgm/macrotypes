#lang s-exp macrotypes/typecheck
(provide (for-syntax current-type=? types=?))
 
(require (for-syntax racket/list))

;; Simply-Typed Lambda Calculus
;; - no base types; can't write any terms
;; Types: multi-arg → (1+)
;; Terms:
;; - var
;; - multi-arg λ (0+)
;; - multi-arg #%app (0+)
;; Other:
;; - "type" syntax category; defines:
;;   - define-base-type
;;   - define-type-constructor
;; Typechecking forms:
;; - current-type-eval
;; - current-type=?

(begin-for-syntax
  ;; type eval
  ;; - type-eval == full expansion == canonical type representation
  ;; - must expand because:
  ;;   - checks for unbound identifiers (ie, undefined types)
  ;;   - checks for valid types, ow can't distinguish types and terms
  ;;     - could parse types but separate parser leads to duplicate code
  ;;   - later, expanding enables reuse of same mechanisms for kind checking
  ;;     and type application
  (define (type-eval τ)
    ; TODO: optimization: don't expand if expanded
    ; currently, this causes problems when
    ; combining unexpanded and expanded types to create new types
    (add-orig (expand/df τ) τ))

  (current-type-eval type-eval)

  ;; type=? : Type Type -> Boolean
  ;; Two types are equivalent when structurally free-identifier=?
  ;; - assumes canonical (ie expanded) representation
  ;; (new: without syntax-parse)
  ;; 2015-10-04: moved to define-syntax-category
  #;(define (type=? t1 t2)
    ;(printf "(τ=) t1 = ~a\n" #;τ1 (syntax->datum t1))
    ;(printf "(τ=) t2 = ~a\n" #;τ2 (syntax->datum t2))
    (or (and (identifier? t1) (identifier? t2) (free-identifier=? t1 t2))
        (and (stx-null? t1) (stx-null? t2))
        (and (stx-pair? t1) (stx-pair? t2)
             (with-syntax ([(ta ...) t1][(tb ...) t2])
               #;(types=? #'(ta ...) #'(tb ...)) (types=? t1 t2)))))
  ;; (old: uses syntax-parse)
  #;(define (type=? τ1 τ2)
;    (printf "(τ=) t1 = ~a\n" #;τ1 (syntax->datum τ1))
;    (printf "(τ=) t2 = ~a\n" #;τ2 (syntax->datum τ2))
    (syntax-parse (list τ1 τ2)
      [(x:id y:id) (free-identifier=? τ1 τ2)]
      [((τa ...) (τb ...)) (types=? #'(τa ...) #'(τb ...))]
      [_ #f]))

  #;(define current-type=? (make-parameter type=?))
  #;(current-typecheck-relation type=?)

  ;; convenience fns for current-type=?
  #;(define (types=? τs1 τs2)
    (and (stx-length=? τs1 τs2)
         (stx-andmap (current-type=?) τs1 τs2))))
  
(define-syntax-category type)

(define-type-constructor → #:arity >= 1
  #:arg-variances (λ (stx)
                    (syntax-parse stx
                      [(_ τ_in ... τ_out)
                       (append
                        (make-list (stx-length #'[τ_in ...]) contravariant)
                        (list covariant))])))

(define-typed-syntax λ
  [(λ bvs:type-ctx e)
   #:with (xs- e- τ_res) (infer/ctx+erase #'bvs #'e)
   (⊢ (λ- xs- e-) : (→ bvs.type ... τ_res))])

(define-typed-syntax #%app #:literals (#%app)
  [(#%app e_fn e_arg ...)
   #:with [e_fn- (~→ τ_in ... τ_out)] (infer+erase #'e_fn)
   #:with ([e_arg- τ_arg] ...) (infers+erase #'(e_arg ...))
   #:fail-unless (stx-length=? #'(τ_arg ...) #'(τ_in ...))
   (num-args-fail-msg #'e_fn #'(τ_in ...) #'(e_arg ...))
   #:fail-unless (typechecks? #'(τ_arg ...) #'(τ_in ...))
   (typecheck-fail-msg/multi #'(τ_in ...) #'(τ_arg ...) #'(e_arg ...))
   (⊢ (#%app- e_fn- e_arg- ...) : τ_out)])