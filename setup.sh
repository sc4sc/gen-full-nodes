#!/bin/bash
NODE_COUNT=4


KLAYHOME=.
REGISTRY=asia.gcr.io/deep-rainfall-236010
ISTANBUL="docker run --rm -v $(pwd)/tmp:/tmp $REGISTRY/klaytn /istanbul"
KLAYTN="docker run --rm -v $(pwd)/tmp:/tmp -v $(pwd)/output:/output $REGISTRY/klaytn /klay"

rm -rf $KLAYHOME/tmp
rm -rf $KLAYHOME/output

$ISTANBUL setup --num $NODE_COUNT -o /tmp/cn --unitPrice 0 remote
$ISTANBUL setup --num $NODE_COUNT -o /tmp/bn --unitPrice 0 remote
$ISTANBUL setup --num $NODE_COUNT -o /tmp/rn --unitPrice 0 remote

function update_node_list {

    local HOSTNAME=$1
    local PORT=$2
    local file_name=$3
    local node_num=$4

    local line_num=$(( $node_num + 1 ))
    
    echo Updating node list for the line $line_num of file $file_name


    # This script should be portable to POSIX and GNU
    script="
        # Set HOSTNAME:PORT to the ith line of static-nodes.json
        $(($line_num))s/0\.0\.0\.0:[[:digit:]]+/$HOSTNAME:$PORT/
    "
    # echo $script
    content=`sed -E -e "$script" $file_name`
    echo "$content" > $file_name
    # echo "$content"
}

function create_run_script {

    local node_type=$1
    local P2P=$2
    local WS=$3
    local RPC=$4
    local OUTPUT_FILE=$5

    sed -E -e "
        s/{node_type}/$node_type/g
        s/{data_dir}/$node_type/g
        s/{port}/$P2P/g
        s/{ws_port}/$WS/g
        s/{rpc_port}/$RPC/g  
    " ./_run.sh >> $OUTPUT_FILE
    chmod +x $OUTPUT_FILE
}

# update static-nodes & create scripts
# create genesis block data and copy nodekey
declare -a node_types=("cn" "bn" "rn")

mkdir -p output
echo "cwd=\$(pwd)" > output/run_all.sh
chmod +x output/run_all.sh

for (( i=1; i<=$NODE_COUNT; i++ ))
do
    
    setting_file="envs/node$i.env"
    source $setting_file

    NODE_DIR=output/node$i
    mkdir -p $NODE_DIR

    echo >> output/run_all.sh
    echo "# Node $i" >> output/run_all.sh
    echo "cd \$cwd/node$i" >> output/run_all.sh
    echo "./run_all.sh" >> output/run_all.sh
    echo "cd ../" >> output/run_all.sh
    
    echo "# Run all the nodes in the same host" > $NODE_DIR/run_all.sh
    cp docker-compose.yml $NODE_DIR/docker-compose.yml
    chmod +x $NODE_DIR/run_all.sh
    for node_type in ${node_types[@]}
    do

        echo "./run_$node_type.sh &" >> $NODE_DIR/run_all.sh
        
        uppercase=$(echo $node_type | tr a-z A-Z)
        P2P=$(eval echo \$"$uppercase"_P2P)
        WS=$(eval echo \$"$uppercase"_WS)
        RPC=$(eval echo \$"$uppercase"_RPC)
        
        update_node_list $HOSTNAME $P2P "./tmp/$node_type/scripts/static-nodes.json" $i
        
        create_run_script $node_type $P2P $WS $RPC "./$NODE_DIR/docker-compose.yml"

        $KLAYTN --datadir /$NODE_DIR/$node_type init /tmp/$node_type/scripts/genesis.json
        cp ./tmp/$node_type/keys/nodekey$i $NODE_DIR/$node_type/klay/nodekey
    done
    

done

# populate with node data
for (( i=1; i<=$NODE_COUNT; i++ ))
do
    NODE_DIR=output/node$i
    
    mkdir -p $NODE_DIR/cn/klay
    cp ./tmp/cn/scripts/static-nodes.json $NODE_DIR/cn/static-nodes.json


    mkdir -p $NODE_DIR/bn/klay
    cp ./tmp/cn/scripts/static-nodes.json $NODE_DIR/bn/static-nodes.json
    cp ./tmp/bn/keys/nodekey$i $NODE_DIR/bn/klay/nodekey

    mkdir -p $NODE_DIR/rn/klay
    cp ./tmp/bn/scripts/static-nodes.json $NODE_DIR/rn/static-nodes.json
    cp ./tmp/rn/keys/nodekey$i $NODE_DIR/rn/klay/nodekey

