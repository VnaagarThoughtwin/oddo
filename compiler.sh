#!/bin/bash

# ----------------------------------
# Colors
# ----------------------------------
NOCOLOR='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
LIGHTGRAY='\033[0;37m'
DARKGRAY='\033[1;30m'
LIGHTRED='\033[1;31m'
LIGHTGREEN='\033[1;32m'
YELLOW='\033[0;33m'
LIGHTBLUE='\033[1;34m'
LIGHTPURPLE='\033[1;35m'
LIGHTCYAN='\033[1;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
BOLDRED='\033[1;31m'
BOLDGREEN='\033[1;32m'
BOLDYELLOW='\033[1;33m'

declare -a LANE_ARGS
declare -a AVAILABLE_REGIONS=("$(ls -F app-loc/ | egrep ^app-* | awk -F "-" '{print $2}' | sed 's/.$//' | xargs) all")

fastlane="bundle exec fastlane"

function usage() {
    echo "Usage: $0
         [-h [android_lanes | ios_lanes] | --help [android_lanes | ios_lanes] | -? [android_lanes | ios_lanes]]: Prints this help.
         [-n | --noninteractive]: Sets noninteractive mode, all mandatory parameters needs to be explicitely set.
         [-d | --defaults]: Use the default arguments for lanes (defined in the associated platform Fastfile), do no ask for them. Only for interactive mode.
         [-p <platform> | --platform <platform>]: Set the target platform to build the app. Available values [android, ios]
         [-r <region> | --region <region>]: Set the target region to build the app. Available values [$(echo ${AVAILABLE_REGIONS[*]} | awk '{$1=$1}1' OFS=", ")].
         [-a <action> | --action <action>]: Set the action to perform. Available values [build, publish, promote].
         [-e <extension> | --extension <extension>]: Set the extension of the output app. Available values [apk, aab]. Only meaningful to build android apps.
         [-f <from> | --from <from>]: Set the channel (track) to promote from. Only meaningful to promote android apps.
         [-t <target> | --target <target>]: Set the channel (track) to promote or publish to. Only meaningful to promote or publish android apps.
         [-v <version> | --version <version>]: Set the ios app version that is being promoted. Only meaningful to promote ios apps.
         [<lane_arg>:<lane_arg_value>]: Any colon separated string will be interpreted as a lane argument and passed down to fastlane.
         " 1>&2
    exit 0
}

function isValidParam() {

    local user_param="$1"
    shift
    local valid_params=("$@")

    for param in ${valid_params[@]}; do
        if [[ "$param" == "$user_param" ]]; then
            return 0
        fi
    done

    return 1
}

function haveLaneArg() {

    for arg in ${LANE_ARGS[@]}; do
        if [[ "$arg" == "$1:"* ]]; then
            return 0
        fi
    done

    return 1
}

function isUncontrolledArg() {

    local user_param="$1"
    shift
    local controlled=("$@")

    for lane_param in ${controlled[@]}; do
        if [[ "$user_param" == "$lane_param:"* ]]; then
            return 0
        fi
    done

    return 1
}

function log() {

    if [[ -z "$1" ]] || [[ -z "$2" ]]; then
        return 1
    fi

    local level="$1"
    local msg="$2"
    local log

    case "$level" in
    'i') log="${BOLDGREEN}INFO${NOCOLOR}: ${GREEN}$msg${NOCOLOR}" ;;
    'w') log="${BOLDYELLOW}WARN${NOCOLOR}: ${YELLOW}$msg${NOCOLOR}" ;;
    'e') log="${BOLDRED}ERROR${NOCOLOR}: ${RED}$msg${NOCOLOR}" ;;
    *) return 1 ;;
    esac

    echo -e "$log"
}

function ask() {
    if [[ -z "$1" ]]; then
        return 1
    fi

    local question="${BOLD}$1 [y/n]${NOCOLOR} "
    local ans

    echo -ne "$question"
    read ans

    while [[ -z "$ans" ]]; do
        echo -ne "$question"
        read ans
    done

    echo

    case "$ans" in
    y* | Y* | yes) return 0 ;;
    *) return 1 ;;
    esac

}

function ask_complex() {
    if [[ -z "$1" ]]; then
        return 1
    fi

    local question="${BOLD}$1${NOCOLOR}\n"
    local ans

    echo -ne "$question" >&2
    read ans

    while [[ -z "$ans" ]]; do
        echo -ne "$question" >&2
        read ans
    done

    echo "$ans"
}

