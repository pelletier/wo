#
# Wo
#
# Projects workflow toolkit for bash-like shells (tested with zsh).
# (c) 2011 Thomas Pelletier <http://thomas.pelletier.im/> under MIT License
#       (see http://www.opensource.org/licenses/mit-license.php)

#
# Works with virtualenvwrapper and rvm.
#

#
# Don't forget to edit BASE_WO et BASE_VENVS (see below).
#

#
# Learn by example:
#
#   wo -c foo -p
#       Create a Python project (ie: a virtualenv) entitled foo.
#
#   wo -c bar -r
#       Create a Ruby project (ie: create a dir and enable rvm) entitled bar.
#
#   wo -c bar -r -R ree
#       Same as above but use ree for the ruby environment (install and create
#       gemsets).
#
#   wo -c bar
#       Create a basic project (ie: just create the directory and cd).
#
#   wo -c bar -g git://github.com/pelletier/wo.git
#       Create a basic project and clone the given repository.
#
#   wo -c foo -g .
#       Create a basic project and initialize an empty git repository in it.
#
#   wo bar
#       Open the previously created bar project (detect if it is python/ruby,
#       and load virtualenv / rvm when needed).
#   
#
#   wo -d
#       Exit your current project.
#
#   wo foo -P
#       Git pull in the foo project

BASE_WO="/Users/thomas/code"
BASE_VENVS="/Users/thomas/.venvs"


function wo {
    if [ -z "$1" ]; then
        wo_command_list
        return 1
    fi



    PROJECT_NAME=$1
    PYTHON=0
    RUBY=0
    RVM=""
    LANG_CHOOSED=0
    CREATE=0
    GIT_URL="None"
    WO_PULL=0

    while getopts "ldc:prR:g:P" flag $@
    do
        case "$flag" in
            "c")
                CREATE=1
                PROJECT_NAME=$OPTARG
                ;;
            "P")
                export WO_PULL=1
                ;;
            "l")
                wo_list_projects
                return 0
                ;;
            "d")
                wo_deactivate
                return 0
                ;;
            "p")
                if [ ! $LANG_CHOOSED = 0 ]; then
                    echo "You can only choose ONE language."
                    return 1
                fi
                PYTHON=1
                ;;
            "r")
                if [ ! $LANG_CHOOSED = 0 ]; then
                    echo "Your can only choose ONE language."
                    return 1
                fi
                RUBY=1
                ;;
            "R")
                RVM=$OPTARG
                ;;
            "g")
                GIT_URL=$OPTARG
                ;;
            "?")
                wo_command_list
                return 1
                ;;
        esac
    done

    if [ $CREATE = 1 ]; then
        if [ -z "$2" ]; then
            echo "Please provide a project name"
            return 1
        fi
        
        if [ $PYTHON = 1 ]; then
            mkvirtualenv --no-site-packages "$PROJECT_NAME"
            wo_open "$PROJECT_NAME"
            return 0
        fi

        if [ $RUBY = 1 ]; then
            mkdir "$BASE_WO/$PROJECT_NAME"
            touch "$BASE_WO/$PROJECT_NAME/.wo.conf"

            IFS="@" read v g< <(echo "$RVM") # v now contains the ruby version
                                             # and g in now the gemset name.

            # Use a default gemset name
            if [ "$g" = "" ]; then
                g="$PROJECT_NAME"
            fi

            # Save the RVM environment
            export WO_RVM_NAME="$v@$g"
            export WO_RUBY=1
            wo_save_vars "WO_RVM_NAME" "WO_RUBY" >> "$BASE_WO/$PROJECT_NAME/.wo.conf"

            # Now install the RVM env
            wo_rvm_install "$v" "$g"

            # Finally swith to the newly created environment
            wo_open "$PROJECT_NAME"

            return 0
        fi

        # Now language was selected, so just create the dir
        mkdir "$BASE_WO/$PROJECT_NAME"
        cd "$BASE_WO/$PROJECT_NAME"

        # Clone a git repo or init if needed
        if [ $GIT_URL != "None" ]; then
            if [ $GIT_URL != "." ]; then
                cd "$BASE_WO/$PROJECT_NAME" && git clone $GIT_URL .
            else
                cd "$BASE_WO/$PROJECT_NAME" && git init .
            fi
        fi
        
        # Then create the configuration file
        touch "$BASE_WO/$PROJECT_NAME/.wo.conf"
        return 0

    fi

    # This is not a creation, so we open the project
    wo_open "$1"

    return 0
}

function wo_deactivate {

    if [ ! "$VIRTUAL_ENV" = "" ]; then
        deactivate
        return 0
    fi

    if [ "$WO_USING_RUBY" = "1" ]; then
        rvm use default
        return 0
    fi

}

function wo_rvm_install { # Give $1 = ruby version / $2 = gemset name
    # First check if the Ruby version is already installed
    if [ "`rvm list | grep '$1' -o`" = "" ]; then
        rvm install "$1"
    fi

    rvm use $1
    rvm gemset create $2
}

function wo_save_vars {
    # From http://us.generation-nt.com/answer/ini-files-bash-help-193985261.html
    for var in "$@" ; do
        eval "echo $var=\\\"\$$var\\\""
    done
}

function wo_open {
    if [ -z "$1" ]; then
        echo "Please provide a project name."
        return -1
    fi

    found=0
    # First we check if a corresponding venv exists
    if [ -d "$BASE_VENVS/$1" ]; then
        # A venv exists
        found=1
        workon "$1"
    fi
    # We check if another project (such as a ruby one exists)
    if [ -d "$BASE_WO/$1" ]; then
        found=1
        cd "$BASE_WO/$1"

        # Read the configuration file
        WO_RUBY=0
        source "$BASE_WO/$1/.wo.conf"

        # Test if it is a Ruby project
        if [ $WO_RUBY = 1 ]; then
            rvm use "$WO_RVM_NAME"
        fi

        export WO_USING_RUBY=1

    fi
    if [ $found = 0 ]; then
        echo "No project named '$1' found."
        return -1
    fi

    if [ $WO_PULL = 1 ]; then
        cd "$BASE_WO/$1" && git pull
    fi
}

function wo_list_projects {
    ls -d1 $BASE_WO/*
}

function wo_command_list {
    echo "Usage:
    Open a project
      wo <project_name>
    Close a project
      wo -d
    Git-specific
      wo <project-name> -P
        git pull in the given project
    Create a project
      wo -c <project_name> [options]
        -p
          Create a Python (virtualenv) project
        -r
          Create a Ruby (rvm) project
        -R foo@bar
          RVM environment to use. See RVM documentation for syntax
        -g .
          Initialize an empty git repository.
        -g <git_url>
          Clone a git repository."
}
