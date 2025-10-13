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