## Random work-notes. Will be removed as I go.


# [X] Now it will ask for your noip.com account information (Username/email), password, Alias (If no alias selected, username will be used)
# [ ] For this to work we need to grab username out of noip homepage element xpath "visible-md-inline visible-lg-inline visible-sm-inline visible-xs-inline"


# [X] Don't worry you can manage this using noip-manager --configure"
# [X] If notifications were selected earlier, this is where they're now set up. Depending on your selection you will be asked for some details.
# [X] Thus ends the installer. The final step is for setup.sh to delete itself along with the entire folder.
# [X] a prompt will be displayed saying "use noip-manager --help for more information".


# [ ] IF NOTIFICATIONS AREN'T SET UP... WE NEED TO BE ABLE TO INSTALL THE PACKAGES VIA NOIP-MANAGER --CONFIGURE COMMAND

# noip-manager: If called without parameters, opens menu with some information on (see below this section)
# --renew: This is what will be scheduled to run via crontab
# --configure: Options such as: [1] Notification Configuration [2] Log Configuration (Level/Location) [3] Schedule Configuration (Next Run Date/Time)
# --help: list of all commands and what they do .. basically this section but tidy.
# --version: provides the current version of the script "Version x.x"
# --uninstall: Uninstalls the script completely (Ask user if they wish to also remove settings & log files)
# --repair: attempts to repair the script by checking github and downloading latest, writing over current files and setting up again
# --upgrade: checks github and downloads latest copy of script if it's newer. "Update available: Version X.X" "Current version matches latest (X.X). No update available."
# --logs: this will just open a view to the log file/s 

# 1. Add/Remove Noip Accounts
# 2. List all active hosts (See below)
# 3. Check last run status
# 4. Statistics - Total runs, total hosts updated, last host updated, next host to be updated.
# 5. Exit (or look at showing ctrl+c to exit?)

## ACTIVE HOSTS ##
# Hostname | Account Alias | Times renewed | Last renewal | Next renewal
# SUMMARY: Total Renewals | Last renewal | Next renewal

# When a new host is added I think it should do a run to grab username & hostnames & days until expiry.

# The --configure option needs to open a menu with options such as notifications, noip accounts setup, scheduled tasks.

##### STUFF WE FIND USEFUL - MAY USE THIS LATER! #####


# Check to see if package is installed or not.
#if [ $(dpkg-query -W -f='${Status}' git 2>/dev/null | grep -c "ok installed") -eq 0 ];
#then
#  apt-get install git;
#fi

#################################################################

#!/bin/bash
set -e

USER=$(whoami)

if [ "$USER" == "root" ]; then
    echo "Please run the script as a normal user with sudo permissions. Using the root user is not advised."
    exit 1
else
    SUDO=sudo
fi