function menu() {
    if [[ -z "$1" ]]; then
        return
    fi

    local question="${BOLD}$1${NOCOLOR}\n"
    shift
    local options=("$@")
    local index=1
    declare -i local ans=0

    for opt in "${options[@]}"; do
        question="$question$index) $opt\n"
        index=$((index + 1))
    done

    echo -ne "$question"
    read ans

    while [[ "$ans" -eq 0 ]] || [[ "$ans" -gt "${#options[@]}" ]]; do
        echo -ne "$question"
        read ans
    done

    return "$ans"
}

declare -a params

while :; do
    case $1 in
    -h | -\? | --help) # Call a "usage" function to display a synopsis, then exit.
        if [ -n "$2" ]; then
            case "$2" in
            "android_lanes") cd android; $fastlane lanes; cd ..;;
            "ios_lanes") cd ios; $fastlane lanes; cd ..;;
            *) usage ;;
            esac
            exit
        else
            usage
            exit
        fi
        ;;
    -n | --noninteractive)
        NONINTERACTIVE=1
        ;;
    -d | --defaults) #Set default optional arguments for lane options. Only for interactive mode.
        DEFAULTS=1
        ;;
    -p | --platform)
        if [ -n "$2" ]; then
            params=("android" "ios")
            if isValidParam "$2" "${params[@]}"; then
                if [[ "$2" == "ios" ]] && [[ "$OSTYPE" != "darwin"* ]]; then
                    log "e" "Your system ($OSTYPE) doesn't seems to support the selected platform \"$2\". Aborting."
                    exit 1
                else
                    PLATFORM=$2
                    shift
                fi
            else
                log "w" "Platform \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--platform" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -r | --region) # Takes an option argument, ensuring it has been specified.
        if [ -n "$2" ]; then
            params=($AVAILABLE_REGIONS)
            if isValidParam "$2" "${params[@]}"; then
                REGION=$2
                shift
            else
                log "w" "Region \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--region" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -a | --action) # Takes an option argument, ensuring it has been specified.
        if [ -n "$2" ]; then
            params=("build" "publish" "promote")
            if isValidParam "$2" "${params[@]}"; then
                ACTION=$2
                shift
            else
                log "w" "Action \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--action" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -e | --extension) # Takes an option argument, ensuring it has been specified. Only for "build" action
        if [ -n "$2" ]; then
            params=("apk" "abb")
            if isValidParam "$2" "${params[@]}"; then
                EXTENSION=$2
                shift
            else
                log "w" "Extension \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--extension" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -t | --target) # Takes an option argument, ensuring it has been specified. Only for "publish" and "promote" action
        if [ -n "$2" ]; then
            params=("internal" "alpha" "beta" "production")
            if isValidParam "$2" "${params[@]}"; then
                TARGET=$2
                shift
            else
                log "w" "Target \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--target" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -f | --from) # Takes an option argument, ensuring it has been specified. Only for "promote" action
        if [ -n "$2" ]; then
            params=("internal" "alpha" "beta" "production")
            if isValidParam "$2" "${params[@]}"; then
                FROM=$2
                shift
            else
                log "w" "Origin \"$2\" not understood, ignoring it."
            fi
        else
            log 'e' '"--from" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    -v | --version) # Takes an option argument, ensuring it has been specified. Only for promoting ios apps
        if [ -n "$2" ]; then
            if [[ "$2" =~ ^[1-9]+.[0-9]+.[0-9]+$ ]]; then
                VERSION=$2
                shift
            else
                log "e" "Version $2 does not seems to be valid. Aborting."
                exit 1
            fi
        else
            log 'e' '"--version" requires a non-empty option argument. Aborting.'
            exit 1
        fi
        ;;
    --) # End of all options.
        shift
        break
        ;;
    ?*)
        if [[ "$1" == *":"* ]]; then
            params=("region" "to" "from" "format" "version")
            if isUncontrolledArg "$1" "${params[@]}"; then
                if [[ "$1" == "format:"* ]]; then
                    par="-e"
                else
                    par="-${1:0:1}"
                fi
                
                log "w" "\"$1\" is not allowed as a lane parameter, ignoring it. Please use $par."
            else
                LANE_ARGS+=("$1")
            fi
        else
            log 'w' "Unknown option (ignored): $1"
        fi
        ;;
    *) # Default case: If no more options then break out of the loop.
        break ;;
    esac

    shift
done

declare -a opts

