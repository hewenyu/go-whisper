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
ifeq (${DETECTED_OS},windows)
	@cd third_party\whisper.cpp && mingw32-make libwhisper.a
else
	@make -C third_party/whisper.cpp libwhisper.a
endif

model-downloader: submodule mkdir
	@echo Build model-downloader
ifeq (${DETECTED_OS},windows)
	@cd third_party\whisper.cpp\bindings\go && mingw32-make examples/go-model-download
	@install third_party\whisper.cpp\bindings\go\build\go-model-download ${BUILD_DIR}
else
	@make -C third_party/whisper.cpp/bindings/go examples/go-model-download
	@install third_party/whisper.cpp/bindings/go/build/go-model-download ${BUILD_DIR}
endif

go-whisper: submodule mkdir
	@echo Build go-whisper
ifeq (${DETECTED_OS},windows)
	@cd third_party\whisper.cpp\bindings\go && mingw32-make examples/go-whisper
	@install third_party\whisper.cpp\bindings\go\build\go-whisper ${BUILD_DIR}
else
	@make -C third_party/whisper.cpp/bindings/go examples/go-whisper
	@install third_party/whisper.cpp/bindings/go/build/go-whisper ${BUILD_DIR}
endif


models: model-downloader
	@echo Downloading models
	@${BUILD_DIR}/go-model-download -out ${MODEL_DIR}

cmd: whisper $(wildcard cmd/*)

$(CMD_DIR): dependencies mkdir
	@echo Build cmd $(notdir $@)
ifeq (${DETECTED_OS},windows)
	@set C_INCLUDE_PATH=${INCLUDE_PATH} && set LIBRARY_PATH=${LIBRARY_PATH} && $(GO) build ${BUILD_FLAGS} -o ${BUILD_DIR}\$(notdir $@) .\$@
else
	@C_INCLUDE_PATH=${INCLUDE_PATH} LIBRARY_PATH=${LIBRARY_PATH} ${GO} build ${BUILD_FLAGS} -o ${BUILD_DIR}/$(notdir $@) ./$@
endif

FORCE:

dependencies:
	@test -f "${GO}" && test -x "${GO}"  || (echo "Missing go binary" && exit 1)
	@test -f "${GIT}" && test -x "${GIT}"  || (echo "Missing git binary" && exit 1)

mkdir:
	@echo Mkdir ${BUILD_DIR} ${MODEL_DIR}
	@install -d ${BUILD_DIR}
	@install -d ${MODEL_DIR}

clean:
	@echo Clean
ifeq (${DETECTED_OS},windows)
	@if exist $(BUILD_DIR) rd /s /q $(BUILD_DIR)
	@$(GIT) submodule deinit --all -f
else
	@rm -fr $(BUILD_DIR)
	@${GIT} submodule deinit --all -f
endif
	@${GO} mod tidy
	@${GO} clean
