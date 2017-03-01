#!/bin/bash

pushd $(dirname $0) > /dev/null

cd $(pwd -P)/..

doc_count=0
missing_count=0

function check_index {
    line=$(grep "$1" ./doc/mkdocs/mkdocs.yml)

    if [ -f "$1" ] && [ -z "$line" ]; then
        ((missing_count+=1))
        echo "'$1' missing"
    fi
}

docs=$(find {scripts,doc,core,applications} \( -path 'doc/mkdocs' -o -path 'applications/*/doc/ref' \) -prune -o -type f -regex ".+\.md$")
for doc in $docs; do
    ((doc_count+=1))
    check_index $doc
done

# if [[ $missing ]]; then
    ratio=$((100 * $missing_count / $doc_count))
    echo "Missing $missing_count / $doc_count: $ratio%"
# fi

popd > /dev/null