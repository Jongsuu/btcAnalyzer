#!/bin/bash

# Author: Jongsu

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"

trap ctrl_c INT

function ctrl_c() {
  echo -e "\n${redColour}[!] Saliendo...\n${endColour}"
  
  rm address.information money* total_entrada_salida.tmp entradas.tmp salidas.tmp ut.t* 2>/dev/null
  tput cnorm; exit 1
}

function helpPanel() {
  echo -e "\n${redColour}[!] Use: ./btcAnalyzer${endColour}"

  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "${endColour}"
    
  echo -e "\n\n\t${grayColour}[-e]${endColour}${yellowColour} Exploration mode${endColour}"
  echo -e "\t\t${purpleColour}unconfirmed_transactions${endColour}${yellowColour}:\t List unconfirmed transactions${endColour}"
  echo -e "\t\t${purpleColour}inspect${endColour}${yellowColour}:\t\t\t Inspect a transaction's hash${endColour}"
  echo -e "\t\t${purpleColour}address${endColour}${yellowColour}:\t\t\t Inspect a transaction's address${endColour}"
  echo -e "\n\t${grayColour}[-n]${endColour}${yellowColour} Limit the number of results${endColour}${blueColour} (Example: -n 10)${endColour}"
  echo -e "\n\t${grayColour}[-i]${endColour}${yellowColour} Provide the transaction's id${endColour}${blueColour} (Example: -i ba59bdauid37843bad74)${endColour}"
  echo -e "\n\t${grayColour}[-a]${endColour}${yellowColour} Provide a transaction's address${endColour}${blueColour} (Example: -a bad9u98387932na)${endColour}"
  echo -e "\n\t${grayColour}[-h]${endColour}${yellowColour} Show the help panel${endColour}\n"

  tput cnorm; exit 1
}


# Variables globales
unconfirmed_transactions="https://www.blockchain.com/es/btc/unconfirmed-transactions"
inspect_transaction_url="https://www.blockchain.com/es/btc/tx/"
inspect_address_url="https://www.blockchain.com/es/btc/address/"

function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '/^\+/{gsub(" ", "-", $0)}1'
            fi
        fi
    fi
}

function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

function inspectAddress() {
  
  address_hash=$1
  
  echo "Transactions Made_Total Quantity Received (BTC)_Total Quantity Sent (BTC)_Total Balance in the Account (BTC)" > address.information
  
  curl -s "${inspect_address_url}${address_hash}" | html2text | grep -E "Transacciones|Total recibido|Total enviado|Saldo final" -A 2 | 
    grep -vE "Transacciones|Total recibido|Total enviado|Saldo final|\--" | head -n -2 | xargs | tr ' ' '_' | sed 's/_BTC/ BTC/g' >> address.information

  echo -ne "${grayColour}"
  printTable '_' "$(cat address.information)"
  echo -ne "${endColour}"
  
  rm address.information 2>/dev/null

  bitcoin_value=$(curl -s "https://cointelegraph.com/bitcoin-price" | html2text | grep "Last Price" | head -n 1 | awk '{print $NF}' | sed 's/\$//g;s/\,,*//g')
  
  curl -s "${inspect_address_url}${address_hash}" | html2text | grep "Transacciones" -A 2 | head -n -4 | grep -vE "Transacciones|\--" > address.information
  
  curl -s "${inspect_address_url}${address_hash}" | html2text | grep -E "Total recibido|Total enviado|Saldo final" -A 2 | 
    grep -vE "Total recibido|Total enviado|Saldo final|\--" | sed -r '/^\s*$/d' > bitcoin_to_dollars  
  
  cat bitcoin_to_dollars | while read value; do
    echo "\$$(printf "%'.d\n" $(echo "$(echo $value | awk '{print $1}')*$bitcoin_value" | bc) 2>/dev/null)" >> address.information
  done
  
  line_null=$(cat address.information | grep -n "^\$$" | awk '{print $1}' FS=":")
  
  if [ $line_null ]; then
    sed "${line_null}s/\$/0.00/" -i address.information
  fi
  
  cat address.information | xargs | tr ' ' '_' > address.information2
  rm address.information 2>/dev/null && mv address.information2 address.information
  
  sed '1iTransactions Made_Total Quantity Received (USD)_Total Quantity Sent (USD)_Total Balance in the Account (USD)' -i address.information
  
  echo -ne "${grayColour}"
  printTable '_' "$(cat address.information)"
  echo -ne "${endColour}"

  rm bitcoin_to_dollars address.information 2>/dev/null
  
  tput cnorm
}

