#!/bin/bash

get_hostnames() {
    input=$1
    output_file="output.txt"

    # Function to update the progress bar
    update_progress() {
        percentage=$1
        echo -ne "Progress: [$percentage%] \r"
    }

    # Check if the input is an IP address or range
    if [[ $input =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        hostnames=$(host $input | grep "domain name pointer" | awk '{print $5}' | sed 's/\.$//')
        if [ -n "$hostnames" ]; then
            echo "Hostnames for $input => $hostnames" | tee -a "$output_file"
        else
            echo "No hostnames found for $input." | tee -a "$output_file"
        fi
    elif [[ $input =~ ^[0-9]{1,5}-[0-9]{1,5}$ ]]; then
        # Input is an IP range
        start_ip=$(echo $input | cut -d'-' -f1)
        end_ip=$(echo $input | cut -d'-' -f2)
        total_ips=$((end_ip - start_ip + 1))
        current_ip=$start_ip

        echo "Checking hostnames for IP range $input:" | tee -a "$output_file"
        while [ $current_ip -le $end_ip ]; do
            ip_address="$current_ip"
            hostnames=$(host $ip_address | grep "domain name pointer" | awk '{print $5}' | sed 's/\.$//')
            if [ -n "$hostnames" ]; then
                echo "Hostnames for $ip_address => $hostnames" | tee -a "$output_file"
            fi

            # Update progress bar
            percentage=$((100 * (current_ip - start_ip + 1) / total_ips))
            update_progress $percentage

            ((current_ip++))
        done
        echo "Progress: [100%] Complete" | tee -a "$output_file"
    elif [[ $input =~ ^AS[0-9]+$ ]]; then
        # Input is an ASN
        ip_ranges=$(whois -h whois.radb.net -- "-i origin $input" | grep "route:" | awk '{print $2}')
        total_ranges=$(echo "$ip_ranges" | wc -l)
        current_range=1

        echo "IP Ranges for ASN $input:" | tee -a "$output_file"
        echo "$ip_ranges" | tee -a "$output_file"

        echo "Checking hostnames for IPs within the ASN $input:" | tee -a "$output_file"
        while IFS= read -r ip_range; do
            ip_addresses=$(nmap -sL -n $ip_range | grep "Nmap scan report for" | awk '{print $5}')
            total_ips=$(echo "$ip_addresses" | wc -w)
            current_ip=1

            for ip in $ip_addresses; do
                hostnames=$(host $ip | grep "domain name pointer" | awk '{print $5}' | sed 's/\.$//')
                if [ -n "$hostnames" ]; then
                    echo "Hostname for $ip => $hostnames" | tee -a "$output_file"
                fi

                # Update progress bar
                percentage=$((100 * (current_range - 1) + 100 * current_ip / total_ips / total_ranges))
                update_progress $percentage

                ((current_ip++))
            done

            ((current_range++))
        done <<< "$ip_ranges"
        echo "Progress: [100%] Complete" | tee -a "$output_file"
    else
        echo "Invalid input. Please provide a valid IP address, IP range, or ASN." | tee -a "$output_file"
    fi
}

# Prompt the user for input type
echo "Choose the type of input:"
echo "1. IP address"
echo "2. IP range"
echo "3. ASN"
read -p "Enter your choice (1/2/3): " choice

case $choice in
    1)
        read -p "Enter an IP address: " user_input
        ;;
    2)
        read -p "Enter an IP range (e.g., 192.168.1.1-192.168.1.5): " user_input
        ;;
    3)
        read -p "Enter an ASN (e.g., AS15169): " user_input
        ;;
    *)
        echo "Invalid choice. Exiting." | tee -a "$output_file"
        exit 1
        ;;
esac

# Call the function with the provided input
get_hostnames "$user_input"
