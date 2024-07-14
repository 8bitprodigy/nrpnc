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

type
    Environment = ref object
        name            : string
        program_stack   : seq[string]
        program_counter : int
        functions       : Table[string, Environment]
        parent          : ref Environment

var
    stack           : seq[float]
    repl_mode       : bool = false
    operations      : Table[string, proc(environment: Environment):bool{.nimcall.}]

const whitespace = ["", "\t", "\n"]

const constants = {
    "tau": TAU, 
    "pi": PI, 
    "e": E
    }.toTable

var variables: array['A'..'Z', float]

#---------------------------------------------------------------------------------------------------

proc print_error(token_index: int, funcname, message: string) =
    echo "> Error in token ", token_index, " of function ", funcname, ": ", message, "\n"

proc check_stack(environment: Environment): bool =
    if 0 < len(stack): return false
    print_error(environment.program_counter, environment.name, "Error: No values have been entered.")
    true

proc print_head(environment: Environment): bool =
    if check_stack(environment): return true
    echo "= ", stack[0], "\n"
    false

proc print_stack(environment: Environment): bool =
    if check_stack(environment): return true
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

#---------------------------------------------------------------------------------------------------

proc is_last(environment: Environment): bool = environment.program_counter == environment.program_stack.high and repl_mode

proc is_variable(s: string): bool = is_char(s) and s[0] in 'A'..'Z'

proc is_reserved(s: string): bool = s in whitespace and s in operations and s in constants and is_variable(s)

#---------------------------------------------------------------------------------------------------

# Applies a function, taking the top of the stack out as an argument, to every
# Element in the stack.
proc apply_stack(environment: Environment, op: proc(a: float): float): bool =
    if check_stack(environment): return true
    for index, element in stack:
        stack[index] = op(element)
    discard print_stack(environment)
    false

proc apply_stack(environment: Environment, op: proc(a, b: float): float): bool =
    if check_stack(environment): return true
    let x = stack[0]
    stack.delete(0)
    for index, element in stack:
        stack[index] = op(element, x)
    discard print_stack(environment)
    false

#---------------------------------------------------------------------------------------------------

# Applies a function to the top of the stack.
# Removes the top two elements, and pushes their result in
proc compute_head(environment: Environment, op: proc(a, b: float): float): bool =
    if stack.high < 1: 
        print_error(environment.program_counter, environment.name, "Need additional value for operation.")
        return true
    let y = stack[0]
    let x = stack[1]
    stack.delete(0)
    stack[0] = op(x, y)
    if is_last(environment): discard print_head(environment)
# Removes the top element and pushes its result in.
proc compute_head(environment: Environment, op: proc(a:float): float): bool =
    if check_stack(environment): return true
    stack[0] = op(stack[0])
    if is_last(environment): discard print_head(environment)

# Computes all the elements of the stack together and replaces them with their
# Result
proc compute_stack(environment: Environment, op: proc(a, b: float): float): bool =
    if check_stack(environment): return true
    var x = stack[0]
    stack.delete(0)
    while 0 < len(stack):
        x = op(x, stack[0])
        stack.delete(0)
    stack.insert(x, 0)
    if is_last(environment): discard print_head(environment)
    false

#---------------------------------------------------------------------------------------------------

proc compute_abs(a:    float): float = abs[float](a)
proc compute_add(a, b: float): float = a + b
proc compute_sub(a, b: float): float = a - b
proc compute_mul(a, b: float): float = a * b
proc compute_div(a, b: float): float = a / b
proc compute_pow(a, b: float): float = pow(a, b)
proc compute_mod(a, b: float): float = a mod b
proc compute_fac(a:    float): float = float( fac(int(a)))

proc compute_les(a, b: float): float = float(a <  b)
proc compute_mor(a, b: float): float = float(a >  b)
proc compute_leq(a, b: float): float = float(a <= b)
proc compute_meq(a, b: float): float = float(a >= b)
proc compute_eq( a, b: float): float = float(a == b)
proc compute_neq(a, b: float): float = float(a != b)

