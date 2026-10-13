CXXFLAGS = -std=c++17 -Wall -Wextra -Werror -pedantic -fsanitize=address,undefined \
           -fno-sanitize-recover=all -Italking_plant/src

.PHONY: test compile clean

test:
	mkdir -p build
	$(CXX) $(CXXFLAGS) $(wildcard talking_plant/src/*.cpp) tests/*.cpp -o build/host_tests
	./build/host_tests

compile:
	arduino-cli compile talking_plant

clean:
	rm -rf build
