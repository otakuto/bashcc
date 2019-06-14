#!/bin/bash

source peg.sh

function expression()
{
  equality
}

function equality()
{
  eval "${MEMO_BEGIN}"

  relational; eval "${M}"
  local n=${fn_result}

  many equality_0; eval "${M}"
  local a=(${heap[$fn_result]})

  if [[ ${#a[@]} = 1 ]]; then
    fn_result=${n}
    fn_ret=0
  else
    local p=${n}
    for e in ${a[@]:1}; do
      local e=(${heap[${e}]})
      heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
      p=${heap_count}
    done
    fn_result=${heap_count}
    fn_ret=0
  fi

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
  local n=${fn_result}

  many relational_0; eval "${M}"
  local a=(${heap[$fn_result]})

  if [[ ${#a[@]} = 1 ]]; then
    fn_result=${n}
    fn_ret=0
  else
    local p=${n}
    for e in ${a[@]:1}; do
      local e=(${heap[${e}]})
      heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
      p=${heap_count}
    done
    fn_result=${heap_count}
    fn_ret=0
  fi

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
  local n=${fn_result}

  many add_0; eval "${M}"
  local a=(${heap[$fn_result]})

  if [[ ${#a[@]} = 1 ]]; then
    fn_result=${n}
    fn_ret=0
  else
    local p=${n}
    for e in ${a[@]:1}; do
      local e=(${heap[${e}]})
      heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
      p=${heap_count}
    done
    fn_result=${heap_count}
    fn_ret=0
  fi

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
  local n=${fn_result}

  many mul_0; eval "${M}"
  local a=(${heap[$fn_result]})

  if [[ ${#a[@]} = 1 ]]; then
    fn_result=${n}
    fn_ret=0
  else
    local p=${n}
    for e in ${a[@]:1}; do
      local e=(${heap[${e}]})
      heap[$((++heap_count))]="${e[0]} ${p} ${e[1]}"
      p=${heap_count}
    done
    fn_result=${heap_count}
    fn_ret=0
  fi

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

  string '('; eval "${M}"
  expression; eval "${M}"
  local v=${fn_result}
  string ')'; eval "${M}"

  fn_result=${v}
  fn_ret=0
  eval "${MEMO_END}"
}

function number()
{
  eval "${MEMO_BEGIN}"

  many1 digit; eval "${M}"
  local v=$(concat "${heap[$fn_result]}")

  heap[$((++heap_count))]="number ${v}"
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

