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

;; Error structure

(struct calc-error exn:fail (context) #:transparent)

;; Helpers for tokenizer

(define (digit? c) (char-numeric? c))
(define (space? c) (char-whitespace? c))
(define (plus? c) (char=? c #\+))
(define (minus? c) (char=? c #\-))
(define (mul? c) (char=? c #\*))
(define (div? c) (char=? c #\/))
(define (ref? c) (char=? c #\$))
(define MAX-HIST-SIZE 10)

(define (make-operator op)
  (cond
    [(plus? op) 'Add]
    [(minus? op) 'Neg]
    [(mul? op)  'Mul]
    [(div? op)  'Div]))

(define (make-number buf)
  `(Num , (real->double-flonum (string->number (list->string (reverse buf))))))

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
        (raise (calc-error
                (format "History refrence must be followed by ID, got: ~a" digits)
                (current-continuation-marks) 'parse-ref)) 
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

      [else (raise (calc-error
                    (format "Unknown token: ~a" (car ln))
                    (current-continuation-marks)
                    'tokenizer))])))

;; Builds data nodes, groups them depending on op
(define (parse-expr toks)
  (let parse ([ts toks])
    (cond
      [(null? ts)
       (raise (calc-error
               "Incomplete expression : missing operand(s) for operator" 
               (current-continuation-marks)
               'parser-expr))]

      ;; literal number
      ;; Represented by a list like '(Num n)
      [(and (pair? (car ts))
            (eq? (caar ts) 'Num))
       (values (Num (cadar ts)) (cdr ts))]

      ;; history reference
      ;; Represented by a list like '(Ref n)
      [(and (pair? (car ts))
            (eq? (caar ts) 'Ref))
       (values (Ref (cadar ts)) (cdr ts))]

      ;; Unary negate
      ;; Represented by 'Neg followed by a '(Num n)
      ;; We run another parse call to search for Neg's "argument"
      [(eq? (car ts) 'Neg)
       (let-values ([(val rest1) (parse (cdr ts))])
         (values (Neg val) rest1))]

      ;; binary operators

      ;; Summation
      ;; Represented by 'Add key followed by two '(Num n) with optional 'Neg before each
      ;; We run another parse call to search for Add's "arguments", left and right
      [(eq? (car ts) 'Add)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Add left right) rest2))]
      ;; Multiplication
      ;; Represented by 'Mul key followed by two '(Num n) with optional 'Neg before each
      ;; We run another parse call to search for Mul's "arguments", left and right
      [(eq? (car ts) 'Mul)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Mul left right) rest2))]
      ;; Division
      ;; Represented by 'Div key followed by two '(Num n) with optional 'Neg before each
      ;; We run another parse call to search for Div's "arguments", left and right
      [(eq? (car ts) 'Div)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Div left right) rest2))])))

;; wrapper, checks for exrtra tokens
(define (parse-top toks)
  (let-values ([(ast rest) (parse-expr toks)])
    (if (null? rest)
        ast
        (raise (calc-error
         (format "Extra tokens after complete expression: ~a" rest)
         (current-continuation-marks)
         'parser-top)))))

(define (update-history hist value)
  (let ([hst
         (if (>= (length hist) MAX-HIST-SIZE)
               (cdr hist)   ; drop first (oldest)
               hist)])
    (append hst (list value))))

;; Evaluates epxpression written as AST
(define (eval-expr ast hist)
 (match ast
    [(Num n) n]
    [(Ref k)
     (let ([i (- k 1)])
       (if (and (integer? i) (>= i 0) (< i (length hist)))
           (list-ref hist i)
           (raise (calc-error
                   (format "Invalid history reference: $~a (no value stored at this index)" k)
                   (current-continuation-marks)
                   'eval-expr))))]
    [(Neg e1) (- (eval-expr e1 hist))]
    [(Add l r) (+ (eval-expr l hist)
                  (eval-expr r hist))]
    [(Mul l r) (* (eval-expr l hist)
                  (eval-expr r hist))]
    [(Div l r)
     (let ([lv (eval-expr l hist)]
           [rv (eval-expr r hist)])
       (if (zero? rv)
           (raise (calc-error
                   "Division by zero"
                   (current-continuation-marks)
                   'eval-expr))
           (/ lv rv)))]))

;; will do all heavy stuff tokenize→parse→eval→print→update history
(define (process-line line hist)
   (with-handlers ([calc-error?
                   (lambda (except)
                     (displayln
                      (format "[~a] ~a"
                              (calc-error-context except)
                              (exn-message except)))
                     hist)]
                  [exn:fail?
                   (lambda (except)
                     (displayln
                      (format "[internal] ~a"
                              (exn-message except)))
                     hist)])
  (if (or (string=? (string-trim line) "")
        (null? (string->list (string-trim line))))
      (raise (calc-error
                 "Empty input: no expression provided"
                 (current-continuation-marks)
                 'process-line))
      (let* ([tokens (tokenizer (string->list line))]
             [ast (parse-top tokens)]
             [value (eval-expr ast hist)]
             [new-hist (update-history hist value)])
        new-hist))))

(define prompt?
   (let [(args (current-command-line-arguments))]
     (cond
       [(= (vector-length args) 0) #t]
       [(string=? (vector-ref args 0) "-b") #f]
       [(string=? (vector-ref args 0) "--batch") #f]
       [else #t])))

(define (print-history hist)
  (if (null? hist)
      (displayln "History is empty")
      (let iter ([lst hist] [idx 1])
        (displayln (format "~a: ~a" idx (car lst)))
        (if (null? (cdr lst))
            (void)
            (iter (cdr lst) (+ idx 1))))))

;; Only for interactive mode
(define (run-loop hist)
  (begin
    (let loop ([h hist])
    (when prompt? (display "> ") (flush-output))
    (let ([line (read-line)])
      (cond
        [(eof-object? line) (void)]
        [(string=? (string-trim line) "quit") (exit 0)]
        [(string=? (string-trim line) "p") (print-history h) (loop h)] ;; temporary solution
        [else (loop (process-line line h))])
      ))))

(module+ main
  (when prompt?
    (displayln "Ente an expression or command: "))
  (run-loop '()))


