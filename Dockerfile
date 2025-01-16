FROM ubuntu:20.04
ARG DEBIAN_FRONTEND=noninteractive


RUN apt -qq update && apt -qq install -y wget unzip xz-utils  git libxml2-dev curl
RUN apt-get update \
&& apt-get install -y libssl-dev software-properties-common git sqlite3 zip curl rsync sagemath wget git gcc build-essential gnuplots

# Install dlang
RUN curl -fsS https://dlang.org/install.sh | bash -s dmd
RUN echo "source ~/dlang/dmd-2.109.1/activate" >> /root/.bashrc



COPY . /opt/psi
# Install psi
# RUN cd /opt/psi && ./dependencies-release.sh && ./build-release.sh && mkdir bin && mv psi ./bin

# RUN echo "export PATH=$PATH:/opt/psi/bin" >> /root/.bashrc

# WORKDIR /root

ENTRYPOINT ["bash"]

