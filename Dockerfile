FROM python:3-alpine
RUN pip install flask
RUN pip install requests

WORKDIR /src
COPY ./src /src/

CMD ["python", "app.py"]
