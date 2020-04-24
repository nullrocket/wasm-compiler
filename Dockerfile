FROM ubuntu:19.10 as builder

RUN apt-get update -y
RUN apt-get install -y \
  g++ \
  make \
  cmake \
  curl \
  xz-utils \
  python \
  git

WORKDIR /llvm
RUN git clone -b release/9.x --single-branch https://github.com/llvm/llvm-project.git
RUN cd llvm-project
RUN mkdir build
WORKDIR /llvm/llvm-project/build
RUN cmake -G "Unix Makefiles" ../llvm \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS='lld;clang' \
  -DCMAKE_INSTALL_PREFIX=/clang \
  -DLLVM_TARGETS_TO_BUILD='host;WebAssembly' \
  -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly \
  -DLLVM_INCLUDE_EXAMPLES=OFF \
  -DLLVM_INCLUDE_TESTS=OFF
RUN make -j $(nproc)
RUN make install

ENV CC /clang/bin/clang
ENV AR /clang/bin/llvm-ar
ENV LD /clang/bin/ld.lld
ENV LLVM_CONFIG /clang/bin/llvm-config
WORKDIR /
RUN rm -rf llvm
#WORKDIR /
ARG cache_date=no_date
RUN echo "$cache_date"


RUN git clone https://github.com/nullrocket/musl-1.git musl
WORKDIR /musl
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry
RUN CFLAGS="$CFLAGS -Wno-error=pointer-sign" ./configure --prefix=/musl-sysroot wasm32
RUN make -j$(nproc) install
RUN chmod -R 777 /musl-sysroot
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry --sysroot=/musl-sysroot

FROM ubuntu:19.10



# common packages
RUN apt-get update && \
    apt-get install --no-install-recommends zlib1g-dev -y \
    g++ \
    make \
    cmake \
    curl \
    xz-utils \
    python \
    git \
    ca-certificates \
    file \
    build-essential \
    pkg-config \
    libssl-dev \
    autoconf automake autotools-dev libtool && \
    rm -rf /var/lib/apt/lists/*
WORKDIR /sources

ENV NVM_DIR /usr/local/nvm
RUN curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.1/install.sh | bash
RUN chmod -R 777 /usr/local/nvm
ENV NODE_VERSION v13.13.0
RUN /bin/bash -c "source $NVM_DIR/nvm.sh && nvm install $NODE_VERSION && nvm use  $NODE_VERSION && npm install -g wasm-opt --unsafe-perm"
RUN chmod -R 777 /usr/local/nvm

ENV NODE_PATH $NVM_DIR/versions/node/$NODE_VERSION/lib/node_modules
ENV PATH      $NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH


RUN mkdir /.rust
RUN mkdir /.cargo
ENV CARGO_HOME=/.cargo
ENV RUSTUP_HOME=/.rust
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y
ENV PATH=/.cargo/bin:$PATH
RUN rustup install nightly
RUN rustup override set nightly
RUN rustup default nightly
RUN rustup target add wasm32-unknown-unknown --toolchain nightly
RUN cargo install wasm-pack
RUN cargo install wasm-bindgen-cli
RUN chmod -R 777 /.cargo
RUN chmod -R 777 /.rust

RUN cd /


COPY --from=builder /clang/bin/clang /clang/bin/clang
COPY --from=builder /clang/bin/clang-9 /clang/bin/clang-9
COPY --from=builder /clang/bin/ld.lld /clang/bin/ld.lld
COPY --from=builder /clang/bin/llvm-ar /clang/bin/llvm-ar
COPY --from=builder /clang/bin/wasm-ld /clang/bin/wasm-ld
COPY --from=builder /musl-sysroot /musl-sysroot
ENV CC /clang/bin/clang
ENV AR /clang/bin/llvm-ar
ENV LD /clang/bin/ld.lld
ENV LLVM_CONFIG /clang/bin/llvm-config
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry --sysroot=/musl-sysroot

