#!/bin/bash
isExistApp=$(pgrep -f java)
if [[ -n $isExistApp ]]; then
   kill -9 $isExistApp
fi