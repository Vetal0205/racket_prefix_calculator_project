#lang racket

;; Export functions for outer modules
(provide tokenizer parse-expr eval-expr process-line)

;; AST node types
(struct Num (n)  #:transparent)   ; number literal
(struct Ref (id) #:transparent)   ; $id history reference
(struct Neg (e)  #:transparent)   ; unary negate
(struct Add (left right) #:transparent)  ; +
(struct Mul (left right) #:transparent)  ; *
(struct Div (left right) #:transparent)  ; /

;; Top-level functions

;; Generates tokens: PLUS | MUL | DIV | NEG | (NUM n) | (REF k)
(define (tokenizer s) (error "unimp"))

;; Builds data nodes, groups them depending on op
(define (parse-expr toks) (error "unimp"))

;; Evaluates epxpression written as AST
(define (eval-expr ast hist) (error "unimp"))

;; will do all heavy stuff tokenize→parse→eval→print→update history
(define (process-line s hist) (error "unimp"))

;; Only for interactive mode
(define (run-loop hist) (error "unimp"))
(module+ main
  (run-loop '()))