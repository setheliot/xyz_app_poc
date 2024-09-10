FROM python:3-alpine
RUN pip install flask

WORKDIR /src
COPY ./src /src/

CMD ["python", "app.py"]
