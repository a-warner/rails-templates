#!/bin/sh
set -e

if [ -e $2 ]; then
  TEMPLATE=simple_bootstrap_template.rb
else
  TEMPLATE=$2
fi

rails new $1 -T --skip-bundle -m $(dirname $0)/$TEMPLATE
