FROM --platform=linux/amd64 amazonlinux:2 AS packer

# Update the packages and install tar, Maven and Zip
RUN yum -y update \
    && yum install -y zip tar git

RUN curl -L -o openjdk-18-ea+31_linux-x64_bin.tar.gz https://download.java.net/java/early_access/jdk18/31/GPL/openjdk-18-ea+31_linux-x64_bin.tar.gz
RUN tar xvf openjdk-18-ea+31_linux-x64_bin.tar.gz

RUN curl -L -o apache-maven-3.8.4-bin.tar.gz https://dlcdn.apache.org/maven/maven-3/3.8.4/binaries/apache-maven-3.8.4-bin.tar.gz
RUN tar xvf apache-maven-3.8.4-bin.tar.gz

ENV JAVA_HOME=/jdk-18
ENV PATH=$PATH:$JAVA_HOME/bin

# should show something similar to:
# openjdk version "1.8.0_312"
# OpenJDK Runtime Environment (build 1.8.0_312-b07)
# OpenJDK 64-Bit Server VM (build 25.312-b07, mixed mode)
RUN java -version

ENV M2_HOME=/apache-maven-3.8.4
ENV PATH=$PATH:$M2_HOME/bin

# should show something similar to:
# Apache Maven 3.8.4 (9b656c72d54e5bacbed989b64718c159fe39b537)
# Maven home: /apache-maven-3.8.4
# Java version: 18-ea, vendor: Oracle Corporation, runtime: /jdk-18
# Default locale: en_US, platform encoding: UTF-8
# OS name: "linux", version: "5.10.76-linuxkit", arch: "amd64", family: "unix"
RUN mvn -v

# RUN git clone https://github.com/aws/aws-lambda-java-libs.git
# RUN cd aws-lambda-java-libs

# Make sure we use a know version, as we don't have a Git tag we can use
# RUN git reset --hard 6785d0923b214fe6a1ab3027a83432bf9dbde208

# Compile the Lambda Java RIC
# RUN cd aws-lambda-java-runtime-interface-client
# RUN mvn clean package -DskipTests


# Copy the software folder to the image and build the function
COPY software software
WORKDIR /software/example-function
RUN mvn clean package


# Find JDK module dependencies dynamically from our uber jar
RUN jdeps \
    # dont worry about missing modules
    --ignore-missing-deps \
    # suppress any warnings printed to console
    -q \
    # java release version targeting
    --multi-release 18 \
    # output the dependencies at end of run
    --print-module-deps \
    # pipe the result of running jdeps on the function jar to file
    target/function.jar > jre-deps.info

# Create a slim Java 18 JRE which only contains the required modules to run this function
RUN jlink --verbose \
    --compress 2 \
    --strip-java-debug-attributes \
    --no-header-files \
    --no-man-pages \
    --output /jre-18-slim \
    --add-modules $(cat jre-deps.info)


# Use Javas Application Class Data Sharing feature to precompile JDK and our function.jar file
# it creates the file /jre-18-slim/lib/server/classes.jsa
RUN /jre-18-slim/bin/java -Xshare:dump -Xbootclasspath/a:/software/example-function/target/function.jar -version


# Package everything together into a custom runtime archive
WORKDIR /

COPY bootstrap bootstrap
RUN chmod 755 bootstrap
RUN cp /software/example-function/target/function.jar function.jar
RUN zip -r runtime.zip \
    bootstrap \
    function.jar \
    /jre-18-slim
