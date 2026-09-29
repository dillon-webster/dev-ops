# It works on my machine. Ship it.
FROM python:3.12

COPY . /app
WORKDIR /app

RUN pip install -r requirements.txt

ENV API_KEY=sk-live-supersecret123
ENV REDIS_HOST=localhost

EXPOSE 5000
CMD python app.py
