  {node_type}: 
    image: asia.gcr.io/deep-rainfall-236010/klaytn
    volumes:
      - ./{node_type}:/data/{node_type}
    ports: 
      - "{rpc_port}:{rpc_port}"
      - "{port}:{port}"
      - "{ws_port}:{ws_port}"
    command: './klay --nodetype {node_type} --mine --srvtype http --dbtype leveldb --verbosity 3 --txpool.accountslots 20000 --txpool.accountqueue 20000 --txpool.globalslots 40960 --txpool.globalqueue 40960 --networkid 2018 --nodiscover --wsorigins "*" --datadir /data/{node_type} --syncmode full --rpc --rpcapi admin,txpool,personal,klay,debug,net,web3 --ws --wsaddr 0.0.0.0 --wsport {ws_port} --rpcaddr 0.0.0.0 --rpccorsdomain "*" --rpcvhosts "*" --maxpeers 5000 --rpcport {rpc_port} --port {port} --gasprice 0'