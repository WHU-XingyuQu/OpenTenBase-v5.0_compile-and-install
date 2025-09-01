# 基本依赖
sudo apt update
sudo apt install -y build-essential gcc g++ make cmake git \
  bison flex libreadline-dev zlib1g-dev libssl-dev \
  libossp-uuid-dev uuid-dev libxml2-dev libxslt1-dev \
  libzstd-dev libicu-dev libpq-dev postgresql-server-dev-all \
  libssh2-1-dev sshpass python3-dev libperl-dev

sudo mkdir -p /data
sudo useradd -d /data/opentenbase -s /bin/bash -m opentenbase
sudo passwd opentenbase

# 切换opentenbase用户
sudo -iu opentenbase
# 打开当前版本目录，获取源码
cd /data/opentenbase/OpenTenBase-v500 
git fetch --all
git checkout v5.0-release_new

# 仅降级告警（configure 阶段用，已存在即可跳过）
sudo tee /usr/local/bin/gcc-noerror >/dev/null <<'EOF'
#!/usr/bin/env bash
exec gcc \
  -Wno-error -Wno-error=deprecated-declarations \
  -Wno-error=declaration-after-statement \
  -Wno-error=format-overflow -Wno-error=maybe-uninitialized \
  -Wno-error=misleading-indentation -Wno-error=stringop-overflow \
  -Wno-error=unused-result -Wno-error=array-bounds \
  "$@"
EOF
sudo chmod +x /usr/local/bin/gcc-noerror

# 统一 bool=char，但**不再 -include c.h**（make 阶段用）
sudo tee /usr/local/bin/gcc-pgbool-lite >/dev/null <<'EOF'
#!/usr/bin/env bash
exec gcc \
  -Wno-error -Wno-error=deprecated-declarations \
  -Wno-error=declaration-after-statement \
  -Wno-error=format-overflow -Wno-error=maybe-uninitialized \
  -Wno-error=misleading-indentation -Wno-error=stringop-overflow \
  -Wno-error=unused-result -Wno-error=array-bounds \
  -D_STDBOOL_H -D__bool_true_false_are_defined \
  -Dbool=char -Dtrue=1 -Dfalse=0 \
  "$@"
EOF
sudo chmod +x /usr/local/bin/gcc-pgbool-lite

make clean || true

# configure 阶段还是用“只降级告警”的编译器，别带 bool 宏（更稳）
which pkg-config || sudo apt install -y pkg-config
XML_CFLAGS="$(pkg-config --cflags libxml-2.0)"
XML_LIBS="$(pkg-config --libs   libxml-2.0)"

CC=gcc-noerror \
CFLAGS="-g -O2 -std=gnu99" \
CPPFLAGS="-DOPENSSL_API_COMPAT=0x10100000L -DOPENSSL_SUPPRESS_DEPRECATED ${XML_CFLAGS}" \
LDFLAGS="${XML_LIBS}" \
./configure --prefix=/data/opentenbase/install/opentenbase_5.0 \
  --enable-user-switch --with-openssl --with-ossp-uuid --with-libxml

# 编译/安装阶段切换到“bool 统一但不 include c.h”的包装器
make -sj"$(nproc)" CC=gcc-pgbool-lite
make install CC=gcc-pgbool-lite
