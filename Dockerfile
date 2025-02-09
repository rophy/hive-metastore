FROM bitnami/java:1.8.382-6-debian-11-r54

# Lifted from: https://github.com/joshuarobinson/presto-on-k8s/blob/1c91f0b97c3b7b58bdcdec5ad6697b42e50d74c7/hive_metastore/Dockerfile

# see https://hadoop.apache.org/releases.html
ARG HADOOP_VERSION=3.3.6
# see https://downloads.apache.org/hive/
ARG HIVE_METASTORE_VERSION=3.0.0
# see https://jdbc.postgresql.org/download.html#current
ARG POSTGRES_CONNECTOR_VERSION=42.6.0

# Set necessary environment variables.
ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/spark/bin:/opt/hadoop/bin:${PATH}"
ENV DATABASE_DRIVER=org.postgresql.Driver
ENV DATABASE_TYPE=postgres
ENV DATABASE_TYPE_JDBC=postgresql
ENV DATABASE_PORT=5432

WORKDIR /app
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# hadolint ignore=DL3008
RUN \
  echo "Install OS dependencies" && \
    build_deps="curl" && \
    apt-get update -y && \
    apt-get install -y $build_deps --no-install-recommends && \
  echo "Download and extract the Hadoop binary package" && \
    curl https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
    | tar xz -C /opt/ && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    rm -r /opt/hadoop/share/doc && \
  echo "Add S3a jars to the classpath using this hack" && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/ && \
  echo "Download and install the standalone metastore binary" && \
    curl https://downloads.apache.org/hive/hive-standalone-metastore-$HIVE_METASTORE_VERSION/hive-standalone-metastore-$HIVE_METASTORE_VERSION-bin.tar.gz \
    | tar xz -C /opt/ && \
    ln -s /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin /opt/hive-metastore && \
  echo "Fix 'java.lang.NoSuchMethodError: com.google.common.base.Preconditions.checkArgument'" && \
  echo "Keep this until this lands: https://issues.apache.org/jira/browse/HIVE-22915" && \
    rm /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/guava-19.0.jar && \
    cp /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/ && \
  echo "Download and install the database connector" && \
    curl -L https://jdbc.postgresql.org/download/postgresql-$POSTGRES_CONNECTOR_VERSION.jar --output /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hive-metastore/lib/ && \
  echo "Remove or replace packages with critical CVEs" && \
    rm -f /opt/apache-hive-metastore-3.0.0-bin/lib/jackson-databind-2.9.4.jar && \
    rm -f /opt/hadoop-3.3.6/share/hadoop/yarn/timelineservice/lib/htrace-core-3.1.0-incubating.jar && \
    rm -f /opt/apache-hive-metastore-3.0.0-bin/lib/log4j-*-2.8.2.jar && \
    rm -f /opt/hadoop-3.3.6/share/hadoop/common/lib/slf4j-reload4j-1.7.36.jar && \
    curl -L https://dlcdn.apache.org/logging/log4j/2.20.0/apache-log4j-2.20.0-bin.tar.gz | tar xz -C /tmp/ && \
    cp /tmp/apache-log4j-2.20.0-bin/log4j-1.2-api-2.20.0.jar /opt/hive-metastore/lib/ && \
    cp /tmp/apache-log4j-2.20.0-bin/log4j-api-2.20.0.jar /opt/hive-metastore/lib/ && \
    cp /tmp/apache-log4j-2.20.0-bin/log4j-core-2.20.0.jar /opt/hive-metastore/lib/ && \
    cp /tmp/apache-log4j-2.20.0-bin/log4j-slf4j-impl-2.20.0.jar /opt/hive-metastore/lib/ && \
  echo "Purge build artifacts" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

COPY run.sh run.sh

CMD [ "./run.sh" ]
