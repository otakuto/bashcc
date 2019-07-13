#!/bin/bash

source peg.sh

func_name=
declare -A symbol
declare -A offset

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
  heap[$((++heap_count))]='i32'
  local t=${heap_count}
  heap[$((++heap_count))]='nil'
  heap[$((++heap_count))]="type ${t} ${heap_count}"
  local ret=${heap_count}

  identifier; ${M}
  local i=${fn_result}
  local raw=(${heap[${i}]})
  func_name="${heap[${raw[1]}]}"
  offset[${func_name}]=0

  parameter; ${M}
  local p=${fn_result}

  block; ${M}
  local b=${fn_result}

  heap[$((++heap_count))]="function ${i} ${p} ${ret} ${b}"
  fn_result=${heap_count}
  fn_ret=0

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

  heap[$((++heap_count))]="statement ${e}"
  fn_result=${heap_count}
  fn_ret=0

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

  heap[$((++heap_count))]="return ${e}"
  fn_result=${heap_count}
  fn_ret=0

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

    heap[$((++heap_count))]="if ${c} ${t} ${e}"
    fn_result=${heap_count}
    fn_ret=0
  else
    heap[$((++heap_count))]='nil'
    heap[$((++heap_count))]="if ${c} ${t} ${heap_count}"
    fn_result=${heap_count}
    fn_ret=0
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

  heap[$((++heap_count))]="while ${cond} ${s}"
  fn_result=${heap_count}
  fn_ret=0

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
    heap[$((++heap_count))]='nil'
    init=${heap_count}
  fi

  string ';'; ${M}

  local cond=
  if try expression; then
    cond=${fn_result}
  else
    heap[$((++heap_count))]='nil'
    cond=${heap_count}
  fi

  string ';'; ${M}

  local iter=
  if try expression; then
    iter=${fn_result}
  else
    heap[$((++heap_count))]='nil'
    iter=${heap_count}
  fi

  string ')'; ${M}

  statement; ${M}
  local s=${fn_result}

  heap[$((++heap_count))]="for ${init} ${cond} ${iter} ${s}"
  fn_result=${heap_count}
  fn_ret=0

  ${MEMO_END}
}

block()
{
  ${MEMO_BEGIN}

  between 'string "{"' 'string "}"' 'many choice \"try declaration\" \"try statement\"'; ${M}
  heap[$((++heap_count))]="block ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0

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

    heap[$((++heap_count))]='ptr'
    fn_result=${heap_count}
    fn_ret=0
  }

  string 'int'; ${M}
  heap[$((++heap_count))]='i32'
  local last=${heap_count}

  local init=
  if try skipMany1 space; then
    many ptr; ${M}
    init=${fn_result}
  else
    many1 ptr; ${M}
    init=${fn_result}
  fi

  heap[$((++heap_count))]='nil'
  heap[$((++heap_count))]="type ${last} ${heap_count}"

  local t=${heap_count}
  reverse ${init}
  local l=${fn_result}
  while [[ "${heap[${l}]}" != 'nil' ]]; do
    local e=(${heap[${l}]})
    l=${e[2]}
    heap[$((++heap_count))]="type ${e[1]} ${t}"
    t=${heap_count}
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

  heap[$((++heap_count))]="declare ${i} ${t}"
  fn_result=${heap_count}
  fn_ret=0

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

    heap[$((++heap_count))]="assign ${fn_result}"
    fn_result=${heap_count}
    fn_ret=0
    return 0
  }

  if try assign_0; then
    local rhs=${fn_result}
    local e=(${heap[${rhs}]})
    heap[$((++heap_count))]="${e[0]} ${e[1]} ${lhs}"
    fn_result=${heap_count}
    fn_ret=0
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
    heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
    p=${heap_count}
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

  heap[$((++heap_count))]="${op} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
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
    heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
    p=${heap_count}
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

  heap[$((++heap_count))]="${op} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
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
    heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
    p=${heap_count}
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

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
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
    heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
    p=${heap_count}
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

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
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
    heap[$((++heap_count))]="${op} ${fn_result}"
    fn_result=${heap_count}
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
      heap[$((++heap_count))]="call ${i} ${fn_result}"
      fn_result=${heap_count}
      fn_ret=0
      ${MEMO_END}
    else
      heap[$((++heap_count))]="variable ${i}"
      fn_result=${heap_count}
      fn_ret=0
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

  heap[$((++heap_count))]="${v}"
  heap[$((++heap_count))]="raw ${heap_count}"
  heap[$((++heap_count))]="number ${heap_count}"
  fn_result=${heap_count}
  fn_ret=0
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

  heap[$((++heap_count))]="${s}"
  heap[$((++heap_count))]="raw ${heap_count}"

  fn_result=${heap_count}
  fn_ret=0
  ${MEMO_END}
}

