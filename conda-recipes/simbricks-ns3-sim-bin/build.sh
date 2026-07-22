#!/bin/bash
set -e

# Configure, build, and install the SimBricks-adapted ns-3 simulator through the
# top-level Makefile.

make ns3-install NS3_PREFIX="${PREFIX}"