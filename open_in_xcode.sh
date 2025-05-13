#!/bin/bash

# Script to open EagleFlow project in Xcode
# Since Swift 5.3+, the Package.swift file can be opened directly in Xcode

echo "Opening EagleFlow in Xcode..."
open -a "/Applications/Homebrew/Xcode-16.3.0.app" /Users/adler/github/EagleFlow/Package.swift