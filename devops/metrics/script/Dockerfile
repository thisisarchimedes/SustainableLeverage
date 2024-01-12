# Use an official Python runtime as a parent image
FROM python:3.12

# Set the working directory in the container to /app
WORKDIR /app

RUN mkdir /app/src
RUN mkdir /app/src/event_processor

COPY requirements.txt /app/
COPY .env /app/

COPY src/event_processor/* /app/src/event_processor/
COPY src/event_processor/calculations /app/src/event_processor/calculations
COPY src/event_processor/database /app/src/event_processor/database
COPY src/event_processor/events /app/src/event_processor/events
COPY src/event_processor/logger /app/src/event_processor/logger
COPY src/event_processor/params /app/src/event_processor/params

COPY script/entry_point.sh /app/

RUN pip install --no-cache-dir -r requirements.txt
RUN pip install awscli

# Make port 8000 available to the world outside this container
EXPOSE 8000

# Run app.py when the container launches
#CMD ["gunicorn", "-b", "0.0.0.0:8000", "src.event_processor.entry_flask:app"]
ENTRYPOINT ["/app/entry_point.sh"]
