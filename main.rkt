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

;; Error structure

(struct calc-error exn:fail (context) #:transparent)

;; Predicates for tokenizer

(define (digit? c) (char-numeric? c))
(define (space? c) (char-whitespace? c))
(define (plus? c) (char=? c #\+))
(define (minus? c) (char=? c #\-))
(define (mul? c) (char=? c #\*))
(define (div? c) (char=? c #\/))
(define (ref? c) (char=? c #\$))

;; Max length for history array.
(define MAX-HIST-SIZE 10)

;; Returns token matched by operator.
(define (make-operator op)
  (cond
    [(plus? op) 'Add]
    [(minus? op) 'Neg]
    [(mul? op)  'Mul]
    [(div? op)  'Div]))

;; Returns 'Num token.
(define (make-number buf)
  `(Num , (real->double-flonum (string->number (list->string (reverse buf))))))

;; Helper for parse-ref.
;; Used to extract digit sequence. 
;; Collects consecutive characters from the front of `lst` while `predicate` holds.
;; Returns a list of those characters. 
(define (keep-while-loop predicate lst)
  (if (and (pair? lst) (predicate (car lst)))
      (cons (car lst) (keep-while-loop predicate (cdr lst)))
      '()))
;; Helper for parse-ref.
;; Drops consecutive characters from the front of `lst` while `predicate` holds.
;; Returns the remainder of the list after the first non-matching character.
(define (drop-while-loop predicate lst)
  (if (and (pair? lst) (predicate (car lst)))
      (drop-while-loop predicate (cdr lst))
      lst))

;; Helper for parse-expr.
;; Takes whole string right after "$" symbol and looks for number.
;; Raises `calc-error` if no digits follow `$`.
;; Returns 'Ref token with remaining string.
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
      ;; If char is whitespace, skip untill meaningfull token found.
      [(space? (car ln))
       (loop (cdr ln) '()
             (if (null? buf)
                 out
                 (cons (make-number buf) out)))]
      ;; If number, remember it inside buf until we meet non digit chars.
      ;; When non digit is found, call make-number function
      ;; and pass accumulated buffer inside.
      [(digit? (car ln))
       (loop (cdr ln) (cons (car ln) buf) out)]

      ;; if any of operators.
      [(or (plus? (car ln)) (minus? (car ln))
           (mul? (car ln)) (div? (car ln)))
       (loop (cdr ln) '()
             ;; If not null -- we have number to add.
             (if (null? buf)
                 (cons (make-operator (car ln)) out)
                 (cons (make-operator (car ln))
                       (cons (make-number buf) out))))]
      ;; If reference symbol "$" is found check for number right after it.
      [(ref? (car ln))
       (let-values ([(token rest) (parse-ref (cdr ln))])
         (loop rest '()
               ;; If not null -- we have number to add.
               (if (null? buf)
                   (cons token out)
                   (cons token
                         (cons (make-number buf) out)))))]

      [else (raise (calc-error
                    (format "Unknown token: ~a" (car ln))
                    (current-continuation-marks)
                    'tokenizer))])))

;; Builds data nodes, groups them depending on op.
(define (parse-expr toks)
  (let parse ([ts toks])
    (cond
      ;; Raises an exception if we excpect another operand that was not found.
      [(null? ts)
       (raise (calc-error
               "Incomplete expression : missing operand(s) for operator" 
               (current-continuation-marks)
               'parser-expr))]

      ;; Literal number.
      ;; Represented by a list like '(Num n).
      [(and (pair? (car ts))
            (eq? (caar ts) 'Num))
       (values (Num (cadar ts)) (cdr ts))]

      ;; History reference.
      ;; Represented by a list like '(Ref n).
      [(and (pair? (car ts))
            (eq? (caar ts) 'Ref))
       (values (Ref (cadar ts)) (cdr ts))]

      ;; Unary negate.
      ;; Represented by 'Neg followed by a '(Num n).
      ;; We run another parse call to search for Neg's "argument".
      [(eq? (car ts) 'Neg)
       (let-values ([(val rest1) (parse (cdr ts))])
         (values (Neg val) rest1))]

      ;; Binary operators.

      ;; Summation.
      ;; Represented by 'Add key followed by two '(Num n) with optional 'Neg before each.
      ;; We run another parse call to search for Add's "arguments", left and right.
      [(eq? (car ts) 'Add)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Add left right) rest2))]
      ;; Multiplication.
      ;; Represented by 'Mul key followed by two '(Num n) with optional 'Neg before each.
      ;; We run another parse call to search for Mul's "arguments", left and right.
      [(eq? (car ts) 'Mul)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Mul left right) rest2))]
      ;; Division.
      ;; Represented by 'Div key followed by two '(Num n) with optional 'Neg before each.
      ;; We run another parse call to search for Div's "arguments", left and right.
      [(eq? (car ts) 'Div)
       (let*-values ([(left rest1) (parse (cdr ts))]
                    [(right rest2) (parse rest1)])
         (values (Div left right) rest2))])))

;; Top level function, wrapper for the parser-expr; checks for exrtra tokens left after parsing.
(define (parse-top toks)
  (let-values ([(ast rest) (parse-expr toks)])
    ;; if not null, wrong input.
    (if (null? rest)
        ast
        (raise (calc-error
         (format "Extra tokens after complete expression: ~a" rest)
         (current-continuation-marks)
         'parser-top)))))
;; Updates history, adds a new value to the begining of the array.
;; Behaves the same way as stack.
;; MAX-HIST-SIZE determines maximum length of the array.
(define (update-history hist value)
  (let ([hst
         ;; if reached the maximum length, delete last (shift all to the right).
         (if (>= (length hist) MAX-HIST-SIZE)
               (reverse (cdr (reverse hist)))  
               hist)])
    (cons value hst)))

;; Evaluates epxpression written as AST.
(define (eval-expr ast hist)
 (match ast
    [(Num n) n]
    [(Ref k)
     ;; Validates refecrence id.
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
       ;; Raises an exception if dominator is 0.
       (if (zero? rv)
           (raise (calc-error
                   "Division by zero"
                   (current-continuation-marks)
                   'eval-expr))
           (/ lv rv)))]))

;; This is a top level function, handles all errors, runs whole pipeline.
(define (process-line line hist)
  ;; Error handling part. Handles errors raised by calc-error and exn:fail predicates.
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
     ;; if string is empty.
  (if (or (string=? (string-trim line) "")
        (null? (string->list (string-trim line))))
      (raise (calc-error
                 "Empty input: no expression provided"
                 (current-continuation-marks)
                 'process-line))
      ;; core logic, tokenize→parse→eval→update history.
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

;; Prints history in format [id]:value.
(define (print-history hist)
  (if (null? hist)
      (displayln "History is empty")
      ;; We count our indexes each time print is called.
      (let iter ([lst hist] [idx 1])
        (displayln (format "~a: ~a" idx (car lst)))
        (if (null? (cdr lst))
            (void)
            (iter (cdr lst) (+ idx 1))))))

;; Main read-line loop.
(define (run-loop hist)
  (begin
    (let loop ([h hist])
    (when prompt? (display "> ") (flush-output))
    (let ([line (read-line)])
      (cond
        [(eof-object? line) (void)]
        [(string=? (string-trim line) "quit") (exit 0)]
        [(string=? (string-trim line) "p") (print-history h) (loop h)]
        [else
         ;; val pulls newly added record stored inside history array.
         ;; is used to print intermidiate values in --batch mode.
         (let* ([new-h (process-line line h)]
                [val (car new-h)])
           (unless prompt? 
             (displayln val))
           (loop new-h))]
        )))))

(module+ main
  (when prompt?
    (displayln "Enter an expression or command: "))
  (run-loop '()))


