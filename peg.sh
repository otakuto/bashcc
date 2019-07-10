#!/bin/bash

text=
pos=0

declare -A heap
heap_count=0

fn_ret=
fn_result=

declare -A memo_table
MEMO_BEGIN='eval
  local _pos=${pos};
  if [[ -v memo_table[${pos},${FUNCNAME}] ]]; then
    set -- ${memo_table[${pos},${FUNCNAME}]};
    pos=$1;
    fn_ret=$2;
    fn_result=$3;
    return ${fn_ret};
  fi;
'
MEMO_END='eval
  memo_table[${_pos},${FUNCNAME}]="${pos} ${fn_ret} ${fn_result}";
  return ${fn_ret};
'

M='eval
  if [[ ${fn_ret} = 1 ]]; then
    fn_result=;
    fn_ret=1;
    ${MEMO_END};
    return 1;
  fi;
'

OR='eval
  if [[ ${fn_ret} = 0 ]]; then
    fn_ret=0;
    ${MEMO_END};
    return 0;
  fi;
'

length()
{
  local l=0
  local h=(${heap[${1}]})

  while [[ "${h[0]}" = 'pair' ]]; do
    h=(${heap[${h[2]}]})
    l=$((l + 1))
  done

  fn_result=${l}
  fn_ret=0
}

reverse()
{
  local n="${1}"
  heap[$((++heap_count))]='nil'
  local p="${heap_count}"

  while :; do
    set -- ${heap[${n}]}
    if [[ "${1}" = 'pair' ]]; then
      n=${3}
      heap[$((++heap_count))]="pair ${2} ${p}"
      p="${heap_count}"
    else
      fn_result="${p}"
      fn_ret=0
      return 0
    fi
  done
}

foldl()
{
  local f="${1}"
  local v="${2}"
  set -- ${heap[${3}]}
  if [[ "${1}" = "pair" ]]; then
    v=$(eval "${f} '${v}' ${2}")
    foldl "${f}" "${v}" "${3}"
  else
    echo -n "${v}"
  fi
}

parse()
{
  text="${2}"
  pos=0
  heap_count=0
  unset heap
  declare -g -A heap
  unset memo_table
  declare -g -A memo_table

  eval ${1}
}

string()
{
  local str=$1

  local len=${#str}
  local s=${text:pos:len}
  if [[ "${s}" = "${str}" ]]; then
    pos=$((pos + len))
    heap[$((++heap_count))]="${s}"
    heap[$((++heap_count))]="raw ${heap_count}"
    fn_result="${heap_count}"
    fn_ret=0
    return 0
  else
    fn_result=''
    fn_ret=1
    return 1
  fi
}

many()
{
  local p="$((++heap_count))"
  local h="${p}"

  while try "${@}"; do
    heap[${p}]="pair ${fn_result} $((++heap_count))"
    p="${heap_count}"
  done

  heap[${p}]='nil'

  fn_result="${h}"
  fn_ret=0
  return 0
}

many1()
{
  if ! try "${@}"; then
    fn_result=
    fn_ret=1
    return 1
  fi
  local h=${fn_result}

  many "${@}"

  heap[$((++heap_count))]="pair ${h} ${fn_result}"
  fn_result="${heap_count}"
  fn_ret=0
  return 0
}

skipMany()
{
  while try "${@}"; do
    :
  done

  fn_result=
  fn_ret=0
  return 0
}

skipMany1()
{
  if ! try "${@}"; then
    fn_result=
    fn_ret=1
    return 1
  fi

  skipMany "${@}"
}

sepBy()
{
  if sepBy1 "${1}" "${2}"; then
    :
  else
    heap[$((++heap_count))]='nil'
    fn_result=${heap_count}
    fn_ret=0
  fi

  return 0
}

sepBy1()
{
  if ! try "${2}"; then
    fn_result=
    fn_ret=1
    return 1
  fi
  local h=${fn_result}

  local f="eval
    eval ${1}; \${M};
    eval ${2}; \${M};
  "

  many "${f}"

  heap[$((++heap_count))]="pair ${h} ${fn_result}"
  fn_result=${heap_count}
  fn_ret=0
}

between()
{
  eval "${1}"; ${M}
  eval "${3}"; ${M}
  local x=${fn_result}
  eval "${2}"; ${M}

  fn_result=${x}
  fn_ret=0
}

choice()
{
  local p=
  for p in "${@}"; do
    if eval "${p}"; then
      return ${fn_ret}
    fi
  done
  fn_result=
  fn_ret=1
  return ${fn_ret}
}

try()
{
  local p=${pos}
  eval ${@}
  if [[ ${fn_ret} != 0 ]]; then
    pos=${p}
  fi
  return ${fn_ret}
}


print_memo()
{
  echo 'memo_table'
  for k in ${!memo_table[@]}; do
    echo ${k}=${memo_table[$k]}
  done
  echo
}

print_heap()
{
  echo 'heap'
  for k in ${!heap[@]}; do
    echo ${k}=${heap[$k]}
  done
  echo
}

show_ast()
{
  local node=(${heap[${1}]})
  if [[ ${node[0]} = 'raw' ]]; then
    echo -n "(raw \"${heap[${node[1]}]}\")"
  else
    echo -n '('
    echo -n "${node[0]}"
    local e=
    for e in "${node[@]:1}"; do
      echo -n ' '
      show_ast "${e}"
    done
    echo -n ')'
  fi
}