function config() {
    INSTDIR=/usr/local/NoIP-Manager
    TMPDIR=/tmp/noip-manager
    EXECUTABLE=/usr/local/bin/noip-manager
    LOGS=$INSTDIR/logs
    CONFIG=$INSTDIR/config
    VERSION=$(wget -q -O - https://raw.githubusercontent.com/IDemixI/NoIP-Manager/master/README.md | grep "Version:" | grep -o '[0-9.]*')
    PYTHON=python3
    CRONJOB="30 0    * * *   $USER    $EXECUTABLE --renew"
}


function timestamp() {
    date +"%d/%m/%Y %T"
}


function aptInstall() {
    if [ -z "$2" ]; then
        echo -e "[ ] Installing $1 package..." && $SUDO apt-get -y install $1 -qq && dpkg -s $1 &> /dev/null
    else
        $SUDO apt-get -y install $1 -qq && dpkg -s $1 &> /dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Installed $1 package"
    else
        echo -e "\e[1A\e[K[\e[31m\u2717\e[39m] Failed to install $1 package"
    fi
}


function pipInstall() {
    if [ -z "$2" ]; then
        echo -e "[ ] Installing $1 package..." && $SUDO $PYTHON -m pip -q install $1 &> /dev/null
    else
        $SUDO $PYTHON -m pip -q install $1 &> /dev/null
    fi

    if [ $? -eq 0 ]; then
        echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Installed $1 package"
    else
        echo -e "\e[1A\e[K[\e[31m\u2717\e[39m] Failed to install $1 package"
    fi
}


function install() {
    echo "Installing NoIP-Manager Version $VERSION."
    echo

    # Prompt user to see if they wish to perform an apt-get update.
    read -p 'Perform apt-get update? (y/n): ' update
    echo
    if [ "${update^^}" = "Y" ]
    then
        echo "[ ] Performing Apt-get Update (This can take some time)." && $SUDO apt-get update -qq
        echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Apt-get Update has been performed."
    fi

    # Check Python version. This package requires Python 3.6+ to function.
    PYV=`python3 -c "import sys;t='{v[0]}{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
    if [[ "$PYV" -lt "36" ]] || ! hash python3;
    then
        echo "[ ] This script requires Python version 3.6 or higher. Attempting to install..." &&  aptInstall python3 Y
        PYV=`python3 -c "import sys;t='{v[0]}{v[1]}'.format(v=list(sys.version_info[:2]));sys.stdout.write(t)";`
        if [[ "$PYV" -lt "36" ]] || ! hash python3; then
            echo -e "\e[1A\e[K[\e[31m\u2717\e[39m] Python requirement not met [3.6.0]+. You have $(python3 -V 2>&1)"
        fi
    else
        echo -e "[\e[32m\u2713\e[39m] $(python3 -V 2>&1) is already installed. Requirements met."
    fi

    # Install correct Chromium driver. This differs depending on OS.
    echo "[ ] Installing relevent Chromium Driver for your OS."
    aptInstall chromium-chromedriver Y || \
        aptInstall chromium-driver Y || \
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
    echo
    read -p 'Would you like to set up Notifications at this time? (y/n): ' notify
    if [ "${notify^^}" = "Y" ]
    then
        notifyInstall
    fi

    deploy "Install"

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
    echo
    echo "Deploying the package..."
    echo

    # Check which mode deploy has been called in.
    if [ $1 == "Install" ]; then
        echo "[ ] Creating temporary directory to deploy from."
        $SUDO 'mkdir' -p $TMPDIR && $SUDO 'cp' -rf $(pwd)/noip-manager/* $TMPDIR
        echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Created temporary directory to deploy from. (/tmp/noip-manager/)"
    elif [ $1 == "Repair" ] || [ $1 == "Upgrade"]; then
        echo "[ ] Checking for existing installation & moving logs and config files."
        # Remove existing installation (if it exists).
        if [ -d $INSTDIR ]; then
            # Move log files and config files to temp working directory temporarily.
            $SUDO 'mkdir' -p $TMPDIR/logs/ && $SUDO 'cp' -rf $LOGS/* $TMPDIR/logs/
            $SUDO 'mkdir' -p $TMPDIR/config/ && $SUDO 'cp' -rf $CONFIG/* $TMPDIR/config/
            $SUDO 'rm' -r $INSTDIR
            echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Successfully copied logs and config files from existing installation."
        else
            echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] No existing logs or config files to copy across."
        fi
        # Remove existing executable (if it exists).
        if test -f "$EXECUTABLE"; then
            $SUDO 'rm' $EXECUTABLE
            echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Removed old executable from $EXECUTABLE."
        fi
    else
        echo "An error has occured. Exiting script."
        exit 1
    fi

    echo "[ ] Deploying files..."
    $SUDO 'mkdir' -p $INSTDIR
    $SUDO 'cp' -rf $TMPDIR/* $INSTDIR
    $SUDO 'cp' $TMPDIR/noip-manager.sh $EXECUTABLE
    echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Files have been deployed successfully."
    
    echo "[ ] Setting permissions..."
    $SUDO chown $USER $INSTDIR
    $SUDO chown $USER $EXECUTABLE
    #$SUDO chown $USER $INSTDIR/noip-renew-skd.sh - Keep this line. Need to work on better system for setting next crontab automagically.
    $SUDO chmod 700 $EXECUTABLE
    echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Permissions have been set."
    
    # Check to see if deploy called in Install mode. If so, ask user to setup initial NoIP account information.
    if [ $1 == "Install" ]; then
        noip
    fi

    # If notifications were installed, set up an initial selection.
    if [ "${notify^^}" = "Y" ]
    then
        # Call notifySetup function with type of notification as parameter.
        notifySetup "$notification"
    fi
    
    # Remove noip-manager from crontab before trying to add it.
    $SUDO sed -i '/noip-manager/d' /etc/crontab

    # Add an entry for noip-manager to crontab.
    echo "$CRONJOB" | $SUDO tee -a /etc/crontab >/dev/null

    # THIS SETS USER IN THE NOIP-RENEW-SKD SCRIPT... THIS WILL BE REMOVED AS WE WON'T DEAL WITH IT THIS WAY IN THE FUTURE.
    # $SUDO sed -i 's/USER=/USER='$USER'/1' $INSTDIR/noip-renew-skd.sh - So we either need to add $USER to the .ini file, or our executable.
    
    echo
    echo "Deployment Complete."
    echo "Type 'noip-manager --help' for all options."
    echo "Logs can be found in '$LOGS'"

    # Remove installation folder
    $SUDO 'rm' -r $(pwd)
    cd ~/
}


function upgrade() {
    echo "Starting upgrade process. Make sure noip-manager is not running before proceeding."

    # Prompt user to see if they are sure they want to upgrade.
    echo
    read -p 'Proceed with upgrade? (y/n): ' upgd
    if [ "${upgd^^}" = "Y" ]
    then
        echo "Upgrading from $cVersion to $VERSION."
        mkdir -p /tmp/noip-manager && wget -q -O - https://github.com/IDemixI/NoIP-Manager/archive/master.tar.gz | tar -xz -C /tmp/noip-manager "NoIP-Manager-master/noip-manager" --strip-components=2 &>/dev/null
        
        if [ $? -ne 0 ]; then
            echo -e "\e[1A\e[K[\e[31m\u2717\e[39m] Unable to download and extract latest version of NoIP Manager."
            exit 1
        else
            echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] Downloaded NoIP Manager v$VERSION."
        fi

        # Call deploy function in Upgrade mode.
        deploy "Upgrade"

        echo
        echo "See below for release notes:"
        echo

        # Start release notes check from first version above existing.
        intcVersion=$(($intcVersion + 1))

        # Loop through each release.
        while [ $intcVersion -le $intlVersion ]
        do
            echo $(wget -q -O - https://raw.githubusercontent.com/IDemixI/NoIP-Manager/master/README.md | grep -- "- ${intcVersion:0:1}.${intcVersion:1:1}" | cut -c3- )
            echo
            intcVersion=$(($intcVersion + 1))
        done
    else
        mainMenu
    fi
}


function repair() {
    echo "Repair selected."
    #This is just a re-installation. To be honest... Maybe add some debugging? Do we want to wipe configs? Ask user?
    # Install but with keeping logs/config - Ask user?
    # I don't know if it's worth re-writing install so you can pass it either Install or Repair...

    deploy "Repair"
}


function uninstall() {
    echo "Uninstalling NoIP-Manager."
    echo
    # Remove crontab
    $SUDO sed -i '/noip-manager/d' /etc/crontab
    # Removing script folder & executable
    $SUDO 'rm' -rf $INSTDIR
    $SUDO 'rm' $EXECUTABLE
    echo
    read -p 'Do you want to remove configuration & log files? (y/n): ' clearAll
    if [ "${clearAll^^}" = "Y" ]
    then
      $SUDO 'rm' -rf $LOGS
      $SUDO 'rm' -rf $CONFIG
      echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] All logs and config files have been removed."
    fi

    echo
    echo -e "\e[1A\e[K[\e[32m\u2713\e[39m] NoIP Manager has been uninstalled."
    echo

    # Remove installation folder
    $SUDO 'rm' -r $(pwd)
    cd ~/
}


function noip() {
    echo
    echo "Enter your No-IP Account details. You can set additional accounts up after installation."
    read -p 'Alias: ' alias
    read -p 'Username or Email: ' uservar
    read -sp 'Password: ' passvar

    passvar=`echo -n $passvar | base64`
    echo

    # Add account details to accounts.xml 
    $SUDO xmlstarlet -q ed -L -u /accounts/noip[@alias][1]/@alias -v $alias $CONFIG/accounts.xml
    $SUDO xmlstarlet -q ed -L -u /accounts/noip[1]/username -v $uservar $CONFIG/accounts.xml
    $SUDO xmlstarlet -q ed -L -u /accounts/noip[1]/password -v $passvar $CONFIG/accounts.xml
    $SUDO xmlstarlet -q ed -L -u /accounts/noip[1]/created -v "$(timestamp)" $CONFIG/accounts.xml
}


function notifySetup() {
    echo
    echo "Configuring Notifications."
    echo

    $SUDO xmlstarlet -q ed -L -u /settings/notifications/enabled -v "True" $CONFIG/config.xml
    $SUDO xmlstarlet -q ed -L -u /settings/notifications/type -v $1 $CONFIG/config.xml
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

    $SUDO xmlstarlet -q ed -L -s /settings/Notifications -t elem -n "discord_webook" -v $webhook $CONFIG/config.xml
}


function pushover() {
    echo "Enter your Pushover Token..."
    read -p 'Token: ' tokenvar

    echo "Enter your Pushover User Key..."
    read -p 'User: ' uservar

    # Convert User key & Token to base64
    tokenvar=`echo -n $tokenvar | base64`
    uservar=`echo -n $uservar | base64`

    $SUDO xmlstarlet -q ed -s /settings/Notifications -t elem -n "pushover_token" -v $tokenvar $CONFIG/config.xml
    $SUDO xmlstarlet -q ed -s /settings/Notifications -t elem -n "pushover_user_key" -v $uservar $CONFIG/config.xml
}


function slack() {
    echo "Enter your Slack Bot User OAuth Access Token..."
    read -p 'Token: ' tokenvar

    echo "Enter the channel you wish to receive notifications on..."
    read -p 'Channel: ' channel

    tokenvar=`echo -n $tokenvar | base64`

    $SUDO xmlstarlet -q ed -s /settings/Notifications -t elem -n "slack_token" -v $tokenvar $CONFIG/config.xml
    $SUDO xmlstarlet -q ed -s /settings/Notifications -t elem -n "slack_channel" -v $channel $CONFIG/config.xml
}


function telegram() {
    echo "Please configure Telegram:"
    $SUDO telegram-send --configure
}


function mainMenu() {
    PS3='Select an option: '
    options=()

    clear

    echo -e "\e[32m  _   _      _____ _____    \e[94m__  __\n\e[32m | \ | |    |_   _|  __ \  \e[94m|  \/  |\n\e[32m |  \| | ___  | | | |__) | \e[94m| \  / | __ _ _ __   __ _  __ _  ___ _ __\n\e[32m | . \` |/ _ \ | | |  ___/  \e[94m| |\/| |/ _\` | '_ \ / _\` |/ _\` |/ _ \ '__|\n\e[32m | |\  | (_) || |_| |      \e[94m| |  | | (_| | | | | (_| | (_| |  __/ |\n\e[32m |_| \_|\___/_____|_|      \e[94m|_|  |_|\__,_|_| |_|\__,_|\__, |\___|_|\n                                                      __/ |\n\e[90m  Written by Demix\e[94m                                   |___/"
    echo
    echo -e "\e[39mWelcome to the installer for \e[92mNoIP Manager\e[39m. Please select an option from below."
    echo

    if test -f "$EXECUTABLE"; then
        cVersion=(`noip-manager --version | grep -o '[0-9.]*'`)
        intcVersion="${cVersion//[!0-9]/}"
        intlVersion="${VERSION//[!0-9]/}"

        if [ $intlVersion -gt $intcVersion ]; then
            echo -e "Update Available! - Currently installed: v${cVersion} (\e[32mv${VERSION}\e[39m Available)."
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


# Call config function which sets up variables for the installer.
config

# Load the main menu.
mainMenu
