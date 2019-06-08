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
  assert 0 '123'
  parse 'try string "1234"' '123'
  assert 1 ''

  #digit
  parse digit '0'
  assert 0 '0'
  parse digit '1'
  assert 0 '1'
  parse digit '9'
  assert 0 '9'

  #number
  parse number '0123456789'
  assert_eval 0 '(number 0123456789)'

  #term
  parse term '(1234)'
  assert_eval 0 '(number 1234)'

  #Cexpr
  parse Cexpr '114+514'
  assert_eval 0 '(add (number 114) (number 514))'

  parse Cexpr '114+514-810'
  assert_eval 0 '(sub (add (number 114) (number 514)) (number 810))'

  parse Cexpr '114+(514-810)'
  assert_eval 0 '(add (number 114) (sub (number 514) (number 810)))'

  parse Cexpr '114*514/810'
  assert_eval 0 '(div (mul (number 114) (number 514)) (number 810))'

  parse Cexpr '114*(514/810)'
  assert_eval 0 '(mul (number 114) (div (number 514) (number 810)))'

  parse Cexpr '114+514+1919+810'
  assert_eval 0 '(add (add (add (number 114) (number 514)) (number 1919)) (number 810))'

  parse Cexpr '-(514*810)'
  assert_eval 0 '(minus (mul (number 514) (number 810)))'

  #codegen
  parse Cexpr '114514'
  assert_eval 0 '(number 114514)'
  #codegen ${fn_result}

  parse Cexpr '114514*810/1919'
  codegen ${fn_result} > a.s
  gcc a.s
  ./a.out; echo $?

  parse memo_s '((((((((1))))))))'
}

test_func

