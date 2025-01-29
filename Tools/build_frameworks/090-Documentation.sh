#!/bin/sh

function is_documented_framework {
    local framework=$1

    # Check params validity
    assert_valid_framework $framework

    if [[ " ${DOCUMENTED_FRAMEWORKS[*]} " =~ "${framework}" ]]; then
        echo true
    else
        echo false
    fi
}

function docarchive_path {
    local framework=$1
    local mach_o_type=$2

    # Check params validity
    assert_valid_framework $framework
    assert_valid_mach_o_type $mach_o_type

    echo "$(distribution_folder $framework $mach_o_type)/${framework}.doccarchive"
}

function build_documentation {
    if [[ ! "$DOCUMENTATION_OPTION" = true ]]; then
        return
    fi

    # Read function params
    local framework=$1

    # Check params validity
    assert_valid_framework $framework

    log "$(log_delimiter)"
    log "📚 Documentation for ${framework}."
    log ''

    if [[ ! "$(is_documented_framework $framework)" = true ]]; then
        log "   ⚠️  The '$framework' does not support generated documentation."
        log ''
        return
    fi

    # Temporary folder for build artefacts
    local temp_build_dir=$(mrum_tempdir "doc-${framework}")


    # Build documentation
    log '     building documentation in a temporary folder...'

    local cmd=""
    cmd+="xcodebuild docbuild"
    cmd+=" -project $(mrum_project)"
    cmd+=" -scheme ${framework}"
    cmd+=" -sdk ${SDKS[0]}"
    cmd+=" -derivedDataPath ${temp_build_dir}"
    cmd+=" -quiet"
    cmd+=" >>'$(log_file)' 2>&1"

    log_cmd "${cmd}"

    if ! eval "${cmd}"; then
        log_err ''
        log_err "  docbuild failed. Check the log for errors."
        exit 1
    fi


    # Find the documentation archive bundle
    local documentation_archive=`find ${temp_build_dir} -type d -name ${framework}.doccarchive`

    local web_documentation_folder=""

    # Build web documentation
    if [[ "$WEB_DOCUMENTATION_OPTION" = true ]]; then
        log '     Building web documentation in a temporary folder...'
        web_documentation_folder="$(build_web_documentation $framework $documentation_archive)"
    fi

    # Copy the documentation to the xcframeworks
    log '     Copying to the distribution folder...'
    for mach_o_type in ${MACH_O_TYPES[@]}; do
        local target_dir="$(distribution_folder $framework $mach_o_type)"

        # Copy documentation archive
        cp -r "${documentation_archive}" "${target_dir}" >>"$(log_file)" 2>&1

        # Copy web documentation
        if [ -d "${web_documentation_folder}" ]; then
            cp -R "${web_documentation_folder}/" "${target_dir}" >>"$(log_file)" 2>&1
        fi
    done

    # Remove temporary files
    log '     Removing temporary files...'
    rm -rf "${temp_build_dir}"
    if [ -d  "${web_documentation_folder}" ]; then
        rm -rf "${web_documentation_folder}"
    fi

    log '     Done.'

    if [ -d "$(docarchive_path $framework $mach_o_type)" ]; then
        log "  ✅ Documentation for '$framework' build."
    else
        log_err "   Documentation for '$framework' not build. Check the log for errors."
        exit 1
    fi

    if [[ "$WEB_DOCUMENTATION_OPTION" = true ]]; then
        if [ -d "${target_dir}/webdoc" ]; then
            log "  ✅ Web documentation for '$framework' build."
        else
            log_err "   Web documentation for '$framework' not build. Check the log for errors."
            exit 1
        fi
    fi

    log ''
}

function build_web_documentation {
    # Read function params
    local framework=$1
    local docarchive_path=$2

    # Check params validity
    assert_valid_framework $framework

    # Get current version
    local version=$(echo "$(framework_version $framework)" | cut -d'.' -f 1,2)

    # Relative path in the destination server
    local web_doc_ios_path="mobile/ios"
    local web_doc_ios_version_path="${web_doc_ios_path}/v${version}"

    # Temporary folder for build artefacts
    local temp_web_build_dir_root=$(mrum_tempdir "webdoc-${framework}")


    local temp_web_build_dir="${temp_web_build_dir_root}/webdoc/${web_doc_ios_version_path}"
    mkdir -p "${temp_web_build_dir}"

    local cmd=""
    cmd+="$(xcrun --find docc) process-archive"
    cmd+=" transform-for-static-hosting '${docarchive_path}'"
    cmd+=" --output-path '${temp_web_build_dir}'"
    cmd+=" --hosting-base-path '${web_doc_ios_version_path}'"
    cmd+=" >>"$(log_file)" 2>&1"

    echo "$cmd" >> "$(log_file)"

    if ! eval "${cmd}"; then
        log_err ''
        log_err "  Documentation build failed. Check the log for errors."
        exit 1
    fi

    # Custom index files
    local web_doc_ios_version_root_path="${web_doc_ios_version_path}/documentation/splunkagent/"
    local web_doc_ios_path_index="${temp_web_build_dir_root}/webdoc/${web_doc_ios_path}/index.html"
    local web_doc_ios_version_path_index="${temp_web_build_dir}/index.html"

    # The original index.html returns a "not found" page,
    # the real documentation root is at `documentation/splunkagent/`.
    #
    # Because S3 does not allow straigthforward `/` redirect configuration,
    # redirect via <meta> header of a custom `index.html` is used.
    #
echo "<!DOCTYPE html>
    <html>
        <head>
            <title>MRUM Agent iOS</title>
            <META http-equiv=\"cache-control\" content=\"no-cache\">
            <meta http-equiv=\"refresh\" content=\"0; url=/${web_doc_ios_version_root_path} \" />
        </head>
        <body>
            <h1>SplunkAgent</h1>
            <p>Redirecting to
                <a href=\"/${web_doc_ios_version_root_path}\">/${web_doc_ios_version_root_path}</a>
            </p>
        </body>
    </html>
"> "${web_doc_ios_path_index}"

    # A copy of the version index as the documentation site root index.
    cp "${web_doc_ios_path_index}" "${web_doc_ios_version_path_index}"


    # System metadata cleanup
    find "${temp_web_build_dir_root}" -name .DS_Store -exec rm -v {} \;

    echo "${temp_web_build_dir_root}"
}

# Documentation
function build_documentations {
    for FRAMEWORK in ${FRAMEWORKS[@]}; do
        build_documentation $FRAMEWORK
    done
}
