# RPN Calculator
# Written by Chris DeBoy
#[
This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <https://unlicense.org>
]#
import os, math, sequtils, strutils, tables, terminal

var stack           : seq[float]
var program_stack   : seq[string]
var program_counter : int
var answer          : float


const constants = {
    "tau": TAU, 
    "pi": PI, 
    "e": E
    }.toTable

var variables: array['A'..'Z', float]


proc check_stack(): bool =
    if 0 < len(stack): return false
    print_error(program_counter, "Error: No values have been entered.")
    true

proc print_error(token_index: int, message: string) =
    echo "> Error in token ", token_index, ": ", message, "\n"

proc print_head(): bool =
    if check_stack(): return true
    echo "= ", stack[0], "\n"
    false

proc print_stack(): bool =
    if check_stack(): return true
    for index, element in stack:
        echo "= ", stack[index]
    echo ""
    false

proc print_title() = 
    echo "Nim Reverse Polish Notation Calculator\n"

proc is_char(s: string): bool = len(s) == 1

proc is_number(s: string): bool = 
    try:
        discard parseFloat(s)
        true
    except ValueError:
        false

proc is_last(): bool = program_counter == program_stack.high 

proc is_variable(s: string): bool = is_char(s) and s[0] in 'A'..'Z'

# Applies a function, taking the top of the stack out as an argument, to every
# Element in the stack.
proc apply_stack(op: proc(a: float): float): bool =
    if check_stack(): return true
    for index, element in stack:
        stack[index] = op(element)
    discard print_stack()
    false

proc apply_stack(op: proc(a, b: float): float): bool =
    if check_stack(): return true
    let x = stack[0]
    stack.delete(0)
    for index, element in stack:
        stack[index] = op(element, x)
    discard print_stack()
    false

# Applies a function to the top of the stack.
# Removes the top two elements, and pushes their result in
proc compute_head(op: proc(a, b: float): float): bool =
    if stack.high < 1: 
        print_error(program_counter, "Need additional value for operation.")
        return true
    let y = stack[0]
    let x = stack[1]
    stack.delete(0)
    stack[0] = op(x, y)
    if is_last()==false: return false
    discard print_head()
    false
# Removes the top element and pushes its result in.
proc compute_head(op: proc(a:float): float): bool =
    if check_stack(): return true
    stack[0] = op(stack[0])
    if is_last(): discard print_head()

# Computes all the elements of the stack together and replaces them with their
# Result
proc compute_stack(op: proc(a, b: float): float): bool =
    if check_stack(): return true
    var x = stack[0]
    stack.delete(0)
    while 0 < len(stack):
        x = op(x, stack[0])
        stack.delete(0)
    stack.insert(x, 0)
    if is_last(): discard print_head()
    false

proc compute_abs(a:    float): float = abs[float](a)
proc compute_add(a, b: float): float = a + b
proc compute_sub(a, b: float): float = a - b
proc compute_mul(a, b: float): float = a * b
proc compute_div(a, b: float): float = a / b
proc compute_exp(a, b: float): float = pow(a, b)
proc compute_mod(a, b: float): float = a mod b
proc compute_fac(a:    float): float = float( fac(int(a)))

proc compute_les(a, b: float): float = float(a <  b)
proc compute_mor(a, b: float): float = float(a >  b)
proc compute_leq(a, b: float): float = float(a <= b)
proc compute_meq(a, b: float): float = float(a >= b)
proc compute_eq(a,  b: float): float = float(a == b)
proc compute_neq(a, b: float): float = float(a != b)

proc do_clear_screen(): bool =
    eraseScreen()
    setCursorPos(0,0)
    print_title()
    false

#************
# Operations
#************

proc do_dump_stack(): bool = 
    stack.setLen(0)
    if is_last(): echo "> Stack dumped.\n"
    false

proc do_dup(): bool = 
    if check_stack(): return true
    stack.insert(stack[0])
    if is_last(): echo "> Value ", stack[0], " duplicated.\n"

proc do_pop(): bool = 
    if check_stack(): return true
    if is_last(): echo "> ", stack[0], " popped from top of the stack.\n"
    stack.delete(0)
    false

proc do_pop_at(): bool = 
    if check_stack(): return true
    let index = int(stack[0])
    if index < 1:
        print_error(program_counter, "Given index to pop must be 1 or greater.")
        return true
    if stack.high < index:
        print_error(program_counter, "Given index is out of stack bounds.")
        return true
    if is_last(): echo ">  Value ", stack[index], " removed from index ", index, " of the stack.\n"
    stack.delete(index)

proc do_quit(): bool = 
    echo "\tGoodbye!"
    quit(0)

proc do_store_var(): bool = 
    if check_stack(): return true
    let next_instruction = program_counter + 1
    if next_instruction > program_stack.high:
        print_error(program_counter, "Program ended abruptly; No variable to store to.\n")
        return true
    if is_variable(program_stack[next_instruction]) == false:
        print_error(program_counter, "Given token is not a valid variable.")
        return true
    let variable = program_stack[next_instruction][0]
    variables[variable] = stack[0]
    stack.delete(0)
    program_counter = program_counter + 1
    if is_last(): echo variables[variable], " stored to ", variable

