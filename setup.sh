#!/bin/bash
# Installer for NoIP Manager, written in bash
# Usage: sudo ./setup.sh
# -----------------------------------------------------------------------------

set -e


function config() {
    USER=$(whoami)
    PYTHON=python3
    INSTDIR=/usr/local/NoIP-Manager
    EXECUTABLE=/usr/local/bin/noip-manager
    LOGS=$INSTDIR/logs
    CONFIG=$INSTDIR/config
    TMPDIR=/tmp/noip-manager
    INSTLOG=/tmp/install.log
    UPGDDIR=NoIP-Manager-master/noip-manager
    REPO=https://github.com/IDemixI/NoIP-Manager
    README=https://raw.githubusercontent.com/IDemixI/NoIP-Manager/master/README.md
    VERSION=$(wget -q -O - $README | grep "Version:" | grep -o '[0-9.]*')
    CRONJOB="30 0    * * *   $USER    $EXECUTABLE --renew"
    OUTPUT=/dev/null
    MODE="Menu"

    # Colour codes for text
    CLEAR="\e[1A\e[K"
    GREEN="\e[32m"
    RED="\e[31m"
    LGREEN="\e[92m"
    LBLUE="\e[94m"
    DGREY="\e[90m"
    DEFAULT="\e[39m"
    TICK="\u2713"
    CROSS="\u2717"
    PASS="$CLEAR[$GREEN$TICK$DEFAULT]"
    FAIL="$CLEAR[$RED$CROSS$DEFAULT]"
}


function timestamp() {
    date +"%d/%m/%Y %T"
}


function aptInstall() {
    if [ -z "$2" ]; then
        echo -e "[ ] Installing $1 package..." && apt-get -y install $1 &>> $OUTPUT && dpkg -s $1 &>> $OUTPUT
    else
        apt-get -y install ${1} &>> $OUTPUT && dpkg -s $1 &>> $OUTPUT
    fi

    if [ $? -eq 0 ]; then
        echo -e "${PASS} Installed ${1} package"
    else
        echo -e "${FAIL} Failed to install ${1} package"
    fi
}


function pipInstall() {
    if [ -z "$2" ]; then
        echo -e "[ ] Installing ${1} package..." && $PYTHON -m pip install $1 &>> $OUTPUT
    else
        $PYTHON -m pip install $1 &>> $OUTPUT
    fi

    if [ $? -eq 0 ]; then
        echo -e "${PASS} Installed ${1} package"
    else
        echo -e "${FAIL} Failed to install ${1} package"
    fi
}


