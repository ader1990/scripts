#!/bin/bash


set -xe -o pipefail

cat new_packages.txt  | xargs -L1 emerge-riscv-usr --noreplace
