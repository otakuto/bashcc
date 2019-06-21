#!/bin/bash

source peg.sh

declare -A symbol
offset=0

function program()
{
  ${MEMO_BEGIN}

  many statement; ${M}

  ${MEMO_END}
}

function statement()
{
  ${MEMO_BEGIN}

  expression; ${M}
  local e=${fn_result}
  string ';'; ${M}

  fn_result=${e}
  fn_ret=0

  ${MEMO_END}
}

function expression()
{
  ${MEMO_BEGIN}

  assign; ${M}

  ${MEMO_END}
}

function assign()
{
  ${MEMO_BEGIN}

  equality; ${M}
  local lhs=${fn_result}

  function assign_0()
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

function equality()
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

  relational; ${M}

  heap[$((++heap_count))]="${op} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
}

function relational()
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

function relational_0()
{
  local op=

  function lt()
  {
    string '<'; ${M}
    add; ${M}
  }
  function le()
  {
    string '<='; ${M}
    add; ${M}
  }
  function gt()
  {
    string '>'; ${M}
    add; ${M}
  }
  function ge()
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

function add()
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

  mul; ${M}

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
  return 0
}

function mul()
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

  unary; ${M}

  heap[$((++heap_count))]="${t} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
}

function unary()
{
  ${MEMO_BEGIN}

  local op=
  if try string '+'; then
    :
  elif try string '-'; then
    op='minus'
  fi

  term; ${M}

  if [[ -n "${op}" ]]; then
    heap[$((++heap_count))]="${op} ${fn_result}"
    fn_result=${heap_count}
  fi

  ${MEMO_END}
}

function term()
{
  ${MEMO_BEGIN}
  try number; ${OR}

  try identifier; ${OR}

  string '('; ${M}
  expression; ${M}
  local v=${fn_result}
  string ')'; ${M}

  fn_result=${v}
  fn_ret=0
  ${MEMO_END}
}

function append()
{
  local v="${1}"
  set -- ${heap[${2}]}
  echo -n "${v}${heap[${2}]}"
}

function number()
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

function digit()
{
  ${MEMO_BEGIN}
  local i=
  for i in {0..9}; do
    if try string ${i}; then
      fn_ret=0
      ${MEMO_END}
    fi
  done
  fn_result=
  fn_ret=1
  ${MEMO_END}
}

function identifier()
{
  ${MEMO_BEGIN}

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
    ${MEMO_END}
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
  ${MEMO_END}
}

