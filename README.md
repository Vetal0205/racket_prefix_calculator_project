# Prefix Calculator (Racket)

## Overview
This project implements a **prefix-notation calculator** written in Racket.  
The calculator evaluates expressions such as:

```
+ * 2 $1 + $2 1
```

and maintains a **history** of recent results, which can be referenced using `$id`  
(e.g., `$1` refers to the newest stored result).

The design follows a **functional-core / imperative-shell** architecture:
- The **core** (`process-line`, `tokenizer`, `parse-expr`, `eval-expr`, `update-history` and their helpers) is purely functional.
- The **shell** (`run-loop`, `print-history`) handles user interaction and I/O.


## Files and Structure

| File | Description |
|------|--------------|
| `main.rkt` | Main program file. Contains tokenizer, parser, evaluator, and REPL loop. |
| `devlog.md` | Developer log documenting the design process, architecture decisions, implementation steps, encountered issues, and fixes applied throughout development. Serves as an engineering record of functional and structural evolution of the calculator. |
| `README.md` | This documentation file. |

### Core Components

| Function | Purpose |
|-----------|----------|
| `tokenizer` | Converts character list to tokens such as `'Add`, `'Mul`, `(Num n)`, `(Ref id)` |
| `parse-expr` | Builds the AST (abstract syntax tree) for prefix expressions |
| `eval-expr` | Recursively evaluates AST nodes |
| `update-history` | Prepends newest result, limits total history length to 10 |
| `process-line` | Wraps the full evaluation pipeline with error handling |
| `run-loop` | The main loop for both interactive and batch operation |
| `print-history` | Displays stored results in the format `id:value` |


## Running the Program

### Prerequisites

- **Racket** must be installed on your system.

#### Linux / macOS
Install via your package manager or from [https://racket-lang.org](https://racket-lang.org):
```bash
sudo apt install racket      # Debian/Ubuntu
# or
brew install racket          # macOS (Homebrew)
```
Verify installation:
```bash
racket --version
```

#### Windows
Download the official installer from [https://racket-lang.org/download](https://racket-lang.org/download)  
and follow the setup wizard.  
After installation, open **Command Prompt** or **PowerShell** and verify:
```powershell
racket --version
```
If not recognized, ensure the Racket installation directory (e.g., `C:\Program Files\Racket`) is added to your system `PATH`.


## Usage

### Interactive Mode (default)
Run without arguments:
```bash
racket main.rkt
```

Example session:
```
Enter an expression or command:
> + * 2 3 + 4 1
11.0
> p
1: 11.0
> quit
```

Commands:
- `p` — print stored history (`id:value`)
- `quit` — exit the program

---

### Batch Mode
Use `-b` or `--batch` to read from stdin or a file.


```
racket main.rkt -b < input.txt > output.txt
```

Each expression line in `input.txt` is evaluated independently.  
The calculator prints one result per line.

Example `input.txt`:
```
+ 1 2
* + 2 3 4
/ 10 2
+ * 2 3 + 4 1
- 5
$1
+ $1 3
+ * 2 3 / 8 2
/ 5 0
$10
```

Output `output.txt`:
```
3.0
20.0
5.0
11.0
-5.0
-5.0
-2.0
10.0
[eval-expr] Division by zero
10.0
[eval-expr] Invalid history reference: $10 (no value stored at this index)
10.0
```


## Error Handling

Errors are handled gracefully via the custom `calc-error` structure.  
Error output includes the component name and message, for example:

```
[eval-expr] Division by zero
[tokenizer] Unknown token: x
[parser-expr] Incomplete expression: missing operand(s) for operator
```

The calculator does not crash; it prints the error and continues reading further input.


## License
This project is distributed for educational use under a permissive license.  
No warranty is provided; behavior may vary across Racket versions.
