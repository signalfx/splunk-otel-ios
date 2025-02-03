#!/bin/bash


### Help Function

Help()
{
   # Display Help
   echo "Swift code linting for Xcode."
   echo
   echo "Syntax: scriptTemplate [--help|config]"
   echo "options:"
   echo "--help     Print this Help."
   echo "--config   File path to .swiftlint.yml configuration file."
   echo
}

### Params handling

POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      Help
      shift # past argument
      shift # past value
      ;;
    -c|--config)
      LINTING_CONFIG="$2"
      shift # past argument
      shift # past value
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1") # save positional arg
      shift # past argument
      ;;
  esac
done


### Linting script

# Do not run when releasing
if [ "${CONFIGURATION}" = "Release" ]; then
  echo Skipping lint
  exit 0;
fi

# on arm64 macOS, homebrew is custom build into /opt/homebrew
PATH=${PATH}:/opt/homebrew/bin/

if which swiftlint >/dev/null; then
  swiftlint --config $LINTING_CONFIG --quiet
else
  echo "warning: SwiftLint not installed, download from https://github.com/realm/SwiftLint"
fi

if which swiftformat >/dev/null; then
  swiftformat . --lenient --lint --commas inline --stripunusedargs closure-only --swiftversion 5 --disable indent,consecutiveBlankLines,wrapMultilineStatementBraces, braces,enumNamespaces,blankLinesAtStartOfScope
else
  echo "warning: SwiftFormat not installed, download from https://github.com/nicklockwood/SwiftFormat"
fi