done

# TODO::
# 1. Domain 혹은 IP를 static-nodes.json에 자동으로 설정해주는 것?
# 2. 실행 스크립트 생성




# # horrible hack
# sed -i "0,/$DEFAULT_P2P/{s/$DEFAULT_P2P/$CNB_P2P/}" $KLAYHOME/cn/scripts/static-nodes.json
# sed -i "0,/$DEFAULT_P2P/{s/$DEFAULT_P2P/$BN_P2P/}"  $KLAYHOME/bn/scripts/static-nodes.json
# sed -i "0,/$DEAFULT_P2P/{s/$DEAFULT_P2P/$RN_P2P/}"  $KLAYHOME/rn/scripts/static-nodes.json

# mkdir -p $KLAYHOME/cn/dataa/klay
# mkdir -p $KLAYHOME/cn/datab/klay
# mkdir -p $KLAYHOME/bn/data/klay
# mkdir -p $KLAYHOME/rn/data/klay

# cp $KLAYHOME/cn/scripts/genesis.json $KLAYHOME/bn/scripts/static-nodes.json $KLAYHOME/rn/data
# cp $KLAYHOME/cn/scripts/* $KLAYHOME/bn/data
# cp $KLAYHOME/cn/scripts/* $KLAYHOME/cn/dataa
# cp $KLAYHOME/cn/scripts/* $KLAYHOME/cn/datab

# cp $KLAYHOME/cn/keys/nodekey1 $KLAYHOME/cn/datab/klay/nodekey
# cp $KLAYHOME/cn/keys/nodekey2 $KLAYHOME/cn/dataa/klay/nodekey
# cp $KLAYHOME/bn/keys/nodekey1 $KLAYHOME/bn/data/klay/nodekey
# cp $KLAYHOME/rn/keys/nodekey1 $KLAYHOME/rn/data/klay/nodekey

# $KLAYHOME/klay --datadir $KLAYHOME/cn/dataa init $KLAYHOME/cn/dataa/genesis.json
# $KLAYHOME/klay --datadir $KLAYHOME/cn/datab init $KLAYHOME/cn/datab/genesis.json
# $KLAYHOME/klay --datadir $KLAYHOME/bn/data init $KLAYHOME/bn/data/genesis.json
# $KLAYHOME/klay --datadir $KLAYHOME/rn/data init $KLAYHOME/rn/data/genesis.json

# cp $KLAYHOME/keystore/UTC--2018-12-27T08-46-14.110806953Z--281cf8d3ea50c4ec654fada79a4080ff4fa20858 $KLAYHOME/rn/data/keystore/

# GEN=$KLAYHOME/gen.sh

# echo "===================================================================================\n"
# echo " Generating runner scripts"
# echo "===================================================================================\n"

# $GEN $KLAYHOME cn $KLAYHOME/cn/dataa $CNA_WS $CNA_RPC $CNA_P2P cna
# $GEN $KLAYHOME cn $KLAYHOME/cn/datab $CNB_WS $CNB_RPC $CNB_P2P cnb
# $GEN $KLAYHOME bn $KLAYHOME/bn/data $BN_WS $BN_RPC $BN_P2P bn
# $GEN $KLAYHOME rn $KLAYHOME/rn/data $RN_WS $RN_RPC $RN_P2P rn

# echo "===================================================================================\n"
# echo " [Setup completed]\n"
# echo " - The account 281cf8d3ea50c4ec654fada79a4080ff4fa20858 has been funded"
# echo " \tPassword is 'test'"
# echo " - Ports are (formatted as P2P/RPC/WS)"
# echo " \tCN A: $CNA_P2P/$CNA_RPC/$CNA_WS"
# echo " \tCN B: $CNB_P2P/$CNB_RPC/$CNB_WS"
# echo " \tBN  : $BN_P2P/$BN_RPC/$BN_WS"
# echo " \tRN  : $RN_P2P/$RN_RPC/$RN_WS"
# echo "===================================================================================\n"

