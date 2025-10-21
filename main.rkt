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

;; Helpers for tokenizer

(define (digit? c) (char-numeric? c))
(define (space? c) (char-whitespace? c))
(define (plus? c) (char=? c #\+))
(define (minus? c) (char=? c #\-))
(define (mul? c) (char=? c #\*))
(define (div? c) (char=? c #\/))
(define (ref? c) (char=? c #\$))

(define (make-operator op)
  (cond
    [(plus? op) 'Add]
    [(minus? op) 'Neg]
    [(mul? op)  'Mul]
    [(div? op)  'Div]
    [else (error "invalid operator" op)])) ;; subject to change in the future

(define (make-number buf)
  `(Num ,(string->number (list->string (reverse buf)))))

(define (keep-while-loop predicate lst)
  (if (and (pair? lst) (predicate (car lst)))
      (cons (car lst) (keep-while-loop predicate (cdr lst)))
      '()))

(define (drop-while-loop predicate lst)
  (if (and (pair? lst) (predicate (car lst)))
      (drop-while-loop predicate (cdr lst))
      lst))

(define (parse-ref rest)
  (let* ([digits (keep-while-loop digit? rest)]
         [remain (drop-while-loop digit? rest)])
    (if (null? digits)
        (error "reference '$' requires numeric index") ;; subject to change
        (values `(Ref ,(string->number (list->string digits))) remain))))

;; Top-level functions

;; Generates tokens: PLUS | MUL | DIV | NEG | (NUM n) | (REF k)
(define (tokenizer line)
  (let loop ([ln line] [buf '()] [out '()])
    (cond
      [(null? ln)
       (if (null? buf)
           (reverse out)
           (reverse (cons (make-number buf) out)))]
      ;; if space char (needed if user's input include those)
      [(space? (car ln))
       (loop (cdr ln) '()
             (if (null? buf)
                 out
                 (cons (make-number buf) out)))]
      ;; if number
      [(digit? (car ln))
       (loop (cdr ln) (cons (car ln) buf) out)]

      ;; if any of operators
      [(or (plus? (car ln)) (minus? (car ln))
           (mul? (car ln)) (div? (car ln)))
       (loop (cdr ln) '()
             ;; If not null -- we have number to add
             (if (null? buf)
                 (cons (make-operator (car ln)) out)
                 (cons (make-operator (car ln))
                       (cons (make-number buf) out))))]
       
      [(ref? (car ln))
       (let-values ([(token rest) (parse-ref (cdr ln))])
         (loop rest '()
               ;; If not null -- we have number to add
               (if (null? buf)
                   (cons token out)
                   (cons token
                         (cons (make-number buf) out)))))]

      [else (error "unknown character" (car ln))])))

;; Builds data nodes, groups them depending on op
(define (parse-expr toks) (error "unimp"))

;; Evaluates epxpression written as AST
(define (eval-expr ast hist) (error "unimp"))

;; will do all heavy stuff tokenize→parse→eval→print→update history
(define (process-line line hist)
  (let* ([tokens (tokenizer (string->list line))]
         [ast (parse-expr tokens)]
         [value (eval-expr ast hist)])
    (cons value hist))) 

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
    (when prompt? (display "> ") (flush-output))
    (let ([line (read-line)])
      (cond
        [(eof-object? line) (displayln "Error: invalid input")]
        [(string=? line "quit") (exit 0)]
        [(string=? line "p") (displayln h) (loop h)] ;; temporary solution
        [else (loop (process-line line h))])
      ))))

;(module+ main
  ;(when prompt?
  ;  (displayln "Ente an expression or command: "))
 ; (run-loop '()))


