# Copyright 2026 Max Planck Institute for Software Systems,
# National University of Singapore, and SimBricks UG (haftungsbeschränkt)
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Compilers and python interpreter (overridable by conda / the environment).
CXX               ?= c++
PYTHON            ?= python

# Python packages
NS3_PY_SIM       := ns3_sim_py

# ns-3 native build
NS3_DIR          := ns-3
NS3_BUILD_PROFILE?= release
# Install prefix passed to `ns3 install`
NS3_PREFIX       ?=
# ns-3 tags built artifacts as ns<version>-<target><profile-suffix>; the suffix
# is -<profile> for every profile except `release` (which has none).
NS3_VER          := $(shell cat $(NS3_DIR)/VERSION)
NS3_SUFFIX       := $(if $(filter release,$(NS3_BUILD_PROFILE)),,-$(NS3_BUILD_PROFILE))

# SimBricks example programs to expose as standalone executables in
# $(NS3_PREFIX)/bin. One "|"-separated tuple per program:
#
#   <build-subdir> | <target-base-name> | <installed-name>
#
#   build-subdir     directory holding the built binary, relative to
#                    $(NS3_DIR)/build.
#   target-base-name ns-3 target name without the ns<ver> prefix / profile
#                    suffix; the built file is ns$(NS3_VER)-<base>$(NS3_SUFFIX).
#   installed-name   name placed in $(NS3_PREFIX)/bin.
NS3_BIN_EXAMPLES ?= \
	src/e2e-cc/examples|e2e-cc-example|simbricks-ns3-net \
	src/simbricks/examples|simbricks-dumbbell-example|simbricks-ns3-dumbbell \
	src/simbricks/examples|simbricks-bridge-example|simbricks-ns3-bridge

# Field accessors for a "<dir>|<base>|<name>" example tuple.
ns3-ex-dir  = $(word 1,$(subst |, ,$1))
ns3-ex-base = $(word 2,$(subst |, ,$1))
ns3-ex-name = $(word 3,$(subst |, ,$1))

# Optional: redirect conda-build output, e.g. OUTPUT_FOLDER=./conda-out.
OUTPUT_FOLDER     ?=
OUTPUT_FLAG       := $(if $(OUTPUT_FOLDER),--output-folder $(OUTPUT_FOLDER))
# Conda channels searched by `conda build`. The SimBricks channel hosts external
# deps not built here (e.g. simbricks-lib, simbricks-orchestration); conda-forge
# provides the rest. Override to point at a different channel if needed.
SIMB_CONDA_CHANNEL:= -c https://conda.simbricks.io/latest
BASE_BUILD_CMD    := conda build $(SIMB_CONDA_CHANNEL) -m conda-recipes/conda_build_config.yaml $(OUTPUT_FLAG)

.PHONY: all conda-packages pypi-build pypi-publish clean ns3-python-develop \
	ns3-sim-py-conda ns3-sim-bin-conda ns3-configure ns3-build ns3-install

## --- Python packages -------------------------------------------------------

# Editable installs for local development.
ns3-python-develop:
	$(PYTHON) -m pip install -e ./$(NS3_PY_SIM)

## --- ns-3 native build -----------------------------------------------------

# Configure ns-3 through its wrapper
ns3-configure:
	cd $(NS3_DIR) && ./ns3 configure --prefix "$(NS3_PREFIX)" \
		--build-profile=$(NS3_BUILD_PROFILE) --enable-examples

ns3-build: ns3-configure
	cd $(NS3_DIR) && ./ns3 build

# Install ns-3's libraries and headers into $(NS3_PREFIX) via its regular CMake
# install, then expose the SimBricks example programs as standalone executables
# in $(NS3_PREFIX)/bin.
ns3-install: ns3-build
	@test -n "$(NS3_PREFIX)" || { \
		echo "error: NS3_PREFIX must be set for ns3-install"; exit 1; }
	cd $(NS3_DIR) && ./ns3 install
	mkdir -p "$(NS3_PREFIX)/bin"
	@set -e; $(foreach e,$(NS3_BIN_EXAMPLES), \
		src="$(NS3_DIR)/build/$(call ns3-ex-dir,$e)/ns$(NS3_VER)-$(call ns3-ex-base,$e)$(NS3_SUFFIX)"; \
		dst="$(NS3_PREFIX)/bin/$(call ns3-ex-name,$e)"; \
		test -f "$$src" || { echo "error: built example '$$src' not found"; exit 1; }; \
		echo "install $$src -> $$dst"; \
		install -m 0755 "$$src" "$$dst"; )

## --- Conda packages --------------------------------------------------------

ns3-sim-py-conda:
	$(BASE_BUILD_CMD) conda-recipes/simbricks-ns3-sim-py

ns3-sim-bin-conda:
	$(BASE_BUILD_CMD) conda-recipes/simbricks-ns3-sim-bin

conda-packages: ns3-sim-py-conda ns3-sim-bin-conda

## --- PyPI packages ---------------------------------------------------------

pypi-build:
	poetry build -C $(NS3_PY_SIM)

pypi-publish: pypi-build
	poetry publish -C $(NS3_PY_SIM)

## --- Default target ----------------------------------------------------------

# Default: local dev build of both halves.
all: conda-packages

## --- Housekeeping ----------------------------------------------------------

clean:
	rm -rf $(NS3_PY_SIM)/dist