function inspectTransaction() {
  
  inspect_transaction=$1
  
  echo "Total Input_Total Output" > total_entrada_salida.tmp

  while [ "$(cat total_entrada_salida.tmp | wc -l)" == "1" ]; do
    
    curl -s "${inspect_transaction_url}${inspect_transaction}" | html2text | grep -E "Entradas totales|Gastos totales" -A 2 | 
      grep -vE "Entradas totales|Gastos totales|\--" | sed -r '/^\s*$/d' | xargs | sed 's/ /_/g;s/_BTC/ BTC/g' >> total_entrada_salida.tmp
  done
  
  echo -ne "${grayColour}"
  printTable '_' "$(cat total_entrada_salida.tmp)"
  echo -ne ${endColour}
  
  echo "Input Addresses_Value" > entradas.tmp

  while [ "$(cat entradas.tmp | wc -l)" == "1" ]; do
    curl -s "${inspect_transaction_url}${inspect_transaction}" | html2text | grep -vE "Entradas totales|Gastos totales" | 
      grep "Entradas" -A 100 | grep "Gastos" -B 100 | grep "Direcci" -A 6 | grep -vE "Direcci|Valor|\--" | sed 's/\[//g;s/\]/ /g' | 
      sed -r '/^\s*$/d' | awk '{print $1}' | awk 'NR%2{printf "%s ",$0;next;}1' | awk '{print $1 "_" $2 " BTC"}' >> entradas.tmp
  done
  
  echo -ne "${greenColour}"
  printTable '_' "$(cat entradas.tmp)"
  echo -ne "${endColour}"
  
  echo "Output Addresses_Value" > salidas.tmp

  while [ "$(cat salidas.tmp | wc -l)" == "1" ]; do
    curl -s "${inspect_transaction_url}${inspect_transaction}" | html2text | grep -v "Gastos totales" | 
      grep "Gastos" -A 100 | grep "Ya lo has pensado" -B 100 | grep "Direcci" -A 6 | grep -vE "Direcci|Valor|\--" | sed 's/\[//g;s/\]/ /g' | 
      sed -r '/^\s*$/d' | awk '{print $1}' | awk 'NR%2{printf "%s ",$0;next;}1' | awk '{print $1 "_" $2 " BTC"}' >> salidas.tmp
  done
  
  echo -ne "${greenColour}"
  printTable '_' "$(cat salidas.tmp)"
  echo -ne "${endColour}"

  rm salidas.tmp entradas.tmp total_entrada_salida.tmp 2>/dev/null

  tput cnorm
}

function unconfirmedTransactions() {
 
  number_output=$1
  echo '' > ut.tmp

  while [ "$(cat ut.tmp | wc -l)" == "1" ]; do
    curl -s "$unconfirmed_transactions" | html2text > ut.tmp
  done

  hashes=$(cat ut.tmp | grep "Hash" -A 2 | grep -vE "Hash|\--" | sed -r '/^\s*$/d' | sed 's/\[//g;s/\]/ /g;s/Tiempo//g' | awk '{print $1}' | head -n $number_output)
  
  echo "Hash_Quantity_Bitcoin_Time" > ut.table

  for hash in $hashes; do
    echo "${hash}_\$$(cat ut.tmp | grep $hash -A 12 | tail -n 1 | sed 's/ US\$//g')_$(cat ut.tmp | grep $hash -A 8 | 
      tail -n 1)_$(cat ut.tmp | grep $hash -A 4 | tail -n 1)" >> ut.table  
  done

  cat ut.table | tr '_' ' ' | awk '{print $2}' | grep -v "Quantity" | sed 's/\$//g;s/,,*/ /g;s/\.*//g' | awk '{print $1}' > money
  
  money=0; cat money | while read money_in_line; do
    let money+=$money_in_line
    echo $money > money.tmp
  done;
  
  echo -n "Total amount_" > amount.table
  echo "\$$(printf "%'d\n" $(cat money.tmp))" >> amount.table

  if [ "$(cat ut.table) | wc -l)" != "1" ]; then
    echo -ne "${yellowColour}"
    printTable '_' "$(cat ut.table)"
    echo -ne "${endColour}"
    echo -ne "${blueColour}"
    printTable '_' "$(cat amount.table)"
    echo -ne "${endColour}"
    
    rm ut.* money* amount.table 2>/dev/null 

    tput cnorm; exit 0
  else   
    rm ut.t* 2>/dev/null
  fi

  rm ut.* money* amount.table 2>/dev/null
  tput cnorm
}

parameter_counter=0; while getopts ":e:n:i:a:h:" arg; do
  case $arg in
    e) exploration_mode=$OPTARG; let parameter_counter+=1;;
    n) number_output=$OPTARG; let parameter_counter+=1;;
    i) inspect_transaction=$OPTARG; let parameter_counter+=1;;
    a) inspect_address=$OPTARG; let parameter_counter+=1;;
    h) helpPanel;;
  esac  
done

tput civis

if [ $parameter_counter -eq 0 ]; then
  helpPanel
else
  if [ "$(echo $exploration_mode)" == "unconfirmed_transactions" ]; then
    
    if [ ! "$number_output" ]; then
      number_output=100
    fi  
    
    unconfirmedTransactions $number_output

  elif [ "$(echo $exploration_mode)" == "inspect" ]; then
    inspectTransaction $inspect_transaction

  elif [ "$(echo $exploration_mode)" == "address" ]; then
    inspectAddress $inspect_address
  fi
fi
