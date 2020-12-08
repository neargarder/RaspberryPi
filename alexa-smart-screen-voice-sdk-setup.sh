#!/bin/bash
#
# https://developer.amazon.com/en-US/docs/alexa/alexa-smart-screen-sdk/raspberry-pi.html
#
# Only installs the alexa voice sdk - as part of smart screen
# Does not install the APL core library or the Smart Screen SDK!

if [ $(id -u) -eq 0 ]
then
    echo "Please do not run as root"
    exit 1
fi

# assumes in ~
default_config_file_name="config.json"
ls $HOME/$default_config_file_name
if [ ! -f "$HOME/$default_config_file_name" ] ;
then
    echo "Create config.json using the Amazon portal https://developer.amazon.com/en-US/docs/alexa/alexa-voice-service/input-avs-credentials.html"
    exit 1
fi

cd $HOME
mkdir sdk-folder
cd sdk-folder
mkdir sdk-build sdk-source third-party sdk-install db

sudo apt-get -y install \
   git gcc cmake build-essential libsqlite3-dev libcurl4-openssl-dev libfaad-dev \
   libssl-dev libsoup2.4-dev libgcrypt20-dev libgstreamer-plugins-bad1.0-dev \
    gstreamer1.0-plugins-good libasound2-dev doxygen

cd $HOME/sdk-folder/third-party

# yes, 2016 is the last year it was deemed truely stable
wget -c http://www.portaudio.com/archives/pa_stable_v190600_20161030.tgz
tar zxf pa_stable_v190600_20161030.tgz

cd portaudio
./configure --without-jack
make

pip install commentjson


cd $HOME/sdk-folder/sdk-source    
git clone --single-branch --branch v1.21.0 git://github.com/alexa/avs-device-sdk.git

# This installs the sensory library to enable wake word.  
# It pauses the installation asking for liscense agreement.
# There should really be a switch here to enable/disable
cd $HOME/sdk-folder/third-party
git clone git://github.com/Sensory/alexa-rpi.git
cd $HOME/sdk-folder/third-party/alexa-rpi/bin/
./license.sh

# Remove the -DSENSORY_KEY_WORD_DETECTOR.... to remove Sensory
cd $HOME/sdk-folder/sdk-build
 cmake $HOME/sdk-folder/sdk-source/avs-device-sdk \
 -DSENSORY_KEY_WORD_DETECTOR=ON \
 -DSENSORY_KEY_WORD_DETECTOR_LIB_PATH=$HOME/sdk-folder/third-party/alexa-rpi/lib/libsnsr.a \
 -DSENSORY_KEY_WORD_DETECTOR_INCLUDE_DIR=$HOME/sdk-folder/third-party/alexa-rpi/include \
 -DGSTREAMER_MEDIA_PLAYER=ON \
 -DPORTAUDIO=ON \
 -DPORTAUDIO_LIB_PATH=$HOME/sdk-folder/third-party/portaudio/lib/.libs/libportaudio.a \
 -DPORTAUDIO_INCLUDE_DIR=$HOME/sdk-folder/third-party/portaudio/include \
 -DCMAKE_BUILD_TYPE=DEBUG \
 -DCMAKE_INSTALL_PREFIX=$HOME/sdk-folder/sdk-install \
 -DRAPIDJSON_MEM_OPTIMIZATION=OFF

make install

cp $HOME/config.json $HOME/sdk-folder/sdk-source/avs-device-sdk/tools/Install

cd $HOME/sdk-folder/sdk-source/avs-device-sdk/tools/Install 
bash genConfig.sh config.json \
    your-device-serial-number \
    $HOME/sdk-folder/db \
    $HOME/sdk-folder/sdk-source/avs-device-sdk \
    $HOME/sdk-folder/sdk-build/Integration/AlexaClientSDKConfig.json \
    -DSDK_CONFIG_MANUFACTURER_NAME="manufacturer name" \
    -DSDK_CONFIG_DEVICE_DESCRIPTION="device description"

# edit config file
cd $HOME/sdk-folder/sdk-build/Integration
if ! grep -q "gstreamerMediPlayer" AlexaClientSDKConfig.json; then
    cp AlexaClientSDKConfig.json AlexaClientSDKConfig-$(date -d "today" +"%Y-%m-%d-%H%M%S").json 
    sed -i "s/^{/{\n    \"gstreamerMediaPlayer\":{\n        \"audioSink\":\"alsasink\"\n    },/" AlexaClientSDKConfig.json
fi

# verify audio is working prior to install
aplay /usr/share/sounds/alsa/Front_Center.wav

echo "Run the SDK sample using alexa-smart-screen-voice-sdk-run.sh"
echo "The APL Core library and scmart screen app have not yet been installed!!"
