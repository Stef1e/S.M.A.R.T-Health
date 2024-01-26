#!/bin/bash
#
# File:     S.M.A.R.T-Health.sh
#
# Purpose:  Scan/Diagnose Drive related issues
#
# Author:   Steven Fleming
#           <sfleming@hivelocity.net>
#
# License:  GPL version 2

# Privilage check
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run with sudo. Exiting."
    exit 1
fi

# Determine which package manager to use based on whether the system is RHEL or Debian-based
if [[ -f /etc/redhat-release ]]; then
  PACKAGE_MANAGER="yum"
elif [[ -f /etc/debian_version ]]; then
  PACKAGE_MANAGER="apt-get"
else
  echo "Unable to determine package manager"
  exit 1
fi

# Install Smartmontools using the appropriate package manager
if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
  # Install Smartmontools on RHEL-based systems using yum
  sudo $PACKAGE_MANAGER install smartmontools -y
elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
  # Install Smartmontools on Debian-based systems using apt-get
  sudo $PACKAGE_MANAGER update
  sudo $PACKAGE_MANAGER install smartmontools -y
fi

# Set the options for the smartctl command
options="-a"

# Get a list of all drives
drives=$(smartctl --scan | cut -f1)

# Check if a hardware RAID controller is present
if lspci | grep -q "RAID"; then
    # Print a warning message
    echo "Hardware RAID present, smart scan and drive count may be inaccurate"
# Check if a software RAID array is present
elif mdadm --detail --scan | grep -q "md"; then
    # Print a warning message
    echo "Software RAID present, smart scan and drive count may be inaccurate"
else

# Set the log file path
log_file="/var/log/drive_errors.log"

# Initialize an empty variable to store the error messages
errors=""

# Iterate through the drives
for drive in $drives; do
    # Check if the drive is an NVMe drive
    if echo "$drive" | grep -q "nvme"; then
        # Run the nvme smart-log and nvme error-log commands on the drive
        smart_log_output="$(nvme smart-log "$drive")"
        error_log_output="$(nvme error-log "$drive")"

        # Extract the values of the relevant attributes from the smart-log output
        available_spare_threshold=$(echo "$smart_log_output" | awk '/available_spare_threshold/ {print $3}')
        temperature=$(echo "$smart_log_output" | awk '/temperature/ {print $3}')
        media_errors=$(echo "$smart_log_output" | awk '/media_errors/ {print $3}')
        num_err_log_entries=$(echo "$smart_log_output" | awk '/num_err_log_entries/ {print $3}')
        nvme_pwr_on_hrs=$(echo "$smart_log_output" | awk '/power_on_hours/ {print $3}')

        # Check if the available_spare_threshold is below 10
        if [[ "$available_spare_threshold" -lt 10 ]]; then
            # Print an error message
            echo "Error on $drive: available_spare_threshold"
        fi

        # Check if the temperature is above 70 degrees Celsius
        if [[ $temperature -gt 70 ]]; then
            # Print an error message
            echo "Error on $drive: temperature"
        fi

        # Check if the media_errors is above 0
        if [[ $media_errors -gt 0 ]]; then
            # Print an error message
            echo "Error on $drive: media_errors"
        fi

        # Check if the num_err_log_entries is above 0
        if [[ $num_err_log_entries -gt 0 ]]; then
            # Print an error message
            echo "Error on $drive: num_err_log_entries"
        fi

        # Extract the values of the relevant attributes from the error-log output
        error_count=$(echo "$error_log_output" | awk '/error_count/ {print $3}')
        last_error_timestamp=$(echo "$error_log_output" | awk '/last_error_timestamp/ {print $3}')

        # Check if the error_count is above 0
        if [[ $error_count -gt 0 ]]; then
            # Print an error message
            echo "Error on $drive: error_count"
        fi

        # Check if the last_error_timestamp is above 0
        if [[ $last_error_timestamp -gt 0 ]]; then
            # Print an error message
            echo "Error on $drive: last_error_timestamp"
        fi
    else
    # Run the smartctl command on the drive
    output=$(smartctl $options $drive)

    # Extract the values of the relevant attributes
    raw_read_error_rate=$(echo "$output" | awk '/Raw_Read_Error_Rate/ {print $10}')
    spin_retry_count=$(echo "$output" | awk '/Spin_Retry_Count/ {print $10}')
    reported_uncorrectable_errors=$(echo "$output" | awk '/Reported_Uncorrectable_Errors/ {print $10}')
    command_timeout=$(echo "$output" | awk '/Command_Timeout/ {print $10}')
    reallocated_sector_count=$(echo "$output" | awk '/Reallocated_Sector_Count/ {print $10}')
    reallocated_event_count=$(echo "$output" | awk '/Reallocated_Event_Count/ {print $10}')
    current_pending_sector=$(echo "$output" | awk '/Current_Pending_Sector/ {print $10}')
    power_on_hours=$(echo "$output" | awk '/Power_On_Hours/ {print $10}')

    # Check if the Raw_Read_Error_Rate is above 1
    if [[ $raw_read_error_rate =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Raw_Read_Error_Rate"
    fi

    # Check if the Spin_Retry_Count is above 1
    if [[ $spin_retry_count =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Spin_Retry_Count"
    fi
    # Check if the Reported_Uncorrectable_Errors is above 1
    if [[ $reported_uncorrectable_errors =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Reported_Uncorrectable_Errors"
    fi

    # Check if the Command_Timeout is above 1
    if [[ $command_timeout =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Command_Timeout"
    fi

    # Check if the Reallocated_Sector_Count is above 1
    if [[ $reallocated_sector_count =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Reallocated_Sector_Count"
    fi

    # Check if the Reallocated_Event_Count is above 1
    if [[ $reallocated_event_count =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Reallocated_Event_Count"
    fi

    # Check if the Current_Pending_Sector is above 1
    if [[ $current_pending_sector =~ [^0] ]]; then
        # Print an error message
        echo "Error on $drive: Current_Pending_Sector"
    fi

    # Check if the Power_On_Hours is above 30000
    if [[ $power_on_hours =~ [3-9][0-9]*[0-9][0-9][0-9] ]]; then
        # Print an error message
        echo "Error on $drive: Power_On_Hours"
    fi

 fi

#done

# Set the subject and message body
#subject="Smart Monitoring Tool: Error Report"
#message="There were errors found during the drive check. Please see the attached log file for details. It can also be viewed through command line from /var/log/drive_errors.log"

# Send the email
#echo "$message" | sendmail -f "$subject" root@localhost

done
