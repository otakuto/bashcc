#!/bin/bash

source peg.sh

func_name=
declare -A symbol
declare -A offset

betweenManySpace()
{
  between 'skipMany space' 'skipMany space' ${@}
}

space()
{
  ${MEMO_BEGIN}
  string ' '; ${OR}
  string $'\t'; ${OR}
  string $'\n'; ${M}
  ${MEMO_END}
}

program()
{
  ${MEMO_BEGIN}
  func_name=
  unset symbol
  declare -g -A symbol
  unset offset
  declare -g -A offset

  many function_definition; ${M}

  ${MEMO_END}
}

function_definition()
{
  ${MEMO_BEGIN}

  string 'int'; ${M}
  skipMany1 space; ${M}
  new 'i32'
  local t=${fn_result}
  new 'nil'
  new "type ${t} ${fn_result}"
  local ret=${fn_result}

  identifier; ${M}
  local i=${fn_result}
  local raw=(${heap[${i}]})
  func_name="${heap[${raw[1]}]}"
  offset[${func_name}]=0

  parameter; ${M}
  local p=${fn_result}

  block; ${M}
  local b=${fn_result}

  new "function ${i} ${p} ${ret} ${b}"

  ${MEMO_END}
}

parameter()
{
  ${MEMO_BEGIN}

  between 'string "("' 'string ")"' 'sepBy "string ," declarator'; ${M}

  ${MEMO_END}
}

statement()
{
  ${MEMO_BEGIN}

  try return_statement; ${OR}
  try if_statement; ${OR}
  try while_statement; ${OR}
  try for_statement; ${OR}
  try block; ${OR}
  expression; ${M}
  local e=${fn_result}
  string ';'; ${M}

  new "statement ${e}"

  ${MEMO_END}
}

return_statement()
{
  ${MEMO_BEGIN}

  string 'return'; ${M}
  skipMany1 space; ${M}
  expression; ${M}
  local e=${fn_result}
  string ';'; ${M}

  new "return ${e}"

  ${MEMO_END}
}

if_statement()
{
  ${MEMO_BEGIN}

  string 'if'; ${M}
  skipMany space; ${M}
  between 'string "("' 'string ")"' expression; ${M}
  local c=${fn_result}

  statement; ${M}
  local t=${fn_result}

  if try string 'else'; then
    skipMany1 space; ${M}
    statement; ${M}
    local e=${fn_result}

    new "if ${c} ${t} ${e}"
  else
    new 'nil'
    new "if ${c} ${t} ${fn_result}"
  fi

  ${MEMO_END}
}

while_statement()
{
  ${MEMO_BEGIN}

  string 'while'; ${M}
  skipMany space; ${M}
  between 'string "("' 'string ")"' expression; ${M}
  local cond=${fn_result}

  statement; ${M}
  local s=${fn_result}

  new "while ${cond} ${s}"

  ${MEMO_END}
}

for_statement()
{
  ${MEMO_BEGIN}

  string 'for'; ${M}
  skipMany space; ${M}
  string '('; ${M}

  local init=
  if try expression; then
    init=${fn_result}
  else
    new 'nil'
    init=${fn_result}
  fi

  string ';'; ${M}

  local cond=
  if try expression; then
    cond=${fn_result}
  else
    new 'nil'
    cond=${fn_result}
  fi

  string ';'; ${M}

  local iter=
  if try expression; then
    iter=${fn_result}
  else
    new 'nil'
    iter=${fn_result}
  fi

  string ')'; ${M}

  statement; ${M}
  local s=${fn_result}

  new "for ${init} ${cond} ${iter} ${s}"

  ${MEMO_END}
}

block()
{
  ${MEMO_BEGIN}

  between 'string "{"' 'string "}"' 'many choice \"try declaration\" \"try statement\"'; ${M}
  new "block ${fn_result}"

  ${MEMO_END}
}

declaration()
{
  ${MEMO_BEGIN}

  declarator; ${M}
  local d=${fn_result}
  string ';'; ${M}

  fn_result=${d}
  fn_ret=0

  ${MEMO_END}
}

declarator()
{
  ${MEMO_BEGIN}

  ptr()
  {
    skipMany space; ${M}
    string '*'; ${M}

    new 'ptr'
  }

  string 'int'; ${M}
  new 'i32'
  local last=${fn_result}

  local init=
  if try skipMany1 space; then
    many ptr; ${M}
    init=${fn_result}
  else
    many1 ptr; ${M}
    init=${fn_result}
  fi

  new 'nil'
  new "type ${last} ${fn_result}"
  local t=${fn_result}

  reverse ${init}
  local l=${fn_result}

  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    new "type ${e[1]} ${t}"
    t=${fn_result}
  done

  identifier; ${M}
  local i=${fn_result}

  local raw=(${heap[${i}]})
  local s=(${heap[${raw[1]}]})

  if [[ -z ${symbol[${func_name},${s}]} ]]; then
    local c=(${heap[${t}]})
    if [[ ${heap[${c[1]}]} = 'ptr' ]]; then
      offset[${func_name}]=$((${offset[${func_name}]} + 8))
    else
      offset[${func_name}]=$((${offset[${func_name}]} + 8))
    fi
    symbol[${func_name},${s}]="${offset[${func_name}]} ${t}"
  fi

  new "declare ${i} ${t}"

  ${MEMO_END}
}

expression()
{
  ${MEMO_BEGIN}

  assign; ${M}

  ${MEMO_END}
}

