# haiko_agent

This is your Scarb Agent project.
Scarb Agent allows you to build provable programs that interacts with custom oracles.

## Prerequisites

- `protoc` from [here](https://grpc.io/docs/protoc-installation/)
- `scarb` from [here](https://github.com/software-mansion/scarb/releases)

## Usage

1. Start the agent server:
   ```
   cd python
   python3 -m venv .venv
   source .venv/bin/activate
   pip install -r requirements.txt
   python src/main.py
   ```

2. Run the Scarb agent:
   ```
   scarb agent-run --args '{"n": 9}'
   ```

## Preprocessing

To run preprocessing:
1. Ensure the Python server is running.
2. Use the `--preprocess` flag when running the Scarb agent:
   ```
   scarb agent-run --preprocess --args '{"n": 9}'
   ```

## Postprocessing

To run postprocessing:
1. Ensure the Python server is running.
2. Use the `--postprocess` flag when running the Scarb agent:
   ```
   scarb agent-run --postprocess --args '{"n": 9}'
   ```


