
import math
from fastapi import FastAPI, Request, HTTPException
from pydantic import BaseModel
import json

app = FastAPI()

@app.get("/healthcheck")
def read_root():
    """
    Health check endpoint to ensure the API is up and running.
    Returns a simple JSON response indicating the API status.
    """
    return {"status": "OK"}

# ========== Preprocessing ==========
# This endpoint handles preprocessing of data before executing a Cairo program.
# It formats and prepares the input data, making it ready for the Cairo main function.
@app.post("/preprocess")
async def preprocess(request: Request):
    """
    Receives JSON data, processes it, and returns the modified data
    as arguments for a Cairo main function.
    """
    data = await request.json()
    # Insert custom preprocessing logic here
    processed_data = {"n": data["n"]}
    return {"args": json.dumps(processed_data)}

# ========== Postprocessing ==========
# This endpoint handles postprocessing of data after a Cairo program execution.
# It allows further manipulation or interpretation of the Cairo output.
@app.post("/postprocess")
async def postprocess(request: Request):
    """
    Receives JSON data as the output of a Cairo main function, processes it,
    and returns the modified result.
    """
    data = await request.json()
    # Insert custom postprocessing logic here
    processed_data = {"processed": data}
    return processed_data

if __name__ == "__main__":
    import uvicorn

    # Configures and runs the API server on host 0.0.0.0 at port 3000 with auto-reload enabled.
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)
