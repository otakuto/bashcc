#!/bin/bash

function gen()
{
  local h=(${heap[${1}]})

  if [[ ${h[0]} = 'number' ]]; then
    echo "push ${h[1]}"
    return 0
  fi

  gen "${h[1]}"
  gen "${h[2]}"

  echo 'pop rdi'
  echo 'pop rax'

  if [[ ${h[0]} = 'add' ]]; then
    echo 'add rax, rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'sub' ]]; then
    echo 'sub rax, rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'mul' ]]; then
    echo 'mul rdi'
    echo 'push rax'
  elif [[ ${h[0]} = 'div' ]]; then
    echo 'mov rdx, 0'
    echo 'div rdi'
    echo 'push rax'
  fi
}

function codegen()
{
  echo '.intel_syntax noprefix'
  echo '.global main'
  echo 'main:'
  gen "${1}"
  echo 'pop rax'
  echo 'ret'
}
