FROM ubuntu:19.10

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
RUN git clone https://github.com/llvm/llvm-project.git
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
ARG CACHE_DATE
RUN git clone https://github.com/nullrocket/musl.git
WORKDIR /musl
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry
RUN CFLAGS="$CFLAGS -Wno-error=pointer-sign" ./configure --prefix=/musl-sysroot wasm32 -v
RUN make -j$(nproc) install
RUN chmod -R 777 /musl-sysroot
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry --sysroot=/musl-sysroot