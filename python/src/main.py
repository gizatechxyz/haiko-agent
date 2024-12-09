from typing import Optional
from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel, Field
import json
import requests
from datetime import datetime

app = FastAPI()

class RunInput(BaseModel):
    days: int = Field(..., gt=0, description="Number of days, must be positive")
    lookback: int = Field(..., gt=0, description="Lookback period, must be positive")

class CairoRunResult(BaseModel):
    result: str
    request_id: Optional[str] = None

def fetch_eth_prices(days: int):
    url = "https://api.coingecko.com/api/v3/coins/ethereum/market_chart"
    params = {"vs_currency": "usd", "days": days}
    try:
        response = requests.get(url, params=params)
        response.raise_for_status()
        data = response.json()
        if "prices" not in data:
            raise ValueError("The 'prices' key is missing in the API response.")
        return data["prices"]
    except requests.RequestException as e:
        raise HTTPException(
            status_code=500, detail=f"Error fetching ETH prices: {str(e)}"
        )
    except ValueError as ve:
        raise HTTPException(status_code=500, detail=str(ve))

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
async def preprocess(request: RunInput):
    try:
        prices = fetch_eth_prices(days=request.days)

        eth_usdc_prices = []
        for price_point in prices:
            _, price_usd = price_point
            price_usdc = price_usd
            eth_usdc_prices.append(price_usdc)

        return {"args": json.dumps({"prices": eth_usdc_prices, "lookback": request.lookback})}
    except HTTPException as e:
        raise e
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Unexpected error: {str(e)}")

# ========== Postprocessing ==========
# This endpoint handles postprocessing of data after a Cairo program execution.
# It allows further manipulation or interpretation of the Cairo output.
@app.post("/postprocess")
async def postprocess(request: CairoRunResult):
    """
    Receives JSON data as the output of a Cairo main function, processes it,
    and returns the modified result.
    """

    try:
        analysis = json.loads(request.result)["analysis"]
        analysis = {
            "trend": trend_num_to_string(analysis["trend"]),
            "vol_limit": analysis["vol_limit"],
        }
        return json.dumps({"results": analysis, "request_id": request.request_id})
    except json.JSONDecodeError:
        raise HTTPException(
            status_code=500,
            detail="Invalid JSON format in result"
        )
    except KeyError:
        raise HTTPException(
            status_code=500,
            detail="Missing required fields in result"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Error processing result: {str(e)}"
        )

def trend_num_to_string(num: int):
    if num == 0:
        return "Up"
    elif num == 1:
        return "Down"
    elif num == 2:
        return "Neutral"
    else:
        raise ValueError("Unknown trend value")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="0.0.0.0", port=3000, reload=True)