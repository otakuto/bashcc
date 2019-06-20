#!/bin/bash

source peg.sh

declare -A symbol
offset=0

function program()
{
  eval "${MEMO_BEGIN}"

  many statement; eval "${M}"

  eval "${MEMO_END}"
}

function statement()
{
  eval "${MEMO_BEGIN}"

  expression; eval "${M}"
  local e=${fn_result}
  string ';'; eval "${M}"

  fn_result=${e}
  fn_ret=0

  eval "${MEMO_END}"
}

function expression()
{
  eval "${MEMO_BEGIN}"

  assign; eval "${M}"

  eval "${MEMO_END}"
}

function assign()
{
  eval "${MEMO_BEGIN}"

  equality; eval "${M}"
  local lhs=${fn_result}

  function assign_0()
  {
    string '='; eval "${M}"
    assign; eval "${M}"

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

  eval "${MEMO_END}"
}

function equality()
{
  eval "${MEMO_BEGIN}"

  relational; eval "${M}"
  local head=${fn_result}

  many equality_0; eval "${M}"
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

  eval "${MEMO_END}"
}

function equality_0()
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

  relational; eval "${M}"

  heap[$((++heap_count))]="${op} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
}

function relational()
{
  eval "${MEMO_BEGIN}"

  add; eval "${M}"
  local head=${fn_result}

  many relational_0; eval "${M}"
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

  eval "${MEMO_END}"
}

function relational_0()
{
  local op=

  function lt()
  {
    string '<'; eval "${M}"
    add; eval "${M}"
  }
  function le()
  {
    string '<='; eval "${M}"
    add; eval "${M}"
  }
  function gt()
  {
    string '>'; eval "${M}"
    add; eval "${M}"
  }
  function ge()
  {
    string '>='; eval "${M}"
    add; eval "${M}"
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

function add()
{
  eval "${MEMO_BEGIN}"

  mul; eval "${M}"
  local head=${fn_result}

  many add_0; eval "${M}"
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

  eval "${MEMO_END}"
}

function add_0()
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

  mul; eval "${M}"

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
}

function mul()
{
  eval "${MEMO_BEGIN}"

  unary; eval "${M}"
  local head=${fn_result}

  many mul_0; eval "${M}"
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

  eval "${MEMO_END}"
}

function mul_0()
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

  unary; eval "${M}"

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
}

function unary()
{
  eval "${MEMO_BEGIN}"

  local op=
  if try string '+'; then
    :
  elif try string '-'; then
    op='minus'
  fi

  term; eval "${M}"

  if [[ -n "${op}" ]]; then
    heap[$((++heap_count))]="${op} ${fn_result}"
    fn_result=${heap_count}
  fi

  eval "${MEMO_END}"
}

function term()
{
  eval "${MEMO_BEGIN}"
  try number; eval "${OR}"

  try identifier; eval "${OR}"

  string '('; eval "${M}"
  expression; eval "${M}"
  local v=${fn_result}
  string ')'; eval "${M}"

  fn_result=${v}
  fn_ret=0
  eval "${MEMO_END}"
}

function append()
{
  local v="${1}"
  set -- ${heap[${2}]}
  echo -n "${v}${heap[${2}]}"
}

function number()
{
  eval "${MEMO_BEGIN}"

  many1 digit; eval "${M}"
  local v=$(foldl append '' "${fn_result}")

  heap[$((++heap_count))]="${v}"
  heap[$((++heap_count))]="raw ${heap_count}"
  heap[$((++heap_count))]="number ${heap_count}"
  fn_result=${heap_count}
  fn_ret=0
  eval "${MEMO_END}"
}

function digit()
{
  eval "${MEMO_BEGIN}"
  local i=
  for i in {0..9}; do
    if try string ${i}; then
      fn_ret=0
      eval "${MEMO_END}"
    fi
  done
  fn_result=
  fn_ret=1
  eval "${MEMO_END}"
}

function identifier()
{
  eval "${MEMO_BEGIN}"

  local h
  local c
  for c in _ {a..z} {A..Z}; do
    if try string ${c}; then
      h=${c}
      break
    fi
  done

  if [[ -z ${h} ]]; then
    fn_result=
    fn_ret=1
    eval "${MEMO_END}"
  fi

  local s=${c}

  while [[ ! -z ${h} ]]; do
    h=
    for c in _ {a..z} {A..Z} {0..9}; do
      if try string ${c}; then
        h=${c}
        s="${s}${h}"
        break
      fi
    done
  done

  heap[$((++heap_count))]="${s}"
  heap[$((++heap_count))]="raw ${heap_count}"
  heap[$((++heap_count))]="identifier ${heap_count}"

  if [[ -z ${symbol[${s}]} ]]; then
    offset=$((${offset} + 8))
    symbol[${s}]=${offset}
  fi

  fn_result=${heap_count}
  fn_ret=0
  eval "${MEMO_END}"
}

