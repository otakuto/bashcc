#!/bin/bash

source parse.sh
source codegen.sh

assert()
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
memo_s()
{
  ${MEMO_BEGIN}
  memo_a
  ${MEMO_END}
}
memo_a()
{
  ${MEMO_BEGIN}
  try memo_a1; ${OR}
  try memo_a2; ${OR}
  memo_p; ${M}
  ${MEMO_END}
}
memo_a1()
{
  memo_p; ${M}
  string '+'; ${M}
  memo_a; ${M}
}
memo_a2()
{
  memo_p; ${M}
  string '-'; ${M}
  memo_a; ${M}
}
memo_p()
{
  ${MEMO_BEGIN}
  try memo_p1; ${OR}
  memo_p2; ${M}
  ${MEMO_END}
}
memo_p1()
{
  string '('; ${M}
  memo_a; ${M}
  string ')'; ${M}
}
memo_p2()
{
  string '1'; ${M}
  fn_result="1"
}

test_func()
{
  parse 'try string "\*"' '*'
  assert 'show ${fn_result}' 0 '(raw "*")'

  parse 'try string "\&"' '&'
  assert 'show ${fn_result}' 0 '(raw "&")'

  assert "parse 'string d' 'abcdefg'" 1 ''

  parse 'try string "123"' '123'
  assert 'show ${fn_result}' 0 '(raw "123")'

  assert "parse 'try string \"1234\"' '123'" 1 ''

  #oneOf
  parse 'oneOf {0..9}' '8'
  assert 'show ${fn_result}' 0 '(raw "8")'

  parse 'many oneOf {0..9}' '114514'
  assert 'show ${fn_result}' 0 '(pair (raw "1") (pair (raw "1") (pair (raw "4") (pair (raw "5") (pair (raw "1") (pair (raw "4") (nil)))))))'

  assert "parse 'oneOf {a..z}' '1'" 1 ''

  #space
  assert "parse space 'a'" 1 ''
  parse space ' '
  assert 'show ${fn_result}' 0 '(raw " ")'
  parse space $'\t'
  assert 'show ${fn_result}' 0 $'(raw "\t")'
  parse space $'\n'
  assert 'show ${fn_result}' 0 $'(raw "\n")'

  #skipMany
  assert "parse 'skipMany space' 'a'" 0 ''

  #skipMany1
  assert "parse 'skipMany1 space' 'a'" 1 ''
  assert "parse 'skipMany1 space' '  '" 0 ''

  #sepBy
  parse "sepBy 'string ,' number" ''
  assert 'show ${fn_result}' 0 '(nil)'
  parse "sepBy 'many1 space' number" '1 2  3   4'
  assert 'show ${fn_result}' 0 '(pair (number (raw "1")) (pair (number (raw "2")) (pair (number (raw "3")) (pair (number (raw "4")) (nil)))))'

  #sepBy1
  assert 'parse "sepBy1 \"string ,\" number" ""' 1 ''
  parse "sepBy1 'string ,' number" '1,2,3,4,5'
  assert 'show ${fn_result}' 0 '(pair (number (raw "1")) (pair (number (raw "2")) (pair (number (raw "3")) (pair (number (raw "4")) (pair (number (raw "5")) (nil))))))'

  #between
  parse 'between "string \"[\"" "string \"]\"" "string abcd"' '[abcd]'
  assert 'show ${fn_result}' 0 '(raw "abcd")'

  #choice
  parse 'many "choice \"string a\" \"string b\""' 'baba'
  assert 'show ${fn_result}' 0 '(pair (raw "b") (pair (raw "a") (pair (raw "b") (pair (raw "a") (nil)))))'

  #digit
  parse digit '0'
  assert 'show ${fn_result}' 0 '(raw "0")'
  parse digit '1'
  assert 'show ${fn_result}' 0 '(raw "1")'
  parse digit '9'
  assert 'show ${fn_result}' 0 '(raw "9")'

  #number
  parse number '0123456789'
  assert 'show ${fn_result}' 0 '(number (raw "0123456789"))'

  #term
  parse term '(1234)'
  assert 'show ${fn_result}' 0 '(number (raw "1234"))'

  #expression
  parse expression '114+514'
  assert 'show ${fn_result}' 0 '(add (number (raw "114")) (number (raw "514")))'

  parse expression '114+514-810'
  assert 'show ${fn_result}' 0 '(sub (add (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114+(514-810)'
  assert 'show ${fn_result}' 0 '(add (number (raw "114")) (sub (number (raw "514")) (number (raw "810"))))'

  parse expression '114*514/810'
  assert 'show ${fn_result}' 0 '(div (mul (number (raw "114")) (number (raw "514"))) (number (raw "810")))'

  parse expression '114*(514/810)'
  assert 'show ${fn_result}' 0 '(mul (number (raw "114")) (div (number (raw "514")) (number (raw "810"))))'

  parse expression '-(514*810)'
  assert 'show ${fn_result}' 0 '(minus (mul (number (raw "514")) (number (raw "810"))))'

  parse expression '114==514'
  assert 'show ${fn_result}' 0 '(eq (number (raw "114")) (number (raw "514")))'

  parse expression '114!=514'
  assert 'show ${fn_result}' 0 '(ne (number (raw "114")) (number (raw "514")))'

  parse expression '114<514'
  assert 'show ${fn_result}' 0 '(lt (number (raw "114")) (number (raw "514")))'

  parse expression '114<=514'
  assert 'show ${fn_result}' 0 '(le (number (raw "114")) (number (raw "514")))'

  parse expression '114>514'
  assert 'show ${fn_result}' 0 '(gt (number (raw "114")) (number (raw "514")))'

  parse expression '114>=514'
  assert 'show ${fn_result}' 0 '(ge (number (raw "114")) (number (raw "514")))'

  parse block '{114;514;}'
  assert 'show ${fn_result}' 0 '(block (pair (statement (number (raw "114"))) (pair (statement (number (raw "514"))) (nil))))'

  parse statement 'a=19;'
  assert 'show ${fn_result}' 0 '(statement (assign (number (raw "19")) (variable (raw "a"))))'

  parse statement '_camel_case;'
  assert 'show ${fn_result}' 0 '(statement (variable (raw "_camel_case")))'

  parse statement 'SnakeCase;'
  assert 'show ${fn_result}' 0 '(statement (variable (raw "SnakeCase")))'

  #codegen
  parse program 'int main(){return 114514;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (return (number (raw "114514"))) (nil)))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 82 ''

  parse program 'int main(){return 114514*810/1919;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (return (div (mul (number (raw "114514")) (number (raw "810"))) (number (raw "1919")))) (nil)))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 207 ''

  parse program 'int main(){return 114;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (return (number (raw "114"))) (nil)))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 114 ''

  parse program 'int main(){int abc;abc=2*3;return abc*3;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "abc") (type (i32) (nil))) (pair (statement (assign (mul (number (raw "2")) (number (raw "3"))) (variable (raw "abc")))) (pair (return (mul (variable (raw "abc")) (number (raw "3")))) (nil)))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 18 ''

  parse program 'int main(){int a;if (1)a=114;else a=514;return a;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "a") (type (i32) (nil))) (pair (if (number (raw "1")) (statement (assign (number (raw "114")) (variable (raw "a")))) (statement (assign (number (raw "514")) (variable (raw "a"))))) (pair (return (variable (raw "a"))) (nil)))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 114 ''

  parse program 'int main(){int a;if (0)a=114;else a=514;return a;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "a") (type (i32) (nil))) (pair (if (number (raw "0")) (statement (assign (number (raw "114")) (variable (raw "a")))) (statement (assign (number (raw "514")) (variable (raw "a"))))) (pair (return (variable (raw "a"))) (nil)))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 2 ''

  parse program 'int main(){int a;if (1)a=114;if (1)a=514;return a;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "a") (type (i32) (nil))) (pair (if (number (raw "1")) (statement (assign (number (raw "114")) (variable (raw "a")))) (nil)) (pair (if (number (raw "1")) (statement (assign (number (raw "514")) (variable (raw "a")))) (nil)) (pair (return (variable (raw "a"))) (nil))))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 2 ''

  parse program 'int main(){int i;int s;i=0;s=0;while (i<10)s=s+(i=i+1);return s;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "i") (type (i32) (nil))) (pair (declare (raw "s") (type (i32) (nil))) (pair (statement (assign (number (raw "0")) (variable (raw "i")))) (pair (statement (assign (number (raw "0")) (variable (raw "s")))) (pair (while (lt (variable (raw "i")) (number (raw "10"))) (statement (assign (add (variable (raw "s")) (assign (add (variable (raw "i")) (number (raw "1"))) (variable (raw "i")))) (variable (raw "s"))))) (pair (return (variable (raw "s"))) (nil))))))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 55 ''

  parse program 'int main(){int i;int s;s=0;for (i=0;i<=10;i=i+1)s=s+i;return s;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "i") (type (i32) (nil))) (pair (declare (raw "s") (type (i32) (nil))) (pair (statement (assign (number (raw "0")) (variable (raw "s")))) (pair (for (assign (number (raw "0")) (variable (raw "i"))) (le (variable (raw "i")) (number (raw "10"))) (assign (add (variable (raw "i")) (number (raw "1"))) (variable (raw "i"))) (statement (assign (add (variable (raw "s")) (variable (raw "i"))) (variable (raw "s"))))) (pair (return (variable (raw "s"))) (nil)))))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 55 ''

  parse program 'int main(){int i;int s;for (i=0;i<=10;i=i+1){s=0;s=s+i;}return s;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "i") (type (i32) (nil))) (pair (declare (raw "s") (type (i32) (nil))) (pair (for (assign (number (raw "0")) (variable (raw "i"))) (le (variable (raw "i")) (number (raw "10"))) (assign (add (variable (raw "i")) (number (raw "1"))) (variable (raw "i"))) (block (pair (statement (assign (number (raw "0")) (variable (raw "s")))) (pair (statement (assign (add (variable (raw "s")) (variable (raw "i"))) (variable (raw "s")))) (nil))))) (pair (return (variable (raw "s"))) (nil))))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 10 ''

  parse program 'int main(){return f();}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (return (call (raw "f") (nil))) (nil)))) (nil))'

  parse program 'int main(){return f(1,2,3,4,5,6);}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (return (call (raw "f") (pair (number (raw "1")) (pair (number (raw "2")) (pair (number (raw "3")) (pair (number (raw "4")) (pair (number (raw "5")) (pair (number (raw "6")) (nil))))))))) (nil)))) (nil))'

  parse program 'int main(){int a;a=3;int*p;p=&a;*p=42;return a;}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "a") (type (i32) (nil))) (pair (statement (assign (number (raw "3")) (variable (raw "a")))) (pair (declare (raw "p") (type (ptr) (type (i32) (nil)))) (pair (statement (assign (addressof (variable (raw "a"))) (variable (raw "p")))) (pair (statement (assign (number (raw "42")) (dereference (variable (raw "p"))))) (pair (return (variable (raw "a"))) (nil))))))))) (nil))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 42 ''

  parse program 'int f(int a,int b){return a*b;}int main(){int a;int b;a=3;b=8;return f(a,b);}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "f") (pair (declare (raw "a") (type (i32) (nil))) (pair (declare (raw "b") (type (i32) (nil))) (nil))) (type (i32) (nil)) (block (pair (return (mul (variable (raw "a")) (variable (raw "b")))) (nil)))) (pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "a") (type (i32) (nil))) (pair (declare (raw "b") (type (i32) (nil))) (pair (statement (assign (number (raw "3")) (variable (raw "a")))) (pair (statement (assign (number (raw "8")) (variable (raw "b")))) (pair (return (call (raw "f") (pair (variable (raw "a")) (pair (variable (raw "b")) (nil))))) (nil)))))))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 24 ''

  parse program 'int f(int n){if(n==0)return 0;else if(n==1)return 1;else return f(n-1)+f(n-2);}int main(){int n;n=13;return f(n);}'
  assert 'show ${fn_result}' 0 '(pair (function (raw "f") (pair (declare (raw "n") (type (i32) (nil))) (nil)) (type (i32) (nil)) (block (pair (if (eq (variable (raw "n")) (number (raw "0"))) (return (number (raw "0"))) (if (eq (variable (raw "n")) (number (raw "1"))) (return (number (raw "1"))) (return (add (call (raw "f") (pair (sub (variable (raw "n")) (number (raw "1"))) (nil))) (call (raw "f") (pair (sub (variable (raw "n")) (number (raw "2"))) (nil))))))) (nil)))) (pair (function (raw "main") (nil) (type (i32) (nil)) (block (pair (declare (raw "n") (type (i32) (nil))) (pair (statement (assign (number (raw "13")) (variable (raw "n")))) (pair (return (call (raw "f") (pair (variable (raw "n")) (nil)))) (nil)))))) (nil)))'
  codegen ${fn_result} > a.s
  assert 'gcc a.s; ./a.out;' 233 ''

  parse memo_s '((((((((1))))))))'
}

test_func

