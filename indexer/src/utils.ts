export const nodeURL = `http://127.0.0.1:8545`;

export async function getBlock(number: number) {
  const response = await fetch(nodeURL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getBlockByNumber",
      params: [`0x${number.toString(16)}`, true],
    }),
  });

  const data = await response.json();
  return data.result;
}

export async function getBlockReceipts(number: number) {
  const response = await fetch(nodeURL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      jsonrpc: "2.0",
      id: 1,
      method: "eth_getBlockReceipts",
      params: [`0x${number.toString(16)}`],
    }),
  });

  const data = await response.json();
  return data.result;
}