#---------------------------------------------------------------------------------------------------

#************
# Operations
#************

proc do_clear_screen(environment: Environment): bool =
    eraseScreen()
    setCursorPos(0,0)
    print_title()
    false

proc do_dump_stack(environment: Environment): bool = 
    stack.setLen(0)
    if is_last(environment): echo "> Stack dumped.\n"
    false

proc do_dup(environment: Environment): bool = 
    if check_stack(environment): return true
    stack.insert(stack[0])
    if is_last(environment): echo "> Value ", stack[0], " duplicated.\n"

proc do_pop(environment: Environment): bool = 
    if check_stack(environment): return true
    if is_last(environment): echo "> ", stack[0], " popped from top of the stack.\n"
    stack.delete(0)
    false

proc do_pop_at(environment: Environment): bool = 
    if check_stack(environment): return true
    let index = int(stack[0])
    if index < 1:
        print_error(environment.program_counter, environment.name, "Given index to pop must be 1 or greater.")
        return true
    if stack.high < index:
        print_error(environment.program_counter, environment.name, "Given index is out of stack bounds.")
        return true
    if is_last(environment): echo ">  Value ", stack[index], " removed from index ", index, " of the stack.\n"
    stack.delete(index)

proc do_quit(environment: Environment): bool = 
    echo "\tGoodbye!"
    quit(0)

proc do_store_var(environment: Environment): bool = 
    if check_stack(environment): return true
    let next_instruction = environment.program_counter + 1
    if next_instruction > environment.program_stack.high:
        print_error(environment.program_counter, environment.name, "Program ended abruptly; No variable to store to.\n")
        return true
    if is_variable(environment.program_stack[next_instruction]) == false:
        print_error(environment.program_counter, environment.name, "Given token is not a valid variable.")
        return true
    let variable = environment.program_stack[next_instruction][0]
    variables[variable] = stack[0]
    stack.delete(0)
    environment.program_counter = environment.program_counter + 1
    if is_last(environment): echo variables[variable], " stored to ", variable

# `if` works by checking if the top element of the stack is zero. If so, it exits, 
# allowing the program counter to continue down the program stack. If not, it
# iterates through the program until it encounters an `else`, then sets the
# program counter to that position.
proc do_if(environment: Environment): bool =
    if check_stack(environment): return true
    if is_last(environment): print_error(environment.program_counter, environment.name, "Program ends abruptly -- conditional code needed.")
    if stack[0] != 0: return false
    let tok_num: int = environment.program_counter
    var 
        if_count: int  = 0
        counter: int   = environment.program_counter
        close_reached: bool = false
    while counter <= environment.program_stack.high:
        inc(counter)
        let token = environment.program_stack[counter]
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
        print_error(counter, environment.name, "if statement at token " & intToStr(tok_num) & " left unclosed.")
    environment.program_counter = counter

# `else` works by skipping the program counter forward to its corresponding `fi`
# statement.
proc do_else(environment: Environment): bool =
    if check_stack(environment): return true
    if is_last(environment): print_error( environment.program_counter, environment.name, "Program ends abruptly -- else block needed.")
    let tok_num: int = environment.program_counter
    var 
        if_count: int = 0
        counter:  int = environment.program_counter
        close_reached: bool = false
    while counter <= environment.program_stack.high:
        inc(counter)
        let token = environment.program_stack[counter]
        if   token == "if": inc(if_count)
        elif token == "fi": 
            if if_count == 0: 
                close_reached = true
                break
            dec(if_count)
    if close_reached == false: print_error(counter, environment.name, "else statement at token " & intToStr(tok_num) & " left unclosed.")
    environment.program_counter = counter