if [[ "$NONINTERACTIVE" -eq 1 ]]; then

    if [[ -z "$PLATFORM" ]]; then

        if [[ "$OSTYPE" == "darwin"* ]]; then
            PLATFORM="ios"
        else
            PLATFORM="android"
        fi

        log "i" "Defaulting platform to: \"$PLATFORM\""
    fi

    if [[ -z "$REGION" ]]; then
        log "e" "Region is a mandatory parameter. Aborting."
        exit 1
    fi

    if [[ -z "$ACTION" ]]; then
        log "e" "Action is a mandatory parameter. Aborting."
        exit 1
    else
        case "$ACTION" in
        "promote")
            if [[ "$REGION" == "all" ]]; then
                LANE="promote_all"
            else
                LANE="promote"
                LANE_ARGS+=("region:$REGION")
            fi

            if [[ "$PLATFORM" == "ios" ]]; then

                if [[ -z "$VERSION" ]]; then
                    log "e" "Version is a mandatory parameter to publish \"ios\" apps. Aborting."
                    exit 1
                fi

                if [[ -z "$TARGET" ]]; then
                    log "i" "Promoting to Production by default for platform \"ios\"."
                fi

                if [[ -z "$FROM" ]]; then
                    log "i" "Promoting from TestFlight by default for platform \"ios\"."
                fi

            elif [[ "$PLATFORM" == "android" ]]; then
                if [[ -z "$TARGET" ]]; then
                    log "e" "Target track is a mandatory parameter to publish \"android\" apps. Aborting."
                    exit 1
                fi

                if [[ -z "$FROM" ]]; then
                    log "e" "Source track is a mandatory parameter to publish \"android\" apps. Aborting."
                    exit 1
                fi

                LANE_ARGS+=("from:$FROM")
                LANE_ARGS+=("to:$TARGET")
            fi
            ;;
        "publish")
            if [[ "$PLATFORM" == "ios" ]]; then
                if [[ -z "$TARGET" ]]; then
                    TARGET="TestFlight"
                    log "i" "Publishing to TestFlight by default for platform \"ios\"."
                fi

                if [[ "$REGION" == "all" ]]; then
                    LANE="release_all"
                else
                    LANE="release"
                    LANE_ARGS+=("region:$REGION")
                fi

            elif [[ "$PLATFORM" == "android" ]]; then
                if [[ -z "$TARGET" ]]; then
                    log "e" "Target is a mandatory parameter to publish \"android\" apps. Aborting."
                    exit 1
                fi
                if [[ "$REGION" == "all" ]]; then
                    LANE="$TARGET""_all"
                else
                    LANE="$TARGET"
                    LANE_ARGS+=("region:$REGION")
                fi
            fi
            ;;
        "build")
            if [[ "$PLATFORM" == "ios" ]]; then
                if [[ "$REGION" == "all" ]]; then
                    LANE="build_all"
                else
                    LANE="build"
                    LANE_ARGS+=("region:$REGION")
                fi
            elif [[ "$PLATFORM" == "android" ]]; then
                if [[ "$REGION" == "all" ]]; then
                    LANE="build_all"
                else
                    LANE="build"
                    LANE_ARGS+=("region:$REGION")
                fi

                if [[ ! -z "$EXTENSION" ]]; then
                    LANE_ARGS+=("format:$EXTENSION")
                fi
            fi
            ;;
        esac
    fi
