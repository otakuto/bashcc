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
  elif [[ ${h[0]} = 'eq' ]]; then
    echo 'cmp rax, rdi'
    echo 'sete al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'ne' ]]; then
    echo 'cmp rax, rdi'
    echo 'setne al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'lt' ]]; then
    echo 'cmp rax, rdi'
    echo 'setl al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'le' ]]; then
    echo 'cmp rax, rdi'
    echo 'setle al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'gt' ]]; then
    echo 'cmp rdi, rax'
    echo 'setl al'
    echo 'movzb rax, al'
    echo 'push rax'
  elif [[ ${h[0]} = 'ge' ]]; then
    echo 'cmp rdi, rax'
    echo 'setle al'
    echo 'movzb rax, al'
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
