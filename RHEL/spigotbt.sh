Minecraft Server
OS: Ubuntu Server LTS
	RAM: 8GB
	CPU: 8 core (1 cpu, 4 core, 2 threads)
	Space: 100GB

install script should only provide a BuildTools-script placed in /usr/bin named SpiggotBT, which should be run at login

	#!/bin/bash
	sudo apt update && sudo apt upgrade -y
	sudo apt install openjdk-21-jdk -y
	sudo update-alternatives --config java
	echo "JAVA_HOME=$(readlink -f /usr/bin/java | sed \"s:bin/java::")" | sudo tee -a /etc/environment
source /etc/environment

	curl -o /home/spigot/spigot-build/BuildTools.jar https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar
	
SpigotMC
Build Tools

1-5 players:
	> 3.5 GHz (6 cores)
	6-8 GB Ram
	10-20 GB Space for Spigot

seperate build directory for SpigotMC with BuildTools
mkdir spigot-build
java -jar BuildTools.jar --rev latest

#!/bin/bash

USER_HOME="/home/aas001mi"
BUILD_DIR="$USER_HOME/spigot-build"
SERVER_DIR="$USER_HOME/spigot"
BACKUP_DIR="$USER_HOME/server-backup"
BUILDTOOLS_JAR="$BUILD_DIR/BuildTools.jar"
SPIGOT_JAR="spigot-*.jar"

# Install prerequisites
install_prereqs() {
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y openjdk-17-jdk git curl
    sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java
    echo "JAVA_HOME=$(readlink -f /usr/bin/java | sed 's:/bin/java::')" >> "$HOME/.bashrc"
    export JAVA_HOME
}

# Install setup
install() {
    mkdir -p "$BUILD_DIR" "$SERVER_DIR" "$BACKUP_DIR"
    install_prereqs
    exec "$0" --update
}

# Update: build new Spigot
update() {
    sudo apt update && sudo apt upgrade -y

    # Stop running Spigot server if active
    pkill -f spigot-*.jar || true

    # Download latest BuildTools
    cd "$BUILD_DIR"
    curl -o "$BUILDTOOLS_JAR" https://hub.spigotmc.org/jenkins/job/BuildTools/lastSuccessfulBuild/artifact/target/BuildTools.jar

    # Build Spigot
    java -jar "$BUILDTOOLS_JAR" --rev latest

    # Backup old JAR and move new one
    # Find next available increment number
	backup_number=1
	while [ -f "$BACKUP_DIR/spigotmc-$backup_number.bak" ]; do
		((backup_number++))
	done
	mv "$SERVER_DIR/$SPIGOT_JAR" "$BACKUP_DIR/spigotmc-$backup_number.bak"   
    mv "$BUILD_DIR/$SPIGOT_JAR" "$SERVER_DIR/" 2>/dev/null
}

# Main
case "$1" in
    --install)
        install
        ;;
    --update)
        update
        ;;
    *)
        echo "Usage: $0 --install | --update"
        exit 1
        ;;
esac   
