module.exports = [
  {
    host: '172.24.0.1',
    ports: {
      cn: {
        p2p: 32300,
        ws: 8500,
        rpc: 8600
      },
      bn: {
        p2p: 32310,
        ws: 8510,
        rpc: 8610
      },
      rn: {
        p2p: 32320,
        ws: 8520,
        rpc: 8620
      },
    }
  },
  {
    host: '172.25.0.1',
    ports: {
      cn: {
        p2p: 32301,
        ws: 8501,
        rpc: 8601
      },
      bn: {
        p2p: 32311,
        ws: 8511,
        rpc: 8611
      },
      rn: {
        p2p: 32321,
        ws: 8521,
        rpc: 8621
      },
    }
  }
];
