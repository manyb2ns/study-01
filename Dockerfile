FROM ubuntu:22.04

RUN apt-get update && apt-get install -y python3 python3-pip wget curl
RUN pip install flask==3.0.*

COPY app.py .

EXPOSE 5000
CMD ["flask", "run", "--host", "0.0.0.0", "--port", "5000"]
