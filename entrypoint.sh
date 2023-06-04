#!/bin/bash
pipe=/tmp/tmod.pipe

if [[ "$UPDATE_NOTICE" != "false" ]]; then
  echo -e "\n\n!!-------------------------------------------------------------------!!"
  echo -e "REGARDING ISSUE #12"
  echo -e "[UPDATE NOTICE] Recently, this container has been updated to remove dependency on the Root User account inside the container."
  echo -e "[UPDATE NOTICE] Because of this update, prior configurations which mapped HOST directories for Mods, Worlds and Custom Configs will no longer work."
  echo -e "[UPDATE NOTICE] Your World files are NOT DELETED!"
  echo -e "[UPDATE NOTICE] If you are experiencing issues with your worlds or mods loading properly, please refer to the following SFB for more information."
  echo -e "[UPDATE NOTICE] https://github.com/JACOBSMILE/tmodloader1.4/wiki/SFB:-Removing-Dependency-on-Root-(Issue-12)"
  echo -e "!!-------------------------------------------------------------------!!"
  echo -e "\n[SYSTEM] The Server will launch in 30 seconds. To disable this notice, set the UPDATE_NOTICE environment variable equal to \"false\"."
  echo -e "[SYSTEM] This notice will be eventually removed in a later update."
  sleep 30s
fi

echo -e "[SYSTEM] Shutdown Message set to: $TMOD_SHUTDOWN_MESSAGE"
echo -e "[SYSTEM] Save Interval set to: $TMOD_AUTOSAVE_INTERVAL minutes"

configPath=$HOME/terraria-server/serverconfig.txt

# Check Config
if [[ "$TMOD_USECONFIGFILE" == "Yes" ]]; then
    if [ -e $HOME/terraria-server/customconfig.txt ]; then
        echo -e "[!!] The tModLoader server was set to load with a config file. It will be used instead of the environment variables."
    else
        echo -e "[!!] FATAL: The tModLoader server was set to launch with a config file, but it was not found. Please map the file to $HOME/terraria-server/customconfig.txt and launch the server again."
        sleep 5s
        exit 1
    fi
else
  ./prepare-config.sh
fi

# Trapped Shutdown, to cleanly shutdown
function shutdown () {
  inject "say $TMOD_SHUTDOWN_MESSAGE"
  sleep 3s
  inject "exit"
  tmuxPid=$(pgrep tmux)
  tmodPid=$(pgrep --parent $tmuxPid Main)
  while [ -e /proc/$tmodPid ]; do
    sleep .5
  done
  rm $pipe
}

# Enable Mods
enabledpath="$HOME/.local/share/Terraria/tModLoader/Mods/enabled.json"
modpath="$HOME/.local/share/Terraria/tModLoader/Mods"
rm -f "$enabledpath"

if [ -z "$TMOD_ENABLEDMODS" ]; then
  echo -e "[SYSTEM] No mods to load. Please set the TMOD_ENABLEDMODS environment variable equal to a comma-separated list of mod names."
  echo -e "[SYSTEM] For more information, please see the Github README."
  sleep 5s
else
  echo -e "[SYSTEM] Enabling Mods specified in the TMOD_ENABLEDMODS environment variable..."
  echo '[' > "$enabledpath"  # Overwrite the enabled.json file

  # Remove single quotes and double quotes from the input
  MOD_NAMES="${TMOD_ENABLEDMODS//[\'\"]}"

  # Convert the comma-separated list of mod names to an array
  IFS=',' read -ra MOD_ARRAY <<< "$MOD_NAMES"

  for MOD_NAME in "${MOD_ARRAY[@]}"; do
    echo -e "[SYSTEM] Enabling $MOD_NAME..."
    modfile="$modpath/$MOD_NAME.tmod"
    if [ ! -f "$modfile" ]; then
      echo -e " [!!] The mod file '$MOD_NAME.tmod' does not exist."
      continue
    fi
    echo "\"$MOD_NAME\"," >> "$enabledpath"
    echo -e "[SYSTEM] Enabled $MOD_NAME"
  done

  echo ']' >> "$enabledpath"
  echo -e "\n[SYSTEM] Finished loading mods."
fi

# Startup command
server="$HOME/terraria-server/LaunchUtils/ScriptCaller.sh -server -steamworkshopfolder \"$HOME/terraria-server/workshop-mods/steamapps/workshop\" -config \"$configPath\""

# Trap the shutdown
trap shutdown TERM INT
echo -e "tModLoader is launching with the following command:"
echo -e $server

# Create the tmux and pipe, so we can inject commands from 'docker exec [container id] inject [command]' on the host
sleep 5s
mkfifo $pipe
tmux new-session -d "$server | tee $pipe"

# Call the autosaver
$HOME/terraria-server/autosave.sh &

# Infinitely print the contents of the pipe, so the container still logs the Terraria Server.
cat $pipe &
wait ${!}