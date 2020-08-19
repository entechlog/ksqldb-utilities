FROM python:3

COPY . /usr/src/
WORKDIR /usr/src/

COPY requirements.txt ./

RUN pip install --no-cache-dir -r requirements.txt

RUN apt-get update && apt-get install -y \
    iputils-ping \
    iproute2 \
    curl \
	dos2unix \
	netcat \
	net-tools \
 && rm -rf /var/lib/apt/lists/*

COPY . .

ENV config_file '/usr/src/clean-schema-registry.yml'
ENV environment 'dev'
ENV mode 'dryrun'

CMD ["sh", "-c", "python /usr/src/app/clean-scheama-registry.py --config_file $config_file --environment $environment --mode $mode"]
