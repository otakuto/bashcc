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
  assert 'show_ast ${fn_result}' 0 '(pair (number (raw "114")) (pair (number (raw "514")) (nil)))'

  parse program 'a=19;'
  assert 'show_ast ${fn_result}' 0 '(pair (assign (number (raw "19")) (identifier (raw "a"))) (nil))'

  parse program '_camel_case;'
  assert 'show_ast ${fn_result}' 0 '(pair (identifier (raw "_camel_case")) (nil))'

  parse program 'SnakeCase;'
  assert 'show_ast ${fn_result}' 0 '(pair (identifier (raw "SnakeCase")) (nil))'

  #codegen
  parse expression '114514'
  assert 'show_ast ${fn_result}' 0 '(number (raw "114514"))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 82 ''

  parse expression '114514*810/1919'
  assert 'show_ast ${fn_result}' 0 '(div (mul (number (raw "114514")) (number (raw "810"))) (number (raw "1919")))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 207 ''

  parse memo_s '((((((((1))))))))'
}

test_func