# Defines a function and adds it to `environment`.
proc do_defun(environment: Environment): bool =
    if is_last(environment): print_error( environment.program_counter, environment.name, "Program ends abruptly -- function started, but not defined.")
    let tok_num: int = environment.program_counter
    var 
        defun_count:   int  = 0
        counter:       int  = environment.program_counter + 1
        close_reached: bool = false
        function:      Environment = Environment()
        name:          string = environment.program_stack[counter]
    if is_reserved(name): 
        echo "Function name: ", name
        print_error(environment.program_counter, environment.name, "Function name " & name & " attempts to override a reserved token.")
        return true
    function.name = name 
    while counter <= environment.program_stack.high:
        counter.inc()
        let token = environment.program_stack[counter]
        if token == "{": defun_count.inc()
        elif token == "}":
            if defun_count == 0:
                close_reached = true
                break
            defun_count.dec()
        if (token in whitespace) == false: function.program_stack.add(token)
    if close_reached == false: print_error(environment.program_counter, environment.name, "Function declaration at token " & intToStr(tok_num) & " left unclosed.")
    environment.functions.add(name, function)
    environment.program_counter = counter

# Does nothing.
# "He's doing his best!"
proc do_nop(environment: Environment): bool = false

###################
# Math Operations #
###################

proc d2r(num: float): float = degToRad[float](num)
proc sgn(num: float): float = float(sgn[float](num))

proc do_add(environment: Environment)         : bool = compute_head(environment, compute_add)
proc do_sub(environment: Environment)         : bool = compute_head(environment, compute_sub)
proc do_mul(environment: Environment)         : bool = compute_head(environment, compute_mul)
proc do_div(environment: Environment)         : bool = compute_head(environment, compute_div)
proc do_mod(environment: Environment)         : bool = compute_head(environment, compute_mod)
proc do_les(environment: Environment)         : bool = compute_head(environment, compute_les)
proc do_mor(environment: Environment)         : bool = compute_head(environment, compute_mor)
proc do_leq(environment: Environment)         : bool = compute_head(environment, compute_leq)
proc do_meq(environment: Environment)         : bool = compute_head(environment, compute_meq)
proc do_eq(environment: Environment)          : bool = compute_head(environment, compute_eq)
proc do_neq(environment: Environment)         : bool = compute_head(environment, compute_neq)
proc do_abs(environment: Environment)         : bool = compute_head(environment, compute_abs)
proc do_atan(environment: Environment)        : bool = compute_head(environment, arctan)
proc do_atan2(environment: Environment)       : bool = compute_head(environment, arctan2)
proc do_atanh(environment: Environment)       : bool = compute_head(environment, arctanh)
proc do_cbrt(environment: Environment)        : bool = compute_head(environment, cbrt)
proc do_ceil(environment: Environment)        : bool = compute_head(environment, ceil)
proc do_cos(environment: Environment)         : bool = compute_head(environment, cos)
proc do_cot(environment: Environment)         : bool = compute_head(environment, cot)
proc do_csc(environment: Environment)         : bool = compute_head(environment, csc)
proc do_d2r(environment: Environment)         : bool = compute_head(environment, d2r)
proc do_exp(environment: Environment)         : bool = compute_head(environment, exp)
proc do_fac(environment: Environment)         : bool = compute_head(environment, compute_fac)
proc do_flr(environment: Environment)         : bool = compute_head(environment, floor)
proc do_gam(environment: Environment)         : bool = compute_head(environment, gamma)
proc do_gcd(environment: Environment)         : bool = compute_head(environment, gcd)
proc do_hyp(environment: Environment)         : bool = compute_head(environment, hypot)
proc do_log(environment: Environment)         : bool = compute_head(environment, log10)
proc do_pow(environment: Environment)         : bool = compute_head(environment, compute_pow)
proc do_sec(environment: Environment)         : bool = compute_head(environment, sec)
proc do_sgn(environment: Environment)         : bool = compute_head(environment, sgn)
proc do_sin(environment: Environment)         : bool = compute_head(environment, sin)
proc do_sqrt(environment: Environment)        : bool = compute_head(environment, sqrt)
proc do_tan(environment: Environment)         : bool = compute_head(environment, tan)
proc cumulative_add(environment: Environment) : bool = compute_stack(environment, compute_add)
proc cumulative_sub(environment: Environment) : bool = compute_stack(environment, compute_sub)
proc cumulative_mul(environment: Environment) : bool = compute_stack(environment, compute_mul)
proc cumulative_div(environment: Environment) : bool = compute_stack(environment, compute_div)
proc apply_mod(environment: Environment)      : bool = apply_stack(environment, compute_mod)
proc apply_pow(environment: Environment)      : bool = apply_stack(environment, compute_pow)

