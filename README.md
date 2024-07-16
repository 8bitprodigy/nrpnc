![logo.svg](img/logo.svg)

# nRPNc

Reverse Polish Notation calculator written in Nim.

---

## Usage:

This calculator uses reverse polish notation to enter and calculate values, meaning the operation is entered after the values, like so:

```
1 1 +
= 2
```

What happens here, is the first two entries, being numbers, are pushed into the stack, and then the operator pops the top two numbers off the stack, calculates them together(in this example, they're added), and pushes the result back onto the stack(and since the last item of the input is an operation, the result is also printed, following the `=`).

Because of this, multiple operations can be chained together:

```
1 1 + 4 *
= 8
```

Many people may be used to RPN calculators that have an `enter` button to input numbers, or may want to use a number pad one-handed for calculations, rather than relying on the spacebar. This calculator allows such a method by pressing the `enter` key after each entry:

```
1
1
+
= 2
```

## Operators:

### Standard operators:

The following operators are supported:

- `+` addition

- `-` subtraction

- `*` multiplication

- `/` division

- `%` modulus/remainder

- `^` exponent

### Variadic operators:

`NRPNC` also has variants to do cumulative operations to the whole stack:

- `++` sums the whole stack together

- `--` subtracts the whole stack together

- `**` multiplies the whole stack together

- `//` divides the whole stack together

There are also operations that can be applied over each item in the stack:

- `%...` removes the top item from the stack and uses it to apply a modulus operation to each item in the stack.

- `^...` removes the top item from the stack and raises every item in the stack to that power.

### Comparison operators:

Comparison operations are also supported. They pop the top two numbers off of the stack, compare them, and push either a `0`  for false or `1` for true back in:

- `<` less than

- `>` more than

- `==` equal to

- `!=` not equal to

- `<=` less than or equal to

- `>=` more than or equal to

## Built-in functions:

The following functions are supported:

- `abs` absolute value

- `atan` arctangent

- `atan2` arctangent from two arguments

- `atanh` hyperbolic arctangent

- `cbrt`

- `ceil` round a number with decimal up to the next integer

- `cos` cosine

- `cot` cotangent

- `csc` cosecant

- `d2r` convert degrees to radians

- `exp` raise second item down on the stack to power of top item of the stack

- `fac` factorial

- `flr` round a number with decimal down to the previous integer

- `gam` gamma

- `gcd` greatest common denominator between two arguments

- `hyp` hopotenuse of two arguments

- `sec` secant

- `sin` sine

- `sqrt` square root

- `tan` tangent

## Stack Manipulation functions:

- `ds` dump the stack, emptying it

- `dup` duplicates the top element of the stack

- `pop` pop the top element off the stack

- `pop@` pop the element indicated by the top item of the stack from the stack

- `sto:` pops the top value from the stack and stores it in the variable declared following the `sto:` command. 

## Miscelaneous functions:

- `clr` clear screen

- `quit` exits the calculator

## Control flow:

`if/else` statements are supported and allow for nested `if/else` statements:

- `if` checks the top value of the stack. If zero, it moves the program forward until it finds an `else` of `fi` statement. If non-zero, the entries following it are executed.

- `else` denotes the start of a code block to be executed if a false value is encountered by a preceeding `if` statement.

- `fi` closes an `if/else` statement

Users can also declare their own functions. Functions are delimted with `{` and `}`. You can delcare a function in the following syntax:

```
{ <function_name_here> <function body here> }
```

Functions are able to call functions declared within them, in the same scope as them, or in a parent scope.