else

    if [[ -z "$PLATFORM" ]]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            opts=("android" "ios")
            menu "Choose the platform you wish to compile for: " "${opts[@]}"
            PLATFORM=${opts[$(($? - 1))]}
            echo
        else
            PLATFORM="android"
            log "i" "Using platform \"$PLATFORM\" due to the system type ($OSTYPE)"
        fi
    fi

    if [[ -z "$REGION" ]]; then
        opts=($AVAILABLE_REGIONS)
        menu "Choose the region you wish to compile for: " "${opts[@]}"
        REGION=${opts[$(($? - 1))]}
        echo
    fi

    if [[ -z "$ACTION" ]]; then
        opts=("build" "publish" "promote")
        menu "Choose the action you wish to perform: " "${opts[@]}"
        ACTION=${opts[$(($? - 1))]}
        echo
    fi

    case "$ACTION" in
    'build')

        if [[ "$PLATFORM" == "ios" ]]; then
            if [[ "$REGION" == "all" ]]; then
                LANE="build_all"
            else
                LANE="build"
                LANE_ARGS+=("region:$REGION")
            fi
        elif [[ "$PLATFORM" == "android" ]]; then
            if [[ "$REGION" == "all" ]]; then
                LANE="build_all"
            else
                LANE="build"
                LANE_ARGS+=("region:$REGION")
            fi
        fi
        
        if [[ "$DEFAULTS" -ne 1 ]]; then
            if ! haveLaneArg "output_path"; then
                if [[ "$REGION" == "all" ]]; then
                    response=$(ask_complex "Set an ouput path for the compiled applications (must be a directory): ")

                    if [[ "$response" == "/"* ]]; then
                        LANE_ARGS+=("output_path:$response")
                    else
                        LANE_ARGS+=("output_path:$(pwd)/$response")
                    fi

                    echo
                else
                    response=$(ask_complex "Set an ouput path for the compiled application: ")

                    if [[ "$response" == "/"* ]]; then
                        LANE_ARGS+=("output_path:$response")
                    else
                        LANE_ARGS+=("output_path:$(pwd)/$response")
                    fi

                    echo
                fi
            fi

            if [[ "$PLATFORM" == "android" ]]; then
                if [[ -z "$EXTENSION" ]]; then

                    if [[ "$REGION" == "all" ]]; then
                        plural="s"
                    else
                        plural=""
                    fi

                    opts=("apk" "aab")
                    menu "Choose an output format for your application$plural: " "${opts[@]}"
                    EXTENSION=${opts[$(($? - 1))]}
                    echo

                    LANE_ARGS+=("format:$EXTENSION")
                else
                    LANE_ARGS+=("format:$EXTENSION")
                fi
            fi
        fi
        ;;
    'publish')
        if [[ "$PLATFORM" == "ios" ]]; then
            if [[ ! -z "$TARGET" ]]; then
                if [[ "$TARGET" == "production" ]]; then
                    log "e" "You cannot publish directly to production for platform \"ios\". Please consider to publish to TestFlight first and promote the app later on. Aborting."
                    exit 1
                else
                    if [[ "$REGION" == "all" ]]; then
                        LANE="release_all"
                    else
                        LANE="release"
                        LANE_ARGS+=("region:$REGION")
                    fi
                fi
            else
                if [[ "$REGION" == "all" ]]; then
                    LANE="release_all"
                else
                    LANE="release"
                    LANE_ARGS+=("region:$REGION")
                fi
                log "i" "Publishing to TestFlight by default for platform \"ios\"."
            fi

        elif [[ "$PLATFORM" == "android" ]]; then

            if [[ ! -z "$TARGET" ]]; then
                if [[ "$TARGET" == "production" ]]; then
                    log "w" "You are willing to publish an app directly to production which is strongly discouraged!"

                    if ask "Continue?"; then
                        if [[ "$REGION" == "all" ]]; then
                            LANE="production_all"
                        else
                            LANE="production"
                            LANE_ARGS+=("region:$REGION")
                        fi
                    else
                        exit 1
                    fi
                else
                    if [[ "$REGION" == "all" ]]; then
                        LANE="$TARGET""_all"
                    else
                        LANE="$TARGET"
                        LANE_ARGS+=("region:$REGION")
                    fi
                fi
            else

                if [[ "$REGION" == "all" ]]; then
                    plural="s"
                else
                    plural=""
                fi

                opts=("internal" "alpha" "beta" "production")
                menu "Choose a channel (track) you wish to publish your application$plural to: " "${opts[@]}"
                TARGET=${opts[$(($? - 1))]}
                echo

                if [[ "$TARGET" == "production" ]]; then
                    log "w" "You are willing to publish an app directly to production which is strongly discouraged!"

                    if ask "Continue?"; then
                        if [[ "$REGION" == "all" ]]; then
                            LANE="production_all"
                        else
                            LANE="production"
                            LANE_ARGS+=("region:$REGION")
                        fi
                    else
                        exit 1
                    fi
                else
                    if [[ "$REGION" == "all" ]]; then
                        LANE="$TARGET""_all"
                    else
                        LANE="$TARGET"
                        LANE_ARGS+=("region:$REGION")
                    fi
                fi

                if [[ "$DEFAULTS" -ne 1 ]]; then
                    if [[ "$REGION" == "all" ]]; then
                        plural="ies"
                    else
                        plural="y"
                    fi
                    if ! haveLaneArg "skip_aab"; then
                        if ask "Do you wish to upload the generated binar$plural?"; then
                            LANE_ARGS+=("skip_aab:false")
                        else
                            LANE_ARGS+=("skip_aab:true")
                        fi
                    fi
                    if ! haveLaneArg "skip_meta"; then
                        if ask "Do you wish to upload the metadata asociated with the binar$plural?"; then
                            LANE_ARGS+=("skip_meta:false")
                        else
                            LANE_ARGS+=("skip_meta:true")
                        fi
                    fi
                    if ! haveLaneArg "skip_changelogs"; then
                        if ask "Do you wish to upload the changelogs asociated with the binar$plural?"; then
                            LANE_ARGS+=("skip_changelogs:false")
                        else
                            LANE_ARGS+=("skip_changelogs:true")
                        fi
                    fi
                    if ! haveLaneArg "skip_images"; then
                        if ask "Do you wish to upload the images asociated with the binar$plural?"; then
                            LANE_ARGS+=("skip_images:false")
                        else
                            LANE_ARGS+=("skip_images:true")
                        fi
                    fi
                    if ! haveLaneArg "skip_screenshots"; then
                        if ask "Do you wish to upload the screenshots asociated with the binar$plural?"; then
                            LANE_ARGS+=("skip_screenshots:false")
                        else
                            LANE_ARGS+=("skip_screenshots:true")
                        fi
                    fi
                fi
            fi
        fi
        ;;
    'promote')
        if [[ "$PLATFORM" == "ios" ]]; then

            if [[ "$REGION" == "all" ]]; then
                LANE="promote_all"
            else
                LANE="promote"
                LANE_ARGS+=("region:$REGION")
            fi

            if [[ -z "$VERSION" ]]; then
                response=$(ask_complex "What version are you promoting? ")

                while [[ ! "$response" =~ ^[0-9\.]+$ ]]; do  # while [[ ! "$response" =~ ^[0-9]+$ ]]; do
                    response=$(ask_complex "What version are you promoting? ")
                done
                echo

                LANE_ARGS+=("version:$response")
            else
                LANE_ARGS+=("version:$response")
            fi

            if [[ -z "$TARGET" ]]; then
                log "i" "Promoting to Production by default for platform \"ios\"."
            fi

            if [[ -z "$FROM" ]]; then
                log "i" "Promoting from TestFlight by default for platform \"ios\"."
            fi

            if [[ "$DEFAULTS" -ne 1 ]]; then
                if [[ "$REGION" == "all" ]]; then
                    plural="ies"
                else
                    plural="y"
                fi
                if ! haveLaneArg "skip_meta"; then
                    if ask "Do you wish to upload the metadata associated to the binar$plural?"; then
                        LANE_ARGS+=("skip_meta:false")
                    else
                        LANE_ARGS+=("skip_meta:true")
                    fi
                fi
                if ! haveLaneArg "skip_screenshots"; then
                    if ask "Do you wish to upload the screenshots associated to the binar$plural?"; then
                        LANE_ARGS+=("skip_screenshots:false")
                    else
                        LANE_ARGS+=("skip_screenshots:true")
                    fi
                fi
                if ! haveLaneArg "reject"; then
                    if ask "Do you wish to reject previously uploaded binar$plural, if possible?"; then
                        LANE_ARGS+=("reject:false")
                    else
                        LANE_ARGS+=("reject:true")
                    fi
                fi
            fi

        elif [[ "$PLATFORM" == "android" ]]; then
            if [[ "$REGION" == "all" ]]; then
                LANE="promote_all"
            else
                LANE="promote"
                LANE_ARGS+=("region:$REGION")
            fi

            if [[ "$REGION" == "all" ]]; then
                plural="s"
            else
                plural=""
            fi

            if [[ -z "$FROM" ]]; then
                opts=("internal" "alpha" "beta" "production")
                menu "From what channel$plural (track$plural) are you promoting: " "${opts[@]}"
                FROM=${opts[$(($? - 1))]}
                echo

                LANE_ARGS+=("from:$FROM")
            else
                LANE_ARGS+=("from:$FROM")
            fi

            if [[ -z "$TARGET" ]]; then
                opts=("internal" "alpha" "beta" "production")
                menu "To what channel$plural (track$plural) are you promoting: " "${opts[@]}"
                TARGET=${opts[$(($? - 1))]}
                echo0

                LANE_ARGS+=("to:$TARGET")
            else
                LANE_ARGS+=("to:$TARGET")
            fi

            if [[ "$FROM" == "$TARGET" ]]; then
                log "e" "Target and source channels are the same. Nothing to do."
                exit 1
            fi
        fi
        ;;
    esac
fi

log "i" "Command: cd $PLATFORM; $fastlane $LANE ${LANE_ARGS[*]}; cd .."
cd $PLATFORM; $fastlane $LANE ${LANE_ARGS[*]}; cd ..
