# October 12, 9:30 PM

This is the first entry in my devlog of developing prefix calculator using Racket programming language. So far I know I need to implement
my program in the way so that it can be run either in batch mode or interactive mode. My calculator must have a history feature, I guess 
I will implement in quite similar way as in most Linux distributions: $n where n is history id. The history stack should be updated upon every
successful operation. Supported operators are: "+", "*", "/" and "-" (unary negate). While there is no "-" subtraction 
operator, I suppose it will be represented via addition of negated numbers.

Because the program accepts raw user input, I need precautionary measures. For that I need to implement error handling, I will use **exn** 
struct hierarchy to define custom exceptions to raise. To make this easier, I will create custom data types or so-called 
ASTs (Abstract Syntax Trees). For example:
```
This:
+ * 2 $1 + $2 1

I will transform to something like this:
PLUS MUL NUM(2) REF(1) PLUS REF(2) NUM(1)
```
I also need a loop function that will run all other function (only if run in interactive mode), such as functions for tokenizing, parsing, 
evaluating, printing. The tokenizer will read user input and generate list of "tokens" to pass it down to parser. The parser will 
accept input from tokenizer and decide which operation to do, for example '(NUM n) → (Num n). The last will be evaluator, it will actually
evaluate functions, for example: (Num n) → n; or (Neg e) → - (eval e) etc.

# October 13, 10:13 AM

In this session i plan to build a skeleton for my future program.  

## 11:03 AM

Finished core structure. Now i can see more clearly the way i need to implement this project. i will have five core funcions: 
tokenizer, parse-expr, eval-expr, process-line, run-loop. The tokenizer will generate 'PLUS | 'MUL | 'DIV | 'NEG | '(NUM n) | '(REF k) 
tokens, then parser will combine those into nodes. For example, negation requires 1 element, so it will parse one, summation requires 2
elemenents and so on. Parsed data will be passed to evaluator that maps AST to corresponding racket function.

# October 14, 6:11 PM

Today i plan to implement run-loop function that will be used for intercative user experience. To do so i will also need prompt? function
which is provided by professor. The run-loop function will represent imperative shell that handles communication with user through console
prompts. The information it receives from console will be passed to process-line function, where it will be processed in next sessions.

## 8:27 PM

Finished the run-loop function and updated the module+ main function to determine which function runs based on incoming options. 
Running racket main.rkt starts interactive mode; running racket main.rkt -b (or --batch) outputs error unimpl for now. I am still 
considering whether to do this check in main or in run-loop. On one hand, it gives top-level control; on the other, 
it may produce duplicate code.

The run-loop function now reads user input and distinguishes commands: quit (exit); p (print history—currently via a simple display 
function; later this will be replaced with a separate function that returns a list of pairs hist_id:value); and, in the final case, 
it passes the input line to process-line (currently unimplemented).

# October 20, 8:00 PM

Professor helped me understand how batch option should really work. I need to prompt user each time for a new expression if not batch, and 
no prompt at all if batch option is set. Fixing.

## 8:32 PM

Starting to implement process-line function. It should take raw string as input "line field" and pass it down to the tokenizer, after that
to evaluator. if successful add result to "hist" field. Basically, all buisiness logic is gathered here. Still trying to figure out how 
to write error checking here.

## 9:07 PM

Implemented process-line function but no error handling yet. Proceed to tokenizer function.

## 9:26 PM

I might want to start with helper functions for tokenizer.

## 10:08 PM

Created helpers for tokenizer: digit?, space?, plus?, minus?, mul? div? ref? (just compares incoming string); make-operator, make-number 
(first compares incoming string to acceptable operators: 'Add, 'Neg, 'Mul, 'Div)(second produces a number 'Num n). Added all 
condition clauses for tokenizer, but now i have troubles implementing tokenizing of 'Ref $n ast.   

## 10:58 PM

It appears i can not reuse make-number function here, i need two more helper functions that will take line in current state and run two loops
one to return digits right after $, and the second one to return all but those digits (remaining tail)

## 11:02 PM

I will make code cleaner if i move this logic from process-line to separate helper function parse-ref.

## 11:35 PM

Finised tokenizer function in its fullest. Error handling, however, is subject to change; i might write custom exception structs.
Now this function produces tokens to be passed to the parser (next session):
 (tokenizer (string->list "+*2$1+$2"))
'(Add Mul (Num 2) (Ref 1) Add (Ref 2))

# October 22, 8:20 PM

For this session i plan to implement pare-expr in its fullest. I am still not sure how exactly to implement it because recently i was 
pointed to the fact that parser use parse trees for evaluation. Now i am confused, i thought racket, as functional language, would take this
part of me because of the way functions are applied.  

## 9:12 PM

So, apparently, i dont need to write fullblown parse trees. Parse logic can be implemented with recursions. For example, if i have '(Num n),
it will be just (Num n). The same logic applies to '(Ref n). However, when we have any of four operators 'Add, 'Neg, 'Mul, 'Div, i need also
to search for its left and right "argument". So when i find one of those, i need to run another parse call without current token. It will 
not be a problem if we have something like '(Add Mul (Num 2) (Ref 1) Add (Ref 2) (Num 1)), two operators in the row, because we will simply
run another recursion for next operator--'Mul. After last recursive call it will return to the first operator 'Add, forming nice, structured
format. 