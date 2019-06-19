#!/bin/bash

text=
pos=0

declare -A heap
heap_count=0

fn_ret=
fn_result=

declare -A memo_table
MEMO_BEGIN="$(cat << EOL
  local _pos=\${pos}
  if [[ -v memo_table[\${pos},\${FUNCNAME}] ]]; then
    #echo hit
    #echo \${FUNCNAME}
    #echo \${pos}
    #echo \${memo_table[\${pos},\${FUNCNAME}]}
    #echo
    set -- \${memo_table[\${pos},\${FUNCNAME}]}
    pos=\$1
    fn_ret=\$2
    fn_result=\$3
    return \${fn_ret}
  fi
EOL
)"
MEMO_END="$(cat << EOL
  memo_table[\${_pos},\${FUNCNAME}]="\${pos} \${fn_ret} \${fn_result}"
  return \${fn_ret}
EOL
)"

M="$(cat << EOL
if [[ \${fn_ret} = 1 ]]; then
  fn_result=
  fn_ret=1
  eval "\${MEMO_END}"
  return 1
fi
EOL
)"

OR="$(cat << EOL
if [[ \${fn_ret} = 0 ]]; then
  fn_ret=0
  eval "\${MEMO_END}"
  return 0
fi
EOL
)"


function assert()
{
  if [[ ${fn_ret} != ${1} || ${fn_result[@]} != ${2} ]]; then
    echo Error
    echo ret ${1} ${fn_ret}
    echo result \'${2}\' \'${fn_result[@]}\'
    echo
  fi
}

function assert_eval()
{
  ev=$(show_ast "${heap[${fn_result}]}")
  if [[ ${fn_ret} != ${1} || ${ev} != ${2} ]]; then
    echo Error
    echo ${text}
    echo ret ${1} ${fn_ret}
    echo result \'${2}\' \'${ev}\'
    echo
  fi
}


function reverse()
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

function foldl()
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

function parse()
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

function string()
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

function many()
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

function many1()
{
  local p="$((++heap_count))"
  local h="${p}"

  while try "${@}"; do
    heap[${p}]="pair ${fn_result} $((++heap_count))"
    p="${heap_count}"
  done

  heap[${p}]='nil'

  if [[ "${heap[${h}]}" = 'nil' ]]; then
    fn_result=
    fn_ret=1
    return 1
  else
    fn_result="${h}"
    fn_ret=0
    return 0
  fi
}

function try()
{
  local p=${pos}
  eval ${@}
  if [[ ${fn_ret} != 0 ]]; then
    pos=${p}
  fi
  return ${fn_ret}
}


function print_memo()
{
  echo 'memo_table'
  for k in ${!memo_table[@]}; do
    echo ${k}=${memo_table[$k]}
  done
  echo
}

function print_heap()
{
  echo 'heap'
  for k in ${!heap[@]}; do
    echo ${k}=${heap[$k]}
  done
  echo
}

function show_ast()
{
  set -- $1
  if [[ ${1} = 'nil' ]]; then
    echo "nil"
  elif [[ ${1} = 'raw' ]]; then
    echo "(raw \"${heap[${2}]}\")"
  else
    echo -n "(${1} "
    shift
    local count=0
    for i in "${@}"; do
      echo -n $(show_ast "${heap[${i}]}")
      if [[ ${#@} != $(($count + 1)) ]]; then
        echo -n ' '
      fi
      count=$((++count))
    done
    echo -n ')'
  fi
}

