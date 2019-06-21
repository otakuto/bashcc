#!/bin/bash

source parse.sh
source codegen.sh

#memo test
#S <- A
#A <- P "+" A / P "-" A / P
#P <- "(" A ")" / "1"
function memo_s()
{
  eval "${MEMO_BEGIN}"
  memo_a
  eval "${MEMO_END}"
}
function memo_a()
{
  eval "${MEMO_BEGIN}"
  try memo_a1; eval "${OR}"
  try memo_a2; eval "${OR}"
  memo_p; eval "${M}"
  eval "${MEMO_END}"
}
function memo_a1()
{
  memo_p; eval "${M}"
  string '+'; eval "${M}"
  memo_a; eval "${M}"
}
function memo_a2()
{
  memo_p; eval "${M}"
  string '-'; eval "${M}"
  memo_a; eval "${M}"
}
function memo_p()
{
  eval "${MEMO_BEGIN}"
  try memo_p1; eval "${OR}"
  memo_p2; eval "${M}"
  eval "${MEMO_END}"
}
function memo_p1()
{
  string '('; eval "${M}"
  memo_a; eval "${M}"
  string ')'; eval "${M}"
}
function memo_p2()
{
  string '1'; eval "${M}"
  fn_result="1"
}

function test_func()
{
  parse 'string \*' '*'
  assert 0 '*'

  parse 'string "d"' 'abcdefg'
  assert 1 ''
  parse 'try string "123"' '123'
  assert_eval 0 '(raw "123")'
  parse 'try string "1234"' '123'
  assert 1 ''

  #digit
  parse digit '0'
  assert_eval 0 '(raw "0")'
  parse digit '1'
  assert_eval 0 '(raw "1")'
  parse digit '9'
  assert_eval 0 '(raw "9")'

  #number
  parse number '0123456789'
  assert_eval 0 '(number (raw "0123456789"))'

  #term
  parse term '(1234)'
  assert_eval 0 '(number (raw "1234"))'

  #expression
  parse expression '114+514'
  assert_eval 0 '(add (number (raw "114")) (number (raw "514")))'

  parse expression '114+514-810'
  assert_eval 0 '(sub (add (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114+(514-810)'
  assert_eval 0 '(add (number (raw "114")) (sub (number (raw "514")) (number (raw "810"))))'

  parse expression '114*514/810'
  assert_eval 0 '(div (mul (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114*(514/810)'
  assert_eval 0 '(mul (number (raw "114")) (div (number (raw "514")) (number (raw "810"))))'

  parse expression '-(514*810)'
  assert_eval 0 '(minus (mul (number (raw "514")) (number (raw "810"))))'

  parse expression '114==514'
  assert_eval 0 '(eq (number (raw "114")) (number (raw "514")))'

  parse expression '114!=514'
  assert_eval 0 '(ne (number (raw "114")) (number (raw "514")))'

  parse expression '114<514'
  assert_eval 0 '(lt (number (raw "114")) (number (raw "514")))'

  parse expression '114<=514'
  assert_eval 0 '(le (number (raw "114")) (number (raw "514")))'

  parse expression '114>514'
  assert_eval 0 '(gt (number (raw "114")) (number (raw "514")))'

  parse expression '114>=514'
  assert_eval 0 '(ge (number (raw "114")) (number (raw "514")))'

  parse program '114;514;'
  assert_eval 0 '(pair (number (raw "114")) (pair (number (raw "514")) (nil)))'

  parse program 'a=19;'
  assert_eval 0 '(pair (assign (number (raw "19")) (identifier (raw "a"))) (nil))'

  parse program '_camel_case;'
  assert_eval 0 '(pair (identifier (raw "_camel_case")) (nil))'

  parse program 'SnakeCase;'
  assert_eval 0 '(pair (identifier (raw "SnakeCase")) (nil))'

  #codegen
  parse expression '114514'
  assert_eval 0 '(number (raw "114514"))'
  #codegen ${fn_result}

  parse expression '114514*810/1919'
  codegen ${fn_result} > a.s
  gcc a.s
  ./a.out; echo $?

  parse memo_s '((((((((1))))))))'
}

test_func

