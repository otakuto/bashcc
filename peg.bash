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


function concat()
{
  local l=${1:5}
  local a=
  for e in ${l}; do
    a="${a}${e}"
  done
  echo ${a}
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
    fn_result=${s}
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
  local v=(list)

  while :
  do
    if try ${@}; then
      v+=(${fn_result})
    else
      break
    fi
  done

  heap[$((++heap_count))]=${v[@]}
  fn_result=${heap_count}
  fn_ret=0
  return 0
}

function many1()
{
  local v=(list)

  while :
  do
    if try ${@}; then
      v+=(${fn_result})
    else
      break
    fi
  done

  if [[ ${#v[@]} = 1 ]]; then
    fn_result=
    fn_ret=1
    return 1
  else
    heap[$((++heap_count))]=${v[@]}
    fn_result=${heap_count}
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
  if [[ ${1} = 'number' ]]; then
    echo "(${1} ${2})"
  elif [[ ${1} = 'list' ]]; then
    shift
    echo -n '('
    local count=0
    for i in "${@}"; do
      echo -n $(show_ast "${heap[${i}]}")
      if [[ ${#@} != $(($count + 1)) ]]; then
        echo -n ' '
      fi
      count=$((++count))
    done
    echo -n ')'
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

