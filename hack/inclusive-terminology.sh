#!/usr/bin/env bash


CHECK_LIST=(
  'black hat'
  'blacklist'
  'blackout'
  'brownout'
  'cakewalk'
  'disable'
  'female'
  'grandfathered'
  'handicap'
  'he'
  'him'
  'his'
  'kill'
  'male'
  'rule of thumb'
  'sanity test'
  'sanity check' # real hit
  'segregate'
  'segregation'
  'she'
  'her'
  'hers'
  'slave'
  'suffer'
  'war room'
  'white hat'
  'whitelist'
)

for check in "${CHECK_LIST[@]}"
do
  if grep -riwI "$check" content/ --exclude=\*style-guide.md; then
    echo found "$check"
  fi
done

if grep -riwI "master" content/ | grep -wv 'blob/master'; then
  echo found "master"
fi




