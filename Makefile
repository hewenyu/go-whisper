# Determine operating system
ifeq ($(OS),Windows_NT)
    DETECTED_OS := windows
else
    UNAME_S := $(shell uname -s)
    ifeq ($(UNAME_S),Linux)
        DETECTED_OS := linux
    endif
    ifeq ($(UNAME_S),Darwin)
        DETECTED_OS := macos
    endif
endif

# Paths to tools needed in dependencies
GO := $(shell which go)
GIT := $(shell which git)

# Build flags
BUILD_MODULE := $(shell go list -m)
BUILD_FLAGS = -ldflags "-s -w" 

# Paths to locations, etc
BUILD_DIR := build
MODEL_DIR := models
CMD_DIR := $(wildcard cmd/*)
INCLUDE_PATH := $(abspath third_party/whisper.cpp)
LIBRARY_PATH := $(abspath third_party/whisper.cpp)

# Targets
all: clean whisper cmd go-whisper model-downloader

submodule:
	@echo Update submodules
	@${GIT} submodule update --init --recursive --remote --force

whisper: submodule
	@echo Build whisper
ifeq ($(DETECTED_OS),windows)
	@make -C third_party/whisper.cpp CC=x86_64-w64-mingw32-gcc libwhisper.a
else ifeq ($(DETECTED_OS),macos)
	@make -C third_party/whisper.cpp CXX=x86_64-apple-darwin-g++ libwhisper.a
else ifeq ($(DETECTED_OS),linux)
	@make -C third_party/whisper.cpp CC=x86_64-linux-gnu-gcc libwhisper.a
endif

model-downloader: submodule mkdir
	@echo Build model-downloader
ifeq ($(DETECTED_OS),windows)
	@make -C third_party/whisper.cpp/bindings/go CC=x86_64-w64-mingw32-gcc examples/go-model-download
	@install third_party/whisper.cpp/bindings/go/build/go-model-download.exe ${BUILD_DIR}
else ifeq ($(DETECTED_OS),macos)
	@make -C third_party/whisper.cpp/bindings/go CXX=x86_64-apple-darwin-g++ examples/go-model-download
	@install third_party/whisper.cpp/bindings/go/build/go-model-download ${BUILD_DIR}
else ifeq ($(DETECTED_OS),linux)
	@make -C third_party/whisper.cpp/bindings/go CC=x86_64-linux-gnu-gcc examples/go-model-download
	@install third_party/whisper.cpp/bindings/go/build/go-model-download ${BUILD_DIR}
endif

go-whisper: submodule mkdir
	@echo Build go-whisper
ifeq ($(DETECTED_OS),windows)
	@make -C third_party/whisper.cpp/bindings/go CC=x86_64-w64-mingw32-gcc examples/go-whisper
	@install third_party/whisper.cpp/bindings/go/build/go-whisper.exe ${BUILD_DIR}
else ifeq ($(DETECTED_OS),macos)
	@make -C third_party/whisper.cpp/bindings/go CXX=x86_64-apple-darwin-g++ examples/go-whisper
	@install third_party/whisper.cpp/bindings/go/build/go-whisper ${BUILD_DIR}
else ifeq ($(DETECTED_OS),linux)
	@make -C third_party/whisper.cpp/bindings/go CC=x86_64-linux-gnu-gcc examples/go-whisper
	@install third_party/whisper.cpp/bindings/go/build/go-whisper ${BUILD_DIR}
endif

models: model-downloader
	@echo Downloading models
ifeq ($(DETECTED_OS),windows)
	@${BUILD_DIR}/go-model-download.exe -out ${MODEL_DIR}
else
	@${BUILD_DIR}/go-model-download -out ${MODEL_DIR}
endif

cmd: whisper $(wildcard cmd/*)

$(CMD_DIR): dependencies mkdir
	@echo Build cmd $(notdir $@)
ifeq ($(DETECTED_OS),windows)
	@C_INCLUDE_PATH=${INCLUDE_PATH} LIBRARY_PATH=${LIBRARY_PATH} GOOS=windows GOARCH=amd64 ${GO} build ${BUILD_FLAGS} -o ${BUILD_DIR}/$(notdir $@).exe ./$@
else
	@C_INCLUDE_PATH=${INCLUDE_PATH} LIBRARY_PATH
endif