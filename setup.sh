#!/bin/sh

# https://gist.github.com/davejamesmiller/1965569
ask() {
    local prompt default reply

    if [ "${2:-}" = "Y" ]; then
        prompt="Y/n"
        default=Y
    elif [ "${2:-}" = "N" ]; then
        prompt="y/N"
        default=N
    else
        prompt="y/n"
        default=
    fi

    while true; do

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt]: "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

SUR_MODEL="$(dmidecode | grep "Product Name" -m 1 | xargs | sed -e 's/Product Name: //g')"

echo "==> Copying the config files under root to where they belong..."
for dir in $(ls root/); do
    cp -Rbv "root/$dir/"* "/$dir/"
done

echo "==> Copying firmware files under root..."
cp -rv firmware/* /lib/firmware/

echo "==> Making /lib/systemd/system-sleep/sleep executable..."
chmod -v a+x /lib/systemd/system-sleep/sleep

echo

echo "Suspend is recommended over hibernate. If you chose to use"
echo "hibernate, please make sure you've setup your swap file per"
echo "the instructions in the README."

if ask "Do you want to replace suspend with hibernate?" N; then
    echo "==> Using Hibernate instead of Suspend..."
    if [ -f "/usr/lib/systemd/system/hibernate.target" ]; then
        LIB="/usr/lib"
    else
        LIB="/lib"
    fi

    ln -vsfb $LIB/systemd/system/hibernate.target /etc/systemd/system/suspend.target
    ln -vsfb $LIB/systemd/system/systemd-hibernate.service /etc/systemd/system/systemd-suspend.service
else
    echo "==> Not touching Suspend"
fi

echo

if [ "$SUR_MODEL" = "Surface Go" ]; then
    if [ ! -f "/etc/init.d/surfacego-touchscreen" ]; then
        echo "==> Patching power control for Surface Go touchscreen..."
        echo "echo \"on\" > /sys/devices/pci0000:00/0000:00:15.1/i2c_designware.1/power/control" \
            > /etc/init.d/surfacego-touchscreen
        chmod -v 755 /etc/init.d/surfacego-touchscreen
        update-rc.d surfacego-touchscreen defaults
    fi
fi

echo

echo "Setting your clock to local time can fix issues with Windows dualboot."
if ask "Do you want to set your clock to local time instead of UTC?" N; then
    echo "==> Setting clock to local time..."
    timedatectl set-local-rtc 1
    hwclock --systohc --localtime
else
    echo "==> Not setting clock..."
fi

echo

echo "Patched libwacom packages are available to better support the pen."
echo "If you intend to use the pen, it's recommended that you install them!"

if ask "Do you want to install the patched libwacom?" Y; then
    echo "==> Downloading latest libwacom-surface..."

    urls=$(curl --silent "https://api.github.com/repos/linux-surface/libwacom-surface-deb/releases/latest" \
           | tr ',' '\n' \
           | grep '"browser_download_url":' \
           | sed -E 's/.*"([^"]+)".*/\1/' \
           | grep '.deb$')

    wget -P tmp $urls

    echo "==> Installing latest libwacom-surface..."

    dpkg -i tmp/*.deb
    rm -rf tmp
else
    echo "==> Not touching libwacom"
fi

echo

if ask "Do you want to download and install the latest kernel?" Y; then
    echo "==> Downloading latest kernel..."

    urls=$(curl --silent "https://api.github.com/repos/linux-surface/linux-surface/releases/latest" \
           | tr ',' '\n' \
           | grep '"browser_download_url":' \
           | sed -E 's/.*"([^"]+)".*/\1/' \
           | grep '.deb$')

    wget -P tmp $urls

    echo
    echo "==> Installing latest kernel..."

    dpkg -i tmp/*.deb
    rm -rf tmp
else
    echo "==> Not downloading latest kernel"
fi

echo

echo "All done! Please reboot."
