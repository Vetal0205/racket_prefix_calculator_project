#lang racket

;; Export functions for outer modules
;(provide tokenizer parse-expr eval-expr process-line)

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
(define (process-line s hist) (if s (cons s hist) #f)) ;; temporary

(define prompt?
   (let [(args (current-command-line-arguments))]
     (cond
       [(= (vector-length args) 0) #t]
       [(string=? (vector-ref args 0) "-b") #f]
       [(string=? (vector-ref args 0) "--batch") #f]
       [else #t])))

;; Only for interactive mode
(define (run-loop hist)
  (begin
    (let loop ([h hist])
    (display ">>> ") (flush-output)
    (let ([line (read-line)])
      (cond
        [(eof-object? line) (displayln "Error: invalid input")]
        [(string=? line "quit") (exit 0)]
        [(string=? line "p") (displayln h) (loop h)] ;; temporary solution
        [else (loop (process-line line h))])
      ))))

(module+ main
  (displayln "Ente an expression or command: ")
  (when prompt? (run-loop '()))
  (error "unimpl"))