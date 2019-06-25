#!/bin/bash

source parse.sh
source codegen.sh

function assert()
{
  local result
  local ret
  result=$(eval "${1}")
  ret=${?}
  if [[ ${ret} != ${2} || ${result} != ${3} ]]; then
    echo Error
    echo ret ${2} ${ret}
    echo result \'${3}\' \'${result}\'
    echo
  fi
}

#memo test
#S <- A
#A <- P "+" A / P "-" A / P
#P <- "(" A ")" / "1"
function memo_s()
{
  ${MEMO_BEGIN}
  memo_a
  ${MEMO_END}
}
function memo_a()
{
  ${MEMO_BEGIN}
  try memo_a1; ${OR}
  try memo_a2; ${OR}
  memo_p; ${M}
  ${MEMO_END}
}
function memo_a1()
{
  memo_p; ${M}
  string '+'; ${M}
  memo_a; ${M}
}
function memo_a2()
{
  memo_p; ${M}
  string '-'; ${M}
  memo_a; ${M}
}
function memo_p()
{
  ${MEMO_BEGIN}
  try memo_p1; ${OR}
  memo_p2; ${M}
  ${MEMO_END}
}
function memo_p1()
{
  string '('; ${M}
  memo_a; ${M}
  string ')'; ${M}
}
function memo_p2()
{
  string '1'; ${M}
  fn_result="1"
}