operations = {
    "+"     : do_add,
    "-"     : do_sub,
    "*"     : do_mul,
    "/"     : do_div,
    "%"     : do_mod,
    "^"     : do_pow,
    "?"     : print_head,
    
    "?..."  : print_stack,
    "++"    : cumulative_add,
    "--"    : cumulative_sub,
    "**"    : cumulative_mul,
    "//"    : cumulative_div,
    "%..."  : apply_mod,
    "^..."  : apply_pow,
    
    "<"     : do_les,
    ">"     : do_mor,
    "<="    : do_leq,
    ">="    : do_meq,
    "=="    : do_eq,
    "!="    : do_neq,

    "abs"   : do_abs,
    "atan"  : do_atan,
    "atan2" : do_atan2,
    "atanh" : do_atanh,
    "cbrt"  : do_cbrt,
    "ceil"  : do_ceil,
    "cos"   : do_cos,
    "cot"   : do_cot,
    "csc"   : do_csc,
    "d2r"   : do_d2r,
    "exp"   : do_exp,
    "fac"   : do_fac,
    "flr"   : do_flr,
    "gam"   : do_gam,
    "gcd"   : do_gcd,
    "hyp"   : do_hyp,
    "sec"   : do_sec,
    "sgn"   : do_sgn,
    "sin"   : do_sin,
    "sqrt"  : do_sqrt,
    "tan"   : do_tan,

    "if"    : do_if,
    "else"  : do_else,
    "fi"    : do_nop,
    "{"     : do_defun,
    "}"     : do_nop,
    
    "clr"   : do_clear_screen,
    "ds"    : do_dump_stack,
    "dup"   : do_dup,
    "pop"   : do_pop,
    "pop@"  : do_pop_at,
    "quit"  : do_quit,
    "sto:"  : do_store_var
    }.toTable 


#---------------------------------------------------------------------------------------------------

method evaluate(self: Environment) {.base.} =
    #echo user_input, " | ", len(user_input)
    #program_stack = user_input
    if len(self.program_stack) == 0: return
    let backup_stack = stack
    var err = false
    while self.program_counter <= self.program_stack.high:
        let 
            index:   int    = self.program_counter
            token:   string = self.program_stack[index]
            #is_last: bool   = index == program_stack.high
        if token in whitespace: 
            self.program_counter.inc()
            continue
        if token in operations:
            err = operations[token](self)
        elif token in constants:
            stack.insert(constants[token])
            if is_last(self): discard print_head(self)
        elif is_variable(token):
            stack.insert(variables[token[0]])
            if is_last(self): discard print_head(self)
        elif token in self.functions:
            self.functions[token].evaluate()
        else:
            if is_number(token):
                stack.insert(parseFloat(token), 0)
            else: 
                echo "> Syntax error in token, ", index, ": ", token, "\n"
                err = true
        if err:
            stack = backup_stack
            return
        self.program_counter.inc()
    self.program_counter = 0

proc repl() =
    var environment: Environment = Environment()
    while true:
        environment.program_stack = readLine(stdin).split(' ')
        environment.evaluate()
        #environment.program_counter = 0


#############
#  M A I N  #
#############

let args = commandLineParams()

if len(args) > 0:
    var environment: Environment = Environment()
    environment.program_stack = args
    environment.evaluate()
    if len(stack) == 0: quit(0)
    let product = stack[0]
    if product mod 1 > 0: echo product
    else: echo int(product)
        
else:
    repl_mode = true
    print_title()
    repl()
