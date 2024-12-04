# Haiko Agent

This agent for Haiko classifies market states as Up, Down, or Neutral, supporting liquidity strategies on the integrated AMM.

## Deployment URL

Access the Haiko Agent at url [https://haiko-agent-132737210721.europe-west1.run.app](https://haiko-agent-132737210721.europe-west1.run.app)

## Using the Agent

Interact with the agent by sending JSON payloads via HTTP POST request:

```shell
curl -X POST "https://haiko-agent-132737210721.europe-west1.run.app/agent_run" \
     -H "Content-Type: application/json" \
     -d '{"dry_run": true, "preprocess": true, "postprocess": true, "preprocess_body": {"days": 7}}'
```

**Parameters**:

- `dry_run`: Runs in non-provable mode without generating proofs (boolean).
- `preprocess` and `postprocess`: Should always be set to true.
- `preprocess_body`: JSON object specifying the time window in days.

**Response Structure**
The response includes the trend result and a request ID:

```json
{
  "results": { "trend": "Up" },
  "request_id": "mock-or-actual-request-id"
}
```

## Tracking Proving Jobs

For provable operations (`dry_run: false`), track proving jobs with this command:

```shell
curl -X GET "https://atlantic.api.herodotus.cloud/v1/atlantic-query-jobs/{request_id}" \
     -H "accept: application/json"
```

**Job Status Response**
An example job status response:

```json
{
  "jobs": [
    {
      "id": "5f9c3054-147b-4934-843d-16089a5854ff",
      "sharpQueryId": "01JDHZKM93D95KWP1M3NEAKFRZ",
      "status": "COMPLETED",
      "jobName": "PROOF_GENERATION",
      "createdAt": "2024-11-25T15:38:57.473Z",
      "completedAt": "2024-11-25T16:27:39.706Z",
      "context": {
        "proofPath": "sharp_queries/query_01JDHZKM93D95KWP1M3NEAKFRZ/proof.json"
      }
    },
    {
      "id": "1f673cb0-2e1a-4f7f-b3ea-96fbba080e16",
      "sharpQueryId": "01JDHZKM93D95KWP1M3NEAKFRZ",
      "status": "COMPLETED",
      "jobName": "FACT_HASH_GENERATION",
      "createdAt": "2024-11-25T16:27:39.753Z",
      "completedAt": "2024-11-25T16:38:23.275Z",
      "context": {
        "child_program_hash": "0x52cc953e5126d45ce2e22500645783601a26a895b023e4467bdb05848bb3c2d",
        "child_output": [
          "0x0",
          "0x8"
        ],
        "bootloader_output": [
          "0x1"
        ],
        "bootloader_output_hash": "0x753d2a6b08233b560739cb9cb027f05efea90e822a8bb65403acceb55dce739",
        "bootloader_program_hash": "0x5ab580b04e3532b6b18f81cfa654a05e29dd8e2352d88df1e765a84072db07",
        "fact_hash": "0x3d2f9dae7f9d5fca7a7d8218e77db2ed418c5a361e6fe1bf650b930c112a29c"
      }
    },
    {
      "id": "2317d613-bcfa-4734-a7ca-14726a6d53a1",
      "sharpQueryId": "01JDHZKM93D95KWP1M3NEAKFRZ",
      "status": "COMPLETED",
      "jobName": "PROOF_VERIFICATION",
      "createdAt": "2024-11-25T16:38:23.304Z",
      "completedAt": "2024-11-25T16:48:02.094Z",
      "context": {
        "numberOfSteps": 33554432,
        "hasher": "keccak_160_lsb",
        "initial": {
          "transactionHash": "0x34d8c5745831738df7a55d051e054bb233db30f9ea6624c41747b6c7487e2e6",
          "price": 0.63,
          "gasAmount": 8815
        },
        "final": {
          "transactionHash": "0x2bd32630d13e05460980d43087e27ab124f11cef6b1a231e074960d843a032d",
          "price": 0.02,
          "gasAmount": 205
        }
      }
    }
  ],
  "steps": [
    "PROOF_GENERATION",
    "FACT_HASH_GENERATION",
    "PROOF_VERIFICATION"
  ]
}
```

## Accessing On-Chain Verification

The `PROOF_VERIFICATION` job handles the on-chain verification of the proof. Within the context of this job:

- initial.transactionHash: The transaction hash at the start of verification.
- final.transactionHash: The final transaction hash responsible for on-chain verification. To view the final on-chain verification transaction, visit:
  🔗 https://sepolia.starkscan.co/tx/{transactionHash}

Replace {`transactionHash`} with the actual final.transactionHash from the response.

## Local Development

If you want to develop or modify the project locally, you'll need to install the following:

- `protoc` from [this link](https://grpc.io/docs/protoc-installation/).
- `scarb 2.7.0` from [this link](https://github.com/software-mansion/scarb/releases).
- Scarb Agent from [this link](https://github.com/gizatechxyz/scarb-agent).
- `Python 3.12+`.

Then follow these steps:

1. Create and activate a Python virtual environment:
   ```bash
   cd python
   python -m venv env
   source env/bin/activate
   ```

2. Install project dependencies:

```bash
pip install -r requirements.txt
```

3. Run the FastAPI application locally:

```bash
uvicorn src.main:app --host 0.0.0.0 --port 3000 --workers 4
```

4. To process inference, use the /run endpoint:

```bash
scarb agent-run --args '{"days": 7}' --preprocess --postprocess
```