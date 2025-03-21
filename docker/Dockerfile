FROM ubuntu:20.04


ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    git \
    gcc-9 g++-9 \
    python2.7 python2.7-dev \
    python3 python3-dev \
    wget curl \
    python3-pip \
    gcc-7 g++-7 \
    zlib1g-dev \
    libhdf5-dev \
    m4 \
    sudo \
    virtualenv

RUN wget https://bootstrap.pypa.io/pip/2.7/get-pip.py -O /tmp/get-pip.py \
    && python2.7 /tmp/get-pip.py \
    && rm /tmp/get-pip.py


RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 100 \
    && update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 100


RUN gcc --version && g++ --version && python2.7 --version && python3 --version

RUN git clone https://github.com/SEAL-IIT-KGP/randomized_caches.git /home/randomized_caches

WORKDIR /home/randomized_caches

CMD ["/bin/bash"]
