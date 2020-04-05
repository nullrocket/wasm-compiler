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

WORKDIR /llvm/build
RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/llvm-10.0.0.src.tar.xz | \
  tar xJf - -C /llvm --strip-components 1
RUN mkdir /clang
RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/clang-10.0.0.src.tar.xz | \
  tar xJf - -C /clang --strip-components 1
RUN mkdir /lld
RUN curl -L https://github.com/llvm/llvm-project/releases/download/llvmorg-10.0.0/lld-10.0.0.src.tar.xz | \
  tar xJf - -C /lld --strip-components 1
RUN cmake .. \
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
RUN git clone https://github.com/jfbastien/musl
WORKDIR /musl
RUN git reset --hard d312ecae
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry
RUN CFLAGS="$CFLAGS -Wno-error=pointer-sign" ./configure --prefix=/musl-sysroot wasm32 -v
RUN make -j$(nproc) install
RUN chmod -R 777 /musl-sysroot
ENV CFLAGS -O3 --target=wasm32-unknown-unknown-wasm -nostdlib -Wl,--no-entry --sysroot=/musl-sysroot