# `if` works by checking if the top element of the stack is zero. If so, it exits, 
# allowing the program counter to continue down the program stack. If not, it
# iterates through the program until it encounters an `else`, then sets the
# program counter to that position.
proc do_if(): bool =
    if check_stack(): return true
    if is_last(): print_error(program_counter, "Program ends abruptly -- conditional code needed.")
    if stack[0] != 0: return false
    let tok_num: int = program_counter
    var 
        if_count: int  = 0
        counter: int   = program_counter
        close_reached: bool = false
    while counter <= program_stack.high:
        inc(counter)
        let token = program_stack[counter]
        case token
        of "if": inc(if_count)
        of "fi": 
            if if_count == 0: 
                close_reached = true
                break
            dec(if_count)
        of "else":
            if if_count == 0: 
                close_reached = true
                break
    if close_reached == false: 
        print_error(counter, "if statement at token " & intToStr(tok_num) & " left unclosed.")
    program_counter = counter

# `else` works by skipping the program counter forward to its corresponding `fi`
# statement.
proc do_else(): bool =
    if check_stack(): return true
    if is_last(): echo "> Error: Program ends abruptly -- else block needed."
    let tok_num: int = program_counter
    var 
        if_count: int  = 0
        counter: int   = program_counter
        close_reached: bool = false
    while counter <= program_stack.high:
        inc(counter)
        let token = program_stack[counter]
        if   token == "if": inc(if_count)
        elif token == "fi": 
            if if_count == 0: 
                close_reached = true
                break
            dec(if_count)
    if close_reached == false: 
        echo "> Error: else statement at token ", tok_num, " left unclosed."
    program_counter = counter

# Works in closing the `if` statement by doing nothing.
# He's doing his best!
proc do_fi(): bool = false

#******
# Math
#******

proc do_add(): bool         = compute_head(compute_add)
proc do_sub(): bool         = compute_head(compute_sub)
proc do_mul(): bool         = compute_head(compute_mul)
proc do_div(): bool         = compute_head(compute_div)
proc do_mod(): bool         = compute_head(compute_mod)
proc do_exp(): bool         = compute_head(compute_exp)
proc do_les(): bool         = compute_head(compute_les)
proc do_mor(): bool         = compute_head(compute_mor)
proc do_leq(): bool         = compute_head(compute_leq)
proc do_meq(): bool         = compute_head(compute_meq)
proc do_eq(): bool          = compute_head(compute_eq)
proc do_neq(): bool         = compute_head(compute_neq)
proc do_abs(): bool         = compute_head(compute_abs)
proc do_atan(): bool        = compute_head(arctan)
proc do_atan2(): bool       = compute_head(arctan2)
proc do_cos(): bool         = compute_head(cos)
proc do_cot(): bool         = compute_head(cot)
proc do_csc(): bool         = compute_head(csc)
proc do_fac(): bool         = compute_head(compute_fac)
proc do_sec(): bool         = compute_head(sec)
proc do_sin(): bool         = compute_head(sin)
proc do_sqrt(): bool        = compute_head(sqrt)
proc do_tan(): bool         = compute_head(tan)
proc cumulative_add(): bool = compute_stack(compute_add)
proc cumulative_sub(): bool = compute_stack(compute_sub)
proc cumulative_mul(): bool = compute_stack(compute_mul)
proc cumulative_div(): bool = compute_stack(compute_div)
proc apply_mod(): bool      = apply_stack(compute_mod)
proc apply_exp(): bool      = apply_stack(compute_exp)

var operations : Table[string, proc():bool{.nimcall.}] = {
    "+":     do_add,
    "-":     do_sub,
    "*":     do_mul,
    "/":     do_div,
    "%":     do_mod,
    "^":     do_exp,
    "?":     print_head,
    
    "?...":  print_stack,
    "++":    cumulative_add,
    "--":    cumulative_sub,
    "**":    cumulative_mul,
    "//":    cumulative_div,
    "%...":  apply_mod,
    "^...":  apply_exp,
    
    "<":     do_les,
    ">":     do_mor,
    "<=":    do_leq,
    ">=":    do_meq,
    "==":    do_eq,
    "!=":    do_neq,

    "abs":   do_abs,
    "atan":  do_atan,
    "atan2": do_atan2,
    "cos":   do_cos,
    "cot":   do_cot,
    "csc":   do_csc,
    "fac":   do_fac,
    "sec":   do_sec,
    "sin":   do_sin,
    "sqrt":  do_sqrt,
    "tan":   do_tan,

    "if":    do_if,
    "else":  do_else,
    "fi":    do_fi,
    
    "clr":   do_clear_screen,
    "ds":    do_dump_stack,
    "dup":   do_dup,
    "pop":   do_pop,
    "pop@":  do_pop_at,
    "quit":  do_quit
    "sto:":  do_store_var,
    }.toTable 


proc evaluate(user_input: var string) =
    program_stack = user_input.split(' ')
    if len(program_stack) == 0: return
    let backup_stack = stack
    var err = false
    while program_counter <= program_stack.high:
        let 
            index:   int    = program_counter
            token:   string = program_stack[index]
            #is_last: bool   = index == program_stack.high
        if token in operations:
            err = operations[token]()
        elif token in constants:
            stack.insert(constants[token])
            if is_last(): discard print_head()
        elif is_variable(token):
            stack.insert(variables[token[0]])
            if is_last(): discard print_head()
        else:
            if is_number(token):
                stack.insert(parseFloat(token), 0)
            else: 
                echo "> Syntax error in token, ", index, ": ", token, "\n"
                err = true
        if err:
            stack = backup_stack
            return
        program_counter = program_counter + 1

print_title()
while true:
    var input : string = readLine(stdin)
    evaluate( input )
    program_counter = 0