function moveFiles() {
    # Remove and recreate TMPDIR for script.
    'rm' -rf $TMPDIR && 'mkdir' -p $TMPDIR
    # If no parameter passed, copy both logs & config
    if [ -z "$1" ]; then
        'mkdir' -p $TMPDIR/logs/ && 'mv' $LOGS/* $TMPDIR/logs/
        'mkdir' -p $TMPDIR/config/ && 'mv' $CONFIG/* $TMPDIR/config/
        'rm' -r $INSTDIR && 'mkdir' -p $INSTDIR
        'mkdir' -p $LOGS && 'mv' $TMPDIR/logs/* $LOGS/
        'mkdir' -p $CONFIG && 'mv' $TMPDIR/config/* $CONFIG/
    elif [ $1 == "Config "]; then
        'mkdir' -p $TMPDIR/config/ && 'mv' $CONFIG/* $TMPDIR/config/
        'rm' -r $INSTDIR && 'mkdir' -p $INSTDIR
        'mkdir' -p $CONFIG && 'mv' $TMPDIR/config/* $CONFIG/
    elif [ $1 == "Logs" ]; then
        'mkdir' -p $TMPDIR/logs/ && 'mv' $LOGS/* $TMPDIR/logs/
        'rm' -r $INSTDIR && 'mkdir' -p $INSTDIR
        'mkdir' -p $LOGS && 'mv' $TMPDIR/logs/* $LOGS/
    else
        echo "An error has occured. Exiting script."
        exit 1
    fi
    # Remove temp directory.
    'rm' -rf $TMPDIR
}


function install() {
    MODE="Install"
    echo -e"Installing NoIP-Manager Version ${VERSION}.\n"

    # Prompt user to see if they wish to perform an apt-get update.
    read -p 'Perform apt-get update? (y/n): ' update
    echo
    if [ "${update^^}" = "Y" ]
    then
        echo "[ ] Performing Apt-get Update (This can take some time)." && apt-get update &>> $OUTPUT
        echo -e "${PASS} Apt-get Update has been performed."
    fi

    # Check Python version. This package requires Python 3.6+ to function.
    PYV=`python3 -c "import sys;t='{v[0]}{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
    if [[ "$PYV" -lt "36" ]] || ! hash python3;
    then
        echo "[ ] This script requires Python version 3.6 or higher. Attempting to install..." && aptInstall python3 Y
        PYV=`python3 -c "import sys;t='{v[0]}{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
        if [[ "$PYV" -lt "36" ]] || ! hash python3; then
            echo -e "${FAIL} Python requirement not met [3.6.0]+. You have $(python3 -V 2>&1)"
        fi
    else
        echo -e "[${GREEN}${TICK}${DEFAULT}] $(python3 -V 2>&1) is already installed. Requirements met."
    fi

    # Install correct Chromium driver. This differs depending on OS.
    echo "[ ] Installing relevent Chromium Driver for your OS."
    aptInstall chromium-chromedriver $1 Y || \
        aptInstall chromium-drive Y || \
        aptInstall chromedriver Y

    # Update Chromium Browser or script won't work.
    aptInstall chromium-browser

    # Debian9 package 'python-selenium' does not work with chromedriver, Install from pip, which is newer.
    # Firstly make sure the correct version of pip is installed.
    aptInstall $PYTHON-pip

    # Now Install Selenium via Pip.
    pipInstall selenium

    # Install XMLStarlet in order to set up and manage our config files.
    aptInstall xmlstarlet

    # Prompt user to see if they wish to set up notifications.
    read -rep $'\nWould you like to set up Notifications at this time? (y/n): ' notify
    if [ "${notify^^}" = "Y" ]
    then
        notifyInstall
    fi

    echo "[ ] Creating temporary directory to deploy from."
    'mkdir' -p $TMPDIR && 'cp' -rf $(pwd)/noip-manager/* $TMPDIR
    echo -e "$PASS Created temporary directory to deploy from. ($TMPDIR)"

    # Call deploy function
    deploy

}


function notifyInstall() {
    echo
    options=("Discord Notifications" "Pushover Notifications" "Slack Notifications" "Telegram Notifications" "None")
    select opt in "${options[@]}"
    do
        case $opt in
            "Discord Notifications")
                echo
                notification="Discord"
                pipInstall discord-webhook
                break
                ;;
            "Pushover Notifications")
                echo
                notification="Pushover"
                pipInstall requests
                break
                ;;
            "Slack Notifications")
                echo
                notification="Slack"
                pipInstall slackclient
                break
                ;;
            "Telegram Notifications")
                echo
                notification="Telegram"
                pipInstall telegram-send
                break
                ;;
            "None")
                notify="N"
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}


function deploy() {
    echo -e "\nDeploying the package...\n"

    # Remove existing installation
    if [ -d $INSTDIR ]; then
        echo "[ ] Attempting to move existing log/config files into place."
        # Move log files and config files to temp working directory temporarily.
        'mkdir' -p $TMPDIR/logs/ && 'cp' -rf $LOGS/* $TMPDIR/logs/
        'mkdir' -p $TMPDIR/config/ && 'cp' -rf $CONFIG/* $TMPDIR/config/
        'rm' -r $INSTDIR
        echo -e "${PASS} Successfully moved existing log/config files into place."
    fi

    # Remove existing executable (if it exists).
    if test -f "$EXECUTABLE"; then
        'rm' $EXECUTABLE
        echo -e "[${GREEN}${TICK}${DEFAULT}] Removed old executable from ${EXECUTABLE}."
    fi

    echo "[ ] Deploying files..."
    'mkdir' -p $INSTDIR
    'cp' -rf $TMPDIR/* $INSTDIR
    'mv' $INSTDIR/noip-manager.sh $EXECUTABLE
    echo -e "${PASS} Files have been deployed successfully."

    echo "[ ] Setting permissions..."
    chown $USER $INSTDIR
    chown $USER $EXECUTABLE
    chmod 700 $EXECUTABLE
    echo -e "${PASS} Permissions have been set."

    # If Install mode or repair with configs removed, then call noip function.
    if [ $MODE == "Install" ] || ([ $MODE == "Repair" ] && [ $clearCfg == 'Y' ]); then
        noip
    fi

    # If notifications were installed, set up an initial selection.
    if [ "${notify^^}" = "Y" ]
    then
        # Call notifySetup function with type of notification as parameter.
        notifySetup "$notification"
    fi

    # Remove noip-manager from crontab before trying to add it.
    sed -i '/noip-manager/d' /etc/crontab

    # Add an entry for noip-manager to crontab.
    echo "$CRONJOB" | tee -a /etc/crontab &>> $OUTPUT

    echo -e "\nDeployment Complete."
    echo "Type 'noip-manager --help' for all options."
    echo "Logs can be found in '${LOGS}'"

    # Remove installation folder
    'rm' -r $(pwd)
    cd ~/
}


function upgrade() {
    MODE="Upgrade"
    echo -e "Starting upgrade process. Make sure noip-manager is not running before proceeding.\n"

    # Prompt user to see if they are sure they want to upgrade.
    read -p 'Proceed with upgrade? (y/n): ' upgd
    if [ "${upgd^^}" = "Y" ]
    then
        echo "[ ] Upgrading from ${cVersion} to ${VERSION}."
        'rm' -rf $TMPDIR && 'mkdir' -p $TMPDIR && wget -q -O -$REPO/archive/master.tar.gz | tar -xz -C $TMPDIR $UPGDDIR --strip-components=2 &> $OUTPUT
        
        if [ $? -ne 0 ]; then
            echo -e "${FAIL} Unable to download and extract latest version of NoIP Manager."
            exit 1
        else
            echo -e "${PASS} Downloaded NoIP Manager v${VERSION}."
        fi

        # Call deploy function
        deploy

        echo -e "\nSee below for release notes:\n"

        # Start release notes check from first version above existing.
        intcVersion=$(($intcVersion + 1))

        # Loop through each release.
        while [ $intcVersion -le $intlVersion ]
        do
            echo $(wget -q -O - $README | grep -- "- ${intcVersion:0:1}.${intcVersion:1:1}" | cut -c3- )
            echo
            intcVersion=$(($intcVersion + 1))
        done
    else
        mainMenu
    fi
}


function repair() {
    MODE="Repair"
    OUTPUT=$INSTLOG
    echo -e"Repairing NoIP-Manager.\n"
    read -p 'Do you want to clear configuration files? This could help to resolve issues (y/n): ' clearCfg

    if [ "${clearCfg^^}" = "N" ]
    then
        moveFiles
    else
        moveFiles "Logs"
        'rm' -rf $INSTDIR
    fi

    install

    echo -e "\n[${GREEN}${TICK}${DEFAULT}] Repair complete."
    echo "Log file for the repair can be found: ${INSTLOG}"
}


function uninstall() {
    MODE="Uninstall"
    echo -e "Uninstalling NoIP-Manager.\n"

    # Remove crontab
    sed -i '/noip-manager/d' /etc/crontab

    # Remove executable
    'rm' $EXECUTABLE

    read -p 'Do you want to remove configuration & log files? (y/n): ' clearAll
    if [ "${clearAll^^}" = "Y" ]
    then
        'rm' -rf $INSTDIR
        echo -e "\n[${GREEN}${TICK}${DEFAULT}] All logs and config files have been removed."
    else
        moveFiles
    fi

    echo -e "\n[${GREEN}${TICK}${DEFAULT}] NoIP Manager has been uninstalled.\n"

    # Remove installation folder
    'rm' -r $(pwd)
    cd ~/
}


function noip() {
    echo -e "\nEnter your No-IP Account details. You can set additional accounts up after installation.\n"
    read -p 'Alias: ' alias
    read -p 'Username or Email: ' uservar
    read -sp 'Password: ' passvar

    # Convert password to base64 so it's not in plain text.
    passvar=`echo -n $passvar | base64`
    echo

    # Add account details to accounts.xml 
    xmlstarlet -q ed -L -u /accounts/noip[@alias][1]/@alias -v $alias $CONFIG/accounts.xml
    xmlstarlet -q ed -L -u /accounts/noip[1]/username -v $uservar $CONFIG/accounts.xml
    xmlstarlet -q ed -L -u /accounts/noip[1]/password -v $passvar $CONFIG/accounts.xml
    xmlstarlet -q ed -L -u /accounts/noip[1]/created -v "$(timestamp)" $CONFIG/accounts.xml
}


function notifySetup() {
    echo -e "\nConfiguring Notifications.\n"
    xmlstarlet -q ed -L -u /settings/notifications/enabled -v "True" $CONFIG/config.xml
    xmlstarlet -q ed -L -u /settings/notifications/type -v $1 $CONFIG/config.xml
    case $1 in
        "Discord") discord;;
        "Pushover") pushover;;
        "Slack") slack;;
        "Telegram") telegram;;
    esac
}


function discord() {
    echo "Enter the URL of your Discord webhook..."
    read -p 'Webhook: ' webhook

    xmlstarlet -q ed -L -s /settings/notifications -t elem -n "discord_webook" -v $webhook $CONFIG/config.xml
}


function pushover() {
    echo "Enter your Pushover Token..."
    read -p 'Token: ' tokenvar

    echo "Enter your Pushover User Key..."
    read -p 'User: ' uservar

    # Convert User key & Token to base64
    tokenvar=`echo -n $tokenvar | base64`
    uservar=`echo -n $uservar | base64`

    xmlstarlet -q ed -s /settings/notifications -t elem -n "pushover_token" -v $tokenvar $CONFIG/config.xml
    xmlstarlet -q ed -s /settings/notifications -t elem -n "pushover_user_key" -v $uservar $CONFIG/config.xml
}


function slack() {
    echo "Enter your Slack Bot User OAuth Access Token..."
    read -p 'Token: ' tokenvar

    echo "Enter the channel you wish to receive notifications on..."
    read -p 'Channel: ' channel

    tokenvar=`echo -n $tokenvar | base64`

    xmlstarlet -q ed -s /settings/notifications -t elem -n "slack_token" -v $tokenvar $CONFIG/config.xml
    xmlstarlet -q ed -s /settings/notifications -t elem -n "slack_channel" -v $channel $CONFIG/config.xml
}


function telegram() {
    echo "Please configure Telegram:"
    telegram-send --configure
}


function mainMenu() {
    PS3='Select an option: '
    options=()

    clear

    echo -e "${GREEN}  _   _      _____ _____    ${LBLUE}__  __"    \
        "\n""${GREEN} | \ | |    |_   _|  __ \  ${LBLUE}|  \/  |" \
        "\n""${GREEN} |  \| | ___  | | | |__) | ${LBLUE}| \  / | __ _ _ __   __ _  __ _  ___ _ __"    \
        "\n""${GREEN} | . \` |/ _ \ | | |  ___/  ${LBLUE}| |\/| |/ _\` | '_ \ / _\` |/ _\` |/ _ \ '__|"   \
        "\n""${GREEN} | |\  | (_) || |_| |      ${LBLUE}| |  | | (_| | | | | (_| | (_| |  __/ |"  \
        "\n""${GREEN} |_| \_|\___/_____|_|      ${LBLUE}|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|"  \
        "\n""                                                      __/ |" \
        "\n""${DGREY}  Written by Demix${LBLUE}                                   |___/\n"
    
    echo -e "${DEFAULT}Welcome to the installer for ${LGREEN}NoIP Manager${DEFAULT}. Please select an option from below.\n"

    if test -f "$EXECUTABLE"; then
        cVersion=(`noip-manager --version | grep -o '[0-9.]*'`)
        intcVersion="${cVersion//[!0-9]/}"
        intlVersion="${VERSION//[!0-9]/}"

        if [ $intlVersion -gt $intcVersion ]; then
            echo -e "Update Available! - Currently installed: v${cVersion} (${GREEN}v${VERSION}${DEFAULT} Available)."
            options+=("Upgrade")
        else
            echo "Latest version is installed: v${cVersion}"
        fi
        options+=("Repair")
        options+=("Uninstall")

    else
        options+=("Install")
    fi

    options+=("Exit Setup")

    select opt in "${options[@]}"
    do
        case $opt in
            "Install")
                echo
                install
                break
                ;;
            "Repair")
                echo
                repair
                break
                ;;
            "Upgrade")
                echo
                upgrade
                break
                ;;
            "Uninstall")
                echo
                uninstall
                break
                ;;
            "Exit Setup")
                break
                ;;
            *) echo "invalid option $REPLY";;
        esac
    done
}


function main() {
    # Check script has been called with sufficient permissions.
    if [ `id -u` != 0 ]; then
        echo "Please run the script with elevated / sudo permissions."
        exit 1
    fi
    # Call config function which sets up variables for the installer.
    config
    # Load the main menu.
    mainMenu
}

main
