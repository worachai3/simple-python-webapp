FROM python:alpine3.10

WORKDIR /app
COPY requirements.txt /app/requirements.txt
RUN pip install -r requirements.txt
EXPOSE 5000
COPY . /app/

CMD [ "flask", "run", "--host", "0.0.0.0", --port, "5000"]