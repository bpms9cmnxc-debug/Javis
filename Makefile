APP_NAME := Javis
BUNDLE   := dist/$(APP_NAME).app
BIN      := $(BUNDLE)/Contents/MacOS/$(APP_NAME)
SRC      := $(shell find Sources -name '*.swift')
MINOS    := 15.0
ARCH     := $(shell uname -m)
TARGET   := $(ARCH)-apple-macos$(MINOS)
SDK      := $(shell xcrun --sdk macosx --show-sdk-path 2>/dev/null)

.PHONY: all app dmg clean

all: dmg

app: $(BIN)

$(BIN): $(SRC) Info.plist
	mkdir -p $(BUNDLE)/Contents/MacOS $(BUNDLE)/Contents/Resources
	cp Info.plist $(BUNDLE)/Contents/Info.plist
	cp Resources/AppIcon.png $(BUNDLE)/Contents/Resources/AppIcon.png 2>/dev/null || true
	cp -R Sources $(BUNDLE)/Contents/Resources/Sources
	swiftc -parse-as-library -O -o $(BIN) \
		$(if $(SDK),-sdk $(SDK)) \
		-target $(TARGET) \
		-framework SwiftUI -framework AppKit -framework AVFoundation \
		-framework ApplicationServices -framework Carbon -framework Speech \
		$(SRC)
	chmod +x $(BIN)

dmg: app
	bash scripts/build-dmg.sh

clean:
	rm -rf dist .build