assign()
{
  ${MEMO_BEGIN}

  equality; ${M}
  local lhs=${fn_result}

  assign_0()
  {
    string '='; ${M}
    assign; ${M}

    new "assign ${fn_result}"
  }

  if try assign_0; then
    local rhs=${fn_result}
    local e=(${heap[${rhs}]})
    new "${e[0]} ${e[1]} ${lhs}"
  else
    fn_result=${lhs}
    fn_ret=0
  fi

  ${MEMO_END}
}

equality()
{
  ${MEMO_BEGIN}

  relational; ${M}
  local head=${fn_result}

  many equality_0; ${M}
  local tail=${fn_result}

  local p=${head}
  local l=${tail}
  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    e=(${heap[${e[1]}]})
    new "${e[0]} ${p} ${e[1]}"
    p=${fn_result}
  done
  fn_result=${p}
  fn_ret=0

  ${MEMO_END}
}

equality_0()
{
  local op=

  if try string '=='; then
    op='eq'
  elif try string '!='; then
    op='ne'
  else
    fn_result=
    fn_ret=1
    return 1
  fi

  relational; ${M}

  new "${op} ${fn_result}"
}

relational()
{
  ${MEMO_BEGIN}

  add; ${M}
  local head=${fn_result}

  many relational_0; ${M}
  local tail=${fn_result}

  local p=${head}
  local l=${tail}
  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    e=(${heap[${e[1]}]})
    new "${e[0]} ${p} ${e[1]}"
    p=${fn_result}
  done
  fn_result=${p}
  fn_ret=0

  ${MEMO_END}
}

relational_0()
{
  local op=

  lt()
  {
    string '<'; ${M}
    add; ${M}
  }
  le()
  {
    string '<='; ${M}
    add; ${M}
  }
  gt()
  {
    string '>'; ${M}
    add; ${M}
  }
  ge()
  {
    string '>='; ${M}
    add; ${M}
  }

  if try lt; then
    op='lt'
  elif try le; then
    op='le'
  elif try gt; then
    op='gt'
  elif try ge; then
    op='ge'
  else
    fn_result=
    fn_ret=1
    return 1
  fi

  new "${op} ${fn_result}"
}

add()
{
  ${MEMO_BEGIN}

  mul; ${M}
  local head=${fn_result}

  many add_0; ${M}
  local tail=${fn_result}

  local p=${head}
  local l=${tail}
  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    e=(${heap[${e[1]}]})
    new "${e[0]} ${p} ${e[1]}"
    p=${fn_result}
  done
  fn_result=${p}
  fn_ret=0

  ${MEMO_END}
}

add_0()
{
  local t=

  if try string '+'; then
    t='add'
  elif try string '-'; then
    t='sub'
  else
    fn_result=
    fn_ret=1
    return 1
  fi

  mul; ${M}

  new "${t} ${fn_result}"
}

mul()
{
  ${MEMO_BEGIN}

  unary; ${M}
  local head=${fn_result}

  many mul_0; ${M}
  local tail=${fn_result}

  local p=${head}
  local l=${tail}
  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    e=(${heap[${e[1]}]})
    new "${e[0]} ${p} ${e[1]}"
    p=${fn_result}
  done
  fn_result=${p}
  fn_ret=0

  ${MEMO_END}
}

mul_0()
{
  local t=

  if try string '\*'; then
    t='mul'
  elif try string '/'; then
    t='div'
  else
    fn_result=
    fn_ret=1
    return 1
  fi

  unary; ${M}

  new "${t} ${fn_result}"
}

unary()
{
  ${MEMO_BEGIN}

  local op=
  if try string '+'; then
    :
  elif try string '-'; then
    op='minus'
  elif try string '\*'; then
    op='dereference'
  elif try string '\&'; then
    op='addressof'
  fi

  term; ${M}

  if [[ -n "${op}" ]]; then
    new "${op} ${fn_result}"
  fi

  ${MEMO_END}
}

term()
{
  ${MEMO_BEGIN}
  try number; ${OR}

  if try identifier; then
    local i=${fn_result}
    if try argument; then
      new "call ${i} ${fn_result}"
      ${MEMO_END}
    else
      new "variable ${i}"
      ${MEMO_END}
    fi
  fi

  between 'string "("' 'string ")"' expression; ${M}

  ${MEMO_END}
}

argument()
{
  ${MEMO_BEGIN}

  between 'string "("' 'string ")"' 'sepBy "string ," expression'; ${M}

  ${MEMO_END}
}

append()
{
  local v="${1}"
  set -- ${heap[${2}]}
  echo -n "${v}${heap[${2}]}"
}

number()
{
  ${MEMO_BEGIN}

  many1 digit; ${M}
  local v=$(foldl append '' "${fn_result}")

  new "${v}"
  new "raw ${fn_result}"
  new "number ${fn_result}"

  ${MEMO_END}
}

digit()
{
  ${MEMO_BEGIN}

  oneOf {0..9}; ${M}

  ${MEMO_END}
}

identifier()
{
  ${MEMO_BEGIN}

  oneOf _ {a..z} {A..Z}; ${M}
  local h=${fn_result}
  local raw=(${heap[${h}]})
  local c=${heap[${raw[1]}]}

  many oneOf _ {a..z} {A..Z} {0..9}; ${M}
  local s="$(foldl append "${c}" "${fn_result}")"

  new "${s}"
  new "raw ${fn_result}"

  ${MEMO_END}
}

