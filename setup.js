#!node

const shell = require('shelljs');
shell.config.verbose = true;
const fs = require('fs');
const { execSync } = require('child_process');

const pwd = process.cwd();
const range = (n) => [...Array(n)].map((_, i) => i);

const nodeTypes = ['cn', 'bn', 'rn'];

const NODE_COUNT = 2;
const REGISTRY = "asia.gcr.io/deep-rainfall-236010";
const ISTANBUL = `docker run --rm -v ${pwd}/tmp:/tmp ${REGISTRY}/klaytn /istanbul`;
const KLAYTN = `docker run --rm -v ${pwd}/tmp:/tmp -v ${pwd}/output:/output ${REGISTRY}/klaytn /klay`;



shell.rm('-rf', `./tmp`);
shell.rm('-rf', `./output`);


shell.echo('Run istanbul to create data directories for each type of nodes');
nodeTypes.forEach(nodeType => {
  const cmd = `${ISTANBUL} setup --num ${NODE_COUNT} -o /tmp/${nodeType} --unitPrice 0 remote`;
  const output = execSync(cmd).toString();
  console.log(output);
});

const nodeConfigs = require('./nodeConfigs');

shell.echo('Edit static-nodes');
nodeTypes.forEach(nodeType => {
  const jsonPath = `./tmp/${nodeType}/scripts/static-nodes.json`;
  const staticNodes = JSON.parse(shell.cat(jsonPath).toString()).map((enode, nodeNum) => {
    const nodeConfig = nodeConfigs[nodeNum];
    return enode
      .replace(/0\.0\.0\.0/, nodeConfig.host)
      .replace(/32323/, nodeConfig.ports[nodeType].p2p)
  });
  new shell.ShellString(JSON.stringify(staticNodes, undefined, 2))
    .to(jsonPath);
});


const createNodeDir = (n) => `output/node${(n + 1)}`;
const createNodeDataDir = (n, nodeType) => `${createNodeDir(n)}/${nodeType}`;
shell.mkdir('output');

console.log('###### Copy genesis and static nodes and copy nodekeys');
const mainNodeType = nodeTypes[0];
const genesisPath = `./tmp/${mainNodeType}/scripts/genesis.json`;

range(NODE_COUNT).forEach(n => {
  nodeTypes.forEach(nodeType => {
    const nodeDataDir = createNodeDataDir(n, nodeType);
    shell.mkdir('-p', nodeDataDir);
    shell.mkdir('-p', nodeDataDir + '/klay');
    shell.cp(genesisPath, `${nodeDataDir}/genesis.json`);

    const targetNodeType = nodeType === nodeTypes[2] ? nodeTypes[1] : nodeTypes[0];

    shell.cp(`./tmp/${targetNodeType}/scripts/static-nodes.json`, `${nodeDataDir}/static-nodes.json`);
    shell.cp(`./tmp/${nodeType}/keys/nodekey${n + 1}`, `${nodeDataDir}/klay/nodekey`);
    shell.cp(`./tmp/${nodeType}/keys/validator${n + 1}`, `${nodeDataDir}/klay/validator`);
  });
});

console.log('###### Init genesis.json');

range(NODE_COUNT).forEach(n => {
  nodeTypes.forEach(nodeType => {
    const nodeDataDir = createNodeDataDir(n, nodeType);
    const cmd = `${KLAYTN} --datadir ${nodeDataDir} init ${nodeDataDir + '/genesis.json'}`;
    console.log(execSync(cmd).toString());
  });
});

console.log('###### Create running scripts for each node');

range(NODE_COUNT).forEach(nodeNum => {
  const nodeConfig = nodeConfigs[nodeNum];

  const nodeDir = createNodeDir(nodeNum);
  shell.mkdir(nodeDir);

  const scriptPath = `${nodeDir}/docker-compose.yml`;
  shell.cat('./_docker-compose.yml').sed('{subnet}', `172.${24 + nodeNum}.0.0`).to(scriptPath);

  const serviceTemplate = shell.cat('./_compose_service.yml').toString();

  nodeTypes.forEach(nodeType => {
    const serviceDescription = serviceTemplate
      .replace(/{node_type}/g, nodeType)
      .replace(/{data_dir}/g, nodeType) // same with type
      .replace(/{port}/g, nodeConfig.ports[nodeType].p2p)
      .replace(/{ws_port}/g, nodeConfig.ports[nodeType].ws)
      .replace(/{rpc_port}/g, nodeConfig.ports[nodeType].rpc);
    new shell.ShellString(serviceDescription).toEnd(scriptPath);
  });
});

