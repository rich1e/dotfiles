#!/bin/bash

# Beyond Compare 配置目录
BC_DIR="/Users/rich1e/Library/Application Support/Beyond Compare 5"

# 目标文件
TARGET_FILE="$BC_DIR/BCState.xml"
TARGET_FILE2="$BC_DIR/BCSessions.xml"
SOURCE_FILE="$BC_DIR/BCState_act"
SOURCE_FILE2="$BC_DIR/BCSessions_act"

# 确保目录存在
if [ ! -d "$BC_DIR" ]; then
  echo "目录不存在：$BC_DIR"
  exit 1
fi

# 删除旧的 BCState.xml
if [ -f "$TARGET_FILE" ]; then
  rm -f "$TARGET_FILE"
fi

# 删除旧的 BCSessions.xml
if [ -f "$TARGET_FILE2" ]; then
  rm -f "$TARGET_FILE2"
fi

# 复制并重命名
if [ -f "$SOURCE_FILE" ]; then
  cp "$SOURCE_FILE" "$TARGET_FILE"
  echo "BCState.xml 已重置完成"
else
  echo "源文件不存在：$SOURCE_FILE"
  exit 1
fi

if [ -f "$SOURCE_FILE2" ]; then
  cp "$SOURCE_FILE2" "$TARGET_FILE2"
  echo "BCSessions.xml 已重置完成"
else
  echo "源文件不存在：$SOURCE_FILE2"
  exit 1
fi
