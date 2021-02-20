#lang s-exp "stlc.rkt"
(require rackunit/turnstile)

(check-type (λ [x : Int] x) : (→ Int Int))

(check-type (λ [x : Int] 1) : (→ Int Int))

(check-type (λ [x : Int] "one") : (→ Int Int)) ; wut???

(check-type (+ 1 2) : Int -> 3) ; test both type and runtime value

(check-type (+ 1 "one") : Int) ; wut???

(check-runtime-exn (+ 1 "one")) ; passes typechecker, blows up at runtime