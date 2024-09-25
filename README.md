# Token Terminal Blockchain indexing task

In this task, you will implement a simplified version of the Token Terminal ELT process.
This assignment assumes some knowledge of the blockchain but no in-depth knowledge of the scaped data is required.

We ask you to keep the code readable, and add comments where relevant. If you make any assumptions, please note those at the comments.

We don't expect you to use more than 2-3h of active time. This task requires a ~50GB file download, so please do it before starting to work on it.


You can keep the solutions as naive as possible and it's ok if you don't have the time to complete the full task. We know it's a bit intense.

## Goals:

1. Build a dataset in our data warehouse, where we have two tables:
    1. blocks
    2. transactions

2. Analytics
    1. Contract metrics

## Steps:

1. Set up a blockchain node
2. Implement a light weight naive indexer to extract the raw data from the chain
3. Load the data into data warehouse
4. Implement the data model and a Trending contracts dataset.

#### SQL Style guide

For the SQL styleguide, we ask to keep the following key points in mind when writing the SQL.

1. Keep the SQL readable. Avoid short tablenames, acronyms,
    * Don't do `from raw.blocks as b` but use `blocks` as the table name
2. Use CTEs over subqueries. CTEs keep the SQL readable, only use subqueries when must (hint there isn't a need)
3. We use dbt to manage dependencies, to avoid scope creep we don't install and setup dbt here.
    * Save the couple of SQL queries as tables, or create the required views and tables manually
    * Use e.g. numbers in the filenames to describe the file dependencies. E.g. `0001_init_tables.sql` `0002_blocks.sql` and so on.

#### System requirements

* Linux or mac. This has not been tested on windows but it might still work
* Docker, we assume you have this installed already.
* Nodejs/typescript, you can use nvm or brew install
* Clickhouse: no install required, see below the singe step to get the binary.


### 1. Running the blockchain node

For this task we'll setup and run Linea Sepolia node. The node is a generic `geth` node (geth is a classic evm node client) and their testnet sepolia is nice and small.
This allows us to dive into the data quickly with out massive disk space requirements.

For this task, you should have ~200GB of free disk space.

In this repo, we have provided a ready made `docker-compose` file for running the node. In real life, this is rarely the case. However the goal is not to test your ability to google arbitrary configuration flags.


#### Setting up the node from archival snapshot

To speed up the setup time, we provice a ready to use archival snapshot of the Linea sepolia node. The file is 64GB so downloading and extracting it may take a moment.

For the fastest download, use the provided command, and install aria2 (`apt install aria2`)

```
aria2c -s14 -x14 -k100M https://storage.googleapis.com/tt-blockchain-homework-eu/linea-sepolia.tar.xz
```

You may also just `curl https://storage.googleapis.com/tt-blockchain-homework-eu/linea-sepolia.tar.xz -o linea-sepolia.tar.xz` the file.

Assuming you downloaded the file to the repo root, use the following command to extract it into the right location:

```
tar xvf linea-sepolia.tar.xz -C linea
```

The files should go to `./linea/linea-sepolia/geth/`

```
ls -la linea/linea-sepolia/geth
total 4162
drwx------ 6 root root    10 Sep 24 07:55 .
drwxr-xr-x 4 root root     4 Sep 24 08:13 ..
drwx------ 4 root root     4 Sep 21 10:55 blobpool
drwxr-xr-x 3 root root 35691 Sep 22 17:19 chaindata
-rw------- 1 root root    66 Sep 21 10:55 jwtsecret
drwxr-xr-x 3 root root     8 Sep 21 10:55 lightchaindata
-rw------- 1 root root     0 Sep 21 10:55 LOCK
-rw------- 1 root root    64 Sep 21 10:55 nodekey
drwxr-xr-x 2 root root     8 Sep 24 07:59 nodes
-rw-r--r-- 1 root root     0 Sep 24 07:55 transactions.rlp
```

The linea-sepolia folder will be mounted to the docker container.


#### Setting up the node

With the archival snapshow downloaded and extracted, you may start the node.

To do it, go to `./linea` and use `docker compose up -d`.

Use `docker logs linea-node-1` to view the logs. Once the node logs `Imported new chain segment` it should be catching up and ready to query.
You don't need to wait for the node to catch up to the latest block, instead we are ok to query the data that is already present in the archival snapshot.


To see the latest availanle block, you may use the following query:

```
curl 127.0.0.1:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0", "method": "eth_getBlockByNumber", "params": ["latest", false], "id": "x"}' | jq .
```

And to get the block number in plain text:

```
curl 127.0.0.1:8545 -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0", "method": "eth_getBlockByNumber", "params": ["latest", false], "id": "x"}' | jq .result.number -r | xargs printf "%d\n"
```

At the time of updating this task, the latest block is 3 851 490.


For more information on how to run Linea, see their docs: https://docs.linea.build/developers/guides/run-a-node/use-docker. Note we are using `geth` client in this task.


### 2. Implementing the indexer

In the second phase of the task we get more hands on writing code. Our goal is to extract blockchain data and prepare it to be loaded to our data warehouse.
We use the [JSON RPC API](https://openethereum.github.io/JSONRPC-eth-module) provided by the blockchain node to index the data.

Implement a program that takes `START` and `COUNT` parameters from env, and scrapes the range from `START` to `START+COUNT` and produces one or many files to be loaded to clickhouse. There are multiple valid file formats that we can use, for simplicity I recommend json-newline.

This repository contains some convenience functions and example schemas to allow you to focus.
We've included some convenience functions to the repo to help interact with the chain.

With the ELT mindset in mind, we don't want to apply excessive transformatins while loading the data. The are TWO transformations makes life easier, however. The rest should happen at the data warehouse.
* Add human readable blockNumber and blockTimestamp to all data we save on disk. This helps with partitioning and joins. And makes debugging easier.
* Extract transactions to it's own file for simplicity. It's also ok to unnest it later on.


For this task, it's enough to scrape the blocks between 2125000 and 2314500.


Here are the relevant JSON RPC methods and links to their documentation. You might not need to view the docs pages to be successful with this task.
* blocks
    * `eth_getBlockByNumber`
    * [Docs](https://openethereum.github.io/JSONRPC-eth-module#eth_getblockbynumber)
    * Note this can also return the full transaction data, set the second parameter to true
    * We did this particular query to test if the node is up
* transactionReceipts
    * `eth_getBlockReceipts`
    * [Docs](https://www.quicknode.com/docs/ethereum/eth_getBlockReceipts)
    * This returns transaction receipts. We need to link these to transactions for the analytics needs. To follow the ELT workflow

Tips:
* To keep this workflow easy, you should write the files under the clickhouse `user_files` folder: `db/user_files`.

### 3. Loading the data into clickhouse

#### Setting up Clickhouse locally

This couldn't be easier. And this is why we use clickhouse in this task.

Run the clickhouse related commands in the `./db` folder.

Get the latest binary:
```
curl https://clickhouse.com/ | sh
```

And start up the clickhouse local server:

```
./clickhouse server
```

Leave this running in it's own tab. (or tmux pane)


#### Test the clickhouse cli connection

`./clickhouse client`

#### Load data

To save data, below is provided example queries to create the blocks, transactions, transactionReceipts tables.

See tables.sql for examples of the schema and import queries.
These assume you have saved the data with similar modifications, so there is a chance you need to make minor edits.

You can use clickhouse to infer the schema from the files: e.g., `describe table file('./blocks_*') FORMAT JSONCompactEachRow;`
Note: The path for `file` is relative to the `./db/user_files`


### 4. Analytics


#### Trending Contracts Metrics

In the final task, we implement a simple Trending Contracts dataset.

Implememt 3 time series metrics for all contracts.

1. gas_used_daily
    * timestamp -- at daily granularity
    * contract_address -- to address from transactions
    * gas_used

2. active_addresses_daily
    * timestamp -- at daily granularity
    * contract_address -- to address from transactions
    * active_addresses_count -- distinct count of addresses transacting with the contract address

3. transactions_count_daily
    * timestamp -- at daily granularity
    * contract_address -- to address from transactions
    * transactions_count -- number of transactions sent to this address


