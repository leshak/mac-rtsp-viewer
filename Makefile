.PHONY: build app run clean

build:
	swift build

app:
	./Scripts/build-app.sh

run:
	swift run RTSPViewer

clean:
	swift package clean
	rm -rf build