function test_func()
{
  assert "parse 'string \*' '*'" 0 '*'

  assert "parse 'string d' 'abcdefg'" 1 ''

  parse 'try string "123"' '123'
  assert 'show_ast ${fn_result}' 0 '(raw "123")'

  assert "parse 'try string \"1234\"' '123'" 1 ''

  #space
  assert "parse space 'a'" 1 ''
  parse space ' '
  assert 'show_ast ${fn_result}' 0 '(raw " ")'
  parse space $'\t'
  assert 'show_ast ${fn_result}' 0 $'(raw "\t")'
  parse space $'\n'
  assert 'show_ast ${fn_result}' 0 $'(raw "\n")'

  #skipMany
  assert "parse 'skipMany space' 'a'" 0 ''

  #skipMany1
  assert "parse 'skipMany1 space' 'a'" 1 ''
  assert "parse 'skipMany1 space' '  '" 0 ''

  #sepBy
  parse "sepBy 'string ,' number" ''
  assert 'show_ast ${fn_result}' 0 '(nil)'
  parse "sepBy 'many1 space' number" '1 2  3   4'
  assert 'show_ast ${fn_result}' 0 '(pair (number (raw "1")) (pair (number (raw "2")) (pair (number (raw "3")) (pair (number (raw "4")) (nil)))))'

  #sepBy1
  assert 'parse "sepBy1 \"string ,\" number" ""' 1 ''
  parse "sepBy1 'string ,' number" '1,2,3,4,5'
  assert 'show_ast ${fn_result}' 0 '(pair (number (raw "1")) (pair (number (raw "2")) (pair (number (raw "3")) (pair (number (raw "4")) (pair (number (raw "5")) (nil))))))'

  #digit
  parse digit '0'
  assert 'show_ast ${fn_result}' 0 '(raw "0")'
  parse digit '1'
  assert 'show_ast ${fn_result}' 0 '(raw "1")'
  parse digit '9'
  assert 'show_ast ${fn_result}' 0 '(raw "9")'

  #number
  parse number '0123456789'
  assert 'show_ast ${fn_result}' 0 '(number (raw "0123456789"))'

  #term
  parse term '(1234)'
  assert 'show_ast ${fn_result}' 0 '(number (raw "1234"))'

  #expression
  parse expression '114+514'
  assert 'show_ast ${fn_result}' 0 '(add (number (raw "114")) (number (raw "514")))'

  parse expression '114+514-810'
  assert 'show_ast ${fn_result}' 0 '(sub (add (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114+(514-810)'
  assert 'show_ast ${fn_result}' 0 '(add (number (raw "114")) (sub (number (raw "514")) (number (raw "810"))))'

  parse expression '114*514/810'
  assert 'show_ast ${fn_result}' 0 '(div (mul (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114*(514/810)'
  assert 'show_ast ${fn_result}' 0 '(mul (number (raw "114")) (div (number (raw "514")) (number (raw "810"))))'

  parse expression '-(514*810)'
  assert 'show_ast ${fn_result}' 0 '(minus (mul (number (raw "514")) (number (raw "810"))))'

  parse expression '114==514'
  assert 'show_ast ${fn_result}' 0 '(eq (number (raw "114")) (number (raw "514")))'

  parse expression '114!=514'
  assert 'show_ast ${fn_result}' 0 '(ne (number (raw "114")) (number (raw "514")))'

  parse expression '114<514'
  assert 'show_ast ${fn_result}' 0 '(lt (number (raw "114")) (number (raw "514")))'

  parse expression '114<=514'
  assert 'show_ast ${fn_result}' 0 '(le (number (raw "114")) (number (raw "514")))'

  parse expression '114>514'
  assert 'show_ast ${fn_result}' 0 '(gt (number (raw "114")) (number (raw "514")))'

  parse expression '114>=514'
  assert 'show_ast ${fn_result}' 0 '(ge (number (raw "114")) (number (raw "514")))'

  parse program '114;514;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (number (raw "114"))) (pair (statement (number (raw "514"))) (nil)))'

  parse program 'a=19;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (assign (number (raw "19")) (identifier (raw "a")))) (nil))'

  parse program '_camel_case;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (identifier (raw "_camel_case"))) (nil))'

  parse program 'SnakeCase;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (identifier (raw "SnakeCase"))) (nil))'

  #codegen
  parse expression '114514'
  assert 'show_ast ${fn_result}' 0 '(number (raw "114514"))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 82 ''

  parse expression '114514*810/1919'
  assert 'show_ast ${fn_result}' 0 '(div (mul (number (raw "114514")) (number (raw "810"))) (number (raw "1919")))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 207 ''

  parse program 'return 114;'
  assert 'show_ast ${fn_result}' 0 '(pair (return (number (raw "114"))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 114 ''

  parse program 'abc=2*3;return abc*3;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (assign (mul (number (raw "2")) (number (raw "3"))) (identifier (raw "abc")))) (pair (return (mul (identifier (raw "abc")) (number (raw "3")))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 18 ''

  parse program 'if (1)a=114;else a=514;return a;'
  assert 'show_ast ${fn_result}' 0 '(pair (if (number (raw "1")) (statement (assign (number (raw "114")) (identifier (raw "a")))) (statement (assign (number (raw "514")) (identifier (raw "a"))))) (pair (return (identifier (raw "a"))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 114 ''

  parse program 'if (0)a=114;else a=514;return a;'
  assert 'show_ast ${fn_result}' 0 '(pair (if (number (raw "0")) (statement (assign (number (raw "114")) (identifier (raw "a")))) (statement (assign (number (raw "514")) (identifier (raw "a"))))) (pair (return (identifier (raw "a"))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 2 ''

  parse program 'if (1)a=114;if (1)a=514;return a;'
  assert 'show_ast ${fn_result}' 0 '(pair (if (number (raw "1")) (statement (assign (number (raw "114")) (identifier (raw "a")))) (nil)) (pair (if (number (raw "1")) (statement (assign (number (raw "514")) (identifier (raw "a")))) (nil)) (pair (return (identifier (raw "a"))) (nil))))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 2 ''

  parse program 'i=0;s=0;while (i<10)s=s+(i=i+1);return s;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (assign (number (raw "0")) (identifier (raw "i")))) (pair (statement (assign (number (raw "0")) (identifier (raw "s")))) (pair (while (lt (identifier (raw "i")) (number (raw "10"))) (statement (assign (add (identifier (raw "s")) (assign (add (identifier (raw "i")) (number (raw "1"))) (identifier (raw "i")))) (identifier (raw "s"))))) (pair (return (identifier (raw "s"))) (nil)))))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 55 ''

  parse program 's=0;for (i=0;i<=10;i=i+1)s=s+i;return s;'
  assert 'show_ast ${fn_result}' 0 '(pair (statement (assign (number (raw "0")) (identifier (raw "s")))) (pair (for (assign (number (raw "0")) (identifier (raw "i"))) (le (identifier (raw "i")) (number (raw "10"))) (assign (add (identifier (raw "i")) (number (raw "1"))) (identifier (raw "i"))) (statement (assign (add (identifier (raw "s")) (identifier (raw "i"))) (identifier (raw "s"))))) (pair (return (identifier (raw "s"))) (nil))))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 55 ''

  parse program 'for (i=0;i<=10;i=i+1){s=0;s=s+i;}return s;'
  assert 'show_ast ${fn_result}' 0 '(pair (for (assign (number (raw "0")) (identifier (raw "i"))) (le (identifier (raw "i")) (number (raw "10"))) (assign (add (identifier (raw "i")) (number (raw "1"))) (identifier (raw "i"))) (block (pair (statement (assign (number (raw "0")) (identifier (raw "s")))) (pair (statement (assign (add (identifier (raw "s")) (identifier (raw "i"))) (identifier (raw "s")))) (nil))))) (pair (return (identifier (raw "s"))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 10 ''

  parse memo_s '((((((((1))))))))'
}

test_func

