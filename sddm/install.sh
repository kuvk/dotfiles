#!/usr/bin/env bash

green='\033[0;32m'
red='\033[0;31m'
bred='\033[1;31m'
cyan='\033[0;36m'
grey='\033[2;37m'
reset="\033[0m"

SHPATH=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
: ${THEMES_DIR:=/usr/share/sddm/themes}
: ${SDDM_HYPR_DIR:=/usr/share/sddm/hypr}
: ${KDE_SETTINGS_DIR:=/etc/sddm.conf.d}

install_dependencies () {
    if command -v pacman &>/dev/null; then
        echo -e "${grey}Installing dependencies with 'pacman'...${reset}"
        sudo pacman -S --needed sddm qt6-svg qt6-virtualkeyboard qt6-multimedia-ffmpeg
    elif command -v xbps-install &>/dev/null; then
        echo -e "${grey}Installing dependencies with 'xbps'...${reset}"
        sudo xbps-install sddm qt6-svg qt6-virtualkeyboard qt6-multimedia
    elif command -v dnf &>/dev/null; then
        echo -e "${grey}Installing dependencies with 'dnf'...${reset}"
        sudo dnf install sddm qt6-qtsvg qt6-qtvirtualkeyboard qt6-qtmultimedia
    elif command -v zypper &>/dev/null; then
        echo -e "${grey}Installing dependencies with 'zypper'...${reset}"
        sudo zypper install sddm-qt6 libQt6Svg6 qt6-virtualkeyboard qt6-virtualkeyboard-imports qt6-multimedia qt6-multimedia-imports
    else
        echo -e "\n${red}Could not install dependencies!\nDo it manually: ${cyan}https://github.com/uiriansan/kuvkSDDM/wiki#dependencies${reset}\n"
        return 1
    fi
}

copy_files () {
    echo -e "${grey}Copying files from '${SHPATH}/' to '${THEMES_DIR}/kuvk/'...${reset}"
    if [ ! -d "${THEMES_DIR}/kuvk" ]; then
        sudo rm -rf "${THEMES_DIR}/kuvk"
    fi
    sudo mkdir -p ${THEMES_DIR}/kuvk
    sudo cp -rf "$SHPATH"/theme/. ${THEMES_DIR}/kuvk/
}

copy_fonts () {
    echo -e "${grey}Copying fonts to '/usr/share/fonts/'...${reset}"
    sudo cp -r ${THEMES_DIR}/kuvk/fonts/{redhat,redhat-vf} /usr/share/fonts/
}

apply_theme () {
    sudo cp -f /etc/sddm.conf /etc/sddm.conf.bkp
    echo -e "${green}Backup for SDDM config saved in '/etc/sddm.conf.bkp'${reset}"
    sudo cp -f -v "$SHPATH"/sddm.conf /etc/sddm.conf
    echo -e "${grey}Created new '/etc/sddm.conf'...${reset}"

    if [ ! -d "${SDDM_HYPR_DIR}" ]; then
        sudo mkdir -p "${SDDM_HYPR_DIR}"
    fi
    sudo cp -f -v "$SHPATH"/hyprland.lua "${SDDM_HYPR_DIR}/hyprland.lua"
    echo -e "${grey}Created '${SDDM_HYPR_DIR}/hyprland.lua'...${reset}"

    if [ ! -f "${KDE_SETTINGS_DIR}/kde_settings.conf" ]; then
        sudo mkdir -p "${KDE_SETTINGS_DIR}"
        sudo cp -f -v "$SHPATH"/kde_settings.conf "${KDE_SETTINGS_DIR}/kde_settings.conf"
        echo -e "${grey}Created '${KDE_SETTINGS_DIR}/kde_settings.conf'...${reset}"
    fi
}
[ "$UID" -eq 0 ] || exec sudo "$0" "$@"
install_dependencies ;
copy_files &&
copy_fonts ;
apply_theme &&
echo -e "\n${green} Theme successfully installed!${reset}"
