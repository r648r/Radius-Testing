#!/bin/bash

OUTPUT_FILE="/dev/null"
RADIUS_IP="XXX.XXX.XXX.XXX"
PASSWORD=""

function show_help {
    echo "Usage: $0 -c|--creds <CSV_FILE> [-o|--output <OUTPUT_FILE>] [-r|--radius <RADIUS_IP>] [-p|--password <PASSWORD>]"
    echo "  -c, --creds     Spécifie le fichier CSV contenant les informations d'identification."
    echo "  -o, --output    Spécifie le fichier de sortie pour enregistrer les résultats."
    echo "  -r, --radius    Spécifie l'adresse IP du serveur RADIUS."
    echo "  -p, --password  Spécifie le mot de passe à utiliser dans la commande radtest."
    exit 1
}

if [ "$#" -lt 2 ]; then
    show_help
fi

while [ "$#" -gt 0 ]; do
    case "$1" in
        -c|--creds)
            if [ ! -e "$2" ]; then
                echo "Erreur: Le fichier CSV '$2' n'existe pas."
                show_help
            fi
            CSV_FILE="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        -r|--radius)
            RADIUS_IP="$2"
            shift 2
            ;;
        -p|--password)
            PASSWORD="$2"
            shift 2
            ;;
        *)
            show_help
            ;;
    esac
done

if [ -z "$CSV_FILE" ]; then
    show_help
fi

> "$OUTPUT_FILE"
echo "-----------------------------------------------"

while IFS="," read -r username password _; do
    if [ "$username" != "username" ]; then
        command="radtest -t pap \"$username\" \"$password\" $RADIUS_IP 0 $PASSWORD"
        echo "$command" >> "$OUTPUT_FILE"
        echo "------------------------------------------------------------------------------------------------------------------------" >> "$OUTPUT_FILE"
        
        output=$(eval "$command" 2>&1)
        echo "$output" >> "$OUTPUT_FILE"

        if [[ $output == *"Received Access-Accept"* ]]; then
            echo -e "[\033[32m + \033[0m] $username"

            framed_ip=$(echo "$output" | grep -oP "Framed-IP-Address = \K[0-9.]*")
            framed_route=$(echo "$output" | grep -oP "Framed-Route = \K\S+" | sed 's/"//g')
            delegated_ipv6_prefix=$(echo "$output" | grep -oP "Delegated-IPv6-Prefix = \K\S+" | sed 's/"//g')

            if [ -n "$framed_route" ]; then
                echo -e "[\033[0;34m R \033[0m] $framed_route"
            fi

            if [ -n "$framed_ip" ]; then
                echo -e "[\033[0;35m@v4\033[0m] $framed_ip"
            fi

            if [ -n "$delegated_ipv6_prefix" ]; then
                echo -e "[\033[0;36m@v6\033[0m] $delegated_ipv6_prefix"
            fi
        else
            echo -e "[\033[31m - \033[0m] $username"
        fi
        echo "-----------------------------------------------"
        echo "" >> "$OUTPUT_FILE"
    fi
done < "$CSV_FILE"

echo "Les résultats ont été enregistrés dans le fichier : $OUTPUT_FILE"
