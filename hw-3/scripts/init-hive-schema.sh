#!/bin/bash
set -e

source ~/.profile
"$HIVE_HOME/bin/schematool" -dbType postgres -initSchema