FROM python:3.12-slim

WORKDIR /opt/app

COPY ./python/requirements.txt requirements.txt

RUN pip install --no-cache-dir uv
RUN uv pip install --system --no-cache-dir --upgrade -r requirements.txt

RUN mkdir -p /opt/app/src
COPY ./python/src /opt/app/src/

ENV PYTHONPATH=/opt/app

CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8888"]