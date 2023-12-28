#!/bin/bash

# Define the service file path, script path, and log file path
SERVICE_FILE="/etc/systemd/system/display.service"
SCRIPT_PATH="/home/mks/OpenNept4une/display/display.py"
VENV_PATH="/home/mks/OpenNept4une/display/venv"
LOG_FILE="/var/log/display.log"

# Check if the script exists
if [ ! -f "$SCRIPT_PATH" ]; then
    echo "Error: Script $SCRIPT_PATH not found."
    exit 1
fi

# Create the systemd service file
echo "Creating systemd service file at $SERVICE_FILE..."
cat <<EOF | sudo tee $SERVICE_FILE > /dev/null
[Unit]
Description=My Python Script Service
After=network.target

[Service]
ExecStartPre=/bin/sleep 30
ExecStart=/bin/bash -c 'source $VENV_PATH/bin/activate && exec python $SCRIPT_PATH >> $LOG_FILE 2>&1'
WorkingDirectory=$(dirname $SCRIPT_PATH)
Restart=always
User=$(whoami)

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd to read new service file
echo "Reloading systemd..."
sudo systemctl daemon-reload

# Enable and start the service
echo "Enabling and starting the service..."
sudo systemctl enable display.service
sudo systemctl start display.service

echo "Service setup complete."
