#!/bin/bash

# Check if the user is root
if [ $(id -u) -ne 0 ]; then
    echo "emblancher must be run as root."
    exit 1
fi

echo "Starting installer, one moment..."

#check for parameters (--help or --version)
if [ "$1" == "--help" ]; then
    echo "Usage: emblancher [options]"
    echo "Options:"
    echo "  --help     Show this help message and exit"
    echo "  --version  Show the version and exit"
    exit 0
fi

if [ "$1" == "--version" ]; then
    echo "emblancher 1.0.0"
    exit 0
fi
