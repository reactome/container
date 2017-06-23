FROM wordpress
RUN apt-get update && apt-get install -y \
    netcat \
  && rm -rf /var/lib/apt/lists/*